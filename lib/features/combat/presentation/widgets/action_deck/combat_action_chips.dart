import 'package:flutter/material.dart';

import '../../../../../theme.dart';

const _actionChipPaper = StitchCodexPalette.textPrimary;
const _actionChipBlood = StitchCodexPalette.crimson;

class CombatActionInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  const CombatActionInfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 46 : 64,
        maxWidth: compact ? 118 : 150,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 13 : 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _actionChipPaper,
                fontFamily: StitchTypography.data,
                fontSize: compact ? 9 : 10.5,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CombatActionInlineWarning extends StatelessWidget {
  final String label;

  const CombatActionInlineWarning({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: _actionChipBlood.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: _actionChipBlood.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: _actionChipPaper,
            size: 14,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _actionChipPaper,
                fontFamily: StitchTypography.data,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
