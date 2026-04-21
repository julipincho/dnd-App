class CharacterOptionModifier {
  final String type;
  final Map<String, dynamic> data;

  const CharacterOptionModifier({
    required this.type,
    required this.data,
  });

  factory CharacterOptionModifier.fromJson(Map<String, dynamic> json) {
    return CharacterOptionModifier(
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
