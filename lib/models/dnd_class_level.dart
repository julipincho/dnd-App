class DndClassLevel {
  final int level;
  final int profBonus;
  final List<String> features;
  final SpellcastingData? spellcasting;

  /// ⭐ NUEVO: progresión opcional (ej: Infusions para Artificer)
  final Map<String, List<int>> optionalProgression;

  DndClassLevel({
    required this.level,
    required this.profBonus,
    required this.features,
    required this.spellcasting,
    required this.optionalProgression,
  });

  factory DndClassLevel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json["features"] as List? ?? [];

    final features = rawFeatures
        .whereType<Map>()
        .map((f) => f["name"]?.toString() ?? "Unknown Feature")
        .toList();

    // ⭐ Leer optionalfeatureProgression si existe
    final Map<String, List<int>> opt = {};

    if (json["optionalfeatureProgression"] is List) {
      for (final item in json["optionalfeatureProgression"]) {
        final name = item["name"]?.toString() ?? "Unknown";

        if (item["progression"] is List) {
          opt[name] = (item["progression"] as List)
              .map((e) => (e as num).toInt())
              .toList();
        }
      }
    }

    return DndClassLevel(
      level: (json["level"] as num?)?.toInt() ?? 1,
      profBonus: (json["prof_bonus"] as num?)?.toInt() ?? 2,
      features: features,
      spellcasting: json["spellcasting"] is Map
          ? SpellcastingData.fromJson(json["spellcasting"])
          : null,

      /// ⭐ NUEVO
      optionalProgression: opt,
    );
  }
}

class SpellcastingData {
  final int cantripsKnown;
  final int spellsKnown;
  final List<int> spellSlots;

  SpellcastingData({
    required this.cantripsKnown,
    required this.spellsKnown,
    required this.spellSlots,
  });

  bool get hasSlots => spellSlots.any((s) => s > 0);

  factory SpellcastingData.fromJson(Map<String, dynamic> json) {
    int _int(dynamic v) => (v is num) ? v.toInt() : 0;

    return SpellcastingData(
      cantripsKnown: _int(json["cantrips_known"]),
      spellsKnown: _int(json["spells_known"]),
      spellSlots: List<int>.generate(
        9,
        (i) => _int(json["spell_slots_level_${i + 1}"]),
      ),
    );
  }
}
