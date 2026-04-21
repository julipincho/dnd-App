import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/journal_entry.dart';

class JournalEntryStorage {
  static const String _entriesKey = 'journal_entries';

  static Future<void> saveEntries(List<JournalEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_entriesKey, encoded);
  }

  static Future<List<JournalEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_entriesKey) ?? [];

    return raw.map((item) => JournalEntry.fromJson(jsonDecode(item))).toList();
  }
}
