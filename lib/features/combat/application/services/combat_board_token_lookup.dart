import '../../../../models/board_token.dart';

class CombatBoardTokenLookup {
  const CombatBoardTokenLookup._();

  static BoardToken? byRef(List<BoardToken> tokens, String refId) {
    for (final token in tokens) {
      if (token.refId == refId) return token;
    }
    return null;
  }

  static BoardToken? active(List<BoardToken> tokens) {
    for (final token in tokens) {
      if (token.isActive) return token;
    }
    return tokens.isEmpty ? null : tokens.first;
  }

  static BoardToken? targeted(List<BoardToken> tokens) {
    for (final token in tokens) {
      if (token.isTargeted) return token;
    }
    return null;
  }
}
