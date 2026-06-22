import 'package:flutter/material.dart';

import '../../../domain/models/combat_feedback.dart';
import '../../../../../theme.dart';
import '../shared/combat_small_window.dart';

class CombatFeedWindow extends StatelessWidget {
  final List<CombatLogEntry> entries;
  final int maxEntries;

  const CombatFeedWindow({
    super.key,
    required this.entries,
    this.maxEntries = 3,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final visible = entries.take(maxEntries).toList();

    return CombatSmallWindow(
      title: 'Log',
      icon: Icons.receipt_long_outlined,
      accentKind: CombatAccentKind.info,
      child: Column(
        children: [
          for (final entry in visible) ...[
            _MiniFeedEntry(entry: entry),
            if (entry != visible.last) const SizedBox(height: 6),
          ],
          if (visible.isEmpty)
            Text(
              'No activity yet.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniFeedEntry extends StatelessWidget {
  final CombatLogEntry entry;

  const _MiniFeedEntry({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = switch (entry.type) {
      CombatLogEntryType.roll => tokens.accentMagic,
      CombatLogEntryType.turn => tokens.accentAction,
      CombatLogEntryType.system => tokens.accentRead,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(entry.icon, color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
        ),
      ],
    );
  }
}
