import 'package:flutter/material.dart';

import '../../../../../theme.dart';

class CombatStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const CombatStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final effectiveColor = combatStatusAccentForLabel(label, tokens, color);
    final icon = combatStatusIconForLabel(label);

    return Container(
      constraints: const BoxConstraints(maxWidth: 176),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
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

Color combatStatusAccentForLabel(
  String label,
  StitchThemeTokens tokens,
  Color fallback,
) {
  final text = label.toLowerCase();
  if (text.contains('temp hp')) return tokens.accentInfo;
  if (text.contains('rage') || text.contains('raging')) {
    return tokens.accentAction;
  }
  if (text.contains('bardic') || text.contains('inspiration')) {
    return tokens.accentMagic;
  }
  if (text.contains('concentrat')) return tokens.accentSuccess;
  if (text.contains('ki') || text.contains('sorcery')) return tokens.accentRead;
  if (text.contains('down')) return tokens.textMuted;
  return fallback;
}

IconData combatStatusIconForLabel(String label) {
  final text = label.toLowerCase();
  if (text.contains('temp hp')) return Icons.health_and_safety_outlined;
  if (text.contains('rage') || text.contains('raging')) {
    return Icons.local_fire_department_outlined;
  }
  if (text.contains('bardic') || text.contains('inspiration')) {
    return Icons.auto_awesome_outlined;
  }
  if (text.contains('concentrat')) return Icons.psychology_alt_outlined;
  if (text.contains('ki')) return Icons.bolt_outlined;
  if (text.contains('sorcery')) return Icons.blur_on_outlined;
  if (text.contains('spell')) return Icons.menu_book_outlined;
  if (text.contains('resist')) return Icons.shield_outlined;
  if (text.contains('immune')) return Icons.verified_user_outlined;
  if (text.contains('speed')) return Icons.directions_run_outlined;
  return Icons.adjust_outlined;
}
