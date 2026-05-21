import 'package:flutter/widgets.dart';

import '../models/board_token.dart';

class BattleBoardDiceBoxOverlay extends StatelessWidget {
  final String boardViewportId;
  final BoardToken? token;
  final double gridSize;

  const BattleBoardDiceBoxOverlay({
    super.key,
    required this.boardViewportId,
    required this.token,
    required this.gridSize,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
