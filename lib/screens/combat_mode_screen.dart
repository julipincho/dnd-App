import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/dice/models/dice_roll_result.dart';
import '../features/dice/services/dice_roller_service.dart';
import '../features/characters/models/resolved_inventory_item.dart';
import '../logic/character_option_effects.dart';
import '../models/character.dart';
import '../models/character_inventory_item.dart';
import '../models/character_feature.dart';
import '../models/character_resource.dart';
import '../models/spell.dart';
import '../providers/compendium_provider.dart';
import '../providers/character_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/spell_provider.dart';
import '../services/character_inventory_service.dart';
import '../services/character_weapon_attack_service.dart';
import '../theme.dart';
import '../utils/character_equipment_effects.dart';

class CombatModeScreen extends StatefulWidget {
  final String? characterId;

  const CombatModeScreen({
    super.key,
    this.characterId,
  });

  @override
  State<CombatModeScreen> createState() => _CombatModeScreenState();
}

class _CombatModeScreenState extends State<CombatModeScreen> {
  late List<_Combatant> _combatants;
  late List<_CombatLogEntry> _activity;
  late List<_CombatAction> _characterActions;
  _CombatRollFeedback? _rollFeedback;
  final Set<String> _spentTimings = {};
  int _activeIndex = 0;
  int _targetIndex = 2;
  int _round = 1;
  String _selectedCommandTiming = 'Action';
  bool _seededCharacter = false;

  static const List<_CombatAction> _playerActions = [
    _CombatAction(
      name: 'Longsword Strike',
      type: 'Weapon Attack',
      timing: 'Action',
      attackFormula: 'd20+7',
      damageFormula: '1d8+4',
      critFormula: '2d8+4',
      tags: ['Melee', 'Slashing', 'Prepared'],
      icon: Icons.gavel_outlined,
      accentKind: _CombatAccentKind.action,
    ),
    _CombatAction(
      name: 'Fire Bolt',
      type: 'Spell Attack',
      timing: 'Action',
      attackFormula: 'd20+6',
      damageFormula: '2d10',
      critFormula: '4d10',
      tags: ['Ranged', 'Fire', 'Cantrip'],
      icon: Icons.local_fire_department_outlined,
      accentKind: _CombatAccentKind.magic,
    ),
    _CombatAction(
      name: 'Second Wind',
      type: 'Feature',
      timing: 'Bonus Action',
      attackFormula: null,
      damageFormula: '1d10+3',
      critFormula: null,
      tags: ['Healing', '1 / Short Rest'],
      icon: Icons.favorite_border,
      accentKind: _CombatAccentKind.support,
      targetsSelf: true,
      isHealing: true,
    ),
  ];

  static const List<_CombatAction> _enemyActions = [
    _CombatAction(
      name: 'Commander Blade',
      type: 'Weapon Attack',
      timing: 'Action',
      attackFormula: 'd20+5',
      damageFormula: '1d8+3',
      critFormula: '2d8+3',
      tags: ['Melee', 'Martial', 'Enemy'],
      icon: Icons.gavel_outlined,
      accentKind: _CombatAccentKind.action,
    ),
    _CombatAction(
      name: 'Shortbow Shot',
      type: 'Ranged Attack',
      timing: 'Action',
      attackFormula: 'd20+4',
      damageFormula: '1d6+2',
      critFormula: '2d6+2',
      tags: ['Ranged', 'Piercing', 'Enemy'],
      icon: Icons.ads_click_outlined,
      accentKind: _CombatAccentKind.read,
    ),
    _CombatAction(
      name: 'Rallying Cry',
      type: 'Monster Feature',
      timing: 'Bonus Action',
      attackFormula: null,
      damageFormula: '1d6+2',
      critFormula: null,
      tags: ['Morale', 'Healing', 'Enemy'],
      icon: Icons.record_voice_over_outlined,
      accentKind: _CombatAccentKind.support,
      targetsSelf: true,
      isHealing: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _combatants = _buildDefaultCombatants();
    _characterActions = _playerActions;
    _activity = [
      _CombatLogEntry.system(
        'Encounter prototype ready. Initiative order is loaded.',
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededCharacter || widget.characterId == null) return;

    final character =
        context.read<CharacterProvider>().getCharacterById(widget.characterId!);
    if (character == null) return;
    final equipmentProvider = context.read<EquipmentProvider>();
    final compendiumProvider = context.read<CompendiumProvider>();
    final spellProvider = context.read<SpellProvider>();

    _combatants = [
      _combatantFromCharacter(
        character,
        equipmentProvider,
        compendiumProvider,
      ),
      ..._combatants.skip(1),
    ];
    _characterActions = _buildCharacterActions(
      character,
      equipmentProvider,
      compendiumProvider,
      spellProvider,
    );
    _activeIndex = 0;
    _targetIndex = _findDefaultTargetIndex(_activeIndex);
    _activity = [
      _CombatLogEntry.system(
        '${character.name} entered Combat Mode. Demo enemies are staged.',
      ),
      ..._activity,
    ];
    _seededCharacter = true;

    if (!spellProvider.isLoaded) {
      spellProvider.loadSpells().then((_) {
        if (!mounted) return;
        setState(() {
          _characterActions = _buildCharacterActions(
            character,
            equipmentProvider,
            compendiumProvider,
            spellProvider,
          );
        });
      });
    }
  }

  _Combatant get _activeCombatant => _combatants[_activeIndex];

  int get _safeTargetIndex {
    if (_combatants.isEmpty) return 0;
    if (_targetIndex >= 0 &&
        _targetIndex < _combatants.length &&
        _targetIndex != _activeIndex) {
      return _targetIndex;
    }
    return _findDefaultTargetIndex(_activeIndex);
  }

  _Combatant get _selectedTarget => _combatants[_safeTargetIndex];

  List<_CombatAction> get _activeActions {
    return _activeCombatant.team == _CombatTeam.party
        ? _characterActions
        : _enemyActions;
  }

  void _requestInitiative() {
    setState(() {
      _activity.insert(
        0,
        _CombatLogEntry.system(
          'DM requested initiative. Waiting for party rolls.',
        ),
      );
    });
  }

  void _rollInitiativeForAll() {
    final updated = <_Combatant>[];

    for (final combatant in _combatants) {
      final bonus = combatant.initiativeBonus;
      final result = DiceRollerService.rollFormula(
        formula: _formatRollFormula('d20', bonus),
        label: '${combatant.name} Initiative',
      );
      updated.add(combatant.copyWith(initiative: result.total));
    }

    updated.sort((a, b) => b.initiative.compareTo(a.initiative));

    setState(() {
      _combatants = updated;
      _activeIndex = 0;
      _targetIndex = _findDefaultTargetIndex(0, updated);
      _spentTimings.clear();
      _round = 1;
      _activity.insert(
        0,
        _CombatLogEntry.system('Initiative rolled. Round 1 begins.'),
      );
    });
  }

  void _nextTurn() {
    setState(() {
      var nextIndex = _activeIndex + 1;
      if (nextIndex >= _combatants.length) {
        nextIndex = 0;
        _round += 1;
        _activity.insert(0, _CombatLogEntry.system('Round $_round begins.'));
      }

      _activeIndex = nextIndex;
      _targetIndex = _findDefaultTargetIndex(nextIndex);
      _spentTimings.clear();
      _selectedCommandTiming = 'Action';
      _rollFeedback = null;
      _activity.insert(
        0,
        _CombatLogEntry.turn('${_activeCombatant.name} takes the turn.'),
      );
    });
  }

  void _rollAction(_CombatAction action, _CombatActionRoll rollType) {
    final formula = switch (rollType) {
      _CombatActionRoll.attack => action.attackFormula,
      _CombatActionRoll.damage => action.damageFormula,
      _CombatActionRoll.critical => action.critFormula,
    };

    if (formula == null) return;

    final label = switch (rollType) {
      _CombatActionRoll.attack => '${action.name} Attack',
      _CombatActionRoll.damage => '${action.name} Damage',
      _CombatActionRoll.critical => '${action.name} Critical',
    };

    final result =
        DiceRollerService.rollFormula(formula: formula, label: label);

    setState(() {
      String? detail;
      String headline;
      String? subline;
      _CombatAccentKind feedbackKind = action.accentKind;
      _spentTimings.add(action.timing);

      if (rollType == _CombatActionRoll.attack) {
        final target = _selectedTarget;
        final outcome = _attackOutcome(result, target);
        headline = outcome.toUpperCase();
        subline = '${_activeCombatant.name} vs ${target.name} AC ${target.ac}';
        feedbackKind = switch (outcome) {
          'critical hit' => _CombatAccentKind.support,
          'hit' => _CombatAccentKind.action,
          'automatic miss' => _CombatAccentKind.info,
          _ => _CombatAccentKind.read,
        };
        detail =
            '${result.formula} - ${result.rollsText}. ${target.name} AC ${target.ac}: $outcome.';
      } else {
        final targetIndex =
            action.targetsSelf ? _activeIndex : _safeTargetIndex;
        final target = _combatants[targetIndex];
        final amount = result.total;
        final nextHp = action.isHealing
            ? (target.hp + amount).clamp(0, target.maxHp).toInt()
            : (target.hp - amount).clamp(0, target.maxHp).toInt();
        final nextCombatants = [..._combatants];
        nextCombatants[targetIndex] = target.copyWith(hp: nextHp);
        _combatants = nextCombatants;

        final verb = action.isHealing ? 'recovers' : 'takes';
        final suffix = action.isHealing ? 'HP' : 'damage';
        headline = action.isHealing ? 'HEAL $amount' : '$amount DAMAGE';
        subline = '${target.name}: ${target.hp} -> $nextHp HP';
        feedbackKind = action.isHealing
            ? _CombatAccentKind.support
            : _CombatAccentKind.action;
        detail =
            '${result.formula} - ${result.rollsText}. ${target.name} $verb $amount $suffix (${target.hp} -> $nextHp HP).';

        if (!action.isHealing && target.hp > 0 && nextHp == 0) {
          _activity.insert(
            0,
            _CombatLogEntry.system('${target.name} is down.'),
          );
          _targetIndex = _findDefaultTargetIndex(_activeIndex);
        }
      }

      _activity.insert(
        0,
        _CombatLogEntry.roll(
          actor: _activeCombatant.name,
          action: action.name,
          result: result,
          detail: detail,
        ),
      );
      _rollFeedback = _CombatRollFeedback(
        actor: _activeCombatant.name,
        action: action.name,
        result: result,
        headline: headline,
        subline: subline,
        accentKind: feedbackKind,
      );
    });
  }

  void _useAction(_CombatAction action) {
    setState(() {
      _spentTimings.add(action.timing);
      _activity.insert(
        0,
        _CombatLogEntry.system('${_activeCombatant.name} used ${action.name}.'),
      );
      _rollFeedback = _CombatRollFeedback.manual(
        actor: _activeCombatant.name,
        action: action.name,
        headline: 'READY',
        subline: action.tags.take(3).join(' - '),
        accentKind: action.accentKind,
      );
    });
  }

  void _selectTarget(int index) {
    if (index == _activeIndex || index < 0 || index >= _combatants.length) {
      return;
    }

    setState(() {
      _targetIndex = index;
      _activity.insert(
        0,
        _CombatLogEntry.system('${_combatants[index].name} is targeted.'),
      );
    });
  }

  void _selectCommandTiming(String timing) {
    setState(() {
      _selectedCommandTiming = timing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Scaffold(
      backgroundColor: tokens.pageBottom,
      body: Stack(
        children: [
          Positioned.fill(
            child: _CombatArenaBackdrop(round: _round),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useGameLayout = constraints.maxWidth >= 1050 &&
                    constraints.maxHeight >= 700;

                if (useGameLayout) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1420),
                      child: _CombatLayeredGameView(
                        round: _round,
                        combatants: _combatants,
                        activeIndex: _activeIndex,
                        targetIndex: _safeTargetIndex,
                        activeCombatant: _activeCombatant,
                        selectedTarget: _selectedTarget,
                        actions: _activeActions,
                        rollFeedback: _rollFeedback,
                        spentTimings: _spentTimings,
                        selectedCommandTiming: _selectedCommandTiming,
                        entries: _activity,
                        onBack: () => Navigator.of(context).maybePop(),
                        onRequestInitiative: _requestInitiative,
                        onRollInitiative: _rollInitiativeForAll,
                        onNextTurn: _nextTurn,
                        onSelectTarget: _selectTarget,
                        onSelectCommandTiming: _selectCommandTiming,
                        onRollAction: _rollAction,
                        onUseAction: _useAction,
                      ),
                    ),
                  );
                }

                final isDesktop = constraints.maxWidth >= 1050;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: ListView(
                      padding: EdgeInsets.all(isDesktop ? 24 : 14),
                      children: [
                        _CombatHeader(
                          round: _round,
                          activeCombatant: _activeCombatant,
                          selectedTarget: _selectedTarget,
                          onBack: () => Navigator.of(context).maybePop(),
                          onRequestInitiative: _requestInitiative,
                          onRollInitiative: _rollInitiativeForAll,
                          onNextTurn: _nextTurn,
                        ),
                        const SizedBox(height: 14),
                        _DuelSpotlightPanel(
                          round: _round,
                          activeCombatant: _activeCombatant,
                          targetCombatant: _selectedTarget,
                        ),
                        if (_rollFeedback != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child:
                                _RollFeedbackWindow(feedback: _rollFeedback!),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _BattlefieldPanel(
                          combatants: _combatants,
                          activeIndex: _activeIndex,
                          targetIndex: _safeTargetIndex,
                          onSelectTarget: _selectTarget,
                        ),
                        const SizedBox(height: 14),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 300,
                                child: _InitiativePanel(
                                  combatants: _combatants,
                                  activeIndex: _activeIndex,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _ActiveTurnPanel(
                                  combatant: _activeCombatant,
                                  combatants: _combatants,
                                  activeIndex: _activeIndex,
                                  targetIndex: _safeTargetIndex,
                                  onSelectTarget: _selectTarget,
                                  spentTimings: _spentTimings,
                                  actions: _activeActions,
                                  onRollAction: _rollAction,
                                ),
                              ),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 330,
                                child: _ActivityPanel(entries: _activity),
                              ),
                            ],
                          )
                        else ...[
                          _InitiativePanel(
                            combatants: _combatants,
                            activeIndex: _activeIndex,
                          ),
                          const SizedBox(height: 12),
                          _ActiveTurnPanel(
                            combatant: _activeCombatant,
                            combatants: _combatants,
                            activeIndex: _activeIndex,
                            targetIndex: _safeTargetIndex,
                            onSelectTarget: _selectTarget,
                            spentTimings: _spentTimings,
                            actions: _activeActions,
                            onRollAction: _rollAction,
                          ),
                          const SizedBox(height: 12),
                          _ActivityPanel(entries: _activity),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_Combatant> _buildDefaultCombatants() {
    return [
      const _Combatant(
        name: 'Arnnazal',
        role: 'Half-Orc Paladin 5 / Blood Hunter 2',
        initiative: 18,
        initiativeBonus: 3,
        hp: 174,
        maxHp: 174,
        ac: 12,
        speed: 30,
        team: _CombatTeam.party,
        conditions: ['Blessed'],
      ),
      const _Combatant(
        name: 'Lyra',
        role: 'Wizard',
        initiative: 15,
        initiativeBonus: 2,
        hp: 32,
        maxHp: 38,
        ac: 14,
        speed: 30,
        team: _CombatTeam.party,
        conditions: ['Concentrating'],
      ),
      const _Combatant(
        name: 'Hobgoblin Captain',
        role: 'Enemy Leader',
        initiative: 14,
        initiativeBonus: 1,
        hp: 48,
        maxHp: 65,
        ac: 17,
        speed: 30,
        team: _CombatTeam.enemy,
        conditions: ['Marked'],
      ),
      const _Combatant(
        name: 'Goblin Archer',
        role: 'Enemy Skirmisher',
        initiative: 11,
        initiativeBonus: 2,
        hp: 14,
        maxHp: 18,
        ac: 15,
        speed: 30,
        team: _CombatTeam.enemy,
        conditions: [],
      ),
    ];
  }

  _Combatant _combatantFromCharacter(
    Character character,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final maxHp = (character.maxHp ?? 0) <= 0 ? 1 : character.maxHp!;
    final currentHp = (character.currentHp ?? maxHp).clamp(0, maxHp).toInt();
    final dexScore = _effectiveAbilityScore(
      character,
      'DEX',
      equipmentProvider,
      compendiumProvider,
    );
    final initiativeBonus =
        _abilityModifier(dexScore) + character.featInitiativeBonus;
    final race = character.race.trim();
    final effectiveAc = _effectiveArmorClass(
      character,
      equipmentProvider,
      compendiumProvider,
    );

    return _Combatant(
      name: character.name.trim().isEmpty ? 'Hero' : character.name.trim(),
      role: [
        if (race.isNotEmpty) race,
        character.classProgressionLabel,
      ].join(' - '),
      initiative: 10 + initiativeBonus,
      initiativeBonus: initiativeBonus,
      hp: currentHp,
      maxHp: maxHp,
      ac: effectiveAc,
      speed: character.speed ?? 30,
      team: _CombatTeam.party,
      conditions: const ['Player Character'],
    );
  }

  List<_CombatAction> _buildCharacterActions(
    Character character,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
    SpellProvider spellProvider,
  ) {
    final actions = <_CombatAction>[];
    final weapons = _prioritizedCombatWeapons(
      character,
      equipmentProvider,
      compendiumProvider,
    );
    final proficiencyBonus = _proficiencyBonus(character.level);

    for (final resolvedWeapon in weapons.take(3)) {
      final weapon = resolvedWeapon.effectiveItem;
      final abilityLabel = CharacterWeaponAttackService.attackAbilityLabel(
        character: character,
        weaponItem: weapon,
        getAbilityScore: (ability) => _effectiveAbilityScore(
          character,
          ability,
          equipmentProvider,
          compendiumProvider,
        ),
        getAbilityModifier: _abilityModifier,
      );
      final attackBonus = _weaponAttackBonus(
        character,
        resolvedWeapon,
        equipmentProvider,
        compendiumProvider,
        proficiencyBonus,
      );
      final damageBonus = _weaponDamageBonus(
        character,
        resolvedWeapon,
        equipmentProvider,
        compendiumProvider,
      );
      final damageDice = (weapon.damageDice ?? '').trim();
      final damageFormula = damageDice.isEmpty
          ? null
          : _formatRollFormula(damageDice, damageBonus);
      final critFormula = damageDice.isEmpty
          ? null
          : _formatRollFormula(_doubleDiceFormula(damageDice), damageBonus);
      final damageType = weapon.damageType?.trim();

      actions.add(
        _CombatAction(
          name: weapon.name.trim().isEmpty ? 'Weapon Attack' : weapon.name,
          type: weapon.isRanged ? 'Ranged Weapon' : 'Weapon Attack',
          timing: 'Action',
          attackFormula: _formatRollFormula('d20', attackBonus),
          damageFormula: damageFormula,
          critFormula: critFormula,
          tags: [
            abilityLabel,
            if (weapon.isEquipped) 'Equipped',
            if (weapon.isFinesse) 'Finesse',
            if (weapon.isRanged) 'Ranged' else 'Melee',
            if (resolvedWeapon.equipmentItem?.isMagic == true) 'Magic',
            if (weapon.hasInfusion) 'Infused',
            if (damageType != null && damageType.isNotEmpty) damageType,
          ],
          icon:
              weapon.isRanged ? Icons.ads_click_outlined : Icons.gavel_outlined,
          accentKind: weapon.isRanged
              ? _CombatAccentKind.read
              : _CombatAccentKind.action,
        ),
      );
    }

    final spellAttack = _spellAttackAction(
      character,
      equipmentProvider,
      compendiumProvider,
      proficiencyBonus,
    );
    if (spellAttack != null) actions.add(spellAttack);
    actions.addAll(
      _spellActions(
        character,
        spellProvider,
        equipmentProvider,
        compendiumProvider,
        proficiencyBonus,
      ),
    );
    actions.addAll(_featureActions(character));
    actions.addAll(_resourceActions(character));

    actions.add(
      const _CombatAction(
        name: 'Hit Dice Surge',
        type: 'Table Utility',
        timing: 'Bonus Action',
        attackFormula: null,
        damageFormula: '1d10',
        critFormula: null,
        tags: ['Healing', 'Manual', 'Prototype'],
        icon: Icons.favorite_border,
        accentKind: _CombatAccentKind.support,
        targetsSelf: true,
        isHealing: true,
      ),
    );

    return actions.isEmpty ? _playerActions : actions;
  }

  List<ResolvedInventoryItem> _prioritizedCombatWeapons(
    Character character,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final weaponIds = {
      character.equippedMainHandItemId,
      character.equippedOffHandItemId,
      character.pactWeaponItemId,
    }.whereType<String>().where((id) => id.trim().isNotEmpty).toSet();

    final weapons = character.inventory
        .map(
          (item) => CharacterInventoryService.resolveInventoryItem(
            inventoryItem: item,
            equipmentItems: equipmentProvider.items,
            compendiumEntries: compendiumProvider.entries,
          ),
        )
        .where(_isCombatWeapon)
        .toList();
    weapons.sort((a, b) {
      final aEquipped =
          weaponIds.contains(a.originalItem.id) || a.effectiveItem.isEquipped;
      final bEquipped =
          weaponIds.contains(b.originalItem.id) || b.effectiveItem.isEquipped;
      if (aEquipped != bEquipped) return aEquipped ? -1 : 1;
      return a.effectiveItem.name
          .toLowerCase()
          .compareTo(b.effectiveItem.name.toLowerCase());
    });
    return weapons;
  }

  bool _isCombatWeapon(ResolvedInventoryItem item) {
    final effective = item.effectiveItem;
    return effective.itemType == EquipItemType.weapon ||
        item.equipmentItem?.isWeapon == true ||
        effective.allowedSlots.contains(EquipSlot.weaponMainHand) ||
        effective.allowedSlots.contains(EquipSlot.weaponOffHand) ||
        (effective.damageDice ?? '').trim().isNotEmpty;
  }

  int _weaponAttackBonus(
    Character character,
    ResolvedInventoryItem resolvedWeapon,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
    int proficiencyBonus,
  ) {
    if (resolvedWeapon.originalItem.id == character.equippedMainHandItemId) {
      return CharacterWeaponAttackService.mainHandAttackBonus(
        character: character,
        resolvedWeapon: resolvedWeapon,
        getAbilityScore: (ability) => _effectiveAbilityScore(
          character,
          ability,
          equipmentProvider,
          compendiumProvider,
        ),
        getAbilityModifier: _abilityModifier,
        proficiencyBonus: proficiencyBonus,
      );
    }

    final weapon = resolvedWeapon.effectiveItem;
    final abilityMod = CharacterWeaponAttackService.attackAbilityModifier(
      character: character,
      weaponItem: weapon,
      getAbilityScore: (ability) => _effectiveAbilityScore(
        character,
        ability,
        equipmentProvider,
        compendiumProvider,
      ),
      getAbilityModifier: _abilityModifier,
    );
    final proficiency = CharacterWeaponAttackService.isProficientWithWeapon(
      character: character,
      weaponItem: weapon,
      equipmentItem: resolvedWeapon.equipmentItem,
    )
        ? proficiencyBonus
        : 0;
    final itemAttackBonus = resolvedWeapon.equipmentItem?.attackBonus ?? 0;

    return abilityMod + proficiency + itemAttackBonus;
  }

  int _weaponDamageBonus(
    Character character,
    ResolvedInventoryItem resolvedWeapon,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    if (resolvedWeapon.originalItem.id == character.equippedMainHandItemId) {
      return CharacterWeaponAttackService.mainHandDamageBonus(
        character: character,
        resolvedWeapon: resolvedWeapon,
        hasOffHandWeaponEquipped:
            (character.equippedOffHandItemId ?? '').trim().isNotEmpty,
        equipmentItems: equipmentProvider.items,
        compendiumEntries: compendiumProvider.entries,
        getAbilityScore: (ability) => _effectiveAbilityScore(
          character,
          ability,
          equipmentProvider,
          compendiumProvider,
        ),
        getAbilityModifier: _abilityModifier,
      );
    }

    final weapon = resolvedWeapon.effectiveItem;
    final abilityMod = CharacterWeaponAttackService.attackAbilityModifier(
      character: character,
      weaponItem: weapon,
      getAbilityScore: (ability) => _effectiveAbilityScore(
        character,
        ability,
        equipmentProvider,
        compendiumProvider,
      ),
      getAbilityModifier: _abilityModifier,
    );
    final itemDamageBonus = resolvedWeapon.equipmentItem?.damageBonus ?? 0;
    return abilityMod + itemDamageBonus;
  }

  _CombatAction? _spellAttackAction(
    Character character,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
    int proficiencyBonus,
  ) {
    final ability = _spellcastingAbility(character);
    if (ability == null) return null;

    final abilityMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        ability,
        equipmentProvider,
        compendiumProvider,
      ),
    );
    final attackBonus = abilityMod +
        proficiencyBonus +
        _passiveSpellAttackBonus(
          character,
          equipmentProvider,
          compendiumProvider,
        );

    return _CombatAction(
      name: 'Spell Attack',
      type: 'Spellcasting',
      timing: 'Action',
      attackFormula: _formatRollFormula('d20', attackBonus),
      damageFormula: null,
      critFormula: null,
      tags: [ability, 'Prepared', 'Manual Damage'],
      icon: Icons.auto_awesome_outlined,
      accentKind: _CombatAccentKind.magic,
    );
  }

  List<_CombatAction> _spellActions(
    Character character,
    SpellProvider spellProvider,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
    int proficiencyBonus,
  ) {
    final spellIds = <String>{
      ...character.preparedSpellIds,
      ...character.preparedSpells,
      ...character.preparedSpellIdsByClass.values.expand((ids) => ids),
    }..removeWhere((id) => id.trim().isEmpty);

    if (spellIds.isEmpty) {
      spellIds.addAll(character.spellIds.take(8));
    }

    final ability = _spellcastingAbility(character);
    final spellAttackBonus = ability == null
        ? 0
        : _abilityModifier(
              _effectiveAbilityScore(
                character,
                ability,
                equipmentProvider,
                compendiumProvider,
              ),
            ) +
            proficiencyBonus +
            _passiveSpellAttackBonus(
              character,
              equipmentProvider,
              compendiumProvider,
            );

    final actions = <_CombatAction>[];
    for (final spellId in spellIds) {
      final spell = spellProvider.getById(spellId);
      if (spell == null) continue;

      final damageFormula = _firstDiceFormula(spell.description);
      final usesAttackRoll = _spellUsesAttackRoll(spell);
      actions.add(
        _CombatAction(
          name: spell.name,
          type: spell.level == 0 ? 'Cantrip' : 'Level ${spell.level} Spell',
          timing: _timingFromCastingTime(spell.castingTime),
          attackFormula: usesAttackRoll
              ? _formatRollFormula('d20', spellAttackBonus)
              : null,
          damageFormula: damageFormula,
          critFormula: usesAttackRoll && damageFormula != null
              ? _doubleDamageFormula(damageFormula)
              : null,
          tags: [
            spell.school,
            spell.range,
            if (spell.level == 0) 'Cantrip' else 'Slot ${spell.level}',
            if (!usesAttackRoll && _spellMentionsSave(spell)) 'Save',
          ],
          icon: _spellIcon(spell),
          accentKind: _CombatAccentKind.magic,
        ),
      );
    }

    return actions;
  }

  List<_CombatAction> _featureActions(Character character) {
    return character.features.map((feature) {
      final timing = _timingForFeature(feature);
      return _CombatAction(
        name: feature.name.trim().isEmpty ? 'Class Feature' : feature.name,
        type: _featureSourceLabel(feature),
        timing: timing,
        attackFormula: null,
        damageFormula: _firstDiceFormula(feature.description),
        critFormula: null,
        tags: [
          feature.source,
          if (feature.unlockedAtLevel != null)
            'Level ${feature.unlockedAtLevel}',
          if ((feature.linkedResourceId ?? '').trim().isNotEmpty) 'Resource',
        ],
        icon: _featureIcon(feature),
        accentKind: _CombatAccentKind.info,
      );
    }).toList();
  }

  List<_CombatAction> _resourceActions(Character character) {
    return character.resources.map((resource) {
      return _CombatAction(
        name: resource.name.trim().isEmpty ? 'Resource' : resource.name,
        type: 'Resource',
        timing: _timingForResource(resource),
        attackFormula: null,
        damageFormula: _firstDiceFormula(resource.notes ?? ''),
        critFormula: null,
        tags: [
          '${resource.current}/${resource.max}',
          _resourceRechargeLabel(resource),
        ],
        icon: Icons.battery_charging_full_outlined,
        accentKind: resource.current > 0
            ? _CombatAccentKind.support
            : _CombatAccentKind.info,
      );
    }).toList();
  }

  String? _spellcastingAbility(Character character) {
    final direct = character.spellcastingAbility?.trim().toUpperCase();
    if (direct != null && direct.isNotEmpty) return direct;

    for (final value in character.spellcastingAbilitiesByClass.values) {
      final normalized = value.trim().toUpperCase();
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  int _effectiveAbilityScore(
    Character character,
    String ability,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    return CharacterEquipmentEffects.getEffectiveAbilityScore(
      char: character,
      ability: ability,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
    );
  }

  int _effectiveArmorClass(
    Character character,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final dexScore = _effectiveAbilityScore(
      character,
      'DEX',
      equipmentProvider,
      compendiumProvider,
    );
    final dexModifier = _abilityModifier(dexScore);
    final baseAc = CharacterEquipmentEffects.calculateEffectiveArmorClass(
      char: character,
      dexModifier: dexModifier,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
    );

    final resolvedArmor = _resolveInventoryItemById(
      character,
      character.equippedArmorItemId,
      equipmentProvider,
      compendiumProvider,
    );
    final resolvedShield = _resolveInventoryItemById(
      character,
      character.equippedShieldItemId,
      equipmentProvider,
      compendiumProvider,
    );
    final isWearingArmor = resolvedArmor != null &&
        resolvedArmor.effectiveItem.itemType == EquipItemType.armor;
    final optionBonus =
        CharacterOptionEffects.getPassiveArmorClassBonusFromOptions(
      character: character,
      isWearingArmor: isWearingArmor,
    );
    final infusedArmorBonus = CharacterOptionEffects.getInfusedArmorClassBonus(
      character: character,
      armorItem: resolvedArmor?.effectiveItem,
      shieldItem: resolvedShield?.effectiveItem,
    );

    return baseAc + optionBonus + infusedArmorBonus;
  }

  int _passiveSpellAttackBonus(
    Character character,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    final passiveBonus = CharacterEquipmentEffects.getPassiveSpellAttackBonus(
      char: character,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
    );
    final resolvedMainHand = _resolveInventoryItemById(
      character,
      character.equippedMainHandItemId,
      equipmentProvider,
      compendiumProvider,
    );
    final resolvedOffHand = _resolveInventoryItemById(
      character,
      character.equippedOffHandItemId,
      equipmentProvider,
      compendiumProvider,
    );
    final infusedBonus = CharacterOptionEffects.getInfusedSpellAttackBonus(
      character: character,
      mainHandItem: resolvedMainHand?.effectiveItem,
      offHandItem: resolvedOffHand?.effectiveItem,
      mainHandEquipmentItem: resolvedMainHand?.equipmentItem,
      offHandEquipmentItem: resolvedOffHand?.equipmentItem,
    );

    return passiveBonus + infusedBonus;
  }

  ResolvedInventoryItem? _resolveInventoryItemById(
    Character character,
    String? itemId,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) {
    if (itemId == null || itemId.trim().isEmpty) return null;
    for (final item in character.inventory) {
      if (item.id != itemId) continue;
      return CharacterInventoryService.resolveInventoryItem(
        inventoryItem: item,
        equipmentItems: equipmentProvider.items,
        compendiumEntries: compendiumProvider.entries,
      );
    }
    return null;
  }

  int _findDefaultTargetIndex(int activeIndex, [List<_Combatant>? source]) {
    final list = source ?? _combatants;
    if (list.isEmpty) return 0;
    final safeActiveIndex = activeIndex.clamp(0, list.length - 1).toInt();
    final active = list[safeActiveIndex];

    for (var index = 0; index < list.length; index++) {
      final combatant = list[index];
      if (index == safeActiveIndex) continue;
      if (combatant.team != active.team && combatant.hp > 0) {
        return index;
      }
    }

    for (var index = 0; index < list.length; index++) {
      final combatant = list[index];
      if (index == safeActiveIndex) continue;
      if (combatant.hp > 0) return index;
    }

    return safeActiveIndex;
  }

  String _attackOutcome(DiceRollResult result, _Combatant target) {
    if (result.isCriticalHit) return 'critical hit';
    if (result.isCriticalMiss) return 'automatic miss';
    return result.total >= target.ac ? 'hit' : 'miss';
  }
}

class _CombatLayeredGameView extends StatelessWidget {
  final int round;
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final List<_CombatAction> actions;
  final _CombatRollFeedback? rollFeedback;
  final Set<String> spentTimings;
  final String selectedCommandTiming;
  final List<_CombatLogEntry> entries;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<String> onSelectCommandTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;

  const _CombatLayeredGameView({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.rollFeedback,
    required this.spentTimings,
    required this.selectedCommandTiming,
    required this.entries,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onSelectTarget,
    required this.onSelectCommandTiming,
    required this.onRollAction,
    required this.onUseAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideWidth = constraints.maxWidth >= 1240 ? 280.0 : 244.0;
          const gap = 12.0;
          const topHeight = 88.0;
          const bottomHeight = 172.0;
          const verticalGap = 12.0;
          final stageLeft = sideWidth + gap;
          final stageRight = sideWidth + gap;
          final stageTop = topHeight + verticalGap;
          final stageBottom = bottomHeight + verticalGap;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: topHeight,
                child: _GameTopHud(
                  round: round,
                  combatants: combatants,
                  activeIndex: activeIndex,
                  onBack: onBack,
                  onRequestInitiative: onRequestInitiative,
                  onRollInitiative: onRollInitiative,
                  onNextTurn: onNextTurn,
                ),
              ),
              Positioned(
                left: 0,
                top: stageTop,
                width: sideWidth,
                bottom: stageBottom,
                child: _GameCombatantPanel(
                  title: 'Active Character',
                  combatant: activeCombatant,
                  accentKind: _CombatAccentKind.info,
                ),
              ),
              Positioned(
                right: 0,
                top: stageTop,
                width: sideWidth,
                bottom: stageBottom,
                child: _GameCombatantPanel(
                  title: 'Current Target',
                  combatant: selectedTarget,
                  accentKind: _CombatAccentKind.action,
                  isTarget: true,
                ),
              ),
              Positioned(
                left: stageLeft,
                right: stageRight,
                top: stageTop,
                bottom: stageBottom,
                child: _GameBattleStage(
                  combatants: combatants,
                  activeIndex: activeIndex,
                  targetIndex: targetIndex,
                  rollFeedback: rollFeedback,
                  onSelectTarget: onSelectTarget,
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                width: sideWidth,
                height: bottomHeight,
                child: _GameFeedWindow(entries: entries),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                width: sideWidth,
                height: bottomHeight,
                child: _GameTargetWindow(
                  combatants: combatants,
                  activeIndex: activeIndex,
                  targetIndex: targetIndex,
                  onSelectTarget: onSelectTarget,
                ),
              ),
              Positioned(
                left: stageLeft,
                right: stageRight,
                bottom: 0,
                height: bottomHeight,
                child: _CommandLayerDock(
                  actions: actions,
                  spentTimings: spentTimings,
                  selectedTiming: selectedCommandTiming,
                  onSelectTiming: onSelectCommandTiming,
                  onRollAction: onRollAction,
                  onUseAction: onUseAction,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GameTopHud extends StatelessWidget {
  final int round;
  final List<_Combatant> combatants;
  final int activeIndex;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;

  const _GameTopHud({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.surfaceRaised.withValues(alpha: 0.96),
            tokens.panel.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Text(
            'TURN\nORDER',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < combatants.length; index++) ...[
                    if (index > 0) const SizedBox(width: 10),
                    _TurnOrderAvatar(
                      combatant: combatants[index],
                      isActive: index == activeIndex,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _RoundBadge(round: round),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onRequestInitiative,
            icon: const Icon(Icons.campaign_outlined, size: 16),
            label: const Text('Ask Init'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side:
                  BorderSide(color: tokens.accentRead.withValues(alpha: 0.28)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onRollInitiative,
            icon: const Icon(Icons.casino_outlined, size: 16),
            label: const Text('Roll'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side:
                  BorderSide(color: tokens.accentMagic.withValues(alpha: 0.28)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onNextTurn,
            icon: const Icon(Icons.skip_next, size: 16),
            label: const Text('Next'),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accentAction,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnOrderAvatar extends StatelessWidget {
  final _Combatant combatant;
  final bool isActive;

  const _TurnOrderAvatar({
    required this.combatant,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent =
        isActive ? tokens.accentInfo : _teamColor(combatant.team, tokens);

    return SizedBox(
      width: 72,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: isActive ? 0.24 : 0.12),
              border: Border.all(
                color: accent.withValues(alpha: isActive ? 0.90 : 0.36),
                width: isActive ? 2 : 1.2,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.34),
                    blurRadius: 18,
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  combatant.team == _CombatTeam.party
                      ? Icons.shield_outlined
                      : Icons.crisis_alert_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                Positioned(
                  right: 1,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${combatant.initiative}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            combatant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  final int round;

  const _RoundBadge({
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: 72,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.30)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ROUND',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '$round',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCombatantPanel extends StatelessWidget {
  final String title;
  final _Combatant combatant;
  final _CombatAccentKind accentKind;
  final bool isTarget;

  const _GameCombatantPanel({
    required this.title,
    required this.combatant,
    required this.accentKind,
    this.isTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(accentKind, tokens);
    final isDown = combatant.hp <= 0;

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isTarget ? 0.22 : 0.18),
            tokens.panel.withValues(alpha: 0.94),
            tokens.surface.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.40)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.30),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Icon(
                  combatant.team == _CombatTeam.party
                      ? Icons.person_4_outlined
                      : Icons.crisis_alert_outlined,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 86,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            combatant.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            combatant.role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            child: LinearProgressIndicator(
              value: combatant.hpRatio,
              minHeight: 11,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDown
                    ? tokens.textMuted
                    : combatant.hpRatio <= 0.30
                        ? tokens.accentAction
                        : tokens.accentSuccess,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GameMetric(
                    label: 'HP', value: '${combatant.hp}/${combatant.maxHp}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GameMetric(label: 'AC', value: '${combatant.ac}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GameMetric(
                  label: 'INIT',
                  value: '${combatant.initiative}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GameMetric(label: 'SPD', value: '${combatant.speed}'),
              ),
            ],
          ),
          if (combatant.conditions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final condition in combatant.conditions.take(3))
                  _StatusChip(label: condition, color: accent),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GameMetric extends StatelessWidget {
  final String label;
  final String value;

  const _GameMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBattleStage extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _CombatRollFeedback? rollFeedback;
  final ValueChanged<int> onSelectTarget;

  const _GameBattleStage({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.rollFeedback,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: tokens.accentInfo.withValues(alpha: 0.10),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GameBattleStagePainter(tokens: tokens),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const tokenSize = 92.0;
                final positions = _mapPositions();

                return Stack(
                  children: [
                    for (final entry in positions.entries)
                      Positioned(
                        left:
                            entry.value.dx * (constraints.maxWidth - tokenSize),
                        top: entry.value.dy *
                            (constraints.maxHeight - tokenSize),
                        width: tokenSize,
                        height: tokenSize,
                        child: _MapCombatToken(
                          combatant: combatants[entry.key],
                          isActive: entry.key == activeIndex,
                          isTargeted: entry.key == targetIndex,
                          onTap: () => onSelectTarget(entry.key),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (rollFeedback != null)
            Positioned(
              left: 26,
              bottom: 24,
              child: _RollFeedbackWindow(feedback: rollFeedback!),
            ),
        ],
      ),
    );
  }

  Map<int, Offset> _mapPositions() {
    final result = <int, Offset>{};
    final partyIndexes = <int>[];
    final enemyIndexes = <int>[];
    for (var index = 0; index < combatants.length; index++) {
      if (combatants[index].team == _CombatTeam.party) {
        partyIndexes.add(index);
      } else {
        enemyIndexes.add(index);
      }
    }

    for (var i = 0; i < partyIndexes.length; i++) {
      final x = (0.24 + i * 0.10).clamp(0.06, 0.42).toDouble();
      final y = (0.68 - i * 0.18).clamp(0.20, 0.72).toDouble();
      result[partyIndexes[i]] = Offset(x, y);
    }

    for (var i = 0; i < enemyIndexes.length; i++) {
      final x = (0.68 + i * 0.07).clamp(0.58, 0.86).toDouble();
      final y = (0.28 + i * 0.18).clamp(0.16, 0.70).toDouble();
      result[enemyIndexes[i]] = Offset(x, y);
    }

    return result;
  }
}

class _GameBattleStagePainter extends CustomPainter {
  final StitchThemeTokens tokens;

  const _GameBattleStagePainter({
    required this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF273033),
          const Color(0xFF1A2024),
          const Color(0xFF12171C),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.16);
    const cell = 64.0;
    for (var x = -cell; x < size.width + cell; x += cell) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + size.height * 0.72, size.height);
      canvas.drawPath(path, gridPaint);
    }
    for (var x = 0.0; x < size.width + cell; x += cell) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x - size.height * 0.72, size.height);
      canvas.drawPath(path, gridPaint);
    }

    final pathPaint = Paint()
      ..color = tokens.accentSuccess.withValues(alpha: 0.20);
    final path = Path()
      ..moveTo(size.width * 0.42, size.height * 0.66)
      ..lineTo(size.width * 0.58, size.height * 0.54)
      ..lineTo(size.width * 0.82, size.height * 0.70)
      ..lineTo(size.width * 0.62, size.height * 0.84)
      ..close();
    canvas.drawPath(path, pathPaint);

    final dangerPaint = Paint()
      ..color = tokens.accentAction.withValues(alpha: 0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.74, size.height * 0.36),
        width: size.width * 0.34,
        height: size.height * 0.26,
      ),
      dangerPaint,
    );

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          tokens.accentInfo.withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.36, size.height * 0.56),
          radius: size.shortestSide * 0.38,
        ),
      );
    canvas.drawRect(rect, glowPaint);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.42),
        ],
        stops: const [0.50, 1],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant _GameBattleStagePainter oldDelegate) {
    return oldDelegate.tokens != tokens;
  }
}

class _MapCombatToken extends StatelessWidget {
  final _Combatant combatant;
  final bool isActive;
  final bool isTargeted;
  final VoidCallback onTap;

  const _MapCombatToken({
    required this.combatant,
    required this.isActive,
    required this.isTargeted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = isTargeted
        ? tokens.accentAction
        : isActive
            ? tokens.accentInfo
            : _teamColor(combatant.team, tokens);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 11,
            child: Container(
              width: 76,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(999),
                color: accent.withValues(alpha: isTargeted ? 0.38 : 0.22),
                border: Border.all(color: accent.withValues(alpha: 0.70)),
              ),
            ),
          ),
          Positioned(
            top: 4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isActive || isTargeted ? 62 : 56,
              height: isActive || isTargeted ? 62 : 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.surfaceRaised.withValues(alpha: 0.96),
                border: Border.all(
                  color: accent.withValues(
                      alpha: isActive || isTargeted ? 0.95 : 0.48),
                  width: isActive || isTargeted ? 2 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(
                        alpha: isActive || isTargeted ? 0.35 : 0.16),
                    blurRadius: isActive || isTargeted ? 24 : 12,
                  ),
                ],
              ),
              child: Icon(
                combatant.team == _CombatTeam.party
                    ? Icons.person_4_outlined
                    : Icons.crisis_alert_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 86,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: accent.withValues(alpha: 0.38)),
              ),
              child: Text(
                combatant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RollFeedbackWindow extends StatelessWidget {
  final _CombatRollFeedback feedback;

  const _RollFeedbackWindow({
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(feedback.accentKind, tokens);
    final result = feedback.result;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(
            '${feedback.action}-${result?.total}-${feedback.headline}'),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.28),
              tokens.surfaceRaised.withValues(alpha: 0.95),
              tokens.surface.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: accent.withValues(alpha: 0.52)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: result == null
                  ? Icon(
                      Icons.auto_awesome_outlined,
                      color: Colors.white,
                      size: 28,
                    )
                  : Text(
                      '${result.total}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${feedback.actor} - ${feedback.action}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feedback.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (feedback.subline != null &&
                      feedback.subline!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      feedback.subline!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (result != null) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _DiceExpressionChip(
                          label: result.formula,
                          color: accent,
                        ),
                        _DiceExpressionChip(
                          label: result.rollsText,
                          color: tokens.accentRead,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiceExpressionChip extends StatelessWidget {
  final String label;
  final Color color;

  const _DiceExpressionChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CommandLayerDock extends StatelessWidget {
  final List<_CombatAction> actions;
  final Set<String> spentTimings;
  final String selectedTiming;
  final ValueChanged<String> onSelectTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;

  const _CommandLayerDock({
    required this.actions,
    required this.spentTimings,
    required this.selectedTiming,
    required this.onSelectTiming,
    required this.onRollAction,
    required this.onUseAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Movement'];
    final visibleActions =
        actions.where((action) => action.timing == selectedTiming).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.panel.withValues(alpha: 0.96),
            tokens.surface.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: tokens.accentMagic.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 154,
            child: Column(
              children: [
                for (final timing in timings) ...[
                  if (timing != timings.first) const SizedBox(height: 6),
                  _CommandTimingButton(
                    label: timing,
                    selected: timing == selectedTiming,
                    spent: spentTimings.contains(timing),
                    onTap: () => onSelectTiming(timing),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: selectedTiming == 'Movement'
                  ? _MovementLayer(key: const ValueKey('Movement'))
                  : _ActionLayerWindow(
                      key: ValueKey(selectedTiming),
                      timing: selectedTiming,
                      actions: visibleActions,
                      onRollAction: onRollAction,
                      onUseAction: onUseAction,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandTimingButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool spent;
  final VoidCallback onTap;

  const _CommandTimingButton({
    required this.label,
    required this.selected,
    required this.spent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = spent
        ? tokens.accentAction
        : selected
            ? tokens.accentMagic
            : tokens.accentRead;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.24 : 0.11),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.56 : 0.24)),
        ),
        child: Row(
          children: [
            Icon(
              spent
                  ? Icons.check_circle_outline
                  : selected
                      ? Icons.keyboard_arrow_right
                      : Icons.circle_outlined,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionLayerWindow extends StatelessWidget {
  final String timing;
  final List<_CombatAction> actions;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;

  const _ActionLayerWindow({
    super.key,
    required this.timing,
    required this.actions,
    required this.onRollAction,
    required this.onUseAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    if (actions.isEmpty) {
      return _EmptyCommandLayer(timing: timing);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 224,
            child: _CompactActionCommand(
              action: actions[index],
              onRollAction: onRollAction,
              onUseAction: onUseAction,
            ),
          );
        },
      ),
    );
  }
}

class _CompactActionCommand extends StatelessWidget {
  final _CombatAction action;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;

  const _CompactActionCommand({
    required this.action,
    required this.onRollAction,
    required this.onUseAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(action.accentKind, tokens);

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            tokens.surfaceRaised.withValues(alpha: 0.84),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(action.icon, color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  action.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action.type,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              if (action.attackFormula != null)
                Expanded(
                  child: _TinyRollButton(
                    label: action.attackFormula!,
                    icon: Icons.track_changes_outlined,
                    color: accent,
                    onTap: () => onRollAction(action, _CombatActionRoll.attack),
                  ),
                ),
              if (action.attackFormula != null && action.damageFormula != null)
                const SizedBox(width: 5),
              if (action.damageFormula != null)
                Expanded(
                  child: _TinyRollButton(
                    label: action.isHealing ? 'Heal' : action.damageFormula!,
                    icon: action.isHealing
                        ? Icons.favorite_border
                        : Icons.auto_fix_high_outlined,
                    color: accent,
                    onTap: () => onRollAction(action, _CombatActionRoll.damage),
                  ),
                ),
              if (action.critFormula != null) ...[
                const SizedBox(width: 5),
                Expanded(
                  child: _TinyRollButton(
                    label: 'Crit',
                    icon: Icons.emergency_outlined,
                    color: tokens.accentSuccess,
                    onTap: () =>
                        onRollAction(action, _CombatActionRoll.critical),
                  ),
                ),
              ],
              if (action.attackFormula == null &&
                  action.damageFormula == null &&
                  action.critFormula == null)
                Expanded(
                  child: _TinyRollButton(
                    label: 'Use',
                    icon: Icons.check_circle_outline,
                    color: accent,
                    onTap: () => onUseAction(action),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyRollButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TinyRollButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.34)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementLayer extends StatelessWidget {
  const _MovementLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Movement Window',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (final step in ['5 ft', '10 ft', '15 ft', '30 ft']) ...[
            const SizedBox(width: 8),
            Container(
              width: 70,
              height: 70,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.accentSuccess.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: tokens.accentSuccess.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCommandLayer extends StatelessWidget {
  final String timing;

  const _EmptyCommandLayer({
    required this.timing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        '$timing window is empty for this prototype.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: tokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GameFeedWindow extends StatelessWidget {
  final List<_CombatLogEntry> entries;

  const _GameFeedWindow({
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final visible = entries.take(3).toList();

    return _GameSmallWindow(
      title: 'Log',
      icon: Icons.receipt_long_outlined,
      accentKind: _CombatAccentKind.info,
      child: Column(
        children: [
          for (final entry in visible) ...[
            _MiniFeedEntry(entry: entry),
            if (entry != visible.last) const SizedBox(height: 6),
          ],
          if (visible.isEmpty)
            Text(
              'No activity yet.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniFeedEntry extends StatelessWidget {
  final _CombatLogEntry entry;

  const _MiniFeedEntry({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = switch (entry.type) {
      _CombatLogEntryType.roll => tokens.accentMagic,
      _CombatLogEntryType.turn => tokens.accentAction,
      _CombatLogEntryType.system => tokens.accentRead,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(entry.icon, color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
        ),
      ],
    );
  }
}

class _GameTargetWindow extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final ValueChanged<int> onSelectTarget;

  const _GameTargetWindow({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final activeTeam = combatants[activeIndex].team;
    final targets = <_IndexedCombatant>[];
    for (var index = 0; index < combatants.length; index++) {
      if (index == activeIndex) continue;
      targets.add(_IndexedCombatant(index, combatants[index]));
    }

    return _GameSmallWindow(
      title: 'Targets',
      icon: Icons.my_location_outlined,
      accentKind: _CombatAccentKind.action,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final entry in targets)
            _TargetMiniButton(
              combatant: entry.combatant,
              selected: entry.index == targetIndex,
              hostile: entry.combatant.team != activeTeam,
              onTap: () => onSelectTarget(entry.index),
            ),
        ],
      ),
    );
  }
}

class _TargetMiniButton extends StatelessWidget {
  final _Combatant combatant;
  final bool selected;
  final bool hostile;
  final VoidCallback onTap;

  const _TargetMiniButton({
    required this.combatant,
    required this.selected,
    required this.hostile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = hostile ? tokens.accentAction : tokens.accentRead;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.24 : 0.11),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.54 : 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hostile ? Icons.crisis_alert_outlined : Icons.shield_outlined,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                combatant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameSmallWindow extends StatelessWidget {
  final String title;
  final IconData icon;
  final _CombatAccentKind accentKind;
  final Widget child;

  const _GameSmallWindow({
    required this.title,
    required this.icon,
    required this.accentKind,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(accentKind, tokens);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.panel.withValues(alpha: 0.94),
            tokens.surface.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

class _CombatArenaBackdrop extends StatelessWidget {
  final int round;

  const _CombatArenaBackdrop({
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CombatArenaBackdropPainter(
        tokens: context.stitch,
        round: round,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CombatArenaBackdropPainter extends CustomPainter {
  final StitchThemeTokens tokens;
  final int round;

  const _CombatArenaBackdropPainter({
    required this.tokens,
    required this.round,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tokens.pageTop,
          const Color(0xFF111A25),
          tokens.pageBottom,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    _drawGlow(
      canvas,
      rect,
      center: Offset(size.width * 0.18, size.height * 0.18),
      radius: size.shortestSide * 0.62,
      color: tokens.accentRead,
      alpha: 0.16,
    );
    _drawGlow(
      canvas,
      rect,
      center: Offset(size.width * 0.82, size.height * 0.22),
      radius: size.shortestSide * 0.54,
      color: tokens.accentAction,
      alpha: 0.15,
    );
    _drawGlow(
      canvas,
      rect,
      center: Offset(size.width * 0.52, size.height * 0.88),
      radius: size.shortestSide * 0.48,
      color: tokens.accentMagic,
      alpha: 0.10,
    );

    final gridPaint = Paint()
      ..color = tokens.accentRead.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const grid = 54.0;
    for (var x = -grid; x < size.width + grid; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x + 80, size.height), gridPaint);
    }
    for (var y = 28.0; y < size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 20), gridPaint);
    }

    final runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = tokens.accentInfo.withValues(alpha: 0.10);
    final center = Offset(size.width * 0.50, size.height * 0.42);
    final pulse = math.sin(round * 0.7) * 4;
    for (final radius in [96.0, 148.0, 206.0]) {
      canvas.drawCircle(center, radius + pulse, runePaint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 16 + pulse),
        math.pi * 0.12,
        math.pi * 0.38,
        false,
        runePaint..color = tokens.accentAction.withValues(alpha: 0.09),
      );
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.58),
        ],
        stops: const [0.42, 1],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  void _drawGlow(
    Canvas canvas,
    Rect rect, {
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);
  }

  @override
  bool shouldRepaint(covariant _CombatArenaBackdropPainter oldDelegate) {
    return oldDelegate.round != round || oldDelegate.tokens != tokens;
  }
}

class _DuelSpotlightPanel extends StatelessWidget {
  final int round;
  final _Combatant activeCombatant;
  final _Combatant targetCombatant;

  const _DuelSpotlightPanel({
    required this.round,
    required this.activeCombatant,
    required this.targetCombatant,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.surfaceRaised.withValues(alpha: 0.96),
            tokens.panel.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: tokens.accentMagic.withValues(alpha: 0.12),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 740;
          if (!isWide) {
            return Column(
              children: [
                _DuelCombatantPortrait(
                  combatant: activeCombatant,
                  label: 'Active',
                  isTarget: false,
                ),
                const SizedBox(height: 10),
                _DuelRoundCore(round: round, compact: true),
                const SizedBox(height: 10),
                _DuelCombatantPortrait(
                  combatant: targetCombatant,
                  label: 'Target',
                  isTarget: true,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _DuelCombatantPortrait(
                  combatant: activeCombatant,
                  label: 'Active',
                  isTarget: false,
                ),
              ),
              const SizedBox(width: 12),
              _DuelRoundCore(round: round),
              const SizedBox(width: 12),
              Expanded(
                child: _DuelCombatantPortrait(
                  combatant: targetCombatant,
                  label: 'Target',
                  isTarget: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DuelCombatantPortrait extends StatelessWidget {
  final _Combatant combatant;
  final String label;
  final bool isTarget;

  const _DuelCombatantPortrait({
    required this.combatant,
    required this.label,
    required this.isTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent =
        isTarget ? tokens.accentAction : _teamColor(combatant.team, tokens);
    final isDown = combatant.hp <= 0;

    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            tokens.surface.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.42),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
              Icon(
                combatant.team == _CombatTeam.party
                    ? Icons.person_4_outlined
                    : Icons.crisis_alert_outlined,
                color: Colors.white,
                size: 42,
              ),
              Positioned(
                bottom: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  combatant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  combatant.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: combatant.hpRatio,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDown
                          ? tokens.textMuted
                          : combatant.hpRatio <= 0.30
                              ? tokens.accentAction
                              : tokens.accentSuccess,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _StatusChip(
                      label: '${combatant.hp}/${combatant.maxHp} HP',
                      color: isDown ? tokens.textMuted : tokens.accentSuccess,
                    ),
                    _StatusChip(
                      label: 'AC ${combatant.ac}',
                      color: tokens.accentRead,
                    ),
                    _StatusChip(
                      label: 'Init ${combatant.initiative}',
                      color: tokens.accentInfo,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DuelRoundCore extends StatelessWidget {
  final int round;
  final bool compact;

  const _DuelRoundCore({
    required this.round,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: compact ? double.infinity : 116,
      height: compact ? 68 : 138,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.28)),
      ),
      child: compact
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_outlined, color: tokens.accentMagic),
                const SizedBox(width: 8),
                _RoundText(round: round),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bolt_outlined,
                  color: tokens.accentMagic,
                  size: 30,
                ),
                const SizedBox(height: 10),
                _RoundText(round: round),
                const SizedBox(height: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: tokens.accentAction,
                  size: 26,
                ),
              ],
            ),
    );
  }
}

class _RoundText extends StatelessWidget {
  final int round;

  const _RoundText({
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ROUND',
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        Text(
          '$round',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _CombatHeader extends StatelessWidget {
  final int round;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;

  const _CombatHeader({
    required this.round,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.surfaceRaised.withValues(alpha: 0.98),
            tokens.panel.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentAction.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: tokens.accentAction.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -36,
            child: IgnorePointer(
              child: Icon(
                Icons.sports_martial_arts_outlined,
                color: Colors.white.withValues(alpha: 0.045),
                size: 148,
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                tooltip: 'Back',
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.accentAction.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: tokens.accentAction.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.sports_martial_arts_outlined,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                width: 310,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMBAT MODE',
                      style: TextStyle(
                        color: tokens.accentReadSoft.withValues(alpha: 0.90),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Round $round - ${activeCombatant.name} is active',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _CombatHeaderMetric(
                label: 'Initiative',
                value: '${activeCombatant.initiative}',
              ),
              _CombatHeaderMetric(
                label: 'HP',
                value: '${activeCombatant.hp}/${activeCombatant.maxHp}',
              ),
              _CombatHeaderMetric(
                label: 'AC',
                value: '${activeCombatant.ac}',
              ),
              _CombatHeaderMetric(
                label: 'Target',
                value: selectedTarget.name,
                wide: true,
              ),
              OutlinedButton.icon(
                onPressed: onRequestInitiative,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Request Initiative'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: tokens.accentRead.withValues(alpha: 0.30),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRollInitiative,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Roll Demo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: tokens.accentMagic.withValues(alpha: 0.30),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onNextTurn,
                icon: const Icon(Icons.skip_next),
                label: const Text('Next Turn'),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.accentAction,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CombatHeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool wide;

  const _CombatHeaderMetric({
    required this.label,
    required this.value,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      constraints: BoxConstraints(minWidth: wide ? 120 : 74),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InitiativePanel extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;

  const _InitiativePanel({
    required this.combatants,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return _CombatSection(
      title: 'Turn Order',
      icon: Icons.format_list_numbered,
      accentKind: _CombatAccentKind.read,
      child: Column(
        children: [
          for (var index = 0; index < combatants.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _CombatantTile(
              combatant: combatants[index],
              isActive: index == activeIndex,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveTurnPanel extends StatelessWidget {
  final _Combatant combatant;
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final ValueChanged<int> onSelectTarget;
  final Set<String> spentTimings;
  final List<_CombatAction> actions;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;

  const _ActiveTurnPanel({
    required this.combatant,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.onSelectTarget,
    required this.spentTimings,
    required this.actions,
    required this.onRollAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      children: [
        _CombatSection(
          title: 'Active Turn',
          icon: Icons.play_arrow_outlined,
          accentKind: _CombatAccentKind.action,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _teamColor(combatant.team, tokens)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(
                        color: _teamColor(combatant.team, tokens)
                            .withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(
                      combatant.team == _CombatTeam.party
                          ? Icons.person_outline
                          : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          combatant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          combatant.role,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                child: LinearProgressIndicator(
                  value: combatant.hpRatio,
                  minHeight: 9,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    combatant.hpRatio <= 0.30
                        ? tokens.accentAction
                        : tokens.accentSuccess,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: 'HP ${combatant.hp}/${combatant.maxHp}',
                    color: tokens.accentSuccess,
                  ),
                  _StatusChip(
                    label: 'AC ${combatant.ac}',
                    color: tokens.accentRead,
                  ),
                  _StatusChip(
                    label: '${combatant.speed} ft',
                    color: tokens.accentInfo,
                  ),
                  for (final condition in combatant.conditions)
                    _StatusChip(
                      label: condition,
                      color: tokens.accentMagic,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _ActionEconomyStrip(spentTimings: spentTimings),
              const SizedBox(height: 14),
              _TargetSelector(
                combatants: combatants,
                activeIndex: activeIndex,
                targetIndex: targetIndex,
                onSelectTarget: onSelectTarget,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CombatSection(
          title: 'Prepared Actions',
          icon: Icons.style_outlined,
          accentKind: _CombatAccentKind.magic,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? 2 : 1;
              const spacing = 10.0;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: actions.map((action) {
                  return SizedBox(
                    width: width,
                    child: _CombatActionCard(
                      action: action,
                      onRollAction: onRollAction,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BattlefieldPanel extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final ValueChanged<int> onSelectTarget;

  const _BattlefieldPanel({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return _CombatSection(
      title: 'Battlefield',
      icon: Icons.grid_view_outlined,
      accentKind: _CombatAccentKind.info,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.surfaceRaised.withValues(alpha: 0.86),
              tokens.surface.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.14)),
        ),
        child: CustomPaint(
          painter: _BattlefieldTerrainPainter(tokens: tokens),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final party = _indexedCombatants(_CombatTeam.party);
              final enemies = _indexedCombatants(_CombatTeam.enemy);

              if (!isWide) {
                return Column(
                  children: [
                    _BattlefieldLane(
                      title: 'Party',
                      subtitle: 'Allies and player characters',
                      entries: party,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      onSelectTarget: onSelectTarget,
                    ),
                    const SizedBox(height: 12),
                    _BattlefieldLane(
                      title: 'Threats',
                      subtitle: 'Hostile combatants',
                      entries: enemies,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      onSelectTarget: onSelectTarget,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _BattlefieldLane(
                      title: 'Party',
                      subtitle: 'Allies and player characters',
                      entries: party,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      onSelectTarget: onSelectTarget,
                    ),
                  ),
                  const SizedBox(width: 14),
                  _VersusBadge(roundText: '${party.length}v${enemies.length}'),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _BattlefieldLane(
                      title: 'Threats',
                      subtitle: 'Hostile combatants',
                      entries: enemies,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      onSelectTarget: onSelectTarget,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_IndexedCombatant> _indexedCombatants(_CombatTeam team) {
    final entries = <_IndexedCombatant>[];
    for (var index = 0; index < combatants.length; index++) {
      if (combatants[index].team == team) {
        entries.add(_IndexedCombatant(index, combatants[index]));
      }
    }
    return entries;
  }
}

class _BattlefieldTerrainPainter extends CustomPainter {
  final StitchThemeTokens tokens;

  const _BattlefieldTerrainPainter({
    required this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final lanePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tokens.accentInfo.withValues(alpha: 0.07);

    for (var x = 24.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x + 24, size.height), lanePaint);
    }
    for (var y = 24.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lanePaint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = tokens.accentAction.withValues(alpha: 0.12);
    canvas.drawLine(
      Offset(size.width * 0.50, 10),
      Offset(size.width * 0.50, size.height - 10),
      linePaint,
    );

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tokens.accentMagic.withValues(alpha: 0.10);
    canvas.drawCircle(
        center, math.min(size.width, size.height) * 0.22, circlePaint);
    canvas.drawArc(
      Rect.fromCircle(
          center: center, radius: math.min(size.width, size.height) * 0.33),
      math.pi * 1.10,
      math.pi * 0.80,
      false,
      circlePaint,
    );

    final mistPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          tokens.accentRead.withValues(alpha: 0.08),
          Colors.transparent,
          tokens.accentAction.withValues(alpha: 0.08),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, mistPaint);
  }

  @override
  bool shouldRepaint(covariant _BattlefieldTerrainPainter oldDelegate) {
    return oldDelegate.tokens != tokens;
  }
}

class _BattlefieldLane extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_IndexedCombatant> entries;
  final int activeIndex;
  final int targetIndex;
  final ValueChanged<int> onSelectTarget;

  const _BattlefieldLane({
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.activeIndex,
    required this.targetIndex,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _StatusChip(
              label: '${entries.length} combatants',
              color: tokens.accentRead,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: entries.map((entry) {
            return SizedBox(
              width: 236,
              child: _BattlefieldCombatantCard(
                combatant: entry.combatant,
                isActive: entry.index == activeIndex,
                isTargeted: entry.index == targetIndex,
                onTap: () => onSelectTarget(entry.index),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BattlefieldCombatantCard extends StatelessWidget {
  final _Combatant combatant;
  final bool isActive;
  final bool isTargeted;
  final VoidCallback onTap;

  const _BattlefieldCombatantCard({
    required this.combatant,
    required this.isActive,
    required this.isTargeted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final teamColor = _teamColor(combatant.team, tokens);
    final accent = isTargeted
        ? tokens.accentAction
        : isActive
            ? tokens.accentMagic
            : teamColor;
    final isDown = combatant.hp <= 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: isTargeted ? 0.22 : 0.12),
              tokens.surfaceRaised.withValues(alpha: 0.86),
              tokens.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: accent.withValues(alpha: isTargeted ? 0.55 : 0.24),
            width: isTargeted ? 1.4 : 1,
          ),
          boxShadow: [
            if (isActive || isTargeted)
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                  ),
                  child: Icon(
                    combatant.team == _CombatTeam.party
                        ? Icons.shield_outlined
                        : Icons.crisis_alert_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        combatant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        combatant.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              child: LinearProgressIndicator(
                value: combatant.hpRatio,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDown
                      ? tokens.textMuted
                      : combatant.hpRatio <= 0.30
                          ? tokens.accentAction
                          : tokens.accentSuccess,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusChip(
                  label: '${combatant.hp}/${combatant.maxHp} HP',
                  color: isDown ? tokens.textMuted : tokens.accentSuccess,
                ),
                _StatusChip(
                  label: 'AC ${combatant.ac}',
                  color: tokens.accentRead,
                ),
                _StatusChip(
                  label: 'I ${combatant.initiative}',
                  color: tokens.accentInfo,
                ),
                if (isActive)
                  _StatusChip(label: 'Active', color: tokens.accentMagic),
                if (isTargeted)
                  _StatusChip(label: 'Target', color: tokens.accentAction),
                if (isDown) _StatusChip(label: 'Down', color: tokens.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VersusBadge extends StatelessWidget {
  final String roundText;

  const _VersusBadge({
    required this.roundText,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: 66,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentAction.withValues(alpha: 0.24)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'VS',
            style: TextStyle(
              color: tokens.accentAction,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            roundText,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionEconomyStrip extends StatelessWidget {
  final Set<String> spentTimings;

  const _ActionEconomyStrip({
    required this.spentTimings,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    const timings = [
      ('Action', Icons.flash_on_outlined),
      ('Bonus Action', Icons.bolt_outlined),
      ('Reaction', Icons.keyboard_return_outlined),
      ('Movement', Icons.directions_run_outlined),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.18)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final timing in timings)
            _TurnResourceChip(
              label: timing.$1,
              icon: timing.$2,
              isSpent: spentTimings.contains(timing.$1),
            ),
        ],
      ),
    );
  }
}

class _TurnResourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSpent;

  const _TurnResourceChip({
    required this.label,
    required this.icon,
    required this.isSpent,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = isSpent ? tokens.accentAction : tokens.accentSuccess;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isSpent ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            '$label ${isSpent ? 'spent' : 'ready'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetSelector extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final ValueChanged<int> onSelectTarget;

  const _TargetSelector({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final activeTeam = combatants[activeIndex].team;
    final targets = <_IndexedCombatant>[];
    for (var index = 0; index < combatants.length; index++) {
      if (index == activeIndex) continue;
      targets.add(_IndexedCombatant(index, combatants[index]));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentAction.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.my_location_outlined,
                color: tokens.accentAction,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Current Target',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: targets.map((entry) {
              final target = entry.combatant;
              final selected = entry.index == targetIndex;
              final hostile = target.team != activeTeam;
              final color = hostile ? tokens.accentAction : tokens.accentRead;

              return ChoiceChip(
                selected: selected,
                onSelected: (_) => onSelectTarget(entry.index),
                avatar: Icon(
                  hostile ? Icons.crisis_alert_outlined : Icons.shield_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                label: Text(target.name),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                backgroundColor: color.withValues(alpha: 0.12),
                selectedColor: color.withValues(alpha: 0.28),
                side: BorderSide(
                  color: color.withValues(alpha: selected ? 0.55 : 0.22),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  final List<_CombatLogEntry> entries;

  const _ActivityPanel({
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return _CombatSection(
      title: 'Encounter Feed',
      icon: Icons.history,
      accentKind: _CombatAccentKind.info,
      child: Column(
        children:
            entries.map((entry) => _ActivityEntryTile(entry: entry)).toList(),
      ),
    );
  }
}

class _CombatActionCard extends StatelessWidget {
  final _CombatAction action;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;

  const _CombatActionCard({
    required this.action,
    required this.onRollAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(action.accentKind, tokens);

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            tokens.surfaceRaised.withValues(alpha: 0.80),
            tokens.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -13,
            left: -13,
            right: -13,
            child: Container(
              height: 4,
              color: accent.withValues(alpha: 0.78),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.34),
                          accent.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(color: accent.withValues(alpha: 0.32)),
                    ),
                    child: Icon(action.icon, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${action.type} - ${action.timing}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: action.tags
                    .map((tag) => _StatusChip(label: tag, color: accent))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (action.attackFormula != null)
                    Expanded(
                      child: _ActionRollButton(
                        label: action.attackFormula!,
                        icon: Icons.track_changes_outlined,
                        color: accent,
                        onPressed: () =>
                            onRollAction(action, _CombatActionRoll.attack),
                      ),
                    ),
                  if (action.attackFormula != null &&
                      action.damageFormula != null)
                    const SizedBox(width: 8),
                  if (action.damageFormula != null)
                    Expanded(
                      child: _ActionRollButton(
                        label: action.isHealing
                            ? 'Heal ${action.damageFormula}'
                            : action.damageFormula!,
                        icon: action.isHealing
                            ? Icons.favorite_border
                            : Icons.auto_fix_high_outlined,
                        color: accent,
                        onPressed: () =>
                            onRollAction(action, _CombatActionRoll.damage),
                      ),
                    ),
                ],
              ),
              if (action.critFormula != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _ActionRollButton(
                    label: 'Crit ${action.critFormula}',
                    icon: Icons.emergency_outlined,
                    color: tokens.accentSuccess,
                    onPressed: () =>
                        onRollAction(action, _CombatActionRoll.critical),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionRollButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionRollButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        side: BorderSide(color: color.withValues(alpha: 0.34)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CombatantTile extends StatelessWidget {
  final _Combatant combatant;
  final bool isActive;

  const _CombatantTile({
    required this.combatant,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent =
        isActive ? tokens.accentAction : _teamColor(combatant.team, tokens);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: 0.12)
            : tokens.surface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: accent.withValues(alpha: isActive ? 0.42 : 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: Text(
              '${combatant.initiative}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  combatant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  combatant.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Icon(
              Icons.play_arrow_rounded,
              color: tokens.accentAction,
            ),
        ],
      ),
    );
  }
}

class _ActivityEntryTile extends StatelessWidget {
  final _CombatLogEntry entry;

  const _ActivityEntryTile({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = switch (entry.type) {
      _CombatLogEntryType.roll => tokens.accentMagic,
      _CombatLogEntryType.turn => tokens.accentAction,
      _CombatLogEntryType.system => tokens.accentRead,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(entry.icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (entry.detail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CombatSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final _CombatAccentKind accentKind;
  final Widget child;

  const _CombatSection({
    required this.title,
    required this.icon,
    required this.accentKind,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(accentKind, tokens);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.panel.withValues(alpha: 0.94),
            tokens.surface.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: tokens.accentReadSoft.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _CombatTeam { party, enemy }

enum _CombatActionRoll { attack, damage, critical }

enum _CombatAccentKind { read, action, magic, support, info }

enum _CombatLogEntryType { system, turn, roll }

class _Combatant {
  final String name;
  final String role;
  final int initiative;
  final int initiativeBonus;
  final int hp;
  final int maxHp;
  final int ac;
  final int speed;
  final _CombatTeam team;
  final List<String> conditions;

  const _Combatant({
    required this.name,
    required this.role,
    required this.initiative,
    required this.initiativeBonus,
    required this.hp,
    required this.maxHp,
    required this.ac,
    required this.speed,
    required this.team,
    required this.conditions,
  });

  double get hpRatio {
    if (maxHp <= 0) return 0;
    return (hp / maxHp).clamp(0.0, 1.0);
  }

  _Combatant copyWith({
    int? initiative,
    int? hp,
    int? maxHp,
    int? ac,
    int? speed,
    List<String>? conditions,
  }) {
    return _Combatant(
      name: name,
      role: role,
      initiative: initiative ?? this.initiative,
      initiativeBonus: initiativeBonus,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      ac: ac ?? this.ac,
      speed: speed ?? this.speed,
      team: team,
      conditions: conditions ?? this.conditions,
    );
  }
}

class _CombatAction {
  final String name;
  final String type;
  final String timing;
  final String? attackFormula;
  final String? damageFormula;
  final String? critFormula;
  final List<String> tags;
  final IconData icon;
  final _CombatAccentKind accentKind;
  final bool targetsSelf;
  final bool isHealing;

  const _CombatAction({
    required this.name,
    required this.type,
    required this.timing,
    required this.attackFormula,
    required this.damageFormula,
    required this.critFormula,
    required this.tags,
    required this.icon,
    required this.accentKind,
    this.targetsSelf = false,
    this.isHealing = false,
  });
}

class _IndexedCombatant {
  final int index;
  final _Combatant combatant;

  const _IndexedCombatant(this.index, this.combatant);
}

class _CombatRollFeedback {
  final String actor;
  final String action;
  final DiceRollResult? result;
  final String headline;
  final String? subline;
  final _CombatAccentKind accentKind;

  const _CombatRollFeedback({
    required this.actor,
    required this.action,
    required this.result,
    required this.headline,
    required this.subline,
    required this.accentKind,
  });

  const _CombatRollFeedback.manual({
    required this.actor,
    required this.action,
    required this.headline,
    required this.subline,
    required this.accentKind,
  }) : result = null;
}

class _CombatLogEntry {
  final String title;
  final String? detail;
  final IconData icon;
  final _CombatLogEntryType type;

  const _CombatLogEntry({
    required this.title,
    required this.detail,
    required this.icon,
    required this.type,
  });

  factory _CombatLogEntry.system(String title) {
    return _CombatLogEntry(
      title: title,
      detail: null,
      icon: Icons.info_outline,
      type: _CombatLogEntryType.system,
    );
  }

  factory _CombatLogEntry.turn(String title) {
    return _CombatLogEntry(
      title: title,
      detail: null,
      icon: Icons.play_arrow_outlined,
      type: _CombatLogEntryType.turn,
    );
  }

  factory _CombatLogEntry.roll({
    required String actor,
    required String action,
    required DiceRollResult result,
    String? detail,
  }) {
    final prefix = result.isCriticalHit
        ? 'Critical! '
        : result.isCriticalMiss
            ? 'Fumble! '
            : '';

    return _CombatLogEntry(
      title: '$prefix$actor used $action: ${result.total}',
      detail: detail ?? '${result.formula} - ${result.rollsText}',
      icon: result.isCriticalHit
          ? Icons.emergency_outlined
          : Icons.casino_outlined,
      type: _CombatLogEntryType.roll,
    );
  }
}

Color _teamColor(_CombatTeam team, StitchThemeTokens tokens) {
  return team == _CombatTeam.party ? tokens.accentRead : tokens.accentAction;
}

Color _accentForKind(_CombatAccentKind kind, StitchThemeTokens tokens) {
  return switch (kind) {
    _CombatAccentKind.read => tokens.accentRead,
    _CombatAccentKind.action => tokens.accentAction,
    _CombatAccentKind.magic => tokens.accentMagic,
    _CombatAccentKind.support => tokens.accentSuccess,
    _CombatAccentKind.info => tokens.accentInfo,
  };
}

int _abilityModifier(int score) => ((score - 10) / 2).floor();

int _proficiencyBonus(int level) {
  final safeLevel = level < 1 ? 1 : level;
  return 2 + ((safeLevel - 1) ~/ 4);
}

String _formatRollFormula(String dice, int modifier) {
  if (modifier == 0) return dice;
  return modifier > 0 ? '$dice+$modifier' : '$dice$modifier';
}

String? _firstDiceFormula(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
  final match = RegExp(
    r'(\d+d\d+(?:\s*[+-]\s*\d+)?)',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (match == null) return null;
  return match.group(1)?.replaceAll(' ', '').toLowerCase();
}

String? _doubleDamageFormula(String formula) {
  final match = RegExp(
    r'^(\d*)d(\d+)([+-]\d+)?$',
    caseSensitive: false,
  ).firstMatch(formula.trim());
  if (match == null) return null;

  final rawCount = match.group(1);
  final count =
      rawCount == null || rawCount.isEmpty ? 1 : int.tryParse(rawCount) ?? 1;
  final sides = match.group(2);
  final modifier = match.group(3) ?? '';
  if (sides == null || sides.isEmpty) return null;
  return '${count * 2}d$sides$modifier';
}

bool _spellUsesAttackRoll(Spell spell) {
  final text = '${spell.description} ${spell.range}'.toLowerCase();
  return text.contains('spell attack') || text.contains('ranged attack');
}

bool _spellMentionsSave(Spell spell) {
  final text = spell.description.toLowerCase();
  return text.contains('saving throw') || text.contains('save');
}

String _timingFromCastingTime(String castingTime) {
  final text = castingTime.toLowerCase();
  if (text.contains('bonus')) return 'Bonus Action';
  if (text.contains('reaction')) return 'Reaction';
  return 'Action';
}

IconData _spellIcon(Spell spell) {
  final school = spell.school.toLowerCase();
  if (school.contains('evocation')) return Icons.local_fire_department_outlined;
  if (school.contains('abjuration')) return Icons.shield_outlined;
  if (school.contains('conjuration')) return Icons.auto_awesome_outlined;
  if (school.contains('necromancy')) return Icons.nights_stay_outlined;
  if (school.contains('illusion')) return Icons.visibility_outlined;
  if (school.contains('enchantment')) return Icons.psychology_alt_outlined;
  return Icons.auto_awesome_outlined;
}

String _timingForFeature(CharacterFeature feature) {
  final text = '${feature.name} ${feature.description}'.toLowerCase();
  if (text.contains('reaction')) return 'Reaction';
  if (text.contains('bonus action') ||
      text.contains('rage') ||
      text.contains('second wind') ||
      text.contains('bardic inspiration')) {
    return 'Bonus Action';
  }
  return 'Action';
}

String _featureSourceLabel(CharacterFeature feature) {
  final source = feature.source.trim();
  if (source.isEmpty) return 'Feature';
  return '${source[0].toUpperCase()}${source.substring(1)} Feature';
}

IconData _featureIcon(CharacterFeature feature) {
  final text = '${feature.name} ${feature.description}'.toLowerCase();
  if (text.contains('heal') || text.contains('lay on hands')) {
    return Icons.favorite_border;
  }
  if (text.contains('shield') || text.contains('defense')) {
    return Icons.shield_outlined;
  }
  if (text.contains('rage') || text.contains('smite')) {
    return Icons.flash_on_outlined;
  }
  return Icons.stars_outlined;
}

String _timingForResource(CharacterResource resource) {
  final text = '${resource.name} ${resource.notes ?? ''}'.toLowerCase();
  if (text.contains('reaction')) return 'Reaction';
  if (text.contains('bonus')) return 'Bonus Action';
  return 'Action';
}

String _resourceRechargeLabel(CharacterResource resource) {
  return switch (resource.rechargeType) {
    'shortRest' => 'Short Rest',
    'longRest' => 'Long Rest',
    _ => 'Manual',
  };
}

String _doubleDiceFormula(String dice) {
  final match =
      RegExp(r'^(\d*)d(\d+)$', caseSensitive: false).firstMatch(dice.trim());
  if (match == null) return dice;

  final rawCount = match.group(1);
  final count =
      rawCount == null || rawCount.isEmpty ? 1 : int.tryParse(rawCount) ?? 1;
  final sides = match.group(2);
  if (sides == null || sides.isEmpty) return dice;
  return '${count * 2}d$sides';
}
