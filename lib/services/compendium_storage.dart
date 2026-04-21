import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/compendium_entry.dart';

class CompendiumStorage {
  static const String _entriesKey = 'compendium_entries';

  static Future<void> saveEntries(List<CompendiumEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson =
        entries.map((entry) => jsonEncode(entry.toJson())).toList();

    await prefs.setStringList(_entriesKey, entriesJson);
  }

  static Future<List<CompendiumEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_entriesKey) ?? [];

    return entriesJson
        .map((item) => CompendiumEntry.fromJson(jsonDecode(item)))
        .toList();
  }
}
