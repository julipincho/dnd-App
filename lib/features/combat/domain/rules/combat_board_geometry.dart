import 'dart:math' as math;
import 'dart:ui';

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

  static bool areaAffectsToken({
    required String shape,
    required int areaFeet,
    required BoardToken originToken,
    required BoardToken candidateToken,
    BoardToken? actorToken,
  }) {
    final normalizedShape = shape.toLowerCase().trim();
    if (areaFeet <= 0 || normalizedShape.isEmpty) return false;

    if (normalizedShape.contains('line')) {
      final actor = actorToken;
      if (actor == null) {
        return tokenCenterDistanceFeet(originToken, candidateToken) <= areaFeet;
      }
      return tokenIsInLineArea(
        actorToken: actor,
        targetToken: originToken,
        candidateToken: candidateToken,
        lengthFeet: areaFeet,
      );
    }

    if (normalizedShape.contains('cone')) {
      final actor = actorToken;
      if (actor == null) {
        return tokenCenterDistanceFeet(originToken, candidateToken) <= areaFeet;
      }
      return tokenIsInConeArea(
        actorToken: actor,
        targetToken: originToken,
        candidateToken: candidateToken,
        lengthFeet: areaFeet,
      );
    }

    if (normalizedShape.contains('cube')) {
      final origin = tokenCenterFeet(originToken);
      final candidate = tokenCenterFeet(candidateToken);
      final halfSideFeet = math.max(5.0, areaFeet / 2);
      return (candidate.dx - origin.dx).abs() <= halfSideFeet &&
          (candidate.dy - origin.dy).abs() <= halfSideFeet;
    }

    return tokenCenterDistanceFeet(originToken, candidateToken) <= areaFeet;
  }

  static bool tokenIsInLineArea({
    required BoardToken actorToken,
    required BoardToken targetToken,
    required BoardToken candidateToken,
    required int lengthFeet,
  }) {
    final start = tokenCenterFeet(actorToken);
    final aim = tokenCenterFeet(targetToken);
    final candidate = tokenCenterFeet(candidateToken);
    final direction = aim - start;
    final directionLength = direction.distance;
    if (directionLength <= 0.001) {
      return tokenCenterDistanceFeet(actorToken, candidateToken) <= 5;
    }

    final candidateVector = candidate - start;
    final projection = (candidateVector.dx * direction.dx +
            candidateVector.dy * direction.dy) /
        directionLength;
    if (projection < 0 || projection > lengthFeet) return false;

    final cross =
        (candidateVector.dx * direction.dy - candidateVector.dy * direction.dx)
            .abs();
    final perpendicular = cross / directionLength;
    final halfWidthFeet = 2.5 + candidateToken.size * 2.5;
    return perpendicular <= halfWidthFeet;
  }

  static bool tokenIsInConeArea({
    required BoardToken actorToken,
    required BoardToken targetToken,
    required BoardToken candidateToken,
    required int lengthFeet,
  }) {
    final start = tokenCenterFeet(actorToken);
    final aim = tokenCenterFeet(targetToken);
    final candidate = tokenCenterFeet(candidateToken);
    final direction = aim - start;
    final directionLength = direction.distance;
    if (directionLength <= 0.001) {
      return tokenCenterDistanceFeet(actorToken, candidateToken) <= lengthFeet;
    }

    final candidateVector = candidate - start;
    final candidateDistance = candidateVector.distance;
    if (candidateDistance <= 0.001) return true;
    if (candidateDistance > lengthFeet + candidateToken.size * 2.5) {
      return false;
    }

    final cosine = (candidateVector.dx * direction.dx +
            candidateVector.dy * direction.dy) /
        (candidateDistance * directionLength);
    const halfConeCosine = 0.8660254038; // 30 degrees.
    return cosine >= halfConeCosine;
  }

  static Offset tokenCenterFeet(BoardToken token) {
    return Offset(
      (token.x + token.size / 2) * 5,
      (token.y + token.size / 2) * 5,
    );
  }

  static double tokenCenterDistanceFeet(BoardToken a, BoardToken b) {
    return (tokenCenterFeet(a) - tokenCenterFeet(b)).distance;
  }
}
