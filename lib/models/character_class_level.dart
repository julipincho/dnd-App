class CharacterClassLevel {
  final String className;
  final String? subclassName;
  final int level;
  final int chosenAtCharacterLevel;
  final int? hitDie;
  final Map<String, dynamic> choices;

  const CharacterClassLevel({
    required this.className,
    required this.level,
    required this.chosenAtCharacterLevel,
    this.subclassName,
    this.hitDie,
    this.choices = const {},
  });

  factory CharacterClassLevel.fromJson(Map<String, dynamic> json) {
    return CharacterClassLevel(
      className: json['className']?.toString() ?? '',
      subclassName: json['subclassName']?.toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      chosenAtCharacterLevel:
          (json['chosenAtCharacterLevel'] as num?)?.toInt() ?? 1,
      hitDie: (json['hitDie'] as num?)?.toInt(),
      choices: (json['choices'] as Map?)
              ?.map((key, value) => MapEntry(key.toString(), value)) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'className': className,
      'subclassName': subclassName,
      'level': level,
      'chosenAtCharacterLevel': chosenAtCharacterLevel,
      'hitDie': hitDie,
      'choices': choices,
    };
  }

  CharacterClassLevel copyWith({
    String? className,
    String? subclassName,
    int? level,
    int? chosenAtCharacterLevel,
    int? hitDie,
    Map<String, dynamic>? choices,
  }) {
    return CharacterClassLevel(
      className: className ?? this.className,
      subclassName: subclassName ?? this.subclassName,
      level: level ?? this.level,
      chosenAtCharacterLevel:
          chosenAtCharacterLevel ?? this.chosenAtCharacterLevel,
      hitDie: hitDie ?? this.hitDie,
      choices: choices ?? this.choices,
    );
  }
}
