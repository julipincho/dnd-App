import '../models/character.dart';
import 'multiclass_rules_service.dart';

class CharacterLevelUpDecision {
  final String className;
  final int hpGain;
  final String? subclassName;
  final int? hitDie;
  final List<String> skillProficiencies;

  const CharacterLevelUpDecision({
    required this.className,
    required this.hpGain,
    this.subclassName,
    this.hitDie,
    this.skillProficiencies = const [],
  });
}

class CharacterLevelUpResult {
  final int previousTotalLevel;
  final int newTotalLevel;
  final int newClassLevel;
  final List<String> notes;

  const CharacterLevelUpResult({
    required this.previousTotalLevel,
    required this.newTotalLevel,
    required this.newClassLevel,
    required this.notes,
  });
}

class CharacterLevelUpService {
  static CharacterLevelUpResult applyLevelUp({
    required Character character,
    required CharacterLevelUpDecision decision,
  }) {
    final previousTotalLevel = character.level;
    final isNewClass = character.levelForClass(decision.className) == 0;

    if (isNewClass) {
      final validation = MulticlassRulesService.validateEntry(
        character: character,
        targetClassName: decision.className,
      );
      if (!validation.canMulticlass) {
        throw StateError(
          'Multiclass requirements not met: '
          '${validation.unmetRequirements.join(', ')}',
        );
      }
    }

    final safeHpGain = decision.hpGain < 1 ? 1 : decision.hpGain;

    character.addClassLevel(
      className: decision.className,
      subclassName: decision.subclassName,
      hitDie: decision.hitDie,
    );
    if (decision.subclassName != null &&
        decision.subclassName!.trim().isNotEmpty) {
      character.progression =
          character.normalizedProgression.withSubclassForClass(
        className: decision.className,
        subclassName: decision.subclassName!,
      );
      if (character.charClass.trim().toLowerCase() ==
          decision.className.trim().toLowerCase()) {
        character.subclass = decision.subclassName;
      }
    }
    for (final skill in decision.skillProficiencies) {
      _addUnique(character.classSkills, skill);
    }
    character.maxHp = (character.maxHp ?? 0) + safeHpGain;
    character.currentHp = (character.currentHp ?? 0) + safeHpGain;

    final newClassLevel = character.levelForClass(decision.className);
    final notes = <String>[
      if (isNewClass) 'Multiclassed into ${decision.className}.',
      if (decision.skillProficiencies.isNotEmpty)
        'Gained skill proficiency: ${decision.skillProficiencies.join(', ')}.',
      if (_levelGrantsAbilityScoreImprovement(newClassLevel))
        '${decision.className} $newClassLevel grants an Ability Score Improvement.',
    ];

    return CharacterLevelUpResult(
      previousTotalLevel: previousTotalLevel,
      newTotalLevel: character.level,
      newClassLevel: newClassLevel,
      notes: notes,
    );
  }

  static bool _levelGrantsAbilityScoreImprovement(int classLevel) {
    return classLevel == 4 ||
        classLevel == 8 ||
        classLevel == 12 ||
        classLevel == 16 ||
        classLevel == 19;
  }

  static void _addUnique(List<String> values, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final key = trimmed.toLowerCase();
    if (values.any((entry) => entry.trim().toLowerCase() == key)) return;
    values.add(trimmed);
  }
}
