enum PendingCombatAttackStatus {
  pending,
  damagePending,
  resolved,
  missed,
}

enum PendingCombatAttackSource {
  attackAction,
  extraAttack,
  martialArts,
  flurryOfBlows,
  multiattack,
}

class PendingCombatAttack {
  final int stepIndex;
  final String label;
  final PendingCombatAttackSource source;
  PendingCombatAttackStatus status;

  PendingCombatAttack({
    required this.stepIndex,
    required this.label,
    required this.source,
    this.status = PendingCombatAttackStatus.pending,
  });

  bool get resolved =>
      status == PendingCombatAttackStatus.resolved ||
      status == PendingCombatAttackStatus.missed;

  bool get damagePending => status == PendingCombatAttackStatus.damagePending;
}

class MultiAttackProgress {
  final String actionKey;
  final List<PendingCombatAttack> pendingAttacks;
  int stepIndex;
  int attackCount;
  int hitCount;
  int critCount;
  int totalDamage;
  int? pendingStepIndex;
  int? pendingTargetIndex;
  bool pendingCritical;
  String? lastHpLine;

  MultiAttackProgress({
    required this.actionKey,
    this.pendingAttacks = const [],
    this.stepIndex = 0,
    this.attackCount = 0,
    this.hitCount = 0,
    this.critCount = 0,
    this.totalDamage = 0,
    this.pendingStepIndex,
    this.pendingTargetIndex,
    this.pendingCritical = false,
    this.lastHpLine,
  });

  bool get hasPendingDamage =>
      pendingStepIndex != null && pendingTargetIndex != null;

  List<PendingCombatAttack> get unresolvedAttacks => pendingAttacks
      .where((attack) => !attack.resolved)
      .toList(growable: false);

  void clearPendingDamage() {
    if (pendingStepIndex != null) {
      markPending(pendingStepIndex!);
    }
    pendingStepIndex = null;
    pendingTargetIndex = null;
    pendingCritical = false;
  }

  void markPending(int index) {
    final attack = _attackByStepIndex(index);
    if (attack == null || attack.resolved) return;
    attack.status = PendingCombatAttackStatus.pending;
  }

  void markDamagePending(int index) {
    final attack = _attackByStepIndex(index);
    if (attack == null || attack.resolved) return;
    attack.status = PendingCombatAttackStatus.damagePending;
  }

  void markResolved(int index, {PendingCombatAttackStatus? status}) {
    final attack = _attackByStepIndex(index);
    if (attack == null) return;
    attack.status = status ?? PendingCombatAttackStatus.resolved;
  }

  PendingCombatAttack? _attackByStepIndex(int index) {
    for (final attack in pendingAttacks) {
      if (attack.stepIndex == index) return attack;
    }
    return null;
  }
}
