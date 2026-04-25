import 'package:flutter/material.dart';

import '../../../../../models/character.dart';
import '../../../../../models/character_inventory_item.dart';
import '../../../../../models/equipment_compendium_item.dart';
import '../../../models/resolved_inventory_item.dart';
import '../../../../../screens/compendium_entry_detail_screen.dart';

class CharacterInventoryTab extends StatelessWidget {
  final Character character;
  final bool isDm;
  final bool isOwnedByCurrentUser;
  final bool canManageInventory;
  final VoidCallback onAddItem;
  final Future<void> Function(CharacterInventoryItem item) onRemoveItem;
  final Widget Function({
    required bool isTablet,
    required bool isLargeTablet,
  }) buildEquipmentSection;
  final ResolvedInventoryItem Function(CharacterInventoryItem item)
      resolveInventoryItem;
  final bool Function(CharacterInventoryItem item) isItemEquipped;
  final String Function(
    CharacterInventoryItem effectiveItem,
    EquipmentCompendiumItem? equipmentItem,
  ) buildEquipmentMetaLabel;
  final Widget Function(
    String path, {
    required double width,
    required double height,
    BoxFit fit,
  }) buildResolvedImage;
  final Future<void> Function(CharacterInventoryItem item) onEquipItem;
  final Future<void> Function(CharacterInventoryItem item) onUnequipItem;
  final bool Function(CharacterInventoryItem item) hasInfusionOptions;
  final Future<void> Function(CharacterInventoryItem item) onShowInfusionPicker;

  const CharacterInventoryTab({
    super.key,
    required this.character,
    required this.isDm,
    required this.isOwnedByCurrentUser,
    required this.canManageInventory,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.buildEquipmentSection,
    required this.resolveInventoryItem,
    required this.isItemEquipped,
    required this.buildEquipmentMetaLabel,
    required this.buildResolvedImage,
    required this.onEquipItem,
    required this.onUnequipItem,
    required this.hasInfusionOptions,
    required this.onShowInfusionPicker,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;
    final maxWidth = isLargeTablet ? 1100.0 : 900.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16,
            isTablet ? 20 : 16,
            isTablet ? 24 : 16,
            8,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Inventory',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: isLargeTablet ? 22 : (isTablet ? 20 : 18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (canManageInventory)
                    TextButton.icon(
                      onPressed: onAddItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add item'),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                children: [
                  buildEquipmentSection(
                    isTablet: isTablet,
                    isLargeTablet: isLargeTablet,
                  ),
                  const SizedBox(height: 20),
                  if (character.inventory.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          isDm
                              ? 'No items yet. Grant one from the compendium.'
                              : 'No items yet.',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    ...character.inventory.map(
                      (inventoryItem) => _InventoryItemCard(
                        inventoryItem: inventoryItem,
                        resolvedItem: resolveInventoryItem(inventoryItem),
                        isEquipped: isItemEquipped(inventoryItem),
                        isTablet: isTablet,
                        canManageInventory: canManageInventory,
                        isOwnedByCurrentUser: isOwnedByCurrentUser,
                        buildEquipmentMetaLabel: buildEquipmentMetaLabel,
                        buildResolvedImage: buildResolvedImage,
                        onRemoveItem: () => onRemoveItem(inventoryItem),
                        onEquipItem: () => onEquipItem(
                          resolveInventoryItem(inventoryItem).effectiveItem,
                        ),
                        onUnequipItem: () => onUnequipItem(
                          resolveInventoryItem(inventoryItem).effectiveItem,
                        ),
                        hasInfusionOptions: hasInfusionOptions(inventoryItem),
                        onShowInfusionPicker: () =>
                            onShowInfusionPicker(inventoryItem),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final CharacterInventoryItem inventoryItem;
  final ResolvedInventoryItem resolvedItem;
  final bool isEquipped;
  final bool isTablet;
  final bool canManageInventory;
  final bool isOwnedByCurrentUser;
  final String Function(
    CharacterInventoryItem effectiveItem,
    EquipmentCompendiumItem? equipmentItem,
  ) buildEquipmentMetaLabel;
  final Widget Function(
    String path, {
    required double width,
    required double height,
    BoxFit fit,
  }) buildResolvedImage;
  final Future<void> Function() onRemoveItem;
  final Future<void> Function() onEquipItem;
  final Future<void> Function() onUnequipItem;
  final bool hasInfusionOptions;
  final Future<void> Function() onShowInfusionPicker;

  const _InventoryItemCard({
    required this.inventoryItem,
    required this.resolvedItem,
    required this.isEquipped,
    required this.isTablet,
    required this.canManageInventory,
    required this.isOwnedByCurrentUser,
    required this.buildEquipmentMetaLabel,
    required this.buildResolvedImage,
    required this.onRemoveItem,
    required this.onEquipItem,
    required this.onUnequipItem,
    required this.hasInfusionOptions,
    required this.onShowInfusionPicker,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveItem = resolvedItem.effectiveItem;
    final linkedEntry = resolvedItem.campaignEntry;
    final itemMetaLabel = buildEquipmentMetaLabel(
      effectiveItem,
      resolvedItem.equipmentItem,
    );
    final displayImagePath = resolvedItem.resolvedImagePath;
    final hasItemImage = displayImagePath != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEquipped
              ? Colors.greenAccent.withValues(alpha: 0.45)
              : Colors.deepPurpleAccent.withValues(alpha: 0.35),
        ),
      ),
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              hasItemImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: buildResolvedImage(
                        displayImagePath,
                        width: isTablet ? 64 : 52,
                        height: isTablet ? 64 : 52,
                        fit: BoxFit.cover,
                      ),
                    )
                  : CircleAvatar(
                      radius: isTablet ? 26 : 20,
                      backgroundColor: Colors.deepPurpleAccent,
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.white,
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: _InventoryItemSummary(
                  inventoryItem: inventoryItem,
                  effectiveItem: effectiveItem,
                  itemMetaLabel: itemMetaLabel,
                  isEquipped: isEquipped,
                  isTablet: isTablet,
                ),
              ),
              if (canManageInventory)
                IconButton(
                  onPressed: onRemoveItem,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white70,
                  ),
                  tooltip: 'Remove item',
                ),
            ],
          ),
          if (hasItemImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: buildResolvedImage(
                displayImagePath,
                width: double.infinity,
                height: isTablet ? 220 : 160,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if ((resolvedItem.resolvedDescription ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              resolvedItem.resolvedDescription!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: isTablet ? 14 : 13,
                height: 1.4,
              ),
            ),
          ],
          if ((inventoryItem.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              inventoryItem.notes!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: isTablet ? 15 : 14,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(resolvedItem.sourceLabel),
                visualDensity: VisualDensity.compact,
              ),
              if (linkedEntry != null)
                ActionChip(
                  label: const Text('Open compendium'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CompendiumEntryDetailScreen(
                          entry: linkedEntry,
                        ),
                      ),
                    );
                  },
                ),
              if (effectiveItem.isEquippable && !isEquipped)
                ActionChip(
                  label: const Text('Equip'),
                  onPressed: isOwnedByCurrentUser ? onEquipItem : null,
                ),
              if (effectiveItem.isEquippable && isEquipped)
                ActionChip(
                  label: const Text('Unequip'),
                  onPressed: isOwnedByCurrentUser ? onUnequipItem : null,
                ),
              if (hasInfusionOptions)
                ActionChip(
                  label: Text(
                    (inventoryItem.appliedInfusionId ?? '').trim().isNotEmpty
                        ? 'Change Infusion'
                        : 'Infuse',
                  ),
                  onPressed: isOwnedByCurrentUser ? onShowInfusionPicker : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryItemSummary extends StatelessWidget {
  final CharacterInventoryItem inventoryItem;
  final CharacterInventoryItem effectiveItem;
  final String itemMetaLabel;
  final bool isEquipped;
  final bool isTablet;

  const _InventoryItemSummary({
    required this.inventoryItem,
    required this.effectiveItem,
    required this.itemMetaLabel,
    required this.isEquipped,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          effectiveItem.name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 18 : 16,
          ),
        ),
        if (itemMetaLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            itemMetaLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: isTablet ? 13 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InventoryPill(
              text: 'x${inventoryItem.quantity}',
              color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
            ),
            if (effectiveItem.isEquippable)
              _InventoryPill(
                text: 'Equippable',
                color: Colors.blueAccent.withValues(alpha: 0.18),
              ),
            if ((inventoryItem.appliedInfusionName ?? '').trim().isNotEmpty)
              _InfusionPill(name: inventoryItem.appliedInfusionName!),
            if (isEquipped)
              _InventoryPill(
                text: 'Equipped',
                color: Colors.green.withValues(alpha: 0.20),
              ),
          ],
        ),
      ],
    );
  }
}

class _InventoryPill extends StatelessWidget {
  final String text;
  final Color color;

  const _InventoryPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _InfusionPill extends StatelessWidget {
  final String name;

  const _InfusionPill({
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.cyanAccent.withValues(alpha: 0.22),
            Colors.deepPurpleAccent.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_fix_high,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
