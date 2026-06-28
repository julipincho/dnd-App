import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme.dart';

class CombatArenaBackdrop extends StatelessWidget {
  final int round;

  const CombatArenaBackdrop({
    super.key,
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
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          StitchCodexPalette.ground,
          StitchCodexPalette.surfaceMuted,
          const Color(0xFF090604),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    _drawGlow(
      canvas,
      center: Offset(size.width * 0.12, size.height * 0.30),
      radius: size.shortestSide * 0.54,
      color: StitchCodexPalette.bronze,
      alpha: 0.14,
    );
    _drawGlow(
      canvas,
      center: Offset(size.width * 0.88, size.height * 0.28),
      radius: size.shortestSide * 0.48,
      color: StitchCodexPalette.crimson,
      alpha: 0.12,
    );
    _drawGlow(
      canvas,
      center: Offset(size.width * 0.52, size.height * 0.88),
      radius: size.shortestSide * 0.48,
      color: StitchCodexPalette.bronzeMuted,
      alpha: 0.07,
    );

    _paintTacticalGrid(canvas, size, alpha: 0.075);

    final runePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = StitchCodexPalette.bronze.withValues(alpha: 0.07);
    final center = Offset(size.width * 0.50, size.height * 0.42);
    final pulse = math.sin(round * 0.7) * 4;
    for (final radius in [96.0, 148.0, 206.0]) {
      canvas.drawCircle(center, radius + pulse, runePaint);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 16 + pulse),
        math.pi * 0.12,
        math.pi * 0.38,
        false,
        runePaint..color = StitchCodexPalette.crimson.withValues(alpha: 0.07),
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
    Canvas canvas, {
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

class CombatTacticalGridOverlay extends StatelessWidget {
  const CombatTacticalGridOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _CombatTacticalGridPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _CombatTacticalGridPainter extends CustomPainter {
  const _CombatTacticalGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintTacticalGrid(canvas, size, alpha: 0.12);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _paintTacticalGrid(
  Canvas canvas,
  Size size, {
  required double alpha,
}) {
  final gridRect = Rect.fromLTWH(
    size.width * 0.035,
    size.height * 0.05,
    size.width * 0.93,
    size.height * 0.90,
  );
  final gridPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..color = StitchCodexPalette.bronzeMuted.withValues(alpha: alpha);
  final majorPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = StitchCodexPalette.bronze.withValues(alpha: alpha * 1.35);

  for (var column = 0; column <= 12; column++) {
    final x = gridRect.left + (gridRect.width * column / 12);
    canvas.drawLine(
      Offset(x, gridRect.top),
      Offset(x, gridRect.bottom),
      column == 0 || column == 12 ? majorPaint : gridPaint,
    );
  }
  for (var row = 0; row <= 8; row++) {
    final y = gridRect.top + (gridRect.height * row / 8);
    canvas.drawLine(
      Offset(gridRect.left, y),
      Offset(gridRect.right, y),
      row == 0 || row == 8 ? majorPaint : gridPaint,
    );
  }
}
