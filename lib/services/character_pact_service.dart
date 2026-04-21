import '../logic/character_option_effects.dart';
import '../models/character.dart';
import '../models/character_inventory_item.dart';
import '../models/equipment_compendium_item.dart';

bool _isBasePactWeaponCandidate(EquipmentCompendiumItem item) {
  if (!item.isWeapon) return false;
  if (!item.isEquippable) return false;

  // Base del pacto: armas cuerpo a cuerpo
  if (item.isRanged) return false;

  return true;
}

bool _isImprovedOnlyPactWeaponCandidate(EquipmentCompendiumItem item) {
  if (!item.isWeapon) return false;

  final normalizedName = item.name.trim().toLowerCase();

  return normalizedName == 'shortbow' ||
      normalizedName == 'longbow' ||
      normalizedName == 'light crossbow' ||
      normalizedName == 'heavy crossbow';
}

List<EquipmentCompendiumItem> getAvailablePactWeaponOptions(
  Character character,
  List<EquipmentCompendiumItem> equipmentItems,
) {
  final hasEnhancedPactWeapon =
      CharacterOptionEffects.getBestPactWeaponEnhancementBonus(character) > 0;

  final result = <EquipmentCompendiumItem>[];

  for (final item in equipmentItems) {
    if (_isBasePactWeaponCandidate(item)) {
      result.add(item);
      continue;
    }

    if (hasEnhancedPactWeapon && _isImprovedOnlyPactWeaponCandidate(item)) {
      result.add(item);
    }
  }

  result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
}

CharacterInventoryItem buildPactWeaponFromCompendiumItem(
  Character character,
  EquipmentCompendiumItem baseItem,
) {
  return CharacterInventoryItem(
    id: 'pact_weapon_${character.id}',
    name: baseItem.name,
    compendiumEntryId: baseItem.id,
    sourceType: InventoryItemSourceType.equipmentCompendium,
    quantity: 1,
    createdAt: DateTime.now(),
    isEquippable: true,
    itemType: EquipItemType.weapon,
    allowedSlots: const [EquipSlot.weaponMainHand],
    isEquipped: false,
    damageDice: baseItem.damageDiceOneHanded,
    damageType: baseItem.damageType,
    isFinesse: baseItem.isFinesse,
    isRanged: baseItem.isRanged,
    isTwoHanded: baseItem.isTwoHanded,
    isPactWeapon: true,
  );
}

CharacterInventoryItem _buildFallbackPactWeapon(Character character) {
  return CharacterInventoryItem(
    id: 'pact_weapon_${character.id}',
    name: 'Pact Weapon',
    quantity: 1,
    createdAt: DateTime.now(),
    isEquippable: true,
    itemType: EquipItemType.weapon,
    allowedSlots: const [EquipSlot.weaponMainHand],
    isEquipped: false,
    damageDice: '1d8',
    damageType: 'slashing',
    isFinesse: false,
    isRanged: false,
    isTwoHanded: false,
    isPactWeapon: true,
  );
}

void syncPactOfTheBlade(
  Character character,
  List<EquipmentCompendiumItem> equipmentItems,
) {
  final pactWeapons = character.inventory.where((i) => i.isPactWeapon).toList();

  // 🔴 Si NO tiene pacto → limpiar todo
  if (!character.hasPactOfTheBlade) {
    for (final item in pactWeapons) {
      if (character.equippedMainHandItemId == item.id) {
        character.equippedMainHandItemId = null;
      }
      if (character.equippedOffHandItemId == item.id) {
        character.equippedOffHandItemId = null;
      }
    }

    character.inventory.removeWhere((i) => i.isPactWeapon);
    character.pactWeaponItemId = null;
    character.pactWeaponBaseItemId = null;
    return;
  }

  final availableOptions = getAvailablePactWeaponOptions(
    character,
    equipmentItems,
  );

  EquipmentCompendiumItem? selectedBaseItem;

  if (character.pactWeaponBaseItemId != null &&
      character.pactWeaponBaseItemId!.trim().isNotEmpty) {
    try {
      selectedBaseItem = availableOptions.firstWhere(
        (item) => item.id == character.pactWeaponBaseItemId,
      );
    } catch (_) {
      selectedBaseItem = null;
    }
  }

  // Si todavía no hay selección pero sí hay opciones válidas,
  // tomamos la primera para dejar el sistema funcional.
  selectedBaseItem ??=
      availableOptions.isNotEmpty ? availableOptions.first : null;

  final existingPactWeapon = pactWeapons.isNotEmpty ? pactWeapons.first : null;

  CharacterInventoryItem desiredWeapon;
  if (selectedBaseItem != null) {
    desiredWeapon = buildPactWeaponFromCompendiumItem(
      character,
      selectedBaseItem,
    );
  } else {
    desiredWeapon = _buildFallbackPactWeapon(character);
  }

  final needsRebuild = existingPactWeapon == null ||
      existingPactWeapon.compendiumEntryId != desiredWeapon.compendiumEntryId ||
      existingPactWeapon.name != desiredWeapon.name ||
      existingPactWeapon.damageDice != desiredWeapon.damageDice ||
      existingPactWeapon.damageType != desiredWeapon.damageType ||
      existingPactWeapon.isRanged != desiredWeapon.isRanged ||
      existingPactWeapon.isFinesse != desiredWeapon.isFinesse ||
      existingPactWeapon.isTwoHanded != desiredWeapon.isTwoHanded;

  if (!needsRebuild) {
    if (pactWeapons.length > 1) {
      final keepId = existingPactWeapon.id;
      character.inventory.removeWhere(
        (i) => i.isPactWeapon && i.id != keepId,
      );
    }

    character.pactWeaponItemId = existingPactWeapon.id;
    character.pactWeaponBaseItemId = selectedBaseItem?.id;
    return;
  }

  character.inventory.removeWhere((i) => i.isPactWeapon);

  character.inventory.add(desiredWeapon);
  character.pactWeaponItemId = desiredWeapon.id;
  character.pactWeaponBaseItemId = selectedBaseItem?.id;
  character.equippedMainHandItemId = desiredWeapon.id;

  if (character.equippedOffHandItemId == desiredWeapon.id) {
    character.equippedOffHandItemId = null;
  }
}
