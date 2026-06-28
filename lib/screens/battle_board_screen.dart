import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/battle_scene.dart';
import '../models/board_dice_roll_outcome.dart';
import '../models/board_token.dart';
import '../providers/battle_board_provider.dart';
import '../services/battle_board_dice_roll_sync_service.dart';
import '../services/dice_color_preferences_service.dart';
import '../theme.dart';
import '../utils/image_path_utils.dart';
import '../widgets/battle_board_dice_box_overlay.dart'
    hide BoardDiceRollOutcome;
import '../widgets/battle_board_view.dart';
import '../widgets/stitch_navigation.dart';
import '../features/dice/models/dice_roll_result.dart';
import '../features/dice/widgets/dice_roller_modal.dart';

const _battleBoardEventVisibleDuration = Duration(seconds: 15);

class BattleBoardScreen extends StatefulWidget {
  final String campaignId;
  final String sceneId;
  final bool readOnly;

  const BattleBoardScreen({
    super.key,
    required this.campaignId,
    required this.sceneId,
    this.readOnly = false,
  });

  @override
  State<BattleBoardScreen> createState() => _BattleBoardScreenState();
}

class _BattleBoardScreenState extends State<BattleBoardScreen> {
  String? _watchedSceneKey;
  bool _hudVisible = true;
  bool _setupMode = false;
  bool _savingSetup = false;
  bool _editUnlocked = false;
  bool _multiSelectMode = false;
  String? _selectedMoveTokenId;
  final Set<String> _selectedMoveTokenIds = {};
  BoardToken? _manualRollToken;
  Timer? _manualRollClearTimer;
  Color _diceColor = DiceColorPreferencesService.defaultColor;
  late final String _diceRollOwnerId =
      BattleBoardDiceRollSyncService.createOwnerId();

  BattleBoardDiceRollSyncService get _diceRollSync {
    return BattleBoardDiceRollSyncService(
      boardProvider: context.read<BattleBoardProvider>(),
      campaignId: widget.campaignId,
      ownerId: _diceRollOwnerId,
    );
  }

  @override
  void initState() {
    super.initState();
    _scheduleSceneWatch();
    _loadDiceColorPreference();
  }

  @override
  void didUpdateWidget(covariant BattleBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campaignId != widget.campaignId ||
        oldWidget.sceneId != widget.sceneId) {
      _scheduleSceneWatch();
    }
  }

  void _scheduleSceneWatch() {
    final sceneKey = '${widget.campaignId}/${widget.sceneId}';
    if (_watchedSceneKey == sceneKey) return;
    _watchedSceneKey = sceneKey;
    _selectedMoveTokenId = null;
    _selectedMoveTokenIds.clear();
    _multiSelectMode = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BattleBoardProvider>().watchScene(
            campaignId: widget.campaignId,
            sceneId: widget.sceneId,
          );
    });
  }

  Future<void> _loadDiceColorPreference() async {
    final color = await DiceColorPreferencesService.loadColor();
    if (!mounted) return;
    setState(() {
      _diceColor = color;
    });
  }

  Future<void> _setDiceColor(Color color) async {
    setState(() {
      _diceColor = color;
    });
    await DiceColorPreferencesService.saveColor(color);
  }

  Future<void> _persistDiceRollOutcome(
    BoardToken token,
    BoardDiceRollOutcome outcome,
  ) async {
    if (token.lastEventId.isEmpty) return;
    if (_manualRollToken?.id == token.id) {
      setState(() {
        _manualRollToken = token.copyWith(
          lastEventResultLabel: outcome.label.isEmpty
              ? token.lastEventResultLabel
              : outcome.label,
          lastEventResultDetail: outcome.detail.isEmpty
              ? token.lastEventResultDetail
              : outcome.detail,
          lastEventRollTotal: outcome.total,
          lastEventRollDiceTotal: outcome.diceTotal,
          lastEventRollValues: outcome.values,
        );
      });
      return;
    }

    try {
      await _diceRollSync.saveOutcomeIfClaimed(token, outcome);
    } catch (error) {
      debugPrint(
        '[BattleBoardScreen] Could not persist 3D dice outcome: $error',
      );
    }
  }

  Future<bool> _claimDiceRollEvent(BoardToken token) async {
    if (_manualRollToken?.id == token.id) return true;

    try {
      final claimed = await _diceRollSync.claim(token).timeout(
        const Duration(milliseconds: 1400),
        onTimeout: () {
          debugPrint(
            '[BattleBoardScreen] 3D dice claim timed out; '
            'allowing visible board roll for event ${token.lastEventId}.',
          );
          return true;
        },
      );
      if (!claimed) {
        debugPrint(
          '[BattleBoardScreen] 3D dice claim denied for '
          'event ${token.lastEventId}.',
        );
      }
      return claimed;
    } catch (error) {
      debugPrint(
        '[BattleBoardScreen] Could not claim 3D dice roll; '
        'allowing visible board roll for event ${token.lastEventId}: $error',
      );
      return true;
    }
  }

  @override
  void dispose() {
    _manualRollClearTimer?.cancel();
    super.dispose();
  }

  void _openDiceRoller() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DiceRollerModal(
          initialDiceColor: _diceColor,
          onDiceColorChanged: (color) => unawaited(_setDiceColor(color)),
          onRoll: (result) {
            if (!mounted) return;
            final eventId =
                'manual-roll-${DateTime.now().microsecondsSinceEpoch}';
            setState(() {
              _manualRollToken = BoardToken.create(
                id: eventId,
                sceneId: widget.sceneId,
                refId: 'manual-roll',
                type: 'manual',
                name: 'Manual Roll',
                lastEventLabel: result.formula,
                lastEventKind: 'manual',
                lastEventId: eventId,
                lastEventDiceNotation: result.formula,
                lastEventDiceColorHex:
                    DiceColorPreferencesService.colorToHex(_diceColor),
                lastEventResultLabel: 'Resultado ${result.total}',
                lastEventResultDetail:
                    '${result.label} - ${result.formula}: ${result.rollsText}',
                lastEventAuthoritativeDice:
                    _authoritativeDiceJsonForRollResult(result),
                controlledByUserId: '',
                now: DateTime.now(),
              );
            });
            _manualRollClearTimer?.cancel();
            _manualRollClearTimer = Timer(_battleBoardEventVisibleDuration, () {
              if (!mounted) return;
              setState(() {
                if (_manualRollToken?.lastEventId == eventId) {
                  _manualRollToken = null;
                }
              });
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  String _authoritativeDiceJsonForRollResult(DiceRollResult result) {
    final dice = <Map<String, dynamic>>[];

    if (result.firstD20 != null && result.secondD20 != null) {
      dice.add({
        'sides': 20,
        'value': result.firstD20,
        'selected': result.firstD20 == result.selectedD20,
      });
      dice.add({
        'sides': 20,
        'value': result.secondD20,
        'selected': result.secondD20 == result.selectedD20,
      });
    } else if (result.terms.isNotEmpty) {
      for (final term in result.terms) {
        if (term.sides < 2) continue;
        for (final roll in term.rolls) {
          dice.add({
            'sides': term.sides,
            'value': roll,
            if (term.sign < 0) 'sign': -1,
          });
        }
      }
    } else if (result.sides >= 2) {
      for (final roll in result.rolls) {
        dice.add({
          'sides': result.sides,
          'value': roll,
        });
      }
    }

    return dice.isEmpty ? '' : jsonEncode(dice);
  }

  @override
  Widget build(BuildContext context) {
    final boardProvider = context.watch<BattleBoardProvider>();
    final scene = boardProvider.activeScene;
    final tokens = boardProvider.tokens;
    final visibleTokens =
        tokens.where((token) => token.isVisible).toList(growable: false);
    final activeToken = _activeTokenOf(visibleTokens);
    final targetToken = _targetTokenOf(visibleTokens);
    final eventToken = _latestEventToken(visibleTokens);
    final manualEventToken = _latestEventToken(
      tokens
          .where(
            (token) =>
                token.lastEventLabel.isNotEmpty &&
                token.lastEventId.isNotEmpty &&
                token.lastEventKind.toLowerCase() == 'manual' &&
                token.id != _manualRollToken?.id &&
                token.id != eventToken?.id,
          )
          .toList(growable: false),
    );
    final diceEventToken = _latestEventToken([
      if (eventToken != null) eventToken,
      if (_manualRollToken != null) _manualRollToken!,
      if (manualEventToken != null) manualEventToken,
    ]);
    final selectedTokenId = _selectedMoveTokenId;
    final selectedToken = selectedTokenId == null
        ? null
        : _tokenById(visibleTokens, selectedTokenId);
    final boardReadOnly = widget.readOnly && !_editUnlocked;
    final selectionToolAvailable =
        !boardReadOnly && (_setupMode || _editUnlocked);
    final selectedGroupTokens = visibleTokens
        .where((token) => _selectedMoveTokenIds.contains(token.id))
        .toList(growable: false);
    final allies = _orderedInitiativeTokens(
      visibleTokens.where((token) => !_isEnemyToken(token)),
    );
    final enemies = _orderedInitiativeTokens(
      visibleTokens.where(_isEnemyToken),
    );

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        title: Text(
          scene?.name.toUpperCase() ?? 'TABLERO DE COMBATE',
          style: const TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        backgroundColor: StitchCodexPalette.ground,
        actions: [
          if (scene != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: StitchCodexPalette.surface,
                  border: Border.all(
                    color:
                        StitchCodexPalette.bronzeMuted.withValues(alpha: 0.46),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.readOnly
                          ? _editUnlocked
                              ? Icons.edit_location_alt_outlined
                              : Icons.visibility_outlined
                          : Icons.sports_esports_rounded,
                      size: 14,
                      color: StitchCodexPalette.bronzeBright,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.readOnly
                          ? _editUnlocked
                              ? 'DISPLAY EDIT'
                              : 'DISPLAY'
                          : 'CONTROLADOR',
                      style: const TextStyle(
                        color: StitchCodexPalette.textSecondary,
                        fontFamily: StitchTypography.data,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (boardProvider.error != null) {
            return Center(
              child: Text(
                boardProvider.error!,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (scene == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              Positioned.fill(
                child: BattleBoardView(
                  scene: scene,
                  tokens: tokens,
                  readOnly: boardReadOnly,
                  selectedTokenId: boardReadOnly ? null : _selectedMoveTokenId,
                  selectedTokenIds:
                      boardReadOnly ? const {} : _selectedMoveTokenIds,
                  selectionEnabled: selectionToolAvailable && _multiSelectMode,
                  onSelectionChanged: (tokenIds) {
                    setState(() {
                      _selectedMoveTokenIds
                        ..clear()
                        ..addAll(tokenIds);
                      _selectedMoveTokenId =
                          tokenIds.isEmpty ? null : tokenIds.first;
                    });
                  },
                  onTokenTap: boardReadOnly
                      ? null
                      : (token) => _handleBoardTokenTap(
                            boardProvider,
                            scene,
                            token,
                          ),
                  onBoardCellTap: boardReadOnly
                      ? null
                      : (x, y) => _moveSelectedBoardToken(
                            boardProvider,
                            scene,
                            x,
                            y,
                          ),
                  onMoveToken: boardReadOnly
                      ? null
                      : (token, x, y) {
                          return _moveBoardTokenFromSurface(
                            boardProvider,
                            scene,
                            token,
                            x,
                            y,
                          );
                        },
                  enableDiceOverlay: false,
                  manualRollToken: _manualRollToken,
                  onDiceRollClaimRequested: _claimDiceRollEvent,
                  onDiceRollResolved: _persistDiceRollOutcome,
                ),
              ),
              if (kIsWeb && _shouldShowBoardDiceStage(diceEventToken))
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 52,
                  child: _BoardDiceOverlayStage(
                    scene: scene,
                    token: diceEventToken,
                    onRollClaimRequested: _claimDiceRollEvent,
                    onRollResolved: _persistDiceRollOutcome,
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_hudVisible,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _hudVisible ? 1 : 0,
                    child: _BoardTacticalHud(
                      allies: allies,
                      enemies: enemies,
                      activeToken: activeToken,
                      targetToken: targetToken,
                      eventToken: eventToken,
                      onSelectToken: boardReadOnly
                          ? null
                          : (token) => _handleBoardTokenTap(
                                boardProvider,
                                scene,
                                token,
                              ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 18,
                child: _BoardToolsDock(
                  hudVisible: _hudVisible,
                  setupMode: _setupMode,
                  readOnly: widget.readOnly,
                  editUnlocked: _editUnlocked,
                  multiSelectMode: _multiSelectMode,
                  canToggleMultiSelect: selectionToolAvailable,
                  canRemoveSelectedToken: !boardReadOnly &&
                      selectedToken != null &&
                      selectedGroupTokens.length <= 1,
                  selectedTokenName: selectedToken?.name,
                  onToggleHud: () {
                    setState(() {
                      _hudVisible = !_hudVisible;
                    });
                  },
                  onToggleSetup: widget.readOnly
                      ? null
                      : () {
                          setState(() {
                            _setupMode = !_setupMode;
                            if (!_setupMode) {
                              _multiSelectMode = false;
                              _selectedMoveTokenIds.clear();
                            }
                            if (_setupMode) _hudVisible = true;
                          });
                        },
                  onToggleEdit: widget.readOnly
                      ? () {
                          setState(() {
                            _editUnlocked = !_editUnlocked;
                            if (!_editUnlocked) {
                              _selectedMoveTokenId = null;
                              _selectedMoveTokenIds.clear();
                              _multiSelectMode = false;
                            }
                            if (_editUnlocked) _hudVisible = true;
                          });
                        }
                      : null,
                  onToggleMultiSelect: !selectionToolAvailable
                      ? null
                      : () {
                          setState(() {
                            _multiSelectMode = !_multiSelectMode;
                            if (!_multiSelectMode) {
                              _selectedMoveTokenIds.clear();
                            }
                          });
                        },
                  onOpenDiceRoller: _openDiceRoller,
                  onRemoveSelectedToken: selectedToken == null
                      ? null
                      : () => _confirmRemoveBoardToken(
                            boardProvider,
                            scene,
                            selectedToken,
                          ),
                ),
              ),
              if (!boardReadOnly && selectedGroupTokens.length > 1)
                Positioned(
                  right: 18,
                  bottom: 78,
                  child: _BoardSelectedGroupPanel(
                    tokens: selectedGroupTokens,
                    onClear: () {
                      setState(() {
                        _selectedMoveTokenIds.clear();
                        _selectedMoveTokenId = null;
                      });
                    },
                  ),
                )
              else if (!boardReadOnly && selectedToken != null)
                Positioned(
                  right: 18,
                  bottom: 78,
                  child: _BoardSelectedTokenPanel(
                    token: selectedToken,
                    onRemove: () => _confirmRemoveBoardToken(
                      boardProvider,
                      scene,
                      selectedToken,
                    ),
                  ),
                ),
              if (_setupMode && !widget.readOnly)
                Positioned(
                  left: 18,
                  bottom: 18,
                  child: _BoardSetupPanel(
                    scene: scene,
                    saving: _savingSetup,
                    onChanged: (nextScene) => _saveSceneSettings(
                      boardProvider,
                      nextScene,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _handleBoardTokenTap(
    BattleBoardProvider boardProvider,
    BattleScene scene,
    BoardToken selected,
  ) {
    if (_multiSelectMode) {
      setState(() {
        if (_selectedMoveTokenIds.contains(selected.id)) {
          _selectedMoveTokenIds.remove(selected.id);
        } else {
          _selectedMoveTokenIds.add(selected.id);
        }
        _selectedMoveTokenId =
            _selectedMoveTokenIds.isEmpty ? null : _selectedMoveTokenIds.first;
      });
      return;
    }

    setState(() {
      _selectedMoveTokenId = selected.id;
      _selectedMoveTokenIds
        ..clear()
        ..add(selected.id);
    });
    unawaited(_selectBoardTarget(boardProvider, scene, selected));
  }

  Future<void> _confirmRemoveBoardToken(
    BattleBoardProvider boardProvider,
    BattleScene scene,
    BoardToken token,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Retirar ${token.name}?'),
          content: const Text(
            'La ficha se borrara del tablero, pero no se eliminara del combate. '
            'Usalo cuando el DM quiera limpiar una criatura caida o removida de la escena.',
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
      campaignId: scene.campaignId,
      sceneId: scene.id,
      tokenId: token.id,
    );
    if (!mounted) return;
    setState(() {
      if (_selectedMoveTokenId == token.id) {
        _selectedMoveTokenId = null;
      }
      _selectedMoveTokenIds.remove(token.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${token.name} fue retirada del tablero.')),
    );
  }

  Future<void> _moveSelectedBoardToken(
    BattleBoardProvider boardProvider,
    BattleScene scene,
    int x,
    int y,
  ) async {
    final selectedTokenId = _selectedMoveTokenId;
    final sceneTokens = boardProvider.tokens
        .where((token) => token.sceneId == scene.id)
        .toList(growable: false);
    final selectedGroup = sceneTokens
        .where((token) => _selectedMoveTokenIds.contains(token.id))
        .toList(growable: false);
    if (selectedGroup.length > 1) {
      await _moveBoardTokenFormation(
        boardProvider,
        scene,
        selectedGroup,
        x,
        y,
      );
      return;
    }
    final selected = selectedTokenId == null
        ? null
        : _tokenById(sceneTokens, selectedTokenId);
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una ficha y luego una casilla vacia.'),
        ),
      );
      return;
    }

    await _moveBoardTokenFromSurface(boardProvider, scene, selected, x, y);
  }

  Future<void> _moveBoardTokenFormation(
    BattleBoardProvider boardProvider,
    BattleScene scene,
    List<BoardToken> selectedTokens,
    int x,
    int y,
  ) async {
    if (!(_setupMode || _editUnlocked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El movimiento de grupo esta disponible en setup.'),
        ),
      );
      return;
    }
    if (selectedTokens.length <= 1) return;

    final minX = selectedTokens.map((token) => token.x).reduce(math.min);
    final minY = selectedTokens.map((token) => token.y).reduce(math.min);
    final maxX =
        selectedTokens.map((token) => token.x + token.size).reduce(math.max);
    final maxY =
        selectedTokens.map((token) => token.y + token.size).reduce(math.max);
    var dx = x - minX;
    var dy = y - minY;
    dx = dx.clamp(-minX, scene.gridColumns - maxX).toInt();
    dy = dy.clamp(-minY, scene.gridRows - maxY).toInt();
    if (dx == 0 && dy == 0) return;

    final selectedIds = selectedTokens.map((token) => token.id).toSet();
    final otherTokens = boardProvider.tokens
        .where(
          (token) =>
              token.sceneId == scene.id &&
              token.isVisible &&
              !selectedIds.contains(token.id),
        )
        .toList(growable: false);
    for (final token in selectedTokens) {
      final moved = token.copyWith(x: token.x + dx, y: token.y + dy);
      if (otherTokens.any((other) => _tokensOverlap(moved, other))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La formacion no puede solaparse con otra ficha.'),
          ),
        );
        return;
      }
    }

    final movedTokens = selectedTokens
        .map(
          (token) => token.copyWith(
            x: token.x + dx,
            y: token.y + dy,
            movementUsedFeet: 0,
            movementOriginX: token.x + dx,
            movementOriginY: token.y + dy,
          ),
        )
        .toList(growable: false);

    await _saveMovedTokensAndRefreshRange(
      boardProvider,
      scene,
      movedTokens,
    );
  }

  Future<void> _selectBoardTarget(
    BattleBoardProvider boardProvider,
    BattleScene scene,
    BoardToken selected,
  ) async {
    final sceneTokens = boardProvider.tokens
        .where((token) => token.sceneId == scene.id)
        .toList(growable: false);
    final activeToken = _activeTokenOf(sceneTokens);
    if (activeToken == null || selected.id == activeToken.id) return;

    final distanceFeet = _distanceFeet(activeToken, selected);
    final actionRangeFeet = activeToken.selectedActionRangeFeet;
    final inRange = actionRangeFeet == 0 || distanceFeet <= actionRangeFeet;

    for (final token in sceneTokens) {
      final isTargeted = token.id == selected.id;
      final carriesTargetMetric = token.id == activeToken.id || isTargeted;
      final next = token.copyWith(
        isTargeted: isTargeted,
        targetDistanceFeet: carriesTargetMetric ? distanceFeet : 0,
        isTargetInRange: carriesTargetMetric ? inRange : true,
        lastEventLabel: isTargeted ? token.lastEventLabel : '',
        lastEventKind: isTargeted ? token.lastEventKind : '',
        lastEventId: isTargeted ? token.lastEventId : '',
        lastEventDiceNotation: isTargeted ? token.lastEventDiceNotation : '',
        lastEventDiceColorHex: isTargeted ? token.lastEventDiceColorHex : '',
        lastEventResultLabel: isTargeted ? token.lastEventResultLabel : '',
        lastEventResultDetail: isTargeted ? token.lastEventResultDetail : '',
        lastEventAuthoritativeDice:
            isTargeted ? token.lastEventAuthoritativeDice : '',
        lastEventDamageType: isTargeted ? token.lastEventDamageType : '',
        lastEventSourceRefId: isTargeted ? token.lastEventSourceRefId : '',
        lastEventPrimaryTargetRefId:
            isTargeted ? token.lastEventPrimaryTargetRefId : '',
        lastEventAffectedRefIds:
            isTargeted ? token.lastEventAffectedRefIds : const [],
        lastEventAreaShape: isTargeted ? token.lastEventAreaShape : '',
        lastEventAreaFeet: isTargeted ? token.lastEventAreaFeet : 0,
        lastEventAreaTargetX: isTargeted ? token.lastEventAreaTargetX : -1,
        lastEventAreaTargetY: isTargeted ? token.lastEventAreaTargetY : -1,
      );
      if (next.isTargeted == token.isTargeted &&
          next.targetDistanceFeet == token.targetDistanceFeet &&
          next.isTargetInRange == token.isTargetInRange &&
          next.lastEventLabel == token.lastEventLabel &&
          next.lastEventKind == token.lastEventKind &&
          next.lastEventId == token.lastEventId &&
          next.lastEventDiceNotation == token.lastEventDiceNotation &&
          next.lastEventDiceColorHex == token.lastEventDiceColorHex &&
          next.lastEventResultLabel == token.lastEventResultLabel &&
          next.lastEventResultDetail == token.lastEventResultDetail &&
          next.lastEventAuthoritativeDice == token.lastEventAuthoritativeDice &&
          next.lastEventDamageType == token.lastEventDamageType &&
          next.lastEventSourceRefId == token.lastEventSourceRefId &&
          next.lastEventPrimaryTargetRefId ==
              token.lastEventPrimaryTargetRefId &&
          _stringListsMatch(
            next.lastEventAffectedRefIds,
            token.lastEventAffectedRefIds,
          ) &&
          next.lastEventAreaShape == token.lastEventAreaShape &&
          next.lastEventAreaFeet == token.lastEventAreaFeet &&
          next.lastEventAreaTargetX == token.lastEventAreaTargetX &&
          next.lastEventAreaTargetY == token.lastEventAreaTargetY) {
        continue;
      }
      await boardProvider.saveToken(campaignId: scene.campaignId, token: next);
    }
  }

  Future<void> _moveBoardTokenFromSurface(
    BattleBoardProvider boardProvider,
    BattleScene scene,
    BoardToken token,
    int x,
    int y,
  ) async {
    final maxX = math.max(0, scene.gridColumns - token.size);
    final maxY = math.max(0, scene.gridRows - token.size);
    final nextX = x.clamp(0, maxX).toInt();
    final nextY = y.clamp(0, maxY).toInt();

    if (_setupMode || _editUnlocked) {
      final moved = token.copyWith(
        x: nextX,
        y: nextY,
        movementUsedFeet: 0,
        movementOriginX: nextX,
        movementOriginY: nextY,
      );
      await _saveMovedTokenAndRefreshRange(
        boardProvider,
        scene,
        moved,
      );
      return;
    }

    final movementUsed = token.movementUsedFeet;
    final originX = movementUsed <= 0 ? token.x : token.movementOriginX;
    final originY = movementUsed <= 0 ? token.y : token.movementOriginY;
    final nextMovementUsed =
        math.max((nextX - originX).abs(), (nextY - originY).abs()) * 5;
    if (nextMovementUsed > token.speedFeet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${token.name} no puede moverse mas este turno.'),
        ),
      );
      return;
    }

    final moved = token.copyWith(
      x: nextX,
      y: nextY,
      movementUsedFeet: nextMovementUsed,
      movementOriginX: originX,
      movementOriginY: originY,
    );
    await _saveMovedTokenAndRefreshRange(
      boardProvider,
      scene,
      moved,
    );
  }

  Future<void> _saveMovedTokenAndRefreshRange(
    BattleBoardProvider boardProvider,
    BattleScene scene,
    BoardToken movedToken,
  ) async {
    await _saveMovedTokensAndRefreshRange(
      boardProvider,
      scene,
      [movedToken],
    );
  }

  Future<void> _saveMovedTokensAndRefreshRange(
    BattleBoardProvider boardProvider,
    BattleScene scene,
    List<BoardToken> movedTokens,
  ) async {
    if (movedTokens.isEmpty) return;
    final movedById = {
      for (final token in movedTokens) token.id: token,
    };
    final sceneTokens = boardProvider.tokens
        .where((token) => token.sceneId == scene.id)
        .map((token) => movedById[token.id] ?? token)
        .toList(growable: false);
    final activeToken = _activeTokenOf(sceneTokens);
    final targetToken = _targetTokenOf(sceneTokens);
    final distanceFeet = activeToken == null || targetToken == null
        ? 0
        : _distanceFeet(activeToken, targetToken);
    final actionRangeFeet = activeToken?.selectedActionRangeFeet ?? 0;
    final inRange = activeToken == null ||
        targetToken == null ||
        actionRangeFeet == 0 ||
        distanceFeet <= actionRangeFeet;

    for (final token in sceneTokens) {
      final carriesTargetMetric = activeToken != null &&
          targetToken != null &&
          (token.id == activeToken.id || token.id == targetToken.id);
      final next = token.copyWith(
        targetDistanceFeet: carriesTargetMetric ? distanceFeet : 0,
        isTargetInRange: carriesTargetMetric ? inRange : true,
      );
      if (next.x == token.x &&
          next.y == token.y &&
          next.movementUsedFeet == token.movementUsedFeet &&
          next.movementOriginX == token.movementOriginX &&
          next.movementOriginY == token.movementOriginY &&
          next.targetDistanceFeet == token.targetDistanceFeet &&
          next.isTargetInRange == token.isTargetInRange) {
        continue;
      }
      await boardProvider.saveToken(campaignId: scene.campaignId, token: next);
    }
  }

  Future<void> _saveSceneSettings(
    BattleBoardProvider boardProvider,
    BattleScene scene,
  ) async {
    if (_savingSetup) return;
    setState(() {
      _savingSetup = true;
    });
    try {
      await boardProvider.saveScene(scene);
    } finally {
      if (mounted) {
        setState(() {
          _savingSetup = false;
        });
      }
    }
  }
}

class _BoardTacticalHud extends StatelessWidget {
  final List<BoardToken> allies;
  final List<BoardToken> enemies;
  final BoardToken? activeToken;
  final BoardToken? targetToken;
  final BoardToken? eventToken;
  final ValueChanged<BoardToken>? onSelectToken;

  const _BoardTacticalHud({
    required this.allies,
    required this.enemies,
    required this.activeToken,
    required this.targetToken,
    required this.eventToken,
    required this.onSelectToken,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final focusWidth =
            ((constraints.maxWidth - 36) / 2).clamp(150.0, 310.0).toDouble();
        final initiative = [...allies, ...enemies]..sort((a, b) {
            final compare = b.initiative.compareTo(a.initiative);
            if (compare != 0) return compare;
            if (a.isActive) return -1;
            if (b.isActive) return 1;
            return a.name.compareTo(b.name);
          });
        return Stack(
          children: [
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              height: 62,
              child: _BoardInitiativeStrip(
                tokens: initiative,
                onSelectToken: onSelectToken,
              ),
            ),
            Positioned(
              top: 82,
              left: 12,
              child: _BoardFocusCard(
                label: 'Turno',
                token: activeToken,
                icon: Icons.bolt_rounded,
                accent: StitchCodexPalette.success,
                width: focusWidth,
              ),
            ),
            Positioned(
              top: 82,
              right: 12,
              child: _BoardFocusCard(
                label: 'Objetivo',
                token: targetToken,
                icon: targetToken?.isTargetInRange == false
                    ? Icons.warning_amber_rounded
                    : Icons.center_focus_strong_rounded,
                accent: targetToken?.isTargetInRange == false
                    ? StitchCodexPalette.crimsonBright
                    : StitchCodexPalette.bronzeBright,
                width: focusWidth,
              ),
            ),
            if (!kIsWeb)
              Positioned(
                top: 156,
                left: _centeredOverlayLeft(constraints.maxWidth),
                width: _centeredOverlayWidth(constraints.maxWidth),
                child: _BoardDiceToast(token: eventToken),
              ),
          ],
        );
      },
    );
  }
}

class _BoardDiceOverlayStage extends StatelessWidget {
  final BattleScene scene;
  final BoardToken? token;
  final Future<bool> Function(BoardToken token)? onRollClaimRequested;
  final FutureOr<void> Function(BoardToken token, BoardDiceRollOutcome outcome)?
      onRollResolved;

  const _BoardDiceOverlayStage({
    required this.scene,
    required this.token,
    required this.onRollClaimRequested,
    required this.onRollResolved,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedToken = token;
    if (!_shouldShowBoardDiceStage(resolvedToken)) {
      return const SizedBox.shrink();
    }

    final isPending = resolvedToken!.lastEventRollValues.isEmpty;
    final accent = isPending
        ? StitchCodexPalette.bronzeBright
        : StitchCodexPalette.success;
    final resultLabel = resolvedToken.lastEventResultLabel.trim();

    return IgnorePointer(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SizedBox(
            height: 390,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StitchCodexPalette.ground.withValues(alpha: 0.58),
                border: Border.all(color: accent.withValues(alpha: 0.58)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 34,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: StitchCodexPalette.surface.withValues(alpha: 0.78),
                      border: Border(
                        bottom: BorderSide(
                          color: StitchCodexPalette.bronzeMuted
                              .withValues(alpha: 0.40),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPending
                              ? Icons.casino_rounded
                              : Icons.check_circle_outline_rounded,
                          color: accent,
                          size: 18,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            isPending
                                ? 'TIRADA EN CURSO'
                                : (resultLabel.isEmpty
                                    ? 'TIRADA RESUELTA'
                                    : resultLabel.toUpperCase()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accent,
                              fontFamily: StitchTypography.display,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Text(
                          resolvedToken.lastEventDiceNotation.toUpperCase(),
                          style: const TextStyle(
                            color: StitchCodexPalette.textSecondary,
                            fontFamily: StitchTypography.data,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: BattleBoardDiceBoxOverlay(
                        key: ValueKey('dice-box-stage-${scene.id}'),
                        boardViewportId: '${scene.id}-dice-stage',
                        token: resolvedToken,
                        gridSize: scene.gridSize.toDouble(),
                        onRollClaimRequested: onRollClaimRequested,
                        onRollResolved: onRollResolved,
                      ),
                    ),
                  ),
                  Container(
                    height: 28,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: StitchCodexPalette.surfaceMuted
                          .withValues(alpha: 0.48),
                      border: Border(
                        top: BorderSide(
                          color: StitchCodexPalette.textFaint
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    child: Text(
                      isPending
                          ? resolvedToken.lastEventLabel
                          : resolvedToken.lastEventResultDetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.body,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardInitiativeStrip extends StatelessWidget {
  final List<BoardToken> tokens;
  final ValueChanged<BoardToken>? onSelectToken;

  const _BoardInitiativeStrip({
    required this.tokens,
    required this.onSelectToken,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StitchCodexPalette.ground.withValues(alpha: 0.92),
        border: Border.all(
          color: StitchCodexPalette.bronzeMuted.withValues(alpha: 0.48),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 104,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: StitchCodexPalette.surface,
              border: Border(
                right: BorderSide(
                  color: StitchCodexPalette.textFaint.withValues(alpha: 0.78),
                ),
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INICIATIVA',
                  style: TextStyle(
                    color: StitchCodexPalette.bronzeBright,
                    fontFamily: StitchTypography.display,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'ORDEN DE TURNO',
                  style: TextStyle(
                    color: StitchCodexPalette.textMuted,
                    fontFamily: StitchTypography.data,
                    fontSize: 6.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tokens.isEmpty
                ? const Center(
                    child: Text(
                      'Sin combatientes',
                      style: TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.body,
                        fontSize: 10,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 6,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: tokens.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 5),
                    itemBuilder: (context, index) {
                      final token = tokens[index];
                      return _BoardInitiativeStripTile(
                        token: token,
                        position: index + 1,
                        onTap: onSelectToken == null
                            ? null
                            : () => onSelectToken!(token),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BoardInitiativeStripTile extends StatelessWidget {
  final BoardToken token;
  final int position;
  final VoidCallback? onTap;

  const _BoardInitiativeStripTile({
    required this.token,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enemy = _isEnemyToken(token);
    final color = token.isActive
        ? StitchCodexPalette.success
        : token.isTargeted
            ? StitchCodexPalette.bronzeBright
            : enemy
                ? StitchCodexPalette.crimsonBright
                : StitchCodexPalette.cold;

    return InkWell(
      onTap: onTap,
      child: Container(
        width: 142,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: token.isActive
              ? color.withValues(alpha: 0.15)
              : StitchCodexPalette.card.withValues(alpha: 0.84),
          border: Border.all(
            color: color.withValues(alpha: token.isActive ? 0.88 : 0.34),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _BoardTokenAvatar(
                  token: token,
                  size: 34,
                  showHpBar: false,
                ),
                Positioned(
                  left: -3,
                  top: -3,
                  child: Container(
                    width: 13,
                    height: 13,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: StitchCodexPalette.ground,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$position',
                      style: const TextStyle(
                        color: StitchCodexPalette.bronzeBright,
                        fontFamily: StitchTypography.data,
                        fontSize: 6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.display,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _MiniHpBar(token: token),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${token.initiative}',
              style: TextStyle(
                color: color,
                fontFamily: StitchTypography.data,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardFocusCard extends StatelessWidget {
  final String label;
  final BoardToken? token;
  final IconData icon;
  final Color accent;
  final double width;

  const _BoardFocusCard({
    required this.label,
    required this.token,
    required this.icon,
    required this.accent,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedToken = token;
    final compact = width < 220;
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StitchCodexPalette.surfaceMuted.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: accent.withValues(alpha: 0.48)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: resolvedToken == null
              ? Row(
                  children: [
                    Icon(icon, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$label pendiente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: StitchCodexPalette.textPrimary,
                          fontFamily: StitchTypography.display,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _BoardTokenAvatar(
                      token: resolvedToken,
                      size: compact ? 34 : 42,
                    ),
                    SizedBox(width: compact ? 7 : 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: accent, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                label.toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontFamily: StitchTypography.data,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            resolvedToken.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: StitchCodexPalette.textPrimary,
                              fontFamily: StitchTypography.display,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (compact)
                            Text(
                              '${resolvedToken.currentHp}/${resolvedToken.maxHp} HP'
                              '${resolvedToken.targetDistanceFeet > 0 ? ' - ${resolvedToken.targetDistanceFeet} FT' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: StitchCodexPalette.textMuted,
                                fontFamily: StitchTypography.data,
                                fontSize: 7,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _BoardMetricPill(
                                  icon: Icons.favorite_rounded,
                                  label:
                                      '${resolvedToken.currentHp}/${resolvedToken.maxHp}',
                                  color: _hpColor(resolvedToken.hpRatio),
                                ),
                                _BoardMetricPill(
                                  icon: Icons.casino_rounded,
                                  label: '${resolvedToken.initiative}',
                                  color: StitchCodexPalette.bronzeBright,
                                ),
                                if (resolvedToken.isActive)
                                  _BoardMetricPill(
                                    icon: Icons.directions_run_rounded,
                                    label:
                                        '${resolvedToken.remainingMovementFeet}/${resolvedToken.speedFeet} ft',
                                    color: StitchCodexPalette.success,
                                  ),
                                if (resolvedToken.isTargeted &&
                                    resolvedToken.targetDistanceFeet > 0)
                                  _BoardMetricPill(
                                    icon: Icons.straighten_rounded,
                                    label:
                                        '${resolvedToken.targetDistanceFeet} ft',
                                    color: resolvedToken.isTargetInRange
                                        ? StitchCodexPalette.bronzeBright
                                        : StitchCodexPalette.crimsonBright,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BoardDiceToast extends StatelessWidget {
  final BoardToken? token;

  const _BoardDiceToast({required this.token});

  @override
  Widget build(BuildContext context) {
    final resolvedToken = token;
    if (resolvedToken == null || resolvedToken.lastEventLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = _eventColor(
      resolvedToken.lastEventKind,
      resolvedToken.lastEventDamageType,
    );
    final toastKey = ValueKey(
      '${resolvedToken.id}-${resolvedToken.lastEventLabel}-${resolvedToken.updatedAt.microsecondsSinceEpoch}',
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: TweenAnimationBuilder<double>(
        key: toastKey,
        duration: const Duration(milliseconds: 720),
        tween: Tween(begin: 0, end: 1),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final eased = Curves.easeOutBack.transform(value.clamp(0, 1));
          return Opacity(
            opacity: value.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, -52 * (1 - eased)),
              child: Transform.rotate(
                angle: -0.35 * (1 - eased),
                child: child,
              ),
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: StitchCodexPalette.surfaceMuted.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color.withValues(alpha: 0.58)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.24),
                blurRadius: 12,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FallingDiceIcon(color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${resolvedToken.lastEventLabel} sobre ${resolvedToken.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.display,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
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

class _FallingDiceIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _FallingDiceIcon({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.casino_rounded, color: color, size: size),
        Positioned(
          right: -8,
          top: -5,
          child: Icon(
            Icons.casino_rounded,
            color: color.withValues(alpha: 0.62),
            size: size * 0.64,
          ),
        ),
        Positioned(
          left: -7,
          bottom: -4,
          child: Icon(
            Icons.casino_rounded,
            color: color.withValues(alpha: 0.40),
            size: size * 0.54,
          ),
        ),
      ],
    );
  }
}

class _BoardToolsDock extends StatelessWidget {
  final bool hudVisible;
  final bool setupMode;
  final bool readOnly;
  final bool editUnlocked;
  final bool multiSelectMode;
  final bool canToggleMultiSelect;
  final bool canRemoveSelectedToken;
  final String? selectedTokenName;
  final VoidCallback onToggleHud;
  final VoidCallback? onToggleSetup;
  final VoidCallback? onToggleEdit;
  final VoidCallback? onToggleMultiSelect;
  final VoidCallback? onOpenDiceRoller;
  final VoidCallback? onRemoveSelectedToken;

  const _BoardToolsDock({
    required this.hudVisible,
    required this.setupMode,
    required this.readOnly,
    required this.editUnlocked,
    required this.multiSelectMode,
    required this.canToggleMultiSelect,
    required this.canRemoveSelectedToken,
    required this.selectedTokenName,
    required this.onToggleHud,
    required this.onToggleSetup,
    required this.onToggleEdit,
    required this.onToggleMultiSelect,
    this.onOpenDiceRoller,
    this.onRemoveSelectedToken,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StitchCodexPalette.surfaceMuted.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronzeMuted.withValues(alpha: 0.48),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 9,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundToolButton(
              tooltip: hudVisible ? 'Ocultar HUD' : 'Mostrar HUD',
              icon: hudVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              active: hudVisible,
              onPressed: onToggleHud,
            ),
            if (canRemoveSelectedToken) ...[
              const SizedBox(width: 6),
              _RoundToolButton(
                tooltip: selectedTokenName == null
                    ? 'Retirar ficha'
                    : 'Retirar $selectedTokenName del tablero',
                icon: Icons.delete_outline_rounded,
                active: false,
                danger: true,
                onPressed: onRemoveSelectedToken,
              ),
            ],
            if (readOnly) ...[
              const SizedBox(width: 6),
              _RoundToolButton(
                tooltip: editUnlocked
                    ? 'Bloquear movimiento'
                    : 'Mover fichas desde el board',
                icon: editUnlocked
                    ? Icons.lock_open_rounded
                    : Icons.edit_location_alt_outlined,
                active: editUnlocked,
                onPressed: onToggleEdit,
              ),
            ],
            if (!readOnly) ...[
              const SizedBox(width: 6),
              _RoundToolButton(
                tooltip: 'Abrir roller de dados',
                icon: Icons.casino_rounded,
                active: false,
                onPressed: onOpenDiceRoller,
              ),
              const SizedBox(width: 6),
              _RoundToolButton(
                tooltip: multiSelectMode
                    ? 'Cerrar seleccion multiple'
                    : 'Seleccion multiple',
                icon: Icons.select_all_rounded,
                active: multiSelectMode,
                onPressed: canToggleMultiSelect ? onToggleMultiSelect : null,
              ),
              const SizedBox(width: 6),
              _RoundToolButton(
                tooltip: setupMode ? 'Cerrar setup' : 'Setup',
                icon: Icons.tune_rounded,
                active: setupMode,
                onPressed: onToggleSetup,
              ),
            ],
            if (readOnly && editUnlocked) ...[
              const SizedBox(width: 6),
              _RoundToolButton(
                tooltip: multiSelectMode
                    ? 'Cerrar seleccion multiple'
                    : 'Seleccion multiple',
                icon: Icons.select_all_rounded,
                active: multiSelectMode,
                onPressed: canToggleMultiSelect ? onToggleMultiSelect : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BoardSelectedTokenPanel extends StatelessWidget {
  final BoardToken token;
  final VoidCallback onRemove;

  const _BoardSelectedTokenPanel({
    required this.token,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final accent = token.currentHp <= 0
        ? StitchCodexPalette.crimsonBright
        : StitchCodexPalette.bronzeBright;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StitchCodexPalette.surfaceMuted.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: accent.withValues(alpha: 0.36)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.36),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BoardTokenAvatar(token: token, size: 38, showHpBar: false),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textPrimary,
                        fontFamily: StitchTypography.display,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      token.currentHp <= 0
                          ? 'Caido o retirado de escena'
                          : 'Ficha seleccionada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.body,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: StitchCodexPalette.crimson,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Retirar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardSelectedGroupPanel extends StatelessWidget {
  final List<BoardToken> tokens;
  final VoidCallback onClear;

  const _BoardSelectedGroupPanel({
    required this.tokens,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final enemyCount = tokens.where(_isEnemyToken).length;
    final allyCount = tokens.length - enemyCount;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StitchCodexPalette.surfaceMuted.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: StitchCodexPalette.bronzeBright.withValues(alpha: 0.42),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.36),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.select_all_rounded,
                color: StitchCodexPalette.bronzeBright,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tokens.length} fichas seleccionadas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textPrimary,
                        fontFamily: StitchTypography.display,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca una casilla vacia para mover la formacion. $allyCount aliados / $enemyCount enemigos.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.body,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Limpiar seleccion',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundToolButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final bool danger;
  final VoidCallback? onPressed;

  const _RoundToolButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    this.danger = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? StitchCodexPalette.crimsonBright
        : active
            ? StitchCodexPalette.success
            : StitchCodexPalette.bronzeBright;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: active || danger ? 0.14 : 0.07),
            border: Border.all(color: color.withValues(alpha: 0.34)),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
      ),
    );
  }
}

class _BoardSetupPanel extends StatelessWidget {
  final BattleScene scene;
  final bool saving;
  final ValueChanged<BattleScene> onChanged;

  const _BoardSetupPanel({
    required this.scene,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mapOptions = _mapOptionsFor(scene.mapImageUrl);
    final currentMap =
        mapOptions.any((option) => option.path == scene.mapImageUrl)
            ? scene.mapImageUrl
            : mapOptions.first.path;

    return SizedBox(
      width: 360,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StitchCodexPalette.surfaceMuted.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: StitchCodexPalette.bronzeMuted.withValues(alpha: 0.48),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.44),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: StitchCodexPalette.bronzeBright,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'CONFIGURACION DEL TABLERO',
                      style: TextStyle(
                        color: StitchCodexPalette.textPrimary,
                        fontFamily: StitchTypography.display,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (saving)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _BoardMapSetupSection(
                scene: scene,
                currentMapLabel: mapOptions
                    .firstWhere((option) => option.path == currentMap)
                    .label,
                saving: saving,
                onChanged: onChanged,
              ),
              const SizedBox(height: 14),
              _BoardStepperRow(
                label: 'Grilla',
                value: '${scene.gridSize}px',
                icon: Icons.grid_4x4_rounded,
                onDecrease: saving || scene.gridSize <= 40
                    ? null
                    : () => onChanged(
                          scene.copyWith(gridSize: scene.gridSize - 8),
                        ),
                onIncrease: saving || scene.gridSize >= 96
                    ? null
                    : () => onChanged(
                          scene.copyWith(gridSize: scene.gridSize + 8),
                        ),
              ),
              const SizedBox(height: 10),
              _BoardGridPresetStrip(
                saving: saving,
                onSelected: (gridSize, columns, rows) {
                  onChanged(
                    scene.copyWith(
                      gridSize: gridSize,
                      gridColumns: columns,
                      gridRows: rows,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _BoardStepperRow(
                      label: 'Ancho',
                      value: '${scene.gridColumns}',
                      icon: Icons.swap_horiz_rounded,
                      onDecrease: saving || scene.gridColumns <= 10
                          ? null
                          : () => onChanged(
                                scene.copyWith(
                                  gridColumns: scene.gridColumns - 1,
                                ),
                              ),
                      onIncrease: saving || scene.gridColumns >= 48
                          ? null
                          : () => onChanged(
                                scene.copyWith(
                                  gridColumns: scene.gridColumns + 1,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BoardStepperRow(
                      label: 'Alto',
                      value: '${scene.gridRows}',
                      icon: Icons.swap_vert_rounded,
                      onDecrease: saving || scene.gridRows <= 8
                          ? null
                          : () => onChanged(
                                scene.copyWith(gridRows: scene.gridRows - 1),
                              ),
                      onIncrease: saving || scene.gridRows >= 36
                          ? null
                          : () => onChanged(
                                scene.copyWith(gridRows: scene.gridRows + 1),
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Arrastra tokens para fijar posiciones iniciales.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardMapSetupSection extends StatelessWidget {
  final BattleScene scene;
  final String currentMapLabel;
  final bool saving;
  final ValueChanged<BattleScene> onChanged;

  const _BoardMapSetupSection({
    required this.scene,
    required this.currentMapLabel,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StitchCodexPalette.card.withValues(alpha: 0.86),
        border: Border.all(
          color: StitchCodexPalette.textFaint.withValues(alpha: 0.76),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.map_outlined,
                  color: StitchCodexPalette.bronzeBright,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ESCENARIO · $currentMapLabel'.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.display,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 104,
              child: Row(
                children: [
                  Expanded(
                    child: ClipRect(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: StitchCodexPalette.ground,
                          border: Border.all(
                            color: StitchCodexPalette.bronzeMuted
                                .withValues(alpha: 0.44),
                          ),
                        ),
                        child: hasDisplayableImagePath(scene.mapImageUrl)
                            ? buildImageFromPath(
                                scene.mapImageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              )
                            : const Center(
                                child: Icon(
                                  Icons.grid_on_rounded,
                                  color: StitchCodexPalette.bronzeMuted,
                                  size: 30,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 118,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BoardSetupActionButton(
                          label: 'Dungeon',
                          icon: Icons.castle_rounded,
                          onPressed: saving
                              ? null
                              : () => onChanged(
                                    scene.copyWith(
                                      mapImageUrl:
                                          'assets/images/combat/dungeon_battlefield.png',
                                    ),
                                  ),
                        ),
                        const SizedBox(height: 6),
                        _BoardSetupActionButton(
                          label: 'Mapa vacio',
                          icon: Icons.grid_3x3_rounded,
                          onPressed: saving
                              ? null
                              : () => onChanged(
                                    scene.copyWith(mapImageUrl: ''),
                                  ),
                        ),
                        const SizedBox(height: 6),
                        _BoardSetupActionButton(
                          label: 'URL',
                          icon: Icons.link_rounded,
                          onPressed: saving
                              ? null
                              : () async {
                                  final value = await _promptMapUrl(
                                    context,
                                    scene.mapImageUrl,
                                  );
                                  if (value == null) return;
                                  onChanged(scene.copyWith(mapImageUrl: value));
                                },
                        ),
                      ],
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

class _BoardSetupActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _BoardSetupActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        height: 29,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: onPressed == null
              ? StitchCodexPalette.surfaceMuted.withValues(alpha: 0.36)
              : StitchCodexPalette.surface.withValues(alpha: 0.82),
          border: Border.all(
            color: StitchCodexPalette.bronzeMuted.withValues(
              alpha: onPressed == null ? 0.22 : 0.48,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: StitchCodexPalette.bronzeBright, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StitchCodexPalette.textSecondary,
                  fontFamily: StitchTypography.data,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardGridPresetStrip extends StatelessWidget {
  final bool saving;
  final void Function(int gridSize, int columns, int rows) onSelected;

  const _BoardGridPresetStrip({
    required this.saving,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BoardGridPresetButton(
            label: 'Compacto',
            detail: '18×12 · 56',
            onPressed: saving ? null : () => onSelected(56, 18, 12),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _BoardGridPresetButton(
            label: 'Dungeon',
            detail: '24×16 · 64',
            onPressed: saving ? null : () => onSelected(64, 24, 16),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _BoardGridPresetButton(
            label: 'Amplio',
            detail: '32×20 · 56',
            onPressed: saving ? null : () => onSelected(56, 32, 20),
          ),
        ),
      ],
    );
  }
}

class _BoardGridPresetButton extends StatelessWidget {
  final String label;
  final String detail;
  final VoidCallback? onPressed;

  const _BoardGridPresetButton({
    required this.label,
    required this.detail,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: StitchCodexPalette.ground.withValues(alpha: 0.42),
          border: Border.all(
            color: StitchCodexPalette.textFaint.withValues(alpha: 0.72),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StitchCodexPalette.bronzeBright,
                fontFamily: StitchTypography.display,
                fontSize: 7,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.data,
                fontSize: 6.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardStepperRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const _BoardStepperRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StitchCodexPalette.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.textFaint.withValues(alpha: 0.80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: StitchCodexPalette.bronzeBright, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: StitchCodexPalette.textMuted,
                      fontFamily: StitchTypography.data,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.data,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Menos',
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_rounded),
            ),
            IconButton(
              tooltip: 'Mas',
              onPressed: onIncrease,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardTokenAvatar extends StatelessWidget {
  final BoardToken token;
  final double size;
  final bool showHpBar;

  const _BoardTokenAvatar({
    required this.token,
    required this.size,
    this.showHpBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = token.isActive
        ? StitchCodexPalette.success
        : token.isTargeted
            ? StitchCodexPalette.bronzeBright
            : _isEnemyToken(token)
                ? StitchCodexPalette.crimsonBright
                : StitchCodexPalette.cold;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StitchCodexPalette.ground.withValues(alpha: 0.86),
                border: Border.all(color: accent, width: 2),
              ),
              child: ClipOval(
                child: hasDisplayableImagePath(token.imageUrl)
                    ? buildImageFromPath(
                        token.imageUrl,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                      )
                    : Icon(
                        _isEnemyToken(token)
                            ? Icons.crisis_alert_outlined
                            : Icons.person_outline_rounded,
                        color: StitchCodexPalette.textPrimary,
                        size: size * 0.46,
                      ),
              ),
            ),
          ),
          if (showHpBar)
            Positioned(
              left: 2,
              right: 2,
              bottom: -4,
              child: _MiniHpBar(token: token),
            ),
        ],
      ),
    );
  }
}

class _MiniHpBar extends StatelessWidget {
  final BoardToken token;

  const _MiniHpBar({required this.token});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      color: StitchCodexPalette.textFaint,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: token.hpRatio,
        child: ColoredBox(
          color: _hpColor(token.hpRatio),
        ),
      ),
    );
  }
}

class _BoardMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BoardMetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: StitchCodexPalette.textPrimary,
                fontFamily: StitchTypography.data,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapOption {
  final String label;
  final String path;

  const _MapOption(this.label, this.path);
}

Future<String?> _promptMapUrl(BuildContext context, String initialValue) async {
  final controller = TextEditingController(
    text: isRemoteImagePath(initialValue) ? initialValue : '',
  );
  try {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: StitchCodexPalette.surface,
          title: const Text('Usar mapa desde URL'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL publica de imagen',
              hintText: 'https://...',
              prefixIcon: Icon(Icons.link_rounded),
            ),
            onSubmitted: (value) {
              Navigator.of(context).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

List<_MapOption> _mapOptionsFor(String currentPath) {
  final options = <_MapOption>[
    const _MapOption('Dungeon', 'assets/images/combat/dungeon_battlefield.png'),
    const _MapOption('Arcane field', ''),
  ];
  if (currentPath.isNotEmpty &&
      !options.any((option) => option.path == currentPath)) {
    options.insert(0, _MapOption('Actual', currentPath));
  }
  return options;
}

List<BoardToken> _orderedInitiativeTokens(Iterable<BoardToken> source) {
  return source.toList(growable: false)
    ..sort((a, b) {
      final initiative = b.initiative.compareTo(a.initiative);
      if (initiative != 0) return initiative;
      return a.name.compareTo(b.name);
    });
}

double _centeredOverlayWidth(double availableWidth) {
  return math.min(340, math.max(220, availableWidth - 32));
}

double _centeredOverlayLeft(double availableWidth) {
  final width = _centeredOverlayWidth(availableWidth);
  return math.max(16, (availableWidth - width) / 2);
}

BoardToken? _activeTokenOf(List<BoardToken> tokens) {
  for (final token in tokens) {
    if (token.isActive) return token;
  }
  return tokens.isEmpty ? null : tokens.first;
}

BoardToken? _targetTokenOf(List<BoardToken> tokens) {
  for (final token in tokens) {
    if (token.isTargeted) return token;
  }
  return null;
}

BoardToken? _tokenById(List<BoardToken> tokens, String tokenId) {
  for (final token in tokens) {
    if (token.id == tokenId) return token;
  }
  return null;
}

BoardToken? _latestEventToken(List<BoardToken> tokens) {
  final eventTokens =
      tokens.where((token) => token.lastEventLabel.isNotEmpty).toList();
  if (eventTokens.isEmpty) return null;
  eventTokens.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final latest = eventTokens.first;
  final latestEventId = latest.lastEventId;
  final sameEventTokens = latestEventId.isEmpty
      ? [latest]
      : eventTokens
          .where((token) => token.lastEventId == latestEventId)
          .toList(growable: false);
  sameEventTokens.sort((a, b) {
    final dicePriority = _eventDicePriority(b).compareTo(
      _eventDicePriority(a),
    );
    if (dicePriority != 0) return dicePriority;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return sameEventTokens.first;
}

int _eventDicePriority(BoardToken token) {
  if (token.lastEventDiceNotation.trim().isNotEmpty) return 2;
  if (token.lastEventKind.toLowerCase().trim() == 'manual') return 1;
  return 0;
}

bool _shouldShowBoardDiceStage(BoardToken? token) {
  return token != null &&
      token.lastEventLabel.isNotEmpty &&
      token.lastEventDiceNotation.trim().isNotEmpty;
}

bool _stringListsMatch(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _isEnemyToken(BoardToken token) {
  return token.type == 'monster' ||
      token.type == 'enemy' ||
      token.type == 'npc';
}

bool _tokensOverlap(BoardToken a, BoardToken b) {
  return a.x < b.x + b.size &&
      a.x + a.size > b.x &&
      a.y < b.y + b.size &&
      a.y + a.size > b.y;
}

int _distanceFeet(BoardToken a, BoardToken b) {
  final dx = _tokenAxisDistanceSquares(
    a.x,
    a.x + a.size - 1,
    b.x,
    b.x + b.size - 1,
  );
  final dy = _tokenAxisDistanceSquares(
    a.y,
    a.y + a.size - 1,
    b.y,
    b.y + b.size - 1,
  );
  return math.max(dx, dy) * 5;
}

int _tokenAxisDistanceSquares(
  int aStart,
  int aEnd,
  int bStart,
  int bEnd,
) {
  if (aEnd < bStart) return bStart - aEnd;
  if (bEnd < aStart) return aStart - bEnd;
  return 0;
}

Color _hpColor(double ratio) {
  if (ratio <= 0.30) return StitchCodexPalette.crimsonBright;
  if (ratio <= 0.60) return StitchCodexPalette.bronzeBright;
  return StitchCodexPalette.success;
}

Color _eventColor(String eventKind, [String damageType = '']) {
  final typeColor = _damageTypeColor(damageType);
  if (typeColor != null && eventKind != 'heal' && eventKind != 'miss') {
    return typeColor;
  }
  return switch (eventKind) {
    'damage' => StitchCodexPalette.crimsonBright,
    'hit' => StitchCodexPalette.bronzeBright,
    'critical' => StitchCodexPalette.success,
    'heal' => StitchCodexPalette.success,
    'miss' => StitchCodexPalette.cold,
    'blocked' => StitchCodexPalette.crimsonBright,
    _ => StitchCodexPalette.cold,
  };
}

Color? _damageTypeColor(String damageType) {
  return switch (damageType.toLowerCase().trim()) {
    'acid' => const Color(0xFF9BE564),
    'bludgeoning' => const Color(0xFFC8BDA4),
    'cold' => const Color(0xFF8BE9FF),
    'fire' => const Color(0xFFFF7A2F),
    'force' => const Color(0xFFB85CFF),
    'lightning' => const Color(0xFFFFF06A),
    'necrotic' => const Color(0xFF9B6BFF),
    'piercing' => const Color(0xFFFFD27A),
    'poison' => const Color(0xFF70D56B),
    'psychic' => const Color(0xFFFF7AD9),
    'radiant' => const Color(0xFFFFF2A6),
    'slashing' => const Color(0xFFFFB454),
    'thunder' => const Color(0xFF7DD3FC),
    _ => null,
  };
}

extension on BoardToken {
  double get hpRatio {
    if (maxHp <= 0) return 0;
    return (currentHp / maxHp).clamp(0.0, 1.0);
  }
}
