import '../models/character.dart';
import 'multiclass_spellcasting_service.dart';

class CharacterSpellSlotService {
  static final RegExp _legacySlotKeyPattern = RegExp(r'^\d+$');
  static final RegExp _slotMaxKeyPattern = RegExp(r'^\d+_max$');
  static final RegExp _slotUsedKeyPattern = RegExp(r'^\d+_used$');

  static int slotMaxForLevel(Character character, int level) {
    return _slotMaxForLevel(character.spellSlots, level);
  }

  static int pactMagicSlotMaxForLevel(Character character, int level) {
    return _slotMaxForLevel(character.pactMagicSlots, level);
  }

  static int _slotMaxForLevel(Map<String, int> slots, int level) {
    final maxKey = '${level}_max';
    final legacyKey = '$level';

    if (slots.containsKey(maxKey)) {
      return slots[maxKey] ?? 0;
    }

    return slots[legacyKey] ?? 0;
  }

  static int slotUsedForLevel(Character character, int level) {
    return _slotUsedForLevel(character.spellSlots, level);
  }

  static int pactMagicSlotUsedForLevel(Character character, int level) {
    return _slotUsedForLevel(character.pactMagicSlots, level);
  }

  static int _slotUsedForLevel(Map<String, int> slots, int level) {
    return slots['${level}_used'] ?? 0;
  }

  static int slotRemainingForLevel(Character character, int level) {
    final max = slotMaxForLevel(character, level);
    final used = slotUsedForLevel(character, level);
    final remaining = max - used;
    return remaining < 0 ? 0 : remaining;
  }

  static bool hasAnySpellSlots(Character character) {
    return _hasAnySlots(character.spellSlots);
  }

  static bool hasAnyPactMagicSlots(Character character) {
    return _hasAnySlots(character.pactMagicSlots);
  }

  static bool _hasAnySlots(Map<String, int> slots) {
    for (var level = 1; level <= 9; level++) {
      if (_slotMaxForLevel(slots, level) > 0) return true;
    }
    return false;
  }

  static void spendSlot(Character character, int level) {
    _spendSlot(character.spellSlots, level);
  }

  static void spendPactMagicSlot(Character character, int level) {
    _spendSlot(character.pactMagicSlots, level);
  }

  static void _spendSlot(Map<String, int> slots, int level) {
    final max = _slotMaxForLevel(slots, level);
    final currentUsed = _slotUsedForLevel(slots, level);

    if (max <= 0) return;
    if (currentUsed >= max) return;

    slots['${level}_max'] = max;
    slots['${level}_used'] = currentUsed + 1;
    slots.remove('$level');
  }

  static void recoverSlot(Character character, int level) {
    _recoverSlot(character.spellSlots, level);
  }

  static void recoverPactMagicSlot(Character character, int level) {
    _recoverSlot(character.pactMagicSlots, level);
  }

  static void _recoverSlot(Map<String, int> slots, int level) {
    final max = _slotMaxForLevel(slots, level);
    final currentUsed = _slotUsedForLevel(slots, level);

    if (max <= 0) return;

    final newUsed = currentUsed - 1;
    slots['${level}_max'] = max;
    slots['${level}_used'] = newUsed < 0 ? 0 : newUsed;
    slots.remove('$level');
  }

  static void recoverAllSlots(Character character) {
    _recoverAllSlots(character.spellSlots);
  }

  static void recoverAllPactMagicSlots(Character character) {
    _recoverAllSlots(character.pactMagicSlots);
  }

  static void _recoverAllSlots(Map<String, int> slots) {
    for (var level = 1; level <= 9; level++) {
      final max = _slotMaxForLevel(slots, level);
      if (max > 0) {
        slots['${level}_max'] = max;
        slots['${level}_used'] = 0;
      }

      slots.remove('$level');
    }
  }

  static void applyManualSlotState(
    Character character, {
    required Map<int, int> maxByLevel,
    required Map<int, int> usedByLevel,
  }) {
    _clearSlotState(character.spellSlots);

    for (var level = 1; level <= 9; level++) {
      final max = maxByLevel[level] ?? 0;
      final rawUsed = usedByLevel[level] ?? 0;
      final safeUsed = rawUsed.clamp(0, max);

      if (max > 0) {
        character.spellSlots['${level}_max'] = max;
        character.spellSlots['${level}_used'] = safeUsed;
      }
    }
  }

  static void applyAutoSlotState(
    Character character, {
    bool preserveUsed = true,
  }) {
    final sharedState = MulticlassSpellcastingService.buildSharedSpellSlotState(
      character: character,
      preserveUsed: preserveUsed,
    );
    final pactState = MulticlassSpellcastingService.buildPactMagicSlotState(
      character: character,
      preserveUsed: preserveUsed,
    );

    _clearSlotState(character.spellSlots);
    character.spellSlots.addAll(sharedState);

    _clearSlotState(character.pactMagicSlots);
    character.pactMagicSlots.addAll(pactState);
  }

  static void _clearSlotState(Map<String, int> slots) {
    final keysToRemove = slots.keys
        .where(
          (key) =>
              _legacySlotKeyPattern.hasMatch(key) ||
              _slotMaxKeyPattern.hasMatch(key) ||
              _slotUsedKeyPattern.hasMatch(key),
        )
        .toList();

    for (final key in keysToRemove) {
      slots.remove(key);
    }
  }
}
