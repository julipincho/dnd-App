import 'package:flutter/material.dart';

import '../../../../../theme.dart';

class CombatTinyRollButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const CombatTinyRollButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.34)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Flexible(
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
          ],
        ),
      ),
    );
  }
}

class CombatActionRollButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const CombatActionRollButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        side: BorderSide(color: color.withValues(alpha: 0.34)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class CombatPrepareActionButton extends StatelessWidget {
  final bool selected;
  final bool disabled;
  final Color color;
  final VoidCallback onTap;

  const CombatPrepareActionButton({
    super.key,
    required this.selected,
    this.disabled = false,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 27,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: (selected ? color : Colors.white).withValues(
            alpha: selected ? 0.26 : 0.07,
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.58 : 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_outline : Icons.add_circle_outline,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              selected ? 'Ready' : 'Prepare',
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

class CombatActionAvailabilityLine extends StatelessWidget {
  final bool isSpent;
  final bool isPrepared;
  final bool canResolveDamage;
  final bool lacksResource;
  final int? resourceRemaining;
  final int resourceCost;
  final Color color;

  const CombatActionAvailabilityLine({
    super.key,
    required this.isSpent,
    required this.isPrepared,
    required this.canResolveDamage,
    required this.lacksResource,
    required this.resourceRemaining,
    required this.resourceCost,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final status = canResolveDamage
        ? 'Damage pending'
        : lacksResource
            ? 'No uses left'
            : isSpent
                ? 'Timing spent'
                : isPrepared
                    ? 'Prepared'
                    : resourceRemaining == null
                        ? 'Available'
                        : '$resourceRemaining left - costs $resourceCost';
    final icon = canResolveDamage
        ? Icons.auto_fix_high_outlined
        : lacksResource
            ? Icons.battery_0_bar_outlined
            : isSpent
                ? Icons.lock_clock_outlined
                : isPrepared
                    ? Icons.playlist_add_check_circle_outlined
                    : Icons.check_circle_outline;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
