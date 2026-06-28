import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../models/board_token.dart';
import '../../../../../theme.dart';

class CombatMovementBudgetBar extends StatelessWidget {
  final BoardToken? token;

  const CombatMovementBudgetBar({
    super.key,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.stitch;
    final speed = token?.speedFeet ?? 0;
    final remaining = token?.remainingMovementFeet ?? 0;
    final used = math.max(0, speed - remaining);
    final ratio = speed <= 0 ? 0.0 : (remaining / speed).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.directions_run_rounded,
              size: 15,
              color: theme.accentSuccess,
            ),
            const SizedBox(width: 6),
            Text(
              '$remaining FT DISPONIBLES',
              style: const TextStyle(
                color: StitchCodexPalette.textPrimary,
                fontFamily: StitchTypography.data,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$used/$speed',
              style: TextStyle(
                color: theme.textSecondary,
                fontFamily: StitchTypography.data,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          color: StitchCodexPalette.textFaint,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: ratio,
            child: ColoredBox(
              color: remaining >= 5 ? theme.accentSuccess : theme.accentAction,
            ),
          ),
        ),
      ],
    );
  }
}

class CombatMovementStrip extends StatelessWidget {
  final bool enabled;
  final void Function(int dx, int dy) onMove;

  const CombatMovementStrip({
    super.key,
    required this.enabled,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CombatMoveButton(
          icon: Icons.keyboard_arrow_left_rounded,
          enabled: enabled,
          onPressed: () => onMove(-1, 0),
        ),
        _CombatMoveButton(
          icon: Icons.keyboard_arrow_up_rounded,
          enabled: enabled,
          onPressed: () => onMove(0, -1),
        ),
        _CombatMoveButton(
          icon: Icons.keyboard_arrow_down_rounded,
          enabled: enabled,
          onPressed: () => onMove(0, 1),
        ),
        _CombatMoveButton(
          icon: Icons.keyboard_arrow_right_rounded,
          enabled: enabled,
          onPressed: () => onMove(1, 0),
        ),
      ],
    );
  }
}

class CombatMovementPad extends StatelessWidget {
  final bool enabled;
  final void Function(int dx, int dy) onMove;

  const CombatMovementPad({
    super.key,
    required this.enabled,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CombatMoveButton(
            icon: Icons.keyboard_arrow_up_rounded,
            enabled: enabled,
            onPressed: () => onMove(0, -1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CombatMoveButton(
                icon: Icons.keyboard_arrow_left_rounded,
                enabled: enabled,
                onPressed: () => onMove(-1, 0),
              ),
              const SizedBox(width: 40, height: 40),
              _CombatMoveButton(
                icon: Icons.keyboard_arrow_right_rounded,
                enabled: enabled,
                onPressed: () => onMove(1, 0),
              ),
            ],
          ),
          _CombatMoveButton(
            icon: Icons.keyboard_arrow_down_rounded,
            enabled: enabled,
            onPressed: () => onMove(0, 1),
          ),
        ],
      ),
    );
  }
}

class _CombatMoveButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _CombatMoveButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? StitchCodexPalette.bronzeBright
        : StitchCodexPalette.textMuted;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: enabled ? 0.10 : 0.04),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
