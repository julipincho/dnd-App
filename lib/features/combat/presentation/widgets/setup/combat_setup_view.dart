import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/combatant.dart';
import '../../../domain/models/combat_turn_models.dart';
import '../../../../../models/custom_monster.dart';
import '../../../../../services/monster_repository.dart';
import '../../../../../theme.dart';
import '../shared/combat_cinematic_buttons.dart';
import '../shared/combat_cinematic_primitives.dart';
import '../shared/combat_portrait_widgets.dart';
import 'combat_setup_primitives.dart';

class CombatSetupView extends StatelessWidget {
  final List<Combatant> combatants;
  final List<SrdMonster> monsterCatalog;
  final int totalMonsterCount;
  final String monsterSearchQuery;
  final String? monsterCatalogError;
  final Map<String, int> stagedMonsterCounts;
  final List<CustomMonster> customMonsters;
  final Map<String, int> stagedCustomMonsterCounts;
  final Set<String> inactivePartyCombatantIds;
  final bool customMonsterLoading;
  final String? customMonsterError;
  final bool loading;
  final bool showDebugBadges;
  final VoidCallback onBack;
  final VoidCallback onReloadCatalog;
  final ValueChanged<String> onMonsterSearchChanged;
  final Future<void> Function(SrdMonster monster, int count)
      onChangeMonsterCount;
  final Future<void> Function(CustomMonster monster, int count)
      onChangeCustomMonsterCount;
  final Future<void> Function() onCreateCustomEnemy;
  final Future<void> Function(CustomMonster monster) onEditCustomEnemy;
  final Future<void> Function(CustomMonster monster) onDeleteCustomEnemy;
  final Future<void> Function(String combatantId) onRemoveCustomEnemy;
  final void Function(String combatantId, bool active) onTogglePartyCombatant;
  final Future<void> Function() onBeginCombat;

  const CombatSetupView({
    super.key,
    required this.combatants,
    required this.monsterCatalog,
    required this.totalMonsterCount,
    required this.monsterSearchQuery,
    required this.monsterCatalogError,
    required this.stagedMonsterCounts,
    required this.customMonsters,
    required this.stagedCustomMonsterCounts,
    required this.inactivePartyCombatantIds,
    required this.customMonsterLoading,
    required this.customMonsterError,
    required this.loading,
    required this.showDebugBadges,
    required this.onBack,
    required this.onReloadCatalog,
    required this.onMonsterSearchChanged,
    required this.onChangeMonsterCount,
    required this.onChangeCustomMonsterCount,
    required this.onCreateCustomEnemy,
    required this.onEditCustomEnemy,
    required this.onDeleteCustomEnemy,
    required this.onRemoveCustomEnemy,
    required this.onTogglePartyCombatant,
    required this.onBeginCombat,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final party =
        combatants.where((item) => item.team == CombatTeam.party).toList();
    final activePartyCount = party
        .where((item) => !inactivePartyCombatantIds.contains(item.id))
        .length;
    final enemies =
        combatants.where((item) => item.team == CombatTeam.enemy).toList();
    final visibleMonsters = monsterCatalog;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: Stack(
          children: [
            const Positioned.fill(child: CombatCinematicDungeonBackdrop()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.36),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final compactHeader = constraints.maxWidth < 700;
                    final titleBlock = Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configurar combate',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: CombatCinematicColors.paper,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$activePartyCount/${party.length} personajes activos contra ${enemies.length} enemigos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                    final beginButton = CombatCinematicConfirmButton(
                      enabled: enemies.isNotEmpty && activePartyCount > 0,
                      label: 'Comenzar combate',
                      onTap: () => onBeginCombat(),
                    );
                    final customEnemyButton = CombatCinematicFooterButton(
                      icon: Icons.add_circle_outline,
                      label: 'Crear enemigo',
                      color: CombatCinematicColors.goldBright,
                      compact: true,
                      onTap: () => onCreateCustomEnemy(),
                    );
                    final header = compactHeader
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CombatCinematicRoundIconButton(
                                    icon: Icons.arrow_back_rounded,
                                    tooltip: 'Volver',
                                    onTap: onBack,
                                  ),
                                  const SizedBox(width: 12),
                                  titleBlock,
                                ],
                              ),
                              const SizedBox(height: 10),
                              customEnemyButton,
                              const SizedBox(height: 8),
                              beginButton,
                            ],
                          )
                        : Row(
                            children: [
                              CombatCinematicRoundIconButton(
                                icon: Icons.arrow_back_rounded,
                                tooltip: 'Volver',
                                onTap: onBack,
                              ),
                              const SizedBox(width: 12),
                              titleBlock,
                              const SizedBox(width: 12),
                              SizedBox(width: 190, child: customEnemyButton),
                              const SizedBox(width: 10),
                              SizedBox(width: 220, child: beginButton),
                            ],
                          );
                    final catalogPanel = CombatSetupMonsterCatalogPanel(
                      monsters: visibleMonsters,
                      totalMonsterCount: totalMonsterCount,
                      searchQuery: monsterSearchQuery,
                      errorMessage: monsterCatalogError,
                      stagedMonsterCounts: stagedMonsterCounts,
                      customMonsters: customMonsters,
                      stagedCustomMonsterCounts: stagedCustomMonsterCounts,
                      customMonsterLoading: customMonsterLoading,
                      customMonsterError: customMonsterError,
                      loading: loading,
                      showDebugBadges: showDebugBadges,
                      onReload: onReloadCatalog,
                      onSearchChanged: onMonsterSearchChanged,
                      onChangeCount: onChangeMonsterCount,
                      onChangeCustomCount: onChangeCustomMonsterCount,
                      onEditCustomMonster: onEditCustomEnemy,
                      onDeleteCustomMonster: onDeleteCustomEnemy,
                    );

                    return Column(
                      children: [
                        header,
                        const SizedBox(height: 12),
                        Expanded(
                          child: wide
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 290,
                                      child: _SetupPartyPanel(
                                        party: party,
                                        inactivePartyCombatantIds:
                                            inactivePartyCombatantIds,
                                        onTogglePartyCombatant:
                                            onTogglePartyCombatant,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: catalogPanel),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 300,
                                      child: _SetupEnemyPreview(
                                        enemies: enemies,
                                        onRemoveCustomEnemy:
                                            onRemoveCustomEnemy,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    SizedBox(
                                      height: 220,
                                      child: _SetupPartyPanel(
                                        party: party,
                                        inactivePartyCombatantIds:
                                            inactivePartyCombatantIds,
                                        onTogglePartyCombatant:
                                            onTogglePartyCombatant,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: math
                                          .max(
                                            320.0,
                                            constraints.maxHeight - 260,
                                          )
                                          .clamp(320.0, 520.0)
                                          .toDouble(),
                                      child: catalogPanel,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 240,
                                      child: _SetupEnemyPreview(
                                        enemies: enemies,
                                        onRemoveCustomEnemy:
                                            onRemoveCustomEnemy,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupPartyPanel extends StatelessWidget {
  final List<Combatant> party;
  final Set<String> inactivePartyCombatantIds;
  final void Function(String combatantId, bool active) onTogglePartyCombatant;

  const _SetupPartyPanel({
    required this.party,
    required this.inactivePartyCombatantIds,
    required this.onTogglePartyCombatant,
  });

  @override
  Widget build(BuildContext context) {
    return CombatCinematicPanelFrame(
      borderColor: CombatCinematicColors.gold,
      backgroundAlpha: 0.76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CombatSetupPanelTitle(
              icon: Icons.groups_outlined, label: 'Party'),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: party.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final combatant = party[index];
                final active =
                    !inactivePartyCombatantIds.contains(combatant.id);
                return _SetupCombatantRow(
                  combatant: combatant,
                  active: active,
                  onToggleActive: (value) =>
                      onTogglePartyCombatant(combatant.id, value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupEnemyPreview extends StatelessWidget {
  final List<Combatant> enemies;
  final Future<void> Function(String combatantId) onRemoveCustomEnemy;

  const _SetupEnemyPreview({
    required this.enemies,
    required this.onRemoveCustomEnemy,
  });

  @override
  Widget build(BuildContext context) {
    return CombatCinematicPanelFrame(
      borderColor: CombatCinematicColors.blood,
      backgroundAlpha: 0.76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CombatSetupPanelTitle(
            icon: Icons.crisis_alert_outlined,
            label: 'Enemigos',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: enemies.isEmpty
                ? const Center(
                    child: Text(
                      'Agrega enemigos para comenzar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CombatCinematicColors.paper,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: enemies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final enemy = enemies[index];
                      final canRemove = enemy.id.startsWith('custom_monster_');
                      return _SetupCombatantRow(
                        combatant: enemy,
                        trailing: canRemove
                            ? IconButton(
                                onPressed: () => onRemoveCustomEnemy(enemy.id),
                                icon: const Icon(Icons.delete_outline),
                                color: CombatCinematicColors.paper,
                                tooltip: 'Quitar enemigo personalizado',
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SetupCombatantRow extends StatelessWidget {
  final Combatant combatant;
  final bool active;
  final ValueChanged<bool>? onToggleActive;
  final Widget? trailing;

  const _SetupCombatantRow({
    required this.combatant,
    this.active = true,
    this.onToggleActive,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent =
        active ? combatTeamColor(combatant.team, tokens) : tokens.textMuted;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: active ? 0.24 : 0.36),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CombatCinematicPortraitBox(
              combatant: combatant,
              color: accent,
              iconSize: 18,
            ),
          ),
          const SizedBox(width: 9),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'HP ${combatant.hp}/${combatant.maxHp}  CA ${combatant.ac}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? tokens.textSecondary : tokens.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ] else if (onToggleActive != null) ...[
            const SizedBox(width: 6),
            Switch(
              value: active,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onToggleActive,
            ),
          ],
        ],
      ),
    );
  }
}
