import 'package:flutter/material.dart';

import '../models/compendium_entry.dart';
import '../models/session.dart';
import '../models/story_timeline_item.dart';
import '../utils/compendium_linking.dart';
import '../widgets/compendium_mention_chips.dart';
import '../widgets/linked_compendium_text.dart';
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
      appBar: StitchAppBar(
        title: Text(_formatDate(date)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            campaignName,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'What happened this day',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.timeline_outlined, size: 16),
                label: Text(
                  '${sortedItems.length} beat${sortedItems.length == 1 ? '' : 's'}',
                ),
              ),
              if (involvedVoices.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.groups_outlined, size: 16),
                  label: Text(
                    '${involvedVoices.length} voice${involvedVoices.length == 1 ? '' : 's'}',
                  ),
                ),
              if (linkedEntries.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.link, size: 16),
                  label: Text(
                    '${linkedEntries.length} link${linkedEntries.length == 1 ? '' : 's'}',
                  ),
                ),
            ],
          ),
          if (involvedVoices.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Involved voices',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: involvedVoices
                  .map(
                    (voice) => Chip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(voice),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (linkedEntries.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Linked compendium',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            CompendiumMentionChips(
              text: combinedText,
              campaignId: sortedItems.first.campaignId,
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'Timeline',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...sortedItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StoryDayBeatCard(
                item: item,
                onOpenSession: (session) => _openSession(context, session),
              ),
            ),
          ),
        ],
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _StoryDayBeatCard extends StatelessWidget {
  final StoryTimelineItem item;
  final ValueChanged<Session> onOpenSession;

  const _StoryDayBeatCard({
    required this.item,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(_iconForItem(item)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(_kindLabel(item)),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(_formatTime(item.date)),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (item.author != null)
                            Chip(
                              label: Text(item.author!),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.body.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              LinkedCompendiumText(
                text: item.body,
                campaignId: item.campaignId,
              ),
            ],
            if (item.linkedSession != null) ...[
              const SizedBox(height: 12),
              ActionChip(
                avatar: const Icon(Icons.menu_book_outlined, size: 16),
                label: Text(
                  item.linkedSession!.title.isEmpty
                      ? 'Open session'
                      : item.linkedSession!.title,
                ),
                onPressed: () => onOpenSession(item.linkedSession!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForItem(StoryTimelineItem item) {
    if (item.kind == 'note') return Icons.edit_note;
    if (item.kind == 'session') return Icons.auto_stories_outlined;

    switch (item.type) {
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

  String _kindLabel(StoryTimelineItem item) {
    if (item.kind == 'note') return item.isPrivate ? 'Private note' : 'Note';
    if (item.kind == 'event') return item.type ?? 'Event';
    return 'Session';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
