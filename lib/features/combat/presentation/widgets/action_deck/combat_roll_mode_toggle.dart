import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import '../shared/combat_cinematic_primitives.dart';

class CombatRollModeOption<T> {
  final T value;
  final IconData icon;
  final String label;
  final String tooltip;

  const CombatRollModeOption({
    required this.value,
    required this.icon,
    required this.label,
    required this.tooltip,
  });
}

class CombatRollModeToggle<T> extends StatelessWidget {
  final T value;
  final List<CombatRollModeOption<T>> options;
  final ValueChanged<T> onChanged;

  const CombatRollModeToggle({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: StitchCodexPalette.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: CombatCinematicColors.gold.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(width: 3),
            Expanded(
              child: CombatCinematicRollModeSegment(
                icon: options[index].icon,
                label: options[index].label,
                tooltip: options[index].tooltip,
                selected: value == options[index].value,
                onTap: () => onChanged(options[index].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
