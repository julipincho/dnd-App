import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/compendium_entry.dart';
import '../providers/compendium_provider.dart';

class CompendiumAwareTextField extends StatefulWidget {
  final TextEditingController controller;
  final String campaignId;
  final InputDecoration? decoration;
  final int? maxLines;
  final int minQueryLength;

  const CompendiumAwareTextField({
    super.key,
    required this.controller,
    required this.campaignId,
    this.decoration,
    this.maxLines,
    this.minQueryLength = 2,
  });

  @override
  State<CompendiumAwareTextField> createState() =>
      _CompendiumAwareTextFieldState();
}

class _CompendiumAwareTextFieldState extends State<CompendiumAwareTextField> {
  List<CompendiumEntry> _suggestions = [];
  String _currentToken = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant CompendiumAwareTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
      _handleTextChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid) {
      _clearSuggestions();
      return;
    }

    final cursorIndex = selection.baseOffset;
    if (cursorIndex < 0 || cursorIndex > text.length) {
      _clearSuggestions();
      return;
    }

    final token = _extractCurrentToken(text, cursorIndex).trim();

    if (token.length < widget.minQueryLength) {
      _clearSuggestions();
      return;
    }

    final entries = context
        .read<CompendiumProvider>()
        .getEntriesByCampaign(widget.campaignId);

    final normalizedToken = token.toLowerCase();

    final matches = entries.where((entry) {
      final title = entry.title.trim().toLowerCase();
      return title.contains(normalizedToken);
    }).toList()
      ..sort((a, b) {
        final aStarts = a.title.toLowerCase().startsWith(normalizedToken);
        final bStarts = b.title.toLowerCase().startsWith(normalizedToken);

        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;

        return a.title.length.compareTo(b.title.length);
      });

    setState(() {
      _currentToken = token;
      _suggestions = matches.take(6).toList();
    });
  }

  void _clearSuggestions() {
    if (_suggestions.isEmpty && _currentToken.isEmpty) return;

    setState(() {
      _suggestions = [];
      _currentToken = '';
    });
  }

  String _extractCurrentToken(String text, int cursorIndex) {
    if (text.isEmpty) return '';

    int start = cursorIndex;
    while (start > 0) {
      final char = text[start - 1];
      final isBoundary = RegExp(r'[\s,.!?:;\(\)\[\]\{\}"“”]').hasMatch(char);
      if (isBoundary) break;
      start--;
    }

    int end = cursorIndex;
    while (end < text.length) {
      final char = text[end];
      final isBoundary = RegExp(r'[\s,.!?:;\(\)\[\]\{\}"“”]').hasMatch(char);
      if (isBoundary) break;
      end++;
    }

    return text.substring(start, end);
  }

  void _insertSuggestion(CompendiumEntry entry) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid) return;

    final cursorIndex = selection.baseOffset;
    int start = cursorIndex;
    while (start > 0) {
      final char = text[start - 1];
      final isBoundary = RegExp(r'[\s,.!?:;\(\)\[\]\{\}"“”]').hasMatch(char);
      if (isBoundary) break;
      start--;
    }

    int end = cursorIndex;
    while (end < text.length) {
      final char = text[end];
      final isBoundary = RegExp(r'[\s,.!?:;\(\)\[\]\{\}"“”]').hasMatch(char);
      if (isBoundary) break;
      end++;
    }

    final replacement = entry.title;
    final newText = text.replaceRange(start, end, replacement);

    final newCursor = start + replacement.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    _clearSuggestions();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: widget.decoration,
          maxLines: widget.maxLines,
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              children: _suggestions.map((entry) {
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    child: Icon(
                      _iconForType(entry.type),
                      size: 16,
                    ),
                  ),
                  title: Text(entry.title),
                  subtitle: Text(entry.type),
                  onTap: () => _insertSuggestion(entry),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
