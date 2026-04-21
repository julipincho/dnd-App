class FeatData {
  final String id;
  final String name;
  final String source;
  final int? page;
  final String? category;
  final List<dynamic> prerequisites;
  final List<dynamic> abilityIncreases;
  final bool repeatable;
  final String description;
  final Map<String, dynamic> modifiers;
  final List<dynamic> additionalSpells;
  final List<dynamic> skillProficiencies;
  final List<dynamic> toolProficiencies;
  final List<dynamic> weaponProficiencies;
  final List<dynamic> armorProficiencies;
  final List<dynamic> languageProficiencies;
  final List<dynamic> resist;
  final List<dynamic> immune;
  final List<dynamic> conditionImmune;
  final List<dynamic> senses;
  final bool hasChoices;
  final bool is2014Ruleset;

  const FeatData({
    required this.id,
    required this.name,
    required this.source,
    required this.page,
    required this.category,
    required this.prerequisites,
    required this.abilityIncreases,
    required this.repeatable,
    required this.description,
    required this.modifiers,
    required this.additionalSpells,
    required this.skillProficiencies,
    required this.toolProficiencies,
    required this.weaponProficiencies,
    required this.armorProficiencies,
    required this.languageProficiencies,
    required this.resist,
    required this.immune,
    required this.conditionImmune,
    required this.senses,
    required this.hasChoices,
    required this.is2014Ruleset,
  });

  factory FeatData.fromJson(Map<String, dynamic> json) {
    return FeatData(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      page: json['page'] is int
          ? json['page'] as int
          : int.tryParse('${json['page']}'),
      category: json['category']?.toString(),
      prerequisites: (json['prerequisites'] as List?)?.toList() ?? const [],
      abilityIncreases:
          (json['abilityIncreases'] as List?)?.toList() ?? const [],
      repeatable: json['repeatable'] == true,
      description: (json['description'] ?? '').toString(),
      modifiers:
          (json['modifiers'] as Map?)?.cast<String, dynamic>() ?? const {},
      additionalSpells:
          (json['additionalSpells'] as List?)?.toList() ?? const [],
      skillProficiencies:
          (json['skillProficiencies'] as List?)?.toList() ?? const [],
      toolProficiencies:
          (json['toolProficiencies'] as List?)?.toList() ?? const [],
      weaponProficiencies:
          (json['weaponProficiencies'] as List?)?.toList() ?? const [],
      armorProficiencies:
          (json['armorProficiencies'] as List?)?.toList() ?? const [],
      languageProficiencies:
          (json['languageProficiencies'] as List?)?.toList() ?? const [],
      resist: (json['resist'] as List?)?.toList() ?? const [],
      immune: (json['immune'] as List?)?.toList() ?? const [],
      conditionImmune: (json['conditionImmune'] as List?)?.toList() ?? const [],
      senses: (json['senses'] as List?)?.toList() ?? const [],
      hasChoices: json['hasChoices'] == true,
      is2014Ruleset: json['is2014Ruleset'] == true,
    );
  }
}
