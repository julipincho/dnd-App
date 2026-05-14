import '../models/compendium_entry.dart';

class CompendiumTextMatch {
  final int start;
  final int end;
  final CompendiumEntry entry;

  const CompendiumTextMatch({
    required this.start,
    required this.end,
    required this.entry,
  });
}

class CompendiumLinking {
  const CompendiumLinking._();

  static List<CompendiumTextMatch> findMentions({
    required String text,
    required List<CompendiumEntry> entries,
  }) {
    if (text.trim().isEmpty || entries.isEmpty) return const [];

    final sortedEntries = entries
        .where((entry) => entry.title.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.title.trim().length.compareTo(a.title.trim().length));

    final matches = <CompendiumTextMatch>[];

    for (final entry in sortedEntries) {
      for (final match in _titleMatches(text, entry.title)) {
        final start = _contentStart(match);
        final mention = match.group(2);
        if (mention == null) continue;

        final end = start + mention.length;
        final overlaps = matches.any(
          (existing) => start < existing.end && end > existing.start,
        );

        if (!overlaps) {
          matches.add(
            CompendiumTextMatch(
              start: start,
              end: end,
              entry: entry,
            ),
          );
        }
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }

  static List<CompendiumEntry> mentionedEntries({
    required String text,
    required List<CompendiumEntry> entries,
  }) {
    final seenIds = <String>{};
    final mentioned = <CompendiumEntry>[];

    for (final match in findMentions(text: text, entries: entries)) {
      if (seenIds.add(match.entry.id)) {
        mentioned.add(match.entry);
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
}
