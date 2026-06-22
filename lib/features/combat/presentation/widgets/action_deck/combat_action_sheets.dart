import 'package:flutter/material.dart';

import '../../../domain/models/combat_action.dart';
import '../../../domain/models/combat_turn_models.dart';
import '../../../domain/models/combatant.dart';
import '../../../../../theme.dart';
import '../shared/combat_accent_colors.dart';
import '../shared/combat_cinematic_buttons.dart';
import '../shared/combat_cinematic_primitives.dart';
import '../shared/combat_metric_widgets.dart';
import 'combat_action_detail_line.dart';

String? combatActionAreaText(CombatAction action) {
  if (!action.hasAreaEffect) return null;
  final shape = switch (action.areaShape.toLowerCase()) {
    'cone' => 'Cono',
    'line' => 'Linea',
    'cube' => 'Cubo',
    'sphere' => 'Area',
    'cylinder' => 'Area',
    _ => 'Area',
  };
  return '$shape ${action.areaFeet} ft';
}

void showCombatActionDetails(BuildContext context, CombatAction action) {
  final tokens = context.stitch;
  final accent = combatAccentColorForKind(action.accentKind, tokens);

  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: tokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          side: BorderSide(color: accent.withValues(alpha: 0.34)),
        ),
        title: Row(
          children: [
            Icon(action.icon, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                action.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CombatActionDetailLine(label: 'Type', value: action.type),
            CombatActionDetailLine(label: 'Timing', value: action.timing),
            if (action.hasMultiAttack)
              CombatActionDetailLine(
                label: 'Sequence',
                value:
                    '${action.multiAttackSteps.length} attacks in one action',
              ),
            if (action.attackFormula != null)
              CombatActionDetailLine(
                  label: 'Attack', value: action.attackFormula!),
            if (action.damageFormula != null)
              CombatActionDetailLine(
                  label: action.isHealing ? 'Healing' : 'Damage',
                  value: action.damageFormula!),
            if (combatActionAreaText(action) != null)
              CombatActionDetailLine(
                  label: 'Area', value: combatActionAreaText(action)!),
            if (action.criticalThreshold < 20)
              CombatActionDetailLine(
                label: 'Crit Range',
                value: '${action.criticalThreshold}-20',
              ),
            if (action.critFormula != null)
              CombatActionDetailLine(
                  label: 'Critical', value: action.critFormula!),
            if (action.hasMultiAttack) ...[
              const SizedBox(height: 4),
              for (var index = 0;
                  index < action.multiAttackSteps.length;
                  index++)
                CombatActionDetailLine(
                  label: 'Hit ${index + 1}',
                  value: [
                    action.multiAttackSteps[index].name,
                    if (action.multiAttackSteps[index].attackFormula != null)
                      action.multiAttackSteps[index].attackFormula!,
                    if (action.multiAttackSteps[index].damageFormula != null)
                      action.multiAttackSteps[index].damageFormula!,
                  ].join(' - '),
                ),
            ],
            if (action.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in action.tags)
                    CombatDiceExpressionChip(label: tag, color: accent),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

void showCombatSavingThrowSheet({
  required BuildContext context,
  required Combatant target,
  required List<CombatAction> actions,
  required ValueChanged<String> onRollSavingThrow,
  required void Function(CombatAction action, CombatActionRoll rollType)
      onRollAction,
}) {
  final tokens = context.stitch;
  final saveActions =
      actions.where((action) => action.requiresSavingThrow).toList();
  const abilities = [
    ('STR', 'Fuerza'),
    ('DEX', 'Destreza'),
    ('CON', 'Constitucion'),
    ('INT', 'Inteligencia'),
    ('WIS', 'Sabiduria'),
    ('CHA', 'Carisma'),
  ];

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: CombatCinematicPanelFrame(
          borderColor: CombatCinematicColors.goldBright,
          backgroundAlpha: 0.94,
          padding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: CombatCinematicColors.goldBright,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tiradas de salvacion: ${target.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CombatCinematicColors.paper,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ability in abilities)
                      SizedBox(
                        width: 150,
                        child: CombatCinematicFooterButton(
                          icon: Icons.casino_outlined,
                          label: '${ability.$1} ${ability.$2}',
                          color: tokens.accentRead,
                          compact: true,
                          onTap: () {
                            Navigator.of(context).pop();
                            onRollSavingThrow(ability.$1);
                          },
                        ),
                      ),
                  ],
                ),
                if (saveActions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Acciones que solicitan TS',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: saveActions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final action = saveActions[index];
                        final accent =
                            combatAccentColorForKind(action.accentKind, tokens);
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            onRollAction(
                              action,
                              CombatActionRoll.savingThrow,
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(action.icon, color: accent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        action.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: CombatCinematicColors.paper,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        [
                                          '${action.saveAbility} DC ${action.saveDc}',
                                          if (combatActionAreaText(action) !=
                                              null)
                                            combatActionAreaText(action)!,
                                          if (action.damageFormula != null)
                                            action.damageFormula!,
                                        ].join(' - '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: tokens.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.keyboard_arrow_right_rounded,
                                  color: CombatCinematicColors.paper,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
