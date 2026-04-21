import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/dnd_race.dart';
import '../models/dnd_subrace.dart';

class DataMerger {
  static Future<List<DndRace>> loadMergedRaces() async {
    try {
      print("=== DataMerger start ===");

      // --------------------------
      // 1. Cargar SRD
      // --------------------------
      final srdStr =
          await rootBundle.loadString("assets/data/5e-SRD-Races.json");
      final List srdJson = json.decode(srdStr);
      final List<DndRace> srdRaces =
          srdJson.map((e) => DndRace.fromJson(e)).toList();

      print("SRD races loaded: ${srdRaces.length}");

      // --------------------------
      // 2. Cargar races.json de 5eTools
      // --------------------------
      final toolsStr =
          await rootBundle.loadString("assets/data/5etools/races.json");
      final dynamic root = json.decode(toolsStr);

      final List allItems = (root is Map && root["race"] is List)
          ? (root["race"] as List)
          : <dynamic>[];

      print("5eTools items: ${allItems.length}");

      // --------------------------
      // 3. Cargar subraces.json (archivo separado)
      // --------------------------
      print("Loading subraces.json...");

      List rawSubraceList = [];
      try {
        final subStr =
            await rootBundle.loadString("assets/data/5etools/subraces.json");
        final subRoot = json.decode(subStr);

        if (subRoot is Map && subRoot["subrace"] is List) {
          rawSubraceList = subRoot["subrace"];
        }
      } catch (e) {
        print("ERROR loading subraces.json → $e");
      }

      print("Subraces loaded from file: ${rawSubraceList.length}");

      // --------------------------
      // 4. Filtrar razas base
      // --------------------------
      const allowedSources = {
        "PHB",
        "DMG",
        "VGM",
        "EEPC",
        "SCAG",
        "GGR",
        "ERLW",
        "EGW",
        "MOT",
      };

      print("Allowed sources: $allowedSources");

      final racesRaw = allItems.where((e) {
        if (e is! Map<String, dynamic>) return false;
        final src = e["source"];
        if (src == null || !allowedSources.contains(src)) return false;

        // excluir cosas que claramente son subrazas
        if (e.containsKey("raceName")) return false;

        return e.containsKey("ability") ||
            e.containsKey("speed") ||
            e.containsKey("entries");
      }).toList();

      print("Detected base races: ${racesRaw.length}");

      // --------------------------
      // 5. Convertir razas
      // --------------------------
      final List<DndRace> toolsRaces = racesRaw.map((raw) {
        final e = raw as Map<String, dynamic>;
        final List entries = (e["entries"] as List?) ?? const [];

        final name = (e["name"] ?? "Unknown").toString();

        return DndRace(
          index: name.toLowerCase().replaceAll(" ", "-"),
          name: name,
          speed: _parseSpeed(e["speed"]),
          abilityBonuses: _convertAbilityBonuses(e["ability"]),
          alignment: _extractBlock(entries, "Alignment"),
          age: _extractBlock(entries, "Age"),
          size: _parseSize(e["size"] ?? []),
          sizeDescription: _extractBlock(entries, "Size"),
          languages: _normalizeLanguages(e["languageProficiencies"]),
          languageDesc: _normalizeLanguageDesc(
              _normalizeLanguages(e["languageProficiencies"])),
          traits: _extractTraits(entries),
          subraces: [],
          description: _extractDescription(entries),
          book: e["source"]?.toString(),
          category: "TOOLS",
        );
      }).toList();

      print("Converted Tools races: ${toolsRaces.length}");

      // --------------------------
      // 6. Convertir subrazas desde subraces.json
      // --------------------------
      final parsedSubraces = rawSubraceList.map((s) {
        final parent = s["raceName"].toString();
        final entries = (s["entries"] as List?) ?? const [];
        final subName = s["name"].toString();

        return {
          "parent": parent,
          "object": DndSubrace(
            name: subName,
            abilityBonuses: _convertAbilityBonuses(s["ability"]),
            traits: _extractTraits(entries),
            description: _extractDescription(entries),
          ),
        };
      }).toList();

      print("Subraces converted: ${parsedSubraces.length}");

      // --------------------------
      // 7. Asignar subrazas
      // --------------------------
      print("=== Assigning subraces ===");

      for (final race in toolsRaces) {
        final parentName = race.name.toLowerCase().trim();

        final children = parsedSubraces
            .where((m) =>
                (m["parent"] as String).toLowerCase().trim() == parentName)
            .map((m) => m["object"] as DndSubrace)
            .toList();

        if (children.isNotEmpty) {
          print("✔ ${race.name} → ${children.length} subraces");
        }

        race.subraces.addAll(children);
      }

      print("=== Subrace assignment COMPLETE ===");

      // --------------------------
      // 8. Fusionar SRD + Tools
      // --------------------------
      final Map<String, DndRace> merged = {
        for (final r in srdRaces) r.name.toLowerCase(): r,
      };

      for (final toolRace in toolsRaces) {
        final key = toolRace.name.toLowerCase();

        if (!merged.containsKey(key)) {
          print("Adding Tools race: ${toolRace.name}");
          merged[key] = toolRace;
        } else {
          print("Merging SRD + Tools: ${toolRace.name}");

          final srd = merged[key]!;

          merged[key] = DndRace(
            index: srd.index,
            name: srd.name,
            speed: toolRace.speed != 30 ? toolRace.speed : srd.speed,
            abilityBonuses: toolRace.abilityBonuses.isNotEmpty
                ? toolRace.abilityBonuses
                : srd.abilityBonuses,
            alignment: toolRace.alignment.isNotEmpty
                ? toolRace.alignment
                : srd.alignment,
            age: toolRace.age.isNotEmpty ? toolRace.age : srd.age,
            size: srd.size,
            sizeDescription: srd.sizeDescription,
            languages: {...srd.languages, ...toolRace.languages}.toList(),
            languageDesc: toolRace.languageDesc.isNotEmpty
                ? toolRace.languageDesc
                : srd.languageDesc,
            traits: {...srd.traits, ...toolRace.traits}.toList(),
            subraces:
                toolRace.subraces.isNotEmpty ? toolRace.subraces : srd.subraces,
            description: (toolRace.description ?? "").isNotEmpty
                ? toolRace.description
                : srd.description,
            book: toolRace.book ?? srd.book,
            category: "MERGED",
          );
        }
      }

      print("=== MERGE COMPLETE → ${merged.length} races ===");

      return merged.values.toList();
    } catch (e) {
      print("MERGE ERROR → $e");
      return [];
    }
  }

  // ----------------------------------------------------
  // Helpers
  // ----------------------------------------------------

  static int _parseSpeed(dynamic s) {
    if (s is int) return s;
    if (s is Map && s["walk"] is int) return s["walk"] as int;
    return 30;
  }

  static String _parseSize(dynamic sizeField) {
    if (sizeField is List && sizeField.isNotEmpty) {
      return sizeField.first.toString();
    }
    return "Medium";
  }

  static List<Map<String, dynamic>> _convertAbilityBonuses(dynamic ability) {
    final List<Map<String, dynamic>> result = [];

    if (ability is Map<String, dynamic>) {
      ability.forEach((key, value) {
        if (value is num) {
          result.add({
            "ability_score": {"name": key.toString().toUpperCase()},
            "bonus": value,
          });
        }
      });
      return result;
    }

    if (ability is List) {
      for (final entry in ability) {
        if (entry is Map) {
          entry.forEach((key, value) {
            if (value is num) {
              result.add({
                "ability_score": {"name": key.toString().toUpperCase()},
                "bonus": value,
              });
            }
          });
        }
      }
    }

    return result;
  }

  static String _extractBlock(List entries, String name) {
    for (final e in entries) {
      if (e is Map &&
          (e["name"]?.toString().toLowerCase() == name.toLowerCase()) &&
          e["entries"] is List) {
        return (e["entries"] as List).join(" ");
      }
    }
    return "";
  }

  static List<String> _normalizeLanguages(dynamic langs) {
    if (langs is! List) return [];

    final List<String> result = [];

    for (final item in langs) {
      if (item is Map<String, dynamic>) {
        item.forEach((key, value) {
          if (value == true) {
            result.add(_cap(key.toString()));
          }
        });
      }
    }

    return result;
  }

  static String _normalizeLanguageDesc(List<String> langs) {
    if (langs.isEmpty) return "";
    return "You can speak, read, and write ${langs.join(" and ")}.";
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static List<String> _extractTraits(List entries) {
    return entries
        .whereType<Map>()
        .map((e) => e["name"]?.toString())
        .whereType<String>()
        .toList();
  }

  static String _extractDescription(List entries) {
    final buffer = StringBuffer();
    for (final e in entries) {
      if (e is Map && e["entries"] is List) {
        buffer.writeln((e["entries"] as List).join(" "));
      }
    }
    return buffer.toString().trim();
  }
}
