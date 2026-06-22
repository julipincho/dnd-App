class CombatBoardTokenSizing {
  const CombatBoardTokenSizing._();

  static int sizeForRole(String role) {
    final normalized = role.toLowerCase();
    if (normalized.contains('gargantuan') || normalized.contains('colossal')) {
      return 4;
    }
    if (normalized.contains('huge') || normalized.contains('enorme')) {
      return 3;
    }
    if (normalized.contains('large') || normalized.contains('grande')) {
      return 2;
    }
    return 1;
  }
}
