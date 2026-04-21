import '../models/character.dart';
import '../models/feat_data.dart';

class FeatValidationService {
  static bool canTakeFeat(Character character, FeatData feat) {
    return getValidationErrors(character, feat).isEmpty;
  }

  static List<String> getValidationErrors(Character character, FeatData feat) {
    final errors = <String>[];

    for (final rawPrereq in feat.prerequisites) {
      if (rawPrereq is! Map) continue;
      final prereq = Map<String, dynamic>.from(rawPrereq);

      if (prereq['level'] is int) {
        final requiredLevel = prereq['level'] as int;
        if (character.level < requiredLevel) {
          errors.add('Requires level $requiredLevel');
        }
      }

      if (prereq['ability'] is List) {
        final abilities = prereq['ability'] as List;

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
      }

      if (prereq['spellcasting'] == true ||
          prereq['spellcasting2020'] == true) {
        final hasSpellcasting = character.spellcastingAbility != null &&
            character.spellcastingAbility!.trim().isNotEmpty;

        if (!hasSpellcasting) {
          errors.add('Requires spellcasting');
        }
      }

      if (prereq['feat'] is List) {
        final requiredFeats = (prereq['feat'] as List)
            .map((e) => e.toString().trim().toLowerCase())
            .toList();

        final ownedFeats = character.selectedFeatIds
            .map((e) => e.trim().toLowerCase())
            .toList();

        final hasRequiredFeat = ownedFeats.any((owned) {
          return requiredFeats.any((req) {
            return owned == req || owned.contains(req);
          });
        });

        if (!hasRequiredFeat) {
          errors.add('Requires another feat');
        }
      }
    }

    if (!feat.repeatable && character.selectedFeatIds.contains(feat.id)) {
      errors.add('Already selected');
    }

    return errors;
  }

  static int _getAbilityScore(Character character, String ability) {
    final base = character.stats[ability] ?? 0;
    final racialBonus = character.racialBonuses[ability] ?? 0;
    final featBonus = character.featAbilityBonuses[ability] ?? 0;
    return base + racialBonus + featBonus;
  }
}
