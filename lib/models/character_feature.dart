class CharacterFeature {
  String id;
  String name;
  String description;
  String source; // class, subclass, race, feat, other
  int? unlockedAtLevel;
  String? linkedResourceId;

  CharacterFeature({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    this.unlockedAtLevel,
    this.linkedResourceId,
  });

  factory CharacterFeature.fromJson(Map<String, dynamic> json) {
    return CharacterFeature(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      source: json['source']?.toString() ?? 'other',
      unlockedAtLevel: (json['unlockedAtLevel'] as num?)?.toInt(),
      linkedResourceId: json['linkedResourceId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'source': source,
      'unlockedAtLevel': unlockedAtLevel,
      'linkedResourceId': linkedResourceId,
    };
  }
}
