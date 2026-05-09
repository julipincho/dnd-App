import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/dice/models/dice_roll_result.dart';
import '../features/dice/services/dice_roller_service.dart';
import '../models/character.dart';
import '../models/combat_encounter.dart' as encounter_models;
import '../providers/campaign_provider.dart';
import '../providers/compendium_provider.dart';
import '../providers/character_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/spell_provider.dart';
import '../services/character_combat_builder_service.dart';
import '../services/combat_encounter_engine.dart';
import '../services/monster_repository.dart';
import '../theme.dart';

class CombatModeScreen extends StatefulWidget {
  final String? characterId;
  final String? campaignId;

  const CombatModeScreen({
    super.key,
    this.characterId,
    this.campaignId,
  });

  @override
  State<CombatModeScreen> createState() => _CombatModeScreenState();
}

class _CombatModeScreenState extends State<CombatModeScreen> {
  late List<_Combatant> _combatants;
  late List<_CombatLogEntry> _activity;
  late List<_CombatAction> _characterActions;
  encounter_models.CombatEncounter? _encounter;
  final Map<String, encounter_models.PreparedCombatAction> _engineActions = {};
  final Map<String, List<_CombatAction>> _partyActionsByCombatantId = {};
  final Map<String, List<_CombatAction>> _enemyActionsByCombatantId = {};
  _CombatRollFeedback? _rollFeedback;
  final Set<String> _spentTimings = {};
  final Set<String> _pendingDamageActions = {};
  final Set<String> _pendingHalfDamageActions = {};
  final Map<String, _CombatAction> _preparedActions = {};
  final List<_CombatAction> _queuedPreparedActions = [];
  int _queuedPreparedIndex = 0;
  int _activeIndex = 0;
  int _targetIndex = 2;
  int _round = 1;
  String _selectedCommandTiming = 'Action';
  _CombatWorkspace _workspace = _CombatWorkspace.turn;
  bool _dmView = true;
  bool _seededMonsters = false;
  String? _seededCharacterId;
  String? _loadingCampaignId;
  String? _loadedPartyCampaignId;

  String? get _queuedPreparedActionName {
    if (_queuedPreparedActions.isEmpty ||
        _queuedPreparedIndex < 0 ||
        _queuedPreparedIndex >= _queuedPreparedActions.length) {
      return null;
    }
    return _queuedPreparedActions[_queuedPreparedIndex].name;
  }

  static const List<_CombatAction> _playerActions = [
    _CombatAction(
      name: 'Longsword Strike',
      type: 'Weapon Attack',
      timing: 'Action',
      attackFormula: 'd20+7',
      damageFormula: '1d8+4',
      critFormula: '2d8+4',
      tags: ['Melee', 'Slashing', 'Prepared'],
      icon: Icons.gavel_outlined,
      accentKind: _CombatAccentKind.action,
    ),
    _CombatAction(
      name: 'Fire Bolt',
      type: 'Spell Attack',
      timing: 'Action',
      attackFormula: 'd20+6',
      damageFormula: '2d10',
      critFormula: '4d10',
      tags: ['Ranged', 'Fire', 'Cantrip'],
      icon: Icons.local_fire_department_outlined,
      accentKind: _CombatAccentKind.magic,
    ),
    _CombatAction(
      name: 'Second Wind',
      type: 'Feature',
      timing: 'Bonus Action',
      attackFormula: null,
      damageFormula: '1d10+3',
      critFormula: null,
      tags: ['Healing', '1 / Short Rest'],
      icon: Icons.favorite_border,
      accentKind: _CombatAccentKind.support,
      targetsSelf: true,
      isHealing: true,
    ),
  ];

  static const List<_CombatAction> _enemyActions = [
    _CombatAction(
      name: 'Commander Blade',
      type: 'Weapon Attack',
      timing: 'Action',
      attackFormula: 'd20+5',
      damageFormula: '1d8+3',
      critFormula: '2d8+3',
      tags: ['Melee', 'Martial', 'Enemy'],
      icon: Icons.gavel_outlined,
      accentKind: _CombatAccentKind.action,
    ),
    _CombatAction(
      name: 'Shortbow Shot',
      type: 'Ranged Attack',
      timing: 'Action',
      attackFormula: 'd20+4',
      damageFormula: '1d6+2',
      critFormula: '2d6+2',
      tags: ['Ranged', 'Piercing', 'Enemy'],
      icon: Icons.ads_click_outlined,
      accentKind: _CombatAccentKind.read,
    ),
    _CombatAction(
      name: 'Rallying Cry',
      type: 'Monster Feature',
      timing: 'Bonus Action',
      attackFormula: null,
      damageFormula: '1d6+2',
      critFormula: null,
      tags: ['Morale', 'Healing', 'Enemy'],
      icon: Icons.record_voice_over_outlined,
      accentKind: _CombatAccentKind.support,
      targetsSelf: true,
      isHealing: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _combatants = _buildDefaultCombatants();
    _characterActions = _playerActions;
    _activity = [
      _CombatLogEntry.system(
        'Encounter prototype ready. Initiative order is loaded.',
      ),
    ];
    _encounter = _createEncounterFromCombatants(_combatants);
    _syncUiFromEncounter();
    _loadRealDemoMonsters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _seedCombatContextIfNeeded(listenToCampaign: true);
  }

  @override
  void didUpdateWidget(covariant CombatModeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.characterId == widget.characterId &&
        oldWidget.campaignId == widget.campaignId) {
      return;
    }

    setState(_resetCombatStateForNewScope);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _seedCombatContextIfNeeded(listenToCampaign: false);
    });
  }

  void _seedCombatContextIfNeeded({required bool listenToCampaign}) {
    final characterId = widget.characterId;
    if (characterId != null && characterId.trim().isNotEmpty) {
      if (_seededCharacterId == characterId) return;
      _seedCharacterCombat(characterId);
      return;
    }

    final campaignId = _resolvedCampaignId(listen: listenToCampaign);
    if (campaignId == null || campaignId.isEmpty) return;
    if (_loadedPartyCampaignId == campaignId ||
        _loadingCampaignId == campaignId) {
      return;
    }

    final equipmentProvider = context.read<EquipmentProvider>();
    final compendiumProvider = context.read<CompendiumProvider>();
    final spellProvider = context.read<SpellProvider>();
    _loadCampaignPartyById(
      campaignId: campaignId,
      equipmentProvider: equipmentProvider,
      compendiumProvider: compendiumProvider,
      spellProvider: spellProvider,
      force: true,
    );
  }

  String? _resolvedCampaignId({required bool listen}) {
    final explicit = widget.campaignId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final activeCampaign = listen
        ? context.watch<CampaignProvider>().activeCampaign
        : context.read<CampaignProvider>().activeCampaign;
    final campaignId = activeCampaign?.id.trim();
    return campaignId == null || campaignId.isEmpty ? null : campaignId;
  }

  void _seedCharacterCombat(String characterId) {
    final character =
        context.read<CharacterProvider>().getCharacterById(characterId);
    if (character == null) return;
    final equipmentProvider = context.read<EquipmentProvider>();
    final compendiumProvider = context.read<CompendiumProvider>();
    final spellProvider = context.read<SpellProvider>();

    final combatBuild = _buildCharacterCombat(
      character,
      equipmentProvider,
      compendiumProvider,
      spellProvider,
    );
    final previousPrimaryId = _combatants.isEmpty ? null : _combatants.first.id;
    final stagedCombatants = _stagedEngineCombatants(
      excludingId: previousPrimaryId,
    );
    _registerCharacterActions(
      combatantId: combatBuild.combatant.id,
      actions: combatBuild.availableActions,
      primary: true,
    );
    _combatants = [
      _combatantFromEngineCombatant(combatBuild.combatant),
      ..._combatants.skip(1),
    ];
    _encounter = _createEncounterFromEngineCombatants([
      combatBuild.combatant,
      ...stagedCombatants,
    ]);
    _syncUiFromEncounter();
    _activeIndex = 0;
    _targetIndex = _findDefaultTargetIndex(_activeIndex);
    _activity = [
      _CombatLogEntry.system(
        '${character.name} entered Combat Mode. Demo enemies are staged.',
      ),
      ..._activity,
    ];
    _seededCharacterId = characterId;
    _loadCampaignParty(
      anchorCharacter: character,
      equipmentProvider: equipmentProvider,
      compendiumProvider: compendiumProvider,
      spellProvider: spellProvider,
    );

    if (!spellProvider.isLoaded) {
      spellProvider.loadSpells().then((_) {
        if (!mounted) return;
        setState(() {
          final combatBuild = _buildCharacterCombat(
            character,
            equipmentProvider,
            compendiumProvider,
            spellProvider,
          );
          final previousPrimaryId =
              _combatants.isEmpty ? null : _combatants.first.id;
          final stagedCombatants = _stagedEngineCombatants(
            excludingId: previousPrimaryId,
          );
          _registerCharacterActions(
            combatantId: combatBuild.combatant.id,
            actions: combatBuild.availableActions,
            primary: true,
          );
          _combatants = [
            _combatantFromEngineCombatant(combatBuild.combatant),
            ..._combatants.skip(1),
          ];
          _encounter = _createEncounterFromEngineCombatants([
            combatBuild.combatant,
            ...stagedCombatants,
          ]);
          _syncUiFromEncounter();
        });
        _loadCampaignParty(
          anchorCharacter: character,
          equipmentProvider: equipmentProvider,
          compendiumProvider: compendiumProvider,
          spellProvider: spellProvider,
          force: true,
        );
      });
    }
  }

  void _resetCombatStateForNewScope() {
    _combatants = _buildDefaultCombatants();
    _characterActions = _playerActions;
    _activity = [
      _CombatLogEntry.system(
        'Encounter prototype ready. Initiative order is loaded.',
      ),
    ];
    _engineActions.clear();
    _partyActionsByCombatantId.clear();
    _enemyActionsByCombatantId.clear();
    _encounter = _createEncounterFromCombatants(_combatants);
    _syncUiFromEncounter();
    _rollFeedback = null;
    _spentTimings.clear();
    _pendingDamageActions.clear();
    _pendingHalfDamageActions.clear();
    _preparedActions.clear();
    _resetQueuedPreparedActions();
    _activeIndex = 0;
    _targetIndex = _findDefaultTargetIndex(_activeIndex);
    _round = 1;
    _selectedCommandTiming = 'Action';
    _workspace = _CombatWorkspace.turn;
    _seededMonsters = false;
    _seededCharacterId = null;
    _loadingCampaignId = null;
    _loadedPartyCampaignId = null;
    _loadRealDemoMonsters(force: true);
  }

  CharacterCombatBuild _buildCharacterCombat(
    Character character,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
    SpellProvider spellProvider,
  ) {
    return CharacterCombatBuilderService.build(
      character: character,
      equipmentItems: equipmentProvider.items,
      compendiumEntries: compendiumProvider.entries,
      spells: spellProvider.spells,
    );
  }

  void _registerCharacterActions({
    required String combatantId,
    required List<encounter_models.PreparedCombatAction> actions,
    bool primary = false,
  }) {
    final resolvedActions = actions
        .map((action) => action.copyWith(actorId: combatantId))
        .toList(growable: false);
    _engineActions
      ..removeWhere(
        (id, action) =>
            id.startsWith('${combatantId}_') || action.actorId == combatantId,
      )
      ..addEntries(
        resolvedActions.map((action) => MapEntry(action.id, action)),
      );

    final uiActions = resolvedActions
        .map(_combatActionFromPreparedAction)
        .toList(growable: false);
    _partyActionsByCombatantId[combatantId] = uiActions;
    if (primary) {
      _characterActions = uiActions;
    }
  }

  Future<void> _loadCampaignParty({
    required Character anchorCharacter,
    required EquipmentProvider equipmentProvider,
    required CompendiumProvider compendiumProvider,
    required SpellProvider spellProvider,
    bool force = false,
  }) async {
    final campaignId = anchorCharacter.campaignId?.trim();
    if (campaignId == null || campaignId.isEmpty) return;
    if (!force && _loadedPartyCampaignId == campaignId) return;
    final resetEncounterScope = force || _loadedPartyCampaignId != campaignId;

    final characterProvider = context.read<CharacterProvider>();
    if (characterProvider.getCharactersByCampaignSafe(campaignId).isEmpty) {
      await characterProvider.loadCampaignCharacters(campaignId);
    }
    if (!mounted) return;

    final campaignCharacters =
        characterProvider.getCharactersByCampaignSafe(campaignId);
    if (campaignCharacters.isEmpty) return;

    final orderedCharacters = _orderedPartyCharacters(
      anchorCharacter: anchorCharacter,
      campaignCharacters: campaignCharacters,
    );
    final partyBuilds = orderedCharacters
        .map(
          (character) => _buildCharacterCombat(
            character,
            equipmentProvider,
            compendiumProvider,
            spellProvider,
          ),
        )
        .toList(growable: false);
    final enemyCombatants = resetEncounterScope
        ? _freshDemoEnemyCombatants()
        : _currentEnemyCombatants();

    setState(() {
      _engineActions
          .removeWhere((_, action) => !_isMonsterActionSource(action));
      _partyActionsByCombatantId.clear();

      for (final build in partyBuilds) {
        _registerCharacterActions(
          combatantId: build.combatant.id,
          actions: build.availableActions,
          primary: build.combatant.sourceId == anchorCharacter.id,
        );
      }

      _encounter = _createEncounterFromEngineCombatants([
        ...partyBuilds.map((build) => build.combatant),
        ...enemyCombatants,
      ]);
      _syncUiFromEncounter();
      _targetIndex = _findDefaultTargetIndex(_activeIndex);
      _spentTimings.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _rollFeedback = _CombatRollFeedback.manual(
        actor: 'DM',
        action: 'Combat begins',
        headline: 'COMBAT BEGINS',
        subline: '${partyBuilds.length} heroes enter initiative.',
        accentKind: _CombatAccentKind.magic,
      );
      _activity = [
        _CombatLogEntry.turn(
          'Combat begins. ${partyBuilds.length} campaign characters joined the encounter.',
        ),
        ..._activity,
      ];
      _loadedPartyCampaignId = campaignId;
      _loadingCampaignId = null;
    });

    if (resetEncounterScope) {
      _loadRealDemoMonsters(force: true);
    }
  }

  Future<void> _loadCampaignPartyById({
    required String campaignId,
    required EquipmentProvider equipmentProvider,
    required CompendiumProvider compendiumProvider,
    required SpellProvider spellProvider,
    bool force = false,
  }) async {
    final normalizedCampaignId = campaignId.trim();
    if (normalizedCampaignId.isEmpty) return;
    if (!force && _loadedPartyCampaignId == normalizedCampaignId) return;

    _loadingCampaignId = normalizedCampaignId;
    final characterProvider = context.read<CharacterProvider>();
    if (characterProvider
        .getCharactersByCampaignSafe(normalizedCampaignId)
        .isEmpty) {
      await characterProvider.loadCampaignCharacters(normalizedCampaignId);
    }
    if (!mounted) return;

    final campaignCharacters =
        characterProvider.getCharactersByCampaignSafe(normalizedCampaignId);
    if (campaignCharacters.isEmpty) {
      setState(() {
        _loadingCampaignId = null;
        _loadedPartyCampaignId = normalizedCampaignId;
        _activity.insert(
          0,
          _CombatLogEntry.system(
            'Combat opened for this campaign, but no party characters were found.',
          ),
        );
      });
      return;
    }

    await _loadCampaignParty(
      anchorCharacter: campaignCharacters.first,
      equipmentProvider: equipmentProvider,
      compendiumProvider: compendiumProvider,
      spellProvider: spellProvider,
      force: force,
    );
  }

  List<Character> _orderedPartyCharacters({
    required Character anchorCharacter,
    required List<Character> campaignCharacters,
  }) {
    final seen = <String>{};
    final ordered = <Character>[];

    void add(Character character) {
      final id = character.id.trim();
      if (id.isEmpty || seen.contains(id)) return;
      seen.add(id);
      ordered.add(character);
    }

    add(anchorCharacter);
    for (final character in campaignCharacters) {
      add(character);
    }

    return ordered;
  }

  List<encounter_models.Combatant> _currentEnemyCombatants() {
    final encounterEnemies =
        (_encounter?.combatants ?? const <encounter_models.Combatant>[])
            .where((combatant) =>
                combatant.team == encounter_models.CombatantTeam.enemy)
            .toList(growable: false);
    if (encounterEnemies.isNotEmpty) return encounterEnemies;

    return _combatants
        .where((combatant) => combatant.team == _CombatTeam.enemy)
        .map(_engineCombatantFromUi)
        .toList(growable: false);
  }

  List<encounter_models.Combatant> _freshDemoEnemyCombatants() {
    return _buildDefaultCombatants()
        .where((combatant) => combatant.team == _CombatTeam.enemy)
        .map(_engineCombatantFromUi)
        .toList(growable: false);
  }

  List<encounter_models.Combatant> _stagedEngineCombatants({
    String? excludingId,
  }) {
    final current = _encounter?.combatants ??
        _combatants.map(_engineCombatantFromUi).toList(growable: false);
    return [
      for (final combatant in current)
        if (combatant.id != excludingId) combatant,
    ];
  }

  bool _isMonsterActionSource(encounter_models.PreparedCombatAction action) {
    final source = action.metadata['source']?.toString();
    return source == 'monster' || source == 'monsterFeature';
  }

  Future<void> _loadRealDemoMonsters({bool force = false}) async {
    if (_seededMonsters && !force) return;

    try {
      final monsters = await Future.wait([
        MonsterRepository.findByIndex('hobgoblin'),
        MonsterRepository.findByIndex('goblin'),
      ]);
      final hobgoblin = monsters[0];
      final goblin = monsters[1];
      if (!mounted || hobgoblin == null || goblin == null) return;

      final builds = [
        MonsterRepository.buildCombatant(
          monster: hobgoblin,
          instanceNumber: 1,
        ),
        MonsterRepository.buildCombatant(
          monster: goblin,
          instanceNumber: 1,
        ),
      ];

      setState(() {
        final partyCombatants =
            (_encounter?.combatants ?? const <encounter_models.Combatant>[])
                .where(
                  (combatant) =>
                      combatant.team == encounter_models.CombatantTeam.party,
                )
                .toList(growable: false);
        final fallbackParty = _combatants
            .where((combatant) => combatant.team == _CombatTeam.party)
            .map(_engineCombatantFromUi)
            .toList(growable: false);
        final party = partyCombatants.isEmpty ? fallbackParty : partyCombatants;

        _engineActions
          ..removeWhere((_, action) => _isMonsterActionSource(action))
          ..addEntries(
            builds.expand(
              (build) => build.availableActions.map(
                (action) => MapEntry(action.id, action),
              ),
            ),
          );

        _enemyActionsByCombatantId
          ..clear()
          ..addEntries(
            builds.map(
              (build) => MapEntry(
                build.combatant.id,
                build.availableActions
                    .map(_combatActionFromPreparedAction)
                    .toList(growable: false),
              ),
            ),
          );

        _encounter = _createEncounterFromEngineCombatants([
          ...party,
          ...builds.map((build) => build.combatant),
        ]);
        _syncUiFromEncounter();
        _activeIndex = _activeIndex.clamp(0, _combatants.length - 1).toInt();
        _targetIndex = _findDefaultTargetIndex(_activeIndex);
        _activity = [
          _CombatLogEntry.system(
            'SRD monsters loaded: Hobgoblin and Goblin are now using real statblocks.',
          ),
          ..._activity,
        ];
        _seededMonsters = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            'Could not load SRD monsters. Demo enemies remain available.',
          ),
        );
      });
    }
  }

  encounter_models.CombatEncounter _createEncounterFromCombatants(
    List<_Combatant> combatants,
  ) {
    return _createEncounterFromEngineCombatants(
      combatants.map(_engineCombatantFromUi).toList(growable: false),
    );
  }

  encounter_models.CombatEncounter _createEncounterFromEngineCombatants(
    List<encounter_models.Combatant> combatants,
  ) {
    var encounter = CombatEncounterEngine.createDraft(
      id: 'local_combat_mode',
      name: 'Combat Mode Prototype',
    );
    for (final combatant in combatants) {
      encounter = CombatEncounterEngine.addCombatant(encounter, combatant);
    }
    return CombatEncounterEngine.startEncounter(encounter);
  }

  encounter_models.Combatant _engineCombatantFromUi(_Combatant combatant) {
    final id = combatant.id.isEmpty
        ? 'ui_${combatant.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}'
        : combatant.id;
    return encounter_models.Combatant(
      id: id,
      name: combatant.name,
      kind: combatant.team == _CombatTeam.party
          ? encounter_models.CombatantKind.playerCharacter
          : encounter_models.CombatantKind.monster,
      team: combatant.team == _CombatTeam.party
          ? encounter_models.CombatantTeam.party
          : encounter_models.CombatantTeam.enemy,
      role: combatant.role,
      initiative: combatant.initiative,
      initiativeBonus: combatant.initiativeBonus,
      hp: combatant.hp,
      maxHp: combatant.maxHp,
      tempHp: combatant.tempHp,
      armorClass: combatant.ac,
      speed: combatant.speed,
      effects: [
        for (final condition in combatant.conditions)
          if (condition != 'Player Character')
            encounter_models.CombatEffect(
              id: '${id}_${condition.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
              name: condition,
              kind: _effectKindForCondition(condition),
              sourceCombatantId: id,
              targetCombatantId: id,
              startedRound: _round,
              visibleToPlayers: true,
            ),
      ],
    );
  }

  void _syncUiFromEncounter() {
    final encounter = _encounter;
    if (encounter == null || encounter.combatants.isEmpty) return;

    final previousTargetId =
        _targetIndex >= 0 && _targetIndex < _combatants.length
            ? _combatants[_targetIndex].id
            : null;
    final combatantsById = {
      for (final combatant in encounter.combatants) combatant.id: combatant,
    };
    final orderedCombatants = <encounter_models.Combatant>[
      for (final entry in encounter.initiativeOrder)
        if (combatantsById[entry.combatantId] != null)
          combatantsById[entry.combatantId]!,
      for (final combatant in encounter.combatants)
        if (!encounter.initiativeOrder
            .any((entry) => entry.combatantId == combatant.id))
          combatant,
    ];

    _combatants = orderedCombatants
        .map(_combatantFromEngineCombatant)
        .toList(growable: false);
    _round = encounter.round;

    final activeId = encounter.activeCombatant?.id;
    final syncedActiveIndex = activeId == null
        ? -1
        : _combatants.indexWhere((item) => item.id == activeId);
    if (syncedActiveIndex >= 0) {
      _activeIndex = syncedActiveIndex;
    } else {
      _activeIndex = _activeIndex.clamp(0, _combatants.length - 1).toInt();
    }

    final syncedTargetIndex = previousTargetId == null
        ? -1
        : _combatants.indexWhere((item) => item.id == previousTargetId);
    if (syncedTargetIndex >= 0 &&
        syncedTargetIndex != _activeIndex &&
        _combatants[syncedTargetIndex].hp > 0) {
      _targetIndex = syncedTargetIndex;
    } else {
      _targetIndex = _findDefaultTargetIndex(_activeIndex);
    }
  }

  _Combatant get _activeCombatant => _combatants[_activeIndex];

  int get _safeTargetIndex {
    if (_combatants.isEmpty) return 0;
    if (_targetIndex >= 0 &&
        _targetIndex < _combatants.length &&
        _targetIndex != _activeIndex) {
      return _targetIndex;
    }
    return _findDefaultTargetIndex(_activeIndex);
  }

  _Combatant get _selectedTarget => _combatants[_safeTargetIndex];

  List<_CombatAction> get _activeActions {
    return _actionsForCombatant(_activeCombatant);
  }

  Map<String, int> get _activeResourcePool {
    return _encounter?.combatantById(_activeCombatant.id)?.resources ?? {};
  }

  List<_CombatAction> _actionsForCombatant(_Combatant combatant) {
    if (combatant.team == _CombatTeam.party) {
      return _partyActionsByCombatantId[combatant.id] ?? _characterActions;
    }
    return _enemyActionsByCombatantId[combatant.id] ?? _enemyActions;
  }

  void _requestInitiative() {
    setState(() {
      final encounter = _encounter;
      if (encounter != null) {
        _encounter = CombatEncounterEngine.requestInitiative(encounter);
      }
      _activity.insert(
        0,
        _CombatLogEntry.system(
          'DM requested initiative. Waiting for party rolls.',
        ),
      );
    });
  }

  void _rollInitiativeForAll() {
    final updated = <_Combatant>[];
    var encounter = _encounter;

    for (final combatant in _combatants) {
      final bonus = combatant.initiativeBonus;
      final result = DiceRollerService.rollFormula(
        formula: _formatRollFormula('d20', bonus),
        label: '${combatant.name} Initiative',
      );
      updated.add(combatant.copyWith(initiative: result.total));
      if (encounter != null) {
        encounter = CombatEncounterEngine.setInitiative(
          encounter,
          combatantId: combatant.id,
          initiative: result.total,
        );
      }
    }

    updated.sort((a, b) => b.initiative.compareTo(a.initiative));

    setState(() {
      if (encounter != null) {
        _encounter = CombatEncounterEngine.startEncounter(encounter);
        _syncUiFromEncounter();
      } else {
        _combatants = updated;
        _activeIndex = 0;
        _targetIndex = _findDefaultTargetIndex(0, updated);
      }
      _spentTimings.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _activity.insert(
        0,
        _CombatLogEntry.system('Initiative rolled. Round 1 begins.'),
      );
    });
  }

  void _nextTurn() {
    setState(() {
      final previousRound = _round;
      final encounter = _encounter;
      if (encounter != null) {
        _encounter = CombatEncounterEngine.nextTurn(encounter);
        _syncUiFromEncounter();
        if (_round != previousRound) {
          _activity.insert(0, _CombatLogEntry.system('Round $_round begins.'));
        }
      } else {
        var nextIndex = _activeIndex + 1;
        if (nextIndex >= _combatants.length) {
          nextIndex = 0;
          _round += 1;
          _activity.insert(0, _CombatLogEntry.system('Round $_round begins.'));
        }
        _activeIndex = nextIndex;
        _targetIndex = _findDefaultTargetIndex(nextIndex);
      }

      _spentTimings.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _selectedCommandTiming = 'Action';
      _rollFeedback = null;
      _activity.insert(
        0,
        _CombatLogEntry.turn('${_activeCombatant.name} takes the turn.'),
      );
    });
  }

  void _rollAction(_CombatAction action, _CombatActionRoll rollType) {
    final actionKey = _actionExecutionKey(action);
    final canResolvePendingDamage = rollType != _CombatActionRoll.attack &&
        _pendingDamageActions.contains(actionKey);
    final resourceBlock = _actionResourceBlockMessage(action);
    if (resourceBlock != null && !canResolvePendingDamage) {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(resourceBlock),
        );
      });
      return;
    }
    if (_spentTimings.contains(action.timing) && !canResolvePendingDamage) {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${action.timing} is already spent this turn.',
          ),
        );
      });
      return;
    }

    final formula = switch (rollType) {
      _CombatActionRoll.attack => action.attackFormula,
      _CombatActionRoll.savingThrow => action.requiresSavingThrow
          ? _savingThrowFormulaForTarget(_selectedTarget, action.saveAbility!)
          : null,
      _CombatActionRoll.damage => action.damageFormula,
      _CombatActionRoll.critical => action.critFormula,
    };

    if (formula == null) return;

    final label = switch (rollType) {
      _CombatActionRoll.attack => '${action.name} Attack',
      _CombatActionRoll.savingThrow =>
        '${_selectedTarget.name} ${action.saveAbility} Save',
      _CombatActionRoll.damage => '${action.name} Damage',
      _CombatActionRoll.critical => '${action.name} Critical',
    };

    final result =
        DiceRollerService.rollFormula(formula: formula, label: label);

    setState(() {
      if (!canResolvePendingDamage) {
        _resetQueuedPreparedActions();
      }
      String? detail;
      String headline;
      String? subline;
      _CombatAccentKind feedbackKind = action.accentKind;
      if (rollType == _CombatActionRoll.attack ||
          rollType == _CombatActionRoll.savingThrow ||
          !canResolvePendingDamage) {
        _spentTimings.add(action.timing);
        _spendEngineActionResource(action);
        final economyMessage = _applyActionEconomyEffect(action);
        if (economyMessage != null) {
          _activity.insert(0, _CombatLogEntry.system(economyMessage));
        }
        final condition = _applyActionState(action);
        if (condition != null) {
          _applyEngineCondition(
            actor: _activeCombatant,
            target: _activeCombatant,
            name: condition,
            sourceActionName: action.name,
          );
          _syncUiFromEncounter();
        } else {
          _syncUiFromEncounter();
        }
      }

      if (rollType == _CombatActionRoll.attack) {
        final target = _selectedTarget;
        final outcome = _attackOutcome(result, target);
        if (outcome == 'hit' || outcome == 'critical hit') {
          _pendingDamageActions.add(actionKey);
          _pendingHalfDamageActions.remove(actionKey);
        } else {
          _pendingDamageActions.remove(actionKey);
          _pendingHalfDamageActions.remove(actionKey);
        }
        headline = outcome.toUpperCase();
        subline = '${_activeCombatant.name} vs ${target.name} AC ${target.ac}';
        feedbackKind = switch (outcome) {
          'critical hit' => _CombatAccentKind.support,
          'hit' => _CombatAccentKind.action,
          'automatic miss' => _CombatAccentKind.info,
          _ => _CombatAccentKind.read,
        };
        detail =
            '${result.formula} - ${result.rollsText}. ${target.name} AC ${target.ac}: $outcome.';
      } else if (rollType == _CombatActionRoll.savingThrow) {
        final target = _selectedTarget;
        final saveDc = action.saveDc ?? 10;
        final success = result.total >= saveDc;
        if (!success && action.damageFormula != null) {
          _pendingDamageActions.add(actionKey);
          _pendingHalfDamageActions.remove(actionKey);
        } else if (success &&
            action.damageFormula != null &&
            action.halfDamageOnSave) {
          _pendingDamageActions.add(actionKey);
          _pendingHalfDamageActions.add(actionKey);
        } else {
          _pendingDamageActions.remove(actionKey);
          _pendingHalfDamageActions.remove(actionKey);
        }
        headline = success ? 'SAVE SUCCESS' : 'SAVE FAILED';
        subline =
            '${target.name} ${action.saveAbility} ${result.total} vs DC $saveDc';
        feedbackKind =
            success ? _CombatAccentKind.read : _CombatAccentKind.magic;
        detail =
            '${result.formula} - ${result.rollsText}. ${target.name} ${success ? 'succeeds' : 'fails'} ${action.saveAbility} save vs DC $saveDc.';
      } else {
        final targetIndex =
            action.targetsSelf ? _activeIndex : _safeTargetIndex;
        final target = _combatants[targetIndex];
        final isHalfDamage =
            !action.isHealing && _pendingHalfDamageActions.contains(actionKey);
        final amount = isHalfDamage ? (result.total / 2).floor() : result.total;
        final hpResult = _resolveHpChange(
          target,
          amount,
          healing: action.isHealing,
        );
        final nextCombatants = [..._combatants];
        nextCombatants[targetIndex] = target.copyWith(
          hp: hpResult.hp,
          tempHp: hpResult.tempHp,
        );
        _combatants = nextCombatants;
        _applyEngineHpChange(
          actor: _activeCombatant,
          target: target,
          amount: amount,
          healing: action.isHealing,
          action: action,
          formula: result.formula,
        );
        _syncUiFromEncounter();

        final verb = action.isHealing ? 'recovers' : 'takes';
        final suffix = action.isHealing
            ? 'HP'
            : isHalfDamage
                ? 'half damage'
                : 'damage';
        headline = action.isHealing
            ? 'HEAL $amount'
            : isHalfDamage
                ? '$amount HALF DAMAGE'
                : '$amount DAMAGE';
        subline = _hpChangeLine(target, hpResult);
        feedbackKind = action.isHealing
            ? _CombatAccentKind.support
            : _CombatAccentKind.action;
        detail =
            '${result.formula} - ${result.rollsText}. ${target.name} $verb $amount $suffix (${_hpChangeLine(target, hpResult)}).';

        if (!action.isHealing && target.hp > 0 && hpResult.hp == 0) {
          _activity.insert(
            0,
            _CombatLogEntry.system('${target.name} is down.'),
          );
          _targetIndex = _findDefaultTargetIndex(_activeIndex);
        }
        _pendingDamageActions.remove(actionKey);
        _pendingHalfDamageActions.remove(actionKey);
      }

      _activity.insert(
        0,
        _CombatLogEntry.roll(
          actor: _activeCombatant.name,
          action: action.name,
          result: result,
          detail: detail,
        ),
      );
      _rollFeedback = _CombatRollFeedback(
        actor: _activeCombatant.name,
        action: action.name,
        result: result,
        headline: headline,
        subline: subline,
        accentKind: feedbackKind,
      );
    });
  }

  void _useAction(_CombatAction action) {
    final resourceBlock = _actionResourceBlockMessage(action);
    if (resourceBlock != null) {
      setState(() {
        _activity.insert(0, _CombatLogEntry.system(resourceBlock));
      });
      return;
    }
    if (_spentTimings.contains(action.timing)) {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${action.timing} is already spent this turn.',
          ),
        );
      });
      return;
    }

    setState(() {
      _resetQueuedPreparedActions();
      _spentTimings.add(action.timing);
      _pendingDamageActions.remove(_actionExecutionKey(action));
      _pendingHalfDamageActions.remove(_actionExecutionKey(action));
      final condition = _applyActionState(action);
      _spendEngineActionResource(action);
      final economyMessage = _applyActionEconomyEffect(action);
      final resolvedFeedback =
          action.hasMultiAttack ? _resolvePreparedAction(action) : null;
      if (condition != null) {
        _applyEngineCondition(
          actor: _activeCombatant,
          target: _activeCombatant,
          name: condition,
          sourceActionName: action.name,
        );
      }
      _syncUiFromEncounter();
      _activity.insert(
        0,
        _CombatLogEntry.system('${_activeCombatant.name} used ${action.name}.'),
      );
      if (economyMessage != null) {
        _activity.insert(0, _CombatLogEntry.system(economyMessage));
      }
      _rollFeedback = resolvedFeedback ??
          _CombatRollFeedback.manual(
            actor: _activeCombatant.name,
            action: action.name,
            headline: action.grantsAction
                ? 'ACTION SURGE'
                : condition == null
                    ? 'READY'
                    : condition.toUpperCase(),
            subline: economyMessage ??
                (condition == null
                    ? action.tags.take(3).join(' - ')
                    : '${_activeCombatant.name} is now $condition'),
            accentKind: action.accentKind,
          );
    });
  }

  void _prepareAction(_CombatAction action) {
    setState(() {
      _resetQueuedPreparedActions();
      if (_spentTimings.contains(action.timing)) {
        final hasPendingDamage =
            _pendingDamageActions.contains(_actionExecutionKey(action));
        _activity.insert(
          0,
          _CombatLogEntry.system(
            hasPendingDamage
                ? '${action.name} has pending damage to resolve.'
                : '${action.name} cannot be prepared: ${action.timing} is already spent.',
          ),
        );
        return;
      }
      final resourceBlock = _actionResourceBlockMessage(action);
      if (resourceBlock != null) {
        _activity.insert(0, _CombatLogEntry.system(resourceBlock));
        return;
      }

      final current = _preparedActions[action.timing];
      if (current?.name == action.name && current?.type == action.type) {
        _preparedActions.remove(action.timing);
        final encounter = _encounter;
        if (encounter != null) {
          _encounter = CombatEncounterEngine.clearPreparedAction(
            encounter,
            combatantId: _activeCombatant.id,
            timing: _timingFromLabel(action.timing),
          );
          _syncUiFromEncounter();
        }
        _activity.insert(
          0,
          _CombatLogEntry.system('${action.name} removed from the turn plan.'),
        );
        return;
      }

      _preparedActions[action.timing] = action;
      final encounter = _encounter;
      final engineAction = _engineActionForUi(action);
      if (encounter != null && engineAction != null) {
        _encounter = CombatEncounterEngine.prepareAction(
          encounter,
          combatantId: _activeCombatant.id,
          action: engineAction.copyWith(
            timing: _timingFromLabel(action.timing),
            actorId: _activeCombatant.id,
            targetId:
                action.targetsSelf ? _activeCombatant.id : _selectedTarget.id,
          ),
        );
        _syncUiFromEncounter();
      }
      _activity.insert(
        0,
        _CombatLogEntry.system('${action.name} prepared for ${action.timing}.'),
      );
    });
  }

  void _clearPreparedActions() {
    if (_preparedActions.isEmpty) return;
    setState(() {
      final encounter = _encounter;
      if (encounter != null) {
        for (final timing in _preparedActions.keys) {
          _encounter = CombatEncounterEngine.clearPreparedAction(
            _encounter ?? encounter,
            combatantId: _activeCombatant.id,
            timing: _timingFromLabel(timing),
          );
        }
        _syncUiFromEncounter();
      }
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _activity.insert(0, _CombatLogEntry.system('Turn plan cleared.'));
    });
  }

  void _resetQueuedPreparedActions() {
    _queuedPreparedActions.clear();
    _queuedPreparedIndex = 0;
  }

  void _launchPreparedTurn() {
    if (_preparedActions.isEmpty) return;

    const order = ['Action', 'Bonus Action', 'Reaction', 'Movement'];

    setState(() {
      if (_queuedPreparedActions.isEmpty ||
          _queuedPreparedIndex >= _queuedPreparedActions.length) {
        final prepared = [
          for (final timing in order)
            if (_preparedActions[timing] != null &&
                !_spentTimings.contains(timing))
              _preparedActions[timing]!,
        ];
        if (prepared.isEmpty) return;
        _queuedPreparedActions
          ..clear()
          ..addAll(prepared);
        _queuedPreparedIndex = 0;
        _activity.insert(
          0,
          _CombatLogEntry.turn(
            '${_activeCombatant.name} starts rolling the turn plan.',
          ),
        );
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${prepared.length} prepared roll${prepared.length == 1 ? '' : 's'} queued. Tap Roll Next to continue.',
          ),
        );
      }

      final action = _queuedPreparedActions[_queuedPreparedIndex];
      _activity.insert(
        0,
        _CombatLogEntry.turn(
          'Rolling ${_queuedPreparedIndex + 1}/${_queuedPreparedActions.length}: ${action.name}.',
        ),
      );

      _spentTimings.add(action.timing);
      _pendingDamageActions.remove(_actionExecutionKey(action));
      _pendingHalfDamageActions.remove(_actionExecutionKey(action));
      final condition = _applyActionState(action);
      if (condition != null) {
        _applyEngineCondition(
          actor: _combatants[_activeIndex],
          target: _combatants[_activeIndex],
          name: condition,
          sourceActionName: action.name,
        );
      }
      final feedback = _resolvePreparedAction(action);
      _spendEngineActionResource(action);
      final economyMessage = _applyActionEconomyEffect(action);
      if (economyMessage != null) {
        _activity.insert(0, _CombatLogEntry.system(economyMessage));
      }
      final encounter = _encounter;
      if (encounter != null) {
        _encounter = CombatEncounterEngine.clearPreparedAction(
          encounter,
          combatantId: _activeCombatant.id,
          timing: _timingFromLabel(action.timing),
        );
      }

      _queuedPreparedIndex += 1;

      _syncUiFromEncounter();
      _rollFeedback = feedback;
      if (_queuedPreparedIndex >= _queuedPreparedActions.length) {
        _resetQueuedPreparedActions();
        _activity.insert(
          0,
          _CombatLogEntry.system('Turn plan fully rolled.'),
        );
      } else {
        final nextAction = _queuedPreparedActions[_queuedPreparedIndex];
        _activity.insert(
          0,
          _CombatLogEntry.system('Next prepared roll: ${nextAction.name}.'),
        );
      }
    });
  }

  void _runDemoRound() {
    setState(() {
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _spentTimings.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _activity.insert(
        0,
        _CombatLogEntry.system('Demo round starts. Every combatant acts once.'),
      );

      _CombatRollFeedback? lastFeedback;
      var lastActorIndex = _activeIndex;
      for (var index = 0; index < _combatants.length; index++) {
        if (_combatants[index].hp <= 0) continue;

        final targetIndex = _findDefaultTargetIndex(index);
        if (targetIndex == index) continue;

        final action = _demoActionFor(_actionsForCombatant(_combatants[index]));
        if (action == null) continue;

        lastActorIndex = index;
        _activity.insert(
          0,
          _CombatLogEntry.turn('${_combatants[index].name} demo turn.'),
        );
        lastFeedback = _resolvePreparedAction(
          action,
          actorIndex: index,
          forcedTargetIndex: targetIndex,
        );
      }

      _round += 1;
      _activeIndex = lastActorIndex.clamp(0, _combatants.length - 1).toInt();
      _targetIndex = _findDefaultTargetIndex(_activeIndex);
      _selectedCommandTiming = 'Action';
      _workspace = _CombatWorkspace.overview;
      _rollFeedback = lastFeedback;
      _activity.insert(
        0,
        _CombatLogEntry.system('Demo round resolved. Review overview state.'),
      );
    });
  }

  _CombatAction? _demoActionFor(List<_CombatAction> actions) {
    for (final action in actions) {
      if (action.hasMultiAttack && !action.targetsSelf) return action;
    }
    for (final action in actions) {
      if (action.attackFormula != null &&
          action.damageFormula != null &&
          !action.targetsSelf) {
        return action;
      }
    }
    for (final action in actions) {
      if (action.damageFormula != null && !action.targetsSelf) return action;
    }
    for (final action in actions) {
      if (action.attackFormula != null) return action;
    }
    return actions.isEmpty ? null : actions.first;
  }

  _CombatRollFeedback _resolvePreparedAction(
    _CombatAction action, {
    int? actorIndex,
    int? forcedTargetIndex,
  }) {
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final actor = _combatants[resolvedActorIndex];
    final resolvedTargetIndex = forcedTargetIndex ??
        (actorIndex == null
            ? _safeTargetIndex
            : _findDefaultTargetIndex(resolvedActorIndex));
    final targetIndex =
        action.targetsSelf ? resolvedActorIndex : resolvedTargetIndex;
    var target = _combatants[targetIndex];

    if (action.hasMultiAttack) {
      return _resolveMultiAttackAction(
        action,
        actor: actor,
        actorIndex: resolvedActorIndex,
        targetIndex: targetIndex,
      );
    }

    if (action.requiresSavingThrow) {
      final saveResult = DiceRollerService.rollFormula(
        formula: _savingThrowFormulaForTarget(target, action.saveAbility!),
        label: '${target.name} ${action.saveAbility} Save',
      );
      final saveDc = action.saveDc ?? 10;
      final success = saveResult.total >= saveDc;
      final saveDetail =
          '${saveResult.formula} - ${saveResult.rollsText}. ${target.name} ${success ? 'succeeds' : 'fails'} ${action.saveAbility} save vs DC $saveDc.';
      _activity.insert(
        0,
        _CombatLogEntry.roll(
          actor: target.name,
          action: '${action.name} save',
          result: saveResult,
          detail: saveDetail,
        ),
      );

      if (action.damageFormula != null &&
          (!success || action.halfDamageOnSave)) {
        final damageResult = DiceRollerService.rollFormula(
          formula: action.damageFormula!,
          label: '${action.name} Damage',
        );
        final amount = success && action.halfDamageOnSave
            ? (damageResult.total / 2).floor()
            : damageResult.total;
        final hpResult = _resolveHpChange(target, amount, healing: false);
        final nextCombatants = [..._combatants];
        nextCombatants[targetIndex] = target.copyWith(
          hp: hpResult.hp,
          tempHp: hpResult.tempHp,
        );
        _combatants = nextCombatants;
        _applyEngineHpChange(
          actor: actor,
          target: target,
          amount: amount,
          healing: false,
          action: action,
          formula: damageResult.formula,
        );
        _syncUiFromEncounter();
        final damageDetail =
            '${damageResult.formula} - ${damageResult.rollsText}. ${target.name} takes $amount ${success ? 'half ' : ''}damage (${_hpChangeLine(target, hpResult)}).';
        _activity.insert(
          0,
          _CombatLogEntry.roll(
            actor: actor.name,
            action: '${action.name} damage',
            result: damageResult,
            detail: damageDetail,
          ),
        );
        return _CombatRollFeedback(
          actor: actor.name,
          action: action.name,
          result: damageResult,
          headline: success ? '$amount HALF DAMAGE' : '$amount DAMAGE',
          subline: _hpChangeLine(target, hpResult),
          accentKind:
              success ? _CombatAccentKind.read : _CombatAccentKind.magic,
        );
      }

      return _CombatRollFeedback(
        actor: target.name,
        action: action.name,
        result: saveResult,
        headline: success ? 'SAVE SUCCESS' : 'SAVE FAILED',
        subline:
            '${target.name} ${action.saveAbility} ${saveResult.total} vs DC $saveDc',
        accentKind: success ? _CombatAccentKind.read : _CombatAccentKind.magic,
      );
    }

    if (action.attackFormula != null) {
      final attackResult = DiceRollerService.rollFormula(
        formula: action.attackFormula!,
        label: '${action.name} Attack',
      );
      final outcome = _attackOutcome(attackResult, target);
      final attackDetail =
          '${attackResult.formula} - ${attackResult.rollsText}. ${target.name} AC ${target.ac}: $outcome.';
      _activity.insert(
        0,
        _CombatLogEntry.roll(
          actor: actor.name,
          action: '${action.name} attack',
          result: attackResult,
          detail: attackDetail,
        ),
      );

      final didHit = outcome == 'hit' || outcome == 'critical hit';
      final damageFormula = outcome == 'critical hit'
          ? action.critFormula ?? action.damageFormula
          : action.damageFormula;
      if (didHit && damageFormula != null) {
        final damageResult = DiceRollerService.rollFormula(
          formula: damageFormula,
          label: '${action.name} Damage',
        );
        final amount = damageResult.total;
        final hpResult = _resolveHpChange(target, amount, healing: false);
        final nextCombatants = [..._combatants];
        nextCombatants[targetIndex] = target.copyWith(
          hp: hpResult.hp,
          tempHp: hpResult.tempHp,
        );
        _combatants = nextCombatants;
        _applyEngineHpChange(
          actor: actor,
          target: target,
          amount: amount,
          healing: false,
          action: action,
          formula: damageResult.formula,
        );
        _syncUiFromEncounter();
        final damageDetail =
            '${damageResult.formula} - ${damageResult.rollsText}. ${target.name} takes $amount damage (${_hpChangeLine(target, hpResult)}).';
        _activity.insert(
          0,
          _CombatLogEntry.roll(
            actor: actor.name,
            action: '${action.name} damage',
            result: damageResult,
            detail: damageDetail,
          ),
        );
        if (target.hp > 0 && hpResult.hp == 0) {
          _activity.insert(
              0, _CombatLogEntry.system('${target.name} is down.'));
          _targetIndex = _findDefaultTargetIndex(_activeIndex);
        }
        final headline = outcome == 'critical hit'
            ? 'CRIT $amount DAMAGE'
            : '$amount DAMAGE';
        return _CombatRollFeedback(
          actor: actor.name,
          action: action.name,
          result: damageResult,
          headline: headline,
          subline: _hpChangeLine(target, hpResult),
          accentKind: outcome == 'critical hit'
              ? _CombatAccentKind.support
              : _CombatAccentKind.action,
        );
      }

      return _CombatRollFeedback(
        actor: actor.name,
        action: action.name,
        result: attackResult,
        headline: outcome.toUpperCase(),
        subline: '${actor.name} vs ${target.name} AC ${target.ac}',
        accentKind: switch (outcome) {
          'critical hit' => _CombatAccentKind.support,
          'hit' => _CombatAccentKind.action,
          'automatic miss' => _CombatAccentKind.info,
          _ => _CombatAccentKind.read,
        },
      );
    }

    if (action.damageFormula != null) {
      final result = DiceRollerService.rollFormula(
        formula: action.damageFormula!,
        label: action.isHealing ? '${action.name} Heal' : '${action.name} Use',
      );
      final amount = result.total;
      final hpResult = _resolveHpChange(
        target,
        amount,
        healing: action.isHealing,
      );
      final nextCombatants = [..._combatants];
      nextCombatants[targetIndex] = target.copyWith(
        hp: hpResult.hp,
        tempHp: hpResult.tempHp,
      );
      _combatants = nextCombatants;
      _applyEngineHpChange(
        actor: actor,
        target: target,
        amount: amount,
        healing: action.isHealing,
        action: action,
        formula: result.formula,
      );
      _syncUiFromEncounter();

      final verb = action.isHealing ? 'recovers' : 'takes';
      final suffix = action.isHealing ? 'HP' : 'damage';
      final detail =
          '${result.formula} - ${result.rollsText}. ${target.name} $verb $amount $suffix (${_hpChangeLine(target, hpResult)}).';
      _activity.insert(
        0,
        _CombatLogEntry.roll(
          actor: actor.name,
          action: action.name,
          result: result,
          detail: detail,
        ),
      );
      if (!action.isHealing && target.hp > 0 && hpResult.hp == 0) {
        _activity.insert(0, _CombatLogEntry.system('${target.name} is down.'));
        _targetIndex = _findDefaultTargetIndex(_activeIndex);
      }
      return _CombatRollFeedback(
        actor: actor.name,
        action: action.name,
        result: result,
        headline: action.isHealing ? 'HEAL $amount' : '$amount DAMAGE',
        subline: _hpChangeLine(target, hpResult),
        accentKind: action.isHealing
            ? _CombatAccentKind.support
            : _CombatAccentKind.action,
      );
    }

    _activity.insert(
      0,
      _CombatLogEntry.system('${actor.name} used ${action.name}.'),
    );
    final condition = _applyActionState(action, actorIndex: resolvedActorIndex);
    if (condition != null) {
      _applyEngineCondition(
        actor: actor,
        target: actor,
        name: condition,
        sourceActionName: action.name,
      );
      _syncUiFromEncounter();
    }
    return _CombatRollFeedback.manual(
      actor: actor.name,
      action: action.name,
      headline: action.grantsAction
          ? 'ACTION SURGE'
          : condition == null
              ? 'USED'
              : condition.toUpperCase(),
      subline: action.grantsAction
          ? '${actor.name} can take another Action this turn.'
          : condition == null
              ? action.tags.take(3).join(' - ')
              : '${actor.name} is now $condition',
      accentKind: action.accentKind,
    );
  }

  _CombatRollFeedback _resolveMultiAttackAction(
    _CombatAction action, {
    required _Combatant actor,
    required int actorIndex,
    required int targetIndex,
  }) {
    var currentTargetIndex = targetIndex;
    var totalDamage = 0;
    var hitCount = 0;
    var critCount = 0;
    var attackCount = 0;
    DiceRollResult? lastResult;
    String? lastHpLine;

    for (var index = 0; index < action.multiAttackSteps.length; index++) {
      if (currentTargetIndex < 0 || currentTargetIndex >= _combatants.length) {
        break;
      }
      final target = _combatants[currentTargetIndex];
      if (target.hp <= 0) break;

      final step = action.multiAttackSteps[index];
      final stepLabel = '${action.name} ${index + 1}: ${step.name}';
      final attackFormula = step.attackFormula;
      final damageFormula = step.damageFormula;
      if (attackFormula == null && damageFormula == null) continue;

      if (attackFormula == null) {
        final damageResult = DiceRollerService.rollFormula(
          formula: damageFormula!,
          label: '$stepLabel Damage',
        );
        lastResult = damageResult;
        final amount = damageResult.total;
        final hpResult = _resolveHpChange(target, amount, healing: false);
        _combatants = [
          for (var i = 0; i < _combatants.length; i++)
            i == currentTargetIndex
                ? target.copyWith(hp: hpResult.hp, tempHp: hpResult.tempHp)
                : _combatants[i],
        ];
        totalDamage += amount;
        hitCount += 1;
        lastHpLine = _hpChangeLine(target, hpResult);
        _applyEngineHpChange(
          actor: actor,
          target: target,
          amount: amount,
          healing: false,
          action: action,
          formula: damageResult.formula,
        );
        _activity.insert(
          0,
          _CombatLogEntry.roll(
            actor: actor.name,
            action: stepLabel,
            result: damageResult,
            detail:
                '${damageResult.formula} - ${damageResult.rollsText}. ${target.name} takes $amount damage ($lastHpLine).',
          ),
        );
      } else {
        attackCount += 1;
        final attackResult = DiceRollerService.rollFormula(
          formula: attackFormula,
          label: '$stepLabel Attack',
        );
        lastResult = attackResult;
        final outcome = _attackOutcome(attackResult, target);
        final didHit = outcome == 'hit' || outcome == 'critical hit';
        if (outcome == 'critical hit') critCount += 1;
        _activity.insert(
          0,
          _CombatLogEntry.roll(
            actor: actor.name,
            action: '$stepLabel attack',
            result: attackResult,
            detail:
                '${attackResult.formula} - ${attackResult.rollsText}. ${target.name} AC ${target.ac}: $outcome.',
          ),
        );

        final resolvedDamageFormula = outcome == 'critical hit'
            ? step.critFormula ?? damageFormula
            : damageFormula;
        if (didHit && resolvedDamageFormula != null) {
          final damageResult = DiceRollerService.rollFormula(
            formula: resolvedDamageFormula,
            label: '$stepLabel Damage',
          );
          lastResult = damageResult;
          final amount = damageResult.total;
          final hpResult = _resolveHpChange(target, amount, healing: false);
          _combatants = [
            for (var i = 0; i < _combatants.length; i++)
              i == currentTargetIndex
                  ? target.copyWith(hp: hpResult.hp, tempHp: hpResult.tempHp)
                  : _combatants[i],
          ];
          totalDamage += amount;
          hitCount += 1;
          lastHpLine = _hpChangeLine(target, hpResult);
          _applyEngineHpChange(
            actor: actor,
            target: target,
            amount: amount,
            healing: false,
            action: action,
            formula: damageResult.formula,
          );
          _activity.insert(
            0,
            _CombatLogEntry.roll(
              actor: actor.name,
              action: '$stepLabel damage',
              result: damageResult,
              detail:
                  '${damageResult.formula} - ${damageResult.rollsText}. ${target.name} takes $amount damage ($lastHpLine).',
            ),
          );
        }
      }

      final updatedTarget = _combatants[currentTargetIndex];
      if (target.hp > 0 && updatedTarget.hp == 0) {
        _activity.insert(
          0,
          _CombatLogEntry.system('${target.name} is down.'),
        );
        _targetIndex = _findDefaultTargetIndex(actorIndex);
        currentTargetIndex = _targetIndex;
        break;
      }
    }

    _syncUiFromEncounter();

    final attacksLabel = attackCount == 0
        ? '${action.multiAttackSteps.length} steps'
        : '$hitCount / $attackCount hits';
    final headline = totalDamage > 0
        ? '${critCount > 0 ? 'CRIT ' : ''}MULTIATTACK $totalDamage'
        : 'MULTIATTACK MISS';

    return _CombatRollFeedback(
      actor: actor.name,
      action: action.name,
      result: lastResult,
      headline: headline,
      subline: lastHpLine ?? '${_combatants[targetIndex].name}: $attacksLabel',
      accentKind: totalDamage > 0
          ? (critCount > 0 ? _CombatAccentKind.support : action.accentKind)
          : _CombatAccentKind.read,
    );
  }

  void _selectTarget(int index) {
    if (index == _activeIndex || index < 0 || index >= _combatants.length) {
      return;
    }

    setState(() {
      _targetIndex = index;
      _activity.insert(
        0,
        _CombatLogEntry.system('${_combatants[index].name} is targeted.'),
      );
    });
  }

  _HpChangeResult _resolveHpChange(
    _Combatant target,
    int amount, {
    required bool healing,
  }) {
    if (healing) {
      return _HpChangeResult(
        hp: (target.hp + amount).clamp(0, target.maxHp).toInt(),
        tempHp: target.tempHp,
      );
    }

    final absorbedByTemp = math.min(target.tempHp, amount);
    final remainingDamage = amount - absorbedByTemp;
    return _HpChangeResult(
      hp: (target.hp - remainingDamage).clamp(0, target.maxHp).toInt(),
      tempHp: target.tempHp - absorbedByTemp,
    );
  }

  encounter_models.PreparedCombatAction? _engineActionForUi(
    _CombatAction action,
  ) {
    final byId = _engineActions[action.id];
    if (byId != null) return byId;
    for (final engineAction in _engineActions.values) {
      if (engineAction.name == action.name &&
          _timingLabel(engineAction.timing) == action.timing) {
        return engineAction;
      }
    }
    return null;
  }

  void _applyEngineHpChange({
    required _Combatant actor,
    required _Combatant target,
    required int amount,
    required bool healing,
    required _CombatAction action,
    required String formula,
  }) {
    final encounter = _encounter;
    if (encounter == null) return;

    if (healing) {
      _encounter = CombatEncounterEngine.applyHealing(
        encounter,
        sourceId: actor.id,
        targetId: target.id,
        amount: amount,
        actionId: action.id.isEmpty ? null : action.id,
        formula: formula,
      );
    } else {
      _encounter = CombatEncounterEngine.applyDamage(
        encounter,
        sourceId: actor.id,
        targetId: target.id,
        amount: amount,
        actionId: action.id.isEmpty ? null : action.id,
        formula: formula,
      );
    }
  }

  void _spendEngineActionResource(_CombatAction action) {
    final encounter = _encounter;
    final engineAction = _engineActionForUi(action);
    final resourceKey = engineAction?.resourceKey;
    final resourceCost = engineAction?.resourceCost ?? 0;
    if (encounter == null || resourceKey == null || resourceCost <= 0) return;

    _encounter = CombatEncounterEngine.spendResource(
      encounter,
      combatantId: _activeCombatant.id,
      resourceKey: resourceKey,
      amount: resourceCost,
    );
  }

  String? _applyActionEconomyEffect(_CombatAction action) {
    if (!action.grantsAction) return null;

    final hadSpentAction = _spentTimings.remove('Action');
    _selectedCommandTiming = 'Action';
    return hadSpentAction
        ? '${action.name} grants another Action this turn.'
        : '${action.name} is active. Your Action is still available.';
  }

  String? _actionResourceBlockMessage(_CombatAction action) {
    final resourceKey = action.resourceKey;
    final resourceCost = action.resourceCost;
    if (resourceKey == null || resourceCost <= 0) return null;

    final remaining = _activeResourcePool[resourceKey] ?? 0;
    if (remaining >= resourceCost) return null;

    return '${action.name} cannot be used: ${_readableActionResourceName(resourceKey)} is depleted.';
  }

  void _applyEngineCondition({
    required _Combatant actor,
    required _Combatant target,
    required String name,
    String? sourceActionName,
  }) {
    final encounter = _encounter;
    if (encounter == null) return;
    var nextEncounter = encounter;
    if (_effectKindForCondition(name) ==
        encounter_models.CombatEffectKind.concentration) {
      final existing = target.id.isEmpty
          ? const <encounter_models.CombatEffect>[]
          : nextEncounter.combatantById(target.id)?.effects ?? const [];
      for (final effect in existing.where(
        (effect) =>
            effect.kind == encounter_models.CombatEffectKind.concentration,
      )) {
        nextEncounter = CombatEncounterEngine.removeEffect(
          nextEncounter,
          targetId: target.id,
          effectId: effect.id,
        );
      }
    }
    _encounter = CombatEncounterEngine.applyEffect(
      nextEncounter,
      effect: encounter_models.CombatEffect(
        id: '${target.id}_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
        name: name,
        kind: _effectKindForCondition(name),
        sourceCombatantId: actor.id,
        targetCombatantId: target.id,
        startedRound: _round,
        endsAtRound: _defaultEffectEndsAtRound(name),
        visibleToPlayers: true,
        mechanics: {
          if (sourceActionName != null) 'sourceAction': sourceActionName,
        },
      ),
    );
  }

  encounter_models.CombatEffectKind _effectKindForCondition(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rage') ||
        lower.contains('inspiration') ||
        lower.contains('inspired')) {
      return encounter_models.CombatEffectKind.buff;
    }
    if (lower.contains('concentrating')) {
      return encounter_models.CombatEffectKind.concentration;
    }
    if (lower.contains('marked')) {
      return encounter_models.CombatEffectKind.debuff;
    }
    return encounter_models.CombatEffectKind.condition;
  }

  int? _defaultEffectEndsAtRound(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rage')) return _round + 10;
    if (lower.contains('bardic inspiration') || lower.contains('inspired')) {
      return _round + 10;
    }
    return null;
  }

  encounter_models.CombatActionTiming _timingFromLabel(String label) {
    return switch (label) {
      'Bonus Action' => encounter_models.CombatActionTiming.bonusAction,
      'Reaction' => encounter_models.CombatActionTiming.reaction,
      'Movement' => encounter_models.CombatActionTiming.movement,
      'Object Interaction' =>
        encounter_models.CombatActionTiming.objectInteraction,
      'Free' => encounter_models.CombatActionTiming.free,
      _ => encounter_models.CombatActionTiming.action,
    };
  }

  String _hpChangeLine(_Combatant before, _HpChangeResult after) {
    String label(int hp, int maxHp, int tempHp) {
      final temp = tempHp > 0 ? ' +$tempHp temp' : '';
      return '$hp/$maxHp$temp';
    }

    return '${before.name}: ${label(before.hp, before.maxHp, before.tempHp)} -> ${label(after.hp, before.maxHp, after.tempHp)} HP';
  }

  String? _applyActionState(_CombatAction action, {int? actorIndex}) {
    final index =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final actor = _combatants[index];
    final condition = _conditionFromAction(action);
    if (condition == null) return null;
    if (actor.conditions.contains(condition) && condition != 'Concentrating') {
      return condition;
    }
    final nextConditions = [
      condition,
      ...actor.conditions.where((item) {
        if (condition == 'Concentrating' && item == 'Concentrating') {
          return false;
        }
        return item != condition;
      }),
    ];

    final nextCombatants = [..._combatants];
    nextCombatants[index] = actor.copyWith(
      conditions: nextConditions,
    );
    _combatants = nextCombatants;
    _activity.insert(
      0,
      _CombatLogEntry.system('${actor.name} gains $condition.'),
    );
    return condition;
  }

  String? _conditionFromAction(_CombatAction action) {
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    if (text.contains('rage')) return 'Raging';
    if (text.contains('bardic inspiration')) return 'Bardic Inspiration';
    if (text.contains('inspiration')) return 'Inspired';
    if (text.contains('concentration')) return 'Concentrating';
    return null;
  }

  void _selectCommandTiming(String timing) {
    setState(() {
      _selectedCommandTiming = timing;
    });
  }

  void _selectFocusedCombatant(int index) {
    if (index < 0 || index >= _combatants.length) return;
    setState(() {
      _activeIndex = index;
      _targetIndex = _findDefaultTargetIndex(index);
      _spentTimings.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _selectedCommandTiming = 'Action';
      _rollFeedback = null;
      _workspace = _CombatWorkspace.turn;
      _activity.insert(
        0,
        _CombatLogEntry.system('${_combatants[index].name} is focused.'),
      );
    });
  }

  void _removeActiveEffect(String combatantId, String effectName) {
    setState(() {
      final combatantIndex =
          _combatants.indexWhere((combatant) => combatant.id == combatantId);
      if (combatantIndex >= 0) {
        final combatant = _combatants[combatantIndex];
        final nextCombatants = [..._combatants];
        nextCombatants[combatantIndex] = combatant.copyWith(
          conditions: combatant.conditions
              .where((condition) => condition != effectName)
              .toList(growable: false),
        );
        _combatants = nextCombatants;
      }

      final encounter = _encounter;
      final effects =
          encounter?.combatantById(combatantId)?.effects ?? const [];
      var nextEncounter = encounter;
      for (final effect
          in effects.where((effect) => effect.name == effectName)) {
        nextEncounter = CombatEncounterEngine.removeEffect(
          nextEncounter!,
          targetId: combatantId,
          effectId: effect.id,
        );
      }
      _encounter = nextEncounter;
      _syncUiFromEncounter();
      _activity.insert(
        0,
        _CombatLogEntry.system('$effectName removed.'),
      );
    });
  }

  void _selectWorkspace(_CombatWorkspace workspace) {
    setState(() {
      _workspace = workspace;
    });
  }

  void _toggleDmView() {
    setState(() {
      _dmView = !_dmView;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Scaffold(
      backgroundColor: tokens.pageBottom,
      body: Stack(
        children: [
          Positioned.fill(
            child: _CombatArenaBackdrop(round: _round),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useGameLayout =
                    constraints.maxWidth >= 900 && constraints.maxHeight >= 640;
                final useCompactLandscapeLayout =
                    constraints.maxWidth >= 700 && constraints.maxHeight >= 340;

                if (useGameLayout) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1420),
                      child: _CombatLayeredGameView(
                        round: _round,
                        combatants: _combatants,
                        activeIndex: _activeIndex,
                        targetIndex: _safeTargetIndex,
                        activeCombatant: _activeCombatant,
                        selectedTarget: _selectedTarget,
                        actions: _activeActions,
                        rollFeedback: _rollFeedback,
                        spentTimings: _spentTimings,
                        pendingDamageActions: _pendingDamageActions,
                        preparedActions: _preparedActions,
                        queuedPreparedIndex: _queuedPreparedIndex,
                        queuedPreparedTotal: _queuedPreparedActions.length,
                        queuedPreparedActionName: _queuedPreparedActionName,
                        selectedCommandTiming: _selectedCommandTiming,
                        workspace: _workspace,
                        showEnemyHp: _dmView,
                        entries: _activity,
                        resourcePool: _activeResourcePool,
                        onBack: () => Navigator.of(context).maybePop(),
                        onRequestInitiative: _requestInitiative,
                        onRollInitiative: _rollInitiativeForAll,
                        onNextTurn: _nextTurn,
                        onToggleDmView: _toggleDmView,
                        onRunDemo: _runDemoRound,
                        onSelectTarget: _selectTarget,
                        onSelectFocusedCombatant: _selectFocusedCombatant,
                        onRemoveActiveEffect: _removeActiveEffect,
                        onSelectWorkspace: _selectWorkspace,
                        onSelectCommandTiming: _selectCommandTiming,
                        onRollAction: _rollAction,
                        onUseAction: _useAction,
                        onPrepareAction: _prepareAction,
                        onLaunchPreparedTurn: _launchPreparedTurn,
                        onClearPreparedActions: _clearPreparedActions,
                      ),
                    ),
                  );
                }

                if (useCompactLandscapeLayout) {
                  return _CombatCompactLandscapeView(
                    round: _round,
                    combatants: _combatants,
                    activeIndex: _activeIndex,
                    targetIndex: _safeTargetIndex,
                    activeCombatant: _activeCombatant,
                    selectedTarget: _selectedTarget,
                    actions: _activeActions,
                    rollFeedback: _rollFeedback,
                    spentTimings: _spentTimings,
                    pendingDamageActions: _pendingDamageActions,
                    preparedActions: _preparedActions,
                    queuedPreparedIndex: _queuedPreparedIndex,
                    queuedPreparedTotal: _queuedPreparedActions.length,
                    queuedPreparedActionName: _queuedPreparedActionName,
                    selectedCommandTiming: _selectedCommandTiming,
                    showEnemyHp: _dmView,
                    resourcePool: _activeResourcePool,
                    onBack: () => Navigator.of(context).maybePop(),
                    onRequestInitiative: _requestInitiative,
                    onRollInitiative: _rollInitiativeForAll,
                    onNextTurn: _nextTurn,
                    onToggleDmView: _toggleDmView,
                    onRunDemo: _runDemoRound,
                    onSelectTarget: _selectTarget,
                    onSelectFocusedCombatant: _selectFocusedCombatant,
                    onRemoveActiveEffect: _removeActiveEffect,
                    onSelectCommandTiming: _selectCommandTiming,
                    onRollAction: _rollAction,
                    onUseAction: _useAction,
                    onPrepareAction: _prepareAction,
                    onLaunchPreparedTurn: _launchPreparedTurn,
                    onClearPreparedActions: _clearPreparedActions,
                  );
                }

                final isDesktop = constraints.maxWidth >= 1050;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: ListView(
                      padding: EdgeInsets.all(isDesktop ? 24 : 14),
                      children: [
                        _CombatHeader(
                          round: _round,
                          activeCombatant: _activeCombatant,
                          selectedTarget: _selectedTarget,
                          onBack: () => Navigator.of(context).maybePop(),
                          onRequestInitiative: _requestInitiative,
                          onRollInitiative: _rollInitiativeForAll,
                          onNextTurn: _nextTurn,
                        ),
                        const SizedBox(height: 14),
                        _DuelSpotlightPanel(
                          round: _round,
                          activeCombatant: _activeCombatant,
                          targetCombatant: _selectedTarget,
                        ),
                        if (_rollFeedback != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child:
                                _RollFeedbackWindow(feedback: _rollFeedback!),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _BattlefieldPanel(
                          combatants: _combatants,
                          activeIndex: _activeIndex,
                          targetIndex: _safeTargetIndex,
                          onSelectTarget: _selectTarget,
                        ),
                        const SizedBox(height: 14),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 300,
                                child: _InitiativePanel(
                                  combatants: _combatants,
                                  activeIndex: _activeIndex,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _ActiveTurnPanel(
                                  combatant: _activeCombatant,
                                  combatants: _combatants,
                                  activeIndex: _activeIndex,
                                  targetIndex: _safeTargetIndex,
                                  onSelectTarget: _selectTarget,
                                  spentTimings: _spentTimings,
                                  actions: _activeActions,
                                  onRollAction: _rollAction,
                                ),
                              ),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 330,
                                child: _ActivityPanel(entries: _activity),
                              ),
                            ],
                          )
                        else ...[
                          _InitiativePanel(
                            combatants: _combatants,
                            activeIndex: _activeIndex,
                          ),
                          const SizedBox(height: 12),
                          _ActiveTurnPanel(
                            combatant: _activeCombatant,
                            combatants: _combatants,
                            activeIndex: _activeIndex,
                            targetIndex: _safeTargetIndex,
                            onSelectTarget: _selectTarget,
                            spentTimings: _spentTimings,
                            actions: _activeActions,
                            onRollAction: _rollAction,
                          ),
                          const SizedBox(height: 12),
                          _ActivityPanel(entries: _activity),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_Combatant> _buildDefaultCombatants() {
    return [
      const _Combatant(
        id: 'demo_arnnazal',
        name: 'Arnnazal',
        role: 'Half-Orc Paladin 5 / Blood Hunter 2',
        initiative: 18,
        initiativeBonus: 3,
        hp: 174,
        maxHp: 174,
        ac: 12,
        speed: 30,
        team: _CombatTeam.party,
        portraitAsset: 'assets/images/races/half-orc.png',
        conditions: ['Blessed'],
      ),
      const _Combatant(
        id: 'demo_lyra',
        name: 'Lyra',
        role: 'Wizard',
        initiative: 15,
        initiativeBonus: 2,
        hp: 32,
        maxHp: 38,
        ac: 14,
        speed: 30,
        team: _CombatTeam.party,
        portraitAsset: 'assets/images/classes/wizard.png',
        conditions: ['Concentrating'],
      ),
      const _Combatant(
        id: 'demo_hobgoblin_captain',
        name: 'Hobgoblin Captain',
        role: 'Enemy Leader',
        initiative: 14,
        initiativeBonus: 1,
        hp: 48,
        maxHp: 65,
        ac: 17,
        speed: 30,
        team: _CombatTeam.enemy,
        portraitAsset: 'assets/images/races/hobgoblin.png',
        conditions: ['Marked'],
      ),
      const _Combatant(
        id: 'demo_goblin_archer',
        name: 'Goblin Archer',
        role: 'Enemy Skirmisher',
        initiative: 11,
        initiativeBonus: 2,
        hp: 14,
        maxHp: 18,
        ac: 15,
        speed: 30,
        team: _CombatTeam.enemy,
        portraitAsset: 'assets/images/races/goblin.png',
        conditions: [],
      ),
    ];
  }

  _Combatant _combatantFromEngineCombatant(
    encounter_models.Combatant combatant,
  ) {
    final team = switch (combatant.team) {
      encounter_models.CombatantTeam.party => _CombatTeam.party,
      encounter_models.CombatantTeam.enemy => _CombatTeam.enemy,
      encounter_models.CombatantTeam.neutral => _CombatTeam.enemy,
    };
    final conditions = [
      if (combatant.kind == encounter_models.CombatantKind.playerCharacter)
        'Player Character',
      for (final resource in combatant.resources.entries)
        if (resource.value > 0)
          '${_readableResourceName(resource.key)} ${resource.value}',
      for (final effect
          in combatant.effects.where((item) => item.visibleToPlayers))
        effect.name,
    ];

    return _Combatant(
      id: combatant.id,
      name: combatant.name,
      role: combatant.role,
      initiative: combatant.initiative,
      initiativeBonus: combatant.initiativeBonus,
      hp: combatant.hp,
      maxHp: combatant.maxHp,
      tempHp: combatant.tempHp,
      ac: combatant.armorClass,
      speed: combatant.speed,
      team: team,
      portraitAsset: _combatantPortraitAsset(
        name: combatant.name,
        role: combatant.role,
        team: team,
      ),
      conditions: conditions.take(9).toList(growable: false),
    );
  }

  _CombatAction _combatActionFromPreparedAction(
    encounter_models.PreparedCombatAction action,
  ) {
    final source = action.metadata['source']?.toString() ?? '';
    final grantsAction = _preparedActionGrantsAction(action);
    final criticalDamageFormula =
        action.metadata['criticalDamageFormula']?.toString();
    final damageFormula = action.damageFormula ?? action.healingFormula;

    return _CombatAction(
      id: action.id,
      name: action.name,
      type: _actionTypeLabel(action),
      timing: grantsAction ? 'Bonus Action' : _timingLabel(action.timing),
      attackFormula: action.attackFormula,
      saveAbility: action.saveAbility,
      saveDc: action.saveDc,
      damageFormula: damageFormula,
      critFormula: criticalDamageFormula == null ||
              criticalDamageFormula.trim().isEmpty ||
              criticalDamageFormula == 'null'
          ? null
          : criticalDamageFormula,
      tags: action.tags,
      icon: _actionIcon(action, source),
      accentKind: _actionAccentKind(action, source),
      resourceKey: action.resourceKey,
      resourceCost: action.resourceCost,
      targetsSelf:
          action.rollKind == encounter_models.CombatActionRollKind.resource,
      isHealing:
          action.rollKind == encounter_models.CombatActionRollKind.healing ||
              action.healingFormula != null,
      halfDamageOnSave: action.metadata['halfDamageOnSave'] == true,
      grantsAction: grantsAction,
      multiAttackSteps: _multiAttackStepsFromMetadata(action.metadata),
    );
  }

  bool _preparedActionGrantsAction(
    encounter_models.PreparedCombatAction action,
  ) {
    final effect = action.metadata['combatEffect']?.toString().toLowerCase();
    if (action.metadata['grantsAction'] == true || effect == 'actionsurge') {
      return true;
    }
    return _looksLikeActionSurgeText(
      '${action.name} ${action.tags.join(' ')} ${action.metadata['description'] ?? ''}',
    );
  }

  bool _looksLikeActionSurgeText(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    return normalized.contains('action surge') ||
        normalized.contains('action sourge') ||
        (normalized.contains('action') &&
            (normalized.contains('surge') || normalized.contains('sourge'))) ||
        normalized.contains('one additional action') ||
        normalized.contains('additional action') ||
        normalized.contains('accion adicional') ||
        normalized.contains('oleada de accion');
  }

  String _actionTypeLabel(encounter_models.PreparedCombatAction action) {
    final source = action.metadata['source']?.toString();
    if (action.metadata['multiattack'] == true) {
      if (source == 'weaponMultiattack') return 'Extra Attack';
      if (source == 'monster') return 'Monster Multiattack';
      return 'Multiattack';
    }
    if (source == 'weapon' || source == 'weaponMultiattack') {
      final weaponType = action.metadata['weaponType']?.toString();
      return weaponType == 'ranged' ? 'Ranged Weapon' : 'Weapon Attack';
    }
    if (source == 'spell') {
      final flow = action.metadata['spellFlow']?.toString();
      if (flow == 'save') return 'Save Spell';
      if (flow == 'attack') return 'Spell Attack';
      if (flow == 'healing') return 'Healing Spell';
      final level = action.metadata['level'];
      if (level is int && level == 0) return 'Cantrip';
      if (level is int) return 'Level $level Spell';
      return 'Spell';
    }
    if (source == 'feature') {
      if (action.metadata['combatEffect'] == 'actionSurge') {
        return 'Fighter Feature';
      }
      return action.metadata['featureSource']?.toString() ?? 'Feature';
    }
    if (source == 'resource') return 'Resource';
    if (source == 'spellcasting') return 'Spellcasting';
    if (source == 'monster') return 'Monster Attack';
    if (source == 'monsterFeature') return 'Monster Feature';
    return action.rollKind.name;
  }

  String _timingLabel(encounter_models.CombatActionTiming timing) {
    return switch (timing) {
      encounter_models.CombatActionTiming.action => 'Action',
      encounter_models.CombatActionTiming.bonusAction => 'Bonus Action',
      encounter_models.CombatActionTiming.reaction => 'Reaction',
      encounter_models.CombatActionTiming.movement => 'Movement',
      encounter_models.CombatActionTiming.objectInteraction =>
        'Object Interaction',
      encounter_models.CombatActionTiming.free => 'Free',
      encounter_models.CombatActionTiming.passive => 'Passive',
      encounter_models.CombatActionTiming.onHit => 'On Hit',
      encounter_models.CombatActionTiming.onDamageTaken => 'On Damage Taken',
      encounter_models.CombatActionTiming.startOfTurn => 'Start of Turn',
      encounter_models.CombatActionTiming.endOfTurn => 'End of Turn',
    };
  }

  List<_MultiAttackStep> _multiAttackStepsFromMetadata(
    Map<String, dynamic> metadata,
  ) {
    final rawSteps = metadata['multiAttackSteps'];
    if (rawSteps is! List) return const [];
    final steps = <_MultiAttackStep>[];
    for (final rawStep in rawSteps) {
      if (rawStep is! Map) continue;
      final name = rawStep['name']?.toString().trim() ?? '';
      final attackFormula = rawStep['attackFormula']?.toString();
      final damageFormula = rawStep['damageFormula']?.toString();
      final criticalDamageFormula =
          rawStep['criticalDamageFormula']?.toString();
      final rawTags = rawStep['tags'];
      steps.add(
        _MultiAttackStep(
          name: name.isEmpty ? 'Attack' : name,
          attackFormula: _cleanNullableFormula(attackFormula),
          damageFormula: _cleanNullableFormula(damageFormula),
          critFormula: _cleanNullableFormula(criticalDamageFormula),
          tags: rawTags is List
              ? rawTags.map((item) => item.toString()).toList(growable: false)
              : const [],
        ),
      );
    }
    return steps;
  }

  String? _cleanNullableFormula(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'null') return null;
    return trimmed;
  }

  IconData _actionIcon(
    encounter_models.PreparedCombatAction action,
    String source,
  ) {
    if (action.metadata['combatEffect'] == 'actionSurge') {
      return Icons.flash_on_outlined;
    }
    if (action.metadata['multiattack'] == true) {
      return Icons.auto_awesome_motion_outlined;
    }
    if (action.rollKind == encounter_models.CombatActionRollKind.healing ||
        action.healingFormula != null) {
      return Icons.favorite_border;
    }
    if (source == 'weapon') {
      return action.tags.any((tag) => tag.toLowerCase() == 'ranged')
          ? Icons.ads_click_outlined
          : Icons.gavel_outlined;
    }
    if (source == 'spell' || source == 'spellcasting') {
      if (action.saveAbility != null) return Icons.shield_outlined;
      if (action.tags.any((tag) => tag.toLowerCase().contains('evocation'))) {
        return Icons.local_fire_department_outlined;
      }
      return Icons.auto_awesome_outlined;
    }
    if (source == 'resource') return Icons.battery_charging_full_outlined;
    if (source == 'feature') return Icons.stars_outlined;
    if (source == 'monster') {
      return action.tags.any((tag) => tag.toLowerCase() == 'ranged')
          ? Icons.ads_click_outlined
          : Icons.gavel_outlined;
    }
    if (source == 'monsterFeature') return Icons.crisis_alert_outlined;
    return Icons.casino_outlined;
  }

  _CombatAccentKind _actionAccentKind(
    encounter_models.PreparedCombatAction action,
    String source,
  ) {
    if (action.metadata['combatEffect'] == 'actionSurge') {
      return _CombatAccentKind.info;
    }
    if (action.metadata['multiattack'] == true) {
      return source == 'monster'
          ? _CombatAccentKind.action
          : _CombatAccentKind.info;
    }
    if (action.rollKind == encounter_models.CombatActionRollKind.healing ||
        action.healingFormula != null) {
      return _CombatAccentKind.support;
    }
    if (source == 'spell' || source == 'spellcasting') {
      return _CombatAccentKind.magic;
    }
    if (source == 'weapon') {
      return action.tags.any((tag) => tag.toLowerCase() == 'ranged')
          ? _CombatAccentKind.read
          : _CombatAccentKind.action;
    }
    if (source == 'resource') return _CombatAccentKind.support;
    if (source == 'monster') {
      return action.tags.any((tag) => tag.toLowerCase() == 'ranged')
          ? _CombatAccentKind.read
          : _CombatAccentKind.action;
    }
    if (source == 'monsterFeature') return _CombatAccentKind.support;
    return _CombatAccentKind.info;
  }

  String _readableResourceName(String key) {
    final rawName = key.contains(':') ? key.split(':').last : key;
    return rawName
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  int _findDefaultTargetIndex(int activeIndex, [List<_Combatant>? source]) {
    final list = source ?? _combatants;
    if (list.isEmpty) return 0;
    final safeActiveIndex = activeIndex.clamp(0, list.length - 1).toInt();
    final active = list[safeActiveIndex];

    for (var index = 0; index < list.length; index++) {
      final combatant = list[index];
      if (index == safeActiveIndex) continue;
      if (combatant.team != active.team && combatant.hp > 0) {
        return index;
      }
    }

    for (var index = 0; index < list.length; index++) {
      final combatant = list[index];
      if (index == safeActiveIndex) continue;
      if (combatant.hp > 0) return index;
    }

    return safeActiveIndex;
  }

  String _attackOutcome(DiceRollResult result, _Combatant target) {
    if (result.isCriticalHit) return 'critical hit';
    if (result.isCriticalMiss) return 'automatic miss';
    return result.total >= target.ac ? 'hit' : 'miss';
  }

  String _savingThrowFormulaForTarget(_Combatant target, String ability) {
    return _formatRollFormula(
      'd20',
      _savingThrowBonusForTarget(target, ability),
    );
  }

  int _savingThrowBonusForTarget(_Combatant target, String ability) {
    final normalizedAbility = ability.trim().toUpperCase();
    final metadata = _encounter?.combatantById(target.id)?.metadata;
    final explicitSave = _intFromDynamicMap(
      metadata?['savingThrowBonuses'],
      normalizedAbility,
    );
    if (explicitSave != null) return explicitSave;

    final score = _intFromDynamicMap(
      metadata?['abilityScores'],
      normalizedAbility,
    );
    if (score != null) return ((score - 10) / 2).floor();
    return 0;
  }

  String _actionExecutionKey(_CombatAction action) {
    return _actionCardKey(action);
  }
}

int? _intFromDynamicMap(Object? raw, String key) {
  if (raw is! Map) return null;
  final value = raw[key] ?? raw[key.toUpperCase()] ?? raw[key.toLowerCase()];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _actionCardKey(_CombatAction action) {
  if (action.id.isNotEmpty) return action.id;
  return '${action.timing}|${action.type}|${action.name}';
}

bool _actionLacksResource(
  _CombatAction action,
  Map<String, int> resourcePool,
) {
  final key = action.resourceKey;
  if (key == null || action.resourceCost <= 0) return false;
  return (resourcePool[key] ?? 0) < action.resourceCost;
}

int? _actionResourceRemaining(
  _CombatAction action,
  Map<String, int> resourcePool,
) {
  final key = action.resourceKey;
  if (key == null || action.resourceCost <= 0) return null;
  return resourcePool[key] ?? 0;
}

String _readableActionResourceName(String key) {
  final rawName = key.contains(':') ? key.split(':').last : key;
  return rawName
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _CombatLayeredGameView extends StatelessWidget {
  final int round;
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final List<_CombatAction> actions;
  final _CombatRollFeedback? rollFeedback;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, _CombatAction> preparedActions;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedCommandTiming;
  final _CombatWorkspace workspace;
  final bool showEnemyHp;
  final List<_CombatLogEntry> entries;
  final Map<String, int> resourcePool;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final ValueChanged<_CombatWorkspace> onSelectWorkspace;
  final ValueChanged<String> onSelectCommandTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;

  const _CombatLayeredGameView({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.rollFeedback,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedCommandTiming,
    required this.workspace,
    required this.showEnemyHp,
    required this.entries,
    required this.resourcePool,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
    required this.onRemoveActiveEffect,
    required this.onSelectWorkspace,
    required this.onSelectCommandTiming,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideWidth = constraints.maxWidth >= 1240 ? 292.0 : 254.0;
          const gap = 12.0;
          const topHeight = 86.0;
          const modeHeight = 42.0;
          final stageTop = topHeight + gap + modeHeight + gap;
          final preferredBottomHeight =
              constraints.maxHeight >= 720 ? 252.0 : 232.0;
          final maxBottomHeight = constraints.maxHeight - stageTop - gap - 244;
          final bottomHeight = math.min(
            preferredBottomHeight,
            math.max(210.0, maxBottomHeight),
          );
          final isTurnView = workspace == _CombatWorkspace.turn;
          final isLogView = workspace == _CombatWorkspace.log;
          final hasSidebar = isTurnView || isLogView;
          final hasBottomPanel =
              isTurnView || workspace == _CombatWorkspace.overview;
          final stageBottom = hasBottomPanel ? bottomHeight + gap : 0.0;
          final stageLeft = hasSidebar ? sideWidth + gap : 0.0;
          const stageRight = 0.0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: topHeight,
                child: _GameTopHud(
                  round: round,
                  combatants: combatants,
                  activeIndex: activeIndex,
                  showEnemyHp: showEnemyHp,
                  onBack: onBack,
                  onRequestInitiative: onRequestInitiative,
                  onRollInitiative: onRollInitiative,
                  onNextTurn: onNextTurn,
                  onToggleDmView: onToggleDmView,
                  onRunDemo: onRunDemo,
                  onSelectCombatant: onSelectFocusedCombatant,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: topHeight + gap,
                height: modeHeight,
                child: _CombatModeBar(
                  workspace: workspace,
                  onSelectWorkspace: onSelectWorkspace,
                ),
              ),
              if (hasSidebar)
                Positioned(
                  left: 0,
                  top: stageTop,
                  width: sideWidth,
                  bottom: 0,
                  child: _GameCombatantPanel(
                    title: 'Focused Turn',
                    combatant: activeCombatant,
                    accentKind: _CombatAccentKind.info,
                    showEnemyHp: showEnemyHp,
                    actions: actions,
                    selectedTiming: selectedCommandTiming,
                    spentTimings: spentTimings,
                    pendingDamageActions: pendingDamageActions,
                    resourcePool: resourcePool,
                    preparedActions: preparedActions,
                    onSelectTiming: onSelectCommandTiming,
                    onRollAction: onRollAction,
                    onUseAction: onUseAction,
                    onPrepareAction: onPrepareAction,
                    onRemoveActiveEffect: onRemoveActiveEffect,
                  ),
                ),
              Positioned(
                left: stageLeft,
                right: stageRight,
                top: stageTop,
                bottom: stageBottom,
                child: _GameBattleStage(
                  combatants: combatants,
                  activeIndex: activeIndex,
                  targetIndex: targetIndex,
                  rollFeedback: rollFeedback,
                  workspace: workspace,
                  showEnemyHp: showEnemyHp,
                  entries: entries,
                  onSelectTarget: onSelectTarget,
                ),
              ),
              if (workspace == _CombatWorkspace.overview)
                Positioned(
                  left: 0,
                  bottom: 0,
                  right: 0,
                  height: bottomHeight,
                  child: _GameFeedWindow(entries: entries),
                ),
              if (isTurnView)
                Positioned(
                  left: stageLeft,
                  right: 0,
                  bottom: 0,
                  height: bottomHeight,
                  child: _CommandLayerDock(
                    activeCombatant: activeCombatant,
                    actions: actions,
                    spentTimings: spentTimings,
                    pendingDamageActions: pendingDamageActions,
                    resourcePool: resourcePool,
                    preparedActions: preparedActions,
                    queuedPreparedIndex: queuedPreparedIndex,
                    queuedPreparedTotal: queuedPreparedTotal,
                    queuedPreparedActionName: queuedPreparedActionName,
                    selectedTiming: selectedCommandTiming,
                    onSelectTiming: onSelectCommandTiming,
                    onRollAction: onRollAction,
                    onUseAction: onUseAction,
                    onPrepareAction: onPrepareAction,
                    onLaunchPreparedTurn: onLaunchPreparedTurn,
                    onClearPreparedActions: onClearPreparedActions,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CombatCompactLandscapeView extends StatelessWidget {
  final int round;
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final List<_CombatAction> actions;
  final _CombatRollFeedback? rollFeedback;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, _CombatAction> preparedActions;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedCommandTiming;
  final bool showEnemyHp;
  final Map<String, int> resourcePool;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final ValueChanged<String> onSelectCommandTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;

  const _CombatCompactLandscapeView({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.rollFeedback,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedCommandTiming,
    required this.showEnemyHp,
    required this.resourcePool,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
    required this.onRemoveActiveEffect,
    required this.onSelectCommandTiming,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final sideWidth =
              math.min(232.0, math.max(196.0, constraints.maxWidth * 0.27));
          final targetWidth =
              math.min(238.0, math.max(188.0, constraints.maxWidth * 0.25));
          final planHeight =
              math.min(128.0, math.max(112.0, constraints.maxHeight * 0.32));

          void openCatalog(String timing) {
            onSelectCommandTiming(timing);
            _showActionCatalogSheet(
              context: context,
              actions: actions,
              spentTimings: spentTimings,
              pendingDamageActions: pendingDamageActions,
              resourcePool: resourcePool,
              preparedActions: preparedActions,
              selectedTiming: timing,
              onSelectTiming: onSelectCommandTiming,
              onRollAction: onRollAction,
              onUseAction: onUseAction,
              onPrepareAction: onPrepareAction,
            );
          }

          return Column(
            children: [
              SizedBox(
                height: 54,
                child: _CompactLandscapeTopBar(
                  round: round,
                  combatants: combatants,
                  activeIndex: activeIndex,
                  showEnemyHp: showEnemyHp,
                  onBack: onBack,
                  onRequestInitiative: onRequestInitiative,
                  onRollInitiative: onRollInitiative,
                  onNextTurn: onNextTurn,
                  onToggleDmView: onToggleDmView,
                  onRunDemo: onRunDemo,
                  onSelectCombatant: onSelectFocusedCombatant,
                ),
              ),
              const SizedBox(height: gap),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: sideWidth,
                      child: _CompactActiveCombatantCard(
                        combatant: activeCombatant,
                        actions: actions,
                        selectedTiming: selectedCommandTiming,
                        spentTimings: spentTimings,
                        showEnemyHp: showEnemyHp,
                        onOpenCatalog: openCatalog,
                        onRemoveActiveEffect: onRemoveActiveEffect,
                      ),
                    ),
                    const SizedBox(width: gap),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _CombatDiceTheater(
                                    feedback: rollFeedback,
                                    activeCombatant: activeCombatant,
                                    selectedTarget: selectedTarget,
                                  ),
                                ),
                                const SizedBox(width: gap),
                                SizedBox(
                                  width: targetWidth,
                                  child: _CompactTargetCard(
                                    combatants: combatants,
                                    activeIndex: activeIndex,
                                    targetIndex: targetIndex,
                                    combatant: selectedTarget,
                                    rollFeedback: rollFeedback,
                                    showEnemyHp: showEnemyHp,
                                    onSelectTarget: onSelectTarget,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: gap),
                          SizedBox(
                            height: planHeight,
                            child: _CompactPreparedTurnStrip(
                              activeCombatant: activeCombatant,
                              actions: actions,
                              preparedActions: preparedActions,
                              spentTimings: spentTimings,
                              queuedPreparedIndex: queuedPreparedIndex,
                              queuedPreparedTotal: queuedPreparedTotal,
                              queuedPreparedActionName:
                                  queuedPreparedActionName,
                              selectedTiming: selectedCommandTiming,
                              onOpenCatalog: openCatalog,
                              onLaunch: onLaunchPreparedTurn,
                              onClear: onClearPreparedActions,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompactLandscapeTopBar extends StatelessWidget {
  final int round;
  final List<_Combatant> combatants;
  final int activeIndex;
  final bool showEnemyHp;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectCombatant;

  const _CompactLandscapeTopBar({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.showEnemyHp,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectCombatant,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.surfaceRaised.withValues(alpha: 0.94),
            tokens.panel.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _CompactIconButton(
            icon: Icons.arrow_back,
            label: 'Back',
            onTap: onBack,
          ),
          const SizedBox(width: 7),
          Container(
            width: 58,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ROUND',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$round',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: combatants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                return _CompactInitiativeChip(
                  combatant: combatants[index],
                  selected: index == activeIndex,
                  showEnemyHp: showEnemyHp,
                  onTap: () => onSelectCombatant(index),
                );
              },
            ),
          ),
          const SizedBox(width: 7),
          _CompactIconButton(
            icon: showEnemyHp
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            label: showEnemyHp ? 'DM' : 'Player',
            onTap: onToggleDmView,
          ),
          _CompactIconButton(
            icon: Icons.campaign_outlined,
            label: 'Init',
            onTap: onRequestInitiative,
          ),
          _CompactIconButton(
            icon: Icons.casino_outlined,
            label: 'Roll',
            onTap: onRollInitiative,
          ),
          _CompactIconButton(
            icon: Icons.play_circle_outline,
            label: 'Demo',
            onTap: onRunDemo,
          ),
          const SizedBox(width: 3),
          _CompactIconButton(
            icon: Icons.skip_next_rounded,
            label: 'Next',
            color: tokens.accentAction,
            onTap: onNextTurn,
          ),
        ],
      ),
    );
  }
}

class _CompactInitiativeChip extends StatelessWidget {
  final _Combatant combatant;
  final bool selected;
  final bool showEnemyHp;
  final VoidCallback onTap;

  const _CompactInitiativeChip({
    required this.combatant,
    required this.selected,
    required this.showEnemyHp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color =
        selected ? tokens.accentInfo : _teamColor(combatant.team, tokens);
    final hpLabel = _compactHpLabel(combatant, showEnemyHp);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: selected ? 104 : 86,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.22 : 0.10),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.72 : 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.20),
                border: Border.all(color: color.withValues(alpha: 0.48)),
              ),
              child: Text(
                '${combatant.initiative}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    combatant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    hpLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _CompactIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = color ?? tokens.accentRead;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: Container(
          width: 39,
          height: 38,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(color: accent.withValues(alpha: 0.26)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _CompactActiveCombatantCard extends StatelessWidget {
  final _Combatant combatant;
  final List<_CombatAction> actions;
  final String selectedTiming;
  final Set<String> spentTimings;
  final bool showEnemyHp;
  final ValueChanged<String> onOpenCatalog;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;

  const _CompactActiveCombatantCard({
    required this.combatant,
    required this.actions,
    required this.selectedTiming,
    required this.spentTimings,
    required this.showEnemyHp,
    required this.onOpenCatalog,
    required this.onRemoveActiveEffect,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(combatant.team, tokens);
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Movement'];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.28),
            tokens.surfaceRaised.withValues(alpha: 0.92),
            tokens.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTight = constraints.maxHeight < 300;
          final portraitHeight = isTight
              ? 54.0
              : math.min(86.0, math.max(58.0, constraints.maxHeight * 0.27));
          final buttonWidth = (constraints.maxWidth - 8) / 2;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: portraitHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  child: _CombatantArtwork(
                    combatant: combatant,
                    color: accent,
                    iconSize: 52,
                  ),
                ),
              ),
              SizedBox(height: isTight ? 5 : 7),
              Text(
                combatant.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              if (!isTight) ...[
                const SizedBox(height: 2),
                Text(
                  combatant.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              SizedBox(height: isTight ? 5 : 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                child: LinearProgressIndicator(
                  value: combatant.hpRatio,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              SizedBox(height: isTight ? 5 : 7),
              Row(
                children: [
                  Expanded(
                    child: _GameMetric(
                      label: 'HP',
                      value: _compactHpLabel(combatant, showEnemyHp),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _GameMetric(label: 'AC', value: '${combatant.ac}'),
                  ),
                ],
              ),
              if (!isTight && combatant.conditions.isNotEmpty) ...[
                const SizedBox(height: 7),
                SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: math.min(combatant.conditions.length, 4),
                    separatorBuilder: (_, __) => const SizedBox(width: 5),
                    itemBuilder: (context, index) {
                      final effect = combatant.conditions[index];
                      return InkWell(
                        onLongPress: () =>
                            onRemoveActiveEffect(combatant.id, effect),
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        child: _StatusChip(label: effect, color: accent),
                      );
                    },
                  ),
                ),
              ],
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 7,
                children: [
                  for (final timing in timings)
                    SizedBox(
                      width: buttonWidth,
                      child: _CompactTimingCommandButton(
                        timing: timing,
                        count: _compactActionCountForTiming(actions, timing),
                        selected: timing == selectedTiming,
                        spent: spentTimings.contains(timing),
                        onTap: () => onOpenCatalog(timing),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompactTimingCommandButton extends StatelessWidget {
  final String timing;
  final int count;
  final bool selected;
  final bool spent;
  final VoidCallback onTap;

  const _CompactTimingCommandButton({
    required this.timing,
    required this.count,
    required this.selected,
    required this.spent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = spent
        ? tokens.accentAction
        : selected
            ? tokens.accentMagic
            : tokens.accentRead;

    return InkWell(
      onTap: spent ? null : onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: spent ? 0.10 : 0.15),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.58 : 0.24)),
        ),
        child: Row(
          children: [
            Icon(
              spent ? Icons.check_circle_outline : _timingIcon(timing),
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _compactTimingLabel(timing),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: spent ? tokens.textMuted : tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactTargetCard extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _Combatant combatant;
  final _CombatRollFeedback? rollFeedback;
  final bool showEnemyHp;
  final ValueChanged<int> onSelectTarget;

  const _CompactTargetCard({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.combatant,
    required this.rollFeedback,
    required this.showEnemyHp,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(combatant.team, tokens);
    final impactFeedback = rollFeedback != null &&
            _feedbackMentionsCombatant(rollFeedback!, combatant)
        ? rollFeedback
        : null;
    final impactAccent = impactFeedback == null
        ? accent
        : _accentForKind(impactFeedback.accentKind, tokens);
    final showHp = _canShowHp(combatant, showEnemyHp);
    final isTightViewport = MediaQuery.sizeOf(context).height < 390;
    final validTargets = <int>[
      for (var index = 0; index < combatants.length; index++)
        if (index != activeIndex &&
            combatants[index].team != combatants[activeIndex].team &&
            combatants[index].hp > 0)
          index,
    ];

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            impactAccent.withValues(
                alpha: impactFeedback == null ? 0.20 : 0.34),
            tokens.surfaceRaised.withValues(alpha: 0.94),
            tokens.surface.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: impactAccent.withValues(
              alpha: impactFeedback == null ? 0.40 : 0.74),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TARGET',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (validTargets.length > 1)
                Text(
                  '${validTargets.indexOf(targetIndex) + 1}/${validTargets.length}',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          if (validTargets.isNotEmpty && !isTightViewport) ...[
            const SizedBox(height: 6),
            _TargetChoiceRail(
              combatants: combatants,
              targetIndexes: validTargets,
              selectedIndex: targetIndex,
              onSelectTarget: onSelectTarget,
            ),
          ],
          const SizedBox(height: 7),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CombatantArtwork(
                    combatant: combatant,
                    color: accent,
                    iconSize: 54,
                  ),
                  if (impactFeedback != null)
                    Positioned(
                      right: 7,
                      top: 7,
                      child: _TargetImpactBadge(
                        feedback: impactFeedback,
                        color: impactAccent,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            combatant.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            child: LinearProgressIndicator(
              value: showHp ? combatant.hpRatio : 1,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                showHp ? accent : tokens.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _GameMetric(
                  label: 'HP',
                  value: _compactHpLabel(combatant, showEnemyHp),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _GameMetric(label: 'AC', value: '${combatant.ac}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactPreparedTurnStrip extends StatelessWidget {
  final _Combatant activeCombatant;
  final List<_CombatAction> actions;
  final Map<String, _CombatAction> preparedActions;
  final Set<String> spentTimings;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final ValueChanged<String> onOpenCatalog;
  final VoidCallback onLaunch;
  final VoidCallback onClear;

  const _CompactPreparedTurnStrip({
    required this.activeCombatant,
    required this.actions,
    required this.preparedActions,
    required this.spentTimings,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedTiming,
    required this.onOpenCatalog,
    required this.onLaunch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Movement'];
    final preparedCount = preparedActions.length;
    final executableCount = preparedActions.entries
        .where((entry) => !spentTimings.contains(entry.key))
        .length;
    final queueActive =
        queuedPreparedTotal > 0 && queuedPreparedIndex < queuedPreparedTotal;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.accentMagic.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.18),
            tokens.accentAction.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.26)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.playlist_add_check_circle_outlined,
                color: tokens.accentAction,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${activeCombatant.name} turn plan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _PreparedTurnProgressPill(
                preparedCount: preparedCount,
                totalCount: timings.length,
              ),
              if (queueActive) ...[
                const SizedBox(width: 6),
                _QueuedRollPill(
                  index: queuedPreparedIndex + 1,
                  total: queuedPreparedTotal,
                  actionName: queuedPreparedActionName ?? 'Next roll',
                ),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: preparedActions.isEmpty ? null : onClear,
                icon: const Icon(Icons.close, size: 16),
                color: Colors.white,
                disabledColor: tokens.textMuted,
                tooltip: 'Clear plan',
              ),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed:
                      executableCount == 0 && !queueActive ? null : onLaunch,
                  icon: Icon(
                    queueActive
                        ? Icons.casino_outlined
                        : Icons.playlist_play_outlined,
                    size: 15,
                  ),
                  label: Text(queueActive ? 'Next' : 'Roll'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accentAction,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.08),
                    disabledForegroundColor: tokens.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Row(
              children: [
                for (var index = 0; index < timings.length; index++) ...[
                  Expanded(
                    child: _CompactPreparedSlot(
                      timing: timings[index],
                      action: preparedActions[timings[index]],
                      selected: selectedTiming == timings[index],
                      spent: spentTimings.contains(timings[index]),
                      onTap: () => onOpenCatalog(timings[index]),
                    ),
                  ),
                  if (index != timings.length - 1) ...[
                    const SizedBox(width: 6),
                    _TurnFlowArrow(
                      active: preparedActions[timings[index]] != null ||
                          spentTimings.contains(timings[index]),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPreparedSlot extends StatelessWidget {
  final String timing;
  final _CombatAction? action;
  final bool selected;
  final bool spent;
  final VoidCallback onTap;

  const _CompactPreparedSlot({
    required this.timing,
    required this.action,
    required this.selected,
    required this.spent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = spent
        ? tokens.accentAction
        : action == null
            ? (selected ? tokens.accentMagic : tokens.textMuted)
            : _accentForKind(action!.accentKind, tokens);
    final icon = spent
        ? Icons.check_circle_outline
        : action == null
            ? Icons.add_circle_outline
            : action!.icon;

    return InkWell(
      onTap: spent ? null : onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: action == null ? 0.08 : 0.18),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.56 : 0.24)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timing,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    action?.name ?? (spent ? 'Resolved' : 'Open'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              spent ? 'Done' : _preparedActionFormula(action),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: action == null ? tokens.textMuted : Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CombatModeBar extends StatelessWidget {
  final _CombatWorkspace workspace;
  final ValueChanged<_CombatWorkspace> onSelectWorkspace;

  const _CombatModeBar({
    required this.workspace,
    required this.onSelectWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.tune_outlined, color: tokens.accentInfo, size: 16),
                const SizedBox(width: 8),
                Text(
                  switch (workspace) {
                    _CombatWorkspace.turn => 'Turn workspace',
                    _CombatWorkspace.log => 'Turn log',
                    _CombatWorkspace.overview => 'Encounter overview',
                  },
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _WorkspaceToggle(
            selected: workspace,
            onSelect: onSelectWorkspace,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceToggle extends StatelessWidget {
  final _CombatWorkspace selected;
  final ValueChanged<_CombatWorkspace> onSelect;

  const _WorkspaceToggle({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WorkspaceToggleButton(
            label: 'Turn',
            icon: Icons.ads_click_outlined,
            selected: selected == _CombatWorkspace.turn,
            onTap: () => onSelect(_CombatWorkspace.turn),
          ),
          const SizedBox(width: 3),
          _WorkspaceToggleButton(
            label: 'Log',
            icon: Icons.receipt_long_outlined,
            selected: selected == _CombatWorkspace.log,
            onTap: () => onSelect(_CombatWorkspace.log),
          ),
          const SizedBox(width: 3),
          _WorkspaceToggleButton(
            label: 'Overview',
            icon: Icons.grid_view_outlined,
            selected: selected == _CombatWorkspace.overview,
            onTap: () => onSelect(_CombatWorkspace.overview),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = selected ? tokens.accentMagic : tokens.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.22 : 0.04),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.45 : 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTopHud extends StatelessWidget {
  final int round;
  final List<_Combatant> combatants;
  final int activeIndex;
  final bool showEnemyHp;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectCombatant;

  const _GameTopHud({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.showEnemyHp,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectCombatant,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF202A33).withValues(alpha: 0.96),
            tokens.surfaceRaised.withValues(alpha: 0.96),
            tokens.panel.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Icon(
                Icons.explore_outlined,
                color: Colors.white.withValues(alpha: 0.055),
                size: 112,
              ),
            ),
          ),
          Row(
            children: [
              _HudMenuButton(onBack: onBack),
              const SizedBox(width: 10),
              _HudSectionLabel(
                title: 'TURN',
                subtitle: 'ORDER',
                icon: Icons.auto_awesome_motion_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0;
                          index < combatants.length;
                          index++) ...[
                        if (index > 0) const SizedBox(width: 9),
                        _TurnOrderAvatar(
                          combatant: combatants[index],
                          isActive: index == activeIndex,
                          showEnemyHp: showEnemyHp,
                          onTap: () => onSelectCombatant(index),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _RoundBadge(round: round),
              const SizedBox(width: 10),
              _HudActionButton(
                onPressed: onToggleDmView,
                icon: showEnemyHp
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                label: showEnemyHp ? 'DM' : 'Player',
                color: showEnemyHp ? tokens.accentWarning : tokens.accentRead,
              ),
              const SizedBox(width: 7),
              _HudActionButton(
                onPressed: onRequestInitiative,
                icon: Icons.campaign_outlined,
                label: 'Ask Init',
                color: tokens.accentRead,
              ),
              const SizedBox(width: 7),
              _HudActionButton(
                onPressed: onRollInitiative,
                icon: Icons.casino_outlined,
                label: 'Roll',
                color: tokens.accentMagic,
              ),
              const SizedBox(width: 7),
              _HudActionButton(
                onPressed: onRunDemo,
                icon: Icons.play_circle_outline,
                label: 'Demo',
                color: tokens.accentAction,
              ),
              const SizedBox(width: 7),
              _HudNextButton(onPressed: onNextTurn),
            ],
          ),
        ],
      ),
    );
  }
}

class _TurnOrderAvatar extends StatelessWidget {
  final _Combatant combatant;
  final bool isActive;
  final bool showEnemyHp;
  final VoidCallback onTap;

  const _TurnOrderAvatar({
    required this.combatant,
    required this.isActive,
    required this.showEnemyHp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent =
        isActive ? tokens.accentInfo : _teamColor(combatant.team, tokens);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: isActive ? 142 : 126,
        height: 62,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: isActive ? 0.28 : 0.14),
              tokens.surfaceRaised.withValues(alpha: isActive ? 0.92 : 0.78),
              Colors.black.withValues(alpha: 0.22),
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: accent.withValues(alpha: isActive ? 0.76 : 0.26),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: accent.withValues(alpha: 0.26),
                blurRadius: 18,
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
                border: Border.all(color: accent.withValues(alpha: 0.54)),
              ),
              child: _CombatantArtwork(
                combatant: combatant,
                color: accent,
                iconSize: 19,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius:
                              BorderRadius.circular(tokens.radiusPill),
                        ),
                        child: Text(
                          '${combatant.initiative}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          combatant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    child: LinearProgressIndicator(
                      value: _canShowHp(combatant, showEnemyHp)
                          ? combatant.hpRatio
                          : 1,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _canShowHp(combatant, showEnemyHp)
                            ? combatant.hpRatio <= 0.30
                                ? tokens.accentAction
                                : tokens.accentSuccess
                            : tokens.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _compactHpLabel(combatant, showEnemyHp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.play_arrow_rounded,
                color: accent,
                size: 17,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HudMenuButton extends StatelessWidget {
  final VoidCallback onBack;

  const _HudMenuButton({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: onBack,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'MENU',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudSectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HudSectionLabel({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return SizedBox(
      width: 76,
      child: Row(
        children: [
          Icon(icon, color: tokens.accentInfo, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$title\n$subtitle',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _HudActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: color.withValues(alpha: 0.30)),
        backgroundColor: color.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HudNextButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HudNextButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.skip_next, size: 16),
      label: const Text('Next'),
      style: FilledButton.styleFrom(
        backgroundColor: tokens.accentAction,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  final int round;

  const _RoundBadge({
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: 72,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.30)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ROUND',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '$round',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCombatantPanel extends StatelessWidget {
  final String title;
  final _Combatant combatant;
  final _CombatAccentKind accentKind;
  final bool showEnemyHp;
  final List<_CombatAction>? actions;
  final String? selectedTiming;
  final Set<String>? spentTimings;
  final Set<String>? pendingDamageActions;
  final Map<String, int>? resourcePool;
  final Map<String, _CombatAction>? preparedActions;
  final ValueChanged<String>? onSelectTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)?
      onRollAction;
  final ValueChanged<_CombatAction>? onUseAction;
  final ValueChanged<_CombatAction>? onPrepareAction;
  final void Function(String combatantId, String effectName)?
      onRemoveActiveEffect;

  const _GameCombatantPanel({
    required this.title,
    required this.combatant,
    required this.accentKind,
    this.showEnemyHp = true,
    this.actions,
    this.selectedTiming,
    this.spentTimings,
    this.pendingDamageActions,
    this.resourcePool,
    this.preparedActions,
    this.onSelectTiming,
    this.onRollAction,
    this.onUseAction,
    this.onPrepareAction,
    this.onRemoveActiveEffect,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(accentKind, tokens);
    final isDown = combatant.hp <= 0;
    final showHp = _canShowHp(combatant, showEnemyHp);
    final statusLabels = [
      if (combatant.tempHp > 0) 'Temp HP ${combatant.tempHp}',
      ...combatant.conditions.take(7),
    ];
    final canShowActionAccess = actions != null &&
        selectedTiming != null &&
        spentTimings != null &&
        pendingDamageActions != null &&
        resourcePool != null &&
        preparedActions != null &&
        onSelectTiming != null &&
        onRollAction != null &&
        onUseAction != null &&
        onPrepareAction != null;

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            tokens.panel.withValues(alpha: 0.94),
            tokens.surface.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.40)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 118,
              child: _CombatantPortraitFrame(
                combatant: combatant,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              combatant.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              combatant.role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              child: LinearProgressIndicator(
                value: showHp ? combatant.hpRatio : 1,
                minHeight: 11,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  !showHp
                      ? tokens.textMuted
                      : isDown
                          ? tokens.textMuted
                          : combatant.hpRatio <= 0.30
                              ? tokens.accentAction
                              : tokens.accentSuccess,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _GameMetric(
                    label: 'HP',
                    value: _compactHpLabel(combatant, showEnemyHp),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GameMetric(label: 'AC', value: '${combatant.ac}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _GameMetric(
                    label: 'INIT',
                    value: '${combatant.initiative}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GameMetric(label: 'SPD', value: '${combatant.speed}'),
                ),
              ],
            ),
            if (statusLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ActiveEffectsPanel(
                combatant: combatant,
                labels: statusLabels,
                color: accent,
                onRemove: onRemoveActiveEffect == null
                    ? null
                    : (effectName) =>
                        onRemoveActiveEffect!(combatant.id, effectName),
              ),
            ],
            if (canShowActionAccess) ...[
              const SizedBox(height: 12),
              _CharacterActionAccessPanel(
                actions: actions!,
                selectedTiming: selectedTiming!,
                spentTimings: spentTimings!,
                pendingDamageActions: pendingDamageActions!,
                resourcePool: resourcePool!,
                preparedActions: preparedActions!,
                onSelectTiming: onSelectTiming!,
                onRollAction: onRollAction!,
                onUseAction: onUseAction!,
                onPrepareAction: onPrepareAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CharacterActionAccessPanel extends StatelessWidget {
  final List<_CombatAction> actions;
  final String selectedTiming;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, int> resourcePool;
  final Map<String, _CombatAction> preparedActions;
  final ValueChanged<String> onSelectTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;

  const _CharacterActionAccessPanel({
    required this.actions,
    required this.selectedTiming,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.resourcePool,
    required this.preparedActions,
    required this.onSelectTiming,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Movement'];

    _CombatAction? pendingDamageActionFor(String timing) {
      for (final action in actions) {
        if (action.timing == timing &&
            pendingDamageActions.contains(_actionCardKey(action))) {
          return action;
        }
      }
      return null;
    }

    void openCatalog(String timing) {
      onSelectTiming(timing);
      _showActionCatalogSheet(
        context: context,
        actions: actions,
        spentTimings: spentTimings,
        pendingDamageActions: pendingDamageActions,
        resourcePool: resourcePool,
        preparedActions: preparedActions,
        selectedTiming: timing,
        onSelectTiming: onSelectTiming,
        onRollAction: onRollAction,
        onUseAction: onUseAction,
        onPrepareAction: onPrepareAction,
      );
    }

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_motion_outlined,
                  color: tokens.accentMagic, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ACTIONS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final timing in timings) ...[
            if (timing != timings.first) const SizedBox(height: 6),
            _CharacterActionAccessRow(
              timing: timing,
              count: actions.where((action) => action.timing == timing).length,
              action: pendingDamageActionFor(timing) ?? preparedActions[timing],
              selected: selectedTiming == timing,
              spent: spentTimings.contains(timing),
              resolvingDamage: pendingDamageActionFor(timing) != null,
              onTap: () => openCatalog(timing),
            ),
          ],
        ],
      ),
    );
  }
}

class _CharacterActionAccessRow extends StatelessWidget {
  final String timing;
  final int count;
  final _CombatAction? action;
  final bool selected;
  final bool spent;
  final bool resolvingDamage;
  final VoidCallback onTap;

  const _CharacterActionAccessRow({
    required this.timing,
    required this.count,
    required this.action,
    required this.selected,
    required this.spent,
    this.resolvingDamage = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = resolvingDamage
        ? tokens.accentSuccess
        : spent
            ? tokens.accentAction
            : action == null
                ? (selected ? tokens.accentMagic : tokens.accentRead)
                : _accentForKind(action!.accentKind, tokens);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.20 : 0.10),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.48 : 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(
              resolvingDamage
                  ? Icons.auto_fix_high_outlined
                  : spent
                      ? Icons.check_circle_outline
                      : action?.icon ?? Icons.grid_view_outlined,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                resolvingDamage
                    ? 'Resolve damage'
                    : action?.name ?? (spent ? '$timing spent' : timing),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(minWidth: 30),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Text(
                resolvingDamage
                    ? 'Hit'
                    : spent
                        ? 'Done'
                        : action == null
                            ? '$count'
                            : 'Ready',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: action == null ? tokens.textSecondary : Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveEffectsPanel extends StatelessWidget {
  final _Combatant combatant;
  final List<String> labels;
  final Color color;
  final ValueChanged<String>? onRemove;

  const _ActiveEffectsPanel({
    required this.combatant,
    required this.labels,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final activeLabels = labels
        .where((label) => label != 'Player Character')
        .toList(growable: false);
    if (activeLabels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ACTIVE EFFECTS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final label in activeLabels.take(8))
                _ActiveEffectChip(
                  label: label,
                  color: _statusAccentForLabel(label, tokens, color),
                  removable: _canRemoveEffect(label) && onRemove != null,
                  onRemove: () => onRemove?.call(label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveEffectChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool removable;
  final VoidCallback onRemove;

  const _ActiveEffectChip({
    required this.label,
    required this.color,
    required this.removable,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    return Container(
      constraints: const BoxConstraints(maxWidth: 212),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIconForLabel(label), color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _effectDisplayLabel(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (removable) ...[
            const SizedBox(width: 5),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              child: Icon(Icons.close, color: Colors.white, size: 13),
            ),
          ],
        ],
      ),
    );
  }
}

bool _canRemoveEffect(String label) {
  final lower = label.toLowerCase();
  return lower.contains('concentrating') ||
      lower.contains('rage') ||
      lower.contains('inspiration') ||
      lower.contains('marked') ||
      lower.contains('blessed');
}

String _effectDisplayLabel(String label) {
  if (label == 'Concentrating') return 'Concentration';
  return label;
}

class _CombatantPortraitFrame extends StatelessWidget {
  final _Combatant combatant;
  final Color color;

  const _CombatantPortraitFrame({
    required this.combatant,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _CombatantArtwork(
              combatant: combatant,
              color: color,
              iconSize: 54,
            ),
          ),
        ],
      ),
    );
  }
}

class _CombatantArtwork extends StatelessWidget {
  final _Combatant combatant;
  final Color color;
  final double iconSize;

  const _CombatantArtwork({
    required this.combatant,
    required this.color,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = _PortraitIconFallback(
      combatant: combatant,
      color: color,
      iconSize: iconSize,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (combatant.portraitAsset == null)
          fallback
        else
          Image.asset(
            combatant.portraitAsset!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallback,
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.30),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PortraitIconFallback extends StatelessWidget {
  final _Combatant combatant;
  final Color color;
  final double iconSize;

  const _PortraitIconFallback({
    required this.combatant,
    required this.color,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color.withValues(alpha: 0.10),
      child: Center(
        child: Icon(
          _portraitIconForCombatant(combatant),
          color: Colors.white.withValues(alpha: 0.92),
          size: iconSize,
        ),
      ),
    );
  }
}

class _GameMetric extends StatelessWidget {
  final String label;
  final String value;

  const _GameMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBattleStage extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _CombatRollFeedback? rollFeedback;
  final _CombatWorkspace workspace;
  final bool showEnemyHp;
  final List<_CombatLogEntry> entries;
  final ValueChanged<int> onSelectTarget;

  const _GameBattleStage({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.rollFeedback,
    required this.workspace,
    required this.showEnemyHp,
    required this.entries,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: tokens.accentInfo.withValues(alpha: 0.10),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GameBattleStagePainter(tokens: tokens),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: switch (workspace) {
                _CombatWorkspace.overview => _EncounterOverviewStage(
                    combatants: combatants,
                    activeIndex: activeIndex,
                    targetIndex: targetIndex,
                    rollFeedback: rollFeedback,
                    showEnemyHp: showEnemyHp,
                  ),
                _CombatWorkspace.log => _TurnLogStage(entries: entries),
                _CombatWorkspace.turn => _FocusedTurnStage(
                    combatants: combatants,
                    activeIndex: activeIndex,
                    targetIndex: targetIndex,
                    activeCombatant: combatants[activeIndex],
                    selectedTarget: combatants[targetIndex],
                    rollFeedback: rollFeedback,
                    showEnemyHp: showEnemyHp,
                    onSelectTarget: onSelectTarget,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusedTurnStage extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final _CombatRollFeedback? rollFeedback;
  final bool showEnemyHp;
  final ValueChanged<int> onSelectTarget;

  const _FocusedTurnStage({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.rollFeedback,
    required this.showEnemyHp,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _CombatDiceTheater(
            feedback: rollFeedback,
            activeCombatant: activeCombatant,
            selectedTarget: selectedTarget,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _SelectedTargetPortraitCard(
            combatants: combatants,
            activeIndex: activeIndex,
            targetIndex: targetIndex,
            combatant: selectedTarget,
            rollFeedback: rollFeedback,
            showEnemyHp: showEnemyHp,
            onSelectTarget: onSelectTarget,
          ),
        ),
      ],
    );
  }
}

class _TurnLogStage extends StatelessWidget {
  final List<_CombatLogEntry> entries;

  const _TurnLogStage({
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return _GameFeedWindow(
      entries: entries,
      maxEntries: 18,
    );
  }
}

class _EncounterOverviewStage extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _CombatRollFeedback? rollFeedback;
  final bool showEnemyHp;

  const _EncounterOverviewStage({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.rollFeedback,
    required this.showEnemyHp,
  });

  @override
  Widget build(BuildContext context) {
    final party = <_IndexedCombatant>[];
    final enemies = <_IndexedCombatant>[];
    for (var index = 0; index < combatants.length; index++) {
      final entry = _IndexedCombatant(index, combatants[index]);
      if (entry.combatant.team == _CombatTeam.party) {
        party.add(entry);
      } else {
        enemies.add(entry);
      }
    }

    return Row(
      children: [
        Expanded(
          child: _EncounterTeamColumn(
            title: 'Party',
            entries: party,
            activeIndex: activeIndex,
            targetIndex: targetIndex,
            showEnemyHp: showEnemyHp,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _EncounterTeamColumn(
            title: 'Enemies',
            entries: enemies,
            activeIndex: activeIndex,
            targetIndex: targetIndex,
            showEnemyHp: showEnemyHp,
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 248,
          child: _OverviewRollSummary(feedback: rollFeedback),
        ),
      ],
    );
  }
}

class _EncounterTeamColumn extends StatelessWidget {
  final String title;
  final List<_IndexedCombatant> entries;
  final int activeIndex;
  final int targetIndex;
  final bool showEnemyHp;

  const _EncounterTeamColumn({
    required this.title,
    required this.entries,
    required this.activeIndex,
    required this.targetIndex,
    required this.showEnemyHp,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final isParty = title.toLowerCase() == 'party';
    final color = isParty ? tokens.accentRead : tokens.accentAction;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isParty ? Icons.groups_2_outlined : Icons.crisis_alert_outlined,
                color: color,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${entries.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _OverviewCombatantCard(
                  entry: entry,
                  isActive: entry.index == activeIndex,
                  isTargeted: entry.index == targetIndex,
                  showEnemyHp: showEnemyHp,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCombatantCard extends StatelessWidget {
  final _IndexedCombatant entry;
  final bool isActive;
  final bool isTargeted;
  final bool showEnemyHp;

  const _OverviewCombatantCard({
    required this.entry,
    required this.isActive,
    required this.isTargeted,
    required this.showEnemyHp,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final combatant = entry.combatant;
    final accent = isTargeted
        ? tokens.accentAction
        : isActive
            ? tokens.accentInfo
            : _teamColor(combatant.team, tokens);
    final showHp = _canShowHp(combatant, showEnemyHp);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isActive || isTargeted ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: accent.withValues(alpha: isActive || isTargeted ? 0.48 : 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(color: accent.withValues(alpha: 0.42)),
            ),
            child: Text(
              '${combatant.initiative}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        combatant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.22)),
                      ),
                      child: Text(
                        _compactHpLabel(combatant, showEnemyHp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: showHp ? Colors.white : tokens.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isActive || isTargeted) const SizedBox(width: 6),
                    if (isActive)
                      Icon(Icons.play_arrow_rounded,
                          color: tokens.accentInfo, size: 18)
                    else if (isTargeted)
                      Icon(Icons.my_location_outlined,
                          color: tokens.accentAction, size: 16),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: showHp ? combatant.hpRatio : 1,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      showHp ? tokens.accentSuccess : tokens.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'AC ${combatant.ac}   ${combatant.role}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewRollSummary extends StatelessWidget {
  final _CombatRollFeedback? feedback;

  const _OverviewRollSummary({
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = feedback == null
        ? tokens.accentMagic
        : _accentForKind(feedback!.accentKind, tokens);
    final result = feedback?.result;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'LAST ROLL',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: _LargeDiceBadge(
                total: result?.total,
                formula: result?.formula,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feedback?.headline ?? 'No roll yet',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          if (feedback?.subline != null) ...[
            const SizedBox(height: 5),
            Text(
              feedback!.subline!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CombatDiceTheater extends StatelessWidget {
  final _CombatRollFeedback? feedback;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;

  const _CombatDiceTheater({
    required this.feedback,
    required this.activeCombatant,
    required this.selectedTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = feedback == null
        ? tokens.accentMagic
        : _accentForKind(feedback!.accentKind, tokens);
    final actorColor = _teamColor(activeCombatant.team, tokens);
    final targetColor = _teamColor(selectedTarget.team, tokens);
    final result = feedback?.result;
    final hasFeedback = feedback != null;

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.05,
          colors: [
            accent.withValues(alpha: hasFeedback ? 0.28 : 0.18),
            tokens.surface.withValues(alpha: 0.52),
            Colors.black.withValues(alpha: 0.26),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: accent.withValues(alpha: hasFeedback ? 0.42 : 0.24),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -44,
            child: Icon(
              Icons.hexagon_outlined,
              color: accent.withValues(alpha: 0.08),
              size: 190,
            ),
          ),
          Positioned(
            left: -80,
            bottom: -72,
            child: Container(
              width: 250,
              height: 180,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    actorColor.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -64,
            bottom: -56,
            child: Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    targetColor.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.casino_outlined, color: accent, size: 17),
                  const SizedBox(width: 7),
                  Text(
                    'ROLL FEEDBACK',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feedback?.action ?? 'Awaiting command',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _DiceTheaterScene(
                    key: ValueKey(
                      '${feedback?.headline ?? 'empty'}-${result?.total ?? 'idle'}',
                    ),
                    feedback: feedback,
                    activeCombatant: activeCombatant,
                    selectedTarget: selectedTarget,
                    accent: accent,
                    actorColor: actorColor,
                    targetColor: targetColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiceTheaterScene extends StatelessWidget {
  final _CombatRollFeedback? feedback;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final Color accent;
  final Color actorColor;
  final Color targetColor;

  const _DiceTheaterScene({
    super.key,
    required this.feedback,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.accent,
    required this.actorColor,
    required this.targetColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final result = feedback?.result;
    final hasFeedback = feedback != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 520 || constraints.maxHeight < 210;

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DiceTheaterImpactPainter(
                  accent: accent,
                  actorColor: actorColor,
                  targetColor: targetColor,
                  active: hasFeedback,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: compact ? 18 : 32,
              bottom: compact ? 18 : 28,
              width: compact ? 94 : 122,
              child: _DuelStagePortrait(
                combatant: activeCombatant,
                label: 'ACTOR',
                color: actorColor,
                alignRight: false,
              ),
            ),
            Positioned(
              right: 0,
              top: compact ? 18 : 32,
              bottom: compact ? 18 : 28,
              width: compact ? 94 : 122,
              child: _DuelStagePortrait(
                combatant: selectedTarget,
                label: 'TARGET',
                color: targetColor,
                alignRight: true,
              ),
            ),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LargeDiceBadge(
                      total: result?.total,
                      formula: result?.formula,
                      color: accent,
                      compact: compact,
                    ),
                    const SizedBox(height: 8),
                    if (feedback == null)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Choose target and roll.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _DiceExpressionChip(
                            label:
                                '${activeCombatant.name} -> ${selectedTarget.name}',
                            color: accent,
                          ),
                        ],
                      )
                    else ...[
                      _ImpactHeadlinePill(
                        label: feedback!.headline,
                        color: accent,
                        compact: compact,
                      ),
                      if (feedback!.subline != null &&
                          feedback!.subline!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: compact ? 230 : 380,
                          ),
                          child: Text(
                            feedback!.subline!,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: compact ? 10 : 11,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                      if (result != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _DiceExpressionChip(
                              label: result.formula,
                              color: accent,
                            ),
                            _DiceExpressionChip(
                              label: result.rollsText,
                              color: tokens.accentRead,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DuelStagePortrait extends StatelessWidget {
  final _Combatant combatant;
  final String label;
  final Color color;
  final bool alignRight;

  const _DuelStagePortrait({
    required this.combatant,
    required this.label,
    required this.color,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: _CombatantArtwork(
                combatant: combatant,
                color: color,
                iconSize: 36,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              color: Colors.black.withValues(alpha: 0.38),
              child: Column(
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    combatant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactHeadlinePill extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _ImpactHeadlinePill({
    required this.label,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 15 : 18,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _LargeDiceBadge extends StatelessWidget {
  final int? total;
  final String? formula;
  final Color color;
  final bool compact;

  const _LargeDiceBadge({
    required this.total,
    required this.formula,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -math.pi / 10,
          child: ClipPath(
            clipper: _DiceGemClipper(),
            child: Container(
              width: compact ? 56 : 70,
              height: compact ? 56 : 70,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.82),
                    tokens.surfaceRaised.withValues(alpha: 0.97),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.34),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _DiceGemPainter(color: color),
                child: Transform.rotate(
                  angle: math.pi / 10,
                  child: Center(
                    child: total == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.casino_outlined,
                                color: Colors.white,
                                size: compact ? 22 : 25,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'D20',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            '$total',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 24 : 29,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          formula ?? 'Waiting for the roll',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DiceGemClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.50, 0)
      ..lineTo(size.width * 0.88, size.height * 0.16)
      ..lineTo(size.width, size.height * 0.52)
      ..lineTo(size.width * 0.72, size.height * 0.92)
      ..lineTo(size.width * 0.28, size.height * 0.92)
      ..lineTo(0, size.height * 0.52)
      ..lineTo(size.width * 0.12, size.height * 0.16)
      ..close();
  }

  @override
  bool shouldReclip(covariant _DiceGemClipper oldClipper) => false;
}

class _DiceGemPainter extends CustomPainter {
  final Color color;

  const _DiceGemPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: 0.72);
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Colors.white.withValues(alpha: 0.14);
    final path = _DiceGemClipper().getClip(size);
    canvas.drawPath(path, border);
    final center = Offset(size.width * 0.50, size.height * 0.54);
    for (final point in [
      Offset(size.width * 0.50, 0),
      Offset(size.width * 0.88, size.height * 0.16),
      Offset(size.width, size.height * 0.52),
      Offset(size.width * 0.72, size.height * 0.92),
      Offset(size.width * 0.28, size.height * 0.92),
      Offset(0, size.height * 0.52),
      Offset(size.width * 0.12, size.height * 0.16),
    ]) {
      canvas.drawLine(center, point, facet);
    }
  }

  @override
  bool shouldRepaint(covariant _DiceGemPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DiceTheaterImpactPainter extends CustomPainter {
  final Color accent;
  final Color actorColor;
  final Color targetColor;
  final bool active;

  const _DiceTheaterImpactPainter({
    required this.accent,
    required this.actorColor,
    required this.targetColor,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.50;
    final actor = Offset(size.width * 0.17, centerY);
    final target = Offset(size.width * 0.83, centerY);
    final center = Offset(size.width * 0.50, centerY);

    final lane = Paint()
      ..shader = LinearGradient(
        colors: [
          actorColor.withValues(alpha: active ? 0.04 : 0.02),
          accent.withValues(alpha: active ? 0.20 : 0.08),
          targetColor.withValues(alpha: active ? 0.04 : 0.02),
        ],
      ).createShader(Offset.zero & size)
      ..strokeWidth = active ? 10 : 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(actor, target, lane);

    final thinLane = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: active ? 0.48 : 0.18);
    final path = Path()
      ..moveTo(actor.dx, actor.dy)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.26,
        center.dx,
        center.dy,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.74,
        target.dx,
        target.dy,
      );
    canvas.drawPath(path, thinLane);

    for (final radius in [44.0, 72.0, 104.0]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: active ? 0.10 : 0.05),
      );
    }

    final burst = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: active ? 0.30 : 0.10),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.shortestSide * 0.38),
      );
    canvas.drawCircle(center, size.shortestSide * 0.38, burst);
  }

  @override
  bool shouldRepaint(covariant _DiceTheaterImpactPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.actorColor != actorColor ||
        oldDelegate.targetColor != targetColor ||
        oldDelegate.active != active;
  }
}

class _SelectedTargetPortraitCard extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _Combatant combatant;
  final _CombatRollFeedback? rollFeedback;
  final bool showEnemyHp;
  final ValueChanged<int> onSelectTarget;

  const _SelectedTargetPortraitCard({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.combatant,
    required this.rollFeedback,
    required this.showEnemyHp,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(combatant.team, tokens);
    final impactFeedback = rollFeedback != null &&
            _feedbackMentionsCombatant(rollFeedback!, combatant)
        ? rollFeedback
        : null;
    final impactAccent = impactFeedback == null
        ? accent
        : _accentForKind(impactFeedback.accentKind, tokens);
    final showHp = _canShowHp(combatant, showEnemyHp);
    final validTargets = <int>[
      for (var index = 0; index < combatants.length; index++)
        if (index != activeIndex &&
            combatants[index].team != combatants[activeIndex].team &&
            combatants[index].hp > 0)
          index,
    ];

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.26),
            tokens.surfaceRaised.withValues(alpha: 0.94),
            tokens.surface.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: impactAccent.withValues(
              alpha: impactFeedback == null ? 0.44 : 0.78),
        ),
        boxShadow: [
          if (impactFeedback != null)
            BoxShadow(
              color: impactAccent.withValues(alpha: 0.24),
              blurRadius: 28,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -22,
            child: Icon(
              _portraitIconForCombatant(combatant),
              color: Colors.white.withValues(alpha: 0.055),
              size: 164,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  combatant.team == _CombatTeam.enemy
                      ? 'CURRENT TARGET'
                      : 'SELECTED ALLY',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                if (validTargets.isNotEmpty) ...[
                  _TargetChoiceRail(
                    combatants: combatants,
                    targetIndexes: validTargets,
                    selectedIndex: targetIndex,
                    onSelectTarget: onSelectTarget,
                  ),
                  const SizedBox(height: 7),
                ],
                Expanded(
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(color: accent.withValues(alpha: 0.20)),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CombatantArtwork(
                          combatant: combatant,
                          color: accent,
                          iconSize: 78,
                        ),
                        if (impactFeedback != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _TargetImpactBadge(
                              feedback: impactFeedback,
                              color: impactAccent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  combatant.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  combatant.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: showHp ? combatant.hpRatio : 1,
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      showHp ? accent : tokens.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _GameMetric(
                        label: 'HP',
                        value: _compactHpLabel(combatant, showEnemyHp),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GameMetric(label: 'AC', value: '${combatant.ac}'),
                    ),
                  ],
                ),
                if (combatant.conditions.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: math.min(combatant.conditions.length, 5),
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        return _StatusChip(
                          label: combatant.conditions[index],
                          color: accent,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _feedbackMentionsCombatant(
  _CombatRollFeedback feedback,
  _Combatant combatant,
) {
  final name = combatant.name.trim().toLowerCase();
  if (name.isEmpty) return false;
  final haystack = [
    feedback.actor,
    feedback.action,
    feedback.headline,
    feedback.subline ?? '',
  ].join(' ').toLowerCase();
  return haystack.contains(name);
}

class _TargetImpactBadge extends StatelessWidget {
  final _CombatRollFeedback feedback;
  final Color color;

  const _TargetImpactBadge({
    required this.feedback,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final label = _targetImpactLabel(feedback);

    return TweenAnimationBuilder<double>(
      key: ValueKey(
        '${feedback.actor}-${feedback.action}-${feedback.headline}-${feedback.result?.total}',
      ),
      tween: Tween(begin: 0.86, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.90),
              color.withValues(alpha: 0.54),
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.42),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _targetImpactIcon(feedback),
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _targetImpactLabel(_CombatRollFeedback feedback) {
  final text = feedback.headline.trim();
  if (text.isEmpty) return 'ROLL';
  if (text.length <= 16) return text;
  return '${text.substring(0, 15)}...';
}

IconData _targetImpactIcon(_CombatRollFeedback feedback) {
  final text = '${feedback.headline} ${feedback.action}'.toLowerCase();
  if (text.contains('crit')) return Icons.emergency_outlined;
  if (text.contains('miss') || text.contains('save success')) {
    return Icons.shield_outlined;
  }
  if (text.contains('heal')) return Icons.favorite_border;
  if (text.contains('damage') || text.contains('hit')) {
    return Icons.bolt_outlined;
  }
  return Icons.casino_outlined;
}

class _TargetChoiceRail extends StatelessWidget {
  final List<_Combatant> combatants;
  final List<int> targetIndexes;
  final int selectedIndex;
  final ValueChanged<int> onSelectTarget;

  const _TargetChoiceRail({
    required this.combatants,
    required this.targetIndexes,
    required this.selectedIndex,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: targetIndexes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final combatantIndex = targetIndexes[index];
          final combatant = combatants[combatantIndex];
          final selected = combatantIndex == selectedIndex;
          final color = selected ? tokens.accentAction : tokens.accentRead;

          return InkWell(
            onTap: () => onSelectTarget(combatantIndex),
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              constraints: const BoxConstraints(maxWidth: 138),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.24 : 0.10),
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                border: Border.all(
                  color: color.withValues(alpha: selected ? 0.56 : 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected
                        ? Icons.my_location_outlined
                        : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      combatant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GameBattleStagePainter extends CustomPainter {
  final StitchThemeTokens tokens;

  const _GameBattleStagePainter({
    required this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF273033),
          const Color(0xFF1A2024),
          const Color(0xFF12171C),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    _drawDungeonFloor(canvas, size);
    _drawDungeonWalls(canvas, size);

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tokens.accentInfo.withValues(alpha: 0.11);
    const cell = 74.0;
    for (var x = -cell * 3; x < size.width + cell * 3; x += cell) {
      final path = Path()
        ..moveTo(x, size.height * 0.12)
        ..lineTo(x + size.height * 0.52, size.height * 0.92);
      canvas.drawPath(path, gridPaint);
    }
    for (var x = -cell; x < size.width + cell * 4; x += cell) {
      final path = Path()
        ..moveTo(x, size.height * 0.92)
        ..lineTo(x - size.height * 0.52, size.height * 0.12);
      canvas.drawPath(path, gridPaint);
    }

    final pathPaint = Paint()
      ..color = tokens.accentSuccess.withValues(alpha: 0.13);
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.72)
      ..lineTo(size.width * 0.42, size.height * 0.45)
      ..lineTo(size.width * 0.77, size.height * 0.66)
      ..lineTo(size.width * 0.51, size.height * 0.90)
      ..close();
    canvas.drawPath(path, pathPaint);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tokens.accentSuccess.withValues(alpha: 0.18),
    );

    final dangerPaint = Paint()
      ..color = tokens.accentAction.withValues(alpha: 0.13);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.80, size.height * 0.42),
        width: size.width * 0.28,
        height: size.height * 0.30,
      ),
      dangerPaint,
    );

    _drawTorchGlow(
      canvas,
      size,
      Offset(size.width * 0.20, size.height * 0.30),
    );
    _drawTorchGlow(
      canvas,
      size,
      Offset(size.width * 0.86, size.height * 0.26),
    );

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          tokens.accentInfo.withValues(alpha: 0.20),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.36, size.height * 0.56),
          radius: size.shortestSide * 0.38,
        ),
      );
    canvas.drawRect(rect, glowPaint);

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.42),
        ],
        stops: const [0.50, 1],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant _GameBattleStagePainter oldDelegate) {
    return oldDelegate.tokens != tokens;
  }

  void _drawDungeonFloor(Canvas canvas, Size size) {
    final floor = Path()
      ..moveTo(size.width * 0.13, size.height * 0.74)
      ..lineTo(size.width * 0.36, size.height * 0.30)
      ..lineTo(size.width * 0.82, size.height * 0.28)
      ..lineTo(size.width * 0.93, size.height * 0.62)
      ..lineTo(size.width * 0.57, size.height * 0.91)
      ..close();
    canvas.drawPath(
      floor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4B463C).withValues(alpha: 0.33),
            const Color(0xFF2F372F).withValues(alpha: 0.18),
            const Color(0xFF151A1F).withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      floor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.05),
    );

    final tilePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.045);
    for (var i = 0; i < 10; i++) {
      final t = i / 9;
      canvas.drawLine(
        Offset(size.width * (0.17 + t * 0.42), size.height * 0.71),
        Offset(size.width * (0.40 + t * 0.40), size.height * 0.31),
        tilePaint,
      );
      canvas.drawLine(
        Offset(size.width * (0.29 + t * 0.54), size.height * 0.35),
        Offset(size.width * (0.52 + t * 0.36), size.height * 0.88),
        tilePaint,
      );
    }
  }

  void _drawDungeonWalls(Canvas canvas, Size size) {
    final wallPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF394148).withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);
    final leftWall = Path()
      ..moveTo(size.width * 0.08, size.height * 0.20)
      ..lineTo(size.width * 0.34, size.height * 0.08)
      ..lineTo(size.width * 0.36, size.height * 0.30)
      ..lineTo(size.width * 0.13, size.height * 0.74)
      ..lineTo(size.width * 0.03, size.height * 0.60)
      ..close();
    final backWall = Path()
      ..moveTo(size.width * 0.34, size.height * 0.08)
      ..lineTo(size.width * 0.88, size.height * 0.10)
      ..lineTo(size.width * 0.82, size.height * 0.28)
      ..lineTo(size.width * 0.36, size.height * 0.30)
      ..close();
    canvas.drawPath(leftWall, wallPaint);
    canvas.drawPath(backWall, wallPaint);
  }

  void _drawTorchGlow(Canvas canvas, Size size, Offset center) {
    canvas.drawCircle(
      center,
      size.shortestSide * 0.18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tokens.accentWarning.withValues(alpha: 0.16),
            tokens.accentAction.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: center, radius: size.shortestSide * 0.18),
        ),
    );
    canvas.drawCircle(
      center,
      3.0,
      Paint()..color = tokens.accentWarning.withValues(alpha: 0.70),
    );
  }
}

class _RollFeedbackWindow extends StatelessWidget {
  final _CombatRollFeedback feedback;

  const _RollFeedbackWindow({
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(feedback.accentKind, tokens);
    final result = feedback.result;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(
            '${feedback.action}-${result?.total}-${feedback.headline}'),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.28),
              tokens.surfaceRaised.withValues(alpha: 0.95),
              tokens.surface.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: accent.withValues(alpha: 0.52)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: result == null
                  ? Icon(
                      Icons.auto_awesome_outlined,
                      color: Colors.white,
                      size: 28,
                    )
                  : Text(
                      '${result.total}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${feedback.actor} - ${feedback.action}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feedback.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (feedback.subline != null &&
                      feedback.subline!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      feedback.subline!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (result != null) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _DiceExpressionChip(
                          label: result.formula,
                          color: accent,
                        ),
                        _DiceExpressionChip(
                          label: result.rollsText,
                          color: tokens.accentRead,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiceExpressionChip extends StatelessWidget {
  final String label;
  final Color color;

  const _DiceExpressionChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CommandLayerDock extends StatelessWidget {
  final _Combatant activeCombatant;
  final List<_CombatAction> actions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, int> resourcePool;
  final Map<String, _CombatAction> preparedActions;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final ValueChanged<String> onSelectTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;

  const _CommandLayerDock({
    required this.activeCombatant,
    required this.actions,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.resourcePool,
    required this.preparedActions,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedTiming,
    required this.onSelectTiming,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.panel.withValues(alpha: 0.96),
            tokens.surface.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: tokens.accentMagic.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: _PreparedTurnPanel(
        activeCombatant: activeCombatant,
        actions: actions,
        preparedActions: preparedActions,
        spentTimings: spentTimings,
        pendingDamageActions: pendingDamageActions,
        resourcePool: resourcePool,
        queuedPreparedIndex: queuedPreparedIndex,
        queuedPreparedTotal: queuedPreparedTotal,
        queuedPreparedActionName: queuedPreparedActionName,
        selectedTiming: selectedTiming,
        onSelectTiming: onSelectTiming,
        onRollAction: onRollAction,
        onUseAction: onUseAction,
        onPrepareAction: onPrepareAction,
        onLaunch: onLaunchPreparedTurn,
        onClear: onClearPreparedActions,
      ),
    );
  }
}

void _showActionCatalogSheet({
  required BuildContext context,
  required List<_CombatAction> actions,
  required Set<String> spentTimings,
  required Set<String> pendingDamageActions,
  required Map<String, int> resourcePool,
  required Map<String, _CombatAction> preparedActions,
  required String selectedTiming,
  required ValueChanged<String> onSelectTiming,
  required void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction,
  required ValueChanged<_CombatAction> onUseAction,
  required ValueChanged<_CombatAction> onPrepareAction,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ActionCatalogSheet(
      actions: actions,
      spentTimings: spentTimings,
      pendingDamageActions: pendingDamageActions,
      resourcePool: resourcePool,
      preparedActions: preparedActions,
      initialTiming: selectedTiming,
      onSelectTiming: onSelectTiming,
      onRollAction: onRollAction,
      onUseAction: onUseAction,
      onPrepareAction: onPrepareAction,
    ),
  );
}

class _ActionCatalogSheet extends StatefulWidget {
  final List<_CombatAction> actions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, int> resourcePool;
  final Map<String, _CombatAction> preparedActions;
  final String initialTiming;
  final ValueChanged<String> onSelectTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;

  const _ActionCatalogSheet({
    required this.actions,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.resourcePool,
    required this.preparedActions,
    required this.initialTiming,
    required this.onSelectTiming,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
  });

  @override
  State<_ActionCatalogSheet> createState() => _ActionCatalogSheetState();
}

class _ActionCatalogSheetState extends State<_ActionCatalogSheet> {
  late String _selectedTiming = widget.initialTiming;
  String _selectedCategory = 'All';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Movement'];
    const categories = ['All', 'Weapons', 'Spells', 'Features', 'Resources'];
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleActions = widget.actions
        .where((action) => action.timing == _selectedTiming)
        .where((action) => _matchesCatalogCategory(action, _selectedCategory))
        .where((action) {
      if (normalizedQuery.isEmpty) return true;
      final haystack = '${action.name} ${action.type} ${action.tags.join(' ')}'
          .toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.74,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.panel.withValues(alpha: 0.98),
                tokens.surface.withValues(alpha: 0.96),
              ],
            ),
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border:
                Border.all(color: tokens.accentMagic.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.view_module_outlined,
                      color: tokens.accentMagic, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTION CATALOG',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${visibleActions.length} shown - ${widget.actions.length} total',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search actions',
                        hintStyle: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: tokens.textMuted,
                          size: 17,
                        ),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.16),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          borderSide: BorderSide(
                            color: tokens.accentMagic.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.white,
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = category == _selectedCategory;
                    return _CatalogFilterChip(
                      label: category,
                      selected: selected,
                      count: _catalogCategoryCount(category),
                      onTap: () => setState(() => _selectedCategory = category),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: timings.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final timing = timings[index];
                    return SizedBox(
                      width: 142,
                      child: _CommandTimingButton(
                        label: timing,
                        selected: timing == _selectedTiming,
                        spent: widget.spentTimings.contains(timing),
                        onTap: () {
                          setState(() => _selectedTiming = timing);
                          widget.onSelectTiming(timing);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _selectedTiming == 'Movement'
                      ? _MovementLayer(key: const ValueKey('MovementCatalog'))
                      : visibleActions.isEmpty
                          ? _EmptyCommandLayer(
                              key: ValueKey('empty_$_selectedTiming'),
                              timing: _selectedTiming,
                            )
                          : GridView.builder(
                              key: ValueKey('catalog_$_selectedTiming'),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 290,
                                mainAxisExtent: 178,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: visibleActions.length,
                              itemBuilder: (context, index) {
                                final action = visibleActions[index];
                                final hasPendingDamage = widget
                                    .pendingDamageActions
                                    .contains(_actionCardKey(action));
                                final lacksResource = _actionLacksResource(
                                    action, widget.resourcePool);
                                return _CompactActionCommand(
                                  action: action,
                                  isSpent: widget.spentTimings
                                          .contains(action.timing) &&
                                      !hasPendingDamage,
                                  canResolveDamage: hasPendingDamage,
                                  lacksResource:
                                      lacksResource && !hasPendingDamage,
                                  resourceRemaining: _actionResourceRemaining(
                                      action, widget.resourcePool),
                                  isPrepared: widget
                                          .preparedActions[_selectedTiming]
                                          ?.name ==
                                      action.name,
                                  onRollAction: (action, rollType) {
                                    widget.onRollAction(action, rollType);
                                    Navigator.of(context).maybePop();
                                  },
                                  onUseAction: (action) {
                                    widget.onUseAction(action);
                                    Navigator.of(context).maybePop();
                                  },
                                  onPrepareAction: widget.onPrepareAction,
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _catalogCategoryCount(String category) {
    return widget.actions
        .where((action) => action.timing == _selectedTiming)
        .where((action) => _matchesCatalogCategory(action, category))
        .length;
  }

  bool _matchesCatalogCategory(_CombatAction action, String category) {
    if (category == 'All') return true;
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    return switch (category) {
      'Weapons' => text.contains('weapon') ||
          text.contains('melee') ||
          text.contains('ranged'),
      'Spells' => text.contains('spell') ||
          text.contains('cantrip') ||
          action.accentKind == _CombatAccentKind.magic,
      'Features' => text.contains('feature') ||
          text.contains('class') ||
          text.contains('monster'),
      'Resources' => text.contains('resource') ||
          text.contains('ki') ||
          text.contains('rage') ||
          text.contains('inspiration'),
      _ => true,
    };
  }
}

class _CatalogFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _CatalogFilterChip({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = selected ? tokens.accentMagic : tokens.accentRead;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.22 : 0.09),
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.48 : 0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: selected ? Colors.white : tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandTimingButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool spent;
  final VoidCallback onTap;

  const _CommandTimingButton({
    required this.label,
    required this.selected,
    required this.spent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = spent
        ? tokens.accentAction
        : selected
            ? tokens.accentMagic
            : tokens.accentRead;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.24 : 0.11),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.56 : 0.24)),
        ),
        child: Row(
          children: [
            Icon(
              spent
                  ? Icons.check_circle_outline
                  : selected
                      ? Icons.keyboard_arrow_right
                      : Icons.circle_outlined,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactActionCommand extends StatelessWidget {
  final _CombatAction action;
  final bool isSpent;
  final bool canResolveDamage;
  final bool lacksResource;
  final int? resourceRemaining;
  final bool isPrepared;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;

  const _CompactActionCommand({
    required this.action,
    required this.isSpent,
    this.canResolveDamage = false,
    this.lacksResource = false,
    this.resourceRemaining,
    required this.isPrepared,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(action.accentKind, tokens);
    final effectiveAccent = isSpent
        ? tokens.textMuted
        : canResolveDamage
            ? tokens.accentSuccess
            : lacksResource
                ? tokens.accentAction
                : accent;
    final canPrepare = !isSpent && !canResolveDamage && !lacksResource;
    final isBlocked = isSpent || lacksResource;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveAccent.withValues(alpha: isSpent ? 0.08 : 0.18),
            tokens.surfaceRaised.withValues(alpha: 0.84),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: effectiveAccent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBlocked ? Icons.lock_clock_outlined : action.icon,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  action.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _PrepareActionButton(
                selected: isPrepared,
                disabled: !canPrepare,
                color: effectiveAccent,
                onTap: () {
                  if (canPrepare) onPrepareAction(action);
                },
              ),
              const SizedBox(width: 5),
              _ActionDetailsButton(action: action, color: effectiveAccent),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            action.type,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          _ActionAvailabilityLine(
            isSpent: isSpent,
            isPrepared: isPrepared,
            canResolveDamage: canResolveDamage,
            lacksResource: lacksResource,
            resourceRemaining: resourceRemaining,
            resourceCost: action.resourceCost,
            color: effectiveAccent,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final tag in action.tags.take(1))
                _DiceExpressionChip(label: tag, color: effectiveAccent),
              if (isSpent)
                _DiceExpressionChip(label: 'Spent', color: effectiveAccent),
              if (lacksResource)
                _DiceExpressionChip(label: 'No uses', color: effectiveAccent),
              if (canResolveDamage)
                _DiceExpressionChip(
                    label: 'Hit confirmed', color: effectiveAccent),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (action.attackFormula != null)
                Expanded(
                  child: _TinyRollButton(
                    label: action.attackFormula!,
                    icon: Icons.track_changes_outlined,
                    color: effectiveAccent,
                    enabled: !isBlocked && !canResolveDamage,
                    onTap: () => onRollAction(action, _CombatActionRoll.attack),
                  ),
                ),
              if (action.requiresSavingThrow)
                Expanded(
                  child: _TinyRollButton(
                    label: '${action.saveAbility} DC ${action.saveDc}',
                    icon: Icons.shield_outlined,
                    color: effectiveAccent,
                    enabled: !isBlocked && !canResolveDamage,
                    onTap: () =>
                        onRollAction(action, _CombatActionRoll.savingThrow),
                  ),
                ),
              if ((action.attackFormula != null ||
                      action.requiresSavingThrow) &&
                  action.damageFormula != null)
                const SizedBox(width: 5),
              if (action.damageFormula != null)
                Expanded(
                  child: _TinyRollButton(
                    label: action.isHealing ? 'Heal' : action.damageFormula!,
                    icon: action.isHealing
                        ? Icons.favorite_border
                        : Icons.auto_fix_high_outlined,
                    color: effectiveAccent,
                    enabled: !isBlocked || canResolveDamage,
                    onTap: () => onRollAction(action, _CombatActionRoll.damage),
                  ),
                ),
              if (action.critFormula != null) ...[
                const SizedBox(width: 5),
                Expanded(
                  child: _TinyRollButton(
                    label: 'Crit',
                    icon: Icons.emergency_outlined,
                    color: isSpent ? effectiveAccent : tokens.accentSuccess,
                    enabled: !isBlocked || canResolveDamage,
                    onTap: () =>
                        onRollAction(action, _CombatActionRoll.critical),
                  ),
                ),
              ],
              if (action.attackFormula == null &&
                  !action.requiresSavingThrow &&
                  action.damageFormula == null &&
                  action.critFormula == null)
                Expanded(
                  child: _TinyRollButton(
                    label: 'Use',
                    icon: Icons.check_circle_outline,
                    color: effectiveAccent,
                    enabled: !isBlocked,
                    onTap: () => onUseAction(action),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionAvailabilityLine extends StatelessWidget {
  final bool isSpent;
  final bool isPrepared;
  final bool canResolveDamage;
  final bool lacksResource;
  final int? resourceRemaining;
  final int resourceCost;
  final Color color;

  const _ActionAvailabilityLine({
    required this.isSpent,
    required this.isPrepared,
    required this.canResolveDamage,
    required this.lacksResource,
    required this.resourceRemaining,
    required this.resourceCost,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final status = canResolveDamage
        ? 'Damage pending'
        : lacksResource
            ? 'No uses left'
            : isSpent
                ? 'Timing spent'
                : isPrepared
                    ? 'Prepared'
                    : resourceRemaining == null
                        ? 'Available'
                        : '$resourceRemaining left - costs $resourceCost';
    final icon = canResolveDamage
        ? Icons.auto_fix_high_outlined
        : lacksResource
            ? Icons.battery_0_bar_outlined
            : isSpent
                ? Icons.lock_clock_outlined
                : isPrepared
                    ? Icons.playlist_add_check_circle_outlined
                    : Icons.check_circle_outline;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyRollButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _TinyRollButton({
    required this.label,
    required this.icon,
    required this.color,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.34)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrepareActionButton extends StatelessWidget {
  final bool selected;
  final bool disabled;
  final Color color;
  final VoidCallback onTap;

  const _PrepareActionButton({
    required this.selected,
    this.disabled = false,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 27,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: (selected ? color : Colors.white).withValues(
            alpha: selected ? 0.26 : 0.07,
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.58 : 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_outline : Icons.add_circle_outline,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              selected ? 'Ready' : 'Prepare',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionDetailsButton extends StatelessWidget {
  final _CombatAction action;
  final Color color;

  const _ActionDetailsButton({
    required this.action,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: () => _showActionDetails(context, action),
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        width: 27,
        height: 27,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: const Icon(
          Icons.info_outline,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}

class _PreparedTurnPanel extends StatelessWidget {
  final _Combatant activeCombatant;
  final List<_CombatAction> actions;
  final Map<String, _CombatAction> preparedActions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, int> resourcePool;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final ValueChanged<String> onSelectTiming;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onLaunch;
  final VoidCallback onClear;

  const _PreparedTurnPanel({
    required this.activeCombatant,
    required this.actions,
    required this.preparedActions,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.resourcePool,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedTiming,
    required this.onSelectTiming,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Movement'];
    final preparedCount = preparedActions.length;
    final executableCount = preparedActions.entries
        .where((entry) => !spentTimings.contains(entry.key))
        .length;
    final queueActive =
        queuedPreparedTotal > 0 && queuedPreparedIndex < queuedPreparedTotal;
    final rollButtonLabel = queueActive ? 'Roll Next' : 'Roll Plan';
    final rollButtonIcon =
        queueActive ? Icons.casino_outlined : Icons.playlist_play_outlined;

    void openCatalog(String timing) {
      onSelectTiming(timing);
      _showActionCatalogSheet(
        context: context,
        actions: actions,
        spentTimings: spentTimings,
        pendingDamageActions: pendingDamageActions,
        resourcePool: resourcePool,
        preparedActions: preparedActions,
        selectedTiming: timing,
        onSelectTiming: onSelectTiming,
        onRollAction: onRollAction,
        onUseAction: onUseAction,
        onPrepareAction: onPrepareAction,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.accentMagic.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.18),
            tokens.accentAction.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentAction.withValues(alpha: 0.26)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tokens.accentAction.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: tokens.accentAction.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.playlist_add_check_circle_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _PreparedTurnHeader(
                  activeCombatant: activeCombatant,
                ),
              ),
              _PreparedTurnProgressPill(
                preparedCount: preparedCount,
                totalCount: timings.length,
              ),
              if (queueActive) ...[
                const SizedBox(width: 7),
                _QueuedRollPill(
                  index: queuedPreparedIndex + 1,
                  total: queuedPreparedTotal,
                  actionName: queuedPreparedActionName ?? 'Next roll',
                ),
              ],
              const SizedBox(width: 7),
              IconButton(
                onPressed: preparedActions.isEmpty ? null : onClear,
                icon: const Icon(Icons.close, size: 17),
                color: Colors.white,
                disabledColor: tokens.textMuted,
                tooltip: 'Clear prepared turn',
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed:
                    executableCount == 0 && !queueActive ? null : onLaunch,
                icon: Icon(rollButtonIcon, size: 17),
                label: Text(rollButtonLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.accentAction,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                  disabledForegroundColor: tokens.textMuted,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Expanded(
            child: Row(
              children: [
                for (var index = 0; index < timings.length; index++) ...[
                  Expanded(
                    child: _PreparedTurnSlot(
                      index: index + 1,
                      timing: timings[index],
                      action: preparedActions[timings[index]],
                      spent: spentTimings.contains(timings[index]),
                      selected: timings[index] == selectedTiming,
                      onOpen: () => openCatalog(timings[index]),
                    ),
                  ),
                  if (index != timings.length - 1) ...[
                    const SizedBox(width: 8),
                    _TurnFlowArrow(
                      active: preparedActions[timings[index]] != null ||
                          spentTimings.contains(timings[index]),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparedTurnHeader extends StatelessWidget {
  final _Combatant activeCombatant;

  const _PreparedTurnHeader({
    required this.activeCombatant,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Row(
      children: [
        Text(
          'PREPARED TURN',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              border: Border.all(
                color: tokens.accentMagic.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person_pin_circle_outlined,
                    color: tokens.accentInfo, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    activeCombatant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.accentInfo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    border: Border.all(
                      color: tokens.accentInfo.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PreparedTurnProgressPill extends StatelessWidget {
  final int preparedCount;
  final int totalCount;

  const _PreparedTurnProgressPill({
    required this.preparedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final ready = preparedCount > 0;
    final color = ready ? tokens.accentAction : tokens.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ready ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$preparedCount / $totalCount ready',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _QueuedRollPill extends StatelessWidget {
  final int index;
  final int total;
  final String actionName;

  const _QueuedRollPill({
    required this.index,
    required this.total,
    required this.actionName,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.accentMagic.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: tokens.accentMagic.withValues(alpha: 0.18),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.casino_outlined, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            '$index/$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              actionName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnFlowArrow extends StatelessWidget {
  final bool active;

  const _TurnFlowArrow({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    return Icon(
      Icons.chevron_right_rounded,
      color: (active ? tokens.accentAction : tokens.textMuted)
          .withValues(alpha: active ? 0.9 : 0.45),
      size: 20,
    );
  }
}

class _PreparedTurnSlot extends StatelessWidget {
  final int index;
  final String timing;
  final _CombatAction? action;
  final bool spent;
  final bool selected;
  final VoidCallback onOpen;

  const _PreparedTurnSlot({
    required this.index,
    required this.timing,
    required this.action,
    required this.spent,
    required this.selected,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = spent
        ? tokens.accentAction
        : action == null
            ? (selected ? tokens.accentMagic : tokens.textMuted)
            : _accentForKind(action!.accentKind, tokens);
    final title = action?.name ?? (spent ? 'Spent' : 'Open command');
    final formula =
        action == null && !spent ? 'Choose' : _preparedActionFormula(action);
    final icon = spent
        ? Icons.check_circle_outline
        : action == null
            ? Icons.add_circle_outline
            : action!.icon;
    final status = spent
        ? 'Resolved'
        : action == null
            ? 'Awaiting choice'
            : 'Ready to execute';

    return InkWell(
      onTap: spent ? null : onOpen,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: action == null ? 0.08 : 0.22),
              Colors.black.withValues(alpha: 0.16),
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: color.withValues(
              alpha: selected ? 0.56 : (action == null ? 0.18 : 0.38),
            ),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -18,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.045),
                size: 86,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        border:
                            Border.all(color: color.withValues(alpha: 0.28)),
                      ),
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STEP $index',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            timing,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.06,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 112),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                        border:
                            Border.all(color: color.withValues(alpha: 0.20)),
                      ),
                      child: Text(
                        formula,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              action == null ? tokens.textMuted : Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (action != null && action!.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final tag in action!.tags.take(2))
                        _DiceExpressionChip(label: tag, color: color),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementLayer extends StatelessWidget {
  const _MovementLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Movement Window',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (final step in ['5 ft', '10 ft', '15 ft', '30 ft']) ...[
            const SizedBox(width: 8),
            Container(
              width: 70,
              height: 70,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.accentSuccess.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: tokens.accentSuccess.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCommandLayer extends StatelessWidget {
  final String timing;

  const _EmptyCommandLayer({
    super.key,
    required this.timing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        '$timing window is empty for this prototype.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: tokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GameFeedWindow extends StatelessWidget {
  final List<_CombatLogEntry> entries;
  final int maxEntries;

  const _GameFeedWindow({
    required this.entries,
    this.maxEntries = 3,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final visible = entries.take(maxEntries).toList();

    return _GameSmallWindow(
      title: 'Log',
      icon: Icons.receipt_long_outlined,
      accentKind: _CombatAccentKind.info,
      child: Column(
        children: [
          for (final entry in visible) ...[
            _MiniFeedEntry(entry: entry),
            if (entry != visible.last) const SizedBox(height: 6),
          ],
          if (visible.isEmpty)
            Text(
              'No activity yet.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniFeedEntry extends StatelessWidget {
  final _CombatLogEntry entry;

  const _MiniFeedEntry({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = switch (entry.type) {
      _CombatLogEntryType.roll => tokens.accentMagic,
      _CombatLogEntryType.turn => tokens.accentAction,
      _CombatLogEntryType.system => tokens.accentRead,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(entry.icon, color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
        ),
      ],
    );
  }
}

class _GameSmallWindow extends StatelessWidget {
  final String title;
  final IconData icon;
  final _CombatAccentKind accentKind;
  final Widget child;

  const _GameSmallWindow({
    required this.title,
    required this.icon,
    required this.accentKind,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(accentKind, tokens);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.panel.withValues(alpha: 0.94),
            tokens.surface.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

class _CombatArenaBackdrop extends StatelessWidget {
  final int round;

  const _CombatArenaBackdrop({
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CombatArenaBackdropPainter(
        tokens: context.stitch,
        round: round,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CombatArenaBackdropPainter extends CustomPainter {
  final StitchThemeTokens tokens;
  final int round;

  const _CombatArenaBackdropPainter({
    required this.tokens,
    required this.round,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tokens.pageTop,
          const Color(0xFF111A25),
          tokens.pageBottom,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    _drawGlow(
      canvas,
      rect,
      center: Offset(size.width * 0.18, size.height * 0.18),
      radius: size.shortestSide * 0.62,
      color: tokens.accentRead,
      alpha: 0.16,
    );
    _drawGlow(
      canvas,
      rect,
      center: Offset(size.width * 0.82, size.height * 0.22),
      radius: size.shortestSide * 0.54,
      color: tokens.accentAction,
      alpha: 0.15,
    );
    _drawGlow(
      canvas,
      rect,
      center: Offset(size.width * 0.52, size.height * 0.88),
      radius: size.shortestSide * 0.48,
      color: tokens.accentMagic,
      alpha: 0.10,
    );

    final gridPaint = Paint()
      ..color = tokens.accentRead.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const grid = 54.0;
    for (var x = -grid; x < size.width + grid; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x + 80, size.height), gridPaint);
    }
    for (var y = 28.0; y < size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 20), gridPaint);
    }

    final runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = tokens.accentInfo.withValues(alpha: 0.10);
    final center = Offset(size.width * 0.50, size.height * 0.42);
    final pulse = math.sin(round * 0.7) * 4;
    for (final radius in [96.0, 148.0, 206.0]) {
      canvas.drawCircle(center, radius + pulse, runePaint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 16 + pulse),
        math.pi * 0.12,
        math.pi * 0.38,
        false,
        runePaint..color = tokens.accentAction.withValues(alpha: 0.09),
      );
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.58),
        ],
        stops: const [0.42, 1],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  void _drawGlow(
    Canvas canvas,
    Rect rect, {
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);
  }

  @override
  bool shouldRepaint(covariant _CombatArenaBackdropPainter oldDelegate) {
    return oldDelegate.round != round || oldDelegate.tokens != tokens;
  }
}

class _DuelSpotlightPanel extends StatelessWidget {
  final int round;
  final _Combatant activeCombatant;
  final _Combatant targetCombatant;

  const _DuelSpotlightPanel({
    required this.round,
    required this.activeCombatant,
    required this.targetCombatant,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.surfaceRaised.withValues(alpha: 0.96),
            tokens.panel.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: tokens.accentMagic.withValues(alpha: 0.12),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 740;
          if (!isWide) {
            return Column(
              children: [
                _DuelCombatantPortrait(
                  combatant: activeCombatant,
                  label: 'Active',
                  isTarget: false,
                ),
                const SizedBox(height: 10),
                _DuelRoundCore(round: round, compact: true),
                const SizedBox(height: 10),
                _DuelCombatantPortrait(
                  combatant: targetCombatant,
                  label: 'Target',
                  isTarget: true,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _DuelCombatantPortrait(
                  combatant: activeCombatant,
                  label: 'Active',
                  isTarget: false,
                ),
              ),
              const SizedBox(width: 12),
              _DuelRoundCore(round: round),
              const SizedBox(width: 12),
              Expanded(
                child: _DuelCombatantPortrait(
                  combatant: targetCombatant,
                  label: 'Target',
                  isTarget: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DuelCombatantPortrait extends StatelessWidget {
  final _Combatant combatant;
  final String label;
  final bool isTarget;

  const _DuelCombatantPortrait({
    required this.combatant,
    required this.label,
    required this.isTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent =
        isTarget ? tokens.accentAction : _teamColor(combatant.team, tokens);
    final isDown = combatant.hp <= 0;

    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            tokens.surface.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.42),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.42)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
              Icon(
                combatant.team == _CombatTeam.party
                    ? Icons.person_4_outlined
                    : Icons.crisis_alert_outlined,
                color: Colors.white,
                size: 42,
              ),
              Positioned(
                bottom: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  combatant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  combatant.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: combatant.hpRatio,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDown
                          ? tokens.textMuted
                          : combatant.hpRatio <= 0.30
                              ? tokens.accentAction
                              : tokens.accentSuccess,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _StatusChip(
                      label: '${combatant.hp}/${combatant.maxHp} HP',
                      color: isDown ? tokens.textMuted : tokens.accentSuccess,
                    ),
                    _StatusChip(
                      label: 'AC ${combatant.ac}',
                      color: tokens.accentRead,
                    ),
                    _StatusChip(
                      label: 'Init ${combatant.initiative}',
                      color: tokens.accentInfo,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DuelRoundCore extends StatelessWidget {
  final int round;
  final bool compact;

  const _DuelRoundCore({
    required this.round,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: compact ? double.infinity : 116,
      height: compact ? 68 : 138,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.28)),
      ),
      child: compact
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_outlined, color: tokens.accentMagic),
                const SizedBox(width: 8),
                _RoundText(round: round),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bolt_outlined,
                  color: tokens.accentMagic,
                  size: 30,
                ),
                const SizedBox(height: 10),
                _RoundText(round: round),
                const SizedBox(height: 10),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: tokens.accentAction,
                  size: 26,
                ),
              ],
            ),
    );
  }
}

class _RoundText extends StatelessWidget {
  final int round;

  const _RoundText({
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ROUND',
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        Text(
          '$round',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _CombatHeader extends StatelessWidget {
  final int round;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;

  const _CombatHeader({
    required this.round,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.surfaceRaised.withValues(alpha: 0.98),
            tokens.panel.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentAction.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: tokens.accentAction.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -36,
            child: IgnorePointer(
              child: Icon(
                Icons.sports_martial_arts_outlined,
                color: Colors.white.withValues(alpha: 0.045),
                size: 148,
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                color: Colors.white,
                tooltip: 'Back',
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.accentAction.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: tokens.accentAction.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.sports_martial_arts_outlined,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                width: 310,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMBAT MODE',
                      style: TextStyle(
                        color: tokens.accentReadSoft.withValues(alpha: 0.90),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Round $round - ${activeCombatant.name} is active',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _CombatHeaderMetric(
                label: 'Initiative',
                value: '${activeCombatant.initiative}',
              ),
              _CombatHeaderMetric(
                label: 'HP',
                value: '${activeCombatant.hp}/${activeCombatant.maxHp}',
              ),
              _CombatHeaderMetric(
                label: 'AC',
                value: '${activeCombatant.ac}',
              ),
              _CombatHeaderMetric(
                label: 'Target',
                value: selectedTarget.name,
                wide: true,
              ),
              OutlinedButton.icon(
                onPressed: onRequestInitiative,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Request Initiative'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: tokens.accentRead.withValues(alpha: 0.30),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRollInitiative,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Roll Demo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: tokens.accentMagic.withValues(alpha: 0.30),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onNextTurn,
                icon: const Icon(Icons.skip_next),
                label: const Text('Next Turn'),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.accentAction,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CombatHeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool wide;

  const _CombatHeaderMetric({
    required this.label,
    required this.value,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      constraints: BoxConstraints(minWidth: wide ? 120 : 74),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InitiativePanel extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;

  const _InitiativePanel({
    required this.combatants,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return _CombatSection(
      title: 'Turn Order',
      icon: Icons.format_list_numbered,
      accentKind: _CombatAccentKind.read,
      child: Column(
        children: [
          for (var index = 0; index < combatants.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _CombatantTile(
              combatant: combatants[index],
              isActive: index == activeIndex,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveTurnPanel extends StatelessWidget {
  final _Combatant combatant;
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final ValueChanged<int> onSelectTarget;
  final Set<String> spentTimings;
  final List<_CombatAction> actions;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;

  const _ActiveTurnPanel({
    required this.combatant,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.onSelectTarget,
    required this.spentTimings,
    required this.actions,
    required this.onRollAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      children: [
        _CombatSection(
          title: 'Active Turn',
          icon: Icons.play_arrow_outlined,
          accentKind: _CombatAccentKind.action,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _teamColor(combatant.team, tokens)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(
                        color: _teamColor(combatant.team, tokens)
                            .withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(
                      combatant.team == _CombatTeam.party
                          ? Icons.person_outline
                          : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          combatant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          combatant.role,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusPill),
                child: LinearProgressIndicator(
                  value: combatant.hpRatio,
                  minHeight: 9,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    combatant.hpRatio <= 0.30
                        ? tokens.accentAction
                        : tokens.accentSuccess,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: 'HP ${combatant.hp}/${combatant.maxHp}',
                    color: tokens.accentSuccess,
                  ),
                  _StatusChip(
                    label: 'AC ${combatant.ac}',
                    color: tokens.accentRead,
                  ),
                  _StatusChip(
                    label: '${combatant.speed} ft',
                    color: tokens.accentInfo,
                  ),
                  for (final condition in combatant.conditions)
                    _StatusChip(
                      label: condition,
                      color: tokens.accentMagic,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _ActionEconomyStrip(spentTimings: spentTimings),
              const SizedBox(height: 14),
              _TargetSelector(
                combatants: combatants,
                activeIndex: activeIndex,
                targetIndex: targetIndex,
                onSelectTarget: onSelectTarget,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CombatSection(
          title: 'Prepared Actions',
          icon: Icons.style_outlined,
          accentKind: _CombatAccentKind.magic,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? 2 : 1;
              const spacing = 10.0;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: actions.map((action) {
                  return SizedBox(
                    width: width,
                    child: _CombatActionCard(
                      action: action,
                      onRollAction: onRollAction,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BattlefieldPanel extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final ValueChanged<int> onSelectTarget;

  const _BattlefieldPanel({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return _CombatSection(
      title: 'Battlefield',
      icon: Icons.grid_view_outlined,
      accentKind: _CombatAccentKind.info,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.surfaceRaised.withValues(alpha: 0.86),
              tokens.surface.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.14)),
        ),
        child: CustomPaint(
          painter: _BattlefieldTerrainPainter(tokens: tokens),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final party = _indexedCombatants(_CombatTeam.party);
              final enemies = _indexedCombatants(_CombatTeam.enemy);

              if (!isWide) {
                return Column(
                  children: [
                    _BattlefieldLane(
                      title: 'Party',
                      subtitle: 'Allies and player characters',
                      entries: party,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      onSelectTarget: onSelectTarget,
                    ),
                    const SizedBox(height: 12),
                    _BattlefieldLane(
                      title: 'Threats',
                      subtitle: 'Hostile combatants',
                      entries: enemies,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      onSelectTarget: onSelectTarget,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _BattlefieldLane(
                      title: 'Party',
                      subtitle: 'Allies and player characters',
                      entries: party,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      onSelectTarget: onSelectTarget,
                    ),
                  ),
                  const SizedBox(width: 14),
                  _VersusBadge(roundText: '${party.length}v${enemies.length}'),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _BattlefieldLane(
                      title: 'Threats',
                      subtitle: 'Hostile combatants',
                      entries: enemies,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      onSelectTarget: onSelectTarget,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_IndexedCombatant> _indexedCombatants(_CombatTeam team) {
    final entries = <_IndexedCombatant>[];
    for (var index = 0; index < combatants.length; index++) {
      if (combatants[index].team == team) {
        entries.add(_IndexedCombatant(index, combatants[index]));
      }
    }
    return entries;
  }
}

class _BattlefieldTerrainPainter extends CustomPainter {
  final StitchThemeTokens tokens;

  const _BattlefieldTerrainPainter({
    required this.tokens,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final lanePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tokens.accentInfo.withValues(alpha: 0.07);

    for (var x = 24.0; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x + 24, size.height), lanePaint);
    }
    for (var y = 24.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lanePaint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = tokens.accentAction.withValues(alpha: 0.12);
    canvas.drawLine(
      Offset(size.width * 0.50, 10),
      Offset(size.width * 0.50, size.height - 10),
      linePaint,
    );

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = tokens.accentMagic.withValues(alpha: 0.10);
    canvas.drawCircle(
        center, math.min(size.width, size.height) * 0.22, circlePaint);
    canvas.drawArc(
      Rect.fromCircle(
          center: center, radius: math.min(size.width, size.height) * 0.33),
      math.pi * 1.10,
      math.pi * 0.80,
      false,
      circlePaint,
    );

    final mistPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          tokens.accentRead.withValues(alpha: 0.08),
          Colors.transparent,
          tokens.accentAction.withValues(alpha: 0.08),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, mistPaint);
  }

  @override
  bool shouldRepaint(covariant _BattlefieldTerrainPainter oldDelegate) {
    return oldDelegate.tokens != tokens;
  }
}

class _BattlefieldLane extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_IndexedCombatant> entries;
  final int activeIndex;
  final int targetIndex;
  final ValueChanged<int> onSelectTarget;

  const _BattlefieldLane({
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.activeIndex,
    required this.targetIndex,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _StatusChip(
              label: '${entries.length} combatants',
              color: tokens.accentRead,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: entries.map((entry) {
            return SizedBox(
              width: 236,
              child: _BattlefieldCombatantCard(
                combatant: entry.combatant,
                isActive: entry.index == activeIndex,
                isTargeted: entry.index == targetIndex,
                onTap: () => onSelectTarget(entry.index),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BattlefieldCombatantCard extends StatelessWidget {
  final _Combatant combatant;
  final bool isActive;
  final bool isTargeted;
  final VoidCallback onTap;

  const _BattlefieldCombatantCard({
    required this.combatant,
    required this.isActive,
    required this.isTargeted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final teamColor = _teamColor(combatant.team, tokens);
    final accent = isTargeted
        ? tokens.accentAction
        : isActive
            ? tokens.accentMagic
            : teamColor;
    final isDown = combatant.hp <= 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: isTargeted ? 0.22 : 0.12),
              tokens.surfaceRaised.withValues(alpha: 0.86),
              tokens.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: accent.withValues(alpha: isTargeted ? 0.55 : 0.24),
            width: isTargeted ? 1.4 : 1,
          ),
          boxShadow: [
            if (isActive || isTargeted)
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                  ),
                  child: Icon(
                    combatant.team == _CombatTeam.party
                        ? Icons.shield_outlined
                        : Icons.crisis_alert_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        combatant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        combatant.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              child: LinearProgressIndicator(
                value: combatant.hpRatio,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDown
                      ? tokens.textMuted
                      : combatant.hpRatio <= 0.30
                          ? tokens.accentAction
                          : tokens.accentSuccess,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusChip(
                  label: '${combatant.hp}/${combatant.maxHp} HP',
                  color: isDown ? tokens.textMuted : tokens.accentSuccess,
                ),
                _StatusChip(
                  label: 'AC ${combatant.ac}',
                  color: tokens.accentRead,
                ),
                _StatusChip(
                  label: 'I ${combatant.initiative}',
                  color: tokens.accentInfo,
                ),
                if (isActive)
                  _StatusChip(label: 'Active', color: tokens.accentMagic),
                if (isTargeted)
                  _StatusChip(label: 'Target', color: tokens.accentAction),
                if (isDown) _StatusChip(label: 'Down', color: tokens.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VersusBadge extends StatelessWidget {
  final String roundText;

  const _VersusBadge({
    required this.roundText,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: 66,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentAction.withValues(alpha: 0.24)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'VS',
            style: TextStyle(
              color: tokens.accentAction,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            roundText,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionEconomyStrip extends StatelessWidget {
  final Set<String> spentTimings;

  const _ActionEconomyStrip({
    required this.spentTimings,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    const timings = [
      ('Action', Icons.flash_on_outlined),
      ('Bonus Action', Icons.bolt_outlined),
      ('Reaction', Icons.keyboard_return_outlined),
      ('Movement', Icons.directions_run_outlined),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.18)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final timing in timings)
            _TurnResourceChip(
              label: timing.$1,
              icon: timing.$2,
              isSpent: spentTimings.contains(timing.$1),
            ),
        ],
      ),
    );
  }
}

class _TurnResourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSpent;

  const _TurnResourceChip({
    required this.label,
    required this.icon,
    required this.isSpent,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = isSpent ? tokens.accentAction : tokens.accentSuccess;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isSpent ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            '$label ${isSpent ? 'spent' : 'ready'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetSelector extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final ValueChanged<int> onSelectTarget;

  const _TargetSelector({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final activeTeam = combatants[activeIndex].team;
    final targets = <_IndexedCombatant>[];
    for (var index = 0; index < combatants.length; index++) {
      if (index == activeIndex) continue;
      targets.add(_IndexedCombatant(index, combatants[index]));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentAction.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.my_location_outlined,
                color: tokens.accentAction,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Current Target',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: targets.map((entry) {
              final target = entry.combatant;
              final selected = entry.index == targetIndex;
              final hostile = target.team != activeTeam;
              final color = hostile ? tokens.accentAction : tokens.accentRead;

              return ChoiceChip(
                selected: selected,
                onSelected: (_) => onSelectTarget(entry.index),
                avatar: Icon(
                  hostile ? Icons.crisis_alert_outlined : Icons.shield_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                label: Text(target.name),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                backgroundColor: color.withValues(alpha: 0.12),
                selectedColor: color.withValues(alpha: 0.28),
                side: BorderSide(
                  color: color.withValues(alpha: selected ? 0.55 : 0.22),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  final List<_CombatLogEntry> entries;

  const _ActivityPanel({
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return _CombatSection(
      title: 'Encounter Feed',
      icon: Icons.history,
      accentKind: _CombatAccentKind.info,
      child: Column(
        children:
            entries.map((entry) => _ActivityEntryTile(entry: entry)).toList(),
      ),
    );
  }
}

class _CombatActionCard extends StatelessWidget {
  final _CombatAction action;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;

  const _CombatActionCard({
    required this.action,
    required this.onRollAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(action.accentKind, tokens);

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            tokens.surfaceRaised.withValues(alpha: 0.80),
            tokens.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -13,
            left: -13,
            right: -13,
            child: Container(
              height: 4,
              color: accent.withValues(alpha: 0.78),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.34),
                          accent.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(color: accent.withValues(alpha: 0.32)),
                    ),
                    child: Icon(action.icon, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${action.type} - ${action.timing}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: action.tags
                    .map((tag) => _StatusChip(label: tag, color: accent))
                    .toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (action.attackFormula != null)
                    Expanded(
                      child: _ActionRollButton(
                        label: action.attackFormula!,
                        icon: Icons.track_changes_outlined,
                        color: accent,
                        onPressed: () =>
                            onRollAction(action, _CombatActionRoll.attack),
                      ),
                    ),
                  if (action.requiresSavingThrow)
                    Expanded(
                      child: _ActionRollButton(
                        label: '${action.saveAbility} DC ${action.saveDc}',
                        icon: Icons.shield_outlined,
                        color: accent,
                        onPressed: () =>
                            onRollAction(action, _CombatActionRoll.savingThrow),
                      ),
                    ),
                  if ((action.attackFormula != null ||
                          action.requiresSavingThrow) &&
                      action.damageFormula != null)
                    const SizedBox(width: 8),
                  if (action.damageFormula != null)
                    Expanded(
                      child: _ActionRollButton(
                        label: action.isHealing
                            ? 'Heal ${action.damageFormula}'
                            : action.damageFormula!,
                        icon: action.isHealing
                            ? Icons.favorite_border
                            : Icons.auto_fix_high_outlined,
                        color: accent,
                        onPressed: () =>
                            onRollAction(action, _CombatActionRoll.damage),
                      ),
                    ),
                ],
              ),
              if (action.critFormula != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _ActionRollButton(
                    label: 'Crit ${action.critFormula}',
                    icon: Icons.emergency_outlined,
                    color: tokens.accentSuccess,
                    onPressed: () =>
                        onRollAction(action, _CombatActionRoll.critical),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionRollButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionRollButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        side: BorderSide(color: color.withValues(alpha: 0.34)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CombatantTile extends StatelessWidget {
  final _Combatant combatant;
  final bool isActive;

  const _CombatantTile({
    required this.combatant,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent =
        isActive ? tokens.accentAction : _teamColor(combatant.team, tokens);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: 0.12)
            : tokens.surface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: accent.withValues(alpha: isActive ? 0.42 : 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: Text(
              '${combatant.initiative}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  combatant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  combatant.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Icon(
              Icons.play_arrow_rounded,
              color: tokens.accentAction,
            ),
        ],
      ),
    );
  }
}

class _ActivityEntryTile extends StatelessWidget {
  final _CombatLogEntry entry;

  const _ActivityEntryTile({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = switch (entry.type) {
      _CombatLogEntryType.roll => tokens.accentMagic,
      _CombatLogEntryType.turn => tokens.accentAction,
      _CombatLogEntryType.system => tokens.accentRead,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(entry.icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (entry.detail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CombatSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final _CombatAccentKind accentKind;
  final Widget child;

  const _CombatSection({
    required this.title,
    required this.icon,
    required this.accentKind,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(accentKind, tokens);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.panel.withValues(alpha: 0.94),
            tokens.surface.withValues(alpha: 0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: tokens.accentReadSoft.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final effectiveColor = _statusAccentForLabel(label, tokens, color);
    final icon = _statusIconForLabel(label);

    return Container(
      constraints: const BoxConstraints(maxWidth: 176),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CombatTeam { party, enemy }

enum _CombatActionRoll { attack, savingThrow, damage, critical }

enum _CombatWorkspace { turn, log, overview }

enum _CombatAccentKind { read, action, magic, support, info }

enum _CombatLogEntryType { system, turn, roll }

class _Combatant {
  final String id;
  final String name;
  final String role;
  final int initiative;
  final int initiativeBonus;
  final int hp;
  final int maxHp;
  final int tempHp;
  final int ac;
  final int speed;
  final _CombatTeam team;
  final String? portraitAsset;
  final List<String> conditions;

  const _Combatant({
    this.id = '',
    required this.name,
    required this.role,
    required this.initiative,
    required this.initiativeBonus,
    required this.hp,
    required this.maxHp,
    this.tempHp = 0,
    required this.ac,
    required this.speed,
    required this.team,
    this.portraitAsset,
    required this.conditions,
  });

  double get hpRatio {
    if (maxHp <= 0) return 0;
    return (hp / maxHp).clamp(0.0, 1.0);
  }

  _Combatant copyWith({
    String? id,
    int? initiative,
    int? hp,
    int? maxHp,
    int? tempHp,
    int? ac,
    int? speed,
    String? portraitAsset,
    List<String>? conditions,
  }) {
    return _Combatant(
      id: id ?? this.id,
      name: name,
      role: role,
      initiative: initiative ?? this.initiative,
      initiativeBonus: initiativeBonus,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      tempHp: tempHp ?? this.tempHp,
      ac: ac ?? this.ac,
      speed: speed ?? this.speed,
      team: team,
      portraitAsset: portraitAsset ?? this.portraitAsset,
      conditions: conditions ?? this.conditions,
    );
  }
}

class _CombatAction {
  final String id;
  final String name;
  final String type;
  final String timing;
  final String? attackFormula;
  final String? saveAbility;
  final int? saveDc;
  final String? damageFormula;
  final String? critFormula;
  final List<String> tags;
  final IconData icon;
  final _CombatAccentKind accentKind;
  final String? resourceKey;
  final int resourceCost;
  final bool targetsSelf;
  final bool isHealing;
  final bool halfDamageOnSave;
  final bool grantsAction;
  final List<_MultiAttackStep> multiAttackSteps;

  const _CombatAction({
    this.id = '',
    required this.name,
    required this.type,
    required this.timing,
    required this.attackFormula,
    this.saveAbility,
    this.saveDc,
    required this.damageFormula,
    required this.critFormula,
    required this.tags,
    required this.icon,
    required this.accentKind,
    this.resourceKey,
    this.resourceCost = 0,
    this.targetsSelf = false,
    this.isHealing = false,
    this.halfDamageOnSave = false,
    this.grantsAction = false,
    this.multiAttackSteps = const [],
  });

  bool get requiresSavingThrow => saveAbility != null && saveDc != null;
  bool get hasMultiAttack => multiAttackSteps.isNotEmpty;
}

class _MultiAttackStep {
  final String name;
  final String? attackFormula;
  final String? damageFormula;
  final String? critFormula;
  final List<String> tags;

  const _MultiAttackStep({
    required this.name,
    required this.attackFormula,
    required this.damageFormula,
    required this.critFormula,
    required this.tags,
  });
}

class _IndexedCombatant {
  final int index;
  final _Combatant combatant;

  const _IndexedCombatant(this.index, this.combatant);
}

class _HpChangeResult {
  final int hp;
  final int tempHp;

  const _HpChangeResult({
    required this.hp,
    required this.tempHp,
  });
}

class _CombatRollFeedback {
  final String actor;
  final String action;
  final DiceRollResult? result;
  final String headline;
  final String? subline;
  final _CombatAccentKind accentKind;

  const _CombatRollFeedback({
    required this.actor,
    required this.action,
    required this.result,
    required this.headline,
    required this.subline,
    required this.accentKind,
  });

  const _CombatRollFeedback.manual({
    required this.actor,
    required this.action,
    required this.headline,
    required this.subline,
    required this.accentKind,
  }) : result = null;
}

class _CombatLogEntry {
  final String title;
  final String? detail;
  final IconData icon;
  final _CombatLogEntryType type;

  const _CombatLogEntry({
    required this.title,
    required this.detail,
    required this.icon,
    required this.type,
  });

  factory _CombatLogEntry.system(String title) {
    return _CombatLogEntry(
      title: title,
      detail: null,
      icon: Icons.info_outline,
      type: _CombatLogEntryType.system,
    );
  }

  factory _CombatLogEntry.turn(String title) {
    return _CombatLogEntry(
      title: title,
      detail: null,
      icon: Icons.play_arrow_outlined,
      type: _CombatLogEntryType.turn,
    );
  }

  factory _CombatLogEntry.roll({
    required String actor,
    required String action,
    required DiceRollResult result,
    String? detail,
  }) {
    final prefix = result.isCriticalHit
        ? 'Critical! '
        : result.isCriticalMiss
            ? 'Fumble! '
            : '';

    return _CombatLogEntry(
      title: '$prefix$actor used $action: ${result.total}',
      detail: detail ?? '${result.formula} - ${result.rollsText}',
      icon: result.isCriticalHit
          ? Icons.emergency_outlined
          : Icons.casino_outlined,
      type: _CombatLogEntryType.roll,
    );
  }
}

Color _teamColor(_CombatTeam team, StitchThemeTokens tokens) {
  return team == _CombatTeam.party ? tokens.accentRead : tokens.accentAction;
}

Color _accentForKind(_CombatAccentKind kind, StitchThemeTokens tokens) {
  return switch (kind) {
    _CombatAccentKind.read => tokens.accentRead,
    _CombatAccentKind.action => tokens.accentAction,
    _CombatAccentKind.magic => tokens.accentMagic,
    _CombatAccentKind.support => tokens.accentSuccess,
    _CombatAccentKind.info => tokens.accentInfo,
  };
}

Color _statusAccentForLabel(
  String label,
  StitchThemeTokens tokens,
  Color fallback,
) {
  final text = label.toLowerCase();
  if (text.contains('temp hp')) return tokens.accentInfo;
  if (text.contains('rage') || text.contains('raging')) {
    return tokens.accentAction;
  }
  if (text.contains('bardic') || text.contains('inspiration')) {
    return tokens.accentMagic;
  }
  if (text.contains('concentrat')) return tokens.accentSuccess;
  if (text.contains('ki') || text.contains('sorcery')) return tokens.accentRead;
  if (text.contains('down')) return tokens.textMuted;
  return fallback;
}

IconData _statusIconForLabel(String label) {
  final text = label.toLowerCase();
  if (text.contains('temp hp')) return Icons.health_and_safety_outlined;
  if (text.contains('rage') || text.contains('raging')) {
    return Icons.local_fire_department_outlined;
  }
  if (text.contains('bardic') || text.contains('inspiration')) {
    return Icons.auto_awesome_outlined;
  }
  if (text.contains('concentrat')) return Icons.psychology_alt_outlined;
  if (text.contains('ki')) return Icons.bolt_outlined;
  if (text.contains('sorcery')) return Icons.blur_on_outlined;
  if (text.contains('spell')) return Icons.menu_book_outlined;
  if (text.contains('resist')) return Icons.shield_outlined;
  if (text.contains('immune')) return Icons.verified_user_outlined;
  if (text.contains('speed')) return Icons.directions_run_outlined;
  return Icons.adjust_outlined;
}

String? _combatantPortraitAsset({
  required String name,
  required String role,
  required _CombatTeam team,
}) {
  final text = '$name $role'.toLowerCase();

  String? match(Map<String, String> lookup) {
    for (final entry in lookup.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  const races = {
    'half-orc': 'half-orc',
    'half orc': 'half-orc',
    'half-elf': 'half-elf',
    'half elf': 'half-elf',
    'dragonborn': 'dragonborn',
    'hobgoblin': 'hobgoblin',
    'goblin': 'goblin',
    'centaur': 'centaur',
    'aasimar': 'aasimar',
    'tiefling': 'tiefling',
    'warforged': 'warforged',
    'goliath': 'goliath',
    'halfling': 'halfling',
    'lizardfolk': 'lizardfolk',
    'bugbear': 'bugbear',
    'kobold': 'kobold',
    'firbolg': 'firbolg',
    'dwarf': 'dwarf',
    'elf': 'elf',
    'orc': 'orc',
    'human': 'human',
  };

  const classes = {
    'barbarian': 'barbarian',
    'paladin': 'paladin',
    'blood hunter': 'fighter',
    'fighter': 'fighter',
    'wizard': 'wizard',
    'warlock': 'warlock',
    'sorcerer': 'sorcerer',
    'cleric': 'cleric',
    'druid': 'druid',
    'bard': 'bard',
    'monk': 'monk',
    'rogue': 'rogue',
    'ranger': 'ranger',
    'artificer': 'artificer',
  };

  final race = match(races);
  if (race != null) return 'assets/images/races/$race.png';

  if (team == _CombatTeam.party) {
    final characterClass = match(classes);
    if (characterClass != null) {
      return 'assets/images/classes/$characterClass.png';
    }
  }

  return null;
}

IconData _portraitIconForCombatant(_Combatant combatant) {
  final text = '${combatant.name} ${combatant.role}'.toLowerCase();
  if (combatant.team == _CombatTeam.party) {
    if (text.contains('wizard') ||
        text.contains('warlock') ||
        text.contains('sorcerer')) {
      return Icons.auto_awesome_outlined;
    }
    if (text.contains('monk')) return Icons.sports_martial_arts_outlined;
    if (text.contains('paladin') || text.contains('fighter')) {
      return Icons.shield_outlined;
    }
    return Icons.person_4_outlined;
  }
  if (text.contains('dragon')) return Icons.local_fire_department_outlined;
  if (text.contains('archer') || text.contains('bow')) {
    return Icons.ads_click_outlined;
  }
  if (text.contains('goblin')) return Icons.crisis_alert_outlined;
  if (text.contains('undead') || text.contains('shadow')) {
    return Icons.nights_stay_outlined;
  }
  return Icons.flare_outlined;
}

bool _canShowHp(_Combatant combatant, bool showEnemyHp) {
  return combatant.team == _CombatTeam.party || showEnemyHp;
}

String _compactHpLabel(_Combatant combatant, bool showEnemyHp) {
  if (!_canShowHp(combatant, showEnemyHp)) return 'Hidden';
  if (combatant.tempHp > 0) {
    return '${combatant.hp}/${combatant.maxHp} +${combatant.tempHp}';
  }
  return '${combatant.hp}/${combatant.maxHp}';
}

String _preparedActionFormula(_CombatAction? action) {
  if (action == null) return 'Open';
  if (action.grantsAction) return '+1 Action';
  if (action.hasMultiAttack) return '${action.multiAttackSteps.length} attacks';
  return action.attackFormula ??
      action.damageFormula ??
      action.critFormula ??
      'Use';
}

int _compactActionCountForTiming(
  List<_CombatAction> actions,
  String timing,
) {
  return actions.where((action) => action.timing == timing).length;
}

String _compactTimingLabel(String timing) {
  return switch (timing) {
    'Bonus Action' => 'Bonus',
    _ => timing,
  };
}

IconData _timingIcon(String timing) {
  return switch (timing) {
    'Action' => Icons.bolt_outlined,
    'Bonus Action' => Icons.control_point_duplicate_outlined,
    'Reaction' => Icons.reply_outlined,
    'Movement' => Icons.directions_run_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

void _showActionDetails(BuildContext context, _CombatAction action) {
  final tokens = context.stitch;
  final accent = _accentForKind(action.accentKind, tokens);

  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: tokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          side: BorderSide(color: accent.withValues(alpha: 0.34)),
        ),
        title: Row(
          children: [
            Icon(action.icon, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                action.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionDetailLine(label: 'Type', value: action.type),
            _ActionDetailLine(label: 'Timing', value: action.timing),
            if (action.hasMultiAttack)
              _ActionDetailLine(
                label: 'Sequence',
                value:
                    '${action.multiAttackSteps.length} attacks in one action',
              ),
            if (action.attackFormula != null)
              _ActionDetailLine(label: 'Attack', value: action.attackFormula!),
            if (action.damageFormula != null)
              _ActionDetailLine(
                  label: action.isHealing ? 'Healing' : 'Damage',
                  value: action.damageFormula!),
            if (action.critFormula != null)
              _ActionDetailLine(label: 'Critical', value: action.critFormula!),
            if (action.hasMultiAttack) ...[
              const SizedBox(height: 4),
              for (var index = 0;
                  index < action.multiAttackSteps.length;
                  index++)
                _ActionDetailLine(
                  label: 'Hit ${index + 1}',
                  value: [
                    action.multiAttackSteps[index].name,
                    if (action.multiAttackSteps[index].attackFormula != null)
                      action.multiAttackSteps[index].attackFormula!,
                    if (action.multiAttackSteps[index].damageFormula != null)
                      action.multiAttackSteps[index].damageFormula!,
                  ].join(' - '),
                ),
            ],
            if (action.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in action.tags)
                    _DiceExpressionChip(label: tag, color: accent),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _ActionDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _ActionDetailLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRollFormula(String dice, int modifier) {
  if (modifier == 0) return dice;
  return modifier > 0 ? '$dice+$modifier' : '$dice$modifier';
}
