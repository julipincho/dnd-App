class Campaign {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final String ownerUserId;
  final List<String> memberUserIds;

  Campaign({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.ownerUserId,
    this.memberUserIds = const [],
  });

  factory Campaign.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) {
    final explicitId = json['id']?.toString().trim() ?? '';

    return Campaign(
      id: explicitId.isNotEmpty ? explicitId : (fallbackId ?? ''),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      memberUserIds: (json['memberUserIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'ownerUserId': ownerUserId,
      'memberUserIds': memberUserIds,
    };
  }

  Campaign copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    String? ownerUserId,
    List<String>? memberUserIds,
  }) {
    return Campaign(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      memberUserIds: memberUserIds ?? this.memberUserIds,
    );
  }
}
