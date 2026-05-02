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
  final Map<String, _CombatAction> _preparedActions = {};
  int _activeIndex = 0;
  int _targetIndex = 2;
  int _round = 1;
  String _selectedCommandTiming = 'Action';
  _CombatWorkspace _workspace = _CombatWorkspace.turn;
  bool _dmView = true;
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
    return _actionsForCombatant(_activeCombatant);
  }

  List<_CombatAction> _actionsForCombatant(_Combatant combatant) {
    return combatant.team == _CombatTeam.party
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
      _preparedActions.clear();
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
      _preparedActions.clear();
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
        final hpResult = _resolveHpChange(
          target,
          amount,
          healing: action.isHealing,
        );
        final nextCombatants = [..._combatants];
        nextCombatants[targetIndex] = target.copyWith(
          hp: hpResult.hp,
          tempHp: hpResult.tempHp,
        );
        _combatants = nextCombatants;

        final verb = action.isHealing ? 'recovers' : 'takes';
        final suffix = action.isHealing ? 'HP' : 'damage';
        headline = action.isHealing ? 'HEAL $amount' : '$amount DAMAGE';
        subline = _hpChangeLine(target, hpResult);
        feedbackKind = action.isHealing
            ? _CombatAccentKind.support
            : _CombatAccentKind.action;
        detail =
            '${result.formula} - ${result.rollsText}. ${target.name} $verb $amount $suffix (${_hpChangeLine(target, hpResult)}).';

        if (!action.isHealing && target.hp > 0 && hpResult.hp == 0) {
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
      final condition = _applyActionState(action);
      _activity.insert(
        0,
        _CombatLogEntry.system('${_activeCombatant.name} used ${action.name}.'),
      );
      _rollFeedback = _CombatRollFeedback.manual(
        actor: _activeCombatant.name,
        action: action.name,
        headline: condition == null ? 'READY' : condition.toUpperCase(),
        subline: condition == null
            ? action.tags.take(3).join(' - ')
            : '${_activeCombatant.name} is now $condition',
        accentKind: action.accentKind,
      );
    });
  }

  void _prepareAction(_CombatAction action) {
    setState(() {
      final current = _preparedActions[action.timing];
      if (current?.name == action.name && current?.type == action.type) {
        _preparedActions.remove(action.timing);
        _activity.insert(
          0,
          _CombatLogEntry.system('${action.name} removed from the turn plan.'),
        );
        return;
      }

      _preparedActions[action.timing] = action;
      _activity.insert(
        0,
        _CombatLogEntry.system('${action.name} prepared for ${action.timing}.'),
      );
    });
  }

  void _clearPreparedActions() {
    if (_preparedActions.isEmpty) return;
    setState(() {
      _preparedActions.clear();
      _activity.insert(0, _CombatLogEntry.system('Turn plan cleared.'));
    });
  }

  void _launchPreparedTurn() {
    if (_preparedActions.isEmpty) return;

    const order = ['Action', 'Bonus Action', 'Reaction', 'Movement'];
    final prepared = [
      for (final timing in order)
        if (_preparedActions[timing] != null) _preparedActions[timing]!,
    ];
    if (prepared.isEmpty) return;

    setState(() {
      _CombatRollFeedback? lastFeedback;
      _activity.insert(
        0,
        _CombatLogEntry.turn(
            '${_activeCombatant.name} launches the turn plan.'),
      );

      for (final action in prepared) {
        _spentTimings.add(action.timing);
        lastFeedback = _resolvePreparedAction(action);
      }

      _preparedActions.clear();
      if (lastFeedback != null) {
        _rollFeedback = lastFeedback;
      }
    });
  }

  void _runDemoRound() {
    setState(() {
      _preparedActions.clear();
      _spentTimings.clear();
      _activity.insert(
        0,
        _CombatLogEntry.system('Demo round starts. Every combatant acts once.'),
      );

      _CombatRollFeedback? lastFeedback;
      var lastActorIndex = _activeIndex;
      for (var index = 0; index < _combatants.length; index++) {
        if (_combatants[index].hp <= 0) continue;

        final targetIndex = _findDefaultTargetIndex(index);
        if (targetIndex == index) continue;

        final action = _demoActionFor(_actionsForCombatant(_combatants[index]));
        if (action == null) continue;

        lastActorIndex = index;
        _activity.insert(
          0,
          _CombatLogEntry.turn('${_combatants[index].name} demo turn.'),
        );
        lastFeedback = _resolvePreparedAction(
          action,
          actorIndex: index,
          forcedTargetIndex: targetIndex,
        );
      }

      _round += 1;
      _activeIndex = lastActorIndex.clamp(0, _combatants.length - 1).toInt();
      _targetIndex = _findDefaultTargetIndex(_activeIndex);
      _selectedCommandTiming = 'Action';
      _workspace = _CombatWorkspace.overview;
      _rollFeedback = lastFeedback;
      _activity.insert(
        0,
        _CombatLogEntry.system('Demo round resolved. Review overview state.'),
      );
    });
  }

  _CombatAction? _demoActionFor(List<_CombatAction> actions) {
    for (final action in actions) {
      if (action.attackFormula != null &&
          action.damageFormula != null &&
          !action.targetsSelf) {
        return action;
      }
    }
    for (final action in actions) {
      if (action.damageFormula != null && !action.targetsSelf) return action;
    }
    for (final action in actions) {
      if (action.attackFormula != null) return action;
    }
    return actions.isEmpty ? null : actions.first;
  }

  _CombatRollFeedback _resolvePreparedAction(
    _CombatAction action, {
    int? actorIndex,
    int? forcedTargetIndex,
  }) {
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final actor = _combatants[resolvedActorIndex];
    final resolvedTargetIndex =
        forcedTargetIndex ?? _findDefaultTargetIndex(resolvedActorIndex);
    final targetIndex =
        action.targetsSelf ? resolvedActorIndex : resolvedTargetIndex;
    var target = _combatants[targetIndex];

    if (action.attackFormula != null) {
      final attackResult = DiceRollerService.rollFormula(
        formula: action.attackFormula!,
        label: '${action.name} Attack',
      );
      final outcome = _attackOutcome(attackResult, target);
      final attackDetail =
          '${attackResult.formula} - ${attackResult.rollsText}. ${target.name} AC ${target.ac}: $outcome.';
      _activity.insert(
        0,
        _CombatLogEntry.roll(
          actor: actor.name,
          action: '${action.name} attack',
          result: attackResult,
          detail: attackDetail,
        ),
      );

      final didHit = outcome == 'hit' || outcome == 'critical hit';
      final damageFormula = outcome == 'critical hit'
          ? action.critFormula ?? action.damageFormula
          : action.damageFormula;
      if (didHit && damageFormula != null) {
        final damageResult = DiceRollerService.rollFormula(
          formula: damageFormula,
          label: '${action.name} Damage',
        );
        final amount = damageResult.total;
        final hpResult = _resolveHpChange(target, amount, healing: false);
        final nextCombatants = [..._combatants];
        nextCombatants[targetIndex] = target.copyWith(
          hp: hpResult.hp,
          tempHp: hpResult.tempHp,
        );
        _combatants = nextCombatants;
        final damageDetail =
            '${damageResult.formula} - ${damageResult.rollsText}. ${target.name} takes $amount damage (${_hpChangeLine(target, hpResult)}).';
        _activity.insert(
          0,
          _CombatLogEntry.roll(
            actor: actor.name,
            action: '${action.name} damage',
            result: damageResult,
            detail: damageDetail,
          ),
        );
        if (target.hp > 0 && hpResult.hp == 0) {
          _activity.insert(
              0, _CombatLogEntry.system('${target.name} is down.'));
          _targetIndex = _findDefaultTargetIndex(_activeIndex);
        }
        final headline = outcome == 'critical hit'
            ? 'CRIT $amount DAMAGE'
            : '$amount DAMAGE';
        return _CombatRollFeedback(
          actor: actor.name,
          action: action.name,
          result: damageResult,
          headline: headline,
          subline: _hpChangeLine(target, hpResult),
          accentKind: outcome == 'critical hit'
              ? _CombatAccentKind.support
              : _CombatAccentKind.action,
        );
      }

      return _CombatRollFeedback(
        actor: actor.name,
        action: action.name,
        result: attackResult,
        headline: outcome.toUpperCase(),
        subline: '${actor.name} vs ${target.name} AC ${target.ac}',
        accentKind: switch (outcome) {
          'critical hit' => _CombatAccentKind.support,
          'hit' => _CombatAccentKind.action,
          'automatic miss' => _CombatAccentKind.info,
          _ => _CombatAccentKind.read,
        },
      );
    }

    if (action.damageFormula != null) {
      final result = DiceRollerService.rollFormula(
        formula: action.damageFormula!,
        label: action.isHealing ? '${action.name} Heal' : '${action.name} Use',
      );
      final amount = result.total;
      final hpResult = _resolveHpChange(
        target,
        amount,
        healing: action.isHealing,
      );
      final nextCombatants = [..._combatants];
      nextCombatants[targetIndex] = target.copyWith(
        hp: hpResult.hp,
        tempHp: hpResult.tempHp,
      );
      _combatants = nextCombatants;

      final verb = action.isHealing ? 'recovers' : 'takes';
      final suffix = action.isHealing ? 'HP' : 'damage';
      final detail =
          '${result.formula} - ${result.rollsText}. ${target.name} $verb $amount $suffix (${_hpChangeLine(target, hpResult)}).';
      _activity.insert(
        0,
        _CombatLogEntry.roll(
          actor: actor.name,
          action: action.name,
          result: result,
          detail: detail,
        ),
      );
      if (!action.isHealing && target.hp > 0 && hpResult.hp == 0) {
        _activity.insert(0, _CombatLogEntry.system('${target.name} is down.'));
        _targetIndex = _findDefaultTargetIndex(_activeIndex);
      }
      return _CombatRollFeedback(
        actor: actor.name,
        action: action.name,
        result: result,
        headline: action.isHealing ? 'HEAL $amount' : '$amount DAMAGE',
        subline: _hpChangeLine(target, hpResult),
        accentKind: action.isHealing
            ? _CombatAccentKind.support
            : _CombatAccentKind.action,
      );
    }

    _activity.insert(
      0,
      _CombatLogEntry.system('${actor.name} used ${action.name}.'),
    );
    final condition = _applyActionState(action, actorIndex: resolvedActorIndex);
    return _CombatRollFeedback.manual(
      actor: actor.name,
      action: action.name,
      headline: condition == null ? 'USED' : condition.toUpperCase(),
      subline: condition == null
          ? action.tags.take(3).join(' - ')
          : '${actor.name} is now $condition',
      accentKind: action.accentKind,
    );
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

  _HpChangeResult _resolveHpChange(
    _Combatant target,
    int amount, {
    required bool healing,
  }) {
    if (healing) {
      return _HpChangeResult(
        hp: (target.hp + amount).clamp(0, target.maxHp).toInt(),
        tempHp: target.tempHp,
      );
    }

    final absorbedByTemp = math.min(target.tempHp, amount);
    final remainingDamage = amount - absorbedByTemp;
    return _HpChangeResult(
      hp: (target.hp - remainingDamage).clamp(0, target.maxHp).toInt(),
      tempHp: target.tempHp - absorbedByTemp,
    );
  }

  String _hpChangeLine(_Combatant before, _HpChangeResult after) {
    String label(int hp, int maxHp, int tempHp) {
      final temp = tempHp > 0 ? ' +$tempHp temp' : '';
      return '$hp/$maxHp$temp';
    }

    return '${before.name}: ${label(before.hp, before.maxHp, before.tempHp)} -> ${label(after.hp, before.maxHp, after.tempHp)} HP';
  }

  String? _applyActionState(_CombatAction action, {int? actorIndex}) {
    final index =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final actor = _combatants[index];
    final condition = _conditionFromAction(action);
    if (condition == null) return null;
    if (actor.conditions.contains(condition)) return condition;

    final nextCombatants = [..._combatants];
    nextCombatants[index] = actor.copyWith(
      conditions: [condition, ...actor.conditions],
    );
    _combatants = nextCombatants;
    _activity.insert(
      0,
      _CombatLogEntry.system('${actor.name} gains $condition.'),
    );
    return condition;
  }

  String? _conditionFromAction(_CombatAction action) {
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    if (text.contains('rage')) return 'Raging';
    if (text.contains('bardic inspiration')) return 'Bardic Inspiration';
    if (text.contains('inspiration')) return 'Inspired';
    if (text.contains('concentration')) return 'Concentrating';
    return null;
  }

  void _selectCommandTiming(String timing) {
    setState(() {
      _selectedCommandTiming = timing;
    });
  }

  void _selectFocusedCombatant(int index) {
    if (index < 0 || index >= _combatants.length) return;
    setState(() {
      _activeIndex = index;
      _targetIndex = _findDefaultTargetIndex(index);
      _spentTimings.clear();
      _preparedActions.clear();
      _selectedCommandTiming = 'Action';
      _rollFeedback = null;
      _workspace = _CombatWorkspace.turn;
      _activity.insert(
        0,
        _CombatLogEntry.system('${_combatants[index].name} is focused.'),
      );
    });
  }

  void _selectWorkspace(_CombatWorkspace workspace) {
    setState(() {
      _workspace = workspace;
    });
  }

  void _toggleDmView() {
    setState(() {
      _dmView = !_dmView;
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
                        preparedActions: _preparedActions,
                        selectedCommandTiming: _selectedCommandTiming,
                        workspace: _workspace,
                        showEnemyHp: _dmView,
                        entries: _activity,
                        onBack: () => Navigator.of(context).maybePop(),
                        onRequestInitiative: _requestInitiative,
                        onRollInitiative: _rollInitiativeForAll,
                        onNextTurn: _nextTurn,
                        onToggleDmView: _toggleDmView,
                        onRunDemo: _runDemoRound,
                        onSelectTarget: _selectTarget,
                        onSelectFocusedCombatant: _selectFocusedCombatant,
                        onSelectWorkspace: _selectWorkspace,
                        onSelectCommandTiming: _selectCommandTiming,
                        onRollAction: _rollAction,
                        onUseAction: _useAction,
                        onPrepareAction: _prepareAction,
                        onLaunchPreparedTurn: _launchPreparedTurn,
                        onClearPreparedActions: _clearPreparedActions,
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
        portraitAsset: 'assets/images/races/half-orc.png',
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
        portraitAsset: 'assets/images/classes/wizard.png',
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
        portraitAsset: 'assets/images/races/hobgoblin.png',
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
        portraitAsset: 'assets/images/races/goblin.png',
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
    final rawTempHp = character.tempHp ?? 0;
    final tempHp = rawTempHp < 0 ? 0 : rawTempHp;
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

    final name = character.name.trim().isEmpty ? 'Hero' : character.name.trim();
    final role = [
      if (race.isNotEmpty) race,
      character.classProgressionLabel,
    ].join(' - ');

    return _Combatant(
      name: name,
      role: role,
      initiative: 10 + initiativeBonus,
      initiativeBonus: initiativeBonus,
      hp: currentHp,
      maxHp: maxHp,
      tempHp: tempHp,
      ac: effectiveAc,
      speed: (character.speed ?? 30) + character.featSpeedBonus,
      team: _CombatTeam.party,
      portraitAsset: _combatantPortraitAsset(
        name: name,
        role: role,
        team: _CombatTeam.party,
      ),
      conditions: [
        'Player Character',
        ..._derivedCombatSignals(character),
      ],
    );
  }

  List<String> _derivedCombatSignals(Character character) {
    final signals = <String>[];
    for (final resource in character.resources) {
      final name = resource.name.trim();
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      final tracked = lower.contains('rage') ||
          lower.contains('bardic') ||
          lower.contains('inspiration') ||
          lower.contains('ki') ||
          lower.contains('sorcery') ||
          lower.contains('channel') ||
          lower.contains('divinity') ||
          lower.contains('lay on hands');
      if (!tracked) continue;
      signals.add('$name ${resource.current}/${resource.max}');
    }

    final hasSpellcasting = character.spellIds.isNotEmpty ||
        character.preparedSpellIds.isNotEmpty ||
        character.preparedSpells.isNotEmpty;
    if (hasSpellcasting) signals.add('Spellcasting');

    void addNamedSignals(String prefix, Iterable<String> values,
        {int max = 2}) {
      for (final value in values) {
        final label = value.trim();
        if (label.isEmpty) continue;
        signals.add('$prefix: $label');
        if (signals.where((item) => item.startsWith(prefix)).length >= max) {
          break;
        }
      }
    }

    addNamedSignals('Resist', [
      ...character.racialResistances,
      ...character.featResistances,
    ]);
    addNamedSignals('Immune', [
      ...character.racialImmunities,
      ...character.featImmunities,
    ]);
    addNamedSignals('Sense', [
      ...character.racialSenses,
      ...character.featSenses,
    ]);
    addNamedSignals(
        'Cond Immune',
        [
          ...character.racialConditionImmunities,
          ...character.featConditionImmunities,
        ],
        max: 1);

    if (character.cannotBeSurprisedWhileConscious) {
      signals.add('Cannot be surprised');
    }
    if (character.unseenAttackersNoAdvantage) {
      signals.add('No unseen advantage');
    }
    if (character.conditionalArmorClassBonus != 0) {
      final condition = character.conditionalArmorClassBonusCondition;
      signals.add(
        condition == null || condition.trim().isEmpty
            ? 'AC +${character.conditionalArmorClassBonus}'
            : 'AC +${character.conditionalArmorClassBonus} ${condition.trim()}',
      );
    }
    if (character.featSpeedBonus != 0) {
      signals.add('Speed +${character.featSpeedBonus}');
    }

    final racialFeatures = character.features.where((feature) {
      final source = feature.source.toLowerCase();
      return source.contains('race') || source.contains('racial');
    });
    for (final feature in racialFeatures.take(2)) {
      final name = feature.name.trim();
      if (name.isNotEmpty) signals.add(name);
    }

    return signals.take(9).toList();
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
  final Map<String, _CombatAction> preparedActions;
  final String selectedCommandTiming;
  final _CombatWorkspace workspace;
  final bool showEnemyHp;
  final List<_CombatLogEntry> entries;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;
  final ValueChanged<_CombatWorkspace> onSelectWorkspace;
  final ValueChanged<String> onSelectCommandTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;

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
    required this.preparedActions,
    required this.selectedCommandTiming,
    required this.workspace,
    required this.showEnemyHp,
    required this.entries,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
    required this.onSelectWorkspace,
    required this.onSelectCommandTiming,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideWidth = constraints.maxWidth >= 1240 ? 268.0 : 238.0;
          const gap = 12.0;
          const topHeight = 72.0;
          const modeHeight = 46.0;
          final stageTop = topHeight + gap + modeHeight + gap;
          final preferredBottomHeight =
              constraints.maxHeight >= 720 ? 284.0 : 264.0;
          final maxBottomHeight = constraints.maxHeight - stageTop - gap - 248;
          final bottomHeight = math.min(
            preferredBottomHeight,
            math.max(236.0, maxBottomHeight),
          );
          final stageBottom = bottomHeight + gap;
          final isTurnView = workspace == _CombatWorkspace.turn;
          final stageLeft = isTurnView ? sideWidth + gap : 0.0;
          const stageRight = 0.0;

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
                  showEnemyHp: showEnemyHp,
                  onBack: onBack,
                  onRequestInitiative: onRequestInitiative,
                  onRollInitiative: onRollInitiative,
                  onNextTurn: onNextTurn,
                  onToggleDmView: onToggleDmView,
                  onRunDemo: onRunDemo,
                  onSelectCombatant: onSelectFocusedCombatant,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: topHeight + gap,
                height: modeHeight,
                child: _CombatModeBar(
                  workspace: workspace,
                  onSelectWorkspace: onSelectWorkspace,
                ),
              ),
              if (isTurnView)
                Positioned(
                  left: 0,
                  top: stageTop,
                  width: sideWidth,
                  bottom: stageBottom,
                  child: _GameCombatantPanel(
                    title: 'Focused Turn',
                    combatant: activeCombatant,
                    accentKind: _CombatAccentKind.info,
                    showEnemyHp: showEnemyHp,
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
                  workspace: workspace,
                  showEnemyHp: showEnemyHp,
                  onSelectTarget: onSelectTarget,
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                width: isTurnView ? sideWidth : null,
                right: isTurnView ? null : 0,
                height: bottomHeight,
                child: _GameFeedWindow(entries: entries),
              ),
              if (isTurnView)
                Positioned(
                  left: stageLeft,
                  right: 0,
                  bottom: 0,
                  height: bottomHeight,
                  child: _CommandLayerDock(
                    activeCombatant: activeCombatant,
                    selectedTarget: selectedTarget,
                    actions: actions,
                    spentTimings: spentTimings,
                    preparedActions: preparedActions,
                    selectedTiming: selectedCommandTiming,
                    onSelectTiming: onSelectCommandTiming,
                    onRollAction: onRollAction,
                    onUseAction: onUseAction,
                    onPrepareAction: onPrepareAction,
                    onLaunchPreparedTurn: onLaunchPreparedTurn,
                    onClearPreparedActions: onClearPreparedActions,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CombatModeBar extends StatelessWidget {
  final _CombatWorkspace workspace;
  final ValueChanged<_CombatWorkspace> onSelectWorkspace;

  const _CombatModeBar({
    required this.workspace,
    required this.onSelectWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.tune_outlined, color: tokens.accentInfo, size: 16),
                const SizedBox(width: 8),
                Text(
                  workspace == _CombatWorkspace.turn
                      ? 'Turn workspace'
                      : 'Encounter overview',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _WorkspaceToggle(
            selected: workspace,
            onSelect: onSelectWorkspace,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceToggle extends StatelessWidget {
  final _CombatWorkspace selected;
  final ValueChanged<_CombatWorkspace> onSelect;

  const _WorkspaceToggle({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WorkspaceToggleButton(
            label: 'Turn',
            icon: Icons.ads_click_outlined,
            selected: selected == _CombatWorkspace.turn,
            onTap: () => onSelect(_CombatWorkspace.turn),
          ),
          const SizedBox(width: 3),
          _WorkspaceToggleButton(
            label: 'Overview',
            icon: Icons.grid_view_outlined,
            selected: selected == _CombatWorkspace.overview,
            onTap: () => onSelect(_CombatWorkspace.overview),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = selected ? tokens.accentMagic : tokens.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.22 : 0.04),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.45 : 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTopHud extends StatelessWidget {
  final int round;
  final List<_Combatant> combatants;
  final int activeIndex;
  final bool showEnemyHp;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectCombatant;

  const _GameTopHud({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.showEnemyHp,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectCombatant,
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
                      onTap: () => onSelectCombatant(index),
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
            onPressed: onToggleDmView,
            icon: Icon(
              showEnemyHp
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 16,
            ),
            label: Text(showEnemyHp ? 'DM View' : 'Player View'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: (showEnemyHp ? tokens.accentWarning : tokens.accentRead)
                    .withValues(alpha: 0.30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
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
          OutlinedButton.icon(
            onPressed: onRunDemo,
            icon: const Icon(Icons.play_circle_outline, size: 16),
            label: const Text('Run Demo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                  color: tokens.accentAction.withValues(alpha: 0.30)),
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
  final VoidCallback onTap;

  const _TurnOrderAvatar({
    required this.combatant,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent =
        isActive ? tokens.accentInfo : _teamColor(combatant.team, tokens);

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 54,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isActive ? 44 : 38,
            height: isActive ? 44 : 38,
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
                  size: 18,
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
        ),
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
  final bool showEnemyHp;

  const _GameCombatantPanel({
    required this.title,
    required this.combatant,
    required this.accentKind,
    this.showEnemyHp = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(accentKind, tokens);
    final isDown = combatant.hp <= 0;
    final showHp = _canShowHp(combatant, showEnemyHp);
    final statusLabels = [
      if (combatant.tempHp > 0) 'Temp HP ${combatant.tempHp}',
      ...combatant.conditions.take(7),
    ];

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 78,
              child: _CombatantPortraitFrame(
                combatant: combatant,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              combatant.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
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
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              child: LinearProgressIndicator(
                value: showHp ? combatant.hpRatio : 1,
                minHeight: 11,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  !showHp
                      ? tokens.textMuted
                      : isDown
                          ? tokens.textMuted
                          : combatant.hpRatio <= 0.30
                              ? tokens.accentAction
                              : tokens.accentSuccess,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _GameMetric(
                    label: 'HP',
                    value: _compactHpLabel(combatant, showEnemyHp),
                  ),
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
            if (statusLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: statusLabels.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    return _StatusChip(
                      label: statusLabels[index],
                      color: accent,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CombatantPortraitFrame extends StatelessWidget {
  final _Combatant combatant;
  final Color color;

  const _CombatantPortraitFrame({
    required this.combatant,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _CombatantArtwork(
              combatant: combatant,
              color: color,
              iconSize: 54,
            ),
          ),
        ],
      ),
    );
  }
}

class _CombatantArtwork extends StatelessWidget {
  final _Combatant combatant;
  final Color color;
  final double iconSize;

  const _CombatantArtwork({
    required this.combatant,
    required this.color,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = _PortraitIconFallback(
      combatant: combatant,
      color: color,
      iconSize: iconSize,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (combatant.portraitAsset == null)
          fallback
        else
          Image.asset(
            combatant.portraitAsset!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PortraitIconFallback extends StatelessWidget {
  final _Combatant combatant;
  final Color color;
  final double iconSize;

  const _PortraitIconFallback({
    required this.combatant,
    required this.color,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color.withValues(alpha: 0.10),
      child: Center(
        child: Icon(
          _portraitIconForCombatant(combatant),
          color: Colors.white.withValues(alpha: 0.92),
          size: iconSize,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

class _GameBattleStage extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _CombatRollFeedback? rollFeedback;
  final _CombatWorkspace workspace;
  final bool showEnemyHp;
  final ValueChanged<int> onSelectTarget;

  const _GameBattleStage({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.rollFeedback,
    required this.workspace,
    required this.showEnemyHp,
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
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: workspace == _CombatWorkspace.overview
                  ? _EncounterOverviewStage(
                      combatants: combatants,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      rollFeedback: rollFeedback,
                      showEnemyHp: showEnemyHp,
                    )
                  : _FocusedTurnStage(
                      combatants: combatants,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      activeCombatant: combatants[activeIndex],
                      selectedTarget: combatants[targetIndex],
                      rollFeedback: rollFeedback,
                      showEnemyHp: showEnemyHp,
                      onSelectTarget: onSelectTarget,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusedTurnStage extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final _CombatRollFeedback? rollFeedback;
  final bool showEnemyHp;
  final ValueChanged<int> onSelectTarget;

  const _FocusedTurnStage({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.rollFeedback,
    required this.showEnemyHp,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _CombatDiceTheater(
            feedback: rollFeedback,
            activeCombatant: activeCombatant,
            selectedTarget: selectedTarget,
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 300,
          child: _SelectedTargetPortraitCard(
            combatants: combatants,
            activeIndex: activeIndex,
            targetIndex: targetIndex,
            combatant: selectedTarget,
            showEnemyHp: showEnemyHp,
            onSelectTarget: onSelectTarget,
          ),
        ),
      ],
    );
  }
}

class _EncounterOverviewStage extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _CombatRollFeedback? rollFeedback;
  final bool showEnemyHp;

  const _EncounterOverviewStage({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.rollFeedback,
    required this.showEnemyHp,
  });

  @override
  Widget build(BuildContext context) {
    final party = <_IndexedCombatant>[];
    final enemies = <_IndexedCombatant>[];
    for (var index = 0; index < combatants.length; index++) {
      final entry = _IndexedCombatant(index, combatants[index]);
      if (entry.combatant.team == _CombatTeam.party) {
        party.add(entry);
      } else {
        enemies.add(entry);
      }
    }

    return Row(
      children: [
        Expanded(
          child: _EncounterTeamColumn(
            title: 'Party',
            entries: party,
            activeIndex: activeIndex,
            targetIndex: targetIndex,
            showEnemyHp: showEnemyHp,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _EncounterTeamColumn(
            title: 'Enemies',
            entries: enemies,
            activeIndex: activeIndex,
            targetIndex: targetIndex,
            showEnemyHp: showEnemyHp,
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 248,
          child: _OverviewRollSummary(feedback: rollFeedback),
        ),
      ],
    );
  }
}

class _EncounterTeamColumn extends StatelessWidget {
  final String title;
  final List<_IndexedCombatant> entries;
  final int activeIndex;
  final int targetIndex;
  final bool showEnemyHp;

  const _EncounterTeamColumn({
    required this.title,
    required this.entries,
    required this.activeIndex,
    required this.targetIndex,
    required this.showEnemyHp,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final isParty = title.toLowerCase() == 'party';
    final color = isParty ? tokens.accentRead : tokens.accentAction;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isParty ? Icons.groups_2_outlined : Icons.crisis_alert_outlined,
                color: color,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${entries.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _OverviewCombatantCard(
                  entry: entry,
                  isActive: entry.index == activeIndex,
                  isTargeted: entry.index == targetIndex,
                  showEnemyHp: showEnemyHp,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCombatantCard extends StatelessWidget {
  final _IndexedCombatant entry;
  final bool isActive;
  final bool isTargeted;
  final bool showEnemyHp;

  const _OverviewCombatantCard({
    required this.entry,
    required this.isActive,
    required this.isTargeted,
    required this.showEnemyHp,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final combatant = entry.combatant;
    final accent = isTargeted
        ? tokens.accentAction
        : isActive
            ? tokens.accentInfo
            : _teamColor(combatant.team, tokens);
    final showHp = _canShowHp(combatant, showEnemyHp);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isActive || isTargeted ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: accent.withValues(alpha: isActive || isTargeted ? 0.48 : 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.42)),
            ),
            child: Text(
              '${combatant.initiative}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        combatant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.22)),
                      ),
                      child: Text(
                        _compactHpLabel(combatant, showEnemyHp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: showHp ? Colors.white : tokens.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isActive || isTargeted) const SizedBox(width: 6),
                    if (isActive)
                      Icon(Icons.play_arrow_rounded,
                          color: tokens.accentInfo, size: 18)
                    else if (isTargeted)
                      Icon(Icons.my_location_outlined,
                          color: tokens.accentAction, size: 16),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: showHp ? combatant.hpRatio : 1,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      showHp ? tokens.accentSuccess : tokens.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'AC ${combatant.ac}   ${combatant.role}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewRollSummary extends StatelessWidget {
  final _CombatRollFeedback? feedback;

  const _OverviewRollSummary({
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = feedback == null
        ? tokens.accentMagic
        : _accentForKind(feedback!.accentKind, tokens);
    final result = feedback?.result;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'LAST ROLL',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: _LargeDiceBadge(
                total: result?.total,
                formula: result?.formula,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feedback?.headline ?? 'No roll yet',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          if (feedback?.subline != null) ...[
            const SizedBox(height: 5),
            Text(
              feedback!.subline!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CombatDiceTheater extends StatelessWidget {
  final _CombatRollFeedback? feedback;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;

  const _CombatDiceTheater({
    required this.feedback,
    required this.activeCombatant,
    required this.selectedTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = feedback == null
        ? tokens.accentMagic
        : _accentForKind(feedback!.accentKind, tokens);
    final result = feedback?.result;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            accent.withValues(alpha: 0.24),
            tokens.surface.withValues(alpha: 0.48),
            Colors.black.withValues(alpha: 0.20),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.casino_outlined, color: accent, size: 17),
              const SizedBox(width: 7),
              Text(
                'ROLL FEEDBACK',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${activeCombatant.name} -> ${selectedTarget.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Column(
                  key: ValueKey(feedback?.headline ?? 'empty-dice'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LargeDiceBadge(
                      total: result?.total,
                      formula: result?.formula,
                      color: accent,
                    ),
                    const SizedBox(height: 9),
                    if (feedback == null)
                      Text(
                        'Choose target and roll.',
                        key: const ValueKey('empty-dice-copy'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else ...[
                      Text(
                        feedback!.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      if (feedback!.subline != null &&
                          feedback!.subline!.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          feedback!.subline!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
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
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeDiceBadge extends StatelessWidget {
  final int? total;
  final String? formula;
  final Color color;

  const _LargeDiceBadge({
    required this.total,
    required this.formula,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -math.pi / 10,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.76),
                  tokens.surfaceRaised.withValues(alpha: 0.96),
                  Colors.black.withValues(alpha: 0.74),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.30),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: math.pi / 10,
              child: total == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.casino_outlined,
                            color: Colors.white, size: 24),
                        const SizedBox(height: 3),
                        Text(
                          'D20',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          formula ?? 'Waiting for the roll',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SelectedTargetPortraitCard extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _Combatant combatant;
  final bool showEnemyHp;
  final ValueChanged<int> onSelectTarget;

  const _SelectedTargetPortraitCard({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.combatant,
    required this.showEnemyHp,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(combatant.team, tokens);
    final showHp = _canShowHp(combatant, showEnemyHp);
    final validTargets = <int>[
      for (var index = 0; index < combatants.length; index++)
        if (index != activeIndex &&
            combatants[index].team != combatants[activeIndex].team &&
            combatants[index].hp > 0)
          index,
    ];

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.26),
            tokens.surfaceRaised.withValues(alpha: 0.94),
            tokens.surface.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.44)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -22,
            child: Icon(
              _portraitIconForCombatant(combatant),
              color: Colors.white.withValues(alpha: 0.055),
              size: 164,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  combatant.team == _CombatTeam.enemy
                      ? 'CURRENT TARGET'
                      : 'SELECTED ALLY',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (validTargets.isNotEmpty) ...[
                  _TargetChoiceRail(
                    combatants: combatants,
                    targetIndexes: validTargets,
                    selectedIndex: targetIndex,
                    onSelectTarget: onSelectTarget,
                  ),
                  const SizedBox(height: 10),
                ],
                Expanded(
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(color: accent.withValues(alpha: 0.20)),
                    ),
                    child: _CombatantArtwork(
                      combatant: combatant,
                      color: accent,
                      iconSize: 78,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  combatant.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: showHp ? combatant.hpRatio : 1,
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      showHp ? accent : tokens.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: _GameMetric(
                        label: 'HP',
                        value: _compactHpLabel(combatant, showEnemyHp),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GameMetric(label: 'AC', value: '${combatant.ac}'),
                    ),
                  ],
                ),
                if (combatant.conditions.isNotEmpty) ...[
                  const SizedBox(height: 8),
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
          ),
        ],
      ),
    );
  }
}

class _TargetChoiceRail extends StatelessWidget {
  final List<_Combatant> combatants;
  final List<int> targetIndexes;
  final int selectedIndex;
  final ValueChanged<int> onSelectTarget;

  const _TargetChoiceRail({
    required this.combatants,
    required this.targetIndexes,
    required this.selectedIndex,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: targetIndexes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final combatantIndex = targetIndexes[index];
          final combatant = combatants[combatantIndex];
          final selected = combatantIndex == selectedIndex;
          final color = selected ? tokens.accentAction : tokens.accentRead;

          return InkWell(
            onTap: () => onSelectTarget(combatantIndex),
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              constraints: const BoxConstraints(maxWidth: 138),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.24 : 0.10),
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                border: Border.all(
                  color: color.withValues(alpha: selected ? 0.56 : 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected
                        ? Icons.my_location_outlined
                        : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      combatant.name,
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
        },
      ),
    );
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
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.045);
    const cell = 112.0;
    for (var x = -cell; x < size.width + cell; x += cell) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + size.height * 0.34, size.height);
      canvas.drawPath(path, gridPaint);
    }

    final pathPaint = Paint()
      ..color = tokens.accentSuccess.withValues(alpha: 0.11);
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.76)
      ..lineTo(size.width * 0.38, size.height * 0.44)
      ..lineTo(size.width * 0.74, size.height * 0.70)
      ..lineTo(size.width * 0.48, size.height * 0.94)
      ..close();
    canvas.drawPath(path, pathPaint);

    final dangerPaint = Paint()
      ..color = tokens.accentAction.withValues(alpha: 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.78, size.height * 0.44),
        width: size.width * 0.30,
        height: size.height * 0.36,
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
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final List<_CombatAction> actions;
  final Set<String> spentTimings;
  final Map<String, _CombatAction> preparedActions;
  final String selectedTiming;
  final ValueChanged<String> onSelectTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;

  const _CommandLayerDock({
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.spentTimings,
    required this.preparedActions,
    required this.selectedTiming,
    required this.onSelectTiming,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
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
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 140,
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
                            preparedActions: preparedActions,
                            onRollAction: onRollAction,
                            onUseAction: onUseAction,
                            onPrepareAction: onPrepareAction,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: _PreparedTurnPanel(
              activeCombatant: activeCombatant,
              selectedTarget: selectedTarget,
              preparedActions: preparedActions,
              spentTimings: spentTimings,
              onLaunch: onLaunchPreparedTurn,
              onClear: onClearPreparedActions,
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
  final Map<String, _CombatAction> preparedActions;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;

  const _ActionLayerWindow({
    super.key,
    required this.timing,
    required this.actions,
    required this.preparedActions,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
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
            width: 238,
            child: _CompactActionCommand(
              action: actions[index],
              isPrepared: preparedActions[timing]?.name == actions[index].name,
              onRollAction: onRollAction,
              onUseAction: onUseAction,
              onPrepareAction: onPrepareAction,
            ),
          );
        },
      ),
    );
  }
}

class _CompactActionCommand extends StatelessWidget {
  final _CombatAction action;
  final bool isPrepared;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;

  const _CompactActionCommand({
    required this.action,
    required this.isPrepared,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(action.accentKind, tokens);

    return Container(
      padding: const EdgeInsets.all(8),
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
              const SizedBox(width: 6),
              _PrepareActionButton(
                selected: isPrepared,
                color: accent,
                onTap: () => onPrepareAction(action),
              ),
              const SizedBox(width: 5),
              _ActionDetailsButton(action: action, color: accent),
            ],
          ),
          const SizedBox(height: 5),
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
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final tag in action.tags.take(2))
                _DiceExpressionChip(label: tag, color: accent),
            ],
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
        height: 28,
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

class _PrepareActionButton extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PrepareActionButton({
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 27,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: (selected ? color : Colors.white).withValues(
            alpha: selected ? 0.26 : 0.07,
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.58 : 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_outline : Icons.add_circle_outline,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              selected ? 'Ready' : 'Prepare',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionDetailsButton extends StatelessWidget {
  final _CombatAction action;
  final Color color;

  const _ActionDetailsButton({
    required this.action,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: () => _showActionDetails(context, action),
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        width: 27,
        height: 27,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: const Icon(
          Icons.info_outline,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}

class _PreparedTurnPanel extends StatelessWidget {
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final Map<String, _CombatAction> preparedActions;
  final Set<String> spentTimings;
  final VoidCallback onLaunch;
  final VoidCallback onClear;

  const _PreparedTurnPanel({
    required this.activeCombatant,
    required this.selectedTarget,
    required this.preparedActions,
    required this.spentTimings,
    required this.onLaunch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Movement'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentAction.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 184,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.playlist_add_check_circle_outlined,
                        color: tokens.accentAction, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PREPARED TURN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _PreparedTurnContext(
                    activeCombatant: activeCombatant,
                    selectedTarget: selectedTarget,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: timings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final timing = timings[index];
                final action = preparedActions[timing];
                return SizedBox(
                  width: 154,
                  child: _PreparedTurnSlot(
                    timing: timing,
                    action: action,
                    spent: spentTimings.contains(timing),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: preparedActions.isEmpty ? null : onClear,
            icon: const Icon(Icons.close, size: 17),
            color: Colors.white,
            disabledColor: tokens.textMuted,
            tooltip: 'Clear prepared turn',
          ),
          FilledButton.icon(
            onPressed: preparedActions.isEmpty ? null : onLaunch,
            icon: const Icon(Icons.casino_outlined, size: 15),
            label: const Text('Execute'),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accentAction,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
              disabledForegroundColor: tokens.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparedTurnContext extends StatelessWidget {
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;

  const _PreparedTurnContext({
    required this.activeCombatant,
    required this.selectedTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: tokens.accentMagic.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin_circle_outlined,
              color: tokens.accentInfo, size: 14),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              activeCombatant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: tokens.textMuted, size: 14),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              selectedTarget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparedTurnSlot extends StatelessWidget {
  final String timing;
  final _CombatAction? action;
  final bool spent;

  const _PreparedTurnSlot({
    required this.timing,
    required this.action,
    required this.spent,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = spent
        ? tokens.accentAction
        : action == null
            ? tokens.textMuted
            : _accentForKind(action!.accentKind, tokens);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: action == null ? 0.07 : 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            spent
                ? Icons.check_circle_outline
                : action == null
                    ? Icons.circle_outlined
                    : action!.icon,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action?.name ?? 'Open',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 58),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Text(
              _preparedActionFormula(action),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: action == null ? tokens.textMuted : Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
    final tokens = context.stitch;
    final effectiveColor = _statusAccentForLabel(label, tokens, color);
    final icon = _statusIconForLabel(label);

    return Container(
      constraints: const BoxConstraints(maxWidth: 176),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CombatTeam { party, enemy }

enum _CombatActionRoll { attack, damage, critical }

enum _CombatWorkspace { turn, overview }

enum _CombatAccentKind { read, action, magic, support, info }

enum _CombatLogEntryType { system, turn, roll }

class _Combatant {
  final String name;
  final String role;
  final int initiative;
  final int initiativeBonus;
  final int hp;
  final int maxHp;
  final int tempHp;
  final int ac;
  final int speed;
  final _CombatTeam team;
  final String? portraitAsset;
  final List<String> conditions;

  const _Combatant({
    required this.name,
    required this.role,
    required this.initiative,
    required this.initiativeBonus,
    required this.hp,
    required this.maxHp,
    this.tempHp = 0,
    required this.ac,
    required this.speed,
    required this.team,
    this.portraitAsset,
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
    int? tempHp,
    int? ac,
    int? speed,
    String? portraitAsset,
    List<String>? conditions,
  }) {
    return _Combatant(
      name: name,
      role: role,
      initiative: initiative ?? this.initiative,
      initiativeBonus: initiativeBonus,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      tempHp: tempHp ?? this.tempHp,
      ac: ac ?? this.ac,
      speed: speed ?? this.speed,
      team: team,
      portraitAsset: portraitAsset ?? this.portraitAsset,
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

class _HpChangeResult {
  final int hp;
  final int tempHp;

  const _HpChangeResult({
    required this.hp,
    required this.tempHp,
  });
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

Color _statusAccentForLabel(
  String label,
  StitchThemeTokens tokens,
  Color fallback,
) {
  final text = label.toLowerCase();
  if (text.contains('temp hp')) return tokens.accentInfo;
  if (text.contains('rage') || text.contains('raging')) {
    return tokens.accentAction;
  }
  if (text.contains('bardic') || text.contains('inspiration')) {
    return tokens.accentMagic;
  }
  if (text.contains('concentrat')) return tokens.accentSuccess;
  if (text.contains('ki') || text.contains('sorcery')) return tokens.accentRead;
  if (text.contains('down')) return tokens.textMuted;
  return fallback;
}

IconData _statusIconForLabel(String label) {
  final text = label.toLowerCase();
  if (text.contains('temp hp')) return Icons.health_and_safety_outlined;
  if (text.contains('rage') || text.contains('raging')) {
    return Icons.local_fire_department_outlined;
  }
  if (text.contains('bardic') || text.contains('inspiration')) {
    return Icons.auto_awesome_outlined;
  }
  if (text.contains('concentrat')) return Icons.psychology_alt_outlined;
  if (text.contains('ki')) return Icons.bolt_outlined;
  if (text.contains('sorcery')) return Icons.blur_on_outlined;
  if (text.contains('spell')) return Icons.menu_book_outlined;
  if (text.contains('resist')) return Icons.shield_outlined;
  if (text.contains('immune')) return Icons.verified_user_outlined;
  if (text.contains('speed')) return Icons.directions_run_outlined;
  return Icons.adjust_outlined;
}

String? _combatantPortraitAsset({
  required String name,
  required String role,
  required _CombatTeam team,
}) {
  final text = '$name $role'.toLowerCase();

  String? match(Map<String, String> lookup) {
    for (final entry in lookup.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  const races = {
    'half-orc': 'half-orc',
    'half orc': 'half-orc',
    'half-elf': 'half-elf',
    'half elf': 'half-elf',
    'dragonborn': 'dragonborn',
    'hobgoblin': 'hobgoblin',
    'goblin': 'goblin',
    'centaur': 'centaur',
    'aasimar': 'aasimar',
    'tiefling': 'tiefling',
    'warforged': 'warforged',
    'goliath': 'goliath',
    'halfling': 'halfling',
    'lizardfolk': 'lizardfolk',
    'bugbear': 'bugbear',
    'kobold': 'kobold',
    'firbolg': 'firbolg',
    'dwarf': 'dwarf',
    'elf': 'elf',
    'orc': 'orc',
    'human': 'human',
  };

  const classes = {
    'barbarian': 'barbarian',
    'paladin': 'paladin',
    'blood hunter': 'fighter',
    'fighter': 'fighter',
    'wizard': 'wizard',
    'warlock': 'warlock',
    'sorcerer': 'sorcerer',
    'cleric': 'cleric',
    'druid': 'druid',
    'bard': 'bard',
    'monk': 'monk',
    'rogue': 'rogue',
    'ranger': 'ranger',
    'artificer': 'artificer',
  };

  final race = match(races);
  if (race != null) return 'assets/images/races/$race.png';

  if (team == _CombatTeam.party) {
    final characterClass = match(classes);
    if (characterClass != null) {
      return 'assets/images/classes/$characterClass.png';
    }
  }

  return null;
}

IconData _portraitIconForCombatant(_Combatant combatant) {
  final text = '${combatant.name} ${combatant.role}'.toLowerCase();
  if (combatant.team == _CombatTeam.party) {
    if (text.contains('wizard') ||
        text.contains('warlock') ||
        text.contains('sorcerer')) {
      return Icons.auto_awesome_outlined;
    }
    if (text.contains('monk')) return Icons.sports_martial_arts_outlined;
    if (text.contains('paladin') || text.contains('fighter')) {
      return Icons.shield_outlined;
    }
    return Icons.person_4_outlined;
  }
  if (text.contains('dragon')) return Icons.local_fire_department_outlined;
  if (text.contains('archer') || text.contains('bow')) {
    return Icons.ads_click_outlined;
  }
  if (text.contains('goblin')) return Icons.crisis_alert_outlined;
  if (text.contains('undead') || text.contains('shadow')) {
    return Icons.nights_stay_outlined;
  }
  return Icons.flare_outlined;
}

bool _canShowHp(_Combatant combatant, bool showEnemyHp) {
  return combatant.team == _CombatTeam.party || showEnemyHp;
}

String _compactHpLabel(_Combatant combatant, bool showEnemyHp) {
  if (!_canShowHp(combatant, showEnemyHp)) return 'Hidden';
  if (combatant.tempHp > 0) {
    return '${combatant.hp}/${combatant.maxHp} +${combatant.tempHp}';
  }
  return '${combatant.hp}/${combatant.maxHp}';
}

String _preparedActionFormula(_CombatAction? action) {
  if (action == null) return 'Open';
  return action.attackFormula ??
      action.damageFormula ??
      action.critFormula ??
      'Use';
}

void _showActionDetails(BuildContext context, _CombatAction action) {
  final tokens = context.stitch;
  final accent = _accentForKind(action.accentKind, tokens);

  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: tokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          side: BorderSide(color: accent.withValues(alpha: 0.34)),
        ),
        title: Row(
          children: [
            Icon(action.icon, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                action.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionDetailLine(label: 'Type', value: action.type),
            _ActionDetailLine(label: 'Timing', value: action.timing),
            if (action.attackFormula != null)
              _ActionDetailLine(label: 'Attack', value: action.attackFormula!),
            if (action.damageFormula != null)
              _ActionDetailLine(
                  label: action.isHealing ? 'Healing' : 'Damage',
                  value: action.damageFormula!),
            if (action.critFormula != null)
              _ActionDetailLine(label: 'Critical', value: action.critFormula!),
            if (action.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in action.tags)
                    _DiceExpressionChip(label: tag, color: accent),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _ActionDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _ActionDetailLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
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

IconData _featureIcon(CharacterFeature feature) {
  final text = '${feature.name} ${feature.description}'.toLowerCase();
  final source = feature.source.toLowerCase();
  if (source.contains('race') || source.contains('racial')) {
    return Icons.auto_awesome_motion_outlined;
  }
  if (source.contains('feat')) return Icons.workspace_premium_outlined;
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
