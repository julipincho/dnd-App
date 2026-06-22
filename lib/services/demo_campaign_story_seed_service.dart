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
    await compendiumProvider.loadEntries();

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
            'A careful archivist who tracks old seals, false prophecies and the movements of the Ashen Concord. Mira knows the Broken Gate answers to names spoken with intent.',
        type: 'npc',
        imagePath: 'assets/images/classes/wizard.png',
        createdAt: DateTime(2026, 3, 1, 10),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-ruins-thalanor',
        campaignId: campaignId,
        title: 'Ruins of Thalanor',
        description:
            'A collapsed elven city where the Broken Gate still hums beneath moonlit stone.',
        type: 'location',
        imagePath: 'assets/images/combat/dungeon_battlefield.png',
        createdAt: DateTime(2026, 3, 1, 10, 5),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-dawn-compass',
        campaignId: campaignId,
        title: 'Dawn Compass',
        description:
            'A brass compass that points toward unfinished promises instead of north.',
        type: 'item',
        imagePath: 'assets/images/classes/artificer.png',
        createdAt: DateTime(2026, 3, 1, 10, 10),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-ashen-concord',
        campaignId: campaignId,
        title: 'Ashen Concord',
        description:
            'A faction of oathbreakers trying to reopen the Broken Gate for reasons they call mercy.',
        type: 'faction',
        imagePath: 'assets/images/classes/warlock.png',
        createdAt: DateTime(2026, 3, 1, 10, 15),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-broken-gate',
        campaignId: campaignId,
        title: 'Broken Gate',
        description:
            'An ancient threshold under the Ruins of Thalanor. It reacts to memory, grief and spoken names.',
        type: 'lore',
        imagePath: 'assets/images/classes/sorcerer.png',
        createdAt: DateTime(2026, 3, 1, 10, 20),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-ilyra',
        campaignId: campaignId,
        title: 'Ilyra of the Moonwell',
        description:
            'An elven scout who guards the Moonwell Vault and distrusts anyone carrying Ashen Concord marks.',
        type: 'npc',
        imagePath: 'assets/images/races/elf.png',
        createdAt: DateTime(2026, 3, 1, 10, 25),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-moonwell-vault',
        campaignId: campaignId,
        title: 'Moonwell Vault',
        description:
            'A submerged sanctuary below Thalanor where vows are preserved as silver light.',
        type: 'location',
        imagePath: 'assets/images/classes/druid.png',
        createdAt: DateTime(2026, 3, 1, 10, 30),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-verdant-seal',
        campaignId: campaignId,
        title: 'Verdant Seal',
        description:
            'A living sigil that can quiet the Broken Gate if carried by someone who has broken an oath and repaired it.',
        type: 'item',
        imagePath: 'assets/images/classes/cleric.png',
        createdAt: DateTime(2026, 3, 1, 10, 35),
      ),
      CompendiumEntry(
        id: '$idPrefix-compendium-starless-prince',
        campaignId: campaignId,
        title: 'Starless Prince',
        description:
            'A name preserved in Moonwell warnings. The Ashen Concord treats him as a lost heir, while Ilyra calls him the first broken promise.',
        type: 'npc',
        imagePath: 'assets/images/classes/warlock.png',
        createdAt: DateTime(2026, 3, 1, 10, 40),
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
            'The party reached [[location:Ruins of Thalanor]] and found [[npc:Mira Valen]] hiding records about the [[lore:Broken Gate]]. Mira claimed the [[faction:Ashen Concord]] had already translated part of the seal-song.',
        summary:
            'The group arrived at [[location:Ruins of Thalanor]] and learned that the [[lore:Broken Gate]] is no longer dormant.',
        imagePath: 'assets/images/combat/dungeon_battlefield.png',
        playerNarrativeRecap:
            'The first thread began with [[npc:Mira Valen]], the [[location:Ruins of Thalanor]] and a warning about the [[faction:Ashen Concord]].',
        dmNarrativeRecap:
            'Mira is withholding the name of the person who first woke the Broken Gate.',
      ),
      Session(
        id: '$idPrefix-session-02',
        campaignId: campaignId,
        title: 'Session 2 - Compass at Dawn',
        date: DateTime(2026, 3, 11, 20),
        rawNotes:
            'The [[item:Dawn Compass]] moved when each character spoke a secret. The [[faction:Ashen Concord]] watched from the old aqueduct and fled toward the [[location:Moonwell Vault]].',
        summary:
            'The [[item:Dawn Compass]] revealed a path through memory, and the [[faction:Ashen Concord]] made its first open move.',
        imagePath: 'assets/images/classes/artificer.png',
        playerNarrativeRecap:
            'The party discovered that the [[item:Dawn Compass]] responds to unfinished promises.',
        dmNarrativeRecap:
            'The compass also points toward whoever regrets the promise most, which will matter later.',
      ),
      Session(
        id: '$idPrefix-session-03',
        campaignId: campaignId,
        title: 'Session 3 - The Moonwell Oath',
        date: DateTime(2026, 3, 18, 20),
        rawNotes:
            'At the [[location:Moonwell Vault]], [[npc:Ilyra of the Moonwell]] demanded an oath before opening the drowned archive. The [[item:Verdant Seal]] pulsed when the party mentioned the [[npc:Starless Prince]].',
        summary:
            'The party entered the [[location:Moonwell Vault]], earned [[npc:Ilyra of the Moonwell]] as a wary ally and recovered the [[item:Verdant Seal]].',
        imagePath: 'assets/images/classes/druid.png',
        playerNarrativeRecap:
            'A new path opened below Thalanor: [[npc:Ilyra of the Moonwell]], the [[location:Moonwell Vault]] and the [[item:Verdant Seal]] are now tied to the fate of the [[lore:Broken Gate]].',
        dmNarrativeRecap:
            'The Starless Prince is tied to the first oath that damaged the Broken Gate.',
      ),
      Session(
        id: '$idPrefix-session-04',
        campaignId: campaignId,
        title: 'Session 4 - Ashes Below Thalanor',
        date: DateTime(2026, 3, 25, 20),
        rawNotes:
            'The [[faction:Ashen Concord]] returned beneath the [[location:Ruins of Thalanor]] and tried to bind the [[item:Verdant Seal]] to the [[lore:Broken Gate]]. [[npc:Mira Valen]] chose to reveal her old oath.',
        summary:
            'Beneath the [[location:Ruins of Thalanor]], the party stopped the [[faction:Ashen Concord]] from binding the [[item:Verdant Seal]] to the [[lore:Broken Gate]].',
        imagePath: 'assets/images/classes/rogue.png',
        playerNarrativeRecap:
            'The first arc ended with the [[item:Verdant Seal]] intact, [[npc:Mira Valen]] exposed and the [[lore:Broken Gate]] quieter but not silent.',
        dmNarrativeRecap:
            'The Concord failed, but their leader escaped with one phrase from the seal-song.',
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
            '[[npc:Mira Valen]] explains that the [[lore:Broken Gate]] is tied to the [[location:Ruins of Thalanor]] and asks the group not to trust the [[faction:Ashen Concord]].',
        date: DateTime(2026, 3, 4, 20, 35),
        type: 'dialogue',
      ),
      CampaignEvent(
        id: '$idPrefix-event-02',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-01',
        title: 'The seal answers',
        description:
            'The [[lore:Broken Gate]] flashes when the [[item:Dawn Compass]] is brought near the central seal.',
        date: DateTime(2026, 3, 4, 21, 25),
        type: 'discovery',
      ),
      CampaignEvent(
        id: '$idPrefix-event-03',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-02',
        title: 'Ambush at the aqueduct',
        description:
            'Agents of the [[faction:Ashen Concord]] attack near the [[location:Ruins of Thalanor]] and try to steal the [[item:Dawn Compass]].',
        date: DateTime(2026, 3, 11, 21, 10),
        type: 'combat',
      ),
      CampaignEvent(
        id: '$idPrefix-event-04',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-02',
        title: 'The compass chooses a path',
        description:
            'The [[item:Dawn Compass]] points away from the road and toward the hidden entrance of the [[location:Moonwell Vault]].',
        date: DateTime(2026, 3, 11, 21, 45),
        type: 'travel',
      ),
      CampaignEvent(
        id: '$idPrefix-event-05',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-03',
        title: 'Ilyra names the oath-price',
        description:
            '[[npc:Ilyra of the Moonwell]] refuses to open the [[location:Moonwell Vault]] until each hero names one promise they intend to keep.',
        date: DateTime(2026, 3, 18, 20, 40),
        type: 'dialogue',
      ),
      CampaignEvent(
        id: '$idPrefix-event-06',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-03',
        title: 'The Verdant Seal wakes',
        description:
            'The [[item:Verdant Seal]] blooms with silver-green light and shows a reflection of the [[npc:Starless Prince]].',
        date: DateTime(2026, 3, 18, 21, 35),
        type: 'discovery',
      ),
      CampaignEvent(
        id: '$idPrefix-event-07',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-04',
        title: 'Concord ritual interrupted',
        description:
            'The party breaks the [[faction:Ashen Concord]] circle before the [[item:Verdant Seal]] can be locked into the [[lore:Broken Gate]].',
        date: DateTime(2026, 3, 25, 21, 5),
        type: 'quest',
      ),
      CampaignEvent(
        id: '$idPrefix-event-08',
        campaignId: campaignId,
        sessionId: null,
        title: 'Rumor reaches the coast',
        description:
            'Travelers claim the [[faction:Ashen Concord]] is buying maps that mark every road into the [[location:Ruins of Thalanor]].',
        date: DateTime(2026, 3, 28, 12),
        type: 'rumor',
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
            'Kael does not trust [[npc:Mira Valen]] yet, but the [[lore:Broken Gate]] felt alive when the [[item:Dawn Compass]] moved.',
        imagePath: 'assets/images/classes/fighter.png',
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
            'Nim thinks the [[location:Ruins of Thalanor]] are listening. The [[faction:Ashen Concord]] knew exactly when [[npc:Mira Valen]] would speak.',
        imagePath: 'assets/images/classes/rogue.png',
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
            'Seren promised to keep the [[item:Dawn Compass]] away from the [[faction:Ashen Concord]], even if the [[lore:Broken Gate]] calls again.',
        imagePath: 'assets/images/classes/paladin.png',
        createdAt: DateTime(2026, 3, 11, 22, 15),
      ),
      JournalEntry(
        id: '$idPrefix-note-04',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-03',
        authorRole: 'player',
        authorName: 'Liora',
        authorCharacterName: 'Liora',
        authorCharacterId: '$idPrefix-character-liora',
        authorUserId: '$idPrefix-user-liora',
        content:
            'Liora believes [[npc:Ilyra of the Moonwell]] is protecting someone, not just the [[location:Moonwell Vault]]. The [[item:Verdant Seal]] reacted to guilt.',
        imagePath: 'assets/images/classes/bard.png',
        createdAt: DateTime(2026, 3, 18, 22, 5),
      ),
      JournalEntry(
        id: '$idPrefix-note-05',
        campaignId: campaignId,
        sessionId: '$idPrefix-session-04',
        authorRole: 'player',
        authorName: 'Nim',
        authorCharacterName: 'Nim',
        authorCharacterId: '$idPrefix-character-nim',
        authorUserId: '$idPrefix-user-nim',
        content:
            'Nim stole a burned token from the [[faction:Ashen Concord]] ritual. It smells like the [[location:Moonwell Vault]] after rain.',
        imagePath: 'assets/images/classes/rogue.png',
        createdAt: DateTime(2026, 3, 25, 22, 18),
      ),
      JournalEntry(
        id: '$idPrefix-note-06',
        campaignId: campaignId,
        sessionId: null,
        authorRole: 'dm',
        authorName: 'DM',
        authorUserId: '$idPrefix-user-dm',
        content:
            'Private thread: the [[npc:Starless Prince]] knows why the [[lore:Broken Gate]] answers to promises broken beneath the [[location:Ruins of Thalanor]].',
        createdAt: DateTime(2026, 3, 28, 12, 30),
      ),
    ];
  }
}
