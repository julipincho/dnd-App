import 'dart:convert';

class DndSpellcastingLevel {
  final int? cantripsKnown;
  final int? spellsKnown;

  /// Ejemplo:
  /// { "1": 4, "2": 2, "3": 0 }
  final Map<int, int> spellSlots;

  DndSpellcastingLevel({
    this.cantripsKnown,
    this.spellsKnown,
    required this.spellSlots,
  });

  factory DndSpellcastingLevel.fromJson(Map<String, dynamic> json) {
    final Map<int, int> parsedSlots = {};

    json.forEach((key, value) {
      if (key.startsWith("spell_slots_level_")) {
        final levelStr = key.replaceFirst("spell_slots_level_", "");
        final lvl = int.tryParse(levelStr);
        if (lvl != null) parsedSlots[lvl] = value ?? 0;
      }
    });

    return DndSpellcastingLevel(
      cantripsKnown: json["cantrips_known"],
      spellsKnown: json["spells_known"],
      spellSlots: parsedSlots,
    );
  }
}
