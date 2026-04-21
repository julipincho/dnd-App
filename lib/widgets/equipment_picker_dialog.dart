import 'package:flutter/material.dart';

import '../models/equipment_compendium_item.dart';

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

  Color _typeColor(EquipmentCompendiumItem item) {
    if (item.isWeapon) return Colors.redAccent;
    if (item.isArmor) return Colors.blueAccent;
    if (item.isShield) return Colors.tealAccent;
    if (item.isAccessory) return Colors.amberAccent;
    return Colors.deepPurpleAccent;
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

    return parts.join(' • ');
  }

  IconData _itemIcon(EquipmentCompendiumItem item) {
    if (item.isWeapon) return Icons.gavel_outlined;
    if (item.isArmor) return Icons.checkroom_outlined;
    if (item.isShield) return Icons.shield_outlined;
    if (item.isAccessory) return Icons.auto_awesome_outlined;
    return Icons.inventory_2_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: isTablet ? 520 : 360,
        height: isTablet ? 620 : 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _filterLabels.entries.map((entry) {
                  final key = entry.key;
                  final label = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _selectedFilter == key,
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
            const SizedBox(height: 12),
            Text(
              '${filteredItems.length} result${filteredItems.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        'No equipment items found.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final selected = _selectedItem?.id == item.id;
                        final accent = _typeColor(item);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _selectedItem = item;
                              });
                            },
                            onDoubleTap: () {
                              Navigator.of(context).pop(item);
                            },
                            child: Ink(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF202028),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? accent.withOpacity(0.8)
                                      : Colors.deepPurpleAccent
                                          .withOpacity(0.22),
                                  width: selected ? 1.5 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: accent.withOpacity(0.16),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _itemIcon(item),
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _buildMeta(item),
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.68),
                                            fontSize: 12,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _MiniChip(label: item.type),
                                            if (item.isMagic)
                                              const _MiniChip(label: 'Magic'),
                                            if (item.requiresAttunement)
                                              const _MiniChip(
                                                label: 'Attunement',
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: selected
                                        ? accent
                                        : Colors.white.withOpacity(0.45),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_selectedItem != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.deepPurpleAccent.withOpacity(0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedItem!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildMeta(_selectedItem!),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedItem == null
              ? null
              : () => Navigator.of(context).pop(_selectedItem),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;

  const _MiniChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.82),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
