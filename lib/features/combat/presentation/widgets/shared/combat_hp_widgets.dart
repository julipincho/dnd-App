import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/combatant.dart';
import '../../../domain/models/combat_turn_models.dart';
import '../../../../../theme.dart';
import 'combat_cinematic_buttons.dart';
import 'combat_cinematic_primitives.dart';
import 'combat_portrait_widgets.dart';

bool canShowCombatantHp(Combatant combatant, bool showEnemyHp) {
  return combatant.team == CombatTeam.party || showEnemyHp;
}

String compactCombatantHpLabel(Combatant combatant, bool showEnemyHp) {
  if (!canShowCombatantHp(combatant, showEnemyHp)) return 'Hidden';
  if (combatant.tempHp > 0) {
    return '${combatant.hp}/${combatant.maxHp} +${combatant.tempHp}';
  }
  return '${combatant.hp}/${combatant.maxHp}';
}

class CombatCinematicHpBar extends StatelessWidget {
  final Combatant combatant;
  final bool showHp;
  final double height;
  final VoidCallback? onTap;

  const CombatCinematicHpBar({
    super.key,
    required this.combatant,
    required this.showHp,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final editable = onTap != null;
    final effectiveHeight = math.max(height, editable ? 22.0 : 16.0);
    final valueColor = !showHp
        ? tokens.textMuted
        : combatant.hp <= 0
            ? tokens.textMuted
            : combatant.hpRatio <= 0.30
                ? tokens.accentAction
                : const Color(0xFFB0201C);

    final bar = SizedBox(
      height: effectiveHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: showHp ? combatant.hpRatio : 1,
                minHeight: effectiveHeight,
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                valueColor: AlwaysStoppedAnimation<Color>(valueColor),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 4,
              right: editable ? 22 : 4,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                compactCombatantHpLabel(combatant, showHp),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          if (editable)
            Positioned(
              right: 5,
              child: Icon(
                Icons.edit_outlined,
                color: Colors.white.withValues(alpha: 0.88),
                size: math.min(effectiveHeight - 6, 16),
              ),
            ),
        ],
      ),
    );

    if (!editable) return bar;
    return Tooltip(
      message: 'Editar HP',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: bar,
        ),
      ),
    );
  }
}

class CombatHpAdjustmentSheet extends StatelessWidget {
  final Combatant combatant;
  final TextEditingController controller;
  final VoidCallback onSubtract;
  final VoidCallback onAdd;
  final VoidCallback onSetExact;

  const CombatHpAdjustmentSheet({
    super.key,
    required this.combatant,
    required this.controller,
    required this.onSubtract,
    required this.onAdd,
    required this.onSetExact,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent = combatTeamColor(combatant.team, tokens);
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxPanelHeight = math.max(120.0, size.height - bottomInset - 32);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: maxPanelHeight,
            ),
            child: CombatCinematicPanelFrame(
              borderColor: accent,
              backgroundAlpha: 0.92,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: CombatCinematicPortraitBox(
                            combatant: combatant,
                            color: accent,
                            iconSize: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                combatant.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CombatCinematicColors.paper,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              CombatCinematicHpBar(
                                combatant: combatant,
                                showHp: true,
                                height: 24,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: false,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: CombatCinematicColors.paper,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor de HP',
                        labelStyle: TextStyle(color: tokens.textSecondary),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.26),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: CombatCinematicColors.gold
                                .withValues(alpha: 0.30),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: CombatCinematicColors.goldBright,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in const [1, 5, 10, 20])
                          ActionChip(
                            label: Text('$value'),
                            onPressed: () {
                              controller.text = '$value';
                              controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length),
                              );
                            },
                            backgroundColor: CombatCinematicColors.gold
                                .withValues(alpha: 0.16),
                            labelStyle: const TextStyle(
                              color: CombatCinematicColors.paper,
                              fontWeight: FontWeight.w900,
                            ),
                            side: BorderSide(
                              color: CombatCinematicColors.gold
                                  .withValues(alpha: 0.28),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          child: CombatHpSheetButton(
                            label: 'Restar',
                            icon: Icons.remove_rounded,
                            color: CombatCinematicColors.blood,
                            onTap: onSubtract,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: CombatHpSheetButton(
                            label: 'Sumar',
                            icon: Icons.add_rounded,
                            color: CombatCinematicColors.goldBright,
                            onTap: onAdd,
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: CombatHpSheetButton(
                            label: 'Fijar',
                            icon: Icons.done_rounded,
                            color: accent,
                            onTap: onSetExact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
