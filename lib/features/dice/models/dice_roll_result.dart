class DiceRollResult {
  final int sides;
  final int diceCount;
  final List<int> rolls;
  final int modifier;
  final bool advantage;
  final bool disadvantage;
  final int? firstD20;
  final int? secondD20;
  final int? selectedD20;
  final int total;
  final DateTime timestamp;
  final String label;

  const DiceRollResult({
    required this.sides,
    required this.diceCount,
    required this.rolls,
    required this.modifier,
    required this.advantage,
    required this.disadvantage,
    required this.total,
    required this.timestamp,
    required this.label,
    this.firstD20,
    this.secondD20,
    this.selectedD20,
  });

  String get modifierText {
    if (modifier == 0) return '';
    return modifier > 0 ? '+$modifier' : '$modifier';
  }

  String get diceText {
    return '${diceCount}d$sides';
  }

  String get summaryText {
    if (sides == 20 && diceCount == 1 && (advantage || disadvantage)) {
      final mode = advantage ? 'ADV' : 'DIS';
      return '$label • $mode • d20 ${modifierText.isNotEmpty ? modifierText : ''} = $total';
    }

    return '$label • $diceText ${modifierText.isNotEmpty ? modifierText : ''} = $total';
  }
}
