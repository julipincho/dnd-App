import '../models/campaign_event.dart';
import '../models/compendium_entry.dart';
import '../models/journal_entry.dart';
import '../models/session.dart';
import '../providers/campaign_event_provider.dart';
import '../providers/compendium_provider.dart';
import '../providers/journal_entry_provider.dart';
import '../providers/session_provider.dart';

class DemoCampaignStorySeedService {
  static const String idPrefix = 'demo-shared-story';

  const DemoCampaignStorySeedService._();

  static bool hasDemoData({
    required String campaignId,
    required SessionProvider sessionProvider,
    required CampaignEventProvider eventProvider,
    required JournalEntryProvider journalProvider,
    required CompendiumProvider compendiumProvider,
  }) {
    return sessionProvider.sessions.any(_isDemoEntityFor(campaignId)) ||
        eventProvider.events.any(_isDemoEntityFor(campaignId)) ||
        journalProvider.entries.any(_isDemoEntityFor(campaignId)) ||
        compendiumProvider.entries.any(_isDemoEntityFor(campaignId));
  }

  static Future<void> seed({
    required String campaignId,
    required SessionProvider sessionProvider,
    required CampaignEventProvider eventProvider,
    required JournalEntryProvider journalProvider,
    required CompendiumProvider compendiumProvider,
  }) async {
    final sessions = _sessions(campaignId);
    final events = _events(campaignId);
    final entries = _journalEntries(campaignId);
    final compendiumEntries = _compendiumEntries(campaignId);

    for (final entry in compendiumEntries) {
      if (!compendiumProvider.entries.any((item) => item.id == entry.id)) {
        await compendiumProvider.addEntry(entry);
      }
    }

    for (final session in sessions) {
      if (!sessionProvider.sessions.any((item) => item.id == session.id)) {
        await sessionProvider.addSession(session);
      }
    }

    for (final event in events) {
      if (!eventProvider.events.any((item) => item.id == event.id)) {
        await eventProvider.addEvent(event);
      }
    }

    for (final entry in entries) {
      if (!journalProvider.entries.any((item) => item.id == entry.id)) {
        await journalProvider.addEntry(entry);
      }
    }
  }

  static Future<void> clear({
    required String campaignId,
    required SessionProvider sessionProvider,
    required CampaignEventProvider eventProvider,
    required JournalEntryProvider journalProvider,
    required CompendiumProvider compendiumProvider,
  }) async {
    final demoJournalEntries = journalProvider.entries
        .where(_isDemoEntityFor(campaignId))
        .map((entry) => entry.id)
        .toList();
    final demoEvents = eventProvider.events
        .where(_isDemoEntityFor(campaignId))
        .map((event) => event.id)
        .toList();
    final demoSessions = sessionProvider.sessions
        .where(_isDemoEntityFor(campaignId))
        .map((session) => session.id)
        .toList();
    final demoCompendiumEntries = compendiumProvider.entries
        .where(_isDemoEntityFor(campaignId))
        .map((entry) => entry.id)
        .toList();

    for (final id in demoJournalEntries) {
      await journalProvider.removeEntry(id);
    }
    for (final id in demoEvents) {
      await eventProvider.removeEvent(id);
    }
    for (final id in demoSessions) {
      await sessionProvider.removeSession(id);
    }
    for (final id in demoCompendiumEntries) {
      await compendiumProvider.removeEntry(id);
    }
  }

  static bool Function(dynamic entity) _isDemoEntityFor(String campaignId) {
    return (dynamic entity) {
      final id = entity.id?.toString() ?? '';
      final entityCampaignId = entity.campaignId?.toString() ?? '';
      return entityCampaignId == campaignId && id.startsWith(idPrefix);
    };
  }

  static List<CompendiumEntry> _compendiumEntries(String campaignId) {
    return [
      CompendiumEntry(
        id: '$idPrefix-compendium-mira-valen',
        campaignId: campaignId,
        title: 'Mira Valen',
        description:
            'A careful archivist who tracks old seals, false prophecies and the movements of the Ashen Concord.',
        type: 'npc',
        createdAt: DateTime(2026, 3, 1, 10),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-ruins-thalanor',
        campaignId: campaignId,
        title: 'Ruins of Thalanor',
        description:
            'A collapsed elven city where the Broken Gate still hums beneath moonlit stone.',
        type: 'location',
        createdAt: DateTime(2026, 3, 1, 10, 5),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-dawn-compass',
        campaignId: campaignId,
        title: 'Dawn Compass',
        description:
            'A brass compass that points toward unfinished promises instead of north.',
        type: 'item',
        createdAt: DateTime(2026, 3, 1, 10, 10),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-ashen-concord',
        campaignId: campaignId,
        title: 'Ashen Concord',
        description:
            'A faction of oathbreakers trying to reopen the Broken Gate for reasons they call mercy.',
        type: 'faction',
        createdAt: DateTime(2026, 3, 1, 10, 15),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-broken-gate',
        campaignId: campaignId,
        title: 'Broken Gate',
        description:
            'An ancient threshold under the Ruins of Thalanor. It reacts to memory, grief and spoken names.',
        type: 'lore',
        createdAt: DateTime(2026, 3, 1, 10, 20),
      ),
    ];
  }

  static List<Session> _sessions(String campaignId) {
    return [
      Session(
        id: '$idPrefix-session-01',
        campaignId: campaignId,
        title: 'Session 1 - The Broken Gate',
        date: DateTime(2026, 3, 4, 20),
        rawNotes:
            'The party reached the Ruins of Thalanor and found Mira Valen hiding records about the Broken Gate.',
        summary:
            'The group arrived at the Ruins of Thalanor and learned that the Broken Gate is no longer dormant.',
        playerNarrativeRecap:
            'The first thread began with Mira Valen, the Ruins of Thalanor and a warning about the Ashen Concord.',
      ),
      Session(
        id: '$idPrefix-session-02',
        campaignId: campaignId,
        title: 'Session 2 - Compass at Dawn',
        date: DateTime(2026, 3, 11, 20),
        rawNotes:
            'The Dawn Compass moved when each character spoke a secret. The Ashen Concord watched from the old aqueduct.',
        summary:
            'The Dawn Compass revealed a path through memory, and the Ashen Concord made its first open move.',
        playerNarrativeRecap:
            'The party discovered that the Dawn Compass responds to unfinished promises.',
      ),
    ];
  }

  static List<CampaignEvent> _events(String campaignId) {
    return [
      CampaignEvent(
        id: '$idPrefix-event-01',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-01',
        title: 'Mira warns the party',
        description:
            'Mira Valen explains that the Broken Gate is tied to the Ruins of Thalanor and asks the group not to trust the Ashen Concord.',
        date: DateTime(2026, 3, 4, 20, 35),
        type: 'dialogue',
      ),
      CampaignEvent(
        id: '$idPrefix-event-02',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-01',
        title: 'The seal answers',
        description:
            'The Broken Gate flashes when the Dawn Compass is brought near the central seal.',
        date: DateTime(2026, 3, 4, 21, 25),
        type: 'discovery',
      ),
      CampaignEvent(
        id: '$idPrefix-event-03',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-02',
        title: 'Ambush at the aqueduct',
        description:
            'Agents of the Ashen Concord attack near the Ruins of Thalanor and try to steal the Dawn Compass.',
        date: DateTime(2026, 3, 11, 21, 10),
        type: 'combat',
      ),
    ];
  }

  static List<JournalEntry> _journalEntries(String campaignId) {
    return [
      JournalEntry(
        id: '$idPrefix-note-01',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-01',
        authorRole: 'player',
        authorName: 'Kael',
        authorCharacterName: 'Kael',
        authorCharacterId: '$idPrefix-character-kael',
        authorUserId: '$idPrefix-user-kael',
        content:
            'Kael does not trust Mira Valen yet, but the Broken Gate felt alive when the Dawn Compass moved.',
        createdAt: DateTime(2026, 3, 4, 22),
      ),
      JournalEntry(
        id: '$idPrefix-note-02',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-01',
        authorRole: 'player',
        authorName: 'Nim',
        authorCharacterName: 'Nim',
        authorCharacterId: '$idPrefix-character-nim',
        authorUserId: '$idPrefix-user-nim',
        content:
            'Nim thinks the Ruins of Thalanor are listening. The Ashen Concord knew exactly when Mira Valen would speak.',
        createdAt: DateTime(2026, 3, 4, 22, 7),
      ),
      JournalEntry(
        id: '$idPrefix-note-03',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-02',
        authorRole: 'player',
        authorName: 'Seren',
        authorCharacterName: 'Seren',
        authorCharacterId: '$idPrefix-character-seren',
        authorUserId: '$idPrefix-user-seren',
        content:
            'Seren promised to keep the Dawn Compass away from the Ashen Concord, even if the Broken Gate calls again.',
        createdAt: DateTime(2026, 3, 11, 22, 15),
      ),
    ];
  }
}
