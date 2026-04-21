import '../models/character.dart';
import '../models/spell.dart';

enum SpellcastingProgression {
  none,
  fullCaster,
  halfCaster,
  warlock,
}

class SpellcastingRules {
  static SpellcastingProgression getProgression(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'bard':
      case 'cleric':
      case 'druid':
      case 'sorcerer':
      case 'wizard':
        return SpellcastingProgression.fullCaster;

      case 'paladin':
      case 'ranger':
      case 'artificer':
        return SpellcastingProgression.halfCaster;

      case 'warlock':
        return SpellcastingProgression.warlock;

      default:
        return SpellcastingProgression.none;
    }
  }

  static bool usesKnownSpells(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'bard':
      case 'sorcerer':
      case 'warlock':
      case 'ranger':
        return true;
      default:
        return false;
    }
  }

  static bool usesKnownCantrips(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'bard':
      case 'sorcerer':
      case 'warlock':
        return true;
      case 'ranger':
        return false;
      default:
        return false;
    }
  }

  static int knownCantrips(Character char) {
    final level = char.level.clamp(1, 20);
    final className = char.charClass.toLowerCase().trim();

    switch (className) {
      case 'bard':
        if (level >= 10) return 4;
        return 2;

      case 'sorcerer':
        if (level >= 10) return 5;
        if (level >= 4) return 4;
        return 4;

      case 'warlock':
        if (level >= 10) return 4;
        if (level >= 4) return 3;
        return 2;

      default:
        return 0;
    }
  }

  static int knownSpells(Character char) {
    final level = char.level.clamp(1, 20);
    final className = char.charClass.toLowerCase().trim();

    switch (className) {
      case 'bard':
        const table = {
          1: 4,
          2: 5,
          3: 6,
          4: 7,
          5: 8,
          6: 9,
          7: 10,
          8: 11,
          9: 12,
          10: 14,
          11: 15,
          12: 15,
          13: 16,
          14: 18,
          15: 19,
          16: 19,
          17: 20,
          18: 22,
          19: 22,
          20: 22,
        };
        return table[level] ?? 0;

      case 'sorcerer':
        const table = {
          1: 2,
          2: 3,
          3: 4,
          4: 5,
          5: 6,
          6: 7,
          7: 8,
          8: 9,
          9: 10,
          10: 11,
          11: 12,
          12: 12,
          13: 13,
          14: 13,
          15: 14,
          16: 14,
          17: 15,
          18: 15,
          19: 15,
          20: 15,
        };
        return table[level] ?? 0;

      case 'warlock':
        const table = {
          1: 2,
          2: 3,
          3: 4,
          4: 5,
          5: 6,
          6: 7,
          7: 8,
          8: 9,
          9: 10,
          10: 10,
          11: 11,
          12: 11,
          13: 12,
          14: 12,
          15: 13,
          16: 13,
          17: 14,
          18: 14,
          19: 15,
          20: 15,
        };
        return table[level] ?? 0;

      case 'ranger':
        const table = {
          1: 0,
          2: 2,
          3: 3,
          4: 3,
          5: 4,
          6: 4,
          7: 5,
          8: 5,
          9: 6,
          10: 6,
          11: 7,
          12: 7,
          13: 8,
          14: 8,
          15: 9,
          16: 9,
          17: 10,
          18: 10,
          19: 11,
          20: 11,
        };
        return table[level] ?? 0;

      default:
        return 0;
    }
  }

  static int knownNonCantripSpellsSelected(Character char, List<Spell> spells) {
    return spells.where((spell) => spell.level > 0).length;
  }

  static int knownCantripsSelected(Character char, List<Spell> spells) {
    return spells.where((spell) => spell.level == 0).length;
  }

  static bool isAutoSlotClass(Character char) {
    final progression = getProgression(char);
    return progression == SpellcastingProgression.fullCaster ||
        progression == SpellcastingProgression.halfCaster ||
        progression == SpellcastingProgression.warlock;
  }

  static bool usesPreparedSpellLimit(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'wizard':
      case 'cleric':
      case 'druid':
      case 'paladin':
      case 'artificer':
        return true;
      default:
        return false;
    }
  }

  static String? preparedSpellLimitLabel(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'wizard':
        return 'Level + INT modifier';
      case 'cleric':
      case 'druid':
        return 'Level + WIS modifier';
      case 'paladin':
        return 'Half level + CHA modifier';
      case 'artificer':
        return 'Half level + INT modifier';
      default:
        return null;
    }
  }

  static String? preparedSpellcastingAbility(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'wizard':
      case 'artificer':
        return 'INT';

      case 'cleric':
      case 'druid':
        return 'WIS';

      case 'paladin':
        return 'CHA';

      default:
        return null;
    }
  }

  static int preparedSpellLimit(
    Character char,
    int Function(String ability) getAbilityScore,
    int Function(int score) getAbilityModifier,
  ) {
    final className = char.charClass.toLowerCase().trim();

    String? ability;
    int baseCount = 0;

    switch (className) {
      case 'wizard':
        ability = 'INT';
        baseCount = char.level;
        break;

      case 'cleric':
      case 'druid':
        ability = 'WIS';
        baseCount = char.level;
        break;

      case 'paladin':
        ability = 'CHA';
        baseCount = (char.level / 2).floor();
        break;

      case 'artificer':
        ability = 'INT';
        baseCount = (char.level / 2).floor();
        break;

      default:
        return 0;
    }

    final score = getAbilityScore(ability);
    final modifier = getAbilityModifier(score);
    final total = baseCount + modifier;

    return total < 1 ? 1 : total;
  }

  static int getEffectiveCasterLevel(Character char) {
    final progression = getProgression(char);

    switch (progression) {
      case SpellcastingProgression.fullCaster:
        return char.level;

      case SpellcastingProgression.halfCaster:
        return (char.level / 2).ceil();

      case SpellcastingProgression.warlock:
        return char.level;

      case SpellcastingProgression.none:
        return 0;
    }
  }

  static Map<int, int> getAutoSpellSlots(Character char) {
    final progression = getProgression(char);

    switch (progression) {
      case SpellcastingProgression.fullCaster:
        return _fullCasterSlotsForLevel(char.level);

      case SpellcastingProgression.halfCaster:
        return _halfCasterSlotsForLevel(char.level);

      case SpellcastingProgression.warlock:
        return _warlockSlotsForLevel(char.level);

      case SpellcastingProgression.none:
        return {};
    }
  }

  static Map<String, int> normalizeSpellSlots(Character char) {
    final result = <String, int>{};

    for (var level = 1; level <= 9; level++) {
      final maxKey = '${level}_max';
      final usedKey = '${level}_used';
      final legacyKey = '$level';

      int max = 0;
      int used = 0;

      if (char.spellSlots.containsKey(maxKey)) {
        max = char.spellSlots[maxKey] ?? 0;
      } else if (char.spellSlots.containsKey(legacyKey)) {
        max = char.spellSlots[legacyKey] ?? 0;
      }

      if (char.spellSlots.containsKey(usedKey)) {
        used = char.spellSlots[usedKey] ?? 0;
      }

      used = used.clamp(0, max);

      if (max > 0) {
        result[maxKey] = max;
        result[usedKey] = used;
      }
    }

    return result;
  }

  static Map<String, int> buildAutoSpellSlotState({
    required Character char,
    bool preserveUsed = true,
  }) {
    final autoSlots = getAutoSpellSlots(char);
    final currentNormalized = normalizeSpellSlots(char);

    final result = <String, int>{};

    for (var level = 1; level <= 9; level++) {
      final max = autoSlots[level] ?? 0;
      if (max <= 0) continue;

      final currentUsed = preserveUsed
          ? (currentNormalized['${level}_used'] ?? 0).clamp(0, max)
          : 0;

      result['${level}_max'] = max;
      result['${level}_used'] = currentUsed;
    }

    return result;
  }

  static Map<int, int> _fullCasterSlotsForLevel(int level) {
    const table = <int, Map<int, int>>{
      1: {1: 2},
      2: {1: 3},
      3: {1: 4, 2: 2},
      4: {1: 4, 2: 3},
      5: {1: 4, 2: 3, 3: 2},
      6: {1: 4, 2: 3, 3: 3},
      7: {1: 4, 2: 3, 3: 3, 4: 1},
      8: {1: 4, 2: 3, 3: 3, 4: 2},
      9: {1: 4, 2: 3, 3: 3, 4: 3, 5: 1},
      10: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2},
      11: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1},
      12: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1},
      13: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1},
      14: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1},
      15: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1, 8: 1},
      16: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1, 8: 1},
      17: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1, 8: 1, 9: 1},
      18: {1: 4, 2: 3, 3: 3, 4: 3, 5: 3, 6: 1, 7: 1, 8: 1, 9: 1},
      19: {1: 4, 2: 3, 3: 3, 4: 3, 5: 3, 6: 2, 7: 1, 8: 1, 9: 1},
      20: {1: 4, 2: 3, 3: 3, 4: 3, 5: 3, 6: 2, 7: 2, 8: 1, 9: 1},
    };

    return Map<int, int>.from(table[level.clamp(1, 20)] ?? {});
  }

  static Map<int, int> _halfCasterSlotsForLevel(int level) {
    const table = <int, Map<int, int>>{
      1: {},
      2: {1: 2},
      3: {1: 3},
      4: {1: 3},
      5: {1: 4, 2: 2},
      6: {1: 4, 2: 2},
      7: {1: 4, 2: 3},
      8: {1: 4, 2: 3},
      9: {1: 4, 2: 3, 3: 2},
      10: {1: 4, 2: 3, 3: 2},
      11: {1: 4, 2: 3, 3: 3},
      12: {1: 4, 2: 3, 3: 3},
      13: {1: 4, 2: 3, 3: 3, 4: 1},
      14: {1: 4, 2: 3, 3: 3, 4: 1},
      15: {1: 4, 2: 3, 3: 3, 4: 2},
      16: {1: 4, 2: 3, 3: 3, 4: 2},
      17: {1: 4, 2: 3, 3: 3, 4: 3, 5: 1},
      18: {1: 4, 2: 3, 3: 3, 4: 3, 5: 1},
      19: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2},
      20: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2},
    };

    return Map<int, int>.from(table[level.clamp(1, 20)] ?? {});
  }

  static Map<int, int> _warlockSlotsForLevel(int level) {
    const table = <int, Map<int, int>>{
      1: {1: 1},
      2: {1: 2},
      3: {2: 2},
      4: {2: 2},
      5: {3: 2},
      6: {3: 2},
      7: {4: 2},
      8: {4: 2},
      9: {5: 2},
      10: {5: 2},
      11: {5: 3},
      12: {5: 3},
      13: {5: 3},
      14: {5: 3},
      15: {5: 3},
      16: {5: 3},
      17: {5: 4},
      18: {5: 4},
      19: {5: 4},
      20: {5: 4},
    };

    return Map<int, int>.from(table[level.clamp(1, 20)] ?? {});
  }

  static bool canReplaceKnownSpellOnLevelUp(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'bard':
      case 'sorcerer':
      case 'warlock':
      case 'ranger':
        return true;
      default:
        return false;
    }
  }

  static bool usesPreparedSpells(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'wizard':
      case 'cleric':
      case 'druid':
      case 'paladin':
      case 'artificer':
        return true;
      default:
        return false;
    }
  }

  static String normalizedClassName(Character char) {
    return char.charClass.toLowerCase().trim();
  }

  static bool spellMatchesCharacterClass(
    Character char,
    Spell spell, {
    bool includeClassVariants = false,
  }) {
    final className = normalizedClassName(char);

    final baseMatch =
        spell.classes.map((e) => e.toLowerCase().trim()).contains(className);

    if (baseMatch) return true;

    if (includeClassVariants) {
      final variantMatch = spell.classVariants
          .map((e) => e.toLowerCase().trim())
          .contains(className);

      if (variantMatch) return true;
    }

    return false;
  }

  static int maxSpellLevelAvailable(Character char) {
    final slots = getAutoSpellSlots(char);
    if (slots.isEmpty) return 0;

    final availableLevels = slots.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();

    if (availableLevels.isEmpty) return 0;
    availableLevels.sort();
    return availableLevels.last;
  }

  static List<Spell> spellsForCharacterClass(
    Character char,
    List<Spell> spells, {
    bool includeClassVariants = false,
  }) {
    return spells.where((spell) {
      return spellMatchesCharacterClass(
        char,
        spell,
        includeClassVariants: includeClassVariants,
      );
    }).toList();
  }

  static List<Spell> spellsForCharacterClassAndLevel(
    Character char,
    List<Spell> spells, {
    bool includeClassVariants = false,
  }) {
    final maxLevel = maxSpellLevelAvailable(char);

    return spells.where((spell) {
      final matchesClass = spellMatchesCharacterClass(
        char,
        spell,
        includeClassVariants: includeClassVariants,
      );

      if (!matchesClass) return false;

      if (spell.level == 0) return true;

      if (_canClassLearnSpellsWithoutSlotsAtThisLevel(char)) {
        final knownLimit = knownSpells(char);
        if (knownLimit <= 0) return false;

        return spell.level <= _maxKnownSpellLevelForClass(char);
      }

      return spell.level <= maxLevel;
    }).toList();
  }

  static bool _canClassLearnSpellsWithoutSlotsAtThisLevel(Character char) {
    switch (char.charClass.toLowerCase().trim()) {
      case 'bard':
      case 'sorcerer':
      case 'warlock':
      case 'ranger':
        return true;
      default:
        return false;
    }
  }

  static int _maxKnownSpellLevelForClass(Character char) {
    final level = char.level.clamp(1, 20);
    switch (char.charClass.toLowerCase().trim()) {
      case 'bard':
      case 'sorcerer':
        if (level >= 17) return 9;
        if (level >= 15) return 8;
        if (level >= 13) return 7;
        if (level >= 11) return 6;
        if (level >= 9) return 5;
        if (level >= 7) return 4;
        if (level >= 5) return 3;
        if (level >= 3) return 2;
        return 1;

      case 'warlock':
        if (level >= 17) return 9;
        if (level >= 13) return 7;
        if (level >= 11) return 6;
        if (level >= 9) return 5;
        if (level >= 7) return 4;
        if (level >= 5) return 3;
        if (level >= 3) return 2;
        return 1;

      case 'ranger':
        if (level >= 17) return 5;
        if (level >= 13) return 4;
        if (level >= 9) return 3;
        if (level >= 5) return 2;
        if (level >= 2) return 1;
        return 0;

      default:
        return 0;
    }
  }
}
