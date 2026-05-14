class DiceRollTermResult {
  final int diceCount;
  final int sides;
  final List<int> rolls;
  final int sign;

  const DiceRollTermResult({
    required this.diceCount,
    required this.sides,
    required this.rolls,
    required this.sign,
  });

  int get subtotal => rolls.fold<int>(0, (sum, roll) => sum + roll) * sign;

  String get diceText {
    final prefix = sign < 0 ? '-' : '';
    return '$prefix${diceCount}d$sides';
  }
}

class DiceRollResult {
  final int sides;
  final int diceCount;
  final List<int> rolls;
  final int modifier;
  final String formula;
  final List<DiceRollTermResult> terms;
  final int flatModifier;
  final bool advantage;
  final bool disadvantage;
  final int? firstD20;
  final int? secondD20;
  final int? selectedD20;
  final int total;
  final DateTime timestamp;
  final String label;

  DiceRollResult({
    required this.sides,
    required this.diceCount,
    required this.rolls,
    required this.modifier,
    String? formula,
    List<DiceRollTermResult>? terms,
    int? flatModifier,
    required this.advantage,
    required this.disadvantage,
    required this.total,
    required this.timestamp,
    required this.label,
    this.firstD20,
    this.secondD20,
    this.selectedD20,
  })  : formula = formula ?? _legacyFormula(diceCount, sides, modifier),
        terms = terms ??
            [
              DiceRollTermResult(
                diceCount: diceCount,
                sides: sides,
                rolls: rolls,
                sign: 1,
              ),
            ],
        flatModifier = flatModifier ?? modifier;

  static String _legacyFormula(int diceCount, int sides, int modifier) {
    final modifierText = modifier == 0
        ? ''
        : modifier > 0
            ? '+$modifier'
            : '$modifier';
    return '${diceCount}d$sides$modifierText';
  }

  String get modifierText {
    if (flatModifier == 0) return '';
    return flatModifier > 0 ? '+$flatModifier' : '$flatModifier';
  }

  String get diceText {
    if (terms.isEmpty) return 'Fixed';
    return '${diceCount}d$sides';
  }

  bool get hasD20 => terms.any((term) => term.sides == 20);

  bool get isCriticalHit {
    if (selectedD20 != null) return selectedD20 == 20;
    return terms.any((term) => term.sides == 20 && term.rolls.contains(20));
  }

  bool get isCriticalMiss {
    if (selectedD20 != null) return selectedD20 == 1;
    return terms.any((term) => term.sides == 20 && term.rolls.contains(1));
  }

  String get outcomeLabel {
    if (isCriticalHit) return 'Critical';
    if (isCriticalMiss) return 'Natural 1';
    return 'Roll';
  }

  String get rollsText {
    if (firstD20 != null && secondD20 != null) {
      return '$firstD20, $secondD20 -> selected $selectedD20';
    }

    if (terms.isEmpty) {
      return 'fixed: $total';
    }

    return terms
        .map((term) => '${term.diceText}: ${term.rolls.join(', ')}')
        .join(' | ');
  }

  String get summaryText {
    if (sides == 20 && diceCount == 1 && (advantage || disadvantage)) {
      final mode = advantage ? 'ADV' : 'DIS';
      final modifierLabel = modifierText.isEmpty ? '' : ' $modifierText';
      return '$label - $mode - d20$modifierLabel = $total';
    }

    return '$label - $formula = $total';
  }
}
