import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/battle_scene.dart';
import '../models/board_token.dart';
import '../utils/image_path_utils.dart';
import 'battle_board_dice_box_overlay.dart';
import 'battle_board_dice_fall_overlay.dart';

class BattleBoardView extends StatelessWidget {
  final BattleScene scene;
  final List<BoardToken> tokens;
  final bool readOnly;
  final Future<void> Function(BoardToken token, int x, int y)? onMoveToken;
  final Future<void> Function(int x, int y)? onBoardCellTap;
  final ValueChanged<BoardToken>? onTokenTap;
  final String? selectedTokenId;
  final BoardToken? manualRollToken;

  const BattleBoardView({
    super.key,
    required this.scene,
    required this.tokens,
    this.readOnly = false,
    this.onMoveToken,
    this.onBoardCellTap,
    this.onTokenTap,
    this.selectedTokenId,
    this.manualRollToken,
  });

  @override
  Widget build(BuildContext context) {
    final boardWidth = scene.gridColumns * scene.gridSize.toDouble();
    final boardHeight = scene.gridRows * scene.gridSize.toDouble();
    final boardKey = GlobalKey();
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
                token.id != manualRollToken?.id &&
                token.id != eventToken?.id,
          )
          .toList(growable: false),
    );
    final diceEventToken = _latestEventToken([
      if (eventToken != null) eventToken,
      if (manualRollToken != null) manualRollToken!,
      if (manualEventToken != null) manualEventToken,
    ]);
    final selectedMoveToken = _tokenById(visibleTokens, selectedTokenId);

    return InteractiveViewer(
      minScale: 0.35,
      maxScale: 3,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(280),
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
        child: DragTarget<BoardToken>(
          key: boardKey,
          onAcceptWithDetails: readOnly || onMoveToken == null
              ? null
              : (details) async {
                  final boardContext = boardKey.currentContext;
                  final renderBox =
                      boardContext?.findRenderObject() as RenderBox?;
                  if (renderBox == null) return;

                  final local = renderBox.globalToLocal(details.offset);
                  final x = (local.dx / scene.gridSize)
                      .round()
                      .clamp(0, scene.gridColumns - 1)
                      .toInt();
                  final y = (local.dy / scene.gridSize)
                      .round()
                      .clamp(0, scene.gridRows - 1)
                      .toInt();
                  await onMoveToken!(details.data, x, y);
                },
          builder: (context, _, __) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: readOnly ||
                      onBoardCellTap == null ||
                      selectedMoveToken == null
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
                      unawaited(onBoardCellTap!(x, y));
                    },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _BattleBoardMap(scene: scene),
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
                  if (activeToken != null)
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
                  if (activeToken != null &&
                      activeToken.selectedActionRangeFeet > 0)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ActionRangePainter(
                          token: activeToken,
                          gridSize: scene.gridSize.toDouble(),
                        ),
                      ),
                    ),
                  if (activeToken != null && targetToken != null)
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
                  if (activeToken != null &&
                      targetToken != null &&
                      activeToken.selectedActionAreaFeet > 0)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AreaEffectPreviewPainter(
                          actor: activeToken,
                          target: targetToken,
                          shape: activeToken.selectedActionAreaShape,
                          areaFeet: activeToken.selectedActionAreaFeet,
                          gridSize: scene.gridSize.toDouble(),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BattleGridPainter(
                        gridSize: scene.gridSize.toDouble(),
                        columns: scene.gridColumns,
                        rows: scene.gridRows,
                      ),
                    ),
                  ),
                  for (final token in visibleTokens)
                    _BoardTokenWidget(
                      key: ValueKey(token.id),
                      token: token,
                      gridSize: scene.gridSize,
                      readOnly: readOnly,
                      selectedForMove: token.id == selectedMoveToken?.id,
                      onTap: onTokenTap,
                    ),
                  if (kIsWeb) ...[
                    Positioned.fill(
                      child: BattleBoardDiceBoxOverlay(
                        boardViewportId: scene.id,
                        token: diceEventToken,
                        gridSize: scene.gridSize.toDouble(),
                      ),
                    ),
                  ] else
                    Positioned.fill(
                      child: BattleBoardDiceFallOverlay(
                        token: diceEventToken,
                        gridSize: scene.gridSize.toDouble(),
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
      return buildImageFromPath(
        scene.mapImageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF153A36),
            Color(0xFF2A233B),
            Color(0xFF141821),
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

class _BoardTokenWidget extends StatelessWidget {
  final BoardToken token;
  final int gridSize;
  final bool readOnly;
  final bool selectedForMove;
  final ValueChanged<BoardToken>? onTap;

  const _BoardTokenWidget({
    super.key,
    required this.token,
    required this.gridSize,
    required this.readOnly,
    required this.selectedForMove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokenSize = token.size * gridSize.toDouble();
    final left = token.x * gridSize.toDouble();
    final top = token.y * gridSize.toDouble();
    final child = _TokenDisc(
      token: token,
      size: tokenSize,
      selectedForMove: selectedForMove,
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

  const _TokenDisc({
    required this.token,
    required this.size,
    required this.selectedForMove,
  });

  @override
  Widget build(BuildContext context) {
    final isEnemy = token.type == 'monster' || token.type == 'enemy';
    final hpRatio = token.maxHp <= 0
        ? 0.0
        : (token.currentHp / token.maxHp).clamp(0.0, 1.0);
    final teamAccent =
        isEnemy ? const Color(0xFFFF5C6C) : const Color(0xFF7DD3FC);
    final accent = selectedForMove
        ? const Color(0xFFFFD166)
        : token.isTargeted
            ? const Color(0xFFFFB454)
            : token.isActive
                ? const Color(0xFF64F4A2)
                : teamAccent;
    final eventColor = _eventColor(token.lastEventKind);
    final highlighted = selectedForMove || token.isActive || token.isTargeted;
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
                color: Colors.black.withValues(alpha: 0.70),
                border: Border.all(color: accent, width: borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(
                      alpha: highlighted ? 0.50 : 0.28,
                    ),
                    blurRadius: highlighted ? 24.0 : 14.0,
                    spreadRadius: highlighted ? 3.0 : 1.0,
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
          Positioned(
            left: -size * 0.08,
            right: -size * 0.08,
            bottom: -18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 6,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: hpRatio,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: hpRatio <= 0.35
                                  ? const Color(0xFFFF5C6C)
                                  : const Color(0xFF64F4A2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  token.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: math.max(10, size * 0.13),
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 5),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (token.isActive)
            Positioned(
              top: -8,
              left: -4,
              child: _TokenBadge(
                icon: Icons.bolt_rounded,
                label: '${token.remainingMovementFeet} ft',
                color: const Color(0xFF64F4A2),
              ),
            ),
          if (selectedForMove)
            Positioned(
              top: -8,
              left: token.isActive ? 72 : -4,
              child: const _TokenBadge(
                icon: Icons.touch_app_rounded,
                label: 'Mover',
                color: Color(0xFFFFD166),
              ),
            ),
          if (token.isTargeted)
            Positioned(
              top: -8,
              right: -4,
              child: _TokenBadge(
                icon: token.isTargetInRange
                    ? Icons.center_focus_strong_rounded
                    : Icons.warning_amber_rounded,
                label: token.targetDistanceFeet > 0
                    ? '${token.targetDistanceFeet} ft'
                    : 'Target',
                color: token.isTargetInRange
                    ? const Color(0xFFFFB454)
                    : const Color(0xFFFF5C6C),
              ),
            ),
          if (token.lastEventLabel.isNotEmpty)
            Positioned(
              left: -8,
              right: -8,
              top: size * 0.32,
              child: Center(
                child: _ImpactBanner(
                  label: token.lastEventLabel,
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
        ],
      ),
    );
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
      ..color = const Color(0xFF64F4A2).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final spentFill = Paint()
      ..color = const Color(0xFFFFB454).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final edge = Paint()
      ..color = const Color(0xFF64F4A2).withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final originX = token.movementOriginX.clamp(0, columns - 1).toInt();
    final originY = token.movementOriginY.clamp(0, rows - 1).toInt();
    final currentDistance =
        (token.x - originX).abs() + (token.y - originY).abs();
    final startX = math.max(0, originX - budgetSquares);
    final endX = math.min(columns - 1, originX + budgetSquares);
    final startY = math.max(0, originY - budgetSquares);
    final endY = math.min(rows - 1, originY + budgetSquares);

    for (var y = startY; y <= endY; y++) {
      for (var x = startX; x <= endX; x++) {
        final distance = (x - originX).abs() + (y - originY).abs();
        if (distance > budgetSquares) continue;
        final isSpent = distance <= currentDistance &&
            ((x - token.x).abs() + (y - token.y).abs()) <=
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
      Paint()..color = const Color(0xFF64F4A2).withValues(alpha: 0.95),
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
    final color = const Color(0xFFFFD166);

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
    final color = const Color(0xFF7DD3FC);

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
    final distanceFeet =
        math.max((actor.x - target.x).abs(), (actor.y - target.y).abs()) * 5;
    final rangeFeet = actor.selectedActionRangeFeet;
    final accent = inRange ? const Color(0xFFFFB454) : const Color(0xFFFF5C6C);

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
  final BoardToken target;
  final String shape;
  final int areaFeet;
  final double gridSize;

  const _AreaEffectPreviewPainter({
    required this.actor,
    required this.target,
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
    final targetCenter = Offset(
      (target.x + target.size / 2) * gridSize,
      (target.y + target.size / 2) * gridSize,
    );
    final areaPixels = math.max(gridSize, (areaFeet / 5) * gridSize);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB85CFF).withValues(alpha: 0.16);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, gridSize * 0.045)
      ..color = const Color(0xFFFFD166).withValues(alpha: 0.78);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(5, gridSize * 0.12)
      ..color = const Color(0xFFB85CFF).withValues(alpha: 0.16);

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
        ..color = const Color(0xFFB85CFF).withValues(alpha: 0.16);
      canvas.drawLine(actorCenter, end, linePaint);
      canvas.drawLine(actorCenter, end, glow);
      canvas.drawLine(actorCenter, end, stroke);
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
      _drawAreaLabel(canvas, targetCenter, 'CUBE $areaFeet ft');
      return;
    }

    canvas.drawCircle(targetCenter, areaPixels, fill);
    canvas.drawCircle(targetCenter, areaPixels, glow);
    canvas.drawCircle(targetCenter, areaPixels, stroke);
    _drawAreaLabel(canvas, targetCenter, 'AREA $areaFeet ft');
  }

  void _drawAreaLabel(Canvas canvas, Offset center, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFFFF2C4),
          fontSize: 12,
          fontWeight: FontWeight.w900,
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
        oldDelegate.target != target ||
        oldDelegate.shape != shape ||
        oldDelegate.areaFeet != areaFeet ||
        oldDelegate.gridSize != gridSize;
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
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 1.4;
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

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
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 2;
    final mistPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
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

BoardToken? _latestEventToken(List<BoardToken> tokens) {
  final eventTokens =
      tokens.where((token) => token.lastEventLabel.isNotEmpty).toList();
  if (eventTokens.isEmpty) return null;
  eventTokens.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return eventTokens.first;
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
