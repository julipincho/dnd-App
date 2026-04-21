import 'dnd_subrace.dart';

class DndRace {
  final String index;
  final String name;
  final int speed;

  final List<Map<String, dynamic>> abilityBonuses;

  final String alignment;
  final String age;

  final String size;
  final String sizeDescription;

  final List<String> languages;
  final String languageDesc;

  final List<String> traits;

  /// 🔥 Ahora subrazas completas
  final List<DndSubrace> subraces;

  // Campos opcionales
  final String? description;
  final String? book;
  final String? category;

  DndRace({
    required this.index,
    required this.name,
    required this.speed,
    required this.abilityBonuses,
    required this.alignment,
    required this.age,
    required this.size,
    required this.sizeDescription,
    required this.languages,
    required this.languageDesc,
    required this.traits,
    required this.subraces,
    this.description,
    this.book,
    this.category,
  });

  factory DndRace.fromJson(Map<String, dynamic> json) {
    return DndRace(
      index: json["index"],
      name: json["name"],
      speed: json["speed"],

      abilityBonuses: (json["ability_bonuses"] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),

      alignment: json["alignment"] ?? "",
      age: json["age"] ?? "",

      size: json["size"] ?? "",
      sizeDescription: json["size_description"] ?? "",

      languages: (json["languages"] as List? ?? [])
          .map((e) => e["name"] as String)
          .toList(),

      languageDesc: json["language_desc"] ?? "",

      traits: (json["traits"] as List? ?? [])
          .map((e) => e["name"] as String)
          .toList(),

      /// SRD subraces → strings (para compatibilidad)
      /// Tools subraces → reemplazadas luego por DataMerger
      subraces: [],

      description: json["description"],
      book: json["book"],
      category: json["category"],
    );
  }
}
