import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/compendium_entry.dart';
import '../providers/compendium_provider.dart';
import '../screens/compendium_entry_detail_screen.dart';
import '../utils/compendium_linking.dart';

class CompendiumMentionChips extends StatelessWidget {
  final String text;
  final String campaignId;
  final int? maxItems;
  final TextStyle? labelStyle;
  final bool showUnresolved;
  final ValueChanged<CompendiumEntry>? onEntryPressed;

  const CompendiumMentionChips({
    super.key,
    required this.text,
    required this.campaignId,
    this.maxItems,
    this.labelStyle,
    this.showUnresolved = false,
    this.onEntryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final entries =
        context.watch<CompendiumProvider>().getEntriesByCampaign(campaignId);

    final mentionedEntries = CompendiumLinking.mentionedEntries(
      text: text,
      entries: entries,
    );

    final unresolvedMentions = showUnresolved
        ? CompendiumLinking.findUnresolvedWikiLinks(
            text: text,
            entries: entries,
          )
        : const <UnresolvedCompendiumTextMatch>[];

    if (mentionedEntries.isEmpty && unresolvedMentions.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleEntries = maxItems == null
        ? mentionedEntries
        : mentionedEntries.take(maxItems!).toList();
    final hiddenCount = mentionedEntries.length - visibleEntries.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...visibleEntries.map(
          (entry) => ActionChip(
            avatar: Icon(_iconForType(entry.type), size: 16),
            label: Text(entry.title, style: labelStyle),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              if (onEntryPressed != null) {
                onEntryPressed!(entry);
                return;
              }

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CompendiumEntryDetailScreen(entry: entry),
                ),
              );
            },
          ),
        ),
        if (hiddenCount > 0)
          Chip(
            label: Text('+$hiddenCount more'),
            visualDensity: VisualDensity.compact,
          ),
        ...unresolvedMentions.map(
          (mention) => Chip(
            avatar: const Icon(Icons.link_off_outlined, size: 16),
            label: Text('Unlinked: ${mention.displayText}'),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
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
}
