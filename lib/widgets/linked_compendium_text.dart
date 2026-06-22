import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/compendium_provider.dart';
import '../screens/compendium_entry_detail_screen.dart';
import '../utils/compendium_linking.dart';

class LinkedCompendiumText extends StatefulWidget {
  final String text;
  final String campaignId;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextStyle? unresolvedStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const LinkedCompendiumText({
    super.key,
    required this.text,
    required this.campaignId,
    this.style,
    this.linkStyle,
    this.unresolvedStyle,
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

    if (widget.text.trim().isEmpty) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    final defaultStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final segments = CompendiumLinking.buildTextSegments(
      text: widget.text,
      entries: compendiumEntries,
    );

    if (segments.isEmpty) {
      _cleanupUnusedRecognizers(const {});
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
      segments: segments,
      defaultStyle: defaultStyle,
      linkStyle: widget.linkStyle ??
          defaultStyle.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
      unresolvedStyle: widget.unresolvedStyle ??
          defaultStyle.copyWith(
            color: Theme.of(context).colorScheme.tertiary,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
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
    required List<CompendiumTextSegment> segments,
    required TextStyle defaultStyle,
    required TextStyle linkStyle,
    required TextStyle unresolvedStyle,
  }) {
    final usedEntryIds = <String>{};
    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final segment in segments) {
      if (segment.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, segment.start),
            style: defaultStyle,
          ),
        );
      }

      final entry = segment.entry;
      if (entry == null) {
        spans.add(
          TextSpan(
            text: segment.displayText,
            style: unresolvedStyle,
          ),
        );
        currentIndex = segment.end;
        continue;
      }

      usedEntryIds.add(entry.id);

      final recognizer = _recognizersByEntryId.putIfAbsent(
        entry.id,
        () => TapGestureRecognizer(),
      );

      recognizer.onTap = () {
        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CompendiumEntryDetailScreen(entry: entry),
          ),
        );
      };

      spans.add(
        TextSpan(
          text: segment.displayText,
          style: linkStyle,
          recognizer: recognizer,
        ),
      );

      currentIndex = segment.end;
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
