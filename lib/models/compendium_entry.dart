class CompendiumEntry {
  final String id;
  final String campaignId;
  final String title;
  final String description;
  final String type;
  final String? imagePath;
  final DateTime createdAt;

  CompendiumEntry({
    required this.id,
    required this.campaignId,
    required this.title,
    required this.description,
    required this.type,
    this.imagePath,
    required this.createdAt,
  });

  factory CompendiumEntry.fromJson(Map<String, dynamic> json) {
    return CompendiumEntry(
      id: json['id'],
      campaignId: json['campaignId'],
      title: json['title'],
      description: json['description'],
      type: json['type'],
      imagePath: json['imagePath']?.toString(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaignId': campaignId,
      'title': title,
      'description': description,
      'type': type,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  CompendiumEntry copyWith({
    String? id,
    String? campaignId,
    String? title,
    String? description,
    String? type,
    String? imagePath,
    DateTime? createdAt,
  }) {
    return CompendiumEntry(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
