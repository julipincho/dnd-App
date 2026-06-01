import 'dart:math' as math;

import '../../../dice/models/dice_roll_result.dart';
import 'combat_action.dart';
import 'combatant.dart';

class BoardActionRangeSnapshot {
  final Combatant actor;
  final Combatant target;
  final int distanceFeet;
  final int? rangeFeet;
  final bool isInRange;

  const BoardActionRangeSnapshot({
    required this.actor,
    required this.target,
    required this.distanceFeet,
    required this.rangeFeet,
    required this.isInRange,
  });
}

class PendingAreaSavingThrow {
  final String actorId;
  final String actionKey;
  final CombatAction action;
  final List<String> targetIds;
  final String? primaryTargetId;
  final String? diceTargetId;
  final math.Point<int>? areaAimPoint;
  final Map<String, PendingAreaSaveOutcome> outcomes = {};

  PendingAreaSavingThrow({
    required this.actorId,
    required this.actionKey,
    required this.action,
    required this.targetIds,
    required this.primaryTargetId,
    required this.diceTargetId,
    required this.areaAimPoint,
  });

  bool matches({
    required String actorId,
    required String actionKey,
  }) {
    return this.actorId == actorId && this.actionKey == actionKey;
  }

  List<String> get unresolvedTargetIds => targetIds
      .where((targetId) => !outcomes.containsKey(targetId))
      .toList(growable: false);

  bool get isComplete => unresolvedTargetIds.isEmpty;
}

class PendingAreaSaveOutcome {
  final DiceRollResult result;
  final bool success;

  const PendingAreaSaveOutcome({
    required this.result,
    required this.success,
  });
}

class SavingThrowDamageResolution {
  final int amount;
  final String? damageType;
  final List<String> notes;
  final CombatAction? absorbElementsAction;

  const SavingThrowDamageResolution({
    required this.amount,
    required this.damageType,
    required this.notes,
    required this.absorbElementsAction,
  });

  String get label {
    final typeLabel = damageType == null ? 'damage' : '$damageType damage';
    if (notes.isEmpty) return typeLabel;
    return '$typeLabel (${notes.join(', ')})';
  }

  String get labelSuffix {
    if (notes.isEmpty) return '';
    return ' (${notes.join(', ')})';
  }
}

class DamageTraitSnapshot {
  final bool resistant;
  final bool immune;
  final bool vulnerable;

  const DamageTraitSnapshot({
    this.resistant = false,
    this.immune = false,
    this.vulnerable = false,
  });
}

class PendingSavePromptData {
  final CombatAction action;
  final Combatant target;
  final String ability;
  final int dc;
  final String formula;
  final int remaining;

  const PendingSavePromptData({
    required this.action,
    required this.target,
    required this.ability,
    required this.dc,
    required this.formula,
    required this.remaining,
  });
}

class ReadiedAction {
  final String combatantId;
  final CombatAction action;
  final String trigger;
  final int round;
  final String? targetId;
  final bool concentrationRequired;

  const ReadiedAction({
    required this.combatantId,
    required this.action,
    required this.trigger,
    required this.round,
    required this.targetId,
    required this.concentrationRequired,
  });
}

class ReactionOption {
  final int actorIndex;
  final Combatant combatant;
  final CombatAction action;
  final bool spent;
  final bool readied;
  final String? trigger;

  const ReactionOption({
    required this.actorIndex,
    required this.combatant,
    required this.action,
    required this.spent,
    this.readied = false,
    this.trigger,
  });
}
