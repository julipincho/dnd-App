import 'character_class_level.dart';

class CharacterProgression {
  final List<CharacterClassLevel> levels;

  const CharacterProgression({
    required this.levels,
  });

  factory CharacterProgression.fromJson(Map<String, dynamic> json) {
    final levels = (json['levels'] as List?)
            ?.whereType<Map>()
            .map(
              (entry) => CharacterClassLevel.fromJson(
                Map<String, dynamic>.from(entry),
              ),
            )
            .toList() ??
        [];

    return CharacterProgression(levels: levels);
  }

  factory CharacterProgression.legacy({
    required String className,
    required int totalLevel,
    String? subclassName,
  }) {
    final safeLevel = totalLevel < 1 ? 1 : totalLevel;
    final trimmedClassName = className.trim();
    if (trimmedClassName.isEmpty) {
      return const CharacterProgression(levels: []);
    }

    return CharacterProgression(
      levels: [
        for (var level = 1; level <= safeLevel; level++)
          CharacterClassLevel(
            className: trimmedClassName,
            subclassName: subclassName,
            level: level,
            chosenAtCharacterLevel: level,
          ),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'levels': levels.map((level) => level.toJson()).toList(),
    };
  }

  int get totalLevel => levels.length;

  bool get isEmpty => levels.isEmpty;

  Map<String, int> get levelsByClass {
    final result = <String, int>{};
    for (final entry in levels) {
      final className = entry.className.trim();
      if (className.isEmpty) continue;
      final current = result[className] ?? 0;
      if (entry.level > current) {
        result[className] = entry.level;
      }
    }
    return result;
  }

  int levelForClass(String className) {
    final target = _norm(className);
    var result = 0;
    for (final entry in levels) {
      if (_norm(entry.className) == target && entry.level > result) {
        result = entry.level;
      }
    }
    return result;
  }

  String? subclassForClass(String className) {
    final target = _norm(className);
    for (final entry in levels.reversed) {
      if (_norm(entry.className) != target) continue;
      final subclassName = entry.subclassName?.trim();
      if (subclassName != null && subclassName.isNotEmpty) {
        return subclassName;
      }
    }
    return null;
  }

  CharacterProgression withPrimaryClassLevel({
    required String className,
    required int totalLevel,
    String? subclassName,
  }) {
    return CharacterProgression.legacy(
      className: className,
      totalLevel: totalLevel,
      subclassName: subclassName,
    );
  }

  CharacterProgression withSubclassForClass({
    required String className,
    required String subclassName,
  }) {
    final target = _norm(className);
    return CharacterProgression(
      levels: [
        for (final entry in levels)
          _norm(entry.className) == target
              ? entry.copyWith(subclassName: subclassName)
              : entry,
      ],
    );
  }

  CharacterProgression addClassLevel({
    required String className,
    String? subclassName,
    int? hitDie,
    Map<String, dynamic> choices = const {},
  }) {
    final nextClassLevel = levelForClass(className) + 1;
    return CharacterProgression(
      levels: [
        ...levels,
        CharacterClassLevel(
          className: className,
          subclassName: subclassName,
          level: nextClassLevel,
          chosenAtCharacterLevel: totalLevel + 1,
          hitDie: hitDie,
          choices: choices,
        ),
      ],
    );
  }

  static String _norm(String value) => value.trim().toLowerCase();
}
