import 'package:flutter/material.dart';

import '../../../domain/models/combat_action.dart';
import '../../../domain/models/pending_combat_attack.dart';
import '../../../../../services/monk_combat_kit_service.dart';

class ClassCombatVisualIdentity {
  final String classKey;
  final String title;
  final String subtitle;
  final String resourceKey;
  final String resourceLabel;
  final IconData icon;
  final List<ClassPassiveTrait> passiveTraits;

  const ClassCombatVisualIdentity({
    required this.classKey,
    required this.title,
    required this.subtitle,
    required this.resourceKey,
    required this.resourceLabel,
    required this.icon,
    required this.passiveTraits,
  });
}

class ClassPassiveTrait {
  final String label;
  final String detail;
  final IconData icon;

  const ClassPassiveTrait({
    required this.label,
    required this.detail,
    required this.icon,
  });
}

class MonkCombatFlowState {
  final ClassCombatVisualIdentity identity;
  final MonkSubclassCombatProfile subclassProfile;
  final CombatAction flurryAction;
  final String resourceKey;
  final int remainingKi;
  final int maxKi;
  final int attackActionSlots;
  final int resolvedAttackActionAttacks;
  final CombatAction? martialArtsAction;
  final bool martialArtsActive;
  final bool martialArtsEnabled;
  final bool martialArtsPendingDamage;
  final bool flurryActive;
  final int flurryAttackIndex;
  final int flurryAttackTotal;
  final int remainingFlurryAttacks;
  final List<PendingCombatAttack> pendingAttacks;
  final bool openHandTechniqueAvailable;
  final bool flurryAlreadyUsedThisTurn;
  final bool enabled;
  final bool pendingDamage;
  final String status;
  final String ctaLabel;

  const MonkCombatFlowState({
    required this.identity,
    required this.subclassProfile,
    required this.flurryAction,
    required this.resourceKey,
    required this.remainingKi,
    required this.maxKi,
    required this.attackActionSlots,
    required this.resolvedAttackActionAttacks,
    required this.martialArtsAction,
    required this.martialArtsActive,
    required this.martialArtsEnabled,
    required this.martialArtsPendingDamage,
    required this.flurryActive,
    required this.flurryAttackIndex,
    required this.flurryAttackTotal,
    required this.remainingFlurryAttacks,
    required this.pendingAttacks,
    required this.openHandTechniqueAvailable,
    required this.flurryAlreadyUsedThisTurn,
    required this.enabled,
    required this.pendingDamage,
    required this.status,
    required this.ctaLabel,
  });
}
