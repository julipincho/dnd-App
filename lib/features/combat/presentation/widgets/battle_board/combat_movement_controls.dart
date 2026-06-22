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
              '$remaining ft left',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              '$used/$speed',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: ratio,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(
              remaining >= 5 ? theme.accentSuccess : theme.accentAction,
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
    return IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
    );
  }
}
