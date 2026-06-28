import 'package:flutter/material.dart';

import '../../../domain/models/combatant.dart';
import '../../../domain/models/combat_turn_models.dart';
import '../../../../../theme.dart';
import '../shared/combat_portrait_widgets.dart';

class CombatActiveHeader extends StatelessWidget {
  final int round;
  final List<Combatant> combatants;
  final int activeIndex;
  final CombatActionEconomySnapshot economy;
  final bool showEnemyHp;
  final CombatWorkspace workspace;
  final VoidCallback onBack;
  final VoidCallback onNextTurn;
  final VoidCallback onRequestInitiative;
  final VoidCallback onRollInitiative;
  final VoidCallback onToggleDmView;
  final VoidCallback onRunDemo;
  final ValueChanged<int> onSelectCombatant;
  final ValueChanged<CombatWorkspace> onSelectWorkspace;

  const CombatActiveHeader({
    super.key,
    required this.round,
    required this.combatants,
    required this.activeIndex,
    required this.economy,
    required this.showEnemyHp,
    required this.workspace,
    required this.onBack,
    required this.onNextTurn,
    required this.onRequestInitiative,
    required this.onRollInitiative,
    required this.onToggleDmView,
    required this.onRunDemo,
    required this.onSelectCombatant,
    required this.onSelectWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    if (combatants.isEmpty) return const SizedBox.shrink();

    final safeActiveIndex = activeIndex.clamp(0, combatants.length - 1).toInt();
    final activeCombatant = combatants[safeActiveIndex];
    final activeColor = _teamColor(activeCombatant.team);
    final initiative = combatants.asMap().entries.toList()
      ..sort((a, b) {
        final result = b.value.initiative.compareTo(a.value.initiative);
        return result == 0 ? a.key.compareTo(b.key) : result;
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: StitchCodexPalette.ground.withValues(alpha: 0.96),
            border: Border.all(
              color: StitchCodexPalette.bronzeMuted.withValues(alpha: 0.52),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    _HeaderIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Volver',
                      onTap: onBack,
                    ),
                    Container(
                      height: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 14,
                      ),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: StitchCodexPalette.textFaint
                                .withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                      child: Text(
                        compact ? 'STITCH  ◆  R$round' : 'STITCH  ◆  COMBATE',
                        maxLines: 1,
                        style: const TextStyle(
                          color: StitchCodexPalette.bronzeBright,
                          fontFamily: StitchTypography.display,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.09),
                          border: Border(
                            bottom: BorderSide(
                              color: activeColor.withValues(alpha: 0.72),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: activeColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: 0.48),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeCombatant.team == CombatTeam.party
                                        ? 'TU TURNO'
                                        : 'TURNO ACTIVO',
                                    style: TextStyle(
                                      color: activeColor,
                                      fontFamily: StitchTypography.data,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  Text(
                                    activeCombatant.name.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: StitchCodexPalette.textPrimary,
                                      fontFamily: StitchTypography.display,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!compact) ...[
                              _EconomyMark(
                                label: 'A',
                                spent: economy.actionSpent,
                                color: activeColor,
                              ),
                              _EconomyMark(
                                label: 'B',
                                spent: economy.bonusActionSpent,
                                color: activeColor,
                              ),
                              _EconomyMark(
                                label: 'R',
                                spent: economy.reactionSpent,
                                color: activeColor,
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      _WorkspaceButton(
                        icon: Icons.grid_view_outlined,
                        tooltip: 'Turno',
                        selected: workspace == CombatWorkspace.turn,
                        onTap: () => onSelectWorkspace(CombatWorkspace.turn),
                      ),
                      _WorkspaceButton(
                        icon: Icons.receipt_long_outlined,
                        tooltip: 'Log',
                        selected: workspace == CombatWorkspace.log,
                        onTap: () => onSelectWorkspace(CombatWorkspace.log),
                      ),
                      _WorkspaceButton(
                        icon: Icons.groups_2_outlined,
                        tooltip: 'Resumen',
                        selected: workspace == CombatWorkspace.overview,
                        onTap: () =>
                            onSelectWorkspace(CombatWorkspace.overview),
                      ),
                    ],
                    _HeaderIconButton(
                      icon: showEnemyHp
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      tooltip: showEnemyHp ? 'Vista DM' : 'Vista jugador',
                      onTap: onToggleDmView,
                    ),
                    _HeaderIconButton(
                      icon: Icons.casino_outlined,
                      tooltip: 'Tirar iniciativa',
                      onTap: onRollInitiative,
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Más controles',
                      color: StitchCodexPalette.surfaceRaised,
                      icon: const Icon(
                        Icons.more_vert,
                        color: StitchCodexPalette.textSecondary,
                        size: 19,
                      ),
                      onSelected: (value) {
                        if (value == 'request') onRequestInitiative();
                        if (value == 'demo') onRunDemo();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'request',
                          child: Text('Pedir iniciativa'),
                        ),
                        PopupMenuItem(
                          value: 'demo',
                          child: Text('Ejecutar demo'),
                        ),
                      ],
                    ),
                    _NextTurnButton(
                      compact: compact,
                      onTap: onNextTurn,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        StitchCodexPalette.surfaceMuted.withValues(alpha: 0.92),
                    border: Border(
                      top: BorderSide(
                        color: StitchCodexPalette.textFaint
                            .withValues(alpha: 0.64),
                      ),
                    ),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: initiative.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, position) {
                      final entry = initiative[position];
                      return _InitiativeCombatant(
                        combatant: entry.value,
                        position: position + 1,
                        active: entry.key == safeActiveIndex,
                        showEnemyHp: showEnemyHp,
                        onTap: () => onSelectCombatant(entry.key),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InitiativeCombatant extends StatelessWidget {
  final Combatant combatant;
  final int position;
  final bool active;
  final bool showEnemyHp;
  final VoidCallback onTap;

  const _InitiativeCombatant({
    required this.combatant,
    required this.position,
    required this.active,
    required this.showEnemyHp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _teamColor(combatant.team);
    final down = combatant.hp <= 0;
    final hpVisible = combatant.team == CombatTeam.party || showEnemyHp;

    return Tooltip(
      message: '${combatant.name} · iniciativa ${combatant.initiative}',
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 144,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.14)
                : StitchCodexPalette.card.withValues(alpha: 0.82),
            border: Border.all(
              color: active
                  ? color
                  : StitchCodexPalette.textFaint.withValues(alpha: 0.76),
            ),
          ),
          child: Opacity(
            opacity: down ? 0.52 : 1,
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? color : color.withValues(alpha: 0.5),
                          width: active ? 2 : 1,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.32),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: CombatantArtwork(
                        combatant: combatant,
                        color: color,
                        iconSize: 17,
                      ),
                    ),
                    if (down)
                      const Positioned.fill(
                        child: Center(
                          child: Icon(
                            Icons.close,
                            color: StitchCodexPalette.crimsonBright,
                            size: 24,
                          ),
                        ),
                      ),
                    Positioned(
                      left: -4,
                      top: -4,
                      child: Container(
                        width: 14,
                        height: 14,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: StitchCodexPalette.ground,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$position',
                          style: const TextStyle(
                            color: StitchCodexPalette.bronzeBright,
                            fontFamily: StitchTypography.data,
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
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
                          ),
                          Text(
                            '${combatant.initiative}',
                            style: TextStyle(
                              color: active
                                  ? color
                                  : StitchCodexPalette.bronzeBright,
                              fontFamily: StitchTypography.data,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: 3,
                        color: StitchCodexPalette.textFaint,
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: combatant.hpRatio,
                          child: ColoredBox(
                            color: down ? StitchCodexPalette.crimson : color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hpVisible
                            ? '${combatant.hp}/${combatant.maxHp} HP'
                            : 'HP ocultos',
                        maxLines: 1,
                        style: const TextStyle(
                          color: StitchCodexPalette.textMuted,
                          fontFamily: StitchTypography.data,
                          fontSize: 7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EconomyMark extends StatelessWidget {
  final String label;
  final bool spent;
  final Color color;

  const _EconomyMark({
    required this.label,
    required this.spent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(left: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: spent
            ? StitchCodexPalette.crimson.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.11),
        border: Border.all(
          color: spent
              ? StitchCodexPalette.crimsonBright.withValues(alpha: 0.5)
              : color.withValues(alpha: 0.42),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: spent ? StitchCodexPalette.crimsonBright : color,
          fontFamily: StitchTypography.data,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WorkspaceButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HeaderIconButton(
      icon: icon,
      tooltip: tooltip,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 38,
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected
                ? StitchCodexPalette.bronze.withValues(alpha: 0.14)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: StitchCodexPalette.textFaint.withValues(alpha: 0.54),
              ),
            ),
          ),
          child: Icon(
            icon,
            color: selected
                ? StitchCodexPalette.bronzeBright
                : StitchCodexPalette.textSecondary,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _NextTurnButton extends StatelessWidget {
  final bool compact;
  final VoidCallback onTap;

  const _NextTurnButton({
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
        color: StitchCodexPalette.crimson,
        child: Row(
          children: [
            const Icon(
              Icons.skip_next,
              color: StitchCodexPalette.textPrimary,
              size: 17,
            ),
            if (!compact) ...[
              const SizedBox(width: 7),
              const Text(
                'SIGUIENTE TURNO',
                style: TextStyle(
                  color: StitchCodexPalette.textPrimary,
                  fontFamily: StitchTypography.display,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _teamColor(CombatTeam team) {
  return team == CombatTeam.party
      ? StitchCodexPalette.success
      : StitchCodexPalette.crimsonBright;
}
