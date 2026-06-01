import 'package:flutter/widgets.dart';

import 'dart:async';

import '../models/board_dice_roll_outcome.dart';
import '../models/board_token.dart';

class BattleBoardDiceBoxOverlay extends StatelessWidget {
  final String boardViewportId;
  final BoardToken? token;
  final double gridSize;
  final Future<bool> Function(BoardToken token)? onRollClaimRequested;
  final FutureOr<void> Function(BoardToken token, BoardDiceRollOutcome outcome)?
      onRollResolved;

  const BattleBoardDiceBoxOverlay({
    super.key,
    required this.boardViewportId,
    required this.token,
    required this.gridSize,
    this.onRollClaimRequested,
    this.onRollResolved,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
