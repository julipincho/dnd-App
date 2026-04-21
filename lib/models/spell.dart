class Spell {
  final String id;
  final String name;
  final int level;
  final String school;
  final String castingTime;
  final String range;
  final List<String> components;
  final String duration;
  final String description;
  final List<String> classes;
  final List<String> classVariants;
  final List<String> subclasses;
  final String source;

  Spell({
    required this.id,
    required this.name,
    required this.level,
    required this.school,
    required this.castingTime,
    required this.range,
    required this.components,
    required this.duration,
    required this.description,
    required this.classes,
    required this.classVariants,
    required this.subclasses,
    required this.source,
  });

  factory Spell.fromJson(Map<String, dynamic> json) {
    return Spell(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      level: json['level'] ?? 0,
      school: json['school'] ?? '',
      castingTime: json['castingTime'] ?? '',
      range: json['range'] ?? '',
      components: List<String>.from(json['components'] ?? []),
      duration: json['duration'] ?? '',
      description: json['description'] ?? '',
      classes: List<String>.from(json['classes'] ?? []),
      classVariants: List<String>.from(json['classVariants'] ?? []),
      subclasses: List<String>.from(json['subclasses'] ?? []),
      source: json['source'] ?? '',
    );
  }
}
