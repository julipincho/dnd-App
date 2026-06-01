class BoardToken {
  final String id;
  final String sceneId;
  final String refId;
  final String type;
  final String name;
  final String imageUrl;
  final int x;
  final int y;
  final int size;
  final int currentHp;
  final int maxHp;
  final int initiative;
  final int speedFeet;
  final int movementUsedFeet;
  final int movementOriginX;
  final int movementOriginY;
  final int selectedActionRangeFeet;
  final String selectedActionAreaShape;
  final int selectedActionAreaFeet;
  final int selectedActionAimX;
  final int selectedActionAimY;
  final int targetDistanceFeet;
  final List<String> conditions;
  final bool isVisible;
  final bool isActive;
  final bool isTargeted;
  final bool isTargetInRange;
  final String role;
  final String focusedActionName;
  final String lastEventLabel;
  final String lastEventKind;
  final String lastEventId;
  final String lastEventDiceNotation;
  final String lastEventDiceColorHex;
  final String lastEventResultLabel;
  final String lastEventResultDetail;
  final String lastEventAuthoritativeDice;
  final int lastEventRollTotal;
  final int lastEventRollDiceTotal;
  final List<int> lastEventRollValues;
  final String lastEventDamageType;
  final String lastEventSourceRefId;
  final String lastEventPrimaryTargetRefId;
  final List<String> lastEventAffectedRefIds;
  final String lastEventAreaShape;
  final int lastEventAreaFeet;
  final int lastEventAreaTargetX;
  final int lastEventAreaTargetY;
  final String controlledByUserId;
  final DateTime updatedAt;

  const BoardToken({
    required this.id,
    required this.sceneId,
    required this.refId,
    required this.type,
    required this.name,
    required this.imageUrl,
    required this.x,
    required this.y,
    required this.size,
    required this.currentHp,
    required this.maxHp,
    required this.initiative,
    required this.speedFeet,
    required this.movementUsedFeet,
    required this.movementOriginX,
    required this.movementOriginY,
    required this.selectedActionRangeFeet,
    required this.selectedActionAreaShape,
    required this.selectedActionAreaFeet,
    required this.selectedActionAimX,
    required this.selectedActionAimY,
    required this.targetDistanceFeet,
    required this.conditions,
    required this.isVisible,
    required this.isActive,
    required this.isTargeted,
    required this.isTargetInRange,
    required this.role,
    required this.focusedActionName,
    required this.lastEventLabel,
    required this.lastEventKind,
    required this.lastEventId,
    required this.lastEventDiceNotation,
    required this.lastEventDiceColorHex,
    required this.lastEventResultLabel,
    required this.lastEventResultDetail,
    required this.lastEventAuthoritativeDice,
    required this.lastEventRollTotal,
    required this.lastEventRollDiceTotal,
    required this.lastEventRollValues,
    required this.lastEventDamageType,
    required this.lastEventSourceRefId,
    required this.lastEventPrimaryTargetRefId,
    required this.lastEventAffectedRefIds,
    required this.lastEventAreaShape,
    required this.lastEventAreaFeet,
    required this.lastEventAreaTargetX,
    required this.lastEventAreaTargetY,
    required this.controlledByUserId,
    required this.updatedAt,
  });

  factory BoardToken.create({
    required String id,
    required String sceneId,
    required String refId,
    required String type,
    required String name,
    String imageUrl = '',
    int x = 0,
    int y = 0,
    int size = 1,
    int currentHp = 1,
    int maxHp = 1,
    int initiative = 0,
    int speedFeet = 30,
    int movementUsedFeet = 0,
    int? movementOriginX,
    int? movementOriginY,
    int selectedActionRangeFeet = 0,
    String selectedActionAreaShape = '',
    int selectedActionAreaFeet = 0,
    int selectedActionAimX = -1,
    int selectedActionAimY = -1,
    int targetDistanceFeet = 0,
    List<String> conditions = const [],
    bool isVisible = true,
    bool isActive = false,
    bool isTargeted = false,
    bool isTargetInRange = true,
    String role = '',
    String focusedActionName = '',
    String lastEventLabel = '',
    String lastEventKind = '',
    String lastEventId = '',
    String lastEventDiceNotation = '',
    String lastEventDiceColorHex = '',
    String lastEventResultLabel = '',
    String lastEventResultDetail = '',
    String lastEventAuthoritativeDice = '',
    int lastEventRollTotal = 0,
    int lastEventRollDiceTotal = 0,
    List<int> lastEventRollValues = const [],
    String lastEventDamageType = '',
    String lastEventSourceRefId = '',
    String lastEventPrimaryTargetRefId = '',
    List<String> lastEventAffectedRefIds = const [],
    String lastEventAreaShape = '',
    int lastEventAreaFeet = 0,
    int lastEventAreaTargetX = -1,
    int lastEventAreaTargetY = -1,
    String controlledByUserId = '',
    DateTime? now,
  }) {
    return BoardToken(
      id: id,
      sceneId: sceneId,
      refId: refId,
      type: type,
      name: name,
      imageUrl: imageUrl,
      x: x,
      y: y,
      size: size,
      currentHp: currentHp,
      maxHp: maxHp,
      initiative: initiative,
      speedFeet: speedFeet,
      movementUsedFeet: movementUsedFeet,
      movementOriginX: movementOriginX ?? x,
      movementOriginY: movementOriginY ?? y,
      selectedActionRangeFeet: selectedActionRangeFeet,
      selectedActionAreaShape: selectedActionAreaShape,
      selectedActionAreaFeet: selectedActionAreaFeet,
      selectedActionAimX: selectedActionAimX,
      selectedActionAimY: selectedActionAimY,
      targetDistanceFeet: targetDistanceFeet,
      conditions: conditions,
      isVisible: isVisible,
      isActive: isActive,
      isTargeted: isTargeted,
      isTargetInRange: isTargetInRange,
      role: role,
      focusedActionName: focusedActionName,
      lastEventLabel: lastEventLabel,
      lastEventKind: lastEventKind,
      lastEventId: lastEventId,
      lastEventDiceNotation: lastEventDiceNotation,
      lastEventDiceColorHex: lastEventDiceColorHex,
      lastEventResultLabel: lastEventResultLabel,
      lastEventResultDetail: lastEventResultDetail,
      lastEventAuthoritativeDice: lastEventAuthoritativeDice,
      lastEventRollTotal: lastEventRollTotal,
      lastEventRollDiceTotal: lastEventRollDiceTotal,
      lastEventRollValues: lastEventRollValues,
      lastEventDamageType: lastEventDamageType,
      lastEventSourceRefId: lastEventSourceRefId,
      lastEventPrimaryTargetRefId: lastEventPrimaryTargetRefId,
      lastEventAffectedRefIds: lastEventAffectedRefIds,
      lastEventAreaShape: lastEventAreaShape,
      lastEventAreaFeet: lastEventAreaFeet,
      lastEventAreaTargetX: lastEventAreaTargetX,
      lastEventAreaTargetY: lastEventAreaTargetY,
      controlledByUserId: controlledByUserId,
      updatedAt: now ?? DateTime.now(),
    );
  }

  factory BoardToken.fromJson(Map<String, dynamic> json) {
    return BoardToken(
      id: json['id']?.toString() ?? '',
      sceneId: json['sceneId']?.toString() ?? '',
      refId: json['refId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'npc',
      name: json['name']?.toString() ?? 'Token',
      imageUrl: json['imageUrl']?.toString() ?? '',
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 1,
      currentHp: (json['currentHp'] as num?)?.toInt() ?? 1,
      maxHp: (json['maxHp'] as num?)?.toInt() ?? 1,
      initiative: (json['initiative'] as num?)?.toInt() ?? 0,
      speedFeet: (json['speedFeet'] as num?)?.toInt() ?? 30,
      movementUsedFeet: (json['movementUsedFeet'] as num?)?.toInt() ?? 0,
      movementOriginX: (json['movementOriginX'] as num?)?.toInt() ??
          (json['x'] as num?)?.toInt() ??
          0,
      movementOriginY: (json['movementOriginY'] as num?)?.toInt() ??
          (json['y'] as num?)?.toInt() ??
          0,
      selectedActionRangeFeet:
          (json['selectedActionRangeFeet'] as num?)?.toInt() ?? 0,
      selectedActionAreaShape:
          json['selectedActionAreaShape']?.toString() ?? '',
      selectedActionAreaFeet:
          (json['selectedActionAreaFeet'] as num?)?.toInt() ?? 0,
      selectedActionAimX: (json['selectedActionAimX'] as num?)?.toInt() ?? -1,
      selectedActionAimY: (json['selectedActionAimY'] as num?)?.toInt() ?? -1,
      targetDistanceFeet: (json['targetDistanceFeet'] as num?)?.toInt() ?? 0,
      conditions: _stringList(json['conditions']),
      isVisible: json['isVisible'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? false,
      isTargeted: json['isTargeted'] as bool? ?? false,
      isTargetInRange: json['isTargetInRange'] as bool? ?? true,
      role: json['role']?.toString() ?? '',
      focusedActionName: json['focusedActionName']?.toString() ?? '',
      lastEventLabel: json['lastEventLabel']?.toString() ?? '',
      lastEventKind: json['lastEventKind']?.toString() ?? '',
      lastEventId: json['lastEventId']?.toString() ?? '',
      lastEventDiceNotation: json['lastEventDiceNotation']?.toString() ?? '',
      lastEventDiceColorHex: json['lastEventDiceColorHex']?.toString() ?? '',
      lastEventResultLabel: json['lastEventResultLabel']?.toString() ?? '',
      lastEventResultDetail: json['lastEventResultDetail']?.toString() ?? '',
      lastEventAuthoritativeDice:
          json['lastEventAuthoritativeDice']?.toString() ?? '',
      lastEventRollTotal: (json['lastEventRollTotal'] as num?)?.toInt() ?? 0,
      lastEventRollDiceTotal:
          (json['lastEventRollDiceTotal'] as num?)?.toInt() ?? 0,
      lastEventRollValues: _intList(json['lastEventRollValues']),
      lastEventDamageType: json['lastEventDamageType']?.toString() ?? '',
      lastEventSourceRefId: json['lastEventSourceRefId']?.toString() ?? '',
      lastEventPrimaryTargetRefId:
          json['lastEventPrimaryTargetRefId']?.toString() ?? '',
      lastEventAffectedRefIds: _stringList(json['lastEventAffectedRefIds']),
      lastEventAreaShape: json['lastEventAreaShape']?.toString() ?? '',
      lastEventAreaFeet: (json['lastEventAreaFeet'] as num?)?.toInt() ?? 0,
      lastEventAreaTargetX:
          (json['lastEventAreaTargetX'] as num?)?.toInt() ?? -1,
      lastEventAreaTargetY:
          (json['lastEventAreaTargetY'] as num?)?.toInt() ?? -1,
      controlledByUserId: json['controlledByUserId']?.toString() ?? '',
      updatedAt: _dateFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sceneId': sceneId,
      'refId': refId,
      'type': type,
      'name': name,
      'imageUrl': imageUrl,
      'x': x,
      'y': y,
      'size': size,
      'currentHp': currentHp,
      'maxHp': maxHp,
      'initiative': initiative,
      'speedFeet': speedFeet,
      'movementUsedFeet': movementUsedFeet,
      'movementOriginX': movementOriginX,
      'movementOriginY': movementOriginY,
      'selectedActionRangeFeet': selectedActionRangeFeet,
      'selectedActionAreaShape': selectedActionAreaShape,
      'selectedActionAreaFeet': selectedActionAreaFeet,
      'selectedActionAimX': selectedActionAimX,
      'selectedActionAimY': selectedActionAimY,
      'targetDistanceFeet': targetDistanceFeet,
      'conditions': conditions,
      'isVisible': isVisible,
      'isActive': isActive,
      'isTargeted': isTargeted,
      'isTargetInRange': isTargetInRange,
      'role': role,
      'focusedActionName': focusedActionName,
      'lastEventLabel': lastEventLabel,
      'lastEventKind': lastEventKind,
      'lastEventId': lastEventId,
      'lastEventDiceNotation': lastEventDiceNotation,
      'lastEventDiceColorHex': lastEventDiceColorHex,
      'lastEventResultLabel': lastEventResultLabel,
      'lastEventResultDetail': lastEventResultDetail,
      'lastEventAuthoritativeDice': lastEventAuthoritativeDice,
      'lastEventRollTotal': lastEventRollTotal,
      'lastEventRollDiceTotal': lastEventRollDiceTotal,
      'lastEventRollValues': lastEventRollValues,
      'lastEventDamageType': lastEventDamageType,
      'lastEventSourceRefId': lastEventSourceRefId,
      'lastEventPrimaryTargetRefId': lastEventPrimaryTargetRefId,
      'lastEventAffectedRefIds': lastEventAffectedRefIds,
      'lastEventAreaShape': lastEventAreaShape,
      'lastEventAreaFeet': lastEventAreaFeet,
      'lastEventAreaTargetX': lastEventAreaTargetX,
      'lastEventAreaTargetY': lastEventAreaTargetY,
      'controlledByUserId': controlledByUserId,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  BoardToken copyWith({
    String? id,
    String? sceneId,
    String? refId,
    String? type,
    String? name,
    String? imageUrl,
    int? x,
    int? y,
    int? size,
    int? currentHp,
    int? maxHp,
    int? initiative,
    int? speedFeet,
    int? movementUsedFeet,
    int? movementOriginX,
    int? movementOriginY,
    int? selectedActionRangeFeet,
    String? selectedActionAreaShape,
    int? selectedActionAreaFeet,
    int? selectedActionAimX,
    int? selectedActionAimY,
    int? targetDistanceFeet,
    List<String>? conditions,
    bool? isVisible,
    bool? isActive,
    bool? isTargeted,
    bool? isTargetInRange,
    String? role,
    String? focusedActionName,
    String? lastEventLabel,
    String? lastEventKind,
    String? lastEventId,
    String? lastEventDiceNotation,
    String? lastEventDiceColorHex,
    String? lastEventResultLabel,
    String? lastEventResultDetail,
    String? lastEventAuthoritativeDice,
    int? lastEventRollTotal,
    int? lastEventRollDiceTotal,
    List<int>? lastEventRollValues,
    String? lastEventDamageType,
    String? lastEventSourceRefId,
    String? lastEventPrimaryTargetRefId,
    List<String>? lastEventAffectedRefIds,
    String? lastEventAreaShape,
    int? lastEventAreaFeet,
    int? lastEventAreaTargetX,
    int? lastEventAreaTargetY,
    String? controlledByUserId,
    DateTime? updatedAt,
  }) {
    return BoardToken(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      refId: refId ?? this.refId,
      type: type ?? this.type,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      x: x ?? this.x,
      y: y ?? this.y,
      size: size ?? this.size,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      initiative: initiative ?? this.initiative,
      speedFeet: speedFeet ?? this.speedFeet,
      movementUsedFeet: movementUsedFeet ?? this.movementUsedFeet,
      movementOriginX: movementOriginX ?? this.movementOriginX,
      movementOriginY: movementOriginY ?? this.movementOriginY,
      selectedActionRangeFeet:
          selectedActionRangeFeet ?? this.selectedActionRangeFeet,
      selectedActionAreaShape:
          selectedActionAreaShape ?? this.selectedActionAreaShape,
      selectedActionAreaFeet:
          selectedActionAreaFeet ?? this.selectedActionAreaFeet,
      selectedActionAimX: selectedActionAimX ?? this.selectedActionAimX,
      selectedActionAimY: selectedActionAimY ?? this.selectedActionAimY,
      targetDistanceFeet: targetDistanceFeet ?? this.targetDistanceFeet,
      conditions: conditions ?? this.conditions,
      isVisible: isVisible ?? this.isVisible,
      isActive: isActive ?? this.isActive,
      isTargeted: isTargeted ?? this.isTargeted,
      isTargetInRange: isTargetInRange ?? this.isTargetInRange,
      role: role ?? this.role,
      focusedActionName: focusedActionName ?? this.focusedActionName,
      lastEventLabel: lastEventLabel ?? this.lastEventLabel,
      lastEventKind: lastEventKind ?? this.lastEventKind,
      lastEventId: lastEventId ?? this.lastEventId,
      lastEventDiceNotation:
          lastEventDiceNotation ?? this.lastEventDiceNotation,
      lastEventDiceColorHex:
          lastEventDiceColorHex ?? this.lastEventDiceColorHex,
      lastEventResultLabel: lastEventResultLabel ?? this.lastEventResultLabel,
      lastEventResultDetail:
          lastEventResultDetail ?? this.lastEventResultDetail,
      lastEventAuthoritativeDice:
          lastEventAuthoritativeDice ?? this.lastEventAuthoritativeDice,
      lastEventRollTotal: lastEventRollTotal ?? this.lastEventRollTotal,
      lastEventRollDiceTotal:
          lastEventRollDiceTotal ?? this.lastEventRollDiceTotal,
      lastEventRollValues: lastEventRollValues ?? this.lastEventRollValues,
      lastEventDamageType: lastEventDamageType ?? this.lastEventDamageType,
      lastEventSourceRefId: lastEventSourceRefId ?? this.lastEventSourceRefId,
      lastEventPrimaryTargetRefId:
          lastEventPrimaryTargetRefId ?? this.lastEventPrimaryTargetRefId,
      lastEventAffectedRefIds:
          lastEventAffectedRefIds ?? this.lastEventAffectedRefIds,
      lastEventAreaShape: lastEventAreaShape ?? this.lastEventAreaShape,
      lastEventAreaFeet: lastEventAreaFeet ?? this.lastEventAreaFeet,
      lastEventAreaTargetX: lastEventAreaTargetX ?? this.lastEventAreaTargetX,
      lastEventAreaTargetY: lastEventAreaTargetY ?? this.lastEventAreaTargetY,
      controlledByUserId: controlledByUserId ?? this.controlledByUserId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get remainingMovementFeet {
    final remaining = speedFeet - movementUsedFeet;
    if (remaining < 0) return 0;
    return remaining > speedFeet ? speedFeet : remaining;
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

List<int> _intList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
      .whereType<int>()
      .toList(growable: false);
}

DateTime _dateFromJson(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
