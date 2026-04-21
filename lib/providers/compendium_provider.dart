import 'package:flutter/foundation.dart';
import '../models/compendium_entry.dart';
import '../services/compendium_storage.dart';

class CompendiumProvider extends ChangeNotifier {
  List<CompendiumEntry> _entries = [];

  List<CompendiumEntry> get entries => _entries;

  Future<void> loadEntries() async {
    _entries = await CompendiumStorage.loadEntries();
    notifyListeners();
  }

  List<CompendiumEntry> getEntriesByCampaign(String campaignId) {
    return _entries.where((entry) => entry.campaignId == campaignId).toList();
  }

  Future<void> addEntry(CompendiumEntry entry) async {
    _entries = [..._entries, entry];
    await CompendiumStorage.saveEntries(_entries);
    notifyListeners();
  }

  Future<void> updateEntry(CompendiumEntry updatedEntry) async {
    _entries = _entries
        .map((entry) => entry.id == updatedEntry.id ? updatedEntry : entry)
        .toList();

    await CompendiumStorage.saveEntries(_entries);
    notifyListeners();
  }

  Future<void> removeEntry(String entryId) async {
    _entries = _entries.where((entry) => entry.id != entryId).toList();
    await CompendiumStorage.saveEntries(_entries);
    notifyListeners();
  }
}
