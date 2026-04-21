import '../../experimental/classes_v2/models/dnd_class_v2.dart';
import '../../experimental/classes_v2/models/class_level_v2.dart';
import '../../experimental/classes_v2/models/dnd_subclass_v2.dart';

class ArtificerV2Parser {
  static DndClassV2 parse(Map<String, dynamic> json) {
    final clase = json['clase'] as Map<String, dynamic>;

    // ===============================
    // DATOS BASE
    // ===============================
    final name = clase['nombre'] as String;
    final description = clase['descripcion_completa'] as String;
    final lore = clase['artificers_in_many_worlds'] as String;

    // ===============================
    // HIT POINTS
    // ===============================
    final hitPoints = clase['hit_points'] as Map<String, dynamic>;

    // ===============================
    // PROFICIENCIAS
    // ===============================
    final prof = clase['proficiencias'] as Map<String, dynamic>;

    // ===============================
    // PROGRESIÓN POR NIVEL
    // ===============================
    final progressionRaw = clase['tabla_progresion'] as List;

    final progression = progressionRaw.map((lvl) {
      final map = lvl as Map<String, dynamic>;
      return ClassLevelV2(
        level: map['nivel'],
        proficiencyBonus: map['pb'],
        cantripsKnown: map['trucos'],
        spellSlots: List<int>.from(map['slots']),
        features: List<String>.from(map['rasgos']),
        infusionsKnown: map['infusiones_conocidas'],
        infusedItems: map['objetos_infundidos'],
      );
    }).toList();

    // ===============================
    // RASGOS DE CLASE
    // ===============================
    final traitsRaw = clase['rasgos_clase'] as Map<String, dynamic>;
    final classTraits = <String, String>{};

    traitsRaw.forEach((key, value) {
      if (value is String) {
        classTraits[key] = value;
      } else if (value is Map) {
        final buffer = StringBuffer();
        value.forEach((_, v) {
          buffer.writeln(v.toString());
        });
        classTraits[key] = buffer.toString().trim();
      }
    });

    // ===============================
    // SUBCLASES / ESPECIALIDADES
    // ===============================
    final specsRaw = clase['especialidades'] as List;

    final subclasses = specsRaw.map((spec) {
      final s = spec as Map<String, dynamic>;

      return DndSubclassV2(
        name: s['nombre'],
        description: s['descripcion'],
        spellsByLevel: (s['hechizos'] as Map?)
                ?.map((k, v) => MapEntry(int.parse(k), List<String>.from(v))) ??
            {},
        features: s
          ..remove('nombre')
          ..remove('descripcion')
          ..remove('hechizos'),
      );
    }).toList();

    // ===============================
    // INFUSIONES
    // ===============================
    final infusionsRaw = clase['infusiones'] as Map<String, dynamic>;

    // ===============================
    // CONSTRUCCIÓN FINAL
    // ===============================
    return DndClassV2(
      index: name.toLowerCase(),
      name: name,
      description: description,
      lore: lore,
      hitDie: hitPoints['hit_dice'],
      hpAtFirstLevel: hitPoints['hp_nivel_1'],
      hpAtHigherLevels: hitPoints['hp_niveles_superiores'],
      armorProficiencies: List<String>.from(prof['armaduras']),
      weaponProficiencies: List<String>.from(prof['armas']),
      toolProficiencies: List<String>.from(prof['herramientas']),
      savingThrows: List<String>.from(prof['salvaciones']),
      skillChoices: List<String>.from(prof['habilidades']),
      progression: progression,
      classTraits: classTraits,
      subclasses: subclasses,
      infusionsRules: infusionsRaw['reglas'],
      infusionExamples: List<String>.from(infusionsRaw['lista_ejemplos']),
    );
  }
}
