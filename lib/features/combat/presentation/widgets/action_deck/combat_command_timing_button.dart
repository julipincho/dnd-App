import 'package:flutter/material.dart';

import '../../../../../theme.dart';

class CombatCommandTimingButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool spent;
  final VoidCallback onTap;

  const CombatCommandTimingButton({
    super.key,
    required this.label,
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.24 : 0.11),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.56 : 0.24),
          ),
        ),
        child: Row(
          children: [
            Icon(
              spent
                  ? Icons.check_circle_outline
                  : selected
                      ? Icons.keyboard_arrow_right
                      : Icons.circle_outlined,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
