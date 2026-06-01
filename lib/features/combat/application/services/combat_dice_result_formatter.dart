import 'dart:convert';

import '../../../dice/models/dice_roll_result.dart';

class CombatDiceResultFormatter {
  const CombatDiceResultFormatter._();

  static String? diceBoxNotation(DiceRollResult result) {
    if (result.firstD20 != null && result.secondD20 != null) {
      final modifier = _signedModifierText(result.flatModifier);
      return modifier == null ? '2d20' : '2d20$modifier';
    }

    final terms = result.terms
        .where((term) => term.diceCount > 0 && term.sides >= 2)
        .map((term) => '${term.diceCount}d${term.sides}')
        .toList(growable: false);

    if (terms.isEmpty) return null;
    final modifier = _signedModifierText(result.flatModifier);
    return '${terms.join('+')}${modifier ?? ''}';
  }

  static String authoritativeDiceJson(DiceRollResult result) {
    final dice = <Map<String, dynamic>>[];

    if (result.firstD20 != null && result.secondD20 != null) {
      dice.add({
        'sides': 20,
        'value': result.firstD20,
        'selected': result.firstD20 == result.selectedD20,
      });
      dice.add({
        'sides': 20,
        'value': result.secondD20,
        'selected': result.secondD20 == result.selectedD20,
      });
    } else if (result.terms.isNotEmpty) {
      for (final term in result.terms) {
        if (term.sides < 2) continue;
        for (final roll in term.rolls) {
          dice.add({
            'sides': term.sides,
            'value': roll,
            if (term.sign < 0) 'sign': -1,
          });
        }
      }
    } else if (result.sides >= 2) {
      for (final roll in result.rolls) {
        dice.add({
          'sides': result.sides,
          'value': roll,
        });
      }
    }

    return dice.isEmpty ? '' : jsonEncode(dice);
  }

  static String detail(DiceRollResult result) {
    final totalBreakdown = _diceTotalBreakdown(result);
    final breakdownSuffix =
        totalBreakdown == null ? '' : ' - $totalBreakdown = ${result.total}';
    return '${result.label} - ${result.formula}: ${result.rollsText}$breakdownSuffix';
  }

  static String? _signedModifierText(int modifier) {
    if (modifier == 0) return null;
    return modifier > 0 ? '+$modifier' : '$modifier';
  }

  static String? _diceTotalBreakdown(DiceRollResult result) {
    if (result.terms.isEmpty) return null;
    final diceSubtotal = result.terms.fold<int>(
      0,
      (sum, term) => sum + term.subtotal,
    );
    final modifier = result.flatModifier;
    final modifierText = _signedModifierText(modifier);

    if (result.firstD20 != null && result.secondD20 != null) {
      final selected = result.selectedD20 ?? diceSubtotal;
      return modifierText == null ? '$selected' : '$selected$modifierText';
    }

    return modifierText == null
        ? '$diceSubtotal'
        : '$diceSubtotal$modifierText';
  }
}
