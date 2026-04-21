import 'class_level_v2.dart';
import 'dnd_subclass_v2.dart';

class DndClassV2 {
  // ===============================
  // IDENTIDAD
  // ===============================
  final String index;
  final String name;

  // ===============================
  // DESCRIPCIÓN / LORE
  // ===============================
  final String description;
  final String lore;

  // ===============================
  // HIT POINTS
  // ===============================
  final String hitDie;
  final String hpAtFirstLevel;
  final String hpAtHigherLevels;

  // ===============================
  // PROFICIENCIAS
  // ===============================
  final List<String> armorProficiencies;
  final List<String> weaponProficiencies;
  final List<String> toolProficiencies;
  final List<String> savingThrows;
  final List<String> skillChoices;

  // ===============================
  // PROGRESIÓN POR NIVEL
  // ===============================
  final List<ClassLevelV2> progression;

  // ===============================
  // RASGOS DE CLASE
  // ===============================
  final Map<String, String> classTraits;

  // ===============================
  // SUBCLASES / ESPECIALIDADES
  // ===============================
  final List<DndSubclassV2> subclasses;

  // ===============================
  // INFUSIONES
  // ===============================
  final String infusionsRules;
  final List<String> infusionExamples;

  DndClassV2({
    required this.index,
    required this.name,
    required this.description,
    required this.lore,
    required this.hitDie,
    required this.hpAtFirstLevel,
    required this.hpAtHigherLevels,
    required this.armorProficiencies,
    required this.weaponProficiencies,
    required this.toolProficiencies,
    required this.savingThrows,
    required this.skillChoices,
    required this.progression,
    required this.classTraits,
    required this.subclasses,
    required this.infusionsRules,
    required this.infusionExamples,
  });
}
