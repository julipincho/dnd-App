import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/campaign_event.dart';
import '../models/journal_entry.dart';
import '../models/session.dart';
import '../providers/app_role_provider.dart';
import '../providers/campaign_event_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/journal_entry_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/linked_compendium_text.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String _recapMode = 'player'; // 'player' | 'dm'
  bool _didLoad = false;
  String _searchQuery = '';
  bool _showPrivateNotes = true;
  final Set<String> _expandedRecaps = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didLoad) {
      _didLoad = true;
      context.read<CampaignEventProvider>().loadEvents();
      context.read<SessionProvider>().loadSessions();
      context.read<JournalEntryProvider>().loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignProvider = context.watch<CampaignProvider>();
    final eventProvider = context.watch<CampaignEventProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final journalProvider = context.watch<JournalEntryProvider>();
    final roleProvider = context.watch<AppRoleProvider>();

    final activeCampaign = campaignProvider.activeCampaign;
    final isDm = roleProvider.isDm;

    if (activeCampaign == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Timeline'),
        ),
        body: const Center(
          child: Text('No active campaign selected'),
        ),
      );
    }

    final sessions = sessionProvider
        .getSessionsByCampaign(activeCampaign.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final campaignEvents =
        eventProvider.getEventsByCampaign(activeCampaign.id).toList();

    final campaignJournalEntries = journalProvider.entries
        .where((e) => e.campaignId == activeCampaign.id)
        .toList();

    final query = _searchQuery.toLowerCase().trim();

    bool matchesSearch(String text) {
      if (query.isEmpty) return true;
      return text.toLowerCase().contains(query);
    }

    final filteredSessions = sessions.where((session) {
      final sessionEvents =
          campaignEvents.where((e) => e.sessionId == session.id).toList();

      final sessionEntries = campaignJournalEntries
          .where((e) => e.sessionId == session.id)
          .toList();

      final sessionMatches = matchesSearch(session.title) ||
          matchesSearch(session.summary ?? '') ||
          matchesSearch(session.playerNarrativeRecap ?? '') ||
          (isDm && matchesSearch(session.rawNotes)) ||
          (isDm && matchesSearch(session.dmNarrativeRecap ?? ''));

      final eventMatches = sessionEvents.any((event) =>
          matchesSearch(event.title) ||
          matchesSearch(event.description) ||
          matchesSearch(event.type));

      final entryMatches = sessionEntries.any((entry) =>
          matchesSearch(entry.content) ||
          matchesSearch(entry.authorName) ||
          matchesSearch(entry.authorCharacterName ?? ''));

      return sessionMatches || eventMatches || entryMatches;
    }).toList();

    final orphanEvents = campaignEvents
        .where((event) => event.sessionId == null)
        .where((event) =>
            matchesSearch(event.title) ||
            matchesSearch(event.description) ||
            matchesSearch(event.type))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final privateEntries = campaignJournalEntries
        .where((entry) => entry.sessionId == null || entry.sessionId!.isEmpty)
        .where((entry) =>
            matchesSearch(entry.content) ||
            matchesSearch(entry.authorName) ||
            matchesSearch(entry.authorCharacterName ?? ''))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final hasContent = filteredSessions.isNotEmpty ||
        orphanEvents.isNotEmpty ||
        (isDm && _showPrivateNotes && privateEntries.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text('${activeCampaign.name} Timeline'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search timeline',
                hintText: 'Search sessions, events or notes',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          if (isDm)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show private notes'),
                subtitle: const Text(
                  'Include notes that do not belong to a session',
                ),
                value: _showPrivateNotes,
                onChanged: (value) {
                  setState(() {
                    _showPrivateNotes = value;
                  });
                },
              ),
            ),
          if (isDm)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'player',
                    label: Text('Player view'),
                    icon: Icon(Icons.auto_stories_outlined),
                  ),
                  ButtonSegment(
                    value: 'dm',
                    label: Text('DM view'),
                    icon: Icon(Icons.psychology_outlined),
                  ),
                ],
                selected: {_recapMode},
                onSelectionChanged: (value) {
                  setState(() {
                    _recapMode = value.first;
                  });
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<AppRole>(
              segments: const [
                ButtonSegment<AppRole>(
                  value: AppRole.dm,
                  label: Text('DM'),
                  icon: Icon(Icons.shield_outlined),
                ),
                ButtonSegment<AppRole>(
                  value: AppRole.player,
                  label: Text('Player'),
                  icon: Icon(Icons.person_outline),
                ),
              ],
              selected: {roleProvider.role},
              onSelectionChanged: (value) {
                context.read<AppRoleProvider>().setRole(value.first);
              },
            ),
          ),
          Expanded(
            child: !hasContent
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'No timeline content yet'
                          : 'No matching timeline content found',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (isDm &&
                          _showPrivateNotes &&
                          privateEntries.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          'Private reflections',
                          subtitle:
                              '${privateEntries.length} private note${privateEntries.length == 1 ? '' : 's'}',
                        ),
                        const SizedBox(height: 8),
                        ...privateEntries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildJournalCard(context, entry),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (orphanEvents.isNotEmpty) ...[
                        _buildSectionHeader(
                          context,
                          'Campaign-wide events',
                          subtitle:
                              '${orphanEvents.length} event${orphanEvents.length == 1 ? '' : 's'} not linked to a session',
                        ),
                        const SizedBox(height: 8),
                        ...orphanEvents.map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildEventCard(context, event, null),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ...filteredSessions.map((session) {
                        final sessionEvents = campaignEvents
                            .where((e) => e.sessionId == session.id)
                            .toList()
                          ..sort((a, b) => b.date.compareTo(a.date));

                        final sessionEntries = campaignJournalEntries
                            .where((e) => e.sessionId == session.id)
                            .toList()
                          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                        final visibleEvents = sessionEvents.where((event) {
                          return query.isEmpty ||
                              matchesSearch(event.title) ||
                              matchesSearch(event.description) ||
                              matchesSearch(event.type);
                        }).toList();

                        final visibleEntries = sessionEntries.where((entry) {
                          return query.isEmpty ||
                              matchesSearch(entry.content) ||
                              matchesSearch(entry.authorName) ||
                              matchesSearch(entry.authorCharacterName ?? '');
                        }).toList();

                        final sessionTitleMatches = query.isEmpty ||
                            matchesSearch(session.title) ||
                            matchesSearch(session.summary ?? '') ||
                            matchesSearch(session.playerNarrativeRecap ?? '') ||
                            (isDm && matchesSearch(session.rawNotes)) ||
                            (isDm &&
                                matchesSearch(session.dmNarrativeRecap ?? ''));

                        if (!sessionTitleMatches &&
                            visibleEvents.isEmpty &&
                            visibleEntries.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildSessionBlock(
                            context,
                            session,
                            visibleEvents,
                            visibleEntries,
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: isDm
          ? FloatingActionButton(
              onPressed: () =>
                  _showCreateEventDialog(context, activeCampaign.id),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionBlock(
    BuildContext context,
    Session session,
    List<CampaignEvent> events,
    List<JournalEntry> entries,
  ) {
    final mainEvents = events;
    final characterEntries =
        entries.where((e) => e.authorCharacterId != null).toList();

    final hasContent = mainEvents.isNotEmpty || characterEntries.isNotEmpty;
    final isDm = context.watch<AppRoleProvider>().isDm;

    final effectiveRecapMode = isDm ? _recapMode : 'player';

    final recap = effectiveRecapMode == 'player'
        ? session.playerNarrativeRecap
        : session.dmNarrativeRecap;

    final hasRecap = (recap ?? '').trim().isNotEmpty;
    final isExpanded = _expandedRecaps.contains(session.id);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title.isEmpty ? 'Untitled session' : session.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(session.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if ((session.summary ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    session.summary!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        '${mainEvents.length} event${mainEvents.length == 1 ? '' : 's'}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(
                        '${characterEntries.length} perspective${characterEntries.length == 1 ? '' : 's'}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (isDm)
                      FilledButton.icon(
                        onPressed: () async {
                          final generated = effectiveRecapMode == 'player'
                              ? _generatePlayerRecap(
                                  session,
                                  mainEvents,
                                  characterEntries,
                                )
                              : _generateDMRecap(
                                  session,
                                  mainEvents,
                                  characterEntries,
                                );

                          final updatedSession = effectiveRecapMode == 'player'
                              ? session.copyWith(
                                  playerNarrativeRecap: generated,
                                )
                              : session.copyWith(
                                  dmNarrativeRecap: generated,
                                );

                          await context
                              .read<SessionProvider>()
                              .updateSession(updatedSession);

                          if (!mounted) return;

                          setState(() {
                            _expandedRecaps.add(session.id);
                          });
                        },
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(
                          (recap ?? '').trim().isEmpty
                              ? 'Generate recap'
                              : 'Regenerate recap',
                        ),
                      ),
                    if (hasRecap)
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedRecaps.remove(session.id);
                            } else {
                              _expandedRecaps.add(session.id);
                            }
                          });
                        },
                        icon: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                        ),
                        label: Text(isExpanded ? 'Hide recap' : 'Show recap'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (hasRecap && isExpanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        effectiveRecapMode == 'player'
                            ? 'Player recap'
                            : 'DM recap',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    recap!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          if (!hasContent)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No narrative content yet'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mainEvents.isNotEmpty) ...[
                    _buildSubsectionTitle(context, 'Main events'),
                    const SizedBox(height: 8),
                    ...mainEvents.map(
                      (event) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildEventCard(context, event, session),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (characterEntries.isNotEmpty) ...[
                    _buildSubsectionTitle(context, 'Character perspectives'),
                    const SizedBox(height: 8),
                    ...characterEntries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildJournalCard(context, entry),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubsectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    CampaignEvent event,
    Session? linkedSession,
  ) {
    final isDm = context.watch<AppRoleProvider>().isDm;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          child: Icon(_iconForType(event.type)),
        ),
        title: Text(event.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(event.date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              LinkedCompendiumText(
                text: event.description,
                campaignId: event.campaignId,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(event.type),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (linkedSession != null)
                    Chip(
                      label: Text(
                        'Session: ${linkedSession.title.isEmpty ? 'Untitled' : linkedSession.title}',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
        trailing: isDm
            ? PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showEditEventDialog(context, event);
                  } else if (value == 'delete') {
                    await _confirmDeleteEvent(context, event);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildJournalCard(BuildContext context, JournalEntry entry) {
    final isPrivate = entry.sessionId == null || entry.sessionId!.isEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(
          child: Icon(Icons.menu_book_outlined),
        ),
        title: Text(
          entry.authorCharacterName ?? entry.authorName,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(entry.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              LinkedCompendiumText(
                text: entry.content,
                campaignId: entry.campaignId,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(isPrivate ? 'Private note' : 'Session note'),
                    visualDensity: VisualDensity.compact,
                  ),
                  if ((entry.imagePath ?? '').isNotEmpty)
                    const Chip(
                      label: Text('Image attached'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateSessionRecap(
    Session session,
    List<CampaignEvent> events,
    List<JournalEntry> entries,
  ) {
    final summary = (session.summary ?? '').trim();

    final topEvents = events.take(2).toList();
    final topEntries = entries.take(2).toList();

    final buffer = StringBuffer();

    if (summary.isNotEmpty) {
      buffer.write(summary);
    } else if (events.isNotEmpty) {
      buffer.write(_buildEventsSentence(events));
    } else {
      buffer.write(
        '${session.title.isEmpty ? 'This session' : session.title} left a trace in the campaign, even if no formal summary was written.',
      );
    }

    if (topEvents.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(_buildHighlightSentence(topEvents));
    }

    if (topEntries.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(_buildPerspectiveSentence(topEntries));
    }

    if (events.isEmpty && entries.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(
        'What stands out most is how the characters processed the session from their own perspective.',
      );
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _generatePlayerRecap(
    Session session,
    List<CampaignEvent> events,
    List<JournalEntry> entries,
  ) {
    final base = _generateSessionRecap(session, events, entries);

    return '$base The story continues to unfold, leaving questions and consequences for the next session.';
  }

  String _generateDMRecap(
    Session session,
    List<CampaignEvent> events,
    List<JournalEntry> entries,
  ) {
    final buffer = StringBuffer();

    if (events.isNotEmpty) {
      buffer.write('Key events: ');
      buffer.write(events.map((e) => e.title).join(', '));
      buffer.write('. ');
    }

    if (entries.isNotEmpty) {
      buffer.write('Character insight present. ');
    }

    if ((session.summary ?? '').isNotEmpty) {
      buffer.write('Summary: ${session.summary}. ');
    }

    buffer.write(
      'Pending threads and consequences should be considered for next session.',
    );

    return buffer.toString().trim();
  }

  String _buildEventsSentence(List<CampaignEvent> events) {
    if (events.isEmpty) {
      return 'No major events were registered for this session.';
    }

    if (events.length == 1) {
      return 'The main development of the session was "${events.first.title}".';
    }

    final first = events[0].title;
    final second = events[1].title;
    return 'The session was shaped mainly by "$first" and "$second".';
  }

  String _buildHighlightSentence(List<CampaignEvent> events) {
    if (events.isEmpty) return '';

    if (events.length == 1) {
      return 'Its clearest turning point was ${_eventLead(events.first)}.';
    }

    final first = _eventLead(events[0]);
    final second = _eventLead(events[1]);
    return 'Its strongest beats were $first and $second.';
  }

  String _buildPerspectiveSentence(List<JournalEntry> entries) {
    if (entries.isEmpty) return '';

    if (entries.length == 1) {
      final author =
          entries.first.authorCharacterName ?? entries.first.authorName;
      return '$author framed the session as: "${_clip(entries.first.content)}".';
    }

    final firstAuthor = entries[0].authorCharacterName ?? entries[0].authorName;
    final secondAuthor =
        entries[1].authorCharacterName ?? entries[1].authorName;

    return '$firstAuthor and $secondAuthor added personal perspective, showing how the same events carried different emotional weight.';
  }

  String _eventLead(CampaignEvent event) {
    final type = event.type.toLowerCase();
    switch (type) {
      case 'combat':
        return 'a combat-focused moment around "${event.title}"';
      case 'dialogue':
        return 'a key dialogue moment in "${event.title}"';
      case 'discovery':
        return 'an important discovery in "${event.title}"';
      case 'travel':
        return 'a turning point during "${event.title}"';
      case 'quest':
        return 'a quest development in "${event.title}"';
      default:
        return '"${event.title}"';
    }
  }

  String _clip(String text, {int max = 90}) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max).trim()}...';
  }

  Future<void> _confirmDeleteEvent(
    BuildContext context,
    CampaignEvent event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete event'),
          content: Text(
            'Are you sure you want to delete "${event.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<CampaignEventProvider>().removeEvent(event.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event deleted')),
    );
  }

  void _showCreateEventDialog(BuildContext context, String campaignId) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'discovery';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event title',
                        hintText: 'Example: The gate was broken',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe what happened...',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Event type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'combat',
                          child: Text('Combat'),
                        ),
                        DropdownMenuItem(
                          value: 'dialogue',
                          child: Text('Dialogue'),
                        ),
                        DropdownMenuItem(
                          value: 'discovery',
                          child: Text('Discovery'),
                        ),
                        DropdownMenuItem(
                          value: 'travel',
                          child: Text('Travel'),
                        ),
                        DropdownMenuItem(
                          value: 'quest',
                          child: Text('Quest'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();

                    if (title.isEmpty || description.isEmpty) return;

                    final event = CampaignEvent(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      campaignId: campaignId,
                      sessionId: null,
                      title: title,
                      description: description,
                      date: DateTime.now(),
                      type: selectedType,
                    );

                    await dialogContext
                        .read<CampaignEventProvider>()
                        .addEvent(event);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditEventDialog(BuildContext context, CampaignEvent event) {
    final titleController = TextEditingController(text: event.title);
    final descriptionController =
        TextEditingController(text: event.description);
    String selectedType = event.type;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Event type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'combat',
                          child: Text('Combat'),
                        ),
                        DropdownMenuItem(
                          value: 'dialogue',
                          child: Text('Dialogue'),
                        ),
                        DropdownMenuItem(
                          value: 'discovery',
                          child: Text('Discovery'),
                        ),
                        DropdownMenuItem(
                          value: 'travel',
                          child: Text('Travel'),
                        ),
                        DropdownMenuItem(
                          value: 'quest',
                          child: Text('Quest'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();

                    if (title.isEmpty || description.isEmpty) return;

                    final updatedEvent = event.copyWith(
                      title: title,
                      description: description,
                      type: selectedType,
                    );

                    await dialogContext
                        .read<CampaignEventProvider>()
                        .updateEvent(updatedEvent);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'combat':
        return Icons.flash_on_outlined;
      case 'dialogue':
        return Icons.forum_outlined;
      case 'travel':
        return Icons.map_outlined;
      case 'quest':
        return Icons.assignment_outlined;
      case 'discovery':
      default:
        return Icons.visibility_outlined;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
