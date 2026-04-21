import 'dart:math';

import '../models/dice_roll_result.dart';

class DiceRollerService {
  DiceRollerService._();

  static final Random _random = Random();

  static DiceRollResult roll({
    required int sides,
    int diceCount = 1,
    int modifier = 0,
    bool advantage = false,
    bool disadvantage = false,
    String label = 'Roll',
  }) {
    assert(sides > 0, 'Dice sides must be greater than 0');
    assert(diceCount > 0, 'Dice count must be greater than 0');

    if (sides == 20 && diceCount == 1 && (advantage || disadvantage)) {
      final first = _random.nextInt(sides) + 1;
      final second = _random.nextInt(sides) + 1;
      final selected = advantage
          ? (first >= second ? first : second)
          : (first <= second ? first : second);

      return DiceRollResult(
        sides: sides,
        diceCount: diceCount,
        rolls: [selected],
        modifier: modifier,
        advantage: advantage,
        disadvantage: disadvantage,
        firstD20: first,
        secondD20: second,
        selectedD20: selected,
        total: selected + modifier,
        timestamp: DateTime.now(),
        label: label,
      );
    }

    final rolls = List.generate(
      diceCount,
      (_) => _random.nextInt(sides) + 1,
    );

    final total = rolls.fold<int>(0, (sum, roll) => sum + roll) + modifier;

    return DiceRollResult(
      sides: sides,
      diceCount: diceCount,
      rolls: rolls,
      modifier: modifier,
      advantage: false,
      disadvantage: false,
      total: total,
      timestamp: DateTime.now(),
      label: label,
    );
  }
}
