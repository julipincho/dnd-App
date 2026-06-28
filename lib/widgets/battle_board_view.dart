import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/combat/domain/rules/combat_board_geometry.dart';
import '../models/battle_scene.dart';
import '../models/board_token.dart';
import '../theme.dart';
import '../utils/image_path_utils.dart';
import 'battle_board_dice_box_overlay.dart';

class BattleBoardView extends StatefulWidget {
  final BattleScene scene;
  final List<BoardToken> tokens;
  final bool readOnly;
  final Future<void> Function(BoardToken token, int x, int y)? onMoveToken;
  final Future<void> Function(int x, int y)? onBoardCellTap;
  final ValueChanged<BoardToken>? onTokenTap;
  final String? selectedTokenId;
  final Set<String> selectedTokenIds;
  final bool selectionEnabled;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final bool enableDiceOverlay;
  final BoardToken? manualRollToken;
  final Future<bool> Function(BoardToken token)? onDiceRollClaimRequested;
  final FutureOr<void> Function(BoardToken token, BoardDiceRollOutcome outcome)?
      onDiceRollResolved;

  const BattleBoardView({
    super.key,
    required this.scene,
    required this.tokens,
    this.readOnly = false,
    this.onMoveToken,
    this.onBoardCellTap,
    this.onTokenTap,
    this.selectedTokenId,
    this.selectedTokenIds = const {},
    this.selectionEnabled = false,
    this.onSelectionChanged,
    this.enableDiceOverlay = true,
    this.manualRollToken,
    this.onDiceRollClaimRequested,
    this.onDiceRollResolved,
  });

  @override
  State<BattleBoardView> createState() => _BattleBoardViewState();
}

class _BattleBoardViewState extends State<BattleBoardView> {
  final GlobalKey _boardKey = GlobalKey();
  Offset? _selectionStart;
  Offset? _selectionCurrent;

  bool get _selectionActive {
    return widget.selectionEnabled &&
        !widget.readOnly &&
        widget.onSelectionChanged != null;
  }

  Rect? get _selectionRect {
    final start = _selectionStart;
    final current = _selectionCurrent;
    if (start == null || current == null) return null;
    return Rect.fromPoints(start, current);
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final boardWidth = scene.gridColumns * scene.gridSize.toDouble();
    final boardHeight = scene.gridRows * scene.gridSize.toDouble();
    final visibleTokens =
        widget.tokens.where((token) => token.isVisible).toList(growable: false);
    final activeToken = _activeTokenOf(visibleTokens);
    final targetToken = _targetTokenOf(visibleTokens);
    final eventToken = _latestEventToken(visibleTokens);
    final areaEventToken = _latestAreaEventToken(visibleTokens);
    final areaEventActorToken = areaEventToken == null
        ? null
        : _tokenByRefId(
              visibleTokens,
              areaEventToken.lastEventSourceRefId,
            ) ??
            activeToken;
    final areaEventTargetToken = areaEventToken == null
        ? null
        : _tokenByRefId(
              visibleTokens,
              areaEventToken.lastEventPrimaryTargetRefId,
            ) ??
            targetToken;
    final areaPreviewTargetCenter = activeToken == null || targetToken == null
        ? null
        : _areaAimCenter(
            activeToken,
            fallback: targetToken,
            gridSize: scene.gridSize.toDouble(),
          );
    final areaEventTargetCenter =
        areaEventToken == null || areaEventTargetToken == null
            ? null
            : _areaEventCenter(
                areaEventToken,
                fallback: areaEventTargetToken,
                gridSize: scene.gridSize.toDouble(),
              );
    final manualEventToken = _latestEventToken(
      widget.tokens
          .where(
            (token) =>
                token.lastEventLabel.isNotEmpty &&
                token.lastEventId.isNotEmpty &&
                token.lastEventKind.toLowerCase() == 'manual' &&
                token.id != widget.manualRollToken?.id &&
                token.id != eventToken?.id,
          )
          .toList(growable: false),
    );
    final diceEventToken = _latestEventToken([
      if (eventToken != null) eventToken,
      if (widget.manualRollToken != null) widget.manualRollToken!,
      if (manualEventToken != null) manualEventToken,
    ]);
    final reduceBoardEffects = _isDiceRollPending(diceEventToken);
    final areaPreviewAffectedRefs = reduceBoardEffects ||
            activeToken == null ||
            areaPreviewTargetCenter == null
        ? const <String>{}
        : _areaPreviewAffectedRefs(
            activeToken: activeToken,
            tokens: visibleTokens,
            targetCenter: areaPreviewTargetCenter,
            shape: activeToken.selectedActionAreaShape,
            areaFeet: activeToken.selectedActionAreaFeet,
            gridSize: scene.gridSize.toDouble(),
          );
    final selectedMoveToken = _tokenById(visibleTokens, widget.selectedTokenId);
    final selectedGroupTokens = visibleTokens
        .where((token) => widget.selectedTokenIds.contains(token.id))
        .toList(growable: false);
    final hasMoveSelection =
        selectedMoveToken != null || selectedGroupTokens.isNotEmpty;

    return InteractiveViewer(
      minScale: 0.35,
      maxScale: 3,
      panEnabled: !_selectionActive,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(280),
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
        child: DragTarget<BoardToken>(
          key: _boardKey,
          onAcceptWithDetails: widget.readOnly || widget.onMoveToken == null
              ? null
              : (details) async {
                  final boardContext = _boardKey.currentContext;
                  final renderBox =
                      boardContext?.findRenderObject() as RenderBox?;
                  if (renderBox == null) return;

                  final local = renderBox.globalToLocal(details.offset);
                  final maxX =
                      math.max(0, scene.gridColumns - details.data.size);
                  final maxY = math.max(0, scene.gridRows - details.data.size);
                  final x = (local.dx / scene.gridSize)
                      .round()
                      .clamp(0, maxX)
                      .toInt();
                  final y = (local.dy / scene.gridSize)
                      .round()
                      .clamp(0, maxY)
                      .toInt();
                  await widget.onMoveToken!(details.data, x, y);
                },
          builder: (context, _, __) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.readOnly ||
                      widget.onBoardCellTap == null ||
                      !hasMoveSelection
                  ? null
                  : (details) {
                      final local = details.localPosition;
                      final x = (local.dx / scene.gridSize)
                          .floor()
                          .clamp(0, scene.gridColumns - 1)
                          .toInt();
                      final y = (local.dy / scene.gridSize)
                          .floor()
                          .clamp(0, scene.gridRows - 1)
                          .toInt();
                      if (_cellHasToken(visibleTokens, x, y)) return;
                      unawaited(widget.onBoardCellTap!(x, y));
                    },
              onPanStart: !_selectionActive
                  ? null
                  : (details) {
                      setState(() {
                        _selectionStart = details.localPosition;
                        _selectionCurrent = details.localPosition;
                      });
                    },
              onPanUpdate: !_selectionActive
                  ? null
                  : (details) {
                      setState(() {
                        _selectionCurrent = details.localPosition;
                      });
                    },
              onPanEnd: !_selectionActive
                  ? null
                  : (_) {
                      final rect = _selectionRect;
                      setState(() {
                        _selectionStart = null;
                        _selectionCurrent = null;
                      });
                      if (rect == null) return;
                      final selectedIds = _tokensInsideSelection(
                        tokens: visibleTokens,
                        rect: rect,
                        gridSize: scene.gridSize.toDouble(),
                      );
                      widget.onSelectionChanged!(selectedIds);
                    },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: _BattleBoardMap(scene: scene),
                    ),
                  ),
                  if (selectedMoveToken != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SelectedMoveCellPainter(
                          token: selectedMoveToken,
                          gridSize: scene.gridSize.toDouble(),
                        ),
                      ),
                    ),
                  if (selectedGroupTokens.length > 1)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SelectedGroupBoundsPainter(
                          tokens: selectedGroupTokens,
                          gridSize: scene.gridSize.toDouble(),
                        ),
                      ),
                    ),
                  if (!reduceBoardEffects && activeToken != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MovementRangePainter(
                          token: activeToken,
                          gridSize: scene.gridSize.toDouble(),
                          columns: scene.gridColumns,
                          rows: scene.gridRows,
                        ),
                      ),
                    ),
                  if (!reduceBoardEffects &&
                      activeToken != null &&
                      activeToken.selectedActionRangeFeet > 0)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ActionRangePainter(
                          token: activeToken,
                          gridSize: scene.gridSize.toDouble(),
                        ),
                      ),
                    ),
                  if (!reduceBoardEffects &&
                      activeToken != null &&
                      targetToken != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TargetLinkPainter(
                          actor: activeToken,
                          target: targetToken,
                          gridSize: scene.gridSize.toDouble(),
                          inRange: targetToken.isTargetInRange,
                        ),
                      ),
                    ),
                  if (!reduceBoardEffects &&
                      activeToken != null &&
                      targetToken != null &&
                      activeToken.selectedActionAreaFeet > 0 &&
                      areaPreviewTargetCenter != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AreaEffectPreviewPainter(
                          actor: activeToken,
                          targetCenter: areaPreviewTargetCenter,
                          shape: activeToken.selectedActionAreaShape,
                          areaFeet: activeToken.selectedActionAreaFeet,
                          gridSize: scene.gridSize.toDouble(),
                        ),
                      ),
                    ),
                  if (areaEventToken != null &&
                      areaEventActorToken != null &&
                      areaEventTargetToken != null &&
                      areaEventToken.lastEventAreaFeet > 0 &&
                      areaEventTargetCenter != null)
                    Positioned.fill(
                      child: reduceBoardEffects
                          ? RepaintBoundary(
                              child: CustomPaint(
                                painter: _AreaEffectEventPainter(
                                  actor: areaEventActorToken,
                                  target: areaEventTargetToken,
                                  targetCenter: areaEventTargetCenter,
                                  shape: areaEventToken.lastEventAreaShape,
                                  areaFeet: areaEventToken.lastEventAreaFeet,
                                  gridSize: scene.gridSize.toDouble(),
                                  progress: 1,
                                  color: _eventColor(
                                    areaEventToken.lastEventKind,
                                    areaEventToken.lastEventDamageType,
                                  ),
                                  damageType:
                                      areaEventToken.lastEventDamageType,
                                  label: areaEventToken
                                          .lastEventResultLabel.isNotEmpty
                                      ? areaEventToken.lastEventResultLabel
                                      : areaEventToken.lastEventLabel,
                                  reducedMotion: true,
                                ),
                              ),
                            )
                          : TweenAnimationBuilder<double>(
                              key: ValueKey(
                                'area-${areaEventToken.lastEventId}-${areaEventToken.updatedAt.microsecondsSinceEpoch}',
                              ),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1450),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _AreaEffectEventPainter(
                                      actor: areaEventActorToken,
                                      target: areaEventTargetToken,
                                      targetCenter: areaEventTargetCenter,
                                      shape: areaEventToken.lastEventAreaShape,
                                      areaFeet:
                                          areaEventToken.lastEventAreaFeet,
                                      gridSize: scene.gridSize.toDouble(),
                                      progress:
                                          value.clamp(0.0, 1.0).toDouble(),
                                      color: _eventColor(
                                        areaEventToken.lastEventKind,
                                        areaEventToken.lastEventDamageType,
                                      ),
                                      damageType:
                                          areaEventToken.lastEventDamageType,
                                      label: areaEventToken
                                              .lastEventResultLabel.isNotEmpty
                                          ? areaEventToken.lastEventResultLabel
                                          : areaEventToken.lastEventLabel,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _BattleGridPainter(
                          gridSize: scene.gridSize.toDouble(),
                          columns: scene.gridColumns,
                          rows: scene.gridRows,
                        ),
                      ),
                    ),
                  ),
                  for (final token in visibleTokens)
                    _BoardTokenWidget(
                      key: ValueKey(token.id),
                      token: token,
                      gridSize: scene.gridSize,
                      readOnly: widget.readOnly || _selectionActive,
                      selectedForMove: token.id == selectedMoveToken?.id ||
                          widget.selectedTokenIds.contains(token.id),
                      areaPreviewAffected:
                          areaPreviewAffectedRefs.contains(token.refId),
                      effectsReduced: reduceBoardEffects,
                      onTap: widget.onTokenTap,
                    ),
                  if (_selectionRect != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SelectionRectPainter(rect: _selectionRect!),
                        ),
                      ),
                    ),
                  if (kIsWeb && widget.enableDiceOverlay)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: BattleBoardDiceBoxOverlay(
                          key: ValueKey('dice-box-overlay-${scene.id}'),
                          boardViewportId: scene.id,
                          token: diceEventToken,
                          gridSize: scene.gridSize.toDouble(),
                          onRollClaimRequested: widget.onDiceRollClaimRequested,
                          onRollResolved: widget.onDiceRollResolved,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BattleBoardMap extends StatelessWidget {
  final BattleScene scene;

  const _BattleBoardMap({required this.scene});

  @override
  Widget build(BuildContext context) {
    if (hasDisplayableImagePath(scene.mapImageUrl)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          buildImageFromPath(
            scene.mapImageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.medium,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: StitchCodexPalette.ground.withValues(alpha: 0.34),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.72, -0.58),
                radius: 0.92,
                colors: [
                  StitchCodexPalette.bronze.withValues(alpha: 0.16),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.82, -0.44),
                radius: 0.82,
                colors: [
                  StitchCodexPalette.crimson.withValues(alpha: 0.13),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const CustomPaint(painter: _BattleMapTexturePainter()),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StitchCodexPalette.ground,
            StitchCodexPalette.surface,
            Color(0xFF211208),
            StitchCodexPalette.ground,
          ],
          stops: [0, 0.38, 0.72, 1],
        ),
      ),
      child: CustomPaint(
        painter: _BattleMapTexturePainter(),
      ),
    );
  }
}

Offset _areaAimCenter(
  BoardToken token, {
  required BoardToken fallback,
  required double gridSize,
}) {
  final x =
      token.selectedActionAimX >= 0 ? token.selectedActionAimX : fallback.x;
  final y =
      token.selectedActionAimY >= 0 ? token.selectedActionAimY : fallback.y;
  return Offset((x + 0.5) * gridSize, (y + 0.5) * gridSize);
}

Offset _areaEventCenter(
  BoardToken token, {
  required BoardToken fallback,
  required double gridSize,
}) {
  final x =
      token.lastEventAreaTargetX >= 0 ? token.lastEventAreaTargetX : fallback.x;
  final y =
      token.lastEventAreaTargetY >= 0 ? token.lastEventAreaTargetY : fallback.y;
  return Offset((x + 0.5) * gridSize, (y + 0.5) * gridSize);
}

Set<String> _areaPreviewAffectedRefs({
  required BoardToken activeToken,
  required List<BoardToken> tokens,
  required Offset targetCenter,
  required String shape,
  required int areaFeet,
  required double gridSize,
}) {
  if (areaFeet <= 0 || shape.trim().isEmpty) return const {};
  final activeIsEnemy = _isEnemyToken(activeToken);
  final aimToken = _areaAimPreviewToken(
    activeToken: activeToken,
    targetCenter: targetCenter,
    gridSize: gridSize,
  );
  final affected = <String>{};
  for (final token in tokens) {
    if (token.refId == activeToken.refId) continue;
    if (_isEnemyToken(token) == activeIsEnemy) continue;
    if (CombatBoardGeometry.areaAffectsToken(
      shape: shape,
      areaFeet: areaFeet,
      originToken: aimToken,
      candidateToken: token,
      actorToken: activeToken,
    )) {
      affected.add(token.refId);
    }
  }
  return affected;
}

BoardToken _areaAimPreviewToken({
  required BoardToken activeToken,
  required Offset targetCenter,
  required double gridSize,
}) {
  return BoardToken.create(
    id: '${activeToken.sceneId}_area_preview_aim',
    sceneId: activeToken.sceneId,
    refId: 'area-preview-aim',
    type: 'area',
    name: 'Area Preview Aim',
    x: (targetCenter.dx / gridSize - 0.5).round(),
    y: (targetCenter.dy / gridSize - 0.5).round(),
    isVisible: false,
  );
}

bool _isEnemyToken(BoardToken token) {
  return token.type == 'monster' ||
      token.type == 'enemy' ||
      token.type == 'npc';
}

Set<String> _tokensInsideSelection({
  required List<BoardToken> tokens,
  required Rect rect,
  required double gridSize,
}) {
  final normalized = Rect.fromLTRB(
    math.min(rect.left, rect.right),
    math.min(rect.top, rect.bottom),
    math.max(rect.left, rect.right),
    math.max(rect.top, rect.bottom),
  );
  if (normalized.width < 8 && normalized.height < 8) {
    return const {};
  }

  final selected = <String>{};
  for (final token in tokens) {
    final tokenRect = Rect.fromLTWH(
      token.x * gridSize,
      token.y * gridSize,
      token.size * gridSize,
      token.size * gridSize,
    );
    if (normalized.overlaps(tokenRect)) {
      selected.add(token.id);
    }
  }
  return selected;
}

class _BoardTokenWidget extends StatelessWidget {
  final BoardToken token;
  final int gridSize;
  final bool readOnly;
  final bool selectedForMove;
  final bool areaPreviewAffected;
  final bool effectsReduced;
  final ValueChanged<BoardToken>? onTap;

  const _BoardTokenWidget({
    super.key,
    required this.token,
    required this.gridSize,
    required this.readOnly,
    required this.selectedForMove,
    required this.areaPreviewAffected,
    required this.effectsReduced,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokenSize = token.size * gridSize.toDouble();
    final left = token.x * gridSize.toDouble();
    final top = token.y * gridSize.toDouble();
    final visualInset = math.max(8.0, tokenSize * 0.12);
    final child = RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.all(visualInset),
        child: _TokenDisc(
          token: token,
          size: tokenSize - visualInset * 2,
          selectedForMove: selectedForMove,
          areaPreviewAffected: areaPreviewAffected,
          effectsReduced: effectsReduced,
        ),
      ),
    );
    final tappableChild = onTap == null
        ? child
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap!(token),
              child: child,
            ),
          );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: tokenSize,
      height: tokenSize,
      child: readOnly
          ? tappableChild
          : Draggable<BoardToken>(
              data: token,
              feedback: Material(
                type: MaterialType.transparency,
                child: Opacity(opacity: 0.78, child: child),
              ),
              childWhenDragging: Opacity(opacity: 0.38, child: child),
              child: tappableChild,
            ),
    );
  }
}

class _TokenDisc extends StatelessWidget {
  final BoardToken token;
  final double size;
  final bool selectedForMove;
  final bool areaPreviewAffected;
  final bool effectsReduced;

  const _TokenDisc({
    required this.token,
    required this.size,
    required this.selectedForMove,
    required this.areaPreviewAffected,
    required this.effectsReduced,
  });

  @override
  Widget build(BuildContext context) {
    final isEnemy = token.type == 'monster' || token.type == 'enemy';
    final teamAccent =
        isEnemy ? StitchCodexPalette.crimsonBright : StitchCodexPalette.success;
    final accent = selectedForMove
        ? StitchCodexPalette.bronzeBright
        : areaPreviewAffected
            ? StitchCodexPalette.crimsonBright
            : token.isTargeted
                ? StitchCodexPalette.bronzeBright
                : token.isActive
                    ? StitchCodexPalette.success
                    : teamAccent;
    final eventColor = _eventColor(
      token.lastEventKind,
      token.lastEventDamageType,
    );
    final highlighted = selectedForMove ||
        areaPreviewAffected ||
        token.isActive ||
        token.isTargeted;
    final borderWidth =
        (highlighted ? math.max(3, size * 0.06) : math.max(2, size * 0.045))
            .toDouble();

    return Tooltip(
      message:
          '${token.name} - ${token.currentHp}/${token.maxHp} HP - ${token.remainingMovementFeet}/${token.speedFeet} ft',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StitchCodexPalette.ground.withValues(alpha: 0.86),
                border: Border.all(color: accent, width: borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(
                      alpha: highlighted ? 0.42 : 0.18,
                    ),
                    blurRadius: highlighted ? 18.0 : 10.0,
                    spreadRadius: highlighted ? 2.0 : 0.0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(borderWidth),
                      child: ClipOval(
                        child: hasDisplayableImagePath(token.imageUrl)
                            ? buildImageFromPath(
                                token.imageUrl,
                                fit: BoxFit.cover,
                                width: size,
                                height: size,
                              )
                            : Icon(
                                isEnemy
                                    ? Icons.crisis_alert_outlined
                                    : Icons.person_outline,
                                color: Colors.white.withValues(alpha: 0.88),
                                size: size * 0.42,
                              ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.48),
                          ],
                          stops: const [0.52, 1],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!effectsReduced && token.lastEventLabel.isNotEmpty)
            Positioned.fill(
              child: _TokenImpactPulse(
                eventKey:
                    '${token.lastEventId}-${token.lastEventLabel}-${token.updatedAt.microsecondsSinceEpoch}',
                color: eventColor,
              ),
            ),
          if (!effectsReduced &&
              token.lastEventLabel.isNotEmpty &&
              token.lastEventDamageType.isNotEmpty)
            Positioned.fill(
              child: _ElementalImpactOverlay(
                eventKey:
                    'element-${token.lastEventId}-${token.lastEventDamageType}-${token.updatedAt.microsecondsSinceEpoch}',
                damageType: token.lastEventDamageType,
                color: eventColor,
              ),
            ),
          if (areaPreviewAffected && token.lastEventLabel.isEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: StitchCodexPalette.crimsonBright
                        .withValues(alpha: 0.10),
                    border: Border.all(
                      color: StitchCodexPalette.bronzeBright
                          .withValues(alpha: 0.92),
                      width: math.max(2, size * 0.045),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: StitchCodexPalette.crimsonBright
                            .withValues(alpha: 0.34),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: -size * 0.08,
            right: -size * 0.08,
            bottom: -18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: StitchCodexPalette.ground.withValues(alpha: 0.9),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.48),
                    ),
                  ),
                  child: Text(
                    token.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.display,
                      fontSize: math.max(8, size * 0.11),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 2,
            right: 2,
            top: -13,
            child: _TokenHpBar(
              token: token,
              color: teamAccent,
            ),
          ),
          if (token.isActive)
            Positioned(
              top: 2,
              left: 2,
              child: const _TokenStateIcon(
                icon: Icons.play_arrow,
                color: StitchCodexPalette.success,
              ),
            ),
          if (selectedForMove)
            Positioned(
              top: 2,
              right: 2,
              child: const _TokenStateIcon(
                icon: Icons.open_with,
                color: StitchCodexPalette.bronzeBright,
              ),
            ),
          if (token.isTargeted)
            Positioned(
              right: 2,
              bottom: 2,
              child: _TokenStateIcon(
                icon: token.isTargetInRange
                    ? Icons.center_focus_strong_rounded
                    : Icons.warning_amber_rounded,
                color: token.isTargetInRange
                    ? StitchCodexPalette.bronzeBright
                    : StitchCodexPalette.crimsonBright,
              ),
            ),
          if (token.currentHp <= 0)
            const Positioned.fill(
              child: Center(
                child: Icon(
                  Icons.close,
                  color: StitchCodexPalette.crimsonBright,
                  size: 42,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 8),
                  ],
                ),
              ),
            ),
          if (token.lastEventLabel.isNotEmpty)
            Positioned(
              left: -8,
              right: -8,
              top: size * 0.32,
              child: Center(
                child: _ImpactBanner(
                  label: token.lastEventResultLabel.isNotEmpty
                      ? token.lastEventResultLabel
                      : token.lastEventLabel,
                  color: eventColor,
                ),
              ),
            ),
          if (token.conditions.isNotEmpty)
            Positioned(
              left: 2,
              right: 2,
              bottom: -38,
              child: _ConditionRibbon(conditions: token.conditions),
            ),
          if (areaPreviewAffected)
            Positioned(
              bottom: -8,
              right: -4,
              child: const _TokenBadge(
                icon: Icons.bolt_rounded,
                label: 'AoE',
                color: StitchCodexPalette.crimsonBright,
              ),
            ),
        ],
      ),
    );
  }
}

class _TokenHpBar extends StatelessWidget {
  final BoardToken token;
  final Color color;

  const _TokenHpBar({
    required this.token,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hpRatio = token.maxHp <= 0
        ? 0.0
        : (token.currentHp / token.maxHp).clamp(0.0, 1.0).toDouble();
    return Container(
      height: 9,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: StitchCodexPalette.ground.withValues(alpha: 0.92),
        border: Border.all(
          color: StitchCodexPalette.textFaint.withValues(alpha: 0.92),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: hpRatio,
          child: ColoredBox(
            color: token.currentHp <= 0
                ? StitchCodexPalette.crimson
                : hpRatio <= 0.30
                    ? StitchCodexPalette.crimsonBright
                    : color,
          ),
        ),
      ),
    );
  }
}

class _TokenStateIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _TokenStateIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: StitchCodexPalette.ground.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.86)),
      ),
      child: Icon(icon, color: color, size: 13),
    );
  }
}

class _TokenImpactPulse extends StatelessWidget {
  final String eventKey;
  final Color color;

  const _TokenImpactPulse({
    required this.eventKey,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(eventKey),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 860),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final t = value.clamp(0.0, 1.0).toDouble();
          final alpha = (1.0 - t).clamp(0.0, 1.0).toDouble();
          return Transform.scale(
            scale: 1.0 + t * 0.26,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.18 * alpha),
                border: Border.all(
                  color: color.withValues(alpha: 0.86 * alpha),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.48 * alpha),
                    blurRadius: 34,
                    spreadRadius: 8,
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

class _ElementalImpactOverlay extends StatelessWidget {
  final String eventKey;
  final String damageType;
  final Color color;

  const _ElementalImpactOverlay({
    required this.eventKey,
    required this.damageType,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(eventKey),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1180),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return CustomPaint(
            painter: _ElementalImpactPainter(
              damageType: damageType,
              color: color,
              progress: value.clamp(0.0, 1.0).toDouble(),
            ),
          );
        },
      ),
    );
  }
}

class _ElementalImpactPainter extends CustomPainter {
  final String damageType;
  final Color color;
  final double progress;

  const _ElementalImpactPainter({
    required this.damageType,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final t = progress.clamp(0.0, 1.0).toDouble();
    final fade = (1 - t).clamp(0.0, 1.0).toDouble();
    final normalized = damageType.toLowerCase().trim();

    if (normalized == 'lightning') {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.88 * fade)
        ..strokeWidth = math.max(2, radius * 0.08)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final angle = -math.pi / 2 + i * math.pi * 2 / 3 + t * 0.4;
        final start = center + Offset(math.cos(angle), math.sin(angle)) * 4;
        final mid = center +
            Offset(math.cos(angle + 0.36), math.sin(angle + 0.36)) *
                radius *
                (0.38 + t * 0.18);
        final end = center +
            Offset(math.cos(angle), math.sin(angle)) * radius * (0.78 + t);
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(end.dx, end.dy);
        canvas.drawPath(path, paint);
      }
      return;
    }

    final particlePaint = Paint()
      ..color = color.withValues(alpha: 0.84 * fade)
      ..style = PaintingStyle.fill;
    final count = normalized == 'fire' ? 11 : 8;
    for (var i = 0; i < count; i++) {
      final angle = i * math.pi * 2 / count + t * 0.8;
      final distance = radius * (0.18 + t * (0.55 + (i % 3) * 0.08));
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final particleRadius = math.max(2.0, radius * (0.045 + (i % 2) * 0.018));
      if (normalized == 'cold') {
        canvas.drawLine(
          position + Offset(-particleRadius, 0),
          position + Offset(particleRadius, 0),
          particlePaint..strokeWidth = math.max(1.5, particleRadius * 0.55),
        );
        canvas.drawLine(
          position + Offset(0, -particleRadius),
          position + Offset(0, particleRadius),
          particlePaint,
        );
      } else {
        canvas.drawCircle(position, particleRadius, particlePaint);
      }
    }

    if (normalized == 'thunder' || normalized == 'force') {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.0, radius * 0.08)
        ..color = color.withValues(alpha: 0.54 * fade);
      canvas.drawCircle(center, radius * (0.4 + t * 0.72), ring);
    }
  }

  @override
  bool shouldRepaint(covariant _ElementalImpactPainter oldDelegate) {
    return oldDelegate.damageType != damageType ||
        oldDelegate.color != color ||
        oldDelegate.progress != progress;
  }
}

class _ImpactBanner extends StatelessWidget {
  final String label;
  final Color color;

  const _ImpactBanner({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.70)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 16,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TokenBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TokenBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 3),
            Text(
              label,
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

class _ConditionRibbon extends StatelessWidget {
  final List<String> conditions;

  const _ConditionRibbon({required this.conditions});

  @override
  Widget build(BuildContext context) {
    final visible = conditions.take(2).join(' + ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          visible,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MovementRangePainter extends CustomPainter {
  final BoardToken token;
  final double gridSize;
  final int columns;
  final int rows;

  const _MovementRangePainter({
    required this.token,
    required this.gridSize,
    required this.columns,
    required this.rows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final budgetSquares = token.speedFeet ~/ 5;
    if (budgetSquares <= 0) return;

    final fill = Paint()
      ..color = StitchCodexPalette.success.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final spentFill = Paint()
      ..color = StitchCodexPalette.bronze.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final edge = Paint()
      ..color = StitchCodexPalette.success.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final originX = token.movementOriginX.clamp(0, columns - 1).toInt();
    final originY = token.movementOriginY.clamp(0, rows - 1).toInt();
    final currentDistance = math.max(
      (token.x - originX).abs(),
      (token.y - originY).abs(),
    );
    final startX = math.max(0, originX - budgetSquares);
    final endX = math.min(columns - 1, originX + budgetSquares);
    final startY = math.max(0, originY - budgetSquares);
    final endY = math.min(rows - 1, originY + budgetSquares);

    for (var y = startY; y <= endY; y++) {
      for (var x = startX; x <= endX; x++) {
        final distance = math.max((x - originX).abs(), (y - originY).abs());
        if (distance > budgetSquares) continue;
        final isSpent = distance <= currentDistance &&
            math.max((x - token.x).abs(), (y - token.y).abs()) <=
                (currentDistance - distance).abs() + 1;
        final rect = Rect.fromLTWH(
          x * gridSize,
          y * gridSize,
          gridSize,
          gridSize,
        ).deflate(1);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          isSpent ? spentFill : fill,
        );
        if (distance == budgetSquares) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            edge,
          );
        }
      }
    }

    final originCenter = Offset(
      (originX + 0.5) * gridSize,
      (originY + 0.5) * gridSize,
    );
    canvas.drawCircle(
      originCenter,
      math.max(5, gridSize * 0.13),
      Paint()..color = StitchCodexPalette.success.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _MovementRangePainter oldDelegate) {
    return oldDelegate.token.x != token.x ||
        oldDelegate.token.y != token.y ||
        oldDelegate.token.movementOriginX != token.movementOriginX ||
        oldDelegate.token.movementOriginY != token.movementOriginY ||
        oldDelegate.token.speedFeet != token.speedFeet ||
        oldDelegate.token.remainingMovementFeet !=
            token.remainingMovementFeet ||
        oldDelegate.gridSize != gridSize ||
        oldDelegate.columns != columns ||
        oldDelegate.rows != rows;
  }
}

class _SelectedMoveCellPainter extends CustomPainter {
  final BoardToken? token;
  final double gridSize;

  const _SelectedMoveCellPainter({
    required this.token,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final selected = token;
    if (selected == null) return;

    final rect = Rect.fromLTWH(
      selected.x * gridSize,
      selected.y * gridSize,
      selected.size * gridSize,
      selected.size * gridSize,
    ).deflate(2);
    final radius = Radius.circular(math.max(8, gridSize * 0.16));
    final rrect = RRect.fromRectAndRadius(rect, radius);
    const color = StitchCodexPalette.bronzeBright;

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect.inflate(4),
      Paint()
        ..color = color.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, gridSize * 0.045),
    );
  }

  @override
  bool shouldRepaint(covariant _SelectedMoveCellPainter oldDelegate) {
    return oldDelegate.token?.id != token?.id ||
        oldDelegate.token?.x != token?.x ||
        oldDelegate.token?.y != token?.y ||
        oldDelegate.token?.size != token?.size ||
        oldDelegate.gridSize != gridSize;
  }
}

class _SelectedGroupBoundsPainter extends CustomPainter {
  final List<BoardToken> tokens;
  final double gridSize;

  const _SelectedGroupBoundsPainter({
    required this.tokens,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tokens.isEmpty) return;
    final left = tokens.map((token) => token.x).reduce(math.min) * gridSize;
    final top = tokens.map((token) => token.y).reduce(math.min) * gridSize;
    final right = tokens
            .map((token) => token.x + token.size)
            .reduce(math.max)
            .toDouble() *
        gridSize;
    final bottom = tokens
            .map((token) => token.y + token.size)
            .reduce(math.max)
            .toDouble() *
        gridSize;
    final rect = Rect.fromLTRB(left, top, right, bottom).inflate(7);
    const color = StitchCodexPalette.bronzeBright;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.max(8, gridSize * 0.14)),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.max(8, gridSize * 0.14)),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, gridSize * 0.04),
    );
  }

  @override
  bool shouldRepaint(covariant _SelectedGroupBoundsPainter oldDelegate) {
    if (oldDelegate.gridSize != gridSize ||
        oldDelegate.tokens.length != tokens.length) {
      return true;
    }
    for (var index = 0; index < tokens.length; index++) {
      final previous = oldDelegate.tokens[index];
      final current = tokens[index];
      if (previous.id != current.id ||
          previous.x != current.x ||
          previous.y != current.y ||
          previous.size != current.size) {
        return true;
      }
    }
    return false;
  }
}

class _SelectionRectPainter extends CustomPainter {
  final Rect rect;

  const _SelectionRectPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final normalized = Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(rect.left, rect.right),
      math.max(rect.top, rect.bottom),
    );
    const color = StitchCodexPalette.cold;
    canvas.drawRRect(
      RRect.fromRectAndRadius(normalized, const Radius.circular(8)),
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(normalized, const Radius.circular(8)),
      Paint()
        ..color = color.withValues(alpha: 0.86)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionRectPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}

class _ActionRangePainter extends CustomPainter {
  final BoardToken token;
  final double gridSize;

  const _ActionRangePainter({
    required this.token,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rangeFeet = token.selectedActionRangeFeet;
    if (rangeFeet <= 0) return;

    final center = Offset(
      (token.x + token.size / 2) * gridSize,
      (token.y + token.size / 2) * gridSize,
    );
    final rangePixels = (rangeFeet / 5) * gridSize + gridSize * 0.48;
    const color = StitchCodexPalette.cold;

    canvas.drawCircle(
      center,
      rangePixels,
      Paint()
        ..color = color.withValues(alpha: 0.055)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      rangePixels,
      Paint()
        ..color = color.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final label = token.focusedActionName.isEmpty
        ? '$rangeFeet ft'
        : '${token.focusedActionName} - $rangeFeet ft';
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.min(260, size.width));
    final labelCenter =
        Offset(center.dx, math.max(22, center.dy - rangePixels));
    final labelRect = Rect.fromCenter(
      center: labelCenter,
      width: textPainter.width + 18,
      height: textPainter.height + 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(999)),
      Paint()..color = Colors.black.withValues(alpha: 0.76),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(999)),
      Paint()
        ..color = color.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(canvas, labelRect.topLeft + const Offset(9, 5));
  }

  @override
  bool shouldRepaint(covariant _ActionRangePainter oldDelegate) {
    return oldDelegate.token.x != token.x ||
        oldDelegate.token.y != token.y ||
        oldDelegate.token.selectedActionRangeFeet !=
            token.selectedActionRangeFeet ||
        oldDelegate.token.focusedActionName != token.focusedActionName ||
        oldDelegate.gridSize != gridSize;
  }
}

class _TargetLinkPainter extends CustomPainter {
  final BoardToken actor;
  final BoardToken target;
  final double gridSize;
  final bool inRange;

  const _TargetLinkPainter({
    required this.actor,
    required this.target,
    required this.gridSize,
    required this.inRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final actorCenter = Offset(
      (actor.x + actor.size / 2) * gridSize,
      (actor.y + actor.size / 2) * gridSize,
    );
    final targetCenter = Offset(
      (target.x + target.size / 2) * gridSize,
      (target.y + target.size / 2) * gridSize,
    );
    final distanceFeet = CombatBoardGeometry.distanceFeet(actor, target);
    final rangeFeet = actor.selectedActionRangeFeet;
    final accent = inRange
        ? StitchCodexPalette.bronzeBright
        : StitchCodexPalette.crimsonBright;

    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.82)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(actorCenter, targetCenter, shadowPaint);
    canvas.drawLine(actorCenter, targetCenter, linePaint);
    canvas.drawCircle(
      targetCenter,
      gridSize * 0.68,
      Paint()
        ..color = accent.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      targetCenter,
      gridSize * 0.68,
      Paint()
        ..color = accent.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    final midpoint = Offset(
      (actorCenter.dx + targetCenter.dx) / 2,
      (actorCenter.dy + targetCenter.dy) / 2,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text:
            rangeFeet > 0 ? '$distanceFeet/$rangeFeet ft' : '$distanceFeet ft',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelRect = Rect.fromCenter(
      center: midpoint,
      width: textPainter.width + 18,
      height: textPainter.height + 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(999)),
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(999)),
      Paint()
        ..color = accent.withValues(alpha: 0.36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(
      canvas,
      labelRect.topLeft + const Offset(9, 5),
    );
  }

  @override
  bool shouldRepaint(covariant _TargetLinkPainter oldDelegate) {
    return oldDelegate.actor.x != actor.x ||
        oldDelegate.actor.y != actor.y ||
        oldDelegate.target.x != target.x ||
        oldDelegate.target.y != target.y ||
        oldDelegate.actor.selectedActionRangeFeet !=
            actor.selectedActionRangeFeet ||
        oldDelegate.inRange != inRange ||
        oldDelegate.gridSize != gridSize;
  }
}

class _AreaEffectPreviewPainter extends CustomPainter {
  final BoardToken actor;
  final Offset targetCenter;
  final String shape;
  final int areaFeet;
  final double gridSize;

  const _AreaEffectPreviewPainter({
    required this.actor,
    required this.targetCenter,
    required this.shape,
    required this.areaFeet,
    required this.gridSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final normalizedShape = shape.toLowerCase().trim();
    final actorCenter = Offset(
      (actor.x + actor.size / 2) * gridSize,
      (actor.y + actor.size / 2) * gridSize,
    );
    final areaPixels = math.max(gridSize, (areaFeet / 5) * gridSize);
    const areaColor = StitchCodexPalette.crimsonBright;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = areaColor.withValues(alpha: 0.15);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, gridSize * 0.045)
      ..color = StitchCodexPalette.bronzeBright.withValues(alpha: 0.78);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(5, gridSize * 0.12)
      ..color = areaColor.withValues(alpha: 0.16);

    if (normalizedShape.contains('cone')) {
      final direction = targetCenter - actorCenter;
      final angle = direction.distance <= 0.1
          ? 0.0
          : math.atan2(direction.dy, direction.dx);
      final left = actorCenter +
          Offset(
            math.cos(angle - math.pi / 6) * areaPixels,
            math.sin(angle - math.pi / 6) * areaPixels,
          );
      final right = actorCenter +
          Offset(
            math.cos(angle + math.pi / 6) * areaPixels,
            math.sin(angle + math.pi / 6) * areaPixels,
          );
      final path = Path()
        ..moveTo(actorCenter.dx, actorCenter.dy)
        ..lineTo(left.dx, left.dy)
        ..quadraticBezierTo(
          targetCenter.dx,
          targetCenter.dy,
          right.dx,
          right.dy,
        )
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, stroke);
      _drawAimMarker(canvas, targetCenter);
      _drawAreaLabel(canvas, targetCenter, 'CONE $areaFeet ft');
      return;
    }

    if (normalizedShape.contains('line')) {
      final direction = targetCenter - actorCenter;
      final angle = direction.distance <= 0.1
          ? 0.0
          : math.atan2(direction.dy, direction.dx);
      final end = actorCenter +
          Offset(math.cos(angle) * areaPixels, math.sin(angle) * areaPixels);
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = gridSize * 0.88
        ..color = areaColor.withValues(alpha: 0.15);
      canvas.drawLine(actorCenter, end, linePaint);
      canvas.drawLine(actorCenter, end, glow);
      canvas.drawLine(actorCenter, end, stroke);
      _drawAimMarker(canvas, targetCenter);
      _drawAreaLabel(canvas, end, 'LINE $areaFeet ft');
      return;
    }

    if (normalizedShape.contains('cube')) {
      final side = areaPixels;
      final rect = Rect.fromCenter(
        center: targetCenter,
        width: side,
        height: side,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(gridSize * 0.12)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(gridSize * 0.12)),
        glow,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(gridSize * 0.12)),
        stroke,
      );
      _drawAimMarker(canvas, targetCenter);
      _drawAreaLabel(canvas, targetCenter, 'CUBE $areaFeet ft');
      return;
    }

    canvas.drawCircle(targetCenter, areaPixels, fill);
    canvas.drawCircle(targetCenter, areaPixels, glow);
    canvas.drawCircle(targetCenter, areaPixels, stroke);
    _drawAimMarker(canvas, targetCenter);
    _drawAreaLabel(canvas, targetCenter, 'AREA $areaFeet ft');
  }

  void _drawAimMarker(Canvas canvas, Offset center) {
    final radius = math.max(5.0, gridSize * 0.16);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, gridSize * 0.04)
      ..color = const Color(0xFFFFF2C4).withValues(alpha: 0.95);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(5, gridSize * 0.10)
      ..color = StitchCodexPalette.bronzeBright.withValues(alpha: 0.22);
    canvas.drawCircle(center, radius * 1.55, glow);
    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(
      center + Offset(-radius * 1.7, 0),
      center + Offset(radius * 1.7, 0),
      paint,
    );
    canvas.drawLine(
      center + Offset(0, -radius * 1.7),
      center + Offset(0, radius * 1.7),
      paint,
    );
  }

  void _drawAreaLabel(Canvas canvas, Offset center, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFFFF2C4),
          fontFamily: StitchTypography.data,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = center + Offset(-painter.width / 2, -gridSize * 0.78);
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offset.dx - 7,
        offset.dy - 4,
        painter.width + 14,
        painter.height + 8,
      ),
      const Radius.circular(999),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = Colors.black.withValues(alpha: 0.70),
    );
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _AreaEffectPreviewPainter oldDelegate) {
    return oldDelegate.actor != actor ||
        oldDelegate.targetCenter != targetCenter ||
        oldDelegate.shape != shape ||
        oldDelegate.areaFeet != areaFeet ||
        oldDelegate.gridSize != gridSize;
  }
}

class _AreaEffectEventPainter extends CustomPainter {
  final BoardToken actor;
  final BoardToken target;
  final Offset targetCenter;
  final String shape;
  final int areaFeet;
  final double gridSize;
  final double progress;
  final Color color;
  final String damageType;
  final String label;
  final bool reducedMotion;

  const _AreaEffectEventPainter({
    required this.actor,
    required this.target,
    required this.targetCenter,
    required this.shape,
    required this.areaFeet,
    required this.gridSize,
    required this.progress,
    required this.color,
    required this.damageType,
    required this.label,
    this.reducedMotion = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final normalizedShape = shape.toLowerCase().trim();
    final actorCenter = Offset(
      (actor.x + actor.size / 2) * gridSize,
      (actor.y + actor.size / 2) * gridSize,
    );
    final t = reducedMotion ? 1.0 : progress.clamp(0.0, 1.0).toDouble();
    final fade =
        reducedMotion ? 0.76 : (1.0 - t * 0.62).clamp(0.0, 1.0).toDouble();
    final pulse = reducedMotion
        ? 1.0
        : Curves.easeOutBack.transform(t).clamp(0.0, 1.18).toDouble();
    final areaPixels = math.max(gridSize, (areaFeet / 5) * gridSize);
    final drawPixels = areaPixels * (0.72 + pulse * 0.28);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.24 * fade);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(3, gridSize * 0.07) * (1.0 + t * 0.18)
      ..color = color.withValues(alpha: 0.92 * fade);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(10, gridSize * 0.18) * (1.0 + t * 0.2)
      ..color = color.withValues(alpha: 0.22 * fade);
    final spark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2, gridSize * 0.045)
      ..color = color.withValues(alpha: 0.78 * fade);

    Offset labelCenter = targetCenter;
    if (normalizedShape.contains('cone')) {
      final direction = targetCenter - actorCenter;
      final angle = direction.distance <= 0.1
          ? 0.0
          : math.atan2(direction.dy, direction.dx);
      final left = actorCenter +
          Offset(
            math.cos(angle - math.pi / 6) * drawPixels,
            math.sin(angle - math.pi / 6) * drawPixels,
          );
      final right = actorCenter +
          Offset(
            math.cos(angle + math.pi / 6) * drawPixels,
            math.sin(angle + math.pi / 6) * drawPixels,
          );
      final path = Path()
        ..moveTo(actorCenter.dx, actorCenter.dy)
        ..lineTo(left.dx, left.dy)
        ..quadraticBezierTo(
          targetCenter.dx,
          targetCenter.dy,
          right.dx,
          right.dy,
        )
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, outer);
      canvas.drawPath(path, stroke);
      if (!reducedMotion) {
        _drawElementalTexture(canvas, actorCenter, targetCenter, spark, t);
      }
      labelCenter = actorCenter +
          Offset(math.cos(angle) * drawPixels, math.sin(angle) * drawPixels);
    } else if (normalizedShape.contains('line')) {
      final direction = targetCenter - actorCenter;
      final angle = direction.distance <= 0.1
          ? 0.0
          : math.atan2(direction.dy, direction.dx);
      final end = actorCenter +
          Offset(math.cos(angle) * drawPixels, math.sin(angle) * drawPixels);
      final lineFill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = gridSize * (0.72 + t * 0.26)
        ..color = color.withValues(alpha: 0.18 * fade);
      canvas.drawLine(actorCenter, end, lineFill);
      canvas.drawLine(actorCenter, end, outer);
      canvas.drawLine(actorCenter, end, stroke);
      if (!reducedMotion) {
        _drawElementalTexture(canvas, actorCenter, end, spark, t);
      }
      labelCenter = end;
    } else if (normalizedShape.contains('cube')) {
      final rect = Rect.fromCenter(
        center: targetCenter,
        width: drawPixels,
        height: drawPixels,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(gridSize * 0.16),
      );
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, outer);
      canvas.drawRRect(rrect, stroke);
      if (!reducedMotion) {
        _drawElementalTexture(canvas, targetCenter, targetCenter, spark, t);
      }
    } else {
      canvas.drawCircle(targetCenter, drawPixels, fill);
      canvas.drawCircle(targetCenter, drawPixels, outer);
      canvas.drawCircle(targetCenter, drawPixels, stroke);
      if (!reducedMotion) {
        _drawElementalTexture(canvas, targetCenter, targetCenter, spark, t);
      }
    }

    _drawEventLabel(canvas, labelCenter, fade);
  }

  void _drawElementalTexture(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double t,
  ) {
    final normalized = damageType.toLowerCase().trim();
    if (normalized.isEmpty) return;
    final direction = end - start;
    final directionLength = direction.distance;
    final baseAngle = directionLength <= 0.1
        ? -math.pi / 2
        : math.atan2(direction.dy, direction.dx);
    final center = directionLength <= 0.1 ? start : start + direction * 0.58;

    if (normalized == 'lightning') {
      for (var i = 0; i < 5; i++) {
        final side = i.isEven ? 1.0 : -1.0;
        final origin = center +
            Offset(
              math.cos(baseAngle) * gridSize * (i - 2) * 0.46,
              math.sin(baseAngle) * gridSize * (i - 2) * 0.46,
            );
        final a = origin +
            Offset(
                  math.cos(baseAngle + side * math.pi / 2),
                  math.sin(baseAngle + side * math.pi / 2),
                ) *
                gridSize *
                (0.22 + t * 0.12);
        final b = origin +
            Offset(math.cos(baseAngle), math.sin(baseAngle)) *
                gridSize *
                (0.34 + t * 0.16);
        canvas.drawLine(a, b, paint);
      }
      return;
    }

    final count = normalized == 'fire' ? 18 : 12;
    for (var i = 0; i < count; i++) {
      final angle = i * math.pi * 2 / count + t * 0.9;
      final spread = gridSize * (0.42 + (i % 4) * 0.16 + t * 0.28);
      final particleCenter =
          center + Offset(math.cos(angle), math.sin(angle)) * spread;
      if (normalized == 'cold') {
        final half = gridSize * 0.08;
        canvas.drawLine(
          particleCenter + Offset(-half, 0),
          particleCenter + Offset(half, 0),
          paint,
        );
        canvas.drawLine(
          particleCenter + Offset(0, -half),
          particleCenter + Offset(0, half),
          paint,
        );
      } else {
        canvas.drawCircle(
          particleCenter,
          math.max(2, gridSize * (normalized == 'fire' ? 0.055 : 0.04)),
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
      }
    }
  }

  void _drawEventLabel(Canvas canvas, Offset center, double fade) {
    final text = label.trim().isEmpty ? 'AREA' : label.trim();
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: fade),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);
    final offset = center + Offset(-painter.width / 2, -gridSize * 0.9);
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offset.dx - 9,
        offset.dy - 5,
        painter.width + 18,
        painter.height + 10,
      ),
      const Radius.circular(999),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = Colors.black.withValues(alpha: 0.78 * fade),
    );
    canvas.drawRRect(
      bg,
      Paint()
        ..color = color.withValues(alpha: 0.72 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _AreaEffectEventPainter oldDelegate) {
    return oldDelegate.actor != actor ||
        oldDelegate.target != target ||
        oldDelegate.targetCenter != targetCenter ||
        oldDelegate.shape != shape ||
        oldDelegate.areaFeet != areaFeet ||
        oldDelegate.gridSize != gridSize ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.damageType != damageType ||
        oldDelegate.label != label ||
        oldDelegate.reducedMotion != reducedMotion;
  }
}

class _BattleGridPainter extends CustomPainter {
  final double gridSize;
  final int columns;
  final int rows;

  const _BattleGridPainter({
    required this.gridSize,
    required this.columns,
    required this.rows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = StitchCodexPalette.bronzeMuted.withValues(alpha: 0.22)
      ..strokeWidth = 0.9;
    final majorPaint = Paint()
      ..color = StitchCodexPalette.bronze.withValues(alpha: 0.36)
      ..strokeWidth = 1.2;
    final framePaint = Paint()
      ..color = StitchCodexPalette.bronzeBright.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var x = 0; x <= columns; x++) {
      final dx = x * gridSize;
      canvas.drawLine(
        Offset(dx, 0),
        Offset(dx, rows * gridSize),
        x % 5 == 0 ? majorPaint : minorPaint,
      );
    }

    for (var y = 0; y <= rows; y++) {
      final dy = y * gridSize;
      canvas.drawLine(
        Offset(0, dy),
        Offset(columns * gridSize, dy),
        y % 5 == 0 ? majorPaint : minorPaint,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, columns * gridSize, rows * gridSize),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BattleGridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
        oldDelegate.columns != columns ||
        oldDelegate.rows != rows;
  }
}

class _BattleMapTexturePainter extends CustomPainter {
  const _BattleMapTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final contourPaint = Paint()
      ..color = StitchCodexPalette.bronze.withValues(alpha: 0.045)
      ..strokeWidth = 1.5;
    final mistPaint = Paint()
      ..color = StitchCodexPalette.ground.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 18; i++) {
      final y = size.height * (i / 17);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + math.sin(i) * 30),
        contourPaint,
      );
    }

    for (var i = 0; i < 7; i++) {
      final left = size.width * ((i * 0.19) % 1);
      final top = size.height * ((i * 0.31) % 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, size.width * 0.24, size.height * 0.16),
          const Radius.circular(18),
        ),
        mistPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BattleMapTexturePainter oldDelegate) => false;
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

BoardToken? _tokenById(List<BoardToken> tokens, String? tokenId) {
  if (tokenId == null) return null;
  for (final token in tokens) {
    if (token.id == tokenId) return token;
  }
  return null;
}

BoardToken? _tokenByRefId(List<BoardToken> tokens, String? refId) {
  if (refId == null || refId.isEmpty) return null;
  for (final token in tokens) {
    if (token.refId == refId) return token;
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

BoardToken? _latestAreaEventToken(List<BoardToken> tokens) {
  final eventTokens = tokens
      .where(
        (token) =>
            token.lastEventAreaShape.isNotEmpty &&
            token.lastEventAreaFeet > 0 &&
            token.lastEventId.isNotEmpty,
      )
      .toList();
  if (eventTokens.isEmpty) return null;
  eventTokens.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return eventTokens.first;
}

int _eventDicePriority(BoardToken token) {
  if (token.lastEventDiceNotation.trim().isNotEmpty) return 2;
  if (token.lastEventKind.toLowerCase().trim() == 'manual') return 1;
  return 0;
}

bool _isDiceRollPending(BoardToken? token) {
  return token != null &&
      token.lastEventLabel.isNotEmpty &&
      token.lastEventDiceNotation.trim().isNotEmpty &&
      token.lastEventRollValues.isEmpty;
}

bool _cellHasToken(List<BoardToken> tokens, int x, int y) {
  for (final token in tokens) {
    if (x >= token.x &&
        x < token.x + token.size &&
        y >= token.y &&
        y < token.y + token.size) {
      return true;
    }
  }
  return false;
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
