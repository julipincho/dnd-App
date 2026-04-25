import 'package:flutter/foundation.dart';

import '../models/character.dart';
import '../models/character_feature.dart';
import '../models/character_inventory_item.dart';
import '../models/character_option_definition.dart';
import '../models/character_resource.dart';
import '../models/dnd_background.dart';
import '../models/dnd_subrace.dart';
import '../models/equipment_compendium_item.dart';
import '../services/character_cloud_repository.dart';
import '../services/character_feature_sync_service.dart';
import '../services/character_infusion_service.dart';
import '../services/character_pact_service.dart';
import '../services/character_resource_factory.dart';
import '../services/feat_data_service.dart';
import '../services/feat_sync_service.dart';
import '../services/race_sync_service.dart';

enum CharacterCreationSource {
  home,
  campaignDetail,
}

class CharacterProvider extends ChangeNotifier {
  final CharacterCloudRepository _cloudRepo = CharacterCloudRepository();

  Character? _character;
  List<Character> _characters = [];
  List<Character> _campaignCharacters = [];
  int? _selectedIndex;
  String? _activeUserId;
  String? _creationCampaignId;
  CharacterCreationSource? _creationSource;

  Character? get character => _character;
  List<Character> get characters => _characters;
  List<Character> get campaignCharacters => _campaignCharacters;
  int? get selectedIndex => _selectedIndex;
  String? get activeUserId => _activeUserId;
  String? get creationCampaignId => _creationCampaignId;
  CharacterCreationSource? get creationSource => _creationSource;

  List<Character> getCharactersByCampaignSafe(String? campaignId) {
    if (campaignId == null) return [];
    return _campaignCharacters
        .where((c) => c.campaignId == campaignId)
        .toList();
  }

  Character? getCharacterById(String id) {
    try {
      return _characters.firstWhere((c) => c.id == id);
    } catch (_) {
      try {
        return _campaignCharacters.firstWhere((c) => c.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> loadCharacters([String? userId]) async {
    final resolvedUserId = userId ?? _activeUserId;
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      debugPrint('CharacterProvider.loadCharacters: missing userId');
      return;
    }

    _activeUserId = resolvedUserId;
    _characters = await _cloudRepo.getCharactersByUser(resolvedUserId);

    if (_character != null) {
      final existingIndex =
          _characters.indexWhere((c) => c.id == _character!.id);
      if (existingIndex != -1) {
        _selectedIndex = existingIndex;
        _character = _characters[existingIndex];
      } else {
        _character = null;
        _selectedIndex = null;
      }
    }

    notifyListeners();
  }

  Future<void> loadCampaignCharacters(String campaignId) async {
    if (campaignId.isEmpty) {
      debugPrint(
          'CharacterProvider.loadCampaignCharacters: missing campaignId');
      return;
    }

    _campaignCharacters = await _cloudRepo.getCharactersByCampaign(campaignId);

    if (_character != null) {
      final existingIndex =
          _campaignCharacters.indexWhere((c) => c.id == _character!.id);
      if (existingIndex != -1) {
        _character = _campaignCharacters[existingIndex];
      }
    }

    notifyListeners();
  }

  void startNewCharacter({
    String? campaignId,
    required CharacterCreationSource source,
  }) {
    _creationCampaignId = campaignId;
    _creationSource = source;

    _character = Character.empty();
    _character!.campaignId = campaignId;

    _selectedIndex = null;
    notifyListeners();
  }

  Future<void> loadCharactersFromCloud(String userId) async {
    await loadCharacters(userId);
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

  Future<void> saveCharacter([String? userId]) async {
    if (_character == null) return;

    final resolvedUserId = _resolveUserId(_character, explicitUserId: userId);
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      debugPrint('CharacterProvider.saveCharacter: missing userId');
      return;
    }

    if (_character!.id.isEmpty) {
      _character!.id = DateTime.now().millisecondsSinceEpoch.toString();
    }

    _character!.ownerUserId = resolvedUserId;
    _activeUserId = resolvedUserId;

    await _cloudRepo.saveCharacter(_character!);
    await loadCharacters(resolvedUserId);
    if ((_character!.campaignId ?? '').isNotEmpty) {
      await loadCampaignCharacters(_character!.campaignId!);
    }
    _syncSelectedCharacterById(_character!.id);
  }

  Future<void> saveCharacterToCloud(String userId) async {
    await saveCharacter(userId);
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
    await _deleteAndRefreshCharacter(character);
  }

  Future<void> deleteCharacterById(String id) async {
    final character = getCharacterById(id);
    if (character == null) return;

    await _deleteAndRefreshCharacter(character);
  }

  void resetCharacter() {
    _character = Character.empty();
    _character!.campaignId = _creationCampaignId;
    _selectedIndex = null;
    notifyListeners();
  }

  void clear() {
    _character = null;
    _selectedIndex = null;
    _creationCampaignId = null;
    _creationSource = null;
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
      final ability = bonus["ability"]?.toString();
      final value = bonus["bonus"] is int ? bonus["bonus"] as int : null;

      if (ability == null || value == null) continue;

      _character!.racialBonuses[ability] =
          (_character!.racialBonuses[ability] ?? 0) + value;
    }

    notifyListeners();
  }

  void setSubclass(String subclassName, {Map<String, int>? bonuses}) {
    if (_character == null) return;

    _character!.setSubclassForPrimaryClass(subclassName);

    if (bonuses != null) {
      bonuses.forEach((ability, value) {
        _character!.stats[ability] = (_character!.stats[ability] ?? 0) + value;
      });
    }

    notifyListeners();
  }

  Future<void> assignCharacterToCampaign(
    String characterId,
    String? campaignId,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    character.campaignId = campaignId;
    await _saveAndRefreshCharacter(character);
  }

  Future<void> updateCharacterById(
    String characterId,
    void Function(Character) updates,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    updates(character);
    await _saveAndRefreshCharacter(character);
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

    await _saveAndRefreshCharacter(character);
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

    await _saveAndRefreshCharacter(character);
  }

  Future<void> clearInvalidInfusionsForCharacter(
    String characterId,
    List<String> selectedInfusionIds,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    clearInvalidInfusions(character, selectedInfusionIds);
    await _saveAndRefreshCharacter(character);
  }

  Future<void> syncPactWeaponWithEquipment(
    String characterId,
    List<EquipmentCompendiumItem> equipmentItems,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    syncPactOfTheBlade(character, equipmentItems);
    await _saveAndRefreshCharacter(character);
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

    await _saveAndRefreshCharacter(character);
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

    await _saveAndRefreshCharacter(character);
  }

  Future<void> updateCharacterFeatures(
    String characterId,
    List<CharacterFeature> features,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    character.features = features;
    await _saveAndRefreshCharacter(character);
  }

  Future<void> updateCharacterResources(
    String characterId,
    List<CharacterResource> resources,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    character.resources = resources;
    await _saveAndRefreshCharacter(character);
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
    await _saveAndRefreshCharacter(character);
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

    await _saveAndRefreshCharacter(character);
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
    await _saveAndRefreshCharacter(character);
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

    await _saveAndRefreshCharacter(character);
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

    await _saveAndRefreshCharacter(character);
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
    await _saveAndRefreshCharacter(character);
  }

  Future<void> removeResourceFromCharacter(
    String characterId,
    String resourceId,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    character.resources =
        character.resources.where((r) => r.id != resourceId).toList();

    await _saveAndRefreshCharacter(character);
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

      await _saveAndRefreshCharacter(character);
      return;
    }

    final feats = await FeatDataService.getFeatsByIds(featIds);

    FeatSyncService.applyFeatsToCharacter(
      character: character,
      feats: feats,
    );

    await _saveAndRefreshCharacter(character);
  }

  Future<void> syncFeaturesAndResources(String characterId) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    final classAndSubclassFeatures =
        await CharacterFeatureSyncService.buildFeaturesForCharacter(character);

    final raceSync = await RaceSyncService.buildForCharacter(character);

    final generatedResources = [
      ...CharacterResourceFactory.buildResources(character),
      ...raceSync.resources,
    ];

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

    character.features = [
      ...classAndSubclassFeatures,
      ...raceSync.features,
    ];

    character.racialArmorProficiencies = raceSync.armorProficiencies;
    character.racialWeaponProficiencies = raceSync.weaponProficiencies;
    character.racialToolProficiencies = raceSync.toolProficiencies;
    character.racialLanguageProficiencies = raceSync.languageProficiencies;
    character.racialResistances = raceSync.resistances;
    character.racialImmunities = raceSync.immunities;
    character.racialConditionImmunities = raceSync.conditionImmunities;
    character.racialSenses = raceSync.senses;
    character.resources = mergedResources;

    await _saveAndRefreshCharacter(character);
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

    await _saveAndRefreshCharacter(character);
  }

  Future<void> unequipItemFromCharacter(
    String characterId,
    EquipSlot slot,
  ) async {
    final character = getCharacterById(characterId);
    if (character == null) return;

    _setEquippedSlot(character, slot, null);
    await _saveAndRefreshCharacter(character);
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

    await _saveAndRefreshCharacter(character);
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

  String? _resolveUserId(
    Character? character, {
    String? explicitUserId,
  }) {
    return explicitUserId ?? character?.ownerUserId ?? _activeUserId;
  }

  Future<void> _saveAndRefreshCharacter(
    Character character, {
    String? explicitUserId,
  }) async {
    final resolvedOwnerUserId = _resolveUserId(
      character,
      explicitUserId: explicitUserId,
    );

    if (resolvedOwnerUserId == null || resolvedOwnerUserId.isEmpty) {
      debugPrint(
        'CharacterProvider._saveAndRefreshCharacter: missing userId for ${character.id}',
      );
      return;
    }

    final refreshUserId = _activeUserId ?? resolvedOwnerUserId;

    character.ownerUserId = resolvedOwnerUserId;
    await _cloudRepo.saveCharacter(character);
    await loadCharacters(refreshUserId);

    if ((character.campaignId ?? '').isNotEmpty) {
      await loadCampaignCharacters(character.campaignId!);
    }

    _syncSelectedCharacterById(character.id);
  }

  Future<void> _deleteAndRefreshCharacter(
    Character character, {
    String? explicitUserId,
  }) async {
    final resolvedUserId = _resolveUserId(
      character,
      explicitUserId: explicitUserId,
    );

    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      debugPrint(
        'CharacterProvider._deleteAndRefreshCharacter: missing userId for ${character.id}',
      );
      return;
    }

    await _cloudRepo.deleteCharacter(character.id);
    _activeUserId = resolvedUserId;

    if (_character?.id == character.id) {
      _character = null;
      _selectedIndex = null;
    }

    await loadCharacters(resolvedUserId);
  }

  void _syncSelectedCharacterById(String id) {
    final index = _characters.indexWhere((c) => c.id == id);
    if (index == -1) return;

    _selectedIndex = index;
    _character = _characters[index];
    notifyListeners();
  }
}
