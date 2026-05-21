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

DateTime _dateFromJson(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
