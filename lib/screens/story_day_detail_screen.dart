import 'package:flutter/material.dart';

import '../models/compendium_entry.dart';
import '../models/session.dart';
import '../models/story_timeline_item.dart';
import '../theme.dart';
import '../utils/compendium_linking.dart';
import '../widgets/compendium_mention_chips.dart';
import '../widgets/linked_compendium_text.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';
import 'session_detail_screen.dart';

class StoryDayDetailScreen extends StatelessWidget {
  final String campaignName;
  final DateTime date;
  final List<StoryTimelineItem> items;
  final List<CompendiumEntry> compendiumEntries;

  const StoryDayDetailScreen({
    super.key,
    required this.campaignName,
    required this.date,
    required this.items,
    required this.compendiumEntries,
  });

  @override
  Widget build(BuildContext context) {
    final sortedItems = [...items]..sort((a, b) => a.date.compareTo(b.date));
    final involvedVoices = sortedItems
        .map((item) => item.author)
        .whereType<String>()
        .where((author) => author.trim().isNotEmpty)
        .toSet()
        .toList();
    final combinedText = sortedItems.map((item) => item.linkText).join('\n');
    final linkedEntries = CompendiumLinking.mentionedEntries(
      text: combinedText,
      entries: compendiumEntries,
    );

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: Text(
          _formatDate(date),
          style: const TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.data,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: SingleChildScrollView(
          child: StitchCodexContentWidth(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StoryDayHero(
                  campaignName: campaignName,
                  date: date,
                  beatCount: sortedItems.length,
                  voiceCount: involvedVoices.length,
                  linkCount: linkedEntries.length,
                ),
                if (involvedVoices.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _MetadataSection(
                    icon: Icons.groups_outlined,
                    title: 'Involved Voices',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final voice in involvedVoices)
                          StitchCodexTag(
                            label: voice.toUpperCase(),
                            color: StitchCodexPalette.crimsonBright,
                          ),
                      ],
                    ),
                  ),
                ],
                if (linkedEntries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _MetadataSection(
                    icon: Icons.link_rounded,
                    title: 'Linked Compendium',
                    child: CompendiumMentionChips(
                      text: combinedText,
                      campaignId: sortedItems.first.campaignId,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const StitchCodexPageHeader(
                  eyebrow: 'DAILY CHRONICLE',
                  title: 'The sequence of events',
                  subtitle:
                      'Sessions, discoveries and notes recorded across this day.',
                ),
                const SizedBox(height: 18),
                if (sortedItems.isEmpty)
                  const StitchCodexEmptyState(
                    icon: Icons.history_toggle_off_outlined,
                    title: 'No events recorded',
                    message: 'This day does not contain any story beats yet.',
                  )
                else
                  for (var index = 0;
                      index < sortedItems.length;
                      index++)
                    _StoryDayBeatCard(
                      index: index + 1,
                      item: sortedItems[index],
                      onOpenSession: (session) =>
                          _openSession(context, session),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSession(BuildContext context, Session session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(session: session),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _StoryDayHero extends StatelessWidget {
  final String campaignName;
  final DateTime date;
  final int beatCount;
  final int voiceCount;
  final int linkCount;

  const _StoryDayHero({
    required this.campaignName,
    required this.date,
    required this.beatCount,
    required this.voiceCount,
    required this.linkCount,
  });

  @override
  Widget build(BuildContext context) {
    return StitchCodexPanel(
      emphasized: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campaignName.toUpperCase(),
            style: const TextStyle(
              color: StitchCodexPalette.bronze,
              fontFamily: StitchTypography.data,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'What happened this day',
            style: TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: 27,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _longDate(date),
            style: const TextStyle(
              color: StitchCodexPalette.textSecondary,
              fontFamily: StitchTypography.body,
              fontSize: 17,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StitchCodexTag(
                label: '$beatCount ${beatCount == 1 ? 'BEAT' : 'BEATS'}',
              ),
              if (voiceCount > 0)
                StitchCodexTag(
                  label:
                      '$voiceCount ${voiceCount == 1 ? 'VOICE' : 'VOICES'}',
                  color: StitchCodexPalette.crimsonBright,
                ),
              if (linkCount > 0)
                StitchCodexTag(
                  label: '$linkCount ${linkCount == 1 ? 'LINK' : 'LINKS'}',
                  color: StitchCodexPalette.success,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _longDate(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _MetadataSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _MetadataSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StitchCodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: StitchCodexPalette.bronze, size: 19),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: StitchCodexPalette.textPrimary,
                  fontFamily: StitchTypography.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _StoryDayBeatCard extends StatelessWidget {
  final int index;
  final StoryTimelineItem item;
  final ValueChanged<Session> onOpenSession;

  const _StoryDayBeatCard({
    required this.index,
    required this.item,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.kind == 'note'
        ? StitchCodexPalette.crimsonBright
        : StitchCodexPalette.bronze;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StitchCodexPanel(
        accent: accent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    border: Border.all(color: accent.withValues(alpha: 0.34)),
                  ),
                  child: Icon(_iconForItem(item), color: accent, size: 21),
                ),
                const SizedBox(height: 7),
                Text(
                  index.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: StitchCodexPalette.textFaint,
                    fontFamily: StitchTypography.data,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.display,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      StitchCodexTag(
                        label: _kindLabel(item).toUpperCase(),
                        color: accent,
                      ),
                      StitchCodexTag(label: _formatTime(item.date)),
                      if (item.author != null)
                        StitchCodexTag(
                          label: item.author!.toUpperCase(),
                          color: StitchCodexPalette.success,
                        ),
                    ],
                  ),
                  if (item.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    LinkedCompendiumText(
                      text: item.body,
                      campaignId: item.campaignId,
                    ),
                  ],
                  if (item.linkedSession != null) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => onOpenSession(item.linkedSession!),
                      style: stitchCodexOutlineButtonStyle(),
                      icon: const Icon(Icons.menu_book_outlined, size: 17),
                      label: Text(
                        item.linkedSession!.title.isEmpty
                            ? 'Open Session'
                            : item.linkedSession!.title,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForItem(StoryTimelineItem value) {
    if (value.kind == 'note') return Icons.edit_note;
    if (value.kind == 'session') return Icons.auto_stories_outlined;

    switch (value.type) {
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

  String _kindLabel(StoryTimelineItem value) {
    if (value.kind == 'note') {
      return value.isPrivate ? 'Private note' : 'Note';
    }
    if (value.kind == 'event') return value.type ?? 'Event';
    return 'Session';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
