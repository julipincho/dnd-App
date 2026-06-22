import 'campaign_event.dart';
import 'journal_entry.dart';
import 'session.dart';

class StoryTimelineItem {
  final String id;
  final String campaignId;
  final String kind;
  final String title;
  final String body;
  final String linkText;
  final String searchText;
  final DateTime date;
  final String? type;
  final String? author;
  final bool isPrivate;
  final Session? linkedSession;

  const StoryTimelineItem({
    required this.id,
    required this.campaignId,
    required this.kind,
    required this.title,
    required this.body,
    required this.linkText,
    required this.searchText,
    required this.date,
    this.type,
    this.author,
    this.isPrivate = false,
    this.linkedSession,
  });

  factory StoryTimelineItem.fromSession(
    Session session, {
    required bool isDm,
    required String recapMode,
  }) {
    final preferredRecap = recapMode == 'dm'
        ? session.dmNarrativeRecap
        : session.playerNarrativeRecap;
    final bodyParts = <String>[
      if ((session.summary ?? '').trim().isNotEmpty) session.summary!.trim(),
      if ((preferredRecap ?? '').trim().isNotEmpty) preferredRecap!.trim(),
      if (isDm && session.rawNotes.trim().isNotEmpty) session.rawNotes.trim(),
    ];
    final body = bodyParts.isEmpty
        ? 'Session opened on the campaign timeline.'
        : bodyParts.join('\n\n');
    final title = session.title.trim().isEmpty
        ? 'Untitled session'
        : session.title.trim();

    return StoryTimelineItem(
      id: 'session:${session.id}',
      campaignId: session.campaignId,
      kind: 'session',
      title: title,
      body: body,
      linkText: '$title\n$body',
      searchText:
          '$title ${session.summary ?? ''} ${session.playerNarrativeRecap ?? ''} ${isDm ? session.rawNotes : ''} ${isDm ? session.dmNarrativeRecap ?? '' : ''}',
      date: session.date,
      linkedSession: session,
    );
  }

  factory StoryTimelineItem.fromEvent(
    CampaignEvent event, {
    required Session? linkedSession,
  }) {
    final sessionTitle = linkedSession?.title ?? '';

    return StoryTimelineItem(
      id: 'event:${event.id}',
      campaignId: event.campaignId,
      kind: 'event',
      title: event.title.trim().isEmpty ? 'Untitled event' : event.title,
      body: event.description,
      linkText: '${event.title}\n${event.description}',
      searchText:
          '${event.title} ${event.description} ${event.type} $sessionTitle',
      date: event.date,
      type: event.type,
      linkedSession: linkedSession,
    );
  }

  factory StoryTimelineItem.fromJournalEntry(
    JournalEntry entry, {
    required Session? linkedSession,
  }) {
    final author = (entry.authorCharacterName ?? entry.authorName).trim();
    final safeAuthor = author.isEmpty ? 'Unknown voice' : author;
    final isPrivate = entry.sessionId == null || entry.sessionId!.isEmpty;
    final sessionTitle = linkedSession?.title ?? '';

    return StoryTimelineItem(
      id: 'note:${entry.id}',
      campaignId: entry.campaignId,
      kind: 'note',
      title: '$safeAuthor adds a perspective',
      body: entry.content,
      linkText: entry.content,
      searchText:
          '$safeAuthor ${entry.authorName} ${entry.authorCharacterName ?? ''} ${entry.content} $sessionTitle',
      date: entry.createdAt,
      author: safeAuthor,
      isPrivate: isPrivate,
      linkedSession: linkedSession,
    );
  }
}

class StoryTimelineStats {
  final int sessionCount;
  final int eventCount;
  final int noteCount;
  final int voiceCount;
  final int linkedMentionCount;

  const StoryTimelineStats({
    required this.sessionCount,
    required this.eventCount,
    required this.noteCount,
    required this.voiceCount,
    required this.linkedMentionCount,
  });
}
