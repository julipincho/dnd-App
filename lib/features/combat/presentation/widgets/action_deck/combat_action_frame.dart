import 'package:flutter/material.dart';

const _frameActionSurface = Color(0xFF16110D);
const _frameActionSurfaceRaised = Color(0xFF221812);
const _frameGoldBright = Color(0xFFE5B46C);

class CombatActionCardFrame extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool blocked;
  final bool prepared;
  final bool dense;

  const CombatActionCardFrame({
    super.key,
    required this.child,
    required this.color,
    required this.blocked,
    required this.prepared,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      clipBehavior: Clip.hardEdge,
      padding: EdgeInsets.all(dense ? 8 : 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: blocked
              ? [
                  const Color(0xFF4A211F),
                  const Color(0xFF20110F),
                  const Color(0xFF090605),
                ]
              : [
                  Color.lerp(Colors.black, color, 0.36)!,
                  _frameActionSurfaceRaised,
                  _frameActionSurface,
                ],
          stops: const [0, 0.56, 1],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: prepared ? _frameGoldBright : color.withValues(alpha: 0.52),
          width: prepared ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: prepared ? 0.34 : 0.22),
            blurRadius: prepared ? 20 : 14,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -18,
            top: -18,
            child: Icon(
              Icons.hexagon_outlined,
              color: color.withValues(alpha: 0.08),
              size: dense ? 82 : 118,
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class CombatActionTapRegion extends StatelessWidget {
  final Widget child;
  final String tooltip;
  final VoidCallback onTap;

  const CombatActionTapRegion({
    super.key,
    required this.child,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      ),
    );
  }
}

class CombatActionStateBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const CombatActionStateBadge({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 36 : 44,
        maxWidth: compact ? 54 : 68,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.44)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: compact ? 7.5 : 8.5,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
