import '../models/character.dart';

class CharacterMulticlassProficiencyService {
  const CharacterMulticlassProficiencyService._();

  static const List<String> allSkills = [
    'Acrobatics',
    'Animal Handling',
    'Arcana',
    'Athletics',
    'Deception',
    'History',
    'Insight',
    'Intimidation',
    'Investigation',
    'Medicine',
    'Nature',
    'Perception',
    'Performance',
    'Persuasion',
    'Religion',
    'Sleight of Hand',
    'Stealth',
    'Survival',
  ];

  static List<String> multiclassSkillOptionsForClass(String className) {
    switch (_norm(className)) {
      case 'bard':
        return allSkills;
      case 'ranger':
        return const [
          'Animal Handling',
          'Athletics',
          'Insight',
          'Investigation',
          'Nature',
          'Perception',
          'Stealth',
          'Survival',
        ];
      case 'rogue':
        return const [
          'Acrobatics',
          'Athletics',
          'Deception',
          'Insight',
          'Intimidation',
          'Investigation',
          'Perception',
          'Performance',
          'Persuasion',
          'Sleight of Hand',
          'Stealth',
        ];
      default:
        return const [];
    }
  }

  static bool grantsMulticlassSkillChoice(String className) {
    return multiclassSkillOptionsForClass(className).isNotEmpty;
  }

  static bool isProficientWithWeapon({
    required Character character,
    required String weaponName,
    required String? weaponCategory,
  }) {
    final normalizedWeapon = _norm(weaponName);

    if (_listContains(character.racialWeaponProficiencies, normalizedWeapon) ||
        _listContains(character.featWeaponProficiencies, normalizedWeapon)) {
      return true;
    }

    final category = _norm(weaponCategory ?? '');
    if (category.isEmpty) return true;

    final classNames = _orderedClassNames(character);
    if (classNames.isEmpty) return true;

    final primaryClass = classNames.first;
    if (_startingClassWeaponProficiency(
      className: primaryClass,
      weaponName: normalizedWeapon,
      weaponCategory: category,
    )) {
      return true;
    }

    for (final className in classNames.skip(1)) {
      if (_multiclassWeaponProficiency(
        className: className,
        weaponName: normalizedWeapon,
        weaponCategory: category,
      )) {
        return true;
      }
    }

    return false;
  }

  static List<String> _orderedClassNames(Character character) {
    final result = <String>[];
    for (final level in character.normalizedProgression.levels) {
      final className = _norm(level.className);
      if (className.isEmpty || result.contains(className)) continue;
      result.add(className);
    }

    if (result.isEmpty && character.charClass.trim().isNotEmpty) {
      result.add(_norm(character.charClass));
    }

    return result;
  }

  static bool _startingClassWeaponProficiency({
    required String className,
    required String weaponName,
    required String weaponCategory,
  }) {
    final isSimple = weaponCategory == 'simple';
    final isMartial = weaponCategory == 'martial';

    switch (className) {
      case 'barbarian':
      case 'fighter':
      case 'paladin':
      case 'ranger':
        return isSimple || isMartial;

      case 'bard':
      case 'cleric':
      case 'druid':
      case 'artificer':
        return isSimple;

      case 'monk':
        return isSimple || weaponName == 'shortsword';

      case 'rogue':
        return isSimple || _isRogueMartialWeapon(weaponName);

      case 'sorcerer':
      case 'wizard':
        return {
          'dagger',
          'dart',
          'sling',
          'quarterstaff',
          'light crossbow',
        }.contains(weaponName);

      case 'warlock':
        return isSimple;

      default:
        return true;
    }
  }

  static bool _multiclassWeaponProficiency({
    required String className,
    required String weaponName,
    required String weaponCategory,
  }) {
    final isSimple = weaponCategory == 'simple';
    final isMartial = weaponCategory == 'martial';

    switch (className) {
      case 'barbarian':
      case 'fighter':
      case 'paladin':
      case 'ranger':
        return isSimple || isMartial;

      case 'bard':
      case 'cleric':
      case 'druid':
      case 'monk':
      case 'rogue':
      case 'warlock':
      case 'artificer':
        return isSimple ||
            (className == 'monk' && weaponName == 'shortsword') ||
            (className == 'rogue' && _isRogueMartialWeapon(weaponName));

      case 'sorcerer':
      case 'wizard':
        return false;

      default:
        return false;
    }
  }

  static bool _isRogueMartialWeapon(String weaponName) {
    return weaponName == 'hand crossbow' ||
        weaponName == 'longsword' ||
        weaponName == 'rapier' ||
        weaponName == 'shortsword';
  }

  static bool _listContains(List<String> values, String normalizedValue) {
    return values.any((entry) => _norm(entry) == normalizedValue);
  }

  static String _norm(String value) => value.trim().toLowerCase();
}
