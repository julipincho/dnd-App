import 'package:flutter/material.dart';
import 'package:stitch_app/models/character.dart';
import 'package:stitch_app/models/character_feature.dart';
import 'package:stitch_app/theme.dart';
import 'package:stitch_app/widgets/stitch_codex_ui.dart';

import 'character_sheet_meta_chip.dart';

class CharacterFeaturesSection extends StatelessWidget {
  final Character character;
  final bool isTablet;
  final bool isLargeTablet;

  const CharacterFeaturesSection({
    super.key,
    required this.character,
    required this.isTablet,
    required this.isLargeTablet,
  });

  @override
  Widget build(BuildContext context) {
    final features = [...character.features]..sort((a, b) {
        final levelCompare =
            (a.unlockedAtLevel ?? 0).compareTo(b.unlockedAtLevel ?? 0);
        if (levelCompare != 0) return levelCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (features.isEmpty) {
      return const _CharacterSheetSection(
        title: 'Features',
        child: Text(
          'No features available yet.',
          style: TextStyle(
            color: StitchCodexPalette.textMuted,
            fontFamily: StitchTypography.body,
          ),
        ),
      );
    }

    final groupedFeatures = _groupFeaturesBySource(features);
    final orderedGroups = <_FeatureGroupData>[
      _FeatureGroupData(
        title: 'Race Features',
        icon: Icons.public,
        features: groupedFeatures['race'] ?? const [],
      ),
      _FeatureGroupData(
        title: 'Subrace Features',
        icon: Icons.account_tree_outlined,
        features: groupedFeatures['subrace'] ?? const [],
      ),
    ].where((group) => group.features.isNotEmpty).toList();

    orderedGroups.addAll(
      _buildClassFeatureGroups(
        character,
        classFeatures: groupedFeatures['class'] ?? const [],
        subclassFeatures: groupedFeatures['subclass'] ?? const [],
      ),
    );

    orderedGroups.addAll(
      [
        _FeatureGroupData(
          title: 'Feat Features',
          icon: Icons.workspace_premium_outlined,
          features: groupedFeatures['feat'] ?? const [],
        ),
        _FeatureGroupData(
          title: 'Other Features',
          icon: Icons.category_outlined,
          features: groupedFeatures['other'] ?? const [],
        ),
      ].where((group) => group.features.isNotEmpty),
    );

    return _CharacterSheetSection(
      title: 'Features',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...orderedGroups.map(
            (group) => _FeatureSourceGroupCard(
              title: group.title,
              icon: group.icon,
              features: group.features,
              isTablet: isTablet,
              isLargeTablet: isLargeTablet,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<CharacterFeature>> _groupFeaturesBySource(
    List<CharacterFeature> features,
  ) {
    final grouped = <String, List<CharacterFeature>>{
      'race': [],
      'subrace': [],
      'class': [],
      'subclass': [],
      'feat': [],
      'other': [],
    };

    for (final feature in features) {
      final normalizedSource = feature.source.trim().toLowerCase();

      if (grouped.containsKey(normalizedSource)) {
        grouped[normalizedSource]!.add(feature);
      } else {
        grouped['other']!.add(feature);
      }
    }

    return grouped;
  }

  List<_FeatureGroupData> _buildClassFeatureGroups(
    Character char, {
    required List<CharacterFeature> classFeatures,
    required List<CharacterFeature> subclassFeatures,
  }) {
    final groups = <_FeatureGroupData>[];
    final usedClassFeatureIds = <String>{};
    final usedSubclassFeatureIds = <String>{};

    for (final entry in char.classLevels.entries) {
      final className = entry.key;
      final classKey = _featureClassKey(className);

      final featuresForClass = classFeatures.where((feature) {
        final matches = _featureClassKeyFromId(feature.id, 'class') == classKey;
        if (matches) usedClassFeatureIds.add(feature.id);
        return matches;
      }).toList();

      final subclassFeaturesForClass = subclassFeatures.where((feature) {
        final matches =
            _featureClassKeyFromId(feature.id, 'subclass') == classKey;
        if (matches) usedSubclassFeatureIds.add(feature.id);
        return matches;
      }).toList();

      if (featuresForClass.isNotEmpty) {
        groups.add(
          _FeatureGroupData(
            title: '$className Features',
            icon: Icons.shield_outlined,
            features: featuresForClass,
          ),
        );
      }

      if (subclassFeaturesForClass.isNotEmpty) {
        final subclassName = char.subclassForClass(className)?.trim();
        groups.add(
          _FeatureGroupData(
            title: (subclassName == null || subclassName.isEmpty)
                ? '$className Subclass Features'
                : '$className - $subclassName Features',
            icon: Icons.auto_awesome_outlined,
            features: subclassFeaturesForClass,
          ),
        );
      }
    }

    final unmatchedClassFeatures = classFeatures
        .where((feature) => !usedClassFeatureIds.contains(feature.id))
        .toList();
    if (unmatchedClassFeatures.isNotEmpty) {
      groups.add(
        _FeatureGroupData(
          title: 'Other Class Features',
          icon: Icons.shield_outlined,
          features: unmatchedClassFeatures,
        ),
      );
    }

    final unmatchedSubclassFeatures = subclassFeatures
        .where((feature) => !usedSubclassFeatureIds.contains(feature.id))
        .toList();
    if (unmatchedSubclassFeatures.isNotEmpty) {
      groups.add(
        _FeatureGroupData(
          title: 'Other Subclass Features',
          icon: Icons.auto_awesome_outlined,
          features: unmatchedSubclassFeatures,
        ),
      );
    }

    return groups;
  }

  String _featureClassKey(String className) {
    return className.trim().toLowerCase();
  }

  String? _featureClassKeyFromId(String featureId, String source) {
    final prefix = '${source}_';
    if (!featureId.startsWith(prefix)) return null;

    final rest = featureId.substring(prefix.length);
    final separator = rest.indexOf('_');
    if (separator <= 0) return null;

    return rest.substring(0, separator);
  }
}

class _FeatureGroupData {
  final String title;
  final IconData icon;
  final List<CharacterFeature> features;

  const _FeatureGroupData({
    required this.title,
    required this.icon,
    required this.features,
  });
}

class _FeatureSourceGroupCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<CharacterFeature> features;
  final bool isTablet;
  final bool isLargeTablet;

  const _FeatureSourceGroupCard({
    required this.title,
    required this.icon,
    required this.features,
    required this.isTablet,
    required this.isLargeTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: StitchCodexPalette.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.24),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: StitchCodexPalette.bronze,
          collapsedIconColor: StitchCodexPalette.textMuted,
          leading: Icon(
            icon,
            color: StitchCodexPalette.bronze,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: isLargeTablet ? 17 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${features.length} feature${features.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
                fontSize: 12,
              ),
            ),
          ),
          children: [
            ...features.map(
              (feature) => _FeatureTile(
                feature: feature,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final CharacterFeature feature;
  final bool isTablet;
  final bool isLargeTablet;

  const _FeatureTile({
    required this.feature,
    required this.isTablet,
    required this.isLargeTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: StitchCodexPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.12),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: StitchCodexPalette.bronze,
          collapsedIconColor: StitchCodexPalette.textMuted,
          title: Text(
            feature.name,
            style: TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: isLargeTablet ? 15 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (feature.unlockedAtLevel != null)
                  CharacterSheetMetaChip(
                    label: 'Lv ${feature.unlockedAtLevel}',
                  ),
                CharacterSheetMetaChip(label: feature.source.toUpperCase()),
              ],
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                feature.description.trim().isEmpty
                    ? 'No description available.'
                    : feature.description,
                style: TextStyle(
                  color: StitchCodexPalette.textSecondary,
                  fontFamily: StitchTypography.body,
                  fontSize: isTablet ? 14 : 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterSheetSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CharacterSheetSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StitchCodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
