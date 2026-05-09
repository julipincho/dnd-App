import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/combat_encounter.dart';

class MonsterCombatBuild {
  final Combatant combatant;
  final List<PreparedCombatAction> availableActions;

  const MonsterCombatBuild({
    required this.combatant,
    required this.availableActions,
  });
}

class SrdMonster {
  final String index;
  final String name;
  final String size;
  final String type;
  final String? subtype;
  final int armorClass;
  final int hitPoints;
  final String? hitDice;
  final int speed;
  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;
  final String? challengeRating;
  final int proficiencyBonus;
  final Map<String, int> savingThrowBonuses;
  final List<SrdMonsterAction> actions;
  final List<SrdMonsterSpecialAbility> specialAbilities;

  const SrdMonster({
    required this.index,
    required this.name,
    required this.size,
    required this.type,
    required this.subtype,
    required this.armorClass,
    required this.hitPoints,
    required this.hitDice,
    required this.speed,
    required this.strength,
    required this.dexterity,
    required this.constitution,
    required this.intelligence,
    required this.wisdom,
    required this.charisma,
    required this.challengeRating,
    required this.proficiencyBonus,
    required this.savingThrowBonuses,
    required this.actions,
    required this.specialAbilities,
  });

  factory SrdMonster.fromJson(Map<String, dynamic> json) {
    return SrdMonster(
      index: json['index']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Monster',
      size: json['size']?.toString() ?? 'Medium',
      type: json['type']?.toString() ?? 'creature',
      subtype: json['subtype']?.toString(),
      armorClass: _parseArmorClass(json['armor_class']),
      hitPoints: (json['hit_points'] as num?)?.toInt() ?? 1,
      hitDice: json['hit_dice']?.toString(),
      speed: _parseSpeed(json['speed']),
      strength: (json['strength'] as num?)?.toInt() ?? 10,
      dexterity: (json['dexterity'] as num?)?.toInt() ?? 10,
      constitution: (json['constitution'] as num?)?.toInt() ?? 10,
      intelligence: (json['intelligence'] as num?)?.toInt() ?? 10,
      wisdom: (json['wisdom'] as num?)?.toInt() ?? 10,
      charisma: (json['charisma'] as num?)?.toInt() ?? 10,
      challengeRating: _formatChallengeRating(json['challenge_rating']),
      proficiencyBonus: (json['proficiency_bonus'] as num?)?.toInt() ?? 2,
      savingThrowBonuses: _parseSavingThrowBonuses(json['proficiencies']),
      actions: _listOfMaps(json['actions'])
          .map(SrdMonsterAction.fromJson)
          .toList(growable: false),
      specialAbilities: _listOfMaps(json['special_abilities'])
          .map(SrdMonsterSpecialAbility.fromJson)
          .toList(growable: false),
    );
  }
}

class SrdMonsterAction {
  final String name;
  final String description;
  final int? attackBonus;
  final String? damageFormula;
  final String? damageType;
  final bool isRanged;
  final bool isMelee;
  final List<SrdMonsterMultiattackEntry> multiattackActions;

  const SrdMonsterAction({
    required this.name,
    required this.description,
    required this.attackBonus,
    required this.damageFormula,
    required this.damageType,
    required this.isRanged,
    required this.isMelee,
    required this.multiattackActions,
  });

  factory SrdMonsterAction.fromJson(Map<String, dynamic> json) {
    final description = json['desc']?.toString() ?? '';
    final lowerDescription = description.toLowerCase();
    final damage = _extractDamage(json['damage']);

    return SrdMonsterAction(
      name: json['name']?.toString() ?? 'Action',
      description: description,
      attackBonus: (json['attack_bonus'] as num?)?.toInt(),
      damageFormula: damage.formula,
      damageType: damage.type,
      isRanged: lowerDescription.contains('ranged weapon attack'),
      isMelee: lowerDescription.contains('melee weapon attack'),
      multiattackActions: _listOfMaps(json['actions'])
          .map(SrdMonsterMultiattackEntry.fromJson)
          .where((entry) => entry.actionName.trim().isNotEmpty)
          .toList(growable: false),
    );
  }
}

class SrdMonsterMultiattackEntry {
  final String actionName;
  final int count;
  final String? type;

  const SrdMonsterMultiattackEntry({
    required this.actionName,
    required this.count,
    required this.type,
  });

  factory SrdMonsterMultiattackEntry.fromJson(Map<String, dynamic> json) {
    return SrdMonsterMultiattackEntry(
      actionName: json['action_name']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
      type: json['type']?.toString(),
    );
  }
}

class SrdMonsterSpecialAbility {
  final String name;
  final String description;

  const SrdMonsterSpecialAbility({
    required this.name,
    required this.description,
  });

  factory SrdMonsterSpecialAbility.fromJson(Map<String, dynamic> json) {
    return SrdMonsterSpecialAbility(
      name: json['name']?.toString() ?? 'Feature',
      description: json['desc']?.toString() ?? '',
    );
  }
}

class MonsterRepository {
  static const String _assetPath = 'assets/data/5e-SRD-Monsters.json';
  static List<SrdMonster>? _cache;

  static Future<List<SrdMonster>> loadMonsters() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    final rawList = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
            ? decoded.values.whereType<List>().expand((item) => item)
            : const [];
    final monsters = rawList
        .whereType<Map<String, dynamic>>()
        .map(SrdMonster.fromJson)
        .where((monster) => monster.index.isNotEmpty)
        .toList(growable: false);

    _cache = monsters;
    return monsters;
  }

  static Future<SrdMonster?> findByIndex(String index) async {
    final normalized = _normalizeKey(index);
    final monsters = await loadMonsters();
    for (final monster in monsters) {
      if (_normalizeKey(monster.index) == normalized) return monster;
    }
    return null;
  }

  static Future<SrdMonster?> findByName(String name) async {
    final normalized = _normalizeKey(name);
    final monsters = await loadMonsters();
    for (final monster in monsters) {
      if (_normalizeKey(monster.name) == normalized) return monster;
    }
    return null;
  }

  static MonsterCombatBuild buildCombatant({
    required SrdMonster monster,
    required int instanceNumber,
    String? displayName,
    int? initiativeSeed,
    bool hideHpFromPlayers = true,
  }) {
    final id = 'monster_${monster.index}_$instanceNumber';
    final initiativeBonus = _abilityModifier(monster.dexterity);
    final name = displayName ?? monster.name;
    final cr = monster.challengeRating;
    final subtype = monster.subtype == null || monster.subtype!.trim().isEmpty
        ? ''
        : ' ${monster.subtype}';
    final role =
        '${monster.size} ${monster.type}$subtype${cr == null ? '' : ' - CR $cr'}';

    return MonsterCombatBuild(
      combatant: Combatant(
        id: id,
        name: name,
        sourceId: monster.index,
        kind: CombatantKind.monster,
        team: CombatantTeam.enemy,
        role: role,
        initiative: initiativeSeed ?? 10 + initiativeBonus,
        initiativeBonus: initiativeBonus,
        hp: monster.hitPoints,
        maxHp: monster.hitPoints,
        armorClass: monster.armorClass,
        speed: monster.speed,
        isHpVisibleToPlayers: !hideHpFromPlayers,
        metadata: {
          'source': 'srdMonster',
          'monsterIndex': monster.index,
          'monsterName': monster.name,
          'abilityScores': {
            'STR': monster.strength,
            'DEX': monster.dexterity,
            'CON': monster.constitution,
            'INT': monster.intelligence,
            'WIS': monster.wisdom,
            'CHA': monster.charisma,
          },
          'savingThrowBonuses': monster.savingThrowBonuses,
          if (monster.challengeRating != null) 'challengeRating': cr,
          if (monster.hitDice != null) 'hitDice': monster.hitDice,
          'proficiencyBonus': monster.proficiencyBonus,
        },
      ),
      availableActions: _buildActions(monster: monster, combatantId: id),
    );
  }

  static List<PreparedCombatAction> _buildActions({
    required SrdMonster monster,
    required String combatantId,
  }) {
    final actions = <PreparedCombatAction>[
      for (final action in monster.actions)
        _buildMonsterAction(monster, action, monster.actions),
      for (final ability in monster.specialAbilities)
        if (_isUsableSpecialAbility(ability))
          _buildSpecialAbility(monster, ability),
    ];

    return actions
        .map(
          (action) => action.copyWith(
            id: '$combatantId:${action.id}',
            actorId: combatantId,
          ),
        )
        .toList(growable: false);
  }

  static PreparedCombatAction _buildMonsterAction(
    SrdMonster monster,
    SrdMonsterAction action,
    List<SrdMonsterAction> allActions,
  ) {
    final multiattackSteps = _multiattackStepsFor(action, allActions);
    if (multiattackSteps.isNotEmpty) {
      return PreparedCombatAction(
        id: 'monster:${monster.index}:action:${_normalizeKey(action.name)}',
        name: action.name,
        timing: CombatActionTiming.action,
        rollKind: CombatActionRollKind.attack,
        tags: [
          'Monster',
          'Multiattack',
          '${multiattackSteps.length} attacks',
          if (monster.challengeRating != null) 'CR ${monster.challengeRating}',
        ],
        metadata: {
          'source': 'monster',
          'monsterIndex': monster.index,
          'monsterName': monster.name,
          'description': action.description,
          'multiattack': true,
          'multiAttackSteps': multiattackSteps,
        },
      );
    }

    final attackBonus = action.attackBonus;
    final attackFormula = attackBonus == null
        ? null
        : attackBonus >= 0
            ? 'd20+$attackBonus'
            : 'd20$attackBonus';
    final tags = <String>[
      'Monster',
      if (action.isMelee) 'Melee',
      if (action.isRanged) 'Ranged',
      if (action.damageType != null) action.damageType!,
      if (monster.challengeRating != null) 'CR ${monster.challengeRating}',
    ];

    return PreparedCombatAction(
      id: 'monster:${monster.index}:action:${_normalizeKey(action.name)}',
      name: action.name,
      timing: CombatActionTiming.action,
      rollKind: attackFormula == null
          ? action.damageFormula == null
              ? CombatActionRollKind.none
              : CombatActionRollKind.damage
          : CombatActionRollKind.attack,
      attackFormula: attackFormula,
      damageFormula: action.damageFormula,
      tags: tags,
      metadata: {
        'source': 'monster',
        'monsterIndex': monster.index,
        'monsterName': monster.name,
        'description': action.description,
        if (action.damageFormula != null)
          'criticalDamageFormula': _doubleDice(action.damageFormula!),
      },
    );
  }

  static List<Map<String, dynamic>> _multiattackStepsFor(
    SrdMonsterAction action,
    List<SrdMonsterAction> allActions,
  ) {
    if (action.multiattackActions.isEmpty) return const [];

    final byName = {
      for (final candidate in allActions)
        _normalizeKey(candidate.name): candidate,
    };
    final steps = <Map<String, dynamic>>[];
    for (final entry in action.multiattackActions) {
      final candidate = byName[_normalizeKey(entry.actionName)];
      if (candidate == null) continue;
      final attackBonus = candidate.attackBonus;
      final attackFormula = attackBonus == null
          ? null
          : attackBonus >= 0
              ? 'd20+$attackBonus'
              : 'd20$attackBonus';
      if (attackFormula == null && candidate.damageFormula == null) {
        continue;
      }
      for (var index = 0; index < entry.count; index++) {
        steps.add({
          'name': candidate.name,
          'attackFormula': attackFormula,
          'damageFormula': candidate.damageFormula,
          if (candidate.damageFormula != null)
            'criticalDamageFormula': _doubleDice(candidate.damageFormula!),
          'tags': [
            if (candidate.isMelee) 'Melee',
            if (candidate.isRanged) 'Ranged',
            if (candidate.damageType != null) candidate.damageType!,
            if (entry.type != null) entry.type!,
          ],
        });
      }
    }
    return steps;
  }

  static PreparedCombatAction _buildSpecialAbility(
    SrdMonster monster,
    SrdMonsterSpecialAbility ability,
  ) {
    final lower = ability.description.toLowerCase();
    final timing = lower.contains('bonus action')
        ? CombatActionTiming.bonusAction
        : lower.contains('reaction')
            ? CombatActionTiming.reaction
            : CombatActionTiming.action;

    return PreparedCombatAction(
      id: 'monster:${monster.index}:feature:${_normalizeKey(ability.name)}',
      name: ability.name,
      timing: timing,
      rollKind: CombatActionRollKind.none,
      tags: [
        'Monster Feature',
        if (timing == CombatActionTiming.bonusAction) 'Bonus Action',
        if (timing == CombatActionTiming.reaction) 'Reaction',
      ],
      metadata: {
        'source': 'monsterFeature',
        'monsterIndex': monster.index,
        'monsterName': monster.name,
        'description': ability.description,
      },
    );
  }

  static bool _isUsableSpecialAbility(SrdMonsterSpecialAbility ability) {
    final lower = ability.description.toLowerCase();
    return lower.contains('action') || lower.contains('reaction');
  }
}

class _ParsedDamage {
  final String? formula;
  final String? type;

  const _ParsedDamage(this.formula, this.type);
}

_ParsedDamage _extractDamage(Object? raw) {
  if (raw is! List) return const _ParsedDamage(null, null);
  for (final item in raw) {
    final parsed = _parseDamageEntry(item);
    if (parsed.formula != null) return parsed;
  }
  return const _ParsedDamage(null, null);
}

_ParsedDamage _parseDamageEntry(Object? raw) {
  if (raw is! Map) return const _ParsedDamage(null, null);

  final directFormula = _cleanFormula(raw['damage_dice']?.toString());
  if (directFormula != null) {
    return _ParsedDamage(directFormula, _damageTypeName(raw['damage_type']));
  }

  final from = raw['from'];
  if (from is Map) {
    final options = from['options'];
    if (options is List) {
      for (final option in options) {
        final parsed = _parseDamageEntry(option);
        if (parsed.formula != null) return parsed;
      }
    }
  }

  return const _ParsedDamage(null, null);
}

String? _damageTypeName(Object? raw) {
  if (raw is Map) {
    return raw['name']?.toString();
  }
  return null;
}

int _parseArmorClass(Object? raw) {
  if (raw is num) return raw.toInt();
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first;
    if (first is num) return first.toInt();
    if (first is Map && first['value'] is num) {
      return (first['value'] as num).toInt();
    }
  }
  return 10;
}

int _parseSpeed(Object? raw) {
  if (raw is Map) {
    final walk = raw['walk']?.toString();
    if (walk != null) {
      final match = RegExp(r'\d+').firstMatch(walk);
      if (match != null) return int.parse(match.group(0)!);
    }
  }
  return 30;
}

String? _formatChallengeRating(Object? raw) {
  if (raw == null) return null;
  if (raw is num) {
    if (raw == 0.125) return '1/8';
    if (raw == 0.25) return '1/4';
    if (raw == 0.5) return '1/2';
    if (raw % 1 == 0) return raw.toInt().toString();
  }
  return raw.toString();
}

int _abilityModifier(int score) {
  return ((score - 10) / 2).floor();
}

List<Map<String, dynamic>> _listOfMaps(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map<String, dynamic>>().toList(growable: false);
}

Map<String, int> _parseSavingThrowBonuses(Object? raw) {
  final bonuses = <String, int>{};
  for (final item in _listOfMaps(raw)) {
    final proficiency = item['proficiency'];
    if (proficiency is! Map) continue;
    final name = proficiency['name']?.toString().toLowerCase() ?? '';
    final match = RegExp(
      r'saving throw:\s*(str|dex|con|int|wis|cha|strength|dexterity|constitution|intelligence|wisdom|charisma)',
    ).firstMatch(name);
    if (match == null) continue;
    final ability = _normalizeAbilityLabel(match.group(1)!);
    final value = (item['value'] as num?)?.toInt();
    if (value != null) bonuses[ability] = value;
  }
  return bonuses;
}

String _normalizeAbilityLabel(String value) {
  final text = value.trim().toLowerCase();
  if (text.startsWith('str')) return 'STR';
  if (text.startsWith('dex')) return 'DEX';
  if (text.startsWith('con')) return 'CON';
  if (text.startsWith('int')) return 'INT';
  if (text.startsWith('wis')) return 'WIS';
  if (text.startsWith('cha')) return 'CHA';
  return value.trim().toUpperCase();
}

String _normalizeKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String? _cleanFormula(String? formula) {
  final trimmed = formula?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == 'null') return null;
  return trimmed.replaceAll(' ', '');
}

String? _doubleDice(String formula) {
  final cleaned = _cleanFormula(formula);
  if (cleaned == null) return null;
  return cleaned.replaceAllMapped(
    RegExp(r'(\d*)d(\d+)'),
    (match) {
      final countText = match.group(1);
      final sides = match.group(2)!;
      final count = countText == null || countText.isEmpty
          ? 1
          : int.tryParse(countText) ?? 1;
      return '${count * 2}d$sides';
    },
  );
}
