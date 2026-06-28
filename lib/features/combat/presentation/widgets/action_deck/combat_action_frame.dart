import 'package:flutter/material.dart';

import '../../../../../theme.dart';

const _frameActionSurface = StitchCodexPalette.card;
const _frameActionSurfaceRaised = StitchCodexPalette.surfaceRaised;
const _frameGoldBright = StitchCodexPalette.bronzeBright;

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
        color: blocked
            ? StitchCodexPalette.crimson.withValues(alpha: 0.13)
            : prepared
                ? _frameActionSurfaceRaised
                : _frameActionSurface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: prepared ? _frameGoldBright : color.withValues(alpha: 0.52),
          width: prepared ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
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
          borderRadius: BorderRadius.circular(2),
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
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.44)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontFamily: StitchTypography.data,
          fontSize: compact ? 7.5 : 8.5,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
