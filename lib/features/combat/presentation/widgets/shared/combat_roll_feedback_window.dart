import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import '../../../domain/models/combat_feedback.dart';
import 'combat_accent_colors.dart';
import 'combat_metric_widgets.dart';

class CombatRollFeedbackWindow extends StatelessWidget {
  final CombatRollFeedback feedback;

  const CombatRollFeedbackWindow({
    super.key,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = combatAccentColorForKind(feedback.accentKind, tokens);
    final result = feedback.result;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(
          '${feedback.action}-${result?.total}-${feedback.headline}',
        ),
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.28),
              tokens.surfaceRaised.withValues(alpha: 0.95),
              tokens.surface.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(color: accent.withValues(alpha: 0.52)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: result == null
                  ? const Icon(
                      Icons.auto_awesome_outlined,
                      color: Colors.white,
                      size: 28,
                    )
                  : Text(
                      '${result.total}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${feedback.actor} - ${feedback.action}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feedback.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (feedback.subline != null &&
                      feedback.subline!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      feedback.subline!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (result != null) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        CombatDiceExpressionChip(
                          label: result.formula,
                          color: accent,
                        ),
                        CombatDiceExpressionChip(
                          label: result.rollsText,
                          color: tokens.accentRead,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
