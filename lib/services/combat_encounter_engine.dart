import '../models/combat_encounter.dart';

class CombatEncounterEngine {
  const CombatEncounterEngine._();

  static CombatEncounter createDraft({
    required String name,
    String? id,
    String? campaignId,
    String? sessionId,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return CombatEncounter.draft(
      id: id ?? _newId('enc', timestamp),
      name: name,
      campaignId: campaignId,
      sessionId: sessionId,
      now: timestamp,
    ).withEvent(
      _event(
        type: CombatEventType.system,
        title: 'Encounter draft created.',
        now: timestamp,
      ),
      now: timestamp,
    );
  }

  static CombatEncounter addCombatant(
    CombatEncounter encounter,
    Combatant combatant, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final combatants = [
      ...encounter.combatants.where((item) => item.id != combatant.id),
      combatant,
    ];

    final initiativeOrder = _buildInitiativeOrder(combatants);
    return encounter
        .copyWith(
          combatants: combatants,
          initiativeOrder: initiativeOrder,
          updatedAt: timestamp,
        )
        .withEvent(
          _event(
            type: CombatEventType.system,
            title: '${combatant.name} joined the encounter.',
            actorId: combatant.id,
            now: timestamp,
          ),
          now: timestamp,
        );
  }

  static CombatEncounter requestInitiative(
    CombatEncounter encounter, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return encounter
        .copyWith(
          status: CombatEncounterStatus.initiativeRequested,
          updatedAt: timestamp,
        )
        .withEvent(
          _event(
            type: CombatEventType.initiativeRequested,
            title: 'Initiative requested.',
            now: timestamp,
          ),
          now: timestamp,
        );
  }

  static CombatEncounter setInitiative(
    CombatEncounter encounter, {
    required String combatantId,
    required int initiative,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final combatants = encounter.combatants.map((combatant) {
      if (combatant.id != combatantId) return combatant;
      return combatant.copyWith(initiative: initiative);
    }).toList(growable: false);

    final updated = encounter.copyWith(
      combatants: combatants,
      initiativeOrder: _buildInitiativeOrder(combatants),
      updatedAt: timestamp,
    );
    final combatant = updated.combatantById(combatantId);

    return updated.withEvent(
      _event(
        type: CombatEventType.initiativeSet,
        title:
            '${combatant?.name ?? 'Combatant'} initiative set to $initiative.',
        actorId: combatantId,
        total: initiative,
        now: timestamp,
      ),
      now: timestamp,
    );
  }

  static CombatEncounter startEncounter(
    CombatEncounter encounter, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final initiativeOrder = _buildInitiativeOrder(encounter.combatants);
    final activeIndex = initiativeOrder.isEmpty ? 0 : 0;
    final activeId = initiativeOrder.isEmpty
        ? null
        : initiativeOrder[activeIndex].combatantId;
    final active = activeId == null ? null : encounter.combatantById(activeId);

    return encounter
        .copyWith(
          status: CombatEncounterStatus.active,
          round: encounter.round <= 0 ? 1 : encounter.round,
          activeTurnIndex: activeIndex,
          initiativeOrder: initiativeOrder,
          updatedAt: timestamp,
        )
        .withEvent(
          _event(
            type: CombatEventType.encounterStarted,
            title: 'Encounter started.',
            now: timestamp,
          ),
          now: timestamp,
        )
        .withEvent(
          _event(
            type: CombatEventType.turnStarted,
            title: active == null
                ? 'No active turn.'
                : '${active.name} turn started.',
            actorId: active?.id,
            now: timestamp,
          ),
          now: timestamp,
        );
  }

  static CombatEncounter pauseEncounter(
    CombatEncounter encounter, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return encounter
        .copyWith(
          status: CombatEncounterStatus.paused,
          updatedAt: timestamp,
        )
        .withEvent(
          _event(
            type: CombatEventType.encounterPaused,
            title: 'Encounter paused.',
            now: timestamp,
          ),
          now: timestamp,
        );
  }

  static CombatEncounter completeEncounter(
    CombatEncounter encounter, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return encounter
        .copyWith(
          status: CombatEncounterStatus.completed,
          updatedAt: timestamp,
        )
        .withEvent(
          _event(
            type: CombatEventType.encounterCompleted,
            title: 'Encounter completed.',
            now: timestamp,
          ),
          now: timestamp,
        );
  }

  static CombatEncounter nextTurn(
    CombatEncounter encounter, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    if (encounter.initiativeOrder.isEmpty) return encounter;

    final currentIndex = encounter.activeTurnIndex
        .clamp(0, encounter.initiativeOrder.length - 1);
    final currentEntry = encounter.initiativeOrder[currentIndex];
    var nextIndex = currentIndex + 1;
    var nextRound = encounter.round;

    var order = encounter.initiativeOrder.map((entry) {
      if (entry.combatantId != currentEntry.combatantId) return entry;
      return entry.copyWith(hasActedThisRound: true);
    }).toList(growable: false);

    if (nextIndex >= order.length) {
      nextIndex = 0;
      nextRound += 1;
      order = order
          .map((entry) => entry.copyWith(hasActedThisRound: false))
          .toList(growable: false);
    }

    final nextId = order[nextIndex].combatantId;
    final nextCombatant = encounter.combatantById(nextId);
    return encounter
        .copyWith(
          round: nextRound,
          activeTurnIndex: nextIndex,
          initiativeOrder: order,
          updatedAt: timestamp,
        )
        .withEvent(
          _event(
            type: CombatEventType.turnStarted,
            title: nextCombatant == null
                ? 'Next turn started.'
                : '${nextCombatant.name} turn started.',
            actorId: nextId,
            now: timestamp,
          ),
          now: timestamp,
        );
  }

  static CombatEncounter prepareAction(
    CombatEncounter encounter, {
    required String combatantId,
    required PreparedCombatAction action,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return _updateCombatant(
      encounter,
      combatantId,
      (combatant) {
        final actionWithActor = action.copyWith(actorId: combatantId);
        final actions = [
          ...combatant.preparedActions
              .where((item) => item.timing != actionWithActor.timing),
          actionWithActor,
        ];
        return combatant.copyWith(preparedActions: actions);
      },
      event: _event(
        type: CombatEventType.actionPrepared,
        title: '${action.name} prepared.',
        actorId: combatantId,
        targetId: action.targetId,
        actionId: action.id,
        now: timestamp,
      ),
      now: timestamp,
    );
  }

  static CombatEncounter clearPreparedAction(
    CombatEncounter encounter, {
    required String combatantId,
    required CombatActionTiming timing,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return _updateCombatant(
      encounter,
      combatantId,
      (combatant) {
        return combatant.copyWith(
          preparedActions: combatant.preparedActions
              .where((action) => action.timing != timing)
              .toList(growable: false),
        );
      },
      event: _event(
        type: CombatEventType.actionCleared,
        title: '${timing.name} plan cleared.',
        actorId: combatantId,
        now: timestamp,
      ),
      now: timestamp,
    );
  }

  static CombatEncounter applyDamage(
    CombatEncounter encounter, {
    required String sourceId,
    required String targetId,
    required int amount,
    String? actionId,
    String? formula,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final target = encounter.combatantById(targetId);
    if (target == null) return encounter;

    final absorbedByTemp = target.tempHp.clamp(0, amount);
    final remainingDamage = amount - absorbedByTemp;
    final nextHp = (target.hp - remainingDamage).clamp(0, target.maxHp);
    final nextTempHp = target.tempHp - absorbedByTemp;

    return _updateCombatant(
      encounter,
      targetId,
      (combatant) => combatant.copyWith(
        hp: nextHp,
        tempHp: nextTempHp,
      ),
      event: _event(
        type: CombatEventType.damageApplied,
        title: '${target.name} takes $amount damage.',
        actorId: sourceId,
        targetId: targetId,
        actionId: actionId,
        formula: formula,
        amount: amount,
        now: timestamp,
        metadata: {
          'absorbedByTempHp': absorbedByTemp,
          'previousHp': target.hp,
          'nextHp': nextHp,
          'previousTempHp': target.tempHp,
          'nextTempHp': nextTempHp,
        },
      ),
      now: timestamp,
    );
  }

  static CombatEncounter applyHealing(
    CombatEncounter encounter, {
    required String sourceId,
    required String targetId,
    required int amount,
    String? actionId,
    String? formula,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final target = encounter.combatantById(targetId);
    if (target == null) return encounter;

    final nextHp = (target.hp + amount).clamp(0, target.maxHp);
    return _updateCombatant(
      encounter,
      targetId,
      (combatant) => combatant.copyWith(hp: nextHp),
      event: _event(
        type: CombatEventType.healingApplied,
        title: '${target.name} recovers $amount HP.',
        actorId: sourceId,
        targetId: targetId,
        actionId: actionId,
        formula: formula,
        amount: amount,
        now: timestamp,
        metadata: {
          'previousHp': target.hp,
          'nextHp': nextHp,
        },
      ),
      now: timestamp,
    );
  }

  static CombatEncounter applyEffect(
    CombatEncounter encounter, {
    required CombatEffect effect,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return _updateCombatant(
      encounter,
      effect.targetCombatantId,
      (combatant) {
        final effects = [
          ...combatant.effects.where((item) => item.id != effect.id),
          effect,
        ];
        return combatant.copyWith(effects: effects);
      },
      event: _event(
        type: CombatEventType.conditionApplied,
        title: '${effect.name} applied.',
        actorId: effect.sourceCombatantId,
        targetId: effect.targetCombatantId,
        now: timestamp,
        metadata: effect.toJson(),
      ),
      now: timestamp,
    );
  }

  static CombatEncounter removeEffect(
    CombatEncounter encounter, {
    required String targetId,
    required String effectId,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return _updateCombatant(
      encounter,
      targetId,
      (combatant) {
        return combatant.copyWith(
          effects: combatant.effects
              .where((effect) => effect.id != effectId)
              .toList(growable: false),
        );
      },
      event: _event(
        type: CombatEventType.effectRemoved,
        title: 'Effect removed.',
        targetId: targetId,
        now: timestamp,
        metadata: {'effectId': effectId},
      ),
      now: timestamp,
    );
  }

  static CombatEncounter spendResource(
    CombatEncounter encounter, {
    required String combatantId,
    required String resourceKey,
    int amount = 1,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return _updateCombatant(
      encounter,
      combatantId,
      (combatant) {
        final resources = Map<String, int>.from(combatant.resources);
        final current = resources[resourceKey] ?? 0;
        resources[resourceKey] = (current - amount).clamp(0, current);
        return combatant.copyWith(resources: resources);
      },
      event: _event(
        type: CombatEventType.actionExecuted,
        title: '$resourceKey spent.',
        actorId: combatantId,
        amount: amount,
        now: timestamp,
      ),
      now: timestamp,
    );
  }

  static CombatEncounter _updateCombatant(
    CombatEncounter encounter,
    String combatantId,
    Combatant Function(Combatant combatant) update, {
    required CombatEvent event,
    required DateTime now,
  }) {
    var found = false;
    final combatants = encounter.combatants.map((combatant) {
      if (combatant.id != combatantId) return combatant;
      found = true;
      return update(combatant);
    }).toList(growable: false);
    if (!found) return encounter;

    return encounter
        .copyWith(
          combatants: combatants,
          updatedAt: now,
        )
        .withEvent(event, now: now);
  }

  static List<InitiativeEntry> _buildInitiativeOrder(
    List<Combatant> combatants,
  ) {
    final entries = combatants
        .where((combatant) => !combatant.isDefeated)
        .map(
          (combatant) => InitiativeEntry(
            combatantId: combatant.id,
            initiative: combatant.initiative,
            tieBreaker: combatant.initiativeBonus,
          ),
        )
        .toList();

    entries.sort((a, b) {
      final initiativeCompare = b.initiative.compareTo(a.initiative);
      if (initiativeCompare != 0) return initiativeCompare;
      return b.tieBreaker.compareTo(a.tieBreaker);
    });
    return entries;
  }

  static CombatEvent _event({
    required CombatEventType type,
    required String title,
    required DateTime now,
    String? description,
    String? actorId,
    String? targetId,
    String? actionId,
    String? formula,
    int? total,
    int? amount,
    Map<String, dynamic> metadata = const {},
  }) {
    return CombatEvent(
      id: _newId(
        'evt',
        now,
        '${type.name}_${actorId}_${targetId}_$actionId',
      ),
      type: type,
      title: title,
      description: description,
      actorId: actorId,
      targetId: targetId,
      actionId: actionId,
      formula: formula,
      total: total,
      amount: amount,
      timestamp: now,
      metadata: metadata,
    );
  }

  static String _newId(String prefix, DateTime timestamp, [String? salt]) {
    final suffix = salt == null ? '' : '_${salt.hashCode.abs()}';
    return '${prefix}_${timestamp.microsecondsSinceEpoch}$suffix';
  }
}

extension CombatEncounterLookup on CombatEncounter {
  Combatant? combatantById(String id) {
    for (final combatant in combatants) {
      if (combatant.id == id) return combatant;
    }
    return null;
  }

  CombatEncounter withEvent(CombatEvent event, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return copyWith(
      events: [event, ...events],
      updatedAt: timestamp,
    );
  }
}
