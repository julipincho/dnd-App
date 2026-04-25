import '../models/character.dart';
import '../models/character_inventory_item.dart';
import '../models/character_option_definition.dart';
import '../models/equipment_compendium_item.dart';

bool itemHasInfusion(CharacterInventoryItem item) {
  return item.appliedInfusionId != null &&
      item.appliedInfusionId!.trim().isNotEmpty;
}

CharacterInventoryItem applyInfusionToItem({
  required CharacterInventoryItem item,
  required CharacterOptionDefinition infusion,
}) {
  return item.copyWith(
    appliedInfusionId: infusion.id,
    appliedInfusionName: infusion.name,
  );
}

CharacterInventoryItem removeInfusionFromItem(CharacterInventoryItem item) {
  return item.copyWith(
    appliedInfusionId: '',
    appliedInfusionName: '',
  );
}

bool canApplyInfusionToItem({
  required CharacterOptionDefinition infusion,
  required CharacterInventoryItem item,
  required EquipmentCompendiumItem? equipmentItem,
}) {
  final infusionId = infusion.id.trim().toLowerCase();

  final isWeapon =
      item.itemType == EquipItemType.weapon || equipmentItem?.isWeapon == true;
  final isArmor =
      item.itemType == EquipItemType.armor || equipmentItem?.isArmor == true;
  final isShield =
      item.itemType == EquipItemType.shield || equipmentItem?.isShield == true;
  final isAccessory = item.itemType == EquipItemType.accessory ||
      equipmentItem?.isAccessory == true;

  final weaponCategory = equipmentItem?.weaponCategory?.trim().toLowerCase();
  final isSimpleOrMartialWeapon =
      weaponCategory == 'simple' || weaponCategory == 'martial';

  final properties =
      equipmentItem?.properties.map((e) => e.toLowerCase()).toList() ?? [];
  final hasThrownProperty = properties.contains('thrown');
  final hasLoadingProperty = properties.contains('loading');
  final hasAmmunitionProperty = properties.contains('ammunition');

  if (infusionId.contains('enhanced_weapon')) {
    return isWeapon && isSimpleOrMartialWeapon;
  }

  if (infusionId.contains('radiant_weapon')) {
    return isWeapon && isSimpleOrMartialWeapon;
  }

  if (infusionId.contains('returning_weapon')) {
    return isWeapon && isSimpleOrMartialWeapon && hasThrownProperty;
  }

  if (infusionId.contains('repeating_shot')) {
    return isWeapon &&
        isSimpleOrMartialWeapon &&
        (hasAmmunitionProperty || hasLoadingProperty || item.isRanged);
  }

  if (infusionId.contains('enhanced_defense')) {
    return isArmor || isShield;
  }

  if (infusionId.contains('repulsion_shield')) {
    return isShield;
  }

  if (infusionId.contains('armor_of_magical_strength')) {
    return isArmor;
  }

  if (infusionId.contains('mind_sharpener')) {
    return isArmor;
  }

  if (infusionId.contains('resistant_armor')) {
    return isArmor;
  }

  if (infusionId.contains('arcane_propulsion_armor')) {
    return isArmor;
  }

  if (infusionId.contains('enhanced_arcane_focus')) {
    final itemName = (equipmentItem?.name ?? item.name).trim().toLowerCase();
    final subtype = equipmentItem?.subtype.trim().toLowerCase() ?? '';
    final displayCategory =
        equipmentItem?.displayCategory.trim().toLowerCase() ?? '';

    return itemName.contains('rod') ||
        itemName.contains('staff') ||
        itemName.contains('wand') ||
        subtype.contains('rod') ||
        subtype.contains('staff') ||
        subtype.contains('wand') ||
        displayCategory.contains('rod') ||
        displayCategory.contains('staff') ||
        displayCategory.contains('wand');
  }

  if (infusionId.contains('spell_refueling_ring')) {
    if (equipmentItem == null) return false;

    final itemName = equipmentItem.name.trim().toLowerCase();
    return isAccessory && itemName.contains('ring');
  }

  // replicate magic item, homunculus, boots, helmets, etc.
  // se pueden resolver después con lógica más específica.
  return false;
}

bool characterAlreadyHasInfusion(
  Character character,
  String infusionId,
) {
  final normalized = infusionId.trim().toLowerCase();

  return character.inventory.any((item) {
    final applied = item.appliedInfusionId?.trim().toLowerCase();
    return applied != null && applied == normalized;
  });
}

CharacterInventoryItem? findInfusedItemByInfusionId(
  Character character,
  String infusionId,
) {
  final normalized = infusionId.trim().toLowerCase();

  try {
    return character.inventory.firstWhere((item) {
      final applied = item.appliedInfusionId?.trim().toLowerCase();
      return applied != null && applied == normalized;
    });
  } catch (_) {
    return null;
  }
}

void clearInvalidInfusions(
  Character character,
  List<String> selectedInfusionIds,
) {
  final normalizedIds =
      selectedInfusionIds.map((id) => id.trim().toLowerCase()).toSet();

  character.inventory = character.inventory.map((item) {
    final appliedId = item.appliedInfusionId?.trim().toLowerCase();

    if (appliedId == null || appliedId.isEmpty) {
      return item;
    }

    if (!normalizedIds.contains(appliedId)) {
      return removeInfusionFromItem(item);
    }

    return item;
  }).toList();
}

int getArtificerActiveInfusedItemsLimit(Character character) {
  final level = character.levelForClass('artificer');

  if (level < 2) return 0;
  if (level < 6) return 2;
  if (level < 10) return 3;
  if (level < 14) return 4;
  if (level < 18) return 5;
  return 6;
}

int getActiveInfusedItemsCount(Character character) {
  return character.inventory.where((item) {
    final appliedId = item.appliedInfusionId?.trim();
    return appliedId != null && appliedId.isNotEmpty;
  }).length;
}

bool canCharacterApplyAnotherInfusion(
  Character character, {
  required CharacterInventoryItem targetItem,
}) {
  final limit = getArtificerActiveInfusedItemsLimit(character);
  if (limit <= 0) return false;

  final targetAlreadyInfused =
      (targetItem.appliedInfusionId ?? '').trim().isNotEmpty;

  if (targetAlreadyInfused) {
    return true;
  }

  final activeCount = getActiveInfusedItemsCount(character);
  return activeCount < limit;
}
