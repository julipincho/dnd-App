class DndSubrace {
  final String name;
  final List<Map<String, dynamic>> abilityBonuses;
  final List<String> traits;
  final String description;

  DndSubrace({
    required this.name,
    required this.abilityBonuses,
    required this.traits,
    required this.description,
  });
}
