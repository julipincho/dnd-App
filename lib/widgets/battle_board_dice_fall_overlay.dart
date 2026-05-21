import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/board_token.dart';

class BattleBoardDiceFallOverlay extends StatelessWidget {
  final BoardToken? token;
  final double gridSize;

  const BattleBoardDiceFallOverlay({
    super.key,
    required this.token,
    required this.gridSize,
  });

  @override
  Widget build(BuildContext context) {
    final eventToken = token;
    if (eventToken == null || eventToken.lastEventLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    final event = _DiceEvent.fromToken(eventToken);
    final tokenSize = eventToken.size * gridSize;
    final centerX = eventToken.x * gridSize + tokenSize / 2;
    final centerY = eventToken.y * gridSize + tokenSize / 2;
    final key = ValueKey(
      '${eventToken.id}-${eventToken.lastEventLabel}-${eventToken.updatedAt.microsecondsSinceEpoch}',
    );

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: centerX - 126,
            top: centerY - 188,
            width: 252,
            height: 252,
            child: TweenAnimationBuilder<double>(
              key: key,
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1120),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final t = value.clamp(0.0, 1.0);
                final fade = t < 0.84 ? 1.0 : (1.0 - t) / 0.16;
                return Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: child,
                );
              },
              child: Stack(
                children: [
                  _DiceImpactBurst(color: event.color),
                  _FallingBoardDie(
                    color: event.color,
                    sides: event.primarySides,
                    faceText: event.primaryFace,
                    sideTag: 'd${event.primarySides}',
                    size: 62,
                    start: const Offset(92, -6),
                    end: const Offset(92, 104),
                    spin: 2.65,
                    delay: 0,
                  ),
                  _FallingBoardDie(
                    color: event.secondaryColor,
                    sides: event.secondarySides.first,
                    faceText: event.secondaryFace,
                    sideTag: 'd${event.secondarySides.first}',
                    size: 40,
                    start: const Offset(38, 30),
                    end: const Offset(56, 134),
                    spin: -2.1,
                    delay: 0.11,
                  ),
                  _FallingBoardDie(
                    color: event.tertiaryColor,
                    sides: event.secondarySides.last,
                    faceText: '',
                    sideTag: 'd${event.secondarySides.last}',
                    size: 36,
                    start: const Offset(174, 28),
                    end: const Offset(150, 142),
                    spin: 2.35,
                    delay: 0.18,
                  ),
                  Positioned(
                    left: 30,
                    right: 30,
                    bottom: 18,
                    child: _DiceImpactLabel(
                      label: eventToken.lastEventLabel,
                      subtitle: event.subtitle,
                      color: event.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiceEvent {
  final Color color;
  final Color secondaryColor;
  final Color tertiaryColor;
  final int primarySides;
  final List<int> secondarySides;
  final String primaryFace;
  final String secondaryFace;
  final String subtitle;

  const _DiceEvent({
    required this.color,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.primarySides,
    required this.secondarySides,
    required this.primaryFace,
    required this.secondaryFace,
    required this.subtitle,
  });

  factory _DiceEvent.fromToken(BoardToken token) {
    final color = _eventColor(token.lastEventKind);
    final label = token.lastEventLabel;
    final kind = token.lastEventKind;
    final number = _lastNumber(label);
    final attackLike = _isAttackOrSave(kind, label);
    final healing = kind == 'heal';
    final damage = kind == 'damage';
    final primarySides = attackLike
        ? 20
        : healing
            ? 8
            : damage
                ? 8
                : 20;
    final companionSides = attackLike
        ? const [6, 4]
        : healing
            ? const [4, 6]
            : damage
                ? const [6, 12]
                : const [8, 4];

    return _DiceEvent(
      color: color,
      secondaryColor:
          Color.lerp(color, Colors.white, 0.16)!.withValues(alpha: 0.88),
      tertiaryColor:
          Color.lerp(color, Colors.black, 0.10)!.withValues(alpha: 0.76),
      primarySides: primarySides,
      secondarySides: companionSides,
      primaryFace: number == null ? _fallbackFace(kind) : '$number',
      secondaryFace: attackLike ? '' : _dieShortLabel(kind),
      subtitle: _subtitleFor(kind, label, primarySides),
    );
  }
}

class _DiceImpactBurst extends StatelessWidget {
  final Color color;

  const _DiceImpactBurst({required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final scale = 0.45 + value * 0.72;
          final opacity = (1 - value).clamp(0.0, 1.0);
          return Center(
            child: Transform.scale(
              scale: scale,
              child: Opacity(opacity: opacity * 0.42, child: child),
            ),
          );
        },
        child: CustomPaint(
          size: const Size.square(150),
          painter: _ImpactBurstPainter(color: color),
        ),
      ),
    );
  }
}

class _FallingBoardDie extends StatelessWidget {
  final Color color;
  final int sides;
  final String faceText;
  final String sideTag;
  final double size;
  final Offset start;
  final Offset end;
  final double spin;
  final double delay;

  const _FallingBoardDie({
    required this.color,
    required this.sides,
    required this.faceText,
    required this.sideTag,
    required this.size,
    required this.start,
    required this.end,
    required this.spin,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 920),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final delayed = ((value - delay) / (1 - delay)).clamp(0.0, 1.0);
          final drop = Curves.easeOutCubic.transform(delayed);
          final bounce = math.sin(delayed * math.pi);
          final wobble = math.sin(delayed * math.pi * 7) * (1 - delayed);
          final offset =
              Offset.lerp(start, end, drop)! + Offset(0, -24 * bounce);
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0018)
            ..rotateX((1 - delayed) * math.pi * 1.55 + wobble * 0.20)
            ..rotateY((1 - delayed) * math.pi * spin)
            ..rotateZ((1 - delayed) * math.pi * 1.18 + wobble * 0.12);

          return Transform.translate(
            offset: offset,
            child: Align(
              alignment: Alignment.topLeft,
              child: Transform(
                transform: matrix,
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: 0.78 + 0.22 * Curves.easeOutBack.transform(delayed),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _PolyhedralDiePainter(
                  color: color,
                  sides: sides,
                ),
              ),
              _DieFaceText(
                faceText: faceText,
                sideTag: sideTag,
                sides: sides,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DieFaceText extends StatelessWidget {
  final String faceText;
  final String sideTag;
  final int sides;

  const _DieFaceText({
    required this.faceText,
    required this.sideTag,
    required this.sides,
  });

  @override
  Widget build(BuildContext context) {
    final primary = faceText.trim();
    final text = primary.isEmpty ? sideTag : primary;
    final tag = primary.isEmpty ? '' : sideTag;
    final fontSize = text.length >= 3 ? 16.0 : 20.0;

    return IgnorePointer(
      child: Transform.rotate(
        angle: sides == 4 ? -0.02 : 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: 0.92,
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            if (tag.isNotEmpty)
              Text(
                tag,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

class _DiceImpactLabel extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;

  const _DiceImpactLabel({
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.66)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 20,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              ),
          ],
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
    final path = _pathForSides(size, sides);
    final bounds = Offset.zero & size;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path.shift(const Offset(0, 3)), shadow);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, 0.34)!,
          color.withValues(alpha: 0.96),
          Color.lerp(color, Colors.black, 0.54)!,
        ],
        stops: const [0, 0.48, 1],
      ).createShader(bounds);
    canvas.drawPath(path, fill);

    final facetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.26);
    _drawFacets(canvas, size, sides, path, facetPaint);

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.white.withValues(alpha: 0.82);
    canvas.drawPath(path, edgePaint);

    final darkEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawPath(path, darkEdge);
    canvas.drawPath(path, edgePaint);
  }

  Path _pathForSides(Size size, int sides) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.47;
    final path = Path();

    switch (sides) {
      case 4:
        final points = [
          Offset(center.dx, center.dy - radius * 0.94),
          Offset(center.dx + radius * 0.92, center.dy + radius * 0.76),
          Offset(center.dx - radius * 0.92, center.dy + radius * 0.76),
        ];
        _addPoints(path, points);
        break;
      case 6:
        final points = [
          Offset(center.dx - radius * 0.76, center.dy - radius * 0.58),
          Offset(center.dx + radius * 0.42, center.dy - radius * 0.72),
          Offset(center.dx + radius * 0.88, center.dy - radius * 0.12),
          Offset(center.dx + radius * 0.74, center.dy + radius * 0.70),
          Offset(center.dx - radius * 0.48, center.dy + radius * 0.82),
          Offset(center.dx - radius * 0.90, center.dy + radius * 0.18),
        ];
        _addPoints(path, points);
        break;
      case 8:
        final points = [
          Offset(center.dx, center.dy - radius),
          Offset(center.dx + radius * 0.86, center.dy),
          Offset(center.dx, center.dy + radius),
          Offset(center.dx - radius * 0.86, center.dy),
        ];
        _addPoints(path, points);
        break;
      case 10:
        final points = [
          Offset(center.dx, center.dy - radius),
          Offset(center.dx + radius * 0.76, center.dy - radius * 0.36),
          Offset(center.dx + radius * 0.58, center.dy + radius * 0.78),
          Offset(center.dx, center.dy + radius),
          Offset(center.dx - radius * 0.58, center.dy + radius * 0.78),
          Offset(center.dx - radius * 0.76, center.dy - radius * 0.36),
        ];
        _addPoints(path, points);
        break;
      case 12:
        _regularPolygon(path, center, radius, 5, -math.pi / 2);
        break;
      case 20:
      default:
        _regularPolygon(path, center, radius, 10, -math.pi / 2);
        break;
    }

    path.close();
    return path;
  }

  void _addPoints(Path path, List<Offset> points) {
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
  }

  void _regularPolygon(
    Path path,
    Offset center,
    double radius,
    int count,
    double startAngle,
  ) {
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
  }

  void _drawFacets(
    Canvas canvas,
    Size size,
    int sides,
    Path path,
    Paint paint,
  ) {
    final center = Offset(size.width / 2, size.height / 2);
    final metrics = path.computeMetrics().toList(growable: false);
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final length = metric.length;
    final count = switch (sides) {
      4 => 3,
      6 => 6,
      8 => 4,
      10 => 6,
      12 => 5,
      _ => 10,
    };

    for (var index = 0; index < count; index++) {
      final tangent = metric.getTangentForOffset(length * index / count);
      if (tangent == null) continue;
      canvas.drawLine(center, tangent.position, paint);
    }

    if (sides == 20) {
      final triangle = Path()
        ..moveTo(center.dx, center.dy - size.shortestSide * 0.26)
        ..lineTo(center.dx + size.shortestSide * 0.25, center.dy + 2)
        ..lineTo(center.dx - size.shortestSide * 0.25, center.dy + 2)
        ..close();
      canvas.drawPath(triangle, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PolyhedralDiePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.sides != sides;
  }
}

class _ImpactBurstPainter extends CustomPainter {
  final Color color;

  const _ImpactBurstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.44;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.42);
    canvas.drawCircle(center, radius * 0.62, ring);
    canvas.drawCircle(
        center, radius, ring..color = color.withValues(alpha: 0.18));

    final ray = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.42);
    for (var index = 0; index < 16; index++) {
      final angle = index * math.pi * 2 / 16;
      final inner = radius * 0.72;
      final outer = radius * (index.isEven ? 1.08 : 0.96);
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * inner,
          center.dy + math.sin(angle) * inner,
        ),
        Offset(
          center.dx + math.cos(angle) * outer,
          center.dy + math.sin(angle) * outer,
        ),
        ray,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactBurstPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

Color _eventColor(String eventKind) {
  return switch (eventKind) {
    'damage' => const Color(0xFFFF5C6C),
    'hit' => const Color(0xFFFFB454),
    'critical' => const Color(0xFF64F4A2),
    'heal' => const Color(0xFF64F4A2),
    'miss' => const Color(0xFF7DD3FC),
    'blocked' => const Color(0xFFFF5C6C),
    'save' => const Color(0xFF7DD3FC),
    _ => const Color(0xFF7DD3FC),
  };
}

bool _isAttackOrSave(String kind, String label) {
  final text = '$kind $label'.toLowerCase();
  return kind == 'hit' ||
      kind == 'miss' ||
      kind == 'critical' ||
      kind == 'blocked' ||
      text.contains('hit') ||
      text.contains('miss') ||
      text.contains('save') ||
      text.contains('d20');
}

int? _lastNumber(String label) {
  final matches = RegExp(r'-?\d+').allMatches(label).toList();
  if (matches.isEmpty) return null;
  return int.tryParse(matches.last.group(0) ?? '');
}

String _fallbackFace(String kind) {
  return switch (kind) {
    'critical' => '20',
    'miss' => '1',
    'blocked' => 'X',
    'damage' => 'DMG',
    'heal' => 'HP',
    _ => '',
  };
}

String _dieShortLabel(String kind) {
  return switch (kind) {
    'damage' => 'DMG',
    'heal' => 'HP',
    _ => '',
  };
}

String _subtitleFor(String kind, String label, int primarySides) {
  if (_isAttackOrSave(kind, label)) return 'd$primarySides roll';
  if (kind == 'heal') return 'healing dice';
  if (kind == 'damage') return 'damage dice';
  return '';
}
