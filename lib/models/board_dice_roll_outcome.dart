class BoardDiceRollOutcome {
  final int total;
  final int diceTotal;
  final List<int> values;
  final String label;
  final String detail;

  const BoardDiceRollOutcome({
    required this.total,
    required this.diceTotal,
    required this.values,
    required this.label,
    required this.detail,
  });
}
