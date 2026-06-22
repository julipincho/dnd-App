import '../models/character.dart';
import '../models/feat_data.dart';
import '../utils/spellcasting_rules.dart';

class FeatValidationService {
  static bool canTakeFeat(Character character, FeatData feat) {
    return getValidationErrors(character, feat).isEmpty;
  }

  static List<String> getValidationErrors(Character character, FeatData feat) {
    final errors = <String>{};

    final prerequisiteErrors = _getPrerequisiteErrors(character, feat);
    errors.addAll(prerequisiteErrors);

    if (!feat.repeatable && character.selectedFeatIds.contains(feat.id)) {
      errors.add('Already selected');
    }

    return errors.toList();
  }

  static List<String> _getPrerequisiteErrors(
    Character character,
    FeatData feat,
  ) {
    if (feat.prerequisites.isEmpty) return const [];

    final alternativeErrors = <List<String>>[];

    for (final rawPrereq in feat.prerequisites) {
      if (rawPrereq is! Map) continue;
      final prereq = Map<String, dynamic>.from(rawPrereq);
      final errors = _validatePrerequisite(character, prereq);
      if (errors.isEmpty) return const [];
      alternativeErrors.add(errors);
    }

    if (alternativeErrors.isEmpty) return const [];

    return alternativeErrors
        .expand((errors) => errors)
        .toSet()
        .toList(growable: false);
  }

  static List<String> _validatePrerequisite(
    Character character,
    Map<String, dynamic> prereq,
  ) {
    final errors = <String>[];

    final levelError = _validateLevelPrerequisite(character, prereq['level']);
    if (levelError != null) errors.add(levelError);

    if (prereq['ability'] is List) {
      errors.addAll(_validateAbilityPrerequisites(
        character,
        prereq['ability'] as List,
      ));
    }

    if (prereq['spellcasting'] == true || prereq['spellcasting2020'] == true) {
      if (!_hasSpellcastingFeature(character)) {
        errors.add('Requires spellcasting');
      }
    }

    if (prereq['feat'] is List) {
      final featError = _validateFeatPrerequisites(
        character,
        prereq['feat'] as List,
      );
      if (featError != null) errors.add(featError);
    }

    if (prereq['background'] is List) {
      final backgroundError = _validateBackgroundPrerequisites(
        character,
        prereq['background'] as List,
      );
      if (backgroundError != null) errors.add(backgroundError);
    }

    return errors;
  }

  static String? _validateLevelPrerequisite(
    Character character,
    dynamic rawLevel,
  ) {
    if (rawLevel is int) {
      return character.level < rawLevel ? 'Requires level $rawLevel' : null;
    }

    if (rawLevel is! Map) return null;

    final levelData = Map<String, dynamic>.from(rawLevel);
    final requiredLevel = levelData['level'] is int
        ? levelData['level'] as int
        : int.tryParse(levelData['level']?.toString() ?? '');
    if (requiredLevel == null) return null;

    final rawClass = levelData['class'];
    if (rawClass is Map) {
      final className = rawClass['name']?.toString().trim();
      if (className != null && className.isNotEmpty) {
        return character.levelForClass(className) < requiredLevel
            ? 'Requires $className level $requiredLevel'
            : null;
      }
    }

    return character.level < requiredLevel
        ? 'Requires level $requiredLevel'
        : null;
  }

  static List<String> _validateAbilityPrerequisites(
    Character character,
    List abilities,
  ) {
    final errors = <String>[];

    for (final entry in abilities) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);

      for (final kv in map.entries) {
        final ability = kv.key.toUpperCase();
        final requiredValue = kv.value is int ? kv.value as int : null;
        if (requiredValue == null) continue;

        final current = _getAbilityScore(character, ability);
        if (current < requiredValue) {
          errors.add('Requires $ability $requiredValue');
        }
      }
    }

    return errors;
  }

  static String? _validateFeatPrerequisites(
    Character character,
    List rawRequiredFeats,
  ) {
    final requiredFeats =
        rawRequiredFeats.map((e) => e.toString().trim().toLowerCase()).toList();

    final ownedFeats =
        character.selectedFeatIds.map((e) => e.trim().toLowerCase()).toList();

    final hasRequiredFeat = ownedFeats.any((owned) {
      return requiredFeats.any((req) {
        return owned == req || owned.contains(req);
      });
    });

    return hasRequiredFeat ? null : 'Requires another feat';
  }

  static String? _validateBackgroundPrerequisites(
    Character character,
    List rawBackgrounds,
  ) {
    final currentBackground = character.background.name.trim().toLowerCase();
    if (currentBackground.isEmpty) return 'Requires a specific background';

    for (final entry in rawBackgrounds) {
      final backgroundName = entry is Map
          ? entry['name']?.toString().trim().toLowerCase()
          : entry.toString().trim().toLowerCase();
      if (backgroundName == null || backgroundName.isEmpty) continue;
      if (currentBackground == backgroundName ||
          currentBackground.contains(backgroundName)) {
        return null;
      }
    }

    return 'Requires a specific background';
  }

  static bool _hasSpellcastingFeature(Character character) {
    if (character.hasAnySpellcastingAbility) return true;

    for (final entry in character.classLevels.entries) {
      if (entry.value <= 0) continue;
      final progression = SpellcastingRules.getProgressionForClassAndSubclass(
        className: entry.key,
        subclassName: character.subclassForClass(entry.key),
      );
      if (progression != SpellcastingProgression.none) return true;
    }

    return false;
  }

  static int _getAbilityScore(Character character, String ability) {
    final base = character.stats[ability] ?? 0;
    final racialBonus = character.racialBonuses[ability] ?? 0;
    final featBonus = character.featAbilityBonuses[ability] ?? 0;
    return base + racialBonus + featBonus;
  }
}
