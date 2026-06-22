import 'package:flutter/material.dart';

import '../../../../../models/character.dart';
import '../../../../../models/character_inventory_item.dart';
import '../../../../../models/equipment_compendium_item.dart';
import '../../../../../screens/compendium_entry_detail_screen.dart';
import '../../../../../theme.dart';
import '../../../models/resolved_inventory_item.dart';

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
    final tokens = context.stitch;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;
    final maxWidth = isLargeTablet ? 1280.0 : 960.0;
    final pagePadding = isLargeTablet ? 26.0 : (isTablet ? 20.0 : 14.0);
    final equippedCount = character.inventory.where(isItemEquipped).length;
    final equippableCount =
        character.inventory.where((item) => item.isEquippable).length;
    final infusedCount = character.inventory
        .where((item) => (item.appliedInfusionId ?? '').trim().isNotEmpty)
        .length;
    final totalQuantity = character.inventory.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tokens.pageTop,
            tokens.pageMid,
            tokens.pageBottom,
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: EdgeInsets.all(pagePadding),
            children: [
              _InventoryCommandHeader(
                totalStacks: character.inventory.length,
                totalQuantity: totalQuantity,
                equippedCount: equippedCount,
                equippableCount: equippableCount,
                infusedCount: infusedCount,
                canManageInventory: canManageInventory,
                onAddItem: onAddItem,
              ),
              const SizedBox(height: 14),
              buildEquipmentSection(
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              const SizedBox(height: 16),
              _InventorySectionHeader(
                title: 'Carried Gear',
                subtitle: character.inventory.isEmpty
                    ? 'Nothing carried yet'
                    : '${character.inventory.length} stacks, $totalQuantity total items',
                icon: Icons.inventory_2_outlined,
                trailing: canManageInventory
                    ? TextButton.icon(
                        onPressed: onAddItem,
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('Add item'),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              if (character.inventory.isEmpty)
                _InventoryEmptyState(
                  isDm: isDm,
                  canManageInventory: canManageInventory,
                  onAddItem: onAddItem,
                )
              else
                _InventoryItemGrid(
                  inventory: character.inventory,
                  isTablet: isTablet,
                  isLargeTablet: isLargeTablet,
                  resolveInventoryItem: resolveInventoryItem,
                  isItemEquipped: isItemEquipped,
                  canManageInventory: canManageInventory,
                  isOwnedByCurrentUser: isOwnedByCurrentUser,
                  buildEquipmentMetaLabel: buildEquipmentMetaLabel,
                  buildResolvedImage: buildResolvedImage,
                  onRemoveItem: onRemoveItem,
                  onEquipItem: onEquipItem,
                  onUnequipItem: onUnequipItem,
                  hasInfusionOptions: hasInfusionOptions,
                  onShowInfusionPicker: onShowInfusionPicker,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryCommandHeader extends StatelessWidget {
  final int totalStacks;
  final int totalQuantity;
  final int equippedCount;
  final int equippableCount;
  final int infusedCount;
  final bool canManageInventory;
  final VoidCallback onAddItem;

  const _InventoryCommandHeader({
    required this.totalStacks,
    required this.totalQuantity,
    required this.equippedCount,
    required this.equippableCount,
    required this.infusedCount,
    required this.canManageInventory,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tokens.accentRead.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(
                color: tokens.accentRead.withValues(alpha: 0.24),
              ),
            ),
            child: Icon(
              Icons.backpack_outlined,
              color: tokens.accentReadSoft,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INVENTORY',
                  style: TextStyle(
                    color: tokens.accentReadSoft.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InventoryStatPill(
                      label: 'Stacks',
                      value: '$totalStacks',
                      color: tokens.accentRead,
                    ),
                    _InventoryStatPill(
                      label: 'Items',
                      value: '$totalQuantity',
                      color: tokens.accentInfo,
                    ),
                    _InventoryStatPill(
                      label: 'Equipped',
                      value: '$equippedCount / $equippableCount',
                      color: tokens.accentSuccess,
                    ),
                    if (infusedCount > 0)
                      _InventoryStatPill(
                        label: 'Infused',
                        value: '$infusedCount',
                        color: tokens.accentMagic,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canManageInventory) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accentRead,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InventorySectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const _InventorySectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tokens.accentRead.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(
              color: tokens.accentRead.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(icon, color: tokens.accentReadSoft, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: tokens.accentReadSoft.withValues(alpha: 0.88),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _InventoryItemGrid extends StatelessWidget {
  final List<CharacterInventoryItem> inventory;
  final bool isTablet;
  final bool isLargeTablet;
  final ResolvedInventoryItem Function(CharacterInventoryItem item)
      resolveInventoryItem;
  final bool Function(CharacterInventoryItem item) isItemEquipped;
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
  final Future<void> Function(CharacterInventoryItem item) onRemoveItem;
  final Future<void> Function(CharacterInventoryItem item) onEquipItem;
  final Future<void> Function(CharacterInventoryItem item) onUnequipItem;
  final bool Function(CharacterInventoryItem item) hasInfusionOptions;
  final Future<void> Function(CharacterInventoryItem item) onShowInfusionPicker;

  const _InventoryItemGrid({
    required this.inventory,
    required this.isTablet,
    required this.isLargeTablet,
    required this.resolveInventoryItem,
    required this.isItemEquipped,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isLargeTablet ? 2 : 1;
        const spacing = 12.0;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: inventory.map((inventoryItem) {
            final resolvedItem = resolveInventoryItem(inventoryItem);

            return SizedBox(
              width: itemWidth,
              child: _InventoryItemCard(
                inventoryItem: inventoryItem,
                resolvedItem: resolvedItem,
                isEquipped: isItemEquipped(inventoryItem),
                isTablet: isTablet,
                canManageInventory: canManageInventory,
                isOwnedByCurrentUser: isOwnedByCurrentUser,
                buildEquipmentMetaLabel: buildEquipmentMetaLabel,
                buildResolvedImage: buildResolvedImage,
                onRemoveItem: () => onRemoveItem(inventoryItem),
                onEquipItem: () => onEquipItem(resolvedItem.effectiveItem),
                onUnequipItem: () => onUnequipItem(resolvedItem.effectiveItem),
                hasInfusionOptions: hasInfusionOptions(inventoryItem),
                onShowInfusionPicker: () => onShowInfusionPicker(
                  inventoryItem,
                ),
              ),
            );
          }).toList(),
        );
      },
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
    final tokens = context.stitch;
    final effectiveItem = resolvedItem.effectiveItem;
    final linkedEntry = resolvedItem.campaignEntry;
    final itemMetaLabel = buildEquipmentMetaLabel(
      effectiveItem,
      resolvedItem.equipmentItem,
    );
    final displayImagePath = resolvedItem.resolvedImagePath;
    final description = (resolvedItem.resolvedDescription ?? '').trim();
    final notes = (inventoryItem.notes ?? '').trim();
    final accent = isEquipped
        ? tokens.accentSuccess
        : _itemAccent(effectiveItem, resolvedItem.equipmentItem, tokens);

    return Container(
      padding: EdgeInsets.all(isTablet ? 14 : 12),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InventoryItemImage(
                imagePath: displayImagePath,
                accent: accent,
                isTablet: isTablet,
                buildResolvedImage: buildResolvedImage,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InventoryItemSummary(
                  inventoryItem: inventoryItem,
                  effectiveItem: effectiveItem,
                  itemMetaLabel: itemMetaLabel,
                  isEquipped: isEquipped,
                  isTablet: isTablet,
                  accent: accent,
                ),
              ),
              if (canManageInventory)
                IconButton(
                  onPressed: onRemoveItem,
                  icon: const Icon(Icons.delete_outline),
                  color: tokens.textSecondary,
                  tooltip: 'Remove item',
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: isTablet ? 4 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: isTablet ? 13 : 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: tokens.accentInfo.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                notes,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InventoryActionChip(
                label: resolvedItem.sourceLabel,
                icon: Icons.source_outlined,
                color: tokens.accentRead,
                onPressed: null,
              ),
              if (linkedEntry != null)
                _InventoryActionChip(
                  label: 'Compendium',
                  icon: Icons.menu_book_outlined,
                  color: tokens.accentInfo,
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
                _InventoryActionChip(
                  label: 'Equip',
                  icon: Icons.check_circle_outline,
                  color: tokens.accentSuccess,
                  onPressed: isOwnedByCurrentUser ? onEquipItem : null,
                ),
              if (effectiveItem.isEquippable && isEquipped)
                _InventoryActionChip(
                  label: 'Unequip',
                  icon: Icons.close,
                  color: tokens.accentWarning,
                  onPressed: isOwnedByCurrentUser ? onUnequipItem : null,
                ),
              if (hasInfusionOptions)
                _InventoryActionChip(
                  label: (inventoryItem.appliedInfusionId ?? '').trim().isEmpty
                      ? 'Infuse'
                      : 'Change Infusion',
                  icon: Icons.auto_fix_high,
                  color: tokens.accentMagic,
                  onPressed: isOwnedByCurrentUser ? onShowInfusionPicker : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _itemAccent(
    CharacterInventoryItem item,
    EquipmentCompendiumItem? equipmentItem,
    StitchThemeTokens tokens,
  ) {
    if (equipmentItem?.isMagic == true ||
        (inventoryItem.appliedInfusionId ?? '').trim().isNotEmpty) {
      return tokens.accentMagic;
    }
    if (item.itemType == EquipItemType.weapon ||
        equipmentItem?.isWeapon == true) {
      return tokens.accentAction;
    }
    if (item.itemType == EquipItemType.armor ||
        item.itemType == EquipItemType.shield ||
        equipmentItem?.isArmor == true ||
        equipmentItem?.isShield == true) {
      return tokens.accentRead;
    }
    return tokens.accentInfo;
  }
}

class _InventoryItemImage extends StatelessWidget {
  final String? imagePath;
  final Color accent;
  final bool isTablet;
  final Widget Function(
    String path, {
    required double width,
    required double height,
    BoxFit fit,
  }) buildResolvedImage;

  const _InventoryItemImage({
    required this.imagePath,
    required this.accent,
    required this.isTablet,
    required this.buildResolvedImage,
  });

  @override
  Widget build(BuildContext context) {
    final size = isTablet ? 62.0 : 52.0;

    if (imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: buildResolvedImage(
          imagePath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.24),
            StitchCodexPalette.surfaceMuted,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: Colors.white,
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
  final Color accent;

  const _InventoryItemSummary({
    required this.inventoryItem,
    required this.effectiveItem,
    required this.itemMetaLabel,
    required this.isEquipped,
    required this.isTablet,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          effectiveItem.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: isTablet ? 16 : 15,
            height: 1.08,
          ),
        ),
        if (itemMetaLabel.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            itemMetaLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: isTablet ? 12 : 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _InventoryPill(
              text: 'x${inventoryItem.quantity}',
              color: tokens.accentInfo,
            ),
            if (effectiveItem.isEquippable)
              _InventoryPill(
                text: 'Equippable',
                color: accent,
              ),
            if ((inventoryItem.appliedInfusionName ?? '').trim().isNotEmpty)
              _InfusionPill(name: inventoryItem.appliedInfusionName!),
            if (isEquipped)
              _InventoryPill(
                text: 'Equipped',
                color: tokens.accentSuccess,
              ),
          ],
        ),
      ],
    );
  }
}

class _InventoryStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InventoryStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InventoryActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _InventoryActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return ActionChip(
      avatar: Icon(
        icon,
        size: 15,
        color: enabled ? Colors.white : Colors.white54,
      ),
      label: Text(label),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        color: enabled ? Colors.white : Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: color.withValues(alpha: enabled ? 0.14 : 0.07),
      disabledColor: color.withValues(alpha: 0.07),
      side: BorderSide(color: color.withValues(alpha: enabled ? 0.28 : 0.14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.accentInfo.withValues(alpha: 0.18),
            tokens.accentMagic.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tokens.accentInfo.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_fix_high,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryEmptyState extends StatelessWidget {
  final bool isDm;
  final bool canManageInventory;
  final VoidCallback onAddItem;

  const _InventoryEmptyState({
    required this.isDm,
    required this.canManageInventory,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: tokens.accentReadSoft,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            isDm ? 'No items granted yet.' : 'No items yet.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isDm
                ? 'Grant one from the compendium to start building this kit.'
                : 'Add gear to turn this sheet into a real loadout.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (canManageInventory) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ],
        ],
      ),
    );
  }
}
