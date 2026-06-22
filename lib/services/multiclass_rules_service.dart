import '../models/character.dart';

class MulticlassRequirement {
  final Map<String, int> allOf;
  final Map<String, int> anyOf;

  const MulticlassRequirement({
    this.allOf = const {},
    this.anyOf = const {},
  });

  bool get hasAnyOf => anyOf.isNotEmpty;
}

class MulticlassValidationResult {
  final String className;
  final bool canMulticlass;
  final List<String> unmetRequirements;
  final Map<String, int> effectiveScores;

  const MulticlassValidationResult({
    required this.className,
    required this.canMulticlass,
    required this.unmetRequirements,
    required this.effectiveScores,
  });

  String get requirementsLabel {
    final requirement = MulticlassRulesService.requirementFor(className);
    if (requirement == null) return 'No requirement configured';

    final parts = <String>[
      ...requirement.allOf.entries
          .map((entry) => '${entry.key} ${entry.value}'),
    ];

    if (requirement.anyOf.isNotEmpty) {
      parts.add(
        requirement.anyOf.entries
            .map((entry) => '${entry.key} ${entry.value}')
            .join(' or '),
      );
    }

    return parts.join(', ');
  }
}

class MulticlassRulesService {
  static const Map<String, MulticlassRequirement> _requirements = {
    'artificer': MulticlassRequirement(allOf: {'INT': 13}),
    'barbarian': MulticlassRequirement(allOf: {'STR': 13}),
    'bard': MulticlassRequirement(allOf: {'CHA': 13}),
    'cleric': MulticlassRequirement(allOf: {'WIS': 13}),
    'druid': MulticlassRequirement(allOf: {'WIS': 13}),
    'fighter': MulticlassRequirement(anyOf: {'STR': 13, 'DEX': 13}),
    'monk': MulticlassRequirement(allOf: {'DEX': 13, 'WIS': 13}),
    'paladin': MulticlassRequirement(allOf: {'STR': 13, 'CHA': 13}),
    'ranger': MulticlassRequirement(allOf: {'DEX': 13, 'WIS': 13}),
    'rogue': MulticlassRequirement(allOf: {'DEX': 13}),
    'sorcerer': MulticlassRequirement(allOf: {'CHA': 13}),
    'warlock': MulticlassRequirement(allOf: {'CHA': 13}),
    'wizard': MulticlassRequirement(allOf: {'INT': 13}),
  };

  static MulticlassRequirement? requirementFor(String className) {
    return _requirements[_norm(className)];
  }

  static MulticlassValidationResult validateEntry({
    required Character character,
    required String targetClassName,
  }) {
    final scores = effectiveAbilityScores(character);
    final targetRequirement = requirementFor(targetClassName);
    final unmet = <String>[];

    if (targetRequirement != null) {
      unmet.addAll(_unmetRequirement(targetRequirement, scores));
    }

    final uniqueUnmet = <String>{...unmet}.toList();

    return MulticlassValidationResult(
      className: targetClassName,
      canMulticlass: uniqueUnmet.isEmpty,
      unmetRequirements: uniqueUnmet,
      effectiveScores: scores,
    );
  }

  static Map<String, MulticlassValidationResult> validateAllEntries({
    required Character character,
    required Iterable<String> classNames,
  }) {
    return {
      for (final className in classNames)
        className: validateEntry(
          character: character,
          targetClassName: className,
        ),
    };
  }

  static Map<String, int> effectiveAbilityScores(Character character) {
    const abilities = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

    return {
      for (final ability in abilities)
        ability: (character.stats[ability] ?? 10) +
            (character.racialBonuses[ability] ?? 0) +
            (character.featAbilityBonuses[ability] ?? 0),
    };
  }

  static List<String> _unmetRequirement(
    MulticlassRequirement requirement,
    Map<String, int> scores, {
    String prefix = '',
  }) {
    final unmet = <String>[];

    for (final entry in requirement.allOf.entries) {
      final score = scores[entry.key] ?? 0;
      if (score < entry.value) {
        unmet.add('$prefix${entry.key} ${entry.value}');
      }
    }

    if (requirement.anyOf.isNotEmpty) {
      final passesAny = requirement.anyOf.entries.any(
        (entry) => (scores[entry.key] ?? 0) >= entry.value,
      );

      if (!passesAny) {
        final label = requirement.anyOf.entries
            .map((entry) => '${entry.key} ${entry.value}')
            .join(' or ');
        unmet.add('$prefix$label');
      }
    }

    return unmet;
  }

  static String _norm(String value) => value.trim().toLowerCase();
}
