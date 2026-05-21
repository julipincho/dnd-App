import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/battle_scene.dart';
import '../models/board_token.dart';
import '../providers/battle_board_provider.dart';
import '../services/dice_color_preferences_service.dart';
import '../utils/image_path_utils.dart';
import '../widgets/battle_board_view.dart';
import '../widgets/stitch_navigation.dart';
import '../features/dice/widgets/dice_roller_modal.dart';

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
  String? _selectedMoveTokenId;
  BoardToken? _manualRollToken;
  Timer? _manualRollClearTimer;
  Color _diceColor = DiceColorPreferencesService.defaultColor;

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
                controlledByUserId: '',
                now: DateTime.now(),
              );
            });
            _manualRollClearTimer?.cancel();
            _manualRollClearTimer = Timer(const Duration(seconds: 4), () {
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
    final boardReadOnly = widget.readOnly && !_editUnlocked;
    final allies = _orderedInitiativeTokens(
      visibleTokens.where((token) => !_isEnemyToken(token)),
    );
    final enemies = _orderedInitiativeTokens(
      visibleTokens.where(_isEnemyToken),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF05070B),
      appBar: StitchAppBar(
        title: Text(scene?.name ?? 'Battle Board'),
        backgroundColor: const Color(0xFF05070B),
        actions: [
          if (scene != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(
                  widget.readOnly
                      ? _editUnlocked
                          ? Icons.edit_location_alt_outlined
                          : Icons.visibility_outlined
                      : Icons.sports_esports_rounded,
                  size: 16,
                ),
                label: Text(
                  widget.readOnly
                      ? _editUnlocked
                          ? 'Display Edit'
                          : 'Display'
                      : 'Controller',
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
                  manualRollToken: _manualRollToken,
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
                            if (_setupMode) _hudVisible = true;
                          });
                        },
                  onToggleEdit: widget.readOnly
                      ? () {
                          setState(() {
                            _editUnlocked = !_editUnlocked;
                            if (!_editUnlocked) {
                              _selectedMoveTokenId = null;
                            }
                            if (_editUnlocked) _hudVisible = true;
                          });
                        }
                      : null,
                  onOpenDiceRoller: _openDiceRoller,
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
    setState(() {
      _selectedMoveTokenId = selected.id;
    });
    unawaited(_selectBoardTarget(boardProvider, scene, selected));
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
          next.lastEventResultDetail == token.lastEventResultDetail) {
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
        ((nextX - originX).abs() + (nextY - originY).abs()) * 5;
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
    final sceneTokens = boardProvider.tokens
        .where((token) => token.sceneId == scene.id)
        .map((token) => token.id == movedToken.id ? movedToken : token)
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
        final compact = constraints.maxWidth < 980;
        final railWidth = compact ? 150.0 : 212.0;
        final railTop = compact ? 148.0 : 166.0;
        return Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: _BoardFocusCard(
                label: 'Turno',
                token: activeToken,
                icon: Icons.bolt_rounded,
                accent: const Color(0xFF64F4A2),
                width: compact ? 250 : 360,
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: _BoardFocusCard(
                label: 'Objetivo',
                token: targetToken,
                icon: targetToken?.isTargetInRange == false
                    ? Icons.warning_amber_rounded
                    : Icons.center_focus_strong_rounded,
                accent: targetToken?.isTargetInRange == false
                    ? const Color(0xFFFF5C6C)
                    : const Color(0xFFFFB454),
                width: compact ? 250 : 360,
              ),
            ),
            Positioned(
              top: railTop,
              bottom: 92,
              left: 16,
              width: railWidth,
              child: _BoardInitiativeRail(
                title: 'Aliados',
                icon: Icons.groups_rounded,
                tokens: allies,
                accent: const Color(0xFF7DD3FC),
                onSelectToken: onSelectToken,
              ),
            ),
            Positioned(
              top: railTop,
              bottom: 92,
              right: 16,
              width: railWidth,
              child: _BoardInitiativeRail(
                title: 'Enemigos',
                icon: Icons.crisis_alert_rounded,
                tokens: enemies,
                accent: const Color(0xFFFF5C6C),
                onSelectToken: onSelectToken,
              ),
            ),
            if (!kIsWeb)
              Positioned(
                top: 18,
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
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.48)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _BoardTokenAvatar(token: resolvedToken, size: 56),
                    const SizedBox(width: 12),
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
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
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
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
                                color: const Color(0xFFFFD27A),
                              ),
                              if (resolvedToken.isActive)
                                _BoardMetricPill(
                                  icon: Icons.directions_run_rounded,
                                  label:
                                      '${resolvedToken.remainingMovementFeet}/${resolvedToken.speedFeet} ft',
                                  color: const Color(0xFF64F4A2),
                                ),
                              if (resolvedToken.isTargeted &&
                                  resolvedToken.targetDistanceFeet > 0)
                                _BoardMetricPill(
                                  icon: Icons.straighten_rounded,
                                  label:
                                      '${resolvedToken.targetDistanceFeet} ft',
                                  color: resolvedToken.isTargetInRange
                                      ? const Color(0xFFFFB454)
                                      : const Color(0xFFFF5C6C),
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

class _BoardInitiativeRail extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<BoardToken> tokens;
  final Color accent;
  final ValueChanged<BoardToken>? onSelectToken;

  const _BoardInitiativeRail({
    required this.title,
    required this.icon,
    required this.tokens,
    required this.accent,
    required this.onSelectToken,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.36)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${tokens.length}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              itemBuilder: (context, index) {
                final token = tokens[index];
                return _BoardInitiativeTile(
                  token: token,
                  accent: token.isActive
                      ? const Color(0xFF64F4A2)
                      : token.isTargeted
                          ? const Color(0xFFFFB454)
                          : accent,
                  onTap: onSelectToken == null
                      ? null
                      : () => onSelectToken!(token),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: tokens.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardInitiativeTile extends StatelessWidget {
  final BoardToken token;
  final Color accent;
  final VoidCallback? onTap;

  const _BoardInitiativeTile({
    required this.token,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: token.isActive ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _BoardTokenAvatar(
                  token: token,
                  size: 38,
                  showHpBar: false,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _MiniHpBar(token: token),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${token.initiative}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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

class _BoardDiceToast extends StatelessWidget {
  final BoardToken? token;

  const _BoardDiceToast({required this.token});

  @override
  Widget build(BuildContext context) {
    final resolvedToken = token;
    if (resolvedToken == null || resolvedToken.lastEventLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = _eventColor(resolvedToken.lastEventKind);
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
            color: Colors.black.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.58)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.24),
                blurRadius: 22,
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
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
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
  final VoidCallback onToggleHud;
  final VoidCallback? onToggleSetup;
  final VoidCallback? onToggleEdit;
  final VoidCallback? onOpenDiceRoller;

  const _BoardToolsDock({
    required this.hudVisible,
    required this.setupMode,
    required this.readOnly,
    required this.editUnlocked,
    required this.onToggleHud,
    required this.onToggleSetup,
    required this.onToggleEdit,
    this.onOpenDiceRoller,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
                tooltip: setupMode ? 'Cerrar setup' : 'Setup',
                icon: Icons.tune_rounded,
                active: setupMode,
                onPressed: onToggleSetup,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundToolButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;

  const _RoundToolButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        style: IconButton.styleFrom(
          fixedSize: const Size.square(46),
          shape: const CircleBorder(),
          backgroundColor: active
              ? const Color(0xFF64F4A2).withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
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
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: const Color(0xFF7DD3FC).withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.44),
              blurRadius: 24,
              offset: const Offset(0, 12),
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
                  const Icon(Icons.tune_rounded, color: Color(0xFF7DD3FC)),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Setup del tablero',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
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
              DropdownButtonFormField<String>(
                value: currentMap,
                decoration: const InputDecoration(
                  labelText: 'Fondo',
                  prefixIcon: Icon(Icons.image_rounded),
                ),
                items: [
                  for (final option in mapOptions)
                    DropdownMenuItem<String>(
                      value: option.path,
                      child: Text(option.label),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        onChanged(scene.copyWith(mapImageUrl: value));
                      },
              ),
              const SizedBox(height: 12),
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
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF7DD3FC), size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
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
        ? const Color(0xFF64F4A2)
        : token.isTargeted
            ? const Color(0xFFFFB454)
            : _isEnemyToken(token)
                ? const Color(0xFFFF5C6C)
                : const Color(0xFF7DD3FC);
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
                color: Colors.black.withValues(alpha: 0.55),
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
                        color: Colors.white,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 5,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.70),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: token.hpRatio,
            child: ColoredBox(color: _hpColor(token.hpRatio)),
          ),
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
        borderRadius: BorderRadius.circular(999),
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

class _MapOption {
  final String label;
  final String path;

  const _MapOption(this.label, this.path);
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
  return eventTokens.first;
}

bool _isEnemyToken(BoardToken token) {
  return token.type == 'monster' ||
      token.type == 'enemy' ||
      token.type == 'npc';
}

int _distanceFeet(BoardToken a, BoardToken b) {
  final dx = (a.x - b.x).abs();
  final dy = (a.y - b.y).abs();
  return math.max(dx, dy) * 5;
}

Color _hpColor(double ratio) {
  if (ratio <= 0.30) return const Color(0xFFFF5C6C);
  if (ratio <= 0.60) return const Color(0xFFFFB454);
  return const Color(0xFF64F4A2);
}

Color _eventColor(String eventKind) {
  return switch (eventKind) {
    'damage' => const Color(0xFFFF5C6C),
    'hit' => const Color(0xFFFFB454),
    'critical' => const Color(0xFF64F4A2),
    'heal' => const Color(0xFF64F4A2),
    'miss' => const Color(0xFF7DD3FC),
    'blocked' => const Color(0xFFFF5C6C),
    _ => const Color(0xFF7DD3FC),
  };
}

extension on BoardToken {
  double get hpRatio {
    if (maxHp <= 0) return 0;
    return (currentHp / maxHp).clamp(0.0, 1.0);
  }
}
