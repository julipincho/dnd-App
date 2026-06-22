import 'package:flutter/material.dart';

import '../../../domain/models/combat_feedback.dart';
import '../../../../../theme.dart';

Color combatAccentColorForKind(
  CombatAccentKind kind,
  StitchThemeTokens tokens,
) {
  return switch (kind) {
    CombatAccentKind.read => tokens.accentRead,
    CombatAccentKind.action => tokens.accentAction,
    CombatAccentKind.magic => tokens.accentMagic,
    CombatAccentKind.support => tokens.accentSuccess,
    CombatAccentKind.info => tokens.accentInfo,
  };
}
