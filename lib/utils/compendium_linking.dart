import '../models/compendium_entry.dart';

class CompendiumTextMatch {
  final int start;
  final int end;
  final CompendiumEntry entry;
  final String? displayText;
  final bool isExplicit;

  const CompendiumTextMatch({
    required this.start,
    required this.end,
    required this.entry,
    this.displayText,
    this.isExplicit = false,
  });
}

class UnresolvedCompendiumTextMatch {
  final int start;
  final int end;
  final String displayText;
  final String rawText;
  final String? type;

  const UnresolvedCompendiumTextMatch({
    required this.start,
    required this.end,
    required this.displayText,
    required this.rawText,
    this.type,
  });
}

class CompendiumTextSegment {
  final int start;
  final int end;
  final String displayText;
  final CompendiumEntry? entry;
  final String? unresolvedType;
  final bool isExplicit;

  const CompendiumTextSegment({
    required this.start,
    required this.end,
    required this.displayText,
    this.entry,
    this.unresolvedType,
    this.isExplicit = false,
  });

  bool get isResolved => entry != null;
  bool get isUnresolved => entry == null && isExplicit;
}

class CompendiumLinking {
  const CompendiumLinking._();

  static List<CompendiumTextMatch> findMentions({
    required String text,
    required List<CompendiumEntry> entries,
  }) {
    return buildTextSegments(text: text, entries: entries)
        .where((segment) => segment.isResolved)
        .map(
          (segment) => CompendiumTextMatch(
            start: segment.start,
            end: segment.end,
            entry: segment.entry!,
            displayText: segment.displayText,
            isExplicit: segment.isExplicit,
          ),
        )
        .toList();
  }

  static List<UnresolvedCompendiumTextMatch> findUnresolvedWikiLinks({
    required String text,
    required List<CompendiumEntry> entries,
  }) {
    return buildTextSegments(text: text, entries: entries)
        .where((segment) => segment.isUnresolved)
        .map(
          (segment) => UnresolvedCompendiumTextMatch(
            start: segment.start,
            end: segment.end,
            displayText: segment.displayText,
            rawText: text.substring(segment.start, segment.end),
            type: segment.unresolvedType,
          ),
        )
        .toList();
  }

  static List<CompendiumTextSegment> buildTextSegments({
    required String text,
    required List<CompendiumEntry> entries,
  }) {
    if (text.trim().isEmpty) return const [];

    final segments = <CompendiumTextSegment>[];

    for (final link in _parseWikiLinks(text)) {
      final entry = _resolveExplicitLink(link, entries);
      segments.add(
        CompendiumTextSegment(
          start: link.start,
          end: link.end,
          displayText: link.displayText,
          entry: entry,
          unresolvedType: entry == null ? link.type : null,
          isExplicit: true,
        ),
      );
    }

    if (entries.isNotEmpty) {
      final sortedEntries =
          entries.where((entry) => entry.title.trim().isNotEmpty).toList()
            ..sort(
              (a, b) => b.title.trim().length.compareTo(a.title.trim().length),
            );

      for (final entry in sortedEntries) {
        for (final match in _titleMatches(text, entry.title)) {
          final start = _contentStart(match);
          final mention = match.group(2);
          if (mention == null) continue;

          final end = start + mention.length;
          if (_overlapsAny(start, end, segments)) continue;

          segments.add(
            CompendiumTextSegment(
              start: start,
              end: end,
              displayText: text.substring(start, end),
              entry: entry,
            ),
          );
        }
      }
    }

    segments.sort((a, b) => a.start.compareTo(b.start));
    return segments;
  }

  static List<CompendiumEntry> mentionedEntries({
    required String text,
    required List<CompendiumEntry> entries,
  }) {
    final seenIds = <String>{};
    final mentioned = <CompendiumEntry>[];

    for (final segment in buildTextSegments(text: text, entries: entries)) {
      final entry = segment.entry;
      if (entry != null && seenIds.add(entry.id)) {
        mentioned.add(entry);
      }
    }

    return mentioned;
  }

  static bool containsTitle(String text, String title) {
    if (text.trim().isEmpty || title.trim().isEmpty) return false;
    return _titleMatches(text, title).isNotEmpty;
  }

  static Iterable<RegExpMatch> _titleMatches(String text, String title) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return const [];

    final escapedTitle = RegExp.escape(cleanTitle);
    final regex = RegExp(
      r'(^|[^A-Za-z0-9_])(' + escapedTitle + r')(?=$|[^A-Za-z0-9_])',
      caseSensitive: false,
    );

    return regex.allMatches(text);
  }

  static int _contentStart(RegExpMatch match) {
    final prefix = match.group(1) ?? '';
    return match.start + prefix.length;
  }

  static List<_ParsedWikiLink> _parseWikiLinks(String text) {
    final regex = RegExp(r'\[\[([^\]\n]+)\]\]');
    final links = <_ParsedWikiLink>[];

    for (final match in regex.allMatches(text)) {
      final rawContent = match.group(1)?.trim();
      if (rawContent == null || rawContent.isEmpty) continue;

      final link = _parseWikiLinkContent(
        rawContent: rawContent,
        start: match.start,
        end: match.end,
      );
      if (link != null) links.add(link);
    }

    return links;
  }

  static _ParsedWikiLink? _parseWikiLinkContent({
    required String rawContent,
    required int start,
    required int end,
  }) {
    final aliasParts = rawContent.split('|');
    final target = aliasParts.first.trim();
    final alias =
        aliasParts.length > 1 ? aliasParts.sublist(1).join('|').trim() : '';

    if (target.isEmpty) return null;

    String? type;
    String title = target;
    final colonIndex = target.indexOf(':');

    if (colonIndex > 0 && colonIndex < target.length - 1) {
      final typeCandidate = target.substring(0, colonIndex).trim();
      final titleCandidate = target.substring(colonIndex + 1).trim();

      if (_looksLikeType(typeCandidate) && titleCandidate.isNotEmpty) {
        type = _normalizeType(typeCandidate);
        title = titleCandidate;
      }
    }

    if (title.trim().isEmpty) return null;

    return _ParsedWikiLink(
      start: start,
      end: end,
      title: title.trim(),
      displayText: alias.isEmpty ? title.trim() : alias,
      type: type,
    );
  }

  static CompendiumEntry? _resolveExplicitLink(
    _ParsedWikiLink link,
    List<CompendiumEntry> entries,
  ) {
    final normalizedTitle = _normalizeText(link.title);

    for (final entry in entries) {
      final titleMatches = _normalizeText(entry.title) == normalizedTitle;
      final typeMatches = link.type == null ||
          _normalizeType(entry.type) == _normalizeType(link.type!);

      if (titleMatches && typeMatches) {
        return entry;
      }
    }

    return null;
  }

  static bool _overlapsAny(
    int start,
    int end,
    List<CompendiumTextSegment> segments,
  ) {
    return segments.any(
      (existing) => start < existing.end && end > existing.start,
    );
  }

  static bool _looksLikeType(String value) {
    return const {'npc', 'location', 'item', 'faction', 'lore'}
        .contains(_normalizeType(value));
  }

  static String _normalizeText(String value) {
    return value.trim().toLowerCase();
  }

  static String _normalizeType(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', '-');

    switch (normalized) {
      case 'character':
      case 'person':
      case 'personaje':
        return 'npc';
      case 'place':
      case 'lugar':
        return 'location';
      case 'object':
      case 'magic-item':
      case 'magic item':
      case 'objeto':
        return 'item';
      case 'group':
      case 'faccion':
        return 'faction';
      case 'story':
      case 'historia':
        return 'lore';
      default:
        return normalized;
    }
  }
}

class _ParsedWikiLink {
  final int start;
  final int end;
  final String title;
  final String displayText;
  final String? type;

  const _ParsedWikiLink({
    required this.start,
    required this.end,
    required this.title,
    required this.displayText,
    this.type,
  });
}
