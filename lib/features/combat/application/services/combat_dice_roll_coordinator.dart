import '../../../../models/board_token.dart';
import '../../../../providers/battle_board_provider.dart';
import '../../../dice/models/dice_roll_result.dart';

class CombatDiceRollCoordinator {
  static const defaultTimeout = Duration(seconds: 12);
  static const defaultPollInterval = Duration(milliseconds: 120);

  String? _lastBoardResolvedRollEventId;

  String nextEventId() {
    return 'combat-roll-${DateTime.now().microsecondsSinceEpoch}';
  }

  String? consumeBoardResolvedRollEventId() {
    final eventId = _lastBoardResolvedRollEventId;
    _lastBoardResolvedRollEventId = null;
    return eventId;
  }

  Future<BoardToken?> waitForBattleBoardRollResult({
    required BattleBoardProvider boardProvider,
    required String sceneId,
    required String eventId,
    bool Function()? isActive,
    Duration timeout = defaultTimeout,
    Duration pollInterval = defaultPollInterval,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while ((isActive?.call() ?? true) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      if (!(isActive?.call() ?? true)) return null;
      for (final token in boardProvider.tokens) {
        if (token.sceneId == sceneId &&
            token.lastEventId == eventId &&
            token.lastEventRollValues.isNotEmpty) {
          _lastBoardResolvedRollEventId = eventId;
          return token;
        }
      }
    }
    return null;
  }

  DiceRollResult rollResultFromBoardToken(
    DiceRollResult fallback,
    BoardToken token,
  ) {
    final values = token.lastEventRollValues;
    if (values.isEmpty) return fallback;

    if (fallback.firstD20 != null && fallback.secondD20 != null) {
      final first = values[0];
      final second = values.length > 1 ? values[1] : fallback.secondD20!;
      final selected = fallback.advantage
          ? (first >= second ? first : second)
          : (first <= second ? first : second);
      final terms = fallback.terms
          .map(
            (term) => term.sides == 20 && term.diceCount == 1
                ? DiceRollTermResult(
                    diceCount: term.diceCount,
                    sides: term.sides,
                    rolls: [selected],
                    sign: term.sign,
                  )
                : term,
          )
          .toList(growable: false);
      return DiceRollResult(
        sides: fallback.sides,
        diceCount: fallback.diceCount,
        rolls: [selected],
        modifier: fallback.modifier,
        formula: fallback.formula,
        terms: terms,
        flatModifier: fallback.flatModifier,
        advantage: fallback.advantage,
        disadvantage: fallback.disadvantage,
        firstD20: first,
        secondD20: second,
        selectedD20: selected,
        total: selected + fallback.flatModifier,
        timestamp: DateTime.now(),
        label: fallback.label,
      );
    }

    var valueIndex = 0;
    final nextTerms = <DiceRollTermResult>[];
    for (final term in fallback.terms) {
      final rolls = <int>[];
      for (var index = 0; index < term.diceCount; index++) {
        if (valueIndex < values.length) {
          rolls.add(values[valueIndex]);
          valueIndex++;
        } else if (index < term.rolls.length) {
          rolls.add(term.rolls[index]);
        }
      }
      nextTerms.add(
        DiceRollTermResult(
          diceCount: term.diceCount,
          sides: term.sides,
          rolls: rolls,
          sign: term.sign,
        ),
      );
    }

    final total = nextTerms.fold<int>(
          0,
          (sum, term) => sum + term.subtotal,
        ) +
        fallback.flatModifier;
    final primary = nextTerms.isEmpty ? null : nextTerms.first;

    return DiceRollResult(
      sides: primary?.sides ?? fallback.sides,
      diceCount: primary?.diceCount ?? fallback.diceCount,
      rolls: nextTerms.expand((term) => term.rolls).toList(growable: false),
      modifier: fallback.modifier,
      formula: fallback.formula,
      terms: nextTerms,
      flatModifier: fallback.flatModifier,
      advantage: fallback.advantage,
      disadvantage: fallback.disadvantage,
      total: total,
      timestamp: DateTime.now(),
      label: fallback.label,
    );
  }
}
