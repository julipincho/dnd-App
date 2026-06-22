import 'package:flutter/material.dart';

import '../../../dice/models/dice_roll_result.dart';

enum CombatAccentKind { read, action, magic, support, info }

enum CombatLogEntryType { system, turn, roll }

class CombatRollFeedback {
  final String actor;
  final String action;
  final DiceRollResult? result;
  final String headline;
  final String? subline;
  final CombatAccentKind accentKind;

  const CombatRollFeedback({
    required this.actor,
    required this.action,
    required this.result,
    required this.headline,
    required this.subline,
    required this.accentKind,
  });

  const CombatRollFeedback.manual({
    required this.actor,
    required this.action,
    required this.headline,
    required this.subline,
    required this.accentKind,
  }) : result = null;
}

class CombatLogEntry {
  final String title;
  final String? detail;
  final IconData icon;
  final CombatLogEntryType type;

  const CombatLogEntry({
    required this.title,
    required this.detail,
    required this.icon,
    required this.type,
  });

  factory CombatLogEntry.system(String title) {
    return CombatLogEntry(
      title: title,
      detail: null,
      icon: Icons.info_outline,
      type: CombatLogEntryType.system,
    );
  }

  factory CombatLogEntry.turn(String title) {
    return CombatLogEntry(
      title: title,
      detail: null,
      icon: Icons.play_arrow_outlined,
      type: CombatLogEntryType.turn,
    );
  }

  factory CombatLogEntry.roll({
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

    return CombatLogEntry(
      title: '$prefix$actor used $action: ${result.total}',
      detail: detail ?? '${result.formula} - ${result.rollsText}',
      icon: result.isCriticalHit
          ? Icons.emergency_outlined
          : Icons.casino_outlined,
      type: CombatLogEntryType.roll,
    );
  }
}
