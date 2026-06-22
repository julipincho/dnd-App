class BattleScene {
  final String id;
  final String campaignId;
  final String name;
  final String mapImageUrl;
  final int gridSize;
  final int gridColumns;
  final int gridRows;
  final bool combatActive;
  final Map<String, dynamic> combatState;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BattleScene({
    required this.id,
    required this.campaignId,
    required this.name,
    required this.mapImageUrl,
    required this.gridSize,
    required this.gridColumns,
    required this.gridRows,
    required this.combatActive,
    required this.combatState,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BattleScene.create({
    required String id,
    required String campaignId,
    required String name,
    String mapImageUrl = '',
    int gridSize = 64,
    int gridColumns = 24,
    int gridRows = 16,
    bool combatActive = false,
    Map<String, dynamic> combatState = const {},
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();

    return BattleScene(
      id: id,
      campaignId: campaignId,
      name: name,
      mapImageUrl: mapImageUrl,
      gridSize: gridSize,
      gridColumns: gridColumns,
      gridRows: gridRows,
      combatActive: combatActive,
      combatState: combatState,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory BattleScene.fromJson(Map<String, dynamic> json) {
    return BattleScene(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Battle Scene',
      mapImageUrl: json['mapImageUrl']?.toString() ?? '',
      gridSize: (json['gridSize'] as num?)?.toInt() ?? 64,
      gridColumns: (json['gridColumns'] as num?)?.toInt() ?? 24,
      gridRows: (json['gridRows'] as num?)?.toInt() ?? 16,
      combatActive: json['combatActive'] as bool? ?? false,
      combatState: _mapFromJson(json['combatState']),
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaignId': campaignId,
      'name': name,
      'mapImageUrl': mapImageUrl,
      'gridSize': gridSize,
      'gridColumns': gridColumns,
      'gridRows': gridRows,
      'combatActive': combatActive,
      'combatState': combatState,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  BattleScene copyWith({
    String? id,
    String? campaignId,
    String? name,
    String? mapImageUrl,
    int? gridSize,
    int? gridColumns,
    int? gridRows,
    bool? combatActive,
    Map<String, dynamic>? combatState,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BattleScene(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      name: name ?? this.name,
      mapImageUrl: mapImageUrl ?? this.mapImageUrl,
      gridSize: gridSize ?? this.gridSize,
      gridColumns: gridColumns ?? this.gridColumns,
      gridRows: gridRows ?? this.gridRows,
      combatActive: combatActive ?? this.combatActive,
      combatState: combatState ?? this.combatState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime _dateFromJson(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

Map<String, dynamic> _mapFromJson(dynamic value) {
  if (value is! Map) return const {};
  return Map<String, dynamic>.from(value);
}
