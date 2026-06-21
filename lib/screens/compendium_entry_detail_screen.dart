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
import '../theme.dart';
import '../utils/compendium_linking.dart';
import '../utils/image_path_utils.dart';
import '../widgets/stitch_codex_ui.dart';
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

    final hasImage = hasDisplayableImagePath(entry.imagePath);

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: Text(
          entry.title.toUpperCase(),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: SingleChildScrollView(
          child: StitchCodexContentWidth(
            maxWidth: 920,
            child: Column(
              children: [
                StitchCodexPanel(
                  emphasized: true,
                  padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: buildImageFromPath(
                          entry.imagePath!,
                          width: double.infinity,
                          height: 280,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 58,
                          decoration: BoxDecoration(
                            color: StitchCodexPalette.bronze
                                .withValues(alpha: 0.09),
                            border: Border.all(
                              color: StitchCodexPalette.bronze
                                  .withValues(alpha: 0.34),
                            ),
                          ),
                          child: Icon(
                            _iconForType(entry.type),
                            color: StitchCodexPalette.bronze,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COMPENDIUM RECORD',
                                style: TextStyle(
                                  color: StitchCodexPalette.bronze,
                                  fontFamily: StitchTypography.data,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.7,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.title,
                                style: const TextStyle(
                                  color: StitchCodexPalette.textPrimary,
                                  fontFamily: StitchTypography.display,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StitchCodexTag(
                          label: entry.type.toUpperCase(),
                        ),
                        StitchCodexTag(
                          label: 'CREATED ${_formatDate(entry.createdAt)}',
                          color: StitchCodexPalette.crimsonBright,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: StitchCodexPalette.textPrimary,
                        fontFamily: StitchTypography.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.description,
                      style: const TextStyle(
                        color: StitchCodexPalette.textSecondary,
                        fontFamily: StitchTypography.body,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                ),
                const SizedBox(height: 24),
                const StitchCodexPageHeader(
                  eyebrow: 'BACKLINKS',
                  title: 'Where this record appears',
                  subtitle:
                      'Every session, event and journal note connected to this piece of lore.',
                ),
                const SizedBox(height: 16),
                _buildBacklinkSection(
                  context,
                  title: 'Appears in sessions',
                  icon: Icons.auto_stories_outlined,
                  count: sessionMentions.length,
                  emptyText: 'No session mentions found yet',
                  children: sessionMentions.map((mention) {
                    return _buildSessionMentionCard(context, mention);
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _buildBacklinkSection(
                  context,
                  title: 'Appears in events',
                  icon: Icons.timeline_outlined,
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
                const SizedBox(height: 12),
                _buildBacklinkSection(
                  context,
                  title: 'Appears in journal',
                  icon: Icons.edit_note_outlined,
                  count: journalMentions.length,
                  emptyText: 'No journal mentions found yet',
                  children: journalMentions.map((journalEntry) {
                    final linkedSession = journalEntry.sessionId == null
                        ? null
                        : campaignSessions.cast<Session?>().firstWhere(
                              (session) =>
                                  session?.id == journalEntry.sessionId,
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
        ),
      ),
    );
  }

  Widget _buildBacklinkSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int count,
    required String emptyText,
    required List<Widget> children,
  }) {
    return StitchCodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: StitchCodexPalette.bronze, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: StitchCodexPalette.textPrimary,
                    fontFamily: StitchTypography.display,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StitchCodexTag(label: '$count'),
            ],
          ),
          const SizedBox(height: 14),
          if (children.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
                fontSize: 14,
              ),
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
    );
  }

  Widget _buildSessionMentionCard(
    BuildContext context,
    _SessionMention mention,
  ) {
    return StitchCodexPanel(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 42,
          height: 46,
          decoration: BoxDecoration(
            color: StitchCodexPalette.bronze.withValues(alpha: 0.08),
            border: Border.all(
              color: StitchCodexPalette.bronze.withValues(alpha: 0.28),
            ),
          ),
          child: const Icon(
            Icons.auto_stories_outlined,
            color: StitchCodexPalette.bronze,
            size: 20,
          ),
        ),
        title: Text(
          mention.session.title.isEmpty
              ? 'Untitled session'
              : mention.session.title,
          style: const TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              _formatDate(mention.session.date),
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.data,
                fontSize: 8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: mention.sources
                  .map(
                    (source) => StitchCodexTag(
                      label: source.toUpperCase(),
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
                style: const TextStyle(
                  color: StitchCodexPalette.textSecondary,
                  fontFamily: StitchTypography.body,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: StitchCodexPalette.textMuted,
        ),
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
    return StitchCodexPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(
                color: StitchCodexPalette.textPrimary,
                fontFamily: StitchTypography.display,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(event.date),
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.data,
                fontSize: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StitchCodexPalette.textSecondary,
                fontFamily: StitchTypography.body,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StitchCodexTag(
                  label: event.type.toUpperCase(),
                ),
                if (linkedSession != null)
                  OutlinedButton.icon(
                    style: stitchCodexOutlineButtonStyle(),
                    icon: const Icon(Icons.menu_book_outlined, size: 16),
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

    return StitchCodexPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              author,
              style: const TextStyle(
                color: StitchCodexPalette.textPrimary,
                fontFamily: StitchTypography.display,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(journalEntry.createdAt),
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.data,
                fontSize: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              journalEntry.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StitchCodexPalette.textSecondary,
                fontFamily: StitchTypography.body,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StitchCodexTag(
                  label: (journalEntry.sessionId == null ||
                          journalEntry.sessionId!.isEmpty)
                      ? 'PRIVATE NOTE'
                      : 'SESSION NOTE',
                  color: StitchCodexPalette.crimsonBright,
                ),
                if (linkedSession != null)
                  OutlinedButton.icon(
                    style: stitchCodexOutlineButtonStyle(),
                    icon: const Icon(Icons.menu_book_outlined, size: 16),
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

    return CompendiumLinking.containsTitle(text, cleanTitle);
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
