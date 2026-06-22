import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/combat_encounter.dart';
import '../models/custom_monster.dart';
import 'monster_repository.dart';

class CustomMonsterRepository {
  static const String _storageKey = 'custom_monster_bestiary_v1';

  const CustomMonsterRepository._();

  static Future<List<CustomMonster>> loadCustomMonsters() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_storageKey) ?? const [];
    final monsters = <CustomMonster>[];
    for (final item in items) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          final monster = CustomMonster.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (monster.id.trim().isNotEmpty) monsters.add(monster);
        }
      } catch (_) {
        // Ignore malformed local entries; the rest of the bestiary remains usable.
      }
    }
    monsters.sort((a, b) => a.name.compareTo(b.name));
    return monsters;
  }

  static Future<void> saveCustomMonsters(List<CustomMonster> monsters) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = monsters
        .map((monster) => jsonEncode(monster.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_storageKey, encoded);
  }

  static Future<List<CustomMonster>> upsertCustomMonster(
    CustomMonster monster,
  ) async {
    final monsters = await loadCustomMonsters();
    final index = monsters.indexWhere((item) => item.id == monster.id);
    final next = [...monsters];
    if (index == -1) {
      next.add(monster);
    } else {
      next[index] = monster;
    }
    next.sort((a, b) => a.name.compareTo(b.name));
    await saveCustomMonsters(next);
    return next;
  }

  static Future<List<CustomMonster>> deleteCustomMonster(String id) async {
    final monsters = await loadCustomMonsters();
    final next = monsters.where((monster) => monster.id != id).toList();
    await saveCustomMonsters(next);
    return next;
  }

  static MonsterCombatBuild buildCombatant({
    required CustomMonster monster,
    required int instanceNumber,
    String? displayName,
    int? initiativeSeed,
  }) {
    final id = 'custom_monster_${_normalizeKey(monster.id)}_$instanceNumber';
    final name = displayName ?? monster.name;
    final actions = _buildActions(monster: monster, combatantId: id);
    final passiveEffects = monster.actions
        .where((action) => action.timing == CombatActionTiming.passive)
        .map(
          (action) => CombatEffect(
            id: '$id:${_normalizeKey(action.id)}',
            name: action.name,
            kind: CombatEffectKind.buff,
            sourceCombatantId: id,
            targetCombatantId: id,
            visibleToPlayers: true,
            mechanics: {
              'source': 'customMonsterPassive',
              if (action.description.trim().isNotEmpty)
                'description': action.description.trim(),
            },
          ),
        )
        .toList(growable: false);

    return MonsterCombatBuild(
      combatant: Combatant(
        id: id,
        name: name,
        sourceId: monster.id,
        kind: CombatantKind.monster,
        team: CombatantTeam.enemy,
        role: monster.role,
        initiative: initiativeSeed ?? 10 + monster.initiativeBonus,
        initiativeBonus: monster.initiativeBonus,
        hp: monster.hitPoints,
        maxHp: monster.hitPoints,
        armorClass: monster.armorClass,
        speed: monster.speed,
        isHpVisibleToPlayers: !monster.hideHpFromPlayers,
        effects: passiveEffects,
        metadata: {
          'source': 'customMonster',
          'customMonsterId': monster.id,
          'monsterName': monster.name,
          'abilityScores': {
            'STR': monster.strength,
            'DEX': monster.dexterity,
            'CON': monster.constitution,
            'INT': monster.intelligence,
            'WIS': monster.wisdom,
            'CHA': monster.charisma,
          },
          if (monster.challengeRating != null)
            'challengeRating': monster.challengeRating,
          if (monster.portraitPath != null)
            'portraitPath': monster.portraitPath,
        },
      ),
      availableActions: actions,
    );
  }

  static List<PreparedCombatAction> _buildActions({
    required CustomMonster monster,
    required String combatantId,
  }) {
    return monster.actions
        .map((action) => _buildAction(monster, action))
        .map(
          (action) => action.copyWith(
            id: '$combatantId:${action.id}',
            actorId: combatantId,
          ),
        )
        .toList(growable: false);
  }

  static PreparedCombatAction _buildAction(
    CustomMonster monster,
    CustomMonsterAction action,
  ) {
    final multiattackSteps = _multiattackStepsFor(action, monster.actions);
    final tags = [
      'Custom',
      if (action.timing == CombatActionTiming.passive) 'Passive',
      if (action.timing == CombatActionTiming.reaction) 'Reaction',
      if (action.isRanged)
        'Ranged'
      else if (action.attackBonus != null)
        'Melee',
      if (action.damageType != null) action.damageType!,
      ...action.tags,
    ];

    if (multiattackSteps.isNotEmpty) {
      return PreparedCombatAction(
        id: 'custom:${monster.id}:action:${_normalizeKey(action.id)}',
        name: action.name,
        timing: action.timing,
        rollKind: CombatActionRollKind.attack,
        tags: [
          ...tags,
          'Multiattack',
          '${multiattackSteps.length} attacks',
        ],
        metadata: {
          'source': 'customMonster',
          'customMonsterId': monster.id,
          'monsterName': monster.name,
          'description': action.description,
          'multiattack': true,
          'multiAttackSteps': multiattackSteps,
        },
      );
    }

    final attackFormula = action.attackBonus == null
        ? null
        : _formatRollFormula('d20', action.attackBonus!);
    final damageFormula = _cleanFormula(action.damageFormula);
    final healingFormula = _cleanFormula(action.healingFormula);

    return PreparedCombatAction(
      id: 'custom:${monster.id}:action:${_normalizeKey(action.id)}',
      name: action.name,
      timing: action.timing,
      rollKind: action.rollKind,
      attackFormula: attackFormula,
      damageFormula: damageFormula,
      healingFormula: healingFormula,
      saveAbility: action.saveAbility,
      saveDc: action.saveDc,
      tags: tags,
      metadata: {
        'source': 'customMonster',
        'customMonsterId': monster.id,
        'monsterName': monster.name,
        'description': action.description,
        'targetsSelf': action.targetsSelf,
        if (action.halfDamageOnSave) 'halfDamageOnSave': true,
        if (damageFormula != null)
          'criticalDamageFormula': _doubleDice(damageFormula),
      },
    );
  }

  static List<Map<String, dynamic>> _multiattackStepsFor(
    CustomMonsterAction action,
    List<CustomMonsterAction> allActions,
  ) {
    if (action.multiattackSteps.isEmpty) return const [];
    final byName = {
      for (final candidate in allActions)
        _normalizeKey(candidate.name): candidate,
    };
    final steps = <Map<String, dynamic>>[];
    for (final entry in action.multiattackSteps) {
      final candidate = byName[_normalizeKey(entry.actionName)];
      if (candidate == null) continue;
      final attackFormula = candidate.attackBonus == null
          ? null
          : _formatRollFormula('d20', candidate.attackBonus!);
      final damageFormula = _cleanFormula(candidate.damageFormula);
      if (attackFormula == null && damageFormula == null) continue;
      final count = entry.count < 1 ? 1 : entry.count;
      for (var index = 0; index < count; index++) {
        steps.add({
          'name': candidate.name,
          'attackFormula': attackFormula,
          'damageFormula': damageFormula,
          if (damageFormula != null)
            'criticalDamageFormula': _doubleDice(damageFormula),
          'tags': [
            if (candidate.isRanged) 'Ranged' else 'Melee',
            if (candidate.damageType != null) candidate.damageType!,
            ...candidate.tags,
          ],
        });
      }
    }
    return steps;
  }

  static String newMonsterId(String name) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final base = _normalizeKey(name);
    return '${base.isEmpty ? 'custom-monster' : base}-$stamp';
  }

  static String newActionId(String name) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final base = _normalizeKey(name);
    return '${base.isEmpty ? 'action' : base}-$stamp';
  }
}

String _formatRollFormula(String dice, int modifier) {
  if (modifier == 0) return dice;
  return modifier > 0 ? '$dice+$modifier' : '$dice$modifier';
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

String _normalizeKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
