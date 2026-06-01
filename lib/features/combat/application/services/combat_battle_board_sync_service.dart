import '../../../../models/board_token.dart';
import '../../../../providers/battle_board_provider.dart';

class CombatBoardSyncCombatant {
  final String id;
  final String name;
  final String imageUrl;
  final String team;
  final int hp;
  final int maxHp;
  final int initiative;
  final String role;
  final int speedFeet;
  final int tokenSize;
  final List<String> conditions;

  const CombatBoardSyncCombatant({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.team,
    required this.hp,
    required this.maxHp,
    required this.initiative,
    required this.role,
    required this.speedFeet,
    required this.tokenSize,
    required this.conditions,
  });
}

class CombatBoardSyncFocus {
  final String actionName;
  final int rangeFeet;
  final String areaShape;
  final int areaFeet;
  final int targetDistanceFeet;
  final bool targetInRange;

  const CombatBoardSyncFocus({
    required this.actionName,
    required this.rangeFeet,
    required this.areaShape,
    required this.areaFeet,
    required this.targetDistanceFeet,
    required this.targetInRange,
  });

  static const empty = CombatBoardSyncFocus(
    actionName: '',
    rangeFeet: 0,
    areaShape: '',
    areaFeet: 0,
    targetDistanceFeet: 0,
    targetInRange: true,
  );
}

class CombatBoardEventSyncPayload {
  final String? label;
  final String kind;
  final String diceNotation;
  final String? diceColorHex;
  final String resultLabel;
  final String resultDetail;
  final String authoritativeDice;
  final String? eventIdOverride;
  final String damageType;
  final Set<String> targetIds;
  final String? diceTargetId;
  final String? sourceRefId;
  final String? primaryTargetRefId;
  final String areaShape;
  final int areaFeet;
  final int? areaTargetX;
  final int? areaTargetY;

  const CombatBoardEventSyncPayload({
    required this.label,
    required this.kind,
    required this.diceNotation,
    required this.diceColorHex,
    required this.resultLabel,
    required this.resultDetail,
    required this.authoritativeDice,
    required this.eventIdOverride,
    required this.damageType,
    required this.targetIds,
    required this.diceTargetId,
    required this.sourceRefId,
    required this.primaryTargetRefId,
    required this.areaShape,
    required this.areaFeet,
    required this.areaTargetX,
    required this.areaTargetY,
  });
}

class CombatBoardSyncResult {
  final String? eventId;

  const CombatBoardSyncResult({required this.eventId});
}

class CombatBattleBoardSyncService {
  const CombatBattleBoardSyncService();

  List<BoardToken> buildInitialTokens({
    required String sceneId,
    required List<CombatBoardSyncCombatant> combatants,
    required Map<String, int> movementUsedByCombatantId,
    required String activeCombatantId,
    required String selectedTargetId,
    required CombatBoardSyncFocus focus,
  }) {
    final party = combatants
        .where((combatant) => combatant.team == 'party')
        .toList(growable: false);
    final enemies = combatants
        .where((combatant) => combatant.team != 'party')
        .toList(growable: false);
    final tokens = <BoardToken>[];

    var partyX = 3;
    var partyY = 4;
    var partyRowHeight = 1;
    for (final combatant in party) {
      final isActive = combatant.id == activeCombatantId;
      final isTargeted = combatant.id == selectedTargetId;
      final tokenSize = combatant.tokenSize;
      if (partyX + tokenSize > 9) {
        partyX = 3;
        partyY += partyRowHeight + 1;
        partyRowHeight = 1;
      }
      final x = partyX;
      final y = partyY;
      partyX += tokenSize + 1;
      if (tokenSize > partyRowHeight) partyRowHeight = tokenSize;
      tokens.add(
        _createToken(
          sceneId: sceneId,
          combatant: combatant,
          type: 'character',
          x: x,
          y: y,
          isActive: isActive,
          isTargeted: isTargeted,
          focus: focus,
          movementUsed: movementUsedByCombatantId[combatant.id] ?? 0,
        ),
      );
    }

    var enemyX = 16;
    var enemyY = 4;
    var enemyRowHeight = 1;
    for (final combatant in enemies) {
      final isActive = combatant.id == activeCombatantId;
      final isTargeted = combatant.id == selectedTargetId;
      final tokenSize = combatant.tokenSize;
      if (enemyX + tokenSize > 22) {
        enemyX = 16;
        enemyY += enemyRowHeight + 1;
        enemyRowHeight = 1;
      }
      final x = enemyX;
      final y = enemyY;
      enemyX += tokenSize + 1;
      if (tokenSize > enemyRowHeight) enemyRowHeight = tokenSize;
      tokens.add(
        _createToken(
          sceneId: sceneId,
          combatant: combatant,
          type: 'monster',
          x: x,
          y: y,
          isActive: isActive,
          isTargeted: isTargeted,
          focus: focus,
          movementUsed: movementUsedByCombatantId[combatant.id] ?? 0,
        ),
      );
    }

    return tokens;
  }

  BoardToken _createToken({
    required String sceneId,
    required CombatBoardSyncCombatant combatant,
    required String type,
    required int x,
    required int y,
    required bool isActive,
    required bool isTargeted,
    required CombatBoardSyncFocus focus,
    required int movementUsed,
  }) {
    return BoardToken.create(
      id: '${sceneId}_${combatant.id}',
      sceneId: sceneId,
      refId: combatant.id,
      type: type,
      name: combatant.name,
      imageUrl: combatant.imageUrl,
      x: x,
      y: y,
      size: combatant.tokenSize,
      currentHp: combatant.hp,
      maxHp: combatant.maxHp,
      initiative: combatant.initiative,
      role: combatant.role,
      speedFeet: combatant.speedFeet,
      movementUsedFeet: movementUsed,
      movementOriginX: x,
      movementOriginY: y,
      selectedActionRangeFeet: isActive ? focus.rangeFeet : 0,
      selectedActionAreaShape: isActive ? focus.areaShape : '',
      selectedActionAreaFeet: isActive ? focus.areaFeet : 0,
      targetDistanceFeet: isActive || isTargeted ? focus.targetDistanceFeet : 0,
      conditions: combatant.conditions,
      isActive: isActive,
      isTargeted: isTargeted,
      isTargetInRange: isActive || isTargeted ? focus.targetInRange : true,
      focusedActionName: isActive ? focus.actionName : '',
    );
  }

  Future<CombatBoardSyncResult> syncTokens({
    required BattleBoardProvider boardProvider,
    required String campaignId,
    required String sceneId,
    required List<CombatBoardSyncCombatant> combatants,
    required Map<String, int> movementUsedByCombatantId,
    required String activeCombatantId,
    required String selectedTargetId,
    required CombatBoardSyncFocus focus,
    required String defaultDiceColorHex,
    required Duration eventVisibleDuration,
    required DateTime now,
    required CombatBoardEventSyncPayload event,
  }) async {
    final eventId = event.label == null
        ? null
        : event.eventIdOverride ?? 'combat-event-${now.microsecondsSinceEpoch}';
    final canCarryDiceRoll = event.label != null &&
        event.diceNotation.trim().isNotEmpty &&
        (event.label == 'ROLLING' || event.eventIdOverride != null);
    final resolvedEventDiceColorHex =
        canCarryDiceRoll ? event.diceColorHex ?? defaultDiceColorHex : '';
    final resolvedEventTargetIds = event.label == null
        ? const <String>{}
        : event.targetIds.isEmpty
            ? <String>{selectedTargetId}
            : event.targetIds;
    final resolvedEventSourceRefId =
        event.sourceRefId?.trim().isNotEmpty == true
            ? event.sourceRefId!.trim()
            : activeCombatantId;
    final resolvedEventPrimaryTargetRefId =
        event.primaryTargetRefId?.trim().isNotEmpty == true
            ? event.primaryTargetRefId!.trim()
            : selectedTargetId;
    final resolvedEventDiceTargetId =
        event.diceTargetId?.trim().isNotEmpty == true
            ? event.diceTargetId!.trim()
            : resolvedEventPrimaryTargetRefId;
    final resolvedEventAreaShape =
        event.areaFeet > 0 ? event.areaShape.trim() : '';
    final resolvedAffectedRefIds = resolvedEventTargetIds.toList()..sort();
    final tokenByRefId = {
      for (final token in boardProvider.tokens.where(
        (token) => token.sceneId == sceneId,
      ))
        token.refId: token,
    };
    final selectedTargetToken = tokenByRefId[selectedTargetId];
    final defaultAreaAimX = selectedTargetToken?.x ?? -1;
    final defaultAreaAimY = selectedTargetToken?.y ?? -1;
    final resolvedEventAreaTargetX =
        event.areaTargetX ?? selectedTargetToken?.x ?? -1;
    final resolvedEventAreaTargetY =
        event.areaTargetY ?? selectedTargetToken?.y ?? -1;

    for (final combatant in combatants) {
      final token = tokenByRefId[combatant.id];
      if (token == null) continue;
      final movementUsed =
          movementUsedByCombatantId[combatant.id] ?? token.movementUsedFeet;
      final isActive = combatant.id == activeCombatantId;
      final isTargeted = combatant.id == selectedTargetId;
      final nextMovementOriginX =
          isActive && movementUsed == 0 ? token.x : token.movementOriginX;
      final nextMovementOriginY =
          isActive && movementUsed == 0 ? token.y : token.movementOriginY;
      final isEventTarget =
          event.label != null && resolvedEventTargetIds.contains(combatant.id);
      final isEventSource = event.label != null &&
          combatant.id == resolvedEventSourceRefId &&
          resolvedEventAreaShape.isNotEmpty &&
          event.areaFeet > 0;
      final carriesEventMetadata = isEventTarget || isEventSource;
      final isDiceEventTarget =
          isEventTarget && combatant.id == resolvedEventDiceTargetId;
      final eventExpired = event.label == null &&
          (token.lastEventLabel.isNotEmpty ||
              token.lastEventAreaShape.isNotEmpty) &&
          now.difference(token.updatedAt) > eventVisibleDuration;
      final nextLastEventLabel = isEventTarget
          ? event.label
          : eventExpired
              ? ''
              : token.lastEventLabel;
      final nextLastEventKind = carriesEventMetadata
          ? event.kind
          : eventExpired
              ? ''
              : token.lastEventKind;
      final nextLastEventId = carriesEventMetadata
          ? eventId!
          : eventExpired
              ? ''
              : token.lastEventId;
      final nextLastEventDiceNotation = isDiceEventTarget
          ? canCarryDiceRoll
              ? event.diceNotation
              : ''
          : carriesEventMetadata
              ? ''
              : eventExpired
                  ? ''
                  : token.lastEventDiceNotation;
      final nextLastEventDiceColorHex = isDiceEventTarget
          ? resolvedEventDiceColorHex
          : carriesEventMetadata
              ? ''
              : eventExpired
                  ? ''
                  : token.lastEventDiceColorHex;
      final nextLastEventResultLabel = carriesEventMetadata
          ? event.resultLabel
          : eventExpired
              ? ''
              : token.lastEventResultLabel;
      final nextLastEventResultDetail = carriesEventMetadata
          ? event.resultDetail
          : eventExpired
              ? ''
              : token.lastEventResultDetail;
      final nextLastEventAuthoritativeDice = isDiceEventTarget
          ? canCarryDiceRoll
              ? event.authoritativeDice
              : ''
          : carriesEventMetadata
              ? ''
              : eventExpired
                  ? ''
                  : token.lastEventAuthoritativeDice;
      final preserveExistingEventRoll = carriesEventMetadata &&
          event.eventIdOverride != null &&
          token.lastEventId == event.eventIdOverride &&
          token.lastEventRollValues.isNotEmpty;
      final nextLastEventRollTotal = preserveExistingEventRoll
          ? token.lastEventRollTotal
          : carriesEventMetadata
              ? 0
              : eventExpired
                  ? 0
                  : token.lastEventRollTotal;
      final nextLastEventRollDiceTotal = preserveExistingEventRoll
          ? token.lastEventRollDiceTotal
          : carriesEventMetadata
              ? 0
              : eventExpired
                  ? 0
                  : token.lastEventRollDiceTotal;
      final nextLastEventRollValues = preserveExistingEventRoll
          ? token.lastEventRollValues
          : carriesEventMetadata
              ? const <int>[]
              : eventExpired
                  ? const <int>[]
                  : token.lastEventRollValues;
      final nextLastEventDamageType = carriesEventMetadata
          ? event.damageType
          : eventExpired
              ? ''
              : token.lastEventDamageType;
      final nextLastEventSourceRefId = carriesEventMetadata
          ? resolvedEventSourceRefId
          : eventExpired
              ? ''
              : token.lastEventSourceRefId;
      final nextLastEventPrimaryTargetRefId = carriesEventMetadata
          ? resolvedEventPrimaryTargetRefId
          : eventExpired
              ? ''
              : token.lastEventPrimaryTargetRefId;
      final nextLastEventAffectedRefIds = carriesEventMetadata
          ? resolvedAffectedRefIds
          : eventExpired
              ? const <String>[]
              : token.lastEventAffectedRefIds;
      final nextLastEventAreaShape =
          carriesEventMetadata && resolvedEventAreaShape.isNotEmpty
              ? resolvedEventAreaShape
              : eventExpired
                  ? ''
                  : token.lastEventAreaShape;
      final nextLastEventAreaFeet =
          carriesEventMetadata && resolvedEventAreaShape.isNotEmpty
              ? event.areaFeet
              : eventExpired
                  ? 0
                  : token.lastEventAreaFeet;
      final nextLastEventAreaTargetX =
          carriesEventMetadata && resolvedEventAreaShape.isNotEmpty
              ? resolvedEventAreaTargetX
              : eventExpired
                  ? -1
                  : token.lastEventAreaTargetX;
      final nextLastEventAreaTargetY =
          carriesEventMetadata && resolvedEventAreaShape.isNotEmpty
              ? resolvedEventAreaTargetY
              : eventExpired
                  ? -1
                  : token.lastEventAreaTargetY;
      final nextSelectedActionRangeFeet = isActive ? focus.rangeFeet : 0;
      final nextSelectedActionAreaShape = isActive ? focus.areaShape : '';
      final nextSelectedActionAreaFeet = isActive ? focus.areaFeet : 0;
      final nextSelectedActionAimX =
          isActive && focus.areaFeet > 0 && focus.areaShape.trim().isNotEmpty
              ? token.selectedActionAimX >= 0
                  ? token.selectedActionAimX
                  : defaultAreaAimX
              : -1;
      final nextSelectedActionAimY =
          isActive && focus.areaFeet > 0 && focus.areaShape.trim().isNotEmpty
              ? token.selectedActionAimY >= 0
                  ? token.selectedActionAimY
                  : defaultAreaAimY
              : -1;
      final nextTargetDistanceFeet =
          isActive || isTargeted ? focus.targetDistanceFeet : 0;
      final nextTargetInRange =
          isActive || isTargeted ? focus.targetInRange : true;
      final nextFocusedActionName = isActive ? focus.actionName : '';

      if (token.currentHp == combatant.hp &&
          token.maxHp == combatant.maxHp &&
          token.size == combatant.tokenSize &&
          token.initiative == combatant.initiative &&
          token.role == combatant.role &&
          token.speedFeet == combatant.speedFeet &&
          token.movementUsedFeet == movementUsed &&
          token.movementOriginX == nextMovementOriginX &&
          token.movementOriginY == nextMovementOriginY &&
          token.selectedActionRangeFeet == nextSelectedActionRangeFeet &&
          token.selectedActionAreaShape == nextSelectedActionAreaShape &&
          token.selectedActionAreaFeet == nextSelectedActionAreaFeet &&
          token.selectedActionAimX == nextSelectedActionAimX &&
          token.selectedActionAimY == nextSelectedActionAimY &&
          token.targetDistanceFeet == nextTargetDistanceFeet &&
          token.isActive == isActive &&
          token.isTargeted == isTargeted &&
          token.isTargetInRange == nextTargetInRange &&
          token.focusedActionName == nextFocusedActionName &&
          token.lastEventLabel == nextLastEventLabel &&
          token.lastEventKind == nextLastEventKind &&
          token.lastEventId == nextLastEventId &&
          token.lastEventDiceNotation == nextLastEventDiceNotation &&
          token.lastEventDiceColorHex == nextLastEventDiceColorHex &&
          token.lastEventResultLabel == nextLastEventResultLabel &&
          token.lastEventResultDetail == nextLastEventResultDetail &&
          token.lastEventAuthoritativeDice == nextLastEventAuthoritativeDice &&
          token.lastEventRollTotal == nextLastEventRollTotal &&
          token.lastEventRollDiceTotal == nextLastEventRollDiceTotal &&
          _intListsMatch(token.lastEventRollValues, nextLastEventRollValues) &&
          token.lastEventDamageType == nextLastEventDamageType &&
          token.lastEventSourceRefId == nextLastEventSourceRefId &&
          token.lastEventPrimaryTargetRefId ==
              nextLastEventPrimaryTargetRefId &&
          _stringListsMatch(
            token.lastEventAffectedRefIds,
            nextLastEventAffectedRefIds,
          ) &&
          token.lastEventAreaShape == nextLastEventAreaShape &&
          token.lastEventAreaFeet == nextLastEventAreaFeet &&
          token.lastEventAreaTargetX == nextLastEventAreaTargetX &&
          token.lastEventAreaTargetY == nextLastEventAreaTargetY &&
          _stringListsMatch(token.conditions, combatant.conditions)) {
        continue;
      }

      await boardProvider.saveToken(
        campaignId: campaignId,
        token: token.copyWith(
          currentHp: combatant.hp,
          maxHp: combatant.maxHp,
          size: combatant.tokenSize,
          initiative: combatant.initiative,
          role: combatant.role,
          speedFeet: combatant.speedFeet,
          movementUsedFeet: movementUsed,
          movementOriginX: nextMovementOriginX,
          movementOriginY: nextMovementOriginY,
          selectedActionRangeFeet: nextSelectedActionRangeFeet,
          selectedActionAreaShape: nextSelectedActionAreaShape,
          selectedActionAreaFeet: nextSelectedActionAreaFeet,
          selectedActionAimX: nextSelectedActionAimX,
          selectedActionAimY: nextSelectedActionAimY,
          targetDistanceFeet: nextTargetDistanceFeet,
          conditions: combatant.conditions,
          isActive: isActive,
          isTargeted: isTargeted,
          isTargetInRange: nextTargetInRange,
          focusedActionName: nextFocusedActionName,
          lastEventLabel: nextLastEventLabel,
          lastEventKind: nextLastEventKind,
          lastEventId: nextLastEventId,
          lastEventDiceNotation: nextLastEventDiceNotation,
          lastEventDiceColorHex: nextLastEventDiceColorHex,
          lastEventResultLabel: nextLastEventResultLabel,
          lastEventResultDetail: nextLastEventResultDetail,
          lastEventAuthoritativeDice: nextLastEventAuthoritativeDice,
          lastEventRollTotal: nextLastEventRollTotal,
          lastEventRollDiceTotal: nextLastEventRollDiceTotal,
          lastEventRollValues: nextLastEventRollValues,
          lastEventDamageType: nextLastEventDamageType,
          lastEventSourceRefId: nextLastEventSourceRefId,
          lastEventPrimaryTargetRefId: nextLastEventPrimaryTargetRefId,
          lastEventAffectedRefIds: nextLastEventAffectedRefIds,
          lastEventAreaShape: nextLastEventAreaShape,
          lastEventAreaFeet: nextLastEventAreaFeet,
          lastEventAreaTargetX: nextLastEventAreaTargetX,
          lastEventAreaTargetY: nextLastEventAreaTargetY,
        ),
      );
    }

    return CombatBoardSyncResult(eventId: eventId);
  }

  static bool _stringListsMatch(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  static bool _intListsMatch(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
