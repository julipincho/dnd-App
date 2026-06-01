import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/services/combat_board_token_lookup.dart';
import '../../../domain/models/combatant.dart';
import '../../../domain/models/combat_turn_models.dart';
import '../../../domain/rules/combat_board_geometry.dart';
import '../../../../../models/board_token.dart';
import '../../../../../providers/battle_board_provider.dart';
import '../../../../../theme.dart';
import '../../../../../utils/image_path_utils.dart';
import '../shared/combat_metric_widgets.dart';
import '../shared/combat_portrait_widgets.dart';
import 'combat_movement_controls.dart';

class CombatBattleBoardFloatingController extends StatefulWidget {
  final String sceneId;
  final String displayUrl;
  final List<Combatant> combatants;
  final String selectedCombatantId;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClose;
  final ValueChanged<String> onSelectCombatant;
  final Future<void> Function(String combatantId, int dx, int dy) onMove;
  final Future<void> Function() onOpenDisplay;
  final Future<void> Function() onSyncState;

  const CombatBattleBoardFloatingController({
    super.key,
    required this.sceneId,
    required this.displayUrl,
    required this.combatants,
    required this.selectedCombatantId,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onClose,
    required this.onSelectCombatant,
    required this.onMove,
    required this.onOpenDisplay,
    required this.onSyncState,
  });

  @override
  State<CombatBattleBoardFloatingController> createState() =>
      _CombatBattleBoardFloatingControllerState();
}

class _CombatBattleBoardFloatingControllerState
    extends State<CombatBattleBoardFloatingController> {
  late String _selectedCombatantId;
  bool _moving = false;
  math.Point<int> _queuedMove = const math.Point<int>(0, 0);
  bool _openingDisplay = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _selectedCombatantId = widget.selectedCombatantId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.stitch;
    final boardProvider = context.watch<BattleBoardProvider>();
    if (widget.combatants.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedCombatant = widget.combatants.firstWhere(
      (combatant) => combatant.id == _selectedCombatantId,
      orElse: () => widget.combatants.first,
    );
    final sceneTokens = boardProvider.tokens
        .where((token) => token.sceneId == widget.sceneId)
        .toList(growable: false);
    final selectedToken =
        CombatBoardTokenLookup.byRef(sceneTokens, selectedCombatant.id);
    final activeToken = CombatBoardTokenLookup.active(sceneTokens);
    final targetToken = CombatBoardTokenLookup.targeted(sceneTokens);
    final aimingArea = activeToken != null &&
        selectedCombatant.id == activeToken.refId &&
        activeToken.selectedActionAreaFeet > 0;
    final selectedMovement = selectedToken == null
        ? 'Loading'
        : aimingArea
            ? 'Aiming area'
            : '${selectedToken.remainingMovementFeet}/${selectedToken.speedFeet} ft';
    final positionLabel = selectedToken == null
        ? 'Loading position'
        : 'Grid ${selectedToken.x}, ${selectedToken.y}';
    final targetDistance = activeToken == null || targetToken == null
        ? null
        : CombatBoardGeometry.distanceFeet(activeToken, targetToken);
    final canMove = selectedToken != null &&
        (aimingArea || selectedToken.remainingMovementFeet >= 5);

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: widget.expanded ? 390 : 286,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.panel.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(color: theme.border.withValues(alpha: 0.65)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports_rounded, color: theme.accentInfo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.expanded
                        ? 'Combat controller'
                        : selectedCombatant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                CombatControllerSignalPill(
                  icon: Icons.bolt_rounded,
                  label: selectedMovement,
                  color: theme.accentSuccess,
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Open display',
                  onPressed: _openingDisplay ? null : _openDisplay,
                  icon: _openingDisplay
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_new_rounded),
                ),
                IconButton(
                  tooltip: widget.expanded ? 'Minimize' : 'Expand',
                  onPressed: widget.onToggleExpanded,
                  icon: Icon(
                    widget.expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Hide board controls',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (!widget.expanded) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _CompactBoardReadout(
                      activeName: activeToken?.name ?? selectedCombatant.name,
                      targetName: targetToken?.name,
                      positionLabel: positionLabel,
                      distanceFeet: targetDistance,
                    ),
                  ),
                  CombatMovementStrip(
                    enabled: canMove,
                    onMove: _move,
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              _BoardControllerHero(
                combatant: selectedCombatant,
                token: selectedToken,
                activeToken: activeToken,
                targetToken: targetToken,
                distanceFeet: targetDistance,
                positionLabel: positionLabel,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CombatControllerSignalPill(
                      icon: Icons.directions_run_rounded,
                      label: selectedToken == null
                          ? 'Speed --'
                          : aimingArea
                              ? '${activeToken.selectedActionAreaShape} ${activeToken.selectedActionAreaFeet} ft aim'
                              : '$selectedMovement movement',
                      color:
                          aimingArea ? theme.accentMagic : theme.accentSuccess,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CombatControllerSignalPill(
                      icon: Icons.center_focus_strong_rounded,
                      label: targetToken == null
                          ? 'Target --'
                          : targetDistance == null
                              ? targetToken.name
                              : '${targetToken.name} $targetDistance ft',
                      color: targetToken?.isTargetInRange == false
                          ? theme.accentAction
                          : theme.accentWarning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.surface.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                  border:
                      Border.all(color: theme.border.withValues(alpha: 0.42)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.live_tv_rounded,
                        color: theme.accentInfo,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          widget.displayUrl,
                          maxLines: 1,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedCombatantId,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  prefixIcon: Icon(Icons.adjust_rounded),
                ),
                items: [
                  for (final combatant in widget.combatants)
                    DropdownMenuItem<String>(
                      value: combatant.id,
                      child: Text(
                        combatant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (combatantId) {
                  if (combatantId == null) return;
                  setState(() {
                    _selectedCombatantId = combatantId;
                  });
                  widget.onSelectCombatant(combatantId);
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedCombatant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$positionLabel - 1 square = 5 ft',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        CombatMovementBudgetBar(token: selectedToken),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CombatMovementPad(
                    enabled: canMove,
                    onMove: _move,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _syncing ? null : _syncState,
                      icon: _syncing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: const Text('Sync state'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openingDisplay ? null : _openDisplay,
                      icon: const Icon(Icons.tv_rounded),
                      label: const Text('Display'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDisplay() async {
    if (_openingDisplay) return;
    setState(() {
      _openingDisplay = true;
    });
    try {
      await widget.onOpenDisplay();
    } finally {
      if (mounted) {
        setState(() {
          _openingDisplay = false;
        });
      }
    }
  }

  Future<void> _syncState() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
    });
    try {
      await widget.onSyncState();
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _move(int dx, int dy) async {
    if (_moving) {
      _queuedMove = math.Point<int>(_queuedMove.x + dx, _queuedMove.y + dy);
      return;
    }
    setState(() {
      _moving = true;
    });
    try {
      await widget.onMove(_selectedCombatantId, dx, dy);
    } finally {
      if (mounted) {
        setState(() {
          _moving = false;
        });
      }
    }
    final queued = _queuedMove;
    _queuedMove = const math.Point<int>(0, 0);
    if (queued.x != 0 || queued.y != 0) {
      unawaited(_move(queued.x, queued.y));
    }
  }
}

class _BoardControllerHero extends StatelessWidget {
  final Combatant combatant;
  final BoardToken? token;
  final BoardToken? activeToken;
  final BoardToken? targetToken;
  final int? distanceFeet;
  final String positionLabel;

  const _BoardControllerHero({
    required this.combatant,
    required this.token,
    required this.activeToken,
    required this.targetToken,
    required this.distanceFeet,
    required this.positionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.stitch;
    final isActive = token?.isActive ?? activeToken?.refId == combatant.id;
    final isTarget = token?.isTargeted ?? targetToken?.refId == combatant.id;
    final accent = isActive
        ? theme.accentSuccess
        : isTarget
            ? theme.accentWarning
            : combatTeamColor(combatant.team, theme);
    final imagePath = token?.imageUrl.isNotEmpty == true
        ? token!.imageUrl
        : combatant.portraitAsset;
    final activeBoardToken = activeToken;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.surfaceRaised.withValues(alpha: 0.96),
            theme.surface.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.28),
                border: Border.all(color: accent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 16,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: hasDisplayableImagePath(imagePath)
                  ? buildImageFromPath(
                      imagePath!,
                      fit: BoxFit.cover,
                      width: 58,
                      height: 58,
                    )
                  : Icon(
                      combatant.team == CombatTeam.enemy
                          ? Icons.crisis_alert_outlined
                          : Icons.person_outline,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          combatant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (isActive)
                        CombatControllerSignalPill(
                          icon: Icons.bolt_rounded,
                          label: 'Active',
                          color: theme.accentSuccess,
                        )
                      else if (isTarget)
                        CombatControllerSignalPill(
                          icon: Icons.center_focus_strong_rounded,
                          label: 'Target',
                          color: theme.accentWarning,
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      CombatControllerSignalPill(
                        icon: Icons.favorite_rounded,
                        label: '${combatant.hp}/${combatant.maxHp} HP',
                        color: combatant.hp <= combatant.maxHp * 0.35
                            ? theme.accentAction
                            : theme.accentSuccess,
                      ),
                      CombatControllerSignalPill(
                        icon: Icons.shield_outlined,
                        label: 'AC ${combatant.ac}',
                        color: theme.accentReadSoft,
                      ),
                      CombatControllerSignalPill(
                        icon: Icons.place_outlined,
                        label: positionLabel,
                        color: theme.accentInfo,
                      ),
                      if (activeToken?.focusedActionName.isNotEmpty == true)
                        CombatControllerSignalPill(
                          icon: Icons.radar_rounded,
                          label:
                              '${activeToken!.focusedActionName} ${activeToken!.selectedActionRangeFeet} ft',
                          color: theme.accentInfo,
                        ),
                      if ((activeBoardToken?.selectedActionAreaFeet ?? 0) > 0)
                        CombatControllerSignalPill(
                          icon: Icons.blur_circular_rounded,
                          label:
                              '${activeBoardToken!.selectedActionAreaShape} ${activeBoardToken.selectedActionAreaFeet} ft',
                          color: theme.accentMagic,
                        ),
                      if (distanceFeet != null)
                        CombatControllerSignalPill(
                          icon: targetToken?.isTargetInRange == false
                              ? Icons.warning_amber_rounded
                              : Icons.social_distance_rounded,
                          label: '$distanceFeet ft',
                          color: targetToken?.isTargetInRange == false
                              ? theme.accentAction
                              : theme.accentWarning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactBoardReadout extends StatelessWidget {
  final String activeName;
  final String? targetName;
  final String positionLabel;
  final int? distanceFeet;

  const _CompactBoardReadout({
    required this.activeName,
    required this.targetName,
    required this.positionLabel,
    required this.distanceFeet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.stitch;
    final targetText = targetName == null
        ? 'No target'
        : distanceFeet == null
            ? targetName!
            : '$targetName - $distanceFeet ft';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          activeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$positionLabel · $targetText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
