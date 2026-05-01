import 'package:flutter/material.dart';
import 'package:stitch_app/models/character.dart';
import 'package:stitch_app/utils/image_path_utils.dart';

class CharacterStoryTab extends StatelessWidget {
  final Character character;
  final String classIdentityLabel;

  const CharacterStoryTab({
    super.key,
    required this.character,
    required this.classIdentityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;
    final maxWidth = isLargeTablet ? 1100.0 : 900.0;

    final backstory = (character.backstory ?? '').trim();
    final backgroundFeatureName = character.background.featureName.trim();
    final backgroundFeatureDescription = character.background.featureDescription
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n\n');

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: isLargeTablet
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 340,
                      child: Column(
                        children: [
                          _PortraitPanel(
                            character: character,
                            isTablet: isTablet,
                          ),
                          const SizedBox(height: 12),
                          _IdentityPanel(
                            character: character,
                            classIdentityLabel: classIdentityLabel,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StoryBody(
                        backstory: backstory,
                        backgroundFeatureName: backgroundFeatureName,
                        backgroundFeatureDescription:
                            backgroundFeatureDescription,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _PortraitPanel(
                      character: character,
                      isTablet: isTablet,
                    ),
                    const SizedBox(height: 12),
                    _IdentityPanel(
                      character: character,
                      classIdentityLabel: classIdentityLabel,
                    ),
                    const SizedBox(height: 12),
                    _StoryBody(
                      backstory: backstory,
                      backgroundFeatureName: backgroundFeatureName,
                      backgroundFeatureDescription:
                          backgroundFeatureDescription,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StoryBody extends StatelessWidget {
  final String backstory;
  final String backgroundFeatureName;
  final String backgroundFeatureDescription;

  const _StoryBody({
    required this.backstory,
    required this.backgroundFeatureName,
    required this.backgroundFeatureDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NarrativeCard(
          title: 'Backstory',
          content: backstory.isEmpty ? 'No backstory yet.' : backstory,
        ),
        if (backgroundFeatureName.isNotEmpty ||
            backgroundFeatureDescription.isNotEmpty) ...[
          const SizedBox(height: 12),
          _NarrativeCard(
            title: backgroundFeatureName.isEmpty
                ? 'Background Feature'
                : backgroundFeatureName,
            content: backgroundFeatureDescription.isEmpty
                ? 'No background feature description yet.'
                : backgroundFeatureDescription,
          ),
        ],
      ],
    );
  }
}

class _PortraitPanel extends StatelessWidget {
  final Character character;
  final bool isTablet;

  const _PortraitPanel({
    required this.character,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final hasPortrait = hasDisplayableImagePath(character.portraitPath);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: isTablet ? 360 : 260,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF171821),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.28),
        ),
        image: hasPortrait
            ? DecorationImage(
                image: imageProviderFromPath(character.portraitPath!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasPortrait
          ? Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
                child: Text(
                  character.name.isEmpty ? 'Unnamed Character' : character.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
          : Center(
              child: Icon(
                Icons.image_outlined,
                color: Colors.white.withValues(alpha: 0.42),
                size: 46,
              ),
            ),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  final Character character;
  final String classIdentityLabel;

  const _IdentityPanel({
    required this.character,
    required this.classIdentityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final raceText =
        '${character.race}${character.subrace != null ? ' (${character.subrace})' : ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            character.name.isEmpty ? 'Unnamed Character' : character.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _StoryMetaRow('Race', raceText),
          _StoryMetaRow(
            'Class',
            '$classIdentityLabel - Level ${character.level}',
          ),
          _StoryMetaRow('Background', character.background.name),
          _StoryMetaRow('Alignment', character.alignment ?? 'True Neutral'),
        ],
      ),
    );
  }
}

class _StoryMetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _StoryMetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  final String title;
  final String content;

  const _NarrativeCard({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
