enum CharacterOptionCategory {
  infusion,
  invocation,
  fightingStyle,
  maneuver,
  metamagic,
  pactBoon,
  spell,
}

extension CharacterOptionCategoryX on CharacterOptionCategory {
  String get key {
    switch (this) {
      case CharacterOptionCategory.infusion:
        return 'infusion';
      case CharacterOptionCategory.invocation:
        return 'invocation';
      case CharacterOptionCategory.fightingStyle:
        return 'fightingStyle';
      case CharacterOptionCategory.maneuver:
        return 'maneuver';
      case CharacterOptionCategory.metamagic:
        return 'metamagic';
      case CharacterOptionCategory.pactBoon:
        return 'pactBoon';
      case CharacterOptionCategory.spell:
        return 'spell';
    }
  }

  String get label {
    switch (this) {
      case CharacterOptionCategory.infusion:
        return 'Infusion';
      case CharacterOptionCategory.invocation:
        return 'Invocation';
      case CharacterOptionCategory.fightingStyle:
        return 'Fighting Style';
      case CharacterOptionCategory.maneuver:
        return 'Maneuver';
      case CharacterOptionCategory.metamagic:
        return 'Metamagic';
      case CharacterOptionCategory.pactBoon:
        return 'Pact Boon';
      case CharacterOptionCategory.spell:
        return 'Spell';
    }
  }

  static CharacterOptionCategory fromString(String value) {
    switch (value) {
      case 'infusion':
        return CharacterOptionCategory.infusion;
      case 'invocation':
        return CharacterOptionCategory.invocation;
      case 'fightingStyle':
        return CharacterOptionCategory.fightingStyle;
      case 'maneuver':
        return CharacterOptionCategory.maneuver;
      case 'metamagic':
        return CharacterOptionCategory.metamagic;
      case 'pactBoon':
        return CharacterOptionCategory.pactBoon;
      case 'spell':
        return CharacterOptionCategory.spell;
      default:
        throw ArgumentError('Unknown CharacterOptionCategory: $value');
    }
  }
}
