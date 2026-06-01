enum CombatTeam { party, enemy }

enum CombatActionRoll { attack, savingThrow, damage, critical }

enum CombatRollMode { normal, advantage, disadvantage }

enum CombatWorkspace { turn, log, overview }

class CombatCharacterSnapshot {
  final String characterId;
  final int currentHp;
  final int tempHp;
  final Map<String, int> resources;

  const CombatCharacterSnapshot({
    required this.characterId,
    required this.currentHp,
    required this.tempHp,
    required this.resources,
  });
}

class CombatActionEconomySnapshot {
  final bool actionSpent;
  final bool bonusActionSpent;
  final bool reactionSpent;
  final int movementAvailable;
  final String? readiedActionName;
  final String? readiedTrigger;

  const CombatActionEconomySnapshot({
    required this.actionSpent,
    required this.bonusActionSpent,
    required this.reactionSpent,
    required this.movementAvailable,
    required this.readiedActionName,
    required this.readiedTrigger,
  });
}

class CombatHpChangeResult {
  final int hp;
  final int tempHp;

  const CombatHpChangeResult({
    required this.hp,
    required this.tempHp,
  });
}
