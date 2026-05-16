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
  final List<String> conditions;
  final bool isVisible;
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
    required this.conditions,
    required this.isVisible,
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
    List<String> conditions = const [],
    bool isVisible = true,
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
      conditions: conditions,
      isVisible: isVisible,
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
      conditions: _stringList(json['conditions']),
      isVisible: json['isVisible'] as bool? ?? true,
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
      'conditions': conditions,
      'isVisible': isVisible,
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
    List<String>? conditions,
    bool? isVisible,
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
      conditions: conditions ?? this.conditions,
      isVisible: isVisible ?? this.isVisible,
      controlledByUserId: controlledByUserId ?? this.controlledByUserId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

DateTime _dateFromJson(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
