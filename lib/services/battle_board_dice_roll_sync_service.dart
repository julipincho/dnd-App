import 'dart:math' as math;

import '../models/board_dice_roll_outcome.dart';
import '../models/board_token.dart';
import '../providers/battle_board_provider.dart';

class BattleBoardDiceRollSyncService {
  final BattleBoardProvider boardProvider;
  final String campaignId;
  final String ownerId;

  const BattleBoardDiceRollSyncService({
    required this.boardProvider,
    required this.campaignId,
    required this.ownerId,
  });

  static String createOwnerId({String prefix = 'board'}) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-'
        '${math.Random().nextInt(0x7fffffff)}';
  }

  Future<bool> claim(BoardToken token) {
    if (token.lastEventId.isEmpty) return Future.value(false);
    if (token.lastEventRollValues.isNotEmpty) return Future.value(false);

    return boardProvider.claimDiceRollEvent(
      campaignId: campaignId,
      token: token,
      ownerId: ownerId,
      lockDuration: const Duration(seconds: 3),
    );
  }

  Future<bool> saveOutcomeIfClaimed(
    BoardToken token,
    BoardDiceRollOutcome outcome,
  ) {
    final current = _currentToken(token);
    if (current.lastEventId != token.lastEventId) return Future.value(false);
    if (current.lastEventRollValues.isNotEmpty) return Future.value(false);
    if (current.lastEventRollTotal == outcome.total &&
        current.lastEventRollDiceTotal == outcome.diceTotal &&
        _intListsMatch(current.lastEventRollValues, outcome.values)) {
      return Future.value(true);
    }

    return boardProvider.saveDiceRollOutcomeIfClaimed(
      campaignId: campaignId,
      token: current,
      ownerId: ownerId,
      total: outcome.total,
      diceTotal: outcome.diceTotal,
      values: outcome.values,
      label:
          outcome.label.isEmpty ? current.lastEventResultLabel : outcome.label,
      detail: outcome.detail.isEmpty
          ? current.lastEventResultDetail
          : outcome.detail,
    );
  }

  BoardToken _currentToken(BoardToken token) {
    for (final item in boardProvider.tokens) {
      if (item.id == token.id) return item;
    }
    return token;
  }

  bool _intListsMatch(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
