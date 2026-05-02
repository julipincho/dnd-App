import 'dart:math';

import '../models/dice_roll_result.dart';

class DiceRollerService {
  DiceRollerService._();

  static final Random _random = Random();
  static final RegExp _tokenPattern = RegExp(r'[+-]?[^+-]+');
  static final RegExp _diceTermPattern = RegExp(r'^(\d*)d(\d+)$');

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
        formula: modifier == 0
            ? '1d20'
            : modifier > 0
                ? '1d20+$modifier'
                : '1d20$modifier',
        flatModifier: modifier,
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
      formula: modifier == 0
          ? '${diceCount}d$sides'
          : modifier > 0
              ? '${diceCount}d$sides+$modifier'
              : '${diceCount}d$sides$modifier',
      flatModifier: modifier,
    );
  }

  static DiceRollResult rollFormula({
    required String formula,
    String label = 'Roll',
  }) {
    final normalized = formula.replaceAll(' ', '').toLowerCase();
    if (normalized.isEmpty) {
      throw const FormatException('Formula cannot be empty.');
    }

    final tokens = _tokenPattern
        .allMatches(normalized)
        .map((match) => match.group(0)!)
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      throw FormatException('Invalid dice formula: $formula');
    }

    final terms = <DiceRollTermResult>[];
    var flatModifier = 0;

    for (final rawToken in tokens) {
      var sign = 1;
      var token = rawToken;

      if (token.startsWith('+')) {
        token = token.substring(1);
      } else if (token.startsWith('-')) {
        sign = -1;
        token = token.substring(1);
      }

      if (token.isEmpty) {
        throw FormatException('Invalid dice formula: $formula');
      }

      final diceMatch = _diceTermPattern.firstMatch(token);
      if (diceMatch != null) {
        final countText = diceMatch.group(1)!;
        final diceCount = countText.isEmpty ? 1 : int.parse(countText);
        final sides = int.parse(diceMatch.group(2)!);

        if (diceCount < 1 || diceCount > 100 || sides < 2 || sides > 1000) {
          throw FormatException('Unsupported dice term: $rawToken');
        }

        final rolls = List.generate(
          diceCount,
          (_) => _random.nextInt(sides) + 1,
        );

        terms.add(
          DiceRollTermResult(
            diceCount: diceCount,
            sides: sides,
            rolls: rolls,
            sign: sign,
          ),
        );
        continue;
      }

      final flat = int.tryParse(token);
      if (flat == null) {
        throw FormatException('Invalid dice term: $rawToken');
      }

      flatModifier += flat * sign;
    }

    if (terms.isEmpty) {
      throw FormatException('Formula must include at least one dice term.');
    }

    final total =
        terms.fold<int>(0, (sum, term) => sum + term.subtotal) + flatModifier;
    final primary = terms.first;
    final allRolls = terms.expand((term) => term.rolls).toList();

    return DiceRollResult(
      sides: primary.sides,
      diceCount: primary.diceCount,
      rolls: allRolls,
      modifier: flatModifier,
      formula: _prettyFormula(normalized),
      terms: terms,
      flatModifier: flatModifier,
      advantage: false,
      disadvantage: false,
      total: total,
      timestamp: DateTime.now(),
      label: label,
    );
  }

  static String _prettyFormula(String normalized) {
    return normalized.replaceAllMapped(
      RegExp(r'([+-])'),
      (match) => ' ${match.group(1)} ',
    );
  }
}
