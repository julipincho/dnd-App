import 'package:flutter/material.dart';

import '../../../domain/models/combatant.dart';
import '../../../domain/models/combat_turn_models.dart';
import '../../../../../theme.dart';
import '../shared/combat_portrait_widgets.dart';

class CombatTargetStrip extends StatelessWidget {
  final List<Combatant> combatants;
  final int activeIndex;
  final int targetIndex;
  final bool showEnemyHp;
  final ValueChanged<int> onSelectTarget;

  const CombatTargetStrip({
    super.key,
    required this.combatants,
    required this.activeIndex,
    required this.targetIndex,
    required this.showEnemyHp,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    if (combatants.isEmpty) return const SizedBox.shrink();

    final safeActiveIndex = activeIndex.clamp(0, combatants.length - 1).toInt();
    final active = combatants[safeActiveIndex];
    final hostileTargets = combatants.asMap().entries.where((entry) {
      return entry.key != safeActiveIndex &&
          entry.value.team != active.team &&
          entry.value.hp > 0;
    }).toList(growable: false);
    final targets = hostileTargets.isNotEmpty
        ? hostileTargets
        : combatants.asMap().entries.where((entry) {
            return entry.key != safeActiveIndex && entry.value.hp > 0;
          }).toList(growable: false);

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Container(
            width: 96,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: StitchCodexPalette.surface,
              border: Border.all(
                color: StitchCodexPalette.bronzeMuted.withValues(alpha: 0.46),
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OBJETIVOS',
                  style: TextStyle(
                    color: StitchCodexPalette.bronzeBright,
                    fontFamily: StitchTypography.data,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'ELIGE UNO',
                  style: TextStyle(
                    color: StitchCodexPalette.textMuted,
                    fontFamily: StitchTypography.data,
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: targets.isEmpty
                ? const Center(
                    child: Text(
                      'No quedan objetivos disponibles.',
                      style: TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.body,
                        fontSize: 11,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: targets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, position) {
                      final entry = targets[position];
                      return _CombatTargetChip(
                        combatant: entry.value,
                        selected: entry.key == targetIndex,
                        showEnemyHp: showEnemyHp,
                        onTap: () => onSelectTarget(entry.key),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CombatTargetChip extends StatelessWidget {
  final Combatant combatant;
  final bool selected;
  final bool showEnemyHp;
  final VoidCallback onTap;

  const _CombatTargetChip({
    required this.combatant,
    required this.selected,
    required this.showEnemyHp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = combatant.team == CombatTeam.enemy
        ? StitchCodexPalette.crimsonBright
        : StitchCodexPalette.success;
    final hpVisible = combatant.team == CombatTeam.party || showEnemyHp;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : StitchCodexPalette.card,
          border: Border.all(
            color: selected
                ? color
                : StitchCodexPalette.textFaint.withValues(alpha: 0.76),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: selected ? 0.9 : 0.48),
                ),
              ),
              child: CombatantArtwork(
                combatant: combatant,
                color: color,
                iconSize: 15,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    combatant.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.display,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 3,
                    color: StitchCodexPalette.textFaint,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: combatant.hpRatio,
                      child: ColoredBox(color: color),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hpVisible
                        ? '${combatant.hp}/${combatant.maxHp} HP'
                        : 'HP ocultos',
                    style: const TextStyle(
                      color: StitchCodexPalette.textMuted,
                      fontFamily: StitchTypography.data,
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.my_location,
                color: color,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
