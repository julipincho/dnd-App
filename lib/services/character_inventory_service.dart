import '../features/characters/models/resolved_inventory_item.dart';
import '../models/character_inventory_item.dart';
import '../models/compendium_entry.dart';
import '../models/equipment_compendium_item.dart';
import '../utils/image_path_utils.dart';

class CharacterInventoryService {
  static String sourceLabel(InventoryItemSourceType sourceType) {
    switch (sourceType) {
      case InventoryItemSourceType.equipmentCompendium:
        return 'Armory';
      case InventoryItemSourceType.campaignCompendium:
        return 'Campaign Compendium';
      case InventoryItemSourceType.manual:
        return 'Manual';
    }
  }

  static EquipmentCompendiumItem? resolveEquipmentCompendiumItem({
    required CharacterInventoryItem item,
    required List<EquipmentCompendiumItem> equipmentItems,
  }) {
    if (item.sourceType != InventoryItemSourceType.equipmentCompendium) {
      return null;
    }

    final compendiumEntryId = item.compendiumEntryId;
    if (compendiumEntryId == null || compendiumEntryId.trim().isEmpty) {
      return null;
    }

    for (final equipmentItem in equipmentItems) {
      if (equipmentItem.id == compendiumEntryId) return equipmentItem;
    }

    return null;
  }

  static CompendiumEntry? resolveCampaignCompendiumEntry({
    required CharacterInventoryItem item,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    if (item.sourceType != InventoryItemSourceType.campaignCompendium) {
      return null;
    }

    final compendiumEntryId = item.compendiumEntryId;
    if (compendiumEntryId == null || compendiumEntryId.trim().isEmpty) {
      return null;
    }

    for (final entry in compendiumEntries) {
      if (entry.id == compendiumEntryId) return entry;
    }

    return null;
  }

  static EquipItemType mapCompendiumTypeToInventoryType(
    EquipmentCompendiumItem item,
  ) {
    if (item.isWeapon) return EquipItemType.weapon;
    if (item.isArmor) return EquipItemType.armor;
    if (item.isShield) return EquipItemType.shield;
    if (item.isAccessory) return EquipItemType.accessory;
    return EquipItemType.generic;
  }

  static bool isHandHeldFocus(EquipmentCompendiumItem item) {
    final name = item.name.trim().toLowerCase();
    final subtype = item.subtype.trim().toLowerCase();
    final displayCategory = item.displayCategory.trim().toLowerCase();

    return name.contains('rod') ||
        name.contains('wand') ||
        name.contains('staff') ||
        subtype.contains('rod') ||
        subtype.contains('wand') ||
        subtype.contains('staff') ||
        displayCategory.contains('rod') ||
        displayCategory.contains('wand') ||
        displayCategory.contains('staff');
  }

  static List<EquipSlot> mapAllowedSlotsFromCompendium(
    EquipmentCompendiumItem item,
  ) {
    final slots = item.allowedSlots.map((slotName) {
      switch (slotName) {
        case 'weaponMainHand':
          return EquipSlot.weaponMainHand;
        case 'weaponOffHand':
          return EquipSlot.weaponOffHand;
        case 'armor':
          return EquipSlot.armor;
        case 'shield':
          return EquipSlot.shield;
        case 'accessory':
        default:
          return EquipSlot.accessory;
      }
    }).toList();

    if (isHandHeldFocus(item)) {
      if (!slots.contains(EquipSlot.weaponMainHand)) {
        slots.add(EquipSlot.weaponMainHand);
      }
      if (!slots.contains(EquipSlot.weaponOffHand)) {
        slots.add(EquipSlot.weaponOffHand);
      }
    }

    return slots;
  }

  static CharacterInventoryItem withCompendiumData({
    required CharacterInventoryItem inventoryItem,
    required EquipmentCompendiumItem? compendiumItem,
  }) {
    if (compendiumItem == null) return inventoryItem;

    return inventoryItem.copyWith(
      isEquippable: compendiumItem.isEquippable,
      itemType: mapCompendiumTypeToInventoryType(compendiumItem),
      allowedSlots: mapAllowedSlotsFromCompendium(compendiumItem),
      damageDice: compendiumItem.damageDiceOneHanded,
      damageType: compendiumItem.damageType,
      isFinesse: compendiumItem.isFinesse,
      isRanged: compendiumItem.isRanged,
      isTwoHanded: compendiumItem.isTwoHanded,
      armorClassBonus: compendiumItem.armorClassBonus,
      baseArmorClass: compendiumItem.baseArmorClass,
      allowsDexBonus: compendiumItem.allowsDexBonus,
      maxDexBonus: compendiumItem.maxDexBonus,
    );
  }

  static ResolvedInventoryItem resolveInventoryItem({
    required CharacterInventoryItem inventoryItem,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final equipmentItem = resolveEquipmentCompendiumItem(
      item: inventoryItem,
      equipmentItems: equipmentItems,
    );

    final campaignEntry = resolveCampaignCompendiumEntry(
      item: inventoryItem,
      compendiumEntries: compendiumEntries,
    );

    final effectiveItem = withCompendiumData(
      inventoryItem: inventoryItem,
      compendiumItem: equipmentItem,
    );

    final resolvedDescription =
        equipmentItem?.description?.trim().isNotEmpty == true
            ? equipmentItem!.description!.trim()
            : campaignEntry?.description.trim().isNotEmpty == true
                ? campaignEntry!.description.trim()
                : inventoryItem.description?.trim().isNotEmpty == true
                    ? inventoryItem.description!.trim()
                    : null;

    final resolvedImagePath = hasDisplayableImagePath(equipmentItem?.imagePath)
        ? equipmentItem!.imagePath
        : hasDisplayableImagePath(campaignEntry?.imagePath)
            ? campaignEntry!.imagePath
            : hasDisplayableImagePath(inventoryItem.imagePath)
                ? inventoryItem.imagePath
                : null;

    return ResolvedInventoryItem(
      originalItem: inventoryItem,
      effectiveItem: effectiveItem,
      equipmentItem: equipmentItem,
      campaignEntry: campaignEntry,
      sourceLabel: sourceLabel(inventoryItem.sourceType),
      resolvedDescription: resolvedDescription,
      resolvedImagePath: resolvedImagePath,
    );
  }
}
