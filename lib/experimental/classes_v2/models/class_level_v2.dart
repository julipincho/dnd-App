// lib/experimental/classes_v2/models/class_level_v2.dart

class ClassLevelV2 {
  final int level;
  final int proficiencyBonus;

  // Spellcasting
  final int cantripsKnown;
  final List<int> spellSlots; // [lvl1, lvl2, lvl3, lvl4, lvl5]

  // Rasgos obtenidos en este nivel
  final List<String> features;

  // Artificer-specific
  final int infusionsKnown;
  final int infusedItems;

  ClassLevelV2({
    required this.level,
    required this.proficiencyBonus,
    required this.cantripsKnown,
    required this.spellSlots,
    required this.features,
    required this.infusionsKnown,
    required this.infusedItems,
  });
}
