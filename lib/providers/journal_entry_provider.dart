import 'package:flutter/foundation.dart';
import '../models/journal_entry.dart';
import '../services/journal_entry_cloud_repository.dart';
import '../services/journal_entry_storage.dart';

class JournalEntryProvider extends ChangeNotifier {
  final JournalEntryCloudRepository _cloudRepo = JournalEntryCloudRepository();

  List<JournalEntry> _entries = [];
  String? _activeCampaignId;

  List<JournalEntry> get entries => _entries;

  Future<void> loadEntries([String? campaignId]) async {
    _activeCampaignId = campaignId ?? _activeCampaignId;

    if (_activeCampaignId != null && _activeCampaignId!.isNotEmpty) {
      _entries = await _cloudRepo.getEntriesByCampaign(_activeCampaignId!);
    } else {
      _entries = await JournalEntryStorage.loadEntries();
    }

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
    if (entry.campaignId.isNotEmpty) {
      await _cloudRepo.saveEntry(entry);
      _activeCampaignId = entry.campaignId;
    } else {
      await JournalEntryStorage.saveEntries(_entries);
    }
    notifyListeners();
  }

  Future<void> removeEntry(String entryId) async {
    JournalEntry? deleted;
    for (final entry in _entries) {
      if (entry.id == entryId) {
        deleted = entry;
        break;
      }
    }

    _entries = _entries.where((e) => e.id != entryId).toList();
    if (deleted != null && deleted.campaignId.isNotEmpty) {
      await _cloudRepo.deleteEntry(entryId);
    } else {
      await JournalEntryStorage.saveEntries(_entries);
    }
    notifyListeners();
  }

  Future<void> updateEntry(JournalEntry updated) async {
    _entries = _entries.map((e) => e.id == updated.id ? updated : e).toList();
    if (updated.campaignId.isNotEmpty) {
      await _cloudRepo.saveEntry(updated);
      _activeCampaignId = updated.campaignId;
    } else {
      await JournalEntryStorage.saveEntries(_entries);
    }
    notifyListeners();
  }
}
