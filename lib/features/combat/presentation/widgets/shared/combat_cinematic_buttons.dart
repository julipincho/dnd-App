import 'package:flutter/material.dart';

const _cinematicPaper = Color(0xFFF2D8B5);
const _cinematicGold = Color(0xFF9C7140);

class CombatCinematicFooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const CombatCinematicFooterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: compact ? 40 : 42,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasFiniteWidth = constraints.maxWidth.isFinite;
            final labelWidget = FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 9 : 10.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            );

            return Row(
              mainAxisSize:
                  hasFiniteWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: compact ? 15 : 17),
                SizedBox(width: compact ? 6 : 8),
                if (hasFiniteWidth)
                  Flexible(child: labelWidget)
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: compact ? 112 : 160,
                    ),
                    child: labelWidget,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CombatCinematicConfirmButton extends StatelessWidget {
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  const CombatCinematicConfirmButton({
    super.key,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF5F1510),
                Color(0xFF9D241A),
                Color(0xFF4E100E),
              ],
            ),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: const Color(0xFFD66B42).withValues(alpha: 0.62),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9D241A).withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    style: const TextStyle(
                      color: _cinematicPaper,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: _cinematicPaper,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CombatCinematicRoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const CombatCinematicRoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _cinematicGold.withValues(alpha: 0.12),
            border: Border.all(
              color: _cinematicGold.withValues(alpha: 0.28),
            ),
          ),
          child: Icon(icon, color: _cinematicPaper, size: 20),
        ),
      ),
    );
  }
}

class CombatHpSheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CombatHpSheetButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.34)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
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
