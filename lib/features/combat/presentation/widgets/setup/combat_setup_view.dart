import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/combatant.dart';
import '../../../domain/models/combat_turn_models.dart';
import '../../../../../models/custom_monster.dart';
import '../../../../../services/monster_repository.dart';
import '../../../../../theme.dart';
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
    final party =
        combatants.where((item) => item.team == CombatTeam.party).toList();
    final activePartyCount = party
        .where((item) => !inactivePartyCombatantIds.contains(item.id))
        .length;
    final enemies =
        combatants.where((item) => item.team == CombatTeam.enemy).toList();
    final visibleMonsters = monsterCatalog;

    return ColoredBox(
      color: StitchCodexPalette.ground,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      StitchCodexPalette.ground,
                      Color(0xFF110C07),
                      StitchCodexPalette.ground,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final compactHeader = constraints.maxWidth < 700;
                    final titleBlock = Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'STITCH',
                                style: TextStyle(
                                  color: StitchCodexPalette.textPrimary,
                                  fontFamily: StitchTypography.display,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '◆',
                                style: TextStyle(
                                  color: StitchCodexPalette.bronze,
                                  fontSize: 8,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'CONFIGURAR COMBATE',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: StitchCodexPalette.bronze
                                        .withValues(alpha: 0.92),
                                    fontFamily: StitchTypography.display,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$activePartyCount/${party.length} personajes activos · ${enemies.length} enemigos preparados',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: StitchCodexPalette.textMuted,
                              fontFamily: StitchTypography.body,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                    final beginButton = _SetupBeginButton(
                      enabled: enemies.isNotEmpty && activePartyCount > 0,
                      label: 'Iniciar combate',
                      onTap: () => onBeginCombat(),
                    );
                    final customEnemyButton = _SetupOutlineButton(
                      icon: Icons.add,
                      label: 'Monstruo custom',
                      onTap: () => onCreateCustomEnemy(),
                    );
                    final header = compactHeader
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    color: StitchCodexPalette.textSecondary,
                                    tooltip: 'Volver',
                                    onPressed: onBack,
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
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                color: StitchCodexPalette.textSecondary,
                                tooltip: 'Volver',
                                onPressed: onBack,
                              ),
                              const SizedBox(width: 12),
                              titleBlock,
                              const SizedBox(width: 12),
                              SizedBox(width: 178, child: customEnemyButton),
                              const SizedBox(width: 10),
                              SizedBox(width: 190, child: beginButton),
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
                                      width: 220,
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
                                      width: 260,
                                      child: _SetupEnemyPreview(
                                        party: party,
                                        enemies: enemies,
                                        inactivePartyCombatantIds:
                                            inactivePartyCombatantIds,
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
                                        party: party,
                                        enemies: enemies,
                                        inactivePartyCombatantIds:
                                            inactivePartyCombatantIds,
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

class _SetupBeginButton extends StatelessWidget {
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  const _SetupBeginButton({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: const Icon(Icons.sports_mma, size: 16),
        label: Text(label.toUpperCase()),
        style: FilledButton.styleFrom(
          backgroundColor: StitchCodexPalette.crimson,
          foregroundColor: StitchCodexPalette.textPrimary,
          disabledBackgroundColor:
              StitchCodexPalette.crimson.withValues(alpha: 0.26),
          disabledForegroundColor:
              StitchCodexPalette.textMuted.withValues(alpha: 0.72),
          textStyle: const TextStyle(
            fontFamily: StitchTypography.display,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SetupOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SetupOutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label.toUpperCase()),
        style: OutlinedButton.styleFrom(
          foregroundColor: StitchCodexPalette.bronze,
          side: BorderSide(
            color: StitchCodexPalette.bronze.withValues(alpha: 0.52),
          ),
          textStyle: const TextStyle(
            fontFamily: StitchTypography.display,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SetupGroupLabel extends StatelessWidget {
  final String label;

  const _SetupGroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: StitchCodexPalette.textFaint,
        fontFamily: StitchTypography.data,
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _SetupEncounterRow extends StatelessWidget {
  final Combatant combatant;
  final VoidCallback? onRemove;

  const _SetupEncounterRow({
    required this.combatant,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = combatant.team == CombatTeam.party
        ? StitchCodexPalette.success
        : StitchCodexPalette.crimsonBright;
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
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
                style: const TextStyle(
                  color: StitchCodexPalette.textPrimary,
                  fontFamily: StitchTypography.display,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                combatant.role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StitchCodexPalette.textMuted,
                  fontFamily: StitchTypography.body,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 14),
            color: StitchCodexPalette.textMuted,
            visualDensity: VisualDensity.compact,
            tooltip: 'Quitar',
          ),
      ],
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
    return CombatSetupSectionFrame(
      borderColor: StitchCodexPalette.bronzeMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CombatSetupPanelTitle(
            icon: Icons.groups_outlined,
            label: 'Partido',
          ),
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
  final List<Combatant> party;
  final List<Combatant> enemies;
  final Set<String> inactivePartyCombatantIds;
  final Future<void> Function(String combatantId) onRemoveCustomEnemy;

  const _SetupEnemyPreview({
    required this.party,
    required this.enemies,
    required this.inactivePartyCombatantIds,
    required this.onRemoveCustomEnemy,
  });

  @override
  Widget build(BuildContext context) {
    final activeParty = party
        .where((item) => !inactivePartyCombatantIds.contains(item.id))
        .toList();
    return CombatSetupSectionFrame(
      borderColor: StitchCodexPalette.bronzeMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CombatSetupPanelTitle(
            icon: Icons.sports_mma,
            label: 'Encuentro',
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                const _SetupGroupLabel(label: 'Jugadores'),
                const SizedBox(height: 8),
                for (final combatant in activeParty) ...[
                  _SetupEncounterRow(combatant: combatant),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                const _SetupGroupLabel(label: 'Enemigos'),
                const SizedBox(height: 8),
                if (enemies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Agrega monstruos desde el catálogo.',
                      style: TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.body,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  for (final enemy in enemies) ...[
                    _SetupEncounterRow(
                      combatant: enemy,
                      onRemove: enemy.id.startsWith('custom_monster_')
                          ? () => onRemoveCustomEnemy(enemy.id)
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
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

  const _SetupCombatantRow({
    required this.combatant,
    this.active = true,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final accent =
        active ? combatTeamColor(combatant.team, tokens) : tokens.textMuted;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active
            ? StitchCodexPalette.surface
            : StitchCodexPalette.ground.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: active
              ? StitchCodexPalette.bronze.withValues(alpha: 0.44)
              : StitchCodexPalette.textFaint.withValues(alpha: 0.54),
        ),
      ),
      child: Row(
        children: [
          if (onToggleActive != null) ...[
            InkWell(
              onTap: () => onToggleActive!(!active),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: active
                      ? StitchCodexPalette.bronze
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: active
                        ? StitchCodexPalette.bronze
                        : StitchCodexPalette.textFaint,
                  ),
                ),
                child: active
                    ? const Icon(
                        Icons.check,
                        size: 13,
                        color: StitchCodexPalette.ground,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 30,
            height: 30,
            child: CombatCinematicPortraitBox(
              combatant: combatant,
              color: accent,
              iconSize: 14,
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
                    color: StitchCodexPalette.textPrimary,
                    fontFamily: StitchTypography.display,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  combatant.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? tokens.textSecondary : tokens.textMuted,
                    fontFamily: StitchTypography.body,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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
