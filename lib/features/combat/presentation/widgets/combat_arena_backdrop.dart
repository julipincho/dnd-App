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
      center: Offset(size.width * 0.18, size.height * 0.18),
      radius: size.shortestSide * 0.62,
      color: tokens.accentRead,
      alpha: 0.16,
    );
    _drawGlow(
      canvas,
      center: Offset(size.width * 0.82, size.height * 0.22),
      radius: size.shortestSide * 0.54,
      color: tokens.accentAction,
      alpha: 0.15,
    );
    _drawGlow(
      canvas,
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
