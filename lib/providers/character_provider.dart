import 'package:flutter/foundation.dart';

import '../models/character.dart';
import '../models/character_inventory_item.dart';
import '../models/dnd_background.dart';
import '../models/dnd_subrace.dart';
import '../services/character_storage.dart';
import '../models/character_feature.dart';
import '../models/character_resource.dart';
import '../services/character_feature_sync_service.dart';
import '../services/character_resource_factory.dart';
import '../models/equipment_compendium_item.dart';
import '../services/character_pact_service.dart';
import '../services/character_infusion_service.dart';
import '../models/character_option_definition.dart';
import '../services/feat_data_service.dart';
import '../services/feat_sync_service.dart';

class CharacterProvider extends ChangeNotifier {
  Character? _character;
  List<Character> _characters = [];
  int? _selectedIndex;

  Character? get character => _character;
  List<Character> get characters => _characters;
  int? get selectedIndex => _selectedIndex;

  List<Character> getCharactersByCampaignSafe(String? campaignId) {
    if (campaignId == null) return [];
    return _characters.where((c) => c.campaignId == campaignId).toList();
  }

  Character? getCharacterById(String id) {
    try {
      return _characters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadCharacters() async {
    _characters = await CharacterStorage.getCharacters();
    notifyListeners();
  }

  void create(Character c) {
    _character = c;
    _selectedIndex = null;
    notifyListeners();
  }

  void update(void Function(Character) updates) {
    if (_character == null) return;
    updates(_character!);
    notifyListeners();
  }

  void setBackground(DndBackground background) {
    if (_character == null) return;
    _character!.background = background;
    notifyListeners();
  }

  Future<void> saveCharacter() async {
    if (_character == null) return;

    final hasValidId = _character!.id.isNotEmpty;

    if (!hasValidId) {
      _character!.id = DateTime.now().millisecondsSinceEpoch.toString();
      await CharacterStorage.addCharacter(_character!);
    } else {
      final existing = await CharacterStorage.getCharacterById(_character!.id);

      if (existing == null) {
        await CharacterStorage.addCharacter(_character!);
      } else {
        await CharacterStorage.updateCharacterById(
          _character!.id,
          _character!,
        );
      }
    }

    await loadCharacters();
    _syncSelectedCharacterById(_character!.id);
  }

  void selectCharacterByObject(Character character) {
    final index = _characters.indexWhere((c) => c.id == character.id);
    if (index == -1) return;

    _selectedIndex = index;
    _character = _characters[index];
    notifyListeners();
  }

  void selectCharacter(int index) {
    if (index < 0 || index >= _characters.length) return;

    _selectedIndex = index;
    _character = _characters[index];
    notifyListeners();
  }

  Future<void> deleteCharacter(int index) async {
    if (index < 0 || index >= _characters.length) return;

    final character = _characters[index];
    await CharacterStorage.deleteCharacterById(character.id);

    if (_character?.id == character.id) {
      _character = null;
      _selectedIndex = null;
    }

    await loadCharacters();
    notifyListeners();
  }

  Future<void> deleteCharacterById(String id) async {
    await CharacterStorage.deleteCharacterById(id);

    if (_character?.id == id) {
      _character = null;
      _selectedIndex = null;
    }

    await loadCharacters();
    notifyListeners();
  }

  void resetCharacter() {
    _character = Character.empty();
    _selectedIndex = null;
    notifyListeners();
  }

  void clear() {
    _character = null;
    _selectedIndex = null;
    notifyListeners();
  }

  void setRace(String raceName, Map<String, int> bonuses) {
    if (_character == null) return;

    _character!.race = raceName;
    _character!.subrace = null;
    _character!.racialBonuses = Map<String, int>.from(bonuses);

    notifyListeners();
  }

  void setSubrace(DndSubrace subrace) {
    if (_character == null) return;

    _character!.subrace = subrace.name;

    for (final bonus in subrace.abilityBonuses) {
      final raw = bonus["ability_score"];
      if (raw is! Map) continue;

      final ability = raw["name"]?.toString();
      final value = bonus["bonus"] is int ? bonus["bonus"] as int : null;

      if (ability == null || value == null) continue;

      _character!.racialBonuses[ability] =
          (_character!.racialBonuses[ability] ?? 0) + value;
    }

    notifyListeners();
  }

  void setSubclass(String subclassName, {Map<String, int>? bonuses}) {
    if (_character == null) return;

    _character!.subclass = subclassName;

    if (bonuses != null) {
      bonuses.forEach((ability, value) {
        _character!.stats[ability] = (_character!.stats[ability] ?? 0) + value;
      });
    }

    notifyListeners();
  }

  Future<void> updateCharacterById(
    String characterId,
    void Function(Character) updates,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    updates(character);

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> applyInfusionToCharacterItem(
    String characterId,
    String inventoryItemId,
    CharacterOptionDefinition infusion,
    List<EquipmentCompendiumItem> equipmentItems,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final index =
        character.inventory.indexWhere((i) => i.id == inventoryItemId);
    if (index == -1) return;

    final item = character.inventory[index];

    EquipmentCompendiumItem? equipmentItem;
    try {
      equipmentItem = equipmentItems.firstWhere(
        (e) => e.id == item.compendiumEntryId,
      );
    } catch (_) {
      equipmentItem = null;
    }

    final canApplyToItem = canApplyInfusionToItem(
      infusion: infusion,
      item: item,
      equipmentItem: equipmentItem,
    );

    if (!canApplyToItem) return;

    final alreadyUsedElsewhere =
        characterAlreadyHasInfusion(character, infusion.id);
    final isSameInfusionOnThisItem = item.appliedInfusionId == infusion.id;

    if (alreadyUsedElsewhere && !isSameInfusionOnThisItem) {
      return;
    }

    final canUseActiveSlot = canCharacterApplyAnotherInfusion(
      character,
      targetItem: item,
    );

    if (!canUseActiveSlot) {
      return;
    }

    character.inventory[index] = applyInfusionToItem(
      item: item,
      infusion: infusion,
    );

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> removeInfusionFromCharacterItem(
    String characterId,
    String inventoryItemId,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final index =
        character.inventory.indexWhere((i) => i.id == inventoryItemId);
    if (index == -1) return;

    final item = character.inventory[index];

    character.inventory[index] = removeInfusionFromItem(item);

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> clearInvalidInfusionsForCharacter(
    String characterId,
    List<String> selectedInfusionIds,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    clearInvalidInfusions(character, selectedInfusionIds);

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> syncPactWeaponWithEquipment(
    String characterId,
    List<EquipmentCompendiumItem> equipmentItems,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    syncPactOfTheBlade(character, equipmentItems);

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> setPactWeaponBaseItem(
    String characterId,
    String baseItemId,
    List<EquipmentCompendiumItem> equipmentItems,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    character.pactWeaponBaseItemId = baseItemId;

    syncPactOfTheBlade(character, equipmentItems);

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> addInventoryItemToCharacter(
    String characterId,
    CharacterInventoryItem item,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final existingIndex = character.inventory.indexWhere(
      (inventoryItem) =>
          inventoryItem.compendiumEntryId != null &&
          inventoryItem.compendiumEntryId == item.compendiumEntryId,
    );

    if (existingIndex != -1) {
      final existing = character.inventory[existingIndex];
      character.inventory[existingIndex] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
      );
    } else {
      character.inventory = [...character.inventory, item];
    }

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> updateCharacterFeatures(
    String characterId,
    List<CharacterFeature> features,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    character.features = features;

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> updateCharacterResources(
    String characterId,
    List<CharacterResource> resources,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    character.resources = resources;

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> spendResource(
    String characterId,
    String resourceId,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final index = character.resources.indexWhere((r) => r.id == resourceId);
    if (index == -1) return;

    final resource = character.resources[index];
    if (resource.current <= 0) return;

    resource.current = resource.current - 1;

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> recoverResource(
    String characterId,
    String resourceId,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final index = character.resources.indexWhere((r) => r.id == resourceId);
    if (index == -1) return;

    final resource = character.resources[index];
    if (resource.current >= resource.max) return;

    resource.current = resource.current + 1;
    if (resource.current > resource.max) {
      resource.current = resource.max;
    }

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> setResourceCurrentValue(
    String characterId,
    String resourceId,
    int value,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final index = character.resources.indexWhere((r) => r.id == resourceId);
    if (index == -1) return;

    final resource = character.resources[index];
    final safeValue = value.clamp(0, resource.max);

    resource.current = safeValue;

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> setResourceMaxValue(
    String characterId,
    String resourceId,
    int value,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final index = character.resources.indexWhere((r) => r.id == resourceId);
    if (index == -1) return;

    final resource = character.resources[index];
    final safeMax = value < 0 ? 0 : value;

    resource.max = safeMax;
    if (resource.current > resource.max) {
      resource.current = resource.max;
    }

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> recoverResourcesByType(
    String characterId,
    String rechargeType,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    for (final resource in character.resources) {
      final isShortRest = resource.rechargeType == 'shortRest';
      final isLongRest = resource.rechargeType == 'longRest';

      final shouldRecover = rechargeType == 'longRest'
          ? (isLongRest || isShortRest)
          : isShortRest;

      if (shouldRecover) {
        resource.current = resource.max;
      }
    }

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> addManualResourceToCharacter(
    String characterId,
    CharacterResource resource,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final exists = character.resources.any((r) => r.id == resource.id);
    if (exists) return;

    character.resources = [...character.resources, resource];

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> removeResourceFromCharacter(
    String characterId,
    String resourceId,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    character.resources =
        character.resources.where((r) => r.id != resourceId).toList();

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> syncFeats(String characterId) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final featIds = List<String>.from(character.selectedFeatIds);

    if (featIds.isEmpty) {
      FeatSyncService.applyFeatsToCharacter(
        character: character,
        feats: const [],
      );

      await CharacterStorage.updateCharacterById(character.id, character);
      await loadCharacters();
      _syncSelectedCharacterById(characterId);
      return;
    }

    final feats = await FeatDataService.getFeatsByIds(featIds);

    FeatSyncService.applyFeatsToCharacter(
      character: character,
      feats: feats,
    );

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> syncFeaturesAndResources(String characterId) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final syncedFeatures =
        await CharacterFeatureSyncService.buildFeaturesForCharacter(character);

    final generatedResources =
        CharacterResourceFactory.buildResources(character);

    final existingById = {
      for (final resource in character.resources) resource.id: resource,
    };

    final mergedResources = generatedResources.map((generated) {
      final existing = existingById[generated.id];
      if (existing == null) return generated;

      final safeCurrent = existing.current.clamp(0, generated.max);

      return CharacterResource(
        id: generated.id,
        name: generated.name,
        current: safeCurrent,
        max: generated.max,
        rechargeType: generated.rechargeType,
        notes: existing.notes ?? generated.notes,
      );
    }).toList();

    final selectedFeats = await FeatDataService.getFeatsByIds(
      character.selectedFeatIds,
    );
    FeatSyncService.applyFeatsToCharacter(
      character: character,
      feats: selectedFeats,
    );

    character.features = syncedFeatures;
    character.resources = mergedResources;

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> equipItemToCharacter(
    String characterId,
    String inventoryItemId,
    EquipSlot slot,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final itemExists =
        character.inventory.any((item) => item.id == inventoryItemId);
    if (!itemExists) return;

    _clearEquippedReferenceFromAllSlots(character, inventoryItemId);
    _setEquippedSlot(character, slot, inventoryItemId);

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  Future<void> unequipItemFromCharacter(
    String characterId,
    EquipSlot slot,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    _setEquippedSlot(character, slot, null);

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  String? getEquippedItemIdForSlot(
    String characterId,
    EquipSlot slot,
  ) {
    final character = getCharacterById(characterId);
    if (character == null) return null;

    return _getEquippedSlotValue(character, slot);
  }

  Future<void> removeInventoryItemFromCharacter(
    String characterId,
    String inventoryItemId,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    _clearEquippedReferenceFromAllSlots(character, inventoryItemId);

    character.inventory = character.inventory
        .where((item) => item.id != inventoryItemId)
        .toList();

    await CharacterStorage.updateCharacterById(character.id, character);
    await loadCharacters();
    _syncSelectedCharacterById(characterId);
  }

  void _setEquippedSlot(
    Character character,
    EquipSlot slot,
    String? inventoryItemId,
  ) {
    switch (slot) {
      case EquipSlot.weaponMainHand:
        character.equippedMainHandItemId = inventoryItemId;
        break;
      case EquipSlot.weaponOffHand:
        character.equippedOffHandItemId = inventoryItemId;
        break;
      case EquipSlot.armor:
        character.equippedArmorItemId = inventoryItemId;
        break;
      case EquipSlot.shield:
        character.equippedShieldItemId = inventoryItemId;
        break;
      case EquipSlot.accessory:
        if (character.equippedAccessory1ItemId == null ||
            character.equippedAccessory1ItemId == inventoryItemId) {
          character.equippedAccessory1ItemId = inventoryItemId;
        } else if (character.equippedAccessory2ItemId == null ||
            character.equippedAccessory2ItemId == inventoryItemId) {
          character.equippedAccessory2ItemId = inventoryItemId;
        } else {
          character.equippedAccessory1ItemId = inventoryItemId;
        }
        break;
    }
  }

  String? _getEquippedSlotValue(
    Character character,
    EquipSlot slot,
  ) {
    switch (slot) {
      case EquipSlot.weaponMainHand:
        return character.equippedMainHandItemId;
      case EquipSlot.weaponOffHand:
        return character.equippedOffHandItemId;
      case EquipSlot.armor:
        return character.equippedArmorItemId;
      case EquipSlot.shield:
        return character.equippedShieldItemId;
      case EquipSlot.accessory:
        return character.equippedAccessory1ItemId;
    }
  }

  void _clearEquippedReferenceFromAllSlots(
    Character character,
    String inventoryItemId,
  ) {
    if (character.equippedMainHandItemId == inventoryItemId) {
      character.equippedMainHandItemId = null;
    }
    if (character.equippedOffHandItemId == inventoryItemId) {
      character.equippedOffHandItemId = null;
    }
    if (character.equippedArmorItemId == inventoryItemId) {
      character.equippedArmorItemId = null;
    }
    if (character.equippedShieldItemId == inventoryItemId) {
      character.equippedShieldItemId = null;
    }
    if (character.equippedAccessory1ItemId == inventoryItemId) {
      character.equippedAccessory1ItemId = null;
    }
    if (character.equippedAccessory2ItemId == inventoryItemId) {
      character.equippedAccessory2ItemId = null;
    }
  }

  void _syncSelectedCharacterById(String id) {
    final index = _characters.indexWhere((c) => c.id == id);
    if (index == -1) return;

    _selectedIndex = index;
    _character = _characters[index];
    notifyListeners();
  }
}
