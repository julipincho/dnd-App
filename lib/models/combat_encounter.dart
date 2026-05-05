enum CombatEncounterStatus {
  draft,
  initiativeRequested,
  active,
  paused,
  completed,
}

enum CombatantTeam {
  party,
  enemy,
  neutral,
}

enum CombatantKind {
  playerCharacter,
  monster,
  npc,
  summon,
  hazard,
}

enum CombatActionTiming {
  action,
  bonusAction,
  reaction,
  movement,
  objectInteraction,
  free,
  passive,
  onHit,
  onDamageTaken,
  startOfTurn,
  endOfTurn,
}

enum CombatActionRollKind {
  none,
  attack,
  damage,
  healing,
  savingThrow,
  abilityCheck,
  resource,
}

enum CombatEffectKind {
  condition,
  concentration,
  resource,
  tempHp,
  buff,
  debuff,
  hidden,
}

enum CombatEventType {
  system,
  initiativeRequested,
  initiativeSet,
  encounterStarted,
  encounterPaused,
  encounterCompleted,
  turnStarted,
  actionPrepared,
  actionCleared,
  actionExecuted,
  damageApplied,
  healingApplied,
  conditionApplied,
  effectRemoved,
  reactionAvailable,
}

class CombatEncounter {
  final String id;
  final String? campaignId;
  final String? sessionId;
  final String name;
  final CombatEncounterStatus status;
  final int round;
  final int activeTurnIndex;
  final List<Combatant> combatants;
  final List<InitiativeEntry> initiativeOrder;
  final List<CombatEvent> events;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CombatEncounter({
    required this.id,
    this.campaignId,
    this.sessionId,
    required this.name,
    required this.status,
    required this.round,
    required this.activeTurnIndex,
    required this.combatants,
    required this.initiativeOrder,
    required this.events,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CombatEncounter.draft({
    required String id,
    required String name,
    String? campaignId,
    String? sessionId,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return CombatEncounter(
      id: id,
      campaignId: campaignId,
      sessionId: sessionId,
      name: name,
      status: CombatEncounterStatus.draft,
      round: 1,
      activeTurnIndex: 0,
      combatants: const [],
      initiativeOrder: const [],
      events: const [],
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory CombatEncounter.fromJson(Map<String, dynamic> json) {
    return CombatEncounter(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaignId']?.toString(),
      sessionId: json['sessionId']?.toString(),
      name: json['name']?.toString() ?? 'Encounter',
      status: _enumFromName(
        CombatEncounterStatus.values,
        json['status']?.toString(),
        CombatEncounterStatus.draft,
      ),
      round: (json['round'] as num?)?.toInt() ?? 1,
      activeTurnIndex: (json['activeTurnIndex'] as num?)?.toInt() ?? 0,
      combatants: _listOfMaps(json['combatants'])
          .map(Combatant.fromJson)
          .toList(growable: false),
      initiativeOrder: _listOfMaps(json['initiativeOrder'])
          .map(InitiativeEntry.fromJson)
          .toList(growable: false),
      events: _listOfMaps(json['events'])
          .map(CombatEvent.fromJson)
          .toList(growable: false),
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaignId': campaignId,
      'sessionId': sessionId,
      'name': name,
      'status': status.name,
      'round': round,
      'activeTurnIndex': activeTurnIndex,
      'combatants': combatants.map((item) => item.toJson()).toList(),
      'initiativeOrder': initiativeOrder.map((item) => item.toJson()).toList(),
      'events': events.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  CombatEncounter copyWith({
    String? id,
    String? campaignId,
    String? sessionId,
    String? name,
    CombatEncounterStatus? status,
    int? round,
    int? activeTurnIndex,
    List<Combatant>? combatants,
    List<InitiativeEntry>? initiativeOrder,
    List<CombatEvent>? events,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CombatEncounter(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      status: status ?? this.status,
      round: round ?? this.round,
      activeTurnIndex: activeTurnIndex ?? this.activeTurnIndex,
      combatants: combatants ?? this.combatants,
      initiativeOrder: initiativeOrder ?? this.initiativeOrder,
      events: events ?? this.events,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Combatant? get activeCombatant {
    if (initiativeOrder.isEmpty) return null;
    final safeIndex = activeTurnIndex.clamp(0, initiativeOrder.length - 1);
    final combatantId = initiativeOrder[safeIndex].combatantId;
    for (final combatant in combatants) {
      if (combatant.id == combatantId) return combatant;
    }
    return null;
  }
}

class Combatant {
  final String id;
  final String name;
  final String? sourceId;
  final CombatantKind kind;
  final CombatantTeam team;
  final String role;
  final int initiative;
  final int initiativeBonus;
  final int hp;
  final int maxHp;
  final int tempHp;
  final int armorClass;
  final int speed;
  final bool isVisibleToPlayers;
  final bool isHpVisibleToPlayers;
  final List<PreparedCombatAction> preparedActions;
  final List<CombatEffect> effects;
  final Map<String, int> resources;
  final Map<String, dynamic> metadata;

  const Combatant({
    required this.id,
    required this.name,
    this.sourceId,
    required this.kind,
    required this.team,
    required this.role,
    required this.initiative,
    required this.initiativeBonus,
    required this.hp,
    required this.maxHp,
    this.tempHp = 0,
    required this.armorClass,
    required this.speed,
    this.isVisibleToPlayers = true,
    this.isHpVisibleToPlayers = true,
    this.preparedActions = const [],
    this.effects = const [],
    this.resources = const {},
    this.metadata = const {},
  });

  bool get isDefeated => hp <= 0;

  double get hpRatio {
    if (maxHp <= 0) return 0;
    return (hp / maxHp).clamp(0.0, 1.0);
  }

  factory Combatant.fromJson(Map<String, dynamic> json) {
    return Combatant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sourceId: json['sourceId']?.toString(),
      kind: _enumFromName(
        CombatantKind.values,
        json['kind']?.toString(),
        CombatantKind.npc,
      ),
      team: _enumFromName(
        CombatantTeam.values,
        json['team']?.toString(),
        CombatantTeam.neutral,
      ),
      role: json['role']?.toString() ?? '',
      initiative: (json['initiative'] as num?)?.toInt() ?? 0,
      initiativeBonus: (json['initiativeBonus'] as num?)?.toInt() ?? 0,
      hp: (json['hp'] as num?)?.toInt() ?? 0,
      maxHp: (json['maxHp'] as num?)?.toInt() ?? 1,
      tempHp: (json['tempHp'] as num?)?.toInt() ?? 0,
      armorClass: (json['armorClass'] as num?)?.toInt() ?? 10,
      speed: (json['speed'] as num?)?.toInt() ?? 30,
      isVisibleToPlayers: json['isVisibleToPlayers'] as bool? ?? true,
      isHpVisibleToPlayers: json['isHpVisibleToPlayers'] as bool? ?? true,
      preparedActions: _listOfMaps(json['preparedActions'])
          .map(PreparedCombatAction.fromJson)
          .toList(growable: false),
      effects: _listOfMaps(json['effects'])
          .map(CombatEffect.fromJson)
          .toList(growable: false),
      resources: _stringIntMap(json['resources']),
      metadata: _dynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourceId': sourceId,
      'kind': kind.name,
      'team': team.name,
      'role': role,
      'initiative': initiative,
      'initiativeBonus': initiativeBonus,
      'hp': hp,
      'maxHp': maxHp,
      'tempHp': tempHp,
      'armorClass': armorClass,
      'speed': speed,
      'isVisibleToPlayers': isVisibleToPlayers,
      'isHpVisibleToPlayers': isHpVisibleToPlayers,
      'preparedActions': preparedActions.map((item) => item.toJson()).toList(),
      'effects': effects.map((item) => item.toJson()).toList(),
      'resources': resources,
      'metadata': metadata,
    };
  }

  Combatant copyWith({
    String? id,
    String? name,
    String? sourceId,
    CombatantKind? kind,
    CombatantTeam? team,
    String? role,
    int? initiative,
    int? initiativeBonus,
    int? hp,
    int? maxHp,
    int? tempHp,
    int? armorClass,
    int? speed,
    bool? isVisibleToPlayers,
    bool? isHpVisibleToPlayers,
    List<PreparedCombatAction>? preparedActions,
    List<CombatEffect>? effects,
    Map<String, int>? resources,
    Map<String, dynamic>? metadata,
  }) {
    return Combatant(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceId: sourceId ?? this.sourceId,
      kind: kind ?? this.kind,
      team: team ?? this.team,
      role: role ?? this.role,
      initiative: initiative ?? this.initiative,
      initiativeBonus: initiativeBonus ?? this.initiativeBonus,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      tempHp: tempHp ?? this.tempHp,
      armorClass: armorClass ?? this.armorClass,
      speed: speed ?? this.speed,
      isVisibleToPlayers: isVisibleToPlayers ?? this.isVisibleToPlayers,
      isHpVisibleToPlayers: isHpVisibleToPlayers ?? this.isHpVisibleToPlayers,
      preparedActions: preparedActions ?? this.preparedActions,
      effects: effects ?? this.effects,
      resources: resources ?? this.resources,
      metadata: metadata ?? this.metadata,
    );
  }
}

class InitiativeEntry {
  final String combatantId;
  final int initiative;
  final int tieBreaker;
  final bool hasActedThisRound;

  const InitiativeEntry({
    required this.combatantId,
    required this.initiative,
    this.tieBreaker = 0,
    this.hasActedThisRound = false,
  });

  factory InitiativeEntry.fromJson(Map<String, dynamic> json) {
    return InitiativeEntry(
      combatantId: json['combatantId']?.toString() ?? '',
      initiative: (json['initiative'] as num?)?.toInt() ?? 0,
      tieBreaker: (json['tieBreaker'] as num?)?.toInt() ?? 0,
      hasActedThisRound: json['hasActedThisRound'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'combatantId': combatantId,
      'initiative': initiative,
      'tieBreaker': tieBreaker,
      'hasActedThisRound': hasActedThisRound,
    };
  }

  InitiativeEntry copyWith({
    String? combatantId,
    int? initiative,
    int? tieBreaker,
    bool? hasActedThisRound,
  }) {
    return InitiativeEntry(
      combatantId: combatantId ?? this.combatantId,
      initiative: initiative ?? this.initiative,
      tieBreaker: tieBreaker ?? this.tieBreaker,
      hasActedThisRound: hasActedThisRound ?? this.hasActedThisRound,
    );
  }
}

class PreparedCombatAction {
  final String id;
  final String name;
  final CombatActionTiming timing;
  final CombatActionRollKind rollKind;
  final String? actorId;
  final String? targetId;
  final String? attackFormula;
  final String? damageFormula;
  final String? healingFormula;
  final String? saveAbility;
  final int? saveDc;
  final String? resourceKey;
  final int resourceCost;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  const PreparedCombatAction({
    required this.id,
    required this.name,
    required this.timing,
    required this.rollKind,
    this.actorId,
    this.targetId,
    this.attackFormula,
    this.damageFormula,
    this.healingFormula,
    this.saveAbility,
    this.saveDc,
    this.resourceKey,
    this.resourceCost = 0,
    this.tags = const [],
    this.metadata = const {},
  });

  factory PreparedCombatAction.fromJson(Map<String, dynamic> json) {
    return PreparedCombatAction(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      timing: _enumFromName(
        CombatActionTiming.values,
        json['timing']?.toString(),
        CombatActionTiming.action,
      ),
      rollKind: _enumFromName(
        CombatActionRollKind.values,
        json['rollKind']?.toString(),
        CombatActionRollKind.none,
      ),
      actorId: json['actorId']?.toString(),
      targetId: json['targetId']?.toString(),
      attackFormula: json['attackFormula']?.toString(),
      damageFormula: json['damageFormula']?.toString(),
      healingFormula: json['healingFormula']?.toString(),
      saveAbility: json['saveAbility']?.toString(),
      saveDc: (json['saveDc'] as num?)?.toInt(),
      resourceKey: json['resourceKey']?.toString(),
      resourceCost: (json['resourceCost'] as num?)?.toInt() ?? 0,
      tags: _stringList(json['tags']),
      metadata: _dynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'timing': timing.name,
      'rollKind': rollKind.name,
      'actorId': actorId,
      'targetId': targetId,
      'attackFormula': attackFormula,
      'damageFormula': damageFormula,
      'healingFormula': healingFormula,
      'saveAbility': saveAbility,
      'saveDc': saveDc,
      'resourceKey': resourceKey,
      'resourceCost': resourceCost,
      'tags': tags,
      'metadata': metadata,
    };
  }

  PreparedCombatAction copyWith({
    String? id,
    String? name,
    CombatActionTiming? timing,
    CombatActionRollKind? rollKind,
    String? actorId,
    String? targetId,
    String? attackFormula,
    String? damageFormula,
    String? healingFormula,
    String? saveAbility,
    int? saveDc,
    String? resourceKey,
    int? resourceCost,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return PreparedCombatAction(
      id: id ?? this.id,
      name: name ?? this.name,
      timing: timing ?? this.timing,
      rollKind: rollKind ?? this.rollKind,
      actorId: actorId ?? this.actorId,
      targetId: targetId ?? this.targetId,
      attackFormula: attackFormula ?? this.attackFormula,
      damageFormula: damageFormula ?? this.damageFormula,
      healingFormula: healingFormula ?? this.healingFormula,
      saveAbility: saveAbility ?? this.saveAbility,
      saveDc: saveDc ?? this.saveDc,
      resourceKey: resourceKey ?? this.resourceKey,
      resourceCost: resourceCost ?? this.resourceCost,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }
}

class CombatEffect {
  final String id;
  final String name;
  final CombatEffectKind kind;
  final String sourceCombatantId;
  final String targetCombatantId;
  final int? startedRound;
  final int? endsAtRound;
  final String? endsOn;
  final bool visibleToPlayers;
  final Map<String, dynamic> mechanics;

  const CombatEffect({
    required this.id,
    required this.name,
    required this.kind,
    required this.sourceCombatantId,
    required this.targetCombatantId,
    this.startedRound,
    this.endsAtRound,
    this.endsOn,
    this.visibleToPlayers = true,
    this.mechanics = const {},
  });

  factory CombatEffect.fromJson(Map<String, dynamic> json) {
    return CombatEffect(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: _enumFromName(
        CombatEffectKind.values,
        json['kind']?.toString(),
        CombatEffectKind.condition,
      ),
      sourceCombatantId: json['sourceCombatantId']?.toString() ?? '',
      targetCombatantId: json['targetCombatantId']?.toString() ?? '',
      startedRound: (json['startedRound'] as num?)?.toInt(),
      endsAtRound: (json['endsAtRound'] as num?)?.toInt(),
      endsOn: json['endsOn']?.toString(),
      visibleToPlayers: json['visibleToPlayers'] as bool? ?? true,
      mechanics: _dynamicMap(json['mechanics']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kind': kind.name,
      'sourceCombatantId': sourceCombatantId,
      'targetCombatantId': targetCombatantId,
      'startedRound': startedRound,
      'endsAtRound': endsAtRound,
      'endsOn': endsOn,
      'visibleToPlayers': visibleToPlayers,
      'mechanics': mechanics,
    };
  }

  CombatEffect copyWith({
    String? id,
    String? name,
    CombatEffectKind? kind,
    String? sourceCombatantId,
    String? targetCombatantId,
    int? startedRound,
    int? endsAtRound,
    String? endsOn,
    bool? visibleToPlayers,
    Map<String, dynamic>? mechanics,
  }) {
    return CombatEffect(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      sourceCombatantId: sourceCombatantId ?? this.sourceCombatantId,
      targetCombatantId: targetCombatantId ?? this.targetCombatantId,
      startedRound: startedRound ?? this.startedRound,
      endsAtRound: endsAtRound ?? this.endsAtRound,
      endsOn: endsOn ?? this.endsOn,
      visibleToPlayers: visibleToPlayers ?? this.visibleToPlayers,
      mechanics: mechanics ?? this.mechanics,
    );
  }
}

class CombatEvent {
  final String id;
  final CombatEventType type;
  final String title;
  final String? description;
  final String? actorId;
  final String? targetId;
  final String? actionId;
  final String? formula;
  final int? total;
  final int? amount;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const CombatEvent({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.actorId,
    this.targetId,
    this.actionId,
    this.formula,
    this.total,
    this.amount,
    required this.timestamp,
    this.metadata = const {},
  });

  factory CombatEvent.fromJson(Map<String, dynamic> json) {
    return CombatEvent(
      id: json['id']?.toString() ?? '',
      type: _enumFromName(
        CombatEventType.values,
        json['type']?.toString(),
        CombatEventType.system,
      ),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      actorId: json['actorId']?.toString(),
      targetId: json['targetId']?.toString(),
      actionId: json['actionId']?.toString(),
      formula: json['formula']?.toString(),
      total: (json['total'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toInt(),
      timestamp: _dateFromJson(json['timestamp']),
      metadata: _dynamicMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'actorId': actorId,
      'targetId': targetId,
      'actionId': actionId,
      'formula': formula,
      'total': total,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

List<Map<String, dynamic>> _listOfMaps(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

Map<String, int> _stringIntMap(dynamic value) {
  if (value is! Map) return const {};
  final output = <String, int>{};
  for (final entry in value.entries) {
    final rawValue = entry.value;
    if (rawValue is num) output[entry.key.toString()] = rawValue.toInt();
  }
  return output;
}

Map<String, dynamic> _dynamicMap(dynamic value) {
  if (value is! Map) return const {};
  return Map<String, dynamic>.from(value);
}

DateTime _dateFromJson(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

T _enumFromName<T extends Enum>(
  List<T> values,
  String? name,
  T fallback,
) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
