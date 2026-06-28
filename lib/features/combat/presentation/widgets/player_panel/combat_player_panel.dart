import 'package:flutter/material.dart';

import '../../../domain/models/combat_action.dart';
import '../../../domain/models/combat_feedback.dart';
import '../../../domain/models/combatant.dart';
import '../../../domain/models/combat_turn_models.dart';
import '../../../../../theme.dart';
import '../battle_board/combat_movement_controls.dart';
import '../shared/combat_portrait_widgets.dart';

enum _PlayerPanelTab { actions, spells, movement }

class CombatPlayerPanel extends StatefulWidget {
  final int round;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final List<CombatAction> actions;
  final String selectedTiming;
  final CombatActionEconomySnapshot economy;
  final bool showEnemyHp;
  final bool canControlActive;
  final bool boardLinked;
  final bool targetInRange;
  final int speedFeet;
  final int movementRemainingFeet;
  final int? gridX;
  final int? gridY;
  final int? distanceFeet;
  final VoidCallback onBack;
  final VoidCallback onNextTurn;
  final VoidCallback onEditHp;
  final ValueChanged<String> onSelectTiming;
  final ValueChanged<CombatAction> onFocusAction;
  final void Function(int dx, int dy) onMove;

  const CombatPlayerPanel({
    super.key,
    required this.round,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.actions,
    required this.selectedTiming,
    required this.economy,
    required this.showEnemyHp,
    required this.canControlActive,
    required this.boardLinked,
    required this.targetInRange,
    required this.speedFeet,
    required this.movementRemainingFeet,
    required this.gridX,
    required this.gridY,
    required this.distanceFeet,
    required this.onBack,
    required this.onNextTurn,
    required this.onEditHp,
    required this.onSelectTiming,
    required this.onFocusAction,
    required this.onMove,
  });

  @override
  State<CombatPlayerPanel> createState() => _CombatPlayerPanelState();
}

class _CombatPlayerPanelState extends State<CombatPlayerPanel> {
  _PlayerPanelTab _tab = _PlayerPanelTab.actions;

  List<CombatAction> get _spells => widget.actions
      .where((action) => action.accentKind == CombatAccentKind.magic)
      .toList(growable: false);

  void _selectTab(_PlayerPanelTab tab) {
    setState(() => _tab = tab);
    if (tab == _PlayerPanelTab.actions) {
      widget.onSelectTiming('Action');
    } else if (tab == _PlayerPanelTab.spells) {
      final spells = _spells;
      if (spells.isNotEmpty) widget.onSelectTiming(spells.first.timing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeCombatant;
    final color = active.team == CombatTeam.party
        ? StitchCodexPalette.success
        : StitchCodexPalette.crimsonBright;
    final showHp = active.team == CombatTeam.party || widget.showEnemyHp;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            StitchCodexPalette.surfaceRaised.withValues(alpha: 0.96),
            StitchCodexPalette.surfaceMuted.withValues(alpha: 0.98),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.54)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final short = constraints.maxHeight < 230;
          final compactDetailWidth =
              (constraints.maxWidth * 0.52).clamp(180.0, 224.0).toDouble();
          final header = _PlayerPanelHeader(
            round: widget.round,
            active: active,
            canControlActive: widget.canControlActive,
            color: color,
            onBack: widget.onBack,
            onNextTurn: widget.onNextTurn,
          );
          final identity = _PlayerIdentity(
            combatant: active,
            color: color,
            showHp: showHp,
            compact: short,
            onEditHp: widget.canControlActive ? widget.onEditHp : null,
          );
          final tabs = _PlayerPanelTabs(
            selected: _tab,
            actionCount: widget.actions.length - _spells.length,
            spellCount: _spells.length,
            onSelected: _selectTab,
          );
          final content = _PlayerPanelContent(
            tab: _tab,
            actions: _tab == _PlayerPanelTab.spells
                ? _spells
                : widget.actions
                    .where(
                      (action) => action.accentKind != CombatAccentKind.magic,
                    )
                    .toList(growable: false),
            selectedTiming: widget.selectedTiming,
            activeCombatant: active,
            selectedTarget: widget.selectedTarget,
            economy: widget.economy,
            color: color,
            canControlActive: widget.canControlActive,
            boardLinked: widget.boardLinked,
            targetInRange: widget.targetInRange,
            speedFeet: widget.speedFeet,
            movementRemainingFeet: widget.movementRemainingFeet,
            gridX: widget.gridX,
            gridY: widget.gridY,
            distanceFeet: widget.distanceFeet,
            onFocusAction: (action) {
              widget.onSelectTiming(action.timing);
              widget.onFocusAction(action);
            },
            onMove: widget.onMove,
          );

          if (short) {
            return Column(
              children: [
                header,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: compactDetailWidth,
                          child: Column(
                            children: [
                              tabs,
                              const SizedBox(height: 6),
                              Expanded(child: content),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              header,
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: identity,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: tabs,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: content,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlayerPanelHeader extends StatelessWidget {
  final int round;
  final Combatant active;
  final bool canControlActive;
  final Color color;
  final VoidCallback onBack;
  final VoidCallback onNextTurn;

  const _PlayerPanelHeader({
    required this.round,
    required this.active,
    required this.canControlActive,
    required this.color,
    required this.onBack,
    required this.onNextTurn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: StitchCodexPalette.ground,
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.48)),
        ),
      ),
      child: Row(
        children: [
          _SquareIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Volver',
            onTap: onBack,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canControlActive ? 'TU TURNO' : 'ESPERANDO TURNO',
                    style: TextStyle(
                      color: color,
                      fontFamily: StitchTypography.data,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'PANEL DEL JUGADOR  -  RONDA $round',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.display,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _SquareIconButton(
            icon: Icons.skip_next,
            tooltip: 'Siguiente turno',
            color: StitchCodexPalette.crimsonBright,
            onTap: onNextTurn,
          ),
        ],
      ),
    );
  }
}

class _PlayerIdentity extends StatelessWidget {
  final Combatant combatant;
  final Color color;
  final bool showHp;
  final bool compact;
  final VoidCallback? onEditHp;

  const _PlayerIdentity({
    required this.combatant,
    required this.color,
    required this.showHp,
    required this.compact,
    required this.onEditHp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: compact ? 54 : 66,
              height: compact ? 54 : 66,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: color.withValues(alpha: 0.72)),
              ),
              child: CombatantArtwork(
                combatant: combatant,
                color: color,
                iconSize: compact ? 25 : 31,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    combatant.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontFamily: StitchTypography.display,
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    combatant.role.isEmpty ? 'Aventurero' : combatant.role,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textSecondary,
                      fontFamily: StitchTypography.body,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _PlayerMetric(
                        label: 'CA',
                        value: '${combatant.ac}',
                        color: StitchCodexPalette.bronzeBright,
                      ),
                      const SizedBox(width: 5),
                      _PlayerMetric(
                        label: 'INIT',
                        value: '${combatant.initiative}',
                        color: StitchCodexPalette.bronzeBright,
                      ),
                      const SizedBox(width: 5),
                      _PlayerMetric(
                        label: 'VEL',
                        value: '${combatant.speed}',
                        color: StitchCodexPalette.bronzeBright,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onEditHp,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: StitchCodexPalette.card,
              border: Border.all(
                color: StitchCodexPalette.textFaint.withValues(alpha: 0.82),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite, color: color, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'PUNTOS DE GOLPE',
                      style: TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.data,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      showHp
                          ? '${combatant.hp} / ${combatant.maxHp}'
                          : 'OCULTOS',
                      style: const TextStyle(
                        color: StitchCodexPalette.textPrimary,
                        fontFamily: StitchTypography.data,
                        fontSize: 12,
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
                    widthFactor: showHp ? combatant.hpRatio : 1,
                    child: ColoredBox(
                      color: combatant.hpRatio <= 0.30
                          ? StitchCodexPalette.crimsonBright
                          : color,
                    ),
                  ),
                ),
                if (!compact &&
                    (combatant.tempHp > 0 ||
                        combatant.conditions.isNotEmpty)) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 18,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (combatant.tempHp > 0)
                          _PlayerStatusBadge(
                            label: 'TEMP ${combatant.tempHp}',
                            color: StitchCodexPalette.cold,
                          ),
                        for (final condition
                            in combatant.conditions.take(compact ? 1 : 3)) ...[
                          const SizedBox(width: 4),
                          _PlayerStatusBadge(
                            label: condition,
                            color: StitchCodexPalette.bronzeBright,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PlayerStatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontFamily: StitchTypography.data,
          fontSize: 6.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlayerMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PlayerMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: StitchCodexPalette.ground.withValues(alpha: 0.62),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.data,
                fontSize: 7,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontFamily: StitchTypography.data,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerPanelTabs extends StatelessWidget {
  final _PlayerPanelTab selected;
  final int actionCount;
  final int spellCount;
  final ValueChanged<_PlayerPanelTab> onSelected;

  const _PlayerPanelTabs({
    required this.selected,
    required this.actionCount,
    required this.spellCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: _PlayerTabButton(
              label: 'ACCIONES',
              count: actionCount,
              selected: selected == _PlayerPanelTab.actions,
              onTap: () => onSelected(_PlayerPanelTab.actions),
            ),
          ),
          Expanded(
            child: _PlayerTabButton(
              label: 'HECHIZOS',
              count: spellCount,
              selected: selected == _PlayerPanelTab.spells,
              onTap: () => onSelected(_PlayerPanelTab.spells),
            ),
          ),
          Expanded(
            child: _PlayerTabButton(
              label: 'MOVIMIENTO',
              selected: selected == _PlayerPanelTab.movement,
              onTap: () => onSelected(_PlayerPanelTab.movement),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTabButton extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? StitchCodexPalette.bronze.withValues(alpha: 0.13)
              : StitchCodexPalette.ground,
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? StitchCodexPalette.bronzeBright
                  : StitchCodexPalette.textFaint,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            count == null ? label : '$label  $count',
            style: TextStyle(
              color: selected
                  ? StitchCodexPalette.bronzeBright
                  : StitchCodexPalette.textMuted,
              fontFamily: StitchTypography.data,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerPanelContent extends StatelessWidget {
  final _PlayerPanelTab tab;
  final List<CombatAction> actions;
  final String selectedTiming;
  final Combatant activeCombatant;
  final Combatant selectedTarget;
  final CombatActionEconomySnapshot economy;
  final Color color;
  final bool canControlActive;
  final bool boardLinked;
  final bool targetInRange;
  final int speedFeet;
  final int movementRemainingFeet;
  final int? gridX;
  final int? gridY;
  final int? distanceFeet;
  final ValueChanged<CombatAction> onFocusAction;
  final void Function(int dx, int dy) onMove;

  const _PlayerPanelContent({
    required this.tab,
    required this.actions,
    required this.selectedTiming,
    required this.activeCombatant,
    required this.selectedTarget,
    required this.economy,
    required this.color,
    required this.canControlActive,
    required this.boardLinked,
    required this.targetInRange,
    required this.speedFeet,
    required this.movementRemainingFeet,
    required this.gridX,
    required this.gridY,
    required this.distanceFeet,
    required this.onFocusAction,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    if (tab == _PlayerPanelTab.movement) {
      final movementEnabled = canControlActive &&
          activeCombatant.hp > 0 &&
          boardLinked &&
          movementRemainingFeet >= 5;
      final ratio = speedFeet <= 0
          ? 0.0
          : (movementRemainingFeet / speedFeet).clamp(0.0, 1.0);

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: StitchCodexPalette.card,
          border: Border.all(
            color: StitchCodexPalette.textFaint.withValues(alpha: 0.8),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_run,
                  color: StitchCodexPalette.success,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  '$movementRemainingFeet / $speedFeet FT',
                  style: const TextStyle(
                    color: StitchCodexPalette.textPrimary,
                    fontFamily: StitchTypography.data,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  boardLinked && gridX != null && gridY != null
                      ? 'GRID $gridX,$gridY'
                      : 'SIN TABLERO',
                  style: const TextStyle(
                    color: StitchCodexPalette.textMuted,
                    fontFamily: StitchTypography.data,
                    fontSize: 7,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 5,
              color: StitchCodexPalette.textFaint,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: const ColoredBox(color: StitchCodexPalette.success),
              ),
            ),
            const SizedBox(height: 8),
            CombatMovementStrip(
              enabled: movementEnabled,
              onMove: onMove,
            ),
            const SizedBox(height: 6),
            Text(
              distanceFeet == null
                  ? 'Objetivo: ${selectedTarget.name}'
                  : '${selectedTarget.name} - $distanceFeet ft'
                      '${targetInRange ? '' : ' - fuera de alcance'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: targetInRange
                    ? StitchCodexPalette.textSecondary
                    : StitchCodexPalette.crimsonBright,
                fontFamily: StitchTypography.body,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    final matching = actions
        .where(
          (action) =>
              action.timing == selectedTiming ||
              (tab == _PlayerPanelTab.spells &&
                  action.accentKind == CombatAccentKind.magic),
        )
        .toList(growable: false);
    final visible =
        (matching.isEmpty ? actions : matching).take(4).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: StitchCodexPalette.card,
        border: Border.all(
          color: StitchCodexPalette.textFaint.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _EconomyStatus(
                label: 'ACCION',
                spent: economy.actionSpent,
                color: color,
              ),
              const SizedBox(width: 5),
              _EconomyStatus(
                label: 'BONUS',
                spent: economy.bonusActionSpent,
                color: color,
              ),
              const SizedBox(width: 5),
              _EconomyStatus(
                label: 'REACCION',
                spent: economy.reactionSpent,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            tab == _PlayerPanelTab.spells
                ? 'HECHIZOS DISPONIBLES'
                : 'ACCIONES DISPONIBLES',
            style: const TextStyle(
              color: StitchCodexPalette.bronzeBright,
              fontFamily: StitchTypography.data,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          if (visible.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No hay opciones para esta pestana.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: StitchCodexPalette.textMuted,
                    fontFamily: StitchTypography.body,
                    fontSize: 10,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 5),
                itemBuilder: (context, index) {
                  final action = visible[index];
                  return _PlayerActionPreviewCard(
                    action: action,
                    color: action.accentKind == CombatAccentKind.magic
                        ? StitchCodexPalette.arcane
                        : color,
                    onTap: () => onFocusAction(action),
                  );
                },
              ),
            ),
          const SizedBox(height: 6),
          Container(
            height: 27,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: StitchCodexPalette.ground.withValues(alpha: 0.68),
              border: Border.all(
                color: targetInRange
                    ? StitchCodexPalette.bronzeMuted.withValues(alpha: 0.36)
                    : StitchCodexPalette.crimsonBright.withValues(alpha: 0.46),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  targetInRange
                      ? Icons.center_focus_strong
                      : Icons.warning_amber,
                  color: targetInRange
                      ? StitchCodexPalette.bronzeBright
                      : StitchCodexPalette.crimsonBright,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    selectedTarget.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textSecondary,
                      fontFamily: StitchTypography.data,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (distanceFeet != null)
                  Text(
                    '$distanceFeet FT',
                    style: TextStyle(
                      color: targetInRange
                          ? StitchCodexPalette.bronzeBright
                          : StitchCodexPalette.crimsonBright,
                      fontFamily: StitchTypography.data,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerActionPreviewCard extends StatelessWidget {
  final CombatAction action;
  final Color color;
  final VoidCallback onTap;

  const _PlayerActionPreviewCard({
    required this.action,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = action.damageFormula ??
        action.attackFormula ??
        (action.requiresSavingThrow
            ? 'DC ${action.saveDc} ${action.saveAbility}'
            : action.type);
    final range = action.targetsSelf
        ? 'SELF'
        : action.rangeFeet == null
            ? '--'
            : '${action.rangeFeet} FT';

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                border: Border.all(color: color.withValues(alpha: 0.30)),
              ),
              child: Icon(action.icon, color: color, size: 15),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    action.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textPrimary,
                      fontFamily: StitchTypography.display,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$primary  -  $range',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StitchCodexPalette.textMuted,
                      fontFamily: StitchTypography.data,
                      fontSize: 6.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: color.withValues(alpha: 0.34)),
              ),
              child: Text(
                _compactTiming(action.timing),
                style: TextStyle(
                  color: color,
                  fontFamily: StitchTypography.data,
                  fontSize: 6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactTiming(String timing) {
    return switch (timing) {
      'Bonus Action' => 'BONUS',
      'Reaction' => 'REACCION',
      'Free' => 'LIBRE',
      _ => timing.toUpperCase(),
    };
  }
}

class _EconomyStatus extends StatelessWidget {
  final String label;
  final bool spent;
  final Color color;

  const _EconomyStatus({
    required this.label,
    required this.spent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (spent ? StitchCodexPalette.crimson : color)
              .withValues(alpha: 0.1),
          border: Border.all(
            color: (spent ? StitchCodexPalette.crimsonBright : color)
                .withValues(alpha: 0.36),
          ),
        ),
        child: Text(
          spent ? '$label USADA' : label,
          style: TextStyle(
            color: spent ? StitchCodexPalette.crimsonBright : color,
            fontFamily: StitchTypography.data,
            fontSize: 6.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;

  const _SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? StitchCodexPalette.textSecondary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 40,
          height: double.infinity,
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.12),
            border: Border(
              right: BorderSide(
                color: StitchCodexPalette.textFaint.withValues(alpha: 0.72),
              ),
            ),
          ),
          child: Icon(icon, color: effectiveColor, size: 18),
        ),
      ),
    );
  }
}
