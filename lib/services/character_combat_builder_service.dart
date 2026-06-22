import 'dart:math' as math;

import '../features/characters/models/resolved_inventory_item.dart';
import '../logic/character_option_effects.dart';
import '../models/character.dart';
import '../models/character_feature.dart';
import '../models/character_inventory_item.dart';
import '../models/character_resource.dart';
import '../models/combat_encounter.dart';
import '../models/compendium_entry.dart';
import '../models/equipment_compendium_item.dart';
import '../models/spell.dart';
import '../utils/character_equipment_effects.dart';
import 'character_inventory_service.dart';
import 'character_resource_factory.dart';
import 'character_spell_slot_service.dart';
import 'character_weapon_attack_service.dart';

class CharacterCombatBuild {
  final Combatant combatant;
  final List<PreparedCombatAction> availableActions;

  const CharacterCombatBuild({
    required this.combatant,
    required this.availableActions,
  });
}

class _IntrinsicAttackSpec {
  final String idSuffix;
  final String name;
  final String abilityLabel;
  final int abilityModifier;
  final String? damageDice;
  final int? flatDamage;
  final String damageType;
  final String source;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  const _IntrinsicAttackSpec({
    required this.idSuffix,
    required this.name,
    required this.abilityLabel,
    required this.abilityModifier,
    required this.damageType,
    required this.source,
    this.damageDice,
    this.flatDamage,
    this.tags = const [],
    this.metadata = const {},
  });
}

class _NaturalWeaponPattern {
  final String id;
  final String name;
  final List<String> keywords;
  final String defaultDice;
  final String damageType;

  const _NaturalWeaponPattern({
    required this.id,
    required this.name,
    required this.keywords,
    required this.defaultDice,
    required this.damageType,
  });
}

class _WeaponRangeSpec {
  final int normalFeet;
  final int? longFeet;

  const _WeaponRangeSpec(this.normalFeet, this.longFeet);
}

class CharacterCombatBuilderService {
  const CharacterCombatBuilderService._();

  static CharacterCombatBuild build({
    required Character character,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
    required List<Spell> spells,
  }) {
    final maxHp = (character.maxHp ?? 0) <= 0 ? 1 : character.maxHp!;
    final currentHp = (character.currentHp ?? maxHp).clamp(0, maxHp).toInt();
    final rawTempHp = character.tempHp ?? 0;
    final tempHp = rawTempHp < 0 ? 0 : rawTempHp;
    final dexScore = _effectiveAbilityScore(
      character,
      'DEX',
      equipmentItems,
      compendiumEntries,
    );
    final initiativeBonus =
        _abilityModifier(dexScore) + character.featInitiativeBonus;
    final name = character.name.trim().isEmpty ? 'Hero' : character.name.trim();
    final role = [
      if (character.race.trim().isNotEmpty) character.race.trim(),
      character.classProgressionLabel,
    ].where((item) => item.trim().isNotEmpty).join(' - ');
    final proficiencyBonus = _proficiencyBonus(character.level);

    final availableActions = _buildAvailableActions(
      character,
      equipmentItems,
      compendiumEntries,
      spells,
    );

    return CharacterCombatBuild(
      combatant: Combatant(
        id: _combatantIdForCharacter(character),
        name: name,
        sourceId: character.id,
        kind: CombatantKind.playerCharacter,
        team: CombatantTeam.party,
        role: role,
        initiative: 10 + initiativeBonus,
        initiativeBonus: initiativeBonus,
        hp: currentHp,
        maxHp: maxHp,
        tempHp: tempHp,
        armorClass: _effectiveArmorClass(
          character,
          equipmentItems,
          compendiumEntries,
        ),
        speed: (character.speed ?? 30) + character.featSpeedBonus,
        resources: _resourceMap(character),
        effects: _passiveEffects(character),
        metadata: {
          'characterId': character.id,
          if ((character.ownerUserId ?? '').trim().isNotEmpty)
            'ownerUserId': character.ownerUserId!.trim(),
          if ((character.portraitPath ?? '').trim().isNotEmpty)
            'portraitPath': character.portraitPath!.trim(),
          'race': character.race,
          'classProgression': character.classProgressionLabel,
          'subclasses': {
            for (final entry in character.classLevels.entries)
              if ((character.subclassForClass(entry.key) ?? '')
                  .trim()
                  .isNotEmpty)
                entry.key: character.subclassForClass(entry.key)!.trim(),
          },
          if ((_subclassForCombatClass(character, 'monk') ?? '')
              .trim()
              .isNotEmpty)
            'monkSubclass': _subclassForCombatClass(character, 'monk')!.trim(),
          'features': [
            for (final feature in character.features)
              {
                'id': feature.id,
                'name': feature.name,
                'description': feature.description,
                'source': feature.source,
                if (feature.unlockedAtLevel != null)
                  'level': feature.unlockedAtLevel,
                if ((feature.linkedResourceId ?? '').trim().isNotEmpty)
                  'linkedResourceId': feature.linkedResourceId!.trim(),
              },
          ],
          'abilityScores': {
            for (final ability in ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'])
              ability: _effectiveAbilityScore(
                character,
                ability,
                equipmentItems,
                compendiumEntries,
              ),
          },
          'savingThrowBonuses': {
            for (final ability in ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'])
              ability: _savingThrowBonus(
                character,
                ability,
                equipmentItems,
                compendiumEntries,
                proficiencyBonus,
              ),
          },
          'classLevels': Map<String, int>.from(character.classLevels),
          'proficiencyBonus': proficiencyBonus,
          'resourceMaximums': _resourceMaxMap(character),
          'availableActionCount': availableActions.length,
        },
      ),
      availableActions: availableActions,
    );
  }

  static List<PreparedCombatAction> _buildAvailableActions(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    List<Spell> spells,
  ) {
    final actions = <PreparedCombatAction>[];
    final proficiencyBonus = _proficiencyBonus(character.level);
    final weapons = _prioritizedCombatWeapons(
      character,
      equipmentItems,
      compendiumEntries,
    );
    final attackActionCount = _extraAttackCount(character);
    final criticalThreshold = _weaponCriticalThreshold(character);

    for (final resolvedWeapon in weapons.take(6)) {
      final weapon = resolvedWeapon.effectiveItem;
      final abilityLabel = CharacterWeaponAttackService.attackAbilityLabel(
        character: character,
        weaponItem: weapon,
        getAbilityScore: (ability) => _effectiveAbilityScore(
          character,
          ability,
          equipmentItems,
          compendiumEntries,
        ),
        getAbilityModifier: _abilityModifier,
      );
      final attackBonus = _weaponAttackBonus(
        character,
        resolvedWeapon,
        equipmentItems,
        compendiumEntries,
        proficiencyBonus,
      );
      final damageBonus = _weaponDamageBonus(
        character,
        resolvedWeapon,
        equipmentItems,
        compendiumEntries,
      );
      final damageDice = (weapon.damageDice ?? '').trim();
      final damageFormula = damageDice.isEmpty
          ? null
          : _formatRollFormula(damageDice, damageBonus);
      final damageType = weapon.damageType?.trim();
      final weaponRange =
          _weaponRangeSpec(weapon, resolvedWeapon.equipmentItem);

      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'weapon', weapon.id),
          name: weapon.name.trim().isEmpty ? 'Weapon Attack' : weapon.name,
          timing: CombatActionTiming.action,
          rollKind: CombatActionRollKind.attack,
          attackFormula: _formatRollFormula('d20', attackBonus),
          damageFormula: damageFormula,
          tags: [
            abilityLabel,
            if (weapon.isEquipped) 'Equipped',
            if (weapon.isFinesse) 'Finesse',
            if (weapon.isRanged) 'Ranged' else 'Melee',
            if (attackActionCount > 1) 'Extra Attack',
            if (attackActionCount > 1) '$attackActionCount Action attacks',
            if (criticalThreshold < 20) 'Crit $criticalThreshold-20',
            if (resolvedWeapon.equipmentItem?.isMagic == true) 'Magic',
            if (weapon.hasInfusion) 'Infused',
            if (damageType != null && damageType.isNotEmpty) damageType,
          ],
          metadata: {
            'source': 'weapon',
            'inventoryItemId': weapon.id,
            'weaponType': weapon.isRanged ? 'ranged' : 'melee',
            'damageType': damageType,
            if (weaponRange != null) 'rangeFeet': weaponRange.normalFeet,
            if (weaponRange?.longFeet != null)
              'longRangeFeet': weaponRange!.longFeet,
            'usesAttackAction': true,
            'attackSlotCount': attackActionCount,
            if (criticalThreshold < 20) 'criticalThreshold': criticalThreshold,
            'criticalDamageFormula': damageDice.isEmpty
                ? null
                : _formatRollFormula(
                    _doubleDiceFormula(damageDice),
                    damageBonus,
                  ),
          },
        ),
      );
    }

    actions.addAll(
      _intrinsicAttackActions(
        character,
        equipmentItems,
        compendiumEntries,
        proficiencyBonus,
        attackActionCount,
      ),
    );
    actions.addAll(_coreTurnActions(character));
    actions.addAll(
      _classCombatActions(
        character,
        equipmentItems,
        compendiumEntries,
        proficiencyBonus,
      ),
    );
    actions.addAll(
      _monkTechniqueActions(
        character,
        equipmentItems,
        compendiumEntries,
        proficiencyBonus,
      ),
    );

    final spellActions = _spellActions(
      character,
      spells,
      equipmentItems,
      compendiumEntries,
      proficiencyBonus,
    );
    actions.addAll(spellActions);

    final spellAttack = _spellAttackAction(
      character,
      equipmentItems,
      compendiumEntries,
      proficiencyBonus,
    );
    if (spellAttack != null && spellActions.isEmpty) actions.add(spellAttack);
    actions.addAll(_featureActions(character));
    actions.addAll(_resourceActions(character));

    return _dedupeCombatActions(actions);
  }

  static List<ResolvedInventoryItem> _prioritizedCombatWeapons(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
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
            equipmentItems: equipmentItems,
            compendiumEntries: compendiumEntries,
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

  static bool _isCombatWeapon(ResolvedInventoryItem item) {
    final effective = item.effectiveItem;
    return effective.itemType == EquipItemType.weapon ||
        item.equipmentItem?.isWeapon == true ||
        effective.allowedSlots.contains(EquipSlot.weaponMainHand) ||
        effective.allowedSlots.contains(EquipSlot.weaponOffHand) ||
        (effective.damageDice ?? '').trim().isNotEmpty;
  }

  static List<PreparedCombatAction> _intrinsicAttackActions(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
    int attackActionCount,
  ) {
    final strMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'STR',
        equipmentItems,
        compendiumEntries,
      ),
    );
    final dexMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'DEX',
        equipmentItems,
        compendiumEntries,
      ),
    );
    final monkLevel = _effectiveMonkLevel(character);
    final bestMartialMod = dexMod > strMod ? dexMod : strMod;
    final bestMartialAbility = dexMod > strMod ? 'DEX' : 'STR';
    final baseUnarmedDamage = 1 + strMod;
    final specs = <_IntrinsicAttackSpec>[
      _IntrinsicAttackSpec(
        idSuffix: 'unarmed_strike',
        name: 'Unarmed Strike',
        abilityLabel: monkLevel > 0 ? bestMartialAbility : 'STR',
        abilityModifier: monkLevel > 0 ? bestMartialMod : strMod,
        damageDice: monkLevel > 0 ? _martialArtsDie(monkLevel) : null,
        flatDamage: monkLevel > 0
            ? null
            : baseUnarmedDamage < 1
                ? 1
                : baseUnarmedDamage,
        damageType: 'Bludgeoning',
        source: 'unarmed',
        tags: [
          'Unarmed',
          if (monkLevel > 0) 'Martial Arts',
        ],
        metadata: {
          if (monkLevel > 0) 'monkLevel': monkLevel,
        },
      ),
      ..._naturalWeaponSpecs(
        character,
        equipmentItems,
        compendiumEntries,
      ),
    ];

    final actions = <PreparedCombatAction>[];
    for (final spec in specs) {
      final action = _intrinsicAttackAction(
        character,
        spec,
        proficiencyBonus,
        attackActionCount,
      );
      actions.add(action);
    }

    return actions;
  }

  static PreparedCombatAction _intrinsicAttackAction(
    Character character,
    _IntrinsicAttackSpec spec,
    int proficiencyBonus,
    int attackActionCount,
  ) {
    final attackBonus = spec.abilityModifier + proficiencyBonus;
    final damageFormula = _intrinsicDamageFormula(spec);
    final criticalDamageFormula = _intrinsicCriticalDamageFormula(spec);
    final criticalThreshold = _weaponCriticalThreshold(character);

    return PreparedCombatAction(
      id: _actionId(character, spec.source, spec.idSuffix),
      name: spec.name,
      timing: CombatActionTiming.action,
      rollKind: CombatActionRollKind.attack,
      attackFormula: _formatRollFormula('d20', attackBonus),
      damageFormula: damageFormula,
      tags: [
        spec.abilityLabel,
        ...spec.tags,
        'Melee',
        spec.damageType,
        if (attackActionCount > 1) 'Extra Attack',
        if (attackActionCount > 1) '$attackActionCount Action attacks',
        if (criticalThreshold < 20) 'Crit $criticalThreshold-20',
      ],
      metadata: {
        'source': spec.source,
        'weaponType': 'melee',
        'damageType': spec.damageType,
        'intrinsicAttack': true,
        'usesAttackAction': true,
        'attackSlotCount': attackActionCount,
        if (criticalThreshold < 20) 'criticalThreshold': criticalThreshold,
        ...spec.metadata,
        if (criticalDamageFormula != null)
          'criticalDamageFormula': criticalDamageFormula,
      },
    );
  }

  static List<_IntrinsicAttackSpec> _naturalWeaponSpecs(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    final strMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'STR',
        equipmentItems,
        compendiumEntries,
      ),
    );
    final specs = <_IntrinsicAttackSpec>[];
    final seen = <String>{};
    for (final feature in character.features) {
      final searchText = _normalizedSearchText(
        '${feature.name} ${feature.description}',
      );
      for (final pattern in _naturalWeaponPatterns) {
        if (!pattern.keywords.any(searchText.contains)) continue;

        final dice = _naturalWeaponDice(searchText, pattern);
        final key = '${pattern.id}|$dice|${pattern.damageType}';
        if (!seen.add(key)) continue;

        specs.add(
          _IntrinsicAttackSpec(
            idSuffix: '${feature.id}_${pattern.id}',
            name: pattern.name,
            abilityLabel: 'STR',
            abilityModifier: strMod,
            damageDice: dice,
            damageType: pattern.damageType,
            source: 'naturalWeapon',
            tags: [
              'Natural Weapon',
              _featureSourceLabel(feature),
            ],
            metadata: {
              'featureId': feature.id,
              'featureSource': feature.source,
            },
          ),
        );
      }
    }
    return specs;
  }

  static const List<_NaturalWeaponPattern> _naturalWeaponPatterns = [
    _NaturalWeaponPattern(
      id: 'claws',
      name: 'Claws',
      keywords: ['claw', 'claws', 'garra', 'garras'],
      defaultDice: '1d4',
      damageType: 'Slashing',
    ),
    _NaturalWeaponPattern(
      id: 'bite',
      name: 'Bite',
      keywords: ['bite', 'fang', 'fangs', 'mordida', 'colmillo', 'colmillos'],
      defaultDice: '1d6',
      damageType: 'Piercing',
    ),
    _NaturalWeaponPattern(
      id: 'horns',
      name: 'Horns',
      keywords: ['horn', 'horns', 'cuerno', 'cuernos'],
      defaultDice: '1d6',
      damageType: 'Piercing',
    ),
    _NaturalWeaponPattern(
      id: 'talons',
      name: 'Talons',
      keywords: ['talon', 'talons'],
      defaultDice: '1d4',
      damageType: 'Slashing',
    ),
    _NaturalWeaponPattern(
      id: 'hooves',
      name: 'Hooves',
      keywords: ['hoof', 'hooves', 'pezuna', 'pezunas'],
      defaultDice: '1d4',
      damageType: 'Bludgeoning',
    ),
    _NaturalWeaponPattern(
      id: 'tail',
      name: 'Tail',
      keywords: ['tail', 'cola'],
      defaultDice: '1d8',
      damageType: 'Piercing',
    ),
  ];

  static String _naturalWeaponDice(
    String searchText,
    _NaturalWeaponPattern pattern,
  ) {
    for (final keyword in pattern.keywords) {
      final index = searchText.indexOf(keyword);
      if (index < 0) continue;
      final start = index - 120 < 0 ? 0 : index - 120;
      final end =
          index + 220 > searchText.length ? searchText.length : index + 220;
      final nearby = searchText.substring(start, end);
      final formula = _firstDiceFormula(nearby);
      if (formula != null) return _diceOnlyFormula(formula);
    }
    return pattern.defaultDice;
  }

  static String _intrinsicDamageFormula(_IntrinsicAttackSpec spec) {
    if (spec.damageDice != null) {
      return _formatRollFormula(spec.damageDice!, spec.abilityModifier);
    }
    return '${spec.flatDamage ?? 1}';
  }

  static String? _intrinsicCriticalDamageFormula(_IntrinsicAttackSpec spec) {
    if (spec.damageDice == null) return _intrinsicDamageFormula(spec);
    return _formatRollFormula(
      _doubleDiceFormula(spec.damageDice!),
      spec.abilityModifier,
    );
  }

  static List<PreparedCombatAction> _coreTurnActions(Character character) {
    return [
      PreparedCombatAction(
        id: _actionId(character, 'combat_rule', 'dash'),
        name: 'Dash',
        timing: CombatActionTiming.action,
        rollKind: CombatActionRollKind.none,
        tags: const ['Core Action', 'Dash', 'Movement'],
        metadata: const {
          'source': 'combatRule',
          'targetsSelf': true,
          'combatEffect': 'dash',
          'grantsMovement': true,
        },
      ),
      PreparedCombatAction(
        id: _actionId(character, 'combat_rule', 'disengage'),
        name: 'Disengage',
        timing: CombatActionTiming.action,
        rollKind: CombatActionRollKind.none,
        tags: const ['Core Action', 'Disengage', 'Movement'],
        metadata: const {
          'source': 'combatRule',
          'targetsSelf': true,
          'combatEffect': 'disengage',
        },
      ),
      PreparedCombatAction(
        id: _actionId(character, 'combat_rule', 'dodge'),
        name: 'Dodge',
        timing: CombatActionTiming.action,
        rollKind: CombatActionRollKind.none,
        tags: const ['Core Action', 'Dodge', 'Defense'],
        metadata: const {
          'source': 'combatRule',
          'targetsSelf': true,
          'combatEffect': 'dodge',
        },
      ),
    ];
  }

  static List<PreparedCombatAction> _classCombatActions(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    return [
      ..._barbarianActions(character),
      ..._fighterActions(
        character,
        equipmentItems,
        compendiumEntries,
        proficiencyBonus,
      ),
      ..._rogueActions(character),
      ..._paladinActions(character),
      ..._bardActions(character),
      ..._clericActions(
        character,
        equipmentItems,
        compendiumEntries,
        proficiencyBonus,
      ),
      ..._druidActions(character),
      ..._artificerActions(character),
    ];
  }

  static List<PreparedCombatAction> _barbarianActions(Character character) {
    final barbarianLevel =
        _classLevel(character, const ['barbarian', 'barbaro', 'bárbaro']);
    if (barbarianLevel <= 0) return const [];

    final rageBonus = _rageDamageBonus(barbarianLevel);
    return [
      PreparedCombatAction(
        id: _actionId(character, 'class_action', 'rage'),
        name: 'Rage',
        timing: CombatActionTiming.bonusAction,
        rollKind: CombatActionRollKind.none,
        resourceKey:
            _resourceIdMatching(character, const ['rage', 'furia', 'rabia']) ??
                'rage',
        resourceCost: 1,
        tags: [
          'Barbarian',
          'Bonus Action',
          'Rage',
          '+$rageBonus melee STR damage',
          'STR save advantage',
          'Resist B/P/S',
        ],
        metadata: {
          'source': 'classMechanic',
          'class': 'barbarian',
          'targetsSelf': true,
          'combatEffect': 'rage',
          'rageDamageBonus': rageBonus,
          'resistances': const ['bludgeoning', 'piercing', 'slashing'],
        },
      ),
    ];
  }

  static int _rageDamageBonus(int barbarianLevel) {
    if (barbarianLevel >= 16) return 4;
    if (barbarianLevel >= 9) return 3;
    return 2;
  }

  static List<PreparedCombatAction> _fighterActions(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final fighterLevel = _classLevel(character, const ['fighter', 'guerrero']);
    final secondWindResource = _resourceIdMatching(
        character, const ['second wind', 'segundo aliento']);
    final actionSurgeResource = _resourceIdMatching(character,
        const ['action surge', 'action sourge', 'oleada de accion', 'oleada']);
    final hasSecondWindFeature = _hasFeatureMatching(
      character,
      (feature) => _isSecondWindText('${feature.name} ${feature.description}'),
    );
    final hasActionSurgeFeature = _hasFeatureMatching(
      character,
      (feature) => _isActionSurgeText('${feature.name} ${feature.description}'),
    );
    final hasFighterMechanic = fighterLevel > 0 ||
        secondWindResource != null ||
        actionSurgeResource != null ||
        hasSecondWindFeature ||
        hasActionSurgeFeature ||
        _hasFeatureMatching(character, _isBattleMasterFeature);
    if (!hasFighterMechanic) return const [];

    final effectiveFighterLevel = fighterLevel > 0
        ? fighterLevel
        : character.level > 0
            ? character.level
            : 1;
    final superiorityDie = _superiorityDie(character, effectiveFighterLevel);
    final actions = <PreparedCombatAction>[];

    if (fighterLevel >= 1 ||
        secondWindResource != null ||
        hasSecondWindFeature) {
      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'class_action', 'second_wind'),
          name: 'Second Wind',
          timing: CombatActionTiming.bonusAction,
          rollKind: CombatActionRollKind.healing,
          healingFormula: _formatRollFormula('1d10', effectiveFighterLevel),
          resourceKey: secondWindResource ?? 'second_wind',
          resourceCost: secondWindResource == null && fighterLevel < 1 ? 0 : 1,
          tags: const ['Fighter', 'Bonus Action', 'Self Healing'],
          metadata: const {
            'source': 'classMechanic',
            'class': 'fighter',
            'targetsSelf': true,
          },
        ),
      );
    }

    if (fighterLevel >= 2 ||
        actionSurgeResource != null ||
        hasActionSurgeFeature) {
      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'class_action', 'action_surge'),
          name: 'Action Surge',
          timing: CombatActionTiming.free,
          rollKind: CombatActionRollKind.none,
          resourceKey: actionSurgeResource ?? 'action_surge',
          resourceCost: actionSurgeResource == null && fighterLevel < 2 ? 0 : 1,
          tags: const ['Fighter', 'Free', 'Extra Action'],
          metadata: const {
            'source': 'classMechanic',
            'class': 'fighter',
            'targetsSelf': true,
            'combatEffect': 'actionSurge',
            'grantsAction': true,
          },
        ),
      );
    }

    if (superiorityDie != null) {
      actions.addAll(
        _battleMasterManeuverActions(
          character,
          equipmentItems,
          compendiumEntries,
          proficiencyBonus,
          superiorityDie,
        ),
      );
    }

    return actions;
  }

  static String? _superiorityDie(Character character, int fighterLevel) {
    final subclass = _normalizedSearchText(
      character.subclassForClass('fighter') ?? '',
    );
    final hasBattleMaster = subclass.contains('battle master') ||
        subclass.contains('battlemeister') ||
        subclass.contains('maestro de batalla') ||
        _hasFeatureMatching(character, _isBattleMasterFeature);
    if (!hasBattleMaster || fighterLevel < 3) return null;
    if (fighterLevel >= 18) return '1d12';
    if (fighterLevel >= 10) return '1d10';
    return '1d8';
  }

  static List<PreparedCombatAction> _battleMasterManeuverActions(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
    String superiorityDie,
  ) {
    final selectedManeuvers =
        CharacterOptionEffects.getSelectedManeuvers(character);
    if (selectedManeuvers.isEmpty) {
      return [
        PreparedCombatAction(
          id: _actionId(character, 'subclass_action', 'battle_master_maneuver'),
          name: 'Battle Master Maneuver',
          timing: CombatActionTiming.free,
          rollKind: CombatActionRollKind.damage,
          damageFormula: superiorityDie,
          resourceKey: _resourceIdMatching(character, const [
                'superiority',
                'superioridad',
                'dado de superioridad',
                'dados de superioridad',
              ]) ??
              'superiority_dice',
          resourceCost: 1,
          tags: [
            'Battle Master',
            'On Hit',
            'Superiority Die',
            superiorityDie,
          ],
          metadata: const {
            'source': 'subclassMechanic',
            'class': 'fighter',
            'targetPolicy': 'hostile',
          },
        ),
      ];
    }

    final maneuverSaveDc = _maneuverSaveDc(
      character,
      equipmentItems,
      compendiumEntries,
      proficiencyBonus,
    );
    return selectedManeuvers.take(12).map((maneuver) {
      final description = maneuver.description ?? '';
      final text = _normalizedSearchText('${maneuver.name} $description');
      final requiresSave = _firstSaveAbility(description) != null;
      final damageFormula =
          _maneuverRollsSuperiorityDie(text) ? superiorityDie : null;
      final timing = _timingForManeuver(text);
      final rollKind = requiresSave
          ? CombatActionRollKind.savingThrow
          : damageFormula == null
              ? CombatActionRollKind.none
              : CombatActionRollKind.damage;
      final saveAbility = _firstSaveAbility(description);
      final condition = _maneuverFailureCondition(text);

      return PreparedCombatAction(
        id: _actionId(character, 'maneuver', maneuver.id),
        name: maneuver.name.trim().isEmpty
            ? 'Battle Master Maneuver'
            : maneuver.name.trim(),
        timing: timing,
        rollKind: rollKind,
        damageFormula: damageFormula,
        saveAbility: saveAbility,
        saveDc: saveAbility == null ? null : maneuverSaveDc,
        resourceKey: _resourceIdMatching(character, const [
              'superiority',
              'superioridad',
              'dado de superioridad',
              'dados de superioridad',
            ]) ??
            'superiority_dice',
        resourceCost: 1,
        tags: [
          'Battle Master',
          'Maneuver',
          superiorityDie,
          _timingTag(timing),
          if (text.contains('when you hit')) 'On Hit',
          if (text.contains('attack roll')) 'Attack Roll',
          if (saveAbility != null) '$saveAbility save',
          if (condition != null) condition,
        ],
        metadata: {
          'source': 'subclassMechanic',
          'class': 'fighter',
          'subclass': 'battleMaster',
          'maneuverId': maneuver.id,
          'description': description,
          'targetPolicy': text.contains('willing creature') ||
                  text.contains('friendly creature') ||
                  text.contains('companion')
              ? 'ally'
              : 'hostile',
          if (condition != null) 'appliesConditionOnFail': condition,
        },
      );
    }).toList(growable: false);
  }

  static int _maneuverSaveDc(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final strMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'STR',
        equipmentItems,
        compendiumEntries,
      ),
    );
    final dexMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'DEX',
        equipmentItems,
        compendiumEntries,
      ),
    );
    return 8 + proficiencyBonus + math.max(strMod, dexMod);
  }

  static CombatActionTiming _timingForManeuver(String normalizedText) {
    if (normalizedText.contains('reaction')) return CombatActionTiming.reaction;
    if (normalizedText.contains('bonus action')) {
      return CombatActionTiming.bonusAction;
    }
    return CombatActionTiming.free;
  }

  static String _timingTag(CombatActionTiming timing) {
    return switch (timing) {
      CombatActionTiming.bonusAction => 'Bonus Action',
      CombatActionTiming.reaction => 'Reaction',
      CombatActionTiming.free => 'Free',
      CombatActionTiming.action => 'Action',
      _ => 'Special',
    };
  }

  static bool _maneuverRollsSuperiorityDie(String normalizedText) {
    return normalizedText.contains('superiority die') &&
        (normalizedText.contains('damage') ||
            normalizedText.contains('damage roll') ||
            normalizedText.contains('takes damage'));
  }

  static String? _maneuverFailureCondition(String normalizedText) {
    if (normalizedText.contains('trip attack')) return 'Prone';
    if (normalizedText.contains('menacing attack')) return 'Frightened';
    if (normalizedText.contains('goading attack')) return 'Goaded';
    if (normalizedText.contains('disarming attack')) return 'Disarmed';
    if (normalizedText.contains('pushing attack')) return 'Pushed';
    return null;
  }

  static int _weaponCriticalThreshold(Character character) {
    final fighterLevel = _classLevel(character, const ['fighter', 'guerrero']);
    if (fighterLevel < 3) return 20;
    final subclass = _normalizedSearchText(
      character.subclassForClass('fighter') ?? character.subclass ?? '',
    );
    if (!subclass.contains('champion') && !subclass.contains('campeon')) {
      return 20;
    }
    return fighterLevel >= 15 ? 18 : 19;
  }

  static List<PreparedCombatAction> _rogueActions(Character character) {
    final rogueLevel = _classLevel(character, const ['rogue', 'picaro']);
    if (rogueLevel <= 0) return const [];

    final diceCount = ((rogueLevel + 1) / 2).floor().clamp(1, 10).toInt();
    final formula = '${diceCount}d6';
    final actions = <PreparedCombatAction>[
      PreparedCombatAction(
        id: _actionId(character, 'class_action', 'sneak_attack'),
        name: 'Sneak Attack',
        timing: CombatActionTiming.free,
        rollKind: CombatActionRollKind.damage,
        damageFormula: formula,
        tags: [
          'Rogue',
          'On Hit',
          'Once per turn',
          formula,
          'Finesse/Ranged',
        ],
        metadata: const {
          'source': 'classMechanic',
          'class': 'rogue',
          'targetPolicy': 'hostile',
          'combatWindow': 'onHit',
        },
      ),
    ];
    if (rogueLevel >= 2) {
      actions.addAll([
        PreparedCombatAction(
          id: _actionId(character, 'class_action', 'cunning_action_dash'),
          name: 'Cunning Action: Dash',
          timing: CombatActionTiming.bonusAction,
          rollKind: CombatActionRollKind.none,
          tags: const ['Rogue', 'Cunning Action', 'Bonus Action', 'Dash'],
          metadata: const {
            'source': 'classMechanic',
            'class': 'rogue',
            'targetsSelf': true,
            'combatEffect': 'dash',
            'grantsMovement': true,
          },
        ),
        PreparedCombatAction(
          id: _actionId(character, 'class_action', 'cunning_action_disengage'),
          name: 'Cunning Action: Disengage',
          timing: CombatActionTiming.bonusAction,
          rollKind: CombatActionRollKind.none,
          tags: const [
            'Rogue',
            'Cunning Action',
            'Bonus Action',
            'Disengage',
          ],
          metadata: const {
            'source': 'classMechanic',
            'class': 'rogue',
            'targetsSelf': true,
            'combatEffect': 'disengage',
          },
        ),
        PreparedCombatAction(
          id: _actionId(character, 'class_action', 'cunning_action_hide'),
          name: 'Cunning Action: Hide',
          timing: CombatActionTiming.bonusAction,
          rollKind: CombatActionRollKind.none,
          tags: const ['Rogue', 'Cunning Action', 'Bonus Action', 'Hide'],
          metadata: const {
            'source': 'classMechanic',
            'class': 'rogue',
            'targetsSelf': true,
            'combatEffect': 'hide',
          },
        ),
      ]);
    }
    if (rogueLevel >= 5) {
      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'class_action', 'uncanny_dodge'),
          name: 'Uncanny Dodge',
          timing: CombatActionTiming.reaction,
          rollKind: CombatActionRollKind.none,
          tags: const [
            'Rogue',
            'Reaction',
            'Halve incoming damage',
            'Visible attacker',
          ],
          metadata: const {
            'source': 'classMechanic',
            'class': 'rogue',
            'targetsSelf': true,
            'combatEffect': 'uncannyDodge',
            'damageReduction': 'half',
          },
        ),
      );
    }
    return actions;
  }

  static List<PreparedCombatAction> _paladinActions(Character character) {
    final paladinLevel = _classLevel(character, const ['paladin', 'paladin']);
    if (paladinLevel <= 0) return const [];

    final actions = <PreparedCombatAction>[
      PreparedCombatAction(
        id: _actionId(character, 'class_action', 'lay_on_hands_5'),
        name: 'Lay on Hands (5 HP)',
        timing: CombatActionTiming.action,
        rollKind: CombatActionRollKind.healing,
        healingFormula: '5',
        resourceKey: _resourceIdMatching(
                character, const ['lay on hands', 'imposicion de manos']) ??
            'lay_on_hands',
        resourceCost: 5,
        tags: const ['Paladin', 'Action', 'Touch', 'Healing', '5 HP'],
        metadata: const {
          'source': 'classMechanic',
          'class': 'paladin',
          'targetPolicy': 'ally',
        },
      ),
    ];
    if (paladinLevel < 2) return actions;

    for (var level = 1; level <= 5; level++) {
      if (CharacterSpellSlotService.slotMaxForLevel(character, level) <= 0) {
        continue;
      }
      final diceCount = math.min(5, level + 1);
      final formula = '${diceCount}d8';
      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'class_action', 'divine_smite_$level'),
          name: 'Divine Smite (${_ordinalSpellLevel(level)})',
          timing: CombatActionTiming.free,
          rollKind: CombatActionRollKind.damage,
          damageFormula: formula,
          resourceKey: 'spellSlot:$level',
          resourceCost: 1,
          tags: [
            'Paladin',
            'On Hit',
            'Melee weapon',
            'Slot $level',
            'Radiant',
            formula,
          ],
          metadata: const {
            'source': 'classMechanic',
            'class': 'paladin',
            'targetPolicy': 'hostile',
            'combatWindow': 'onHit',
            'damageType': 'Radiant',
          },
        ),
      );
    }
    return actions;
  }

  static List<PreparedCombatAction> _bardActions(Character character) {
    final bardLevel = _classLevel(character, const ['bard', 'bardo']);
    if (bardLevel <= 0) return const [];

    final die = _bardicInspirationDie(bardLevel);
    return [
      PreparedCombatAction(
        id: _actionId(character, 'class_action', 'bardic_inspiration'),
        name: 'Bardic Inspiration',
        timing: CombatActionTiming.bonusAction,
        rollKind: CombatActionRollKind.none,
        resourceKey: _resourceIdMatching(character, const [
              'bardic inspiration',
              'inspiracion bardica',
            ]) ??
            'bardic_inspiration',
        resourceCost: 1,
        tags: ['Bard', 'Bonus Action', 'Ally', '60 ft', die],
        metadata: {
          'source': 'classMechanic',
          'class': 'bard',
          'targetPolicy': 'ally',
          'combatEffect': 'bardicInspiration',
          'inspirationDie': die,
        },
      ),
    ];
  }

  static String _bardicInspirationDie(int bardLevel) {
    if (bardLevel >= 15) return '1d12';
    if (bardLevel >= 10) return '1d10';
    if (bardLevel >= 5) return '1d8';
    return '1d6';
  }

  static List<PreparedCombatAction> _clericActions(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final clericLevel = _classLevel(character, const ['cleric', 'clerigo']);
    if (clericLevel < 2) return const [];

    final saveDc = _spellSaveDc(
      character,
      equipmentItems,
      compendiumEntries,
      proficiencyBonus,
    );
    return [
      PreparedCombatAction(
        id: _actionId(character, 'class_action', 'turn_undead'),
        name: 'Channel Divinity: Turn Undead',
        timing: CombatActionTiming.action,
        rollKind: CombatActionRollKind.savingThrow,
        saveAbility: 'WIS',
        saveDc: saveDc,
        resourceKey: _resourceIdMatching(character, const [
              'channel divinity',
              'canalizar divinidad',
            ]) ??
            'channel_divinity',
        resourceCost: 1,
        tags: const ['Cleric', 'Channel Divinity', 'Undead', '30 ft'],
        metadata: const {
          'source': 'classMechanic',
          'class': 'cleric',
          'targetPolicy': 'hostile',
          'areaShape': 'sphere',
          'areaFeet': 30,
          'appliesConditionOnFail': 'Turned',
        },
      ),
    ];
  }

  static List<PreparedCombatAction> _druidActions(Character character) {
    final druidLevel = _classLevel(character, const ['druid', 'druida']);
    if (druidLevel < 2) return const [];

    return [
      PreparedCombatAction(
        id: _actionId(character, 'class_action', 'wild_shape'),
        name: 'Wild Shape',
        timing: CombatActionTiming.action,
        rollKind: CombatActionRollKind.none,
        resourceKey: _resourceIdMatching(
              character,
              const ['wild shape', 'forma salvaje'],
            ) ??
            'wild_shape',
        resourceCost: 1,
        tags: const ['Druid', 'Action', 'Shapechange'],
        metadata: const {
          'source': 'classMechanic',
          'class': 'druid',
          'targetsSelf': true,
          'combatEffect': 'wildShape',
        },
      ),
    ];
  }

  static List<PreparedCombatAction> _artificerActions(Character character) {
    final artificerLevel =
        _classLevel(character, const ['artificer', 'artifice']);
    if (artificerLevel < 7) return const [];

    final intMod =
        _abilityModifier(_characterBaseAbilityScore(character, 'INT'));
    final bonus = intMod < 1 ? 1 : intMod;
    return [
      PreparedCombatAction(
        id: _actionId(character, 'class_action', 'flash_of_genius'),
        name: 'Flash of Genius',
        timing: CombatActionTiming.reaction,
        rollKind: CombatActionRollKind.none,
        resourceKey: _resourceIdMatching(character, const [
              'flash of genius',
              'destello de genialidad',
            ]) ??
            'flash_of_genius',
        resourceCost: 1,
        tags: ['Artificer', 'Reaction', '+$bonus check/save', '30 ft'],
        metadata: {
          'source': 'classMechanic',
          'class': 'artificer',
          'targetPolicy': 'ally',
          'rollBonus': bonus,
        },
      ),
    ];
  }

  static List<PreparedCombatAction> _monkTechniqueActions(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final monkLevel = _effectiveMonkLevel(character);
    if (monkLevel <= 0) return const [];

    final strMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'STR',
        equipmentItems,
        compendiumEntries,
      ),
    );
    final dexMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'DEX',
        equipmentItems,
        compendiumEntries,
      ),
    );
    final abilityLabel = dexMod > strMod ? 'DEX' : 'STR';
    final abilityModifier = dexMod > strMod ? dexMod : strMod;
    final attackFormula = _formatRollFormula(
      'd20',
      abilityModifier + proficiencyBonus,
    );
    final damageFormula = _formatRollFormula(
      _martialArtsDie(monkLevel),
      abilityModifier,
    );
    final criticalFormula = _formatRollFormula(
      _doubleDiceFormula(_martialArtsDie(monkLevel)),
      abilityModifier,
    );
    final actions = <PreparedCombatAction>[
      PreparedCombatAction(
        id: _actionId(character, 'class_action', 'martial_arts_bonus_strike'),
        name: 'Martial Arts: Bonus Unarmed Strike',
        timing: CombatActionTiming.bonusAction,
        rollKind: CombatActionRollKind.attack,
        attackFormula: attackFormula,
        damageFormula: damageFormula,
        tags: [
          'Monk',
          'Martial Arts',
          'Bonus Action',
          'Unarmed',
          'Melee',
          'Requires Attack action',
          abilityLabel,
        ],
        metadata: {
          'source': 'classMechanic',
          'class': 'monk',
          'targetPolicy': 'hostile',
          'combatPrerequisite': 'attackActionThisTurn',
          'usesAttackAction': false,
          'multiattack': true,
          'damageType': 'Bludgeoning',
          'criticalDamageFormula': criticalFormula,
          'multiAttackSteps': [
            {
              'name': 'Unarmed Strike',
              'attackFormula': attackFormula,
              'damageFormula': damageFormula,
              'criticalDamageFormula': criticalFormula,
              'tags': [
                abilityLabel,
                'Martial Arts',
                'Unarmed',
                'Melee',
                'Bludgeoning',
              ],
            },
          ],
        },
      ),
    ];
    if (monkLevel < 2) return actions;

    final flurryFeature =
        _firstFeatureWhere(character, _isFlurryOfBlowsFeature);
    final patientDefenseFeature =
        _firstFeatureWhere(character, _isPatientDefenseFeature);
    final stepOfTheWindFeature =
        _firstFeatureWhere(character, _isStepOfTheWindFeature);
    final resourceKey = _monkKiResourceKey(character, flurryFeature);

    actions.addAll([
      PreparedCombatAction(
        id: _actionId(character, 'feature', 'flurry_of_blows'),
        name: flurryFeature?.name.trim().isNotEmpty == true
            ? flurryFeature!.name.trim()
            : 'Rafaga de golpes',
        timing: CombatActionTiming.bonusAction,
        rollKind: CombatActionRollKind.attack,
        resourceKey: resourceKey,
        resourceCost: 1,
        tags: [
          'Monk',
          'Ki',
          'Bonus Action',
          '2 attacks',
          'Unarmed',
          'Melee',
          'Bludgeoning',
        ],
        metadata: {
          'source': 'feature',
          if (flurryFeature != null) 'featureId': flurryFeature.id,
          if (flurryFeature != null) 'featureSource': flurryFeature.source,
          'flurryOfBlows': true,
          'multiattack': true,
          'targetPolicy': 'hostile',
          'usesAttackAction': false,
          'multiAttackSteps': [
            for (var index = 0; index < 2; index++)
              {
                'name': 'Unarmed Strike',
                'attackFormula': attackFormula,
                'damageFormula': damageFormula,
                'criticalDamageFormula': criticalFormula,
                'tags': [
                  abilityLabel,
                  'Martial Arts',
                  'Unarmed',
                  'Melee',
                  'Bludgeoning',
                ],
              },
          ],
        },
      ),
      PreparedCombatAction(
        id: _actionId(character, 'feature', 'patient_defense'),
        name: patientDefenseFeature?.name.trim().isNotEmpty == true
            ? patientDefenseFeature!.name.trim()
            : 'Patient Defense',
        timing: CombatActionTiming.bonusAction,
        rollKind: CombatActionRollKind.none,
        resourceKey: resourceKey,
        resourceCost: 1,
        tags: const ['Monk', 'Ki', 'Bonus Action', 'Dodge', 'Defense'],
        metadata: {
          'source': 'feature',
          if (patientDefenseFeature != null)
            'featureId': patientDefenseFeature.id,
          if (patientDefenseFeature != null)
            'featureSource': patientDefenseFeature.source,
          'targetsSelf': true,
          'combatEffect': 'dodge',
        },
      ),
      PreparedCombatAction(
        id: _actionId(character, 'feature', 'step_of_the_wind_dash'),
        name: stepOfTheWindFeature?.name.trim().isNotEmpty == true
            ? '${stepOfTheWindFeature!.name.trim()}: Dash'
            : 'Step of the Wind: Dash',
        timing: CombatActionTiming.bonusAction,
        rollKind: CombatActionRollKind.none,
        resourceKey: resourceKey,
        resourceCost: 1,
        tags: const ['Monk', 'Ki', 'Bonus Action', 'Dash', 'Movement'],
        metadata: {
          'source': 'feature',
          if (stepOfTheWindFeature != null)
            'featureId': stepOfTheWindFeature.id,
          if (stepOfTheWindFeature != null)
            'featureSource': stepOfTheWindFeature.source,
          'targetsSelf': true,
          'combatEffect': 'dash',
          'grantsMovement': true,
        },
      ),
      PreparedCombatAction(
        id: _actionId(character, 'feature', 'step_of_the_wind_disengage'),
        name: stepOfTheWindFeature?.name.trim().isNotEmpty == true
            ? '${stepOfTheWindFeature!.name.trim()}: Disengage'
            : 'Step of the Wind: Disengage',
        timing: CombatActionTiming.bonusAction,
        rollKind: CombatActionRollKind.none,
        resourceKey: resourceKey,
        resourceCost: 1,
        tags: const ['Monk', 'Ki', 'Bonus Action', 'Disengage', 'Movement'],
        metadata: {
          'source': 'feature',
          if (stepOfTheWindFeature != null)
            'featureId': stepOfTheWindFeature.id,
          if (stepOfTheWindFeature != null)
            'featureSource': stepOfTheWindFeature.source,
          'targetsSelf': true,
          'combatEffect': 'disengage',
        },
      ),
    ]);
    if (monkLevel >= 3) {
      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'class_action', 'deflect_missiles'),
          name: 'Deflect Missiles',
          timing: CombatActionTiming.reaction,
          rollKind: CombatActionRollKind.none,
          tags: [
            'Monk',
            'Reaction',
            'Ranged weapon',
            'Reduce 1d10+$abilityLabel+$monkLevel',
          ],
          metadata: {
            'source': 'classMechanic',
            'class': 'monk',
            'targetsSelf': true,
            'combatEffect': 'deflectMissiles',
            'damageReductionFormula':
                _formatRollFormula('1d10', abilityModifier + monkLevel),
          },
        ),
      );
    }
    if (monkLevel >= 5) {
      final wisdomMod = _abilityModifier(
        _effectiveAbilityScore(
          character,
          'WIS',
          equipmentItems,
          compendiumEntries,
        ),
      );
      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'class_action', 'stunning_strike'),
          name: 'Stunning Strike',
          timing: CombatActionTiming.free,
          rollKind: CombatActionRollKind.savingThrow,
          saveAbility: 'CON',
          saveDc: 8 + proficiencyBonus + wisdomMod,
          resourceKey: resourceKey,
          resourceCost: 1,
          tags: const [
            'Monk',
            'Ki',
            'On Hit',
            'CON save',
            'Stunned',
          ],
          metadata: const {
            'source': 'classMechanic',
            'class': 'monk',
            'targetPolicy': 'hostile',
            'combatWindow': 'onHit',
            'appliesConditionOnFail': 'Stunned',
          },
        ),
      );
    }
    return actions;
  }

  static int _effectiveMonkLevel(Character character) {
    final explicitMonkLevel = _classLevel(character, const [
      'monk',
      'monje',
      'monk 5e',
      'monje 5e',
    ]);
    if (explicitMonkLevel > 0) return explicitMonkLevel;

    final hasKiResource = _resourceIdMatching(character, const [
          'ki',
          'focus point',
          'focus points',
          'puntos de ki',
          'punto de ki',
          'puntos de enfoque',
          'punto de enfoque',
        ]) !=
        null;
    final hasMonkFeature = character.features.any((feature) {
      final text = _normalizedSearchText(
        '${feature.name} ${feature.description} ${feature.source}',
      );
      return _isRawMonkKiFeature(feature) ||
          _isFlurryOfBlowsFeature(feature) ||
          _isPatientDefenseFeature(feature) ||
          _isStepOfTheWindFeature(feature) ||
          text.contains('stunning strike') ||
          text.contains('golpe aturdidor') ||
          text.contains('martial arts') ||
          text.contains('artes marciales') ||
          text.contains('monk') ||
          text.contains('monje');
    });
    if (!hasKiResource && !hasMonkFeature) return 0;
    return character.level > 0 ? character.level : 2;
  }

  static int _weaponAttackBonus(
    Character character,
    ResolvedInventoryItem resolvedWeapon,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    if (resolvedWeapon.originalItem.id == character.equippedMainHandItemId) {
      return CharacterWeaponAttackService.mainHandAttackBonus(
        character: character,
        resolvedWeapon: resolvedWeapon,
        getAbilityScore: (ability) => _effectiveAbilityScore(
          character,
          ability,
          equipmentItems,
          compendiumEntries,
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
        equipmentItems,
        compendiumEntries,
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

  static int _weaponDamageBonus(
    Character character,
    ResolvedInventoryItem resolvedWeapon,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    if (resolvedWeapon.originalItem.id == character.equippedMainHandItemId) {
      return CharacterWeaponAttackService.mainHandDamageBonus(
        character: character,
        resolvedWeapon: resolvedWeapon,
        hasOffHandWeaponEquipped:
            (character.equippedOffHandItemId ?? '').trim().isNotEmpty,
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
        getAbilityScore: (ability) => _effectiveAbilityScore(
          character,
          ability,
          equipmentItems,
          compendiumEntries,
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
        equipmentItems,
        compendiumEntries,
      ),
      getAbilityModifier: _abilityModifier,
    );
    final itemDamageBonus = resolvedWeapon.equipmentItem?.damageBonus ?? 0;
    return abilityMod + itemDamageBonus;
  }

  static PreparedCombatAction? _spellAttackAction(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final ability = _spellcastingAbility(character);
    if (ability == null) return null;

    final abilityMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        ability,
        equipmentItems,
        compendiumEntries,
      ),
    );
    final attackBonus = abilityMod +
        proficiencyBonus +
        _passiveSpellAttackBonus(character, equipmentItems, compendiumEntries);

    return PreparedCombatAction(
      id: _actionId(character, 'spellcasting', 'spell_attack'),
      name: 'Spell Attack',
      timing: CombatActionTiming.action,
      rollKind: CombatActionRollKind.attack,
      attackFormula: _formatRollFormula('d20', attackBonus),
      tags: [ability, 'Manual Damage'],
      metadata: {
        'source': 'spellcasting',
        'spellcastingAbility': ability,
      },
    );
  }

  static List<PreparedCombatAction> _spellActions(
    Character character,
    List<Spell> spells,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final spellById = {for (final spell in spells) spell.id: spell};
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
                equipmentItems,
                compendiumEntries,
              ),
            ) +
            proficiencyBonus +
            _passiveSpellAttackBonus(
              character,
              equipmentItems,
              compendiumEntries,
            );

    final actions = <PreparedCombatAction>[];
    for (final spellId in spellIds) {
      final spell = spellById[spellId];
      if (spell == null) continue;

      final damageFormula = _firstDiceFormula(spell.description);
      final usesAttackRoll = _spellUsesAttackRoll(spell);
      final mentionsSave = _spellMentionsSave(spell);
      final saveAbility =
          mentionsSave ? _firstSaveAbility(spell.description) : null;
      final healingSpell = _spellLooksLikeHealing(spell.description);
      final saveDc = saveAbility == null
          ? null
          : _spellSaveDc(
              character,
              equipmentItems,
              compendiumEntries,
              proficiencyBonus,
            );
      final areaMetadata = _spellAreaMetadata(spell);
      final spellDamageType = _spellDamageType(spell.description);
      final spellRangeFeet = _spellRangeFeet(spell, areaMetadata);
      final targetsOnlySelf = _spellTargetsOnlySelf(spell, areaMetadata);
      final targetPolicy = _spellTargetPolicy(
        spell,
        healingSpell: healingSpell,
        targetsOnlySelf: targetsOnlySelf,
        usesAttackRoll: usesAttackRoll,
        saveAbility: saveAbility,
        damageFormula: damageFormula,
      );
      final spellFlow = usesAttackRoll
          ? 'attack'
          : saveAbility != null
              ? 'save'
              : healingSpell
                  ? 'healing'
                  : damageFormula != null
                      ? 'damage'
                      : 'effect';
      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'spell', spell.id),
          name: spell.name,
          timing: _timingFromCastingTime(spell.castingTime),
          rollKind: usesAttackRoll
              ? CombatActionRollKind.attack
              : saveAbility != null
                  ? CombatActionRollKind.savingThrow
                  : healingSpell
                      ? CombatActionRollKind.healing
                      : damageFormula != null
                          ? CombatActionRollKind.damage
                          : CombatActionRollKind.none,
          attackFormula: usesAttackRoll
              ? _formatRollFormula('d20', spellAttackBonus)
              : null,
          damageFormula: healingSpell ? null : damageFormula,
          healingFormula: healingSpell ? damageFormula : null,
          saveAbility: saveAbility,
          saveDc: saveDc,
          resourceKey: spell.level > 0 ? 'spellSlot:${spell.level}' : null,
          resourceCost: spell.level > 0 ? 1 : 0,
          tags: [
            spell.school,
            spell.range,
            if (spell.level == 0) 'Cantrip' else 'Slot ${spell.level}',
            if (spell.duration.toLowerCase().contains('concentration'))
              'Concentration',
            if (saveAbility != null && saveDc != null)
              '$saveAbility DC $saveDc',
            if (usesAttackRoll) 'Spell Attack',
            if (healingSpell) 'Healing',
            if (spellDamageType != null) spellDamageType,
            if (targetPolicy == 'ally') 'Ally',
            if (targetsOnlySelf) 'Self',
          ],
          metadata: {
            'source': 'spell',
            'spellFlow': spellFlow,
            'spellId': spell.id,
            'level': spell.level,
            'castingTime': spell.castingTime,
            'duration': spell.duration,
            if (targetsOnlySelf) 'targetsSelf': true,
            if (targetPolicy.isNotEmpty) 'targetPolicy': targetPolicy,
            if (spellDamageType != null) 'damageType': spellDamageType,
            if (spellRangeFeet != null) 'rangeFeet': spellRangeFeet,
            ...areaMetadata,
            'halfDamageOnSave': _spellDealsHalfDamageOnSave(spell.description),
            'criticalDamageFormula': usesAttackRoll && damageFormula != null
                ? _doubleDamageFormula(damageFormula)
                : null,
          },
        ),
      );
    }
    return actions;
  }

  static List<PreparedCombatAction> _featureActions(Character character) {
    return character.features.where((feature) {
      return _isUsableCombatFeature(feature) &&
          !_isSpecificModeledCombatFeature(feature);
    }).map((feature) {
      final diceFormula = _firstDiceFormula(feature.description);
      final healing = _looksLikeHealing(feature.description);
      final grantsActionSurge = _isActionSurgeText(
        '${feature.name} ${feature.description}',
      );
      return PreparedCombatAction(
        id: _actionId(character, 'feature', feature.id),
        name: feature.name.trim().isEmpty ? 'Class Feature' : feature.name,
        timing: _timingForFeature(feature),
        rollKind: diceFormula == null
            ? CombatActionRollKind.none
            : healing
                ? CombatActionRollKind.healing
                : CombatActionRollKind.damage,
        damageFormula: healing ? null : diceFormula,
        healingFormula: healing ? diceFormula : null,
        resourceKey: (feature.linkedResourceId ?? '').trim().isEmpty
            ? null
            : feature.linkedResourceId!.trim(),
        resourceCost: (feature.linkedResourceId ?? '').trim().isEmpty ? 0 : 1,
        tags: [
          _featureSourceLabel(feature),
          if (grantsActionSurge) 'Extra Action',
          if (feature.unlockedAtLevel != null)
            'Level ${feature.unlockedAtLevel}',
          if ((feature.linkedResourceId ?? '').trim().isNotEmpty) 'Resource',
        ],
        metadata: {
          'source': 'feature',
          'featureId': feature.id,
          'featureSource': feature.source,
          'description': feature.description,
          if (grantsActionSurge) 'combatEffect': 'actionSurge',
          if (grantsActionSurge) 'grantsAction': true,
          if (healing) 'targetPolicy': 'ally',
          if (grantsActionSurge) 'targetsSelf': true,
        },
      );
    }).toList();
  }

  static bool _isSpecificModeledCombatFeature(CharacterFeature feature) {
    final text =
        _normalizedSearchText('${feature.name} ${feature.description}');
    return _isFlurryOfBlowsFeature(feature) ||
        _isPatientDefenseFeature(feature) ||
        _isStepOfTheWindFeature(feature) ||
        _isRawMonkKiFeature(feature) ||
        _isSecondWindText(text) ||
        _isActionSurgeText(text) ||
        text.contains('martial arts') ||
        text.contains('ki-fueled attack') ||
        text.contains('ki fueled attack') ||
        text.contains('ataque potenciado por ki') ||
        text.contains('stunning strike') ||
        text.contains('deflect missiles') ||
        text.contains('cunning action') ||
        text.contains('uncanny dodge') ||
        text.contains('rage') ||
        text.contains('sneak attack') ||
        text.contains('lay on hands') ||
        text.contains('imposicion de manos') ||
        text.contains('divine smite') ||
        text.contains('improved divine smite') ||
        text.contains('radiant strikes') ||
        text.contains('bardic inspiration') ||
        text.contains('inspiracion bardica') ||
        text.contains('channel divinity') ||
        text.contains('canalizar divinidad') ||
        text.contains('turn undead') ||
        text.contains('wild shape') ||
        text.contains('forma salvaje') ||
        text.contains('flash of genius') ||
        text.contains('destello de genialidad') ||
        text.contains('combat superiority') ||
        text.contains('superiority die') ||
        text.contains('dado de superioridad') ||
        text.contains('battle master');
  }

  static bool _isUsableCombatFeature(CharacterFeature feature) {
    final linkedResource = (feature.linkedResourceId ?? '').trim();
    final text = '${feature.name} ${feature.description}'.toLowerCase();

    if (linkedResource.isNotEmpty) return true;
    if (_firstDiceFormula(feature.description) != null) return true;

    final activeSignals = [
      'as an action',
      'use your action',
      'bonus action',
      'reaction',
      'when you hit',
      'when you take damage',
      'when you are hit',
      'you can use',
      'you may use',
      'you can expend',
      'you can spend',
      'activate',
      'rage',
      'furia',
      'rabia',
      'bardic inspiration',
      'inspiracion bardica',
      'channel divinity',
      'canalizar divinidad',
      'lay on hands',
      'imposicion de manos',
      'second wind',
      'action surge',
      'oleada de accion',
      'wild shape',
      'forma salvaje',
      'superiority die',
      'dado de superioridad',
      'ki point',
      'puntos de ki',
      'focus point',
    ];
    if (activeSignals.any(text.contains)) return true;

    final passiveSignals = [
      'you gain proficiency',
      'you are proficient',
      'your speed increases',
      'your walking speed',
      'darkvision',
      'resistance to',
      'you have resistance',
      'you have advantage',
      'you can speak',
      'you know',
      'your maximum',
      'unarmored defense',
      'fighting style',
      'extra attack',
      'ability score',
      'language',
      'armor class',
    ];
    if (passiveSignals.any(text.contains)) return false;

    return false;
  }

  static CharacterFeature? _firstFeatureWhere(
    Character character,
    bool Function(CharacterFeature feature) test,
  ) {
    for (final feature in character.features) {
      if (test(feature)) return feature;
    }
    return null;
  }

  static bool _isFlurryOfBlowsFeature(CharacterFeature feature) {
    final text =
        _normalizedSearchText('${feature.name} ${feature.description}');
    return text.contains('flurry of blows') ||
        text.contains('rafaga de golpes') ||
        text.contains('rafaga de golpe');
  }

  static bool _isPatientDefenseFeature(CharacterFeature feature) {
    final text =
        _normalizedSearchText('${feature.name} ${feature.description}');
    return text.contains('patient defense') ||
        text.contains('defensa paciente');
  }

  static bool _isStepOfTheWindFeature(CharacterFeature feature) {
    final text =
        _normalizedSearchText('${feature.name} ${feature.description}');
    return text.contains('step of the wind') ||
        text.contains('paso del viento');
  }

  static bool _isRawMonkKiFeature(CharacterFeature feature) {
    final name = _normalizedSearchText(feature.name);
    final text =
        _normalizedSearchText('${feature.name} ${feature.description}');
    final isKiTitle = name == 'ki' ||
        name == 'ki points' ||
        name == 'puntos de ki' ||
        name == 'monk ki' ||
        name == 'monastic discipline' ||
        name == 'disciplina monastica';
    if (!isKiTitle) return false;
    return text.contains('ki point') ||
        text.contains('ki points') ||
        text.contains('puntos de ki') ||
        text.contains('punto de ki') ||
        text.contains('focus point') ||
        text.contains('focus points') ||
        text.contains('puntos de enfoque') ||
        text.contains('punto de enfoque');
  }

  static bool _isBattleMasterFeature(CharacterFeature feature) {
    final text =
        _normalizedSearchText('${feature.name} ${feature.description}');
    return text.contains('combat superiority') ||
        text.contains('superiority die') ||
        text.contains('battle master') ||
        text.contains('maestro de batalla');
  }

  static bool _hasFeatureMatching(
    Character character,
    bool Function(CharacterFeature feature) test,
  ) {
    return _firstFeatureWhere(character, test) != null;
  }

  static String _monkKiResourceKey(
    Character character,
    CharacterFeature? feature,
  ) {
    final linkedResource = (feature?.linkedResourceId ?? '').trim();
    if (linkedResource.isNotEmpty) return linkedResource;
    return _resourceIdMatching(character, const [
          'ki',
          'focus point',
          'focus points',
          'puntos de ki',
          'punto de ki',
          'puntos de enfoque',
          'punto de enfoque',
        ]) ??
        'ki_points';
  }

  static String? _resourceIdMatching(
    Character character,
    List<String> needles,
  ) {
    for (final resource in character.resources) {
      final text = _normalizedSearchText('${resource.id} ${resource.name}');
      for (final needle in needles) {
        if (text.contains(_normalizedSearchText(needle))) {
          return resource.id;
        }
      }
    }
    return null;
  }

  static List<PreparedCombatAction> _resourceActions(Character character) {
    return character.resources.where((resource) {
      return !_isSpecificCombatResource(resource);
    }).map((resource) {
      final diceFormula = _firstDiceFormula(resource.notes ?? '');
      final healing =
          _looksLikeHealing('${resource.name} ${resource.notes ?? ''}');
      final grantsActionSurge = _isActionSurgeText(
        '${resource.name} ${resource.notes ?? ''}',
      );
      return PreparedCombatAction(
        id: _actionId(character, 'resource', resource.id),
        name: resource.name.trim().isEmpty ? 'Resource' : resource.name,
        timing: _timingForResource(resource),
        rollKind: diceFormula == null
            ? CombatActionRollKind.resource
            : healing
                ? CombatActionRollKind.healing
                : CombatActionRollKind.damage,
        damageFormula: healing ? null : diceFormula,
        healingFormula: healing ? diceFormula : null,
        resourceKey: resource.id,
        resourceCost: 1,
        tags: [
          '${resource.current}/${resource.max}',
          _resourceRechargeLabel(resource),
          if (grantsActionSurge) 'Extra Action',
        ],
        metadata: {
          'source': 'resource',
          'resourceId': resource.id,
          'rechargeType': resource.rechargeType,
          'notes': resource.notes,
          if (grantsActionSurge) 'combatEffect': 'actionSurge',
          if (grantsActionSurge) 'grantsAction': true,
          if (healing) 'targetPolicy': 'ally',
          if (grantsActionSurge) 'targetsSelf': true,
        },
      );
    }).toList();
  }

  static List<PreparedCombatAction> _dedupeCombatActions(
    List<PreparedCombatAction> actions,
  ) {
    final seen = <String>{};
    final result = <PreparedCombatAction>[];
    for (final action in actions) {
      final key = _actionDedupeKey(action);
      if (!seen.add(key)) continue;
      result.add(action);
    }
    return result;
  }

  static String _actionDedupeKey(PreparedCombatAction action) {
    final source = action.metadata['source']?.toString() ?? '';
    final slotLevel = action.metadata['level']?.toString() ?? '';
    final inventoryItemId =
        action.metadata['inventoryItemId']?.toString() ?? '';
    final maneuverId = action.metadata['maneuverId']?.toString() ?? '';
    final stableSpecificity = maneuverId.isNotEmpty
        ? maneuverId
        : slotLevel.isNotEmpty
            ? 'slot:$slotLevel'
            : inventoryItemId.isNotEmpty
                ? 'item:$inventoryItemId'
                : '';
    return [
      _normalizedSearchText(action.name),
      action.timing.name,
      action.rollKind.name,
      _normalizedSearchText(action.resourceKey ?? ''),
      _normalizedSearchText(action.attackFormula ?? ''),
      _normalizedSearchText(action.damageFormula ?? ''),
      _normalizedSearchText(action.healingFormula ?? ''),
      _normalizedSearchText(action.saveAbility ?? ''),
      action.saveDc?.toString() ?? '',
      if (source == 'spell') source,
      stableSpecificity,
    ].join('|');
  }

  static bool _isSpecificCombatResource(CharacterResource resource) {
    final text = _normalizedSearchText('${resource.id} ${resource.name}');
    return text.contains('ki') ||
        text.contains('focus point') ||
        text.contains('punto de ki') ||
        text.contains('puntos de ki') ||
        text.contains('punto de enfoque') ||
        text.contains('puntos de enfoque') ||
        text.contains('rage') ||
        text.contains('furia') ||
        text.contains('rabia') ||
        text.contains('second wind') ||
        text.contains('segundo aliento') ||
        text.contains('action surge') ||
        text.contains('oleada de accion') ||
        text.contains('bardic inspiration') ||
        text.contains('inspiracion bardica') ||
        text.contains('channel divinity') ||
        text.contains('canalizar divinidad') ||
        text.contains('wild shape') ||
        text.contains('forma salvaje') ||
        text.contains('flash of genius') ||
        text.contains('destello de genialidad') ||
        text.contains('superiority') ||
        text.contains('superioridad') ||
        text.contains('lay on hands') ||
        text.contains('imposicion de manos');
  }

  static List<CombatEffect> _passiveEffects(Character character) {
    final effects = <CombatEffect>[];
    final targetId = _combatantIdForCharacter(character);

    void addEffect({
      required String id,
      required String name,
      required CombatEffectKind kind,
      Map<String, dynamic> mechanics = const {},
    }) {
      effects.add(
        CombatEffect(
          id: _actionId(character, 'passive_effect', id),
          name: name,
          kind: kind,
          sourceCombatantId: targetId,
          targetCombatantId: targetId,
          mechanics: mechanics,
        ),
      );
    }

    for (final resistance in [
      ...character.racialResistances,
      ...character.featResistances,
    ]) {
      addEffect(
        id: 'resist_${_slug(resistance)}',
        name: 'Resist $resistance',
        kind: CombatEffectKind.buff,
        mechanics: {'resistance': resistance},
      );
    }

    for (final immunity in [
      ...character.racialImmunities,
      ...character.featImmunities,
    ]) {
      addEffect(
        id: 'immune_${_slug(immunity)}',
        name: 'Immune $immunity',
        kind: CombatEffectKind.buff,
        mechanics: {'immunity': immunity},
      );
    }

    if (character.cannotBeSurprisedWhileConscious) {
      addEffect(
        id: 'cannot_be_surprised',
        name: 'Cannot be surprised',
        kind: CombatEffectKind.buff,
      );
    }

    if (character.unseenAttackersNoAdvantage) {
      addEffect(
        id: 'no_unseen_advantage',
        name: 'No unseen advantage',
        kind: CombatEffectKind.buff,
      );
    }

    final rogueLevel = _classLevel(character, const ['rogue', 'picaro']);
    final monkLevel = _classLevel(character, const ['monk', 'monje']);
    final hasEvasion = rogueLevel >= 7 ||
        monkLevel >= 7 ||
        character.features.any((feature) {
          final text = _normalizedSearchText(
            '${feature.name} ${feature.description}',
          );
          return text.contains('evasion');
        });
    if (hasEvasion) {
      addEffect(
        id: 'evasion',
        name: 'Evasion',
        kind: CombatEffectKind.buff,
        mechanics: const {
          'savingThrow': 'DEX',
          'halfDamageOnSuccess': 'none',
          'damageOnFailedHalfSave': 'half',
        },
      );
    }

    final paladinLevel = _classLevel(character, const ['paladin', 'paladin']);
    final hasRadiantStrikeFeature = character.features.any((feature) {
      final text = _normalizedSearchText(
        '${feature.name} ${feature.description}',
      );
      return text.contains('radiant strikes') ||
          text.contains('improved divine smite');
    });
    if (paladinLevel >= 11 || hasRadiantStrikeFeature) {
      addEffect(
        id: 'radiant_strikes',
        name: 'Radiant Strikes',
        kind: CombatEffectKind.buff,
        mechanics: const {
          'extraDamageOnHit': '1d8',
          'damageType': 'Radiant',
          'requiresMeleeWeaponAttack': true,
        },
      );
    }

    return effects;
  }

  static Map<String, int> _resourceMap(Character character) {
    final result = {
      for (final resource in character.resources)
        if (resource.id.trim().isNotEmpty) resource.id: resource.current,
    };

    for (final resource in CharacterResourceFactory.buildResources(character)) {
      final resourceId = resource.id.trim();
      if (resourceId.isEmpty) continue;
      result.putIfAbsent(resourceId, () => resource.current);
    }

    final fighterLevel = _classLevel(character, const ['fighter', 'guerrero']);
    if (fighterLevel >= 1) {
      result.putIfAbsent('second_wind', () => 1);
    }
    if (fighterLevel >= 2) {
      result.putIfAbsent('action_surge', () => 1);
    }

    for (var level = 1; level <= 9; level++) {
      if (CharacterSpellSlotService.slotMaxForLevel(character, level) > 0) {
        result['spellSlot:$level'] =
            CharacterSpellSlotService.slotRemainingForLevel(character, level);
      }
      if (CharacterSpellSlotService.pactMagicSlotMaxForLevel(
            character,
            level,
          ) >
          0) {
        result['pactMagicSlot:$level'] =
            CharacterSpellSlotService.pactMagicSlotRemainingForLevel(
          character,
          level,
        );
      }
    }

    return result;
  }

  static Map<String, int> _resourceMaxMap(Character character) {
    final result = {
      for (final resource in character.resources)
        if (resource.id.trim().isNotEmpty) resource.id: resource.max,
    };

    for (final resource in CharacterResourceFactory.buildResources(character)) {
      final resourceId = resource.id.trim();
      if (resourceId.isEmpty) continue;
      result.putIfAbsent(resourceId, () => resource.max);
    }

    final fighterLevel = _classLevel(character, const ['fighter', 'guerrero']);
    if (fighterLevel >= 1) {
      result.putIfAbsent('second_wind', () => 1);
    }
    if (fighterLevel >= 2) {
      result.putIfAbsent('action_surge', () => 1);
    }

    for (var level = 1; level <= 9; level++) {
      final slotMax = CharacterSpellSlotService.slotMaxForLevel(
        character,
        level,
      );
      if (slotMax > 0) {
        result['spellSlot:$level'] = slotMax;
      }
      final pactMax = CharacterSpellSlotService.pactMagicSlotMaxForLevel(
        character,
        level,
      );
      if (pactMax > 0) {
        result['pactMagicSlot:$level'] = pactMax;
      }
    }

    return result;
  }

  static int _savingThrowBonus(
    Character character,
    String ability,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final normalizedAbility = ability.toUpperCase();
    final score = _effectiveAbilityScore(
      character,
      normalizedAbility,
      equipmentItems,
      compendiumEntries,
    );
    final proficient = character.savingThrows.any(
      (item) => _normalizeSavingThrowAbility(item) == normalizedAbility,
    );
    return _abilityModifier(score) + (proficient ? proficiencyBonus : 0);
  }

  static String _normalizeSavingThrowAbility(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.contains('STRENGTH')) return 'STR';
    if (normalized.contains('DEXTERITY')) return 'DEX';
    if (normalized.contains('CONSTITUTION')) return 'CON';
    if (normalized.contains('INTELLIGENCE')) return 'INT';
    if (normalized.contains('WISDOM')) return 'WIS';
    if (normalized.contains('CHARISMA')) return 'CHA';
    if (normalized.contains('STR')) return 'STR';
    if (normalized.contains('DEX')) return 'DEX';
    if (normalized.contains('CON')) return 'CON';
    if (normalized.contains('INT')) return 'INT';
    if (normalized.contains('WIS')) return 'WIS';
    if (normalized.contains('CHA')) return 'CHA';
    const aliases = {
      'STRENGTH': 'STR',
      'DEXTERITY': 'DEX',
      'CONSTITUTION': 'CON',
      'INTELLIGENCE': 'INT',
      'WISDOM': 'WIS',
      'CHARISMA': 'CHA',
    };
    return aliases[normalized] ?? normalized;
  }

  static int _effectiveAbilityScore(
    Character character,
    String ability,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    return CharacterEquipmentEffects.getEffectiveAbilityScore(
      char: character,
      ability: ability,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
  }

  static int _effectiveArmorClass(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    final dexScore = _effectiveAbilityScore(
      character,
      'DEX',
      equipmentItems,
      compendiumEntries,
    );
    final dexModifier = _abilityModifier(dexScore);
    final baseAc = CharacterEquipmentEffects.calculateEffectiveArmorClass(
      char: character,
      dexModifier: dexModifier,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
    final resolvedArmor = _resolveInventoryItemById(
      character,
      character.equippedArmorItemId,
      equipmentItems,
      compendiumEntries,
    );
    final resolvedShield = _resolveInventoryItemById(
      character,
      character.equippedShieldItemId,
      equipmentItems,
      compendiumEntries,
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

  static int _passiveSpellAttackBonus(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    final passiveBonus = CharacterEquipmentEffects.getPassiveSpellAttackBonus(
      char: character,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
    final resolvedMainHand = _resolveInventoryItemById(
      character,
      character.equippedMainHandItemId,
      equipmentItems,
      compendiumEntries,
    );
    final resolvedOffHand = _resolveInventoryItemById(
      character,
      character.equippedOffHandItemId,
      equipmentItems,
      compendiumEntries,
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

  static int? _spellSaveDc(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final ability = _spellcastingAbility(character);
    if (ability == null) return null;
    final abilityMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        ability,
        equipmentItems,
        compendiumEntries,
      ),
    );
    final passiveBonus = CharacterEquipmentEffects.getPassiveSpellSaveDcBonus(
      char: character,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
    return 8 + proficiencyBonus + abilityMod + passiveBonus;
  }

  static ResolvedInventoryItem? _resolveInventoryItemById(
    Character character,
    String? itemId,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    if (itemId == null || itemId.trim().isEmpty) return null;
    for (final item in character.inventory) {
      if (item.id != itemId) continue;
      return CharacterInventoryService.resolveInventoryItem(
        inventoryItem: item,
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
      );
    }
    return null;
  }

  static String? _spellcastingAbility(Character character) {
    final direct = character.spellcastingAbility?.trim().toUpperCase();
    if (direct != null && direct.isNotEmpty) return direct;

    for (final value in character.spellcastingAbilitiesByClass.values) {
      final normalized = value.trim().toUpperCase();
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  static int _abilityModifier(int score) => ((score - 10) / 2).floor();

  static int _characterBaseAbilityScore(Character character, String ability) {
    final normalized = ability.trim().toUpperCase();
    return (character.stats[normalized] ?? 10) +
        (character.racialBonuses[normalized] ?? 0) +
        (character.featAbilityBonuses[normalized] ?? 0);
  }

  static String _ordinalSpellLevel(int level) {
    return switch (level) {
      1 => '1st',
      2 => '2nd',
      3 => '3rd',
      _ => '${level}th',
    };
  }

  static int _classLevel(Character character, List<String> classNames) {
    final normalizedNames = classNames.map(_normalizedSearchText).toSet();
    var result = 0;
    for (final entry in character.classLevels.entries) {
      if (!normalizedNames.contains(_normalizedSearchText(entry.key))) {
        continue;
      }
      if (entry.value > result) result = entry.value;
    }
    return result;
  }

  static String? _subclassForCombatClass(
    Character character,
    String className,
  ) {
    final target = _normalizedSearchText(className);
    for (final entry in character.classLevels.entries) {
      if (_normalizedSearchText(entry.key) != target) continue;
      final subclass = character.subclassForClass(entry.key)?.trim();
      if (subclass != null && subclass.isNotEmpty) return subclass;
    }
    final legacySubclass = character.subclass?.trim();
    if (_normalizedSearchText(character.charClass) == target &&
        legacySubclass != null &&
        legacySubclass.isNotEmpty) {
      return legacySubclass;
    }
    return null;
  }

  static String _martialArtsDie(int monkLevel) {
    if (monkLevel >= 17) return '1d12';
    if (monkLevel >= 11) return '1d10';
    if (monkLevel >= 5) return '1d8';
    return '1d6';
  }

  static int _proficiencyBonus(int level) {
    final safeLevel = level < 1 ? 1 : level;
    return 2 + ((safeLevel - 1) ~/ 4);
  }

  static String _formatRollFormula(String dice, int modifier) {
    if (modifier == 0) return dice;
    return modifier > 0 ? '$dice+$modifier' : '$dice$modifier';
  }

  static String? _firstDiceFormula(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(
      r'(\d+d\d+(?:\s*[+-]\s*\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;
    return match.group(1)?.replaceAll(' ', '').toLowerCase();
  }

  static String _diceOnlyFormula(String formula) {
    final match = RegExp(
      r'^(\d*)d(\d+)',
      caseSensitive: false,
    ).firstMatch(formula.trim());
    if (match == null) return formula.trim().toLowerCase();
    final count = (match.group(1) ?? '').isEmpty ? '1' : match.group(1)!;
    return '${count}d${match.group(2)}'.toLowerCase();
  }

  static String? _doubleDamageFormula(String formula) {
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

  static String _doubleDiceFormula(String dice) {
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

  static bool _spellUsesAttackRoll(Spell spell) {
    final text = '${spell.description} ${spell.range}'.toLowerCase();
    return text.contains('spell attack') || text.contains('ranged attack');
  }

  static bool _spellMentionsSave(Spell spell) {
    final text = spell.description.toLowerCase();
    return text.contains('saving throw') || text.contains('save');
  }

  static bool _spellDealsHalfDamageOnSave(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('half as much') ||
        normalized.contains('half damage') ||
        normalized.contains('half the damage');
  }

  static _WeaponRangeSpec? _weaponRangeSpec(
    CharacterInventoryItem weapon,
    EquipmentCompendiumItem? equipmentItem,
  ) {
    final parsed = _parseWeaponRange(equipmentItem?.range);
    if (parsed != null) return parsed;

    final text =
        '${weapon.name} ${weapon.description ?? ''} ${weapon.notes ?? ''}'
            .toLowerCase();
    if (text.contains('shortbow')) return const _WeaponRangeSpec(80, 320);
    if (text.contains('longbow')) return const _WeaponRangeSpec(150, 600);
    if (text.contains('light crossbow')) {
      return const _WeaponRangeSpec(80, 320);
    }
    if (text.contains('heavy crossbow')) {
      return const _WeaponRangeSpec(100, 400);
    }
    if (text.contains('hand crossbow')) return const _WeaponRangeSpec(30, 120);
    if (text.contains('sling')) return const _WeaponRangeSpec(30, 120);
    if (text.contains('dart')) return const _WeaponRangeSpec(20, 60);
    if (weapon.isRanged) return const _WeaponRangeSpec(60, null);
    return null;
  }

  static _WeaponRangeSpec? _parseWeaponRange(String? rawRange) {
    if (rawRange == null || rawRange.trim().isEmpty) return null;
    final text = rawRange.toLowerCase();
    final slash = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);
    if (slash != null) {
      final normal = int.tryParse(slash.group(1) ?? '');
      final long = int.tryParse(slash.group(2) ?? '');
      if (normal != null && normal > 0) return _WeaponRangeSpec(normal, long);
    }
    final explicit = RegExp(r'(\d+)\s*(?:ft|feet|foot)').firstMatch(text);
    if (explicit != null) {
      final normal = int.tryParse(explicit.group(1) ?? '');
      if (normal != null && normal > 0) return _WeaponRangeSpec(normal, null);
    }
    return null;
  }

  static String? _spellDamageType(String text) {
    final normalized = text.toLowerCase();
    const damageTypes = [
      'acid',
      'bludgeoning',
      'cold',
      'fire',
      'force',
      'lightning',
      'necrotic',
      'piercing',
      'poison',
      'psychic',
      'radiant',
      'slashing',
      'thunder',
    ];
    for (final type in damageTypes) {
      if (normalized.contains('$type damage')) {
        return type;
      }
    }
    return null;
  }

  static Map<String, dynamic> _spellAreaMetadata(Spell spell) {
    final text = '${spell.range} ${spell.description}'.toLowerCase();
    String? shape;
    if (text.contains('cone')) {
      shape = 'cone';
    } else if (text.contains('line')) {
      shape = 'line';
    } else if (text.contains('cube')) {
      shape = 'cube';
    } else if (text.contains('sphere') ||
        text.contains('radius') ||
        text.contains('cylinder')) {
      shape = 'sphere';
    }

    if (shape == null) return const {};

    final size = _firstAreaFeet(text, shape);
    if (size == null || size <= 0) return const {};

    return {
      'areaShape': shape,
      'areaFeet': size,
    };
  }

  static int? _spellRangeFeet(
    Spell spell,
    Map<String, dynamic> areaMetadata,
  ) {
    final range = spell.range.trim().toLowerCase();
    if (range.isEmpty) return null;

    if (range.startsWith('self')) {
      final areaFeet = areaMetadata['areaFeet'];
      if (areaFeet is num && areaFeet > 0) return areaFeet.toInt();
      return 0;
    }

    if (range.contains('touch')) return 5;

    final explicitRange =
        RegExp(r'(\d+)\s*(?:ft|feet|foot|pies|pie)').firstMatch(range);
    if (explicitRange != null) {
      return int.tryParse(explicitRange.group(1) ?? '');
    }

    if (range.contains('sight')) return 120;
    if (range.contains('unlimited')) return null;
    return null;
  }

  static int? _firstAreaFeet(String text, String shape) {
    final patterns = <RegExp>[
      RegExp(
        '(\\d+)[-\\s]*(?:foot|feet|ft)[-\\s]*(?:radius[-\\s]*)?$shape',
      ),
      RegExp(
        '(\\d+)[-\\s]*(?:foot|feet|ft)[-\\s]*(?:long[-,\\s]*)?.{0,24}$shape',
      ),
      RegExp('$shape.{0,24}?(\\d+)[-\\s]*(?:foot|feet|ft)'),
      RegExp('(\\d+)[-\\s]*(?:foot|feet|ft)[-\\s]*radius'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > 0) return value;
    }
    return null;
  }

  static bool _spellLooksLikeHealing(String text) {
    final lower = text.toLowerCase();
    return lower.contains('regain') ||
        lower.contains('healing') ||
        lower.contains('heals') ||
        lower.contains('restore');
  }

  static bool _spellTargetsOnlySelf(
    Spell spell,
    Map<String, dynamic> areaMetadata,
  ) {
    final range = spell.range.trim().toLowerCase();
    if (!range.startsWith('self')) return false;
    return areaMetadata.isEmpty;
  }

  static String _spellTargetPolicy(
    Spell spell, {
    required bool healingSpell,
    required bool targetsOnlySelf,
    required bool usesAttackRoll,
    required String? saveAbility,
    required String? damageFormula,
  }) {
    if (targetsOnlySelf) return 'self';
    if (healingSpell) return 'ally';
    if (usesAttackRoll || saveAbility != null || damageFormula != null) {
      return 'hostile';
    }
    if (_spellLooksLikeAllySupport(spell)) return 'ally';
    return '';
  }

  static bool _spellLooksLikeAllySupport(Spell spell) {
    final text = _normalizedSearchText(
        '${spell.name} ${spell.range} ${spell.description}');
    if (text.contains('willing creature') ||
        text.contains('friendly creature') ||
        text.contains('allied creature') ||
        text.contains('ally') ||
        text.contains('creature you touch') ||
        text.contains('creature of your choice') ||
        text.contains('target creature') && _spellSupportVerb(text)) {
      return true;
    }
    return _spellSupportVerb(text) &&
        (text.contains('one creature') ||
            text.contains('a creature') ||
            text.contains('creatures of your choice'));
  }

  static bool _spellSupportVerb(String normalizedText) {
    return normalizedText.contains('gains') ||
        normalizedText.contains('gain ') ||
        normalizedText.contains('advantage') ||
        normalizedText.contains('bonus') ||
        normalizedText.contains('increase') ||
        normalizedText.contains('protect') ||
        normalizedText.contains('ward') ||
        normalizedText.contains('resistance') ||
        normalizedText.contains('temporary hit points');
  }

  static String? _firstSaveAbility(String text) {
    final match = RegExp(
      r'(strength|dexterity|constitution|intelligence|wisdom|charisma)\s+saving throw',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.substring(0, 3).toUpperCase();
  }

  static CombatActionTiming _timingFromCastingTime(String castingTime) {
    final text = castingTime.toLowerCase();
    if (text.contains('bonus')) return CombatActionTiming.bonusAction;
    if (text.contains('reaction')) return CombatActionTiming.reaction;
    return CombatActionTiming.action;
  }

  static int _extraAttackCount(Character character) {
    var count = 1;
    for (final feature in character.features) {
      final text = '${feature.name} ${feature.description}'.toLowerCase();
      if (!text.contains('extra attack')) continue;
      if (text.contains('four times') ||
          text.contains('four attacks') ||
          text.contains('three additional')) {
        count = count < 4 ? 4 : count;
      } else if (text.contains('three times') ||
          text.contains('three attacks') ||
          text.contains('two additional')) {
        count = count < 3 ? 3 : count;
      } else {
        count = count < 2 ? 2 : count;
      }
    }
    return count;
  }

  static CombatActionTiming _timingForFeature(CharacterFeature feature) {
    final text = '${feature.name} ${feature.description}'.toLowerCase();
    if (text.contains('reaction')) return CombatActionTiming.reaction;
    if (_isActionSurgeText(text)) return CombatActionTiming.free;
    if (text.contains('bonus action') ||
        text.contains('rage') ||
        text.contains('second wind') ||
        text.contains('bardic inspiration')) {
      return CombatActionTiming.bonusAction;
    }
    if (text.contains('when you hit')) return CombatActionTiming.onHit;
    if (text.contains('when you take damage')) {
      return CombatActionTiming.onDamageTaken;
    }
    return CombatActionTiming.action;
  }

  static String _featureSourceLabel(CharacterFeature feature) {
    final source = feature.source.trim().toLowerCase();
    if (source.isEmpty) return 'Feature';
    if (source.contains('race') || source.contains('racial')) {
      return 'Racial Feature';
    }
    if (source.contains('feat')) return 'Feat Feature';
    if (source.contains('background')) return 'Background Feature';
    if (source.contains('subclass')) return 'Subclass Feature';
    if (source.contains('class')) return 'Class Feature';
    return '${source[0].toUpperCase()}${source.substring(1)} Feature';
  }

  static CombatActionTiming _timingForResource(CharacterResource resource) {
    final text = '${resource.name} ${resource.notes ?? ''}'.toLowerCase();
    if (text.contains('reaction')) return CombatActionTiming.reaction;
    if (_isActionSurgeText(text)) return CombatActionTiming.free;
    if (text.contains('bardic inspiration')) {
      return CombatActionTiming.bonusAction;
    }
    if (text.contains('inspiration')) return CombatActionTiming.free;
    if (text.contains('bonus')) return CombatActionTiming.bonusAction;
    return CombatActionTiming.action;
  }

  static String _resourceRechargeLabel(CharacterResource resource) {
    return switch (resource.rechargeType) {
      'shortRest' => 'Short Rest',
      'longRest' => 'Long Rest',
      _ => 'Manual',
    };
  }

  static bool _looksLikeHealing(String text) {
    final lower = text.toLowerCase();
    return lower.contains('heal') ||
        lower.contains('regain') ||
        lower.contains('recover') ||
        lower.contains('hit points');
  }

  static bool _isSecondWindText(String text) {
    final normalized = _normalizedSearchText(text);
    return normalized.contains('second wind') ||
        normalized.contains('segundo aliento');
  }

  static bool _isActionSurgeText(String text) {
    final lower = text.toLowerCase();
    final normalized = lower
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    return normalized.contains('action surge') ||
        normalized.contains('action sourge') ||
        (normalized.contains('action') &&
            (normalized.contains('surge') || normalized.contains('sourge'))) ||
        normalized.contains('additional action') ||
        normalized.contains('one additional action') ||
        normalized.contains('accion adicional') ||
        normalized.contains('oleada de accion');
  }

  static String _normalizedSearchText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('\u00e1', 'a')
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00ed', 'i')
        .replaceAll('\u00f3', 'o')
        .replaceAll('\u00fa', 'u')
        .replaceAll('\u00f1', 'n')
        .replaceAll('\u00c3\u00a1', 'a')
        .replaceAll('\u00c3\u00a9', 'e')
        .replaceAll('\u00c3\u00ad', 'i')
        .replaceAll('\u00c3\u00b3', 'o')
        .replaceAll('\u00c3\u00ba', 'u')
        .replaceAll('\u00c3\u00b1', 'n');
  }

  static String _combatantIdForCharacter(Character character) {
    return 'character_${character.id}';
  }

  static String _actionId(Character character, String source, String value) {
    return '${_combatantIdForCharacter(character)}_${source}_${_slug(value)}';
  }

  static String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
