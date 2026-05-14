import 'package:flutter/material.dart';

import '../models/compendium_entry.dart';
import '../models/session.dart';
import '../models/story_timeline_item.dart';
import '../utils/compendium_linking.dart';
import 'compendium_mention_chips.dart';
import 'linked_compendium_text.dart';

class CampaignStoryOverviewCard extends StatelessWidget {
  final StoryTimelineStats stats;

  const CampaignStoryOverviewCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.route_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Shared chronicle',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StoryStatChip(
                icon: Icons.auto_stories_outlined,
                label:
                    '${stats.sessionCount} session${stats.sessionCount == 1 ? '' : 's'}',
              ),
              _StoryStatChip(
                icon: Icons.bolt_outlined,
                label:
                    '${stats.eventCount} event${stats.eventCount == 1 ? '' : 's'}',
              ),
              _StoryStatChip(
                icon: Icons.edit_note,
                label:
                    '${stats.noteCount} note${stats.noteCount == 1 ? '' : 's'}',
              ),
              _StoryStatChip(
                icon: Icons.groups_outlined,
                label:
                    '${stats.voiceCount} voice${stats.voiceCount == 1 ? '' : 's'}',
              ),
              _StoryStatChip(
                icon: Icons.link,
                label:
                    '${stats.linkedMentionCount} compendium link${stats.linkedMentionCount == 1 ? '' : 's'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CampaignStoryTimelineTile extends StatelessWidget {
  final StoryTimelineItem item;
  final List<CompendiumEntry> compendiumEntries;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Session> onOpenSession;

  const CampaignStoryTimelineTile({
    super.key,
    required this.item,
    required this.compendiumEntries,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    final mentionedEntries = CompendiumLinking.mentionedEntries(
      text: item.linkText,
      entries: compendiumEntries,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_storyIcon(item), size: 20),
              ),
              const SizedBox(height: 8),
              Container(
                width: 2,
                height: isExpanded ? 190 : 118,
                color: Theme.of(context).dividerColor,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onToggleExpanded,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                    label: Text(_storyKindLabel(item)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    label: Text(_formatDateTime(item.date)),
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
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                        ),
                      ],
                    ),
                    if (item.body.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      LinkedCompendiumText(
                        text: item.body,
                        campaignId: item.campaignId,
                        maxLines: isExpanded ? null : 4,
                        overflow: isExpanded
                            ? TextOverflow.clip
                            : TextOverflow.ellipsis,
                      ),
                    ],
                    if (mentionedEntries.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      CompendiumMentionChips(
                        text: item.linkText,
                        campaignId: item.campaignId,
                        maxItems: isExpanded ? null : 4,
                      ),
                    ],
                    if (item.linkedSession != null ||
                        item.kind == 'session') ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (item.linkedSession != null &&
                              item.kind != 'session')
                            ActionChip(
                              avatar: const Icon(
                                Icons.menu_book_outlined,
                                size: 16,
                              ),
                              label: Text(
                                item.linkedSession!.title.isEmpty
                                    ? 'Open session'
                                    : item.linkedSession!.title,
                              ),
                              onPressed: () {
                                onOpenSession(item.linkedSession!);
                              },
                            ),
                          if (item.kind == 'session' &&
                              item.linkedSession != null)
                            ActionChip(
                              avatar: const Icon(
                                Icons.open_in_new,
                                size: 16,
                              ),
                              label: const Text('Open session'),
                              onPressed: () {
                                onOpenSession(item.linkedSession!);
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _storyIcon(StoryTimelineItem item) {
    switch (item.kind) {
      case 'event':
        return _iconForType(item.type ?? 'discovery');
      case 'note':
        return Icons.edit_note;
      case 'session':
      default:
        return Icons.auto_stories_outlined;
    }
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

  String _storyKindLabel(StoryTimelineItem item) {
    if (item.kind == 'note') {
      return item.isPrivate ? 'Private note' : 'Player note';
    }
    if (item.kind == 'event') return item.type ?? 'Event';
    return 'Session';
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class _StoryStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StoryStatChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
