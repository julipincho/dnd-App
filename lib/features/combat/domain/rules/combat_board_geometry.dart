import 'dart:math' as math;

import '../../../../models/board_token.dart';

class CombatBoardGeometry {
  const CombatBoardGeometry._();

  static int distanceFeet(BoardToken a, BoardToken b) {
    final dx = axisDistanceSquares(
      a.x,
      a.x + a.size - 1,
      b.x,
      b.x + b.size - 1,
    );
    final dy = axisDistanceSquares(
      a.y,
      a.y + a.size - 1,
      b.y,
      b.y + b.size - 1,
    );
    return math.max(dx, dy) * 5;
  }

  static int axisDistanceSquares(
    int aStart,
    int aEnd,
    int bStart,
    int bEnd,
  ) {
    if (aEnd < bStart) return bStart - aEnd;
    if (bEnd < aStart) return aStart - bEnd;
    return 0;
  }
}
