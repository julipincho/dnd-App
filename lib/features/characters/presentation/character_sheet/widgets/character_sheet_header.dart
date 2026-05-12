import 'package:flutter/material.dart';
import 'package:stitch_app/models/character.dart';
import 'package:stitch_app/utils/image_path_utils.dart';

class CharacterSheetHeader extends StatelessWidget {
  final Character character;

  const CharacterSheetHeader({
    super.key,
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;

    final cardPadding = isLargeTablet ? 24.0 : (isTablet ? 20.0 : 16.0);
    final portraitSize = isLargeTablet ? 128.0 : (isTablet ? 112.0 : 92.0);
    final titleSize = isLargeTablet ? 36.0 : (isTablet ? 31.0 : 25.0);
    final subtitleSize = isLargeTablet ? 15.0 : (isTablet ? 14.0 : 13.0);
    final smallSubtitleSize = isLargeTablet ? 13.0 : (isTablet ? 12.0 : 11.0);
    final minHeight = isLargeTablet ? 246.0 : (isTablet ? 226.0 : 286.0);

    final portrait = _CharacterHeaderPortrait(
      character: character,
      size: portraitSize,
    );

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF11141B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE14658).withValues(alpha: 0.34),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _classImagePath(character.charClass),
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF11141B),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF0E1117),
                    const Color(0xFF11141B).withValues(alpha: 0.94),
                    const Color(0xFF11141B).withValues(alpha: 0.48),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.60),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: isTablet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      portrait,
                      const SizedBox(width: 20),
                      Expanded(
                        child: _CharacterHeaderTextBlock(
                          character: character,
                          titleSize: titleSize,
                          subtitleSize: subtitleSize,
                          smallSubtitleSize: smallSubtitleSize,
                          isCentered: false,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      portrait,
                      const SizedBox(height: 14),
                      _CharacterHeaderTextBlock(
                        character: character,
                        titleSize: titleSize,
                        subtitleSize: subtitleSize,
                        smallSubtitleSize: smallSubtitleSize,
                        isCentered: true,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _classImagePath(String className) {
  final slug = className.trim().toLowerCase().replaceAll(' ', '-');
  return 'assets/images/classes/$slug.png';
}

String buildCharacterClassIdentityLabel(Character character) {
  return buildCharacterClassIdentityParts(character).join(' + ');
}

List<String> buildCharacterClassIdentityParts(Character character) {
  final orderedClassNames = <String>[];
  final seen = <String>{};

  void addClassName(String? className) {
    final trimmed = className?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final key = trimmed.toLowerCase();
    if (seen.add(key)) {
      orderedClassNames.add(trimmed);
    }
  }

  addClassName(character.charClass);
  for (final level in character.normalizedProgression.levels) {
    addClassName(level.className);
  }
  for (final className in character.classLevels.keys) {
    addClassName(className);
  }

  if (orderedClassNames.isEmpty) {
    return [
      character.charClass.trim().isEmpty
          ? 'No class selected'
          : character.charClass,
    ];
  }

  final isMulticlass = orderedClassNames.length > 1;

  return orderedClassNames.map((className) {
    final classLevel = character.levelForClass(className);
    final subclassName = (character.subclassForClass(className) ??
            (className.trim().toLowerCase() ==
                    character.charClass.trim().toLowerCase()
                ? character.subclass
                : null))
        ?.trim();

    final subclassSuffix =
        subclassName == null || subclassName.isEmpty ? '' : ' / $subclassName';
    final levelSuffix = isMulticlass && classLevel > 0 ? ' $classLevel' : '';

    return '$className$subclassSuffix$levelSuffix';
  }).toList();
}

class _CharacterHeaderPortrait extends StatelessWidget {
  final Character character;
  final double size;

  const _CharacterHeaderPortrait({
    required this.character,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final hasPortrait = hasDisplayableImagePath(character.portraitPath);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF252631),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE14658).withValues(alpha: 0.72),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        image: hasPortrait
            ? DecorationImage(
                image: imageProviderFromPath(character.portraitPath!),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              )
            : null,
      ),
      child: !hasPortrait
          ? const Icon(
              Icons.person,
              size: 34,
              color: Colors.white70,
            )
          : null,
    );
  }
}

class _CharacterHeaderTextBlock extends StatelessWidget {
  final Character character;
  final double titleSize;
  final double subtitleSize;
  final double smallSubtitleSize;
  final bool isCentered;

  const _CharacterHeaderTextBlock({
    required this.character,
    required this.titleSize,
    required this.subtitleSize,
    required this.smallSubtitleSize,
    required this.isCentered,
  });

  @override
  Widget build(BuildContext context) {
    final ancestryLabel =
        "${character.race}${character.subrace != null ? ' (${character.subrace})' : ''}";
    final classIdentityParts = buildCharacterClassIdentityParts(character);

    return Column(
      crossAxisAlignment:
          isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          character.name.isEmpty ? 'Unnamed Character' : character.name,
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 12,
              ),
            ],
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$ancestryLabel - Level ${character.level}',
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: subtitleSize,
            color: Colors.white.withValues(alpha: 0.82),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: isCentered ? WrapAlignment.center : WrapAlignment.start,
          spacing: 6,
          runSpacing: 6,
          children: classIdentityParts
              .map(
                (label) => _ClassIdentityChip(
                  label: label,
                  fontSize: smallSubtitleSize,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        Text(
          '${character.background.name} - ${character.alignment ?? 'True Neutral'}',
          textAlign: isCentered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: smallSubtitleSize,
            color: Colors.white.withValues(alpha: 0.76),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ClassIdentityChip extends StatelessWidget {
  final String label;
  final double fontSize;

  const _ClassIdentityChip({
    required this.label,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE14658).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFE14658).withValues(alpha: 0.42),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.90),
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
