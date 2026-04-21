import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/dnd_class.dart';
import '../models/subclass_progress_feature.dart';

class ClassDataService {
  static const String _path = "assets/data/classes_normalized.json";

  static String _norm(String s) => s.trim().toLowerCase();

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  static String? _mapSpellAbility(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    switch (raw.toUpperCase()) {
      case "STR":
        return "Strength";
      case "DEX":
        return "Dexterity";
      case "CON":
        return "Constitution";
      case "INT":
        return "Intelligence";
      case "WIS":
        return "Wisdom";
      case "CHA":
        return "Charisma";
      default:
        return raw;
    }
  }

  static List<String> _buildProficiencies(Map<String, dynamic>? profsJson) {
    if (profsJson == null) return [];

    final List<String> result = [];

    final armor = (profsJson["armor"] as List? ?? []).map((e) => e.toString());
    final weapons =
        (profsJson["weapons"] as List? ?? []).map((e) => e.toString());
    final tools = (profsJson["tools"] as List? ?? []).map((e) => e.toString());

    for (final a in armor) {
      switch (a.toLowerCase()) {
        case "light":
          result.add("Light armor");
          break;
        case "medium":
          result.add("Medium armor");
          break;
        case "heavy":
          result.add("Heavy armor");
          break;
        case "shield":
        case "shields":
          result.add("Shields");
          break;
        default:
          result.add("Armor: ${_capitalize(a)}");
      }
    }

    for (final w in weapons) {
      switch (w.toLowerCase()) {
        case "simple":
          result.add("Simple weapons");
          break;
        case "martial":
          result.add("Martial weapons");
          break;
        default:
          result.add("Weapons: ${_capitalize(w)}");
      }
    }

    for (final t in tools) {
      result.add("Tools: $t");
    }

    return result;
  }

  static List<ClassSkillChoice> _buildSkillChoices(List rawChoices) {
    return rawChoices
        .whereType<Map<String, dynamic>>()
        .map(
          (entry) => ClassSkillChoice(
            choose: (entry["choose"] as num?)?.toInt() ?? 0,
            from: (entry["from"] as List? ?? [])
                .map((e) => e.toString())
                .toList(),
          ),
        )
        .toList();
  }

  static List<DndSubclass> _buildSubclasses(List rawSubclasses) {
    return rawSubclasses
        .whereType<Map<String, dynamic>>()
        .map(
          (sub) => DndSubclass(
            name: sub["name"]?.toString() ?? "Unknown Subclass",
            source: sub["source"]?.toString() ?? "UNKNOWN",
            description: sub["description"]?.toString(),
          ),
        )
        .toList();
  }

  static DndClass _fromNormalizedJson(Map<String, dynamic> json) {
    return DndClass(
      index: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "Unknown Class",
      hitDie: (json["hitDie"] as num?)?.toInt() ?? 6,
      proficiencies: _buildProficiencies(
        json["proficiencies"] as Map<String, dynamic>?,
      ),
      savingThrows: (json["savingThrows"] as List? ?? [])
          .map((e) => e.toString().toUpperCase())
          .toList(),
      skillChoices: _buildSkillChoices(json["skillChoices"] as List? ?? []),
      startingEquipment: (json["startingEquipment"] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      subclasses: _buildSubclasses(json["subclasses"] as List? ?? []),
      spellcastingAbility:
          _mapSpellAbility(json["spellcastingAbility"]?.toString()),
    );
  }

  static Future<List<DndClass>> loadAllClasses() async {
    final jsonString = await rootBundle.loadString(_path);
    final root = jsonDecode(jsonString) as Map<String, dynamic>;
    final classes = (root["classes"] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_fromNormalizedJson)
        .toList();

    return classes;
  }

  static Future<DndClass?> loadClass(String index) async {
    final all = await loadAllClasses();
    final norm = _norm(index);

    for (final c in all) {
      if (_norm(c.index) == norm || _norm(c.name) == norm) {
        return c;
      }
    }

    return null;
  }

  static Future<Map<int, List<SubclassProgressFeature>>>
      loadSubclassProgression(
    String classIndex,
    String subclassName,
  ) async {
    final rawData = await rootBundle.loadString(_path);
    final root = jsonDecode(rawData) as Map<String, dynamic>;
    final classes =
        (root["classes"] as List? ?? []).whereType<Map<String, dynamic>>();

    Map<String, dynamic>? classJson;
    for (final c in classes) {
      final id = _norm(c["id"]?.toString() ?? "");
      final name = _norm(c["name"]?.toString() ?? "");
      if (id == _norm(classIndex) || name == _norm(classIndex)) {
        classJson = c;
        break;
      }
    }

    if (classJson == null) return {};

    final subclasses = (classJson["subclasses"] as List? ?? [])
        .whereType<Map<String, dynamic>>();

    Map<String, dynamic>? subclassJson;
    for (final sc in subclasses) {
      final id = _norm(sc["id"]?.toString() ?? "");
      final name = _norm(sc["name"]?.toString() ?? "");
      final shortName = _norm(sc["shortName"]?.toString() ?? "");

      if (id == _norm(subclassName) ||
          name == _norm(subclassName) ||
          shortName == _norm(subclassName)) {
        subclassJson = sc;
        break;
      }
    }

    if (subclassJson == null) return {};

    final progression =
        (subclassJson["progression"] as Map<String, dynamic>? ?? {});

    final Map<int, List<SubclassProgressFeature>> byLevel = {};

    for (final entry in progression.entries) {
      final level = int.tryParse(entry.key);
      if (level == null) continue;

      final features = (entry.value as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(
            (f) => SubclassProgressFeature(
              name: f["name"]?.toString() ?? "",
              level: level,
              description: f["description"]?.toString() ?? "",
            ),
          )
          .toList();

      byLevel[level] = features;
    }

    return byLevel;
  }
}
