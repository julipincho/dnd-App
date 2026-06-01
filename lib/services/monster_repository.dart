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
  static const String imageBaseUrl = 'https://www.dnd5eapi.co';

  final String index;
  final String name;
  final String? imagePath;
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
    required this.imagePath,
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
    final name = json['name']?.toString() ?? 'Monster';
    final rawIndex = json['index']?.toString().trim();
    return SrdMonster(
      index:
          rawIndex == null || rawIndex.isEmpty ? _normalizeKey(name) : rawIndex,
      name: name,
      imagePath: _normalizeImagePath(json['image']),
      size: json['size']?.toString() ?? 'Medium',
      type: json['type']?.toString() ?? 'creature',
      subtype: json['subtype']?.toString(),
      armorClass: _parseArmorClass(json['armor_class']),
      hitPoints: _intFromJson(json['hit_points'], fallback: 1),
      hitDice: json['hit_dice']?.toString(),
      speed: _parseSpeed(json['speed']),
      strength: _intFromJson(json['strength'], fallback: 10),
      dexterity: _intFromJson(json['dexterity'], fallback: 10),
      constitution: _intFromJson(json['constitution'], fallback: 10),
      intelligence: _intFromJson(json['intelligence'], fallback: 10),
      wisdom: _intFromJson(json['wisdom'], fallback: 10),
      charisma: _intFromJson(json['charisma'], fallback: 10),
      challengeRating: _formatChallengeRating(json['challenge_rating']),
      proficiencyBonus: _intFromJson(json['proficiency_bonus'], fallback: 2),
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
  final List<SrdMonsterActionOption> optionActions;

  const SrdMonsterAction({
    required this.name,
    required this.description,
    required this.attackBonus,
    required this.damageFormula,
    required this.damageType,
    required this.isRanged,
    required this.isMelee,
    required this.multiattackActions,
    required this.optionActions,
  });

  factory SrdMonsterAction.fromJson(Map<String, dynamic> json) {
    final description = json['desc']?.toString() ?? '';
    final lowerDescription = description.toLowerCase();
    final damage = _extractDamage(json['damage']);

    return SrdMonsterAction(
      name: json['name']?.toString() ?? 'Action',
      description: description,
      attackBonus: _optionalIntFromJson(json['attack_bonus']) ??
          _attackBonusFromDescription(description),
      damageFormula: damage.formula,
      damageType: damage.type,
      isRanged: lowerDescription.contains('ranged weapon attack'),
      isMelee: lowerDescription.contains('melee weapon attack'),
      multiattackActions: _parseMultiattackEntries(
        json['actions'],
        json['action_options'],
      ),
      optionActions: _parseActionOptions(json['options'], description),
    );
  }
}

class SrdMonsterActionOption {
  final String name;
  final String description;
  final String? optionType;
  final String? saveAbility;
  final int? saveDc;
  final String? successType;
  final String? damageFormula;
  final String? damageType;

  const SrdMonsterActionOption({
    required this.name,
    required this.description,
    required this.optionType,
    required this.saveAbility,
    required this.saveDc,
    required this.successType,
    required this.damageFormula,
    required this.damageType,
  });
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
      count: _intFromJson(json['count'], fallback: 1),
      type: json['type']?.toString(),
    );
  }
}

List<SrdMonsterMultiattackEntry> _parseMultiattackEntries(
  Object? directActions,
  Object? actionOptions,
) {
  final direct = _listOfMaps(directActions)
      .map(SrdMonsterMultiattackEntry.fromJson)
      .where((entry) => entry.actionName.trim().isNotEmpty)
      .toList(growable: false);
  if (direct.isNotEmpty) return direct;

  final alternatives = _optionMaps(actionOptions)
      .map(_multiattackEntriesFromOption)
      .where((entries) => entries.isNotEmpty)
      .toList(growable: false);
  if (alternatives.isEmpty) return const [];

  alternatives.sort((a, b) {
    final totalA = a.fold<int>(0, (sum, entry) => sum + entry.count);
    final totalB = b.fold<int>(0, (sum, entry) => sum + entry.count);
    return totalB.compareTo(totalA);
  });
  return alternatives.first;
}

List<SrdMonsterMultiattackEntry> _multiattackEntriesFromOption(
  Map<String, dynamic> option,
) {
  final items = _listOfMaps(option['items']);
  if (items.isNotEmpty) {
    return items
        .expand(_multiattackEntriesFromOption)
        .where((entry) => entry.actionName.trim().isNotEmpty)
        .toList(growable: false);
  }

  final actionName =
      option['action_name']?.toString() ?? option['name']?.toString() ?? '';
  if (actionName.trim().isEmpty) return const [];

  return [
    SrdMonsterMultiattackEntry(
      actionName: actionName,
      count: _intFromJson(option['count'], fallback: 1),
      type: option['type']?.toString(),
    ),
  ];
}

List<SrdMonsterActionOption> _parseActionOptions(
  Object? rawOptions,
  String parentDescription,
) {
  final options = <SrdMonsterActionOption>[];
  for (final rawOption in _optionMaps(rawOptions)) {
    final name =
        rawOption['name']?.toString() ?? rawOption['action_name']?.toString();
    if (name == null || name.trim().isEmpty) continue;

    final optionDescription = rawOption['desc']?.toString();
    final description =
        (optionDescription == null || optionDescription.trim().isEmpty)
            ? _descriptionForNamedOption(parentDescription, name)
            : optionDescription;
    final damage = _extractDamage(rawOption['damage']);
    final textDamage = _extractDamageFromText(description);
    final saveFromDc = _saveFromDc(rawOption['dc']);
    final saveFromText = _extractSavingThrow(description);
    final dc = rawOption['dc'];
    final successType =
        dc is Map ? dc['success_type']?.toString().toLowerCase() : null;

    options.add(
      SrdMonsterActionOption(
        name: name,
        description: description,
        optionType: rawOption['option_type']?.toString(),
        saveAbility: saveFromDc?.ability ?? saveFromText?.ability,
        saveDc: saveFromDc?.dc ?? saveFromText?.dc,
        successType: successType,
        damageFormula: damage.formula ?? textDamage.formula,
        damageType: damage.type ?? textDamage.type,
      ),
    );
  }
  return options;
}

List<Map<String, dynamic>> _optionMaps(Object? rawOptions) {
  if (rawOptions is Map) {
    final from = rawOptions['from'];
    if (from is Map) return _listOfMaps(from['options']);
    return _listOfMaps(rawOptions['options']);
  }
  return _listOfMaps(rawOptions);
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

  static void clearCache() {
    _cache = null;
  }

  static Future<List<SrdMonster>> loadMonsters() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    final rawList = decoded is List
        ? decoded
        : decoded is Map
            ? decoded.values.whereType<List>().expand((item) => item)
            : const [];
    final rawStatBlocks = rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(_looksLikeSrdStatBlock)
        .toList(growable: false);
    final source = rawStatBlocks.isEmpty
        ? rawList
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : rawStatBlocks;
    final monsters = source
        .map(SrdMonster.fromJson)
        .where((monster) => monster.index.isNotEmpty)
        .toList(growable: false);
    if (monsters.isEmpty) {
      throw StateError('No SRD monster statblocks were found in $_assetPath.');
    }

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
    final portraitPath = monster.imagePath;

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
          'specialAbilities': [
            for (final ability in monster.specialAbilities)
              '${ability.name}: ${ability.description}',
          ],
          if (monster.challengeRating != null) 'challengeRating': cr,
          if (monster.hitDice != null) 'hitDice': monster.hitDice,
          if (portraitPath != null) ...{
            'portraitPath': portraitPath,
            'portraitSource': 'D&D 5e SRD API',
            'portraitSourceUrl': SrdMonster.imageBaseUrl,
          },
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
        ..._buildMonsterActionEntries(monster, action, monster.actions),
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

  static Iterable<PreparedCombatAction> _buildMonsterActionEntries(
    SrdMonster monster,
    SrdMonsterAction action,
    List<SrdMonsterAction> allActions,
  ) sync* {
    final isOptionContainer =
        action.optionActions.isNotEmpty && action.multiattackActions.isEmpty;
    if (!isOptionContainer) {
      yield _buildMonsterAction(monster, action, allActions);
    }
    for (final option in action.optionActions) {
      yield _buildMonsterActionOption(monster, action, option);
    }
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

    final textDamage = _extractDamageFromText(action.description);
    final damageFormula = action.damageFormula ?? textDamage.formula;
    final damageType = action.damageType ?? textDamage.type;
    final save = _extractSavingThrow(action.description);
    final area = _extractAreaFromText(action.description);
    final attackRange = _extractAttackRangeFromText(action.description);
    final attackBonus = action.attackBonus;
    final attackFormula = attackBonus == null
        ? null
        : attackBonus >= 0
            ? 'd20+$attackBonus'
            : 'd20$attackBonus';
    final hasPrimarySave = save != null && attackFormula == null;
    final tags = <String>[
      'Monster',
      if (action.isMelee) 'Melee',
      if (action.isRanged) 'Ranged',
      if (damageType != null) damageType,
      if (save != null) '${save.ability} DC ${save.dc}',
      if (area != null) '${area.shape} ${area.feet} ft',
      if (monster.challengeRating != null) 'CR ${monster.challengeRating}',
    ];

    return PreparedCombatAction(
      id: 'monster:${monster.index}:action:${_normalizeKey(action.name)}',
      name: action.name,
      timing: CombatActionTiming.action,
      rollKind: hasPrimarySave
          ? CombatActionRollKind.savingThrow
          : attackFormula == null
              ? damageFormula == null
                  ? CombatActionRollKind.none
                  : CombatActionRollKind.damage
              : CombatActionRollKind.attack,
      attackFormula: attackFormula,
      damageFormula: damageFormula,
      saveAbility: save?.ability,
      saveDc: save?.dc,
      tags: tags,
      metadata: {
        'source': 'monster',
        'monsterIndex': monster.index,
        'monsterName': monster.name,
        'description': action.description,
        if (damageType != null) 'damageType': damageType,
        if (damageFormula != null && !hasPrimarySave)
          'criticalDamageFormula': _doubleDice(damageFormula),
        if (save != null)
          'halfDamageOnSave': _dealsHalfDamageOnSave(
            action.description,
          ),
        if (area != null) ...{
          'areaShape': area.shape,
          'areaFeet': area.feet,
          if (area.shape == 'cone' || area.shape == 'line')
            'rangeFeet': area.feet,
        },
        if (area == null && attackRange != null) ...{
          'rangeFeet': attackRange.normalFeet,
          if (attackRange.longFeet != null)
            'longRangeFeet': attackRange.longFeet,
        },
      },
    );
  }

  static PreparedCombatAction _buildMonsterActionOption(
    SrdMonster monster,
    SrdMonsterAction parent,
    SrdMonsterActionOption option,
  ) {
    final damageFormula = option.damageFormula;
    final damageType = option.damageType;
    final saveAbility = option.saveAbility;
    final saveDc = option.saveDc;
    final area = _extractAreaFromText(option.description);
    final attackRange = _extractAttackRangeFromText(option.description);
    final hasPrimarySave = saveAbility != null && saveDc != null;
    final optionType = option.optionType?.toLowerCase();
    final isBreath = optionType == 'breath' ||
        parent.name.toLowerCase().contains('breath') ||
        option.name.toLowerCase().contains('breath');
    final halfDamageOnSave = option.successType == 'half' ||
        _dealsHalfDamageOnSave(option.description);
    final failureCondition = _failureConditionForMonsterOption(option);

    return PreparedCombatAction(
      id: 'monster:${monster.index}:action:${_normalizeKey(parent.name)}:${_normalizeKey(option.name)}',
      name: option.name,
      timing: CombatActionTiming.action,
      rollKind: hasPrimarySave
          ? CombatActionRollKind.savingThrow
          : damageFormula == null
              ? CombatActionRollKind.none
              : CombatActionRollKind.damage,
      damageFormula: damageFormula,
      saveAbility: saveAbility,
      saveDc: saveDc,
      tags: [
        'Monster',
        if (isBreath) 'Breath',
        if (damageType != null) damageType,
        if (failureCondition != null) failureCondition,
        if (hasPrimarySave) '$saveAbility DC $saveDc',
        if (area != null) '${area.shape} ${area.feet} ft',
        if (monster.challengeRating != null) 'CR ${monster.challengeRating}',
      ],
      metadata: {
        'source': 'monster',
        'monsterIndex': monster.index,
        'monsterName': monster.name,
        'description': option.description,
        'parentAction': parent.name,
        if (option.optionType != null) 'optionType': option.optionType,
        if (damageType != null) 'damageType': damageType,
        if (isBreath) 'breathWeapon': true,
        if (failureCondition != null) 'failureCondition': failureCondition,
        if (damageFormula != null && !hasPrimarySave)
          'criticalDamageFormula': _doubleDice(damageFormula),
        if (hasPrimarySave) 'halfDamageOnSave': halfDamageOnSave,
        if (area != null) ...{
          'areaShape': area.shape,
          'areaFeet': area.feet,
          if (area.shape == 'cone' || area.shape == 'line')
            'rangeFeet': area.feet,
        },
        if (area == null && attackRange != null) ...{
          'rangeFeet': attackRange.normalFeet,
          if (attackRange.longFeet != null)
            'longRangeFeet': attackRange.longFeet,
        },
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
      final candidateDamage = _damageForMonsterAction(candidate);
      final damageFormula = candidateDamage.formula;
      if (attackFormula == null && damageFormula == null) {
        continue;
      }
      for (var index = 0; index < entry.count; index++) {
        steps.add({
          'name': candidate.name,
          'attackFormula': attackFormula,
          'damageFormula': damageFormula,
          if (damageFormula != null)
            'criticalDamageFormula': _doubleDice(damageFormula),
          'tags': [
            if (candidate.isMelee) 'Melee',
            if (candidate.isRanged) 'Ranged',
            if (candidateDamage.type != null) candidateDamage.type!,
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
    final attackBonus = _attackBonusFromDescription(ability.description);
    final damage = _extractDamageFromText(ability.description);
    final save = _extractSavingThrow(ability.description);
    final area = _extractAreaFromText(ability.description);
    final attackRange = _extractAttackRangeFromText(ability.description);
    final timing = lower.contains('bonus action')
        ? CombatActionTiming.bonusAction
        : lower.contains('reaction')
            ? CombatActionTiming.reaction
            : CombatActionTiming.action;
    final attackFormula = attackBonus == null
        ? null
        : attackBonus >= 0
            ? 'd20+$attackBonus'
            : 'd20$attackBonus';
    final hasPrimarySave = save != null && attackFormula == null;

    return PreparedCombatAction(
      id: 'monster:${monster.index}:feature:${_normalizeKey(ability.name)}',
      name: ability.name,
      timing: timing,
      rollKind: hasPrimarySave
          ? CombatActionRollKind.savingThrow
          : attackFormula == null
              ? damage.formula == null
                  ? CombatActionRollKind.none
                  : CombatActionRollKind.damage
              : CombatActionRollKind.attack,
      attackFormula: attackFormula,
      damageFormula: damage.formula,
      saveAbility: save?.ability,
      saveDc: save?.dc,
      tags: [
        'Monster Feature',
        if (timing == CombatActionTiming.bonusAction) 'Bonus Action',
        if (timing == CombatActionTiming.reaction) 'Reaction',
        if (damage.type != null) damage.type!,
        if (save != null) '${save.ability} DC ${save.dc}',
        if (area != null) '${area.shape} ${area.feet} ft',
      ],
      metadata: {
        'source': 'monsterFeature',
        'monsterIndex': monster.index,
        'monsterName': monster.name,
        'description': ability.description,
        if (damage.formula != null && !hasPrimarySave)
          'criticalDamageFormula': _doubleDice(damage.formula!),
        if (save != null)
          'halfDamageOnSave': _dealsHalfDamageOnSave(
            ability.description,
          ),
        if (area != null) ...{
          'areaShape': area.shape,
          'areaFeet': area.feet,
          if (area.shape == 'cone' || area.shape == 'line')
            'rangeFeet': area.feet,
        },
        if (area == null && attackRange != null) ...{
          'rangeFeet': attackRange.normalFeet,
          if (attackRange.longFeet != null)
            'longRangeFeet': attackRange.longFeet,
        },
      },
    );
  }

  static bool _isUsableSpecialAbility(SrdMonsterSpecialAbility ability) {
    final lower = ability.description.toLowerCase();
    return lower.contains('action') ||
        lower.contains('reaction') ||
        _attackBonusFromDescription(ability.description) != null ||
        _extractSavingThrow(ability.description) != null ||
        _extractDamageFromText(ability.description).formula != null;
  }
}

_ParsedDamage _damageForMonsterAction(SrdMonsterAction action) {
  final textDamage = _extractDamageFromText(action.description);
  return _ParsedDamage(
    action.damageFormula ?? textDamage.formula,
    action.damageType ?? textDamage.type,
  );
}

String? _failureConditionForMonsterOption(SrdMonsterActionOption option) {
  final text = '${option.name} ${option.description}'.toLowerCase();
  if (text.contains('weakening breath') ||
      text.contains('disadvantage on strength')) {
    return 'Weakened';
  }
  if (text.contains('sleep breath') || text.contains('fall unconscious')) {
    return 'Unconscious';
  }
  if (text.contains('poison') && text.contains('saving throw')) {
    return 'Poisoned';
  }
  if (text.contains('frightened')) return 'Frightened';
  if (text.contains('restrained')) return 'Restrained';
  if (text.contains('paralyzed')) return 'Paralyzed';
  return null;
}

class _ParsedDamage {
  final String? formula;
  final String? type;

  const _ParsedDamage(this.formula, this.type);
}

class _ParsedSave {
  final String ability;
  final int dc;

  const _ParsedSave(this.ability, this.dc);
}

class _ParsedArea {
  final String shape;
  final int feet;

  const _ParsedArea(this.shape, this.feet);
}

class _ParsedRange {
  final int normalFeet;
  final int? longFeet;

  const _ParsedRange(this.normalFeet, this.longFeet);
}

_ParsedSave? _saveFromDc(Object? raw) {
  if (raw is! Map) return null;
  final value = _optionalIntFromJson(raw['dc_value']);
  final dcType = raw['dc_type'];
  String? ability;
  if (dcType is Map) {
    ability = dcType['index']?.toString() ?? dcType['name']?.toString();
  } else {
    ability = dcType?.toString();
  }
  if (value == null || ability == null || ability.trim().isEmpty) {
    return null;
  }
  return _ParsedSave(_normalizeAbilityLabel(ability), value);
}

String _descriptionForNamedOption(String parentDescription, String optionName) {
  final parent = parentDescription.trim();
  if (parent.isEmpty) return '';

  final startMatch = RegExp(
    r'(?:^|\n\s*)' + RegExp.escape(optionName.trim()) + r'\.\s*',
    caseSensitive: false,
  ).firstMatch(parent);
  if (startMatch == null) return parent;

  final start = startMatch.start;
  final rest = parent.substring(start).trim();
  final nextHeading = RegExp(
    r'\n\s*[A-Z][^.\n]{1,64}\.\s',
  ).firstMatch(rest.length <= 1 ? '' : rest.substring(1));
  if (nextHeading == null) return rest;
  return rest.substring(0, nextHeading.start + 1).trim();
}

_ParsedDamage _extractDamage(Object? raw) {
  if (raw is! List) return const _ParsedDamage(null, null);
  for (final item in raw) {
    final parsed = _parseDamageEntry(item);
    if (parsed.formula != null) return parsed;
  }
  return const _ParsedDamage(null, null);
}

_ParsedDamage _extractDamageFromText(String text) {
  final hitIndex = text.toLowerCase().indexOf('hit:');
  final source = hitIndex < 0 ? text : text.substring(hitIndex);
  final formulaMatch = RegExp(
    r'\((\d+d\d+(?:\s*[+-]\s*\d+)?)\)',
    caseSensitive: false,
  ).firstMatch(source);
  final formula = _cleanFormula(formulaMatch?.group(1));
  if (formula == null) return const _ParsedDamage(null, null);

  final typeMatch = RegExp(
    r'\)\s+[a-z,\s]*?\b([a-z]+)\s+damage',
    caseSensitive: false,
  ).firstMatch(source);
  final rawType = typeMatch?.group(1);
  final type = rawType == null || rawType.isEmpty
      ? null
      : '${rawType[0].toUpperCase()}${rawType.substring(1).toLowerCase()}';
  return _ParsedDamage(formula, type);
}

_ParsedSave? _extractSavingThrow(String text) {
  final patterns = <RegExp>[
    RegExp(
      r'dc\s*(\d+)\s*(strength|dexterity|constitution|intelligence|wisdom|charisma|str|dex|con|int|wis|cha)\s+saving throw',
      caseSensitive: false,
    ),
    RegExp(
      r'(strength|dexterity|constitution|intelligence|wisdom|charisma|str|dex|con|int|wis|cha)\s+saving throw.{0,24}?dc\s*(\d+)',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final first = match.group(1) ?? '';
    final second = match.group(2) ?? '';
    final firstNumber = int.tryParse(first);
    final dc = firstNumber ?? int.tryParse(second);
    final abilityText = firstNumber == null ? first : second;
    if (dc == null || abilityText.isEmpty) continue;
    return _ParsedSave(_normalizeAbilityLabel(abilityText), dc);
  }
  return null;
}

_ParsedArea? _extractAreaFromText(String text) {
  final normalized = text.toLowerCase();
  final shape = normalized.contains('cone')
      ? 'cone'
      : normalized.contains('line')
          ? 'line'
          : normalized.contains('cube')
              ? 'cube'
              : normalized.contains('sphere') ||
                      normalized.contains('radius') ||
                      normalized.contains('cylinder')
                  ? 'sphere'
                  : null;
  if (shape == null) return null;

  final feet = _firstAreaFeet(normalized, shape);
  if (feet == null || feet <= 0) return null;
  return _ParsedArea(shape, feet);
}

_ParsedRange? _extractAttackRangeFromText(String text) {
  final normalized = text.toLowerCase();
  final rangeSection =
      RegExp(r'range\s+(\d+)\s*/\s*(\d+)\s*ft', caseSensitive: false)
          .firstMatch(normalized);
  if (rangeSection != null) {
    final normal = int.tryParse(rangeSection.group(1) ?? '');
    final long = int.tryParse(rangeSection.group(2) ?? '');
    if (normal != null && normal > 0) {
      return _ParsedRange(normal, long);
    }
  }

  final explicitRange =
      RegExp(r'range\s+(\d+)\s*ft', caseSensitive: false).firstMatch(
    normalized,
  );
  if (explicitRange != null) {
    final normal = int.tryParse(explicitRange.group(1) ?? '');
    if (normal != null && normal > 0) return _ParsedRange(normal, null);
  }

  final reach = RegExp(r'reach\s+(\d+)\s*ft', caseSensitive: false).firstMatch(
    normalized,
  );
  if (reach != null) {
    final normal = int.tryParse(reach.group(1) ?? '');
    if (normal != null && normal > 0) return _ParsedRange(normal, null);
  }
  return null;
}

int? _firstAreaFeet(String text, String shape) {
  final patterns = <RegExp>[
    RegExp(
      '(\\d+)[-\\s]*(?:foot|feet|ft)[-\\s]*(?:radius[-\\s]*)?$shape',
    ),
    RegExp(
      '(\\d+)[-\\s]*(?:foot|feet|ft)[-\\s]*(?:long[-,\\s]*)?.{0,24}$shape',
    ),
    RegExp('$shape.{0,24}?(\\d+)[-\\s]*(?:foot|feet|ft)'),
    RegExp('(\\d+)[-\\s]*(?:foot|feet|ft)[-\\s]*radius'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final value = int.tryParse(match.group(1) ?? '');
    if (value != null && value > 0) return value;
  }
  return null;
}

bool _dealsHalfDamageOnSave(String text) {
  final normalized = text.toLowerCase();
  return normalized.contains('half as much') ||
      normalized.contains('half damage') ||
      normalized.contains('half the damage');
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

String? _normalizeImagePath(Object? raw) {
  final path = raw?.toString().trim();
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('assets/')) {
    return path;
  }
  if (path.startsWith('/')) {
    return '${SrdMonster.imageBaseUrl}$path';
  }
  return path;
}

int _parseArmorClass(Object? raw) {
  final direct = _optionalIntFromJson(raw);
  if (direct != null) return direct;
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first;
    final firstValue = _optionalIntFromJson(first);
    if (firstValue != null) return firstValue;
    if (first is Map) {
      final value = _optionalIntFromJson(first['value']);
      if (value != null) return value;
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
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, int> _parseSavingThrowBonuses(Object? raw) {
  final bonuses = <String, int>{};
  for (final item in _listOfMaps(raw)) {
    final proficiency = item['proficiency'];
    if (proficiency is! Map) continue;
    final name = '${proficiency['name'] ?? ''} ${proficiency['index'] ?? ''}'
        .toLowerCase();
    final match = RegExp(
      r'saving throw:\s*(str|dex|con|int|wis|cha|strength|dexterity|constitution|intelligence|wisdom|charisma)',
    ).firstMatch(name);
    if (match == null) continue;
    final ability = _normalizeAbilityLabel(match.group(1)!);
    final value = _optionalIntFromJson(item['value']);
    if (value != null) bonuses[ability] = value;
  }
  return bonuses;
}

int _intFromJson(Object? raw, {required int fallback}) {
  return _optionalIntFromJson(raw) ?? fallback;
}

int? _optionalIntFromJson(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toInt();
  final text = raw.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  final direct = num.tryParse(text);
  if (direct != null) return direct.toInt();
  final match = RegExp(r'-?\d+').firstMatch(text);
  if (match == null) return null;
  return int.tryParse(match.group(0)!);
}

int? _attackBonusFromDescription(String description) {
  final match = RegExp(
    r'([+-]\s*\d+)\s+to\s+hit',
    caseSensitive: false,
  ).firstMatch(description);
  if (match == null) return null;
  return int.tryParse((match.group(1) ?? '').replaceAll(' ', ''));
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

bool _looksLikeSrdStatBlock(Map<String, dynamic> json) {
  return json.containsKey('name') &&
      json.containsKey('armor_class') &&
      json.containsKey('hit_points') &&
      json.containsKey('challenge_rating');
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
