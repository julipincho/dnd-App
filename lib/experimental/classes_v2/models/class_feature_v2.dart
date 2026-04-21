class ClassFeatureV2 {
  final String name;
  final String description;

  /// Metadata útil para UI / lógica
  final bool isOptional;
  final bool isChoice;
  final int? choices;

  ClassFeatureV2({
    required this.name,
    required this.description,
    this.isOptional = false,
    this.isChoice = false,
    this.choices,
  });
}
