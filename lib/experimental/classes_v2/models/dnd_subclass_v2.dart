// lib/experimental/classes_v2/models/dnd_subclass_v2.dart

class DndSubclassV2 {
  final String name;
  final String description;

  /// Hechizos otorgados por nivel de clase
  /// Ej: {3: ['healing word'], 5: ['flaming sphere']}
  final Map<int, List<String>> spellsByLevel;

  /// Rasgos específicos de la subclase (estructura libre)
  /// Ej: experimental_elixir, modelos_armadura, steel_defender, etc.
  final Map<String, dynamic> features;

  DndSubclassV2({
    required this.name,
    required this.description,
    required this.spellsByLevel,
    required this.features,
  });
}
