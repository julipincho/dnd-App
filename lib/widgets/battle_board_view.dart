import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battle_scene.dart';
import '../models/board_token.dart';
import '../utils/image_path_utils.dart';

class BattleBoardView extends StatelessWidget {
  final BattleScene scene;
  final List<BoardToken> tokens;
  final bool readOnly;
  final Future<void> Function(BoardToken token, int x, int y)? onMoveToken;

  const BattleBoardView({
    super.key,
    required this.scene,
    required this.tokens,
    this.readOnly = false,
    this.onMoveToken,
  });

  @override
  Widget build(BuildContext context) {
    final boardWidth = scene.gridColumns * scene.gridSize.toDouble();
    final boardHeight = scene.gridRows * scene.gridSize.toDouble();
    final boardKey = GlobalKey();

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
                      .clamp(0, scene.gridColumns - 1);
                  final y = (local.dy / scene.gridSize)
                      .round()
                      .clamp(0, scene.gridRows - 1);
                  await onMoveToken!(details.data, x, y);
                },
          builder: (context, _, __) {
            return Stack(
              children: [
                Positioned.fill(
                  child: _BattleBoardMap(scene: scene),
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
                for (final token in tokens.where((token) => token.isVisible))
                  _BoardTokenWidget(
                    token: token,
                    gridSize: scene.gridSize,
                    readOnly: readOnly,
                  ),
              ],
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
            Color(0xFF1C2630),
            Color(0xFF213A34),
            Color(0xFF302538),
          ],
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

  const _BoardTokenWidget({
    required this.token,
    required this.gridSize,
    required this.readOnly,
  });

  @override
  Widget build(BuildContext context) {
    final tokenSize = token.size * gridSize.toDouble();
    final left = token.x * gridSize.toDouble();
    final top = token.y * gridSize.toDouble();
    final child = _TokenDisc(token: token, size: tokenSize);

    if (readOnly) {
      return Positioned(
        left: left,
        top: top,
        width: tokenSize,
        height: tokenSize,
        child: child,
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: tokenSize,
      height: tokenSize,
      child: Draggable<BoardToken>(
        data: token,
        feedback: Material(
          type: MaterialType.transparency,
          child: Opacity(opacity: 0.78, child: child),
        ),
        childWhenDragging: Opacity(opacity: 0.38, child: child),
        child: child,
      ),
    );
  }
}

class _TokenDisc extends StatelessWidget {
  final BoardToken token;
  final double size;

  const _TokenDisc({
    required this.token,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isEnemy = token.type == 'monster' || token.type == 'enemy';
    final hpRatio = token.maxHp <= 0
        ? 0.0
        : (token.currentHp / token.maxHp).clamp(0.0, 1.0);
    final accent = isEnemy ? Colors.redAccent : const Color(0xFF7DD3FC);

    return Tooltip(
      message: '${token.name} ${token.currentHp}/${token.maxHp} HP',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.68),
          border: Border.all(color: accent, width: math.max(2, size * 0.045)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
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
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: hpRatio,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: hpRatio <= 0.35
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    token.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: math.max(9, size * 0.13),
                      fontWeight: FontWeight.w800,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
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
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1;

    for (var x = 0; x <= columns; x++) {
      final dx = x * gridSize;
      canvas.drawLine(Offset(dx, 0), Offset(dx, rows * gridSize), paint);
    }

    for (var y = 0; y <= rows; y++) {
      final dy = y * gridSize;
      canvas.drawLine(Offset(0, dy), Offset(columns * gridSize, dy), paint);
    }
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
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 2;

    for (var i = 0; i < 16; i++) {
      final y = size.height * (i / 15);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + math.sin(i) * 28),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BattleMapTexturePainter oldDelegate) => false;
}
