class RuleEngine {
  static int getAbilityModifier(int score) {
    return ((score - 10) / 2).floor();
  }

  static int getProficiencyBonus(int totalLevel) {
    if (totalLevel <= 0) return 2;
    return ((totalLevel - 1) ~/ 4) + 2;
  }

  static int getSavingThrow({
    required int abilityScore,
    required int totalLevel,
    required bool isProficient,
  }) {
    final base = getAbilityModifier(abilityScore);
    final proficiency = isProficient ? getProficiencyBonus(totalLevel) : 0;
    return base + proficiency;
  }

  static int getSkillBonus({
    required int abilityScore,
    required int totalLevel,
    required bool isProficient,
    bool hasExpertise = false,
  }) {
    final base = getAbilityModifier(abilityScore);
    final proficiencyBonus = getProficiencyBonus(totalLevel);

    int proficiency = 0;
    if (hasExpertise) {
      proficiency = proficiencyBonus * 2;
    } else if (isProficient) {
      proficiency = proficiencyBonus;
    }

    return base + proficiency;
  }

  static int getBaseSpeed({
    int? manualSpeed,
    int? raceSpeed,
    int? subraceSpeed,
  }) {
    if (manualSpeed != null && manualSpeed > 0) {
      return manualSpeed;
    }

    if (subraceSpeed != null && subraceSpeed > 0) {
      return subraceSpeed;
    }

    if (raceSpeed != null && raceSpeed > 0) {
      return raceSpeed;
    }

    return 30;
  }

  static int getEffectiveSpeed({
    int? manualSpeed,
    int? raceSpeed,
    int? subraceSpeed,
    int featSpeedBonus = 0,
  }) {
    final baseSpeed = getBaseSpeed(
      manualSpeed: manualSpeed,
      raceSpeed: raceSpeed,
      subraceSpeed: subraceSpeed,
    );

    return baseSpeed + featSpeedBonus;
  }
}
