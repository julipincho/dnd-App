import 'package:flutter/material.dart';

import '../../../../../models/custom_monster.dart';
import '../../../../../services/monster_repository.dart';
import '../../../../../theme.dart';
import '../../../../../utils/image_path_utils.dart';
import '../shared/combat_cinematic_buttons.dart';
import '../shared/combat_cinematic_primitives.dart';

const _setupGold = Color(0xFF9C7140);
const _setupGoldBright = Color(0xFFE5B46C);
const _setupPaper = Color(0xFFF2D8B5);
const _setupTextMuted = Color(0xFFC3A57E);

class CombatCompactNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const CombatCompactNumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class CombatSetupPanelTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const CombatSetupPanelTitle({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _setupGoldBright, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _setupPaper,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class CombatMiniSetupBadge extends StatelessWidget {
  final String label;
  final bool visible;

  const CombatMiniSetupBadge({
    super.key,
    required this.label,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _setupGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: _setupGold.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _setupPaper,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class CombatSetupCountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const CombatSetupCountButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 30,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _setupGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: _setupGold.withValues(alpha: 0.28),
          ),
        ),
        child: Icon(icon, color: _setupPaper, size: 16),
      ),
    );
  }
}

class CombatSetupMonsterSearchField extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;

  const CombatSetupMonsterSearchField({
    super.key,
    required this.query,
    required this.onChanged,
  });

  @override
  State<CombatSetupMonsterSearchField> createState() =>
      _CombatSetupMonsterSearchFieldState();
}

class _CombatSetupMonsterSearchFieldState
    extends State<CombatSetupMonsterSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant CombatSetupMonsterSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: const TextStyle(
        color: _setupPaper,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Buscar por nombre, tipo o CR',
        hintStyle: TextStyle(color: tokens.textMuted),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: _setupGoldBright,
          size: 18,
        ),
        suffixIcon: widget.query.trim().isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: _setupPaper,
                onPressed: () => widget.onChanged(''),
              ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: _setupGold.withValues(alpha: 0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: _setupGold.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _setupGoldBright),
        ),
      ),
    );
  }
}

class CombatSetupMonsterEmptyState extends StatelessWidget {
  final bool loading;

  const CombatSetupMonsterEmptyState({
    super.key,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        loading ? 'Cargando monstruos...' : 'No hay monstruos para mostrar.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _setupPaper,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class CombatSetupMonsterError extends StatelessWidget {
  final String message;
  final VoidCallback onReload;

  const CombatSetupMonsterError({
    super.key,
    required this.message,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: _setupGoldBright,
              size: 34,
            ),
            const SizedBox(height: 10),
            const Text(
              'No se pudo cargar el bestiario.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _setupPaper,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _setupTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            CombatCinematicFooterButton(
              icon: Icons.refresh_rounded,
              label: 'Reintentar',
              color: _setupGoldBright,
              onTap: onReload,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class CombatSetupMonsterTile extends StatelessWidget {
  final SrdMonster monster;
  final int count;
  final ValueChanged<int> onChangeCount;

  const CombatSetupMonsterTile({
    super.key,
    required this.monster,
    required this.count,
    required this.onChangeCount,
  });

  @override
  Widget build(BuildContext context) {
    final selected = count > 0;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF8F1E19).withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected
              ? _setupGoldBright.withValues(alpha: 0.44)
              : _setupGold.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monster.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _setupPaper,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${monster.size} ${monster.type}${monster.challengeRating == null ? '' : ' - CR ${monster.challengeRating}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _setupTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              CombatSetupCountButton(
                icon: Icons.remove,
                onTap: () => onChangeCount(count - 1),
              ),
              Expanded(
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _setupPaper,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              CombatSetupCountButton(
                icon: Icons.add,
                onTap: () => onChangeCount(count + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CombatSetupCustomMonsterEmptyState extends StatelessWidget {
  const CombatSetupCustomMonsterEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'Tu bestiario personalizado esta vacio. Usa Crear enemigo para guardar una plantilla con acciones, reacciones, multiattack y rasgos pasivos.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _setupPaper,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class CombatSetupCustomMonsterTile extends StatelessWidget {
  final CustomMonster monster;
  final int count;
  final bool showDebugBadges;
  final ValueChanged<int> onChangeCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CombatSetupCustomMonsterTile({
    super.key,
    required this.monster,
    required this.count,
    required this.showDebugBadges,
    required this.onChangeCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final selected = count > 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF8F1E19).withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected
              ? _setupGoldBright.withValues(alpha: 0.44)
              : _setupGold.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: monster.portraitPath == null
                  ? Container(
                      color: const Color(0xFF8F1E19).withValues(alpha: 0.18),
                      child: const Icon(
                        Icons.crisis_alert_outlined,
                        color: _setupPaper,
                      ),
                    )
                  : buildImageFromPath(
                      monster.portraitPath!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monster.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _setupPaper,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  monster.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    CombatMiniSetupBadge(
                      label: 'HP ${monster.hitPoints}',
                      visible: showDebugBadges,
                    ),
                    CombatMiniSetupBadge(
                      label: 'CA ${monster.armorClass}',
                      visible: showDebugBadges,
                    ),
                    CombatMiniSetupBadge(
                      label: '${monster.activeActionCount} act',
                      visible: showDebugBadges,
                    ),
                    if (monster.passiveCount > 0)
                      CombatMiniSetupBadge(
                        label: '${monster.passiveCount} pas',
                        visible: showDebugBadges,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Row(
              children: [
                CombatSetupCountButton(
                  icon: Icons.remove,
                  onTap: () => onChangeCount(count - 1),
                ),
                Expanded(
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _setupPaper,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                CombatSetupCountButton(
                  icon: Icons.add,
                  onTap: () => onChangeCount(count + 1),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar plantilla',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: _setupPaper,
          ),
          IconButton(
            tooltip: 'Eliminar plantilla',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: _setupPaper,
          ),
        ],
      ),
    );
  }
}

class CombatSetupMonsterCatalogPanel extends StatelessWidget {
  final List<SrdMonster> monsters;
  final int totalMonsterCount;
  final String searchQuery;
  final String? errorMessage;
  final Map<String, int> stagedMonsterCounts;
  final List<CustomMonster> customMonsters;
  final Map<String, int> stagedCustomMonsterCounts;
  final bool customMonsterLoading;
  final String? customMonsterError;
  final bool loading;
  final bool showDebugBadges;
  final VoidCallback onReload;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(SrdMonster monster, int count) onChangeCount;
  final Future<void> Function(CustomMonster monster, int count)
      onChangeCustomCount;
  final Future<void> Function(CustomMonster monster) onEditCustomMonster;
  final Future<void> Function(CustomMonster monster) onDeleteCustomMonster;

  const CombatSetupMonsterCatalogPanel({
    super.key,
    required this.monsters,
    required this.totalMonsterCount,
    required this.searchQuery,
    required this.errorMessage,
    required this.stagedMonsterCounts,
    required this.customMonsters,
    required this.stagedCustomMonsterCounts,
    required this.customMonsterLoading,
    required this.customMonsterError,
    required this.loading,
    required this.showDebugBadges,
    required this.onReload,
    required this.onSearchChanged,
    required this.onChangeCount,
    required this.onChangeCustomCount,
    required this.onEditCustomMonster,
    required this.onDeleteCustomMonster,
  });

  @override
  Widget build(BuildContext context) {
    return CombatCinematicPanelFrame(
      borderColor: CombatCinematicColors.gold,
      backgroundAlpha: 0.78,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: CombatSetupPanelTitle(
                    icon: Icons.menu_book_outlined,
                    label: 'Bestiario',
                  ),
                ),
                if (loading || customMonsterLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  CombatCinematicRoundIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Recargar',
                    onTap: onReload,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TabBar(
              indicatorColor: CombatCinematicColors.goldBright,
              labelColor: CombatCinematicColors.paper,
              unselectedLabelColor: CombatCinematicColors.actionTextMuted,
              tabs: [
                Tab(text: 'SRD ($totalMonsterCount)'),
                Tab(text: 'Custom (${customMonsters.length})'),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      CombatSetupMonsterSearchField(
                        query: searchQuery,
                        onChanged: onSearchChanged,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: errorMessage != null
                            ? CombatSetupMonsterError(
                                message: errorMessage!,
                                onReload: onReload,
                              )
                            : monsters.isEmpty
                                ? CombatSetupMonsterEmptyState(
                                    loading: loading,
                                  )
                                : GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 230,
                                      mainAxisExtent: 104,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: monsters.length,
                                    itemBuilder: (context, index) {
                                      final monster = monsters[index];
                                      final count =
                                          stagedMonsterCounts[monster.index] ??
                                              0;
                                      return CombatSetupMonsterTile(
                                        monster: monster,
                                        count: count,
                                        onChangeCount: (next) =>
                                            onChangeCount(monster, next),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                  customMonsterError != null
                      ? CombatSetupMonsterError(
                          message: customMonsterError!,
                          onReload: () {},
                        )
                      : customMonsters.isEmpty
                          ? const CombatSetupCustomMonsterEmptyState()
                          : ListView.separated(
                              itemCount: customMonsters.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final monster = customMonsters[index];
                                final count =
                                    stagedCustomMonsterCounts[monster.id] ?? 0;
                                return CombatSetupCustomMonsterTile(
                                  monster: monster,
                                  count: count,
                                  showDebugBadges: showDebugBadges,
                                  onChangeCount: (next) =>
                                      onChangeCustomCount(monster, next),
                                  onEdit: () => onEditCustomMonster(monster),
                                  onDelete: () =>
                                      onDeleteCustomMonster(monster),
                                );
                              },
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
