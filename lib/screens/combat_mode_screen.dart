// ignore_for_file: unused_element

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/dice/models/dice_roll_result.dart';
import '../features/dice/services/dice_roller_service.dart';
import '../models/character.dart';
import '../models/board_token.dart';
import '../models/combat_encounter.dart' as encounter_models;
import '../models/custom_monster.dart';
import '../providers/campaign_provider.dart';
import '../providers/compendium_provider.dart';
import '../providers/character_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/spell_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/battle_board_provider.dart';
import '../services/character_combat_builder_service.dart';
import '../services/combat_encounter_engine.dart';
import '../services/custom_monster_repository.dart';
import '../services/monster_repository.dart';
import '../theme.dart';
import '../utils/external_url_launcher.dart';
import '../utils/image_path_utils.dart';
import '../widgets/stitch_navigation.dart';

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
  final Map<String, _CombatCharacterSnapshot> _pendingCharacterCombatSnapshots =
      {};
  final Map<String, List<_CombatAction>> _partyActionsByCombatantId = {};
  final Map<String, List<_CombatAction>> _enemyActionsByCombatantId = {};
  CharacterProvider? _characterProvider;
  _CombatRollFeedback? _rollFeedback;
  final Set<String> _spentTimings = {};
  final Set<String> _pendingDamageActions = {};
  final Set<String> _pendingHalfDamageActions = {};
  final Set<String> _spentReactionCombatantIds = {};
  final Map<String, _CombatAction> _preparedActions = {};
  final Map<String, _ReadiedAction> _readiedActionsByCombatantId = {};
  final List<_CombatAction> _queuedPreparedActions = [];
  int _queuedPreparedIndex = 0;
  int _activeIndex = 0;
  int _targetIndex = 2;
  int _round = 1;
  String _selectedCommandTiming = 'Action';
  _CombatWorkspace _workspace = _CombatWorkspace.turn;
  bool _dmView = true;
  bool _seededMonsters = false;
  bool _combatStarted = false;
  bool _openingBattleBoard = false;
  bool _showBattleBoardController = false;
  bool _battleBoardControllerExpanded = true;
  String? _activeBattleBoardSceneId;
  String? _selectedBattleBoardCombatantId;
  bool _monsterCatalogLoading = false;
  final Map<String, int> _stagedMonsterCounts = {
    'hobgoblin': 1,
    'goblin': 1,
  };
  final Map<String, int> _stagedCustomMonsterCounts = {};
  List<CustomMonster> _customMonsterCatalog = const [];
  bool _customMonsterCatalogLoading = false;
  String? _customMonsterCatalogError;
  List<SrdMonster> _monsterCatalog = const [];
  Future<void>? _monsterCatalogLoadFuture;
  String _monsterSearchQuery = '';
  String? _monsterCatalogError;
  String? _seededCharacterId;
  String? _loadingCampaignId;
  String? _loadedPartyCampaignId;
  bool _autoAdvanceScheduled = false;
  _CombatRollMode _rollMode = _CombatRollMode.normal;
  _MultiAttackProgress? _multiAttackProgress;

  String? get _queuedPreparedActionName {
    if (_queuedPreparedActions.isEmpty ||
        _queuedPreparedIndex < 0 ||
        _queuedPreparedIndex >= _queuedPreparedActions.length) {
      return null;
    }
    return _queuedPreparedActions[_queuedPreparedIndex].name;
  }

  bool get _hasAdvantage => _rollMode == _CombatRollMode.advantage;

  bool get _hasDisadvantage => _rollMode == _CombatRollMode.disadvantage;

  void _selectRollMode(_CombatRollMode mode) {
    if (_rollMode == mode) return;
    setState(() {
      _rollMode = mode;
    });
  }

  void _clearMultiAttackProgress() {
    _multiAttackProgress = null;
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
    _loadMonsterCatalog();
    _loadCustomMonsterCatalog();
    _loadRealDemoMonsters();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _characterProvider = context.read<CharacterProvider?>();
    _seedCombatContextIfNeeded(listenToCampaign: true);
  }

  @override
  void dispose() {
    final snapshots = _pendingCharacterCombatSnapshots.values.toList(
      growable: false,
    );
    _pendingCharacterCombatSnapshots.clear();
    if (snapshots.isNotEmpty) {
      unawaited(_flushCharacterCombatSnapshots(snapshots));
    }
    super.dispose();
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
    _spentReactionCombatantIds.clear();
    _readiedActionsByCombatantId.clear();
    _clearMultiAttackProgress();
    _preparedActions.clear();
    _resetQueuedPreparedActions();
    _activeIndex = 0;
    _targetIndex = _findDefaultTargetIndex(_activeIndex);
    _round = 1;
    _selectedCommandTiming = 'Action';
    _workspace = _CombatWorkspace.turn;
    _seededMonsters = false;
    _stagedCustomMonsterCounts.clear();
    _combatStarted = false;
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
      _spentReactionCombatantIds.clear();
      _readiedActionsByCombatantId.clear();
      _clearMultiAttackProgress();
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
    return source == 'monster' ||
        source == 'monsterFeature' ||
        source == 'customMonster';
  }

  Future<void> _loadCustomMonsterCatalog() async {
    if (_customMonsterCatalogLoading) return;
    setState(() {
      _customMonsterCatalogLoading = true;
      _customMonsterCatalogError = null;
    });
    try {
      final monsters = await CustomMonsterRepository.loadCustomMonsters();
      if (!mounted) return;
      setState(() {
        _customMonsterCatalog = monsters;
        _customMonsterCatalogLoading = false;
      });
      await _applyStagedMonsterSetup();
    } catch (error, stackTrace) {
      debugPrint('Custom bestiary load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _customMonsterCatalogLoading = false;
        _customMonsterCatalogError = error.toString();
      });
    }
  }

  Future<void> _saveCustomMonster(CustomMonster monster) async {
    final next = await CustomMonsterRepository.upsertCustomMonster(monster);
    if (!mounted) return;
    setState(() {
      _customMonsterCatalog = next;
      _customMonsterCatalogError = null;
    });
    await _applyStagedMonsterSetup();
  }

  Future<void> _loadMonsterCatalog() async {
    if (_monsterCatalog.isNotEmpty) return;
    final currentLoad = _monsterCatalogLoadFuture;
    if (currentLoad != null) {
      await currentLoad;
      return;
    }

    final loadFuture = _loadMonsterCatalogInner().whenComplete(() {
      _monsterCatalogLoadFuture = null;
    });
    _monsterCatalogLoadFuture = loadFuture;
    await loadFuture;
  }

  Future<void> _loadMonsterCatalogInner() async {
    setState(() {
      _monsterCatalogLoading = true;
      _monsterCatalogError = null;
    });
    try {
      final monsters = await MonsterRepository.loadMonsters();
      if (!mounted) return;
      final sorted = [...monsters]..sort((a, b) {
          final byCr = _crSortValue(a.challengeRating)
              .compareTo(_crSortValue(b.challengeRating));
          if (byCr != 0) return byCr;
          return a.name.compareTo(b.name);
        });
      setState(() {
        _monsterCatalog = sorted;
        _monsterCatalogLoading = false;
        _monsterCatalogError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Bestiary load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _monsterCatalogLoading = false;
        _monsterCatalogError = error.toString();
        _activity.insert(
          0,
          _CombatLogEntry.system('Bestiary load failed: $error'),
        );
      });
    }
  }

  Future<void> _reloadMonsterCatalog() async {
    MonsterRepository.clearCache();
    setState(() {
      _monsterCatalog = const [];
      _monsterCatalogLoading = false;
      _monsterCatalogError = null;
    });
    await _loadMonsterCatalog();
    await _applyStagedMonsterSetup();
  }

  List<SrdMonster> get _visibleMonsterCatalog {
    final query = _monsterSearchQuery.trim().toLowerCase();
    final source = query.isEmpty
        ? _monsterCatalog
        : _monsterCatalog.where((monster) {
            final haystack = [
              monster.name,
              monster.index,
              monster.type,
              monster.size,
              if (monster.subtype != null) monster.subtype!,
              if (monster.challengeRating != null)
                'cr ${monster.challengeRating}',
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          });
    return source.take(80).toList(growable: false);
  }

  void _setMonsterSearchQuery(String value) {
    setState(() {
      _monsterSearchQuery = value;
    });
  }

  double _crSortValue(String? cr) {
    if (cr == null || cr.trim().isEmpty) return 0;
    final trimmed = cr.trim();
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      final numerator = double.tryParse(parts.first) ?? 0;
      final denominator = double.tryParse(parts.last) ?? 1;
      return denominator == 0 ? 0 : numerator / denominator;
    }
    return double.tryParse(trimmed) ?? 0;
  }

  Future<void> _setStagedMonsterCount(SrdMonster monster, int count) async {
    final safeCount = count.clamp(0, 12).toInt();
    setState(() {
      if (safeCount == 0) {
        _stagedMonsterCounts.remove(monster.index);
      } else {
        _stagedMonsterCounts[monster.index] = safeCount;
      }
    });
    await _applyStagedMonsterSetup();
  }

  Future<void> _setStagedCustomMonsterCount(
    CustomMonster monster,
    int count,
  ) async {
    final safeCount = count.clamp(0, 12).toInt();
    setState(() {
      if (safeCount == 0) {
        _stagedCustomMonsterCounts.remove(monster.id);
      } else {
        _stagedCustomMonsterCounts[monster.id] = safeCount;
      }
    });
    await _applyStagedMonsterSetup();
  }

  Future<void> _removeCustomEnemy(String combatantId) async {
    final engineCombatant = _encounter?.combatantById(combatantId);
    final monsterId = engineCombatant?.sourceId ??
        engineCombatant?.metadata['customMonsterId']?.toString();
    if (monsterId == null || monsterId.trim().isEmpty) return;

    setState(() {
      final current = _stagedCustomMonsterCounts[monsterId] ?? 0;
      if (current <= 1) {
        _stagedCustomMonsterCounts.remove(monsterId);
      } else {
        _stagedCustomMonsterCounts[monsterId] = current - 1;
      }
    });
    await _applyStagedMonsterSetup();
  }

  Future<void> _deleteCustomMonster(CustomMonster monster) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar plantilla'),
          content: Text(
            'Eliminar ${monster.name} del bestiario personalizado?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final next = await CustomMonsterRepository.deleteCustomMonster(monster.id);
    if (!mounted) return;
    setState(() {
      _customMonsterCatalog = next;
      _stagedCustomMonsterCounts.remove(monster.id);
    });
    await _applyStagedMonsterSetup();
  }

  void _disposeDialogControllersAfterPop(
    List<TextEditingController> controllers,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
    });
  }

  Future<void> _showCustomEnemyDialog({CustomMonster? existing}) async {
    if (!mounted) return;
    final isEditing = existing != null;
    final nameController = TextEditingController(
      text: existing?.name ?? 'Custom Enemy',
    );
    final sizeController =
        TextEditingController(text: existing?.size ?? 'Medium');
    final typeController =
        TextEditingController(text: existing?.type ?? 'humanoid');
    final subtypeController =
        TextEditingController(text: existing?.subtype ?? '');
    final crController =
        TextEditingController(text: existing?.challengeRating ?? '');
    final hpController =
        TextEditingController(text: '${existing?.hitPoints ?? 12}');
    final acController =
        TextEditingController(text: '${existing?.armorClass ?? 13}');
    final speedController =
        TextEditingController(text: '${existing?.speed ?? 30}');
    final initiativeController =
        TextEditingController(text: '${existing?.initiativeBonus ?? 0}');
    final portraitController =
        TextEditingController(text: existing?.portraitPath ?? '');
    final strController =
        TextEditingController(text: '${existing?.strength ?? 10}');
    final dexController =
        TextEditingController(text: '${existing?.dexterity ?? 10}');
    final conController =
        TextEditingController(text: '${existing?.constitution ?? 10}');
    final intController =
        TextEditingController(text: '${existing?.intelligence ?? 10}');
    final wisController =
        TextEditingController(text: '${existing?.wisdom ?? 10}');
    final chaController =
        TextEditingController(text: '${existing?.charisma ?? 10}');
    var hideHpFromPlayers = existing?.hideHpFromPlayers ?? true;
    var actions = [
      ...(existing?.actions ?? const <CustomMonsterAction>[]),
    ];
    if (actions.isEmpty) {
      actions = [
        CustomMonsterAction(
          id: CustomMonsterRepository.newActionId('Strike'),
          name: 'Strike',
          description: 'Melee Weapon Attack.',
          timing: encounter_models.CombatActionTiming.action,
          rollKind: encounter_models.CombatActionRollKind.attack,
          attackBonus: 3,
          damageFormula: '1d6+1',
          damageType: 'slashing',
          tags: const ['Melee'],
        ),
      ];
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final tokens = context.stitch;

              int readInt(TextEditingController controller, int fallback) {
                return int.tryParse(controller.text.trim()) ?? fallback;
              }

              return AlertDialog(
                backgroundColor: tokens.panel,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  side: BorderSide(
                    color: _CinematicColors.blood.withValues(alpha: 0.34),
                  ),
                ),
                title: Text(
                  isEditing
                      ? 'Editar monstruo personalizado'
                      : 'Crear monstruo personalizado',
                ),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 620,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            hintText: 'Cultist Captain',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: sizeController,
                                decoration: const InputDecoration(
                                  labelText: 'Tamano',
                                  hintText: 'Medium',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: typeController,
                                decoration: const InputDecoration(
                                  labelText: 'Tipo',
                                  hintText: 'humanoid',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: subtypeController,
                                decoration: const InputDecoration(
                                  labelText: 'Subtipo',
                                  hintText: 'goblinoid',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 88,
                              child: TextField(
                                controller: crController,
                                decoration: const InputDecoration(
                                  labelText: 'CR',
                                  hintText: '1/2',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: hpController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'HP',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: acController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'CA',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: speedController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Vel',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: initiativeController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Init',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: portraitController,
                          decoration: const InputDecoration(
                            labelText: 'Retrato URL o asset path',
                            hintText: 'Opcional',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: hideHpFromPlayers,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ocultar HP a jugadores'),
                          onChanged: (value) {
                            setDialogState(() {
                              hideHpFromPlayers = value;
                            });
                          },
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Ability scores'),
                          children: [
                            Row(
                              children: [
                                _CompactNumberField(
                                  controller: strController,
                                  label: 'STR',
                                ),
                                const SizedBox(width: 8),
                                _CompactNumberField(
                                  controller: dexController,
                                  label: 'DEX',
                                ),
                                const SizedBox(width: 8),
                                _CompactNumberField(
                                  controller: conController,
                                  label: 'CON',
                                ),
                                const SizedBox(width: 8),
                                _CompactNumberField(
                                  controller: intController,
                                  label: 'INT',
                                ),
                                const SizedBox(width: 8),
                                _CompactNumberField(
                                  controller: wisController,
                                  label: 'WIS',
                                ),
                                const SizedBox(width: 8),
                                _CompactNumberField(
                                  controller: chaController,
                                  label: 'CHA',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ACCIONES Y RASGOS',
                            style: TextStyle(
                              color:
                                  tokens.accentAction.withValues(alpha: 0.86),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final action =
                                    await _showCustomMonsterActionDialog(
                                  existingActions: actions,
                                );
                                if (action == null || !dialogContext.mounted) {
                                  return;
                                }
                                setDialogState(() {
                                  actions = [...actions, action];
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Accion'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final action =
                                    await _showCustomMonsterActionDialog(
                                  existingActions: actions,
                                  seed: CustomMonsterAction(
                                    id: CustomMonsterRepository.newActionId(
                                      'Passive trait',
                                    ),
                                    name: 'Passive trait',
                                    description: '',
                                    timing: encounter_models
                                        .CombatActionTiming.passive,
                                    rollKind: encounter_models
                                        .CombatActionRollKind.none,
                                  ),
                                );
                                if (action == null || !dialogContext.mounted) {
                                  return;
                                }
                                setDialogState(() {
                                  actions = [...actions, action];
                                });
                              },
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: const Text('Rasgo'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final firstAttack = _firstOrNull(
                                  actions.where(
                                    (action) =>
                                        action.attackBonus != null ||
                                        (action.damageFormula ?? '')
                                            .trim()
                                            .isNotEmpty,
                                  ),
                                );
                                final action =
                                    await _showCustomMonsterActionDialog(
                                  existingActions: actions,
                                  seed: CustomMonsterAction(
                                    id: CustomMonsterRepository.newActionId(
                                      'Multiattack',
                                    ),
                                    name: 'Multiattack',
                                    description:
                                        'The monster makes multiple attacks.',
                                    timing: encounter_models
                                        .CombatActionTiming.action,
                                    rollKind: encounter_models
                                        .CombatActionRollKind.attack,
                                    multiattackSteps: [
                                      if (firstAttack != null)
                                        CustomMonsterMultiattackStep(
                                          actionName: firstAttack.name,
                                          count: 2,
                                        ),
                                    ],
                                    tags: const ['Multiattack'],
                                  ),
                                );
                                if (action == null || !dialogContext.mounted) {
                                  return;
                                }
                                setDialogState(() {
                                  actions = [...actions, action];
                                });
                              },
                              icon: const Icon(
                                Icons.auto_awesome_motion_outlined,
                              ),
                              label: const Text('Multiattack'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (actions.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.20),
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              border: Border.all(
                                color:
                                    tokens.accentRead.withValues(alpha: 0.20),
                              ),
                            ),
                            child: const Text(
                              'Agrega acciones, reacciones o rasgos pasivos.',
                              style: TextStyle(
                                color: _CinematicColors.paper,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        for (final action in actions) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusSm),
                              border: Border.all(
                                color: _CinematicColors.gold
                                    .withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  action.multiattackSteps.isNotEmpty
                                      ? Icons.auto_awesome_motion_outlined
                                      : action.timing ==
                                              encounter_models
                                                  .CombatActionTiming.passive
                                          ? Icons.auto_awesome_outlined
                                          : Icons.casino_outlined,
                                  color: _CinematicColors.goldBright,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        action.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _CinematicColors.paper,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _customActionSummary(action),
                                        maxLines: 2,
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
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed: () async {
                                    final edited =
                                        await _showCustomMonsterActionDialog(
                                      existing: action,
                                      existingActions: actions,
                                    );
                                    if (edited == null ||
                                        !dialogContext.mounted) {
                                      return;
                                    }
                                    setDialogState(() {
                                      actions = actions
                                          .map(
                                            (item) => item.id == action.id
                                                ? edited
                                                : item,
                                          )
                                          .toList(growable: false);
                                    });
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Quitar',
                                  onPressed: () {
                                    setDialogState(() {
                                      actions = actions
                                          .where((item) => item.id != action.id)
                                          .toList(growable: false);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Preview: CA ${readInt(acController, 13)} - HP ${readInt(hpController, 12)} - ${actions.length} entradas',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      final hp =
                          readInt(hpController, 12).clamp(1, 999).toInt();
                      final ac = readInt(acController, 13).clamp(1, 40).toInt();
                      final speed =
                          readInt(speedController, 30).clamp(0, 240).toInt();
                      final initiativeBonus = readInt(initiativeController, 0)
                          .clamp(-10, 20)
                          .toInt();
                      final now = DateTime.now();
                      final monster = CustomMonster(
                        id: existing?.id ??
                            CustomMonsterRepository.newMonsterId(name),
                        name: name,
                        size: sizeController.text.trim().isEmpty
                            ? 'Medium'
                            : sizeController.text.trim(),
                        type: typeController.text.trim().isEmpty
                            ? 'creature'
                            : typeController.text.trim(),
                        subtype: _nullableText(subtypeController.text),
                        challengeRating: _nullableText(crController.text),
                        portraitPath: _nullableText(portraitController.text),
                        armorClass: ac,
                        hitPoints: hp,
                        speed: speed,
                        initiativeBonus: initiativeBonus,
                        strength:
                            readInt(strController, 10).clamp(1, 30).toInt(),
                        dexterity:
                            readInt(dexController, 10).clamp(1, 30).toInt(),
                        constitution:
                            readInt(conController, 10).clamp(1, 30).toInt(),
                        intelligence:
                            readInt(intController, 10).clamp(1, 30).toInt(),
                        wisdom: readInt(wisController, 10).clamp(1, 30).toInt(),
                        charisma:
                            readInt(chaController, 10).clamp(1, 30).toInt(),
                        hideHpFromPlayers: hideHpFromPlayers,
                        actions: actions,
                        createdAt: existing?.createdAt ?? now,
                        updatedAt: now,
                      );

                      await _saveCustomMonster(monster);
                      if (!isEditing) {
                        setState(() {
                          _stagedCustomMonsterCounts[monster.id] = 1;
                        });
                        await _applyStagedMonsterSetup();
                      }
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                    },
                    icon: Icon(isEditing ? Icons.save_outlined : Icons.add),
                    label: Text(isEditing ? 'Guardar' : 'Crear'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      _disposeDialogControllersAfterPop([
        nameController,
        sizeController,
        typeController,
        subtypeController,
        crController,
        hpController,
        acController,
        speedController,
        initiativeController,
        portraitController,
        strController,
        dexController,
        conController,
        intController,
        wisController,
        chaController,
      ]);
    }
  }

  Future<CustomMonsterAction?> _showCustomMonsterActionDialog({
    CustomMonsterAction? existing,
    CustomMonsterAction? seed,
    List<CustomMonsterAction> existingActions = const [],
  }) async {
    if (!mounted) return null;
    final source = existing ?? seed;
    final nameController = TextEditingController(
      text: source?.name ?? 'Strike',
    );
    final descriptionController = TextEditingController(
      text: source?.description ?? '',
    );
    final attackBonusController = TextEditingController(
      text: source?.attackBonus?.toString() ?? '3',
    );
    final damageController = TextEditingController(
      text: source?.damageFormula ?? '1d6+1',
    );
    final damageTypeController = TextEditingController(
      text: source?.damageType ?? 'slashing',
    );
    final healingController = TextEditingController(
      text: source?.healingFormula ?? '',
    );
    final saveDcController = TextEditingController(
      text: source?.saveDc?.toString() ?? '',
    );
    final tagsController = TextEditingController(
      text: source?.tags.join(', ') ?? '',
    );
    final multiattackController = TextEditingController(
      text: (source?.multiattackSteps ?? const <CustomMonsterMultiattackStep>[])
          .map((step) => '${step.count}x ${step.actionName}')
          .join('\n'),
    );
    var timing = source?.timing ?? encounter_models.CombatActionTiming.action;
    var rollKind =
        source?.rollKind ?? encounter_models.CombatActionRollKind.attack;
    var saveAbility = source?.saveAbility ?? 'DEX';
    var halfDamageOnSave = source?.halfDamageOnSave ?? false;
    var targetsSelf = source?.targetsSelf ?? false;
    var isRanged = source?.isRanged ?? false;

    try {
      return await showDialog<CustomMonsterAction>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final tokens = context.stitch;
              final isPassive =
                  timing == encounter_models.CombatActionTiming.passive;
              final usesAttack =
                  rollKind == encounter_models.CombatActionRollKind.attack;
              final usesDamage = rollKind ==
                      encounter_models.CombatActionRollKind.attack ||
                  rollKind == encounter_models.CombatActionRollKind.damage ||
                  rollKind == encounter_models.CombatActionRollKind.savingThrow;
              final usesHealing =
                  rollKind == encounter_models.CombatActionRollKind.healing;
              final usesSave =
                  rollKind == encounter_models.CombatActionRollKind.savingThrow;

              return AlertDialog(
                backgroundColor: tokens.panel,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  side: BorderSide(
                    color: _CinematicColors.gold.withValues(alpha: 0.28),
                  ),
                ),
                title: Text(
                    existing == null ? 'Agregar entrada' : 'Editar entrada'),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 540,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            hintText: 'Claw, Fire Breath, Parry...',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<
                                  encounter_models.CombatActionTiming>(
                                value: timing,
                                decoration: const InputDecoration(
                                  labelText: 'Timing',
                                ),
                                items: const [
                                  encounter_models.CombatActionTiming.action,
                                  encounter_models
                                      .CombatActionTiming.bonusAction,
                                  encounter_models.CombatActionTiming.reaction,
                                  encounter_models.CombatActionTiming.passive,
                                ].map((value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(_timingMenuLabel(value)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    timing = value;
                                    if (value ==
                                        encounter_models
                                            .CombatActionTiming.passive) {
                                      rollKind = encounter_models
                                          .CombatActionRollKind.none;
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<
                                  encounter_models.CombatActionRollKind>(
                                value: rollKind,
                                decoration: const InputDecoration(
                                  labelText: 'Resolucion',
                                ),
                                items: const [
                                  encounter_models.CombatActionRollKind.none,
                                  encounter_models.CombatActionRollKind.attack,
                                  encounter_models.CombatActionRollKind.damage,
                                  encounter_models.CombatActionRollKind.healing,
                                  encounter_models
                                      .CombatActionRollKind.savingThrow,
                                ].map((value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(_rollKindMenuLabel(value)),
                                  );
                                }).toList(),
                                onChanged: isPassive
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setDialogState(() {
                                          rollKind = value;
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Descripcion',
                            hintText:
                                'Texto de regla, condicion, recharge, aura...',
                          ),
                        ),
                        if (!isPassive && usesAttack) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: attackBonusController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Ataque +',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SwitchListTile(
                                  value: isRanged,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Ranged'),
                                  onChanged: (value) {
                                    setDialogState(() => isRanged = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!isPassive && usesDamage) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: damageController,
                                  decoration: const InputDecoration(
                                    labelText: 'Dano',
                                    hintText: '2d6+3',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: damageTypeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo de dano',
                                    hintText: 'slashing',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (!isPassive && usesHealing) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: healingController,
                            decoration: const InputDecoration(
                              labelText: 'Curacion',
                              hintText: '2d8+2',
                            ),
                          ),
                        ],
                        if (!isPassive && usesSave) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: saveAbility,
                                  decoration: const InputDecoration(
                                    labelText: 'Save',
                                  ),
                                  items: const [
                                    'STR',
                                    'DEX',
                                    'CON',
                                    'INT',
                                    'WIS',
                                    'CHA',
                                  ].map((value) {
                                    return DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setDialogState(() => saveAbility = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: saveDcController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'DC',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SwitchListTile(
                                  value: halfDamageOnSave,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Half on save'),
                                  onChanged: (value) {
                                    setDialogState(
                                      () => halfDamageOnSave = value,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: tagsController,
                          decoration: const InputDecoration(
                            labelText: 'Tags',
                            hintText: 'Recharge 5-6, Poison, Aura',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: multiattackController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Multiattack steps',
                            hintText: existingActions.isEmpty
                                ? '2x Claw\n1x Bite'
                                : '2x ${existingActions.first.name}',
                          ),
                        ),
                        SwitchListTile(
                          value: targetsSelf,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Se usa sobre si mismo'),
                          onChanged: (value) {
                            setDialogState(() => targetsSelf = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      final damage = _nullableText(damageController.text);
                      final healing = _nullableText(healingController.text);
                      if (!isPassive &&
                          usesDamage &&
                          damage != null &&
                          !_isValidDiceFormula(damage)) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Usa dano como 1d6, 2d8+3 o 4d10.'),
                          ),
                        );
                        return;
                      }
                      if (!isPassive &&
                          usesHealing &&
                          healing != null &&
                          !_isValidDiceFormula(healing)) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Usa curacion como 1d8, 2d8+3 o 4d10.'),
                          ),
                        );
                        return;
                      }
                      final saveDc = int.tryParse(saveDcController.text.trim());
                      if (!isPassive && usesSave && saveDc == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Indica una DC para la salvacion.'),
                          ),
                        );
                        return;
                      }

                      final steps =
                          _parseMultiattackSteps(multiattackController.text);
                      final attackBonus = int.tryParse(
                        attackBonusController.text.trim(),
                      );
                      final tags = tagsController.text
                          .split(',')
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList(growable: false);
                      final action = CustomMonsterAction(
                        id: existing?.id ??
                            source?.id ??
                            CustomMonsterRepository.newActionId(name),
                        name: name,
                        description: descriptionController.text.trim(),
                        timing: timing,
                        rollKind: isPassive
                            ? encounter_models.CombatActionRollKind.none
                            : rollKind,
                        attackBonus:
                            !isPassive && usesAttack ? attackBonus : null,
                        damageFormula: !isPassive && usesDamage ? damage : null,
                        damageType: !isPassive && usesDamage
                            ? _nullableText(damageTypeController.text)
                            : null,
                        healingFormula:
                            !isPassive && usesHealing ? healing : null,
                        saveAbility:
                            !isPassive && usesSave ? saveAbility : null,
                        saveDc: !isPassive && usesSave ? saveDc : null,
                        halfDamageOnSave:
                            !isPassive && usesSave && halfDamageOnSave,
                        targetsSelf: targetsSelf,
                        isRanged: !isPassive && isRanged,
                        tags: tags,
                        multiattackSteps: steps,
                      );
                      Navigator.of(dialogContext).pop(action);
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      _disposeDialogControllersAfterPop([
        nameController,
        descriptionController,
        attackBonusController,
        damageController,
        damageTypeController,
        healingController,
        saveDcController,
        tagsController,
        multiattackController,
      ]);
    }
  }

  String _customActionSummary(CustomMonsterAction action) {
    final parts = [
      _timingMenuLabel(action.timing),
      _rollKindMenuLabel(action.rollKind),
      if (action.attackBonus != null)
        'd20${action.attackBonus! >= 0 ? '+' : ''}${action.attackBonus}',
      if ((action.damageFormula ?? '').trim().isNotEmpty)
        action.damageFormula!.trim(),
      if ((action.healingFormula ?? '').trim().isNotEmpty)
        'Heal ${action.healingFormula!.trim()}',
      if (action.saveAbility != null && action.saveDc != null)
        '${action.saveAbility} DC ${action.saveDc}',
      if (action.multiattackSteps.isNotEmpty)
        action.multiattackSteps
            .map((step) => '${step.count}x ${step.actionName}')
            .join(', '),
    ];
    return parts.join(' - ');
  }

  List<CustomMonsterMultiattackStep> _parseMultiattackSteps(String value) {
    final steps = <CustomMonsterMultiattackStep>[];
    final lines = value
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    for (final line in lines) {
      final match =
          RegExp(r'^(\d+)\s*x?\s+(.+)$', caseSensitive: false).firstMatch(line);
      if (match == null) {
        steps.add(CustomMonsterMultiattackStep(actionName: line, count: 1));
        continue;
      }
      final count = int.tryParse(match.group(1) ?? '') ?? 1;
      final actionName = match.group(2)?.trim() ?? '';
      if (actionName.isEmpty) continue;
      steps.add(
        CustomMonsterMultiattackStep(
          actionName: actionName,
          count: count.clamp(1, 12).toInt(),
        ),
      );
    }
    return steps;
  }

  String? _nullableText(String value) {
    final text = value.trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  bool _isValidDiceFormula(String value) {
    return RegExp(
      r'^\d*d\d+([+-]\d+)?$',
      caseSensitive: false,
    ).hasMatch(value.trim().replaceAll(' ', ''));
  }

  String _timingMenuLabel(encounter_models.CombatActionTiming timing) {
    return switch (timing) {
      encounter_models.CombatActionTiming.action => 'Action',
      encounter_models.CombatActionTiming.bonusAction => 'Bonus Action',
      encounter_models.CombatActionTiming.reaction => 'Reaction',
      encounter_models.CombatActionTiming.passive => 'Passive',
      encounter_models.CombatActionTiming.movement => 'Movement',
      encounter_models.CombatActionTiming.objectInteraction =>
        'Object Interaction',
      encounter_models.CombatActionTiming.free => 'Free',
      encounter_models.CombatActionTiming.onHit => 'On Hit',
      encounter_models.CombatActionTiming.onDamageTaken => 'On Damage Taken',
      encounter_models.CombatActionTiming.startOfTurn => 'Start of Turn',
      encounter_models.CombatActionTiming.endOfTurn => 'End of Turn',
    };
  }

  String _rollKindMenuLabel(encounter_models.CombatActionRollKind rollKind) {
    return switch (rollKind) {
      encounter_models.CombatActionRollKind.none => 'Utility',
      encounter_models.CombatActionRollKind.attack => 'Attack',
      encounter_models.CombatActionRollKind.damage => 'Damage',
      encounter_models.CombatActionRollKind.healing => 'Healing',
      encounter_models.CombatActionRollKind.savingThrow => 'Saving Throw',
      encounter_models.CombatActionRollKind.abilityCheck => 'Ability Check',
      encounter_models.CombatActionRollKind.resource => 'Resource',
    };
  }

  Future<void> _beginConfiguredCombat() async {
    final stagedEnemyCount =
        _stagedMonsterCounts.values.fold<int>(0, (sum, count) => sum + count) +
            _stagedCustomMonsterCounts.values
                .fold<int>(0, (sum, count) => sum + count);
    if (stagedEnemyCount == 0) {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
              'Add at least one enemy before combat begins.'),
        );
      });
      return;
    }
    await _applyStagedMonsterSetup(beginCombat: true);
  }

  _CombatCharacterSnapshot? _characterSnapshotForCombatantId(
    String combatantId,
  ) {
    final engineCombatant = _encounter?.combatantById(combatantId);
    if (engineCombatant != null) {
      if (engineCombatant.team != encounter_models.CombatantTeam.party) {
        return null;
      }
      final characterId = engineCombatant.sourceId ??
          engineCombatant.metadata['characterId']?.toString();
      if (characterId == null || characterId.trim().isEmpty) return null;
      return _CombatCharacterSnapshot(
        characterId: characterId.trim(),
        currentHp: engineCombatant.hp,
        tempHp: engineCombatant.tempHp,
        resources: Map<String, int>.from(engineCombatant.resources),
      );
    }

    final uiIndex =
        _combatants.indexWhere((combatant) => combatant.id == combatantId);
    if (uiIndex == -1 || _combatants[uiIndex].team != _CombatTeam.party) {
      return null;
    }
    final uiCombatant = _combatants[uiIndex];
    final characterId = uiCombatant.sourceId;
    if (characterId == null || characterId.trim().isEmpty) return null;
    return _CombatCharacterSnapshot(
      characterId: characterId.trim(),
      currentHp: uiCombatant.hp,
      tempHp: uiCombatant.tempHp,
      resources: const {},
    );
  }

  void _queueCharacterCombatSnapshot(String combatantId) {
    final snapshot = _characterSnapshotForCombatantId(combatantId);
    if (snapshot == null) return;
    _pendingCharacterCombatSnapshots[snapshot.characterId] = snapshot;
    Future.microtask(() {
      _characterProvider?.applyCombatSnapshotToCharacterById(
        snapshot.characterId,
        currentHp: snapshot.currentHp,
        tempHp: snapshot.tempHp,
        resources: snapshot.resources,
      );
    });
  }

  Future<void> _flushCharacterCombatState() async {
    final snapshots = _pendingCharacterCombatSnapshots.values.toList(
      growable: false,
    );
    _pendingCharacterCombatSnapshots.clear();
    await _flushCharacterCombatSnapshots(snapshots);
  }

  Future<void> _flushCharacterCombatSnapshots(
    List<_CombatCharacterSnapshot> snapshots,
  ) async {
    final provider = _characterProvider;
    if (provider == null) return;
    for (final snapshot in snapshots) {
      await provider.saveCombatSnapshotToCharacterById(
        snapshot.characterId,
        currentHp: snapshot.currentHp,
        tempHp: snapshot.tempHp,
        resources: snapshot.resources,
      );
    }
  }

  Future<void> _exitCombatMode() async {
    await _flushCharacterCombatState();
    if (!mounted) return;
    stitchGoBackOrHome(context);
  }

  void _adjustCombatantHp(int combatantIndex, int delta) {
    if (combatantIndex < 0 || combatantIndex >= _combatants.length) return;
    final combatant = _combatants[combatantIndex];
    if (delta == 0) return;

    setState(() {
      final encounter = _encounter;
      if (encounter != null) {
        _encounter = delta < 0
            ? CombatEncounterEngine.applyDamage(
                encounter,
                sourceId: 'dm',
                targetId: combatant.id,
                amount: -delta,
                formula: 'DM adjustment',
              )
            : CombatEncounterEngine.applyHealing(
                encounter,
                sourceId: 'dm',
                targetId: combatant.id,
                amount: delta,
                formula: 'DM adjustment',
              );
        _syncUiFromEncounter();
      } else {
        final nextHp = (combatant.hp + delta).clamp(0, combatant.maxHp).toInt();
        final nextCombatants = [..._combatants];
        nextCombatants[combatantIndex] = combatant.copyWith(hp: nextHp);
        _combatants = nextCombatants;
      }

      _activity.insert(
        0,
        _CombatLogEntry.system(
          'DM ${delta < 0 ? 'damaged' : 'healed'} ${combatant.name} for ${delta.abs()} HP.',
        ),
      );
    });
    _queueCharacterCombatSnapshot(combatant.id);
  }

  Future<void> _openHpAdjustmentSheet(int combatantIndex) async {
    if (combatantIndex < 0 || combatantIndex >= _combatants.length) return;
    final combatant = _combatants[combatantIndex];
    final controller = TextEditingController(text: '5');

    void applyDelta(BuildContext sheetContext, int sign) {
      final value = int.tryParse(controller.text.trim());
      if (value == null || value < 0) return;
      _adjustCombatantHp(combatantIndex, value * sign);
      Navigator.maybeOf(sheetContext)?.pop();
    }

    void applyExact(BuildContext sheetContext) {
      final value = int.tryParse(controller.text.trim());
      if (value == null || value < 0) return;
      final nextHp = value.clamp(0, combatant.maxHp).toInt();
      _adjustCombatantHp(combatantIndex, nextHp - combatant.hp);
      Navigator.maybeOf(sheetContext)?.pop();
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          return _HpAdjustmentSheet(
            combatant: combatant,
            controller: controller,
            onSubtract: () => applyDelta(sheetContext, -1),
            onAdd: () => applyDelta(sheetContext, 1),
            onSetExact: () => applyExact(sheetContext),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _applyStagedMonsterSetup({bool beginCombat = false}) async {
    if (_monsterCatalog.isEmpty) {
      await _loadMonsterCatalog();
    }
    final byIndex = {
      for (final monster in _monsterCatalog) monster.index: monster,
    };
    final builds = <MonsterCombatBuild>[];
    for (final entry in _stagedMonsterCounts.entries) {
      final monster = byIndex[entry.key];
      if (monster == null || entry.value <= 0) continue;
      for (var index = 1; index <= entry.value; index++) {
        builds.add(
          MonsterRepository.buildCombatant(
            monster: monster,
            instanceNumber: index,
            displayName:
                entry.value == 1 ? monster.name : '${monster.name} $index',
          ),
        );
      }
    }
    final customById = {
      for (final monster in _customMonsterCatalog) monster.id: monster,
    };
    for (final entry in _stagedCustomMonsterCounts.entries) {
      final monster = customById[entry.key];
      if (monster == null || entry.value <= 0) continue;
      for (var index = 1; index <= entry.value; index++) {
        builds.add(
          CustomMonsterRepository.buildCombatant(
            monster: monster,
            instanceNumber: index,
            displayName:
                entry.value == 1 ? monster.name : '${monster.name} $index',
          ),
        );
      }
    }
    if (!mounted) return;
    if (builds.isEmpty) {
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
            .removeWhere((_, action) => _isMonsterActionSource(action));
        _enemyActionsByCombatantId.clear();
        _encounter = _createEncounterFromEngineCombatants(party);
        _syncUiFromEncounter();
        _targetIndex = _findDefaultTargetIndex(_activeIndex);
        _seededMonsters = false;
        if (!beginCombat) {
          _activity.insert(
            0,
            _CombatLogEntry.system('Encounter setup has no enemies staged.'),
          );
        }
      });
      return;
    }

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
      _seededMonsters = true;
      _combatStarted = beginCombat || _combatStarted;
      _workspace = _CombatWorkspace.turn;
      _activity.insert(
        0,
        _CombatLogEntry.system(
          beginCombat
              ? 'Combat begins. ${builds.length} enemies enter initiative.'
              : 'Encounter setup updated: ${builds.length} enemies staged.',
        ),
      );
    });
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
      sourceId: combatant.sourceId,
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
      metadata: {
        if (combatant.ownerUserId != null &&
            combatant.ownerUserId!.trim().isNotEmpty)
          'ownerUserId': combatant.ownerUserId!.trim(),
        if (combatant.portraitAsset != null &&
            combatant.portraitAsset!.trim().isNotEmpty)
          'portraitPath': combatant.portraitAsset!.trim(),
      },
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
    if (_isHostileTargetIndex(syncedTargetIndex)) {
      _targetIndex = syncedTargetIndex;
    } else {
      _targetIndex = _findDefaultTargetIndex(_activeIndex);
    }
  }

  _Combatant get _activeCombatant => _combatants[_activeIndex];

  int get _safeTargetIndex {
    if (_combatants.isEmpty) return 0;
    if (_isHostileTargetIndex(_targetIndex)) {
      return _targetIndex;
    }
    return _findDefaultTargetIndex(_activeIndex);
  }

  _Combatant get _selectedTarget => _combatants[_safeTargetIndex];

  bool _isHostileTargetIndex(
    int targetIndex, {
    int? actorIndex,
    List<_Combatant>? source,
  }) {
    final list = source ?? _combatants;
    if (list.isEmpty || targetIndex < 0 || targetIndex >= list.length) {
      return false;
    }
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, list.length - 1).toInt();
    if (targetIndex == resolvedActorIndex) return false;
    final actor = list[resolvedActorIndex];
    final target = list[targetIndex];
    return target.hp > 0 && target.team != actor.team;
  }

  bool _isSupportTargetIndex(
    int targetIndex, {
    int? actorIndex,
    List<_Combatant>? source,
  }) {
    final list = source ?? _combatants;
    if (list.isEmpty || targetIndex < 0 || targetIndex >= list.length) {
      return false;
    }
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, list.length - 1).toInt();
    final actor = list[resolvedActorIndex];
    final target = list[targetIndex];
    return target.hp > 0 && target.team == actor.team;
  }

  int? _firstHostileTargetIndex(
    int actorIndex, [
    List<_Combatant>? source,
  ]) {
    final list = source ?? _combatants;
    if (list.isEmpty) return null;
    final resolvedActorIndex = actorIndex.clamp(0, list.length - 1).toInt();
    for (var index = 0; index < list.length; index++) {
      if (_isHostileTargetIndex(
        index,
        actorIndex: resolvedActorIndex,
        source: list,
      )) {
        return index;
      }
    }
    return null;
  }

  int _findDefaultSupportTargetIndex(int actorIndex) {
    if (_combatants.isEmpty) return 0;
    final resolvedActorIndex =
        actorIndex.clamp(0, _combatants.length - 1).toInt();
    for (var index = 0; index < _combatants.length; index++) {
      final combatant = _combatants[index];
      if (combatant.team == _combatants[resolvedActorIndex].team &&
          combatant.hp > 0 &&
          combatant.hp < combatant.maxHp) {
        return index;
      }
    }
    if (_isSupportTargetIndex(resolvedActorIndex,
        actorIndex: resolvedActorIndex)) {
      return resolvedActorIndex;
    }
    return resolvedActorIndex;
  }

  bool _actionNeedsHostileTarget(_CombatAction action) {
    if (action.targetsSelf || action.isHealing) return false;
    return action.hasMultiAttack ||
        action.attackFormula != null ||
        action.requiresSavingThrow ||
        action.damageFormula != null;
  }

  int? _targetIndexForAction(
    _CombatAction action, {
    int? actorIndex,
    int? forcedTargetIndex,
  }) {
    if (_combatants.isEmpty) return null;
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final canUseSelectedTarget = resolvedActorIndex == _activeIndex;
    if (action.targetsSelf) return resolvedActorIndex;

    if (action.isHealing) {
      if (forcedTargetIndex != null &&
          _isSupportTargetIndex(
            forcedTargetIndex,
            actorIndex: resolvedActorIndex,
          )) {
        return forcedTargetIndex;
      }
      if (canUseSelectedTarget &&
          _isSupportTargetIndex(
            _targetIndex,
            actorIndex: resolvedActorIndex,
          )) {
        return _targetIndex;
      }
      return _findDefaultSupportTargetIndex(resolvedActorIndex);
    }

    if (_actionNeedsHostileTarget(action)) {
      if (forcedTargetIndex != null &&
          _isHostileTargetIndex(
            forcedTargetIndex,
            actorIndex: resolvedActorIndex,
          )) {
        return forcedTargetIndex;
      }
      if (canUseSelectedTarget &&
          _isHostileTargetIndex(
            _targetIndex,
            actorIndex: resolvedActorIndex,
          )) {
        return _targetIndex;
      }
      return _firstHostileTargetIndex(resolvedActorIndex);
    }

    if (forcedTargetIndex != null &&
        forcedTargetIndex >= 0 &&
        forcedTargetIndex < _combatants.length) {
      return forcedTargetIndex;
    }
    return _findDefaultTargetIndex(resolvedActorIndex);
  }

  bool _ensureActionTargetAvailable(_CombatAction action, {int? actorIndex}) {
    if (!_actionNeedsHostileTarget(action)) return true;
    if (_combatants.isEmpty) return false;
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    if (_firstHostileTargetIndex(resolvedActorIndex) != null) return true;
    final actor = _combatants[resolvedActorIndex];
    setState(() {
      _activity.insert(
        0,
        _CombatLogEntry.system(
          '${actor.name} needs a hostile target for ${action.name}.',
        ),
      );
      _rollFeedback = _CombatRollFeedback.manual(
        actor: actor.name,
        action: action.name,
        headline: 'NO TARGET',
        subline: 'Choose a living enemy before rolling.',
        accentKind: _CombatAccentKind.read,
      );
    });
    return false;
  }

  List<_CombatAction> get _activeActions {
    return _actionsForCombatant(_activeCombatant);
  }

  Map<String, int> get _activeResourcePool {
    return _encounter?.combatantById(_activeCombatant.id)?.resources ?? {};
  }

  _ActionEconomySnapshot get _activeEconomy {
    final active = _activeCombatant;
    final readiedAction = _readiedActionsByCombatantId[active.id];
    return _ActionEconomySnapshot(
      actionSpent: _spentTimings.contains('Action'),
      bonusActionSpent: _spentTimings.contains('Bonus Action'),
      reactionSpent: _spentReactionCombatantIds.contains(active.id),
      movementAvailable: active.speed,
      readiedActionName: readiedAction?.action.name,
      readiedTrigger: readiedAction?.trigger,
    );
  }

  String? _currentUserId() {
    final rawUserId = context.read<AuthProvider?>()?.userId;
    final userId = rawUserId?.trim();
    return userId == null || userId.isEmpty ? null : userId;
  }

  bool _canControlCombatant(_Combatant combatant) {
    if (_dmView) return true;
    if (combatant.team == _CombatTeam.enemy) return false;

    final routeCharacterId = widget.characterId?.trim();
    if (routeCharacterId != null && routeCharacterId.isNotEmpty) {
      return combatant.sourceId == routeCharacterId ||
          combatant.id == routeCharacterId ||
          combatant.id == 'character_$routeCharacterId';
    }

    final userId = _currentUserId();
    if (userId == null) return false;
    return combatant.ownerUserId == userId;
  }

  String _controlBlockedMessage(_Combatant combatant) {
    if (combatant.team == _CombatTeam.enemy) {
      return 'Vista jugador: los enemigos los dirige el DM.';
    }
    return 'Vista jugador: solo puedes resolver acciones de tu personaje.';
  }

  bool _ensureCanControlCombatant(
    _Combatant combatant, {
    String actionLabel = 'resolver acciones',
  }) {
    if (_canControlCombatant(combatant)) return true;
    final message = '${_controlBlockedMessage(combatant)} No puedes '
        '$actionLabel de ${combatant.name}.';
    setState(() {
      _activity.insert(0, _CombatLogEntry.system(message));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ),
    );
    return false;
  }

  void _notifyActiveControlBlocked() {
    _ensureCanControlCombatant(_activeCombatant);
  }

  List<_ReactionOption> get _reactionOptions {
    final options = <_ReactionOption>[];
    for (var index = 0; index < _combatants.length; index++) {
      if (index == _activeIndex) continue;
      final combatant = _combatants[index];
      if (combatant.hp <= 0) continue;
      final readiedAction = _readiedActionsByCombatantId[combatant.id];
      if (readiedAction != null) {
        if (_actionNeedsHostileTarget(readiedAction.action) &&
            !_isHostileTargetIndex(_activeIndex, actorIndex: index)) {
          continue;
        }
        options.add(
          _ReactionOption(
            actorIndex: index,
            combatant: combatant,
            action: readiedAction.action,
            spent: _spentReactionCombatantIds.contains(combatant.id),
            readied: true,
            trigger: readiedAction.trigger,
          ),
        );
        continue;
      }
      final reactionActions = _reactionActionsForCombatant(combatant);
      for (final action in reactionActions.take(2)) {
        if (_actionNeedsHostileTarget(action) &&
            !_isHostileTargetIndex(_activeIndex, actorIndex: index)) {
          continue;
        }
        options.add(
          _ReactionOption(
            actorIndex: index,
            combatant: combatant,
            action: action,
            spent: _spentReactionCombatantIds.contains(combatant.id),
          ),
        );
      }
    }
    return options.take(24).toList(growable: false);
  }

  List<_CombatAction> _actionsForCombatant(_Combatant combatant) {
    if (combatant.team == _CombatTeam.party) {
      return _partyActionsByCombatantId[combatant.id] ?? _characterActions;
    }
    return _enemyActionsByCombatantId[combatant.id] ?? _enemyActions;
  }

  List<_CombatAction> _reactionActionsForCombatant(_Combatant combatant) {
    final actions = _actionsForCombatant(combatant);
    final explicitReactions = actions
        .where((action) => action.timing == 'Reaction')
        .toList(growable: false);
    if (explicitReactions.isNotEmpty) return explicitReactions;

    final opportunitySource = _firstOrNull(
      actions.where(_looksLikeOpportunityAttackSource),
    );
    if (opportunitySource == null) return const [];
    return [
      _opportunityAttackFrom(opportunitySource),
    ];
  }

  bool _looksLikeOpportunityAttackSource(_CombatAction action) {
    if (action.attackFormula == null || action.targetsSelf) return false;
    if (action.hasMultiAttack) return false;
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    if (text.contains('ranged') || text.contains('spell attack')) {
      return false;
    }
    return text.contains('melee') ||
        text.contains('sword') ||
        text.contains('blade') ||
        text.contains('claw') ||
        text.contains('bite') ||
        text.contains('tail') ||
        text.contains('unarmed') ||
        text.contains('weapon attack');
  }

  _CombatAction _opportunityAttackFrom(_CombatAction source) {
    return _CombatAction(
      id: source.id.isEmpty
          ? '${source.name}|opportunity'
          : '${source.id}|opportunity',
      name: 'Opportunity Attack',
      type: 'Reaction',
      timing: 'Reaction',
      attackFormula: source.attackFormula,
      damageFormula: source.damageFormula,
      critFormula: source.critFormula,
      tags: [
        'Reaction',
        'Opportunity',
        ...source.tags.where((tag) => tag != 'Reaction'),
      ],
      icon: Icons.reply_outlined,
      accentKind: source.accentKind,
    );
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
      _spentReactionCombatantIds.clear();
      _readiedActionsByCombatantId.clear();
      _clearMultiAttackProgress();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _rollFeedback = null;
      _activity.removeWhere(
        (entry) =>
            entry.title == 'DM requested initiative. Waiting for party rolls.',
      );
      _activity.insert(
        0,
        _CombatLogEntry.system('Initiative rolled. Round 1 begins.'),
      );
    });
  }

  void _nextTurn() {
    if (!_ensureCanControlCombatant(
      _activeCombatant,
      actionLabel: 'terminar el turno',
    )) {
      return;
    }
    _autoAdvanceScheduled = false;
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
      _spentReactionCombatantIds.remove(_activeCombatant.id);
      final expiredReady =
          _readiedActionsByCombatantId.remove(_activeCombatant.id);
      if (expiredReady != null) {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${_activeCombatant.name} readied action expired.',
          ),
        );
      }
      _clearMultiAttackProgress();
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

  void _scheduleAutoAdvanceTurn(String reason) {
    if (_autoAdvanceScheduled) return;
    final activeId = _activeCombatant.id;
    final round = _round;
    _autoAdvanceScheduled = true;

    Future.delayed(const Duration(milliseconds: 950), () {
      if (!mounted || !_autoAdvanceScheduled) return;
      if (_combatants.isEmpty ||
          _activeCombatant.id != activeId ||
          _round != round ||
          _pendingDamageActions.isNotEmpty ||
          _queuedPreparedActions.isNotEmpty) {
        _autoAdvanceScheduled = false;
        return;
      }
      _activity.insert(0, _CombatLogEntry.system(reason));
      _nextTurn();
    });
  }

  DiceRollResult _rollCombatFormula({
    required String formula,
    required String label,
    bool useRollMode = false,
  }) {
    return DiceRollerService.rollFormula(
      formula: formula,
      label: label,
      advantage: useRollMode && _hasAdvantage,
      disadvantage: useRollMode && _hasDisadvantage,
    );
  }

  void _rollAction(_CombatAction action, _CombatActionRoll rollType) {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (!_ensureActionTargetAvailable(action)) return;
    if (action.hasMultiAttack) {
      _rollMultiAttackStep(action, rollType);
      return;
    }

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

    final initialTargetIndex = _targetIndexForAction(action);
    final initialTarget =
        initialTargetIndex == null ? null : _combatants[initialTargetIndex];
    final formula = switch (rollType) {
      _CombatActionRoll.attack => action.attackFormula,
      _CombatActionRoll.savingThrow => action.requiresSavingThrow
          ? initialTarget == null
              ? null
              : _savingThrowFormulaForTarget(
                  initialTarget,
                  action.saveAbility!,
                )
          : null,
      _CombatActionRoll.damage => action.damageFormula,
      _CombatActionRoll.critical => action.critFormula,
    };

    if (formula == null) return;

    final label = switch (rollType) {
      _CombatActionRoll.attack => '${action.name} Attack',
      _CombatActionRoll.savingThrow =>
        '${initialTarget?.name ?? 'Target'} ${action.saveAbility} Save',
      _CombatActionRoll.damage => '${action.name} Damage',
      _CombatActionRoll.critical => '${action.name} Critical',
    };

    final result = _rollCombatFormula(
      formula: formula,
      label: label,
      useRollMode: rollType == _CombatActionRoll.attack ||
          rollType == _CombatActionRoll.savingThrow,
    );

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
        final targetIndex = _targetIndexForAction(action);
        if (targetIndex == null) return;
        final target = _combatants[targetIndex];
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
        final targetIndex = _targetIndexForAction(action);
        if (targetIndex == null) return;
        final target = _combatants[targetIndex];
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
        final targetIndex = _targetIndexForAction(action);
        if (targetIndex == null) return;
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

  void _useReaction(int actorIndex, _CombatAction action) {
    if (actorIndex < 0 ||
        actorIndex >= _combatants.length ||
        actorIndex == _activeIndex) {
      return;
    }
    final actor = _combatants[actorIndex];
    if (actor.hp <= 0) return;
    if (!_ensureCanControlCombatant(
      actor,
      actionLabel: 'usar la reaccion',
    )) {
      return;
    }
    if (_actionNeedsHostileTarget(action) &&
        !_isHostileTargetIndex(_activeIndex, actorIndex: actorIndex)) {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${actor.name} cannot use ${action.name} against an ally.',
          ),
        );
      });
      return;
    }

    if (_spentReactionCombatantIds.contains(actor.id)) {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${actor.name} has already spent a reaction.',
          ),
        );
      });
      return;
    }

    final resourceBlock = _reactionResourceBlockMessage(actor, action);
    if (resourceBlock != null) {
      setState(() {
        _activity.insert(0, _CombatLogEntry.system(resourceBlock));
      });
      return;
    }

    final readiedAction = _readiedActionsByCombatantId[actor.id];
    final isReadiedAction =
        readiedAction != null && identical(readiedAction.action, action);
    setState(() {
      _spentReactionCombatantIds.add(actor.id);
      if (isReadiedAction) {
        _readiedActionsByCombatantId.remove(actor.id);
      }
      _activity.insert(
        0,
        _CombatLogEntry.system(
          isReadiedAction
              ? '${actor.name} triggers readied action: ${action.name}.'
              : '${actor.name} uses reaction: ${action.name}.',
        ),
      );
      if (!isReadiedAction) {
        _spendEngineActionResourceForCombatant(action, actor);
      }
      _rollFeedback = _resolvePreparedAction(
        action,
        actorIndex: actorIndex,
        forcedTargetIndex: _activeIndex,
      );
    });
  }

  String? _reactionResourceBlockMessage(
    _Combatant actor,
    _CombatAction action,
  ) {
    final resourceKey = action.resourceKey;
    final resourceCost = action.resourceCost;
    if (resourceKey == null || resourceCost <= 0) return null;

    final pool = _encounter?.combatantById(actor.id)?.resources ?? const {};
    final remaining = pool[resourceKey] ?? 0;
    if (remaining >= resourceCost) return null;
    return '${actor.name} cannot react: ${_readableActionResourceName(resourceKey)} is depleted.';
  }

  Future<void> _readyAction(_CombatAction action) async {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (!_ensureActionTargetAvailable(action)) return;
    if (action.timing != 'Action') {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            'Ready requires an Action. Choose an Action first.',
          ),
        );
      });
      return;
    }
    if (_spentTimings.contains('Action')) {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${_activeCombatant.name} has already spent Action this turn.',
          ),
        );
      });
      return;
    }
    if (_spentReactionCombatantIds.contains(_activeCombatant.id)) {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${_activeCombatant.name} needs an available reaction to Ready.',
          ),
        );
      });
      return;
    }
    final resourceBlock = _actionResourceBlockMessage(action);
    if (resourceBlock != null) {
      setState(() {
        _activity.insert(0, _CombatLogEntry.system(resourceBlock));
      });
      return;
    }

    final trigger = await _askReadyTrigger(action);
    if (!mounted || trigger == null || trigger.trim().isEmpty) return;
    final targetIndex = _targetIndexForAction(action);
    if (_actionNeedsHostileTarget(action) && targetIndex == null) {
      _ensureActionTargetAvailable(action);
      return;
    }

    setState(() {
      _resetQueuedPreparedActions();
      _pendingDamageActions.remove(_actionExecutionKey(action));
      _pendingHalfDamageActions.remove(_actionExecutionKey(action));
      _preparedActions.remove(action.timing);
      _spentTimings.add('Action');
      _spendEngineActionResource(action);
      final concentrationRequired = _actionRequiresConcentrationToReady(action);
      if (concentrationRequired) {
        final condition = _applyActionState(
          _concentrationReadyMarker(action),
        );
        if (condition != null) {
          _applyEngineCondition(
            actor: _activeCombatant,
            target: _activeCombatant,
            name: condition,
            sourceActionName: 'Ready ${action.name}',
          );
        }
      }
      _syncUiFromEncounter();
      _readiedActionsByCombatantId[_activeCombatant.id] = _ReadiedAction(
        combatantId: _activeCombatant.id,
        action: action,
        trigger: trigger.trim(),
        round: _round,
        targetId: targetIndex == null
            ? _activeCombatant.id
            : _combatants[targetIndex].id,
        concentrationRequired: concentrationRequired,
      );
      _rollFeedback = _CombatRollFeedback.manual(
        actor: _activeCombatant.name,
        action: 'Ready ${action.name}',
        headline: 'READY',
        subline: trigger.trim(),
        accentKind: action.accentKind,
      );
      _activity.insert(
        0,
        _CombatLogEntry.system(
          '${_activeCombatant.name} readies ${action.name}: ${trigger.trim()}',
        ),
      );
    });
  }

  Future<String?> _askReadyTrigger(_CombatAction action) {
    final controller = TextEditingController(
      text: 'When a hostile creature acts within range',
    );
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.stitch.surface,
          title: Text('Ready ${action.name}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Trigger',
              hintText: 'When the goblin moves away...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Ready'),
            ),
          ],
        );
      },
    );
  }

  bool _actionRequiresConcentrationToReady(_CombatAction action) {
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    return text.contains('spell') && !text.contains('cantrip');
  }

  _CombatAction _concentrationReadyMarker(_CombatAction action) {
    return _CombatAction(
      id: '${action.id}|ready_concentration',
      name: 'Ready ${action.name}',
      type: 'Concentration',
      timing: 'Action',
      attackFormula: null,
      damageFormula: null,
      critFormula: null,
      tags: const ['Concentration'],
      icon: Icons.psychology_alt_outlined,
      accentKind: _CombatAccentKind.magic,
      targetsSelf: true,
    );
  }

  void _rollMultiAttackStep(
    _CombatAction action,
    _CombatActionRoll rollType,
  ) {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    final actionKey = _actionExecutionKey(action);
    final currentProgress = _multiAttackProgress;
    final hasActiveProgress = currentProgress != null &&
        currentProgress.actionKey == actionKey &&
        currentProgress.stepIndex < action.multiAttackSteps.length;

    if (!hasActiveProgress && !_ensureActionTargetAvailable(action)) return;

    if (!hasActiveProgress) {
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
    }

    setState(() {
      var progress = hasActiveProgress
          ? currentProgress
          : _MultiAttackProgress(actionKey: actionKey);

      if (!hasActiveProgress) {
        _resetQueuedPreparedActions();
        _pendingDamageActions.remove(actionKey);
        _pendingHalfDamageActions.remove(actionKey);
        _spentTimings.add(action.timing);
        _spendEngineActionResource(action);
        final economyMessage = _applyActionEconomyEffect(action);
        if (economyMessage != null) {
          _activity.insert(0, _CombatLogEntry.system(economyMessage));
        }
        _multiAttackProgress = progress;
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${_activeCombatant.name} starts ${action.name}: ${action.multiAttackSteps.length} attacks.',
          ),
        );
      }

      if (progress.hasPendingDamage) {
        if (rollType == _CombatActionRoll.attack ||
            rollType == _CombatActionRoll.savingThrow) {
          _activity.insert(
            0,
            _CombatLogEntry.system(
              'Resolve ${action.name} damage before the next attack.',
            ),
          );
          return;
        }
        _resolveMultiAttackPendingDamage(action, progress);
        return;
      }

      if (rollType == _CombatActionRoll.damage ||
          rollType == _CombatActionRoll.critical) {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            'Roll the next ${action.name} attack before damage.',
          ),
        );
        return;
      }

      if (progress.stepIndex >= action.multiAttackSteps.length) {
        _finishMultiAttackProgress(action, progress);
        return;
      }

      final step = action.multiAttackSteps[progress.stepIndex];
      if (step.attackFormula == null && step.damageFormula != null) {
        final targetIndex = _targetIndexForAction(action);
        if (targetIndex == null) return;
        progress
          ..pendingStepIndex = progress.stepIndex
          ..pendingTargetIndex = targetIndex
          ..pendingCritical = false;
        _pendingDamageActions.add(actionKey);
        _resolveMultiAttackPendingDamage(action, progress);
        return;
      }

      final attackFormula = step.attackFormula;
      if (attackFormula == null) {
        progress.stepIndex += 1;
        _advanceMultiAttackAfterStep(action, progress);
        return;
      }

      final targetIndex = _targetIndexForAction(action);
      if (targetIndex == null) return;
      final target = _combatants[targetIndex];
      final stepNumber = progress.stepIndex + 1;
      final stepLabel = '${action.name} $stepNumber: ${step.name}';
      final result = _rollCombatFormula(
        formula: attackFormula,
        label: '$stepLabel Attack',
        useRollMode: true,
      );
      final outcome = _attackOutcome(result, target);
      final didHit = outcome == 'hit' || outcome == 'critical hit';
      final didCrit = outcome == 'critical hit';
      progress.attackCount += 1;
      if (didCrit) progress.critCount += 1;

      _activity.insert(
        0,
        _CombatLogEntry.roll(
          actor: _activeCombatant.name,
          action: '$stepLabel attack',
          result: result,
          detail:
              '${result.formula} - ${result.rollsText}. ${target.name} AC ${target.ac}: $outcome.',
        ),
      );

      if (didHit && step.damageFormula != null) {
        progress
          ..pendingStepIndex = progress.stepIndex
          ..pendingTargetIndex = targetIndex
          ..pendingCritical = didCrit;
        _pendingDamageActions.add(actionKey);
      } else {
        progress.stepIndex += 1;
        _pendingDamageActions.remove(actionKey);
        _advanceMultiAttackAfterStep(action, progress);
      }

      _rollFeedback = _CombatRollFeedback(
        actor: _activeCombatant.name,
        action: action.name,
        result: result,
        headline: outcome.toUpperCase(),
        subline:
            'Attack $stepNumber/${action.multiAttackSteps.length} vs ${target.name}',
        accentKind: switch (outcome) {
          'critical hit' => _CombatAccentKind.support,
          'hit' => _CombatAccentKind.action,
          'automatic miss' => _CombatAccentKind.info,
          _ => _CombatAccentKind.read,
        },
      );
    });
  }

  void _resolveMultiAttackPendingDamage(
    _CombatAction action,
    _MultiAttackProgress progress,
  ) {
    final actionKey = _actionExecutionKey(action);
    final stepIndex = progress.pendingStepIndex;
    final targetIndex = progress.pendingTargetIndex;
    if (stepIndex == null ||
        targetIndex == null ||
        stepIndex < 0 ||
        stepIndex >= action.multiAttackSteps.length ||
        targetIndex < 0 ||
        targetIndex >= _combatants.length) {
      _pendingDamageActions.remove(actionKey);
      progress.clearPendingDamage();
      return;
    }

    final step = action.multiAttackSteps[stepIndex];
    final wasCritical = progress.pendingCritical;
    final damageFormula = progress.pendingCritical
        ? step.critFormula ?? step.damageFormula
        : step.damageFormula;
    if (damageFormula == null) {
      progress
        ..clearPendingDamage()
        ..stepIndex = stepIndex + 1;
      _pendingDamageActions.remove(actionKey);
      _advanceMultiAttackAfterStep(action, progress);
      return;
    }

    final target = _combatants[targetIndex];
    final stepNumber = stepIndex + 1;
    final stepLabel = '${action.name} $stepNumber: ${step.name}';
    final result = _rollCombatFormula(
      formula: damageFormula,
      label: '$stepLabel Damage',
    );
    final amount = result.total;
    final hpResult = _resolveHpChange(target, amount, healing: false);
    _combatants = [
      for (var index = 0; index < _combatants.length; index++)
        index == targetIndex
            ? target.copyWith(hp: hpResult.hp, tempHp: hpResult.tempHp)
            : _combatants[index],
    ];
    _applyEngineHpChange(
      actor: _activeCombatant,
      target: target,
      amount: amount,
      healing: false,
      action: action,
      formula: result.formula,
    );
    _syncUiFromEncounter();

    progress
      ..totalDamage += amount
      ..hitCount += 1
      ..lastHpLine = _hpChangeLine(target, hpResult)
      ..clearPendingDamage()
      ..stepIndex = stepIndex + 1;
    _pendingDamageActions.remove(actionKey);
    _pendingHalfDamageActions.remove(actionKey);

    _activity.insert(
      0,
      _CombatLogEntry.roll(
        actor: _activeCombatant.name,
        action: '$stepLabel damage',
        result: result,
        detail:
            '${result.formula} - ${result.rollsText}. ${target.name} takes $amount damage (${progress.lastHpLine}).',
      ),
    );

    if (target.hp > 0 && hpResult.hp == 0) {
      _activity.insert(0, _CombatLogEntry.system('${target.name} is down.'));
      _targetIndex = _findDefaultTargetIndex(_activeIndex);
    }

    final completed = progress.stepIndex >= action.multiAttackSteps.length;
    _rollFeedback = _CombatRollFeedback(
      actor: _activeCombatant.name,
      action: action.name,
      result: result,
      headline: wasCritical ? 'CRIT $amount DAMAGE' : '$amount DAMAGE',
      subline: completed
          ? 'Multiattack complete: ${progress.hitCount}/${progress.attackCount} hits'
          : 'Attack $stepNumber/${action.multiAttackSteps.length} damage',
      accentKind: wasCritical ? _CombatAccentKind.support : action.accentKind,
    );

    _advanceMultiAttackAfterStep(action, progress);
  }

  void _advanceMultiAttackAfterStep(
    _CombatAction action,
    _MultiAttackProgress progress,
  ) {
    if (progress.stepIndex >= action.multiAttackSteps.length) {
      _finishMultiAttackProgress(action, progress);
      return;
    }
    final nextStep = action.multiAttackSteps[progress.stepIndex];
    _activity.insert(
      0,
      _CombatLogEntry.system(
        'Next ${action.name} roll: ${progress.stepIndex + 1}/${action.multiAttackSteps.length} ${nextStep.name}.',
      ),
    );
  }

  void _finishMultiAttackProgress(
    _CombatAction action,
    _MultiAttackProgress progress,
  ) {
    final actionKey = _actionExecutionKey(action);
    _pendingDamageActions.remove(actionKey);
    _pendingHalfDamageActions.remove(actionKey);
    _activity.insert(
      0,
      _CombatLogEntry.system(
        '${action.name} complete: ${progress.hitCount}/${progress.attackCount} hits, ${progress.totalDamage} total damage.',
      ),
    );
    _multiAttackProgress = null;
  }

  void _useAction(_CombatAction action) {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (action.hasMultiAttack) {
      _rollMultiAttackStep(action, _CombatActionRoll.attack);
      return;
    }

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
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (!_ensureActionTargetAvailable(action)) return;
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
      final targetIndex = _targetIndexForAction(action);
      if (encounter != null && engineAction != null) {
        _encounter = CombatEncounterEngine.prepareAction(
          encounter,
          combatantId: _activeCombatant.id,
          action: engineAction.copyWith(
            timing: _timingFromLabel(action.timing),
            actorId: _activeCombatant.id,
            targetId: targetIndex == null
                ? _activeCombatant.id
                : _combatants[targetIndex].id,
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
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
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
    if (!_ensureCanControlCombatant(_activeCombatant)) return;

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
      _preparedActions.remove(action.timing);

      _queuedPreparedIndex += 1;

      _syncUiFromEncounter();
      _rollFeedback = feedback;
      if (_queuedPreparedIndex >= _queuedPreparedActions.length) {
        _resetQueuedPreparedActions();
        _preparedActions.clear();
        _activity.insert(
          0,
          _CombatLogEntry.system('Turn plan fully rolled.'),
        );
        _scheduleAutoAdvanceTurn(
          '${_activeCombatant.name} completed the planned turn.',
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
      _spentReactionCombatantIds.clear();
      _readiedActionsByCombatantId.clear();
      _clearMultiAttackProgress();
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
    if (_combatants.isEmpty) {
      return _CombatRollFeedback.manual(
        actor: 'Combat',
        action: action.name,
        headline: 'NO TARGET',
        subline: 'No combatants are available.',
        accentKind: _CombatAccentKind.read,
      );
    }
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final actor = _combatants[resolvedActorIndex];
    final targetIndex = _targetIndexForAction(
      action,
      actorIndex: resolvedActorIndex,
      forcedTargetIndex: forcedTargetIndex,
    );
    if (targetIndex == null) {
      _activity.insert(
        0,
        _CombatLogEntry.system(
          '${actor.name} needs a hostile target for ${action.name}.',
        ),
      );
      return _CombatRollFeedback.manual(
        actor: actor.name,
        action: action.name,
        headline: 'NO TARGET',
        subline: 'Choose a living enemy before rolling.',
        accentKind: _CombatAccentKind.read,
      );
    }
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
      final saveResult = _rollCombatFormula(
        formula: _savingThrowFormulaForTarget(target, action.saveAbility!),
        label: '${target.name} ${action.saveAbility} Save',
        useRollMode: true,
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
      final attackResult = _rollCombatFormula(
        formula: action.attackFormula!,
        label: '${action.name} Attack',
        useRollMode: true,
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
      if (!_isHostileTargetIndex(
        currentTargetIndex,
        actorIndex: actorIndex,
      )) {
        final nextTargetIndex = _firstHostileTargetIndex(actorIndex);
        if (nextTargetIndex == null) break;
        currentTargetIndex = nextTargetIndex;
      }
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
        final attackResult = _rollCombatFormula(
          formula: attackFormula,
          label: '$stepLabel Attack',
          useRollMode: true,
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
    if (index < 0 || index >= _combatants.length) {
      return;
    }
    if (!_isHostileTargetIndex(index)) {
      setState(() {
        _activity.insert(
          0,
          _CombatLogEntry.system(
            '${_combatants[index].name} is on the same side. Choose an enemy target.',
          ),
        );
      });
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
    _queueCharacterCombatSnapshot(target.id);
  }

  void _spendEngineActionResource(_CombatAction action) {
    _spendEngineActionResourceForCombatant(action, _activeCombatant);
  }

  void _spendEngineActionResourceForCombatant(
    _CombatAction action,
    _Combatant actor,
  ) {
    final encounter = _encounter;
    final engineAction = _engineActionForUi(action);
    final resourceKey = engineAction?.resourceKey ?? action.resourceKey;
    final resourceCost = engineAction?.resourceCost ?? action.resourceCost;
    if (encounter == null || resourceKey == null || resourceCost <= 0) return;

    _encounter = CombatEncounterEngine.spendResource(
      encounter,
      combatantId: actor.id,
      resourceKey: resourceKey,
      amount: resourceCost,
    );
    _queueCharacterCombatSnapshot(actor.id);
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
    if (!_dmView && !_canControlCombatant(_combatants[index])) {
      _ensureCanControlCombatant(
        _combatants[index],
        actionLabel: 'cambiar el turno',
      );
      return;
    }
    setState(() {
      _activeIndex = index;
      _targetIndex = _findDefaultTargetIndex(index);
      _spentTimings.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _spentReactionCombatantIds.remove(_combatants[index].id);
      _readiedActionsByCombatantId.remove(_combatants[index].id);
      _clearMultiAttackProgress();
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
    if (workspace == _CombatWorkspace.overview) {
      _showEncounterOverviewWindow();
      return;
    }

    setState(() {
      _workspace = workspace;
    });
  }

  void _showEncounterOverviewWindow() {
    if (_combatants.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 20,
          ),
          backgroundColor: Colors.transparent,
          child: _EncounterOverviewWindow(
            combatants: _combatants,
            activeIndex: _activeIndex,
            targetIndex: _safeTargetIndex,
            rollFeedback: _rollFeedback,
            showEnemyHp: _dmView,
            onClose: () => Navigator.of(dialogContext).maybePop(),
          ),
        );
      },
    );
  }

  void _toggleDmView() {
    setState(() {
      _dmView = !_dmView;
    });
  }

  Future<String?> _ensureBattleBoardScene() async {
    if (_openingBattleBoard) return null;

    final campaignId = _resolvedCampaignId(listen: false);
    if (campaignId == null || campaignId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a campaign before opening the battle board.'),
        ),
      );
      return null;
    }

    setState(() {
      _openingBattleBoard = true;
    });

    try {
      final boardProvider = context.read<BattleBoardProvider>();
      final sceneId = _activeBattleBoardSceneId;
      if (sceneId != null) {
        boardProvider.watchScene(campaignId: campaignId, sceneId: sceneId);
        return sceneId;
      }

      final scene = await boardProvider.createScene(
        campaignId: campaignId,
        name: 'Combat Board - Round $_round',
        mapImageUrl: 'assets/images/combat/dungeon_battlefield.png',
        combatActive: _combatStarted,
      );

      for (final token in _boardTokensForScene(scene.id)) {
        await boardProvider.saveToken(campaignId: campaignId, token: token);
      }

      boardProvider.watchScene(campaignId: campaignId, sceneId: scene.id);
      _activeBattleBoardSceneId = scene.id;
      _selectedBattleBoardCombatantId ??= _activeCombatant.id;
      return scene.id;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not prepare the battle board: $error'),
        ),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _openingBattleBoard = false;
        });
      }
    }
  }

  Future<void> _openBattleBoardController() async {
    await _activateBattleBoardController(openDisplay: false);
  }

  Future<void> _activateBattleBoardController({
    required bool openDisplay,
  }) async {
    final campaignId = _resolvedCampaignId(listen: false);
    if (campaignId == null || campaignId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a campaign before opening the battle board.'),
        ),
      );
      return;
    }
    final sceneId = await _ensureBattleBoardScene();
    if (!mounted || sceneId == null) return;

    setState(() {
      _showBattleBoardController = true;
      _battleBoardControllerExpanded = true;
      _selectedBattleBoardCombatantId ??= _activeCombatant.id;
    });

    await _syncBattleBoardTokensFromCombatState();

    if (openDisplay) {
      await _openBattleBoardDisplayWindow();
    }
  }

  Future<void> _showBattleBoardControls() async {
    final pendingWindow = openPendingExternalWindow();
    await _activateBattleBoardController(openDisplay: false);

    final campaignId = _resolvedCampaignId(listen: false);
    final sceneId = _activeBattleBoardSceneId;
    if (campaignId == null || sceneId == null) {
      pendingWindow?.close();
      return;
    }

    pendingWindow?.navigate(_displayBoardUrl(campaignId, sceneId));
  }

  Future<void> _openBattleBoardDisplayWindow() async {
    final campaignId = _resolvedCampaignId(listen: false);
    final sceneId = _activeBattleBoardSceneId;
    if (campaignId == null || sceneId == null) return;

    final displayUrl = _displayBoardUrl(campaignId, sceneId);
    final opened = await openExternalUrl(displayUrl);
    if (!mounted) return;

    if (opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Battle board display opened in another window.'),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: displayUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Display URL copied. Open it in another browser window.'),
      ),
    );
  }

  String _displayBoardUrl(String campaignId, String sceneId) {
    final baseUri = Uri.base;
    if (baseUri.hasScheme &&
        (baseUri.scheme == 'http' || baseUri.scheme == 'https')) {
      return Uri.parse(baseUri.origin).replace(
        path: '/',
        queryParameters: {
          'boardCampaignId': campaignId,
          'boardSceneId': sceneId,
          'mode': 'display',
        },
      ).toString();
    }

    return Uri(
      path: '/',
      queryParameters: {
        'boardCampaignId': campaignId,
        'boardSceneId': sceneId,
        'mode': 'display',
      },
    ).toString();
  }

  Future<void> _moveBattleBoardToken(String combatantId, int dx, int dy) async {
    final campaignId = _resolvedCampaignId(listen: false);
    final sceneId = _activeBattleBoardSceneId;
    if (campaignId == null || sceneId == null) return;

    final boardProvider = context.read<BattleBoardProvider>();
    final scene = boardProvider.activeScene;
    final matchingTokens = boardProvider.tokens.where(
      (token) => token.sceneId == sceneId && token.refId == combatantId,
    );
    if (scene == null || matchingTokens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board token is still loading.')),
      );
      return;
    }

    final token = matchingTokens.first;
    final nextX = (token.x + dx).clamp(0, scene.gridColumns - token.size);
    final nextY = (token.y + dy).clamp(0, scene.gridRows - token.size);
    await boardProvider.moveToken(
      campaignId: campaignId,
      token: token,
      x: nextX,
      y: nextY,
    );
  }

  Future<void> _syncBattleBoardTokensFromCombatState() async {
    final campaignId = _resolvedCampaignId(listen: false);
    final sceneId = _activeBattleBoardSceneId;
    if (campaignId == null || sceneId == null) return;

    final boardProvider = context.read<BattleBoardProvider>();
    final tokenByRefId = {
      for (final token in boardProvider.tokens.where(
        (token) => token.sceneId == sceneId,
      ))
        token.refId: token,
    };

    for (final combatant in _combatants) {
      final token = tokenByRefId[combatant.id];
      if (token == null) continue;
      if (token.currentHp == combatant.hp &&
          token.maxHp == combatant.maxHp &&
          _stringListsMatch(token.conditions, combatant.conditions)) {
        continue;
      }

      await boardProvider.saveToken(
        campaignId: campaignId,
        token: token.copyWith(
          currentHp: combatant.hp,
          maxHp: combatant.maxHp,
          conditions: combatant.conditions,
        ),
      );
    }
  }

  bool _stringListsMatch(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  List<BoardToken> _boardTokensForScene(String sceneId) {
    final party = _combatants
        .where((combatant) => combatant.team == _CombatTeam.party)
        .toList(growable: false);
    final enemies = _combatants
        .where((combatant) => combatant.team == _CombatTeam.enemy)
        .toList(growable: false);
    final tokens = <BoardToken>[];

    for (var index = 0; index < party.length; index++) {
      final combatant = party[index];
      tokens.add(
        BoardToken.create(
          id: '${sceneId}_${combatant.id}',
          sceneId: sceneId,
          refId: combatant.id,
          type: 'character',
          name: combatant.name,
          imageUrl: combatant.portraitAsset ?? '',
          x: 3 + (index % 3),
          y: 4 + (index ~/ 3) * 2,
          size: 1,
          currentHp: combatant.hp,
          maxHp: combatant.maxHp,
          conditions: combatant.conditions,
        ),
      );
    }

    for (var index = 0; index < enemies.length; index++) {
      final combatant = enemies[index];
      tokens.add(
        BoardToken.create(
          id: '${sceneId}_${combatant.id}',
          sceneId: sceneId,
          refId: combatant.id,
          type: 'monster',
          name: combatant.name,
          imageUrl: combatant.portraitAsset ?? '',
          x: 16 + (index % 4),
          y: 4 + (index ~/ 4) * 2,
          size: 1,
          currentHp: combatant.hp,
          maxHp: combatant.maxHp,
          conditions: combatant.conditions,
        ),
      );
    }

    return tokens;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final boardCampaignId = _resolvedCampaignId(listen: false);
    final boardSceneId = _activeBattleBoardSceneId;
    final boardDisplayUrl = boardCampaignId != null && boardSceneId != null
        ? _displayBoardUrl(boardCampaignId, boardSceneId)
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_exitCombatMode());
      },
      child: Scaffold(
        backgroundColor: tokens.pageBottom,
        body: Stack(
          children: [
            Positioned.fill(
              child: _CombatArenaBackdrop(round: _round),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (!_combatStarted) {
                    return _CombatSetupView(
                      combatants: _combatants,
                      monsterCatalog: _visibleMonsterCatalog,
                      totalMonsterCount: _monsterCatalog.length,
                      monsterSearchQuery: _monsterSearchQuery,
                      monsterCatalogError: _monsterCatalogError,
                      stagedMonsterCounts: _stagedMonsterCounts,
                      customMonsters: _customMonsterCatalog,
                      stagedCustomMonsterCounts: _stagedCustomMonsterCounts,
                      customMonsterLoading: _customMonsterCatalogLoading,
                      customMonsterError: _customMonsterCatalogError,
                      loading: _monsterCatalogLoading,
                      onBack: () => unawaited(_exitCombatMode()),
                      onReloadCatalog: _reloadMonsterCatalog,
                      onMonsterSearchChanged: _setMonsterSearchQuery,
                      onChangeMonsterCount: _setStagedMonsterCount,
                      onChangeCustomMonsterCount: _setStagedCustomMonsterCount,
                      onCreateCustomEnemy: () => _showCustomEnemyDialog(),
                      onEditCustomEnemy: (monster) =>
                          _showCustomEnemyDialog(existing: monster),
                      onDeleteCustomEnemy: _deleteCustomMonster,
                      onRemoveCustomEnemy: _removeCustomEnemy,
                      onBeginCombat: _beginConfiguredCombat,
                    );
                  }

                  final useGameLayout = constraints.maxWidth >= 1080 &&
                      constraints.maxHeight >= 680;
                  final useCompactLandscapeLayout =
                      constraints.maxWidth >= 700 &&
                          constraints.maxHeight >= 340;
                  final canControlActive =
                      _canControlCombatant(_activeCombatant);
                  final controlBlockedMessage =
                      _controlBlockedMessage(_activeCombatant);

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
                          activeMultiAttackActionKey:
                              _multiAttackProgress?.actionKey,
                          reactionOptions: _reactionOptions,
                          activeEconomy: _activeEconomy,
                          queuedPreparedIndex: _queuedPreparedIndex,
                          queuedPreparedTotal: _queuedPreparedActions.length,
                          queuedPreparedActionName: _queuedPreparedActionName,
                          selectedCommandTiming: _selectedCommandTiming,
                          workspace: _workspace,
                          showEnemyHp: _dmView,
                          entries: _activity,
                          resourcePool: _activeResourcePool,
                          rollMode: _rollMode,
                          canControlActive: canControlActive,
                          controlBlockedMessage: controlBlockedMessage,
                          onBack: () => unawaited(_exitCombatMode()),
                          onRequestInitiative: _requestInitiative,
                          onRollInitiative: _rollInitiativeForAll,
                          onNextTurn: _nextTurn,
                          onToggleDmView: _toggleDmView,
                          onRunDemo: _runDemoRound,
                          onSelectTarget: _selectTarget,
                          onSelectFocusedCombatant: _selectFocusedCombatant,
                          onEditHp: _openHpAdjustmentSheet,
                          onRemoveActiveEffect: _removeActiveEffect,
                          onSelectWorkspace: _selectWorkspace,
                          onSelectCommandTiming: _selectCommandTiming,
                          onSelectRollMode: _selectRollMode,
                          onUseReaction: _useReaction,
                          onReadyAction: _readyAction,
                          onRollAction: _rollAction,
                          onUseAction: _useAction,
                          onPrepareAction: _prepareAction,
                          onLaunchPreparedTurn: _launchPreparedTurn,
                          onClearPreparedActions: _clearPreparedActions,
                          onControlBlocked: _notifyActiveControlBlocked,
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
                      canControlActive: canControlActive,
                      controlBlockedMessage: controlBlockedMessage,
                      onBack: () => unawaited(_exitCombatMode()),
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
                      onControlBlocked: _notifyActiveControlBlocked,
                    );
                  }

                  return _CombatNarrowModeView(
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
                    canControlActive: canControlActive,
                    controlBlockedMessage: controlBlockedMessage,
                    onBack: () => unawaited(_exitCombatMode()),
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
                    onControlBlocked: _notifyActiveControlBlocked,
                  );
                },
              ),
            ),
            if (_combatStarted &&
                _showBattleBoardController &&
                boardDisplayUrl != null)
              Positioned(
                top: 78,
                right: 16,
                child: SafeArea(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: _BattleBoardFloatingController(
                      displayUrl: boardDisplayUrl,
                      sceneId: boardSceneId!,
                      combatants: _combatants,
                      selectedCombatantId: _selectedBattleBoardCombatantId ??
                          _activeCombatant.id,
                      expanded: _battleBoardControllerExpanded,
                      onToggleExpanded: () {
                        setState(() {
                          _battleBoardControllerExpanded =
                              !_battleBoardControllerExpanded;
                        });
                      },
                      onClose: () {
                        setState(() {
                          _showBattleBoardController = false;
                        });
                      },
                      onSelectCombatant: (combatantId) {
                        setState(() {
                          _selectedBattleBoardCombatantId = combatantId;
                        });
                      },
                      onMove: _moveBattleBoardToken,
                      onOpenDisplay: _openBattleBoardDisplayWindow,
                      onSyncState: _syncBattleBoardTokensFromCombatState,
                    ),
                  ),
                ),
              ),
            if (_combatStarted)
              Positioned(
                top: 14,
                right: 16,
                child: SafeArea(
                  child: FloatingActionButton.extended(
                    heroTag: 'battle-board-controller',
                    onPressed: _openingBattleBoard
                        ? null
                        : () => unawaited(_showBattleBoardControls()),
                    icon: _openingBattleBoard
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.grid_view_rounded),
                    label: const Text('Board'),
                  ),
                ),
              ),
          ],
        ),
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
    final metadataPortraitPath = combatant.metadata['portraitPath']?.toString();
    final metadataCharacterId = combatant.metadata['characterId']?.toString();
    final metadataOwnerUserId = combatant.metadata['ownerUserId']?.toString();
    final portraitPath =
        metadataPortraitPath == null || metadataPortraitPath.trim().isEmpty
            ? combatant.kind == encounter_models.CombatantKind.playerCharacter
                ? null
                : _combatantPortraitAsset(
                    name: combatant.name,
                    role: combatant.role,
                    team: team,
                  )
            : metadataPortraitPath.trim();

    return _Combatant(
      id: combatant.id,
      sourceId: combatant.sourceId ??
          (metadataCharacterId == null || metadataCharacterId.trim().isEmpty
              ? null
              : metadataCharacterId.trim()),
      ownerUserId:
          metadataOwnerUserId == null || metadataOwnerUserId.trim().isEmpty
              ? null
              : metadataOwnerUserId.trim(),
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
      portraitAsset: portraitPath,
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
          action.rollKind == encounter_models.CombatActionRollKind.resource ||
              action.metadata['targetsSelf'] == true,
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
      if (source == 'unarmedMultiattack') return 'Unarmed Extra Attack';
      if (source == 'naturalWeaponMultiattack') return 'Natural Multiattack';
      if (source == 'monster') return 'Monster Multiattack';
      if (source == 'customMonster') return 'Custom Multiattack';
      return 'Multiattack';
    }
    if (source == 'unarmed') return 'Unarmed Attack';
    if (source == 'naturalWeapon') return 'Natural Weapon';
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
    if (source == 'customMonster') {
      if (action.timing == encounter_models.CombatActionTiming.passive) {
        return 'Passive Trait';
      }
      if (action.timing == encounter_models.CombatActionTiming.reaction) {
        return 'Monster Reaction';
      }
      return 'Custom Monster';
    }
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
    if (source == 'unarmed') return Icons.back_hand_outlined;
    if (source == 'naturalWeapon') return Icons.crisis_alert_outlined;
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
    if (source == 'customMonster') {
      if (action.timing == encounter_models.CombatActionTiming.passive) {
        return Icons.auto_awesome_outlined;
      }
      if (action.timing == encounter_models.CombatActionTiming.reaction) {
        return Icons.reply_outlined;
      }
      return action.tags.any((tag) => tag.toLowerCase() == 'ranged')
          ? Icons.ads_click_outlined
          : Icons.crisis_alert_outlined;
    }
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
    if (source == 'unarmed' || source == 'naturalWeapon') {
      return _CombatAccentKind.action;
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
    if (source == 'customMonster') {
      if (action.timing == encounter_models.CombatActionTiming.passive) {
        return _CombatAccentKind.support;
      }
      return action.tags.any((tag) => tag.toLowerCase() == 'ranged')
          ? _CombatAccentKind.read
          : _CombatAccentKind.action;
    }
    return _CombatAccentKind.info;
  }

  String _readableResourceName(String key) {
    if (key.startsWith('spellSlot:')) {
      return 'Spell Slot ${key.split(':').last}';
    }
    if (key.startsWith('pactMagicSlot:')) {
      return 'Pact Slot ${key.split(':').last}';
    }
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

    final hostileTarget = _firstHostileTargetIndex(safeActiveIndex, list);
    if (hostileTarget != null) return hostileTarget;
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
  if (key.startsWith('spellSlot:')) {
    return 'Spell Slot ${key.split(':').last}';
  }
  if (key.startsWith('pactMagicSlot:')) {
    return 'Pact Slot ${key.split(':').last}';
  }
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
  final String? activeMultiAttackActionKey;
  final List<_ReactionOption> reactionOptions;
  final _ActionEconomySnapshot activeEconomy;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedCommandTiming;
  final _CombatWorkspace workspace;
  final bool showEnemyHp;
  final List<_CombatLogEntry> entries;
  final Map<String, int> resourcePool;
  final _CombatRollMode rollMode;
  final bool canControlActive;
  final String controlBlockedMessage;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;
  final ValueChanged<int> onEditHp;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final ValueChanged<_CombatWorkspace> onSelectWorkspace;
  final ValueChanged<String> onSelectCommandTiming;
  final ValueChanged<_CombatRollMode> onSelectRollMode;
  final void Function(int actorIndex, _CombatAction action) onUseReaction;
  final ValueChanged<_CombatAction> onReadyAction;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onControlBlocked;

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
    required this.activeMultiAttackActionKey,
    required this.reactionOptions,
    required this.activeEconomy,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedCommandTiming,
    required this.workspace,
    required this.showEnemyHp,
    required this.entries,
    required this.resourcePool,
    required this.rollMode,
    required this.canControlActive,
    required this.controlBlockedMessage,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
    required this.onEditHp,
    required this.onRemoveActiveEffect,
    required this.onSelectWorkspace,
    required this.onSelectCommandTiming,
    required this.onSelectRollMode,
    required this.onUseReaction,
    required this.onReadyAction,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
    required this.onControlBlocked,
  });

  @override
  Widget build(BuildContext context) {
    return _CinematicCombatDesktop(
      round: round,
      combatants: combatants,
      activeIndex: activeIndex,
      targetIndex: targetIndex,
      activeCombatant: activeCombatant,
      selectedTarget: selectedTarget,
      actions: actions,
      rollFeedback: rollFeedback,
      spentTimings: spentTimings,
      pendingDamageActions: pendingDamageActions,
      preparedActions: preparedActions,
      activeMultiAttackActionKey: activeMultiAttackActionKey,
      reactionOptions: reactionOptions,
      activeEconomy: activeEconomy,
      queuedPreparedIndex: queuedPreparedIndex,
      queuedPreparedTotal: queuedPreparedTotal,
      queuedPreparedActionName: queuedPreparedActionName,
      selectedCommandTiming: selectedCommandTiming,
      workspace: workspace,
      showEnemyHp: showEnemyHp,
      entries: entries,
      resourcePool: resourcePool,
      rollMode: rollMode,
      canControlActive: canControlActive,
      controlBlockedMessage: controlBlockedMessage,
      onBack: onBack,
      onRequestInitiative: onRequestInitiative,
      onRollInitiative: onRollInitiative,
      onNextTurn: onNextTurn,
      onToggleDmView: onToggleDmView,
      onRunDemo: onRunDemo,
      onSelectTarget: onSelectTarget,
      onSelectFocusedCombatant: onSelectFocusedCombatant,
      onEditHp: onEditHp,
      onRemoveActiveEffect: onRemoveActiveEffect,
      onSelectWorkspace: onSelectWorkspace,
      onSelectCommandTiming: onSelectCommandTiming,
      onSelectRollMode: onSelectRollMode,
      onUseReaction: onUseReaction,
      onReadyAction: onReadyAction,
      onRollAction: onRollAction,
      onUseAction: onUseAction,
      onPrepareAction: onPrepareAction,
      onLaunchPreparedTurn: onLaunchPreparedTurn,
      onClearPreparedActions: onClearPreparedActions,
      onControlBlocked: onControlBlocked,
    );
  }
}

class _CompactNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _CompactNumberField({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _CombatSetupView extends StatelessWidget {
  final List<_Combatant> combatants;
  final List<SrdMonster> monsterCatalog;
  final int totalMonsterCount;
  final String monsterSearchQuery;
  final String? monsterCatalogError;
  final Map<String, int> stagedMonsterCounts;
  final List<CustomMonster> customMonsters;
  final Map<String, int> stagedCustomMonsterCounts;
  final bool customMonsterLoading;
  final String? customMonsterError;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onReloadCatalog;
  final ValueChanged<String> onMonsterSearchChanged;
  final Future<void> Function(SrdMonster monster, int count)
      onChangeMonsterCount;
  final Future<void> Function(CustomMonster monster, int count)
      onChangeCustomMonsterCount;
  final Future<void> Function() onCreateCustomEnemy;
  final Future<void> Function(CustomMonster monster) onEditCustomEnemy;
  final Future<void> Function(CustomMonster monster) onDeleteCustomEnemy;
  final Future<void> Function(String combatantId) onRemoveCustomEnemy;
  final Future<void> Function() onBeginCombat;

  const _CombatSetupView({
    required this.combatants,
    required this.monsterCatalog,
    required this.totalMonsterCount,
    required this.monsterSearchQuery,
    required this.monsterCatalogError,
    required this.stagedMonsterCounts,
    required this.customMonsters,
    required this.stagedCustomMonsterCounts,
    required this.customMonsterLoading,
    required this.customMonsterError,
    required this.loading,
    required this.onBack,
    required this.onReloadCatalog,
    required this.onMonsterSearchChanged,
    required this.onChangeMonsterCount,
    required this.onChangeCustomMonsterCount,
    required this.onCreateCustomEnemy,
    required this.onEditCustomEnemy,
    required this.onDeleteCustomEnemy,
    required this.onRemoveCustomEnemy,
    required this.onBeginCombat,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final party =
        combatants.where((item) => item.team == _CombatTeam.party).toList();
    final enemies =
        combatants.where((item) => item.team == _CombatTeam.enemy).toList();
    final visibleMonsters = monsterCatalog;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: Stack(
          children: [
            const Positioned.fill(child: _CinematicDungeonBackdrop()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.36),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final compactHeader = constraints.maxWidth < 700;
                    final titleBlock = Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configurar combate',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _CinematicColors.paper,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${party.length} personajes contra ${enemies.length} enemigos preparados',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                    final beginButton = _CinematicConfirmButton(
                      enabled: enemies.isNotEmpty,
                      label: 'Comenzar combate',
                      onTap: () => onBeginCombat(),
                    );
                    final customEnemyButton = _CinematicFooterButton(
                      icon: Icons.add_circle_outline,
                      label: 'Crear enemigo',
                      color: _CinematicColors.goldBright,
                      compact: true,
                      onTap: () => onCreateCustomEnemy(),
                    );
                    final header = compactHeader
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  _CinematicRoundIconButton(
                                    icon: Icons.arrow_back_rounded,
                                    tooltip: 'Volver',
                                    onTap: onBack,
                                  ),
                                  const SizedBox(width: 12),
                                  titleBlock,
                                ],
                              ),
                              const SizedBox(height: 10),
                              customEnemyButton,
                              const SizedBox(height: 8),
                              beginButton,
                            ],
                          )
                        : Row(
                            children: [
                              _CinematicRoundIconButton(
                                icon: Icons.arrow_back_rounded,
                                tooltip: 'Volver',
                                onTap: onBack,
                              ),
                              const SizedBox(width: 12),
                              titleBlock,
                              const SizedBox(width: 12),
                              SizedBox(width: 190, child: customEnemyButton),
                              const SizedBox(width: 10),
                              SizedBox(width: 220, child: beginButton),
                            ],
                          );
                    final catalogPanel = _SetupMonsterCatalogPanel(
                      monsters: visibleMonsters,
                      totalMonsterCount: totalMonsterCount,
                      searchQuery: monsterSearchQuery,
                      errorMessage: monsterCatalogError,
                      stagedMonsterCounts: stagedMonsterCounts,
                      customMonsters: customMonsters,
                      stagedCustomMonsterCounts: stagedCustomMonsterCounts,
                      customMonsterLoading: customMonsterLoading,
                      customMonsterError: customMonsterError,
                      loading: loading,
                      onReload: onReloadCatalog,
                      onSearchChanged: onMonsterSearchChanged,
                      onChangeCount: onChangeMonsterCount,
                      onChangeCustomCount: onChangeCustomMonsterCount,
                      onEditCustomMonster: onEditCustomEnemy,
                      onDeleteCustomMonster: onDeleteCustomEnemy,
                    );

                    return Column(
                      children: [
                        header,
                        const SizedBox(height: 12),
                        Expanded(
                          child: wide
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 290,
                                      child: _SetupPartyPanel(party: party),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: catalogPanel),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 300,
                                      child: _SetupEnemyPreview(
                                        enemies: enemies,
                                        onRemoveCustomEnemy:
                                            onRemoveCustomEnemy,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    SizedBox(
                                      height: 220,
                                      child: _SetupPartyPanel(party: party),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: math
                                          .max(
                                            320.0,
                                            constraints.maxHeight - 260,
                                          )
                                          .clamp(320.0, 520.0)
                                          .toDouble(),
                                      child: catalogPanel,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 240,
                                      child: _SetupEnemyPreview(
                                        enemies: enemies,
                                        onRemoveCustomEnemy:
                                            onRemoveCustomEnemy,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupPartyPanel extends StatelessWidget {
  final List<_Combatant> party;

  const _SetupPartyPanel({
    required this.party,
  });

  @override
  Widget build(BuildContext context) {
    return _CinematicPanelFrame(
      borderColor: _CinematicColors.gold,
      backgroundAlpha: 0.76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SetupPanelTitle(icon: Icons.groups_outlined, label: 'Party'),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: party.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final combatant = party[index];
                return _SetupCombatantRow(combatant: combatant);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupEnemyPreview extends StatelessWidget {
  final List<_Combatant> enemies;
  final Future<void> Function(String combatantId) onRemoveCustomEnemy;

  const _SetupEnemyPreview({
    required this.enemies,
    required this.onRemoveCustomEnemy,
  });

  @override
  Widget build(BuildContext context) {
    return _CinematicPanelFrame(
      borderColor: _CinematicColors.blood,
      backgroundAlpha: 0.76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SetupPanelTitle(
            icon: Icons.crisis_alert_outlined,
            label: 'Enemigos',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: enemies.isEmpty
                ? const Center(
                    child: Text(
                      'Agrega enemigos para comenzar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _CinematicColors.paper,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: enemies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final enemy = enemies[index];
                      final canRemove = enemy.id.startsWith('custom_monster_');
                      return _SetupCombatantRow(
                        combatant: enemy,
                        trailing: canRemove
                            ? IconButton(
                                onPressed: () => onRemoveCustomEnemy(enemy.id),
                                icon: const Icon(Icons.delete_outline),
                                color: _CinematicColors.paper,
                                tooltip: 'Quitar enemigo personalizado',
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SetupMonsterCatalogPanel extends StatelessWidget {
  final List<SrdMonster> monsters;
  final int totalMonsterCount;
  final String searchQuery;
  final String? errorMessage;
  final Map<String, int> stagedMonsterCounts;
  final List<CustomMonster> customMonsters;
  final Map<String, int> stagedCustomMonsterCounts;
  final bool customMonsterLoading;
  final String? customMonsterError;
  final bool loading;
  final VoidCallback onReload;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(SrdMonster monster, int count) onChangeCount;
  final Future<void> Function(CustomMonster monster, int count)
      onChangeCustomCount;
  final Future<void> Function(CustomMonster monster) onEditCustomMonster;
  final Future<void> Function(CustomMonster monster) onDeleteCustomMonster;

  const _SetupMonsterCatalogPanel({
    required this.monsters,
    required this.totalMonsterCount,
    required this.searchQuery,
    required this.errorMessage,
    required this.stagedMonsterCounts,
    required this.customMonsters,
    required this.stagedCustomMonsterCounts,
    required this.customMonsterLoading,
    required this.customMonsterError,
    required this.loading,
    required this.onReload,
    required this.onSearchChanged,
    required this.onChangeCount,
    required this.onChangeCustomCount,
    required this.onEditCustomMonster,
    required this.onDeleteCustomMonster,
  });

  @override
  Widget build(BuildContext context) {
    return _CinematicPanelFrame(
      borderColor: _CinematicColors.gold,
      backgroundAlpha: 0.78,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SetupPanelTitle(
                    icon: Icons.menu_book_outlined,
                    label: 'Bestiario',
                  ),
                ),
                if (loading || customMonsterLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  _CinematicRoundIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Recargar',
                    onTap: onReload,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TabBar(
              indicatorColor: _CinematicColors.goldBright,
              labelColor: _CinematicColors.paper,
              unselectedLabelColor: _CinematicColors.actionTextMuted,
              tabs: [
                Tab(text: 'SRD ($totalMonsterCount)'),
                Tab(text: 'Custom (${customMonsters.length})'),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      _SetupMonsterSearchField(
                        query: searchQuery,
                        onChanged: onSearchChanged,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: errorMessage != null
                            ? _SetupMonsterError(
                                message: errorMessage!,
                                onReload: onReload,
                              )
                            : monsters.isEmpty
                                ? _SetupMonsterEmptyState(loading: loading)
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 230,
                                      mainAxisExtent: 104,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: monsters.length,
                                    itemBuilder: (context, index) {
                                      final monster = monsters[index];
                                      final count =
                                          stagedMonsterCounts[monster.index] ??
                                              0;
                                      return _SetupMonsterTile(
                                        monster: monster,
                                        count: count,
                                        onChangeCount: (next) =>
                                            onChangeCount(monster, next),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                  customMonsterError != null
                      ? _SetupMonsterError(
                          message: customMonsterError!,
                          onReload: () {},
                        )
                      : customMonsters.isEmpty
                          ? const _SetupCustomMonsterEmptyState()
                          : ListView.separated(
                              itemCount: customMonsters.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final monster = customMonsters[index];
                                final count =
                                    stagedCustomMonsterCounts[monster.id] ?? 0;
                                return _SetupCustomMonsterTile(
                                  monster: monster,
                                  count: count,
                                  onChangeCount: (next) =>
                                      onChangeCustomCount(monster, next),
                                  onEdit: () => onEditCustomMonster(monster),
                                  onDelete: () =>
                                      onDeleteCustomMonster(monster),
                                );
                              },
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

class _SetupMonsterSearchField extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;

  const _SetupMonsterSearchField({
    required this.query,
    required this.onChanged,
  });

  @override
  State<_SetupMonsterSearchField> createState() =>
      _SetupMonsterSearchFieldState();
}

class _SetupMonsterSearchFieldState extends State<_SetupMonsterSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _SetupMonsterSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: const TextStyle(
        color: _CinematicColors.paper,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar por nombre, tipo o CR',
        hintStyle: TextStyle(color: tokens.textMuted),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: _CinematicColors.goldBright,
          size: 18,
        ),
        suffixIcon: widget.query.trim().isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: _CinematicColors.paper,
                onPressed: () => widget.onChanged(''),
              ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: _CinematicColors.gold.withValues(alpha: 0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: _CinematicColors.gold.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _CinematicColors.goldBright),
        ),
      ),
    );
  }
}

class _SetupMonsterEmptyState extends StatelessWidget {
  final bool loading;

  const _SetupMonsterEmptyState({
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        loading ? 'Cargando monstruos...' : 'No hay monstruos para mostrar.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _CinematicColors.paper,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SetupMonsterError extends StatelessWidget {
  final String message;
  final VoidCallback onReload;

  const _SetupMonsterError({
    required this.message,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: _CinematicColors.goldBright,
              size: 34,
            ),
            const SizedBox(height: 10),
            const Text(
              'No se pudo cargar el bestiario.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _CinematicColors.paper,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _CinematicColors.actionTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _CinematicFooterButton(
              icon: Icons.refresh_rounded,
              label: 'Reintentar',
              color: _CinematicColors.goldBright,
              onTap: onReload,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupPanelTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SetupPanelTitle({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _CinematicColors.goldBright, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _CinematicColors.paper,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupCombatantRow extends StatelessWidget {
  final _Combatant combatant;
  final Widget? trailing;

  const _SetupCombatantRow({
    required this.combatant,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(combatant.team, tokens);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: _CinematicPortraitBox(
              combatant: combatant,
              color: accent,
              iconSize: 18,
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
                    color: _CinematicColors.paper,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'HP ${combatant.hp}/${combatant.maxHp}  CA ${combatant.ac}',
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
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _SetupMonsterTile extends StatelessWidget {
  final SrdMonster monster;
  final int count;
  final ValueChanged<int> onChangeCount;

  const _SetupMonsterTile({
    required this.monster,
    required this.count,
    required this.onChangeCount,
  });

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selected
            ? _CinematicColors.blood.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected
              ? _CinematicColors.goldBright.withValues(alpha: 0.44)
              : _CinematicColors.gold.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monster.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _CinematicColors.paper,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${monster.size} ${monster.type}${monster.challengeRating == null ? '' : ' - CR ${monster.challengeRating}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _CinematicColors.actionTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _SetupCountButton(
                icon: Icons.remove,
                onTap: () => onChangeCount(count - 1),
              ),
              Expanded(
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _CinematicColors.paper,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              _SetupCountButton(
                icon: Icons.add,
                onTap: () => onChangeCount(count + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupCustomMonsterEmptyState extends StatelessWidget {
  const _SetupCustomMonsterEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'Tu bestiario personalizado esta vacio. Usa Crear enemigo para guardar una plantilla con acciones, reacciones, multiattack y rasgos pasivos.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _CinematicColors.paper,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _SetupCustomMonsterTile extends StatelessWidget {
  final CustomMonster monster;
  final int count;
  final ValueChanged<int> onChangeCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SetupCustomMonsterTile({
    required this.monster,
    required this.count,
    required this.onChangeCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final selected = count > 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected
            ? _CinematicColors.blood.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected
              ? _CinematicColors.goldBright.withValues(alpha: 0.44)
              : _CinematicColors.gold.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: monster.portraitPath == null
                  ? Container(
                      color: _CinematicColors.blood.withValues(alpha: 0.18),
                      child: const Icon(
                        Icons.crisis_alert_outlined,
                        color: _CinematicColors.paper,
                      ),
                    )
                  : buildImageFromPath(
                      monster.portraitPath!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monster.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _CinematicColors.paper,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  monster.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniSetupBadge(label: 'HP ${monster.hitPoints}'),
                    _MiniSetupBadge(label: 'CA ${monster.armorClass}'),
                    _MiniSetupBadge(label: '${monster.activeActionCount} act'),
                    if (monster.passiveCount > 0)
                      _MiniSetupBadge(label: '${monster.passiveCount} pas'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Row(
              children: [
                _SetupCountButton(
                  icon: Icons.remove,
                  onTap: () => onChangeCount(count - 1),
                ),
                Expanded(
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _CinematicColors.paper,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _SetupCountButton(
                  icon: Icons.add,
                  onTap: () => onChangeCount(count + 1),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar plantilla',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: _CinematicColors.paper,
          ),
          IconButton(
            tooltip: 'Eliminar plantilla',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: _CinematicColors.paper,
          ),
        ],
      ),
    );
  }
}

class _MiniSetupBadge extends StatelessWidget {
  final String label;

  const _MiniSetupBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _CinematicColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: _CinematicColors.gold.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _CinematicColors.paper,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SetupCountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SetupCountButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 30,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _CinematicColors.gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: _CinematicColors.gold.withValues(alpha: 0.28),
          ),
        ),
        child: Icon(icon, color: _CinematicColors.paper, size: 16),
      ),
    );
  }
}

class _CinematicCombatDesktop extends StatelessWidget {
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
  final String? activeMultiAttackActionKey;
  final List<_ReactionOption> reactionOptions;
  final _ActionEconomySnapshot activeEconomy;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedCommandTiming;
  final _CombatWorkspace workspace;
  final bool showEnemyHp;
  final List<_CombatLogEntry> entries;
  final Map<String, int> resourcePool;
  final _CombatRollMode rollMode;
  final bool canControlActive;
  final String controlBlockedMessage;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;
  final ValueChanged<int> onEditHp;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final ValueChanged<_CombatWorkspace> onSelectWorkspace;
  final ValueChanged<String> onSelectCommandTiming;
  final ValueChanged<_CombatRollMode> onSelectRollMode;
  final void Function(int actorIndex, _CombatAction action) onUseReaction;
  final ValueChanged<_CombatAction> onReadyAction;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onControlBlocked;

  const _CinematicCombatDesktop({
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
    required this.activeMultiAttackActionKey,
    required this.reactionOptions,
    required this.activeEconomy,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedCommandTiming,
    required this.workspace,
    required this.showEnemyHp,
    required this.entries,
    required this.resourcePool,
    required this.rollMode,
    required this.canControlActive,
    required this.controlBlockedMessage,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
    required this.onEditHp,
    required this.onRemoveActiveEffect,
    required this.onSelectWorkspace,
    required this.onSelectCommandTiming,
    required this.onSelectRollMode,
    required this.onUseReaction,
    required this.onReadyAction,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
    required this.onControlBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final enemies = _indexedTeam(combatants, _CombatTeam.enemy);
    final party = _indexedTeam(combatants, _CombatTeam.party);
    final aliveEnemies = enemies
        .where((entry) => entry.combatant.hp > 0)
        .map((entry) => entry.combatant.name)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1240;
          final bottomHeight = math.min(
            compact ? 278.0 : 296.0,
            math.max(compact ? 238.0 : 264.0, constraints.maxHeight * 0.36),
          );
          final stageInsets = EdgeInsets.fromLTRB(
            12,
            92,
            12,
            bottomHeight + 18,
          );

          return ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: Stack(
              children: [
                const Positioned.fill(child: _CinematicDungeonBackdrop()),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: _CinematicTacticalCenterLayer(
                      combatants: combatants,
                      party: party,
                      enemies: enemies,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      rollFeedback: rollFeedback,
                      showEnemyHp: showEnemyHp,
                      insets: stageInsets,
                      onEditHp: onEditHp,
                      onRemoveActiveEffect: onRemoveActiveEffect,
                      onSelectTarget: onSelectTarget,
                      onSelectFocusedCombatant: onSelectFocusedCombatant,
                    ),
                  ),
                ),
                if (rollFeedback != null)
                  Positioned(
                    left: 24,
                    right: 24,
                    top: 94,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _CinematicRollToast(feedback: rollFeedback!),
                    ),
                  ),
                Positioned(
                  left: 10,
                  top: 14,
                  width: compact ? 292 : 328,
                  height: 62,
                  child: _CinematicTurnHeaderPanel(
                    round: round,
                    activeCombatant: activeCombatant,
                    economy: activeEconomy,
                    showEnemyHp: showEnemyHp,
                    onBack: onBack,
                    onNextTurn: onNextTurn,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: compact ? 316 : 352,
                  right: 390,
                  height: 68,
                  child: _CinematicObjectiveBanner(
                    aliveEnemies: aliveEnemies,
                    selectedTarget: selectedTarget,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 14,
                  width: 368,
                  height: 58,
                  child: _CinematicToolbar(
                    workspace: workspace,
                    showEnemyHp: showEnemyHp,
                    onRequestInitiative: onRequestInitiative,
                    onRollInitiative: onRollInitiative,
                    onToggleDmView: onToggleDmView,
                    onRunDemo: onRunDemo,
                    onSelectWorkspace: onSelectWorkspace,
                  ),
                ),
                if (workspace != _CombatWorkspace.turn)
                  Positioned(
                    left: 18,
                    right: 18,
                    top: 96,
                    bottom: bottomHeight + 28,
                    child: _CinematicWorkspaceOverlay(
                      workspace: workspace,
                      combatants: combatants,
                      activeIndex: activeIndex,
                      targetIndex: targetIndex,
                      showEnemyHp: showEnemyHp,
                      entries: entries,
                      rollFeedback: rollFeedback,
                    ),
                  ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  height: bottomHeight,
                  child: _CinematicActionDeck(
                    activeCombatant: activeCombatant,
                    selectedTarget: selectedTarget,
                    actions: actions,
                    spentTimings: spentTimings,
                    pendingDamageActions: pendingDamageActions,
                    preparedActions: preparedActions,
                    activeMultiAttackActionKey: activeMultiAttackActionKey,
                    reactionOptions: reactionOptions,
                    queuedPreparedIndex: queuedPreparedIndex,
                    queuedPreparedTotal: queuedPreparedTotal,
                    queuedPreparedActionName: queuedPreparedActionName,
                    selectedTiming: selectedCommandTiming,
                    resourcePool: resourcePool,
                    rollMode: rollMode,
                    canControlActive: canControlActive,
                    controlBlockedMessage: controlBlockedMessage,
                    onSelectTiming: onSelectCommandTiming,
                    onSelectRollMode: onSelectRollMode,
                    onUseReaction: onUseReaction,
                    onReadyAction: onReadyAction,
                    onRollAction: onRollAction,
                    onUseAction: onUseAction,
                    onPrepareAction: onPrepareAction,
                    onLaunchPreparedTurn: onLaunchPreparedTurn,
                    onClearPreparedActions: onClearPreparedActions,
                    onControlBlocked: onControlBlocked,
                    onNextTurn: onNextTurn,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CinematicDungeonBackdrop extends StatelessWidget {
  const _CinematicDungeonBackdrop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (size.width * pixelRatio).clamp(1280.0, 2200.0).round();

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/combat/dungeon_battlefield.png',
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const _CombatArenaBackdrop(round: 1),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.82),
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.78),
              ],
              stops: const [0, 0.28, 0.68, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.48),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.72),
              ],
              stops: const [0, 0.42, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _CinematicTurnHeaderPanel extends StatelessWidget {
  final int round;
  final _Combatant activeCombatant;
  final _ActionEconomySnapshot economy;
  final bool showEnemyHp;
  final VoidCallback onBack;
  final VoidCallback onNextTurn;

  const _CinematicTurnHeaderPanel({
    required this.round,
    required this.activeCombatant,
    required this.economy,
    required this.showEnemyHp,
    required this.onBack,
    required this.onNextTurn,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(activeCombatant.team, tokens);

    return _CinematicPanelFrame(
      borderColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      backgroundAlpha: 0.74,
      child: Row(
        children: [
          _CinematicRoundIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Volver',
            onTap: onBack,
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Text(
              '$round',
              style: const TextStyle(
                color: _CinematicColors.paper,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeCombatant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _CinematicColors.paper,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _CinematicEconomyDot(
                      icon: Icons.flash_on,
                      spent: economy.actionSpent,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    _CinematicEconomyDot(
                      icon: Icons.control_point_duplicate,
                      spent: economy.bonusActionSpent,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    _CinematicEconomyDot(
                      icon: Icons.reply_rounded,
                      spent: economy.reactionSpent,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _compactHpLabel(activeCombatant, showEnemyHp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _CinematicRoundIconButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Siguiente turno',
            onTap: onNextTurn,
          ),
        ],
      ),
    );
  }
}

class _CinematicEconomyDot extends StatelessWidget {
  final IconData icon;
  final bool spent;
  final Color color;

  const _CinematicEconomyDot({
    required this.icon,
    required this.spent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: spent ? 'Usado' : 'Disponible',
      child: Icon(
        icon,
        color: spent ? _CinematicColors.blood : color.withValues(alpha: 0.92),
        size: 13,
      ),
    );
  }
}

class _CinematicInitiativePanel extends StatelessWidget {
  final int round;
  final List<_Combatant> combatants;
  final int activeIndex;
  final bool showEnemyHp;
  final ValueChanged<int> onSelectCombatant;
  final ValueChanged<int> onEditHp;
  final VoidCallback onBack;

  const _CinematicInitiativePanel({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.showEnemyHp,
    required this.onSelectCombatant,
    required this.onEditHp,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return _CinematicPanelFrame(
      borderColor: _CinematicColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turno $round',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _CinematicColors.paper,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Iniciativa',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _CinematicRoundIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Volver',
                onTap: onBack,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: combatants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final combatant = combatants[index];
                return _CinematicInitiativeTile(
                  combatant: combatant,
                  selected: index == activeIndex,
                  showEnemyHp: showEnemyHp,
                  editableHp: showEnemyHp,
                  onEditHp: () => onEditHp(index),
                  onTap: () => onSelectCombatant(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CinematicInitiativeTile extends StatelessWidget {
  final _Combatant combatant;
  final bool selected;
  final bool showEnemyHp;
  final bool editableHp;
  final VoidCallback onEditHp;
  final VoidCallback onTap;

  const _CinematicInitiativeTile({
    required this.combatant,
    required this.selected,
    required this.showEnemyHp,
    required this.editableHp,
    required this.onEditHp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = selected
        ? _CinematicColors.goldBright
        : _teamColor(combatant.team, tokens);
    final showHp = _canShowHp(combatant, showEnemyHp);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: editableHp ? 90 : 78,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: selected ? 0.48 : 0.28),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: accent.withValues(alpha: selected ? 0.88 : 0.22),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: accent.withValues(alpha: 0.26),
                blurRadius: 14,
              ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: editableHp ? 78 : 66,
              child: _CinematicPortraitBox(
                combatant: combatant,
                color: accent,
                iconSize: 22,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                            color: _CinematicColors.paper,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _CinematicTinyPill(
                        label: 'CA ${combatant.ac}',
                        color: accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    combatant.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _CinematicHpBar(
                    combatant: combatant,
                    showHp: showHp,
                    height: editableHp ? 22 : 14,
                    onTap: editableHp ? onEditHp : null,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.play_arrow_rounded,
                color: accent,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _CinematicTinyPill extends StatelessWidget {
  final String label;
  final Color color;

  const _CinematicTinyPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _CinematicColors.paper,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _CinematicObjectiveBanner extends StatelessWidget {
  final List<String> aliveEnemies;
  final _Combatant selectedTarget;

  const _CinematicObjectiveBanner({
    required this.aliveEnemies,
    required this.selectedTarget,
  });

  @override
  Widget build(BuildContext context) {
    final targetName = selectedTarget.name;
    final objective = aliveEnemies.isEmpty
        ? 'Victoria asegurada'
        : aliveEnemies.length == 1
            ? 'Derrota a ${aliveEnemies.first}'
            : 'Derrota a los enemigos';

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: _CinematicColors.gold.withValues(alpha: 0.36),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              aliveEnemies.isEmpty
                  ? Icons.verified_outlined
                  : Icons.dangerous_outlined,
              color: _CinematicColors.paper,
              size: 24,
            ),
            const SizedBox(width: 11),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Objetivo actual: $targetName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _CinematicColors.paper.withValues(alpha: 0.58),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    objective,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _CinematicColors.paper,
                      fontSize: 20,
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

class _CinematicToolbar extends StatelessWidget {
  final _CombatWorkspace workspace;
  final bool showEnemyHp;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<_CombatWorkspace> onSelectWorkspace;

  const _CinematicToolbar({
    required this.workspace,
    required this.showEnemyHp,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    return _CinematicPanelFrame(
      padding: const EdgeInsets.all(4),
      borderColor: _CinematicColors.gold,
      child: Row(
        children: [
          _CinematicToolbarButton(
            icon: Icons.grid_view_outlined,
            tooltip: 'Turno',
            selected: workspace == _CombatWorkspace.turn,
            onTap: () => onSelectWorkspace(_CombatWorkspace.turn),
          ),
          _CinematicToolbarButton(
            icon: Icons.receipt_long_outlined,
            tooltip: 'Log',
            selected: workspace == _CombatWorkspace.log,
            onTap: () => onSelectWorkspace(_CombatWorkspace.log),
          ),
          _CinematicToolbarButton(
            icon: Icons.groups_2_outlined,
            tooltip: 'Resumen',
            selected: workspace == _CombatWorkspace.overview,
            onTap: () => onSelectWorkspace(_CombatWorkspace.overview),
          ),
          _CinematicToolbarButton(
            icon: showEnemyHp
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            tooltip: showEnemyHp ? 'Vista DM' : 'Vista jugador',
            onTap: onToggleDmView,
          ),
          _CinematicToolbarButton(
            icon: Icons.campaign_outlined,
            tooltip: 'Pedir iniciativa',
            onTap: onRequestInitiative,
          ),
          _CinematicToolbarButton(
            icon: Icons.casino_outlined,
            tooltip: 'Tirar iniciativa',
            onTap: onRollInitiative,
          ),
          _CinematicToolbarButton(
            icon: Icons.play_circle_outline,
            tooltip: 'Demo',
            onTap: onRunDemo,
          ),
        ],
      ),
    );
  }
}

class _CinematicToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  const _CinematicToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? _CinematicColors.goldBright
        : _CinematicColors.paper.withValues(alpha: 0.72);

    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected
                  ? _CinematicColors.gold.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.42 : 0.13),
              ),
            ),
            child: Center(
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _CinematicTacticalCenterLayer extends StatelessWidget {
  final List<_Combatant> combatants;
  final List<_IndexedCombatant> party;
  final List<_IndexedCombatant> enemies;
  final int activeIndex;
  final int targetIndex;
  final _CombatRollFeedback? rollFeedback;
  final bool showEnemyHp;
  final EdgeInsets insets;
  final ValueChanged<int> onEditHp;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;

  const _CinematicTacticalCenterLayer({
    required this.combatants,
    required this.party,
    required this.enemies,
    required this.activeIndex,
    required this.targetIndex,
    required this.rollFeedback,
    required this.showEnemyHp,
    required this.insets,
    required this.onEditHp,
    required this.onRemoveActiveEffect,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
  });

  @override
  Widget build(BuildContext context) {
    if (combatants.isEmpty) return const SizedBox.shrink();

    final safeActiveIndex = activeIndex.clamp(0, combatants.length - 1).toInt();
    final safeTargetIndex = targetIndex.clamp(0, combatants.length - 1).toInt();
    final activeCombatant = combatants[safeActiveIndex];
    final selectedTarget = combatants[safeTargetIndex];

    return Padding(
      padding: insets,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight =
              constraints.maxWidth < 690 || constraints.maxHeight < 270;
          final engagement = _CinematicEngagementPanel(
            activeCombatant: activeCombatant,
            selectedTarget: selectedTarget,
            rollFeedback: rollFeedback,
            showEnemyHp: showEnemyHp,
          );
          final allies = _CinematicBattleTeamColumn(
            title: 'Aliados',
            subtitle: 'orden de iniciativa',
            icon: Icons.groups_2_outlined,
            entries: _initiativeSortedBattleEntries(
              party,
              activeIndex: safeActiveIndex,
              targetIndex: safeTargetIndex,
            ),
            activeIndex: safeActiveIndex,
            targetIndex: safeTargetIndex,
            activeTeam: activeCombatant.team,
            showEnemyHp: showEnemyHp,
            onEditHp: onEditHp,
            onRemoveActiveEffect: onRemoveActiveEffect,
            onSelectTarget: onSelectTarget,
            onSelectFocusedCombatant: onSelectFocusedCombatant,
          );
          final foes = _CinematicBattleTeamColumn(
            title: 'Enemigos',
            subtitle: 'orden de iniciativa',
            icon: Icons.crisis_alert_outlined,
            entries: _initiativeSortedBattleEntries(
              enemies,
              activeIndex: safeActiveIndex,
              targetIndex: safeTargetIndex,
            ),
            activeIndex: safeActiveIndex,
            targetIndex: safeTargetIndex,
            activeTeam: activeCombatant.team,
            showEnemyHp: showEnemyHp,
            onEditHp: onEditHp,
            onRemoveActiveEffect: onRemoveActiveEffect,
            onSelectTarget: onSelectTarget,
            onSelectFocusedCombatant: onSelectFocusedCombatant,
          );

          if (tight) {
            return Column(
              children: [
                Expanded(flex: 5, child: engagement),
                const SizedBox(height: 8),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Expanded(child: allies),
                      const SizedBox(width: 8),
                      Expanded(child: foes),
                    ],
                  ),
                ),
              ],
            );
          }

          final engagementWidth =
              math.min(540.0, math.max(360.0, constraints.maxWidth * 0.44));
          return Row(
            children: [
              Expanded(child: allies),
              const SizedBox(width: 12),
              SizedBox(width: engagementWidth, child: engagement),
              const SizedBox(width: 12),
              Expanded(child: foes),
            ],
          );
        },
      ),
    );
  }
}

List<_IndexedCombatant> _initiativeSortedBattleEntries(
  List<_IndexedCombatant> entries, {
  required int activeIndex,
  required int targetIndex,
}) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    final initiativeCompare =
        b.combatant.initiative.compareTo(a.combatant.initiative);
    if (initiativeCompare != 0) return initiativeCompare;
    if (a.index == activeIndex) return -1;
    if (b.index == activeIndex) return 1;
    if (a.index == targetIndex) return -1;
    if (b.index == targetIndex) return 1;
    return a.index.compareTo(b.index);
  });
  return sorted;
}

class _CinematicBattleTeamColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_IndexedCombatant> entries;
  final int activeIndex;
  final int targetIndex;
  final _CombatTeam activeTeam;
  final bool showEnemyHp;
  final ValueChanged<int> onEditHp;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;

  const _CinematicBattleTeamColumn({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entries,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeTeam,
    required this.showEnemyHp,
    required this.onEditHp,
    required this.onRemoveActiveEffect,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final partyColumn = entries.any(
      (entry) => entry.combatant.team == _CombatTeam.party,
    );
    final accent = partyColumn ? tokens.accentRead : tokens.accentAction;
    final aliveCount = entries.where((entry) => entry.combatant.hp > 0).length;

    return _CinematicPanelFrame(
      borderColor: accent,
      padding: const EdgeInsets.all(10),
      backgroundAlpha: 0.42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _CinematicColors.paper,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
              _CinematicTinyPill(
                label: '$aliveCount/${entries.length}',
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'Sin combatientes',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final targetable = entry.index != activeIndex &&
                          entry.combatant.team != activeTeam &&
                          entry.combatant.hp > 0;
                      return _CinematicBattleRosterCard(
                        entry: entry,
                        active: entry.index == activeIndex,
                        targeted: entry.index == targetIndex,
                        targetable: targetable,
                        showEnemyHp: showEnemyHp,
                        onEditHp: () => onEditHp(entry.index),
                        onRemoveActiveEffect: onRemoveActiveEffect,
                        onTap: () {
                          if (targetable) {
                            onSelectTarget(entry.index);
                          } else {
                            onSelectFocusedCombatant(entry.index);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CinematicBattleRosterCard extends StatelessWidget {
  final _IndexedCombatant entry;
  final bool active;
  final bool targeted;
  final bool targetable;
  final bool showEnemyHp;
  final VoidCallback onEditHp;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final VoidCallback onTap;

  const _CinematicBattleRosterCard({
    required this.entry,
    required this.active,
    required this.targeted,
    required this.targetable,
    required this.showEnemyHp,
    required this.onEditHp,
    required this.onRemoveActiveEffect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final combatant = entry.combatant;
    final down = combatant.hp <= 0;
    final baseAccent = _teamColor(combatant.team, tokens);
    final accent = targeted
        ? _CinematicColors.goldBright
        : active
            ? tokens.accentInfo
            : baseAccent;
    final showHp = _canShowHp(combatant, showEnemyHp);
    final activeLabels = combatant.conditions
        .where((label) => label != 'Player Character')
        .toList(growable: false);

    return Tooltip(
      message: targetable
          ? 'Elegir ${combatant.name} como objetivo'
          : active
              ? '${combatant.name} tiene el turno'
              : 'Ver ${combatant.name}',
      child: InkWell(
        onTap: down ? null : onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accent.withValues(
              alpha: active || targeted ? 0.20 : 0.09,
            ),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(
              color: accent.withValues(alpha: active || targeted ? 0.58 : 0.22),
            ),
          ),
          child: Opacity(
            opacity: down ? 0.55 : 1,
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 50,
                  child: _CinematicPortraitBox(
                    combatant: combatant,
                    color: accent,
                    iconSize: 19,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                                color: _CinematicColors.paper,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                          if (active || targeted || targetable) ...[
                            const SizedBox(width: 5),
                            Icon(
                              active
                                  ? Icons.play_arrow_rounded
                                  : targeted
                                      ? Icons.my_location
                                      : Icons.ads_click_outlined,
                              color: accent,
                              size: 15,
                            ),
                          ],
                          const SizedBox(width: 5),
                          _CinematicTinyPill(
                            label: '${combatant.initiative}',
                            color: accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _CinematicHpBar(
                        combatant: combatant,
                        showHp: showHp,
                        height: 12,
                        onTap: showEnemyHp ? onEditHp : null,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'CA ${combatant.ac}',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              combatant.role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (activeLabels.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onLongPress: showEnemyHp
                                  ? () => onRemoveActiveEffect(
                                        combatant.id,
                                        activeLabels.first,
                                      )
                                  : null,
                              borderRadius:
                                  BorderRadius.circular(tokens.radiusPill),
                              child: _CinematicTinyPill(
                                label: activeLabels.first,
                                color: _statusAccentForLabel(
                                  activeLabels.first,
                                  tokens,
                                  accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CinematicEngagementPanel extends StatelessWidget {
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final _CombatRollFeedback? rollFeedback;
  final bool showEnemyHp;

  const _CinematicEngagementPanel({
    required this.activeCombatant,
    required this.selectedTarget,
    required this.rollFeedback,
    required this.showEnemyHp,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final actorColor = _teamColor(activeCombatant.team, tokens);
    final targetColor = _teamColor(selectedTarget.team, tokens);
    final feedbackAccent = rollFeedback == null
        ? _CinematicColors.goldBright
        : _accentForKind(rollFeedback!.accentKind, tokens);
    final result = rollFeedback?.result;

    return _CinematicPanelFrame(
      borderColor: feedbackAccent,
      padding: const EdgeInsets.all(12),
      backgroundAlpha: 0.48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 300;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DiceTheaterImpactPainter(
                    accent: feedbackAccent,
                    actorColor: actorColor,
                    targetColor: targetColor,
                    active: rollFeedback != null,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.compare_arrows_rounded,
                          color: feedbackAccent, size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'INTERCAMBIO ACTUAL',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _EngagementCombatantPlate(
                            combatant: activeCombatant,
                            label: 'TURNO',
                            color: actorColor,
                            showEnemyHp: showEnemyHp,
                            compact: compact,
                          ),
                        ),
                        SizedBox(
                          width: compact ? 82 : 100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _LargeDiceBadge(
                                total: result?.total,
                                formula: result?.formula,
                                color: feedbackAccent,
                                compact: true,
                                sides: result?.sides,
                              ),
                              const SizedBox(height: 6),
                              Icon(Icons.arrow_forward_rounded,
                                  color: feedbackAccent, size: 22),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _EngagementCombatantPlate(
                            combatant: selectedTarget,
                            label: 'OBJETIVO',
                            color: targetColor,
                            showEnemyHp: showEnemyHp,
                            compact: compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: feedbackAccent.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      rollFeedback == null
                          ? '${activeCombatant.name} apunta a ${selectedTarget.name}.'
                          : '${rollFeedback!.headline}: ${rollFeedback!.subline ?? rollFeedback!.action}',
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _CinematicColors.paper,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
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

class _EngagementCombatantPlate extends StatelessWidget {
  final _Combatant combatant;
  final String label;
  final Color color;
  final bool showEnemyHp;
  final bool compact;

  const _EngagementCombatantPlate({
    required this.combatant,
    required this.label,
    required this.color,
    required this.showEnemyHp,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final showHp = _canShowHp(combatant, showEnemyHp);

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CombatantArtwork(
                  combatant: combatant,
                  color: color,
                  iconSize: compact ? 34 : 42,
                ),
                Positioned(
                  left: 7,
                  top: 7,
                  child: _CinematicTinyPill(label: label, color: color),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: compact ? 6 : 8,
            ),
            color: Colors.black.withValues(alpha: 0.42),
            child: Column(
              children: [
                Text(
                  combatant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _CinematicColors.paper,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                _CinematicHpBar(
                  combatant: combatant,
                  showHp: showHp,
                  height: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CinematicBattlefieldLayer extends StatelessWidget {
  final List<_Combatant> combatants;
  final List<_IndexedCombatant> party;
  final List<_IndexedCombatant> enemies;
  final int activeIndex;
  final int targetIndex;
  final bool showEnemyHp;
  final EdgeInsets insets;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;

  const _CinematicBattlefieldLayer({
    required this.combatants,
    required this.party,
    required this.enemies,
    required this.activeIndex,
    required this.targetIndex,
    required this.showEnemyHp,
    required this.insets,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final activeTeam = combatants.isEmpty
        ? _CombatTeam.party
        : combatants[activeIndex.clamp(0, combatants.length - 1).toInt()].team;

    void handleTokenTap(_IndexedCombatant entry) {
      if (entry.index == activeIndex || entry.combatant.team == activeTeam) {
        onSelectFocusedCombatant(entry.index);
        return;
      }
      onSelectTarget(entry.index);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final arenaLeft = insets.left;
        final arenaTop = insets.top;
        final arenaWidth = math.max(
          260.0,
          constraints.maxWidth - insets.left - insets.right,
        );
        final arenaHeight = math.max(
          240.0,
          constraints.maxHeight - insets.top - insets.bottom,
        );

        Offset point(double x, double y) {
          return Offset(arenaLeft + arenaWidth * x, arenaTop + arenaHeight * y);
        }

        const partyPoints = [
          Offset(0.24, 0.46),
          Offset(0.13, 0.62),
          Offset(0.36, 0.68),
          Offset(0.18, 0.36),
          Offset(0.32, 0.30),
        ];
        const enemyPoints = [
          Offset(0.68, 0.50),
          Offset(0.83, 0.59),
          Offset(0.78, 0.36),
          Offset(0.62, 0.68),
          Offset(0.90, 0.42),
        ];
        final visibleParty = party.take(partyPoints.length).toList();
        final visibleEnemies = enemies.take(enemyPoints.length).toList();
        final hiddenPartyCount = party.length - visibleParty.length;
        final hiddenEnemyCount = enemies.length - visibleEnemies.length;

        return Stack(
          children: [
            Positioned(
              left: arenaLeft + arenaWidth * 0.04,
              right: insets.right + arenaWidth * 0.04,
              bottom: insets.bottom - 8,
              height: 110,
              child: CustomPaint(
                painter: _CinematicArenaFloorPainter(
                  partyColor: tokens.accentRead,
                  enemyColor: tokens.accentAction,
                ),
              ),
            ),
            for (var i = 0; i < visibleParty.length; i++)
              _BattlefieldTokenPositioned(
                point: point(
                  partyPoints[i % partyPoints.length].dx,
                  partyPoints[i % partyPoints.length].dy,
                ),
                child: _CinematicBattleToken(
                  entry: visibleParty[i],
                  active: visibleParty[i].index == activeIndex,
                  targeted: visibleParty[i].index == targetIndex,
                  showEnemyHp: showEnemyHp,
                  onTap: () => handleTokenTap(visibleParty[i]),
                ),
              ),
            if (hiddenPartyCount > 0)
              _BattlefieldTokenPositioned(
                point: point(0.08, 0.78),
                child: _CinematicCrowdBadge(
                  label: '+$hiddenPartyCount allies',
                  color: tokens.accentRead,
                ),
              ),
            for (var i = 0; i < visibleEnemies.length; i++)
              _BattlefieldTokenPositioned(
                point: point(
                  enemyPoints[i % enemyPoints.length].dx,
                  enemyPoints[i % enemyPoints.length].dy,
                ),
                child: _CinematicBattleToken(
                  entry: visibleEnemies[i],
                  active: visibleEnemies[i].index == activeIndex,
                  targeted: visibleEnemies[i].index == targetIndex,
                  showEnemyHp: showEnemyHp,
                  onTap: () => handleTokenTap(visibleEnemies[i]),
                ),
              ),
            if (hiddenEnemyCount > 0)
              _BattlefieldTokenPositioned(
                point: point(0.94, 0.76),
                child: _CinematicCrowdBadge(
                  label: '+$hiddenEnemyCount foes',
                  color: tokens.accentAction,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BattlefieldTokenPositioned extends StatelessWidget {
  final Offset point;
  final Widget child;

  const _BattlefieldTokenPositioned({
    required this.point,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: point.dx - 54,
      top: point.dy - 86,
      width: 108,
      height: 172,
      child: child,
    );
  }
}

class _CinematicCrowdBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CinematicCrowdBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 104),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.42)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _CinematicColors.paper,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _CinematicBattleToken extends StatelessWidget {
  final _IndexedCombatant entry;
  final bool active;
  final bool targeted;
  final bool showEnemyHp;
  final VoidCallback onTap;

  const _CinematicBattleToken({
    required this.entry,
    required this.active,
    required this.targeted,
    required this.showEnemyHp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final combatant = entry.combatant;
    final color = targeted
        ? _CinematicColors.goldBright
        : active
            ? tokens.accentInfo
            : _teamColor(combatant.team, tokens);
    final down = combatant.hp <= 0;

    return Tooltip(
      message: '${combatant.name} - AC ${combatant.ac}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: down ? 0.55 : 1,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 10,
                right: 10,
                bottom: 4,
                height: 30,
                child: CustomPaint(
                  painter: _CinematicTargetRingPainter(
                    color: color,
                    active: active || targeted,
                    enemy: combatant.team == _CombatTeam.enemy,
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: active ? 0 : 14,
                bottom: 42,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: color.withValues(
                          alpha: active || targeted ? 0.72 : 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(
                            alpha: active || targeted ? 0.32 : 0.12),
                        blurRadius: active || targeted ? 22 : 12,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _CombatantArtwork(
                      combatant: combatant,
                      color: color,
                      iconSize: active ? 42 : 34,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 26,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 104),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: color.withValues(alpha: 0.36)),
                    ),
                    child: Text(
                      combatant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _CinematicColors.paper,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              if (active || targeted)
                Positioned(
                  top: active ? 0 : 12,
                  right: 8,
                  child: Icon(
                    active ? Icons.play_arrow_rounded : Icons.my_location,
                    color: color,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CinematicEnemyRail extends StatelessWidget {
  final String title;
  final List<_IndexedCombatant> targets;
  final int activeIndex;
  final int targetIndex;
  final bool showEnemyHp;
  final ValueChanged<int> onEditHp;
  final ValueChanged<int> onSelectTarget;

  const _CinematicEnemyRail({
    required this.title,
    required this.targets,
    required this.activeIndex,
    required this.targetIndex,
    required this.showEnemyHp,
    required this.onEditHp,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final compact = targets.length > 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
          child: Row(
            children: [
              const Icon(
                Icons.my_location_outlined,
                color: _CinematicColors.goldBright,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _CinematicColors.paper,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: targets.length,
            separatorBuilder: (_, __) => SizedBox(height: compact ? 8 : 12),
            itemBuilder: (context, index) {
              final entry = targets[index];
              return _CinematicEnemyCard(
                entry: entry,
                active: entry.index == activeIndex,
                targeted: entry.index == targetIndex,
                showEnemyHp: showEnemyHp,
                compact: compact,
                onEditHp: () => onEditHp(entry.index),
                onTap: () => onSelectTarget(entry.index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CinematicEnemyCard extends StatelessWidget {
  final _IndexedCombatant entry;
  final bool active;
  final bool targeted;
  final bool showEnemyHp;
  final bool compact;
  final VoidCallback onEditHp;
  final VoidCallback onTap;

  const _CinematicEnemyCard({
    required this.entry,
    required this.active,
    required this.targeted,
    required this.showEnemyHp,
    required this.compact,
    required this.onEditHp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final combatant = entry.combatant;
    final baseAccent = _teamColor(combatant.team, tokens);
    final accent = targeted
        ? _CinematicColors.goldBright
        : active
            ? tokens.accentInfo
            : baseAccent;
    final activeLabels = combatant.conditions
        .where((label) => label != 'Player Character')
        .toList(growable: false);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: _CinematicPanelFrame(
        padding: EdgeInsets.all(compact ? 8 : 10),
        borderColor: accent,
        backgroundAlpha: targeted ? 0.78 : 0.62,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boundedHeight = constraints.maxHeight.isFinite;
            final cardCompact =
                compact || (boundedHeight && constraints.maxHeight < 190);
            final showEffects = !cardCompact &&
                (!boundedHeight || constraints.maxHeight >= 190);
            final portraitSize = cardCompact ? 48.0 : 64.0;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: portraitSize,
                      height: portraitSize,
                      child: _CinematicPortraitBox(
                        combatant: combatant,
                        color: accent,
                        iconSize: cardCompact ? 21 : 26,
                      ),
                    ),
                    SizedBox(width: cardCompact ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            combatant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _CinematicColors.paper,
                              fontSize: cardCompact ? 13 : 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (!cardCompact) const SizedBox(height: 2),
                          Text(
                            combatant.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: cardCompact ? 10 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: cardCompact ? 5 : 7),
                          _CinematicHpBar(
                            combatant: combatant,
                            showHp: _canShowHp(combatant, showEnemyHp),
                            height: cardCompact ? 18 : 22,
                            onTap: showEnemyHp ? onEditHp : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: cardCompact ? 6 : 8),
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: tokens.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'CA ${combatant.ac}',
                      style: const TextStyle(
                        color: _CinematicColors.paper,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (targeted)
                      Icon(Icons.my_location, color: accent, size: 17)
                    else if (active)
                      Icon(Icons.play_arrow_rounded, color: accent, size: 18),
                  ],
                ),
                if (showEffects) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Efectos',
                    style: TextStyle(
                      color: _CinematicColors.paper.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    activeLabels.isEmpty
                        ? 'Ninguno'
                        : activeLabels.take(3).join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            );

            if (boundedHeight && constraints.maxHeight < 214) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: content,
              );
            }
            return content;
          },
        ),
      ),
    );
  }
}

class _CinematicActiveCard extends StatelessWidget {
  final _Combatant combatant;
  final bool showEnemyHp;
  final _ActionEconomySnapshot economy;
  final VoidCallback onEditHp;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;

  const _CinematicActiveCard({
    required this.combatant,
    required this.showEnemyHp,
    required this.economy,
    required this.onEditHp,
    required this.onRemoveActiveEffect,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(combatant.team, tokens);
    final labels = [
      if (combatant.tempHp > 0) 'Temp HP ${combatant.tempHp}',
      ...combatant.conditions,
    ];

    return _CinematicPanelFrame(
      borderColor: accent,
      padding: const EdgeInsets.all(10),
      backgroundAlpha: 0.76,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boundedHeight = constraints.maxHeight.isFinite;
          final compact = boundedHeight && constraints.maxHeight < 270;
          final veryCompact = boundedHeight && constraints.maxHeight < 230;
          final portraitWidth = veryCompact
              ? 84.0
              : compact
                  ? 96.0
                  : 112.0;
          final idealPortraitHeight = combatant.team == _CombatTeam.party
              ? portraitWidth * 1.25
              : portraitWidth * 1.18;
          final portraitHeight = boundedHeight
              ? math.min(constraints.maxHeight, idealPortraitHeight)
              : idealPortraitHeight;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                combatant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _CinematicColors.paper,
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 2 : 3),
              Text(
                combatant.role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: compact ? 7 : 10),
              _CinematicHpBar(
                combatant: combatant,
                showHp: _canShowHp(combatant, showEnemyHp),
                height: compact ? 22 : 26,
                onTap: showEnemyHp ? onEditHp : null,
              ),
              SizedBox(height: compact ? 7 : 10),
              Row(
                children: [
                  _CinematicMiniStat(label: 'CA', value: '${combatant.ac}'),
                  const SizedBox(width: 8),
                  _CinematicMiniStat(
                    label: 'Init',
                    value: '${combatant.initiative}',
                  ),
                  const SizedBox(width: 8),
                  _CinematicMiniStat(label: 'Vel', value: '${combatant.speed}'),
                ],
              ),
              SizedBox(height: compact ? 7 : 10),
              _CinematicEconomyStrip(economy: economy),
              if (labels.isNotEmpty && !veryCompact) ...[
                SizedBox(height: compact ? 7 : 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in labels.take(6))
                      _ActiveEffectChip(
                        label: label,
                        color: _statusAccentForLabel(label, tokens, accent),
                        removable: _canRemoveEffect(label),
                        onRemove: () =>
                            onRemoveActiveEffect(combatant.id, label),
                      ),
                  ],
                ),
              ],
            ],
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: portraitWidth,
                  height: portraitHeight,
                  child: _CinematicPortraitBox(
                    combatant: combatant,
                    color: accent,
                    iconSize: veryCompact
                        ? 32
                        : compact
                            ? 36
                            : 42,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: details,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CinematicActionDeck extends StatelessWidget {
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final List<_CombatAction> actions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, _CombatAction> preparedActions;
  final String? activeMultiAttackActionKey;
  final List<_ReactionOption> reactionOptions;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final Map<String, int> resourcePool;
  final _CombatRollMode rollMode;
  final bool canControlActive;
  final String controlBlockedMessage;
  final ValueChanged<String> onSelectTiming;
  final ValueChanged<_CombatRollMode> onSelectRollMode;
  final void Function(int actorIndex, _CombatAction action) onUseReaction;
  final ValueChanged<_CombatAction> onReadyAction;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onControlBlocked;
  final VoidCallback onNextTurn;

  const _CinematicActionDeck({
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.activeMultiAttackActionKey,
    required this.reactionOptions,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedTiming,
    required this.resourcePool,
    required this.rollMode,
    required this.canControlActive,
    required this.controlBlockedMessage,
    required this.onSelectTiming,
    required this.onSelectRollMode,
    required this.onUseReaction,
    required this.onReadyAction,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
    required this.onControlBlocked,
    required this.onNextTurn,
  });

  @override
  Widget build(BuildContext context) {
    final visibleActions = actions
        .where((action) => action.timing == selectedTiming)
        .toList(growable: false);
    final prepared = preparedActions[selectedTiming];
    final activeMultiAttackAction = activeMultiAttackActionKey == null
        ? null
        : _firstOrNull(
            actions.where(
              (action) => _actionCardKey(action) == activeMultiAttackActionKey,
            ),
          );
    final featuredAction = prepared ??
        (activeMultiAttackAction?.timing == selectedTiming
            ? activeMultiAttackAction
            : null) ??
        _firstOrNull(visibleActions) ??
        _firstOrNull(actions);
    final featuredPending = featuredAction != null &&
        pendingDamageActions.contains(_actionCardKey(featuredAction));
    final featuredMultiAttackActive = featuredAction != null &&
        activeMultiAttackActionKey == _actionCardKey(featuredAction);
    final featuredSpent = featuredAction != null &&
        spentTimings.contains(featuredAction.timing) &&
        !featuredPending &&
        !featuredMultiAttackActive;
    final secondaryActions = visibleActions
        .where((action) => action != featuredAction)
        .take(4)
        .toList(growable: false);
    final hasPrepared = preparedActions.isNotEmpty;
    final confirmLabel = queuedPreparedTotal > 0
        ? 'Tirar siguiente'
        : hasPrepared
            ? 'Tirar plan'
            : featuredPending
                ? 'Resolver dano'
                : featuredMultiAttackActive
                    ? 'Tirar siguiente'
                    : featuredSpent
                        ? 'Siguiente turno'
                        : 'Confirmar accion';
    final VoidCallback confirmAction = hasPrepared
        ? onLaunchPreparedTurn
        : () {
            final action = featuredAction;
            if (action == null) return;
            if (featuredSpent) {
              onNextTurn();
              return;
            }
            _rollPrimaryAction(
              action,
              onRollAction,
              onUseAction,
              pendingDamage: featuredPending,
            );
          };

    if (!canControlActive) {
      return _CinematicActionControlLockDock(
        activeCombatant: activeCombatant,
        actionCount: actions.length,
        message: controlBlockedMessage,
        rollMode: rollMode,
        onSelectRollMode: onSelectRollMode,
        onControlBlocked: onControlBlocked,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 340) {
          return _CinematicActionQuickDock(
            activeCombatant: activeCombatant,
            actions: actions,
            spentTimings: spentTimings,
            pendingDamageActions: pendingDamageActions,
            preparedActions: preparedActions,
            reactionOptions: reactionOptions,
            queuedPreparedIndex: queuedPreparedIndex,
            queuedPreparedTotal: queuedPreparedTotal,
            queuedPreparedActionName: queuedPreparedActionName,
            selectedTiming: selectedTiming,
            resourcePool: resourcePool,
            rollMode: rollMode,
            featuredAction: featuredAction,
            featuredPending: featuredPending,
            featuredSpent: featuredSpent,
            confirmLabel: confirmLabel,
            confirmAction: confirmAction,
            hasPrepared: hasPrepared,
            onSelectTiming: onSelectTiming,
            onSelectRollMode: onSelectRollMode,
            onUseReaction: onUseReaction,
            onRollAction: onRollAction,
            onUseAction: onUseAction,
            onPrepareAction: onPrepareAction,
            onClearPreparedActions: onClearPreparedActions,
            onNextTurn: onNextTurn,
          );
        }

        return _CinematicPanelFrame(
          borderColor: _CinematicColors.gold,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          backgroundAlpha: 0.78,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _CinematicTimingTabs(
                      actions: actions,
                      selectedTiming: selectedTiming,
                      spentTimings: spentTimings,
                      preparedActions: preparedActions,
                      onSelectTiming: onSelectTiming,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (queuedPreparedTotal > 0)
                    _CinematicQueueChip(
                      index: queuedPreparedIndex,
                      total: queuedPreparedTotal,
                      name: queuedPreparedActionName,
                    ),
                ],
              ),
              if (reactionOptions.isNotEmpty) ...[
                const SizedBox(height: 6),
                _CinematicReactionBar(
                  options: reactionOptions,
                  activeName: activeCombatant.name,
                  onUseReaction: onUseReaction,
                ),
              ],
              if (preparedActions.isNotEmpty || featuredPending) ...[
                const SizedBox(height: 6),
                _CinematicTurnPlanStrip(
                  preparedActions: preparedActions,
                  pendingAction: featuredPending ? featuredAction : null,
                ),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 282,
                      child: featuredAction == null
                          ? const _CinematicEmptyActionCard()
                          : _CinematicFeaturedActionCard(
                              action: featuredAction,
                              activeCombatant: activeCombatant,
                              selectedTarget: selectedTarget,
                              prepared: prepared == featuredAction,
                              spent: spentTimings
                                      .contains(featuredAction.timing) &&
                                  !featuredMultiAttackActive,
                              pendingDamage: pendingDamageActions
                                  .contains(_actionCardKey(featuredAction)),
                              blocked: _actionLacksResource(
                                  featuredAction, resourcePool),
                              resourceRemaining: _actionResourceRemaining(
                                featuredAction,
                                resourcePool,
                              ),
                              onRollAction: onRollAction,
                              onUseAction: onUseAction,
                              onPrepareAction: onPrepareAction,
                              onReadyAction: onReadyAction,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: secondaryActions.isEmpty
                          ? _CinematicActionListEmpty(
                              selectedTiming: selectedTiming,
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: secondaryActions.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final action = secondaryActions[index];
                                final secondaryMultiAttackActive =
                                    activeMultiAttackActionKey ==
                                        _actionCardKey(action);
                                return SizedBox(
                                  width: 178,
                                  child: _CinematicSmallActionCard(
                                    action: action,
                                    prepared: preparedActions[action.timing] ==
                                        action,
                                    spent:
                                        spentTimings.contains(action.timing) &&
                                            !secondaryMultiAttackActive,
                                    pendingDamage: pendingDamageActions
                                        .contains(_actionCardKey(action)),
                                    blocked: _actionLacksResource(
                                        action, resourcePool),
                                    resourceRemaining: _actionResourceRemaining(
                                      action,
                                      resourcePool,
                                    ),
                                    onRollAction: onRollAction,
                                    onUseAction: onUseAction,
                                    onPrepareAction: onPrepareAction,
                                    onReadyAction: onReadyAction,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 214,
                    child: _CinematicFooterButton(
                      icon: Icons.hourglass_bottom_outlined,
                      label: 'Terminar turno',
                      color: _CinematicColors.paper,
                      onTap: onNextTurn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (hasPrepared)
                    _CinematicFooterButton(
                      icon: Icons.clear_all_outlined,
                      label: 'Limpiar plan',
                      color: _CinematicColors.goldBright,
                      onTap: onClearPreparedActions,
                      compact: true,
                    ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 232,
                    child: _CinematicRollModeToggle(
                      value: rollMode,
                      onChanged: onSelectRollMode,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 276,
                    child: _CinematicConfirmButton(
                      enabled: featuredAction != null || hasPrepared,
                      label: confirmLabel,
                      onTap: confirmAction,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CinematicActionControlLockDock extends StatelessWidget {
  final _Combatant activeCombatant;
  final int actionCount;
  final String message;
  final _CombatRollMode rollMode;
  final ValueChanged<_CombatRollMode> onSelectRollMode;
  final VoidCallback onControlBlocked;

  const _CinematicActionControlLockDock({
    required this.activeCombatant,
    required this.actionCount,
    required this.message,
    required this.rollMode,
    required this.onSelectRollMode,
    required this.onControlBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(activeCombatant.team, tokens);

    return _CinematicPanelFrame(
      borderColor: accent,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      backgroundAlpha: 0.80,
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: accent, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turno de ${activeCombatant.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _CinematicColors.paper,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 230,
                child: _CinematicRollModeToggle(
                  value: rollMode,
                  onChanged: onSelectRollMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.24)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: _CinematicPortraitBox(
                      combatant: activeCombatant,
                      color: accent,
                      iconSize: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Puedes seguir el turno, elegir objetivos y ver resultados. '
                      'Las $actionCount acciones de este combatiente quedan bloqueadas para evitar que un jugador use habilidades ajenas.',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 210,
                    child: _CinematicFooterButton(
                      icon: Icons.view_module_outlined,
                      label: 'Ver acciones',
                      color: accent,
                      onTap: onControlBlocked,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 214,
                child: _CinematicFooterButton(
                  icon: Icons.hourglass_bottom_outlined,
                  label: 'Esperar turno',
                  color: _CinematicColors.paper,
                  onTap: onControlBlocked,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 276,
                child: _CinematicConfirmButton(
                  enabled: true,
                  label: 'Accion bloqueada',
                  onTap: onControlBlocked,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CinematicActionQuickDock extends StatelessWidget {
  final _Combatant activeCombatant;
  final List<_CombatAction> actions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, _CombatAction> preparedActions;
  final List<_ReactionOption> reactionOptions;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final Map<String, int> resourcePool;
  final _CombatRollMode rollMode;
  final _CombatAction? featuredAction;
  final bool featuredPending;
  final bool featuredSpent;
  final String confirmLabel;
  final VoidCallback confirmAction;
  final bool hasPrepared;
  final ValueChanged<String> onSelectTiming;
  final ValueChanged<_CombatRollMode> onSelectRollMode;
  final void Function(int actorIndex, _CombatAction action) onUseReaction;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onNextTurn;

  const _CinematicActionQuickDock({
    required this.activeCombatant,
    required this.actions,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.reactionOptions,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedTiming,
    required this.resourcePool,
    required this.rollMode,
    required this.featuredAction,
    required this.featuredPending,
    required this.featuredSpent,
    required this.confirmLabel,
    required this.confirmAction,
    required this.hasPrepared,
    required this.onSelectTiming,
    required this.onSelectRollMode,
    required this.onUseReaction,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onClearPreparedActions,
    required this.onNextTurn,
  });

  @override
  Widget build(BuildContext context) {
    return _CinematicPanelFrame(
      borderColor: _CinematicColors.gold,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      backgroundAlpha: 0.80,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CinematicTimingTabs(
                  actions: actions,
                  selectedTiming: selectedTiming,
                  spentTimings: spentTimings,
                  preparedActions: preparedActions,
                  onSelectTiming: onSelectTiming,
                ),
              ),
              if (queuedPreparedTotal > 0) ...[
                const SizedBox(width: 10),
                _CinematicQueueChip(
                  index: queuedPreparedIndex,
                  total: queuedPreparedTotal,
                  name: queuedPreparedActionName,
                ),
              ],
            ],
          ),
          if (reactionOptions.isNotEmpty) ...[
            const SizedBox(height: 6),
            _CinematicReactionBar(
              options: reactionOptions,
              activeName: activeCombatant.name,
              onUseReaction: onUseReaction,
            ),
          ],
          if (preparedActions.isNotEmpty || featuredPending) ...[
            const SizedBox(height: 6),
            _CinematicTurnPlanStrip(
              preparedActions: preparedActions,
              pendingAction: featuredPending ? featuredAction : null,
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _CinematicQuickActionSummary(
                    action: featuredAction,
                    pendingDamage: featuredPending,
                    spent: featuredSpent,
                    preparedActions: preparedActions,
                    resourcePool: resourcePool,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 202,
                  child: _CinematicFooterButton(
                    icon: Icons.view_module_outlined,
                    label: 'Acciones',
                    color: _CinematicColors.goldBright,
                    compact: true,
                    onTap: () => _showActionCatalogSheet(
                      context: context,
                      actions: actions,
                      spentTimings: spentTimings,
                      pendingDamageActions: pendingDamageActions,
                      resourcePool: resourcePool,
                      preparedActions: preparedActions,
                      selectedTiming: selectedTiming,
                      onSelectTiming: onSelectTiming,
                      onRollAction: onRollAction,
                      onUseAction: onUseAction,
                      onPrepareAction: onPrepareAction,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 222,
                  child: _CinematicRollModeToggle(
                    value: rollMode,
                    onChanged: onSelectRollMode,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 190,
                child: _CinematicFooterButton(
                  icon: Icons.hourglass_bottom_outlined,
                  label: 'Terminar turno',
                  color: _CinematicColors.paper,
                  onTap: onNextTurn,
                ),
              ),
              if (hasPrepared) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 168,
                  child: _CinematicFooterButton(
                    icon: Icons.clear_all_outlined,
                    label: 'Limpiar plan',
                    color: _CinematicColors.goldBright,
                    onTap: onClearPreparedActions,
                    compact: true,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: 276,
                child: _CinematicConfirmButton(
                  enabled: featuredAction != null || hasPrepared,
                  label: confirmLabel,
                  onTap: confirmAction,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CinematicQuickActionSummary extends StatelessWidget {
  final _CombatAction? action;
  final bool pendingDamage;
  final bool spent;
  final Map<String, _CombatAction> preparedActions;
  final Map<String, int> resourcePool;

  const _CinematicQuickActionSummary({
    required this.action,
    required this.pendingDamage,
    required this.spent,
    required this.preparedActions,
    required this.resourcePool,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final currentAction = action;
    if (currentAction == null) {
      return _CinematicActionListEmpty(selectedTiming: 'este timing');
    }

    final accent = _accentForKind(currentAction.accentKind, tokens);
    final resourceRemaining =
        _actionResourceRemaining(currentAction, resourcePool);
    final isPrepared = preparedActions[currentAction.timing] == currentAction;
    final stateLabel = pendingDamage
        ? 'Dano pendiente'
        : spent
            ? 'Timing usado'
            : isPrepared
                ? 'Preparada'
                : 'Lista';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.32)),
            ),
            child: Icon(
              pendingDamage ? Icons.auto_fix_high_outlined : currentAction.icon,
              color: _CinematicColors.paper,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentAction.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _CinematicColors.paper,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _cinematicQuickActionLine(
                    currentAction,
                    resourceRemaining,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(maxWidth: 132),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Text(
              stateLabel.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _CinematicColors.paper,
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

String _cinematicQuickActionLine(_CombatAction action, int? resourceRemaining) {
  final formula = action.attackFormula ??
      (action.requiresSavingThrow
          ? '${action.saveAbility} DC ${action.saveDc}'
          : null);
  final damage = action.damageFormula;
  final resource = resourceRemaining == null
      ? null
      : '${_readableActionResourceName(action.resourceKey ?? 'resource')}: $resourceRemaining';
  return [
    action.timing,
    if (formula != null) formula,
    if (damage != null) damage,
    if (resource != null) resource,
  ].join('  -  ');
}

class _CinematicTimingTabs extends StatelessWidget {
  final List<_CombatAction> actions;
  final String selectedTiming;
  final Set<String> spentTimings;
  final Map<String, _CombatAction> preparedActions;
  final ValueChanged<String> onSelectTiming;

  const _CinematicTimingTabs({
    required this.actions,
    required this.selectedTiming,
    required this.spentTimings,
    required this.preparedActions,
    required this.onSelectTiming,
  });

  @override
  Widget build(BuildContext context) {
    const timings = ['Action', 'Bonus Action', 'Reaction'];
    return Row(
      children: [
        for (final timing in timings) ...[
          Expanded(
            child: _CinematicTimingTab(
              timing: timing,
              selected: selectedTiming == timing,
              spent: spentTimings.contains(timing),
              prepared: preparedActions[timing] != null,
              count: _compactActionCountForTiming(actions, timing),
              onTap: () => onSelectTiming(timing),
            ),
          ),
          if (timing != timings.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _CinematicTimingTab extends StatelessWidget {
  final String timing;
  final bool selected;
  final bool spent;
  final bool prepared;
  final int count;
  final VoidCallback onTap;

  const _CinematicTimingTab({
    required this.timing,
    required this.selected,
    required this.spent,
    required this.prepared,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = spent
        ? _CinematicColors.blood
        : prepared
            ? _CinematicColors.goldBright
            : selected
                ? _CinematicColors.gold
                : _CinematicColors.paper.withValues(alpha: 0.48);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? _CinematicColors.gold.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_timingIcon(timing), color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _compactTimingLabel(timing).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _CinematicColors.paper,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              spent
                  ? 'OK'
                  : prepared
                      ? 'SET'
                      : '$count',
              style: TextStyle(
                color: color,
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

class _CinematicTurnPlanStrip extends StatelessWidget {
  final Map<String, _CombatAction> preparedActions;
  final _CombatAction? pendingAction;

  const _CinematicTurnPlanStrip({
    required this.preparedActions,
    required this.pendingAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final entries = [
      if (pendingAction != null)
        _TurnPlanEntry(
          label: 'Resolver dano',
          action: pendingAction!,
          color: tokens.accentSuccess,
          icon: Icons.auto_fix_high_outlined,
        ),
      for (final timing in ['Action', 'Bonus Action', 'Reaction', 'Movement'])
        if (preparedActions[timing] != null)
          _TurnPlanEntry(
            label: _compactTimingLabel(timing),
            action: preparedActions[timing]!,
            color: _accentForKind(preparedActions[timing]!.accentKind, tokens),
            icon: _timingIcon(timing),
          ),
    ];

    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: entry.color.withValues(alpha: 0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(entry.icon, color: entry.color, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${entry.label}: ${entry.action.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _CinematicColors.paper,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TurnPlanEntry {
  final String label;
  final _CombatAction action;
  final Color color;
  final IconData icon;

  const _TurnPlanEntry({
    required this.label,
    required this.action,
    required this.color,
    required this.icon,
  });
}

class _CinematicFeaturedActionCard extends StatelessWidget {
  final _CombatAction action;
  final _Combatant activeCombatant;
  final _Combatant selectedTarget;
  final bool prepared;
  final bool spent;
  final bool pendingDamage;
  final bool blocked;
  final int? resourceRemaining;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final ValueChanged<_CombatAction> onReadyAction;

  const _CinematicFeaturedActionCard({
    required this.action,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.prepared,
    required this.spent,
    required this.pendingDamage,
    required this.blocked,
    required this.resourceRemaining,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onReadyAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(action.accentKind, tokens);
    final resourceName = action.resourceKey == null
        ? null
        : _readableActionResourceName(action.resourceKey!);
    final stateLabel = _actionStateLabel(
      prepared: prepared,
      spent: spent,
      pendingDamage: pendingDamage,
      blocked: blocked,
    );

    return _CinematicActionTapRegion(
      tooltip: _primaryActionTooltip(action, pendingDamage),
      onTap: () => _rollPrimaryAction(
        action,
        onRollAction,
        onUseAction,
        pendingDamage: pendingDamage,
      ),
      child: _CinematicActionCardFrame(
        color: accent,
        blocked: blocked,
        prepared: prepared,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tight = constraints.maxHeight < 218;
            final ultraTight = constraints.maxHeight < 184;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: ultraTight
                          ? 32
                          : tight
                              ? 36
                              : 42,
                      height: ultraTight
                          ? 32
                          : tight
                              ? 36
                              : 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.30)),
                      ),
                      child: Icon(
                        action.icon,
                        color: _CinematicColors.paper,
                        size: ultraTight
                            ? 18
                            : tight
                                ? 20
                                : 23,
                      ),
                    ),
                    SizedBox(width: ultraTight ? 8 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.name,
                            maxLines: tight ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _CinematicColors.paper,
                              fontSize: ultraTight
                                  ? 14
                                  : tight
                                      ? 15
                                      : 17,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          if (!ultraTight) ...[
                            const SizedBox(height: 2),
                            Text(
                              action.timing,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _CinematicColors.actionTextMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (stateLabel != null) ...[
                      const SizedBox(width: 7),
                      _CinematicActionStateBadge(
                        label: stateLabel,
                        color: _actionStateColor(
                          prepared: prepared,
                          spent: spent,
                          pendingDamage: pendingDamage,
                          blocked: blocked,
                          fallback: accent,
                        ),
                      ),
                    ],
                  ],
                ),
                if (!ultraTight) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (action.attackFormula != null)
                        _ParchmentFormulaPill(
                          label: action.attackFormula!,
                          caption: 'Para impactar',
                          compact: tight,
                        )
                      else if (action.requiresSavingThrow)
                        _ParchmentFormulaPill(
                          label: '${action.saveAbility} ${action.saveDc}',
                          caption: 'Salvacion',
                          compact: tight,
                        )
                      else
                        _ParchmentFormulaPill(
                          label: action.hasMultiAttack
                              ? '${action.multiAttackSteps.length}x'
                              : 'Uso',
                          caption: action.type,
                          compact: tight,
                        ),
                      const SizedBox(width: 9),
                      if (action.damageFormula != null)
                        Expanded(
                          child: Text(
                            action.isHealing
                                ? '${action.damageFormula} curacion'
                                : '${action.damageFormula} dano',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _CinematicColors.paper,
                              fontSize: tight ? 15 : 18,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (!tight) ...[
                  const SizedBox(height: 8),
                  Text(
                    _cinematicActionDescription(
                        action, activeCombatant, selectedTarget),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _CinematicColors.actionTextMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.16,
                    ),
                  ),
                ],
                const Spacer(),
                if (resourceName != null && !ultraTight)
                  Text(
                    '$resourceName: ${resourceRemaining ?? 0}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: blocked
                          ? _CinematicColors.blood
                          : _CinematicColors.actionTextMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                SizedBox(height: ultraTight ? 4 : 6),
                Row(
                  children: [
                    Expanded(
                      child: _ParchmentActionButton(
                        label: _primaryActionLabel(action, pendingDamage),
                        icon: pendingDamage
                            ? Icons.auto_fix_high_outlined
                            : Icons.casino_outlined,
                        color: accent,
                        compact: tight,
                        onTap: () => _rollPrimaryAction(
                          action,
                          onRollAction,
                          onUseAction,
                          pendingDamage: pendingDamage,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ParchmentIconButton(
                      icon: prepared ? Icons.bookmark_added : Icons.add_task,
                      tooltip: prepared ? 'Quitar del plan' : 'Preparar',
                      color: accent,
                      compact: tight,
                      onTap: () => onPrepareAction(action),
                    ),
                    if (!ultraTight && action.timing == 'Action') ...[
                      const SizedBox(width: 8),
                      _ParchmentIconButton(
                        icon: Icons.flag_outlined,
                        tooltip: 'Ready action',
                        color: accent,
                        compact: tight,
                        onTap: () => onReadyAction(action),
                      ),
                    ],
                    if (!tight) ...[
                      const SizedBox(width: 8),
                      _ParchmentIconButton(
                        icon: Icons.info_outline,
                        tooltip: 'Detalles',
                        color: accent,
                        onTap: () => _showActionDetails(context, action),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CinematicSmallActionCard extends StatelessWidget {
  final _CombatAction action;
  final bool prepared;
  final bool spent;
  final bool pendingDamage;
  final bool blocked;
  final int? resourceRemaining;
  final void Function(_CombatAction action, _CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<_CombatAction> onUseAction;
  final ValueChanged<_CombatAction> onPrepareAction;
  final ValueChanged<_CombatAction> onReadyAction;

  const _CinematicSmallActionCard({
    required this.action,
    required this.prepared,
    required this.spent,
    required this.pendingDamage,
    required this.blocked,
    required this.resourceRemaining,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onReadyAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(action.accentKind, tokens);
    final stateLabel = _actionStateLabel(
      prepared: prepared,
      spent: spent,
      pendingDamage: pendingDamage,
      blocked: blocked,
    );

    return _CinematicActionTapRegion(
      tooltip: _primaryActionTooltip(action, pendingDamage),
      onTap: () => _rollPrimaryAction(
        action,
        onRollAction,
        onUseAction,
        pendingDamage: pendingDamage,
      ),
      child: _CinematicActionCardFrame(
        color: accent,
        blocked: blocked,
        prepared: prepared,
        dense: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final veryTight = constraints.maxHeight < 150;
            final ultraTight = constraints.maxHeight < 124;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      action.icon,
                      color: _CinematicColors.actionTextMuted,
                      size: veryTight ? 18 : 20,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        action.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _CinematicColors.paper,
                          fontSize: ultraTight
                              ? 11
                              : veryTight
                                  ? 12
                                  : 13,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ),
                    if (stateLabel != null) ...[
                      const SizedBox(width: 5),
                      _CinematicActionStateBadge(
                        label: stateLabel,
                        color: _actionStateColor(
                          prepared: prepared,
                          spent: spent,
                          pendingDamage: pendingDamage,
                          blocked: blocked,
                          fallback: accent,
                        ),
                        compact: true,
                      ),
                    ],
                  ],
                ),
                if (!veryTight) ...[
                  const SizedBox(height: 5),
                  Text(
                    action.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _CinematicColors.actionTextMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                SizedBox(height: ultraTight ? 2 : 4),
                Text(
                  _preparedActionFormula(action),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _CinematicColors.paper,
                    fontSize: ultraTight
                        ? 13
                        : veryTight
                            ? 15
                            : 17,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                if (resourceRemaining != null && !veryTight) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rec: $resourceRemaining',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: blocked
                          ? _CinematicColors.blood
                          : _CinematicColors.actionTextMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: _ParchmentActionButton(
                        label: _primaryActionLabel(action, pendingDamage),
                        icon: pendingDamage
                            ? Icons.auto_fix_high_outlined
                            : Icons.casino_outlined,
                        color: accent,
                        compact: true,
                        onTap: () => _rollPrimaryAction(
                          action,
                          onRollAction,
                          onUseAction,
                          pendingDamage: pendingDamage,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _ParchmentIconButton(
                      icon: prepared ? Icons.bookmark_added : Icons.add,
                      tooltip: prepared ? 'Quitar del plan' : 'Preparar',
                      color: accent,
                      compact: true,
                      onTap: () => onPrepareAction(action),
                    ),
                    if (!ultraTight && action.timing == 'Action') ...[
                      const SizedBox(width: 6),
                      _ParchmentIconButton(
                        icon: Icons.flag_outlined,
                        tooltip: 'Ready action',
                        color: accent,
                        compact: true,
                        onTap: () => onReadyAction(action),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CinematicActionCardFrame extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool blocked;
  final bool prepared;
  final bool dense;

  const _CinematicActionCardFrame({
    required this.child,
    required this.color,
    required this.blocked,
    required this.prepared,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      clipBehavior: Clip.hardEdge,
      padding: EdgeInsets.all(dense ? 7 : 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: blocked
              ? [
                  const Color(0xFF3C2B25),
                  const Color(0xFF281B17),
                ]
              : [
                  color.withValues(alpha: 0.18),
                  _CinematicColors.actionSurfaceRaised,
                  _CinematicColors.actionSurface,
                ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: prepared
              ? _CinematicColors.goldBright
              : color.withValues(alpha: 0.34),
          width: prepared ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: prepared ? 0.30 : 0.16),
            blurRadius: prepared ? 16 : 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -18,
            top: -18,
            child: Icon(
              Icons.hexagon_outlined,
              color: _CinematicColors.paper.withValues(alpha: 0.05),
              size: dense ? 82 : 118,
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _CinematicActionTapRegion extends StatelessWidget {
  final Widget child;
  final String tooltip;
  final VoidCallback onTap;

  const _CinematicActionTapRegion({
    required this.child,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      ),
    );
  }
}

class _CinematicActionStateBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _CinematicActionStateBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 36 : 44,
        maxWidth: compact ? 54 : 68,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.44)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: compact ? 7.5 : 8.5,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _ParchmentFormulaPill extends StatelessWidget {
  final String label;
  final String caption;
  final bool compact;

  const _ParchmentFormulaPill({
    required this.label,
    required this.caption,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 8,
            vertical: compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: _CinematicColors.blood,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
                color: const Color(0xFFFFD9B0).withValues(alpha: 0.20)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: compact ? 5 : 7),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _CinematicColors.actionTextMuted,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ParchmentActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _ParchmentActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: compact ? 28 : 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _CinematicColors.paper, size: compact ? 14 : 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _CinematicColors.paper,
                  fontSize: compact ? 10 : 12,
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

class _ParchmentIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _ParchmentIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 34.0;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Icon(icon,
              color: _CinematicColors.paper, size: compact ? 15 : 18),
        ),
      ),
    );
  }
}

class _CinematicFooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _CinematicFooterButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: compact ? 40 : 42,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasFiniteWidth = constraints.maxWidth.isFinite;
            final labelWidget = Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w900,
              ),
            );

            return Row(
              mainAxisSize:
                  hasFiniteWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: compact ? 17 : 19),
                const SizedBox(width: 10),
                if (hasFiniteWidth)
                  Flexible(child: labelWidget)
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: compact ? 112 : 160,
                    ),
                    child: labelWidget,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CinematicConfirmButton extends StatelessWidget {
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  const _CinematicConfirmButton({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF5F1510),
                Color(0xFF9D241A),
                Color(0xFF4E100E),
              ],
            ),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: const Color(0xFFD66B42).withValues(alpha: 0.62)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9D241A).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _CinematicColors.paper,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_rounded,
                color: _CinematicColors.paper,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CinematicEmptyActionCard extends StatelessWidget {
  const _CinematicEmptyActionCard();

  @override
  Widget build(BuildContext context) {
    return _CinematicActionCardFrame(
      color: _CinematicColors.gold,
      blocked: false,
      prepared: false,
      child: const Center(
        child: Text(
          'Sin acciones disponibles',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _CinematicColors.paper,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CinematicActionListEmpty extends StatelessWidget {
  final String selectedTiming;

  const _CinematicActionListEmpty({
    required this.selectedTiming,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _CinematicColors.gold.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        'No hay mas opciones para ${_compactTimingLabel(selectedTiming)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _CinematicColors.paper.withValues(alpha: 0.66),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CinematicQueueChip extends StatelessWidget {
  final int index;
  final int total;
  final String? name;

  const _CinematicQueueChip({
    required this.index,
    required this.total,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _CinematicColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: _CinematicColors.gold.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.playlist_play_outlined,
            color: _CinematicColors.goldBright,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${math.min(index + 1, total)}/$total ${name ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _CinematicColors.paper,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CinematicReactionBar extends StatelessWidget {
  final List<_ReactionOption> options;
  final String activeName;
  final void Function(int actorIndex, _CombatAction action) onUseReaction;

  const _CinematicReactionBar({
    required this.options,
    required this.activeName,
    required this.onUseReaction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Container(
            width: 96,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _CinematicColors.gold.withValues(alpha: 0.18),
              ),
            ),
            child: const Text(
              'REACCIONES',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _CinematicColors.paper,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final option = options[index];
                return _CinematicReactionChip(
                  option: option,
                  activeName: activeName,
                  onTap: option.spent
                      ? null
                      : () => onUseReaction(option.actorIndex, option.action),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CinematicReactionChip extends StatelessWidget {
  final _ReactionOption option;
  final String activeName;
  final VoidCallback? onTap;

  const _CinematicReactionChip({
    required this.option,
    required this.activeName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(option.combatant.team, tokens);
    final disabled = option.spent;
    return Tooltip(
      message: disabled
          ? '${option.combatant.name} already spent reaction'
          : option.readied
              ? '${option.combatant.name}: ${option.trigger ?? option.action.name}'
              : '${option.combatant.name}: ${option.action.name} vs $activeName',
      child: Opacity(
        opacity: disabled ? 0.46 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 168,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: disabled ? 0.06 : 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accent.withValues(alpha: disabled ? 0.14 : 0.30),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  disabled ? Icons.lock_clock_outlined : option.action.icon,
                  color: accent,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.combatant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _CinematicColors.paper,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        disabled
                            ? 'Reaction spent'
                            : option.readied
                                ? 'Ready: ${option.action.name}'
                                : option.action.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CinematicRollModeToggle extends StatelessWidget {
  final _CombatRollMode value;
  final ValueChanged<_CombatRollMode> onChanged;

  const _CinematicRollModeToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: _CinematicColors.gold.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CinematicRollModeSegment(
              icon: Icons.casino_outlined,
              label: 'N',
              tooltip: 'Normal',
              selected: value == _CombatRollMode.normal,
              onTap: () => onChanged(_CombatRollMode.normal),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _CinematicRollModeSegment(
              icon: Icons.keyboard_arrow_up_rounded,
              label: 'ADV',
              tooltip: 'Ventaja',
              selected: value == _CombatRollMode.advantage,
              onTap: () => onChanged(_CombatRollMode.advantage),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _CinematicRollModeSegment(
              icon: Icons.keyboard_arrow_down_rounded,
              label: 'DIS',
              tooltip: 'Desventaja',
              selected: value == _CombatRollMode.disadvantage,
              onTap: () => onChanged(_CombatRollMode.disadvantage),
            ),
          ),
        ],
      ),
    );
  }
}

class _CinematicRollModeSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _CinematicRollModeSegment({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? _CinematicColors.goldBright : _CinematicColors.paper;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? _CinematicColors.gold.withValues(alpha: 0.20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.36 : 0.10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CinematicWorkspaceOverlay extends StatelessWidget {
  final _CombatWorkspace workspace;
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final bool showEnemyHp;
  final List<_CombatLogEntry> entries;
  final _CombatRollFeedback? rollFeedback;

  const _CinematicWorkspaceOverlay({
    required this.workspace,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.showEnemyHp,
    required this.entries,
    required this.rollFeedback,
  });

  @override
  Widget build(BuildContext context) {
    return _CinematicPanelFrame(
      borderColor: _CinematicColors.gold,
      padding: const EdgeInsets.all(14),
      backgroundAlpha: 0.76,
      child: switch (workspace) {
        _CombatWorkspace.log =>
          _GameFeedWindow(entries: entries, maxEntries: 12),
        _CombatWorkspace.overview => _EncounterOverviewStage(
            combatants: combatants,
            activeIndex: activeIndex,
            targetIndex: targetIndex,
            rollFeedback: rollFeedback,
            showEnemyHp: showEnemyHp,
          ),
        _CombatWorkspace.turn => const SizedBox.shrink(),
      },
    );
  }
}

class _CinematicRollToast extends StatelessWidget {
  final _CombatRollFeedback feedback;

  const _CinematicRollToast({
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _accentForKind(feedback.accentKind, tokens);
    final result = feedback.result;

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: _FallingDiceTrail(
              key: ValueKey(
                '${feedback.action}-${feedback.headline}-${result?.total ?? 'manual'}',
              ),
              color: accent,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LargeDiceBadge(
                total: result?.total,
                formula: result?.formula,
                color: accent,
                compact: true,
                sides: result?.sides,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feedback.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _CinematicColors.paper,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (feedback.subline != null) ...[
                      const SizedBox(height: 2),
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
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FallingDiceTrail extends StatelessWidget {
  final Color color;

  const _FallingDiceTrail({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const offsets = [
      Offset(0.16, -0.16),
      Offset(0.37, -0.34),
      Offset(0.62, -0.22),
      Offset(0.84, -0.40),
    ];

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  for (var index = 0; index < offsets.length; index++)
                    Positioned(
                      left: constraints.maxWidth * offsets[index].dx,
                      top: constraints.maxHeight *
                          (offsets[index].dy + value * 0.86),
                      child: Opacity(
                        opacity: (1 - value).clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: value * 7.0 + index,
                          child: _PolyhedralDieIcon(
                            color: color.withValues(alpha: 0.55),
                            size: 16 + index * 2,
                            sides: const [20, 12, 8, 6][index],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CinematicPanelFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color borderColor;
  final double backgroundAlpha;

  const _CinematicPanelFrame({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor = _CinematicColors.gold,
    this.backgroundAlpha = 0.68,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.hardEdge,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: backgroundAlpha),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: borderColor.withValues(alpha: 0.08),
              blurRadius: 12,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _CinematicPortraitBox extends StatelessWidget {
  final _Combatant combatant;
  final Color color;
  final double iconSize;

  const _CinematicPortraitBox({
    required this.combatant,
    required this.color,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: _CombatantArtwork(
        combatant: combatant,
        color: color,
        iconSize: iconSize,
      ),
    );
  }
}

class _CinematicHpBar extends StatelessWidget {
  final _Combatant combatant;
  final bool showHp;
  final double height;
  final VoidCallback? onTap;

  const _CinematicHpBar({
    required this.combatant,
    required this.showHp,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final editable = onTap != null;
    final effectiveHeight = math.max(height, editable ? 22.0 : 16.0);
    final valueColor = !showHp
        ? tokens.textMuted
        : combatant.hp <= 0
            ? tokens.textMuted
            : combatant.hpRatio <= 0.30
                ? tokens.accentAction
                : const Color(0xFFB0201C);

    final bar = SizedBox(
      height: effectiveHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: showHp ? combatant.hpRatio : 1,
                minHeight: effectiveHeight,
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                valueColor: AlwaysStoppedAnimation<Color>(valueColor),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 4,
              right: editable ? 22 : 4,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _compactHpLabel(combatant, showHp),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          if (editable)
            Positioned(
              right: 5,
              child: Icon(
                Icons.edit_outlined,
                color: Colors.white.withValues(alpha: 0.88),
                size: math.min(effectiveHeight - 6, 16),
              ),
            ),
        ],
      ),
    );

    if (!editable) return bar;
    return Tooltip(
      message: 'Editar HP',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: bar,
        ),
      ),
    );
  }
}

class _HpAdjustmentSheet extends StatelessWidget {
  final _Combatant combatant;
  final TextEditingController controller;
  final VoidCallback onSubtract;
  final VoidCallback onAdd;
  final VoidCallback onSetExact;

  const _HpAdjustmentSheet({
    required this.combatant,
    required this.controller,
    required this.onSubtract,
    required this.onAdd,
    required this.onSetExact,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _teamColor(combatant.team, tokens);
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxPanelHeight = math.max(120.0, size.height - bottomInset - 32);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: maxPanelHeight,
            ),
            child: _CinematicPanelFrame(
              borderColor: accent,
              backgroundAlpha: 0.92,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: _CinematicPortraitBox(
                            combatant: combatant,
                            color: accent,
                            iconSize: 24,
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
                                  color: _CinematicColors.paper,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _CinematicHpBar(
                                combatant: combatant,
                                showHp: true,
                                height: 24,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: false,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: _CinematicColors.paper,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor de HP',
                        labelStyle: TextStyle(color: tokens.textSecondary),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.26),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color:
                                _CinematicColors.gold.withValues(alpha: 0.30),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _CinematicColors.goldBright,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in const [1, 5, 10, 20])
                          ActionChip(
                            label: Text('$value'),
                            onPressed: () {
                              controller.text = '$value';
                              controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length),
                              );
                            },
                            backgroundColor:
                                _CinematicColors.gold.withValues(alpha: 0.16),
                            labelStyle: const TextStyle(
                              color: _CinematicColors.paper,
                              fontWeight: FontWeight.w900,
                            ),
                            side: BorderSide(
                              color:
                                  _CinematicColors.gold.withValues(alpha: 0.28),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          child: _HpSheetButton(
                            label: 'Restar',
                            icon: Icons.remove_rounded,
                            color: _CinematicColors.blood,
                            onTap: onSubtract,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: _HpSheetButton(
                            label: 'Sumar',
                            icon: Icons.add_rounded,
                            color: _CinematicColors.goldBright,
                            onTap: onAdd,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: _HpSheetButton(
                            label: 'Fijar',
                            icon: Icons.done_rounded,
                            color: accent,
                            onTap: onSetExact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HpSheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HpSheetButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.34)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
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

class _CinematicMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _CinematicMiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _CinematicColors.gold.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _CinematicColors.paper.withValues(alpha: 0.58),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _CinematicColors.paper,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CinematicEconomyStrip extends StatelessWidget {
  final _ActionEconomySnapshot economy;

  const _CinematicEconomyStrip({
    required this.economy,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _EconomyPill(
          label: 'Action',
          spent: economy.actionSpent,
          icon: Icons.bolt_outlined,
        ),
        _EconomyPill(
          label: 'Bonus',
          spent: economy.bonusActionSpent,
          icon: Icons.control_point_duplicate_outlined,
        ),
        _EconomyPill(
          label: 'React',
          spent: economy.reactionSpent,
          icon: Icons.reply_outlined,
        ),
        _EconomyPill(
          label: '${economy.movementAvailable} ft',
          spent: false,
          icon: Icons.directions_run_outlined,
        ),
        if (economy.readiedActionName != null)
          _EconomyPill(
            label: 'Ready',
            spent: false,
            icon: Icons.flag_outlined,
            tooltip:
                '${economy.readiedActionName}: ${economy.readiedTrigger ?? ''}',
          ),
      ],
    );
  }
}

class _EconomyPill extends StatelessWidget {
  final String label;
  final bool spent;
  final IconData icon;
  final String? tooltip;

  const _EconomyPill({
    required this.label,
    required this.spent,
    required this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = spent ? _CinematicColors.blood : _CinematicColors.goldBright;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: spent ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            spent ? '$label spent' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

class _CinematicRoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CinematicRoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _CinematicColors.gold.withValues(alpha: 0.12),
            border: Border.all(
              color: _CinematicColors.gold.withValues(alpha: 0.28),
            ),
          ),
          child: Icon(icon, color: _CinematicColors.paper, size: 20),
        ),
      ),
    );
  }
}

class _CinematicTargetRingPainter extends CustomPainter {
  final Color color;
  final bool active;
  final bool enemy;

  const _CinematicTargetRingPainter({
    required this.color,
    required this.active,
    required this.enemy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 2.6 : 1.7
      ..color = color.withValues(alpha: active ? 0.78 : 0.38);
    canvas.drawOval(rect, paint);

    if (active) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = color.withValues(alpha: 0.25);
      canvas.drawOval(rect.deflate(1), glow);
    }

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = (enemy ? _CinematicColors.blood : color)
          .withValues(alpha: active ? 0.75 : 0.34);
    canvas.drawArc(
        rect.inflate(6), -math.pi * 0.84, math.pi * 0.18, false, tickPaint);
    canvas.drawArc(
        rect.inflate(6), math.pi * 0.16, math.pi * 0.18, false, tickPaint);
  }

  @override
  bool shouldRepaint(covariant _CinematicTargetRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.active != active ||
        oldDelegate.enemy != enemy;
  }
}

class _CinematicArenaFloorPainter extends CustomPainter {
  final Color partyColor;
  final Color enemyColor;

  const _CinematicArenaFloorPainter({
    required this.partyColor,
    required this.enemyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.64;
    final partyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = partyColor.withValues(alpha: 0.28);
    final enemyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = enemyColor.withValues(alpha: 0.28);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.25, centerY),
        width: size.width * 0.28,
        height: 42,
      ),
      partyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.72, centerY - 6),
        width: size.width * 0.34,
        height: 48,
      ),
      enemyPaint,
    );

    final path = Path()
      ..moveTo(size.width * 0.33, centerY - 22)
      ..quadraticBezierTo(
        size.width * 0.50,
        centerY - 64,
        size.width * 0.66,
        centerY - 24,
      );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _CinematicColors.gold.withValues(alpha: 0.18);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _CinematicArenaFloorPainter oldDelegate) {
    return oldDelegate.partyColor != partyColor ||
        oldDelegate.enemyColor != enemyColor;
  }
}

class _CinematicColors {
  static const gold = Color(0xFF9C7140);
  static const goldBright = Color(0xFFE5B46C);
  static const paper = Color(0xFFF2D8B5);
  static const actionSurface = Color(0xFF16110D);
  static const actionSurfaceRaised = Color(0xFF221812);
  static const actionTextMuted = Color(0xFFC3A57E);
  static const blood = Color(0xFF8F1E19);
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
  final bool canControlActive;
  final String controlBlockedMessage;
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
  final VoidCallback onControlBlocked;

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
    required this.canControlActive,
    required this.controlBlockedMessage,
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
    required this.onControlBlocked,
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
            if (!canControlActive) {
              onControlBlocked();
              return;
            }
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
                        enabled: canControlActive,
                        disabledMessage: controlBlockedMessage,
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
                              enabled: canControlActive,
                              disabledMessage: controlBlockedMessage,
                              onDisabledTap: onControlBlocked,
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

class _CombatNarrowModeView extends StatelessWidget {
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
  final bool canControlActive;
  final String controlBlockedMessage;
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
  final VoidCallback onControlBlocked;

  const _CombatNarrowModeView({
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
    required this.canControlActive,
    required this.controlBlockedMessage,
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
    required this.onControlBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.sizeOf(context).height > MediaQuery.sizeOf(context).width;

    void openCatalog(String timing) {
      if (!canControlActive) {
        onControlBlocked();
        return;
      }
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

    return ListView(
      padding: const EdgeInsets.all(8),
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
        if (isPortrait) ...[
          const SizedBox(height: 8),
          const _LandscapeNudge(),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: isPortrait ? 230 : 190,
          child: _CombatDiceTheater(
            feedback: rollFeedback,
            activeCombatant: activeCombatant,
            selectedTarget: selectedTarget,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: isPortrait
              ? _CompactActiveCombatantCard(
                  combatant: activeCombatant,
                  actions: actions,
                  selectedTiming: selectedCommandTiming,
                  spentTimings: spentTimings,
                  showEnemyHp: showEnemyHp,
                  enabled: canControlActive,
                  disabledMessage: controlBlockedMessage,
                  onOpenCatalog: openCatalog,
                  onRemoveActiveEffect: onRemoveActiveEffect,
                )
              : Row(
                  children: [
                    Expanded(
                      child: _CompactActiveCombatantCard(
                        combatant: activeCombatant,
                        actions: actions,
                        selectedTiming: selectedCommandTiming,
                        spentTimings: spentTimings,
                        showEnemyHp: showEnemyHp,
                        enabled: canControlActive,
                        disabledMessage: controlBlockedMessage,
                        onOpenCatalog: openCatalog,
                        onRemoveActiveEffect: onRemoveActiveEffect,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
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
        if (isPortrait) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 250,
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
        const SizedBox(height: 8),
        SizedBox(
          height: isPortrait ? 178 : 142,
          child: _CompactPreparedTurnStrip(
            activeCombatant: activeCombatant,
            actions: actions,
            preparedActions: preparedActions,
            spentTimings: spentTimings,
            queuedPreparedIndex: queuedPreparedIndex,
            queuedPreparedTotal: queuedPreparedTotal,
            queuedPreparedActionName: queuedPreparedActionName,
            selectedTiming: selectedCommandTiming,
            enabled: canControlActive,
            disabledMessage: controlBlockedMessage,
            onDisabledTap: onControlBlocked,
            onOpenCatalog: openCatalog,
            onLaunch: onLaunchPreparedTurn,
            onClear: onClearPreparedActions,
          ),
        ),
      ],
    );
  }
}

class _LandscapeNudge extends StatelessWidget {
  const _LandscapeNudge();

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.accentInfo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.screen_rotation_alt_outlined,
              color: tokens.accentInfo, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Landscape gives Combat Mode more room for turns, dice and target.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
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
  final bool enabled;
  final String disabledMessage;
  final ValueChanged<String> onOpenCatalog;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;

  const _CompactActiveCombatantCard({
    required this.combatant,
    required this.actions,
    required this.selectedTiming,
    required this.spentTimings,
    required this.showEnemyHp,
    required this.enabled,
    required this.disabledMessage,
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
              if (!enabled) ...[
                SizedBox(height: isTight ? 5 : 7),
                _CompactControlLockNotice(message: disabledMessage),
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

class _CompactControlLockNotice extends StatelessWidget {
  final String message;

  const _CompactControlLockNotice({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.accentWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentWarning.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: tokens.accentWarning, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.08,
              ),
            ),
          ),
        ],
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
  final bool enabled;
  final String disabledMessage;
  final VoidCallback onDisabledTap;
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
    required this.enabled,
    required this.disabledMessage,
    required this.onDisabledTap,
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
                if (MediaQuery.sizeOf(context).width >= 520) ...[
                  const SizedBox(width: 6),
                  _QueuedRollPill(
                    index: queuedPreparedIndex + 1,
                    total: queuedPreparedTotal,
                    actionName: queuedPreparedActionName ?? 'Next roll',
                  ),
                ],
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: preparedActions.isEmpty
                    ? null
                    : enabled
                        ? onClear
                        : onDisabledTap,
                icon: const Icon(Icons.close, size: 16),
                color: Colors.white,
                disabledColor: tokens.textMuted,
                tooltip: 'Clear plan',
              ),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: !enabled
                      ? onDisabledTap
                      : executableCount == 0 && !queueActive
                          ? null
                          : onLaunch,
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
          if (!enabled) ...[
            const SizedBox(height: 7),
            _CompactControlLockNotice(message: disabledMessage),
          ],
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final veryTight = constraints.maxWidth < 92;
            return Row(
              children: [
                Icon(icon, color: Colors.white, size: veryTight ? 14 : 16),
                SizedBox(width: veryTight ? 5 : 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        veryTight ? _compactTimingLabel(timing) : timing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: veryTight ? 8 : 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        action?.name ?? (spent ? 'Done' : 'Open'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: veryTight ? 10 : 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!veryTight) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      spent ? 'Done' : _preparedActionFormula(action),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: action == null ? tokens.textMuted : Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
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

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : iconSize * 2.2;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : iconSize * 2.2;
          final cacheWidth = (width * pixelRatio).clamp(96.0, 520.0).round();
          final cacheHeight = (height * pixelRatio).clamp(96.0, 520.0).round();
          final portraitPath = combatant.portraitAsset;
          final hasPortrait = hasDisplayableImagePath(portraitPath);
          final imageAlignment = combatant.team == _CombatTeam.party
              ? const Alignment(0, -0.14)
              : Alignment.center;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (!hasPortrait)
                fallback
              else
                Image(
                  image: ResizeImage.resizeIfNeeded(
                    cacheWidth,
                    cacheHeight,
                    imageProviderFromPath(portraitPath!),
                  ),
                  fit: combatant.team == _CombatTeam.party
                      ? BoxFit.cover
                      : BoxFit.contain,
                  alignment: imageAlignment,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
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
        },
      ),
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

class _EncounterOverviewWindow extends StatelessWidget {
  final List<_Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final _CombatRollFeedback? rollFeedback;
  final bool showEnemyHp;
  final VoidCallback onClose;

  const _EncounterOverviewWindow({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.rollFeedback,
    required this.showEnemyHp,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxDialogWidth = math.max(320.0, size.width - 44);
    final maxDialogHeight = math.max(420.0, size.height - 40);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(1180.0, maxDialogWidth),
        maxHeight: math.min(760.0, maxDialogHeight),
      ),
      child: _CinematicPanelFrame(
        borderColor: _CinematicColors.gold,
        padding: const EdgeInsets.all(14),
        backgroundAlpha: 0.88,
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.groups_2_outlined,
                  color: _CinematicColors.goldBright,
                  size: 19,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'RESUMEN DEL ENCUENTRO',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _CinematicColors.paper,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _ParchmentIconButton(
                  icon: Icons.close,
                  tooltip: 'Cerrar resumen',
                  color: _CinematicColors.gold,
                  compact: true,
                  onTap: onClose,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _EncounterOverviewStage(
                combatants: combatants,
                activeIndex: activeIndex,
                targetIndex: targetIndex,
                rollFeedback: rollFeedback,
                showEnemyHp: showEnemyHp,
              ),
            ),
          ],
        ),
      ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
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
              const SizedBox(height: 10),
              Expanded(
                child: _EncounterTeamColumn(
                  title: 'Enemies',
                  entries: enemies,
                  activeIndex: activeIndex,
                  targetIndex: targetIndex,
                  showEnemyHp: showEnemyHp,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 148,
                child: _OverviewRollSummary(feedback: rollFeedback),
              ),
            ],
          );
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
      },
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
                sides: result?.sides,
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
                      sides: result?.sides,
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
  final int? sides;

  const _LargeDiceBadge({
    required this.total,
    required this.formula,
    required this.color,
    this.compact = false,
    this.sides,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final explicitSides = sides == null || sides! < 2 ? null : sides;
    final dieSides =
        explicitSides ?? _primaryDieSidesFromFormula(formula) ?? 20;

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
                              _PolyhedralDieIcon(
                                color: Colors.white,
                                size: compact ? 24 : 28,
                                sides: dieSides,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'D$dieSides',
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

int? _primaryDieSidesFromFormula(String? formula) {
  if (formula == null) return null;
  final match = RegExp(r'd(\d+)', caseSensitive: false).firstMatch(formula);
  return int.tryParse(match?.group(1) ?? '');
}

class _PolyhedralDieIcon extends StatelessWidget {
  final Color color;
  final double size;
  final int sides;

  const _PolyhedralDieIcon({
    required this.color,
    required this.size,
    required this.sides,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PolyhedralDiePainter(
          color: color,
          sides: sides,
        ),
      ),
    );
  }
}

class _PolyhedralDiePainter extends CustomPainter {
  final Color color;
  final int sides;

  const _PolyhedralDiePainter({
    required this.color,
    required this.sides,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _DiceGemClipper().getClip(size);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.95),
          color.withValues(alpha: 0.34),
          Colors.black.withValues(alpha: 0.28),
        ],
      ).createShader(Offset.zero & size);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.shortestSide * 0.055)
      ..color = Colors.white.withValues(alpha: 0.82);
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, size.shortestSide * 0.030)
      ..color = Colors.white.withValues(alpha: 0.42);

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);

    final top = Offset(size.width * 0.50, size.height * 0.06);
    final left = Offset(size.width * 0.16, size.height * 0.42);
    final right = Offset(size.width * 0.84, size.height * 0.42);
    final bottom = Offset(size.width * 0.50, size.height * 0.92);
    final center = Offset(size.width * 0.50, size.height * 0.52);
    canvas.drawLine(top, center, facet);
    canvas.drawLine(left, center, facet);
    canvas.drawLine(right, center, facet);
    canvas.drawLine(bottom, center, facet);
    canvas.drawLine(left, right, facet);

    if (size.shortestSide >= 18) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'D$sides',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: size.shortestSide * 0.25,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PolyhedralDiePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.sides != sides;
  }
}

class _DiceGemClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.50, 0)
      ..lineTo(size.width * 0.84, size.height * 0.10)
      ..lineTo(size.width, size.height * 0.42)
      ..lineTo(size.width * 0.78, size.height * 0.82)
      ..lineTo(size.width * 0.50, size.height)
      ..lineTo(size.width * 0.22, size.height * 0.82)
      ..lineTo(0, size.height * 0.42)
      ..lineTo(size.width * 0.16, size.height * 0.10)
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
      Offset(size.width * 0.84, size.height * 0.10),
      Offset(size.width, size.height * 0.42),
      Offset(size.width * 0.78, size.height * 0.82),
      Offset(size.width * 0.50, size.height),
      Offset(size.width * 0.22, size.height * 0.82),
      Offset(0, size.height * 0.42),
      Offset(size.width * 0.16, size.height * 0.10),
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
      final combatant = combatants[index];
      if (combatant.team != activeTeam && combatant.hp > 0) {
        targets.add(_IndexedCombatant(index, combatant));
      }
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
          if (targets.isEmpty)
            Text(
              'No hostile targets available.',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: targets.map((entry) {
                final target = entry.combatant;
                final selected = entry.index == targetIndex;
                final color = tokens.accentAction;

                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => onSelectTarget(entry.index),
                  avatar: const Icon(
                    Icons.crisis_alert_outlined,
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

enum _CombatRollMode { normal, advantage, disadvantage }

enum _CombatWorkspace { turn, log, overview }

enum _CombatAccentKind { read, action, magic, support, info }

enum _CombatLogEntryType { system, turn, roll }

class _CombatCharacterSnapshot {
  final String characterId;
  final int currentHp;
  final int tempHp;
  final Map<String, int> resources;

  const _CombatCharacterSnapshot({
    required this.characterId,
    required this.currentHp,
    required this.tempHp,
    required this.resources,
  });
}

class _Combatant {
  final String id;
  final String? sourceId;
  final String? ownerUserId;
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
    this.sourceId,
    this.ownerUserId,
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
    String? sourceId,
    String? ownerUserId,
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
      sourceId: sourceId ?? this.sourceId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
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

class _BattleBoardFloatingController extends StatefulWidget {
  final String sceneId;
  final String displayUrl;
  final List<_Combatant> combatants;
  final String selectedCombatantId;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClose;
  final ValueChanged<String> onSelectCombatant;
  final Future<void> Function(String combatantId, int dx, int dy) onMove;
  final Future<void> Function() onOpenDisplay;
  final Future<void> Function() onSyncState;

  const _BattleBoardFloatingController({
    required this.sceneId,
    required this.displayUrl,
    required this.combatants,
    required this.selectedCombatantId,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onClose,
    required this.onSelectCombatant,
    required this.onMove,
    required this.onOpenDisplay,
    required this.onSyncState,
  });

  @override
  State<_BattleBoardFloatingController> createState() =>
      _BattleBoardFloatingControllerState();
}

class _BattleBoardFloatingControllerState
    extends State<_BattleBoardFloatingController> {
  late String _selectedCombatantId;
  bool _moving = false;
  bool _openingDisplay = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _selectedCombatantId = widget.selectedCombatantId;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final boardProvider = context.watch<BattleBoardProvider>();
    if (widget.combatants.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedCombatant = widget.combatants.firstWhere(
      (combatant) => combatant.id == _selectedCombatantId,
      orElse: () => widget.combatants.first,
    );
    final boardToken = boardProvider.tokens.where(
      (token) =>
          token.sceneId == widget.sceneId &&
          token.refId == selectedCombatant.id,
    );
    final positionLabel = boardToken.isEmpty
        ? 'Loading position'
        : 'Grid ${boardToken.first.x}, ${boardToken.first.y}';
    final canMove = !_moving && boardToken.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: widget.expanded ? 360 : 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.panel.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(color: tokens.border.withValues(alpha: 0.65)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view_rounded, color: tokens.accentAction),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.expanded
                        ? 'Board controller'
                        : selectedCombatant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Open display',
                  onPressed: _openingDisplay ? null : _openDisplay,
                  icon: _openingDisplay
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_new_rounded),
                ),
                IconButton(
                  tooltip: widget.expanded ? 'Minimize' : 'Expand',
                  onPressed: widget.onToggleExpanded,
                  icon: Icon(
                    widget.expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Hide board controls',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (!widget.expanded) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      positionLabel,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _MovementStrip(
                    enabled: canMove,
                    onMove: _move,
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Virtual monitor URL',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      widget.displayUrl,
                      maxLines: 2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCombatantId,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  prefixIcon: Icon(Icons.adjust_rounded),
                ),
                items: [
                  for (final combatant in widget.combatants)
                    DropdownMenuItem<String>(
                      value: combatant.id,
                      child: Text(
                        combatant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (combatantId) {
                  if (combatantId == null) return;
                  setState(() {
                    _selectedCombatantId = combatantId;
                  });
                  widget.onSelectCombatant(combatantId);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedCombatant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$positionLabel - 1 square = 5 ft',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _MovementPad(
                    enabled: canMove,
                    onMove: _move,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _syncing ? null : _syncState,
                      icon: _syncing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: const Text('Sync HP'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openingDisplay ? null : _openDisplay,
                      icon: const Icon(Icons.tv_rounded),
                      label: const Text('Display'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDisplay() async {
    if (_openingDisplay) return;
    setState(() {
      _openingDisplay = true;
    });
    try {
      await widget.onOpenDisplay();
    } finally {
      if (mounted) {
        setState(() {
          _openingDisplay = false;
        });
      }
    }
  }

  Future<void> _syncState() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
    });
    try {
      await widget.onSyncState();
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _move(int dx, int dy) async {
    if (_moving) return;
    setState(() {
      _moving = true;
    });
    try {
      await widget.onMove(_selectedCombatantId, dx, dy);
    } finally {
      if (mounted) {
        setState(() {
          _moving = false;
        });
      }
    }
  }
}

class _MovementStrip extends StatelessWidget {
  final bool enabled;
  final void Function(int dx, int dy) onMove;

  const _MovementStrip({
    required this.enabled,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MoveButton(
          icon: Icons.keyboard_arrow_left_rounded,
          enabled: enabled,
          onPressed: () => onMove(-1, 0),
        ),
        _MoveButton(
          icon: Icons.keyboard_arrow_up_rounded,
          enabled: enabled,
          onPressed: () => onMove(0, -1),
        ),
        _MoveButton(
          icon: Icons.keyboard_arrow_down_rounded,
          enabled: enabled,
          onPressed: () => onMove(0, 1),
        ),
        _MoveButton(
          icon: Icons.keyboard_arrow_right_rounded,
          enabled: enabled,
          onPressed: () => onMove(1, 0),
        ),
      ],
    );
  }
}

class _MovementPad extends StatelessWidget {
  final bool enabled;
  final void Function(int dx, int dy) onMove;

  const _MovementPad({
    required this.enabled,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MoveButton(
            icon: Icons.keyboard_arrow_up_rounded,
            enabled: enabled,
            onPressed: () => onMove(0, -1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MoveButton(
                icon: Icons.keyboard_arrow_left_rounded,
                enabled: enabled,
                onPressed: () => onMove(-1, 0),
              ),
              const SizedBox(width: 40, height: 40),
              _MoveButton(
                icon: Icons.keyboard_arrow_right_rounded,
                enabled: enabled,
                onPressed: () => onMove(1, 0),
              ),
            ],
          ),
          _MoveButton(
            icon: Icons.keyboard_arrow_down_rounded,
            enabled: enabled,
            onPressed: () => onMove(0, 1),
          ),
        ],
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _MoveButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
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

class _MultiAttackProgress {
  final String actionKey;
  int stepIndex;
  int attackCount;
  int hitCount;
  int critCount;
  int totalDamage;
  int? pendingStepIndex;
  int? pendingTargetIndex;
  bool pendingCritical;
  String? lastHpLine;

  _MultiAttackProgress({
    required this.actionKey,
    this.stepIndex = 0,
    this.attackCount = 0,
    this.hitCount = 0,
    this.critCount = 0,
    this.totalDamage = 0,
    this.pendingStepIndex,
    this.pendingTargetIndex,
    this.pendingCritical = false,
    this.lastHpLine,
  });

  bool get hasPendingDamage =>
      pendingStepIndex != null && pendingTargetIndex != null;

  void clearPendingDamage() {
    pendingStepIndex = null;
    pendingTargetIndex = null;
    pendingCritical = false;
  }
}

class _ReadiedAction {
  final String combatantId;
  final _CombatAction action;
  final String trigger;
  final int round;
  final String? targetId;
  final bool concentrationRequired;

  const _ReadiedAction({
    required this.combatantId,
    required this.action,
    required this.trigger,
    required this.round,
    required this.targetId,
    required this.concentrationRequired,
  });
}

class _ActionEconomySnapshot {
  final bool actionSpent;
  final bool bonusActionSpent;
  final bool reactionSpent;
  final int movementAvailable;
  final String? readiedActionName;
  final String? readiedTrigger;

  const _ActionEconomySnapshot({
    required this.actionSpent,
    required this.bonusActionSpent,
    required this.reactionSpent,
    required this.movementAvailable,
    required this.readiedActionName,
    required this.readiedTrigger,
  });
}

class _ReactionOption {
  final int actorIndex;
  final _Combatant combatant;
  final _CombatAction action;
  final bool spent;
  final bool readied;
  final String? trigger;

  const _ReactionOption({
    required this.actorIndex,
    required this.combatant,
    required this.action,
    required this.spent,
    this.readied = false,
    this.trigger,
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

List<_IndexedCombatant> _indexedTeam(
  List<_Combatant> combatants,
  _CombatTeam team,
) {
  final entries = <_IndexedCombatant>[];
  for (var index = 0; index < combatants.length; index++) {
    if (combatants[index].team == team) {
      entries.add(_IndexedCombatant(index, combatants[index]));
    }
  }
  return entries;
}

T? _firstOrNull<T>(Iterable<T> items) {
  for (final item in items) {
    return item;
  }
  return null;
}

void _rollPrimaryAction(
  _CombatAction action,
  void Function(_CombatAction action, _CombatActionRoll rollType) onRollAction,
  ValueChanged<_CombatAction> onUseAction, {
  bool pendingDamage = false,
}) {
  if (action.hasMultiAttack) {
    onRollAction(
      action,
      pendingDamage ? _CombatActionRoll.damage : _CombatActionRoll.attack,
    );
    return;
  }
  if (pendingDamage && action.damageFormula != null) {
    onRollAction(action, _CombatActionRoll.damage);
    return;
  }
  if (action.attackFormula != null) {
    onRollAction(action, _CombatActionRoll.attack);
    return;
  }
  if (action.requiresSavingThrow) {
    onRollAction(action, _CombatActionRoll.savingThrow);
    return;
  }
  if (action.damageFormula != null) {
    onRollAction(action, _CombatActionRoll.damage);
    return;
  }
  onUseAction(action);
}

String _primaryActionLabel(_CombatAction action, bool pendingDamage) {
  if (action.hasMultiAttack) return pendingDamage ? 'Dano' : 'Ataque';
  if (pendingDamage && action.damageFormula != null) return 'Dano';
  if (action.attackFormula != null) return 'Tirar';
  if (action.requiresSavingThrow) return 'Salvar';
  if (action.damageFormula != null) return action.isHealing ? 'Curar' : 'Dano';
  return 'Usar';
}

String _primaryActionTooltip(_CombatAction action, bool pendingDamage) {
  final label = _primaryActionLabel(action, pendingDamage).toLowerCase();
  return '$label ${action.name}';
}

String? _actionStateLabel({
  required bool prepared,
  required bool spent,
  required bool pendingDamage,
  required bool blocked,
}) {
  if (pendingDamage) return 'DANO';
  if (blocked) return 'SIN REC';
  if (prepared) return 'PLAN';
  if (spent) return 'USADA';
  return null;
}

Color _actionStateColor({
  required bool prepared,
  required bool spent,
  required bool pendingDamage,
  required bool blocked,
  required Color fallback,
}) {
  if (pendingDamage) return const Color(0xFF246B3A);
  if (blocked) return _CinematicColors.blood;
  if (prepared) return _CinematicColors.goldBright;
  if (spent) return _CinematicColors.gold;
  return fallback;
}

String _cinematicActionDescription(
  _CombatAction action,
  _Combatant activeCombatant,
  _Combatant selectedTarget,
) {
  if (action.hasMultiAttack) {
    return '${activeCombatant.name} ejecuta ${action.multiAttackSteps.length} ataques contra ${selectedTarget.name}.';
  }
  if (action.targetsSelf && action.isHealing) {
    return '${activeCombatant.name} recupera puntos de golpe y mantiene la presion del turno.';
  }
  if (action.attackFormula != null && action.damageFormula != null) {
    return '${activeCombatant.name} ataca a ${selectedTarget.name}; si impacta, resuelve ${action.damageFormula}.';
  }
  if (action.requiresSavingThrow) {
    return '${selectedTarget.name} debe superar una salvacion ${action.saveAbility} contra DC ${action.saveDc}.';
  }
  if (action.damageFormula != null) {
    return action.isHealing
        ? 'Aplica curacion con ${action.damageFormula}.'
        : 'Aplica dano directo con ${action.damageFormula}.';
  }
  if (action.grantsAction) {
    return 'Recupera la economia del turno y habilita una accion adicional.';
  }
  final tags = action.tags.take(3).join(' - ');
  return tags.isEmpty ? action.type : tags;
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

String? _criticalFormulaForDamage(String formula) {
  final trimmed = formula.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(
    r'^(\d*)d(\d+)([+-]\d+)?$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (match == null) return trimmed;

  final rawCount = match.group(1);
  final count =
      rawCount == null || rawCount.isEmpty ? 1 : int.tryParse(rawCount) ?? 1;
  final sides = match.group(2);
  final modifier = match.group(3) ?? '';
  if (sides == null || sides.isEmpty) return trimmed;
  return '${count * 2}d$sides$modifier';
}
