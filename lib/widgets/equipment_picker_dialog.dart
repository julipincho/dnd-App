import 'package:flutter/material.dart';

import '../models/equipment_compendium_item.dart';
import '../theme.dart';

Future<EquipmentCompendiumItem?> showEquipmentPickerDialog(
  BuildContext context, {
  required List<EquipmentCompendiumItem> items,
  EquipmentCompendiumItem? initiallySelected,
  String title = 'Select equipment item',
}) {
  return showDialog<EquipmentCompendiumItem>(
    context: context,
    builder: (_) => EquipmentPickerDialog(
      items: items,
      initiallySelected: initiallySelected,
      title: title,
    ),
  );
}

class EquipmentPickerDialog extends StatefulWidget {
  final List<EquipmentCompendiumItem> items;
  final EquipmentCompendiumItem? initiallySelected;
  final String title;

  const EquipmentPickerDialog({
    super.key,
    required this.items,
    this.initiallySelected,
    this.title = 'Select equipment item',
  });

  @override
  State<EquipmentPickerDialog> createState() => _EquipmentPickerDialogState();
}

class _EquipmentPickerDialogState extends State<EquipmentPickerDialog> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String _selectedFilter = 'all';
  EquipmentCompendiumItem? _selectedItem;

  static const Map<String, String> _filterLabels = {
    'all': 'All',
    'weapon': 'Weapons',
    'armor': 'Armor',
    'shield': 'Shields',
    'accessory': 'Accessories',
  };

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initiallySelected;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EquipmentCompendiumItem> get _filteredItems {
    final normalizedQuery = _query.trim().toLowerCase();

    final filtered = widget.items.where((item) {
      final matchesFilter =
          _selectedFilter == 'all' || item.type == _selectedFilter;

      final matchesQuery = normalizedQuery.isEmpty ||
          item.name.toLowerCase().contains(normalizedQuery) ||
          item.source.toLowerCase().contains(normalizedQuery) ||
          item.displayCategory.toLowerCase().contains(normalizedQuery);

      return matchesFilter && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      final typeCompare = a.type.compareTo(b.type);
      if (typeCompare != 0) return typeCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  Color _typeColor(EquipmentCompendiumItem item, StitchThemeTokens tokens) {
    if (item.isMagic) return tokens.accentMagic;
    if (item.isWeapon) return tokens.accentAction;
    if (item.isArmor || item.isShield) return tokens.accentRead;
    if (item.isAccessory) return tokens.accentWarning;
    return tokens.accentInfo;
  }

  String _buildMeta(EquipmentCompendiumItem item) {
    final parts = <String>[];

    if (item.displayCategory.trim().isNotEmpty) {
      parts.add(item.displayCategory);
    }

    if (item.isWeapon) {
      final damage = item.damageDiceOneHanded;
      final damageType = item.damageType;

      if (damage != null && damage.isNotEmpty) {
        parts.add(
          damageType != null && damageType.isNotEmpty
              ? '$damage $damageType'
              : damage,
        );
      }
    }

    if (item.isArmor && item.baseArmorClass != null) {
      parts.add('AC ${item.baseArmorClass}');
    }

    if (item.isShield && item.armorClassBonus != null) {
      parts.add('+${item.armorClassBonus} AC');
    }

    parts.add(item.source);

    return parts.join(' - ');
  }

  IconData _itemIcon(EquipmentCompendiumItem item) {
    if (item.isWeapon) return Icons.gavel_outlined;
    if (item.isArmor) return Icons.checkroom_outlined;
    if (item.isShield) return Icons.shield_outlined;
    if (item.isAccessory) return Icons.diamond_outlined;
    return Icons.inventory_2_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final filteredItems = _filteredItems;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 28 : 14,
        vertical: isTablet ? 24 : 14,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 680 : 420,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border: Border.all(
              color: tokens.accentRead.withValues(alpha: 0.26),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              _PickerHeader(
                title: widget.title,
                resultCount: filteredItems.length,
                totalCount: widget.items.length,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, type, or source...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                  });
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _filterLabels.entries.map((entry) {
                          final key = entry.key;
                          final label = entry.value;
                          final selected = _selectedFilter == key;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              selectedColor:
                                  tokens.accentRead.withValues(alpha: 0.18),
                              backgroundColor:
                                  tokens.surface.withValues(alpha: 0.80),
                              side: BorderSide(
                                color: selected
                                    ? tokens.accentRead.withValues(alpha: 0.34)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(tokens.radiusSm),
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedFilter = key;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredItems.isEmpty
                    ? _PickerEmptyState(query: _query)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final selected = _selectedItem?.id == item.id;
                          final accent = _typeColor(item, tokens);

                          return _EquipmentResultTile(
                            item: item,
                            selected: selected,
                            accent: accent,
                            icon: _itemIcon(item),
                            meta: _buildMeta(item),
                            onTap: () {
                              setState(() {
                                _selectedItem = item;
                              });
                            },
                            onDoubleTap: () {
                              Navigator.of(context).pop(item);
                            },
                          );
                        },
                      ),
              ),
              if (_selectedItem != null)
                _SelectedEquipmentPreview(
                  item: _selectedItem!,
                  accent: _typeColor(_selectedItem!, tokens),
                  meta: _buildMeta(_selectedItem!),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _selectedItem == null
                            ? null
                            : () => Navigator.of(context).pop(_selectedItem),
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.accentRead,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Select'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  final String title;
  final int resultCount;
  final int totalCount;

  const _PickerHeader({
    required this.title,
    required this.resultCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tokens.accentRead.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(
                color: tokens.accentRead.withValues(alpha: 0.24),
              ),
            ),
            child: Icon(
              Icons.manage_search_outlined,
              color: tokens.accentReadSoft,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.accentReadSoft.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$resultCount results from $totalCount armory items',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            color: tokens.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _EquipmentResultTile extends StatelessWidget {
  final EquipmentCompendiumItem item;
  final bool selected;
  final Color accent;
  final IconData icon;
  final String meta;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _EquipmentResultTile({
    required this.item,
    required this.selected,
    required this.accent,
    required this.icon,
    required this.meta,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.18),
                      tokens.surface,
                    ],
                  )
                : null,
            color: selected ? null : tokens.surface,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.70)
                  : tokens.accentRead.withValues(alpha: 0.16),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _MiniChip(label: item.type, color: accent),
                        if (item.isMagic)
                          _MiniChip(label: 'Magic', color: tokens.accentMagic),
                        if (item.requiresAttunement)
                          _MiniChip(
                            label: 'Attunement',
                            color: tokens.accentWarning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? accent : tokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedEquipmentPreview extends StatelessWidget {
  final EquipmentCompendiumItem item;
  final Color accent;
  final String meta;

  const _SelectedEquipmentPreview({
    required this.item,
    required this.accent,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerEmptyState extends StatelessWidget {
  final String query;

  const _PickerEmptyState({
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              color: tokens.accentReadSoft,
              size: 34,
            ),
            const SizedBox(height: 10),
            const Text(
              'No equipment found.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (query.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Try another search or filter.',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
