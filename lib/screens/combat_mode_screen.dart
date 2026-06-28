// ignore_for_file: unused_element

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/combat/application/services/combat_board_token_lookup.dart';
import '../features/combat/application/services/combat_battle_board_session_service.dart';
import '../features/combat/application/services/combat_battle_board_sync_service.dart';
import '../features/combat/application/services/combat_dice_result_formatter.dart';
import '../features/combat/application/services/combat_dice_roll_coordinator.dart';
import '../features/combat/domain/models/combat_action.dart';
import '../features/combat/domain/models/combat_feedback.dart';
import '../features/combat/domain/models/combat_resolution_models.dart';
import '../features/combat/domain/models/combatant.dart';
import '../features/combat/domain/models/combat_turn_models.dart';
import '../features/combat/domain/models/pending_combat_attack.dart';
import '../features/combat/domain/rules/combat_board_geometry.dart';
import '../features/combat/domain/rules/combat_board_token_sizing.dart';
import '../features/combat/domain/rules/combat_damage_type_rules.dart';
import '../features/combat/presentation/widgets/action_deck/combat_action_chips.dart';
import '../features/combat/presentation/widgets/action_deck/combat_action_command_buttons.dart';
import '../features/combat/presentation/widgets/action_deck/combat_action_empty_states.dart';
import '../features/combat/presentation/widgets/action_deck/combat_action_frame.dart';
import '../features/combat/presentation/widgets/action_deck/combat_catalog_filter_chip.dart';
import '../features/combat/presentation/widgets/action_deck/combat_command_timing_button.dart';
import '../features/combat/presentation/widgets/action_deck/combat_parchment_controls.dart';
import '../features/combat/presentation/widgets/action_deck/combat_roll_mode_toggle.dart';
import '../features/combat/presentation/widgets/action_deck/combat_action_sheets.dart';
import '../features/combat/presentation/widgets/battle_board/combat_movement_controls.dart';
import '../features/combat/presentation/widgets/battle_board/battle_board_floating_controller.dart';
import '../features/combat/presentation/class_widgets/monk/monk_combat_flow_models.dart';
import '../features/combat/presentation/widgets/combat_arena_backdrop.dart';
import '../features/combat/presentation/widgets/combat_log/combat_feed_window.dart';
import '../features/combat/presentation/widgets/combat_mode_debug_banner.dart';
import '../features/combat/presentation/widgets/player_panel/combat_player_panel.dart';
import '../features/combat/presentation/widgets/setup/combat_setup_primitives.dart';
import '../features/combat/presentation/widgets/setup/combat_setup_view.dart';
import '../features/combat/presentation/widgets/targeting/combat_target_strip.dart';
import '../features/combat/presentation/widgets/turn_header/combat_active_header.dart';
import '../features/combat/presentation/widgets/shared/combat_accent_colors.dart';
import '../features/combat/presentation/widgets/shared/combat_cinematic_buttons.dart';
import '../features/combat/presentation/widgets/shared/combat_cinematic_primitives.dart';
import '../features/combat/presentation/widgets/shared/combat_compact_controls.dart';
import '../features/combat/presentation/widgets/shared/combat_console_badges.dart';
import '../features/combat/presentation/widgets/shared/combat_metric_widgets.dart';
import '../features/combat/presentation/widgets/shared/combat_hp_widgets.dart';
import '../features/combat/presentation/widgets/shared/combat_portrait_widgets.dart';
import '../features/combat/presentation/widgets/shared/combat_status_chip.dart';
import '../features/dice/models/dice_roll_result.dart';
import '../features/dice/services/dice_roller_service.dart';
import '../features/dice/widgets/dice_roller_modal.dart';
import '../models/character.dart';
import '../models/battle_scene.dart';
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
import '../services/class_data_service.dart';
import '../services/combat_encounter_engine.dart';
import '../services/custom_monster_repository.dart';
import '../services/dice_color_preferences_service.dart';
import '../services/monk_combat_kit_service.dart';
import '../services/monster_repository.dart';
import '../theme.dart';
import '../utils/external_url_launcher.dart';
import '../widgets/stitch_navigation.dart';

const _battleBoardEventVisibleDuration = Duration(seconds: 15);
const _showCombatModeDebugBanner = false;

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
  late List<Combatant> _combatants;
  late List<CombatLogEntry> _activity;
  late List<CombatAction> _characterActions;
  encounter_models.CombatEncounter? _encounter;
  final Map<String, encounter_models.PreparedCombatAction> _engineActions = {};
  final Map<String, CombatCharacterSnapshot> _pendingCharacterCombatSnapshots =
      {};
  Timer? _combatSnapshotFlushTimer;
  final Map<String, List<CombatAction>> _partyActionsByCombatantId = {};
  final Map<String, List<CombatAction>> _enemyActionsByCombatantId = {};
  CharacterProvider? _characterProvider;
  CombatRollFeedback? _rollFeedback;
  final CombatBattleBoardSyncService _battleBoardSyncService =
      const CombatBattleBoardSyncService();
  final Set<String> _spentTimings = {};
  final Set<String> _pendingDamageActions = {};
  final Set<String> _pendingHalfDamageActions = {};
  PendingAreaSavingThrow? _pendingAreaSavingThrow;
  final Set<String> _spentReactionCombatantIds = {};
  final Set<String> _inactivePartyCombatantIds = {};
  final Set<String> _oncePerTurnActionUses = {};
  final Set<String> _flurryUsedThisTurnCombatantIds = {};
  final Set<String> _martialArtsEligibleCombatantIds = {};
  final Map<String, int> _actionAttackUsesByCombatantId = {};
  final Map<String, int> _movementBonusFeetByCombatantId = {};
  final Map<String, CombatAction> _preparedActions = {};
  final Map<String, ReadiedAction> _readiedActionsByCombatantId = {};
  final List<CombatAction> _queuedPreparedActions = [];
  int _queuedPreparedIndex = 0;
  int _activeIndex = 0;
  int _targetIndex = 2;
  int _round = 1;
  String _selectedCommandTiming = 'Action';
  CombatWorkspace _workspace = CombatWorkspace.turn;
  late bool _dmView;
  bool _devCombatMode = false;
  bool _seededMonsters = false;
  bool _combatStarted = false;
  bool _openingBattleBoard = false;
  bool _showBattleBoardController = false;
  bool _battleBoardControllerExpanded = true;
  bool _combatRollInFlight = false;
  final Set<String> _activeCombatResolutionKeys = {};
  String? _activeBattleBoardSceneId;
  String? _selectedBattleBoardCombatantId;
  CombatAction? _focusedBattleBoardAction;
  final CombatDiceRollCoordinator _diceRollCoordinator =
      CombatDiceRollCoordinator();
  final Map<String, int> _battleBoardMovementUsedByCombatantId = {};
  final Map<String, math.Point<int>> _queuedBattleBoardMovesByCombatantId = {};
  final Set<String> _battleBoardMoveInFlightCombatantIds = {};
  bool _restoringBattleBoardScene = false;
  Color _diceColor = DiceColorPreferencesService.defaultColor;
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
  String? _sessionRestoreAttemptCampaignId;
  CombatRollMode _rollMode = CombatRollMode.normal;
  MultiAttackProgress? _multiAttackProgress;

  bool get _hasRouteCharacterId {
    final characterId = widget.characterId?.trim();
    return characterId != null && characterId.isNotEmpty;
  }

  String? get _queuedPreparedActionName {
    if (_queuedPreparedActions.isEmpty ||
        _queuedPreparedIndex < 0 ||
        _queuedPreparedIndex >= _queuedPreparedActions.length) {
      return null;
    }
    return _queuedPreparedActions[_queuedPreparedIndex].name;
  }

  bool get _hasAdvantage => _rollMode == CombatRollMode.advantage;

  bool get _hasDisadvantage => _rollMode == CombatRollMode.disadvantage;

  void _selectRollMode(CombatRollMode mode) {
    if (_rollMode == mode) return;
    setState(() {
      _rollMode = mode;
    });
  }

  void _clearMultiAttackProgress() {
    _multiAttackProgress = null;
  }

  void _clearClassTurnFlowState({String? combatantId}) {
    if (combatantId == null) {
      _flurryUsedThisTurnCombatantIds.clear();
      _martialArtsEligibleCombatantIds.clear();
      return;
    }
    _flurryUsedThisTurnCombatantIds.remove(combatantId);
    _martialArtsEligibleCombatantIds.remove(combatantId);
  }

  bool _beginCombatResolution(String key) {
    if (_activeCombatResolutionKeys.contains(key)) {
      return false;
    }
    _activeCombatResolutionKeys.add(key);
    return true;
  }

  void _endCombatResolution(String key) {
    _activeCombatResolutionKeys.remove(key);
  }

  String _combatResolutionKey(
    String phase,
    CombatAction action, {
    CombatActionRoll? rollType,
    int? targetIndex,
    int? stepIndex,
    String? actorId,
  }) {
    final targetId = targetIndex == null ||
            targetIndex < 0 ||
            targetIndex >= _combatants.length
        ? 'target:${_targetIndex.clamp(0, _combatants.length - 1)}'
        : _combatants[targetIndex].id;
    final roll = rollType == null ? '' : ':${rollType.name}';
    final step = stepIndex == null ? '' : ':step$stepIndex';
    return [
          phase,
          actorId ?? _activeCombatant.id,
          _actionExecutionKey(action),
          targetId,
        ].join(':') +
        roll +
        step;
  }

  static const List<CombatAction> _playerActions = [
    CombatAction(
      name: 'Longsword Strike',
      type: 'Weapon Attack',
      timing: 'Action',
      attackFormula: 'd20+7',
      damageFormula: '1d8+4',
      critFormula: '2d8+4',
      rangeFeet: 5,
      tags: ['Melee', 'Slashing', 'Prepared'],
      icon: Icons.gavel_outlined,
      accentKind: CombatAccentKind.action,
    ),
    CombatAction(
      name: 'Fire Bolt',
      type: 'Spell Attack',
      timing: 'Action',
      attackFormula: 'd20+6',
      damageFormula: '2d10',
      critFormula: '4d10',
      rangeFeet: 120,
      tags: ['Ranged', 'Fire', 'Cantrip'],
      icon: Icons.local_fire_department_outlined,
      accentKind: CombatAccentKind.magic,
    ),
    CombatAction(
      name: 'Second Wind',
      type: 'Feature',
      timing: 'Bonus Action',
      attackFormula: null,
      damageFormula: '1d10+3',
      critFormula: null,
      tags: ['Healing', '1 / Short Rest'],
      icon: Icons.favorite_border,
      accentKind: CombatAccentKind.support,
      targetsSelf: true,
      isHealing: true,
    ),
  ];

  static const List<CombatAction> _enemyActions = [
    CombatAction(
      name: 'Commander Blade',
      type: 'Weapon Attack',
      timing: 'Action',
      attackFormula: 'd20+5',
      damageFormula: '1d8+3',
      critFormula: '2d8+3',
      rangeFeet: 5,
      tags: ['Melee', 'Martial', 'Enemy'],
      icon: Icons.gavel_outlined,
      accentKind: CombatAccentKind.action,
    ),
    CombatAction(
      name: 'Shortbow Shot',
      type: 'Ranged Attack',
      timing: 'Action',
      attackFormula: 'd20+4',
      damageFormula: '1d6+2',
      critFormula: '2d6+2',
      rangeFeet: 80,
      tags: ['Ranged', 'Piercing', 'Enemy'],
      icon: Icons.ads_click_outlined,
      accentKind: CombatAccentKind.read,
    ),
    CombatAction(
      name: 'Rallying Cry',
      type: 'Monster Feature',
      timing: 'Bonus Action',
      attackFormula: null,
      damageFormula: '1d6+2',
      critFormula: null,
      tags: ['Morale', 'Healing', 'Enemy'],
      icon: Icons.record_voice_over_outlined,
      accentKind: CombatAccentKind.support,
      targetsSelf: true,
      isHealing: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _dmView = !_hasRouteCharacterId;
    _combatants = _buildDefaultCombatants();
    _characterActions = _playerActions;
    _activity = [
      CombatLogEntry.system(
        'Encounter prototype ready. Initiative order is loaded.',
      ),
    ];
    _encounter = _createEncounterFromCombatants(_combatants);
    _syncUiFromEncounter();
    _loadMonsterCatalog();
    _loadCustomMonsterCatalog();
    _loadRealDemoMonsters();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadDiceColorPreference());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _characterProvider = context.read<CharacterProvider?>();
    _seedCombatContextIfNeeded(listenToCampaign: true);
  }

  @override
  void dispose() {
    _combatSnapshotFlushTimer?.cancel();
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
    if (oldWidget.characterId != widget.characterId) {
      _dmView = !_hasRouteCharacterId;
    }
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

    final characterId = widget.characterId?.trim();
    if (characterId != null && characterId.isNotEmpty) {
      final character = listen
          ? context.watch<CharacterProvider>().getCharacterById(characterId)
          : context.read<CharacterProvider>().getCharacterById(characterId);
      final campaignId = character?.campaignId?.trim();
      if (campaignId != null && campaignId.isNotEmpty) return campaignId;
    }

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
    _queueNormalizedMonkCombatKitHydration(
      character,
      combatBuild.combatant.id,
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
      CombatLogEntry.system(
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
          _queueNormalizedMonkCombatKitHydration(
            character,
            combatBuild.combatant.id,
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
      CombatLogEntry.system(
        'Encounter prototype ready. Initiative order is loaded.',
      ),
    ];
    _engineActions.clear();
    _partyActionsByCombatantId.clear();
    _enemyActionsByCombatantId.clear();
    _encounter = _createEncounterFromCombatants(_combatants);
    _syncUiFromEncounter();
    _rollFeedback = null;
    _activeCombatResolutionKeys.clear();
    _spentTimings.clear();
    _clearClassTurnFlowState();
    _actionAttackUsesByCombatantId.clear();
    _movementBonusFeetByCombatantId.clear();
    _pendingDamageActions.clear();
    _pendingHalfDamageActions.clear();
    _pendingAreaSavingThrow = null;
    _spentReactionCombatantIds.clear();
    _inactivePartyCombatantIds.clear();
    _oncePerTurnActionUses.clear();
    _readiedActionsByCombatantId.clear();
    _clearMultiAttackProgress();
    _preparedActions.clear();
    _resetQueuedPreparedActions();
    _activeIndex = 0;
    _targetIndex = _findDefaultTargetIndex(_activeIndex);
    _round = 1;
    _selectedCommandTiming = 'Action';
    _workspace = CombatWorkspace.turn;
    _seededMonsters = false;
    _stagedCustomMonsterCounts.clear();
    _combatStarted = false;
    _seededCharacterId = null;
    _loadingCampaignId = null;
    _loadedPartyCampaignId = null;
    _sessionRestoreAttemptCampaignId = null;
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

  void _queueNormalizedMonkCombatKitHydration(
    Character character,
    String combatantId,
  ) {
    unawaited(
      _hydrateNormalizedMonkCombatKit(
        character: character,
        combatantId: combatantId,
      ),
    );
  }

  Future<void> _hydrateNormalizedMonkCombatKit({
    required Character character,
    required String combatantId,
  }) async {
    final monkLevel = _classLevelForCharacter(character, 'monk');
    if (monkLevel <= 0) return;
    final subclassName = _subclassForCharacterClass(character, 'monk');
    if (subclassName == null || subclassName.trim().isEmpty) return;

    final progression = await ClassDataService.loadSubclassProgression(
      'Monk',
      subclassName,
    );
    if (!mounted) return;

    final subclassFeatures = <Map<String, dynamic>>[
      for (final entry in progression.entries)
        if (entry.key <= monkLevel)
          for (final feature in entry.value)
            {
              'name': feature.name,
              'description': feature.description,
              'source': 'subclass',
              'level': feature.level,
              'dataSource': 'classes_normalized',
            },
    ];

    final update = <String, dynamic>{
      'monkSubclass': subclassName.trim(),
      'monkSubclassFeatures': subclassFeatures,
      'monkCombatDataSource': 'classes_normalized',
    };

    setState(() {
      final currentCombatant = _firstOrNull(
        _combatants.where((combatant) => combatant.id == combatantId),
      );
      final subclassActions = currentCombatant == null
          ? const <CombatAction>[]
          : _normalizedMonkSubclassCombatActions(
              combatant: currentCombatant,
              subclassName: subclassName,
              featureEntries: subclassFeatures,
            );
      if (subclassActions.isNotEmpty) {
        final existingActions =
            _partyActionsByCombatantId[combatantId] ?? const <CombatAction>[];
        final mergedActions = _dedupeUiActions([
          ...existingActions,
          ...subclassActions,
        ]);
        _partyActionsByCombatantId[combatantId] = mergedActions;
        if (_activeCombatant.id == combatantId) {
          _characterActions = mergedActions;
        }
      }

      _combatants = [
        for (final combatant in _combatants)
          if (combatant.id == combatantId)
            combatant.copyWith(
              metadata: {
                ...combatant.metadata,
                ...update,
              },
            )
          else
            combatant,
      ];

      final encounter = _encounter;
      if (encounter != null) {
        _encounter = encounter.copyWith(
          combatants: [
            for (final combatant in encounter.combatants)
              if (combatant.id == combatantId)
                combatant.copyWith(
                  metadata: {
                    ...combatant.metadata,
                    ...update,
                  },
                )
              else
                combatant,
          ],
        );
      }
    });
  }

  List<CombatAction> _normalizedMonkSubclassCombatActions({
    required Combatant combatant,
    required String subclassName,
    required List<Map<String, dynamic>> featureEntries,
  }) {
    final resourcePool =
        _encounter?.combatantById(combatant.id)?.resources ?? const {};
    final kiResourceKey = _resourceKeyWhere(
            resourcePool.keys, _isKiResourceKey) ??
        _resourceKeyWhere(combatant.resourceMaximums.keys, _isKiResourceKey) ??
        'ki_points';
    final monkLevel = _monkLevelForCombatant(combatant);
    final proficiencyBonus = _proficiencyBonusForCombatant(combatant);
    final dexMod = _abilityModifierForCombatant(combatant, 'DEX');
    final wisMod = _abilityModifierForCombatant(combatant, 'WIS');
    final martialDie = _monkMartialArtsDie(monkLevel);
    final radiantAttackFormula =
        _formatRollFormula('d20', dexMod + proficiencyBonus);
    final martialWisFormula = _formatRollFormula(martialDie, wisMod);
    final radiantDamageFormula = _formatRollFormula(martialDie, dexMod);
    final normalizedSubclass = MonkCombatKitService.normalize(subclassName);
    final actions = <CombatAction>[];

    for (final feature in featureEntries) {
      final name = feature['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final detail = feature['description']?.toString().trim() ?? '';
      final text = MonkCombatKitService.normalize('$name $detail');
      final idBase = MonkCombatKitService.normalize(name)
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final actionId = '${combatant.id}:normalized_monk_subclass:$idBase';

      if (text.contains('shadow arts')) {
        actions.add(
          CombatAction(
            id: actionId,
            name: 'Shadow Arts',
            type: 'Monk Tradition',
            timing: 'Action',
            attackFormula: null,
            damageFormula: null,
            critFormula: null,
            tags: const [
              'Monk',
              'Shadow',
              'Ki',
              'Subclass',
              'Spell-like',
              'classes_normalized',
            ],
            icon: Icons.nights_stay_outlined,
            accentKind: CombatAccentKind.magic,
            resourceKey: kiResourceKey,
            resourceCost: 2,
            targetsSelf: true,
            targetPolicy: 'self',
          ),
        );
        continue;
      }

      if (text.contains('hand of healing')) {
        actions.add(
          CombatAction(
            id: actionId,
            name: 'Hand of Healing',
            type: 'Monk Tradition',
            timing: 'Action',
            attackFormula: null,
            damageFormula: martialWisFormula,
            critFormula: null,
            tags: const [
              'Monk',
              'Mercy',
              'Ki',
              'Healing',
              'Subclass',
              'classes_normalized',
            ],
            icon: Icons.healing_outlined,
            accentKind: CombatAccentKind.support,
            resourceKey: kiResourceKey,
            resourceCost: 1,
            targetPolicy: 'ally',
            isHealing: true,
          ),
        );
        continue;
      }

      if (text.contains('hand of harm')) {
        actions.add(
          CombatAction(
            id: actionId,
            name: 'Hand of Harm',
            type: 'Monk Tradition',
            timing: 'Free',
            attackFormula: null,
            damageFormula: martialWisFormula,
            damageType: 'necrotic',
            critFormula: _criticalFormulaForDamage(martialWisFormula),
            tags: const [
              'Monk',
              'Mercy',
              'Ki',
              'On Hit',
              'Necrotic',
              'Subclass',
              'classes_normalized',
            ],
            icon: Icons.back_hand_outlined,
            accentKind: CombatAccentKind.magic,
            resourceKey: kiResourceKey,
            resourceCost: 1,
            targetPolicy: 'hostile',
          ),
        );
        continue;
      }

      if (text.contains('radiant sun bolt')) {
        actions.add(
          CombatAction(
            id: actionId,
            name: 'Radiant Sun Bolt',
            type: 'Monk Tradition',
            timing: 'Action',
            attackFormula: radiantAttackFormula,
            damageFormula: radiantDamageFormula,
            damageType: 'radiant',
            critFormula: _criticalFormulaForDamage(radiantDamageFormula),
            rangeFeet: 30,
            tags: const [
              'Monk',
              'Sun Soul',
              'Ranged spell attack',
              'Radiant',
              'Subclass',
              'classes_normalized',
            ],
            icon: Icons.wb_sunny_outlined,
            accentKind: CombatAccentKind.magic,
            targetPolicy: 'hostile',
            usesAttackAction: true,
            actionAttackSlots: monkLevel >= 5 ? 2 : 1,
          ),
        );
        continue;
      }

      if (text.contains('arms of the astral self')) {
        actions.add(
          CombatAction(
            id: actionId,
            name: 'Arms of the Astral Self',
            type: 'Monk Tradition',
            timing: 'Bonus Action',
            attackFormula: null,
            damageFormula: null,
            critFormula: null,
            tags: const [
              'Monk',
              'Astral Self',
              'Ki',
              'Subclass',
              'classes_normalized',
            ],
            icon: Icons.auto_awesome_outlined,
            accentKind: CombatAccentKind.magic,
            resourceKey: kiResourceKey,
            resourceCost: 1,
            targetsSelf: true,
            targetPolicy: 'self',
          ),
        );
        continue;
      }

      if (text.contains("kensei's shot") || text.contains('kensei shot')) {
        actions.add(
          CombatAction(
            id: actionId,
            name: "Kensei's Shot",
            type: 'Monk Tradition',
            timing: 'Bonus Action',
            attackFormula: null,
            damageFormula: null,
            critFormula: null,
            tags: const [
              'Monk',
              'Kensei',
              'Bonus Action',
              'Ranged weapon',
              'Subclass',
              'classes_normalized',
            ],
            icon: Icons.track_changes_outlined,
            accentKind: CombatAccentKind.info,
            targetsSelf: true,
            targetPolicy: 'self',
          ),
        );
        continue;
      }

      if (text.contains('elemental attunement') ||
          (normalizedSubclass.contains('four elements') &&
              text.contains('discipline'))) {
        actions.add(
          CombatAction(
            id: actionId,
            name: name,
            type: 'Monk Discipline',
            timing: 'Action',
            attackFormula: null,
            damageFormula: null,
            critFormula: null,
            tags: const [
              'Monk',
              'Four Elements',
              'Subclass',
              'classes_normalized',
            ],
            icon: Icons.blur_on_outlined,
            accentKind: CombatAccentKind.magic,
            targetsSelf: true,
            targetPolicy: 'self',
          ),
        );
      }
    }

    return actions;
  }

  int _monkLevelForCombatant(Combatant combatant) {
    final classLevels = combatant.metadata['classLevels'];
    if (classLevels is Map) {
      for (final entry in classLevels.entries) {
        final key = MonkCombatKitService.normalize(entry.key.toString());
        if (!key.contains('monk') && !key.contains('monje')) continue;
        final value = entry.value;
        return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      }
    }
    return 0;
  }

  int _proficiencyBonusForCombatant(Combatant combatant) {
    final raw = combatant.metadata['proficiencyBonus'];
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed != null) return parsed;
    final level = math.max(1, _monkLevelForCombatant(combatant));
    return 2 + ((level - 1) ~/ 4);
  }

  int _abilityModifierForCombatant(Combatant combatant, String ability) {
    final score = _intFromDynamicMap(
          combatant.metadata['abilityScores'],
          ability.toUpperCase(),
        ) ??
        10;
    return ((score - 10) / 2).floor();
  }

  int _classLevelForCharacter(Character character, String className) {
    final target = MonkCombatKitService.normalize(className);
    var result = 0;
    for (final entry in character.classLevels.entries) {
      if (MonkCombatKitService.normalize(entry.key) != target) continue;
      result = math.max(result, entry.value);
    }
    return result;
  }

  String? _subclassForCharacterClass(Character character, String className) {
    final target = MonkCombatKitService.normalize(className);
    for (final entry in character.classLevels.entries) {
      if (MonkCombatKitService.normalize(entry.key) != target) continue;
      final subclass = character.subclassForClass(entry.key)?.trim();
      if (subclass != null && subclass.isNotEmpty) return subclass;
    }
    final legacySubclass = character.subclass?.trim();
    if (MonkCombatKitService.normalize(character.charClass) == target &&
        legacySubclass != null &&
        legacySubclass.isNotEmpty) {
      return legacySubclass;
    }
    return null;
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
      _clearClassTurnFlowState();
      _actionAttackUsesByCombatantId.clear();
      _movementBonusFeetByCombatantId.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _pendingAreaSavingThrow = null;
      _spentReactionCombatantIds.clear();
      _inactivePartyCombatantIds.removeWhere(
        (id) => !partyBuilds.any((build) => build.combatant.id == id),
      );
      _oncePerTurnActionUses.clear();
      _readiedActionsByCombatantId.clear();
      _clearMultiAttackProgress();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _rollFeedback = CombatRollFeedback.manual(
        actor: 'DM',
        action: 'Combat begins',
        headline: 'COMBAT BEGINS',
        subline: '${partyBuilds.length} heroes enter initiative.',
        accentKind: CombatAccentKind.magic,
      );
      _activity = [
        CombatLogEntry.turn(
          'Combat begins. ${partyBuilds.length} campaign characters joined the encounter.',
        ),
        ..._activity,
      ];
      _loadedPartyCampaignId = campaignId;
      _loadingCampaignId = null;
    });

    for (var index = 0; index < partyBuilds.length; index++) {
      _queueNormalizedMonkCombatKitHydration(
        orderedCharacters[index],
        partyBuilds[index].combatant.id,
      );
    }

    final restoredSession =
        await _restoreActiveCombatSessionForCampaign(campaignId);
    if (restoredSession) {
      for (var index = 0; index < partyBuilds.length; index++) {
        _queueNormalizedMonkCombatKitHydration(
          orderedCharacters[index],
          partyBuilds[index].combatant.id,
        );
      }
      return;
    }

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
          CombatLogEntry.system(
            'Combat opened for this campaign, but no party characters were found.',
          ),
        );
      });
      unawaited(_restoreActiveCombatSessionForCampaign(normalizedCampaignId));
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
        .where((combatant) => combatant.team == CombatTeam.enemy)
        .map(_engineCombatantFromUi)
        .toList(growable: false);
  }

  List<encounter_models.Combatant> _freshDemoEnemyCombatants() {
    return _buildDefaultCombatants()
        .where((combatant) => combatant.team == CombatTeam.enemy)
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
          CombatLogEntry.system('Bestiary load failed: $error'),
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
                    color: CombatCinematicColors.blood.withValues(alpha: 0.34),
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
                                CombatCompactNumberField(
                                  controller: strController,
                                  label: 'STR',
                                ),
                                const SizedBox(width: 8),
                                CombatCompactNumberField(
                                  controller: dexController,
                                  label: 'DEX',
                                ),
                                const SizedBox(width: 8),
                                CombatCompactNumberField(
                                  controller: conController,
                                  label: 'CON',
                                ),
                                const SizedBox(width: 8),
                                CombatCompactNumberField(
                                  controller: intController,
                                  label: 'INT',
                                ),
                                const SizedBox(width: 8),
                                CombatCompactNumberField(
                                  controller: wisController,
                                  label: 'WIS',
                                ),
                                const SizedBox(width: 8),
                                CombatCompactNumberField(
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
                                color: CombatCinematicColors.paper,
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
                                color: CombatCinematicColors.gold
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
                                  color: CombatCinematicColors.goldBright,
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
                                          color: CombatCinematicColors.paper,
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
                    color: CombatCinematicColors.gold.withValues(alpha: 0.28),
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
    if (_activeSetupPartyCount == 0) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            'Select at least one party member before combat begins.',
          ),
        );
      });
      return;
    }
    if (stagedEnemyCount == 0) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system('Add at least one enemy before combat begins.'),
        );
      });
      return;
    }
    await _applyStagedMonsterSetup(beginCombat: true);
    if (!mounted || _combatants.isEmpty) return;
    setState(() {
      _battleBoardMovementUsedByCombatantId
        ..clear()
        ..[_activeCombatant.id] = 0;
    });
    if (_showBattleBoardController) {
      unawaited(_syncBattleBoardTokensFromCombatState());
    }
    final campaignId = _resolvedCampaignId(listen: false);
    if (campaignId != null && campaignId.isNotEmpty) {
      final sceneId = await _ensureBattleBoardScene();
      if (!mounted || sceneId == null) return;
      await _syncBattleBoardTokensFromCombatState();
    }
  }

  int get _activeSetupPartyCount {
    return _combatants
        .where(
          (combatant) =>
              combatant.team == CombatTeam.party &&
              !_inactivePartyCombatantIds.contains(combatant.id),
        )
        .length;
  }

  void _toggleSetupPartyCombatant(String combatantId, bool active) {
    setState(() {
      if (active) {
        _inactivePartyCombatantIds.remove(combatantId);
      } else {
        _inactivePartyCombatantIds.add(combatantId);
      }
    });
  }

  CombatCharacterSnapshot? _characterSnapshotForCombatantId(
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
      return CombatCharacterSnapshot(
        characterId: characterId.trim(),
        currentHp: engineCombatant.hp,
        tempHp: engineCombatant.tempHp,
        resources: Map<String, int>.from(engineCombatant.resources),
      );
    }

    final uiIndex =
        _combatants.indexWhere((combatant) => combatant.id == combatantId);
    if (uiIndex == -1 || _combatants[uiIndex].team != CombatTeam.party) {
      return null;
    }
    final uiCombatant = _combatants[uiIndex];
    final characterId = uiCombatant.sourceId;
    if (characterId == null || characterId.trim().isEmpty) return null;
    return CombatCharacterSnapshot(
      characterId: characterId.trim(),
      currentHp: uiCombatant.hp,
      tempHp: uiCombatant.tempHp,
      resources: const {},
    );
  }

  void _queueCharacterCombatSnapshot(
    String combatantId, {
    bool flushNow = false,
  }) {
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
    if (flushNow) {
      unawaited(_flushCharacterCombatState());
      return;
    }
    _scheduleCharacterCombatSnapshotFlush();
  }

  void _scheduleCharacterCombatSnapshotFlush() {
    _combatSnapshotFlushTimer?.cancel();
    _combatSnapshotFlushTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      unawaited(_flushCharacterCombatState());
    });
  }

  Future<void> _flushCharacterCombatState() async {
    _combatSnapshotFlushTimer?.cancel();
    _combatSnapshotFlushTimer = null;
    final snapshots = _pendingCharacterCombatSnapshots.values.toList(
      growable: false,
    );
    _pendingCharacterCombatSnapshots.clear();
    await _flushCharacterCombatSnapshots(snapshots);
  }

  Future<void> _flushCharacterCombatSnapshots(
    List<CombatCharacterSnapshot> snapshots,
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
        CombatLogEntry.system(
          'HP ajustado: ${combatant.name} ${delta < 0 ? 'pierde' : 'recupera'} ${delta.abs()} HP.',
        ),
      );
    });
    _queueCharacterCombatSnapshot(combatant.id, flushNow: true);
    if (_showBattleBoardController) {
      unawaited(_syncBattleBoardTokensFromCombatState());
    }
  }

  Future<void> _openHpAdjustmentSheet(int combatantIndex) async {
    if (combatantIndex < 0 || combatantIndex >= _combatants.length) return;
    final combatant = _combatants[combatantIndex];
    if (!_ensureCanControlCombatant(
      combatant,
      actionLabel: 'ajustar HP',
    )) {
      return;
    }
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
          return CombatHpAdjustmentSheet(
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
            .where((combatant) => combatant.team == CombatTeam.party)
            .map(_engineCombatantFromUi)
            .toList(growable: false);
        final party = _partyForStagedEncounter(
          partyCombatants.isEmpty ? fallbackParty : partyCombatants,
          beginCombat: beginCombat,
        );

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
            CombatLogEntry.system('Encounter setup has no enemies staged.'),
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
          .where((combatant) => combatant.team == CombatTeam.party)
          .map(_engineCombatantFromUi)
          .toList(growable: false);
      final party = _partyForStagedEncounter(
        partyCombatants.isEmpty ? fallbackParty : partyCombatants,
        beginCombat: beginCombat,
      );

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
      _workspace = CombatWorkspace.turn;
      _activity.insert(
        0,
        CombatLogEntry.system(
          beginCombat
              ? 'Combat begins. ${builds.length} enemies enter initiative.'
              : 'Encounter setup updated: ${builds.length} enemies staged.',
        ),
      );
    });
  }

  List<encounter_models.Combatant> _partyForStagedEncounter(
    List<encounter_models.Combatant> party, {
    required bool beginCombat,
  }) {
    if (!beginCombat || _inactivePartyCombatantIds.isEmpty) return party;
    final activeParty = party
        .where(
            (combatant) => !_inactivePartyCombatantIds.contains(combatant.id))
        .toList(growable: false);
    return activeParty.isEmpty ? party : activeParty;
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
            .where((combatant) => combatant.team == CombatTeam.party)
            .map(_engineCombatantFromUi)
            .toList(growable: false);
        final party = _partyForStagedEncounter(
          partyCombatants.isEmpty ? fallbackParty : partyCombatants,
          beginCombat: false,
        );

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
          CombatLogEntry.system(
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
          CombatLogEntry.system(
            'Could not load SRD monsters. Demo enemies remain available.',
          ),
        );
      });
    }
  }

  encounter_models.CombatEncounter _createEncounterFromCombatants(
    List<Combatant> combatants,
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
      final preparedActions = _engineActions.values
          .where((action) => action.actorId == combatant.id)
          .map((action) => action.copyWith(actorId: combatant.id))
          .toList(growable: false);
      encounter = CombatEncounterEngine.addCombatant(
        encounter,
        preparedActions.isEmpty
            ? combatant
            : combatant.copyWith(preparedActions: preparedActions),
      );
    }
    return CombatEncounterEngine.startEncounter(encounter);
  }

  void _registerPreparedActionsFromEncounter(
    encounter_models.CombatEncounter encounter,
  ) {
    for (final combatant in encounter.combatants) {
      if (combatant.preparedActions.isEmpty) continue;
      final preparedActions = combatant.preparedActions
          .map((action) => action.copyWith(actorId: combatant.id))
          .toList(growable: false);
      _engineActions.addEntries(
        preparedActions.map((action) => MapEntry(action.id, action)),
      );
      final uiActions = preparedActions
          .map(_combatActionFromPreparedAction)
          .toList(growable: false);
      if (combatant.team == encounter_models.CombatantTeam.party) {
        _partyActionsByCombatantId[combatant.id] = uiActions;
        _characterActions = uiActions;
      } else {
        _enemyActionsByCombatantId[combatant.id] = uiActions;
      }
    }
  }

  encounter_models.Combatant _engineCombatantFromUi(Combatant combatant) {
    final id = combatant.id.isEmpty
        ? 'ui_${combatant.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}'
        : combatant.id;
    return encounter_models.Combatant(
      id: id,
      name: combatant.name,
      sourceId: combatant.sourceId,
      kind: combatant.team == CombatTeam.party
          ? encounter_models.CombatantKind.playerCharacter
          : encounter_models.CombatantKind.monster,
      team: combatant.team == CombatTeam.party
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
    if (syncedTargetIndex >= 0 &&
        syncedTargetIndex < _combatants.length &&
        _combatants[syncedTargetIndex].hp > 0) {
      _targetIndex = syncedTargetIndex;
    } else {
      _targetIndex = _findDefaultTargetIndex(_activeIndex);
    }
  }

  Combatant get _activeCombatant => _combatants[_activeIndex];

  int get _safeTargetIndex {
    if (_combatants.isEmpty) return 0;
    if (_targetIndex >= 0 &&
        _targetIndex < _combatants.length &&
        _combatants[_targetIndex].hp > 0) {
      return _targetIndex;
    }
    return _findDefaultTargetIndex(_activeIndex);
  }

  Combatant get _selectedTarget => _combatants[_safeTargetIndex];

  bool _isHostileTargetIndex(
    int targetIndex, {
    int? actorIndex,
    List<Combatant>? source,
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
    List<Combatant>? source,
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
    List<Combatant>? source,
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

  int? _findDefaultSupportTargetIndex(
    int actorIndex, {
    bool allowSelf = true,
  }) {
    if (_combatants.isEmpty) return null;
    final resolvedActorIndex =
        actorIndex.clamp(0, _combatants.length - 1).toInt();
    for (var index = 0; index < _combatants.length; index++) {
      if (!allowSelf && index == resolvedActorIndex) continue;
      final combatant = _combatants[index];
      if (combatant.team == _combatants[resolvedActorIndex].team &&
          combatant.hp > 0 &&
          combatant.hp < combatant.maxHp) {
        return index;
      }
    }
    if (allowSelf &&
        _isSupportTargetIndex(resolvedActorIndex,
            actorIndex: resolvedActorIndex)) {
      return resolvedActorIndex;
    }
    for (var index = 0; index < _combatants.length; index++) {
      if (index == resolvedActorIndex) continue;
      if (_isSupportTargetIndex(index, actorIndex: resolvedActorIndex)) {
        return index;
      }
    }
    return null;
  }

  bool _actionNeedsHostileTarget(CombatAction action) {
    if (action.targetsSelf ||
        action.isHealing ||
        action.targetPolicy == 'ally' ||
        action.targetPolicy == 'self' ||
        action.targetPolicy == 'any') {
      return false;
    }
    return action.hasMultiAttack ||
        action.attackFormula != null ||
        action.requiresSavingThrow ||
        action.damageFormula != null;
  }

  bool _actionAllowsSelfSupportTarget(CombatAction action) {
    final text = '${action.name} ${action.tags.join(' ')}'.toLowerCase();
    return !text.contains('bardic inspiration');
  }

  bool _isValidTargetForAction(
    CombatAction action,
    int targetIndex, {
    int? actorIndex,
  }) {
    if (_combatants.isEmpty ||
        targetIndex < 0 ||
        targetIndex >= _combatants.length) {
      return false;
    }
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final target = _combatants[targetIndex];
    if (target.hp <= 0) return false;
    if (action.targetsSelf || action.targetPolicy == 'self') {
      return targetIndex == resolvedActorIndex;
    }
    if (action.isHealing || action.targetPolicy == 'ally') {
      if (!_isSupportTargetIndex(
        targetIndex,
        actorIndex: resolvedActorIndex,
      )) {
        return false;
      }
      return _actionAllowsSelfSupportTarget(action) ||
          targetIndex != resolvedActorIndex;
    }
    if (action.targetPolicy == 'any') return true;
    if (_actionNeedsHostileTarget(action)) {
      return _isHostileTargetIndex(
        targetIndex,
        actorIndex: resolvedActorIndex,
      );
    }
    return true;
  }

  String _targetUnavailableMessage(CombatAction action, Combatant actor) {
    if (action.targetsSelf || action.targetPolicy == 'self') {
      return '${actor.name} must target self for ${action.name}.';
    }
    if (action.isHealing || action.targetPolicy == 'ally') {
      final allowSelf = _actionAllowsSelfSupportTarget(action);
      return allowSelf
          ? '${actor.name} needs a living ally or self for ${action.name}.'
          : '${actor.name} needs another living ally for ${action.name}.';
    }
    if (action.targetPolicy == 'any') {
      return '${actor.name} needs a living target for ${action.name}.';
    }
    return '${actor.name} needs a hostile target for ${action.name}.';
  }

  String _targetUnavailableSubline(CombatAction action) {
    if (action.isHealing || action.targetPolicy == 'ally') {
      return _actionAllowsSelfSupportTarget(action)
          ? 'Choose a living ally or self before resolving.'
          : 'Choose another living ally before resolving.';
    }
    if (action.targetPolicy == 'any') {
      return 'Choose a living target before resolving.';
    }
    return 'Choose a living enemy before rolling.';
  }

  bool _actionIsOncePerTurn(CombatAction action) {
    final text = '${action.name} ${action.tags.join(' ')}'.toLowerCase();
    return text.contains('once per turn') || text.contains('sneak attack');
  }

  String _oncePerTurnActionKey(Combatant actor, CombatAction action) {
    return '${actor.id}|${action.id.isEmpty ? action.name : action.id}';
  }

  bool _actionOncePerTurnUsed(Combatant actor, CombatAction action) {
    return _actionIsOncePerTurn(action) &&
        _oncePerTurnActionUses.contains(_oncePerTurnActionKey(actor, action));
  }

  void _markOncePerTurnActionUse(Combatant actor, CombatAction action) {
    if (!_actionIsOncePerTurn(action)) return;
    _oncePerTurnActionUses.add(_oncePerTurnActionKey(actor, action));
  }

  bool _actionUsesAttackSlot(
    CombatAction action,
    CombatActionRoll rollType,
  ) {
    return action.timing == 'Action' &&
        rollType == CombatActionRoll.attack &&
        action.usesAttackAction &&
        action.attackFormula != null &&
        !action.hasMultiAttack &&
        !action.targetsSelf;
  }

  bool _actionConsumesTurnTiming(CombatAction action) {
    return action.timing != 'Free';
  }

  int _maxActionAttackSlots(Combatant combatant) {
    var maxAttacks = 1;
    for (final action in _actionsForCombatant(combatant)) {
      if (action.timing != 'Action' || !action.usesAttackAction) continue;
      maxAttacks = math.max(maxAttacks, action.actionAttackSlots);
    }
    return maxAttacks;
  }

  bool _hasStartedAttackAction(Combatant combatant) {
    return (_actionAttackUsesByCombatantId[combatant.id] ?? 0) > 0 &&
        !_spentTimings.contains('Action');
  }

  bool _hasTakenAttackActionThisTurn(Combatant combatant) {
    return (_actionAttackUsesByCombatantId[combatant.id] ?? 0) > 0;
  }

  bool _hasMartialArtsEligibleAttackThisTurn(Combatant combatant) {
    return _martialArtsEligibleCombatantIds.contains(combatant.id);
  }

  bool _attackQualifiesForMonkMartialArts(CombatAction action) {
    if (!_actionsForCombatant(_activeCombatant)
        .any(_actionIsMartialArtsBonusStrike)) {
      return false;
    }
    if (action.timing != 'Action' || !action.usesAttackAction) return false;
    final text = _rulesText(
      '${action.name} ${action.type} ${action.tags.join(' ')}',
    );
    return text.contains('unarmed') ||
        text.contains('martial arts') ||
        text.contains('monk weapon') ||
        text.contains('weapon attack') ||
        text.contains('weapon');
  }

  bool _actionBlockedByStartedAttackAction(CombatAction action) {
    return action.timing == 'Action' &&
        _hasStartedAttackAction(_activeCombatant) &&
        !action.usesAttackAction;
  }

  bool _actionRequiresAttackActionThisTurn(CombatAction action) {
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    return text.contains('requires attack action') ||
        text.contains('flurry of blows') ||
        text.contains('rafaga de golpes');
  }

  String? _actionPrerequisiteBlockMessage(
    CombatAction action, {
    Combatant? actor,
  }) {
    final resolvedActor = actor ?? _activeCombatant;
    if (_actionRequiresAttackActionThisTurn(action) &&
        !_hasTakenAttackActionThisTurn(resolvedActor)) {
      return '${action.name} requires ${resolvedActor.name} to take the Attack action first this turn.';
    }
    return null;
  }

  bool _ensureActionPrerequisites(CombatAction action) {
    final message = _actionPrerequisiteBlockMessage(action);
    if (message == null) return true;
    setState(() {
      _activity.insert(0, CombatLogEntry.system(message));
      _rollFeedback = CombatRollFeedback.manual(
        actor: _activeCombatant.name,
        action: action.name,
        headline: 'NOT READY',
        subline: 'Take the Attack action first this turn.',
        accentKind: CombatAccentKind.read,
      );
    });
    return false;
  }

  String _startedAttackActionMessage(CombatAction action) {
    final maxAttacks = _maxActionAttackSlots(_activeCombatant);
    final used = _actionAttackUsesByCombatantId[_activeCombatant.id] ?? 0;
    return '${_activeCombatant.name} is resolving the Attack action ($used/$maxAttacks). Finish remaining attacks before ${action.name}.';
  }

  bool _hasAttackSlotRemaining(CombatAction action) {
    final maxAttacks = _maxActionAttackSlots(_activeCombatant);
    if (maxAttacks <= 1) return !_spentTimings.contains(action.timing);
    final used = _actionAttackUsesByCombatantId[_activeCombatant.id] ?? 0;
    return used < maxAttacks;
  }

  String _attackSlotSpentMessage(CombatAction action) {
    final maxAttacks = _maxActionAttackSlots(_activeCombatant);
    if (maxAttacks <= 1) return '${action.timing} is already spent this turn.';
    return '${_activeCombatant.name} has used all $maxAttacks attacks for this Action.';
  }

  void _spendActionOrAttackSlot(
    CombatAction action,
    CombatActionRoll rollType,
  ) {
    if (!_actionUsesAttackSlot(action, rollType)) {
      if (_actionConsumesTurnTiming(action)) {
        _spentTimings.add(action.timing);
      }
      return;
    }

    final maxAttacks = _maxActionAttackSlots(_activeCombatant);
    if (maxAttacks <= 1) {
      _actionAttackUsesByCombatantId[_activeCombatant.id] = 1;
      if (_attackQualifiesForMonkMartialArts(action)) {
        _martialArtsEligibleCombatantIds.add(_activeCombatant.id);
      }
      _spentTimings.add(action.timing);
      return;
    }

    final used = _actionAttackUsesByCombatantId[_activeCombatant.id] ?? 0;
    final nextUsed = math.min(maxAttacks, used + 1);
    _actionAttackUsesByCombatantId[_activeCombatant.id] = nextUsed;
    if (_attackQualifiesForMonkMartialArts(action)) {
      _martialArtsEligibleCombatantIds.add(_activeCombatant.id);
    }
    if (nextUsed >= maxAttacks) {
      _spentTimings.add(action.timing);
    }
    _activity.insert(
      0,
      CombatLogEntry.system(
        '${_activeCombatant.name} attack $nextUsed/$maxAttacks resolved.',
      ),
    );
  }

  CombatActionRoll _primaryRollTypeForAction(CombatAction action) {
    if (action.attackFormula != null || action.hasMultiAttack) {
      return CombatActionRoll.attack;
    }
    if (action.requiresSavingThrow) return CombatActionRoll.savingThrow;
    if (action.damageFormula != null) return CombatActionRoll.damage;
    return CombatActionRoll.damage;
  }

  int? _targetIndexForAction(
    CombatAction action, {
    int? actorIndex,
    int? forcedTargetIndex,
  }) {
    if (_combatants.isEmpty) return null;
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final canUseSelectedTarget = resolvedActorIndex == _activeIndex;
    if (action.targetsSelf || action.targetPolicy == 'self') {
      return resolvedActorIndex;
    }

    if (action.isHealing || action.targetPolicy == 'ally') {
      final allowSelf = _actionAllowsSelfSupportTarget(action);
      if (forcedTargetIndex != null &&
          _isValidTargetForAction(
            action,
            forcedTargetIndex,
            actorIndex: resolvedActorIndex,
          )) {
        return forcedTargetIndex;
      }
      if (canUseSelectedTarget &&
          _isValidTargetForAction(
            action,
            _targetIndex,
            actorIndex: resolvedActorIndex,
          )) {
        return _targetIndex;
      }
      return _findDefaultSupportTargetIndex(
        resolvedActorIndex,
        allowSelf: allowSelf,
      );
    }

    if (action.targetPolicy == 'any') {
      if (forcedTargetIndex != null &&
          _isValidTargetForAction(
            action,
            forcedTargetIndex,
            actorIndex: resolvedActorIndex,
          )) {
        return forcedTargetIndex;
      }
      if (canUseSelectedTarget &&
          _isValidTargetForAction(
            action,
            _targetIndex,
            actorIndex: resolvedActorIndex,
          )) {
        return _targetIndex;
      }
      return _findDefaultTargetIndex(resolvedActorIndex);
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

  bool _ensureActionTargetAvailable(CombatAction action, {int? actorIndex}) {
    if (_combatants.isEmpty) return false;
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    if (_targetIndexForAction(action, actorIndex: resolvedActorIndex) != null) {
      return true;
    }
    final actor = _combatants[resolvedActorIndex];
    setState(() {
      _activity.insert(
        0,
        CombatLogEntry.system(
          _targetUnavailableMessage(action, actor),
        ),
      );
      _rollFeedback = CombatRollFeedback.manual(
        actor: actor.name,
        action: action.name,
        headline: 'NO TARGET',
        subline: _targetUnavailableSubline(action),
        accentKind: CombatAccentKind.read,
      );
    });
    return false;
  }

  List<CombatAction> get _activeActions {
    return _actionsForCombatant(_activeCombatant);
  }

  static const CombatAction _deathSavingThrowAction = CombatAction(
    id: 'system:death_saving_throw',
    name: 'Death Saving Throw',
    type: 'Death Save',
    timing: 'Action',
    attackFormula: null,
    damageFormula: null,
    critFormula: null,
    tags: ['Death Save', 'D20', 'Down'],
    icon: Icons.monitor_heart_outlined,
    accentKind: CombatAccentKind.read,
  );

  Map<String, int> get _activeResourcePool {
    return _encounter?.combatantById(_activeCombatant.id)?.resources ?? {};
  }

  CombatActionEconomySnapshot get _activeEconomy {
    final active = _activeCombatant;
    final readiedAction = _readiedActionsByCombatantId[active.id];
    return CombatActionEconomySnapshot(
      actionSpent: _spentTimings.contains('Action'),
      bonusActionSpent: _spentTimings.contains('Bonus Action'),
      reactionSpent: _spentReactionCombatantIds.contains(active.id),
      movementAvailable: _effectiveMovementBudget(active),
      readiedActionName: readiedAction?.action.name,
      readiedTrigger: readiedAction?.trigger,
    );
  }

  PendingSavePromptData? _pendingSavePromptData() {
    final pending = _pendingAreaSavingThrow;
    if (pending == null || pending.isComplete) return null;
    final targetIndex = _nextPendingAreaSaveTargetIndex(
      pending,
      controllableOnly: !_dmView && !_devCombatMode,
    );
    if (targetIndex == null) return null;
    final target = _combatants[targetIndex];
    if (!_canControlCombatant(target)) return null;
    final ability = pending.action.saveAbility ?? 'DEX';
    return PendingSavePromptData(
      action: pending.action,
      target: target,
      ability: ability,
      dc: pending.action.saveDc ?? 10,
      formula: _savingThrowFormulaForTarget(target, ability),
      remaining: pending.unresolvedTargetIds.length,
    );
  }

  int _effectiveMovementBudget(Combatant combatant) {
    final baseSpeed = combatant.speed < 0 ? 0 : combatant.speed;
    final bonus = _movementBonusFeetByCombatantId[combatant.id] ?? 0;
    return baseSpeed + math.max(0, bonus);
  }

  String? _currentUserId() {
    final rawUserId = context.read<AuthProvider?>()?.userId;
    final userId = rawUserId?.trim();
    return userId == null || userId.isEmpty ? null : userId;
  }

  String get _diceColorPreferenceKey {
    final userId = _currentUserId();
    return userId == null
        ? DiceColorPreferencesService.defaultKey
        : '${DiceColorPreferencesService.defaultKey}.$userId';
  }

  String get _diceColorHex {
    return DiceColorPreferencesService.colorToHex(_diceColor);
  }

  Future<void> _loadDiceColorPreference() async {
    final color = await DiceColorPreferencesService.loadColor(
      key: _diceColorPreferenceKey,
    );
    if (!mounted) return;
    setState(() {
      _diceColor = color;
    });
  }

  Future<void> _setDiceColor(Color color) async {
    if (mounted) {
      setState(() {
        _diceColor = color;
      });
    }
    await DiceColorPreferencesService.saveColor(
      color,
      key: _diceColorPreferenceKey,
    );
  }

  bool _canControlCombatant(Combatant combatant) {
    if (_devCombatMode) return true;
    if (_dmView) return true;
    if (combatant.team == CombatTeam.enemy) return false;

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

  String _controlBlockedMessage(Combatant combatant) {
    if (!_dmView && !_devCombatMode) {
      return 'Vista jugador: activa Modo prueba para probar todo el flujo.';
    }
    if (combatant.team == CombatTeam.enemy) {
      return 'Vista jugador: los enemigos los dirige el DM.';
    }
    return 'Vista jugador: solo puedes resolver acciones de tu personaje.';
  }

  bool _ensureCanControlCombatant(
    Combatant combatant, {
    String actionLabel = 'resolver acciones',
  }) {
    if (_canControlCombatant(combatant)) return true;
    final message = '${_controlBlockedMessage(combatant)} No puedes '
        '$actionLabel de ${combatant.name}.';
    setState(() {
      _activity.insert(0, CombatLogEntry.system(message));
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

  List<ReactionOption> get _reactionOptions {
    final options = <ReactionOption>[];
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
          ReactionOption(
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
          ReactionOption(
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

  List<CombatAction> _actionsForCombatant(Combatant combatant) {
    if (_combatantCanOnlyDeathSave(combatant)) {
      return const [_deathSavingThrowAction];
    }
    if (combatant.hp <= 0) return const [];

    final actions = combatant.team == CombatTeam.party
        ? _partyActionsByCombatantId[combatant.id] ?? _characterActions
        : _enemyActionsByCombatantId[combatant.id] ?? _enemyActions;
    final visible = _dedupeUiActions(
      actions.where(_actionAppearsInMenu).toList(),
    );
    final visibleWithFallback = _withMonkFlurryFallback(combatant, visible);
    if (visibleWithFallback.isNotEmpty) return visibleWithFallback;

    final engineCombatant = _encounter?.combatantById(combatant.id);
    final preparedActions = engineCombatant?.preparedActions ??
        const <encounter_models.PreparedCombatAction>[];
    if (preparedActions.isEmpty) return visible;

    final hydrated = preparedActions
        .map((action) => action.copyWith(actorId: combatant.id))
        .map(_combatActionFromPreparedAction)
        .where(_actionAppearsInMenu)
        .toList(growable: false);
    if (hydrated.isEmpty) return visible;

    if (combatant.team == CombatTeam.party) {
      _partyActionsByCombatantId[combatant.id] = hydrated;
    } else {
      _enemyActionsByCombatantId[combatant.id] = hydrated;
    }
    return _withMonkFlurryFallback(combatant, _dedupeUiActions(hydrated));
  }

  List<CombatAction> _withMonkFlurryFallback(
    Combatant combatant,
    List<CombatAction> actions,
  ) {
    if (combatant.team != CombatTeam.party) return actions;
    if (actions.any(_actionIsFlurryOfBlows)) return actions;
    final martialArts =
        _firstOrNull(actions.where(_actionIsMartialArtsBonusStrike));
    if (martialArts == null) return actions;
    final resourcePool =
        _encounter?.combatantById(combatant.id)?.resources ?? const {};
    final resourceKey = _classKitResourceKey(actions, resourcePool) ??
        _resourceKeyWhere(resourcePool.keys, _isKiResourceKey) ??
        _resourceKeyWhere(combatant.resourceMaximums.keys, _isKiResourceKey);
    if (resourceKey == null) return actions;

    final steps = martialArts.multiAttackSteps.isNotEmpty
        ? [
            for (var index = 0; index < 2; index++)
              martialArts.multiAttackSteps[
                  index % martialArts.multiAttackSteps.length],
          ]
        : [
            for (var index = 0; index < 2; index++)
              MultiAttackStep(
                name: 'Unarmed Strike',
                attackFormula: martialArts.attackFormula,
                damageFormula: martialArts.damageFormula,
                critFormula: martialArts.critFormula,
                tags: martialArts.tags,
              ),
          ];

    return [
      ...actions,
      CombatAction(
        id: '${combatant.id}:synthetic_flurry_of_blows',
        name: 'Flurry of Blows',
        type: 'Monk Technique',
        timing: 'Bonus Action',
        attackFormula: martialArts.attackFormula,
        damageFormula: martialArts.damageFormula,
        critFormula: martialArts.critFormula,
        rangeFeet: martialArts.rangeFeet ?? 5,
        damageType: martialArts.damageType ?? 'bludgeoning',
        tags: const [
          'Monk',
          'Ki',
          'Bonus Action',
          '2 attacks',
          'Unarmed',
          'Melee',
          'Bludgeoning',
          'Requires Attack action',
        ],
        icon: Icons.flash_on_rounded,
        accentKind: CombatAccentKind.info,
        resourceKey: resourceKey,
        resourceCost: 1,
        targetPolicy: 'hostile',
        usesAttackAction: false,
        multiAttackSteps: steps,
      ),
    ];
  }

  bool _combatantCanOnlyDeathSave(Combatant combatant) {
    return combatant.team == CombatTeam.party && combatant.hp <= 0;
  }

  bool _actionAppearsInMenu(CombatAction action) {
    final text = _rulesText(
      '${action.name} ${action.type} ${action.tags.join(' ')} ${action.resourceKey ?? ''}',
    );
    if (action.timing == 'Passive') return false;
    if (text.contains('passive trait') || text.contains('passive effect')) {
      return false;
    }
    if (text.contains('improved divine smite')) return false;
    if (text.contains('radiant strikes')) return false;
    if (text.contains('ki-fueled attack') ||
        text.contains('ki fueled attack') ||
        text.contains('ataque potenciado por ki')) {
      return false;
    }
    if (_isRawKiActionCard(action, text)) return false;
    if (text == 'evasion' ||
        text.startsWith('evasion ') ||
        text.contains(' evasion')) {
      return false;
    }
    if (_isModeledResourceCard(action, text)) return false;
    return true;
  }

  bool _isRawKiActionCard(CombatAction action, String text) {
    final name = _rulesText(action.name);
    final isRawName = name == 'ki' ||
        name == 'ki points' ||
        name == 'puntos de ki' ||
        name == 'monk ki' ||
        name == 'monastic discipline' ||
        name == 'disciplina monastica';
    if (!isRawName) return false;
    final hasNoRollPayload = action.attackFormula == null &&
        action.damageFormula == null &&
        !action.requiresSavingThrow &&
        !action.hasMultiAttack &&
        !action.grantsAction;
    if (!hasNoRollPayload) return false;
    return text.contains('ki') ||
        text.contains('focus point') ||
        text.contains('punto de ki') ||
        text.contains('puntos de ki') ||
        text.contains('punto de enfoque') ||
        text.contains('puntos de enfoque');
  }

  bool _isModeledResourceCard(CombatAction action, String text) {
    if (action.type.trim().toLowerCase() != 'resource') return false;
    return text.contains('ki') ||
        text.contains('focus point') ||
        text.contains('punto de ki') ||
        text.contains('puntos de ki') ||
        text.contains('rage') ||
        text.contains('furia') ||
        text.contains('rabia') ||
        text.contains('second wind') ||
        text.contains('segundo aliento') ||
        text.contains('action surge') ||
        text.contains('action sourge') ||
        text.contains('oleada de accion') ||
        text.contains('bardic inspiration') ||
        text.contains('inspiracion bardica') ||
        text.contains('channel divinity') ||
        text.contains('canalizar divinidad') ||
        text.contains('wild shape') ||
        text.contains('forma salvaje') ||
        text.contains('flash of genius') ||
        text.contains('destello de genialidad') ||
        text.contains('superiority') ||
        text.contains('superioridad') ||
        text.contains('lay on hands') ||
        text.contains('imposicion de manos');
  }

  String _rulesText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Ã¡', 'a')
        .replaceAll('Ã©', 'e')
        .replaceAll('Ã­', 'i')
        .replaceAll('Ã³', 'o')
        .replaceAll('Ãº', 'u')
        .replaceAll('Ã±', 'n');
  }

  List<CombatAction> _dedupeUiActions(List<CombatAction> actions) {
    final seen = <String>{};
    final result = <CombatAction>[];
    for (final action in actions) {
      final key = [
        action.name.trim().toLowerCase(),
        action.timing,
        action.type.trim().toLowerCase(),
        action.resourceKey ?? '',
        action.attackFormula ?? '',
        action.damageFormula ?? '',
        action.saveAbility ?? '',
        action.saveDc?.toString() ?? '',
      ].join('|');
      if (!seen.add(key)) continue;
      result.add(action);
    }
    return result;
  }

  List<CombatAction> _reactionActionsForCombatant(Combatant combatant) {
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

  bool _looksLikeOpportunityAttackSource(CombatAction action) {
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

  CombatAction _opportunityAttackFrom(CombatAction source) {
    return CombatAction(
      id: source.id.isEmpty
          ? '${source.name}|opportunity'
          : '${source.id}|opportunity',
      name: 'Opportunity Attack',
      type: 'Reaction',
      timing: 'Reaction',
      attackFormula: source.attackFormula,
      damageFormula: source.damageFormula,
      damageType: source.damageType,
      critFormula: source.critFormula,
      rangeFeet: source.rangeFeet ?? 5,
      longRangeFeet: source.longRangeFeet,
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
        CombatLogEntry.system(
          'DM requested initiative. Waiting for party rolls.',
        ),
      );
    });
  }

  void _rollInitiativeForAll() {
    if (_combatRollInFlight) return;
    unawaited(_rollInitiativeForAllAsync());
  }

  Future<void> _rollInitiativeForAllAsync() async {
    final updated = <Combatant>[];
    var encounter = _encounter;

    for (final combatant in _combatants) {
      final bonus = combatant.initiativeBonus;
      final result = await _rollCombatFormulaAwaitingBoard(
        formula: _formatRollFormula('d20', bonus),
        label: '${combatant.name} Initiative',
      );
      if (!mounted) return;
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
      _clearClassTurnFlowState();
      _actionAttackUsesByCombatantId.clear();
      _movementBonusFeetByCombatantId.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _pendingAreaSavingThrow = null;
      _spentReactionCombatantIds.clear();
      _oncePerTurnActionUses.clear();
      _readiedActionsByCombatantId.clear();
      _clearMultiAttackProgress();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _rollFeedback = null;
      _activeCombatResolutionKeys.clear();
      _activity.removeWhere(
        (entry) =>
            entry.title == 'DM requested initiative. Waiting for party rolls.',
      );
      _activity.insert(
        0,
        CombatLogEntry.system('Initiative rolled. Round 1 begins.'),
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
    final pendingArea = _pendingAreaSavingThrow;
    if (pendingArea != null && !pendingArea.isComplete) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            'Resolve all ${pendingArea.action.name} saving throws before ending the turn.',
          ),
        );
      });
      return;
    }
    final endingCombatantId = _activeCombatant.id;
    setState(() {
      final previousRound = _round;
      final encounter = _encounter;
      if (encounter != null) {
        _encounter = CombatEncounterEngine.nextTurn(encounter);
        _syncUiFromEncounter();
        if (_round != previousRound) {
          _activity.insert(0, CombatLogEntry.system('Round $_round begins.'));
        }
      } else {
        var nextIndex = _activeIndex + 1;
        if (nextIndex >= _combatants.length) {
          nextIndex = 0;
          _round += 1;
          _activity.insert(0, CombatLogEntry.system('Round $_round begins.'));
        }
        _activeIndex = nextIndex;
        _targetIndex = _findDefaultTargetIndex(nextIndex);
      }

      _spentTimings.clear();
      _clearClassTurnFlowState(combatantId: endingCombatantId);
      _actionAttackUsesByCombatantId.remove(endingCombatantId);
      _actionAttackUsesByCombatantId.remove(_activeCombatant.id);
      _movementBonusFeetByCombatantId.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _pendingAreaSavingThrow = null;
      _spentReactionCombatantIds.remove(_activeCombatant.id);
      _oncePerTurnActionUses.removeWhere(
        (key) => key.startsWith('${_activeCombatant.id}|'),
      );
      final expiredReady =
          _readiedActionsByCombatantId.remove(_activeCombatant.id);
      if (expiredReady != null) {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${_activeCombatant.name} readied action expired.',
          ),
        );
      }
      _clearMultiAttackProgress();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _selectedCommandTiming = 'Action';
      _rollFeedback = null;
      _activeCombatResolutionKeys.clear();
      _activity.insert(
        0,
        CombatLogEntry.turn('${_activeCombatant.name} takes the turn.'),
      );
      _battleBoardMovementUsedByCombatantId[_activeCombatant.id] = 0;
      _selectedBattleBoardCombatantId = _activeCombatant.id;
      _focusedBattleBoardAction = null;
    });
    if (_showBattleBoardController) {
      unawaited(_syncBattleBoardTokensFromCombatState());
    }
  }

  void _scheduleAutoAdvanceTurn(String reason) {
    _activity.insert(
      0,
      CombatLogEntry.system('$reason Turn stays active until End Turn.'),
    );
  }

  DiceRollResult _rollCombatFormula({
    required String formula,
    required String label,
    bool useRollMode = false,
    bool forceAdvantage = false,
    bool forceDisadvantage = false,
  }) {
    final hasAdvantage = (useRollMode && _hasAdvantage) || forceAdvantage;
    final hasDisadvantage =
        (useRollMode && _hasDisadvantage) || forceDisadvantage;
    final cancelled = hasAdvantage && hasDisadvantage;
    return DiceRollerService.rollFormula(
      formula: formula,
      label: label,
      advantage: !cancelled && hasAdvantage,
      disadvantage: !cancelled && hasDisadvantage,
    );
  }

  Future<DiceRollResult> _rollCombatFormulaAwaitingBoard({
    required String formula,
    required String label,
    bool useRollMode = false,
    bool forceAdvantage = false,
    bool forceDisadvantage = false,
  }) async {
    if (_showBattleBoardController && _activeBattleBoardSceneId != null) {
      setState(() {
        _combatRollInFlight = true;
        _rollFeedback = CombatRollFeedback.manual(
          actor: _activeCombatant.name,
          action: label,
          headline: 'ROLLING',
          subline: 'Waiting for the 3D dice...',
          accentKind: CombatAccentKind.info,
        );
      });
    }

    final fallback = _rollCombatFormula(
      formula: formula,
      label: label,
      useRollMode: useRollMode,
      forceAdvantage: forceAdvantage,
      forceDisadvantage: forceDisadvantage,
    );
    final sceneId = _activeBattleBoardSceneId;
    if (!_showBattleBoardController || sceneId == null) {
      return fallback;
    }

    final notation =
        CombatDiceResultFormatter.diceBoxNotation(fallback) ?? fallback.formula;
    if (notation.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _combatRollInFlight = false;
        });
      }
      return fallback;
    }
    final eventId = _diceRollCoordinator.nextEventId();

    try {
      await _syncBattleBoardTokensFromCombatState(
        eventLabel: 'ROLLING',
        eventKind: 'focus',
        eventDiceNotation: notation,
        eventResultLabel: '',
        eventResultDetail: '',
        eventAuthoritativeDice: '',
        eventIdOverride: eventId,
      );
      if (!mounted) return fallback;

      final boardToken =
          await _diceRollCoordinator.waitForBattleBoardRollResult(
        boardProvider: context.read<BattleBoardProvider>(),
        sceneId: sceneId,
        eventId: eventId,
        isActive: () => mounted,
      );
      if (boardToken == null) {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '3D dice result was not received in time; using local fallback.',
          ),
        );
        return fallback;
      }

      return _diceRollCoordinator.rollResultFromBoardToken(
        fallback,
        boardToken,
      );
    } finally {
      if (mounted) {
        setState(() {
          _combatRollInFlight = false;
        });
      }
    }
  }

  String? _consumeBoardResolvedRollEventId() {
    return _diceRollCoordinator.consumeBoardResolvedRollEventId();
  }

  void _rollManualSavingThrow(String ability) {
    if (_combatRollInFlight) return;
    unawaited(_rollManualSavingThrowAsync(ability));
  }

  Future<void> _rollManualSavingThrowAsync(String ability) async {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    final target = _selectedTarget;
    final normalizedAbility = ability.trim();
    if (normalizedAbility.isEmpty) return;
    final result = await _rollCombatFormulaAwaitingBoard(
      formula: _savingThrowFormulaForTarget(target, normalizedAbility),
      label: '${target.name} $normalizedAbility Save',
      useRollMode: true,
      forceAdvantage: _savingThrowHasAdvantage(target, normalizedAbility),
      forceDisadvantage: _savingThrowHasDisadvantage(target, normalizedAbility),
    );
    setState(() {
      _activity.insert(
        0,
        CombatLogEntry.roll(
          actor: target.name,
          action: '$normalizedAbility saving throw',
          result: result,
          detail:
              '${result.formula} - ${result.rollsText}. ${target.name} rolls $normalizedAbility save: ${result.total}.',
        ),
      );
      _rollFeedback = CombatRollFeedback(
        actor: target.name,
        action: '$normalizedAbility Save',
        result: result,
        headline: 'SAVE ${result.total}',
        subline: '${target.name} tira $normalizedAbility',
        accentKind: CombatAccentKind.read,
      );
    });
    if (_showBattleBoardController) {
      unawaited(
        _syncBattleBoardTokensFromCombatState(
          eventLabel: 'SAVE ${result.total}',
          eventKind: 'focus',
          eventDiceNotation:
              CombatDiceResultFormatter.diceBoxNotation(result) ?? '',
          eventResultLabel: 'SAVE ${result.total}',
          eventResultDetail: CombatDiceResultFormatter.detail(result),
          eventAuthoritativeDice:
              CombatDiceResultFormatter.authoritativeDiceJson(result),
          eventIdOverride: _consumeBoardResolvedRollEventId(),
        ),
      );
    }
  }

  void _rollAction(CombatAction action, CombatActionRoll rollType) {
    if (_combatRollInFlight) return;
    unawaited(_rollActionAsync(action, rollType));
  }

  Future<void> _rollActionAsync(
    CombatAction action,
    CombatActionRoll rollType,
  ) async {
    if (_isDeathSavingThrowAction(action)) {
      _rollDeathSavingThrowForActiveCombatant();
      return;
    }

    final actionKey = _actionExecutionKey(action);
    if (_pendingAreaSavingThrow?.matches(
          actorId: _activeCombatant.id,
          actionKey: actionKey,
        ) ==
        true) {
      await _rollPendingAreaSavingThrowAsync(action);
      return;
    }

    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (!_ensureActionTargetAvailable(action)) return;
    if (action.hasMultiAttack) {
      if (_actionIsMartialArtsBonusStrike(action) &&
          !_multiAttackProgressMatches(action)) {
        _activateMartialArtsBonusStrike(action);
        return;
      }
      if (_actionIsFlurryOfBlows(action) &&
          !_multiAttackProgressMatches(action)) {
        _activateFlurryOfBlows(action);
        return;
      }
      await _rollMultiAttackStepAsync(action, rollType);
      return;
    }
    final canResolvePendingDamage = rollType != CombatActionRoll.attack &&
        _pendingDamageActions.contains(actionKey);
    final usesAttackSlot = _actionUsesAttackSlot(action, rollType);
    if (!canResolvePendingDamage && !_ensureActionPrerequisites(action)) {
      return;
    }
    if (!canResolvePendingDamage && !_ensureBattleBoardActionRange(action)) {
      return;
    }
    _focusedBattleBoardAction = action;
    final resourceBlock = _actionResourceBlockMessage(action);
    if (resourceBlock != null && !canResolvePendingDamage) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(resourceBlock),
        );
      });
      return;
    }
    if (!canResolvePendingDamage &&
        usesAttackSlot &&
        !_hasAttackSlotRemaining(action)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(_attackSlotSpentMessage(action)),
        );
      });
      return;
    }
    if (!canResolvePendingDamage &&
        _actionOncePerTurnUsed(_activeCombatant, action)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${action.name} has already been used this turn.',
          ),
        );
      });
      return;
    }
    if (!canResolvePendingDamage &&
        _actionBlockedByStartedAttackAction(action)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(_startedAttackActionMessage(action)),
        );
      });
      return;
    }
    if (!canResolvePendingDamage &&
        !usesAttackSlot &&
        _actionConsumesTurnTiming(action) &&
        _spentTimings.contains(action.timing)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${action.timing} is already spent this turn.',
          ),
        );
      });
      return;
    }
    if (!canResolvePendingDamage &&
        rollType == CombatActionRoll.savingThrow &&
        action.requiresSavingThrow &&
        action.hasAreaEffect) {
      _resolveAreaSavingThrowAction(action);
      return;
    }

    final initialTargetIndex = _targetIndexForAction(action);
    final initialTarget =
        initialTargetIndex == null ? null : _combatants[initialTargetIndex];
    final formula = switch (rollType) {
      CombatActionRoll.attack => action.attackFormula,
      CombatActionRoll.savingThrow => action.requiresSavingThrow
          ? initialTarget == null
              ? null
              : _savingThrowFormulaForTarget(
                  initialTarget,
                  action.saveAbility!,
                )
          : null,
      CombatActionRoll.damage => action.damageFormula,
      CombatActionRoll.critical => action.critFormula,
    };

    if (formula == null) return;

    final label = switch (rollType) {
      CombatActionRoll.attack => '${action.name} Attack',
      CombatActionRoll.savingThrow =>
        '${initialTarget?.name ?? 'Target'} ${action.saveAbility} Save',
      CombatActionRoll.damage => '${action.name} Damage',
      CombatActionRoll.critical => '${action.name} Critical',
    };

    final resolutionKey = _combatResolutionKey(
      canResolvePendingDamage ? 'resolve-damage' : 'roll-action',
      action,
      rollType: rollType,
      targetIndex: initialTargetIndex,
    );
    if (!_beginCombatResolution(resolutionKey)) return;
    try {
      final result = await _rollCombatFormulaAwaitingBoard(
        formula: formula,
        label: label,
        useRollMode: rollType == CombatActionRoll.attack ||
            rollType == CombatActionRoll.savingThrow,
        forceAdvantage: rollType == CombatActionRoll.savingThrow &&
            initialTarget != null &&
            action.saveAbility != null &&
            _savingThrowHasAdvantage(
              initialTarget,
              action.saveAbility!,
              sourceAction: action,
            ),
        forceDisadvantage: rollType == CombatActionRoll.savingThrow &&
                initialTarget != null &&
                action.saveAbility != null
            ? _savingThrowHasDisadvantage(
                initialTarget,
                action.saveAbility!,
                sourceAction: action,
              )
            : rollType == CombatActionRoll.attack &&
                _attackHasLongRangeDisadvantage(action),
      );
      final boardEventDiceNotation =
          CombatDiceResultFormatter.diceBoxNotation(result) ?? '';
      DiceRollResult? passiveDamageResultForResolvedDamage;
      if (rollType == CombatActionRoll.damage ||
          rollType == CombatActionRoll.critical) {
        final passiveTargetIndex = _targetIndexForAction(action);
        final isHalfDamage =
            !action.isHealing && _pendingHalfDamageActions.contains(actionKey);
        final passiveDamageFormula =
            passiveTargetIndex == null || action.isHealing || isHalfDamage
                ? null
                : _passiveExtraHitDamageFormula(
                    _activeCombatant,
                    action,
                    critical: rollType == CombatActionRoll.critical,
                  );
        passiveDamageResultForResolvedDamage = passiveDamageFormula == null
            ? null
            : await _rollCombatFormulaAwaitingBoard(
                formula: passiveDamageFormula,
                label: 'Improved Divine Smite',
              );
      }

      String? boardEventLabel;
      var boardEventKind = 'focus';
      setState(() {
        if (!canResolvePendingDamage) {
          _resetQueuedPreparedActions();
        }
        String? detail;
        String headline;
        String? subline;
        CombatAccentKind feedbackKind = action.accentKind;
        if (rollType == CombatActionRoll.attack ||
            rollType == CombatActionRoll.savingThrow ||
            !canResolvePendingDamage) {
          _spendActionOrAttackSlot(action, rollType);
          _markOncePerTurnActionUse(_activeCombatant, action);
          _spendEngineActionResource(action);
          final economyMessage = _applyActionEconomyEffect(action);
          if (economyMessage != null) {
            _activity.insert(0, CombatLogEntry.system(economyMessage));
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

        if (rollType == CombatActionRoll.attack) {
          final targetIndex = _targetIndexForAction(action);
          if (targetIndex == null) return;
          final target = _combatants[targetIndex];
          final outcome = _attackOutcome(result, target, action);
          if (outcome == 'hit' || outcome == 'critical hit') {
            _pendingDamageActions.add(actionKey);
            _pendingHalfDamageActions.remove(actionKey);
            _queueOnHitPromptIfAvailable(target.name);
            _selectBestCommandTimingAfterAttackRoll(didHit: true);
          } else {
            _pendingDamageActions.remove(actionKey);
            _pendingHalfDamageActions.remove(actionKey);
            _selectBestCommandTimingAfterAttackRoll(didHit: false);
          }
          headline = outcome.toUpperCase();
          subline =
              '${_activeCombatant.name} vs ${target.name} AC ${target.ac}';
          feedbackKind = switch (outcome) {
            'critical hit' => CombatAccentKind.support,
            'hit' => CombatAccentKind.action,
            'automatic miss' => CombatAccentKind.info,
            _ => CombatAccentKind.read,
          };
          boardEventLabel = switch (outcome) {
            'critical hit' => 'CRIT ${result.total}',
            'hit' => 'HIT ${result.total}',
            _ => 'MISS ${result.total}',
          };
          boardEventKind = switch (outcome) {
            'critical hit' => 'critical',
            'hit' => 'hit',
            _ => 'miss',
          };
          detail =
              '${result.formula} - ${result.rollsText}. ${target.name} AC ${target.ac}: $outcome.';
        } else if (rollType == CombatActionRoll.savingThrow) {
          final targetIndex = _targetIndexForAction(action);
          if (targetIndex == null) return;
          final target = _combatants[targetIndex];
          final saveDc = action.saveDc ?? 10;
          final success = result.total >= saveDc;
          if (!success) {
            final failureCondition = _savingThrowFailureCondition(action);
            if (failureCondition != null) {
              final nextCombatants = [..._combatants];
              nextCombatants[targetIndex] = _combatantWithCondition(
                target,
                failureCondition,
              );
              _combatants = nextCombatants;
              _applyEngineCondition(
                actor: _activeCombatant,
                target: target,
                name: failureCondition,
                sourceActionName: action.name,
              );
              _syncUiFromEncounter();
            }
          }
          if (action.damageFormula != null &&
              _savingThrowUsesEvasion(action, target)) {
            if (success) {
              _pendingDamageActions.remove(actionKey);
              _pendingHalfDamageActions.remove(actionKey);
              _activity.insert(
                0,
                CombatLogEntry.system(
                  '${target.name} avoids all ${action.name} damage with Evasion.',
                ),
              );
            } else {
              _pendingDamageActions.add(actionKey);
              _pendingHalfDamageActions.add(actionKey);
            }
          } else if (!success && action.damageFormula != null) {
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
              success ? CombatAccentKind.read : CombatAccentKind.magic;
          boardEventLabel =
              success ? 'SAVE ${result.total}' : 'FAIL ${result.total}';
          boardEventKind = success ? 'miss' : 'hit';
          detail =
              '${result.formula} - ${result.rollsText}. ${target.name} ${success ? 'succeeds' : 'fails'} ${action.saveAbility} save vs DC $saveDc.';
        } else {
          final targetIndex = _targetIndexForAction(action);
          if (targetIndex == null) return;
          final target = _combatants[targetIndex];
          final isHalfDamage = !action.isHealing &&
              _pendingHalfDamageActions.contains(actionKey);
          final damageBonus = isHalfDamage
              ? 0
              : _situationalDamageBonus(_activeCombatant, action);
          final passiveDamageResult = passiveDamageResultForResolvedDamage;
          final amount = isHalfDamage
              ? (result.total / 2).floor()
              : result.total + damageBonus + (passiveDamageResult?.total ?? 0);
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
          final passiveDetail = passiveDamageResult == null
              ? ''
              : ' Improved Divine Smite adds ${passiveDamageResult.total} radiant (${passiveDamageResult.rollsText}).';
          headline = action.isHealing
              ? 'HEAL $amount'
              : isHalfDamage
                  ? '$amount HALF DAMAGE'
                  : '$amount DAMAGE';
          subline = _hpChangeLine(target, hpResult);
          feedbackKind = action.isHealing
              ? CombatAccentKind.support
              : CombatAccentKind.action;
          boardEventLabel =
              action.isHealing ? 'HEAL $amount' : '$amount DAMAGE';
          boardEventKind = action.isHealing ? 'heal' : 'damage';
          detail =
              '${result.formula} - ${result.rollsText}.$passiveDetail ${target.name} $verb $amount $suffix (${_hpChangeLine(target, hpResult)}).';

          if (!action.isHealing && target.hp > 0 && hpResult.hp == 0) {
            _activity.insert(
              0,
              CombatLogEntry.system('${target.name} is down.'),
            );
            _targetIndex = _findDefaultTargetIndex(_activeIndex);
          }
          _pendingDamageActions.remove(actionKey);
          _pendingHalfDamageActions.remove(actionKey);
          _selectBestCommandTimingAfterDamageResolution();
        }

        _activity.insert(
          0,
          CombatLogEntry.roll(
            actor: _activeCombatant.name,
            action: action.name,
            result: result,
            detail: detail,
          ),
        );
        _rollFeedback = CombatRollFeedback(
          actor: _activeCombatant.name,
          action: action.name,
          result: result,
          headline: headline,
          subline: subline,
          accentKind: feedbackKind,
        );
      });
      unawaited(
        _syncBattleBoardTokensFromCombatState(
          eventLabel: boardEventLabel,
          eventKind: boardEventKind,
          eventDiceNotation: boardEventDiceNotation,
          eventResultLabel: boardEventLabel ?? '',
          eventResultDetail: CombatDiceResultFormatter.detail(result),
          eventAuthoritativeDice:
              CombatDiceResultFormatter.authoritativeDiceJson(result),
          eventIdOverride: _consumeBoardResolvedRollEventId(),
          eventDamageType: action.isHealing ? '' : action.damageType ?? '',
        ),
      );
    } finally {
      _endCombatResolution(resolutionKey);
    }
  }

  Future<void> _rollDeathSavingThrowForActiveCombatant() async {
    final combatant = _activeCombatant;
    if (!_combatantCanOnlyDeathSave(combatant)) return;
    if (!_ensureCanControlCombatant(
      combatant,
      actionLabel: 'hacer death save',
    )) {
      return;
    }

    final result = await _rollCombatFormulaAwaitingBoard(
      formula: 'd20',
      label: '${combatant.name} Death Saving Throw',
      useRollMode: true,
    );
    final roll = _naturalD20(result) ?? result.total;
    final characterId =
        _characterSnapshotForCombatantId(combatant.id)?.characterId.trim();
    var message = '';
    var healedToOne = false;

    setState(() {
      if (roll == 1) {
        message = 'Natural 1: two death save failures.';
      } else if (roll == 20) {
        message = 'Natural 20: ${combatant.name} regains 1 HP.';
        healedToOne = true;
        final nextCombatants = [..._combatants];
        nextCombatants[_activeIndex] = combatant.copyWith(hp: 1);
        _combatants = nextCombatants;
        final encounter = _encounter;
        if (encounter != null) {
          _encounter = CombatEncounterEngine.applyHealing(
            encounter,
            sourceId: combatant.id,
            targetId: combatant.id,
            amount: 1,
            formula: 'Death Save natural 20',
          );
          _syncUiFromEncounter();
        }
      } else if (roll >= 10) {
        message = 'Death save success.';
      } else {
        message = 'Death save failure.';
      }
      _activity.insert(
        0,
        CombatLogEntry.roll(
          actor: combatant.name,
          action: 'Death Saving Throw',
          result: result,
          detail: '${result.formula} - ${result.rollsText}. $message',
        ),
      );
      _rollFeedback = CombatRollFeedback(
        actor: combatant.name,
        action: 'Death Saving Throw',
        result: result,
        headline: roll == 20
            ? 'NAT 20'
            : roll == 1
                ? 'NAT 1'
                : roll >= 10
                    ? 'SUCCESS'
                    : 'FAILURE',
        subline: message,
        accentKind:
            roll >= 10 ? CombatAccentKind.read : CombatAccentKind.action,
      );
    });

    if (characterId != null && characterId.isNotEmpty) {
      final provider = _characterProvider;
      if (provider != null) {
        await provider.updateCharacterById(characterId, (character) {
          if ((character.currentHp ?? 0) > 0 && !healedToOne) return;
          if (roll == 1) {
            character.deathSaveFailures =
                (character.deathSaveFailures + 2).clamp(0, 3).toInt();
          } else if (roll == 20) {
            character.currentHp = 1;
            character.deathSaveSuccesses = 0;
            character.deathSaveFailures = 0;
          } else if (roll >= 10) {
            character.deathSaveSuccesses =
                (character.deathSaveSuccesses + 1).clamp(0, 3).toInt();
          } else {
            character.deathSaveFailures =
                (character.deathSaveFailures + 1).clamp(0, 3).toInt();
          }
        });
      }
    }

    if (healedToOne) {
      _queueCharacterCombatSnapshot(combatant.id, flushNow: true);
    }
    if (_showBattleBoardController) {
      unawaited(
        _syncBattleBoardTokensFromCombatState(
          eventLabel: roll >= 10 ? 'DEATH SAVE OK' : 'DEATH SAVE FAIL',
          eventKind: roll >= 10 ? 'focus' : 'blocked',
          eventDiceNotation:
              CombatDiceResultFormatter.diceBoxNotation(result) ?? '',
          eventResultLabel:
              roll >= 10 ? 'SAVE ${result.total}' : 'FAIL ${result.total}',
          eventResultDetail: CombatDiceResultFormatter.detail(result),
          eventAuthoritativeDice:
              CombatDiceResultFormatter.authoritativeDiceJson(result),
          eventIdOverride: _consumeBoardResolvedRollEventId(),
          eventTargetIds: {combatant.id},
          eventDiceTargetId: combatant.id,
          eventSourceRefId: combatant.id,
          eventPrimaryTargetRefId: combatant.id,
        ),
      );
    }
  }

  void _resolveAreaSavingThrowAction(CombatAction action) {
    final actionKey = _actionExecutionKey(action);
    final existingPending = _pendingAreaSavingThrow;
    if (existingPending != null) {
      if (existingPending.matches(
        actorId: _activeCombatant.id,
        actionKey: actionKey,
      )) {
        unawaited(_rollPendingAreaSavingThrowAsync(action));
        return;
      }

      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            'Resolve ${existingPending.action.name} before starting ${action.name}.',
          ),
        );
      });
      return;
    }

    final targetIndices = _areaTargetIndicesForAction(action);
    if (targetIndices.isEmpty) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system('${action.name} has no affected targets.'),
        );
      });
      return;
    }

    final saveDc = action.saveDc ?? 10;
    final affectedTargetIds = <String>{
      for (final index in targetIndices)
        if (index >= 0 && index < _combatants.length) _combatants[index].id,
    };
    final primaryTargetIndex = _targetIndexForAction(action);
    final primaryTargetId =
        primaryTargetIndex == null ? null : _combatants[primaryTargetIndex].id;
    final diceTargetId =
        primaryTargetId != null && affectedTargetIds.contains(primaryTargetId)
            ? primaryTargetId
            : affectedTargetIds.isEmpty
                ? primaryTargetId
                : affectedTargetIds.first;
    final areaAimPoint = _areaAimPointForAction(action);

    setState(() {
      _resetQueuedPreparedActions();
      _pendingDamageActions.add(actionKey);
      _pendingHalfDamageActions.remove(actionKey);
      _spendActionOrAttackSlot(action, CombatActionRoll.savingThrow);
      _spendEngineActionResource(action);
      final economyMessage = _applyActionEconomyEffect(action);
      if (economyMessage != null) {
        _activity.insert(0, CombatLogEntry.system(economyMessage));
      }
      final condition = _applyActionState(action);
      if (condition != null) {
        _applyEngineCondition(
          actor: _activeCombatant,
          target: _activeCombatant,
          name: condition,
          sourceActionName: action.name,
        );
      }
      _pendingAreaSavingThrow = PendingAreaSavingThrow(
        actorId: _activeCombatant.id,
        actionKey: actionKey,
        action: action,
        targetIds: targetIndices
            .where((index) => index >= 0 && index < _combatants.length)
            .map((index) => _combatants[index].id)
            .toList(growable: false),
        primaryTargetId: primaryTargetId,
        diceTargetId: diceTargetId,
        areaAimPoint: areaAimPoint,
      );
      final pending = _pendingAreaSavingThrow;
      final firstSaveIndex =
          pending == null ? null : _nextPendingAreaSaveTargetIndex(pending);
      final firstSaveTarget =
          firstSaveIndex == null ? null : _combatants[firstSaveIndex];
      if (firstSaveIndex != null) {
        _targetIndex = firstSaveIndex;
      }
      _activity.insert(
        0,
        CombatLogEntry.system(
          '${action.name}: waiting for ${targetIndices.length} ${action.saveAbility} saving throw${targetIndices.length == 1 ? '' : 's'} before damage.',
        ),
      );
      _rollFeedback = CombatRollFeedback.manual(
        actor: _activeCombatant.name,
        action: action.name,
        headline: 'SAVES PENDING',
        subline: firstSaveTarget == null
            ? '${targetIndices.length} target${targetIndices.length == 1 ? '' : 's'} - DC $saveDc ${action.saveAbility}'
            : '${firstSaveTarget.name} must roll ${action.saveAbility} DC $saveDc',
        accentKind: CombatAccentKind.magic,
      );
    });

    if (_showBattleBoardController) {
      unawaited(
        _syncBattleBoardTokensFromCombatState(
          eventLabel: 'SAVE DC $saveDc',
          eventKind: 'focus',
          eventDiceNotation: '',
          eventResultLabel: 'SAVE DC $saveDc',
          eventResultDetail:
              '${targetIndices.length} target${targetIndices.length == 1 ? '' : 's'} must roll ${action.saveAbility}.',
          eventAuthoritativeDice: '',
          eventDamageType: action.damageType ?? '',
          eventTargetIds: affectedTargetIds,
          eventDiceTargetId: diceTargetId,
          eventSourceRefId: _activeCombatant.id,
          eventPrimaryTargetRefId: primaryTargetId,
          eventAreaShape: action.areaShape,
          eventAreaFeet: action.areaFeet,
          eventAreaTargetX: areaAimPoint?.x,
          eventAreaTargetY: areaAimPoint?.y,
        ),
      );
    }
  }

  void _rollPendingAreaSavingThrow(CombatAction action) {
    if (_combatRollInFlight) return;
    unawaited(_rollPendingAreaSavingThrowAsync(action));
  }

  Future<void> _rollPendingAreaSavingThrowAsync(CombatAction action) async {
    final pending = _pendingAreaSavingThrow;
    if (pending == null) return;
    final targetIndex = _nextPendingAreaSaveTargetIndex(
      pending,
      controllableOnly: !_dmView && !_devCombatMode,
    );
    if (targetIndex == null) {
      final nextAnyTarget = _nextPendingAreaSaveTargetIndex(pending);
      if (nextAnyTarget == null) {
        await _finishPendingAreaSavingThrowAsync();
      } else {
        final target = _combatants[nextAnyTarget];
        setState(() {
          _activity.insert(
            0,
            CombatLogEntry.system(
              'Waiting for ${target.name} to roll ${pending.action.saveAbility} save.',
            ),
          );
          _rollFeedback = CombatRollFeedback.manual(
            actor: target.name,
            action: '${pending.action.name} save',
            headline: 'SAVE REQUIRED',
            subline:
                '${target.name} must roll ${pending.action.saveAbility} DC ${pending.action.saveDc ?? 10}',
            accentKind: CombatAccentKind.magic,
          );
        });
      }
      return;
    }

    final target = _combatants[targetIndex];
    final resolutionKey =
        'area-save:${pending.actorId}:${pending.actionKey}:${target.id}';
    if (!_beginCombatResolution(resolutionKey)) return;
    try {
      final saveDc = pending.action.saveDc ?? 10;
      final saveResult = await _rollCombatFormulaAwaitingBoard(
        formula: _savingThrowFormulaForTarget(
          target,
          pending.action.saveAbility!,
        ),
        label: '${target.name} ${pending.action.saveAbility} Save',
        useRollMode: true,
        forceAdvantage: _savingThrowHasAdvantage(
          target,
          pending.action.saveAbility!,
          sourceAction: pending.action,
        ),
        forceDisadvantage: _savingThrowHasDisadvantage(
          target,
          pending.action.saveAbility!,
          sourceAction: pending.action,
        ),
      );
      final success = saveResult.total >= saveDc;
      final failureCondition = _savingThrowFailureCondition(pending.action);
      var completed = false;

      setState(() {
        var nextEncounter = _encounter;
        final nextCombatants = [..._combatants];
        pending.outcomes[target.id] = PendingAreaSaveOutcome(
          result: saveResult,
          success: success,
        );

        _activity.insert(
          0,
          CombatLogEntry.roll(
            actor: target.name,
            action: '${pending.action.name} save',
            result: saveResult,
            detail:
                '${saveResult.formula} - ${saveResult.rollsText}. ${target.name} ${success ? 'succeeds' : 'fails'} ${pending.action.saveAbility} save vs DC $saveDc.',
          ),
        );

        if (!success && failureCondition != null) {
          nextCombatants[targetIndex] = _combatantWithCondition(
            nextCombatants[targetIndex],
            failureCondition,
          );
          if (nextEncounter != null) {
            nextEncounter = CombatEncounterEngine.applyEffect(
              nextEncounter,
              effect: encounter_models.CombatEffect(
                id: '${target.id}_${failureCondition.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
                name: failureCondition,
                kind: encounter_models.CombatEffectKind.condition,
                sourceCombatantId: pending.actorId,
                targetCombatantId: target.id,
                startedRound: _round,
                endsAtRound: _round + 10,
                visibleToPlayers: true,
                mechanics: {'sourceAction': pending.action.name},
              ),
            );
          }
          _activity.insert(
            0,
            CombatLogEntry.system('${target.name} is $failureCondition.'),
          );
        }

        _combatants = nextCombatants;
        if (nextEncounter != null) {
          _encounter = nextEncounter;
          _syncUiFromEncounter();
        }

        final remaining = pending.unresolvedTargetIds.length;
        _rollFeedback = CombatRollFeedback(
          actor: target.name,
          action: '${pending.action.name} save',
          result: saveResult,
          headline: success ? 'SAVE SUCCESS' : 'SAVE FAILED',
          subline: remaining == 0
              ? 'All saves resolved'
              : '$remaining save${remaining == 1 ? '' : 's'} remaining',
          accentKind: success ? CombatAccentKind.read : CombatAccentKind.magic,
        );

        final nextTargetIndex = _nextPendingAreaSaveTargetIndex(pending);
        if (nextTargetIndex != null) {
          _targetIndex = nextTargetIndex;
        }
        completed = pending.isComplete;
      });

      if (_showBattleBoardController) {
        unawaited(
          _syncBattleBoardTokensFromCombatState(
            eventLabel: success
                ? 'SAVE ${saveResult.total}'
                : 'FAIL ${saveResult.total}',
            eventKind: success ? 'miss' : 'hit',
            eventDiceNotation:
                CombatDiceResultFormatter.diceBoxNotation(saveResult) ?? '',
            eventResultLabel: success
                ? 'SAVE ${saveResult.total}'
                : 'FAIL ${saveResult.total}',
            eventResultDetail: CombatDiceResultFormatter.detail(saveResult),
            eventAuthoritativeDice:
                CombatDiceResultFormatter.authoritativeDiceJson(saveResult),
            eventIdOverride: _consumeBoardResolvedRollEventId(),
            eventDamageType: pending.action.damageType ?? '',
            eventTargetIds: pending.targetIds.toSet(),
            eventDiceTargetId: target.id,
            eventSourceRefId: pending.actorId,
            eventPrimaryTargetRefId: pending.primaryTargetId,
            eventAreaShape: pending.action.areaShape,
            eventAreaFeet: pending.action.areaFeet,
            eventAreaTargetX: pending.areaAimPoint?.x,
            eventAreaTargetY: pending.areaAimPoint?.y,
          ),
        );
      }

      if (completed) {
        await _finishPendingAreaSavingThrowAsync();
      }
    } finally {
      _endCombatResolution(resolutionKey);
    }
  }

  void _finishPendingAreaSavingThrow() {
    unawaited(_finishPendingAreaSavingThrowAsync());
  }

  Future<void> _finishPendingAreaSavingThrowAsync() async {
    final pending = _pendingAreaSavingThrow;
    if (pending == null) return;
    final action = pending.action;
    final actionKey = pending.actionKey;
    final resolutionKey = 'area-finish:${pending.actorId}:$actionKey';
    if (!_beginCombatResolution(resolutionKey)) return;
    try {
      final saveDc = action.saveDc ?? 10;
      final damageResult = action.damageFormula == null
          ? null
          : await _rollCombatFormulaAwaitingBoard(
              formula: action.damageFormula!,
              label: '${action.name} Damage',
            );
      final successes =
          pending.outcomes.values.where((item) => item.success).length;
      final failures = pending.outcomes.length - successes;
      var totalDamage = 0;

      setState(() {
        var nextEncounter = _encounter;
        final nextCombatants = [..._combatants];

        if (damageResult != null) {
          for (final targetId in pending.targetIds) {
            final outcome = pending.outcomes[targetId];
            if (outcome == null) continue;
            final targetIndex = _combatantIndexById(targetId, nextCombatants);
            if (targetIndex == null) continue;
            final target = nextCombatants[targetIndex];
            if (target.hp <= 0) continue;
            if (outcome.success && !action.halfDamageOnSave) continue;

            final damageResolution = _resolveSavingThrowDamage(
              action: action,
              target: target,
              success: outcome.success,
              rolledDamage: damageResult.total,
            );
            final amount = damageResolution.amount;
            if (damageResolution.absorbElementsAction != null) {
              _applyAbsorbElementsReactionCost(
                target,
                damageResolution.absorbElementsAction!,
                encounterOverride: (next) => nextEncounter = next,
                currentEncounter: nextEncounter,
              );
            }
            if (amount <= 0) {
              _activity.insert(
                0,
                CombatLogEntry.system(
                  '${target.name} avoids all ${action.name} damage${damageResolution.labelSuffix}.',
                ),
              );
              continue;
            }

            final hpResult = _resolveHpChange(target, amount, healing: false);
            nextCombatants[targetIndex] = target.copyWith(
              hp: hpResult.hp,
              tempHp: hpResult.tempHp,
            );
            totalDamage += amount;
            final encounterForDamage = nextEncounter;
            if (encounterForDamage != null) {
              nextEncounter = CombatEncounterEngine.applyDamage(
                encounterForDamage,
                sourceId: pending.actorId,
                targetId: target.id,
                amount: amount,
                actionId: action.id.isEmpty ? null : action.id,
                formula: damageResult.formula,
              );
              _queueCharacterCombatSnapshot(target.id);
            }
            _activity.insert(
              0,
              CombatLogEntry.roll(
                actor: _activeCombatant.name,
                action: '${action.name} damage',
                result: damageResult,
                detail:
                    '${damageResult.formula} - ${damageResult.rollsText}. ${target.name} takes $amount ${damageResolution.label} (${_hpChangeLine(target, hpResult)}).',
              ),
            );
            if (target.hp > 0 && hpResult.hp == 0) {
              _activity.insert(
                0,
                CombatLogEntry.system('${target.name} is down.'),
              );
            }
          }
        }

        _combatants = nextCombatants;
        if (nextEncounter != null) {
          _encounter = nextEncounter;
          _syncUiFromEncounter();
        }
        _pendingDamageActions.remove(actionKey);
        _pendingHalfDamageActions.remove(actionKey);
        _pendingAreaSavingThrow = null;
        _selectBestCommandTimingAfterDamageResolution();
        _activity.insert(
          0,
          CombatLogEntry.system(
            damageResult == null
                ? '${action.name} saves resolved: $failures failed / $successes saved.'
                : '${action.name} resolved after all saves: $totalDamage total damage.',
          ),
        );
        _rollFeedback = CombatRollFeedback(
          actor: _activeCombatant.name,
          action: action.name,
          result: damageResult ??
              (pending.outcomes.isEmpty
                  ? null
                  : pending.outcomes.values.last.result),
          headline: damageResult == null
              ? '$failures FAILED / $successes SAVED'
              : '$totalDamage AREA DAMAGE',
          subline:
              '${pending.targetIds.length} target${pending.targetIds.length == 1 ? '' : 's'} - DC $saveDc ${action.saveAbility}',
          accentKind:
              totalDamage > 0 ? CombatAccentKind.magic : CombatAccentKind.read,
        );
      });

      if (_showBattleBoardController) {
        unawaited(
          _syncBattleBoardTokensFromCombatState(
            eventLabel:
                damageResult == null ? '$failures FAIL' : '$totalDamage AREA',
            eventKind: totalDamage > 0 ? 'damage' : 'focus',
            eventDiceNotation: damageResult == null
                ? ''
                : CombatDiceResultFormatter.diceBoxNotation(damageResult) ?? '',
            eventResultLabel:
                damageResult == null ? '$failures FAIL' : '$totalDamage AREA',
            eventResultDetail: damageResult == null
                ? '${pending.targetIds.length} targets - DC $saveDc'
                : CombatDiceResultFormatter.detail(damageResult),
            eventAuthoritativeDice: damageResult == null
                ? ''
                : CombatDiceResultFormatter.authoritativeDiceJson(damageResult),
            eventIdOverride: damageResult == null
                ? null
                : _consumeBoardResolvedRollEventId(),
            eventDamageType: action.damageType ?? '',
            eventTargetIds: pending.targetIds.toSet(),
            eventDiceTargetId: pending.diceTargetId,
            eventSourceRefId: pending.actorId,
            eventPrimaryTargetRefId: pending.primaryTargetId,
            eventAreaShape: action.areaShape,
            eventAreaFeet: action.areaFeet,
            eventAreaTargetX: pending.areaAimPoint?.x,
            eventAreaTargetY: pending.areaAimPoint?.y,
          ),
        );
      }
    } finally {
      _endCombatResolution(resolutionKey);
    }
  }

  int? _nextPendingAreaSaveTargetIndex(
    PendingAreaSavingThrow pending, {
    bool controllableOnly = false,
  }) {
    if (pending.unresolvedTargetIds.isEmpty) return null;
    final selectedId = _selectedTarget.id;
    if (pending.unresolvedTargetIds.contains(selectedId)) {
      final selectedIndex = _combatantIndexById(selectedId);
      if (selectedIndex != null &&
          _combatants[selectedIndex].hp > 0 &&
          (!controllableOnly ||
              _canControlCombatant(_combatants[selectedIndex]))) {
        return selectedIndex;
      }
    }
    for (final targetId in pending.unresolvedTargetIds) {
      final index = _combatantIndexById(targetId);
      if (index != null &&
          _combatants[index].hp > 0 &&
          (!controllableOnly || _canControlCombatant(_combatants[index]))) {
        return index;
      }
    }
    return null;
  }

  int? _combatantIndexById(String combatantId, [List<Combatant>? source]) {
    final list = source ?? _combatants;
    final index = list.indexWhere((combatant) => combatant.id == combatantId);
    return index < 0 ? null : index;
  }

  List<int> _areaTargetIndicesForAction(CombatAction action) {
    final primaryTargetIndex = _targetIndexForAction(action);
    if (primaryTargetIndex == null) return const [];
    if (!action.hasAreaEffect) return [primaryTargetIndex];

    final sceneId = _activeBattleBoardSceneId;
    if (sceneId == null) return [primaryTargetIndex];
    final boardProvider = context.read<BattleBoardProvider>();
    final sceneTokens = boardProvider.tokens
        .where((token) => token.sceneId == sceneId)
        .toList(growable: false);
    final primaryToken = CombatBoardTokenLookup.byRef(
        sceneTokens, _combatants[primaryTargetIndex].id);
    final actorToken =
        CombatBoardTokenLookup.byRef(sceneTokens, _activeCombatant.id);
    if (primaryToken == null) return [primaryTargetIndex];
    final aimToken = _areaAimTokenForAction(
      action: action,
      sceneId: sceneId,
      sceneTokens: sceneTokens,
      fallbackToken: primaryToken,
    );

    final affected = <int>{};
    for (var index = 0; index < _combatants.length; index++) {
      final candidate = _combatants[index];
      if (candidate.hp <= 0) continue;
      if (candidate.id == _activeCombatant.id) continue;
      final token = CombatBoardTokenLookup.byRef(sceneTokens, candidate.id);
      if (token == null) continue;

      final affectedByShape = _areaActionAffectsToken(
        action: action,
        originToken: aimToken,
        candidateToken: token,
        actorToken: actorToken,
      );
      if (affectedByShape) affected.add(index);
    }

    return affected.toList(growable: false)..sort();
  }

  BoardToken _areaAimTokenForAction({
    required CombatAction action,
    required String sceneId,
    required List<BoardToken> sceneTokens,
    required BoardToken fallbackToken,
  }) {
    final activeToken =
        CombatBoardTokenLookup.byRef(sceneTokens, _activeCombatant.id);
    final aimX = activeToken?.selectedActionAimX ?? -1;
    final aimY = activeToken?.selectedActionAimY ?? -1;
    if (action.hasAreaEffect && aimX >= 0 && aimY >= 0) {
      return BoardToken.create(
        id: '${sceneId}_area_aim',
        sceneId: sceneId,
        refId: 'area-aim',
        type: 'area',
        name: 'Area Aim',
        x: aimX,
        y: aimY,
        isVisible: false,
      );
    }
    return fallbackToken;
  }

  math.Point<int>? _areaAimPointForAction(CombatAction action) {
    if (!action.hasAreaEffect) return null;
    final sceneId = _activeBattleBoardSceneId;
    if (sceneId == null) return null;
    final boardProvider = context.read<BattleBoardProvider>();
    final sceneTokens = boardProvider.tokens
        .where((token) => token.sceneId == sceneId)
        .toList(growable: false);
    final activeToken =
        CombatBoardTokenLookup.byRef(sceneTokens, _activeCombatant.id);
    if (activeToken != null &&
        activeToken.selectedActionAimX >= 0 &&
        activeToken.selectedActionAimY >= 0) {
      return math.Point<int>(
        activeToken.selectedActionAimX,
        activeToken.selectedActionAimY,
      );
    }
    final targetIndex = _targetIndexForAction(action);
    if (targetIndex == null) return null;
    final targetToken =
        CombatBoardTokenLookup.byRef(sceneTokens, _combatants[targetIndex].id);
    if (targetToken == null) return null;
    return math.Point<int>(targetToken.x, targetToken.y);
  }

  bool _areaActionAffectsToken({
    required CombatAction action,
    required BoardToken originToken,
    required BoardToken candidateToken,
    BoardToken? actorToken,
  }) {
    return CombatBoardGeometry.areaAffectsToken(
      shape: action.areaShape,
      areaFeet: action.areaFeet,
      originToken: originToken,
      candidateToken: candidateToken,
      actorToken: actorToken,
    );
  }

  bool _tokenIsInLineArea({
    required BoardToken actorToken,
    required BoardToken targetToken,
    required BoardToken candidateToken,
    required int lengthFeet,
  }) {
    final start = _tokenCenterFeet(actorToken);
    final aim = _tokenCenterFeet(targetToken);
    final candidate = _tokenCenterFeet(candidateToken);
    final direction = aim - start;
    final directionLength = direction.distance;
    if (directionLength <= 0.001) {
      return _tokenCenterDistanceFeet(actorToken, candidateToken) <= 5;
    }

    final candidateVector = candidate - start;
    final projection = (candidateVector.dx * direction.dx +
            candidateVector.dy * direction.dy) /
        directionLength;
    if (projection < 0 || projection > lengthFeet) return false;

    final cross =
        (candidateVector.dx * direction.dy - candidateVector.dy * direction.dx)
            .abs();
    final perpendicular = cross / directionLength;
    final halfWidthFeet = 2.5 + candidateToken.size * 2.5;
    return perpendicular <= halfWidthFeet;
  }

  bool _tokenIsInConeArea({
    required BoardToken actorToken,
    required BoardToken targetToken,
    required BoardToken candidateToken,
    required int lengthFeet,
  }) {
    final start = _tokenCenterFeet(actorToken);
    final aim = _tokenCenterFeet(targetToken);
    final candidate = _tokenCenterFeet(candidateToken);
    final direction = aim - start;
    final directionLength = direction.distance;
    if (directionLength <= 0.001) {
      return _tokenCenterDistanceFeet(actorToken, candidateToken) <= lengthFeet;
    }

    final candidateVector = candidate - start;
    final candidateDistance = candidateVector.distance;
    if (candidateDistance <= 0.001) return true;
    if (candidateDistance > lengthFeet + candidateToken.size * 2.5) {
      return false;
    }

    final cosine = (candidateVector.dx * direction.dx +
            candidateVector.dy * direction.dy) /
        (candidateDistance * directionLength);
    const halfConeCosine = 0.8660254038; // 30 degrees.
    return cosine >= halfConeCosine;
  }

  Offset _tokenCenterFeet(BoardToken token) {
    return Offset(
      (token.x + token.size / 2) * 5,
      (token.y + token.size / 2) * 5,
    );
  }

  double _tokenCenterDistanceFeet(BoardToken a, BoardToken b) {
    return (_tokenCenterFeet(a) - _tokenCenterFeet(b)).distance;
  }

  String? _savingThrowFailureCondition(CombatAction action) {
    final text = '${action.name} ${action.tags.join(' ')}'.toLowerCase();
    if (text.contains('turn undead')) return 'Turned';
    if (text.contains('stunning strike') || text.contains('stunned')) {
      return 'Stunned';
    }
    if (text.contains('trip attack') || text.contains('prone')) return 'Prone';
    if (text.contains('menacing attack') || text.contains('frightened')) {
      return 'Frightened';
    }
    if (text.contains('goading attack') || text.contains('goaded')) {
      return 'Goaded';
    }
    if (text.contains('disarming attack') || text.contains('disarmed')) {
      return 'Disarmed';
    }
    if (text.contains('pushing attack') || text.contains('pushed')) {
      return 'Pushed';
    }
    if (text.contains('weakening breath') || text.contains('weakened')) {
      return 'Weakened';
    }
    if (text.contains('sleep breath') || text.contains('unconscious')) {
      return 'Unconscious';
    }
    if (text.contains('poisoned')) return 'Poisoned';
    if (text.contains('restrained')) return 'Restrained';
    if (text.contains('paralyzed')) return 'Paralyzed';
    return null;
  }

  Combatant _combatantWithCondition(Combatant combatant, String condition) {
    if (combatant.conditions.contains(condition)) return combatant;
    return combatant.copyWith(
      conditions: [
        condition,
        ...combatant.conditions.where((item) => item != condition),
      ],
    );
  }

  void _useReaction(int actorIndex, CombatAction action) {
    if (_combatRollInFlight) return;
    unawaited(_useReactionAsync(actorIndex, action));
  }

  Future<void> _useReactionAsync(int actorIndex, CombatAction action) async {
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
          CombatLogEntry.system(
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
          CombatLogEntry.system(
            '${actor.name} has already spent a reaction.',
          ),
        );
      });
      return;
    }

    final resourceBlock = _reactionResourceBlockMessage(actor, action);
    if (resourceBlock != null) {
      setState(() {
        _activity.insert(0, CombatLogEntry.system(resourceBlock));
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
        CombatLogEntry.system(
          isReadiedAction
              ? '${actor.name} triggers readied action: ${action.name}.'
              : '${actor.name} uses reaction: ${action.name}.',
        ),
      );
      if (!isReadiedAction) {
        _spendEngineActionResourceForCombatant(action, actor);
      }
    });
    final feedback = await _resolvePreparedAction(
      action,
      actorIndex: actorIndex,
      forcedTargetIndex: _activeIndex,
    );
    if (!mounted) return;
    setState(() {
      _rollFeedback = feedback;
    });
  }

  String? _reactionResourceBlockMessage(
    Combatant actor,
    CombatAction action,
  ) {
    final resourceKey = action.resourceKey;
    final resourceCost = action.resourceCost;
    if (resourceKey == null || resourceCost <= 0) return null;

    final pool = _encounter?.combatantById(actor.id)?.resources ?? const {};
    final remaining = pool[resourceKey] ?? 0;
    if (remaining >= resourceCost) return null;
    return '${actor.name} cannot react: ${_readableActionResourceName(resourceKey)} is depleted.';
  }

  Future<void> _readyAction(CombatAction action) async {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (!_ensureActionTargetAvailable(action)) return;
    if (action.timing != 'Action') {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
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
          CombatLogEntry.system(
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
          CombatLogEntry.system(
            '${_activeCombatant.name} needs an available reaction to Ready.',
          ),
        );
      });
      return;
    }
    final resourceBlock = _actionResourceBlockMessage(action);
    if (resourceBlock != null) {
      setState(() {
        _activity.insert(0, CombatLogEntry.system(resourceBlock));
      });
      return;
    }

    final trigger = await _askReadyTrigger(action);
    if (!mounted || trigger == null || trigger.trim().isEmpty) return;
    final targetIndex = _targetIndexForAction(action);
    if (targetIndex == null) {
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
      _readiedActionsByCombatantId[_activeCombatant.id] = ReadiedAction(
        combatantId: _activeCombatant.id,
        action: action,
        trigger: trigger.trim(),
        round: _round,
        targetId: _combatants[targetIndex].id,
        concentrationRequired: concentrationRequired,
      );
      _rollFeedback = CombatRollFeedback.manual(
        actor: _activeCombatant.name,
        action: 'Ready ${action.name}',
        headline: 'READY',
        subline: trigger.trim(),
        accentKind: action.accentKind,
      );
      _activity.insert(
        0,
        CombatLogEntry.system(
          '${_activeCombatant.name} readies ${action.name}: ${trigger.trim()}',
        ),
      );
    });
  }

  Future<String?> _askReadyTrigger(CombatAction action) {
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

  bool _actionRequiresConcentrationToReady(CombatAction action) {
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    return text.contains('spell') && !text.contains('cantrip');
  }

  CombatAction _concentrationReadyMarker(CombatAction action) {
    return CombatAction(
      id: '${action.id}|ready_concentration',
      name: 'Ready ${action.name}',
      type: 'Concentration',
      timing: 'Action',
      attackFormula: null,
      damageFormula: null,
      critFormula: null,
      tags: const ['Concentration'],
      icon: Icons.psychology_alt_outlined,
      accentKind: CombatAccentKind.magic,
      targetsSelf: true,
    );
  }

  void _rollMultiAttackStep(
    CombatAction action,
    CombatActionRoll rollType,
  ) {
    if (_combatRollInFlight) return;
    unawaited(_rollMultiAttackStepAsync(action, rollType));
  }

  Future<void> _rollMultiAttackStepAsync(
    CombatAction action,
    CombatActionRoll rollType,
  ) async {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    final actionKey = _actionExecutionKey(action);
    final currentProgress = _multiAttackProgress;
    final currentStepIndex =
        currentProgress?.pendingStepIndex ?? currentProgress?.stepIndex ?? 0;
    final currentTargetIndex =
        currentProgress?.pendingTargetIndex ?? _targetIndexForAction(action);
    final resolutionKey = _combatResolutionKey(
      currentProgress?.hasPendingDamage == true
          ? 'multi-damage-request'
          : 'multi-step',
      action,
      rollType: rollType,
      targetIndex: currentTargetIndex,
      stepIndex: currentStepIndex,
    );
    if (!_beginCombatResolution(resolutionKey)) return;
    try {
      final hasActiveProgress = currentProgress != null &&
          currentProgress.actionKey == actionKey &&
          currentProgress.stepIndex < action.multiAttackSteps.length;

      if (!hasActiveProgress && !_ensureActionTargetAvailable(action)) return;
      if (!hasActiveProgress && !_ensureActionPrerequisites(action)) return;
      if (!hasActiveProgress && !_ensureBattleBoardActionRange(action)) return;
      _focusedBattleBoardAction = action;

      if (!hasActiveProgress) {
        final resourceBlock = _actionResourceBlockMessage(action);
        if (resourceBlock != null) {
          setState(() {
            _activity.insert(0, CombatLogEntry.system(resourceBlock));
          });
          return;
        }
        if (_spentTimings.contains(action.timing)) {
          setState(() {
            _activity.insert(
              0,
              CombatLogEntry.system(
                '${action.timing} is already spent this turn.',
              ),
            );
          });
          return;
        }
      }

      DiceRollResult? boardAttackResult;
      if (rollType == CombatActionRoll.attack ||
          rollType == CombatActionRoll.savingThrow) {
        final previewProgress = hasActiveProgress
            ? currentProgress
            : MultiAttackProgress(
                actionKey: actionKey,
                pendingAttacks: _pendingCombatAttacksForAction(action),
              );
        if (!previewProgress.hasPendingDamage &&
            previewProgress.stepIndex < action.multiAttackSteps.length) {
          final step = action.multiAttackSteps[previewProgress.stepIndex];
          final attackFormula = step.attackFormula;
          final targetIndex = _targetIndexForAction(action);
          if (attackFormula != null && targetIndex != null) {
            final stepNumber = previewProgress.stepIndex + 1;
            final stepLabel = '${action.name} $stepNumber: ${step.name}';
            boardAttackResult = await _rollCombatFormulaAwaitingBoard(
              formula: attackFormula,
              label: '$stepLabel Attack',
              useRollMode: true,
              forceDisadvantage: _attackHasLongRangeDisadvantage(action),
            );
          }
        }
      }

      String? boardEventLabel;
      var boardEventKind = 'focus';
      var boardEventDiceNotation = '';
      var boardEventResultLabel = '';
      var boardEventResultDetail = '';
      var boardEventAuthoritativeDice = '';
      setState(() {
        var progress = hasActiveProgress
            ? currentProgress
            : MultiAttackProgress(
                actionKey: actionKey,
                pendingAttacks: _pendingCombatAttacksForAction(action),
              );

        if (!hasActiveProgress) {
          _resetQueuedPreparedActions();
          _pendingDamageActions.remove(actionKey);
          _pendingHalfDamageActions.remove(actionKey);
          _spentTimings.add(action.timing);
          _spendEngineActionResource(action);
          final economyMessage = _applyActionEconomyEffect(action);
          if (economyMessage != null) {
            _activity.insert(0, CombatLogEntry.system(economyMessage));
          }
          _multiAttackProgress = progress;
          _activity.insert(
            0,
            CombatLogEntry.system(
              '${_activeCombatant.name} starts ${action.name}: ${action.multiAttackSteps.length} attacks.',
            ),
          );
        }

        if (progress.hasPendingDamage) {
          if (rollType == CombatActionRoll.attack ||
              rollType == CombatActionRoll.savingThrow) {
            _activity.insert(
              0,
              CombatLogEntry.system(
                'Resolve ${action.name} damage before the next attack.',
              ),
            );
            return;
          }
          _resolveMultiAttackPendingDamage(action, progress);
          return;
        }

        if (rollType == CombatActionRoll.damage ||
            rollType == CombatActionRoll.critical) {
          _activity.insert(
            0,
            CombatLogEntry.system(
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
          progress.markDamagePending(progress.stepIndex);
          _pendingDamageActions.add(actionKey);
          _resolveMultiAttackPendingDamage(action, progress);
          return;
        }

        final attackFormula = step.attackFormula;
        if (attackFormula == null) {
          progress.markResolved(progress.stepIndex);
          progress.stepIndex += 1;
          _advanceMultiAttackAfterStep(action, progress);
          return;
        }

        final targetIndex = _targetIndexForAction(action);
        if (targetIndex == null) return;
        final target = _combatants[targetIndex];
        final stepNumber = progress.stepIndex + 1;
        final stepLabel = '${action.name} $stepNumber: ${step.name}';
        final result = boardAttackResult ??
            _rollCombatFormula(
              formula: attackFormula,
              label: '$stepLabel Attack',
              useRollMode: true,
              forceDisadvantage: _attackHasLongRangeDisadvantage(action),
            );
        final outcome = _attackOutcome(result, target, action);
        final didHit = outcome == 'hit' || outcome == 'critical hit';
        final didCrit = outcome == 'critical hit';
        progress.attackCount += 1;
        if (didCrit) progress.critCount += 1;

        _activity.insert(
          0,
          CombatLogEntry.roll(
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
          progress.markDamagePending(progress.stepIndex);
          _pendingDamageActions.add(actionKey);
          _queueOnHitPromptIfAvailable(target.name);
          _selectBestCommandTimingAfterAttackRoll(didHit: true);
        } else {
          progress.markResolved(
            progress.stepIndex,
            status: PendingCombatAttackStatus.missed,
          );
          progress.stepIndex += 1;
          _pendingDamageActions.remove(actionKey);
          _selectBestCommandTimingAfterAttackRoll(didHit: false);
          _advanceMultiAttackAfterStep(action, progress);
        }
        boardEventLabel = didCrit
            ? 'CRIT ${result.total}'
            : didHit
                ? 'HIT ${result.total}'
                : 'MISS ${result.total}';
        boardEventKind = didCrit
            ? 'critical'
            : didHit
                ? 'hit'
                : 'miss';
        boardEventDiceNotation =
            CombatDiceResultFormatter.diceBoxNotation(result) ?? '';
        boardEventResultLabel = boardEventLabel ?? '';
        boardEventResultDetail = CombatDiceResultFormatter.detail(result);
        boardEventAuthoritativeDice =
            CombatDiceResultFormatter.authoritativeDiceJson(result);

        _rollFeedback = CombatRollFeedback(
          actor: _activeCombatant.name,
          action: action.name,
          result: result,
          headline: outcome.toUpperCase(),
          subline:
              'Attack $stepNumber/${action.multiAttackSteps.length} vs ${target.name}',
          accentKind: switch (outcome) {
            'critical hit' => CombatAccentKind.support,
            'hit' => CombatAccentKind.action,
            'automatic miss' => CombatAccentKind.info,
            _ => CombatAccentKind.read,
          },
        );
      });
      if (_showBattleBoardController) {
        final boardRollEventId = boardAttackResult == null
            ? null
            : _consumeBoardResolvedRollEventId();
        unawaited(
          _syncBattleBoardTokensFromCombatState(
            eventLabel: boardEventLabel,
            eventKind: boardEventKind,
            eventDiceNotation: boardEventDiceNotation,
            eventResultLabel: boardEventResultLabel,
            eventResultDetail: boardEventResultDetail,
            eventAuthoritativeDice: boardEventAuthoritativeDice,
            eventIdOverride: boardRollEventId,
          ),
        );
      }
    } finally {
      _endCombatResolution(resolutionKey);
    }
  }

  bool _multiAttackProgressMatches(CombatAction action) {
    final progress = _multiAttackProgress;
    return progress != null &&
        progress.actionKey == _actionExecutionKey(action) &&
        progress.stepIndex < action.multiAttackSteps.length;
  }

  void _activateMartialArtsBonusStrike(CombatAction action) {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (!_ensureActionTargetAvailable(action)) return;
    if (!_ensureActionPrerequisites(action)) return;
    if (!_ensureBattleBoardActionRange(action)) return;

    final actionKey = _actionExecutionKey(action);
    final activeProgress = _multiAttackProgress;
    if (activeProgress != null && activeProgress.actionKey == actionKey) {
      setState(() {
        _selectedCommandTiming = 'Action';
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${action.name} is already active: resolve the bonus strike.',
          ),
        );
      });
      return;
    }

    if (!_hasMartialArtsEligibleAttackThisTurn(_activeCombatant)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${action.name} requires an unarmed strike or monk weapon Attack action first this turn.',
          ),
        );
      });
      return;
    }

    if (_pendingDamageActions.any((pendingKey) => pendingKey != actionKey)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            'Resolve pending damage before activating ${action.name}.',
          ),
        );
      });
      return;
    }

    if (_spentTimings.contains(action.timing)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${action.name} cannot be activated: ${action.timing} is already spent.',
          ),
        );
      });
      return;
    }

    setState(() {
      _resetQueuedPreparedActions();
      _pendingDamageActions.remove(actionKey);
      _pendingHalfDamageActions.remove(actionKey);
      _spentTimings.add(action.timing);
      _multiAttackProgress = MultiAttackProgress(
        actionKey: actionKey,
        pendingAttacks: _pendingCombatAttacksForAction(
          action,
          labelPrefix: 'Martial Arts Strike',
          source: PendingCombatAttackSource.martialArts,
        ),
      );
      _selectedCommandTiming = 'Action';
      _activity.insert(
        0,
        CombatLogEntry.system(
          '${_activeCombatant.name} uses Martial Arts as a Bonus Action: 1 bonus strike ready.',
        ),
      );
      _rollFeedback = CombatRollFeedback.manual(
        actor: _activeCombatant.name,
        action: action.name,
        headline: 'MARTIAL ARTS',
        subline: '1 bonus unarmed strike ready.',
        accentKind: CombatAccentKind.info,
      );
    });
  }

  void _activateFlurryOfBlows(CombatAction action) {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (!_ensureActionTargetAvailable(action)) return;
    if (!_ensureActionPrerequisites(action)) return;
    if (!_ensureBattleBoardActionRange(action)) return;

    final actionKey = _actionExecutionKey(action);
    final activeProgress = _multiAttackProgress;
    if (activeProgress != null && activeProgress.actionKey == actionKey) {
      setState(() {
        _selectedCommandTiming = 'Action';
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${action.name} is already active: resolve the remaining strikes.',
          ),
        );
      });
      return;
    }

    if (_flurryUsedThisTurnCombatantIds.contains(_activeCombatant.id)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${action.name} has already been used this turn.',
          ),
        );
      });
      return;
    }

    if (_pendingDamageActions.any((pendingKey) => pendingKey != actionKey)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            'Resolve pending damage before activating ${action.name}.',
          ),
        );
      });
      return;
    }

    final resourceBlock = _actionResourceBlockMessage(action);
    if (resourceBlock != null) {
      setState(() {
        _activity.insert(0, CombatLogEntry.system(resourceBlock));
      });
      return;
    }
    if (_spentTimings.contains(action.timing)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${action.name} cannot be activated: ${action.timing} is already spent.',
          ),
        );
      });
      return;
    }

    setState(() {
      _resetQueuedPreparedActions();
      _pendingDamageActions.remove(actionKey);
      _pendingHalfDamageActions.remove(actionKey);
      _spentTimings.add(action.timing);
      _spendEngineActionResource(action);
      _flurryUsedThisTurnCombatantIds.add(_activeCombatant.id);
      _multiAttackProgress = MultiAttackProgress(
        actionKey: actionKey,
        pendingAttacks: _pendingCombatAttacksForAction(
          action,
          labelPrefix: 'Flurry Strike',
          source: PendingCombatAttackSource.flurryOfBlows,
        ),
      );
      _selectedCommandTiming = 'Action';
      _activity.insert(
        0,
        CombatLogEntry.system(
          '${_activeCombatant.name} spends 1 Ki and activates ${action.name}: ${action.multiAttackSteps.length} strikes ready.',
        ),
      );
      _rollFeedback = CombatRollFeedback.manual(
        actor: _activeCombatant.name,
        action: action.name,
        headline: 'FLURRY ACTIVE',
        subline: '${action.multiAttackSteps.length} unarmed strikes ready.',
        accentKind: CombatAccentKind.info,
      );
    });
  }

  void _resolveMultiAttackPendingDamage(
    CombatAction action,
    MultiAttackProgress progress,
  ) {
    unawaited(_resolveMultiAttackPendingDamageAsync(action, progress));
  }

  Future<void> _resolveMultiAttackPendingDamageAsync(
    CombatAction action,
    MultiAttackProgress progress,
  ) async {
    final actionKey = _actionExecutionKey(action);
    final stepIndex = progress.pendingStepIndex;
    final targetIndex = progress.pendingTargetIndex;
    if (stepIndex == null ||
        targetIndex == null ||
        stepIndex < 0 ||
        stepIndex >= action.multiAttackSteps.length ||
        targetIndex < 0 ||
        targetIndex >= _combatants.length) {
      setState(() {
        _pendingDamageActions.remove(actionKey);
        progress.clearPendingDamage();
      });
      return;
    }

    final resolutionKey = _combatResolutionKey(
      'multi-damage',
      action,
      rollType: CombatActionRoll.damage,
      targetIndex: targetIndex,
      stepIndex: stepIndex,
    );
    if (!_beginCombatResolution(resolutionKey)) return;
    try {
      final step = action.multiAttackSteps[stepIndex];
      final wasCritical = progress.pendingCritical;
      final damageFormula = progress.pendingCritical
          ? step.critFormula ?? step.damageFormula
          : step.damageFormula;
      if (damageFormula == null) {
        setState(() {
          progress
            ..clearPendingDamage()
            ..stepIndex = stepIndex + 1;
          _pendingDamageActions.remove(actionKey);
          _advanceMultiAttackAfterStep(action, progress);
        });
        return;
      }

      final stepNumber = stepIndex + 1;
      final stepLabel = '${action.name} $stepNumber: ${step.name}';
      final result = await _rollCombatFormulaAwaitingBoard(
        formula: damageFormula,
        label: '$stepLabel Damage',
      );
      final amount =
          result.total + _situationalDamageBonus(_activeCombatant, action);
      var completed = false;
      setState(() {
        final currentTarget = _combatants[targetIndex];
        final hpResult =
            _resolveHpChange(currentTarget, amount, healing: false);
        _combatants = [
          for (var index = 0; index < _combatants.length; index++)
            index == targetIndex
                ? currentTarget.copyWith(
                    hp: hpResult.hp,
                    tempHp: hpResult.tempHp,
                  )
                : _combatants[index],
        ];
        _applyEngineHpChange(
          actor: _activeCombatant,
          target: currentTarget,
          amount: amount,
          healing: false,
          action: action,
          formula: result.formula,
        );
        _syncUiFromEncounter();

        progress
          ..totalDamage += amount
          ..hitCount += 1
          ..lastHpLine = _hpChangeLine(currentTarget, hpResult)
          ..markResolved(stepIndex)
          ..clearPendingDamage()
          ..stepIndex = stepIndex + 1;
        _pendingDamageActions.remove(actionKey);
        _pendingHalfDamageActions.remove(actionKey);
        _selectBestCommandTimingAfterDamageResolution();

        _activity.insert(
          0,
          CombatLogEntry.roll(
            actor: _activeCombatant.name,
            action: '$stepLabel damage',
            result: result,
            detail:
                '${result.formula} - ${result.rollsText}. ${currentTarget.name} takes $amount damage (${progress.lastHpLine}).',
          ),
        );

        if (currentTarget.hp > 0 && hpResult.hp == 0) {
          _activity.insert(
            0,
            CombatLogEntry.system('${currentTarget.name} is down.'),
          );
          _targetIndex = _findDefaultTargetIndex(_activeIndex);
        }

        completed = progress.stepIndex >= action.multiAttackSteps.length;
        _rollFeedback = CombatRollFeedback(
          actor: _activeCombatant.name,
          action: action.name,
          result: result,
          headline: wasCritical ? 'CRIT $amount DAMAGE' : '$amount DAMAGE',
          subline: completed
              ? 'Multiattack complete: ${progress.hitCount}/${progress.attackCount} hits'
              : 'Attack $stepNumber/${action.multiAttackSteps.length} damage',
          accentKind:
              wasCritical ? CombatAccentKind.support : action.accentKind,
        );

        _advanceMultiAttackAfterStep(action, progress);
      });
      if (_showBattleBoardController) {
        unawaited(
          _syncBattleBoardTokensFromCombatState(
            eventLabel: '$amount DAMAGE',
            eventKind: wasCritical ? 'critical' : 'damage',
            eventDiceNotation:
                CombatDiceResultFormatter.diceBoxNotation(result) ?? '',
            eventResultLabel: '$amount DAMAGE',
            eventResultDetail: CombatDiceResultFormatter.detail(result),
            eventAuthoritativeDice:
                CombatDiceResultFormatter.authoritativeDiceJson(result),
            eventIdOverride: _consumeBoardResolvedRollEventId(),
            eventDamageType: action.damageType ?? '',
          ),
        );
      }
    } finally {
      _endCombatResolution(resolutionKey);
    }
  }

  void _advanceMultiAttackAfterStep(
    CombatAction action,
    MultiAttackProgress progress,
  ) {
    if (progress.stepIndex >= action.multiAttackSteps.length) {
      _finishMultiAttackProgress(action, progress);
      return;
    }
    final nextStep = action.multiAttackSteps[progress.stepIndex];
    _activity.insert(
      0,
      CombatLogEntry.system(
        'Next ${action.name} roll: ${progress.stepIndex + 1}/${action.multiAttackSteps.length} ${nextStep.name}.',
      ),
    );
  }

  void _finishMultiAttackProgress(
    CombatAction action,
    MultiAttackProgress progress,
  ) {
    final actionKey = _actionExecutionKey(action);
    _pendingDamageActions.remove(actionKey);
    _pendingHalfDamageActions.remove(actionKey);
    _activity.insert(
      0,
      CombatLogEntry.system(
        '${action.name} complete: ${progress.hitCount}/${progress.attackCount} hits, ${progress.totalDamage} total damage.',
      ),
    );
    _multiAttackProgress = null;
  }

  void _useAction(CombatAction action) {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (!_ensureActionTargetAvailable(action)) return;
    if (!_ensureActionPrerequisites(action)) return;
    if (action.hasMultiAttack) {
      if (_actionIsMartialArtsBonusStrike(action) &&
          !_multiAttackProgressMatches(action)) {
        _activateMartialArtsBonusStrike(action);
        return;
      }
      if (_actionIsFlurryOfBlows(action) &&
          !_multiAttackProgressMatches(action)) {
        _activateFlurryOfBlows(action);
        return;
      }
      _rollMultiAttackStep(action, CombatActionRoll.attack);
      return;
    }
    if (!_ensureBattleBoardActionRange(action)) return;

    final resourceBlock = _actionResourceBlockMessage(action);
    if (resourceBlock != null) {
      setState(() {
        _activity.insert(0, CombatLogEntry.system(resourceBlock));
      });
      return;
    }
    if (_actionBlockedByStartedAttackAction(action)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(_startedAttackActionMessage(action)),
        );
      });
      return;
    }
    if (_actionConsumesTurnTiming(action) &&
        _spentTimings.contains(action.timing)) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${action.timing} is already spent this turn.',
          ),
        );
      });
      return;
    }

    setState(() {
      _resetQueuedPreparedActions();
      if (_actionConsumesTurnTiming(action)) {
        _spentTimings.add(action.timing);
      }
      _pendingDamageActions.remove(_actionExecutionKey(action));
      _pendingHalfDamageActions.remove(_actionExecutionKey(action));
      final stateTargetIndex = _stateTargetIndexForAction(action);
      final stateTarget = _combatants[stateTargetIndex];
      final condition = _applyActionState(action, actorIndex: stateTargetIndex);
      _spendEngineActionResource(action);
      final economyMessage = _applyActionEconomyEffect(action);
      if (condition != null) {
        _applyEngineCondition(
          actor: _activeCombatant,
          target: stateTarget,
          name: condition,
          sourceActionName: action.name,
        );
        if (condition == 'Inspired') {
          _rollMode = CombatRollMode.advantage;
          _activity.insert(
            0,
            CombatLogEntry.system(
              '${_activeCombatant.name} will roll the next d20 with advantage.',
            ),
          );
        }
      }
      _syncUiFromEncounter();
      _activity.insert(
        0,
        CombatLogEntry.system('${_activeCombatant.name} used ${action.name}.'),
      );
      if (economyMessage != null) {
        _activity.insert(0, CombatLogEntry.system(economyMessage));
      }
      _rollFeedback = CombatRollFeedback.manual(
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
                : '${stateTarget.name} is now $condition'),
        accentKind: action.accentKind,
      );
    });
    if (_showBattleBoardController) {
      unawaited(
        _syncBattleBoardTokensFromCombatState(
          eventLabel: 'READY',
          eventKind: 'focus',
        ),
      );
    }
  }

  void _prepareAction(CombatAction action) {
    if (!_ensureCanControlCombatant(_activeCombatant)) return;
    if (!_ensureActionTargetAvailable(action)) return;
    setState(() {
      _resetQueuedPreparedActions();
      if (_spentTimings.contains(action.timing)) {
        final hasPendingDamage =
            _pendingDamageActions.contains(_actionExecutionKey(action));
        _activity.insert(
          0,
          CombatLogEntry.system(
            hasPendingDamage
                ? '${action.name} has pending damage to resolve.'
                : '${action.name} cannot be prepared: ${action.timing} is already spent.',
          ),
        );
        return;
      }
      final resourceBlock = _actionResourceBlockMessage(action);
      if (resourceBlock != null) {
        _activity.insert(0, CombatLogEntry.system(resourceBlock));
        return;
      }
      if (_actionBlockedByStartedAttackAction(action)) {
        _activity.insert(
          0,
          CombatLogEntry.system(_startedAttackActionMessage(action)),
        );
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
          CombatLogEntry.system('${action.name} removed from the turn plan.'),
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
        CombatLogEntry.system('${action.name} prepared for ${action.timing}.'),
      );
    });
  }

  void _focusActionForController(CombatAction action) {
    if (!_ensureCanControlCombatant(
      _activeCombatant,
      actionLabel: 'seleccionar acciones',
    )) {
      return;
    }
    final targetIndex = _targetIndexForAction(action);
    if (targetIndex == null) {
      _ensureActionTargetAvailable(action);
      return;
    }

    setState(() {
      _selectedCommandTiming = action.timing;
      _focusedBattleBoardAction = action;
      _targetIndex = targetIndex;
      _activity.insert(
        0,
        CombatLogEntry.system(
          '${action.name} enfocada sobre ${_combatants[targetIndex].name}.',
        ),
      );
    });
    if (_showBattleBoardController) {
      unawaited(_syncBattleBoardTokensFromCombatState());
    }
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
      _activity.insert(0, CombatLogEntry.system('Turn plan cleared.'));
    });
  }

  void _resetQueuedPreparedActions() {
    _queuedPreparedActions.clear();
    _queuedPreparedIndex = 0;
  }

  void _launchPreparedTurn() {
    if (_combatRollInFlight) return;
    unawaited(_launchPreparedTurnAsync());
  }

  Future<void> _launchPreparedTurnAsync() async {
    if (_preparedActions.isEmpty) return;
    if (!_ensureCanControlCombatant(_activeCombatant)) return;

    const order = ['Action', 'Bonus Action', 'Reaction', 'Movement'];

    CombatAction? action;
    CombatActionRoll? rollType;
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
          CombatLogEntry.turn(
            '${_activeCombatant.name} starts rolling the turn plan.',
          ),
        );
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${prepared.length} prepared roll${prepared.length == 1 ? '' : 's'} queued. Tap Roll Next to continue.',
          ),
        );
      }

      action = _queuedPreparedActions[_queuedPreparedIndex];
      rollType = _primaryRollTypeForAction(action!);
      _activity.insert(
        0,
        CombatLogEntry.turn(
          'Rolling ${_queuedPreparedIndex + 1}/${_queuedPreparedActions.length}: ${action!.name}.',
        ),
      );

      _spendActionOrAttackSlot(action!, rollType!);
      _pendingDamageActions.remove(_actionExecutionKey(action!));
      _pendingHalfDamageActions.remove(_actionExecutionKey(action!));
    });
    final resolvedAction = action;
    if (resolvedAction == null) return;
    final feedback = await _resolvePreparedAction(resolvedAction);
    if (!mounted) return;
    setState(() {
      _spendEngineActionResource(resolvedAction);
      final economyMessage = _applyActionEconomyEffect(resolvedAction);
      if (economyMessage != null) {
        _activity.insert(0, CombatLogEntry.system(economyMessage));
      }
      final encounter = _encounter;
      if (encounter != null) {
        _encounter = CombatEncounterEngine.clearPreparedAction(
          encounter,
          combatantId: _activeCombatant.id,
          timing: _timingFromLabel(resolvedAction.timing),
        );
      }
      _preparedActions.remove(resolvedAction.timing);

      _queuedPreparedIndex += 1;

      _syncUiFromEncounter();
      _rollFeedback = feedback;
      if (_queuedPreparedIndex >= _queuedPreparedActions.length) {
        _resetQueuedPreparedActions();
        _preparedActions.clear();
        _activity.insert(
          0,
          CombatLogEntry.system('Turn plan fully rolled.'),
        );
        _scheduleAutoAdvanceTurn(
          '${_activeCombatant.name} completed the planned turn.',
        );
      } else {
        final nextAction = _queuedPreparedActions[_queuedPreparedIndex];
        _activity.insert(
          0,
          CombatLogEntry.system('Next prepared roll: ${nextAction.name}.'),
        );
      }
    });
  }

  void _runDemoRound() {
    if (_combatRollInFlight) return;
    unawaited(_runDemoRoundAsync());
  }

  Future<void> _runDemoRoundAsync() async {
    CombatRollFeedback? lastFeedback;
    var lastActorIndex = _activeIndex;
    setState(() {
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _spentTimings.clear();
      _clearClassTurnFlowState();
      _actionAttackUsesByCombatantId.clear();
      _movementBonusFeetByCombatantId.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _pendingAreaSavingThrow = null;
      _spentReactionCombatantIds.clear();
      _oncePerTurnActionUses.clear();
      _readiedActionsByCombatantId.clear();
      _clearMultiAttackProgress();
      _activity.insert(
        0,
        CombatLogEntry.system('Demo round starts. Every combatant acts once.'),
      );
    });
    for (var index = 0; index < _combatants.length; index++) {
      if (_combatants[index].hp <= 0) continue;

      final targetIndex = _findDefaultTargetIndex(index);
      if (targetIndex == index) continue;

      final action = _demoActionFor(_actionsForCombatant(_combatants[index]));
      if (action == null) continue;

      lastActorIndex = index;
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.turn('${_combatants[index].name} demo turn.'),
        );
      });
      lastFeedback = await _resolvePreparedAction(
        action,
        actorIndex: index,
        forcedTargetIndex: targetIndex,
      );
      if (!mounted) return;
    }

    setState(() {
      _round += 1;
      _activeIndex = lastActorIndex.clamp(0, _combatants.length - 1).toInt();
      _targetIndex = _findDefaultTargetIndex(_activeIndex);
      _selectedCommandTiming = 'Action';
      _workspace = CombatWorkspace.overview;
      _rollFeedback = lastFeedback;
      _activity.insert(
        0,
        CombatLogEntry.system('Demo round resolved. Review overview state.'),
      );
    });
  }

  CombatAction? _demoActionFor(List<CombatAction> actions) {
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

  Future<CombatRollFeedback> _resolvePreparedAction(
    CombatAction action, {
    int? actorIndex,
    int? forcedTargetIndex,
  }) async {
    if (_combatants.isEmpty) {
      return CombatRollFeedback.manual(
        actor: 'Combat',
        action: action.name,
        headline: 'NO TARGET',
        subline: 'No combatants are available.',
        accentKind: CombatAccentKind.read,
      );
    }
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final actor = _combatants[resolvedActorIndex];
    final prerequisiteBlock =
        _actionPrerequisiteBlockMessage(action, actor: actor);
    if (prerequisiteBlock != null) {
      _activity.insert(0, CombatLogEntry.system(prerequisiteBlock));
      return CombatRollFeedback.manual(
        actor: actor.name,
        action: action.name,
        headline: 'NOT READY',
        subline: 'Take the Attack action first this turn.',
        accentKind: CombatAccentKind.read,
      );
    }
    final targetIndex = _targetIndexForAction(
      action,
      actorIndex: resolvedActorIndex,
      forcedTargetIndex: forcedTargetIndex,
    );
    if (targetIndex == null) {
      _activity.insert(
        0,
        CombatLogEntry.system(
          _targetUnavailableMessage(action, actor),
        ),
      );
      return CombatRollFeedback.manual(
        actor: actor.name,
        action: action.name,
        headline: 'NO TARGET',
        subline: _targetUnavailableSubline(action),
        accentKind: CombatAccentKind.read,
      );
    }
    var target = _combatants[targetIndex];
    _focusedBattleBoardAction = action;
    final rangeSnapshot = _boardActionRangeFor(
      action,
      actorIndex: resolvedActorIndex,
      forcedTargetIndex: targetIndex,
    );
    if (rangeSnapshot != null && !rangeSnapshot.isInRange) {
      _activity.insert(
        0,
        CombatLogEntry.system(
          '${rangeSnapshot.target.name} is out of range for ${action.name}: ${rangeSnapshot.distanceFeet}/${rangeSnapshot.rangeFeet} ft.',
        ),
      );
      unawaited(
        _syncBattleBoardTokensFromCombatState(
          eventLabel: 'OUT OF RANGE',
          eventKind: 'blocked',
        ),
      );
      return CombatRollFeedback.manual(
        actor: actor.name,
        action: action.name,
        headline: 'OUT OF RANGE',
        subline:
            '${rangeSnapshot.target.name} is ${rangeSnapshot.distanceFeet} ft away; ${rangeSnapshot.rangeFeet} ft needed.',
        accentKind: CombatAccentKind.action,
      );
    }

    final resolutionKey = _combatResolutionKey(
      'prepared',
      action,
      targetIndex: targetIndex,
      actorId: actor.id,
    );
    if (!_beginCombatResolution(resolutionKey)) {
      return CombatRollFeedback.manual(
        actor: actor.name,
        action: action.name,
        headline: 'ROLLING',
        subline: 'This action is already resolving.',
        accentKind: CombatAccentKind.info,
      );
    }
    try {
      if (action.hasMultiAttack) {
        return await _resolveMultiAttackAction(
          action,
          actor: actor,
          actorIndex: resolvedActorIndex,
          targetIndex: targetIndex,
        );
      }

      if (action.requiresSavingThrow) {
        final saveResult = await _rollCombatFormulaAwaitingBoard(
          formula: _savingThrowFormulaForTarget(target, action.saveAbility!),
          label: '${target.name} ${action.saveAbility} Save',
          useRollMode: true,
          forceAdvantage: _savingThrowHasAdvantage(
            target,
            action.saveAbility!,
            sourceAction: action,
          ),
          forceDisadvantage: _savingThrowHasDisadvantage(
            target,
            action.saveAbility!,
            sourceAction: action,
          ),
        );
        final saveDc = action.saveDc ?? 10;
        final success = saveResult.total >= saveDc;
        final saveDetail =
            '${saveResult.formula} - ${saveResult.rollsText}. ${target.name} ${success ? 'succeeds' : 'fails'} ${action.saveAbility} save vs DC $saveDc.';
        _activity.insert(
          0,
          CombatLogEntry.roll(
            actor: target.name,
            action: '${action.name} save',
            result: saveResult,
            detail: saveDetail,
          ),
        );
        if (!success) {
          final failureCondition = _savingThrowFailureCondition(action);
          if (failureCondition != null) {
            final nextCombatants = [..._combatants];
            nextCombatants[targetIndex] = _combatantWithCondition(
              target,
              failureCondition,
            );
            _combatants = nextCombatants;
            _applyEngineCondition(
              actor: actor,
              target: target,
              name: failureCondition,
              sourceActionName: action.name,
            );
            _syncUiFromEncounter();
            target = _combatants[targetIndex];
          }
        }

        if (action.damageFormula != null &&
            (!success || action.halfDamageOnSave)) {
          final damageResult = await _rollCombatFormulaAwaitingBoard(
            formula: action.damageFormula!,
            label: '${action.name} Damage',
          );
          final damageResolution = _resolveSavingThrowDamage(
            action: action,
            target: target,
            success: success,
            rolledDamage: damageResult.total,
          );
          final amount = damageResolution.amount;
          if (damageResolution.absorbElementsAction != null) {
            _applyAbsorbElementsReactionCost(
              target,
              damageResolution.absorbElementsAction!,
            );
          }
          if (amount <= 0) {
            _activity.insert(
              0,
              CombatLogEntry.system(
                '${target.name} avoids all ${action.name} damage${damageResolution.labelSuffix}.',
              ),
            );
            return CombatRollFeedback(
              actor: actor.name,
              action: action.name,
              result: damageResult,
              headline: 'EVASION',
              subline: '${target.name} takes no damage',
              accentKind: CombatAccentKind.support,
            );
          }
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
              '${damageResult.formula} - ${damageResult.rollsText}. ${target.name} takes $amount ${damageResolution.label} (${_hpChangeLine(target, hpResult)}).';
          _activity.insert(
            0,
            CombatLogEntry.roll(
              actor: actor.name,
              action: '${action.name} damage',
              result: damageResult,
              detail: damageDetail,
            ),
          );
          return CombatRollFeedback(
            actor: actor.name,
            action: action.name,
            result: damageResult,
            headline: success && action.halfDamageOnSave
                ? '$amount HALF DAMAGE'
                : '$amount DAMAGE',
            subline: _hpChangeLine(target, hpResult),
            accentKind:
                success ? CombatAccentKind.read : CombatAccentKind.magic,
          );
        }

        return CombatRollFeedback(
          actor: target.name,
          action: action.name,
          result: saveResult,
          headline: success ? 'SAVE SUCCESS' : 'SAVE FAILED',
          subline:
              '${target.name} ${action.saveAbility} ${saveResult.total} vs DC $saveDc',
          accentKind: success ? CombatAccentKind.read : CombatAccentKind.magic,
        );
      }

      if (action.attackFormula != null) {
        final attackResult = await _rollCombatFormulaAwaitingBoard(
          formula: action.attackFormula!,
          label: '${action.name} Attack',
          useRollMode: true,
          forceDisadvantage: _attackHasLongRangeDisadvantage(
            action,
            actorIndex: actorIndex,
            forcedTargetIndex: targetIndex,
          ),
        );
        final outcome = _attackOutcome(attackResult, target, action);
        final attackDetail =
            '${attackResult.formula} - ${attackResult.rollsText}. ${target.name} AC ${target.ac}: $outcome.';
        _activity.insert(
          0,
          CombatLogEntry.roll(
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
          final damageResult = await _rollCombatFormulaAwaitingBoard(
            formula: damageFormula,
            label: '${action.name} Damage',
          );
          final passiveDamageFormula = _passiveExtraHitDamageFormula(
            actor,
            action,
            critical: outcome == 'critical hit',
          );
          final passiveDamageResult = passiveDamageFormula == null
              ? null
              : await _rollCombatFormulaAwaitingBoard(
                  formula: passiveDamageFormula,
                  label: 'Improved Divine Smite',
                );
          final amount = damageResult.total +
              _situationalDamageBonus(actor, action) +
              (passiveDamageResult?.total ?? 0);
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
          final passiveDetail = passiveDamageResult == null
              ? ''
              : ' Improved Divine Smite adds ${passiveDamageResult.total} radiant (${passiveDamageResult.rollsText}).';
          final damageDetail =
              '${damageResult.formula} - ${damageResult.rollsText}.$passiveDetail ${target.name} takes $amount damage (${_hpChangeLine(target, hpResult)}).';
          _activity.insert(
            0,
            CombatLogEntry.roll(
              actor: actor.name,
              action: '${action.name} damage',
              result: damageResult,
              detail: damageDetail,
            ),
          );
          if (target.hp > 0 && hpResult.hp == 0) {
            _activity.insert(
                0, CombatLogEntry.system('${target.name} is down.'));
            _targetIndex = _findDefaultTargetIndex(_activeIndex);
          }
          final headline = outcome == 'critical hit'
              ? 'CRIT $amount DAMAGE'
              : '$amount DAMAGE';
          return CombatRollFeedback(
            actor: actor.name,
            action: action.name,
            result: damageResult,
            headline: headline,
            subline: _hpChangeLine(target, hpResult),
            accentKind: outcome == 'critical hit'
                ? CombatAccentKind.support
                : CombatAccentKind.action,
          );
        }

        return CombatRollFeedback(
          actor: actor.name,
          action: action.name,
          result: attackResult,
          headline: outcome.toUpperCase(),
          subline: '${actor.name} vs ${target.name} AC ${target.ac}',
          accentKind: switch (outcome) {
            'critical hit' => CombatAccentKind.support,
            'hit' => CombatAccentKind.action,
            'automatic miss' => CombatAccentKind.info,
            _ => CombatAccentKind.read,
          },
        );
      }

      if (action.damageFormula != null) {
        final result = await _rollCombatFormulaAwaitingBoard(
          formula: action.damageFormula!,
          label:
              action.isHealing ? '${action.name} Heal' : '${action.name} Use',
        );
        final amount = result.total + _situationalDamageBonus(actor, action);
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
          CombatLogEntry.roll(
            actor: actor.name,
            action: action.name,
            result: result,
            detail: detail,
          ),
        );
        if (!action.isHealing && target.hp > 0 && hpResult.hp == 0) {
          _activity.insert(0, CombatLogEntry.system('${target.name} is down.'));
          _targetIndex = _findDefaultTargetIndex(_activeIndex);
        }
        return CombatRollFeedback(
          actor: actor.name,
          action: action.name,
          result: result,
          headline: action.isHealing ? 'HEAL $amount' : '$amount DAMAGE',
          subline: _hpChangeLine(target, hpResult),
          accentKind: action.isHealing
              ? CombatAccentKind.support
              : CombatAccentKind.action,
        );
      }

      _activity.insert(
        0,
        CombatLogEntry.system('${actor.name} used ${action.name}.'),
      );
      final stateTargetIndex =
          action.targetPolicy == 'ally' || action.targetPolicy == 'any'
              ? (targetIndex).clamp(0, _combatants.length - 1).toInt()
              : resolvedActorIndex;
      final stateTarget = _combatants[stateTargetIndex];
      final condition = _applyActionState(action, actorIndex: stateTargetIndex);
      if (condition != null) {
        _applyEngineCondition(
          actor: actor,
          target: stateTarget,
          name: condition,
          sourceActionName: action.name,
        );
        _syncUiFromEncounter();
      }
      return CombatRollFeedback.manual(
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
                : '${stateTarget.name} is now $condition',
        accentKind: action.accentKind,
      );
    } finally {
      _endCombatResolution(resolutionKey);
    }
  }

  Future<CombatRollFeedback> _resolveMultiAttackAction(
    CombatAction action, {
    required Combatant actor,
    required int actorIndex,
    required int targetIndex,
  }) async {
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
        final damageResult = await _rollCombatFormulaAwaitingBoard(
          formula: damageFormula!,
          label: '$stepLabel Damage',
        );
        lastResult = damageResult;
        final amount =
            damageResult.total + _situationalDamageBonus(actor, action);
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
          CombatLogEntry.roll(
            actor: actor.name,
            action: stepLabel,
            result: damageResult,
            detail:
                '${damageResult.formula} - ${damageResult.rollsText}. ${target.name} takes $amount damage ($lastHpLine).',
          ),
        );
      } else {
        attackCount += 1;
        final attackResult = await _rollCombatFormulaAwaitingBoard(
          formula: attackFormula,
          label: '$stepLabel Attack',
          useRollMode: true,
          forceDisadvantage: _attackHasLongRangeDisadvantage(
            action,
            forcedTargetIndex: targetIndex,
          ),
        );
        lastResult = attackResult;
        final outcome = _attackOutcome(attackResult, target, action);
        final didHit = outcome == 'hit' || outcome == 'critical hit';
        if (outcome == 'critical hit') critCount += 1;
        _activity.insert(
          0,
          CombatLogEntry.roll(
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
          final damageResult = await _rollCombatFormulaAwaitingBoard(
            formula: resolvedDamageFormula,
            label: '$stepLabel Damage',
          );
          lastResult = damageResult;
          final amount =
              damageResult.total + _situationalDamageBonus(actor, action);
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
            CombatLogEntry.roll(
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
          CombatLogEntry.system('${target.name} is down.'),
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

    return CombatRollFeedback(
      actor: actor.name,
      action: action.name,
      result: lastResult,
      headline: headline,
      subline: lastHpLine ?? '${_combatants[targetIndex].name}: $attacksLabel',
      accentKind: totalDamage > 0
          ? (critCount > 0 ? CombatAccentKind.support : action.accentKind)
          : CombatAccentKind.read,
    );
  }

  void _selectTarget(int index) {
    if (index < 0 || index >= _combatants.length) {
      return;
    }
    if (_combatants[index].hp <= 0) {
      setState(() {
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${_combatants[index].name} cannot be targeted while down.',
          ),
        );
      });
      return;
    }

    setState(() {
      _targetIndex = index;
      _activity.insert(
        0,
        CombatLogEntry.system(
          '${_combatants[index].name} is the current target.',
        ),
      );
    });
    if (_showBattleBoardController) {
      unawaited(_syncBattleBoardTokensFromCombatState());
    }
  }

  void _scheduleTargetSelectionFromBoard(List<BoardToken> tokens) {
    final sceneId = _activeBattleBoardSceneId;
    if (sceneId == null || _combatants.isEmpty) return;
    final targetToken = CombatBoardTokenLookup.targeted(
      tokens.where((token) => token.sceneId == sceneId).toList(growable: false),
    );
    if (targetToken == null || targetToken.refId == _selectedTarget.id) {
      return;
    }

    final targetIndex = _combatants.indexWhere(
      (combatant) => combatant.id == targetToken.refId,
    );
    if (targetIndex < 0 ||
        targetIndex >= _combatants.length ||
        _combatants[targetIndex].hp <= 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || targetIndex == _targetIndex) return;
      setState(() {
        _targetIndex = targetIndex;
        _activity.insert(
          0,
          CombatLogEntry.system(
            '${_combatants[targetIndex].name} is targeted from the board.',
          ),
        );
      });
      unawaited(_syncBattleBoardTokensFromCombatState());
    });
  }

  CombatHpChangeResult _resolveHpChange(
    Combatant target,
    int amount, {
    required bool healing,
  }) {
    if (healing) {
      return CombatHpChangeResult(
        hp: (target.hp + amount).clamp(0, target.maxHp).toInt(),
        tempHp: target.tempHp,
      );
    }

    final absorbedByTemp = math.min(target.tempHp, amount);
    final remainingDamage = amount - absorbedByTemp;
    return CombatHpChangeResult(
      hp: (target.hp - remainingDamage).clamp(0, target.maxHp).toInt(),
      tempHp: target.tempHp - absorbedByTemp,
    );
  }

  int _situationalDamageBonus(Combatant actor, CombatAction action) {
    if (action.isHealing || action.timing == 'Free') return 0;
    if (!_combatantHasCondition(actor, 'Raging')) return 0;
    if (!_rageAppliesToAction(action)) return 0;
    return _rageDamageBonusForCombatant(actor);
  }

  String? _passiveExtraHitDamageFormula(
    Combatant actor,
    CombatAction action, {
    required bool critical,
  }) {
    if (!_combatantHasPassiveEffect(actor, 'Improved Divine Smite')) {
      return null;
    }
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    final meleeWeaponAttack = text.contains('weapon') && text.contains('melee');
    if (!meleeWeaponAttack) return null;
    return critical ? '2d8' : '1d8';
  }

  bool _combatantHasCondition(Combatant combatant, String condition) {
    final normalized = condition.toLowerCase();
    return combatant.conditions.any(
      (item) => item.toLowerCase() == normalized,
    );
  }

  bool _combatantHasPassiveEffect(Combatant combatant, String effectName) {
    final normalized = effectName.toLowerCase();
    final engineEffects =
        _encounter?.combatantById(combatant.id)?.effects ?? const [];
    if (engineEffects
        .any((effect) => effect.name.toLowerCase() == normalized)) {
      return true;
    }
    return combatant.conditions.any(
      (condition) => condition.toLowerCase() == normalized,
    );
  }

  bool _savingThrowUsesEvasion(CombatAction action, Combatant target) {
    final ability = action.saveAbility?.trim().toUpperCase();
    return ability == 'DEX' &&
        action.halfDamageOnSave &&
        _combatantHasPassiveEffect(target, 'Evasion');
  }

  SavingThrowDamageResolution _resolveSavingThrowDamage({
    required CombatAction action,
    required Combatant target,
    required bool success,
    required int rolledDamage,
  }) {
    final notes = <String>[];
    var amount = rolledDamage;
    if (_savingThrowUsesEvasion(action, target)) {
      if (success) {
        amount = 0;
        notes.add('Evasion');
      } else {
        amount = (amount / 2).floor();
        notes.add('Evasion');
      }
    } else if (success && action.halfDamageOnSave) {
      amount = (amount / 2).floor();
      notes.add('save half');
    }

    final damageType = CombatDamageTypeRules.normalize(action.damageType);
    final traits = _damageTraitsForCombatant(target, damageType);
    if (amount > 0 && traits.immune) {
      amount = 0;
      notes.add('immunity');
    }
    final absorbElementsAction = amount > 0 && !traits.resistant
        ? _availableAbsorbElementsReaction(target, damageType)
        : null;
    if (amount > 0 && (traits.resistant || absorbElementsAction != null)) {
      amount = (amount / 2).floor();
      notes
          .add(absorbElementsAction == null ? 'resistance' : 'Absorb Elements');
    }
    if (amount > 0 && traits.vulnerable) {
      amount *= 2;
      notes.add('vulnerability');
    }

    return SavingThrowDamageResolution(
      amount: amount,
      damageType: damageType,
      notes: notes,
      absorbElementsAction: absorbElementsAction,
    );
  }

  DamageTraitSnapshot _damageTraitsForCombatant(
    Combatant target,
    String? damageType,
  ) {
    if (damageType == null) {
      return const DamageTraitSnapshot();
    }
    var resistant = false;
    var immune = false;
    var vulnerable = false;

    bool matches(Object? value) {
      if (value == null) return false;
      if (value is Iterable) {
        return value.any(matches);
      }
      return CombatDamageTypeRules.normalize(value.toString()) == damageType;
    }

    final engineCombatant = _encounter?.combatantById(target.id);
    for (final effect in engineCombatant?.effects ?? const []) {
      final mechanics = effect.mechanics;
      resistant = resistant ||
          matches(mechanics['resistance']) ||
          matches(mechanics['resistances']);
      immune = immune ||
          matches(mechanics['immunity']) ||
          matches(mechanics['immunities']);
      vulnerable = vulnerable ||
          matches(mechanics['vulnerability']) ||
          matches(mechanics['vulnerabilities']);
    }

    for (final condition in target.conditions) {
      final normalized = condition.toLowerCase();
      if (normalized == 'raging' &&
          const {'bludgeoning', 'piercing', 'slashing'}.contains(damageType)) {
        resistant = true;
      }
      if (normalized.contains('resist') && normalized.contains(damageType)) {
        resistant = true;
      }
      if (normalized.contains('immune') && normalized.contains(damageType)) {
        immune = true;
      }
      if (normalized.contains('vulnerable') &&
          normalized.contains(damageType)) {
        vulnerable = true;
      }
    }

    return DamageTraitSnapshot(
      resistant: resistant,
      immune: immune,
      vulnerable: vulnerable,
    );
  }

  CombatAction? _availableAbsorbElementsReaction(
    Combatant target,
    String? damageType,
  ) {
    if (damageType == null) return null;
    if (!const {'acid', 'cold', 'fire', 'lightning', 'thunder'}
        .contains(damageType)) {
      return null;
    }
    if (_spentReactionCombatantIds.contains(target.id)) return null;
    for (final action in _reactionActionsForCombatant(target)) {
      if (!_looksLikeAbsorbElements(action)) continue;
      if (_reactionResourceBlockMessage(target, action) != null) continue;
      return action;
    }
    return null;
  }

  bool _looksLikeAbsorbElements(CombatAction action) {
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    return text.contains('absorb elements') ||
        text.contains('absorber elementos');
  }

  void _applyAbsorbElementsReactionCost(
    Combatant target,
    CombatAction action, {
    encounter_models.CombatEncounter? currentEncounter,
    void Function(encounter_models.CombatEncounter? next)? encounterOverride,
  }) {
    _spentReactionCombatantIds.add(target.id);
    final resourceKey = action.resourceKey;
    final resourceCost = action.resourceCost;
    var nextEncounter = currentEncounter ?? _encounter;
    if (nextEncounter != null && resourceKey != null && resourceCost > 0) {
      nextEncounter = CombatEncounterEngine.spendResource(
        nextEncounter,
        combatantId: target.id,
        resourceKey: resourceKey,
        amount: resourceCost,
      );
      _queueCharacterCombatSnapshot(target.id);
    }
    if (encounterOverride != null) {
      encounterOverride(nextEncounter);
    } else {
      _encounter = nextEncounter;
    }
    _activity.insert(
      0,
      CombatLogEntry.system(
        '${target.name} reacts with ${action.name} to reduce incoming elemental damage.',
      ),
    );
  }

  bool _rageAppliesToAction(CombatAction action) {
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    if (text.contains('spell') || text.contains('ranged')) return false;
    return text.contains('melee') && text.contains('str');
  }

  int _rageDamageBonusForCombatant(Combatant combatant) {
    final metadata = _encounter?.combatantById(combatant.id)?.metadata;
    final classLevels = metadata?['classLevels'];
    var barbarianLevel = 0;
    if (classLevels is Map) {
      for (final entry in classLevels.entries) {
        final key = entry.key.toString().toLowerCase();
        if (!key.contains('barbarian') && !key.contains('barbaro')) continue;
        final value = entry.value;
        final level =
            value is num ? value.toInt() : int.tryParse('$value') ?? 0;
        if (level > barbarianLevel) barbarianLevel = level;
      }
    }
    if (barbarianLevel >= 16) return 4;
    if (barbarianLevel >= 9) return 3;
    return 2;
  }

  encounter_models.PreparedCombatAction? _engineActionForUi(
    CombatAction action,
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
    required Combatant actor,
    required Combatant target,
    required int amount,
    required bool healing,
    required CombatAction action,
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

  void _spendEngineActionResource(CombatAction action) {
    _spendEngineActionResourceForCombatant(action, _activeCombatant);
  }

  void _spendEngineActionResourceForCombatant(
    CombatAction action,
    Combatant actor,
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

  String? _applyActionEconomyEffect(CombatAction action) {
    final messages = <String>[];

    if (_actionGrantsDashMovement(action)) {
      final movementBonus = math.max(0, _activeCombatant.speed);
      if (movementBonus > 0) {
        final current =
            _movementBonusFeetByCombatantId[_activeCombatant.id] ?? 0;
        _movementBonusFeetByCombatantId[_activeCombatant.id] =
            current + movementBonus;
        messages.add(
          '${action.name} adds $movementBonus ft of movement this turn.',
        );
      }
    }

    if (action.grantsAction) {
      final hadSpentAction = _spentTimings.remove('Action');
      _actionAttackUsesByCombatantId[_activeCombatant.id] = 0;
      _selectedCommandTiming = 'Action';
      messages.add(
        hadSpentAction
            ? '${action.name} grants another Action this turn.'
            : '${action.name} is active. Your Action is still available.',
      );
    }

    if (messages.isEmpty) return null;
    return messages.join(' ');
  }

  bool _actionGrantsDashMovement(CombatAction action) {
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    return text.contains('dash') || text.contains('correr');
  }

  String? _actionResourceBlockMessage(CombatAction action) {
    final resourceKey = action.resourceKey;
    final resourceCost = action.resourceCost;
    if (resourceKey == null || resourceCost <= 0) return null;

    final remaining = _activeResourcePool[resourceKey] ?? 0;
    if (remaining >= resourceCost) return null;

    return '${action.name} cannot be used: ${_readableActionResourceName(resourceKey)} is depleted.';
  }

  bool _hasAvailableOnHitOptionForActiveCombatant() {
    return _actionsForCombatant(_activeCombatant).any(
      (action) =>
          _actionIsOnHitOption(action) &&
          _actionResourceBlockMessage(action) == null,
    );
  }

  void _queueOnHitPromptIfAvailable(String targetName) {
    if (!_hasAvailableOnHitOptionForActiveCombatant()) return;
    _activity.insert(
      0,
      CombatLogEntry.system(
        'Hit confirmed on $targetName. On-hit options are available before damage.',
      ),
    );
  }

  void _applyEngineCondition({
    required Combatant actor,
    required Combatant target,
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
        lower.contains('inspired') ||
        lower.contains('dodging') ||
        lower.contains('disengaged') ||
        lower.contains('hidden') ||
        lower.contains('uncanny dodge') ||
        lower.contains('deflect missiles') ||
        lower.contains('wild shape')) {
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
    if (lower.contains('dodging') ||
        lower.contains('disengaged') ||
        lower.contains('hidden') ||
        lower.contains('uncanny dodge') ||
        lower.contains('deflect missiles')) {
      return _round + 1;
    }
    if (lower.contains('wild shape')) return null;
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

  String _hpChangeLine(Combatant before, CombatHpChangeResult after) {
    String label(int hp, int maxHp, int tempHp) {
      final temp = tempHp > 0 ? ' +$tempHp temp' : '';
      return '$hp/$maxHp$temp';
    }

    return '${before.name}: ${label(before.hp, before.maxHp, before.tempHp)} -> ${label(after.hp, before.maxHp, after.tempHp)} HP';
  }

  int _stateTargetIndexForAction(CombatAction action) {
    if (action.targetsSelf || action.targetPolicy == 'self') {
      return _activeIndex;
    }
    if (action.targetPolicy == 'ally' || action.targetPolicy == 'any') {
      return (_targetIndexForAction(action) ?? _activeIndex)
          .clamp(0, _combatants.length - 1)
          .toInt();
    }
    return _activeIndex;
  }

  String? _applyActionState(CombatAction action, {int? actorIndex}) {
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
      CombatLogEntry.system('${actor.name} gains $condition.'),
    );
    return condition;
  }

  String? _conditionFromAction(CombatAction action) {
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    if (text.contains('rage')) return 'Raging';
    if (text.contains('bardic inspiration')) return 'Bardic Inspiration';
    if (text.contains('inspiration')) return 'Inspired';
    if (text.contains('concentration')) return 'Concentrating';
    if (text.contains('dodge') || text.contains('patient defense')) {
      return 'Dodging';
    }
    if (text.contains('disengage')) {
      return 'Disengaged';
    }
    if (text.contains('hide')) return 'Hidden';
    if (text.contains('uncanny dodge')) return 'Uncanny Dodge';
    if (text.contains('deflect missiles')) return 'Deflect Missiles';
    if (text.contains('wild shape')) return 'Wild Shape';
    return null;
  }

  void _selectCommandTiming(String timing) {
    setState(() {
      _selectedCommandTiming = timing;
    });
  }

  String _selectedTimingAvailableForActions(
    String preferredTiming,
    List<CombatAction> actions,
  ) {
    if (actions.isEmpty) return preferredTiming;
    if (actions.any((action) => action.timing == preferredTiming)) {
      return preferredTiming;
    }
    const priority = ['Action', 'Bonus Action', 'Reaction', 'Free', 'Movement'];
    for (final timing in priority) {
      if (actions.any((action) => action.timing == timing)) return timing;
    }
    return actions.first.timing;
  }

  void _selectBestCommandTimingAfterAttackRoll({required bool didHit}) {
    _selectedCommandTiming = 'Action';
  }

  void _selectBestCommandTimingAfterDamageResolution() {
    if (_multiAttackProgress?.hasPendingDamage == true) return;
    _selectedCommandTiming = 'Action';
  }

  bool _hasActionDeckTechniqueRailForActiveCombatant() {
    final actions = _actionsForCombatant(_activeCombatant);
    return actions.any(_actionBelongsInTechniqueRail);
  }

  void _selectNextAvailableCommandTiming({required bool preferBonus}) {
    final preferred = preferBonus
        ? const ['Bonus Action', 'Action', 'Free', 'Reaction']
        : const ['Action', 'Bonus Action', 'Free', 'Reaction'];
    final actions = _actionsForCombatant(_activeCombatant);
    final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
      actions,
      _pendingDamageActions,
    );
    for (final timing in preferred) {
      if (_spentTimings.contains(timing)) continue;
      final hasAction = actions.any(
        (action) =>
            _actionVisibleInActionTiming(
              action,
              timing,
              hasPendingOnHitTrigger: hasPendingOnHitTrigger,
            ) &&
            _actionResourceBlockMessage(action) == null &&
            _actionPrerequisiteBlockMessage(action) == null,
      );
      if (!hasAction) continue;
      _selectedCommandTiming = timing;
      return;
    }
  }

  void _selectFocusedCombatant(int index) {
    if (index < 0 || index >= _combatants.length) return;
    if (!_dmView) {
      if (index == _activeIndex) return;
      final message =
          'Vista jugador: solo el DM puede cambiar el turno activo.';
      setState(() {
        _activity.insert(0, CombatLogEntry.system(message));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
        ),
      );
      return;
    }
    setState(() {
      _activeIndex = index;
      _targetIndex = _findDefaultTargetIndex(index);
      _spentTimings.clear();
      _clearClassTurnFlowState();
      _actionAttackUsesByCombatantId.remove(_combatants[index].id);
      _movementBonusFeetByCombatantId.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _spentReactionCombatantIds.remove(_combatants[index].id);
      _oncePerTurnActionUses.removeWhere(
        (key) => key.startsWith('${_combatants[index].id}|'),
      );
      _readiedActionsByCombatantId.remove(_combatants[index].id);
      _clearMultiAttackProgress();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _selectedCommandTiming = 'Action';
      _rollFeedback = null;
      _activeCombatResolutionKeys.clear();
      _workspace = CombatWorkspace.turn;
      _activity.insert(
        0,
        CombatLogEntry.system('${_combatants[index].name} is focused.'),
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
        CombatLogEntry.system('$effectName removed.'),
      );
    });
  }

  void _selectWorkspace(CombatWorkspace workspace) {
    if (workspace == CombatWorkspace.overview) {
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
            showEnemyHp: _dmView || _devCombatMode,
            onClose: () => Navigator.of(dialogContext).maybePop(),
          ),
        );
      },
    );
  }

  void _toggleDmView() {
    if (_hasRouteCharacterId && !_dmView) {
      const message =
          'Vista jugador fija: este controlador solo puede usar su personaje.';
      setState(() {
        _activity.insert(0, CombatLogEntry.system(message));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1800),
        ),
      );
      return;
    }
    setState(() {
      _dmView = !_dmView;
      _activity.insert(
        0,
        CombatLogEntry.system(
          _dmView
              ? 'Vista DM activa: puedes dirigir todos los turnos.'
              : 'Vista jugador activa: solo se muestran acciones propias.',
        ),
      );
    });
  }

  void _toggleDevCombatMode() {
    setState(() {
      _devCombatMode = !_devCombatMode;
      _workspace = CombatWorkspace.turn;
      _activity.insert(
        0,
        CombatLogEntry.system(
          _devCombatMode
              ? 'Modo prueba activo: puedes controlar todos los turnos sin ser DM.'
              : 'Modo prueba desactivado: vuelve el control normal de jugador.',
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _devCombatMode ? 'Modo prueba activo' : 'Modo prueba desactivado',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  void _openDiceRoller() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DiceRollerModal(
          initialDiceColor: _diceColor,
          diceColorPreferenceKey: _diceColorPreferenceKey,
          onDiceColorChanged: (color) => unawaited(_setDiceColor(color)),
          onRoll: (result) {
            if (!mounted) return;

            debugPrint(
              '[CombatMode._openDiceRoller] Roll result received: '
              'formula=${result.formula} '
              'diceCount=${result.diceCount} '
              'sides=${result.sides} '
              'rolls=${result.rolls} '
              'total=${result.total}',
            );

            unawaited(_publishManualDiceRollToBattleBoard(result));
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _publishManualDiceRollToBattleBoard(
    DiceRollResult result,
  ) async {
    final campaignId = _resolvedCampaignId(listen: false);
    final sceneId = _activeBattleBoardSceneId;
    final notation = CombatDiceResultFormatter.diceBoxNotation(result);

    if (campaignId == null || sceneId == null || notation == null) {
      debugPrint(
        '[CombatMode._publishManualDiceRollToBattleBoard] '
        'Skipping board sync: campaignId=$campaignId sceneId=$sceneId '
        'notation=$notation',
      );
      return;
    }

    final now = DateTime.now();
    final eventId = 'combat-manual-roll-${now.microsecondsSinceEpoch}';
    final manualToken = BoardToken.create(
      id: '${sceneId}_combat_manual_roll',
      sceneId: sceneId,
      refId: 'combat-manual-roll',
      type: 'manual',
      name: 'Combat Roll',
      isVisible: false,
      lastEventLabel: notation,
      lastEventKind: 'manual',
      lastEventId: eventId,
      lastEventDiceNotation: notation,
      lastEventDiceColorHex: _diceColorHex,
      lastEventResultLabel: 'Resultado ${result.total}',
      lastEventResultDetail: CombatDiceResultFormatter.detail(result),
      lastEventAuthoritativeDice:
          CombatDiceResultFormatter.authoritativeDiceJson(result),
      controlledByUserId: '',
      now: now,
    );

    debugPrint(
      '[CombatMode._publishManualDiceRollToBattleBoard] '
      'Publishing manual roll token id=${manualToken.id} '
      'sceneId=${manualToken.sceneId} notation=$notation',
    );

    final boardProvider = context.read<BattleBoardProvider>();
    boardProvider.addTemporaryToken(manualToken);

    try {
      await boardProvider.saveToken(
        campaignId: campaignId,
        token: manualToken,
      );
    } catch (error) {
      debugPrint(
        '[CombatMode._publishManualDiceRollToBattleBoard] '
        'Could not persist manual roll token: $error',
      );
    }

    _scheduleBattleBoardEventClear(
      campaignId: campaignId,
      sceneId: sceneId,
      eventId: eventId,
    );
  }

  void _scheduleBattleBoardEventClear({
    required String campaignId,
    required String sceneId,
    required String eventId,
  }) {
    Future.delayed(_battleBoardEventVisibleDuration, () async {
      if (!mounted) return;

      final boardProvider = context.read<BattleBoardProvider>();
      final eventTokens = boardProvider.tokens
          .where(
            (token) =>
                token.sceneId == sceneId &&
                token.lastEventId == eventId &&
                (token.lastEventLabel.isNotEmpty ||
                    token.lastEventAreaShape.isNotEmpty),
          )
          .toList(growable: false);

      for (final token in eventTokens) {
        await boardProvider.saveToken(
          campaignId: campaignId,
          token: token.copyWith(
            lastEventLabel: '',
            lastEventKind: '',
            lastEventId: '',
            lastEventDiceNotation: '',
            lastEventDiceColorHex: '',
            lastEventResultLabel: '',
            lastEventResultDetail: '',
            lastEventAuthoritativeDice: '',
            lastEventDamageType: '',
            lastEventSourceRefId: '',
            lastEventPrimaryTargetRefId: '',
            lastEventAffectedRefIds: const [],
            lastEventAreaShape: '',
            lastEventAreaFeet: 0,
            lastEventAreaTargetX: -1,
            lastEventAreaTargetY: -1,
          ),
        );
      }
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

      await boardProvider.loadScenes(campaignId);
      if (!mounted) return null;
      final resumableScene =
          CombatBattleBoardSessionService.latestResumableScene(
        boardProvider.scenes,
        campaignId: campaignId,
      );
      if (resumableScene != null &&
          _restoreCombatStateFromScene(resumableScene)) {
        boardProvider.watchScene(
          campaignId: campaignId,
          sceneId: resumableScene.id,
        );
        return resumableScene.id;
      }

      final scene = await boardProvider.createScene(
        campaignId: campaignId,
        name: 'Combat Board - Round $_round',
        mapImageUrl: 'assets/images/combat/dungeon_battlefield.png',
        combatActive: _combatStarted,
        combatState: _battleBoardCombatStatePayload(),
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

  Future<bool> _restoreActiveCombatSessionForCampaign(
    String campaignId, {
    bool force = false,
  }) async {
    final normalizedCampaignId = campaignId.trim();
    if (normalizedCampaignId.isEmpty) return false;
    if (!force && _sessionRestoreAttemptCampaignId == normalizedCampaignId) {
      return false;
    }
    _sessionRestoreAttemptCampaignId = normalizedCampaignId;

    try {
      final boardProvider = context.read<BattleBoardProvider>();
      await boardProvider.loadScenes(normalizedCampaignId);
      if (!mounted) return false;
      final resumableScene =
          CombatBattleBoardSessionService.latestResumableScene(
        boardProvider.scenes,
        campaignId: normalizedCampaignId,
      );
      if (resumableScene == null) return false;
      if (!_restoreCombatStateFromScene(resumableScene)) return false;
      boardProvider.watchScene(
        campaignId: normalizedCampaignId,
        sceneId: resumableScene.id,
      );
      unawaited(_syncBattleBoardTokensFromCombatState());
      return true;
    } catch (error) {
      debugPrint('Active combat session restore failed: $error');
      return false;
    }
  }

  bool _restoreCombatStateFromScene(BattleScene scene) {
    if (_restoringBattleBoardScene) return false;
    final state = scene.combatState;
    final encounterRaw = state['encounter'];
    if (encounterRaw is! Map) return false;

    _restoringBattleBoardScene = true;
    try {
      final restoredEncounter = encounter_models.CombatEncounter.fromJson(
        Map<String, dynamic>.from(encounterRaw),
      );
      final restoredMovement = CombatBattleBoardSessionService.intMapFromState(
        state,
        'movementUsedByCombatantId',
      );
      final restoredAttackUses =
          CombatBattleBoardSessionService.intMapFromState(
        state,
        'actionAttackUsesByCombatantId',
      );
      final restoredMovementBonus =
          CombatBattleBoardSessionService.intMapFromState(
        state,
        'movementBonusFeetByCombatantId',
      );

      setState(() {
        _encounter = restoredEncounter;
        _registerPreparedActionsFromEncounter(restoredEncounter);
        _syncUiFromEncounter();
        _combatStarted = state['combatStarted'] as bool? ?? scene.combatActive;
        _round = (state['round'] as num?)?.toInt() ?? _round;
        _activeIndex = ((state['activeIndex'] as num?)?.toInt() ?? _activeIndex)
            .clamp(0, math.max(0, _combatants.length - 1))
            .toInt();
        _targetIndex = ((state['targetIndex'] as num?)?.toInt() ?? _targetIndex)
            .clamp(0, math.max(0, _combatants.length - 1))
            .toInt();
        _selectedCommandTiming = state['selectedCommandTiming']?.toString() ??
            _selectedCommandTiming;
        _battleBoardMovementUsedByCombatantId
          ..clear()
          ..addAll(restoredMovement);
        _actionAttackUsesByCombatantId
          ..clear()
          ..addAll(restoredAttackUses);
        _movementBonusFeetByCombatantId
          ..clear()
          ..addAll(restoredMovementBonus);
        _spentTimings
          ..clear()
          ..addAll(
            CombatBattleBoardSessionService.stringSetFromState(
              state,
              'spentTimings',
            ),
          );
        _pendingDamageActions
          ..clear()
          ..addAll(
            CombatBattleBoardSessionService.stringSetFromState(
              state,
              'pendingDamageActions',
            ),
          );
        _pendingHalfDamageActions
          ..clear()
          ..addAll(
            CombatBattleBoardSessionService.stringSetFromState(
              state,
              'pendingHalfDamageActions',
            ),
          );
        _spentReactionCombatantIds
          ..clear()
          ..addAll(
            CombatBattleBoardSessionService.stringSetFromState(
              state,
              'spentReactionCombatantIds',
            ),
          );
        _oncePerTurnActionUses
          ..clear()
          ..addAll(
            CombatBattleBoardSessionService.stringSetFromState(
              state,
              'oncePerTurnActionUses',
            ),
          );
        _activeBattleBoardSceneId = scene.id;
        _showBattleBoardController = true;
        _battleBoardControllerExpanded = false;
        _selectedBattleBoardCombatantId =
            _combatants.isEmpty ? null : _activeCombatant.id;
        final restoredFocusedActionName =
            state['focusedActionName']?.toString().trim();
        _focusedBattleBoardAction = restoredFocusedActionName == null ||
                restoredFocusedActionName.isEmpty
            ? null
            : _firstOrNull(
                _actionsForCombatant(_activeCombatant).where(
                  (action) => action.name == restoredFocusedActionName,
                ),
              );
        _activity.insert(
          0,
          CombatLogEntry.system('Battle board state restored.'),
        );
      });
      return true;
    } catch (error) {
      debugPrint('Battle board state restore failed: $error');
      return false;
    } finally {
      _restoringBattleBoardScene = false;
    }
  }

  Map<String, dynamic> _battleBoardCombatStatePayload() {
    return CombatBattleBoardSessionService.combatStatePayload(
      combatStarted: _combatStarted,
      round: _round,
      activeIndex: _activeIndex,
      targetIndex: _safeTargetIndex,
      selectedCommandTiming: _selectedCommandTiming,
      movementUsedByCombatantId: _battleBoardMovementUsedByCombatantId,
      actionAttackUsesByCombatantId: _actionAttackUsesByCombatantId,
      movementBonusFeetByCombatantId: _movementBonusFeetByCombatantId,
      spentTimings: _spentTimings,
      pendingDamageActions: _pendingDamageActions,
      pendingHalfDamageActions: _pendingHalfDamageActions,
      spentReactionCombatantIds: _spentReactionCombatantIds,
      oncePerTurnActionUses: _oncePerTurnActionUses,
      focusedActionName: _focusedBattleBoardAction?.name,
      encounterJson: _encounter?.toJson(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _persistBattleBoardCombatState(
    BattleBoardProvider boardProvider,
  ) async {
    final scene = boardProvider.activeScene;
    final sceneId = _activeBattleBoardSceneId;
    if (scene == null || sceneId == null || scene.id != sceneId) return;
    await boardProvider.saveScene(
      scene.copyWith(
        combatActive: _combatStarted,
        combatState: _battleBoardCombatStatePayload(),
      ),
    );
  }

  Future<void> _requestEndCombatSession() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End combat?'),
          content: const Text(
            'The active combat session will be closed and will not resume the next time Combat is opened.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.flag_circle_outlined),
              label: const Text('End combat'),
            ),
          ],
        );
      },
    );
    if (shouldEnd != true || !mounted) return;
    await _endCombatSession();
  }

  Future<void> _endCombatSession() async {
    final campaignId = _resolvedCampaignId(listen: false);
    final sceneId = _activeBattleBoardSceneId;
    final boardProvider = context.read<BattleBoardProvider>();
    await _flushCharacterCombatState();
    if (!mounted) return;

    final scene = boardProvider.activeScene?.id == sceneId
        ? boardProvider.activeScene
        : _firstOrNull(
            boardProvider.scenes.where((item) => item.id == sceneId),
          );

    if (scene != null) {
      await boardProvider.saveScene(
        scene.copyWith(
          combatActive: false,
          combatState: const {},
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      if (_encounter != null) {
        _encounter = CombatEncounterEngine.completeEncounter(_encounter!);
      }
      _combatStarted = false;
      _showBattleBoardController = false;
      _battleBoardControllerExpanded = true;
      _activeBattleBoardSceneId = null;
      _selectedBattleBoardCombatantId = null;
      _focusedBattleBoardAction = null;
      _battleBoardMovementUsedByCombatantId.clear();
      _queuedBattleBoardMovesByCombatantId.clear();
      _battleBoardMoveInFlightCombatantIds.clear();
      _spentTimings.clear();
      _clearClassTurnFlowState();
      _actionAttackUsesByCombatantId.clear();
      _movementBonusFeetByCombatantId.clear();
      _pendingDamageActions.clear();
      _pendingHalfDamageActions.clear();
      _spentReactionCombatantIds.clear();
      _oncePerTurnActionUses.clear();
      _clearMultiAttackProgress();
      _preparedActions.clear();
      _resetQueuedPreparedActions();
      _selectedCommandTiming = 'Action';
      _workspace = CombatWorkspace.turn;
      _sessionRestoreAttemptCampaignId = campaignId;
      _activity.insert(
        0,
        CombatLogEntry.system('Combat ended. Active session cleared.'),
      );
    });
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
      _battleBoardMovementUsedByCombatantId.putIfAbsent(
        _activeCombatant.id,
        () => 0,
      );
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
    return CombatBattleBoardSessionService.displayUrl(
      baseUri: Uri.base,
      campaignId: campaignId,
      sceneId: sceneId,
    );
  }

  int? _rangeFeetForCombatAction(CombatAction action) {
    if (action.longRangeFeet != null && action.longRangeFeet! > 0) {
      return action.longRangeFeet;
    }
    if (action.rangeFeet != null) return action.rangeFeet;
    return _rangeFeetFromActionText(
      name: action.name,
      type: action.type,
      tags: action.tags,
      source: null,
      isSelf: action.targetsSelf,
      isHealing: action.isHealing,
      hasSavingThrow: action.requiresSavingThrow,
      hasAttack: action.attackFormula != null || action.hasMultiAttack,
      hasDamage: action.damageFormula != null,
    );
  }

  BoardActionRangeSnapshot? _boardActionRangeFor(
    CombatAction action, {
    int? actorIndex,
    int? forcedTargetIndex,
  }) {
    if (!_showBattleBoardController && _activeBattleBoardSceneId == null) {
      return null;
    }
    if (action.targetsSelf || action.targetPolicy == 'self') return null;

    final sceneId = _activeBattleBoardSceneId;
    if (sceneId == null || _combatants.isEmpty) return null;
    final resolvedActorIndex =
        (actorIndex ?? _activeIndex).clamp(0, _combatants.length - 1).toInt();
    final targetIndex = _targetIndexForAction(
      action,
      actorIndex: resolvedActorIndex,
      forcedTargetIndex: forcedTargetIndex,
    );
    if (targetIndex == null) return null;

    final boardProvider = context.read<BattleBoardProvider>();
    final sceneTokens = boardProvider.tokens
        .where((token) => token.sceneId == sceneId)
        .toList(growable: false);
    final actor = _combatants[resolvedActorIndex];
    final target = _combatants[targetIndex];
    final actorToken = CombatBoardTokenLookup.byRef(sceneTokens, actor.id);
    final targetToken = CombatBoardTokenLookup.byRef(sceneTokens, target.id);
    if (actorToken == null || targetToken == null) return null;

    final aimToken = action.hasAreaEffect
        ? _areaAimTokenForAction(
            action: action,
            sceneId: sceneId,
            sceneTokens: sceneTokens,
            fallbackToken: targetToken,
          )
        : targetToken;
    final rangeFeet = _rangeFeetForCombatAction(action);
    final distanceFeet = CombatBoardGeometry.distanceFeet(actorToken, aimToken);
    final isInRange = rangeFeet == null || distanceFeet <= rangeFeet;
    return BoardActionRangeSnapshot(
      actor: actor,
      target: target,
      distanceFeet: distanceFeet,
      rangeFeet: rangeFeet,
      isInRange: isInRange,
    );
  }

  int? _normalRangeFeetForCombatAction(CombatAction action) {
    if (action.rangeFeet != null && action.rangeFeet! > 0) {
      return action.rangeFeet;
    }
    return _rangeFeetFromActionText(
      name: action.name,
      type: action.type,
      tags: action.tags,
      source: null,
      isSelf: action.targetsSelf,
      isHealing: action.isHealing,
      hasSavingThrow: action.requiresSavingThrow,
      hasAttack: action.attackFormula != null || action.hasMultiAttack,
      hasDamage: action.damageFormula != null,
    );
  }

  bool _attackHasLongRangeDisadvantage(
    CombatAction action, {
    int? actorIndex,
    int? forcedTargetIndex,
  }) {
    final longRangeFeet = action.longRangeFeet;
    if (longRangeFeet == null || longRangeFeet <= 0) return false;
    final normalRangeFeet = _normalRangeFeetForCombatAction(action);
    if (normalRangeFeet == null || normalRangeFeet <= 0) return false;
    final snapshot = _boardActionRangeFor(
      action,
      actorIndex: actorIndex,
      forcedTargetIndex: forcedTargetIndex,
    );
    if (snapshot == null) return false;
    return snapshot.distanceFeet > normalRangeFeet &&
        snapshot.distanceFeet <= longRangeFeet;
  }

  bool _ensureBattleBoardActionRange(CombatAction action) {
    final snapshot = _boardActionRangeFor(action);
    if (snapshot == null || snapshot.isInRange) {
      _focusedBattleBoardAction = action;
      if (_showBattleBoardController) {
        unawaited(_syncBattleBoardTokensFromCombatState());
      }
      return true;
    }

    _focusedBattleBoardAction = action;
    setState(() {
      _activity.insert(
        0,
        CombatLogEntry.system(
          '${snapshot.target.name} is out of range for ${action.name}: ${snapshot.distanceFeet}/${snapshot.rangeFeet} ft.',
        ),
      );
      _rollFeedback = CombatRollFeedback.manual(
        actor: snapshot.actor.name,
        action: action.name,
        headline: 'OUT OF RANGE',
        subline:
            '${snapshot.target.name} is ${snapshot.distanceFeet} ft away; ${snapshot.rangeFeet} ft needed.',
        accentKind: CombatAccentKind.action,
      );
    });
    unawaited(
      _syncBattleBoardTokensFromCombatState(
        eventLabel: 'OUT OF RANGE',
        eventKind: 'blocked',
      ),
    );
    return false;
  }

  Future<void> _moveBattleBoardToken(String combatantId, int dx, int dy) async {
    if (_battleBoardMoveInFlightCombatantIds.contains(combatantId)) {
      final queued = _queuedBattleBoardMovesByCombatantId[combatantId] ??
          const math.Point<int>(0, 0);
      _queuedBattleBoardMovesByCombatantId[combatantId] =
          math.Point<int>(queued.x + dx, queued.y + dy);
      return;
    }
    _battleBoardMoveInFlightCombatantIds.add(combatantId);
    try {
      await _moveBattleBoardTokenImmediate(combatantId, dx, dy);
    } finally {
      _battleBoardMoveInFlightCombatantIds.remove(combatantId);
    }

    final queued = _queuedBattleBoardMovesByCombatantId.remove(combatantId);
    if (queued != null && (queued.x != 0 || queued.y != 0)) {
      unawaited(_moveBattleBoardToken(combatantId, queued.x, queued.y));
    }
  }

  Future<void> _moveBattleBoardTokenImmediate(
    String combatantId,
    int dx,
    int dy,
  ) async {
    if (combatantId == _activeCombatant.id &&
        _focusedBattleBoardAction?.hasAreaEffect == true) {
      await _moveBattleBoardAreaAim(dx, dy);
      return;
    }

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

    final combatantIndex = _combatants.indexWhere(
      (combatant) => combatant.id == combatantId,
    );
    if (combatantIndex == -1) return;

    final combatant = _combatants[combatantIndex];
    final token = matchingTokens.first;
    if (combatant.hp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${combatant.name} is down and cannot move.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final maxX = math.max(0, scene.gridColumns - token.size);
    final maxY = math.max(0, scene.gridRows - token.size);
    final nextX = (token.x + dx).clamp(0, maxX).toInt();
    final nextY = (token.y + dy).clamp(0, maxY).toInt();
    if (nextX == token.x && nextY == token.y) return;

    final speedFeet = _effectiveMovementBudget(combatant) > 0
        ? _effectiveMovementBudget(combatant)
        : token.speedFeet;
    final movementUsed = _battleBoardMovementUsedByCombatantId[combatantId] ??
        token.movementUsedFeet;
    final originX = movementUsed <= 0 ? token.x : token.movementOriginX;
    final originY = movementUsed <= 0 ? token.y : token.movementOriginY;
    final updatedMovementUsed =
        math.max((nextX - originX).abs(), (nextY - originY).abs()) * 5;
    if (updatedMovementUsed > speedFeet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${combatant.name} cannot move beyond $speedFeet ft this turn.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _battleBoardMovementUsedByCombatantId[combatantId] = updatedMovementUsed;
    });

    final focusedAction = _focusedBattleBoardAction;
    final focusedRangeFeet = focusedAction == null
        ? 0
        : _rangeFeetForCombatAction(focusedAction) ?? 0;
    final focusedAreaShape = focusedAction?.areaShape ?? '';
    final focusedAreaFeet = focusedAction?.areaFeet ?? 0;
    final sceneTokens = boardProvider.tokens
        .where((item) => item.sceneId == sceneId)
        .toList(growable: false);
    final movedToken = token.copyWith(
      x: nextX,
      y: nextY,
      speedFeet: speedFeet,
      movementUsedFeet: updatedMovementUsed,
      movementOriginX: originX,
      movementOriginY: originY,
    );
    BoardToken? tokenForCombatant(String refId) {
      if (refId == combatantId) return movedToken;
      return CombatBoardTokenLookup.byRef(sceneTokens, refId);
    }

    final activeBoardToken = tokenForCombatant(_activeCombatant.id);
    final targetBoardToken = tokenForCombatant(_selectedTarget.id);
    final nextDistanceFeet = activeBoardToken == null ||
            targetBoardToken == null
        ? 0
        : CombatBoardGeometry.distanceFeet(activeBoardToken, targetBoardToken);
    final nextTargetInRange = focusedAction == null ||
        focusedAction.targetsSelf ||
        focusedRangeFeet == 0 ||
        nextDistanceFeet <= focusedRangeFeet;

    BoardToken hydrateBoardToken(BoardToken item) {
      final isActive = item.refId == _activeCombatant.id;
      final isTargeted = item.refId == _selectedTarget.id;
      final matchingCombatant = _combatants.firstWhere(
        (candidate) => candidate.id == item.refId,
        orElse: () => combatant,
      );
      return item.copyWith(
        currentHp: matchingCombatant.hp,
        maxHp: matchingCombatant.maxHp,
        size: CombatBoardTokenSizing.sizeForRole(matchingCombatant.role),
        initiative: matchingCombatant.initiative,
        role: matchingCombatant.role,
        speedFeet: item.refId == combatantId
            ? speedFeet
            : _effectiveMovementBudget(matchingCombatant),
        movementUsedFeet: item.refId == combatantId
            ? updatedMovementUsed
            : _battleBoardMovementUsedByCombatantId[item.refId] ??
                item.movementUsedFeet,
        movementOriginX:
            item.refId == combatantId ? originX : item.movementOriginX,
        movementOriginY:
            item.refId == combatantId ? originY : item.movementOriginY,
        selectedActionRangeFeet: isActive ? focusedRangeFeet : 0,
        selectedActionAreaShape: isActive ? focusedAreaShape : '',
        selectedActionAreaFeet: isActive ? focusedAreaFeet : 0,
        selectedActionAimX:
            isActive && focusedAreaFeet > 0 ? item.selectedActionAimX : -1,
        selectedActionAimY:
            isActive && focusedAreaFeet > 0 ? item.selectedActionAimY : -1,
        targetDistanceFeet: isActive || isTargeted ? nextDistanceFeet : 0,
        conditions: matchingCombatant.conditions,
        isActive: isActive,
        isTargeted: isTargeted,
        isTargetInRange: isActive || isTargeted ? nextTargetInRange : true,
        focusedActionName: isActive ? focusedAction?.name ?? '' : '',
      );
    }

    await boardProvider.saveToken(
      campaignId: campaignId,
      token: hydrateBoardToken(movedToken),
    );
    final counterpartTokens = [
      if (activeBoardToken != null && activeBoardToken.id != movedToken.id)
        activeBoardToken,
      if (targetBoardToken != null &&
          targetBoardToken.id != movedToken.id &&
          targetBoardToken.id != activeBoardToken?.id)
        targetBoardToken,
    ];
    for (final counterpart in counterpartTokens) {
      await boardProvider.saveToken(
        campaignId: campaignId,
        token: hydrateBoardToken(counterpart),
      );
    }
    await _persistBattleBoardCombatState(boardProvider);
  }

  Future<void> _moveBattleBoardAreaAim(int dx, int dy) async {
    final campaignId = _resolvedCampaignId(listen: false);
    final sceneId = _activeBattleBoardSceneId;
    final action = _focusedBattleBoardAction;
    if (campaignId == null ||
        sceneId == null ||
        action == null ||
        !action.hasAreaEffect) {
      return;
    }

    final boardProvider = context.read<BattleBoardProvider>();
    final scene = boardProvider.activeScene;
    if (scene == null) return;

    final sceneTokens = boardProvider.tokens
        .where((token) => token.sceneId == sceneId)
        .toList(growable: false);
    final activeToken =
        CombatBoardTokenLookup.byRef(sceneTokens, _activeCombatant.id);
    if (activeToken == null) return;
    final targetToken =
        CombatBoardTokenLookup.byRef(sceneTokens, _selectedTarget.id);
    final currentX = activeToken.selectedActionAimX >= 0
        ? activeToken.selectedActionAimX
        : targetToken?.x ?? activeToken.x;
    final currentY = activeToken.selectedActionAimY >= 0
        ? activeToken.selectedActionAimY
        : targetToken?.y ?? activeToken.y;
    final nextX = (currentX + dx).clamp(0, scene.gridColumns - 1).toInt();
    final nextY = (currentY + dy).clamp(0, scene.gridRows - 1).toInt();
    if (nextX == currentX && nextY == currentY) return;

    final updatedToken = activeToken.copyWith(
      selectedActionAimX: nextX,
      selectedActionAimY: nextY,
    );
    boardProvider.addTemporaryToken(updatedToken);
    await boardProvider.saveToken(
      campaignId: campaignId,
      token: updatedToken,
    );
    await _syncBattleBoardTokensFromCombatState();
  }

  Future<void> _removeBattleBoardTokenForCombatant(int combatantIndex) async {
    if (combatantIndex < 0 || combatantIndex >= _combatants.length) return;
    if (!_dmView && !_devCombatMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo el DM o el modo prueba pueden retirar fichas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final campaignId = _resolvedCampaignId(listen: false);
    final sceneId = _activeBattleBoardSceneId;
    if (campaignId == null || sceneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay tablero activo para retirar la ficha.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final combatant = _combatants[combatantIndex];
    final boardProvider = context.read<BattleBoardProvider>();
    final token = _firstOrNull(
      boardProvider.tokens.where(
        (token) => token.sceneId == sceneId && token.refId == combatant.id,
      ),
    );
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${combatant.name} ya no tiene ficha en el tablero.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Retirar ${combatant.name}?'),
          content: const Text(
            'La ficha se borrara del tablero, pero el combatiente seguira en el combate para death saves u otros estados.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Retirar ficha'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await boardProvider.deleteToken(
      campaignId: campaignId,
      sceneId: sceneId,
      tokenId: token.id,
    );
    await _persistBattleBoardCombatState(boardProvider);
    if (!mounted) return;
    setState(() {
      if (_selectedBattleBoardCombatantId == combatant.id) {
        _selectedBattleBoardCombatantId = null;
      }
      _activity.insert(
        0,
        CombatLogEntry.system('${combatant.name} fue retirado del tablero.'),
      );
    });
  }

  Future<void> _syncBattleBoardTokensFromCombatState({
    String? eventLabel,
    String eventKind = 'focus',
    String eventDiceNotation = '',
    String? eventDiceColorHex,
    String eventResultLabel = '',
    String eventResultDetail = '',
    String eventAuthoritativeDice = '',
    String? eventIdOverride,
    String eventDamageType = '',
    Set<String> eventTargetIds = const <String>{},
    String? eventDiceTargetId,
    String? eventSourceRefId,
    String? eventPrimaryTargetRefId,
    String eventAreaShape = '',
    int eventAreaFeet = 0,
    int? eventAreaTargetX,
    int? eventAreaTargetY,
  }) async {
    final campaignId = _resolvedCampaignId(listen: false);
    final sceneId = _activeBattleBoardSceneId;
    if (campaignId == null || sceneId == null) return;

    final boardProvider = context.read<BattleBoardProvider>();
    final now = DateTime.now();

    final result = await _battleBoardSyncService.syncTokens(
      boardProvider: boardProvider,
      campaignId: campaignId,
      sceneId: sceneId,
      combatants: _boardSyncCombatants(),
      movementUsedByCombatantId: _battleBoardMovementUsedByCombatantId,
      activeCombatantId: _activeCombatant.id,
      selectedTargetId: _selectedTarget.id,
      focus: _boardSyncFocus(),
      defaultDiceColorHex: _diceColorHex,
      eventVisibleDuration: _battleBoardEventVisibleDuration,
      now: now,
      event: CombatBoardEventSyncPayload(
        label: eventLabel,
        kind: eventKind,
        diceNotation: eventDiceNotation,
        diceColorHex: eventDiceColorHex,
        resultLabel: eventResultLabel,
        resultDetail: eventResultDetail,
        authoritativeDice: eventAuthoritativeDice,
        eventIdOverride: eventIdOverride,
        damageType: eventLabel == null
            ? ''
            : CombatDamageTypeRules.normalize(eventDamageType) ?? '',
        targetIds: eventTargetIds,
        diceTargetId: eventDiceTargetId,
        sourceRefId: eventSourceRefId,
        primaryTargetRefId: eventPrimaryTargetRefId,
        areaShape: eventAreaShape,
        areaFeet: eventAreaFeet,
        areaTargetX: eventAreaTargetX,
        areaTargetY: eventAreaTargetY,
      ),
    );

    await _persistBattleBoardCombatState(boardProvider);

    if (result.eventId != null) {
      _scheduleBattleBoardEventClear(
        campaignId: campaignId,
        sceneId: sceneId,
        eventId: result.eventId!,
      );
    }
  }

  List<BoardToken> _boardTokensForScene(String sceneId) {
    return _battleBoardSyncService.buildInitialTokens(
      sceneId: sceneId,
      combatants: _boardSyncCombatants(),
      movementUsedByCombatantId: _battleBoardMovementUsedByCombatantId,
      activeCombatantId: _activeCombatant.id,
      selectedTargetId: _selectedTarget.id,
      focus: _boardSyncFocus(),
    );
  }

  List<CombatBoardSyncCombatant> _boardSyncCombatants() {
    return _combatants
        .map(
          (combatant) => CombatBoardSyncCombatant(
            id: combatant.id,
            name: combatant.name,
            imageUrl: combatant.portraitAsset ?? '',
            team: combatant.team == CombatTeam.party ? 'party' : 'enemy',
            hp: combatant.hp,
            maxHp: combatant.maxHp,
            initiative: combatant.initiative,
            role: combatant.role,
            speedFeet: _effectiveMovementBudget(combatant),
            tokenSize: CombatBoardTokenSizing.sizeForRole(combatant.role),
            conditions: combatant.conditions,
          ),
        )
        .toList(growable: false);
  }

  CombatBoardSyncFocus _boardSyncFocus() {
    final focusedAction = _focusedBattleBoardAction;
    if (focusedAction == null) return CombatBoardSyncFocus.empty;

    final rangeSnapshot = _boardActionRangeFor(focusedAction);
    return CombatBoardSyncFocus(
      actionName: focusedAction.name,
      rangeFeet: _rangeFeetForCombatAction(focusedAction) ?? 0,
      areaShape: focusedAction.areaShape,
      areaFeet: focusedAction.areaFeet,
      targetDistanceFeet: rangeSnapshot?.distanceFeet ?? 0,
      targetInRange: rangeSnapshot?.isInRange ?? true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final boardCampaignId = _resolvedCampaignId(listen: false);
    final boardSceneId = _activeBattleBoardSceneId;
    final boardDisplayUrl = boardCampaignId != null && boardSceneId != null
        ? _displayBoardUrl(boardCampaignId, boardSceneId)
        : null;
    final boardControllerActive =
        _combatStarted && _showBattleBoardController && boardDisplayUrl != null;
    if (boardControllerActive) {
      final boardProvider = context.watch<BattleBoardProvider>();
      _scheduleTargetSelectionFromBoard(boardProvider.tokens);
    }
    final viewportSize = MediaQuery.sizeOf(context);
    final useIntegratedBoardController = viewportSize.width.isFinite;
    final pendingSavePrompt = _combatStarted ? _pendingSavePromptData() : null;

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
              child: CombatArenaBackdrop(round: _round),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (!_combatStarted) {
                    return CombatSetupView(
                      combatants: _combatants,
                      monsterCatalog: _visibleMonsterCatalog,
                      totalMonsterCount: _monsterCatalog.length,
                      monsterSearchQuery: _monsterSearchQuery,
                      monsterCatalogError: _monsterCatalogError,
                      stagedMonsterCounts: _stagedMonsterCounts,
                      customMonsters: _customMonsterCatalog,
                      stagedCustomMonsterCounts: _stagedCustomMonsterCounts,
                      inactivePartyCombatantIds: _inactivePartyCombatantIds,
                      customMonsterLoading: _customMonsterCatalogLoading,
                      customMonsterError: _customMonsterCatalogError,
                      loading: _monsterCatalogLoading,
                      showDebugBadges: _showCombatModeDebugBanner,
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
                      onTogglePartyCombatant: _toggleSetupPartyCombatant,
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
                  final controllerActions = canControlActive
                      ? _activeActions
                      : const <CombatAction>[];
                  final selectedCommandTiming =
                      _selectedTimingAvailableForActions(
                    _selectedCommandTiming,
                    controllerActions,
                  );
                  final showEnemyHp = _dmView || _devCombatMode;

                  if (useGameLayout) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1420),
                        child: _CombatUnifiedControllerView(
                          round: _round,
                          combatants: _combatants,
                          activeIndex: _activeIndex,
                          targetIndex: _safeTargetIndex,
                          activeCombatant: _activeCombatant,
                          selectedTarget: _selectedTarget,
                          actions: controllerActions,
                          rollFeedback: _rollFeedback,
                          rollInFlight: _combatRollInFlight,
                          spentTimings: _spentTimings,
                          pendingDamageActions: _pendingDamageActions,
                          preparedActions: _preparedActions,
                          activeMultiAttackActionKey:
                              _multiAttackProgress?.actionKey,
                          activeMultiAttackStepIndex:
                              _multiAttackProgress?.stepIndex ?? 0,
                          activeMultiAttackPendingAttacks:
                              _multiAttackProgress?.pendingAttacks ?? const [],
                          reactionOptions: _reactionOptions,
                          hasTakenAttackActionThisTurn:
                              _hasTakenAttackActionThisTurn(_activeCombatant),
                          martialArtsEligibleAttackThisTurn:
                              _hasMartialArtsEligibleAttackThisTurn(
                            _activeCombatant,
                          ),
                          flurryAlreadyUsedThisTurn:
                              _flurryUsedThisTurnCombatantIds.contains(
                            _activeCombatant.id,
                          ),
                          activeEconomy: _activeEconomy,
                          queuedPreparedIndex: _queuedPreparedIndex,
                          queuedPreparedTotal: _queuedPreparedActions.length,
                          queuedPreparedActionName: _queuedPreparedActionName,
                          selectedCommandTiming: selectedCommandTiming,
                          workspace: _workspace,
                          showEnemyHp: showEnemyHp,
                          devMode: _devCombatMode,
                          entries: _activity,
                          resourcePool: _activeResourcePool,
                          rollMode: _rollMode,
                          canControlActive: canControlActive,
                          controlBlockedMessage: controlBlockedMessage,
                          boardControllerActive: boardControllerActive,
                          openingBattleBoard: _openingBattleBoard,
                          boardSceneId: boardSceneId,
                          focusedBattleBoardAction: _focusedBattleBoardAction,
                          onBack: () => unawaited(_exitCombatMode()),
                          onRequestInitiative: _requestInitiative,
                          onRollInitiative: _rollInitiativeForAll,
                          onNextTurn: _nextTurn,
                          onToggleDmView: _toggleDmView,
                          onToggleDevMode: _toggleDevCombatMode,
                          onOpenDiceRoller: _openDiceRoller,
                          onShowBattleBoardControls: () =>
                              unawaited(_showBattleBoardControls()),
                          onEndCombat: () =>
                              unawaited(_requestEndCombatSession()),
                          onRunDemo: _runDemoRound,
                          onSelectTarget: _selectTarget,
                          onSelectFocusedCombatant: _selectFocusedCombatant,
                          onEditHp: _openHpAdjustmentSheet,
                          onRemoveBoardToken: (index) => unawaited(
                              _removeBattleBoardTokenForCombatant(index)),
                          onRemoveActiveEffect: _removeActiveEffect,
                          onSelectWorkspace: _selectWorkspace,
                          onSelectCommandTiming: _selectCommandTiming,
                          onSelectRollMode: _selectRollMode,
                          onFocusAction: _focusActionForController,
                          onUseReaction: _useReaction,
                          onReadyAction: _readyAction,
                          onRollSavingThrow: _rollManualSavingThrow,
                          onRollAction: _rollAction,
                          onUseAction: _useAction,
                          onPrepareAction: _prepareAction,
                          onLaunchPreparedTurn: _launchPreparedTurn,
                          onClearPreparedActions: _clearPreparedActions,
                          onControlBlocked: _notifyActiveControlBlocked,
                          onMoveBoardToken: _moveBattleBoardToken,
                        ),
                      ),
                    );
                  }

                  if (useCompactLandscapeLayout) {
                    return _CombatUnifiedControllerView(
                      round: _round,
                      combatants: _combatants,
                      activeIndex: _activeIndex,
                      targetIndex: _safeTargetIndex,
                      activeCombatant: _activeCombatant,
                      selectedTarget: _selectedTarget,
                      actions: controllerActions,
                      rollFeedback: _rollFeedback,
                      rollInFlight: _combatRollInFlight,
                      spentTimings: _spentTimings,
                      pendingDamageActions: _pendingDamageActions,
                      preparedActions: _preparedActions,
                      activeMultiAttackActionKey:
                          _multiAttackProgress?.actionKey,
                      activeMultiAttackStepIndex:
                          _multiAttackProgress?.stepIndex ?? 0,
                      activeMultiAttackPendingAttacks:
                          _multiAttackProgress?.pendingAttacks ?? const [],
                      reactionOptions: _reactionOptions,
                      hasTakenAttackActionThisTurn:
                          _hasTakenAttackActionThisTurn(_activeCombatant),
                      martialArtsEligibleAttackThisTurn:
                          _hasMartialArtsEligibleAttackThisTurn(
                        _activeCombatant,
                      ),
                      flurryAlreadyUsedThisTurn:
                          _flurryUsedThisTurnCombatantIds.contains(
                        _activeCombatant.id,
                      ),
                      activeEconomy: _activeEconomy,
                      queuedPreparedIndex: _queuedPreparedIndex,
                      queuedPreparedTotal: _queuedPreparedActions.length,
                      queuedPreparedActionName: _queuedPreparedActionName,
                      selectedCommandTiming: selectedCommandTiming,
                      workspace: _workspace,
                      showEnemyHp: showEnemyHp,
                      devMode: _devCombatMode,
                      entries: _activity,
                      resourcePool: _activeResourcePool,
                      rollMode: _rollMode,
                      canControlActive: canControlActive,
                      controlBlockedMessage: controlBlockedMessage,
                      boardControllerActive: boardControllerActive,
                      openingBattleBoard: _openingBattleBoard,
                      boardSceneId: boardSceneId,
                      focusedBattleBoardAction: _focusedBattleBoardAction,
                      onBack: () => unawaited(_exitCombatMode()),
                      onRequestInitiative: _requestInitiative,
                      onRollInitiative: _rollInitiativeForAll,
                      onNextTurn: _nextTurn,
                      onToggleDmView: _toggleDmView,
                      onToggleDevMode: _toggleDevCombatMode,
                      onOpenDiceRoller: _openDiceRoller,
                      onShowBattleBoardControls: () =>
                          unawaited(_showBattleBoardControls()),
                      onEndCombat: () => unawaited(_requestEndCombatSession()),
                      onRunDemo: _runDemoRound,
                      onSelectTarget: _selectTarget,
                      onSelectFocusedCombatant: _selectFocusedCombatant,
                      onEditHp: _openHpAdjustmentSheet,
                      onRemoveBoardToken: (index) =>
                          unawaited(_removeBattleBoardTokenForCombatant(index)),
                      onRemoveActiveEffect: _removeActiveEffect,
                      onSelectWorkspace: _selectWorkspace,
                      onSelectCommandTiming: _selectCommandTiming,
                      onSelectRollMode: _selectRollMode,
                      onFocusAction: _focusActionForController,
                      onUseReaction: _useReaction,
                      onReadyAction: _readyAction,
                      onRollSavingThrow: _rollManualSavingThrow,
                      onRollAction: _rollAction,
                      onUseAction: _useAction,
                      onPrepareAction: _prepareAction,
                      onLaunchPreparedTurn: _launchPreparedTurn,
                      onClearPreparedActions: _clearPreparedActions,
                      onControlBlocked: _notifyActiveControlBlocked,
                      onMoveBoardToken: _moveBattleBoardToken,
                    );
                  }

                  return _CombatUnifiedControllerView(
                    round: _round,
                    combatants: _combatants,
                    activeIndex: _activeIndex,
                    targetIndex: _safeTargetIndex,
                    activeCombatant: _activeCombatant,
                    selectedTarget: _selectedTarget,
                    actions: controllerActions,
                    rollFeedback: _rollFeedback,
                    rollInFlight: _combatRollInFlight,
                    spentTimings: _spentTimings,
                    pendingDamageActions: _pendingDamageActions,
                    preparedActions: _preparedActions,
                    activeMultiAttackActionKey: _multiAttackProgress?.actionKey,
                    activeMultiAttackStepIndex:
                        _multiAttackProgress?.stepIndex ?? 0,
                    activeMultiAttackPendingAttacks:
                        _multiAttackProgress?.pendingAttacks ?? const [],
                    reactionOptions: _reactionOptions,
                    hasTakenAttackActionThisTurn:
                        _hasTakenAttackActionThisTurn(_activeCombatant),
                    martialArtsEligibleAttackThisTurn:
                        _hasMartialArtsEligibleAttackThisTurn(
                      _activeCombatant,
                    ),
                    flurryAlreadyUsedThisTurn:
                        _flurryUsedThisTurnCombatantIds.contains(
                      _activeCombatant.id,
                    ),
                    activeEconomy: _activeEconomy,
                    queuedPreparedIndex: _queuedPreparedIndex,
                    queuedPreparedTotal: _queuedPreparedActions.length,
                    queuedPreparedActionName: _queuedPreparedActionName,
                    selectedCommandTiming: selectedCommandTiming,
                    workspace: _workspace,
                    showEnemyHp: showEnemyHp,
                    devMode: _devCombatMode,
                    entries: _activity,
                    resourcePool: _activeResourcePool,
                    rollMode: _rollMode,
                    canControlActive: canControlActive,
                    controlBlockedMessage: controlBlockedMessage,
                    boardControllerActive: boardControllerActive,
                    openingBattleBoard: _openingBattleBoard,
                    boardSceneId: boardSceneId,
                    focusedBattleBoardAction: _focusedBattleBoardAction,
                    onBack: () => unawaited(_exitCombatMode()),
                    onRequestInitiative: _requestInitiative,
                    onRollInitiative: _rollInitiativeForAll,
                    onNextTurn: _nextTurn,
                    onToggleDmView: _toggleDmView,
                    onToggleDevMode: _toggleDevCombatMode,
                    onOpenDiceRoller: _openDiceRoller,
                    onShowBattleBoardControls: () =>
                        unawaited(_showBattleBoardControls()),
                    onEndCombat: () => unawaited(_requestEndCombatSession()),
                    onRunDemo: _runDemoRound,
                    onSelectTarget: _selectTarget,
                    onSelectFocusedCombatant: _selectFocusedCombatant,
                    onEditHp: _openHpAdjustmentSheet,
                    onRemoveBoardToken: (index) =>
                        unawaited(_removeBattleBoardTokenForCombatant(index)),
                    onRemoveActiveEffect: _removeActiveEffect,
                    onSelectWorkspace: _selectWorkspace,
                    onSelectCommandTiming: _selectCommandTiming,
                    onSelectRollMode: _selectRollMode,
                    onFocusAction: _focusActionForController,
                    onUseReaction: _useReaction,
                    onReadyAction: _readyAction,
                    onRollSavingThrow: _rollManualSavingThrow,
                    onRollAction: _rollAction,
                    onUseAction: _useAction,
                    onPrepareAction: _prepareAction,
                    onLaunchPreparedTurn: _launchPreparedTurn,
                    onClearPreparedActions: _clearPreparedActions,
                    onControlBlocked: _notifyActiveControlBlocked,
                    onMoveBoardToken: _moveBattleBoardToken,
                  );
                },
              ),
            ),
            if (_combatStarted && pendingSavePrompt != null)
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _PendingSavePrompt(
                      data: pendingSavePrompt,
                      onRoll: () => _rollPendingAreaSavingThrow(
                        pendingSavePrompt.action,
                      ),
                    ),
                  ),
                ),
              ),
            if (_combatStarted &&
                _showBattleBoardController &&
                boardDisplayUrl != null &&
                !useIntegratedBoardController)
              Positioned(
                top: 78,
                right: 16,
                child: SafeArea(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: CombatBattleBoardFloatingController(
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
          ],
        ),
      ),
    );
  }

  List<Combatant> _buildDefaultCombatants() {
    return [
      const Combatant(
        id: 'demo_arnnazal',
        name: 'Arnnazal',
        role: 'Half-Orc Paladin 5 / Blood Hunter 2',
        initiative: 18,
        initiativeBonus: 3,
        hp: 174,
        maxHp: 174,
        ac: 12,
        speed: 30,
        team: CombatTeam.party,
        portraitAsset: 'assets/images/races/half-orc.png',
        conditions: ['Blessed'],
      ),
      const Combatant(
        id: 'demo_lyra',
        name: 'Lyra',
        role: 'Wizard',
        initiative: 15,
        initiativeBonus: 2,
        hp: 32,
        maxHp: 38,
        ac: 14,
        speed: 30,
        team: CombatTeam.party,
        portraitAsset: 'assets/images/classes/wizard.png',
        conditions: ['Concentrating'],
      ),
      const Combatant(
        id: 'demo_hobgoblin_captain',
        name: 'Hobgoblin Captain',
        role: 'Enemy Leader',
        initiative: 14,
        initiativeBonus: 1,
        hp: 48,
        maxHp: 65,
        ac: 17,
        speed: 30,
        team: CombatTeam.enemy,
        portraitAsset: 'assets/images/races/hobgoblin.png',
        conditions: ['Marked'],
      ),
      const Combatant(
        id: 'demo_goblin_archer',
        name: 'Goblin Archer',
        role: 'Enemy Skirmisher',
        initiative: 11,
        initiativeBonus: 2,
        hp: 14,
        maxHp: 18,
        ac: 15,
        speed: 30,
        team: CombatTeam.enemy,
        portraitAsset: 'assets/images/races/goblin.png',
        conditions: [],
      ),
    ];
  }

  Combatant _combatantFromEngineCombatant(
    encounter_models.Combatant combatant,
  ) {
    final team = switch (combatant.team) {
      encounter_models.CombatantTeam.party => CombatTeam.party,
      encounter_models.CombatantTeam.enemy => CombatTeam.enemy,
      encounter_models.CombatantTeam.neutral => CombatTeam.enemy,
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

    return Combatant(
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
      resourceMaximums: _stringIntMapFromDynamic(
        combatant.metadata['resourceMaximums'],
      ),
      metadata: Map<String, dynamic>.from(combatant.metadata),
      conditions: conditions.take(9).toList(growable: false),
    );
  }

  CombatAction _combatActionFromPreparedAction(
    encounter_models.PreparedCombatAction action,
  ) {
    final source = action.metadata['source']?.toString() ?? '';
    final grantsAction = _preparedActionGrantsAction(action);
    final criticalDamageFormula =
        action.metadata['criticalDamageFormula']?.toString();
    final damageFormula = action.damageFormula ?? action.healingFormula;
    final damageType = _preparedActionDamageType(action);

    return CombatAction(
      id: action.id,
      name: action.name,
      type: _actionTypeLabel(action),
      timing: grantsAction ? 'Free' : _timingLabel(action.timing),
      attackFormula: action.attackFormula,
      saveAbility: action.saveAbility,
      saveDc: action.saveDc,
      damageFormula: damageFormula,
      damageType: damageType,
      critFormula: criticalDamageFormula == null ||
              criticalDamageFormula.trim().isEmpty ||
              criticalDamageFormula == 'null'
          ? null
          : criticalDamageFormula,
      rangeFeet: _preparedActionRangeFeet(action),
      longRangeFeet: _preparedActionLongRangeFeet(action),
      areaShape: action.metadata['areaShape']?.toString() ?? '',
      areaFeet: _intFromDynamic(action.metadata['areaFeet']) ?? 0,
      criticalThreshold:
          _intFromDynamic(action.metadata['criticalThreshold']) ?? 20,
      tags: action.tags,
      icon: _actionIcon(action, source),
      accentKind: _actionAccentKind(action, source),
      resourceKey: action.resourceKey,
      resourceCost: action.resourceCost,
      targetsSelf:
          action.rollKind == encounter_models.CombatActionRollKind.resource ||
              action.metadata['targetsSelf'] == true,
      targetPolicy: action.metadata['targetPolicy']?.toString() ?? '',
      isHealing:
          action.rollKind == encounter_models.CombatActionRollKind.healing ||
              action.healingFormula != null,
      halfDamageOnSave: action.metadata['halfDamageOnSave'] == true,
      grantsAction: grantsAction,
      usesAttackAction: _preparedActionUsesAttackAction(action),
      actionAttackSlots: math.max(
        1,
        _intFromDynamic(action.metadata['attackSlotCount']) ?? 1,
      ),
      multiAttackSteps: _multiAttackStepsFromMetadata(action.metadata),
    );
  }

  String? _preparedActionDamageType(
    encounter_models.PreparedCombatAction action,
  ) {
    final metadataType = CombatDamageTypeRules.normalize(
      action.metadata['damageType']?.toString(),
    );
    if (metadataType != null) return metadataType;

    for (final tag in action.tags) {
      final tagType = CombatDamageTypeRules.normalize(tag);
      if (tagType != null) return tagType;
    }

    final descriptionType = CombatDamageTypeRules.normalize(
      action.metadata['description']?.toString(),
    );
    if (descriptionType != null) return descriptionType;
    return null;
  }

  bool _preparedActionUsesAttackAction(
    encounter_models.PreparedCombatAction action,
  ) {
    if (action.metadata['usesAttackAction'] == true) return true;
    final source = action.metadata['source']?.toString();
    return source == 'weapon' ||
        source == 'unarmed' ||
        source == 'naturalWeapon';
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
      if (action.metadata['flurryOfBlows'] == true) return 'Monk Technique';
      if (source == 'classMechanic' &&
          action.metadata['class']?.toString().toLowerCase() == 'monk') {
        return 'Monk Technique';
      }
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
    if (source == 'combatRule') return 'Core Action';
    if (source == 'classMechanic') return 'Class Feature';
    if (source == 'subclassMechanic') return 'Subclass Feature';
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

  List<MultiAttackStep> _multiAttackStepsFromMetadata(
    Map<String, dynamic> metadata,
  ) {
    final rawSteps = metadata['multiAttackSteps'];
    if (rawSteps is! List) return const [];
    final steps = <MultiAttackStep>[];
    for (final rawStep in rawSteps) {
      if (rawStep is! Map) continue;
      final name = rawStep['name']?.toString().trim() ?? '';
      final attackFormula = rawStep['attackFormula']?.toString();
      final damageFormula = rawStep['damageFormula']?.toString();
      final criticalDamageFormula =
          rawStep['criticalDamageFormula']?.toString();
      final rawTags = rawStep['tags'];
      steps.add(
        MultiAttackStep(
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
    if (source == 'combatRule') {
      final text = '${action.name} ${action.tags.join(' ')}'.toLowerCase();
      if (text.contains('dash')) return Icons.directions_run_outlined;
      if (text.contains('dodge')) return Icons.shield_outlined;
      if (text.contains('disengage')) return Icons.route_outlined;
      return Icons.touch_app_outlined;
    }
    if (source == 'classMechanic' || source == 'subclassMechanic') {
      final text = '${action.name} ${action.tags.join(' ')}'.toLowerCase();
      if (text.contains('rage')) return Icons.local_fire_department_outlined;
      if (text.contains('inspiration')) return Icons.music_note_outlined;
      if (text.contains('smite')) return Icons.bolt_outlined;
      if (text.contains('sneak')) return Icons.visibility_off_outlined;
      if (text.contains('second wind') || text.contains('lay on hands')) {
        return Icons.favorite_border;
      }
      if (text.contains('wild shape')) return Icons.change_circle_outlined;
      if (text.contains('channel')) return Icons.flare_outlined;
      if (text.contains('flash')) return Icons.psychology_alt_outlined;
      return Icons.stars_outlined;
    }
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

  CombatAccentKind _actionAccentKind(
    encounter_models.PreparedCombatAction action,
    String source,
  ) {
    if (action.metadata['combatEffect'] == 'actionSurge') {
      return CombatAccentKind.info;
    }
    if (action.metadata['multiattack'] == true) {
      return source == 'monster'
          ? CombatAccentKind.action
          : CombatAccentKind.info;
    }
    if (action.rollKind == encounter_models.CombatActionRollKind.healing ||
        action.healingFormula != null) {
      return CombatAccentKind.support;
    }
    if (source == 'spell' || source == 'spellcasting') {
      return CombatAccentKind.magic;
    }
    if (source == 'unarmed' || source == 'naturalWeapon') {
      return CombatAccentKind.action;
    }
    if (source == 'weapon') {
      return action.tags.any((tag) => tag.toLowerCase() == 'ranged')
          ? CombatAccentKind.read
          : CombatAccentKind.action;
    }
    if (source == 'combatRule') return CombatAccentKind.info;
    if (source == 'classMechanic' || source == 'subclassMechanic') {
      final text = '${action.name} ${action.tags.join(' ')}'.toLowerCase();
      if (text.contains('smite') || text.contains('channel')) {
        return CombatAccentKind.magic;
      }
      if (text.contains('second wind') ||
          text.contains('lay on hands') ||
          text.contains('inspiration')) {
        return CombatAccentKind.support;
      }
      return CombatAccentKind.info;
    }
    if (source == 'resource') return CombatAccentKind.support;
    if (source == 'monster') {
      return action.tags.any((tag) => tag.toLowerCase() == 'ranged')
          ? CombatAccentKind.read
          : CombatAccentKind.action;
    }
    if (source == 'monsterFeature') return CombatAccentKind.support;
    if (source == 'customMonster') {
      if (action.timing == encounter_models.CombatActionTiming.passive) {
        return CombatAccentKind.support;
      }
      return action.tags.any((tag) => tag.toLowerCase() == 'ranged')
          ? CombatAccentKind.read
          : CombatAccentKind.action;
    }
    return CombatAccentKind.info;
  }

  int? _preparedActionRangeFeet(encounter_models.PreparedCombatAction action) {
    final metadataRange = _intFromDynamic(action.metadata['rangeFeet']) ??
        _intFromDynamic(action.metadata['range']);
    if (metadataRange != null && metadataRange > 0) return metadataRange;
    return _rangeFeetFromActionText(
      name: action.name,
      type: _actionTypeLabel(action),
      tags: action.tags,
      source: action.metadata['source']?.toString(),
      isSelf: action.metadata['targetsSelf'] == true ||
          action.rollKind == encounter_models.CombatActionRollKind.resource,
      isHealing:
          action.rollKind == encounter_models.CombatActionRollKind.healing ||
              action.healingFormula != null,
      hasSavingThrow: action.saveAbility != null,
      hasAttack: action.attackFormula != null,
      hasDamage: action.damageFormula != null || action.healingFormula != null,
    );
  }

  int? _preparedActionLongRangeFeet(
    encounter_models.PreparedCombatAction action,
  ) {
    final metadataRange = _intFromDynamic(action.metadata['longRangeFeet']) ??
        _intFromDynamic(action.metadata['longRange']);
    if (metadataRange != null && metadataRange > 0) return metadataRange;
    return _longRangeFeetFromActionText(
      name: action.name,
      type: _actionTypeLabel(action),
      tags: action.tags,
      source: action.metadata['source']?.toString(),
      isSelf: action.metadata['targetsSelf'] == true ||
          action.rollKind == encounter_models.CombatActionRollKind.resource,
    );
  }

  int? _intFromDynamic(dynamic value) {
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  int? _rangeFeetFromActionText({
    required String name,
    required String type,
    required List<String> tags,
    required String? source,
    required bool isSelf,
    required bool isHealing,
    required bool hasSavingThrow,
    required bool hasAttack,
    required bool hasDamage,
  }) {
    if (isSelf) return 0;
    final text = '$name $type ${tags.join(' ')} ${source ?? ''}'.toLowerCase();
    if (text.contains('self')) return 0;
    if (text.contains('touch')) return 5;

    final slashRange = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);
    if (slashRange != null) {
      return int.tryParse(slashRange.group(1) ?? '');
    }

    final explicitRange =
        RegExp(r'(\d+)\s*(?:ft|feet|foot|pies|pie)').firstMatch(text);
    if (explicitRange != null) {
      return int.tryParse(explicitRange.group(1) ?? '');
    }

    if (text.contains('melee') ||
        text.contains('unarmed') ||
        text.contains('claw') ||
        text.contains('bite') ||
        text.contains('sword') ||
        text.contains('blade')) {
      return 5;
    }
    if (text.contains('spell attack')) return 120;
    if (text.contains('shortbow')) return 80;
    if (text.contains('longbow')) return 150;
    if (text.contains('ranged') || text.contains('bow')) return 60;
    if (source == 'spell' || source == 'spellcasting') {
      if (isHealing) return 60;
      if (hasSavingThrow || hasDamage || hasAttack) return 60;
    }
    if (hasAttack || hasDamage || hasSavingThrow) return 5;
    return null;
  }

  int? _longRangeFeetFromActionText({
    required String name,
    required String type,
    required List<String> tags,
    required String? source,
    required bool isSelf,
  }) {
    if (isSelf) return null;
    final text = '$name $type ${tags.join(' ')} ${source ?? ''}'.toLowerCase();
    final slashRange = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);
    if (slashRange != null) {
      return int.tryParse(slashRange.group(2) ?? '');
    }
    if (text.contains('shortbow')) return 320;
    if (text.contains('longbow')) return 600;
    if (text.contains('light crossbow')) return 320;
    if (text.contains('heavy crossbow')) return 400;
    if (text.contains('hand crossbow')) return 120;
    if (text.contains('dart')) return 60;
    if (text.contains('sling')) return 120;
    return null;
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

  int _findDefaultTargetIndex(int activeIndex, [List<Combatant>? source]) {
    final list = source ?? _combatants;
    if (list.isEmpty) return 0;
    final safeActiveIndex = activeIndex.clamp(0, list.length - 1).toInt();

    final hostileTarget = _firstHostileTargetIndex(safeActiveIndex, list);
    if (hostileTarget != null) return hostileTarget;
    return safeActiveIndex;
  }

  String _attackOutcome(
    DiceRollResult result,
    Combatant target,
    CombatAction action,
  ) {
    if (result.isCriticalMiss) return 'automatic miss';
    final naturalD20 = _naturalD20(result);
    final threshold = action.criticalThreshold.clamp(2, 20).toInt();
    if (naturalD20 != null && naturalD20 >= threshold) return 'critical hit';
    if (result.isCriticalHit) return 'critical hit';
    return result.total >= target.ac ? 'hit' : 'miss';
  }

  int? _naturalD20(DiceRollResult result) {
    if (result.selectedD20 != null) return result.selectedD20;
    for (final term in result.terms) {
      if (term.sides == 20 && term.rolls.isNotEmpty) return term.rolls.first;
    }
    if (result.sides == 20 && result.rolls.isNotEmpty) {
      return result.rolls.first;
    }
    return null;
  }

  String _savingThrowFormulaForTarget(Combatant target, String ability) {
    return _formatRollFormula(
      'd20',
      _savingThrowBonusForTarget(target, ability),
    );
  }

  int _savingThrowBonusForTarget(Combatant target, String ability) {
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

  bool _savingThrowHasAdvantage(
    Combatant target,
    String ability, {
    CombatAction? sourceAction,
  }) {
    final normalizedAbility = ability.trim().toUpperCase();
    if (normalizedAbility == 'STR' &&
        _combatantHasCondition(target, 'Raging')) {
      return true;
    }

    final engineCombatant = _encounter?.combatantById(target.id);
    for (final effect in engineCombatant?.effects ?? const []) {
      final mechanics = effect.mechanics;
      if (_mechanicMatchesAbility(
        mechanics['savingThrowAdvantage'] ??
            mechanics['advantageOnSavingThrow'] ??
            mechanics['advantageOnSavingThrows'],
        normalizedAbility,
      )) {
        return true;
      }
    }

    final metadata = engineCombatant?.metadata;
    if (_mechanicMatchesAbility(
      metadata?['savingThrowAdvantages'],
      normalizedAbility,
    )) {
      return true;
    }

    final sourceText =
        '${sourceAction?.name ?? ''} ${sourceAction?.type ?? ''} ${sourceAction?.tags.join(' ') ?? ''}'
            .toLowerCase();
    final isSpellOrMagic =
        sourceText.contains('spell') || sourceText.contains('magic');
    final rawTraits = metadata?['specialAbilities'];
    if (isSpellOrMagic && rawTraits is Iterable) {
      for (final trait in rawTraits) {
        final text = trait.toString().toLowerCase();
        if (text.contains('magic resistance') &&
            text.contains('advantage on saving throws')) {
          return true;
        }
      }
    }

    return false;
  }

  bool _savingThrowHasDisadvantage(
    Combatant target,
    String ability, {
    CombatAction? sourceAction,
  }) {
    final normalizedAbility = ability.trim().toUpperCase();
    if (normalizedAbility == 'DEX' &&
        _combatantHasCondition(target, 'Restrained')) {
      return true;
    }
    if ((normalizedAbility == 'STR' || normalizedAbility == 'DEX') &&
        (_combatantHasCondition(target, 'Paralyzed') ||
            _combatantHasCondition(target, 'Petrified') ||
            _combatantHasCondition(target, 'Stunned') ||
            _combatantHasCondition(target, 'Unconscious'))) {
      return true;
    }

    final engineCombatant = _encounter?.combatantById(target.id);
    for (final effect in engineCombatant?.effects ?? const []) {
      final mechanics = effect.mechanics;
      if (_mechanicMatchesAbility(
        mechanics['savingThrowDisadvantage'] ??
            mechanics['disadvantageOnSavingThrow'] ??
            mechanics['disadvantageOnSavingThrows'],
        normalizedAbility,
      )) {
        return true;
      }
    }

    final metadata = engineCombatant?.metadata;
    return _mechanicMatchesAbility(
      metadata?['savingThrowDisadvantages'],
      normalizedAbility,
    );
  }

  bool _mechanicMatchesAbility(Object? raw, String normalizedAbility) {
    if (raw == null) return false;
    if (raw is Map) {
      final value = raw[normalizedAbility] ??
          raw[normalizedAbility.toLowerCase()] ??
          raw['ALL'] ??
          raw['all'];
      if (value is bool) return value;
      if (value != null) {
        return _mechanicMatchesAbility(value, normalizedAbility);
      }
      return false;
    }
    if (raw is Iterable) {
      return raw
          .any((item) => _mechanicMatchesAbility(item, normalizedAbility));
    }
    final text = raw.toString().trim().toUpperCase();
    return text == 'ALL' || text == normalizedAbility;
  }

  String _actionExecutionKey(CombatAction action) {
    return _actionCardKey(action);
  }
}

int? _intFromDynamicMap(Object? raw, String key) {
  if (raw is! Map) return null;
  final value = raw[key] ?? raw[key.toUpperCase()] ?? raw[key.toLowerCase()];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

Map<String, int> _stringIntMapFromDynamic(Object? raw) {
  if (raw is! Map) return const {};
  final result = <String, int>{};
  for (final entry in raw.entries) {
    final key = entry.key?.toString().trim() ?? '';
    if (key.isEmpty) continue;
    final value = entry.value;
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null) continue;
    result[key] = parsed;
  }
  return result;
}

String _actionCardKey(CombatAction action) {
  if (action.id.isNotEmpty) return action.id;
  return '${action.timing}|${action.type}|${action.name}';
}

bool _actionLacksResource(
  CombatAction action,
  Map<String, int> resourcePool,
) {
  final key = action.resourceKey;
  if (key == null || action.resourceCost <= 0) return false;
  return (resourcePool[key] ?? 0) < action.resourceCost;
}

int? _actionResourceRemaining(
  CombatAction action,
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

String? _classKitResourceKey(
  List<CombatAction> actions,
  Map<String, int> resourcePool,
) {
  final actionKeys = actions
      .map((action) => action.resourceKey)
      .whereType<String>()
      .where((key) => key.trim().isNotEmpty)
      .toSet();
  final knownKeys = {...resourcePool.keys, ...actionKeys};
  final priority = [
    _resourceKeyWhere(knownKeys, _isKiResourceKey),
    _resourceKeyWhere(knownKeys, _isBardicResourceKey),
    _resourceKeyWhere(knownKeys, _isSuperiorityResourceKey),
    _resourceKeyWhere(knownKeys, _isSorceryResourceKey),
  ];
  for (final key in priority) {
    if (key != null &&
        actions.any(
            (action) => action.resourceKey == key && action.resourceCost > 0)) {
      return key;
    }
  }
  return null;
}

String? _resourceKeyWhere(
  Iterable<String> keys,
  bool Function(String normalizedKey) test,
) {
  for (final key in keys) {
    if (test(_rulesLabelText(key))) return key;
  }
  return null;
}

bool _isKiResourceKey(String text) {
  return text.contains('ki') ||
      text.contains('focus') ||
      text.contains('punto de enfoque') ||
      text.contains('puntos de enfoque');
}

bool _isBardicResourceKey(String text) {
  return text.contains('bardic') || text.contains('inspiracion bardica');
}

bool _isSuperiorityResourceKey(String text) {
  return text.contains('superiority') || text.contains('superioridad');
}

bool _isSorceryResourceKey(String text) {
  return text.contains('sorcery') || text.contains('hechiceria');
}

String _classKitTitle(String resourceKey) {
  final text = _rulesLabelText(resourceKey);
  if (_isKiResourceKey(text)) return 'Monk Focus';
  if (_isBardicResourceKey(text)) return 'Bardic Inspiration';
  if (_isSuperiorityResourceKey(text)) return 'Combat Superiority';
  if (_isSorceryResourceKey(text)) return 'Sorcery Points';
  return _readableActionResourceName(resourceKey);
}

String _classKitShortLabel(String resourceKey) {
  final text = _rulesLabelText(resourceKey);
  if (_isKiResourceKey(text)) return 'Focus';
  if (_isBardicResourceKey(text)) return 'Insp';
  if (_isSuperiorityResourceKey(text)) return 'Dice';
  if (_isSorceryResourceKey(text)) return 'SP';
  return 'left';
}

IconData _classKitIcon(String resourceKey) {
  final text = _rulesLabelText(resourceKey);
  if (_isKiResourceKey(text)) return Icons.self_improvement_rounded;
  if (_isBardicResourceKey(text)) return Icons.music_note_rounded;
  if (_isSuperiorityResourceKey(text)) return Icons.military_tech_outlined;
  if (_isSorceryResourceKey(text)) return Icons.blur_on_outlined;
  return Icons.battery_charging_full_outlined;
}

Color _classKitAccent(String resourceKey, StitchThemeTokens tokens) {
  final text = _rulesLabelText(resourceKey);
  if (_isKiResourceKey(text)) return tokens.accentInfo;
  if (_isBardicResourceKey(text)) return tokens.accentMagic;
  if (_isSuperiorityResourceKey(text)) return tokens.accentAction;
  if (_isSorceryResourceKey(text)) return tokens.accentMagic;
  return tokens.accentRead;
}

ClassCombatVisualIdentity? _classCombatVisualIdentityForActions({
  required List<CombatAction> actions,
  required Map<String, int> resourcePool,
}) {
  final resourceKey = _classKitResourceKey(actions, resourcePool) ??
      _resourceKeyWhere(resourcePool.keys, _isKiResourceKey);
  final actionText = _rulesLabelText(
    actions
        .map((action) =>
            '${action.name} ${action.type} ${action.tags.join(' ')} ${action.resourceKey ?? ''}')
        .join(' '),
  );

  if ((resourceKey != null && _isKiResourceKey(_rulesLabelText(resourceKey))) ||
      actionText.contains('monk') ||
      actionText.contains('monje') ||
      actionText.contains('martial arts')) {
    return _monkCombatVisualIdentity(
      actions: actions,
      resourceKey: resourceKey ?? 'ki',
      maxKi: resourceKey == null ? 0 : resourcePool[resourceKey] ?? 0,
    );
  }

  return null;
}

ClassCombatVisualIdentity _monkCombatVisualIdentity({
  required List<CombatAction> actions,
  required String resourceKey,
  required int maxKi,
  MonkSubclassCombatProfile? subclassProfile,
}) {
  final profile = subclassProfile ??
      const MonkSubclassCombatProfile(
        kind: MonkSubclassCombatKind.none,
        name: '',
        shortName: '',
        themeLabel: 'Monk base',
      );
  final actionText = _rulesLabelText(
    actions
        .map((action) => '${action.name} ${action.tags.join(' ')}')
        .join(' '),
  );
  final hasMartialArts = actionText.contains('martial arts') ||
      actionText.contains('artes marciales') ||
      actionText.contains('unarmed strike');
  final hasKiDiscipline = maxKi > 0 ||
      actionText.contains('flurry of blows') ||
      actionText.contains('rafaga') ||
      actionText.contains('step of the wind');

  return ClassCombatVisualIdentity(
    classKey: 'monk',
    title: 'Monje',
    subtitle: profile.hasSubclass
        ? '${profile.shortName} - ${profile.themeLabel}'
        : 'Disciplina fisica y ritmo Ki',
    resourceKey: resourceKey,
    resourceLabel: 'Ki',
    icon: Icons.self_improvement_rounded,
    passiveTraits: [
      if (profile.hasSubclass)
        ClassPassiveTrait(
          label: profile.shortName,
          detail: profile.name,
          icon: Icons.spa_outlined,
        ),
      if (hasMartialArts)
        const ClassPassiveTrait(
          label: 'Martial Arts',
          detail: 'Golpes sin armas y bonus strike tras atacar.',
          icon: Icons.back_hand_outlined,
        ),
      const ClassPassiveTrait(
        label: 'Unarmored Defense',
        detail: 'AC sin armadura: DES + SAB.',
        icon: Icons.shield_outlined,
      ),
      if (hasKiDiscipline)
        const ClassPassiveTrait(
          label: 'Unarmored Movement',
          detail: 'Movimiento extra mientras no usa armadura.',
          icon: Icons.directions_run_rounded,
        ),
      ..._monkSubclassPassiveTraits(profile),
    ],
  );
}

List<ClassPassiveTrait> _monkSubclassPassiveTraits(
  MonkSubclassCombatProfile profile,
) {
  return profile.passiveReferences.take(2).map((feature) {
    return ClassPassiveTrait(
      label: feature.name,
      detail: feature.detail.isEmpty ? profile.name : feature.detail,
      icon: Icons.auto_stories_outlined,
    );
  }).toList(growable: false);
}

Color _classCombatVisualAccent(
  ClassCombatVisualIdentity identity,
  StitchThemeTokens tokens,
) {
  switch (identity.classKey) {
    case 'monk':
      return tokens.accentInfo;
    default:
      return tokens.accentRead;
  }
}

String _compactClassKitActionLabel(CombatAction action) {
  final text = _rulesLabelText(action.name);
  if (text.contains('flurry of blows') || text.contains('rafaga')) {
    return 'Flurry';
  }
  if (text.contains('patient defense') || text.contains('defensa paciente')) {
    return 'Patient';
  }
  if (text.contains('step of the wind') || text.contains('paso del viento')) {
    if (text.contains('disengage')) return 'Step: Disengage';
    return 'Step: Dash';
  }
  if (text.contains('stunning strike')) return 'Stun';
  return action.name;
}

int _classKitActionPriority(
  CombatAction action, {
  required bool hasPendingOnHitTrigger,
}) {
  final text = _rulesLabelText('${action.name} ${action.tags.join(' ')}');
  if (hasPendingOnHitTrigger && _actionIsOnHitOption(action)) return 0;
  if (text.contains('flurry of blows') || text.contains('rafaga')) return 1;
  if (text.contains('patient defense') || text.contains('defensa paciente')) {
    return 2;
  }
  if (text.contains('step of the wind') || text.contains('paso del viento')) {
    return 3;
  }
  return 4;
}

void _sortActionsForTurnFlow(
  List<CombatAction> actions, {
  required String selectedTiming,
  required Set<String> pendingDamageActions,
  required Map<String, int> resourcePool,
}) {
  actions.sort((a, b) {
    final priorityA = _turnFlowActionPriority(
      a,
      selectedTiming: selectedTiming,
      pendingDamageActions: pendingDamageActions,
      resourcePool: resourcePool,
    );
    final priorityB = _turnFlowActionPriority(
      b,
      selectedTiming: selectedTiming,
      pendingDamageActions: pendingDamageActions,
      resourcePool: resourcePool,
    );
    if (priorityA != priorityB) return priorityA.compareTo(priorityB);
    return a.name.compareTo(b.name);
  });
}

int _turnFlowActionPriority(
  CombatAction action, {
  required String selectedTiming,
  required Set<String> pendingDamageActions,
  required Map<String, int> resourcePool,
}) {
  final key = _actionCardKey(action);
  final text = _rulesLabelText(
    '${action.name} ${action.type} ${action.tags.join(' ')}',
  );
  if (pendingDamageActions.contains(key)) return 0;
  if (_actionLacksResource(action, resourcePool)) return 90;
  if (selectedTiming == 'Free' && _actionIsOnHitOption(action)) return 1;
  if (text.contains('flurry of blows') || text.contains('rafaga de golpes')) {
    return 2;
  }
  if (text.contains('martial arts') && text.contains('bonus')) return 3;
  if (text.contains('patient defense') || text.contains('defensa paciente')) {
    return 4;
  }
  if (text.contains('step of the wind') || text.contains('paso del viento')) {
    return 5;
  }
  if (action.timing == 'Action' && action.usesAttackAction) return 10;
  if (action.targetsSelf) return 60;
  return 30;
}

List<CombatAction> _techniqueRailActions({
  required List<CombatAction> actions,
  required Map<String, int> resourcePool,
  required Set<String> pendingDamageActions,
  required bool hasTakenAttackActionThisTurn,
}) {
  final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
    actions,
    pendingDamageActions,
  );
  final candidates = actions.where((action) {
    if (!_actionBelongsInTechniqueRail(action)) return false;
    if (_actionIsFlurryOfBlows(action)) return false;
    if (_actionIsMartialArtsBonusStrike(action)) return false;
    if (_actionIsOnHitOption(action) && !hasPendingOnHitTrigger) return false;
    return true;
  }).toList(growable: false);
  _sortActionsForTurnFlow(
    candidates,
    selectedTiming: 'Action',
    pendingDamageActions: pendingDamageActions,
    resourcePool: resourcePool,
  );
  candidates.sort((a, b) {
    final priorityA = _techniqueRailPriority(
      a,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
      hasPendingOnHitTrigger: hasPendingOnHitTrigger,
    );
    final priorityB = _techniqueRailPriority(
      b,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
      hasPendingOnHitTrigger: hasPendingOnHitTrigger,
    );
    if (priorityA != priorityB) return priorityA.compareTo(priorityB);
    return a.name.compareTo(b.name);
  });
  return candidates.take(6).toList(growable: false);
}

bool _actionBelongsInTechniqueRail(CombatAction action) {
  final text = _rulesLabelText(
    '${action.name} ${action.type} ${action.tags.join(' ')} ${action.resourceKey ?? ''}',
  );
  if (text.contains('martial arts') && text.contains('bonus')) return true;
  if (_actionIsOnHitOption(action)) return true;
  if (text.contains('monk tradition') ||
      text.contains('monk discipline') ||
      (text.contains('monk') && text.contains('subclass'))) {
    return true;
  }
  if (text.contains('monk') && text.contains('ki')) return true;
  final resourceKey = action.resourceKey;
  return resourceKey != null && _isKiResourceKey(_rulesLabelText(resourceKey));
}

int _techniqueRailPriority(
  CombatAction action, {
  required bool hasTakenAttackActionThisTurn,
  required bool hasPendingOnHitTrigger,
}) {
  final text = _rulesLabelText('${action.name} ${action.tags.join(' ')}');
  if (hasPendingOnHitTrigger && _actionIsOnHitOption(action)) return 0;
  if (hasTakenAttackActionThisTurn &&
      (text.contains('flurry of blows') || text.contains('rafaga de golpes'))) {
    return 1;
  }
  if (hasTakenAttackActionThisTurn && text.contains('martial arts')) return 2;
  if (text.contains('patient defense') || text.contains('defensa paciente')) {
    return 3;
  }
  if (text.contains('step of the wind') || text.contains('paso del viento')) {
    return 4;
  }
  if (text.contains('monk tradition') ||
      text.contains('monk discipline') ||
      (text.contains('monk') && text.contains('subclass'))) {
    return 5;
  }
  return 8;
}

String? _techniqueActionBlockedReason({
  required List<CombatAction> actions,
  required CombatAction action,
  required Map<String, int> resourcePool,
  required Set<String> spentTimings,
  required Set<String> pendingDamageActions,
  required String? activeMultiAttackActionKey,
  required bool hasTakenAttackActionThisTurn,
}) {
  final isActiveMultiAttack =
      activeMultiAttackActionKey == _actionCardKey(action);
  if (isActiveMultiAttack) return null;

  final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
    actions,
    pendingDamageActions,
  );
  if (_actionRequiresAttackActionLabel(action) &&
      !hasTakenAttackActionThisTurn) {
    return 'Primero resuelve una Attack Action.';
  }
  if (_actionIsOnHitOption(action) && !hasPendingOnHitTrigger) {
    return 'Disponible despues de impactar.';
  }
  if (_actionLacksResource(action, resourcePool)) {
    return 'No quedan recursos suficientes.';
  }
  if (spentTimings.contains(action.timing)) {
    return action.timing == 'Bonus Action'
        ? 'La Bonus Action ya fue usada.'
        : '${action.timing} ya fue usada.';
  }
  return null;
}

bool _actionRequiresAttackActionLabel(CombatAction action) {
  final text =
      _rulesLabelText('${action.name} ${action.type} ${action.tags.join(' ')}');
  return text.contains('requires attack action') ||
      text.contains('flurry of blows') ||
      text.contains('rafaga de golpes') ||
      text.contains('martial arts');
}

String? _combatantMonkSubclassName(Combatant combatant) {
  final direct = combatant.metadata['monkSubclass']?.toString().trim();
  if (direct != null && direct.isNotEmpty) return direct;

  final subclasses = combatant.metadata['subclasses'];
  if (subclasses is Map) {
    for (final entry in subclasses.entries) {
      final className = _rulesLabelText(entry.key.toString());
      if (!className.contains('monk') && !className.contains('monje')) {
        continue;
      }
      final subclass = entry.value?.toString().trim();
      if (subclass != null && subclass.isNotEmpty) return subclass;
    }
  }

  return null;
}

MonkCombatFlowState? _monkCombatFlowState({
  required Combatant activeCombatant,
  required List<CombatAction> actions,
  required Map<String, int> resourcePool,
  required Set<String> spentTimings,
  required Set<String> pendingDamageActions,
  required String? activeMultiAttackActionKey,
  required int activeMultiAttackStepIndex,
  required List<PendingCombatAttack> activeMultiAttackPendingAttacks,
  required bool hasTakenAttackActionThisTurn,
  required bool martialArtsEligibleAttackThisTurn,
  required bool flurryAlreadyUsedThisTurn,
}) {
  final flurryAction = _firstOrNull(actions.where(_actionIsFlurryOfBlows));
  if (flurryAction == null) return null;
  final martialArtsAction =
      _firstOrNull(actions.where(_actionIsMartialArtsBonusStrike));
  final resourceKey = flurryAction.resourceKey ??
      _classKitResourceKey(actions, resourcePool) ??
      _resourceKeyWhere(resourcePool.keys, _isKiResourceKey);
  if (resourceKey == null) return null;
  final subclassProfile = MonkCombatKitService.profileFromMetadata(
    subclassName: _combatantMonkSubclassName(activeCombatant),
    featureEntries: activeCombatant.metadata['monkSubclassFeatures'] ??
        activeCombatant.metadata['features'],
  );

  final remaining = resourcePool[resourceKey] ?? 0;
  final maximum = activeCombatant.resourceMaximums[resourceKey] ??
      math.max(remaining, flurryAction.resourceCost);
  final actionKey = _actionCardKey(flurryAction);
  final multiAttackActive = activeMultiAttackActionKey == actionKey;
  final pendingDamage = pendingDamageActions.contains(actionKey);
  final otherPendingDamage =
      pendingDamageActions.any((pendingKey) => pendingKey != actionKey);
  final bonusActionAvailable = !spentTimings.contains(flurryAction.timing);
  final flurryAttackTotal = math.max(1, flurryAction.multiAttackSteps.length);
  final flurryAttackIndex = multiAttackActive
      ? activeMultiAttackStepIndex.clamp(0, flurryAttackTotal - 1).toInt()
      : 0;
  final remainingFlurryAttacks =
      multiAttackActive ? flurryAttackTotal - flurryAttackIndex : 0;
  final martialArtsKey =
      martialArtsAction == null ? null : _actionCardKey(martialArtsAction);
  final martialArtsActive =
      martialArtsKey != null && activeMultiAttackActionKey == martialArtsKey;
  final martialArtsPending =
      martialArtsKey != null && pendingDamageActions.contains(martialArtsKey);
  final martialArtsEnabled = martialArtsAction != null &&
      (martialArtsActive ||
          martialArtsPending ||
          (martialArtsEligibleAttackThisTurn &&
              bonusActionAvailable &&
              !otherPendingDamage));
  final comboPendingAttacks = multiAttackActive || martialArtsActive
      ? activeMultiAttackPendingAttacks
      : const <PendingCombatAttack>[];
  final openHandTechniqueAvailable = subclassProfile.hasOpenHandTechnique &&
      activeMultiAttackPendingAttacks.any(
        (attack) =>
            attack.source == PendingCombatAttackSource.flurryOfBlows &&
            attack.damagePending,
      );
  var attackActionSlots = 1;
  for (final action in actions) {
    if (action.timing != 'Action' || !action.usesAttackAction) continue;
    attackActionSlots = math.max(attackActionSlots, action.actionAttackSlots);
  }
  final resolvedAttackActionAttacks = !hasTakenAttackActionThisTurn
      ? 0
      : spentTimings.contains('Action')
          ? attackActionSlots
          : 1;

  var enabled = true;
  String status;
  String ctaLabel;
  if (martialArtsPending) {
    enabled = false;
    status = 'Hay dano pendiente de Artes Marciales.';
    ctaLabel = 'Dano MA';
  } else if (martialArtsActive) {
    enabled = false;
    status = 'Golpe de Artes Marciales activo.';
    ctaLabel = 'Bonus usada';
  } else if (pendingDamage) {
    status = 'Hay dano pendiente de Ráfaga.';
    ctaLabel = 'Resolver daño';
  } else if (multiAttackActive) {
    status = 'Rafaga activa: $remainingFlurryAttacks golpes restantes.';
    ctaLabel = 'Golpe ${flurryAttackIndex + 1}/$flurryAttackTotal';
  } else if (!hasTakenAttackActionThisTurn) {
    enabled = false;
    status = 'Primero toma la acción de Ataque.';
    ctaLabel = 'Ataca primero';
  } else if (otherPendingDamage) {
    enabled = false;
    status = 'Resuelve el dano pendiente antes del combo.';
    ctaLabel = 'Dano pendiente';
  } else if (flurryAlreadyUsedThisTurn) {
    enabled = false;
    status = 'Rafaga ya usada este turno.';
    ctaLabel = 'Rafaga usada';
  } else if (!bonusActionAvailable) {
    enabled = false;
    status = 'Ya gastaste tu Bonus Action este turno.';
    ctaLabel = 'Bonus gastada';
  } else if (remaining < flurryAction.resourceCost) {
    enabled = false;
    status = 'No quedan puntos de Ki suficientes.';
    ctaLabel = 'Sin Ki';
  } else {
    status = 'Después de atacar, puedes gastar 1 Ki para dos golpes.';
    ctaLabel = 'Gastar 1 Ki';
  }

  return MonkCombatFlowState(
    identity: _monkCombatVisualIdentity(
      actions: actions,
      resourceKey: resourceKey,
      maxKi: maximum,
      subclassProfile: subclassProfile,
    ),
    subclassProfile: subclassProfile,
    flurryAction: flurryAction,
    resourceKey: resourceKey,
    remainingKi: remaining,
    maxKi: maximum,
    attackActionSlots: attackActionSlots,
    resolvedAttackActionAttacks: resolvedAttackActionAttacks,
    martialArtsAction: martialArtsAction,
    martialArtsActive: martialArtsActive,
    martialArtsEnabled: martialArtsEnabled,
    martialArtsPendingDamage: martialArtsPending,
    flurryActive: multiAttackActive,
    flurryAttackIndex: flurryAttackIndex,
    flurryAttackTotal: flurryAttackTotal,
    remainingFlurryAttacks: remainingFlurryAttacks,
    pendingAttacks: comboPendingAttacks,
    openHandTechniqueAvailable: openHandTechniqueAvailable,
    flurryAlreadyUsedThisTurn: flurryAlreadyUsedThisTurn,
    enabled: enabled,
    pendingDamage: pendingDamage,
    status: status,
    ctaLabel: ctaLabel,
  );
}

bool _actionIsFlurryOfBlows(CombatAction action) {
  final text = _rulesLabelText('${action.name} ${action.tags.join(' ')}');
  return text.contains('flurry of blows') ||
      text.contains('rafaga de golpes') ||
      text.contains('rafaga');
}

bool _actionIsMartialArtsBonusStrike(CombatAction action) {
  final text = _rulesLabelText(
    '${action.name} ${action.type} ${action.timing} ${action.tags.join(' ')}',
  );
  return text.contains('martial arts') &&
      (text.contains('bonus') ||
          text.contains('golpe extra') ||
          text.contains('bonus unarmed'));
}

bool _actionHandledByMonkCombo(CombatAction action) {
  return _actionIsFlurryOfBlows(action) ||
      _actionIsMartialArtsBonusStrike(action);
}

String _combatModeDebugDetails({
  required List<CombatAction> actions,
  required Map<String, int> resourcePool,
  required MonkCombatFlowState? monkFlow,
}) {
  String compactList(Iterable<String> values) {
    final items = values.where((value) => value.trim().isNotEmpty).take(3);
    final text = items.join('|');
    return text.isEmpty ? 'NO' : text;
  }

  final flurryNames = compactList(
    actions.where(_actionIsFlurryOfBlows).map((action) => action.name),
  );
  final martialNames = compactList(
    actions.where(_actionIsMartialArtsBonusStrike).map((action) => action.name),
  );
  final kiKeys = compactList(
    resourcePool.keys.where((key) => _isKiResourceKey(_rulesLabelText(key))),
  );
  final monkSignals = actions.where((action) {
    final text = _rulesLabelText(
      '${action.name} ${action.type} ${action.tags.join(' ')}',
    );
    return text.contains('monk') ||
        text.contains('monje') ||
        text.contains('martial arts') ||
        text.contains('unarmed');
  }).length;

  return 'monkFlow=${monkFlow != null}; flurry=$flurryNames; martial=$martialNames; ki=$kiKeys; monkSignals=$monkSignals; actions=${actions.length}';
}

String _techniqueActionLabel(CombatAction action) {
  final text = _rulesLabelText(action.name);
  if (text.contains('martial arts')) return 'Golpe extra';
  if (text.contains('flurry of blows') || text.contains('rafaga de golpes')) {
    return 'Rafaga de golpes';
  }
  if (text.contains('stunning strike') || text.contains('golpe aturdidor')) {
    return 'Golpe aturdidor';
  }
  if (text.contains('shadow arts')) return 'Shadow Arts';
  if (text.contains('hand of healing')) return 'Hand of Healing';
  if (text.contains('hand of harm')) return 'Hand of Harm';
  if (text.contains('radiant sun bolt')) return 'Sun Bolt';
  if (text.contains('arms of the astral self')) return 'Astral Arms';
  if (text.contains('kensei')) return "Kensei's Shot";
  if (text.contains('element')) return 'Elemental';
  return _compactClassKitActionLabel(action);
}

String _techniqueActionHint(CombatAction action, String? blockedReason) {
  final text = _rulesLabelText('${action.name} ${action.tags.join(' ')}');
  if (blockedReason != null) {
    if (blockedReason.contains('Attack Action')) return 'requiere Ataque';
    if (blockedReason.contains('impactar')) return 'tras impactar';
    if (blockedReason.contains('recursos')) return 'sin recursos';
    if (blockedReason.contains('Bonus')) return 'bonus usada';
    return 'bloqueado';
  }
  if (_actionIsOnHitOption(action)) return 'TS del objetivo';
  if (text.contains('martial arts')) return 'Bonus sin Ki';
  if (text.contains('flurry of blows') || text.contains('rafaga de golpes')) {
    return 'gasta 1 Ki - 2 ataques';
  }
  if (text.contains('shadow arts')) return '2 Ki - sombras';
  if (text.contains('hand of healing')) return '1 Ki - cura';
  if (text.contains('hand of harm')) return '1 Ki - on hit';
  if (text.contains('radiant sun bolt')) return 'Ataque 30 ft';
  if (text.contains('arms of the astral self')) return '1 Ki - forma';
  if (text.contains('kensei')) return 'Bonus - disparo';
  if (text.contains('element')) {
    return action.resourceCost > 0
        ? '${action.resourceCost} Ki - disciplina'
        : 'disciplina';
  }
  if (action.resourceCost > 0) return 'gasta ${action.resourceCost} Ki';
  return 'listo';
}

String _classKitActionHint(
  CombatAction action,
  bool pendingDamage,
  bool blocked,
) {
  if (pendingDamage) return 'resolve';
  if (_actionIsOnHitOption(action)) return 'on hit';
  if (blocked) return 'locked';
  final text = _rulesLabelText('${action.name} ${action.tags.join(' ')}');
  if (text.contains('requires attack action') ||
      text.contains('flurry of blows') ||
      text.contains('rafaga')) {
    return 'after Attack';
  }
  if (action.resourceCost > 0) return 'spend ${action.resourceCost}';
  return '';
}

bool _actionVisibleInActionTiming(
  CombatAction action,
  String timing, {
  required bool hasPendingOnHitTrigger,
}) {
  if (_actionIsOnHitOption(action)) {
    return timing == 'Free' && hasPendingOnHitTrigger;
  }
  return action.timing == timing;
}

bool _actionIsOnHitOption(CombatAction action) {
  final text = _rulesLabelText(
    '${action.name} ${action.type} ${action.timing} ${action.tags.join(' ')}',
  );
  return action.timing == 'On Hit' ||
      text.contains('on hit') ||
      text.contains('when you hit') ||
      text.contains('cuando impactas') ||
      text.contains('cuando golpeas') ||
      text.contains('stunning strike') ||
      text.contains('golpe aturdidor');
}

bool _hasPendingOnHitTrigger(
  List<CombatAction> actions,
  Set<String> pendingDamageActions,
) {
  if (pendingDamageActions.isEmpty) return false;
  for (final action in actions) {
    if (!pendingDamageActions.contains(_actionCardKey(action))) continue;
    if (_actionCanTriggerOnHitOptions(action)) return true;
  }
  return false;
}

bool _actionCanTriggerOnHitOptions(CombatAction action) {
  if (action.isHealing || action.requiresSavingThrow) return false;
  if (action.attackFormula == null && !action.hasMultiAttack) return false;

  final text = _rulesLabelText(
    '${action.name} ${action.type} ${action.tags.join(' ')}',
  );
  if (text.contains('spell')) return false;
  if (text.contains('ranged') && !text.contains('melee')) return false;
  return text.contains('melee') ||
      text.contains('unarmed') ||
      text.contains('weapon') ||
      text.contains('martial arts') ||
      text.contains('natural');
}

String _rulesLabelText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('\u00e1', 'a')
      .replaceAll('\u00e9', 'e')
      .replaceAll('\u00ed', 'i')
      .replaceAll('\u00f3', 'o')
      .replaceAll('\u00fa', 'u')
      .replaceAll('\u00fc', 'u')
      .replaceAll('\u00f1', 'n')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('Ã¡', 'a')
      .replaceAll('Ã©', 'e')
      .replaceAll('Ã­', 'i')
      .replaceAll('Ã³', 'o')
      .replaceAll('Ãº', 'u')
      .replaceAll('Ã±', 'n');
}

int? _rangeFeetForActionCard(CombatAction action) {
  if (action.rangeFeet != null) return action.rangeFeet;
  if (action.targetsSelf) return 0;

  final text =
      '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
  if (text.contains('self')) return 0;
  if (text.contains('touch')) return 5;

  final slashRange = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(text);
  if (slashRange != null) {
    return int.tryParse(slashRange.group(1) ?? '');
  }

  final explicitRange =
      RegExp(r'(\d+)\s*(?:ft|feet|foot|pies|pie)').firstMatch(text);
  if (explicitRange != null) {
    return int.tryParse(explicitRange.group(1) ?? '');
  }

  if (text.contains('melee') ||
      text.contains('unarmed') ||
      text.contains('claw') ||
      text.contains('bite') ||
      text.contains('sword') ||
      text.contains('blade')) {
    return 5;
  }
  if (text.contains('spell attack')) return 120;
  if (text.contains('shortbow')) return 80;
  if (text.contains('longbow')) return 150;
  if (text.contains('ranged') || text.contains('bow')) return 60;
  if (action.accentKind == CombatAccentKind.magic &&
      (action.isHealing ||
          action.requiresSavingThrow ||
          action.damageFormula != null ||
          action.attackFormula != null ||
          action.hasMultiAttack)) {
    return 60;
  }
  if (action.attackFormula != null ||
      action.damageFormula != null ||
      action.requiresSavingThrow ||
      action.hasMultiAttack) {
    return 5;
  }
  return null;
}

class _CombatLayeredGameView extends StatelessWidget {
  final int round;
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final CombatRollFeedback? rollFeedback;
  final bool rollInFlight;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
  final String? activeMultiAttackActionKey;
  final int activeMultiAttackStepIndex;
  final List<PendingCombatAttack> activeMultiAttackPendingAttacks;
  final List<ReactionOption> reactionOptions;
  final bool hasTakenAttackActionThisTurn;
  final bool martialArtsEligibleAttackThisTurn;
  final bool flurryAlreadyUsedThisTurn;
  final CombatActionEconomySnapshot activeEconomy;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedCommandTiming;
  final CombatWorkspace workspace;
  final bool showEnemyHp;
  final List<CombatLogEntry> entries;
  final Map<String, int> resourcePool;
  final CombatRollMode rollMode;
  final bool canControlActive;
  final String controlBlockedMessage;
  final bool boardControllerActive;
  final String? boardSceneId;
  final CombatAction? focusedBattleBoardAction;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;
  final ValueChanged<int> onEditHp;
  final ValueChanged<int> onRemoveBoardToken;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final ValueChanged<CombatWorkspace> onSelectWorkspace;
  final ValueChanged<String> onSelectCommandTiming;
  final ValueChanged<CombatRollMode> onSelectRollMode;
  final void Function(int actorIndex, CombatAction action) onUseReaction;
  final ValueChanged<CombatAction> onReadyAction;
  final ValueChanged<String> onRollSavingThrow;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onControlBlocked;
  final Future<void> Function(String combatantId, int dx, int dy)
      onMoveBoardToken;

  const _CombatLayeredGameView({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.rollFeedback,
    required this.rollInFlight,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.activeMultiAttackActionKey,
    required this.activeMultiAttackStepIndex,
    required this.activeMultiAttackPendingAttacks,
    required this.reactionOptions,
    required this.hasTakenAttackActionThisTurn,
    required this.martialArtsEligibleAttackThisTurn,
    required this.flurryAlreadyUsedThisTurn,
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
    required this.boardControllerActive,
    required this.boardSceneId,
    required this.focusedBattleBoardAction,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
    required this.onEditHp,
    required this.onRemoveBoardToken,
    required this.onRemoveActiveEffect,
    required this.onSelectWorkspace,
    required this.onSelectCommandTiming,
    required this.onSelectRollMode,
    required this.onUseReaction,
    required this.onReadyAction,
    required this.onRollSavingThrow,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
    required this.onControlBlocked,
    required this.onMoveBoardToken,
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
      rollInFlight: rollInFlight,
      spentTimings: spentTimings,
      pendingDamageActions: pendingDamageActions,
      preparedActions: preparedActions,
      activeMultiAttackActionKey: activeMultiAttackActionKey,
      activeMultiAttackStepIndex: activeMultiAttackStepIndex,
      activeMultiAttackPendingAttacks: activeMultiAttackPendingAttacks,
      reactionOptions: reactionOptions,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
      martialArtsEligibleAttackThisTurn: martialArtsEligibleAttackThisTurn,
      flurryAlreadyUsedThisTurn: flurryAlreadyUsedThisTurn,
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
      boardControllerActive: boardControllerActive,
      boardSceneId: boardSceneId,
      focusedBattleBoardAction: focusedBattleBoardAction,
      onBack: onBack,
      onRequestInitiative: onRequestInitiative,
      onRollInitiative: onRollInitiative,
      onNextTurn: onNextTurn,
      onToggleDmView: onToggleDmView,
      onRunDemo: onRunDemo,
      onSelectTarget: onSelectTarget,
      onSelectFocusedCombatant: onSelectFocusedCombatant,
      onEditHp: onEditHp,
      onRemoveBoardToken: onRemoveBoardToken,
      onRemoveActiveEffect: onRemoveActiveEffect,
      onSelectWorkspace: onSelectWorkspace,
      onSelectCommandTiming: onSelectCommandTiming,
      onSelectRollMode: onSelectRollMode,
      onUseReaction: onUseReaction,
      onReadyAction: onReadyAction,
      onRollSavingThrow: onRollSavingThrow,
      onRollAction: onRollAction,
      onUseAction: onUseAction,
      onPrepareAction: onPrepareAction,
      onLaunchPreparedTurn: onLaunchPreparedTurn,
      onClearPreparedActions: onClearPreparedActions,
      onControlBlocked: onControlBlocked,
      onMoveBoardToken: onMoveBoardToken,
    );
  }
}

class _CinematicCombatDesktop extends StatelessWidget {
  final int round;
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final CombatRollFeedback? rollFeedback;
  final bool rollInFlight;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
  final String? activeMultiAttackActionKey;
  final int activeMultiAttackStepIndex;
  final List<PendingCombatAttack> activeMultiAttackPendingAttacks;
  final List<ReactionOption> reactionOptions;
  final bool hasTakenAttackActionThisTurn;
  final bool martialArtsEligibleAttackThisTurn;
  final bool flurryAlreadyUsedThisTurn;
  final CombatActionEconomySnapshot activeEconomy;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedCommandTiming;
  final CombatWorkspace workspace;
  final bool showEnemyHp;
  final List<CombatLogEntry> entries;
  final Map<String, int> resourcePool;
  final CombatRollMode rollMode;
  final bool canControlActive;
  final String controlBlockedMessage;
  final bool boardControllerActive;
  final String? boardSceneId;
  final CombatAction? focusedBattleBoardAction;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;
  final ValueChanged<int> onEditHp;
  final ValueChanged<int> onRemoveBoardToken;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final ValueChanged<CombatWorkspace> onSelectWorkspace;
  final ValueChanged<String> onSelectCommandTiming;
  final ValueChanged<CombatRollMode> onSelectRollMode;
  final void Function(int actorIndex, CombatAction action) onUseReaction;
  final ValueChanged<CombatAction> onReadyAction;
  final ValueChanged<String> onRollSavingThrow;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onControlBlocked;
  final Future<void> Function(String combatantId, int dx, int dy)
      onMoveBoardToken;

  const _CinematicCombatDesktop({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.rollFeedback,
    required this.rollInFlight,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.activeMultiAttackActionKey,
    required this.activeMultiAttackStepIndex,
    required this.activeMultiAttackPendingAttacks,
    required this.reactionOptions,
    required this.hasTakenAttackActionThisTurn,
    required this.martialArtsEligibleAttackThisTurn,
    required this.flurryAlreadyUsedThisTurn,
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
    required this.boardControllerActive,
    required this.boardSceneId,
    required this.focusedBattleBoardAction,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
    required this.onEditHp,
    required this.onRemoveBoardToken,
    required this.onRemoveActiveEffect,
    required this.onSelectWorkspace,
    required this.onSelectCommandTiming,
    required this.onSelectRollMode,
    required this.onUseReaction,
    required this.onReadyAction,
    required this.onRollSavingThrow,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
    required this.onControlBlocked,
    required this.onMoveBoardToken,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final enemies = _indexedTeam(combatants, CombatTeam.enemy);
    final party = _indexedTeam(combatants, CombatTeam.party);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1240;
          final bottomHeight = boardControllerActive
              ? math.min(
                  compact ? 322.0 : 344.0,
                  math.max(
                    compact ? 286.0 : 308.0,
                    constraints.maxHeight * 0.42,
                  ),
                )
              : math.min(
                  compact ? 278.0 : 296.0,
                  math.max(
                    compact ? 238.0 : 264.0,
                    constraints.maxHeight * 0.36,
                  ),
                );
          final stageInsets = EdgeInsets.fromLTRB(
            12,
            132,
            12,
            bottomHeight + 18,
          );

          return ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: Stack(
              children: [
                const Positioned.fill(child: CombatCinematicDungeonBackdrop()),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: boardControllerActive
                        ? _BoardLinkedControllerStage(
                            combatants: combatants,
                            activeIndex: activeIndex,
                            targetIndex: targetIndex,
                            activeCombatant: activeCombatant,
                            selectedTarget: selectedTarget,
                            actions: actions,
                            selectedTiming: selectedCommandTiming,
                            focusedAction: focusedBattleBoardAction,
                            sceneId: boardSceneId,
                            showEnemyHp: showEnemyHp,
                            canControlActive: canControlActive,
                            insets: stageInsets,
                            onSelectTarget: onSelectTarget,
                            onEditHp: onEditHp,
                            onMoveBoardToken: onMoveBoardToken,
                          )
                        : _CinematicTacticalCenterLayer(
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
                if (!boardControllerActive && rollFeedback != null)
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
                  right: 10,
                  top: 10,
                  height: 112,
                  child: CombatActiveHeader(
                    round: round,
                    combatants: combatants,
                    activeIndex: activeIndex,
                    economy: activeEconomy,
                    showEnemyHp: showEnemyHp,
                    workspace: workspace,
                    onBack: onBack,
                    onNextTurn: onNextTurn,
                    onRequestInitiative: onRequestInitiative,
                    onRollInitiative: onRollInitiative,
                    onToggleDmView: onToggleDmView,
                    onRunDemo: onRunDemo,
                    onSelectCombatant: onSelectFocusedCombatant,
                    onSelectWorkspace: onSelectWorkspace,
                  ),
                ),
                if (workspace != CombatWorkspace.turn)
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
                    combatants: combatants,
                    activeIndex: activeIndex,
                    targetIndex: targetIndex,
                    activeCombatant: activeCombatant,
                    selectedTarget: selectedTarget,
                    actions: actions,
                    spentTimings: spentTimings,
                    pendingDamageActions: pendingDamageActions,
                    preparedActions: preparedActions,
                    activeMultiAttackActionKey: activeMultiAttackActionKey,
                    activeMultiAttackStepIndex: activeMultiAttackStepIndex,
                    activeMultiAttackPendingAttacks:
                        activeMultiAttackPendingAttacks,
                    reactionOptions: reactionOptions,
                    hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
                    martialArtsEligibleAttackThisTurn:
                        martialArtsEligibleAttackThisTurn,
                    flurryAlreadyUsedThisTurn: flurryAlreadyUsedThisTurn,
                    queuedPreparedIndex: queuedPreparedIndex,
                    queuedPreparedTotal: queuedPreparedTotal,
                    queuedPreparedActionName: queuedPreparedActionName,
                    selectedTiming: selectedCommandTiming,
                    resourcePool: resourcePool,
                    rollMode: rollMode,
                    showEnemyHp: showEnemyHp,
                    canControlActive: canControlActive,
                    controlBlockedMessage: controlBlockedMessage,
                    onSelectTiming: onSelectCommandTiming,
                    onSelectTarget: onSelectTarget,
                    onSelectRollMode: onSelectRollMode,
                    onUseReaction: onUseReaction,
                    onReadyAction: onReadyAction,
                    onRollSavingThrow: onRollSavingThrow,
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

class _CinematicTurnHeaderPanel extends StatelessWidget {
  final int round;
  final Combatant activeCombatant;
  final CombatActionEconomySnapshot economy;
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
    final accent = combatTeamColor(activeCombatant.team, tokens);

    return CombatCinematicPanelFrame(
      borderColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      backgroundAlpha: 0.74,
      child: Row(
        children: [
          CombatCinematicRoundIconButton(
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
                color: CombatCinematicColors.paper,
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
                    color: CombatCinematicColors.paper,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    CombatCinematicEconomyDot(
                      icon: Icons.flash_on,
                      spent: economy.actionSpent,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    CombatCinematicEconomyDot(
                      icon: Icons.control_point_duplicate,
                      spent: economy.bonusActionSpent,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    CombatCinematicEconomyDot(
                      icon: Icons.reply_rounded,
                      spent: economy.reactionSpent,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        compactCombatantHpLabel(activeCombatant, showEnemyHp),
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
          CombatCinematicRoundIconButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Siguiente turno',
            onTap: onNextTurn,
          ),
        ],
      ),
    );
  }
}

class _CinematicObjectiveBanner extends StatelessWidget {
  final List<String> aliveEnemies;
  final Combatant selectedTarget;

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
            color: CombatCinematicColors.gold.withValues(alpha: 0.36),
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
              color: CombatCinematicColors.paper,
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
                      color:
                          CombatCinematicColors.paper.withValues(alpha: 0.58),
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
                      color: CombatCinematicColors.paper,
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
  final CombatWorkspace workspace;
  final bool showEnemyHp;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<CombatWorkspace> onSelectWorkspace;

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
    return CombatCinematicPanelFrame(
      padding: const EdgeInsets.all(4),
      borderColor: CombatCinematicColors.gold,
      child: Row(
        children: [
          CombatCinematicToolbarButton(
            icon: Icons.grid_view_outlined,
            tooltip: 'Turno',
            selected: workspace == CombatWorkspace.turn,
            onTap: () => onSelectWorkspace(CombatWorkspace.turn),
          ),
          CombatCinematicToolbarButton(
            icon: Icons.receipt_long_outlined,
            tooltip: 'Log',
            selected: workspace == CombatWorkspace.log,
            onTap: () => onSelectWorkspace(CombatWorkspace.log),
          ),
          CombatCinematicToolbarButton(
            icon: Icons.groups_2_outlined,
            tooltip: 'Resumen',
            selected: workspace == CombatWorkspace.overview,
            onTap: () => onSelectWorkspace(CombatWorkspace.overview),
          ),
          CombatCinematicToolbarButton(
            icon: showEnemyHp
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            tooltip: showEnemyHp ? 'Vista DM' : 'Vista jugador',
            onTap: onToggleDmView,
          ),
          CombatCinematicToolbarButton(
            icon: Icons.campaign_outlined,
            tooltip: 'Pedir iniciativa',
            onTap: onRequestInitiative,
          ),
          CombatCinematicToolbarButton(
            icon: Icons.casino_outlined,
            tooltip: 'Tirar iniciativa',
            onTap: onRollInitiative,
          ),
          CombatCinematicToolbarButton(
            icon: Icons.play_circle_outline,
            tooltip: 'Demo',
            onTap: onRunDemo,
          ),
        ],
      ),
    );
  }
}

class _BoardLinkedControllerStage extends StatelessWidget {
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final String selectedTiming;
  final CombatAction? focusedAction;
  final String? sceneId;
  final bool showEnemyHp;
  final bool canControlActive;
  final EdgeInsets insets;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onEditHp;
  final Future<void> Function(String combatantId, int dx, int dy)
      onMoveBoardToken;

  const _BoardLinkedControllerStage({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.selectedTiming,
    required this.focusedAction,
    required this.sceneId,
    required this.showEnemyHp,
    required this.canControlActive,
    required this.insets,
    required this.onSelectTarget,
    required this.onEditHp,
    required this.onMoveBoardToken,
  });

  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BattleBoardProvider>();
    final sceneTokens = sceneId == null
        ? <BoardToken>[]
        : boardProvider.tokens
            .where((token) => token.sceneId == sceneId)
            .toList(growable: false);
    final activeToken =
        CombatBoardTokenLookup.byRef(sceneTokens, activeCombatant.id);
    final targetToken =
        CombatBoardTokenLookup.byRef(sceneTokens, selectedTarget.id);
    final distanceFeet = activeToken == null || targetToken == null
        ? null
        : CombatBoardGeometry.distanceFeet(activeToken, targetToken);
    final hostileTargets = combatants.asMap().entries.where((entry) {
      final combatant = entry.value;
      return combatant.team != activeCombatant.team && combatant.hp > 0;
    }).toList(growable: false);
    final fallbackTargets = hostileTargets.isEmpty
        ? combatants
            .asMap()
            .entries
            .where((entry) => entry.key != activeIndex)
            .toList(growable: false)
        : hostileTargets;
    final visibleActions = actions
        .where((action) =>
            action.timing == selectedTiming &&
            !_actionHandledByMonkCombo(action))
        .toList(growable: false);
    final activeAction =
        focusedAction ?? _firstOrNull(visibleActions) ?? _firstOrNull(actions);

    return Padding(
      padding: insets,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight =
              constraints.maxWidth < 820 || constraints.maxHeight < 265;
          if (tight) {
            return Column(
              children: [
                Expanded(
                  child: _BoardLinkedTargetSelector(
                    entries: fallbackTargets,
                    activeCombatant: activeCombatant,
                    selectedTarget: selectedTarget,
                    selectedIndex: targetIndex,
                    sceneTokens: sceneTokens,
                    showEnemyHp: showEnemyHp,
                    onSelectTarget: onSelectTarget,
                    onEditHp: onEditHp,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 106,
                  child: Row(
                    children: [
                      Expanded(
                        child: _BoardLinkedMovementPanel(
                          activeCombatant: activeCombatant,
                          selectedTarget: selectedTarget,
                          activeToken: activeToken,
                          targetToken: targetToken,
                          distanceFeet: distanceFeet,
                          canControlActive: canControlActive,
                          compact: true,
                          onMoveBoardToken: onMoveBoardToken,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BoardLinkedActionFocusPanel(
                          action: activeAction,
                          distanceFeet: distanceFeet,
                          targetToken: targetToken,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: math.min(
                  330.0,
                  math.max(280.0, constraints.maxWidth * 0.25),
                ),
                child: _BoardLinkedMovementPanel(
                  activeCombatant: activeCombatant,
                  selectedTarget: selectedTarget,
                  activeToken: activeToken,
                  targetToken: targetToken,
                  distanceFeet: distanceFeet,
                  canControlActive: canControlActive,
                  onMoveBoardToken: onMoveBoardToken,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BoardLinkedTargetSelector(
                  entries: fallbackTargets,
                  activeCombatant: activeCombatant,
                  selectedTarget: selectedTarget,
                  selectedIndex: targetIndex,
                  sceneTokens: sceneTokens,
                  showEnemyHp: showEnemyHp,
                  onSelectTarget: onSelectTarget,
                  onEditHp: onEditHp,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: math.min(
                  330.0,
                  math.max(280.0, constraints.maxWidth * 0.24),
                ),
                child: _BoardLinkedActionFocusPanel(
                  action: activeAction,
                  distanceFeet: distanceFeet,
                  targetToken: targetToken,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BoardLinkedMovementPanel extends StatelessWidget {
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final BoardToken? activeToken;
  final BoardToken? targetToken;
  final int? distanceFeet;
  final bool canControlActive;
  final bool compact;
  final Future<void> Function(String combatantId, int dx, int dy)
      onMoveBoardToken;

  const _BoardLinkedMovementPanel({
    required this.activeCombatant,
    required this.selectedTarget,
    required this.activeToken,
    required this.targetToken,
    required this.distanceFeet,
    required this.canControlActive,
    required this.onMoveBoardToken,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = combatTeamColor(activeCombatant.team, tokens);
    final canMove = canControlActive &&
        activeCombatant.hp > 0 &&
        activeToken != null &&
        activeToken!.remainingMovementFeet >= 5;
    final position = activeToken == null
        ? 'Grid --'
        : 'Grid ${activeToken!.x}, ${activeToken!.y}';
    final distance = distanceFeet == null ? '-- ft' : '$distanceFeet ft';

    return CombatCinematicPanelFrame(
      borderColor: accent,
      backgroundAlpha: 0.82,
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: compact
          ? Row(
              children: [
                SizedBox(
                  width: 70,
                  child: CombatCinematicPortraitBox(
                    combatant: activeCombatant,
                    color: accent,
                    iconSize: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BoardLinkedMovementReadout(
                    activeCombatant: activeCombatant,
                    selectedTarget: selectedTarget,
                    token: activeToken,
                    position: position,
                    distance: distance,
                  ),
                ),
                CombatMovementStrip(
                  enabled: canMove,
                  onMove: (dx, dy) => unawaited(
                    onMoveBoardToken(activeCombatant.id, dx, dy),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 74,
                      height: 74,
                      child: CombatCinematicPortraitBox(
                        combatant: activeCombatant,
                        color: accent,
                        iconSize: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BoardLinkedMovementReadout(
                        activeCombatant: activeCombatant,
                        selectedTarget: selectedTarget,
                        token: activeToken,
                        position: position,
                        distance: distance,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CombatMovementBudgetBar(token: activeToken),
                const Spacer(),
                Center(
                  child: CombatMovementPad(
                    enabled: canMove,
                    onMove: (dx, dy) => unawaited(
                      onMoveBoardToken(activeCombatant.id, dx, dy),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BoardLinkedMovementReadout extends StatelessWidget {
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final BoardToken? token;
  final String position;
  final String distance;

  const _BoardLinkedMovementReadout({
    required this.activeCombatant,
    required this.selectedTarget,
    required this.token,
    required this.position,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(Icons.sports_esports_rounded,
                color: tokens.accentInfo, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                activeCombatant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CombatCinematicColors.paper,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1,
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
            CombatControllerSignalPill(
              icon: Icons.directions_run_rounded,
              label: token == null
                  ? '-- ft'
                  : '${token!.remainingMovementFeet}/${token!.speedFeet} ft',
              color: tokens.accentSuccess,
            ),
            CombatControllerSignalPill(
              icon: Icons.grid_4x4_rounded,
              label: position,
              color: tokens.accentInfo,
            ),
            CombatControllerSignalPill(
              icon: Icons.center_focus_strong_rounded,
              label: '${selectedTarget.name} $distance',
              color: targetRangeColor(token, tokens),
            ),
          ],
        ),
      ],
    );
  }

  Color targetRangeColor(BoardToken? token, StitchThemeTokens tokens) {
    if (token?.isTargetInRange == false) return tokens.accentAction;
    return tokens.accentWarning;
  }
}

class _BoardLinkedTargetSelector extends StatelessWidget {
  final List<MapEntry<int, Combatant>> entries;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final int selectedIndex;
  final List<BoardToken> sceneTokens;
  final bool showEnemyHp;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onEditHp;

  const _BoardLinkedTargetSelector({
    required this.entries,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.selectedIndex,
    required this.sceneTokens,
    required this.showEnemyHp,
    required this.onSelectTarget,
    required this.onEditHp,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return CombatCinematicPanelFrame(
      borderColor: CombatCinematicColors.gold,
      backgroundAlpha: 0.78,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.crisis_alert_outlined,
                  color: tokens.accentWarning, size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Objetivos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CombatCinematicColors.paper,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              CombatControllerSignalPill(
                icon: Icons.track_changes_rounded,
                label: selectedTarget.name,
                color: tokens.accentWarning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final combatant = entry.value;
                final token =
                    CombatBoardTokenLookup.byRef(sceneTokens, combatant.id);
                final activeToken = CombatBoardTokenLookup.byRef(
                    sceneTokens, activeCombatant.id);
                final distanceFeet = activeToken == null || token == null
                    ? null
                    : CombatBoardGeometry.distanceFeet(activeToken, token);
                return SizedBox(
                  width: 214,
                  child: _BoardLinkedTargetCard(
                    combatant: combatant,
                    token: token,
                    distanceFeet: distanceFeet,
                    selected: entry.key == selectedIndex,
                    showHp: showEnemyHp || combatant.team == CombatTeam.party,
                    onTap: () => onSelectTarget(entry.key),
                    onEditHp: () => onEditHp(entry.key),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardLinkedTargetCard extends StatelessWidget {
  final Combatant combatant;
  final BoardToken? token;
  final int? distanceFeet;
  final bool selected;
  final bool showHp;
  final VoidCallback onTap;
  final VoidCallback onEditHp;

  const _BoardLinkedTargetCard({
    required this.combatant,
    required this.token,
    required this.distanceFeet,
    required this.selected,
    required this.showHp,
    required this.onTap,
    required this.onEditHp,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = selected
        ? CombatCinematicColors.goldBright
        : combatTeamColor(combatant.team, tokens);
    final distance = distanceFeet == null ? '-- ft' : '$distanceFeet ft';
    final rangeLabel = token?.isTargetInRange == false ? 'Fuera' : 'En rango';
    final rangeColor = token?.isTargetInRange == false
        ? tokens.accentAction
        : tokens.accentSuccess;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.17)
                : Colors.black.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.74 : 0.30),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CombatCinematicPortraitBox(
                      combatant: combatant,
                      color: accent,
                      iconSize: 20,
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
                            color: CombatCinematicColors.paper,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'CA ${combatant.ac}  $distance',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CombatCinematicHpBar(
                combatant: combatant,
                showHp: showHp,
                height: 20,
                onTap: onEditHp,
              ),
              const Spacer(),
              Row(
                children: [
                  CombatControllerSignalPill(
                    icon: token?.isTargetInRange == false
                        ? Icons.block_rounded
                        : Icons.my_location_rounded,
                    label: rangeLabel,
                    color: rangeColor,
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.radio_button_checked_rounded,
                        color: accent, size: 19),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardLinkedActionFocusPanel extends StatelessWidget {
  final CombatAction? action;
  final int? distanceFeet;
  final BoardToken? targetToken;
  final bool compact;

  const _BoardLinkedActionFocusPanel({
    required this.action,
    required this.distanceFeet,
    required this.targetToken,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final resolvedAction = action;
    final actionColor = resolvedAction == null
        ? tokens.textMuted
        : _accentForKind(resolvedAction.accentKind, tokens);
    final rangeFeet =
        resolvedAction == null ? null : _rangeFeetForActionCard(resolvedAction);
    final distance = distanceFeet == null ? null : '$distanceFeet ft';
    final range = rangeFeet == null ? '-- ft' : '$rangeFeet ft';
    final inRange = targetToken?.isTargetInRange ?? true;

    return CombatCinematicPanelFrame(
      borderColor: actionColor,
      backgroundAlpha: 0.80,
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 38 : 46,
                height: compact ? 38 : 46,
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: actionColor.withValues(alpha: 0.34)),
                ),
                child: Icon(
                  resolvedAction?.icon ?? Icons.auto_awesome_outlined,
                  color: actionColor,
                  size: compact ? 20 : 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedAction?.name ?? 'Accion',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CombatCinematicColors.paper,
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      resolvedAction?.type ?? 'Sin accion seleccionada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CombatControllerSignalPill(
                icon: Icons.straighten_rounded,
                label: range,
                color: actionColor,
              ),
              CombatControllerSignalPill(
                icon: Icons.center_focus_strong_rounded,
                label: distance ?? '-- ft',
                color: inRange ? tokens.accentSuccess : tokens.accentAction,
              ),
              CombatControllerSignalPill(
                icon: inRange ? Icons.check_circle_outline : Icons.block,
                label: inRange ? 'Listo' : 'Fuera',
                color: inRange ? tokens.accentSuccess : tokens.accentAction,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CinematicTacticalCenterLayer extends StatelessWidget {
  final List<Combatant> combatants;
  final List<IndexedCombatant> party;
  final List<IndexedCombatant> enemies;
  final int activeIndex;
  final int targetIndex;
  final CombatRollFeedback? rollFeedback;
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

List<IndexedCombatant> _initiativeSortedBattleEntries(
  List<IndexedCombatant> entries, {
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
  final List<IndexedCombatant> entries;
  final int activeIndex;
  final int targetIndex;
  final CombatTeam activeTeam;
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
      (entry) => entry.combatant.team == CombatTeam.party,
    );
    final accent = partyColumn ? tokens.accentRead : tokens.accentAction;
    final aliveCount = entries.where((entry) => entry.combatant.hp > 0).length;

    return CombatCinematicPanelFrame(
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
                        color: CombatCinematicColors.paper,
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
              CombatCinematicTinyPill(
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
  final IndexedCombatant entry;
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
    final baseAccent = combatTeamColor(combatant.team, tokens);
    final accent = targeted
        ? CombatCinematicColors.goldBright
        : active
            ? tokens.accentInfo
            : baseAccent;
    final showHp = canShowCombatantHp(combatant, showEnemyHp);
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
                  child: CombatCinematicPortraitBox(
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
                                color: CombatCinematicColors.paper,
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
                          CombatCinematicTinyPill(
                            label: '${combatant.initiative}',
                            color: accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      CombatCinematicHpBar(
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
                              child: CombatCinematicTinyPill(
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
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final CombatRollFeedback? rollFeedback;
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
    final actorColor = combatTeamColor(activeCombatant.team, tokens);
    final targetColor = combatTeamColor(selectedTarget.team, tokens);
    final feedbackAccent = rollFeedback == null
        ? CombatCinematicColors.goldBright
        : _accentForKind(rollFeedback!.accentKind, tokens);
    final result = rollFeedback?.result;

    return CombatCinematicPanelFrame(
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
                        color: CombatCinematicColors.paper,
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
  final Combatant combatant;
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
    final showHp = canShowCombatantHp(combatant, showEnemyHp);

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
                CombatantArtwork(
                  combatant: combatant,
                  color: color,
                  iconSize: compact ? 34 : 42,
                ),
                Positioned(
                  left: 7,
                  top: 7,
                  child: CombatCinematicTinyPill(label: label, color: color),
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
                    color: CombatCinematicColors.paper,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                CombatCinematicHpBar(
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
  final List<Combatant> combatants;
  final List<IndexedCombatant> party;
  final List<IndexedCombatant> enemies;
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
        ? CombatTeam.party
        : combatants[activeIndex.clamp(0, combatants.length - 1).toInt()].team;

    void handleTokenTap(IndexedCombatant entry) {
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
                painter: CombatCinematicArenaFloorPainter(
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
            color: CombatCinematicColors.paper,
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
  final IndexedCombatant entry;
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
        ? CombatCinematicColors.goldBright
        : active
            ? tokens.accentInfo
            : combatTeamColor(combatant.team, tokens);
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
                  painter: CombatCinematicTargetRingPainter(
                    color: color,
                    active: active || targeted,
                    enemy: combatant.team == CombatTeam.enemy,
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
                    child: CombatantArtwork(
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
                        color: CombatCinematicColors.paper,
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

class _CinematicActionDeck extends StatelessWidget {
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
  final String? activeMultiAttackActionKey;
  final int activeMultiAttackStepIndex;
  final List<PendingCombatAttack> activeMultiAttackPendingAttacks;
  final List<ReactionOption> reactionOptions;
  final bool hasTakenAttackActionThisTurn;
  final bool martialArtsEligibleAttackThisTurn;
  final bool flurryAlreadyUsedThisTurn;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final Map<String, int> resourcePool;
  final CombatRollMode rollMode;
  final bool showEnemyHp;
  final bool canControlActive;
  final String controlBlockedMessage;
  final ValueChanged<String> onSelectTiming;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<CombatRollMode> onSelectRollMode;
  final void Function(int actorIndex, CombatAction action) onUseReaction;
  final ValueChanged<CombatAction> onReadyAction;
  final ValueChanged<String> onRollSavingThrow;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onControlBlocked;
  final VoidCallback onNextTurn;

  const _CinematicActionDeck({
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.activeMultiAttackActionKey,
    required this.activeMultiAttackStepIndex,
    required this.activeMultiAttackPendingAttacks,
    required this.reactionOptions,
    required this.hasTakenAttackActionThisTurn,
    required this.martialArtsEligibleAttackThisTurn,
    required this.flurryAlreadyUsedThisTurn,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedTiming,
    required this.resourcePool,
    required this.rollMode,
    required this.showEnemyHp,
    required this.canControlActive,
    required this.controlBlockedMessage,
    required this.onSelectTiming,
    required this.onSelectTarget,
    required this.onSelectRollMode,
    required this.onUseReaction,
    required this.onReadyAction,
    required this.onRollSavingThrow,
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
    final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
      actions,
      pendingDamageActions,
    );
    final visibleActions = actions
        .where(
          (action) =>
              _actionVisibleInActionTiming(
                action,
                selectedTiming,
                hasPendingOnHitTrigger: hasPendingOnHitTrigger,
              ) &&
              !_actionHandledByMonkCombo(action),
        )
        .toList(growable: false);
    _sortActionsForTurnFlow(
      visibleActions,
      selectedTiming: selectedTiming,
      pendingDamageActions: pendingDamageActions,
      resourcePool: resourcePool,
    );
    final prepared = preparedActions[selectedTiming];
    final activeMultiAttackAction = activeMultiAttackActionKey == null
        ? null
        : _firstOrNull(
            actions.where(
              (action) => _actionCardKey(action) == activeMultiAttackActionKey,
            ),
          );
    final featuredAction = prepared ??
        activeMultiAttackAction ??
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
        .take(8)
        .toList(growable: false);
    final handActions = [
      if (featuredAction != null) featuredAction,
      ...secondaryActions,
    ].take(9).toList(growable: false);
    final hasPrepared = preparedActions.isNotEmpty;
    final showTechniqueRail = _techniqueRailActions(
      actions: actions,
      resourcePool: resourcePool,
      pendingDamageActions: pendingDamageActions,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
    ).isNotEmpty;
    final monkFlow = _monkCombatFlowState(
      activeCombatant: activeCombatant,
      actions: actions,
      resourcePool: resourcePool,
      spentTimings: spentTimings,
      pendingDamageActions: pendingDamageActions,
      activeMultiAttackActionKey: activeMultiAttackActionKey,
      activeMultiAttackStepIndex: activeMultiAttackStepIndex,
      activeMultiAttackPendingAttacks: activeMultiAttackPendingAttacks,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
      martialArtsEligibleAttackThisTurn: martialArtsEligibleAttackThisTurn,
      flurryAlreadyUsedThisTurn: flurryAlreadyUsedThisTurn,
    );
    final debugDetail = _combatModeDebugDetails(
      actions: actions,
      resourcePool: resourcePool,
      monkFlow: monkFlow,
    );
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
            selectedTarget: selectedTarget,
            actions: actions,
            spentTimings: spentTimings,
            pendingDamageActions: pendingDamageActions,
            preparedActions: preparedActions,
            activeMultiAttackActionKey: activeMultiAttackActionKey,
            activeMultiAttackStepIndex: activeMultiAttackStepIndex,
            activeMultiAttackPendingAttacks: activeMultiAttackPendingAttacks,
            reactionOptions: reactionOptions,
            hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
            martialArtsEligibleAttackThisTurn:
                martialArtsEligibleAttackThisTurn,
            flurryAlreadyUsedThisTurn: flurryAlreadyUsedThisTurn,
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
            onReadyAction: onReadyAction,
            onRollSavingThrow: onRollSavingThrow,
            onRollAction: onRollAction,
            onUseAction: onUseAction,
            onPrepareAction: onPrepareAction,
            onClearPreparedActions: onClearPreparedActions,
            onNextTurn: onNextTurn,
          );
        }

        return CombatCinematicPanelFrame(
          borderColor: CombatCinematicColors.gold,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          backgroundAlpha: 0.78,
          child: Column(
            children: [
              CombatTargetStrip(
                combatants: combatants,
                activeIndex: activeIndex,
                targetIndex: targetIndex,
                showEnemyHp: showEnemyHp,
                onSelectTarget: onSelectTarget,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _CinematicTimingTabs(
                      actions: actions,
                      selectedTiming: selectedTiming,
                      spentTimings: spentTimings,
                      pendingDamageActions: pendingDamageActions,
                      preparedActions: preparedActions,
                      onSelectTiming: onSelectTiming,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (queuedPreparedTotal > 0)
                    CombatCinematicQueueChip(
                      index: queuedPreparedIndex,
                      total: queuedPreparedTotal,
                      name: queuedPreparedActionName,
                    ),
                ],
              ),
              if (selectedTiming == 'Reaction' &&
                  reactionOptions.isNotEmpty) ...[
                const SizedBox(height: 6),
                _CinematicReactionBar(
                  options: reactionOptions,
                  activeName: activeCombatant.name,
                  onUseReaction: onUseReaction,
                ),
              ],
              const SizedBox(height: 6),
              CombatModeDebugBanner(
                location: 'CinematicActionDeck',
                detail: debugDetail,
              ),
              if (preparedActions.isNotEmpty || featuredPending) ...[
                const SizedBox(height: 6),
                _CinematicTurnPlanStrip(
                  preparedActions: preparedActions,
                  pendingAction: featuredPending ? featuredAction : null,
                ),
              ],
              if (selectedTiming == 'Action' && monkFlow != null) ...[
                const SizedBox(height: 6),
                _MonkCombatFlowPanel(
                  state: monkFlow,
                  onRollAction: onRollAction,
                  onUseAction: onUseAction,
                ),
              ],
              if (showTechniqueRail) ...[
                const SizedBox(height: 6),
                _CinematicTechniqueRail(
                  actions: actions,
                  resourcePool: resourcePool,
                  spentTimings: spentTimings,
                  pendingDamageActions: pendingDamageActions,
                  activeMultiAttackActionKey: activeMultiAttackActionKey,
                  hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
                  onRollAction: onRollAction,
                  onUseAction: onUseAction,
                ),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: handActions.isEmpty
                    ? CombatActionListEmpty(selectedTiming: selectedTiming)
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: handActions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final action = handActions[index];
                          final multiAttackActive =
                              activeMultiAttackActionKey ==
                                  _actionCardKey(action);
                          final isSpent =
                              spentTimings.contains(action.timing) &&
                                  !multiAttackActive;
                          final isPending = pendingDamageActions.contains(
                            _actionCardKey(action),
                          );
                          return SizedBox(
                            width: index == 0 ? 302 : 252,
                            child: _CinematicFeaturedActionCard(
                              action: action,
                              activeCombatant: activeCombatant,
                              selectedTarget: selectedTarget,
                              prepared:
                                  preparedActions[action.timing] == action,
                              spent: isSpent,
                              pendingDamage: isPending,
                              blocked: _actionLacksResource(
                                action,
                                resourcePool,
                              ),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 214,
                    child: CombatCinematicFooterButton(
                      icon: Icons.hourglass_bottom_outlined,
                      label: 'Terminar turno',
                      color: CombatCinematicColors.paper,
                      onTap: onNextTurn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (hasPrepared)
                    CombatCinematicFooterButton(
                      icon: Icons.clear_all_outlined,
                      label: 'Limpiar plan',
                      color: CombatCinematicColors.goldBright,
                      onTap: onClearPreparedActions,
                      compact: true,
                    ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 154,
                    child: CombatCinematicFooterButton(
                      icon: Icons.shield_outlined,
                      label: 'TS objetivo',
                      color: CombatCinematicColors.goldBright,
                      onTap: () => showCombatSavingThrowSheet(
                        context: context,
                        target: selectedTarget,
                        actions: actions,
                        onRollSavingThrow: onRollSavingThrow,
                        onRollAction: onRollAction,
                      ),
                      compact: true,
                    ),
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
                    child: CombatCinematicConfirmButton(
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
  final Combatant activeCombatant;
  final int actionCount;
  final String message;
  final CombatRollMode rollMode;
  final ValueChanged<CombatRollMode> onSelectRollMode;
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
    final accent = combatTeamColor(activeCombatant.team, tokens);

    return CombatCinematicPanelFrame(
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
                        color: CombatCinematicColors.paper,
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
                    child: CombatCinematicPortraitBox(
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
                    child: CombatCinematicFooterButton(
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
                child: CombatCinematicFooterButton(
                  icon: Icons.hourglass_bottom_outlined,
                  label: 'Esperar turno',
                  color: CombatCinematicColors.paper,
                  onTap: onControlBlocked,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 276,
                child: CombatCinematicConfirmButton(
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
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
  final String? activeMultiAttackActionKey;
  final int activeMultiAttackStepIndex;
  final List<PendingCombatAttack> activeMultiAttackPendingAttacks;
  final List<ReactionOption> reactionOptions;
  final bool hasTakenAttackActionThisTurn;
  final bool martialArtsEligibleAttackThisTurn;
  final bool flurryAlreadyUsedThisTurn;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final Map<String, int> resourcePool;
  final CombatRollMode rollMode;
  final CombatAction? featuredAction;
  final bool featuredPending;
  final bool featuredSpent;
  final String confirmLabel;
  final VoidCallback confirmAction;
  final bool hasPrepared;
  final ValueChanged<String> onSelectTiming;
  final ValueChanged<CombatRollMode> onSelectRollMode;
  final void Function(int actorIndex, CombatAction action) onUseReaction;
  final ValueChanged<CombatAction> onReadyAction;
  final ValueChanged<String> onRollSavingThrow;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onNextTurn;

  const _CinematicActionQuickDock({
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.activeMultiAttackActionKey,
    required this.activeMultiAttackStepIndex,
    required this.activeMultiAttackPendingAttacks,
    required this.reactionOptions,
    required this.hasTakenAttackActionThisTurn,
    required this.martialArtsEligibleAttackThisTurn,
    required this.flurryAlreadyUsedThisTurn,
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
    required this.onReadyAction,
    required this.onRollSavingThrow,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onClearPreparedActions,
    required this.onNextTurn,
  });

  @override
  Widget build(BuildContext context) {
    final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
      actions,
      pendingDamageActions,
    );
    final visibleActions = actions
        .where(
          (action) =>
              _actionVisibleInActionTiming(
                action,
                selectedTiming,
                hasPendingOnHitTrigger: hasPendingOnHitTrigger,
              ) &&
              !_actionHandledByMonkCombo(action),
        )
        .toList(growable: false);
    _sortActionsForTurnFlow(
      visibleActions,
      selectedTiming: selectedTiming,
      pendingDamageActions: pendingDamageActions,
      resourcePool: resourcePool,
    );
    final handActions = [
      if (featuredAction != null) featuredAction!,
      ...visibleActions.where((action) => action != featuredAction),
    ].take(8).toList(growable: false);
    final showTechniqueRail = _techniqueRailActions(
      actions: actions,
      resourcePool: resourcePool,
      pendingDamageActions: pendingDamageActions,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
    ).isNotEmpty;
    final monkFlow = _monkCombatFlowState(
      activeCombatant: activeCombatant,
      actions: actions,
      resourcePool: resourcePool,
      spentTimings: spentTimings,
      pendingDamageActions: pendingDamageActions,
      activeMultiAttackActionKey: activeMultiAttackActionKey,
      activeMultiAttackStepIndex: activeMultiAttackStepIndex,
      activeMultiAttackPendingAttacks: activeMultiAttackPendingAttacks,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
      martialArtsEligibleAttackThisTurn: martialArtsEligibleAttackThisTurn,
      flurryAlreadyUsedThisTurn: flurryAlreadyUsedThisTurn,
    );
    return CombatCinematicPanelFrame(
      borderColor: CombatCinematicColors.gold,
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
                  pendingDamageActions: pendingDamageActions,
                  preparedActions: preparedActions,
                  onSelectTiming: onSelectTiming,
                ),
              ),
              if (queuedPreparedTotal > 0) ...[
                const SizedBox(width: 10),
                CombatCinematicQueueChip(
                  index: queuedPreparedIndex,
                  total: queuedPreparedTotal,
                  name: queuedPreparedActionName,
                ),
              ],
            ],
          ),
          if (selectedTiming == 'Reaction' && reactionOptions.isNotEmpty) ...[
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
          if (selectedTiming == 'Action' && monkFlow != null) ...[
            const SizedBox(height: 6),
            _MonkCombatFlowPanel(
              state: monkFlow,
              onRollAction: onRollAction,
              onUseAction: onUseAction,
              compact: true,
            ),
          ],
          if (showTechniqueRail) ...[
            const SizedBox(height: 6),
            _CinematicTechniqueRail(
              actions: actions,
              resourcePool: resourcePool,
              spentTimings: spentTimings,
              pendingDamageActions: pendingDamageActions,
              activeMultiAttackActionKey: activeMultiAttackActionKey,
              hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
              onRollAction: onRollAction,
              onUseAction: onUseAction,
              compact: true,
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: handActions.isEmpty
                      ? CombatActionListEmpty(selectedTiming: selectedTiming)
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: handActions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 9),
                          itemBuilder: (context, index) {
                            final action = handActions[index];
                            final key = _actionCardKey(action);
                            return SizedBox(
                              width: index == 0 ? 256 : 226,
                              child: _CinematicSmallActionCard(
                                action: action,
                                prepared:
                                    preparedActions[action.timing] == action,
                                spent: spentTimings.contains(action.timing) &&
                                    activeMultiAttackActionKey != key,
                                pendingDamage:
                                    pendingDamageActions.contains(key),
                                blocked:
                                    _actionLacksResource(action, resourcePool),
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
                const SizedBox(width: 10),
                SizedBox(
                  width: 314,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: CombatCinematicFooterButton(
                              icon: Icons.view_module_outlined,
                              label: 'Todas',
                              color: CombatCinematicColors.goldBright,
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: CombatCinematicFooterButton(
                              icon: Icons.shield_outlined,
                              label: 'TS',
                              color: CombatCinematicColors.goldBright,
                              compact: true,
                              onTap: () => showCombatSavingThrowSheet(
                                context: context,
                                target: selectedTarget,
                                actions: actions,
                                onRollSavingThrow: onRollSavingThrow,
                                onRollAction: onRollAction,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _CinematicRollModeToggle(
                        value: rollMode,
                        onChanged: onSelectRollMode,
                      ),
                    ],
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
                child: CombatCinematicFooterButton(
                  icon: Icons.hourglass_bottom_outlined,
                  label: 'Terminar turno',
                  color: CombatCinematicColors.paper,
                  onTap: onNextTurn,
                ),
              ),
              if (hasPrepared) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 168,
                  child: CombatCinematicFooterButton(
                    icon: Icons.clear_all_outlined,
                    label: 'Limpiar plan',
                    color: CombatCinematicColors.goldBright,
                    onTap: onClearPreparedActions,
                    compact: true,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: 276,
                child: CombatCinematicConfirmButton(
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
  final CombatAction? action;
  final bool pendingDamage;
  final bool spent;
  final Map<String, CombatAction> preparedActions;
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
      return const CombatActionListEmpty(selectedTiming: 'este timing');
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
              color: CombatCinematicColors.paper,
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
                    color: CombatCinematicColors.paper,
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
                color: CombatCinematicColors.paper,
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

String _cinematicQuickActionLine(CombatAction action, int? resourceRemaining) {
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

String _actionRangeText(CombatAction action) {
  final range = _rangeFeetForActionCard(action);
  if (range == null) return 'Especial';
  if (range <= 0) return 'Personal';
  return '$range ft';
}

String _actionRollText(CombatAction action) {
  if (action.attackFormula != null) return action.attackFormula!;
  if (action.requiresSavingThrow) {
    final ability = action.saveAbility ?? 'Save';
    final dc = action.saveDc == null ? '' : ' ${action.saveDc}';
    return 'TS $ability$dc';
  }
  if (action.hasMultiAttack) return '${action.multiAttackSteps.length} ataques';
  if (action.damageFormula != null) return 'Sin impacto';
  return 'Uso';
}

String _actionImpactText(CombatAction action) {
  if (action.damageFormula != null) {
    final suffix = action.isHealing ? ' cura' : ' dano';
    return '${action.damageFormula}$suffix';
  }
  if (action.hasMultiAttack) {
    final firstDamage = _firstOrNull(
      action.multiAttackSteps
          .map((step) => step.damageFormula)
          .whereType<String>(),
    );
    return firstDamage == null ? 'Variable' : '$firstDamage+';
  }
  if (action.grantsAction) return '+accion';
  return action.type;
}

String? _actionResourceText(CombatAction action, int? resourceRemaining) {
  final key = action.resourceKey;
  if (key == null || action.resourceCost <= 0) return null;
  final name = _readableActionResourceName(key);
  return '$name ${resourceRemaining ?? 0}';
}

String _actionDecisionStateText({
  required bool pendingDamage,
  required bool spent,
  required bool blocked,
}) {
  if (blocked) return 'Bloqueada';
  if (pendingDamage) return 'Resolver';
  if (spent) return 'Usada';
  return 'Lista';
}

String _actionRoleLine(CombatAction action) {
  final tags =
      action.tags.where((tag) => tag.trim().isNotEmpty).take(2).join(' / ');
  if (tags.isEmpty) return action.type;
  return '${action.type} - $tags';
}

class _CinematicTimingTabs extends StatelessWidget {
  final List<CombatAction> actions;
  final String selectedTiming;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
  final ValueChanged<String> onSelectTiming;

  const _CinematicTimingTabs({
    required this.actions,
    required this.selectedTiming,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.onSelectTiming,
  });

  @override
  Widget build(BuildContext context) {
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Free'];
    return Row(
      children: [
        for (final timing in timings) ...[
          Expanded(
            child: _CinematicTimingTab(
              timing: timing,
              selected: selectedTiming == timing,
              spent: spentTimings.contains(timing),
              prepared: preparedActions[timing] != null,
              count: _compactActionCountForTiming(
                actions,
                timing,
                pendingDamageActions: pendingDamageActions,
              ),
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
        ? CombatCinematicColors.blood
        : prepared
            ? CombatCinematicColors.goldBright
            : selected
                ? CombatCinematicColors.gold
                : CombatCinematicColors.paper.withValues(alpha: 0.48);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? CombatCinematicColors.gold.withValues(alpha: 0.15)
              : StitchCodexPalette.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(2),
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
                  color: CombatCinematicColors.paper,
                  fontFamily: StitchTypography.display,
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
                fontFamily: StitchTypography.data,
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
  final Map<String, CombatAction> preparedActions;
  final CombatAction? pendingAction;

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
                      color: CombatCinematicColors.paper,
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
  final CombatAction action;
  final Color color;
  final IconData icon;

  const _TurnPlanEntry({
    required this.label,
    required this.action,
    required this.color,
    required this.icon,
  });
}

class _MonkCombatFlowPanel extends StatelessWidget {
  final MonkCombatFlowState state;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final bool compact;

  const _MonkCombatFlowPanel({
    required this.state,
    required this.onRollAction,
    required this.onUseAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final identity = state.identity;
    final accent = _classCombatVisualAccent(identity, tokens);
    final highlighted = state.enabled ||
        state.pendingDamage ||
        state.flurryActive ||
        state.martialArtsActive;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: highlighted ? 1 : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, emphasis, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(minHeight: compact ? 96 : 116),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.12 + emphasis * 0.05),
                Colors.black.withValues(alpha: 0.28),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accent.withValues(alpha: 0.30 + emphasis * 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08 + emphasis * 0.06),
                blurRadius: 16 + emphasis * 8,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = compact || constraints.maxWidth < 620;
              final header = Row(
                children: [
                  Container(
                    width: compact ? 34 : 40,
                    height: compact ? 34 : 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Icon(
                      identity.icon,
                      color: CombatCinematicColors.paper,
                      size: compact ? 18 : 22,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          identity.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: CombatCinematicColors.paper,
                            fontSize: compact ? 12 : 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          identity.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: compact ? 8 : 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  _MonkKiPipCounter(
                    current: state.remainingKi,
                    max: state.maxKi,
                    color: accent,
                    enabled: state.enabled ||
                        state.flurryActive ||
                        state.pendingDamage,
                    compact: compact,
                  ),
                ],
              );

              final flow = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MonkAttackActionTrack(
                    slots: state.attackActionSlots,
                    resolved: state.resolvedAttackActionAttacks,
                    color: accent,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 5 : 7),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: state.pendingAttacks.isEmpty
                        ? _MonkFlowStatusLine(
                            key: ValueKey(state.status),
                            text: state.status,
                            color: accent,
                            compact: compact,
                          )
                        : _MonkPendingAttackQueue(
                            key: ValueKey(
                              state.pendingAttacks
                                  .map((attack) =>
                                      '${attack.label}:${attack.status.name}')
                                  .join('|'),
                            ),
                            attacks: state.pendingAttacks,
                            color: accent,
                            compact: compact,
                          ),
                  ),
                  if (state.openHandTechniqueAvailable) ...[
                    SizedBox(height: compact ? 5 : 7),
                    _OpenHandTechniquePrompt(
                      color: accent,
                      compact: compact,
                    ),
                  ],
                  if (identity.passiveTraits.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _ClassPassiveTraitStrip(
                      traits: identity.passiveTraits,
                      color: accent,
                      compact: true,
                    ),
                  ],
                ],
              );

              final actions = _MonkComboActionStrip(
                state: state,
                color: accent,
                compact: compact,
                onRollAction: onRollAction,
                onUseAction: onUseAction,
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    SizedBox(height: compact ? 7 : 9),
                    flow,
                    SizedBox(height: compact ? 7 : 9),
                    actions,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 9),
                        flow,
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 292, child: actions),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _MonkFlowStatusLine extends StatelessWidget {
  final String text;
  final Color color;
  final bool compact;

  const _MonkFlowStatusLine({
    super.key,
    required this.text,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timeline_rounded,
            color: color,
            size: compact ? 12 : 14,
          ),
          SizedBox(width: compact ? 5 : 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenHandTechniquePrompt extends StatelessWidget {
  final Color color;
  final bool compact;

  const _OpenHandTechniquePrompt({
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final effects = const [
      ('Prone', 'DEX save or knocked prone'),
      ('Push 15 ft', 'STR save or pushed away'),
      ('No reactions', 'Until the end of your next turn'),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.pan_tool_alt_outlined,
              color: color, size: compact ? 13 : 15),
          SizedBox(width: compact ? 5 : 7),
          Flexible(
            flex: 2,
            child: Text(
              'Open Hand Technique',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CombatCinematicColors.paper,
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < effects.length; index++) ...[
                    if (index > 0) const SizedBox(width: 5),
                    Tooltip(
                      message: effects[index].$2,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 6 : 7,
                          vertical: compact ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: color.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Text(
                          effects[index].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: compact ? 8 : 9,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonkAttackActionTrack extends StatelessWidget {
  final int slots;
  final int resolved;
  final Color color;
  final bool compact;

  const _MonkAttackActionTrack({
    required this.slots,
    required this.resolved,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final total = math.max(1, slots);
    final done = resolved.clamp(0, total).toInt();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.gavel_outlined, color: color, size: compact ? 12 : 14),
          SizedBox(width: compact ? 5 : 6),
          Text(
            'Attack Action',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: compact ? 8 : 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < total; index++) ...[
                    if (index > 0) const SizedBox(width: 5),
                    _MonkAttackSlotChip(
                      label: index == 0 ? 'Attack 1' : 'Extra ${index + 1}',
                      resolved: index < done,
                      color: color,
                      compact: compact,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonkAttackSlotChip extends StatelessWidget {
  final String label;
  final bool resolved;
  final Color color;
  final bool compact;

  const _MonkAttackSlotChip({
    required this.label,
    required this.resolved,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = resolved ? context.stitch.accentSuccess : color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 7,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: resolved ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resolved ? Icons.check_rounded : Icons.radio_button_unchecked,
            color: chipColor,
            size: compact ? 9 : 11,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: CombatCinematicColors.paper,
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonkPendingAttackQueue extends StatelessWidget {
  final List<PendingCombatAttack> attacks;
  final Color color;
  final bool compact;

  const _MonkPendingAttackQueue({
    super.key,
    required this.attacks,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 18 : 20,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attacks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final attack = attacks[index];
          final resolved = attack.resolved;
          final damagePending = attack.damagePending;
          final tokens = context.stitch;
          final sourceColor = switch (attack.source) {
            PendingCombatAttackSource.martialArts =>
              CombatCinematicColors.goldBright,
            PendingCombatAttackSource.flurryOfBlows => color,
            PendingCombatAttackSource.extraAttack => tokens.accentRead,
            PendingCombatAttackSource.attackAction => tokens.accentAction,
            PendingCombatAttackSource.multiattack => color,
          };
          final chipColor = resolved
              ? context.stitch.accentSuccess
              : damagePending
                  ? context.stitch.accentAction
                  : sourceColor;
          final sourceIcon = switch (attack.source) {
            PendingCombatAttackSource.martialArts => Icons.back_hand_outlined,
            PendingCombatAttackSource.flurryOfBlows => Icons.flash_on_rounded,
            PendingCombatAttackSource.extraAttack =>
              Icons.control_point_duplicate_outlined,
            PendingCombatAttackSource.attackAction => Icons.gavel_outlined,
            PendingCombatAttackSource.multiattack =>
              Icons.radio_button_unchecked_rounded,
          };
          final icon = resolved
              ? Icons.check_rounded
              : damagePending
                  ? Icons.auto_fix_high_outlined
                  : sourceIcon;
          return Container(
            constraints: BoxConstraints(maxWidth: compact ? 118 : 146),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 7,
              vertical: compact ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: resolved ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: chipColor.withValues(alpha: 0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: chipColor, size: compact ? 10 : 12),
                SizedBox(width: compact ? 4 : 5),
                Flexible(
                  child: Text(
                    attack.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CombatCinematicColors.paper,
                      fontSize: compact ? 8 : 9,
                      fontWeight: FontWeight.w900,
                      height: 1,
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

class _MonkComboActionStrip extends StatelessWidget {
  final MonkCombatFlowState state;
  final Color color;
  final bool compact;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;

  const _MonkComboActionStrip({
    required this.state,
    required this.color,
    required this.compact,
    required this.onRollAction,
    required this.onUseAction,
  });

  @override
  Widget build(BuildContext context) {
    final martialArtsAction = state.martialArtsAction;
    final flurryDetail = state.flurryActive
        ? '${state.remainingFlurryAttacks}/${state.flurryAttackTotal} golpes'
        : state.remainingKi <= 0
            ? 'Sin Ki'
            : '1 Ki - Bonus';

    return Row(
      children: [
        if (martialArtsAction != null) ...[
          Expanded(
            child: _MonkComboButton(
              icon: state.martialArtsPendingDamage
                  ? Icons.auto_fix_high_outlined
                  : Icons.back_hand_outlined,
              label: state.martialArtsPendingDamage ? 'Dano MA' : 'Golpe MA',
              detail: state.martialArtsPendingDamage
                  ? 'resolver'
                  : state.martialArtsActive
                      ? '1/1 listo'
                      : 'bonus sin Ki',
              color: color,
              enabled: state.martialArtsEnabled,
              compact: compact,
              filled: false,
              onTap: () => _rollPrimaryAction(
                martialArtsAction,
                onRollAction,
                onUseAction,
                pendingDamage: state.martialArtsPendingDamage,
              ),
            ),
          ),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: _MonkComboButton(
            icon: state.pendingDamage
                ? Icons.auto_fix_high_outlined
                : Icons.flash_on_rounded,
            label: state.flurryActive ? state.ctaLabel : 'Gastar Ki',
            detail: flurryDetail,
            color: color,
            enabled: state.enabled,
            compact: compact,
            filled: true,
            onTap: () => _handleFlurryTap(context),
          ),
        ),
      ],
    );
  }

  Future<void> _handleFlurryTap(BuildContext context) async {
    if (state.flurryActive || state.pendingDamage) {
      _rollPrimaryAction(
        state.flurryAction,
        onRollAction,
        onUseAction,
        pendingDamage: state.pendingDamage,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final tokens = dialogContext.stitch;
        return AlertDialog(
          backgroundColor: tokens.surface,
          title: const Text('Use Flurry of Blows?'),
          content: Text(
            'Spend 1 Ki and your Bonus Action to ready 2 unarmed strikes.',
            style: TextStyle(color: tokens.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Use Flurry'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    _rollPrimaryAction(
      state.flurryAction,
      onRollAction,
      onUseAction,
      pendingDamage: false,
    );
  }
}

class _MonkComboButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final bool enabled;
  final bool compact;
  final bool filled;
  final VoidCallback onTap;

  const _MonkComboButton({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    required this.enabled,
    required this.compact,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final effectiveColor = enabled ? color : tokens.textMuted;
    final backgroundAlpha = filled ? 0.88 : 0.12;
    final foreground =
        filled && enabled ? Colors.black : CombatCinematicColors.paper;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: compact ? 48 : 54,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(
            alpha: enabled ? backgroundAlpha : 0.10,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: effectiveColor.withValues(alpha: enabled ? 0.42 : 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: compact ? 16 : 18),
            SizedBox(width: compact ? 5 : 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: filled && enabled
                          ? Colors.black.withValues(alpha: 0.72)
                          : tokens.textSecondary,
                      fontSize: compact ? 8 : 9,
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
    );
  }
}

class _MonkKiPipCounter extends StatelessWidget {
  final int current;
  final int max;
  final Color color;
  final bool enabled;
  final bool compact;

  const _MonkKiPipCounter({
    required this.current,
    required this.max,
    required this.color,
    required this.enabled,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final pipTotal = max <= 0 ? 0 : math.min(max, compact ? 5 : 6);
    final overflow = max > pipTotal;
    final inactiveColor = tokens.textMuted.withValues(alpha: 0.42);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (enabled ? color : tokens.textMuted).withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.blur_on_rounded,
            color: enabled ? color : tokens.textMuted,
            size: compact ? 11 : 13,
          ),
          SizedBox(width: compact ? 4 : 5),
          for (var index = 0; index < pipTotal; index++) ...[
            if (index > 0) SizedBox(width: compact ? 2 : 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: compact ? 6 : 7,
              height: compact ? 6 : 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < current && enabled ? color : inactiveColor,
                border: Border.all(
                  color: index < current
                      ? color.withValues(alpha: 0.72)
                      : inactiveColor,
                ),
              ),
            ),
          ],
          SizedBox(width: compact ? 5 : 6),
          Text(
            overflow ? '$current/$max' : '$current Ki',
            maxLines: 1,
            style: TextStyle(
              color: enabled ? CombatCinematicColors.paper : tokens.textMuted,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassPassiveTraitStrip extends StatelessWidget {
  final List<ClassPassiveTrait> traits;
  final Color color;
  final bool compact;

  const _ClassPassiveTraitStrip({
    required this.traits,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (traits.isEmpty) return const SizedBox.shrink();
    final visibleTraits = traits.take(compact ? 2 : 3).toList(growable: false);
    final hiddenCount = traits.length - visibleTraits.length;

    return SizedBox(
      height: compact ? 18 : 21,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visibleTraits.length + (hiddenCount > 0 ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(width: compact ? 5 : 6),
        itemBuilder: (context, index) {
          if (index >= visibleTraits.length) {
            return _PassiveTraitBadge(
              label: '+$hiddenCount',
              detail: 'Mas rasgos pasivos del personaje.',
              icon: Icons.more_horiz,
              color: color,
              compact: compact,
            );
          }
          final trait = visibleTraits[index];
          return _PassiveTraitBadge(
            label: trait.label,
            detail: trait.detail,
            icon: trait.icon,
            color: color,
            compact: compact,
          );
        },
      ),
    );
  }
}

class _PassiveTraitBadge extends StatelessWidget {
  final String label;
  final String detail;
  final IconData icon;
  final Color color;
  final bool compact;

  const _PassiveTraitBadge({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: detail,
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 128 : 168),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: compact ? 10 : 12),
            SizedBox(width: compact ? 4 : 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: CombatCinematicColors.paper,
                  fontSize: compact ? 8 : 9,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CinematicTechniqueRail extends StatelessWidget {
  final List<CombatAction> actions;
  final Map<String, int> resourcePool;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final String? activeMultiAttackActionKey;
  final bool hasTakenAttackActionThisTurn;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final bool compact;

  const _CinematicTechniqueRail({
    required this.actions,
    required this.resourcePool,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.activeMultiAttackActionKey,
    required this.hasTakenAttackActionThisTurn,
    required this.onRollAction,
    required this.onUseAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final techniqueActions = _techniqueRailActions(
      actions: actions,
      resourcePool: resourcePool,
      pendingDamageActions: pendingDamageActions,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
    );
    if (techniqueActions.isEmpty) return const SizedBox.shrink();

    final resourceKey = _classKitResourceKey(actions, resourcePool);
    final resourceRemaining =
        resourceKey == null ? null : resourcePool[resourceKey] ?? 0;
    final color = resourceKey == null
        ? tokens.accentAction
        : _classKitAccent(resourceKey, tokens);
    final isKiKit =
        resourceKey != null && _isKiResourceKey(_rulesLabelText(resourceKey));
    final title = isKiKit
        ? 'Tecnicas activas'
        : resourceKey == null
            ? 'Artes marciales'
            : 'Artes marciales - ${_classKitTitle(resourceKey)}';
    final subtitle = resourceRemaining == null
        ? 'Golpe adicional sin Ki tras atacar'
        : isKiKit
            ? '$resourceRemaining Ki - acciones ejecutables'
            : '$resourceRemaining ${_classKitShortLabel(resourceKey ?? '')} disponibles';

    return Container(
      height: compact ? 50 : 56,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 42,
            height: compact ? 36 : 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Icon(
              Icons.self_improvement_rounded,
              color: CombatCinematicColors.paper,
              size: compact ? 18 : 21,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          SizedBox(
            width: compact ? 172 : 220,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CombatCinematicColors.paper,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: techniqueActions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final action = techniqueActions[index];
                final blockedReason = _techniqueActionBlockedReason(
                  actions: actions,
                  action: action,
                  resourcePool: resourcePool,
                  spentTimings: spentTimings,
                  pendingDamageActions: pendingDamageActions,
                  activeMultiAttackActionKey: activeMultiAttackActionKey,
                  hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
                );
                final pendingDamage =
                    pendingDamageActions.contains(_actionCardKey(action));
                return _TechniqueRailChip(
                  action: action,
                  color: color,
                  blockedReason: blockedReason,
                  pendingDamage: pendingDamage,
                  compact: compact,
                  onTap: () {
                    if (blockedReason != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${action.name}: $blockedReason'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(milliseconds: 1500),
                        ),
                      );
                      return;
                    }
                    _rollPrimaryAction(
                      action,
                      onRollAction,
                      onUseAction,
                      pendingDamage: pendingDamage,
                    );
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

class _TechniqueRailChip extends StatelessWidget {
  final CombatAction action;
  final Color color;
  final String? blockedReason;
  final bool pendingDamage;
  final bool compact;
  final VoidCallback onTap;

  const _TechniqueRailChip({
    required this.action,
    required this.color,
    required this.blockedReason,
    required this.pendingDamage,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = blockedReason != null;
    final effectiveColor = blocked ? context.stitch.textMuted : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: compact ? 154 : 178,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 9,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: blocked ? 0.08 : 0.16),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: effectiveColor.withValues(alpha: blocked ? 0.20 : 0.42),
          ),
        ),
        child: Row(
          children: [
            Icon(
              pendingDamage ? Icons.auto_fix_high_outlined : action.icon,
              color: CombatCinematicColors.paper,
              size: compact ? 15 : 17,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _techniqueActionLabel(action),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CombatCinematicColors.paper,
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _techniqueActionHint(action, blockedReason),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.stitch.textSecondary,
                      fontSize: compact ? 8 : 9,
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
    );
  }
}

class _CinematicActionLoadoutStrip extends StatelessWidget {
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final String selectedTiming;
  final int visibleActionCount;
  final int totalActionCount;
  final CombatAction? featuredAction;
  final bool pendingDamage;
  final bool spent;
  final Map<String, int> resourcePool;

  const _CinematicActionLoadoutStrip({
    required this.activeCombatant,
    required this.selectedTarget,
    required this.selectedTiming,
    required this.visibleActionCount,
    required this.totalActionCount,
    required this.featuredAction,
    required this.pendingDamage,
    required this.spent,
    required this.resourcePool,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final action = featuredAction;
    final accent = action == null
        ? combatTeamColor(activeCombatant.team, tokens)
        : _accentForKind(action.accentKind, tokens);
    final blocked =
        action == null ? false : _actionLacksResource(action, resourcePool);
    final resourceText = action == null
        ? null
        : _actionResourceText(
            action,
            _actionResourceRemaining(action, resourcePool),
          );

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_motion_outlined, color: accent, size: 17),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              '${activeCombatant.name} - ${_compactTimingLabel(selectedTiming)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CombatCinematicColors.paper,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CombatActionInfoChip(
            icon: Icons.inventory_2_outlined,
            label: '$visibleActionCount/$totalActionCount',
            color: tokens.accentInfo,
            compact: true,
          ),
          const SizedBox(width: 6),
          CombatActionInfoChip(
            icon: Icons.center_focus_strong_rounded,
            label: selectedTarget.name,
            color: tokens.accentWarning,
            compact: true,
          ),
          if (action != null) ...[
            const SizedBox(width: 6),
            CombatActionInfoChip(
              icon: pendingDamage
                  ? Icons.auto_fix_high_outlined
                  : spent
                      ? Icons.lock_clock_outlined
                      : Icons.flash_on_outlined,
              label: _actionDecisionStateText(
                pendingDamage: pendingDamage,
                spent: spent,
                blocked: blocked,
              ),
              color: pendingDamage
                  ? tokens.accentSuccess
                  : spent
                      ? CombatCinematicColors.blood
                      : blocked
                          ? CombatCinematicColors.blood
                          : accent,
              compact: true,
            ),
          ],
          if (resourceText != null) ...[
            const SizedBox(width: 6),
            CombatActionInfoChip(
              icon: Icons.battery_charging_full_outlined,
              label: resourceText,
              color: tokens.accentSuccess,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _CinematicFeaturedActionCard extends StatelessWidget {
  final CombatAction action;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final bool prepared;
  final bool spent;
  final bool pendingDamage;
  final bool blocked;
  final int? resourceRemaining;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final ValueChanged<CombatAction> onReadyAction;

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

    return CombatActionTapRegion(
      tooltip: _primaryActionTooltip(action, pendingDamage),
      onTap: () => _rollPrimaryAction(
        action,
        onRollAction,
        onUseAction,
        pendingDamage: pendingDamage,
      ),
      child: CombatActionCardFrame(
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
                        borderRadius: BorderRadius.circular(2),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.30)),
                      ),
                      child: Icon(
                        action.icon,
                        color: CombatCinematicColors.paper,
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
                              color: CombatCinematicColors.paper,
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
                                color: CombatCinematicColors.actionTextMuted,
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
                      CombatActionStateBadge(
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
                  _CinematicActionMetricGrid(
                    action: action,
                    resourceName: resourceName,
                    resourceRemaining: resourceRemaining,
                    blocked: blocked,
                    compact: tight,
                  ),
                ],
                if (!tight) ...[
                  const SizedBox(height: 8),
                  _CinematicActionOutcomeStrip(
                    action: action,
                    selectedTarget: selectedTarget,
                    pendingDamage: pendingDamage,
                    color: accent,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _cinematicActionDescription(
                        action, activeCombatant, selectedTarget),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CombatCinematicColors.actionTextMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.16,
                    ),
                  ),
                ],
                const Spacer(),
                if (blocked && !ultraTight) ...[
                  CombatActionInlineWarning(
                    label: resourceName == null
                        ? 'No disponible'
                        : '$resourceName agotado',
                  ),
                  const SizedBox(height: 6),
                ],
                SizedBox(height: ultraTight ? 4 : 6),
                Row(
                  children: [
                    Expanded(
                      child: CombatParchmentActionButton(
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
                    CombatParchmentIconButton(
                      icon: prepared ? Icons.bookmark_added : Icons.add_task,
                      tooltip: prepared ? 'Quitar del plan' : 'Preparar',
                      color: accent,
                      compact: tight,
                      onTap: () => onPrepareAction(action),
                    ),
                    if (!ultraTight && action.timing == 'Action') ...[
                      const SizedBox(width: 8),
                      CombatParchmentIconButton(
                        icon: Icons.flag_outlined,
                        tooltip: 'Ready action',
                        color: accent,
                        compact: tight,
                        onTap: () => onReadyAction(action),
                      ),
                    ],
                    if (!tight) ...[
                      const SizedBox(width: 8),
                      CombatParchmentIconButton(
                        icon: Icons.info_outline,
                        tooltip: 'Detalles',
                        color: accent,
                        onTap: () => showCombatActionDetails(context, action),
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
  final CombatAction action;
  final bool prepared;
  final bool spent;
  final bool pendingDamage;
  final bool blocked;
  final int? resourceRemaining;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final ValueChanged<CombatAction> onReadyAction;

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

    return CombatActionTapRegion(
      tooltip: _primaryActionTooltip(action, pendingDamage),
      onTap: () => _rollPrimaryAction(
        action,
        onRollAction,
        onUseAction,
        pendingDamage: pendingDamage,
      ),
      child: CombatActionCardFrame(
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
                      color: CombatCinematicColors.actionTextMuted,
                      size: veryTight ? 18 : 20,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        action.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: CombatCinematicColors.paper,
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
                      CombatActionStateBadge(
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
                    _actionRoleLine(action),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CombatCinematicColors.actionTextMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                SizedBox(height: ultraTight ? 3 : 6),
                _CinematicSmallActionStatLine(
                  action: action,
                  resourceRemaining: resourceRemaining,
                  blocked: blocked,
                  compact: veryTight,
                ),
                if (!veryTight) ...[
                  const SizedBox(height: 6),
                  _CinematicActionOutcomeStrip(
                    action: action,
                    selectedTarget: null,
                    pendingDamage: pendingDamage,
                    color: accent,
                    compact: true,
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: CombatParchmentActionButton(
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
                    CombatParchmentIconButton(
                      icon: prepared ? Icons.bookmark_added : Icons.add,
                      tooltip: prepared ? 'Quitar del plan' : 'Preparar',
                      color: accent,
                      compact: true,
                      onTap: () => onPrepareAction(action),
                    ),
                    if (!ultraTight && action.timing == 'Action') ...[
                      const SizedBox(width: 6),
                      CombatParchmentIconButton(
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

class _CinematicActionMetricGrid extends StatelessWidget {
  final CombatAction action;
  final String? resourceName;
  final int? resourceRemaining;
  final bool blocked;
  final bool compact;

  const _CinematicActionMetricGrid({
    required this.action,
    required this.resourceName,
    required this.resourceRemaining,
    required this.blocked,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final impactColor = action.isHealing
        ? tokens.accentSuccess
        : _accentForKind(action.accentKind, tokens);
    final areaText = combatActionAreaText(action);

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        CombatActionInfoChip(
          icon: Icons.straighten_rounded,
          label: _actionRangeText(action),
          color: tokens.accentInfo,
          compact: compact,
        ),
        CombatActionInfoChip(
          icon: action.requiresSavingThrow
              ? Icons.shield_outlined
              : Icons.casino_outlined,
          label: _actionRollText(action),
          color: CombatCinematicColors.goldBright,
          compact: compact,
        ),
        CombatActionInfoChip(
          icon: action.isHealing
              ? Icons.volunteer_activism_outlined
              : Icons.local_fire_department_outlined,
          label: _actionImpactText(action),
          color: impactColor,
          compact: compact,
        ),
        if (areaText != null)
          CombatActionInfoChip(
            icon: Icons.blur_circular_rounded,
            label: areaText,
            color: tokens.accentMagic,
            compact: compact,
          ),
        if (resourceName != null)
          CombatActionInfoChip(
            icon: blocked
                ? Icons.battery_alert_outlined
                : Icons.battery_charging_full_outlined,
            label: '$resourceName ${resourceRemaining ?? 0}',
            color: blocked ? CombatCinematicColors.blood : tokens.accentSuccess,
            compact: compact,
          ),
      ],
    );
  }
}

class _CinematicSmallActionStatLine extends StatelessWidget {
  final CombatAction action;
  final int? resourceRemaining;
  final bool blocked;
  final bool compact;

  const _CinematicSmallActionStatLine({
    required this.action,
    required this.resourceRemaining,
    required this.blocked,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final areaText = combatActionAreaText(action);
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        CombatActionInfoChip(
          icon: Icons.straighten_rounded,
          label: _actionRangeText(action),
          color: tokens.accentInfo,
          compact: true,
        ),
        CombatActionInfoChip(
          icon: Icons.casino_outlined,
          label: _actionRollText(action),
          color: CombatCinematicColors.goldBright,
          compact: true,
        ),
        if (!compact)
          CombatActionInfoChip(
            icon: action.isHealing
                ? Icons.volunteer_activism_outlined
                : Icons.local_fire_department_outlined,
            label: _actionImpactText(action),
            color: _accentForKind(action.accentKind, tokens),
            compact: true,
          ),
        if (areaText != null)
          CombatActionInfoChip(
            icon: Icons.blur_circular_rounded,
            label: areaText,
            color: tokens.accentMagic,
            compact: true,
          ),
        if (resourceRemaining != null)
          CombatActionInfoChip(
            icon: blocked
                ? Icons.battery_alert_outlined
                : Icons.battery_charging_full_outlined,
            label: '$resourceRemaining',
            color: blocked ? CombatCinematicColors.blood : tokens.accentSuccess,
            compact: true,
          ),
      ],
    );
  }
}

class _CinematicActionOutcomeStrip extends StatelessWidget {
  final CombatAction action;
  final Combatant? selectedTarget;
  final bool pendingDamage;
  final Color color;
  final bool compact;

  const _CinematicActionOutcomeStrip({
    required this.action,
    required this.selectedTarget,
    required this.pendingDamage,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final target = selectedTarget;
    final label = pendingDamage
        ? 'Dano pendiente'
        : action.requiresSavingThrow
            ? 'TS del objetivo'
            : action.attackFormula != null || action.hasMultiAttack
                ? 'Tirada de impacto'
                : action.isHealing
                    ? 'Recuperacion'
                    : 'Efecto listo';

    return Container(
      height: compact ? 26 : 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(
            pendingDamage ? Icons.auto_fix_high_outlined : action.icon,
            color: color,
            size: compact ? 14 : 16,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              target == null ? label : '$label - ${target.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CombatCinematicColors.paper,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 7),
            Text(
              action.timing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CinematicReactionBar extends StatelessWidget {
  final List<ReactionOption> options;
  final String activeName;
  final void Function(int actorIndex, CombatAction action) onUseReaction;

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
                color: CombatCinematicColors.gold.withValues(alpha: 0.18),
              ),
            ),
            child: const Text(
              'REACCIONES',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CombatCinematicColors.paper,
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
  final ReactionOption option;
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
    final accent = combatTeamColor(option.combatant.team, tokens);
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
                          color: CombatCinematicColors.paper,
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
  final CombatRollMode value;
  final ValueChanged<CombatRollMode> onChanged;

  const _CinematicRollModeToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CombatRollModeToggle<CombatRollMode>(
      value: value,
      onChanged: onChanged,
      options: const [
        CombatRollModeOption(
          value: CombatRollMode.normal,
          icon: Icons.casino_outlined,
          label: 'N',
          tooltip: 'Normal',
        ),
        CombatRollModeOption(
          value: CombatRollMode.advantage,
          icon: Icons.keyboard_arrow_up_rounded,
          label: 'ADV',
          tooltip: 'Ventaja',
        ),
        CombatRollModeOption(
          value: CombatRollMode.disadvantage,
          icon: Icons.keyboard_arrow_down_rounded,
          label: 'DIS',
          tooltip: 'Desventaja',
        ),
      ],
    );
  }
}

class _CinematicWorkspaceOverlay extends StatelessWidget {
  final CombatWorkspace workspace;
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final bool showEnemyHp;
  final List<CombatLogEntry> entries;
  final CombatRollFeedback? rollFeedback;

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
    return CombatCinematicPanelFrame(
      borderColor: CombatCinematicColors.gold,
      padding: const EdgeInsets.all(14),
      backgroundAlpha: 0.76,
      child: switch (workspace) {
        CombatWorkspace.log =>
          CombatFeedWindow(entries: entries, maxEntries: 12),
        CombatWorkspace.overview => _EncounterOverviewStage(
            combatants: combatants,
            activeIndex: activeIndex,
            targetIndex: targetIndex,
            rollFeedback: rollFeedback,
            showEnemyHp: showEnemyHp,
          ),
        CombatWorkspace.turn => const SizedBox.shrink(),
      },
    );
  }
}

class _CombatFallingDiceOverlay extends StatelessWidget {
  final CombatRollFeedback? feedback;

  const _CombatFallingDiceOverlay({
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final currentFeedback = feedback;
    final result = currentFeedback?.result;
    if (currentFeedback == null || result == null) {
      return const SizedBox.shrink();
    }

    final tokens = context.stitch;
    final accent = _accentForKind(currentFeedback.accentKind, tokens);
    final dice = _diceVisualsForResult(result);
    if (dice.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(
          '${currentFeedback.action}-${currentFeedback.headline}-${result.timestamp.microsecondsSinceEpoch}',
        ),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1550),
        curve: Curves.linear,
        builder: (context, value, child) {
          final t = value.clamp(0.0, 1.0);
          final opacity = t < 0.78 ? 1.0 : ((1.0 - t) / 0.22).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: child,
          );
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final stageTop = math.max(74.0, height * 0.10);
            final stageBottom = math.max(stageTop + 220, height * 0.62);
            final centerX = width * 0.50;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: centerX - 150,
                  top: stageBottom - 104,
                  width: 300,
                  height: 150,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final pulse = (1 - value).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: pulse * 0.46,
                        child: Transform.scale(
                          scale: 0.72 + value * 0.48,
                          child: child,
                        ),
                      );
                    },
                    child: CustomPaint(
                      painter: _DiceLandingShadowPainter(color: accent),
                    ),
                  ),
                ),
                for (var index = 0; index < dice.length; index++)
                  _FallingCombatDie(
                    visual: dice[index],
                    color: _dieColorForIndex(accent, index),
                    index: index,
                    total: dice.length,
                    stageTop: stageTop,
                    stageBottom: stageBottom,
                    stageWidth: width,
                  ),
                Positioned(
                  left: centerX - 190,
                  top: stageBottom + 24,
                  width: 380,
                  child: _DiceLandingResultPill(
                    feedback: currentFeedback,
                    color: accent,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FallingCombatDie extends StatelessWidget {
  final _RollDieVisual visual;
  final Color color;
  final int index;
  final int total;
  final double stageTop;
  final double stageBottom;
  final double stageWidth;

  const _FallingCombatDie({
    required this.visual,
    required this.color,
    required this.index,
    required this.total,
    required this.stageTop,
    required this.stageBottom,
    required this.stageWidth,
  });

  @override
  Widget build(BuildContext context) {
    final spread = math.min(360.0, stageWidth * 0.46);
    final slot = total <= 1 ? 0.5 : index / (total - 1);
    final wave = math.sin((index + 1) * 1.73);
    final start = Offset(
      stageWidth * (0.16 + (0.68 * ((slot + 0.17 * wave) % 1.0))),
      stageTop - 150 - index * 10,
    );
    final end = Offset(
      stageWidth * 0.50 - spread / 2 + spread * slot + wave * 18,
      stageBottom - 52 + math.cos(index * 1.37) * 18,
    );
    final size = visual.selected ? 72.0 : 58.0 - math.min(index, 4) * 2.0;
    final delay = math.min(0.24, index * 0.035);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 980 + index * 44),
      curve: Curves.easeOutCubic,
      builder: (context, rawValue, child) {
        final value = ((rawValue - delay) / (1 - delay)).clamp(0.0, 1.0);
        final drop = Curves.easeOutCubic.transform(value);
        final bounce = math.sin(value * math.pi);
        final settle = math.sin(value * math.pi * 8.0) * (1 - value);
        final offset =
            Offset.lerp(start, end, drop)! + Offset(settle * 10, -44 * bounce);
        final spin = 1 - value;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0019)
          ..rotateX(spin * math.pi * (2.0 + index * 0.18) + settle * 0.18)
          ..rotateY(spin * math.pi * (2.7 + index * 0.24))
          ..rotateZ(spin * math.pi * (1.4 + index * 0.16) + settle * 0.10);

        return Positioned(
          left: offset.dx - size / 2,
          top: offset.dy - size / 2,
          width: size,
          height: size,
          child: Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: Transform.scale(
              scale: 0.76 + 0.24 * Curves.easeOutBack.transform(value),
              child: child,
            ),
          ),
        );
      },
      child: _DndDieFace(
        visual: visual,
        color: color,
        size: size,
      ),
    );
  }
}

class _DndDieFace extends StatelessWidget {
  final _RollDieVisual visual;
  final Color color;
  final double size;

  const _DndDieFace({
    required this.visual,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size.square(size),
          painter: _DndDiePainter(
            sides: visual.sides,
            color: color,
            selected: visual.selected,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${visual.value}',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: visual.value >= 100 ? size * 0.26 : size * 0.34,
                fontWeight: FontWeight.w900,
                height: 0.92,
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            Text(
              'd${visual.sides}',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: size * 0.12,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DndDiePainter extends CustomPainter {
  final int sides;
  final Color color;
  final bool selected;

  const _DndDiePainter({
    required this.sides,
    required this.color,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _diePath(size, sides);
    final bounds = Offset.zero & size;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.44)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(0, 5)), shadow);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, selected ? 0.42 : 0.30)!,
          color.withValues(alpha: 0.96),
          Color.lerp(color, Colors.black, 0.58)!,
        ],
        stops: const [0, 0.48, 1],
      ).createShader(bounds);
    canvas.drawPath(path, fill);

    final center = Offset(size.width / 2, size.height / 2);
    final metric =
        path.computeMetrics().isEmpty ? null : path.computeMetrics().first;
    if (metric != null) {
      final facet = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, size.shortestSide * 0.026)
        ..color = Colors.white.withValues(alpha: 0.28);
      final count = _dieVertexCount(sides);
      for (var vertex = 0; vertex < count; vertex++) {
        final tangent =
            metric.getTangentForOffset(metric.length * vertex / count);
        if (tangent != null) canvas.drawLine(center, tangent.position, facet);
      }
    }

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 3.1 : 2.1
      ..color = Colors.white.withValues(alpha: selected ? 0.96 : 0.78);
    canvas.drawPath(path, edge);
  }

  Path _diePath(Size size, int sides) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.46;
    final path = Path();
    switch (sides) {
      case 4:
        return path
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius * 0.92, center.dy + radius * 0.72)
          ..lineTo(center.dx - radius * 0.92, center.dy + radius * 0.72)
          ..close();
      case 6:
        return path
          ..moveTo(center.dx - radius * 0.76, center.dy - radius * 0.58)
          ..lineTo(center.dx + radius * 0.42, center.dy - radius * 0.72)
          ..lineTo(center.dx + radius * 0.88, center.dy - radius * 0.12)
          ..lineTo(center.dx + radius * 0.74, center.dy + radius * 0.70)
          ..lineTo(center.dx - radius * 0.48, center.dy + radius * 0.82)
          ..lineTo(center.dx - radius * 0.90, center.dy + radius * 0.18)
          ..close();
      case 8:
        return path
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius * 0.86, center.dy)
          ..lineTo(center.dx, center.dy + radius)
          ..lineTo(center.dx - radius * 0.86, center.dy)
          ..close();
      case 10:
        return _regularDiePath(center, radius, 6, -math.pi / 2);
      case 12:
        return _regularDiePath(center, radius, 5, -math.pi / 2);
      case 20:
      default:
        return _regularDiePath(center, radius, 10, -math.pi / 2);
    }
  }

  Path _regularDiePath(
    Offset center,
    double radius,
    int count,
    double startAngle,
  ) {
    final path = Path();
    for (var index = 0; index < count; index++) {
      final angle = startAngle + index * math.pi * 2 / count;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  int _dieVertexCount(int sides) {
    return switch (sides) {
      4 => 3,
      6 => 6,
      8 => 4,
      10 => 6,
      12 => 5,
      _ => 10,
    };
  }

  @override
  bool shouldRepaint(covariant _DndDiePainter oldDelegate) {
    return oldDelegate.sides != sides ||
        oldDelegate.color != color ||
        oldDelegate.selected != selected;
  }
}

class _DiceLandingResultPill extends StatelessWidget {
  final CombatRollFeedback feedback;
  final Color color;

  const _DiceLandingResultPill({
    required this.feedback,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final result = feedback.result;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.54)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.casino_outlined, color: color, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              result == null
                  ? feedback.headline
                  : '${feedback.headline}  ${result.formula} = ${result.total}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CombatCinematicColors.paper,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiceLandingShadowPainter extends CustomPainter {
  final Color color;

  const _DiceLandingShadowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.42);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.64,
        height: size.height * 0.30,
      ),
      ring,
    );
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.30),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.82,
        height: size.height * 0.42,
      ),
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _DiceLandingShadowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RollDieVisual {
  final int sides;
  final int value;
  final bool selected;

  const _RollDieVisual({
    required this.sides,
    required this.value,
    this.selected = false,
  });
}

List<_RollDieVisual> _diceVisualsForResult(DiceRollResult result) {
  if (result.firstD20 != null && result.secondD20 != null) {
    return [
      _RollDieVisual(
        sides: 20,
        value: result.firstD20!,
        selected: result.selectedD20 == result.firstD20,
      ),
      _RollDieVisual(
        sides: 20,
        value: result.secondD20!,
        selected: result.selectedD20 == result.secondD20,
      ),
    ];
  }

  final dice = <_RollDieVisual>[];
  for (final term in result.terms) {
    for (final roll in term.rolls) {
      dice.add(_RollDieVisual(sides: term.sides, value: roll));
      if (dice.length >= 10) return dice;
    }
  }
  if (dice.isEmpty && result.total != 0) {
    dice.add(_RollDieVisual(
        sides: result.sides <= 1 ? 20 : result.sides, value: result.total));
  }
  return dice;
}

Color _dieColorForIndex(Color base, int index) {
  final mixes = [0.0, 0.18, -0.14, 0.30, -0.22, 0.10, -0.08, 0.24];
  final mix = mixes[index % mixes.length];
  if (mix >= 0) return Color.lerp(base, Colors.white, mix) ?? base;
  return Color.lerp(base, Colors.black, -mix) ?? base;
}

class _CinematicRollToast extends StatelessWidget {
  final CombatRollFeedback feedback;

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
                        color: CombatCinematicColors.paper,
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

class _CinematicEconomyStrip extends StatelessWidget {
  final CombatActionEconomySnapshot economy;

  const _CinematicEconomyStrip({
    required this.economy,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        CombatCinematicEconomyPill(
          label: 'Action',
          spent: economy.actionSpent,
          icon: Icons.bolt_outlined,
        ),
        CombatCinematicEconomyPill(
          label: 'Bonus',
          spent: economy.bonusActionSpent,
          icon: Icons.control_point_duplicate_outlined,
        ),
        CombatCinematicEconomyPill(
          label: 'React',
          spent: economy.reactionSpent,
          icon: Icons.reply_outlined,
        ),
        CombatCinematicEconomyPill(
          label: '${economy.movementAvailable} ft',
          spent: false,
          icon: Icons.directions_run_outlined,
        ),
        if (economy.readiedActionName != null)
          CombatCinematicEconomyPill(
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

class _CombatUnifiedControllerView extends StatelessWidget {
  final int round;
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final CombatRollFeedback? rollFeedback;
  final bool rollInFlight;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
  final String? activeMultiAttackActionKey;
  final int activeMultiAttackStepIndex;
  final List<PendingCombatAttack> activeMultiAttackPendingAttacks;
  final List<ReactionOption> reactionOptions;
  final bool hasTakenAttackActionThisTurn;
  final bool martialArtsEligibleAttackThisTurn;
  final bool flurryAlreadyUsedThisTurn;
  final CombatActionEconomySnapshot activeEconomy;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedCommandTiming;
  final CombatWorkspace workspace;
  final bool showEnemyHp;
  final bool devMode;
  final List<CombatLogEntry> entries;
  final Map<String, int> resourcePool;
  final CombatRollMode rollMode;
  final bool canControlActive;
  final String controlBlockedMessage;
  final bool boardControllerActive;
  final bool openingBattleBoard;
  final String? boardSceneId;
  final CombatAction? focusedBattleBoardAction;
  final VoidCallback onBack;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onToggleDevMode;
  final VoidCallback onOpenDiceRoller;
  final VoidCallback onShowBattleBoardControls;
  final VoidCallback onEndCombat;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onSelectFocusedCombatant;
  final ValueChanged<int> onEditHp;
  final ValueChanged<int> onRemoveBoardToken;
  final void Function(String combatantId, String effectName)
      onRemoveActiveEffect;
  final ValueChanged<CombatWorkspace> onSelectWorkspace;
  final ValueChanged<String> onSelectCommandTiming;
  final ValueChanged<CombatRollMode> onSelectRollMode;
  final ValueChanged<CombatAction> onFocusAction;
  final void Function(int actorIndex, CombatAction action) onUseReaction;
  final ValueChanged<CombatAction> onReadyAction;
  final ValueChanged<String> onRollSavingThrow;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onControlBlocked;
  final Future<void> Function(String combatantId, int dx, int dy)
      onMoveBoardToken;

  const _CombatUnifiedControllerView({
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.rollFeedback,
    required this.rollInFlight,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.activeMultiAttackActionKey,
    required this.activeMultiAttackStepIndex,
    required this.activeMultiAttackPendingAttacks,
    required this.reactionOptions,
    required this.hasTakenAttackActionThisTurn,
    required this.martialArtsEligibleAttackThisTurn,
    required this.flurryAlreadyUsedThisTurn,
    required this.activeEconomy,
    required this.queuedPreparedIndex,
    required this.queuedPreparedTotal,
    required this.queuedPreparedActionName,
    required this.selectedCommandTiming,
    required this.workspace,
    required this.showEnemyHp,
    required this.devMode,
    required this.entries,
    required this.resourcePool,
    required this.rollMode,
    required this.canControlActive,
    required this.controlBlockedMessage,
    required this.boardControllerActive,
    required this.openingBattleBoard,
    required this.boardSceneId,
    required this.focusedBattleBoardAction,
    required this.onBack,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onToggleDevMode,
    required this.onOpenDiceRoller,
    required this.onShowBattleBoardControls,
    required this.onEndCombat,
    required this.onRunDemo,
    required this.onSelectTarget,
    required this.onSelectFocusedCombatant,
    required this.onEditHp,
    required this.onRemoveBoardToken,
    required this.onRemoveActiveEffect,
    required this.onSelectWorkspace,
    required this.onSelectCommandTiming,
    required this.onSelectRollMode,
    required this.onFocusAction,
    required this.onUseReaction,
    required this.onReadyAction,
    required this.onRollSavingThrow,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
    required this.onControlBlocked,
    required this.onMoveBoardToken,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final sceneTokens = boardControllerActive && boardSceneId != null
        ? context
            .watch<BattleBoardProvider>()
            .tokens
            .where((token) => token.sceneId == boardSceneId)
            .toList(growable: false)
        : <BoardToken>[];
    final activeToken =
        CombatBoardTokenLookup.byRef(sceneTokens, activeCombatant.id);
    final selectedTargetToken =
        CombatBoardTokenLookup.byRef(sceneTokens, selectedTarget.id);
    final distanceFeet = activeToken == null || selectedTargetToken == null
        ? null
        : CombatBoardGeometry.distanceFeet(activeToken, selectedTargetToken);
    final targetEntries = _controllerTargetEntries(
      combatants,
      activeIndex: activeIndex,
    );
    final decision = _controllerDecision(
      actions: actions,
      selectedTiming: selectedCommandTiming,
      spentTimings: spentTimings,
      pendingDamageActions: pendingDamageActions,
      preparedActions: preparedActions,
      resourcePool: resourcePool,
      activeMultiAttackActionKey: activeMultiAttackActionKey,
      focusedAction: focusedBattleBoardAction,
      queuedPreparedTotal: queuedPreparedTotal,
      rollInFlight: rollInFlight,
      onNextTurn: onNextTurn,
      onLaunchPreparedTurn: onLaunchPreparedTurn,
      onRollAction: onRollAction,
      onUseAction: onUseAction,
    );

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: Stack(
          children: [
            const Positioned.fill(child: CombatCinematicDungeonBackdrop()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.34),
                ),
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1000 &&
                      constraints.maxHeight >= 620;
                  final leftWidth = math
                      .min(320.0, math.max(260.0, constraints.maxWidth * 0.26))
                      .toDouble();
                  final rightWidth = math
                      .min(300.0, math.max(250.0, constraints.maxWidth * 0.24))
                      .toDouble();

                  final actorPanel = CombatPlayerPanel(
                    round: round,
                    activeCombatant: activeCombatant,
                    selectedTarget: selectedTarget,
                    actions: actions,
                    selectedTiming: selectedCommandTiming,
                    economy: activeEconomy,
                    showEnemyHp: showEnemyHp,
                    canControlActive: canControlActive,
                    boardLinked: activeToken != null,
                    targetInRange: selectedTargetToken?.isTargetInRange ?? true,
                    speedFeet: activeToken?.speedFeet ?? activeCombatant.speed,
                    movementRemainingFeet: activeToken?.remainingMovementFeet ??
                        math.max(0, activeEconomy.movementAvailable),
                    gridX: activeToken?.x,
                    gridY: activeToken?.y,
                    distanceFeet: distanceFeet,
                    onBack: onBack,
                    onNextTurn: onNextTurn,
                    onEditHp: () => onEditHp(activeIndex),
                    onSelectTiming: onSelectCommandTiming,
                    onFocusAction: onFocusAction,
                    onMove: (dx, dy) => unawaited(
                      onMoveBoardToken(activeCombatant.id, dx, dy),
                    ),
                  );
                  final actionPanel = _ConsoleActionListPanel(
                    actions: actions,
                    visibleActions: decision.visibleActions,
                    selectedTiming: selectedCommandTiming,
                    spentTimings: spentTimings,
                    pendingDamageActions: pendingDamageActions,
                    preparedActions: preparedActions,
                    activeMultiAttackActionKey: activeMultiAttackActionKey,
                    activeMultiAttackStepIndex: activeMultiAttackStepIndex,
                    activeMultiAttackPendingAttacks:
                        activeMultiAttackPendingAttacks,
                    activeCombatant: activeCombatant,
                    hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
                    martialArtsEligibleAttackThisTurn:
                        martialArtsEligibleAttackThisTurn,
                    flurryAlreadyUsedThisTurn: flurryAlreadyUsedThisTurn,
                    selectedAction: decision.featuredAction,
                    resourcePool: resourcePool,
                    canControlActive: canControlActive,
                    controlBlockedMessage: controlBlockedMessage,
                    onSelectTiming: onSelectCommandTiming,
                    onFocusAction: onFocusAction,
                    onRollAction: onRollAction,
                    onUseAction: onUseAction,
                    onPrepareAction: onPrepareAction,
                    onReadyAction: onReadyAction,
                    rollInFlight: rollInFlight,
                  );
                  final targetPanel = _ConsoleTargetPanel(
                    targetEntries: targetEntries,
                    actions: actions,
                    combatants: combatants,
                    activeIndex: activeIndex,
                    selectedTarget: selectedTarget,
                    targetIndex: targetIndex,
                    sceneTokens: sceneTokens,
                    activeToken: activeToken,
                    showEnemyHp: showEnemyHp,
                    devMode: devMode,
                    rollMode: rollMode,
                    workspace: workspace,
                    canControlActive: canControlActive,
                    boardControllerActive: boardControllerActive,
                    openingBattleBoard: openingBattleBoard,
                    confirmLabel: decision.confirmLabel,
                    confirmEnabled: !rollInFlight &&
                        (decision.featuredAction != null ||
                            preparedActions.isNotEmpty),
                    rollInFlight: rollInFlight,
                    onConfirm: decision.confirmAction,
                    onSelectTarget: onSelectTarget,
                    onEditHp: onEditHp,
                    onRemoveBoardToken: onRemoveBoardToken,
                    onSelectRollMode: onSelectRollMode,
                    onRollSavingThrow: onRollSavingThrow,
                    onRollAction: onRollAction,
                    onSelectWorkspace: onSelectWorkspace,
                    onToggleDmView: onToggleDmView,
                    onToggleDevMode: onToggleDevMode,
                    onOpenDiceRoller: onOpenDiceRoller,
                    onShowBattleBoardControls: onShowBattleBoardControls,
                    onEndCombat: onEndCombat,
                    onRequestInitiative: onRequestInitiative,
                    onRollInitiative: onRollInitiative,
                    onRunDemo: onRunDemo,
                    onControlBlocked: onControlBlocked,
                  );

                  if (workspace != CombatWorkspace.turn) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          SizedBox(height: 158, child: actorPanel),
                          const SizedBox(height: 8),
                          Expanded(
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
                        ],
                      ),
                    );
                  }

                  if (compact) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          SizedBox(height: 184, child: actorPanel),
                          const SizedBox(height: 8),
                          Expanded(child: actionPanel),
                          const SizedBox(height: 8),
                          SizedBox(height: 210, child: targetPanel),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: leftWidth, child: actorPanel),
                        const SizedBox(width: 8),
                        Expanded(child: actionPanel),
                        const SizedBox(width: 8),
                        SizedBox(width: rightWidth, child: targetPanel),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControllerDecision {
  final List<CombatAction> visibleActions;
  final CombatAction? featuredAction;
  final String confirmLabel;
  final VoidCallback confirmAction;

  const _ControllerDecision({
    required this.visibleActions,
    required this.featuredAction,
    required this.confirmLabel,
    required this.confirmAction,
  });
}

_ControllerDecision _controllerDecision({
  required List<CombatAction> actions,
  required String selectedTiming,
  required Set<String> spentTimings,
  required Set<String> pendingDamageActions,
  required Map<String, CombatAction> preparedActions,
  required Map<String, int> resourcePool,
  required String? activeMultiAttackActionKey,
  required CombatAction? focusedAction,
  required int queuedPreparedTotal,
  required bool rollInFlight,
  required VoidCallback onNextTurn,
  required VoidCallback onLaunchPreparedTurn,
  required void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction,
  required ValueChanged<CombatAction> onUseAction,
}) {
  final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
    actions,
    pendingDamageActions,
  );
  final visibleActions = actions
      .where(
        (action) =>
            _actionVisibleInActionTiming(
              action,
              selectedTiming,
              hasPendingOnHitTrigger: hasPendingOnHitTrigger,
            ) &&
            !_actionHandledByMonkCombo(action),
      )
      .toList(growable: false);
  _sortActionsForTurnFlow(
    visibleActions,
    selectedTiming: selectedTiming,
    pendingDamageActions: pendingDamageActions,
    resourcePool: resourcePool,
  );
  final prepared = preparedActions[selectedTiming];
  final activeMultiAttackAction = activeMultiAttackActionKey == null
      ? null
      : _firstOrNull(
          actions.where(
            (action) => _actionCardKey(action) == activeMultiAttackActionKey,
          ),
        );
  final focused =
      focusedAction == null || focusedAction.timing != selectedTiming
          ? null
          : focusedAction;
  final featuredAction = prepared ??
      focused ??
      activeMultiAttackAction ??
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
  final hasPrepared = preparedActions.isNotEmpty;
  final confirmLabel = rollInFlight
      ? 'Rolling...'
      : queuedPreparedTotal > 0
          ? 'Tirar siguiente'
          : hasPrepared
              ? 'Tirar plan'
              : featuredPending
                  ? 'Resolver dano'
                  : featuredMultiAttackActive
                      ? 'Tirar siguiente'
                      : featuredSpent
                          ? 'Siguiente turno'
                          : 'Confirmar y tirar';
  final confirmAction = rollInFlight
      ? () {}
      : hasPrepared
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
  return _ControllerDecision(
    visibleActions: visibleActions,
    featuredAction: featuredAction,
    confirmLabel: confirmLabel,
    confirmAction: confirmAction,
  );
}

List<IndexedCombatant> _controllerTargetEntries(
  List<Combatant> combatants, {
  required int activeIndex,
}) {
  if (combatants.isEmpty ||
      activeIndex < 0 ||
      activeIndex >= combatants.length) {
    return const [];
  }
  final active = combatants[activeIndex];
  final hostile = <IndexedCombatant>[];
  final fallback = <IndexedCombatant>[];
  final fallen = <IndexedCombatant>[];
  for (var index = 0; index < combatants.length; index++) {
    if (index == activeIndex) continue;
    final entry = IndexedCombatant(index, combatants[index]);
    if (combatants[index].hp <= 0) {
      fallen.add(entry);
      continue;
    }
    fallback.add(entry);
    if (combatants[index].team != active.team) hostile.add(entry);
  }
  final primary = hostile.isEmpty ? fallback : hostile;
  return [...primary, ...fallen];
}

class _ConsoleActorMovePanel extends StatelessWidget {
  final int round;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final CombatActionEconomySnapshot economy;
  final bool showEnemyHp;
  final BoardToken? activeToken;
  final BoardToken? targetToken;
  final int? distanceFeet;
  final bool canControlActive;
  final VoidCallback onBack;
  final VoidCallback onNextTurn;
  final VoidCallback onEditHp;
  final void Function(int dx, int dy) onMove;

  const _ConsoleActorMovePanel({
    required this.round,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.economy,
    required this.showEnemyHp,
    required this.activeToken,
    required this.targetToken,
    required this.distanceFeet,
    required this.canControlActive,
    required this.onBack,
    required this.onNextTurn,
    required this.onEditHp,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = combatTeamColor(activeCombatant.team, tokens);
    final speed = activeToken?.speedFeet ?? activeCombatant.speed;
    final remaining = activeToken?.remainingMovementFeet ??
        math.max(0, economy.movementAvailable);
    final movementEnabled = canControlActive &&
        activeCombatant.hp > 0 &&
        activeToken != null &&
        remaining >= 5;
    final gridLabel = activeToken == null
        ? 'Grid --'
        : 'Grid ${activeToken!.x}, ${activeToken!.y}';
    final distanceLabel =
        distanceFeet == null ? 'Sin distancia' : '$distanceFeet ft';

    return CombatCinematicPanelFrame(
      borderColor: accent,
      padding: const EdgeInsets.all(8),
      backgroundAlpha: 0.82,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final short = constraints.maxHeight < 230;
          final portraitSize = short ? 58.0 : 78.0;
          final header = Row(
            children: [
              CombatPhoneIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Volver',
                onTap: onBack,
              ),
              const SizedBox(width: 7),
              Container(
                width: 38,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: accent.withValues(alpha: 0.30)),
                ),
                child: Text(
                  '$round',
                  style: const TextStyle(
                    color: CombatCinematicColors.paper,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const Spacer(),
              CombatPhoneIconButton(
                icon: Icons.skip_next_rounded,
                tooltip: 'Siguiente turno',
                color: CombatCinematicColors.goldBright,
                onTap: onNextTurn,
              ),
            ],
          );

          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: portraitSize,
                height: portraitSize,
                child: CombatCinematicPortraitBox(
                  combatant: activeCombatant,
                  color: accent,
                  iconSize: short ? 30 : 38,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeCombatant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CombatCinematicColors.paper,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      activeCombatant.role.isEmpty
                          ? 'Aventurero'
                          : activeCombatant.role,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: CombatCinematicHpBar(
                            combatant: activeCombatant,
                            showHp: showEnemyHp ||
                                activeCombatant.team == CombatTeam.party,
                            height: 22,
                            onTap: canControlActive ? onEditHp : null,
                          ),
                        ),
                        const SizedBox(width: 7),
                        CombatConsoleValueBadge(
                          label: 'AC',
                          value: '${activeCombatant.ac}',
                          color: accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final movement = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ConsoleMovementBudget(
                remaining: remaining,
                speed: speed,
                linked: activeToken != null,
                color: accent,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: _ConsoleMoveStick(
                    enabled: movementEnabled,
                    onMove: onMove,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CombatConsoleInfoPill(
                      icon: Icons.grid_on_rounded,
                      label: gridLabel,
                      color: tokens.accentInfo,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: CombatConsoleInfoPill(
                      icon: Icons.social_distance_outlined,
                      label: distanceLabel,
                      color: CombatCinematicColors.goldBright,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              CombatConsoleInfoPill(
                icon: targetToken == null
                    ? Icons.crisis_alert_outlined
                    : Icons.my_location_rounded,
                label: 'Objetivo: ${selectedTarget.name}',
                color: targetToken?.isTargetInRange == false
                    ? CombatCinematicColors.blood
                    : accent,
              ),
            ],
          );

          if (short) {
            return Column(
              children: [
                header,
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 138,
                        child: movement,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 9),
              identity,
              const SizedBox(height: 10),
              Expanded(child: movement),
            ],
          );
        },
      ),
    );
  }
}

class _ConsoleMovementBudget extends StatelessWidget {
  final int remaining;
  final int speed;
  final bool linked;
  final Color color;

  const _ConsoleMovementBudget({
    required this.remaining,
    required this.speed,
    required this.linked,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final ratio = speed <= 0 ? 0.0 : (remaining / speed).clamp(0.0, 1.0);
    final used = math.max(0, speed - remaining);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.directions_run_rounded,
                size: 15, color: remaining >= 5 ? color : tokens.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                linked ? '$remaining/$speed ft' : '$remaining ft disponibles',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CombatCinematicColors.paper,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              linked ? '$used usados' : 'sin token',
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
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: ratio,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining >= 5 ? color : tokens.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsoleMoveStick extends StatefulWidget {
  final bool enabled;
  final void Function(int dx, int dy) onMove;

  const _ConsoleMoveStick({
    required this.enabled,
    required this.onMove,
  });

  @override
  State<_ConsoleMoveStick> createState() => _ConsoleMoveStickState();
}

class _ConsoleMoveStickState extends State<_ConsoleMoveStick> {
  static const double _dragStep = 34;
  Offset _dragDebt = Offset.zero;

  void _drag(DragUpdateDetails details) {
    if (!widget.enabled) return;
    _dragDebt += details.delta;
    while (_dragDebt.dx.abs() >= _dragStep) {
      final dx = _dragDebt.dx > 0 ? 1 : -1;
      widget.onMove(dx, 0);
      _dragDebt = Offset(_dragDebt.dx - dx * _dragStep, _dragDebt.dy);
    }
    while (_dragDebt.dy.abs() >= _dragStep) {
      final dy = _dragDebt.dy > 0 ? 1 : -1;
      widget.onMove(0, dy);
      _dragDebt = Offset(_dragDebt.dx, _dragDebt.dy - dy * _dragStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = widget.enabled ? tokens.accentSuccess : tokens.textMuted;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.58,
      child: SizedBox.square(
        dimension: 136,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onPanUpdate: _drag,
              onPanEnd: (_) => _dragDebt = Offset.zero,
              child: Container(
                width: 98,
                height: 98,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.42),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.36),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.touch_app_rounded,
                  color: accent,
                  size: 28,
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: _ConsoleStickButton(
                icon: Icons.keyboard_arrow_up_rounded,
                enabled: widget.enabled,
                onTap: () => widget.onMove(0, -1),
              ),
            ),
            Positioned(
              bottom: 0,
              child: _ConsoleStickButton(
                icon: Icons.keyboard_arrow_down_rounded,
                enabled: widget.enabled,
                onTap: () => widget.onMove(0, 1),
              ),
            ),
            Positioned(
              left: 0,
              child: _ConsoleStickButton(
                icon: Icons.keyboard_arrow_left_rounded,
                enabled: widget.enabled,
                onTap: () => widget.onMove(-1, 0),
              ),
            ),
            Positioned(
              right: 0,
              child: _ConsoleStickButton(
                icon: Icons.keyboard_arrow_right_rounded,
                enabled: widget.enabled,
                onTap: () => widget.onMove(1, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleStickButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ConsoleStickButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = enabled ? CombatCinematicColors.goldBright : tokens.textMuted;
    return Tooltip(
      message: 'Mover',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.50),
            border: Border.all(color: color.withValues(alpha: 0.36)),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}

class _ConsoleActionListPanel extends StatelessWidget {
  final List<CombatAction> actions;
  final List<CombatAction> visibleActions;
  final String selectedTiming;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
  final String? activeMultiAttackActionKey;
  final int activeMultiAttackStepIndex;
  final List<PendingCombatAttack> activeMultiAttackPendingAttacks;
  final Combatant activeCombatant;
  final bool hasTakenAttackActionThisTurn;
  final bool martialArtsEligibleAttackThisTurn;
  final bool flurryAlreadyUsedThisTurn;
  final CombatAction? selectedAction;
  final Map<String, int> resourcePool;
  final bool canControlActive;
  final String controlBlockedMessage;
  final ValueChanged<String> onSelectTiming;
  final ValueChanged<CombatAction> onFocusAction;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final ValueChanged<CombatAction> onReadyAction;
  final bool rollInFlight;

  const _ConsoleActionListPanel({
    required this.actions,
    required this.visibleActions,
    required this.selectedTiming,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.activeMultiAttackActionKey,
    required this.activeMultiAttackStepIndex,
    required this.activeMultiAttackPendingAttacks,
    required this.activeCombatant,
    required this.hasTakenAttackActionThisTurn,
    required this.martialArtsEligibleAttackThisTurn,
    required this.flurryAlreadyUsedThisTurn,
    required this.selectedAction,
    required this.resourcePool,
    required this.canControlActive,
    required this.controlBlockedMessage,
    required this.onSelectTiming,
    required this.onFocusAction,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onReadyAction,
    required this.rollInFlight,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final selected = selectedAction;
    final selectedKey = selected == null ? null : _actionCardKey(selected);
    final selectedPrepared =
        selected != null && preparedActions[selected.timing] == selected;
    final monkFlow = _monkCombatFlowState(
      activeCombatant: activeCombatant,
      actions: actions,
      resourcePool: resourcePool,
      spentTimings: spentTimings,
      pendingDamageActions: pendingDamageActions,
      activeMultiAttackActionKey: activeMultiAttackActionKey,
      activeMultiAttackStepIndex: activeMultiAttackStepIndex,
      activeMultiAttackPendingAttacks: activeMultiAttackPendingAttacks,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
      martialArtsEligibleAttackThisTurn: martialArtsEligibleAttackThisTurn,
      flurryAlreadyUsedThisTurn: flurryAlreadyUsedThisTurn,
    );
    final debugDetail = _combatModeDebugDetails(
      actions: actions,
      resourcePool: resourcePool,
      monkFlow: monkFlow,
    );

    return CombatCinematicPanelFrame(
      borderColor: CombatCinematicColors.gold,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      backgroundAlpha: 0.90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sports_mma_outlined,
                color: CombatCinematicColors.goldBright,
                size: 17,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ACCIONES DEL TURNO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CombatCinematicColors.paper,
                    fontFamily: StitchTypography.display,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    height: 1,
                  ),
                ),
              ),
              Text(
                '${visibleActions.length}/${actions.length}',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontFamily: StitchTypography.data,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CinematicTimingTabs(
            actions: actions,
            selectedTiming: selectedTiming,
            spentTimings: spentTimings,
            pendingDamageActions: pendingDamageActions,
            preparedActions: preparedActions,
            onSelectTiming: onSelectTiming,
          ),
          const SizedBox(height: 7),
          CombatModeDebugBanner(
            location: 'ConsoleActionListPanel',
            detail: debugDetail,
          ),
          if (selectedTiming == 'Action' && monkFlow != null) ...[
            const SizedBox(height: 7),
            _MonkCombatFlowPanel(
              state: monkFlow,
              onRollAction: rollInFlight ? (_, __) {} : onRollAction,
              onUseAction: rollInFlight ? (_) {} : onUseAction,
              compact: true,
            ),
          ],
          if (selected != null) ...[
            const SizedBox(height: 7),
            _ConsoleSelectedActionBanner(
              action: selected,
              prepared: selectedPrepared,
              pendingDamage: pendingDamageActions.contains(selectedKey),
              blocked: _actionLacksResource(selected, resourcePool),
              resourceRemaining: _actionResourceRemaining(
                selected,
                resourcePool,
              ),
            ),
          ],
          const SizedBox(height: 7),
          Expanded(
            child: !canControlActive
                ? CombatConsoleLockState(message: controlBlockedMessage)
                : visibleActions.isEmpty
                    ? CombatActionListEmpty(selectedTiming: selectedTiming)
                    : ListView.separated(
                        itemCount: visibleActions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final action = visibleActions[index];
                          final key = _actionCardKey(action);
                          return _ConsoleActionRow(
                            action: action,
                            selected: selectedKey == key,
                            prepared: preparedActions[action.timing] == action,
                            spent: spentTimings.contains(action.timing) &&
                                activeMultiAttackActionKey != key,
                            pendingDamage: pendingDamageActions.contains(key),
                            blocked: _actionLacksResource(
                              action,
                              resourcePool,
                            ),
                            resourceRemaining: _actionResourceRemaining(
                              action,
                              resourcePool,
                            ),
                            onTap: () => onFocusAction(action),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CombatCinematicFooterButton(
                  icon: Icons.view_module_outlined,
                  label: 'Todas',
                  color: CombatCinematicColors.goldBright,
                  compact: true,
                  onTap: rollInFlight
                      ? () {}
                      : () => _showActionCatalogSheet(
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
              const SizedBox(width: 7),
              Expanded(
                child: CombatCinematicFooterButton(
                  icon: Icons.playlist_add_check_circle_outlined,
                  label: selectedPrepared ? 'En plan' : 'Planear',
                  color: selectedPrepared
                      ? tokens.accentSuccess
                      : CombatCinematicColors.goldBright,
                  compact: true,
                  onTap: selected == null || rollInFlight
                      ? () {}
                      : () => onPrepareAction(selected),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: CombatCinematicFooterButton(
                  icon: Icons.reply_outlined,
                  label: 'Ready',
                  color: CombatCinematicColors.paper,
                  compact: true,
                  onTap: selected == null || rollInFlight
                      ? () {}
                      : () => onReadyAction(selected),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConsoleSelectedActionBanner extends StatelessWidget {
  final CombatAction action;
  final bool prepared;
  final bool pendingDamage;
  final bool blocked;
  final int? resourceRemaining;

  const _ConsoleSelectedActionBanner({
    required this.action,
    required this.prepared,
    required this.pendingDamage,
    required this.blocked,
    required this.resourceRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = _actionStateColor(
      prepared: prepared,
      spent: false,
      pendingDamage: pendingDamage,
      blocked: blocked,
      fallback: _accentForKind(action.accentKind, tokens),
    );
    final resource = _actionResourceText(action, resourceRemaining);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          return Row(
            children: [
              Icon(action.icon, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CombatCinematicColors.paper,
                        fontFamily: StitchTypography.display,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (compact) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${_actionRangeText(action)} - ${resource ?? _actionImpactText(action)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: StitchCodexPalette.textMuted,
                          fontFamily: StitchTypography.data,
                          fontSize: 7,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                CombatConsoleMetricBlock(
                  label: 'Rango',
                  value: _actionRangeText(action),
                ),
                const SizedBox(width: 6),
                CombatConsoleMetricBlock(
                  label: action.requiresSavingThrow ? 'TS' : 'Bonus',
                  value: _consoleRollBonusText(action),
                ),
                const SizedBox(width: 6),
                CombatConsoleMetricBlock(
                  label: 'Impacto',
                  value: resource ?? _actionImpactText(action),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ConsoleActionRow extends StatelessWidget {
  final CombatAction action;
  final bool selected;
  final bool prepared;
  final bool spent;
  final bool pendingDamage;
  final bool blocked;
  final int? resourceRemaining;
  final VoidCallback onTap;

  const _ConsoleActionRow({
    required this.action,
    required this.selected,
    required this.prepared,
    required this.spent,
    required this.pendingDamage,
    required this.blocked,
    required this.resourceRemaining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = _actionStateColor(
      prepared: prepared,
      spent: spent,
      pendingDamage: pendingDamage,
      blocked: blocked,
      fallback: _accentForKind(action.accentKind, tokens),
    );
    final state = _actionDecisionStateText(
      pendingDamage: pendingDamage,
      spent: spent,
      blocked: blocked,
    );
    final resource = _actionResourceText(action, resourceRemaining);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : StitchCodexPalette.card.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.62 : 0.24),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            return Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: color.withValues(alpha: 0.30)),
                  ),
                  child: Icon(action.icon, color: color, size: 20),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              action.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CombatCinematicColors.paper,
                                fontFamily: StitchTypography.display,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                          if (prepared || pendingDamage || spent || blocked)
                            CombatConsoleStateChip(label: state, color: color),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        compact
                            ? '${_actionRoleLine(action)} - ${resource ?? _actionImpactText(action)}'
                            : _actionRoleLine(action),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontFamily: StitchTypography.body,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  CombatConsoleMetricBlock(
                    label: 'Rango',
                    value: _actionRangeText(action),
                  ),
                  const SizedBox(width: 6),
                  CombatConsoleMetricBlock(
                    label: action.requiresSavingThrow ? 'TS' : 'Bonus',
                    value: _consoleRollBonusText(action),
                  ),
                  const SizedBox(width: 6),
                  CombatConsoleMetricBlock(
                    label: 'Dano',
                    value: resource ?? _actionImpactText(action),
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

class _ConsoleTargetPanel extends StatelessWidget {
  final List<IndexedCombatant> targetEntries;
  final List<CombatAction> actions;
  final List<Combatant> combatants;
  final int activeIndex;
  final Combatant selectedTarget;
  final int targetIndex;
  final List<BoardToken> sceneTokens;
  final BoardToken? activeToken;
  final bool showEnemyHp;
  final bool devMode;
  final CombatRollMode rollMode;
  final CombatWorkspace workspace;
  final bool canControlActive;
  final bool boardControllerActive;
  final bool openingBattleBoard;
  final String confirmLabel;
  final bool confirmEnabled;
  final bool rollInFlight;
  final VoidCallback onConfirm;
  final ValueChanged<int> onSelectTarget;
  final ValueChanged<int> onEditHp;
  final ValueChanged<int> onRemoveBoardToken;
  final ValueChanged<CombatRollMode> onSelectRollMode;
  final ValueChanged<String> onRollSavingThrow;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatWorkspace> onSelectWorkspace;
  final VoidCallback onToggleDmView;
  final VoidCallback onToggleDevMode;
  final VoidCallback onOpenDiceRoller;
  final VoidCallback onShowBattleBoardControls;
  final VoidCallback onEndCombat;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onRunDemo;
  final VoidCallback onControlBlocked;

  const _ConsoleTargetPanel({
    required this.targetEntries,
    required this.actions,
    required this.combatants,
    required this.activeIndex,
    required this.selectedTarget,
    required this.targetIndex,
    required this.sceneTokens,
    required this.activeToken,
    required this.showEnemyHp,
    required this.devMode,
    required this.rollMode,
    required this.workspace,
    required this.canControlActive,
    required this.boardControllerActive,
    required this.openingBattleBoard,
    required this.confirmLabel,
    required this.confirmEnabled,
    required this.rollInFlight,
    required this.onConfirm,
    required this.onSelectTarget,
    required this.onEditHp,
    required this.onRemoveBoardToken,
    required this.onSelectRollMode,
    required this.onRollSavingThrow,
    required this.onRollAction,
    required this.onSelectWorkspace,
    required this.onToggleDmView,
    required this.onToggleDevMode,
    required this.onOpenDiceRoller,
    required this.onShowBattleBoardControls,
    required this.onEndCombat,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onRunDemo,
    required this.onControlBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final workspaceIcon = workspace == CombatWorkspace.turn
        ? Icons.receipt_long_outlined
        : Icons.dashboard_customize_outlined;
    final workspaceTarget = workspace == CombatWorkspace.turn
        ? CombatWorkspace.log
        : CombatWorkspace.turn;
    final selectedToken =
        CombatBoardTokenLookup.byRef(sceneTokens, selectedTarget.id);
    final selectedDistance = activeToken == null || selectedToken == null
        ? null
        : CombatBoardGeometry.distanceFeet(activeToken!, selectedToken);
    final footerEnabled = canControlActive && confirmEnabled && !rollInFlight;

    return CombatCinematicPanelFrame(
      borderColor: CombatCinematicColors.gold,
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
      backgroundAlpha: 0.90,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tiny = constraints.maxHeight < 220;
          final short = constraints.maxHeight < 280;
          final gap = tiny ? 6.0 : 8.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.center_focus_strong_outlined,
                    color: CombatCinematicColors.goldBright,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'OBJETIVOS Y CONTROL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CombatCinematicColors.paper,
                        fontFamily: StitchTypography.display,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    '${activeIndex + 1}/${combatants.length}',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontFamily: StitchTypography.data,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CombatPhoneIconButton(
                    icon: workspaceIcon,
                    tooltip:
                        workspace == CombatWorkspace.turn ? 'Log' : 'Turno',
                    onTap: () => onSelectWorkspace(workspaceTarget),
                  ),
                  const SizedBox(width: 4),
                  _PhoneToolMenu(
                    showEnemyHp: showEnemyHp,
                    devMode: devMode,
                    onToggleDmView: onToggleDmView,
                    onToggleDevMode: onToggleDevMode,
                    onRequestInitiative: onRequestInitiative,
                    onRollInitiative: onRollInitiative,
                    onRunDemo: onRunDemo,
                    onShowOverview: () =>
                        onSelectWorkspace(CombatWorkspace.overview),
                  ),
                ],
              ),
              if (!tiny) ...[
                SizedBox(height: gap),
                CombatConsoleInfoPill(
                  icon: selectedToken?.isTargetInRange == false
                      ? Icons.warning_amber_rounded
                      : Icons.my_location_rounded,
                  label: selectedDistance == null
                      ? selectedTarget.name
                      : '${selectedTarget.name} - $selectedDistance ft',
                  color: selectedToken?.isTargetInRange == false
                      ? CombatCinematicColors.blood
                      : CombatCinematicColors.goldBright,
                ),
              ],
              SizedBox(height: gap),
              _ConsoleQuickToolBar(
                boardControllerActive: boardControllerActive,
                openingBattleBoard: openingBattleBoard,
                devMode: devMode,
                onOpenDiceRoller: onOpenDiceRoller,
                onShowBattleBoardControls: onShowBattleBoardControls,
                onToggleDevMode: onToggleDevMode,
                onEndCombat: onEndCombat,
              ),
              SizedBox(height: gap),
              Expanded(
                child: targetEntries.isEmpty
                    ? const CombatConsoleEmptyTargets()
                    : ListView.separated(
                        itemCount: targetEntries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 5),
                        itemBuilder: (context, index) {
                          final entry = targetEntries[index];
                          final token = CombatBoardTokenLookup.byRef(
                            sceneTokens,
                            entry.combatant.id,
                          );
                          final distance = activeToken == null || token == null
                              ? null
                              : CombatBoardGeometry.distanceFeet(
                                  activeToken!, token);
                          return _ConsoleTargetTile(
                            entry: entry,
                            token: token,
                            selected: entry.index == targetIndex,
                            distanceFeet: distance,
                            showEnemyHp: showEnemyHp,
                            enabled: canControlActive,
                            onRemoveToken:
                                boardControllerActive && entry.combatant.hp <= 0
                                    ? () => onRemoveBoardToken(entry.index)
                                    : null,
                            onSelect: () {
                              if (!canControlActive) {
                                onControlBlocked();
                                return;
                              }
                              onSelectTarget(entry.index);
                            },
                            onEditHp: () => onEditHp(entry.index),
                          );
                        },
                      ),
              ),
              if (!short) ...[
                const SizedBox(height: 9),
                _CinematicRollModeToggle(
                  value: rollMode,
                  onChanged: canControlActive ? onSelectRollMode : (_) {},
                ),
              ],
              SizedBox(height: gap),
              Row(
                children: [
                  if (!tiny) ...[
                    SizedBox(
                      width: 76,
                      child: CombatCinematicFooterButton(
                        icon: Icons.shield_outlined,
                        label: 'TS',
                        color: CombatCinematicColors.goldBright,
                        compact: true,
                        onTap: canControlActive && !rollInFlight
                            ? () => showCombatSavingThrowSheet(
                                  context: context,
                                  target: selectedTarget,
                                  actions: actions,
                                  onRollSavingThrow: onRollSavingThrow,
                                  onRollAction: onRollAction,
                                )
                            : onControlBlocked,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: CombatCinematicConfirmButton(
                      enabled: footerEnabled,
                      label: rollInFlight
                          ? 'Rolling...'
                          : canControlActive
                              ? confirmLabel
                              : 'Esperar turno',
                      onTap: footerEnabled ? onConfirm : onControlBlocked,
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

class _ConsoleQuickToolBar extends StatelessWidget {
  final bool boardControllerActive;
  final bool openingBattleBoard;
  final bool devMode;
  final VoidCallback onOpenDiceRoller;
  final VoidCallback onShowBattleBoardControls;
  final VoidCallback onToggleDevMode;
  final VoidCallback onEndCombat;

  const _ConsoleQuickToolBar({
    required this.boardControllerActive,
    required this.openingBattleBoard,
    required this.devMode,
    required this.onOpenDiceRoller,
    required this.onShowBattleBoardControls,
    required this.onToggleDevMode,
    required this.onEndCombat,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    return Row(
      children: [
        Expanded(
          child: _ConsoleQuickToolButton(
            icon: Icons.casino_outlined,
            label: 'Dados',
            color: tokens.accentMagic,
            onTap: onOpenDiceRoller,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ConsoleQuickToolButton(
            icon: openingBattleBoard
                ? Icons.hourglass_empty_rounded
                : boardControllerActive
                    ? Icons.connected_tv_rounded
                    : Icons.grid_view_rounded,
            label: 'Board',
            color: tokens.accentInfo,
            onTap: openingBattleBoard ? null : onShowBattleBoardControls,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ConsoleQuickToolButton(
            icon: devMode ? Icons.construction_rounded : Icons.science_outlined,
            label: devMode ? 'Prueba ON' : 'Prueba',
            color: devMode
                ? tokens.accentSuccess
                : CombatCinematicColors.goldBright,
            onTap: onToggleDevMode,
          ),
        ),
        const SizedBox(width: 6),
        _ConsoleQuickToolButton(
          icon: Icons.flag_circle_outlined,
          label: '',
          tooltip: 'Terminar combate',
          color: tokens.accentAction,
          width: 38,
          onTap: onEndCombat,
        ),
      ],
    );
  }
}

class _ConsoleQuickToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final Color color;
  final double? width;
  final VoidCallback? onTap;

  const _ConsoleQuickToolButton({
    required this.icon,
    required this.label,
    this.tooltip,
    required this.color,
    this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final button = Opacity(
      opacity: enabled ? 1 : 0.48,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: width,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CombatCinematicColors.paper,
                      fontFamily: StitchTypography.data,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Tooltip(message: tooltip ?? label, child: button);
  }
}

class _ConsoleTargetTile extends StatelessWidget {
  final IndexedCombatant entry;
  final BoardToken? token;
  final bool selected;
  final int? distanceFeet;
  final bool showEnemyHp;
  final bool enabled;
  final VoidCallback? onRemoveToken;
  final VoidCallback onSelect;
  final VoidCallback onEditHp;

  const _ConsoleTargetTile({
    required this.entry,
    required this.token,
    required this.selected,
    required this.distanceFeet,
    required this.showEnemyHp,
    required this.enabled,
    required this.onRemoveToken,
    required this.onSelect,
    required this.onEditHp,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final combatant = entry.combatant;
    final color = combatTeamColor(combatant.team, tokens);
    final hpVisible = canShowCombatantHp(combatant, showEnemyHp);
    final canEditHp = hpVisible;
    final rangeColor = token?.isTargetInRange == false
        ? CombatCinematicColors.blood
        : CombatCinematicColors.goldBright;

    return Opacity(
      opacity: enabled ? 1 : 0.64,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 61,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : StitchCodexPalette.card.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: selected
                  ? CombatCinematicColors.goldBright.withValues(alpha: 0.68)
                  : color.withValues(alpha: 0.24),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: CombatCinematicPortraitBox(
                  combatant: combatant,
                  color: color,
                  iconSize: 21,
                ),
              ),
              const SizedBox(width: 8),
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
                        color: CombatCinematicColors.paper,
                        fontFamily: StitchTypography.display,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            combatant.role.isEmpty
                                ? 'Objetivo'
                                : combatant.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontFamily: StitchTypography.body,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          distanceFeet == null ? 'Grid --' : '$distanceFeet ft',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: rangeColor,
                            fontFamily: StitchTypography.data,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      color: StitchCodexPalette.textFaint,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: hpVisible ? combatant.hpRatio : 1,
                        child: ColoredBox(
                          color: hpVisible
                              ? combatant.hpRatio <= 0.30
                                  ? StitchCodexPalette.crimsonBright
                                  : color
                              : StitchCodexPalette.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (onRemoveToken != null)
                    Tooltip(
                      message: 'Retirar ficha del tablero',
                      child: InkWell(
                        onTap: onRemoveToken,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CombatCinematicColors.blood.withValues(
                              alpha: 0.18,
                            ),
                            border: Border.all(
                              color: CombatCinematicColors.blood.withValues(
                                alpha: 0.34,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: CombatCinematicColors.paper,
                            size: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      'AC ${combatant.ac}',
                      style: const TextStyle(
                        color: CombatCinematicColors.paper,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: canEditHp ? onEditHp : null,
                    child: Text(
                      compactCombatantHpLabel(combatant, showEnemyHp),
                      style: TextStyle(
                        color: canEditHp ? color : tokens.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _consoleRollBonusText(CombatAction action) {
  if (action.requiresSavingThrow) return 'DC ${action.saveDc}';
  if (action.hasMultiAttack) return '${action.multiAttackSteps.length}x';
  final formula = action.attackFormula;
  if (formula == null) return '-';
  final compact = formula.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  final match = RegExp(r'^d20([+-]\d+)$').firstMatch(compact);
  if (match != null) return match.group(1)!;
  if (compact == 'd20') return '+0';
  return formula;
}

class _CombatPhoneControllerView extends StatelessWidget {
  final int round;
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final CombatRollFeedback? rollFeedback;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
  final String? activeMultiAttackActionKey;
  final int activeMultiAttackStepIndex;
  final List<PendingCombatAttack> activeMultiAttackPendingAttacks;
  final List<ReactionOption> reactionOptions;
  final bool hasTakenAttackActionThisTurn;
  final bool martialArtsEligibleAttackThisTurn;
  final bool flurryAlreadyUsedThisTurn;
  final CombatActionEconomySnapshot activeEconomy;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedCommandTiming;
  final CombatWorkspace workspace;
  final bool showEnemyHp;
  final List<CombatLogEntry> entries;
  final Map<String, int> resourcePool;
  final CombatRollMode rollMode;
  final bool canControlActive;
  final String controlBlockedMessage;
  final bool boardControllerActive;
  final String? boardSceneId;
  final CombatAction? focusedBattleBoardAction;
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
  final ValueChanged<CombatWorkspace> onSelectWorkspace;
  final ValueChanged<String> onSelectCommandTiming;
  final ValueChanged<CombatRollMode> onSelectRollMode;
  final ValueChanged<CombatAction> onFocusAction;
  final void Function(int actorIndex, CombatAction action) onUseReaction;
  final ValueChanged<CombatAction> onReadyAction;
  final ValueChanged<String> onRollSavingThrow;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onControlBlocked;
  final Future<void> Function(String combatantId, int dx, int dy)
      onMoveBoardToken;

  const _CombatPhoneControllerView({
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
    required this.activeMultiAttackStepIndex,
    required this.activeMultiAttackPendingAttacks,
    required this.reactionOptions,
    required this.hasTakenAttackActionThisTurn,
    required this.martialArtsEligibleAttackThisTurn,
    required this.flurryAlreadyUsedThisTurn,
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
    required this.boardControllerActive,
    required this.boardSceneId,
    required this.focusedBattleBoardAction,
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
    required this.onFocusAction,
    required this.onUseReaction,
    required this.onReadyAction,
    required this.onRollSavingThrow,
    required this.onRollAction,
    required this.onUseAction,
    required this.onPrepareAction,
    required this.onLaunchPreparedTurn,
    required this.onClearPreparedActions,
    required this.onControlBlocked,
    required this.onMoveBoardToken,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final party = _indexedTeam(combatants, CombatTeam.party);
    final enemies = _indexedTeam(combatants, CombatTeam.enemy);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: Stack(
          children: [
            const Positioned.fill(child: CombatCinematicDungeonBackdrop()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.34),
                ),
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final veryShort = constraints.maxHeight < 620;
                  final topHeight = veryShort ? 58.0 : 64.0;
                  final deckHeight = math
                      .min(
                        veryShort ? 292.0 : 324.0,
                        math.max(
                          veryShort ? 250.0 : 282.0,
                          constraints.maxHeight * (veryShort ? 0.48 : 0.44),
                        ),
                      )
                      .toDouble();
                  const gap = 8.0;
                  final stage = boardControllerActive
                      ? _BoardLinkedControllerStage(
                          combatants: combatants,
                          activeIndex: activeIndex,
                          targetIndex: targetIndex,
                          activeCombatant: activeCombatant,
                          selectedTarget: selectedTarget,
                          actions: actions,
                          selectedTiming: selectedCommandTiming,
                          focusedAction: focusedBattleBoardAction,
                          sceneId: boardSceneId,
                          showEnemyHp: showEnemyHp,
                          canControlActive: canControlActive,
                          insets: EdgeInsets.zero,
                          onSelectTarget: onSelectTarget,
                          onEditHp: onEditHp,
                          onMoveBoardToken: onMoveBoardToken,
                        )
                      : _CinematicTacticalCenterLayer(
                          combatants: combatants,
                          party: party,
                          enemies: enemies,
                          activeIndex: activeIndex,
                          targetIndex: targetIndex,
                          rollFeedback: rollFeedback,
                          showEnemyHp: showEnemyHp,
                          insets: EdgeInsets.zero,
                          onEditHp: onEditHp,
                          onRemoveActiveEffect: onRemoveActiveEffect,
                          onSelectTarget: onSelectTarget,
                          onSelectFocusedCombatant: onSelectFocusedCombatant,
                        );

                  return Stack(
                    children: [
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 8,
                        height: topHeight,
                        child: _PhoneControllerTopBar(
                          round: round,
                          activeCombatant: activeCombatant,
                          selectedTarget: selectedTarget,
                          economy: activeEconomy,
                          workspace: workspace,
                          showEnemyHp: showEnemyHp,
                          boardControllerActive: boardControllerActive,
                          onBack: onBack,
                          onNextTurn: onNextTurn,
                          onToggleDmView: onToggleDmView,
                          onRequestInitiative: onRequestInitiative,
                          onRollInitiative: onRollInitiative,
                          onRunDemo: onRunDemo,
                          onSelectWorkspace: onSelectWorkspace,
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        top: 8 + topHeight + gap,
                        bottom: deckHeight + 16,
                        child: workspace == CombatWorkspace.log
                            ? _CinematicWorkspaceOverlay(
                                workspace: workspace,
                                combatants: combatants,
                                activeIndex: activeIndex,
                                targetIndex: targetIndex,
                                showEnemyHp: showEnemyHp,
                                entries: entries,
                                rollFeedback: rollFeedback,
                              )
                            : stage,
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        height: deckHeight,
                        child: _PhoneActionDeck(
                          activeCombatant: activeCombatant,
                          selectedTarget: selectedTarget,
                          actions: actions,
                          spentTimings: spentTimings,
                          pendingDamageActions: pendingDamageActions,
                          preparedActions: preparedActions,
                          activeMultiAttackActionKey:
                              activeMultiAttackActionKey,
                          reactionOptions: reactionOptions,
                          hasTakenAttackActionThisTurn:
                              hasTakenAttackActionThisTurn,
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
                          onRollSavingThrow: onRollSavingThrow,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneControllerTopBar extends StatelessWidget {
  final int round;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final CombatActionEconomySnapshot economy;
  final CombatWorkspace workspace;
  final bool showEnemyHp;
  final bool boardControllerActive;
  final VoidCallback onBack;
  final VoidCallback onNextTurn;
  final VoidCallback onToggleDmView;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onRunDemo;
  final ValueChanged<CombatWorkspace> onSelectWorkspace;

  const _PhoneControllerTopBar({
    required this.round,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.economy,
    required this.workspace,
    required this.showEnemyHp,
    required this.boardControllerActive,
    required this.onBack,
    required this.onNextTurn,
    required this.onToggleDmView,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onRunDemo,
    required this.onSelectWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = combatTeamColor(activeCombatant.team, tokens);
    final workspaceIcon = workspace == CombatWorkspace.log
        ? Icons.grid_view_outlined
        : Icons.receipt_long_outlined;
    final workspaceTarget = workspace == CombatWorkspace.log
        ? CombatWorkspace.turn
        : CombatWorkspace.log;

    return CombatCinematicPanelFrame(
      borderColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      backgroundAlpha: 0.82,
      child: Row(
        children: [
          CombatPhoneIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Volver',
            onTap: onBack,
          ),
          const SizedBox(width: 7),
          Container(
            width: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Text(
              '$round',
              style: const TextStyle(
                color: CombatCinematicColors.paper,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                    color: CombatCinematicColors.paper,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CombatCinematicEconomyDot(
                      icon: Icons.flash_on,
                      spent: economy.actionSpent,
                      color: accent,
                    ),
                    const SizedBox(width: 4),
                    CombatCinematicEconomyDot(
                      icon: Icons.control_point_duplicate,
                      spent: economy.bonusActionSpent,
                      color: accent,
                    ),
                    const SizedBox(width: 4),
                    CombatCinematicEconomyDot(
                      icon: Icons.reply_rounded,
                      spent: economy.reactionSpent,
                      color: accent,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        boardControllerActive
                            ? '${economy.movementAvailable} ft - ${selectedTarget.name}'
                            : compactCombatantHpLabel(
                                activeCombatant, showEnemyHp),
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
          const SizedBox(width: 7),
          CombatPhoneIconButton(
            icon: workspaceIcon,
            tooltip: workspace == CombatWorkspace.log ? 'Turno' : 'Log',
            onTap: () => onSelectWorkspace(workspaceTarget),
          ),
          const SizedBox(width: 5),
          _PhoneToolMenu(
            showEnemyHp: showEnemyHp,
            onToggleDmView: onToggleDmView,
            onRequestInitiative: onRequestInitiative,
            onRollInitiative: onRollInitiative,
            onRunDemo: onRunDemo,
            onShowOverview: () => onSelectWorkspace(CombatWorkspace.overview),
          ),
          const SizedBox(width: 5),
          CombatPhoneIconButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Siguiente turno',
            color: CombatCinematicColors.goldBright,
            onTap: onNextTurn,
          ),
        ],
      ),
    );
  }
}

class _PhoneToolMenu extends StatelessWidget {
  final bool showEnemyHp;
  final bool devMode;
  final VoidCallback onToggleDmView;
  final VoidCallback? onToggleDevMode;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onRunDemo;
  final VoidCallback onShowOverview;

  const _PhoneToolMenu({
    required this.showEnemyHp,
    this.devMode = false,
    required this.onToggleDmView,
    this.onToggleDevMode,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onRunDemo,
    required this.onShowOverview,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Herramientas',
      color: context.stitch.surfaceRaised,
      icon: const Icon(
        Icons.more_horiz_rounded,
        color: CombatCinematicColors.paper,
      ),
      onSelected: (value) {
        switch (value) {
          case 'view':
            onToggleDmView();
          case 'dev':
            onToggleDevMode?.call();
          case 'overview':
            onShowOverview();
          case 'initiative':
            onRequestInitiative();
          case 'roll':
            onRollInitiative();
          case 'demo':
            onRunDemo();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'view',
          child: Text(showEnemyHp ? 'Vista jugador' : 'Vista DM'),
        ),
        if (onToggleDevMode != null)
          PopupMenuItem(
            value: 'dev',
            child: Text(devMode ? 'Desactivar modo prueba' : 'Modo prueba'),
          ),
        const PopupMenuItem(
          value: 'overview',
          child: Text('Resumen'),
        ),
        const PopupMenuItem(
          value: 'initiative',
          child: Text('Pedir iniciativa'),
        ),
        const PopupMenuItem(
          value: 'roll',
          child: Text('Tirar iniciativa'),
        ),
        const PopupMenuItem(
          value: 'demo',
          child: Text('Demo'),
        ),
      ],
    );
  }
}

class _PhoneActionDeck extends StatelessWidget {
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
  final String? activeMultiAttackActionKey;
  final List<ReactionOption> reactionOptions;
  final bool hasTakenAttackActionThisTurn;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final Map<String, int> resourcePool;
  final CombatRollMode rollMode;
  final bool canControlActive;
  final String controlBlockedMessage;
  final ValueChanged<String> onSelectTiming;
  final ValueChanged<CombatRollMode> onSelectRollMode;
  final void Function(int actorIndex, CombatAction action) onUseReaction;
  final ValueChanged<CombatAction> onReadyAction;
  final ValueChanged<String> onRollSavingThrow;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
  final VoidCallback onLaunchPreparedTurn;
  final VoidCallback onClearPreparedActions;
  final VoidCallback onControlBlocked;
  final VoidCallback onNextTurn;

  const _PhoneActionDeck({
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.preparedActions,
    required this.activeMultiAttackActionKey,
    required this.reactionOptions,
    required this.hasTakenAttackActionThisTurn,
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
    required this.onRollSavingThrow,
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
    if (!canControlActive) {
      return _PhoneControlLockDock(
        activeCombatant: activeCombatant,
        message: controlBlockedMessage,
        onControlBlocked: onControlBlocked,
      );
    }

    final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
      actions,
      pendingDamageActions,
    );
    final visibleActions = actions
        .where(
          (action) =>
              _actionVisibleInActionTiming(
                action,
                selectedTiming,
                hasPendingOnHitTrigger: hasPendingOnHitTrigger,
              ) &&
              !_actionHandledByMonkCombo(action),
        )
        .toList(growable: false);
    _sortActionsForTurnFlow(
      visibleActions,
      selectedTiming: selectedTiming,
      pendingDamageActions: pendingDamageActions,
      resourcePool: resourcePool,
    );
    final prepared = preparedActions[selectedTiming];
    final activeMultiAttackAction = activeMultiAttackActionKey == null
        ? null
        : _firstOrNull(
            actions.where(
              (action) => _actionCardKey(action) == activeMultiAttackActionKey,
            ),
          );
    final featuredAction = prepared ??
        activeMultiAttackAction ??
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
    final handActions = [
      if (featuredAction != null) featuredAction,
      ...visibleActions.where((action) => action != featuredAction),
    ].take(8).toList(growable: false);
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
                        : 'Confirmar';
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
    final showTechniqueRail = _techniqueRailActions(
      actions: actions,
      resourcePool: resourcePool,
      pendingDamageActions: pendingDamageActions,
      hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
    ).isNotEmpty;

    return CombatCinematicPanelFrame(
      borderColor: CombatCinematicColors.gold,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
      backgroundAlpha: 0.84,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final short = constraints.maxHeight < 285;
          final roomy = constraints.maxHeight >= 350;
          final actionCardHeight = short ? 118.0 : 142.0;
          final actionCardWidth =
              math.min(254.0, math.max(220.0, constraints.maxWidth * 0.72));

          return Column(
            children: [
              _CinematicTimingTabs(
                actions: actions,
                selectedTiming: selectedTiming,
                spentTimings: spentTimings,
                pendingDamageActions: pendingDamageActions,
                preparedActions: preparedActions,
                onSelectTiming: onSelectTiming,
              ),
              if (selectedTiming == 'Reaction' &&
                  reactionOptions.isNotEmpty) ...[
                const SizedBox(height: 6),
                _CinematicReactionBar(
                  options: reactionOptions,
                  activeName: activeCombatant.name,
                  onUseReaction: onUseReaction,
                ),
              ],
              if (roomy && (preparedActions.isNotEmpty || featuredPending)) ...[
                const SizedBox(height: 6),
                _CinematicTurnPlanStrip(
                  preparedActions: preparedActions,
                  pendingAction: featuredPending ? featuredAction : null,
                ),
              ],
              if (roomy && showTechniqueRail) ...[
                const SizedBox(height: 6),
                _CinematicTechniqueRail(
                  actions: actions,
                  resourcePool: resourcePool,
                  spentTimings: spentTimings,
                  pendingDamageActions: pendingDamageActions,
                  activeMultiAttackActionKey: activeMultiAttackActionKey,
                  hasTakenAttackActionThisTurn: hasTakenAttackActionThisTurn,
                  onRollAction: onRollAction,
                  onUseAction: onUseAction,
                  compact: true,
                ),
              ],
              const SizedBox(height: 7),
              SizedBox(
                height: actionCardHeight,
                child: handActions.isEmpty
                    ? CombatActionListEmpty(
                        selectedTiming: selectedTiming,
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: handActions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final action = handActions[index];
                          final key = _actionCardKey(action);
                          return SizedBox(
                            width: actionCardWidth,
                            child: _CinematicSmallActionCard(
                              action: action,
                              prepared:
                                  preparedActions[action.timing] == action,
                              spent: spentTimings.contains(action.timing) &&
                                  activeMultiAttackActionKey != key,
                              pendingDamage: pendingDamageActions.contains(key),
                              blocked:
                                  _actionLacksResource(action, resourcePool),
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
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: CombatCinematicFooterButton(
                      icon: Icons.view_module_outlined,
                      label: 'Todas',
                      color: CombatCinematicColors.goldBright,
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
                  const SizedBox(width: 7),
                  Expanded(
                    child: CombatCinematicFooterButton(
                      icon: Icons.shield_outlined,
                      label: 'TS',
                      color: CombatCinematicColors.goldBright,
                      compact: true,
                      onTap: () => showCombatSavingThrowSheet(
                        context: context,
                        target: selectedTarget,
                        actions: actions,
                        onRollSavingThrow: onRollSavingThrow,
                        onRollAction: onRollAction,
                      ),
                    ),
                  ),
                  if (hasPrepared) ...[
                    const SizedBox(width: 7),
                    Expanded(
                      child: CombatCinematicFooterButton(
                        icon: Icons.clear_all_outlined,
                        label: 'Limpiar',
                        color: CombatCinematicColors.paper,
                        compact: true,
                        onTap: onClearPreparedActions,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  SizedBox(
                    width: 118,
                    child: _CinematicRollModeToggle(
                      value: rollMode,
                      onChanged: onSelectRollMode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CombatCinematicConfirmButton(
                      enabled: featuredAction != null || hasPrepared,
                      label: confirmLabel,
                      onTap: confirmAction,
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

class _PhoneControlLockDock extends StatelessWidget {
  final Combatant activeCombatant;
  final String message;
  final VoidCallback onControlBlocked;

  const _PhoneControlLockDock({
    required this.activeCombatant,
    required this.message,
    required this.onControlBlocked,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = combatTeamColor(activeCombatant.team, tokens);

    return CombatCinematicPanelFrame(
      borderColor: accent,
      padding: const EdgeInsets.all(12),
      backgroundAlpha: 0.84,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: CombatCinematicPortraitBox(
                  combatant: activeCombatant,
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
                      'Turno de ${activeCombatant.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CombatCinematicColors.paper,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
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
            ],
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Text(
              'Puedes mirar el turno, elegir objetivos para el tablero y esperar tu momento. Las acciones ajenas quedan ocultas en el controlador de jugador.',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.18,
              ),
            ),
          ),
          const SizedBox(height: 10),
          CombatCinematicConfirmButton(
            enabled: true,
            label: 'Esperar turno',
            onTap: onControlBlocked,
          ),
        ],
      ),
    );
  }
}

class _CombatNarrowModeView extends StatelessWidget {
  final int round;
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final CombatRollFeedback? rollFeedback;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, CombatAction> preparedActions;
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
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
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
          const CombatLandscapeNudge(),
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

class _CompactLandscapeTopBar extends StatelessWidget {
  final int round;
  final List<Combatant> combatants;
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
          CombatCompactIconButton(
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
          CombatCompactIconButton(
            icon: showEnemyHp
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            label: showEnemyHp ? 'DM' : 'Player',
            onTap: onToggleDmView,
          ),
          CombatCompactIconButton(
            icon: Icons.campaign_outlined,
            label: 'Init',
            onTap: onRequestInitiative,
          ),
          CombatCompactIconButton(
            icon: Icons.casino_outlined,
            label: 'Roll',
            onTap: onRollInitiative,
          ),
          CombatCompactIconButton(
            icon: Icons.play_circle_outline,
            label: 'Demo',
            onTap: onRunDemo,
          ),
          const SizedBox(width: 3),
          CombatCompactIconButton(
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
  final Combatant combatant;
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
        selected ? tokens.accentInfo : combatTeamColor(combatant.team, tokens);
    final hpLabel = compactCombatantHpLabel(combatant, showEnemyHp);

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

class _CompactActiveCombatantCard extends StatelessWidget {
  final Combatant combatant;
  final List<CombatAction> actions;
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
    final accent = combatTeamColor(combatant.team, tokens);
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Free', 'Movement'];

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
                  child: CombatantArtwork(
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
                    child: CombatGameMetric(
                      label: 'HP',
                      value: compactCombatantHpLabel(combatant, showEnemyHp),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child:
                        CombatGameMetric(label: 'AC', value: '${combatant.ac}'),
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
                        child: CombatStatusChip(label: effect, color: accent),
                      );
                    },
                  ),
                ),
              ],
              if (!enabled) ...[
                SizedBox(height: isTight ? 5 : 7),
                CombatCompactControlLockNotice(message: disabledMessage),
              ],
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 7,
                children: [
                  for (final timing in timings)
                    SizedBox(
                      width: buttonWidth,
                      child: CombatCompactTimingCommandButton(
                        icon: _timingIcon(timing),
                        label: _compactTimingLabel(timing),
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

class _CompactTargetCard extends StatelessWidget {
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant combatant;
  final CombatRollFeedback? rollFeedback;
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
    final accent = combatTeamColor(combatant.team, tokens);
    final impactFeedback = rollFeedback != null &&
            _feedbackMentionsCombatant(rollFeedback!, combatant)
        ? rollFeedback
        : null;
    final impactAccent = impactFeedback == null
        ? accent
        : _accentForKind(impactFeedback.accentKind, tokens);
    final showHp = canShowCombatantHp(combatant, showEnemyHp);
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
                  CombatantArtwork(
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
                child: CombatGameMetric(
                  label: 'HP',
                  value: compactCombatantHpLabel(combatant, showEnemyHp),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: CombatGameMetric(label: 'AC', value: '${combatant.ac}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactPreparedTurnStrip extends StatelessWidget {
  final Combatant activeCombatant;
  final List<CombatAction> actions;
  final Map<String, CombatAction> preparedActions;
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
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Free', 'Movement'];
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
            CombatCompactControlLockNotice(message: disabledMessage),
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
  final CombatAction? action;
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

class _GameCombatantPanel extends StatelessWidget {
  final String title;
  final Combatant combatant;
  final CombatAccentKind accentKind;
  final bool showEnemyHp;
  final List<CombatAction>? actions;
  final String? selectedTiming;
  final Set<String>? spentTimings;
  final Set<String>? pendingDamageActions;
  final Map<String, int>? resourcePool;
  final Map<String, CombatAction>? preparedActions;
  final ValueChanged<String>? onSelectTiming;
  final void Function(CombatAction action, CombatActionRoll rollType)?
      onRollAction;
  final ValueChanged<CombatAction>? onUseAction;
  final ValueChanged<CombatAction>? onPrepareAction;
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
    final showHp = canShowCombatantHp(combatant, showEnemyHp);
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
              child: CombatantPortraitFrame(
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
                  child: CombatGameMetric(
                    label: 'HP',
                    value: compactCombatantHpLabel(combatant, showEnemyHp),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      CombatGameMetric(label: 'AC', value: '${combatant.ac}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CombatGameMetric(
                    label: 'INIT',
                    value: '${combatant.initiative}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CombatGameMetric(
                      label: 'SPD', value: '${combatant.speed}'),
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
  final List<CombatAction> actions;
  final String selectedTiming;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, int> resourcePool;
  final Map<String, CombatAction> preparedActions;
  final ValueChanged<String> onSelectTiming;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;

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
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Free', 'Movement'];
    final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
      actions,
      pendingDamageActions,
    );
    final classIdentity = _classCombatVisualIdentityForActions(
      actions: actions,
      resourcePool: resourcePool,
    );

    CombatAction? pendingDamageActionFor(String timing) {
      for (final action in actions) {
        if (_actionVisibleInActionTiming(
              action,
              timing,
              hasPendingOnHitTrigger: hasPendingOnHitTrigger,
            ) &&
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
          if (classIdentity != null &&
              classIdentity.passiveTraits.isNotEmpty) ...[
            _ClassPassiveReferencePanel(identity: classIdentity),
            const SizedBox(height: 8),
          ],
          _CharacterClassKitPanel(
            actions: actions,
            resourcePool: resourcePool,
            spentTimings: spentTimings,
            pendingDamageActions: pendingDamageActions,
            onRollAction: onRollAction,
            onUseAction: onUseAction,
          ),
          const SizedBox(height: 8),
          for (final timing in timings) ...[
            if (timing != timings.first) const SizedBox(height: 6),
            _CharacterActionAccessRow(
              timing: timing,
              count: actions
                  .where(
                    (action) => _actionVisibleInActionTiming(
                      action,
                      timing,
                      hasPendingOnHitTrigger: hasPendingOnHitTrigger,
                    ),
                  )
                  .length,
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

class _ClassPassiveReferencePanel extends StatelessWidget {
  final ClassCombatVisualIdentity identity;

  const _ClassPassiveReferencePanel({
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = _classCombatVisualAccent(identity, tokens);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: accent, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'RASGOS PASIVOS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _ClassPassiveTraitStrip(
            traits: identity.passiveTraits,
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _CharacterClassKitPanel extends StatelessWidget {
  final List<CombatAction> actions;
  final Map<String, int> resourcePool;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;

  const _CharacterClassKitPanel({
    required this.actions,
    required this.resourcePool,
    required this.spentTimings,
    required this.pendingDamageActions,
    required this.onRollAction,
    required this.onUseAction,
  });

  @override
  Widget build(BuildContext context) {
    final resourceKey = _classKitResourceKey(actions, resourcePool);
    if (resourceKey == null) return const SizedBox.shrink();

    final tokens = context.stitch;
    final accent = _classKitAccent(resourceKey, tokens);
    final remaining = resourcePool[resourceKey] ?? 0;
    final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
      actions,
      pendingDamageActions,
    );
    final kitActions = actions
        .where((action) =>
            action.resourceKey == resourceKey &&
            action.resourceCost > 0 &&
            action.timing != 'Reaction' &&
            (!_actionIsOnHitOption(action) || hasPendingOnHitTrigger))
        .toList(growable: false);
    if (kitActions.isEmpty) return const SizedBox.shrink();
    kitActions.sort((a, b) {
      final priorityA = _classKitActionPriority(
        a,
        hasPendingOnHitTrigger: hasPendingOnHitTrigger,
      );
      final priorityB = _classKitActionPriority(
        b,
        hasPendingOnHitTrigger: hasPendingOnHitTrigger,
      );
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);
      return a.name.compareTo(b.name);
    });

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_classKitIcon(resourceKey), color: accent, size: 16),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _classKitTitle(resourceKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ClassResourcePip(
                remaining: remaining,
                label: _classKitShortLabel(resourceKey),
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final action in kitActions.take(6))
                _ClassKitActionChip(
                  action: action,
                  color: accent,
                  pendingDamage:
                      pendingDamageActions.contains(_actionCardKey(action)),
                  blocked: remaining < action.resourceCost ||
                      (_actionIsOnHitOption(action) &&
                          !hasPendingOnHitTrigger) ||
                      spentTimings.contains(action.timing),
                  onTap: () {
                    if (remaining < action.resourceCost) return;
                    _rollPrimaryAction(
                      action,
                      onRollAction,
                      onUseAction,
                      pendingDamage:
                          pendingDamageActions.contains(_actionCardKey(action)),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassResourcePip extends StatelessWidget {
  final int remaining;
  final String label;
  final Color color;

  const _ClassResourcePip({
    required this.remaining,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        '$remaining $label',
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ClassKitActionChip extends StatelessWidget {
  final CombatAction action;
  final Color color;
  final bool pendingDamage;
  final bool blocked;
  final VoidCallback onTap;

  const _ClassKitActionChip({
    required this.action,
    required this.color,
    required this.pendingDamage,
    required this.blocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final effectiveColor = blocked ? tokens.textMuted : color;
    final label = _compactClassKitActionLabel(action);
    final hint = _classKitActionHint(action, pendingDamage, blocked);

    return InkWell(
      onTap: blocked ? null : onTap,
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: Container(
        constraints: const BoxConstraints(minWidth: 118, maxWidth: 176),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: blocked ? 0.08 : 0.14),
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          border: Border.all(
            color: effectiveColor.withValues(alpha: blocked ? 0.18 : 0.34),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, color: effectiveColor, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (hint.isNotEmpty)
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
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

class _CharacterActionAccessRow extends StatelessWidget {
  final String timing;
  final int count;
  final CombatAction? action;
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
  final Combatant combatant;
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

class _GameBattleStage extends StatelessWidget {
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final CombatRollFeedback? rollFeedback;
  final CombatWorkspace workspace;
  final bool showEnemyHp;
  final List<CombatLogEntry> entries;
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
                CombatWorkspace.overview => _EncounterOverviewStage(
                    combatants: combatants,
                    activeIndex: activeIndex,
                    targetIndex: targetIndex,
                    rollFeedback: rollFeedback,
                    showEnemyHp: showEnemyHp,
                  ),
                CombatWorkspace.log => _TurnLogStage(entries: entries),
                CombatWorkspace.turn => _FocusedTurnStage(
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
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final CombatRollFeedback? rollFeedback;
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
  final List<CombatLogEntry> entries;

  const _TurnLogStage({
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return CombatFeedWindow(
      entries: entries,
      maxEntries: 18,
    );
  }
}

class _EncounterOverviewWindow extends StatelessWidget {
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final CombatRollFeedback? rollFeedback;
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
      child: CombatCinematicPanelFrame(
        borderColor: CombatCinematicColors.gold,
        padding: const EdgeInsets.all(14),
        backgroundAlpha: 0.88,
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.groups_2_outlined,
                  color: CombatCinematicColors.goldBright,
                  size: 19,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'RESUMEN DEL ENCUENTRO',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CombatCinematicColors.paper,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                CombatParchmentIconButton(
                  icon: Icons.close,
                  tooltip: 'Cerrar resumen',
                  color: CombatCinematicColors.gold,
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
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final CombatRollFeedback? rollFeedback;
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
    final party = <IndexedCombatant>[];
    final enemies = <IndexedCombatant>[];
    for (var index = 0; index < combatants.length; index++) {
      final entry = IndexedCombatant(index, combatants[index]);
      if (entry.combatant.team == CombatTeam.party) {
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
  final List<IndexedCombatant> entries;
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
  final IndexedCombatant entry;
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
            : combatTeamColor(combatant.team, tokens);
    final showHp = canShowCombatantHp(combatant, showEnemyHp);

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
                        compactCombatantHpLabel(combatant, showEnemyHp),
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
  final CombatRollFeedback? feedback;

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
  final CombatRollFeedback? feedback;
  final Combatant activeCombatant;
  final Combatant selectedTarget;

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
    final actorColor = combatTeamColor(activeCombatant.team, tokens);
    final targetColor = combatTeamColor(selectedTarget.team, tokens);
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
                      '${feedback?.headline ?? 'empty'}-${result?.total ?? 'idle'}-${result?.timestamp.millisecondsSinceEpoch ?? 'static'}',
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
  final CombatRollFeedback? feedback;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
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
                    _TumblingDiceBadge(
                      rollKey:
                          result?.timestamp.millisecondsSinceEpoch.toString() ??
                              'idle',
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
                          CombatDiceExpressionChip(
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
                            CombatDiceExpressionChip(
                              label: result.formula,
                              color: accent,
                            ),
                            CombatDiceExpressionChip(
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
  final Combatant combatant;
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
              child: CombatantArtwork(
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

class _TumblingDiceBadge extends StatelessWidget {
  final String rollKey;
  final int? total;
  final String? formula;
  final Color color;
  final bool compact;
  final int? sides;

  const _TumblingDiceBadge({
    required this.rollKey,
    required this.total,
    required this.formula,
    required this.color,
    required this.compact,
    required this.sides,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(rollKey),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 680),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final t = value.clamp(0.0, 1.0);
        final spin = 1 - t;
        final bounce = math.sin(t * math.pi);
        final wobble = math.sin(t * math.pi * 6) * spin;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0017)
          ..rotateX(spin * math.pi * 1.55 + wobble * 0.16)
          ..rotateY(spin * math.pi * 2.15)
          ..rotateZ(spin * math.pi * 1.35 + wobble * 0.12);

        return Transform.translate(
          offset: Offset(0, -18 * bounce),
          child: Transform(
            transform: matrix,
            alignment: Alignment.center,
            child: Transform.scale(
              scale: 0.92 + (0.08 * Curves.easeOutBack.transform(t)),
              child: child,
            ),
          ),
        );
      },
      child: _LargeDiceBadge(
        total: total,
        formula: formula,
        color: color,
        compact: compact,
        sides: sides,
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
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final Combatant combatant;
  final CombatRollFeedback? rollFeedback;
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
    final accent = combatTeamColor(combatant.team, tokens);
    final impactFeedback = rollFeedback != null &&
            _feedbackMentionsCombatant(rollFeedback!, combatant)
        ? rollFeedback
        : null;
    final impactAccent = impactFeedback == null
        ? accent
        : _accentForKind(impactFeedback.accentKind, tokens);
    final showHp = canShowCombatantHp(combatant, showEnemyHp);
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
              combatPortraitIconForCombatant(combatant),
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
                  combatant.team == CombatTeam.enemy
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
                        CombatantArtwork(
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
                      child: CombatGameMetric(
                        label: 'HP',
                        value: compactCombatantHpLabel(combatant, showEnemyHp),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CombatGameMetric(
                          label: 'AC', value: '${combatant.ac}'),
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
                        return CombatStatusChip(
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
  CombatRollFeedback feedback,
  Combatant combatant,
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
  final CombatRollFeedback feedback;
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

String _targetImpactLabel(CombatRollFeedback feedback) {
  final text = feedback.headline.trim();
  if (text.isEmpty) return 'ROLL';
  if (text.length <= 16) return text;
  return '${text.substring(0, 15)}...';
}

IconData _targetImpactIcon(CombatRollFeedback feedback) {
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
  final List<Combatant> combatants;
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

class _CommandLayerDock extends StatelessWidget {
  final Combatant activeCombatant;
  final List<CombatAction> actions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, int> resourcePool;
  final Map<String, CombatAction> preparedActions;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final ValueChanged<String> onSelectTiming;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
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
  required List<CombatAction> actions,
  required Set<String> spentTimings,
  required Set<String> pendingDamageActions,
  required Map<String, int> resourcePool,
  required Map<String, CombatAction> preparedActions,
  required String selectedTiming,
  required ValueChanged<String> onSelectTiming,
  required void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction,
  required ValueChanged<CombatAction> onUseAction,
  required ValueChanged<CombatAction> onPrepareAction,
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
  final List<CombatAction> actions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, int> resourcePool;
  final Map<String, CombatAction> preparedActions;
  final String initialTiming;
  final ValueChanged<String> onSelectTiming;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;

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
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Free', 'Movement'];
    const categories = ['All', 'Weapons', 'Spells', 'Features', 'Resources'];
    final normalizedQuery = _query.trim().toLowerCase();
    final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
      widget.actions,
      widget.pendingDamageActions,
    );
    final visibleActions = widget.actions
        .where(
          (action) =>
              _actionVisibleInTiming(
                action,
                _selectedTiming,
                hasPendingOnHitTrigger: hasPendingOnHitTrigger,
              ) &&
              !_actionHandledByMonkCombo(action),
        )
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
                    return CombatCatalogFilterChip(
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
                      child: CombatCommandTimingButton(
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
    final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
      widget.actions,
      widget.pendingDamageActions,
    );
    return widget.actions
        .where(
          (action) =>
              _actionVisibleInTiming(
                action,
                _selectedTiming,
                hasPendingOnHitTrigger: hasPendingOnHitTrigger,
              ) &&
              !_actionHandledByMonkCombo(action),
        )
        .where((action) => _matchesCatalogCategory(action, category))
        .length;
  }

  bool _actionVisibleInTiming(
    CombatAction action,
    String timing, {
    required bool hasPendingOnHitTrigger,
  }) {
    return _actionVisibleInActionTiming(
      action,
      timing,
      hasPendingOnHitTrigger: hasPendingOnHitTrigger,
    );
  }

  bool _matchesCatalogCategory(CombatAction action, String category) {
    if (category == 'All') return true;
    final text =
        '${action.name} ${action.type} ${action.tags.join(' ')}'.toLowerCase();
    return switch (category) {
      'Weapons' => text.contains('weapon') ||
          text.contains('melee') ||
          text.contains('ranged'),
      'Spells' => text.contains('spell') ||
          text.contains('cantrip') ||
          action.accentKind == CombatAccentKind.magic,
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

class _CompactActionCommand extends StatelessWidget {
  final CombatAction action;
  final bool isSpent;
  final bool canResolveDamage;
  final bool lacksResource;
  final int? resourceRemaining;
  final bool isPrepared;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;

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
              CombatPrepareActionButton(
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
            _actionCommandSubtitle(action),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          CombatActionAvailabilityLine(
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
              for (final tag in _actionCommandTags(action).take(2))
                CombatDiceExpressionChip(label: tag, color: effectiveAccent),
              if (isSpent)
                CombatDiceExpressionChip(
                    label: 'Spent', color: effectiveAccent),
              if (lacksResource)
                CombatDiceExpressionChip(
                    label: 'No uses', color: effectiveAccent),
              if (canResolveDamage)
                CombatDiceExpressionChip(
                    label: 'Hit confirmed', color: effectiveAccent),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (action.attackFormula != null)
                Expanded(
                  child: CombatTinyRollButton(
                    label: action.attackFormula!,
                    icon: Icons.track_changes_outlined,
                    color: effectiveAccent,
                    enabled: !isBlocked && !canResolveDamage,
                    onTap: () => onRollAction(action, CombatActionRoll.attack),
                  ),
                ),
              if (action.requiresSavingThrow)
                Expanded(
                  child: CombatTinyRollButton(
                    label: '${action.saveAbility} DC ${action.saveDc}',
                    icon: Icons.shield_outlined,
                    color: effectiveAccent,
                    enabled: !isBlocked && !canResolveDamage,
                    onTap: () =>
                        onRollAction(action, CombatActionRoll.savingThrow),
                  ),
                ),
              if ((action.attackFormula != null ||
                      action.requiresSavingThrow) &&
                  action.damageFormula != null)
                const SizedBox(width: 5),
              if (action.damageFormula != null)
                Expanded(
                  child: CombatTinyRollButton(
                    label: action.isHealing ? 'Heal' : action.damageFormula!,
                    icon: action.isHealing
                        ? Icons.favorite_border
                        : Icons.auto_fix_high_outlined,
                    color: effectiveAccent,
                    enabled: !isBlocked || canResolveDamage,
                    onTap: () => onRollAction(action, CombatActionRoll.damage),
                  ),
                ),
              if (action.critFormula != null) ...[
                const SizedBox(width: 5),
                Expanded(
                  child: CombatTinyRollButton(
                    label: 'Crit',
                    icon: Icons.emergency_outlined,
                    color: isSpent ? effectiveAccent : tokens.accentSuccess,
                    enabled: !isBlocked || canResolveDamage,
                    onTap: () =>
                        onRollAction(action, CombatActionRoll.critical),
                  ),
                ),
              ],
              if (action.attackFormula == null &&
                  !action.requiresSavingThrow &&
                  action.damageFormula == null &&
                  action.critFormula == null)
                Expanded(
                  child: CombatTinyRollButton(
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

class _ActionDetailsButton extends StatelessWidget {
  final CombatAction action;
  final Color color;

  const _ActionDetailsButton({
    required this.action,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: () => showCombatActionDetails(context, action),
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
  final Combatant activeCombatant;
  final List<CombatAction> actions;
  final Map<String, CombatAction> preparedActions;
  final Set<String> spentTimings;
  final Set<String> pendingDamageActions;
  final Map<String, int> resourcePool;
  final int queuedPreparedIndex;
  final int queuedPreparedTotal;
  final String? queuedPreparedActionName;
  final String selectedTiming;
  final ValueChanged<String> onSelectTiming;
  final void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction;
  final ValueChanged<CombatAction> onUseAction;
  final ValueChanged<CombatAction> onPrepareAction;
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
    const timings = ['Action', 'Bonus Action', 'Reaction', 'Free', 'Movement'];
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
  final Combatant activeCombatant;

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
  final CombatAction? action;
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
                        CombatDiceExpressionChip(label: tag, color: color),
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

class _PendingSavePrompt extends StatelessWidget {
  final PendingSavePromptData data;
  final VoidCallback onRoll;

  const _PendingSavePrompt({
    required this.data,
    required this.onRoll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.stitch;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.accentMagic.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.accentMagic.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.accentMagic.withValues(alpha: 0.38),
                  ),
                ),
                child: Icon(
                  Icons.shield_moon_outlined,
                  color: theme.accentMagic,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.target.name}: ${data.ability} save DC ${data.dc}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${data.action.name} - ${data.formula} - ${data.remaining} pending',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onRoll,
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: const Text('Roll save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<PendingCombatAttack> _pendingCombatAttacksForAction(
  CombatAction action, {
  String labelPrefix = 'Attack',
  PendingCombatAttackSource source = PendingCombatAttackSource.multiattack,
}) {
  return [
    for (var index = 0; index < action.multiAttackSteps.length; index++)
      PendingCombatAttack(
        stepIndex: index,
        label: '$labelPrefix ${index + 1}',
        source: source,
      ),
  ];
}

Color _accentForKind(CombatAccentKind kind, StitchThemeTokens tokens) {
  return combatAccentColorForKind(kind, tokens);
}

Color _statusAccentForLabel(
  String label,
  StitchThemeTokens tokens,
  Color fallback,
) {
  return combatStatusAccentForLabel(label, tokens, fallback);
}

IconData _statusIconForLabel(String label) {
  return combatStatusIconForLabel(label);
}

String? _combatantPortraitAsset({
  required String name,
  required String role,
  required CombatTeam team,
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

  if (team == CombatTeam.party) {
    final characterClass = match(classes);
    if (characterClass != null) {
      return 'assets/images/classes/$characterClass.png';
    }
  }

  return null;
}

String _preparedActionFormula(CombatAction? action) {
  if (action == null) return 'Open';
  if (action.grantsAction) return '+1 Action';
  if (action.hasMultiAttack) return '${action.multiAttackSteps.length} attacks';
  return action.attackFormula ??
      action.damageFormula ??
      action.critFormula ??
      'Use';
}

int _compactActionCountForTiming(
  List<CombatAction> actions,
  String timing, {
  Set<String> pendingDamageActions = const {},
}) {
  final hasPendingOnHitTrigger = _hasPendingOnHitTrigger(
    actions,
    pendingDamageActions,
  );
  return actions
      .where(
        (action) =>
            _actionVisibleInActionTiming(
              action,
              timing,
              hasPendingOnHitTrigger: hasPendingOnHitTrigger,
            ) &&
            !_actionHandledByMonkCombo(action),
      )
      .length;
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
    'Free' => Icons.auto_awesome_outlined,
    'Movement' => Icons.directions_run_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

List<IndexedCombatant> _indexedTeam(
  List<Combatant> combatants,
  CombatTeam team,
) {
  final entries = <IndexedCombatant>[];
  for (var index = 0; index < combatants.length; index++) {
    if (combatants[index].team == team) {
      entries.add(IndexedCombatant(index, combatants[index]));
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
  CombatAction action,
  void Function(CombatAction action, CombatActionRoll rollType) onRollAction,
  ValueChanged<CombatAction> onUseAction, {
  bool pendingDamage = false,
}) {
  if (_isDeathSavingThrowAction(action)) {
    onRollAction(action, CombatActionRoll.savingThrow);
    return;
  }
  if (action.hasMultiAttack) {
    onRollAction(
      action,
      pendingDamage ? CombatActionRoll.damage : CombatActionRoll.attack,
    );
    return;
  }
  if (pendingDamage && action.damageFormula != null) {
    onRollAction(action, CombatActionRoll.damage);
    return;
  }
  if (action.attackFormula != null) {
    onRollAction(action, CombatActionRoll.attack);
    return;
  }
  if (action.requiresSavingThrow) {
    onRollAction(action, CombatActionRoll.savingThrow);
    return;
  }
  if (action.damageFormula != null) {
    onRollAction(action, CombatActionRoll.damage);
    return;
  }
  onUseAction(action);
}

String _primaryActionLabel(CombatAction action, bool pendingDamage) {
  if (_isDeathSavingThrowAction(action)) return 'Death Save';
  if (action.hasMultiAttack) return pendingDamage ? 'Dano' : 'Ataque';
  if (pendingDamage && action.requiresSavingThrow) return 'Resolver';
  if (pendingDamage && action.damageFormula != null) return 'Dano';
  if (action.attackFormula != null) return 'Tirar';
  if (action.requiresSavingThrow) return 'TS objetivo';
  if (action.damageFormula != null) return action.isHealing ? 'Curar' : 'Dano';
  return 'Usar';
}

bool _isDeathSavingThrowAction(CombatAction action) {
  return action.id == 'system:death_saving_throw';
}

String _primaryActionTooltip(CombatAction action, bool pendingDamage) {
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

String _actionCommandSubtitle(CombatAction action) {
  final text = _rulesLabelText('${action.name} ${action.type}');
  if (text.contains('flurry') ||
      text.contains('patient defense') ||
      text.contains('step of the wind') ||
      text.contains('stunning strike')) {
    return 'Monk technique';
  }
  if (action.isHealing) return 'Support';
  if (action.requiresSavingThrow) return 'Saving throw';
  if (action.attackFormula != null) {
    return action.timing == 'Bonus Action' ? 'Bonus attack' : 'Attack';
  }
  if (action.resourceKey != null && action.resourceCost > 0) {
    return '${_readableActionResourceName(action.resourceKey!)} cost ${action.resourceCost}';
  }
  return action.type;
}

List<String> _actionCommandTags(CombatAction action) {
  final seen = <String>{};
  final result = <String>[];
  for (final tag in action.tags) {
    final normalized = _rulesLabelText(tag);
    if (normalized.isEmpty) continue;
    if (normalized == 'ki' ||
        normalized == 'focus' ||
        normalized == 'monk' ||
        normalized == 'bonus action' ||
        normalized == 'action' ||
        normalized == 'melee' ||
        normalized == 'class feature') {
      continue;
    }
    if (!seen.add(normalized)) continue;
    result.add(tag);
  }
  if (action.resourceKey != null && action.resourceCost > 0) {
    result.insert(0, 'Cost ${action.resourceCost}');
  }
  if (action.rangeFeet != null && action.rangeFeet! > 0) {
    result.add('${action.rangeFeet} ft');
  }
  return result;
}

Color _actionStateColor({
  required bool prepared,
  required bool spent,
  required bool pendingDamage,
  required bool blocked,
  required Color fallback,
}) {
  if (pendingDamage) return const Color(0xFF246B3A);
  if (blocked) return CombatCinematicColors.blood;
  if (prepared) return CombatCinematicColors.goldBright;
  if (spent) return CombatCinematicColors.gold;
  return fallback;
}

String _cinematicActionDescription(
  CombatAction action,
  Combatant activeCombatant,
  Combatant selectedTarget,
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
    final areaText = combatActionAreaText(action);
    final areaSuffix = areaText == null ? '' : ' en $areaText';
    return '${selectedTarget.name} debe superar una salvacion ${action.saveAbility} contra DC ${action.saveDc}$areaSuffix.';
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

String _formatRollFormula(String dice, int modifier) {
  if (modifier == 0) return dice;
  return modifier > 0 ? '$dice+$modifier' : '$dice$modifier';
}

String _monkMartialArtsDie(int monkLevel) {
  if (monkLevel >= 17) return '1d12';
  if (monkLevel >= 11) return '1d10';
  if (monkLevel >= 5) return '1d8';
  return '1d6';
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
