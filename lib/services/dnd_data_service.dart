// lib/services/dnd_data_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/dnd_background.dart';
import '../models/dnd_race.dart';
import '../models/dnd_class.dart';

import 'data_merger.dart';
import 'class_data_service.dart';

class DndDataService {
  // -------------------------------------------------------------
  // BACKGROUNDS (JSON unificado y limpio)
  // -------------------------------------------------------------
  static Future<List<DndBackground>> getBackgrounds() async {
    final jsonStr = await rootBundle.loadString('assets/data/backgrounds.json');
    final data = jsonDecode(jsonStr);

    // ✅ soporta:
    // - raíz List
    // - raíz Map { background: [] }
    final List rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map && data['background'] is List) {
      rawList = data['background'] as List;
    } else {
      return [];
    }

    final seen = <String>{};
    final result = <DndBackground>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final bg = DndBackground.fromJson(map);

      // dedupe por nombre + source si existe
      final source = map['source']?.toString() ?? '';
      final key = '${bg.name}|$source'.toLowerCase().trim();

      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(bg);
    }

    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  // -------------------------------------------------------------
  // RACES (SRD + 5eTools via DataMerger)
  // -------------------------------------------------------------
  static List<DndRace>? _cachedRaces;

  static Future<List<DndRace>> getRaces() async {
    if (_cachedRaces != null) return _cachedRaces!;

    try {
      final merged = await DataMerger.loadMergedRaces();
      merged.sort((a, b) => a.name.compareTo(b.name));
      _cachedRaces = merged;
      return merged;
    } catch (e) {
      print('ERROR loading merged races → $e');
      return [];
    }
  }

  // -------------------------------------------------------------
  // CLASSES (SRD + 5eTools via ClassDataService)
  // -------------------------------------------------------------
  static Future<List<DndClass>> getAllClasses() async {
    final classes = await ClassDataService.loadAllClasses();
    classes.sort((a, b) => a.name.compareTo(b.name));
    return classes;
  }

  static Future<DndClass?> loadClass(String input) async {
    final all = await getAllClasses();
    final norm = input.trim().toLowerCase();

    try {
      return all.firstWhere(
        (cls) =>
            cls.index.toLowerCase() == norm || cls.name.toLowerCase() == norm,
      );
    } catch (_) {
      return null;
    }
  }

  /// Solo nombres oficiales SRD
  static Future<List<String>> getOfficialClassNames() async {
    final jsonStr =
        await rootBundle.loadString('assets/data/5e-SRD-Classes.json');

    final raw = jsonDecode(jsonStr) as List;

    return raw
        .map((c) => c['index'].toString())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
  }
}
