import '../models/character.dart';

class MulticlassSpellcastingResult {
  final int sharedCasterLevel;
  final int pactMagicLevel;
  final Map<int, int> sharedSlots;
  final Map<int, int> pactMagicSlots;

  const MulticlassSpellcastingResult({
    required this.sharedCasterLevel,
    required this.pactMagicLevel,
    required this.sharedSlots,
    required this.pactMagicSlots,
  });

  bool get hasSharedSlots => sharedSlots.values.any((slots) => slots > 0);
  bool get hasPactMagicSlots => pactMagicSlots.values.any((slots) => slots > 0);

  bool get hasAnySlots => hasSharedSlots || hasPactMagicSlots;
}

class MulticlassSpellcastingService {
  static MulticlassSpellcastingResult calculate(Character character) {
    final levelsByClass = character.classLevels;
    var fullCasterLevels = 0;
    var halfCasterLevels = 0;
    var artificerLevels = 0;
    var thirdCasterLevels = 0;
    var pactMagicLevel = 0;

    for (final entry in levelsByClass.entries) {
      final className = _norm(entry.key);
      final level = entry.value.clamp(0, 20);

      if (_isFullCaster(className)) {
        fullCasterLevels += level;
      } else if (_isArtificer(className)) {
        artificerLevels += level;
      } else if (_isHalfCaster(className)) {
        halfCasterLevels += level;
      } else if (_isWarlock(className)) {
        pactMagicLevel += level;
      } else if (_isThirdCaster(character, className)) {
        thirdCasterLevels += level;
      }
    }

    final sharedCasterLevel = fullCasterLevels +
        (halfCasterLevels / 2).floor() +
        (artificerLevels / 2).ceil() +
        (thirdCasterLevels / 3).floor();

    return MulticlassSpellcastingResult(
      sharedCasterLevel: sharedCasterLevel,
      pactMagicLevel: pactMagicLevel,
      sharedSlots: _fullCasterSlotsForLevel(sharedCasterLevel),
      pactMagicSlots: _warlockSlotsForLevel(pactMagicLevel),
    );
  }

  static bool hasAutoSlots(Character character) {
    return calculate(character).hasAnySlots;
  }

  static Map<int, int> sharedSlots(Character character) {
    return calculate(character).sharedSlots;
  }

  static Map<int, int> pactMagicSlots(Character character) {
    return calculate(character).pactMagicSlots;
  }

  static Map<int, int> storageSlots(Character character) {
    final result = calculate(character);
    if (result.hasSharedSlots) return result.sharedSlots;
    return result.pactMagicSlots;
  }

  static Map<String, int> buildAutoSpellSlotState({
    required Character character,
    bool preserveUsed = true,
  }) {
    final result = calculate(character);
    final autoSlots =
        result.hasSharedSlots ? result.sharedSlots : result.pactMagicSlots;
    final currentNormalized = normalizeSpellSlots(character.spellSlots);
    return _buildSlotState(
      autoSlots: autoSlots,
      currentNormalized: currentNormalized,
      preserveUsed: preserveUsed,
    );
  }

  static Map<String, int> buildSharedSpellSlotState({
    required Character character,
    bool preserveUsed = true,
  }) {
    final currentNormalized = normalizeSpellSlots(character.spellSlots);
    return _buildSlotState(
      autoSlots: calculate(character).sharedSlots,
      currentNormalized: currentNormalized,
      preserveUsed: preserveUsed,
    );
  }

  static Map<String, int> buildPactMagicSlotState({
    required Character character,
    bool preserveUsed = true,
  }) {
    final currentNormalized = normalizeSpellSlots(character.pactMagicSlots);
    return _buildSlotState(
      autoSlots: calculate(character).pactMagicSlots,
      currentNormalized: currentNormalized,
      preserveUsed: preserveUsed,
    );
  }

  static Map<String, int> _buildSlotState({
    required Map<int, int> autoSlots,
    required Map<String, int> currentNormalized,
    required bool preserveUsed,
  }) {
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

  static Map<String, int> normalizeSpellSlots(Map<String, int> slots) {
    final result = <String, int>{};

    for (var level = 1; level <= 9; level++) {
      final maxKey = '${level}_max';
      final usedKey = '${level}_used';
      final legacyKey = '$level';

      int max = 0;
      int used = 0;

      if (slots.containsKey(maxKey)) {
        max = slots[maxKey] ?? 0;
      } else if (slots.containsKey(legacyKey)) {
        max = slots[legacyKey] ?? 0;
      }

      if (slots.containsKey(usedKey)) {
        used = slots[usedKey] ?? 0;
      }

      used = used.clamp(0, max);

      if (max > 0) {
        result[maxKey] = max;
        result[usedKey] = used;
      }
    }

    return result;
  }

  static bool _isFullCaster(String className) {
    return const {
      'bard',
      'cleric',
      'druid',
      'sorcerer',
      'wizard',
    }.contains(className);
  }

  static bool _isHalfCaster(String className) {
    return const {
      'paladin',
      'ranger',
    }.contains(className);
  }

  static bool _isArtificer(String className) => className == 'artificer';

  static bool _isWarlock(String className) => className == 'warlock';

  static bool _isThirdCaster(Character character, String className) {
    final subclass = character.subclassForClass(className)?.toLowerCase() ?? '';
    return (className == 'fighter' && subclass.contains('eldritch knight')) ||
        (className == 'rogue' && subclass.contains('arcane trickster'));
  }

  static String _norm(String value) => value.trim().toLowerCase();

  static Map<int, int> _fullCasterSlotsForLevel(int level) {
    if (level <= 0) return {};
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

  static Map<int, int> _warlockSlotsForLevel(int level) {
    if (level <= 0) return {};
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
}
