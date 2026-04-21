// lib/data/core_rules.dart

/// Orden estándar de habilidades (códigos correctos)
const abilityOrder = <String>[
  'STR',
  'DEX',
  'CON',
  'INT',
  'WIS',
  'CHA',
];

/// Calcula el modificador de una habilidad
int abilityModifier(int score) {
  return ((score - 10) / 2).floor();
}

String formatModifier(int mod) => mod >= 0 ? '+$mod' : '$mod';

/// Clases básicas (AJUSTADAS A STR/DEX/INT...)
final Map<String, Map<String, dynamic>> dndClasses = {
  'Fighter': {
    'hitDie': 10,
    'primaryAbility': 'STR',
    'savingThrows': ['STR', 'CON'],
  },
  'Wizard': {
    'hitDie': 6,
    'primaryAbility': 'INT',
    'savingThrows': ['INT', 'WIS'],
  },
  'Rogue': {
    'hitDie': 8,
    'primaryAbility': 'DEX',
    'savingThrows': ['DEX', 'INT'],
  },
  'Cleric': {
    'hitDie': 8,
    'primaryAbility': 'WIS',
    'savingThrows': ['WIS', 'CHA'],
  },
  'Paladin': {
    'hitDie': 10,
    'primaryAbility': 'STR',
    'savingThrows': ['WIS', 'CHA'],
  },
  'Ranger': {
    'hitDie': 10,
    'primaryAbility': 'DEX',
    'savingThrows': ['STR', 'DEX'],
  },
  'Barbarian': {
    'hitDie': 12,
    'primaryAbility': 'STR',
    'savingThrows': ['STR', 'CON'],
  },
  'Bard': {
    'hitDie': 8,
    'primaryAbility': 'CHA',
    'savingThrows': ['DEX', 'CHA'],
  },
};

/// Backgrounds básicos (las skills sí están bien)
final Map<String, Map<String, dynamic>> dndBackgrounds = {
  'Acolyte': {
    'skills': ['Insight', 'Religion'],
  },
  'Criminal': {
    'skills': ['Deception', 'Stealth'],
  },
  'Folk Hero': {
    'skills': ['Animal Handling', 'Survival'],
  },
  'Sage': {
    'skills': ['Arcana', 'History'],
  },
  'Soldier': {
    'skills': ['Athletics', 'Intimidation'],
  },
};
