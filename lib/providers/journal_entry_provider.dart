import 'package:flutter/foundation.dart';
import '../models/journal_entry.dart';
import '../services/journal_entry_storage.dart';

class JournalEntryProvider extends ChangeNotifier {
  List<JournalEntry> _entries = [];

  List<JournalEntry> get entries => _entries;

  Future<void> loadEntries() async {
    _entries = await JournalEntryStorage.loadEntries();
    notifyListeners();
  }

  List<JournalEntry> getEntriesBySession(String sessionId) {
    return _entries.where((e) => e.sessionId == sessionId).toList();
  }

  List<JournalEntry> getEntriesByCharacter(String characterId) {
    return _entries.where((e) => e.authorCharacterId == characterId).toList();
  }

  Future<void> addEntry(JournalEntry entry) async {
    _entries = [..._entries, entry];
    await JournalEntryStorage.saveEntries(_entries);
    notifyListeners();
  }

  Future<void> removeEntry(String entryId) async {
    _entries = _entries.where((e) => e.id != entryId).toList();
    await JournalEntryStorage.saveEntries(_entries);
    notifyListeners();
  }

  Future<void> updateEntry(JournalEntry updated) async {
    _entries = _entries.map((e) => e.id == updated.id ? updated : e).toList();
    await JournalEntryStorage.saveEntries(_entries);
    notifyListeners();
  }
}
