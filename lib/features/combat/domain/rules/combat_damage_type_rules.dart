class CombatDamageTypeRules {
  const CombatDamageTypeRules._();

  static const damageTypes = [
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

  static String? normalize(String? raw) {
    if (raw == null) return null;
    final text = raw.toLowerCase().replaceAll('-', ' ');
    for (final type in damageTypes) {
      if (text == type ||
          text.contains('$type damage') ||
          text.contains('damage $type') ||
          text.contains(type)) {
        return type;
      }
    }
    return null;
  }
}
