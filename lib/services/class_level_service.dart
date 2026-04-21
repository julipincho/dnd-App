import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/dnd_class_level.dart';

class ClassLevelService {
  static const String _path = "assets/data/classes_normalized.json";

  static String _norm(String s) => s.trim().toLowerCase();

  static Future<Map<String, dynamic>?> _findClassJson(String classIndex) async {
    final jsonString = await rootBundle.loadString(_path);
    final root = jsonDecode(jsonString) as Map<String, dynamic>;
    final classes = (root["classes"] as List? ?? []);

    final normalized = _norm(classIndex);

    for (final item in classes) {
      if (item is! Map<String, dynamic>) continue;

      final id = _norm(item["id"]?.toString() ?? "");
      final name = _norm(item["name"]?.toString() ?? "");

      if (id == normalized || name == normalized) {
        return item;
      }
    }

    return null;
  }

  static Map<String, dynamic> _buildSrdLikeLevelJson(
    Map<String, dynamic> classJson,
    Map<String, dynamic> levelJson,
  ) {
    final features = (levelJson["features"] as List? ?? [])
        .whereType<Map>()
        .map((f) => {
              "name": f["name"]?.toString() ?? "",
            })
        .toList();

    final spellcasting = levelJson["spellcasting"] as Map<String, dynamic>?;
    final spellSlots =
        (spellcasting?["spellSlots"] as List? ?? List.filled(9, 0))
            .map((e) => (e as num).toInt())
            .toList();

    while (spellSlots.length < 9) {
      spellSlots.add(0);
    }

    return {
      "level": levelJson["level"],
      "prof_bonus": levelJson["profBonus"],
      "class": {
        "index": classJson["id"],
        "name": classJson["name"],
      },
      "features": features,
      "spellcasting": spellcasting == null
          ? null
          : {
              "cantrips_known": spellcasting["cantripsKnown"],
              "spells_known": spellcasting["spellsKnown"],
              "prepared_spells": spellcasting["preparedSpellsCount"],
              "spell_slots_level_1": spellSlots[0],
              "spell_slots_level_2": spellSlots[1],
              "spell_slots_level_3": spellSlots[2],
              "spell_slots_level_4": spellSlots[3],
              "spell_slots_level_5": spellSlots[4],
              "spell_slots_level_6": spellSlots[5],
              "spell_slots_level_7": spellSlots[6],
              "spell_slots_level_8": spellSlots[7],
              "spell_slots_level_9": spellSlots[8],
            },
    };
  }

  static Future<Map<int, DndClassLevel>> loadLevelsForClass(
    String classIndex,
  ) async {
    final classJson = await _findClassJson(classIndex);

    if (classJson == null) {
      print("⚠ WARNING: No class found in normalized data: $classIndex");
      return {};
    }

    final progression = (classJson["progression"] as List? ?? [])
        .whereType<Map<String, dynamic>>();

    final Map<int, DndClassLevel> levels = {};

    for (final rawLevel in progression) {
      final normalizedLevelJson = _buildSrdLikeLevelJson(classJson, rawLevel);
      final lvl = DndClassLevel.fromJson(normalizedLevelJson);
      levels[lvl.level] = lvl;
    }

    if (levels.isEmpty) {
      print("⚠ WARNING: No levels found for class: $classIndex");
    }

    return levels;
  }

  static Future<DndClassLevel?> loadLevel(String classIndex, int level) async {
    final all = await loadLevelsForClass(classIndex);

    if (!all.containsKey(level)) {
      print("⚠ WARNING: Level $level not found for class: $classIndex");
    }

    return all[level];
  }
}
