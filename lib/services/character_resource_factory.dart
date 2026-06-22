import '../models/character.dart';
import '../models/character_resource.dart';

class CharacterResourceFactory {
  static String _norm(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Ã¡', 'a')
        .replaceAll('Ã©', 'e')
        .replaceAll('Ã­', 'i')
        .replaceAll('Ã³', 'o')
        .replaceAll('Ãº', 'u')
        .replaceAll('Ã±', 'n');
  }

  static const Map<String, List<String>> _classAliases = {
    'artificer': ['artificer', 'artifice', 'artificiero'],
    'barbarian': ['barbarian', 'barbaro'],
    'bard': ['bard', 'bardo'],
    'cleric': ['cleric', 'clerigo'],
    'druid': ['druid', 'druida'],
    'fighter': ['fighter', 'guerrero'],
    'monk': ['monk', 'monje'],
    'paladin': ['paladin'],
    'sorcerer': ['sorcerer', 'hechicero'],
  };

  static bool _classMatches(String actual, String target) {
    final normalizedActual = _norm(actual);
    final normalizedTarget = _norm(target);
    final aliases = _classAliases[normalizedTarget] ?? [normalizedTarget];
    return aliases.contains(normalizedActual);
  }

  static List<CharacterResource> buildResources(Character character) {
    final result = <CharacterResource>[];

    int abilityMod(String key) {
      final base = character.stats[key] ?? 10;
      final racial = character.racialBonuses[key] ?? 0;
      final feat = character.featAbilityBonuses[key] ?? 0;
      return ((base + racial + feat - 10) / 2).floor();
    }

    int classLevel(String className) {
      var result = 0;
      for (final entry in character.classLevels.entries) {
        if (!_classMatches(entry.key, className)) continue;
        if (entry.value > result) result = entry.value;
      }
      return result;
    }

    bool hasClassLevel(String className, int minimumLevel) {
      return classLevel(className) >= minimumLevel;
    }

    String? subclassForClass(String className) {
      for (final entry in character.normalizedProgression.levels.reversed) {
        if (!_classMatches(entry.className, className)) continue;
        final subclassName = entry.subclassName?.trim();
        if (subclassName != null && subclassName.isNotEmpty) {
          return subclassName;
        }
      }
      return null;
    }

    void addResource({
      required String id,
      required String name,
      required int max,
      required String rechargeType,
      String? notes,
    }) {
      final safeMax = max < 1 ? 1 : max;
      result.add(
        CharacterResource(
          id: id,
          name: name,
          current: safeMax,
          max: safeMax,
          rechargeType: rechargeType,
          notes: notes,
        ),
      );
    }

    final barbarianLevel = classLevel('barbarian');
    if (barbarianLevel > 0) {
      int rageMax;
      if (barbarianLevel >= 17) {
        rageMax = 6;
      } else if (barbarianLevel >= 12) {
        rageMax = 5;
      } else if (barbarianLevel >= 6) {
        rageMax = 4;
      } else if (barbarianLevel >= 3) {
        rageMax = 3;
      } else {
        rageMax = 2;
      }

      addResource(
        id: 'rage',
        name: 'Rage',
        max: rageMax,
        rechargeType: 'longRest',
      );
    }

    if (hasClassLevel('artificer', 7)) {
      addResource(
        id: 'flash_of_genius',
        name: 'Flash of Genius',
        max: abilityMod('INT'),
        rechargeType: 'longRest',
      );
    }

    if (hasClassLevel('fighter', 1)) {
      addResource(
        id: 'second_wind',
        name: 'Second Wind',
        max: 1,
        rechargeType: 'shortRest',
      );
    }

    if (hasClassLevel('fighter', 2)) {
      addResource(
        id: 'action_surge',
        name: 'Action Surge',
        max: 1,
        rechargeType: 'shortRest',
      );
    }

    final monkLevel = classLevel('monk');
    if (monkLevel >= 2) {
      addResource(
        id: 'ki_points',
        name: 'Ki Points',
        max: monkLevel,
        rechargeType: 'shortRest',
      );
    }

    final sorcererLevel = classLevel('sorcerer');
    if (sorcererLevel >= 2) {
      addResource(
        id: 'sorcery_points',
        name: 'Sorcery Points',
        max: sorcererLevel,
        rechargeType: 'longRest',
      );
    }

    final clericLevel = classLevel('cleric');
    if (clericLevel >= 2) {
      final uses = clericLevel >= 6 ? 2 : 1;
      addResource(
        id: 'channel_divinity',
        name: 'Channel Divinity',
        max: uses,
        rechargeType: 'shortRest',
      );
    }

    final paladinLevel = classLevel('paladin');
    if (paladinLevel >= 1) {
      addResource(
        id: 'lay_on_hands',
        name: 'Lay on Hands',
        max: paladinLevel * 5,
        rechargeType: 'longRest',
      );
    }

    final bardLevel = classLevel('bard');
    if (bardLevel >= 1) {
      final max = abilityMod('CHA');
      addResource(
        id: 'bardic_inspiration',
        name: 'Bardic Inspiration',
        max: max,
        rechargeType: bardLevel >= 5 ? 'shortRest' : 'longRest',
      );
    }

    if (hasClassLevel('druid', 2)) {
      addResource(
        id: 'wild_shape',
        name: 'Wild Shape',
        max: 2,
        rechargeType: 'shortRest',
      );
    }

    int superiorityDiceMax = 0;
    String? superiorityDiceNotes;

    final fighterLevel = classLevel('fighter');
    final fighterSubclass = _norm(subclassForClass('fighter') ?? '');
    if (fighterSubclass == 'battle master' && fighterLevel >= 3) {
      superiorityDiceMax = fighterLevel >= 15 ? 6 : (fighterLevel >= 7 ? 5 : 4);
      superiorityDiceNotes = fighterLevel >= 18
          ? 'd12 superiority dice'
          : fighterLevel >= 10
              ? 'd10 superiority dice'
              : 'd8 superiority dice';
    }

// luego feats futuros aquí

    if (superiorityDiceMax > 0) {
      addResource(
        id: 'superiority_dice',
        name: 'Superiority Dice',
        max: superiorityDiceMax,
        rechargeType: 'shortRest',
        notes: superiorityDiceNotes,
      );
    }

    return result;
  }
}
