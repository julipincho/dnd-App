import '../models/campaign_event.dart';
import '../models/compendium_entry.dart';
import '../models/journal_entry.dart';
import '../models/session.dart';
import '../models/story_timeline_item.dart';
import '../utils/compendium_linking.dart';

class CampaignStoryTimelineService {
  const CampaignStoryTimelineService._();

  static List<StoryTimelineItem> buildItems({
    required List<Session> sessions,
    required List<CampaignEvent> events,
    required List<JournalEntry> entries,
    required bool isDm,
    required bool showPrivateNotes,
    required String recapMode,
  }) {
    final sessionsById = {
      for (final session in sessions) session.id: session,
    };

    return <StoryTimelineItem>[
      ...sessions.map(
        (session) => StoryTimelineItem.fromSession(
          session,
          isDm: isDm,
          recapMode: recapMode,
        ),
      ),
      ...events.map(
        (event) => StoryTimelineItem.fromEvent(
          event,
          linkedSession:
              event.sessionId == null ? null : sessionsById[event.sessionId],
        ),
      ),
      ...entries
          .where((entry) => showPrivateNotes || !isPrivateEntry(entry))
          .where((entry) => isDm || !isPrivateEntry(entry))
          .map(
            (entry) => StoryTimelineItem.fromJournalEntry(
              entry,
              linkedSession: entry.sessionId == null
                  ? null
                  : sessionsById[entry.sessionId],
            ),
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  static List<StoryTimelineItem> filterItems({
    required List<StoryTimelineItem> items,
    required String query,
    required String kindFilter,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final normalizedQuery = query.toLowerCase().trim();

    bool matchesSearch(String text) {
      if (normalizedQuery.isEmpty) return true;
      return text.toLowerCase().contains(normalizedQuery);
    }

    return items.where((item) {
      if (kindFilter != 'all' && item.kind != kindFilter) return false;

      final mentionMatches = normalizedQuery.isNotEmpty &&
          CompendiumLinking.mentionedEntries(
            text: item.linkText,
            entries: compendiumEntries,
          ).any((entry) => matchesSearch(entry.title));

      return matchesSearch(item.searchText) || mentionMatches;
    }).toList();
  }

  static List<JournalEntry> visibleJournalEntries({
    required List<JournalEntry> entries,
    required bool isDm,
    required bool showPrivateNotes,
  }) {
    return entries
        .where((entry) => showPrivateNotes || !isPrivateEntry(entry))
        .where((entry) => isDm || !isPrivateEntry(entry))
        .toList();
  }

  static StoryTimelineStats buildStats({
    required List<Session> sessions,
    required List<CampaignEvent> events,
    required List<JournalEntry> visibleJournalEntries,
    required List<StoryTimelineItem> items,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final voiceCount = visibleJournalEntries
        .map((entry) => entry.authorCharacterName ?? entry.authorName)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .length;

    final linkedMentionCount = items.fold<int>(
      0,
      (count, item) =>
          count +
          CompendiumLinking.mentionedEntries(
            text: item.linkText,
            entries: compendiumEntries,
          ).length,
    );

    return StoryTimelineStats(
      sessionCount: sessions.length,
      eventCount: events.length,
      noteCount: visibleJournalEntries.length,
      voiceCount: voiceCount,
      linkedMentionCount: linkedMentionCount,
    );
  }

  static bool isPrivateEntry(JournalEntry entry) {
    return entry.sessionId == null || entry.sessionId!.isEmpty;
  }
}
