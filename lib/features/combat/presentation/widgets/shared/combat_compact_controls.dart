import 'package:flutter/material.dart';

import '../../../../../theme.dart';

const _compactPaper = Color(0xFFF2D8B5);

class CombatPhoneIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const CombatPhoneIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? _compactPaper;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: effectiveColor.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: effectiveColor, size: 18),
        ),
      ),
    );
  }
}

class CombatCompactIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const CombatCompactIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = color ?? tokens.accentRead;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: Container(
          width: 39,
          height: 38,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(color: accent.withValues(alpha: 0.26)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class CombatLandscapeNudge extends StatelessWidget {
  const CombatLandscapeNudge({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.accentInfo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentInfo.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.screen_rotation_alt_outlined,
            color: tokens.accentInfo,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Landscape gives Combat Mode more room for turns, dice and target.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CombatRoundText extends StatelessWidget {
  final int round;

  const CombatRoundText({
    super.key,
    required this.round,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ROUND',
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        Text(
          '$round',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class CombatCompactControlLockNotice extends StatelessWidget {
  final String message;

  const CombatCompactControlLockNotice({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.accentWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentWarning.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: tokens.accentWarning, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.08,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CombatCompactTimingCommandButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final bool spent;
  final VoidCallback onTap;

  const CombatCompactTimingCommandButton({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.spent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = spent
        ? tokens.accentAction
        : selected
            ? tokens.accentMagic
            : tokens.accentRead;

    return InkWell(
      onTap: spent ? null : onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: spent ? 0.10 : 0.15),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.58 : 0.24),
          ),
        ),
        child: Row(
          children: [
            Icon(
              spent ? Icons.check_circle_outline : icon,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: spent ? tokens.textMuted : tokens.textSecondary,
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
