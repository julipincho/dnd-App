import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:provider/provider.dart';

import '../models/campaign_event.dart';
import '../models/compendium_entry.dart';
import '../models/journal_entry.dart';
import '../models/session.dart';
import '../providers/app_role_provider.dart';
import '../providers/campaign_event_provider.dart';
import '../providers/journal_entry_provider.dart';
import '../providers/session_provider.dart';
import 'session_detail_screen.dart';

class CompendiumEntryDetailScreen extends StatelessWidget {
  final CompendiumEntry entry;

  const CompendiumEntryDetailScreen({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final eventProvider = context.watch<CampaignEventProvider>();
    final journalProvider = context.watch<JournalEntryProvider>();
    final roleProvider = context.watch<AppRoleProvider>();
    final isDm = roleProvider.isDm;

    final campaignSessions = sessionProvider
        .getSessionsByCampaign(entry.campaignId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final campaignEvents = eventProvider
        .getEventsByCampaign(entry.campaignId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final campaignJournalEntries = journalProvider.entries
        .where((e) => e.campaignId == entry.campaignId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final sessionMentions = campaignSessions
        .map((session) => _buildSessionMention(session, entry.title, isDm))
        .whereType<_SessionMention>()
        .toList();

    final eventMentions = campaignEvents.where((event) {
      final matches = _containsReference(event.title, entry.title) ||
          _containsReference(event.description, entry.title);

      return matches;
    }).toList();

    final journalMentions = campaignJournalEntries.where((journalEntry) {
      final matches = _containsReference(journalEntry.content, entry.title);

      if (!matches) return false;

      final isPrivate =
          journalEntry.sessionId == null || journalEntry.sessionId!.isEmpty;

      if (!isDm && isPrivate) return false;

      return true;
    }).toList();

    final hasImage = entry.imagePath != null &&
        entry.imagePath!.isNotEmpty &&
        File(entry.imagePath!).existsSync();

    return Scaffold(
      appBar: StitchAppBar(
        title: Text(entry.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(entry.imagePath!),
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          child: Icon(_iconForType(entry.type)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(entry.type.toUpperCase()),
                        ),
                        Chip(
                          label: Text(
                            'Created ${_formatDate(entry.createdAt)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildBacklinkSection(
              context,
              title: 'Appears in sessions',
              count: sessionMentions.length,
              emptyText: 'No session mentions found yet',
              children: sessionMentions.map((mention) {
                return _buildSessionMentionCard(context, mention);
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildBacklinkSection(
              context,
              title: 'Appears in events',
              count: eventMentions.length,
              emptyText: 'No event mentions found yet',
              children: eventMentions.map((event) {
                final linkedSession = event.sessionId == null
                    ? null
                    : campaignSessions.cast<Session?>().firstWhere(
                          (session) => session?.id == event.sessionId,
                          orElse: () => null,
                        );

                return _buildEventMentionCard(
                  context,
                  event,
                  linkedSession,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildBacklinkSection(
              context,
              title: 'Appears in journal',
              count: journalMentions.length,
              emptyText: 'No journal mentions found yet',
              children: journalMentions.map((journalEntry) {
                final linkedSession = journalEntry.sessionId == null
                    ? null
                    : campaignSessions.cast<Session?>().firstWhere(
                          (session) => session?.id == journalEntry.sessionId,
                          orElse: () => null,
                        );

                return _buildJournalMentionCard(
                  context,
                  journalEntry,
                  linkedSession,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBacklinkSection(
    BuildContext context, {
    required String title,
    required int count,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title ($count)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (children.isEmpty)
              Text(
                emptyText,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...children
                  .expand((child) => [
                        child,
                        const SizedBox(height: 10),
                      ])
                  .toList()
                ..removeLast(),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionMentionCard(
    BuildContext context,
    _SessionMention mention,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(
          child: Icon(Icons.auto_stories_outlined),
        ),
        title: Text(
          mention.session.title.isEmpty
              ? 'Untitled session'
              : mention.session.title,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(_formatDate(mention.session.date)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: mention.sources
                  .map(
                    (source) => Chip(
                      label: Text(source),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            if (mention.preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                mention.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionDetailScreen(session: mention.session),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventMentionCard(
    BuildContext context,
    CampaignEvent event,
    Session? linkedSession,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(event.date),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              event.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
                  ActionChip(
                    label: Text(
                      linkedSession.title.isEmpty
                          ? 'Open session'
                          : linkedSession.title,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SessionDetailScreen(session: linkedSession),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalMentionCard(
    BuildContext context,
    JournalEntry journalEntry,
    Session? linkedSession,
  ) {
    final author = journalEntry.authorCharacterName ?? journalEntry.authorName;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              author,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(journalEntry.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              journalEntry.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    (journalEntry.sessionId == null ||
                            journalEntry.sessionId!.isEmpty)
                        ? 'Private note'
                        : 'Session note',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                if (linkedSession != null)
                  ActionChip(
                    label: Text(
                      linkedSession.title.isEmpty
                          ? 'Open session'
                          : linkedSession.title,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SessionDetailScreen(session: linkedSession),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _SessionMention? _buildSessionMention(
    Session session,
    String title,
    bool isDm,
  ) {
    final sources = <String>[];
    String preview = '';

    if (_containsReference(session.summary ?? '', title)) {
      sources.add('summary');
      preview = preview.isEmpty ? session.summary ?? '' : preview;
    }

    if (isDm && _containsReference(session.rawNotes, title)) {
      sources.add('notes');
      preview = preview.isEmpty ? session.rawNotes : preview;
    }

    if (_containsReference(session.playerNarrativeRecap ?? '', title)) {
      sources.add('player recap');
      preview = preview.isEmpty ? session.playerNarrativeRecap ?? '' : preview;
    }

    if (isDm && _containsReference(session.dmNarrativeRecap ?? '', title)) {
      sources.add('dm recap');
      preview = preview.isEmpty ? session.dmNarrativeRecap ?? '' : preview;
    }

    if (sources.isEmpty) return null;

    return _SessionMention(
      session: session,
      sources: sources,
      preview: _clip(preview),
    );
  }

  bool _containsReference(String text, String title) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || text.trim().isEmpty) return false;

    final regex = RegExp(
      '(?<!\\w)${RegExp.escape(cleanTitle)}(?!\\w)',
      caseSensitive: false,
    );

    return regex.hasMatch(text);
  }

  String _clip(String text, {int max = 140}) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max).trim()}...';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'location':
        return Icons.place_outlined;
      case 'item':
        return Icons.inventory_2_outlined;
      case 'faction':
        return Icons.shield_outlined;
      case 'lore':
        return Icons.auto_stories_outlined;
      case 'npc':
      default:
        return Icons.person_outline;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _SessionMention {
  final Session session;
  final List<String> sources;
  final String preview;

  _SessionMention({
    required this.session,
    required this.sources,
    required this.preview,
  });
}
