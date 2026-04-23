class DndSubrace {
  final String id;
  final String name;
  final String source;

  final int? speed; //

  final List<Map<String, dynamic>> abilityBonuses;
  final List<Map<String, String>> traits;

  final String description;

  DndSubrace({
    required this.id,
    required this.name,
    required this.source,
    this.speed, //
    required this.abilityBonuses,
    required this.traits,
    required this.description,
  });

  factory DndSubrace.fromJson(Map<String, dynamic> json) {
    return DndSubrace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),

      speed: json['speed'] is int
          ? json['speed']
          : int.tryParse(json['speed']?.toString() ?? ''), // 👈 robusto

      abilityBonuses: (json['abilityBonuses'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),

      traits: (json['traits'] as List? ?? [])
          .map((e) => {
                'name': (e['name'] ?? '').toString(),
                'description': (e['description'] ?? '').toString(),
              })
          .toList(),

      description: (json['description'] ?? '').toString(),
    );
  }
}
