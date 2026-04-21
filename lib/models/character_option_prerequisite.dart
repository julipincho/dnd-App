class CharacterOptionPrerequisite {
  final String type;
  final Map<String, dynamic> data;

  const CharacterOptionPrerequisite({
    required this.type,
    required this.data,
  });

  factory CharacterOptionPrerequisite.fromJson(Map<String, dynamic> json) {
    return CharacterOptionPrerequisite(
      type: json['type']?.toString() ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
    };
  }
}
