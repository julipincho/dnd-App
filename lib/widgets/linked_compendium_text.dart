import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/compendium_entry.dart';
import '../providers/compendium_provider.dart';
import '../screens/compendium_entry_detail_screen.dart';

class LinkedCompendiumText extends StatefulWidget {
  final String text;
  final String campaignId;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const LinkedCompendiumText({
    super.key,
    required this.text,
    required this.campaignId,
    this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow,
  });

  @override
  State<LinkedCompendiumText> createState() => _LinkedCompendiumTextState();
}

class _LinkedCompendiumTextState extends State<LinkedCompendiumText> {
  final Map<String, TapGestureRecognizer> _recognizersByEntryId = {};

  @override
  void dispose() {
    for (final recognizer in _recognizersByEntryId.values) {
      recognizer.dispose();
    }
    _recognizersByEntryId.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compendiumEntries = context
        .watch<CompendiumProvider>()
        .getEntriesByCampaign(widget.campaignId);

    if (compendiumEntries.isEmpty || widget.text.trim().isEmpty) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    final spans = _buildSpans(
      context: context,
      text: widget.text,
      entries: compendiumEntries,
      defaultStyle: widget.style ?? DefaultTextStyle.of(context).style,
      linkStyle: widget.linkStyle ??
          (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
    );

    return RichText(
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
      text: TextSpan(
        style: widget.style ?? DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }

  List<InlineSpan> _buildSpans({
    required BuildContext context,
    required String text,
    required List<CompendiumEntry> entries,
    required TextStyle defaultStyle,
    required TextStyle linkStyle,
  }) {
    final sortedEntries = [...entries]
      ..sort((a, b) => b.title.length.compareTo(a.title.length));

    final matches = <_TextMatch>[];

    for (final entry in sortedEntries) {
      final rawTitle = entry.title.trim();
      if (rawTitle.isEmpty) continue;

      final escapedTitle = RegExp.escape(rawTitle);

      final regex = RegExp(
        '(?<!\\w)$escapedTitle(?!\\w)',
        caseSensitive: false,
      );

      for (final match in regex.allMatches(text)) {
        final overlaps = matches.any(
          (existing) =>
              match.start < existing.end && match.end > existing.start,
        );

        if (!overlaps) {
          matches.add(
            _TextMatch(
              start: match.start,
              end: match.end,
              entry: entry,
            ),
          );
        }
      }
    }

    if (matches.isEmpty) {
      _cleanupUnusedRecognizers(const {});
      return [TextSpan(text: text, style: defaultStyle)];
    }

    matches.sort((a, b) => a.start.compareTo(b.start));

    final usedEntryIds = <String>{};
    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: defaultStyle,
          ),
        );
      }

      usedEntryIds.add(match.entry.id);

      final recognizer = _recognizersByEntryId.putIfAbsent(
        match.entry.id,
        () => TapGestureRecognizer(),
      );

      recognizer.onTap = () {
        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CompendiumEntryDetailScreen(entry: match.entry),
          ),
        );
      };

      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: linkStyle,
          recognizer: recognizer,
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: defaultStyle,
        ),
      );
    }

    _cleanupUnusedRecognizers(usedEntryIds);

    return spans;
  }

  void _cleanupUnusedRecognizers(Set<String> usedEntryIds) {
    final unusedKeys = _recognizersByEntryId.keys
        .where((key) => !usedEntryIds.contains(key))
        .toList();

    for (final key in unusedKeys) {
      _recognizersByEntryId[key]?.dispose();
      _recognizersByEntryId.remove(key);
    }
  }
}

class _TextMatch {
  final int start;
  final int end;
  final CompendiumEntry entry;

  _TextMatch({
    required this.start,
    required this.end,
    required this.entry,
  });
}
