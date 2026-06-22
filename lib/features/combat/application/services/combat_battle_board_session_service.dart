import '../../../../models/battle_scene.dart';

class CombatBattleBoardSessionService {
  const CombatBattleBoardSessionService._();

  static Map<String, dynamic> combatStatePayload({
    required bool combatStarted,
    required int round,
    required int activeIndex,
    required int targetIndex,
    required String selectedCommandTiming,
    required Map<String, int> movementUsedByCombatantId,
    required Map<String, int> actionAttackUsesByCombatantId,
    required Map<String, int> movementBonusFeetByCombatantId,
    required Set<String> spentTimings,
    required Set<String> pendingDamageActions,
    required Set<String> pendingHalfDamageActions,
    required Set<String> spentReactionCombatantIds,
    required Set<String> oncePerTurnActionUses,
    required String? focusedActionName,
    required Map<String, dynamic>? encounterJson,
    required DateTime updatedAt,
  }) {
    return {
      'version': 1,
      'combatStarted': combatStarted,
      'round': round,
      'activeIndex': activeIndex,
      'targetIndex': targetIndex,
      'selectedCommandTiming': selectedCommandTiming,
      'movementUsedByCombatantId':
          Map<String, int>.from(movementUsedByCombatantId),
      'actionAttackUsesByCombatantId':
          Map<String, int>.from(actionAttackUsesByCombatantId),
      'movementBonusFeetByCombatantId':
          Map<String, int>.from(movementBonusFeetByCombatantId),
      'spentTimings': spentTimings.toList(growable: false),
      'pendingDamageActions': pendingDamageActions.toList(growable: false),
      'pendingHalfDamageActions':
          pendingHalfDamageActions.toList(growable: false),
      'spentReactionCombatantIds':
          spentReactionCombatantIds.toList(growable: false),
      'oncePerTurnActionUses': oncePerTurnActionUses.toList(growable: false),
      'focusedActionName': focusedActionName,
      'encounter': encounterJson,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static Map<String, int> intMapFromState(
    Map<String, dynamic> state,
    String key,
  ) {
    final output = <String, int>{};
    final raw = state[key];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        output[entry.key.toString()] =
            value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      }
    }
    return output;
  }

  static Set<String> stringSetFromState(
    Map<String, dynamic> state,
    String key,
  ) {
    final raw = state[key];
    if (raw is Iterable) {
      return raw.map((item) => item.toString()).toSet();
    }
    return <String>{};
  }

  static BattleScene? latestResumableScene(
    List<BattleScene> scenes, {
    required String? campaignId,
  }) {
    final resolvedCampaignId = campaignId?.trim();
    final candidates = scenes
        .where(
          (scene) =>
              scene.combatActive &&
              scene.combatState.isNotEmpty &&
              scene.campaignId == resolvedCampaignId,
        )
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return candidates.isEmpty ? null : candidates.first;
  }

  static String displayUrl({
    required Uri baseUri,
    required String campaignId,
    required String sceneId,
  }) {
    final queryParameters = {
      'boardCampaignId': campaignId,
      'boardSceneId': sceneId,
      'mode': 'display',
    };
    if (baseUri.hasScheme &&
        (baseUri.scheme == 'http' || baseUri.scheme == 'https')) {
      return Uri.parse(baseUri.origin)
          .replace(
            path: '/',
            queryParameters: queryParameters,
          )
          .toString();
    }

    return Uri(
      path: '/',
      queryParameters: queryParameters,
    ).toString();
  }
}
