import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../combat_arena_backdrop.dart';

class CombatCinematicColors {
  static const gold = Color(0xFF9C7140);
  static const goldBright = Color(0xFFE5B46C);
  static const paper = Color(0xFFF2D8B5);
  static const actionTextMuted = Color(0xFFC3A57E);
  static const blood = Color(0xFF8F1E19);
}

class CombatCinematicDungeonBackdrop extends StatelessWidget {
  const CombatCinematicDungeonBackdrop({super.key});

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
          errorBuilder: (_, __, ___) => const CombatArenaBackdrop(round: 1),
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

class CombatCinematicPanelFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color borderColor;
  final double backgroundAlpha;

  const CombatCinematicPanelFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor = CombatCinematicColors.gold,
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

class CombatCinematicTinyPill extends StatelessWidget {
  final String label;
  final Color color;

  const CombatCinematicTinyPill({
    super.key,
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
          color: CombatCinematicColors.paper,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class CombatCinematicEconomyDot extends StatelessWidget {
  final IconData icon;
  final bool spent;
  final Color color;

  const CombatCinematicEconomyDot({
    super.key,
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
        color:
            spent ? CombatCinematicColors.blood : color.withValues(alpha: 0.92),
        size: 13,
      ),
    );
  }
}

class CombatCinematicEconomyPill extends StatelessWidget {
  final String label;
  final bool spent;
  final IconData icon;
  final String? tooltip;

  const CombatCinematicEconomyPill({
    super.key,
    required this.label,
    required this.spent,
    required this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        spent ? CombatCinematicColors.blood : CombatCinematicColors.goldBright;
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

class CombatCinematicToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool selected;

  const CombatCinematicToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? CombatCinematicColors.goldBright
        : CombatCinematicColors.paper.withValues(alpha: 0.72);

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
                  ? CombatCinematicColors.gold.withValues(alpha: 0.18)
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

class CombatCinematicQueueChip extends StatelessWidget {
  final int index;
  final int total;
  final String? name;

  const CombatCinematicQueueChip({
    super.key,
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
        color: CombatCinematicColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: CombatCinematicColors.gold.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.playlist_play_outlined,
            color: CombatCinematicColors.goldBright,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${math.min(index + 1, total)}/$total ${name ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CombatCinematicColors.paper,
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

class CombatCinematicRollModeSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const CombatCinematicRollModeSegment({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? CombatCinematicColors.goldBright
        : CombatCinematicColors.paper;
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
                ? CombatCinematicColors.gold.withValues(alpha: 0.20)
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

class CombatCinematicTargetRingPainter extends CustomPainter {
  final Color color;
  final bool active;
  final bool enemy;

  const CombatCinematicTargetRingPainter({
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
      ..color = (enemy ? CombatCinematicColors.blood : color)
          .withValues(alpha: active ? 0.75 : 0.34);
    canvas.drawArc(
      rect.inflate(6),
      -math.pi * 0.84,
      math.pi * 0.18,
      false,
      tickPaint,
    );
    canvas.drawArc(
      rect.inflate(6),
      math.pi * 0.16,
      math.pi * 0.18,
      false,
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CombatCinematicTargetRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.active != active ||
        oldDelegate.enemy != enemy;
  }
}

class CombatCinematicArenaFloorPainter extends CustomPainter {
  final Color partyColor;
  final Color enemyColor;

  const CombatCinematicArenaFloorPainter({
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
      ..color = CombatCinematicColors.gold.withValues(alpha: 0.18);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant CombatCinematicArenaFloorPainter oldDelegate) {
    return oldDelegate.partyColor != partyColor ||
        oldDelegate.enemyColor != enemyColor;
  }
}
