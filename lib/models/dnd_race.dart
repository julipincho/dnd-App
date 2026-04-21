import 'dnd_subrace.dart';

class DndRace {
  final String id;
  final String name;
  final String source;
  final int speed;

  final List<Map<String, dynamic>> abilityBonuses;
  final Map<String, dynamic>? abilityBonusOptions;

  final String alignment;
  final String age;

  final String size;
  final String sizeDescription;

  final List<String> languages;
  final String languageDesc;
  final Map<String, dynamic>? languageOptions;

  final List<Map<String, String>> traits;

  final List<DndSubrace> subraces;

  final String description;

  DndRace({
    required this.id,
    required this.name,
    required this.source,
    required this.speed,
    required this.abilityBonuses,
    required this.abilityBonusOptions,
    required this.alignment,
    required this.age,
    required this.size,
    required this.sizeDescription,
    required this.languages,
    required this.languageDesc,
    required this.languageOptions,
    required this.traits,
    required this.subraces,
    required this.description,
  });

  factory DndRace.fromJson(Map<String, dynamic> json) {
    return DndRace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      speed: (json['speed'] ?? 30) as int,
      abilityBonuses: (json['abilityBonuses'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      abilityBonusOptions: json['abilityBonusOptions'] is Map
          ? Map<String, dynamic>.from(json['abilityBonusOptions'])
          : null,
      alignment: (json['alignment'] ?? '').toString(),
      age: (json['age'] ?? '').toString(),
      size: (json['size'] ?? '').toString(),
      sizeDescription: (json['sizeDescription'] ?? '').toString(),
      languages:
          (json['languages'] as List? ?? []).map((e) => e.toString()).toList(),
      languageDesc: (json['languageDesc'] ?? '').toString(),
      languageOptions: json['languageOptions'] is Map
          ? Map<String, dynamic>.from(json['languageOptions'])
          : null,
      traits: (json['traits'] as List? ?? [])
          .map((e) => {
                'name': (e['name'] ?? '').toString(),
                'description': (e['description'] ?? '').toString(),
              })
          .toList(),
      subraces: (json['subraces'] as List? ?? [])
          .map((e) => DndSubrace.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      description: (json['description'] ?? '').toString(),
    );
  }
}
