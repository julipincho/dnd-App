import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/character.dart';
import '../models/character_feature.dart';

class CharacterFeatureSyncService {
  static const String _path = 'assets/data/classes_normalized.json';

  static String _norm(String value) => value.trim().toLowerCase();

  static Future<Map<String, dynamic>?> _findClassJson(String className) async {
    final raw = await rootBundle.loadString(_path);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final classes = (json['classes'] as List? ?? []).whereType<Map>();

    final target = _norm(className);

    for (final item in classes) {
      final map = Map<String, dynamic>.from(item);
      final id = _norm(map['id']?.toString() ?? '');
      final name = _norm(map['name']?.toString() ?? '');

      if (id == target || name == target) {
        return map;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _findSubclassJson(
    Map<String, dynamic> classJson,
    String subclassName,
  ) {
    final subclasses =
        (classJson['subclasses'] as List? ?? []).whereType<Map>();
    final target = _norm(subclassName);

    for (final item in subclasses) {
      final map = Map<String, dynamic>.from(item);
      final id = _norm(map['id']?.toString() ?? '');
      final name = _norm(map['name']?.toString() ?? '');
      final shortName = _norm(map['shortName']?.toString() ?? '');

      if (id == target || name == target || shortName == target) {
        return map;
      }
    }

    return null;
  }

  static Future<List<CharacterFeature>> buildFeaturesForCharacter(
    Character character,
  ) async {
    final List<CharacterFeature> result = [];
    final classLevels = character.classLevels;

    for (final classEntry in classLevels.entries) {
      final className = classEntry.key;
      final classLevel = classEntry.value;
      final classJson = await _findClassJson(className);
      if (classJson == null) continue;

      final progression = (classJson['progression'] as List? ?? [])
          .whereType<Map<String, dynamic>>();

      for (final levelData in progression) {
        final level = (levelData['level'] as num?)?.toInt() ?? 0;
        if (level > classLevel) continue;

        final features =
            (levelData['features'] as List? ?? []).whereType<Map>().toList();

        for (final rawFeature in features) {
          final feature = Map<String, dynamic>.from(rawFeature);
          final name = feature['name']?.toString().trim() ?? '';
          final description = feature['description']?.toString().trim() ?? '';

          if (name.isEmpty) continue;

          result.add(
            CharacterFeature(
              id: 'class_${_norm(className)}_${level}_${_norm(name)}',
              name: name,
              description: description,
              source: 'class',
              unlockedAtLevel: level,
            ),
          );
        }
      }

      final subclassName = character.subclassForClass(className);
      if (subclassName != null && subclassName.trim().isNotEmpty) {
        final subclassJson = _findSubclassJson(classJson, subclassName);

        if (subclassJson != null) {
          final progression = (subclassJson['progression'] as Map? ?? {}).map(
            (key, value) => MapEntry(
              int.tryParse(key.toString()) ?? 0,
              (value as List?) ?? [],
            ),
          );

          for (final entry in progression.entries) {
            final level = entry.key;
            if (level <= 0 || level > classLevel) continue;

            final features = entry.value.whereType<Map>().toList();

            for (final rawFeature in features) {
              final feature = Map<String, dynamic>.from(rawFeature);
              final name = feature['name']?.toString().trim() ?? '';
              final description =
                  feature['description']?.toString().trim() ?? '';

              if (name.isEmpty) continue;

              result.add(
                CharacterFeature(
                  id: 'subclass_${_norm(className)}_${_norm(subclassName)}_${level}_${_norm(name)}',
                  name: name,
                  description: description,
                  source: 'subclass',
                  unlockedAtLevel: level,
                ),
              );
            }
          }
        }
      }
    }

    final unique = <String, CharacterFeature>{};
    for (final feature in result) {
      unique[feature.id] = feature;
    }

    return unique.values.toList()
      ..sort((a, b) {
        final levelCompare =
            (a.unlockedAtLevel ?? 0).compareTo(b.unlockedAtLevel ?? 0);
        if (levelCompare != 0) return levelCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }
}
