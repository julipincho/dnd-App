import '../models/character.dart';
import '../models/character_inventory_item.dart';
import '../models/compendium_entry.dart';
import '../models/equipment_compendium_item.dart';

class ResolvedEquippedItem {
  final CharacterInventoryItem originalItem;
  final CharacterInventoryItem effectiveItem;
  final EquipmentCompendiumItem? equipmentItem;
  final CompendiumEntry? campaignEntry;
  final String slotLabel;

  const ResolvedEquippedItem({
    required this.originalItem,
    required this.effectiveItem,
    required this.equipmentItem,
    required this.campaignEntry,
    required this.slotLabel,
  });
}

class EquipmentConditionContext {
  final Character char;
  final ResolvedEquippedItem? mainHand;
  final ResolvedEquippedItem? armor;
  final ResolvedEquippedItem? shield;
  final List<ResolvedEquippedItem> equippedItems;

  const EquipmentConditionContext({
    required this.char,
    required this.mainHand,
    required this.armor,
    required this.shield,
    required this.equippedItems,
  });

  CharacterInventoryItem? get mainHandItem => mainHand?.effectiveItem;
  CharacterInventoryItem? get armorItem => armor?.effectiveItem;
  CharacterInventoryItem? get shieldItem => shield?.effectiveItem;

  bool get hasArmorEquipped => armorItem?.baseArmorClass != null;
  bool get hasShieldEquipped => shield != null;

  bool get isRangedAttack => mainHandItem != null && mainHandItem!.isRanged;

  bool get isMeleeAttack => mainHandItem != null && !mainHandItem!.isRanged;

  bool get isLongbowOrShortbow {
    final name = mainHandItem?.name.toLowerCase().replaceAll(' ', '') ?? '';
    return name.contains('longbow') || name.contains('shortbow');
  }

  bool get isUnarmored => !hasArmorEquipped;
  bool get isNotUsingShield => !hasShieldEquipped;
}

class CharacterEquipmentEffects {
  static CharacterInventoryItem? findInventoryItemById(
    Character char,
    String? itemId,
  ) {
    if (itemId == null || itemId.isEmpty) return null;

    for (final item in char.inventory) {
      if (item.id == itemId) return item;
    }

    return null;
  }

  static EquipmentConditionContext _buildConditionContext({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final mainHand = getEquippedMainHand(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    final armor = getEquippedArmor(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    final shield = getEquippedShield(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    final equippedItems = getEquippedItems(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    return EquipmentConditionContext(
      char: char,
      mainHand: mainHand,
      armor: armor,
      shield: shield,
      equippedItems: equippedItems,
    );
  }

  static bool evaluateCondition(
    String condition,
    EquipmentConditionContext context,
  ) {
    switch (condition) {
      case 'rangedAttacksWithLongbowOrShortbow':
        return context.isRangedAttack && context.isLongbowOrShortbow;

      case 'rangedWeaponAttacks':
        return context.isRangedAttack;

      case 'meleeWeaponAttacks':
        return context.isMeleeAttack;

      case 'whileUnarmored':
      case 'whileNotWearingArmor':
        return context.isUnarmored;

      case 'whileNotUsingShield':
      case 'whileNotWieldingShield':
        return context.isNotUsingShield;

      case 'whileUnarmoredAndNoShield':
        return context.isUnarmored && context.isNotUsingShield;

      default:
        return false;
    }
  }

  static EquipmentCompendiumItem? resolveEquipmentCompendiumItem(
    CharacterInventoryItem item,
    List<EquipmentCompendiumItem> equipmentItems,
  ) {
    if (item.sourceType != InventoryItemSourceType.equipmentCompendium) {
      return null;
    }

    final compendiumEntryId = item.compendiumEntryId;
    if (compendiumEntryId == null || compendiumEntryId.trim().isEmpty) {
      return null;
    }

    try {
      return equipmentItems
          .firstWhere((entry) => entry.id == compendiumEntryId);
    } catch (_) {
      return null;
    }
  }

  static CompendiumEntry? resolveCampaignCompendiumEntry(
    CharacterInventoryItem item,
    List<CompendiumEntry> compendiumEntries,
  ) {
    if (item.sourceType != InventoryItemSourceType.campaignCompendium) {
      return null;
    }

    final compendiumEntryId = item.compendiumEntryId;
    if (compendiumEntryId == null || compendiumEntryId.trim().isEmpty) {
      return null;
    }

    try {
      return compendiumEntries
          .firstWhere((entry) => entry.id == compendiumEntryId);
    } catch (_) {
      return null;
    }
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

  static List<EquipSlot> mapAllowedSlotsFromCompendium(
    EquipmentCompendiumItem item,
  ) {
    return item.allowedSlots.map((slotName) {
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
  }

  static CharacterInventoryItem inventoryItemWithCompendiumData(
    CharacterInventoryItem inventoryItem,
    EquipmentCompendiumItem? compendiumItem,
  ) {
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

  static ResolvedEquippedItem? resolveEquippedItem({
    required Character char,
    required String? inventoryItemId,
    required String slotLabel,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final originalItem = findInventoryItemById(char, inventoryItemId);
    if (originalItem == null) return null;

    final equipmentItem = resolveEquipmentCompendiumItem(
      originalItem,
      equipmentItems,
    );

    final campaignEntry = resolveCampaignCompendiumEntry(
      originalItem,
      compendiumEntries,
    );

    final effectiveItem = inventoryItemWithCompendiumData(
      originalItem,
      equipmentItem,
    );

    return ResolvedEquippedItem(
      originalItem: originalItem,
      effectiveItem: effectiveItem,
      equipmentItem: equipmentItem,
      campaignEntry: campaignEntry,
      slotLabel: slotLabel,
    );
  }

  static List<ResolvedEquippedItem> getEquippedItems({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final resolved = <ResolvedEquippedItem?>[
      resolveEquippedItem(
        char: char,
        inventoryItemId: char.equippedMainHandItemId,
        slotLabel: 'Main Hand',
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
      ),
      resolveEquippedItem(
        char: char,
        inventoryItemId: char.equippedOffHandItemId,
        slotLabel: 'Off Hand',
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
      ),
      resolveEquippedItem(
        char: char,
        inventoryItemId: char.equippedArmorItemId,
        slotLabel: 'Armor',
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
      ),
      resolveEquippedItem(
        char: char,
        inventoryItemId: char.equippedShieldItemId,
        slotLabel: 'Shield',
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
      ),
      resolveEquippedItem(
        char: char,
        inventoryItemId: char.equippedAccessory1ItemId,
        slotLabel: 'Accessory 1',
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
      ),
      resolveEquippedItem(
        char: char,
        inventoryItemId: char.equippedAccessory2ItemId,
        slotLabel: 'Accessory 2',
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
      ),
    ];

    return resolved.whereType<ResolvedEquippedItem>().toList();
  }

  static ResolvedEquippedItem? getEquippedArmor({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    return resolveEquippedItem(
      char: char,
      inventoryItemId: char.equippedArmorItemId,
      slotLabel: 'Armor',
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
  }

  static ResolvedEquippedItem? getEquippedShield({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    return resolveEquippedItem(
      char: char,
      inventoryItemId: char.equippedShieldItemId,
      slotLabel: 'Shield',
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
  }

  static ResolvedEquippedItem? getEquippedMainHand({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final resolved = resolveEquippedItem(
      char: char,
      inventoryItemId: char.equippedMainHandItemId,
      slotLabel: 'Main Hand',
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    if (resolved == null) return null;
    if (resolved.effectiveItem.itemType != EquipItemType.weapon) return null;

    return resolved;
  }

  static List<ResolvedEquippedItem> getEquippedAccessories({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    return getEquippedItems(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    )
        .where((item) => item.effectiveItem.itemType == EquipItemType.accessory)
        .toList();
  }

  static Map<String, dynamic> _itemModifiers(ResolvedEquippedItem item) {
    return item.equipmentItem?.modifiers ?? const <String, dynamic>{};
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static int getEffectiveAbilityScore({
    required Character char,
    required String ability,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final baseScore = (char.stats[ability] ?? 10) +
        (char.racialBonuses[ability] ?? 0) +
        (char.featAbilityBonuses[ability] ?? 0);
    int effective = baseScore;

    final equippedItems = getEquippedItems(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    for (final item in equippedItems) {
      final modifiers = _itemModifiers(item);

      final minimumScores = modifiers['minimumAbilityScores'];
      if (minimumScores is Map) {
        final minimum = _readInt(minimumScores[ability]);
        if (minimum != null && effective < minimum) {
          effective = minimum;
        }
      }

      final setScores = modifiers['setAbilityScores'];
      if (setScores is Map) {
        final setValue = _readInt(setScores[ability]);
        if (setValue != null) {
          effective = setValue;
        }
      }

      final abilityBonuses = modifiers['abilityBonuses'];
      if (abilityBonuses is Map) {
        final bonus = _readInt(abilityBonuses[ability]) ?? 0;
        effective += bonus;
      }
    }

    return effective;
  }

  static bool _hasArmorEquipped({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final armor = getEquippedArmor(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    return armor?.effectiveItem.baseArmorClass != null;
  }

  static bool _hasShieldEquipped({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final shield = getEquippedShield(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    return shield != null;
  }

  static int getPassiveArmorClassBonus({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final context = _buildConditionContext(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    int total = 0;

    for (final item in context.equippedItems) {
      final effectiveItem = item.effectiveItem;
      final isArmorSlot = item.slotLabel == 'Armor';
      final isShieldSlot = item.slotLabel == 'Shield';

      if (isArmorSlot || isShieldSlot) continue;

      total += effectiveItem.armorClassBonus ?? 0;

      final modifiers = _itemModifiers(item);

      final conditionalArmorBonus =
          _readInt(modifiers['conditionalArmorClassBonus']) ?? 0;
      final condition =
          modifiers['conditionalArmorClassBonusCondition']?.toString().trim();

      if (conditionalArmorBonus == 0) continue;

      if (condition != null && condition.isNotEmpty) {
        if (evaluateCondition(condition, context)) {
          total += conditionalArmorBonus;
        }
        continue;
      }

      final onlyWhenUnarmored = modifiers['onlyWhenUnarmored'] == true;
      final onlyWhenNoShield = modifiers['onlyWhenNoShield'] == true;

      final armorOk = !onlyWhenUnarmored || context.isUnarmored;
      final shieldOk = !onlyWhenNoShield || context.isNotUsingShield;

      if (armorOk && shieldOk) {
        total += conditionalArmorBonus;
      }
    }

    return total;
  }

  static int getPassiveSavingThrowBonus({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final equippedItems = getEquippedItems(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    int total = 0;

    for (final item in equippedItems) {
      final modifiers = _itemModifiers(item);

      final saveBonus = modifiers['savingThrowBonus'];
      if (saveBonus is num) {
        total += saveBonus.toInt();
      }
    }

    return total;
  }

  static int getPassiveSpellAttackBonus({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final equippedItems = getEquippedItems(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    int total = 0;

    for (final item in equippedItems) {
      final modifiers = _itemModifiers(item);
      final modifierBonus = modifiers['spellAttackBonus'];

      if (modifierBonus is num) {
        total += modifierBonus.toInt();
      } else {
        total += item.equipmentItem?.spellAttackBonus ?? 0;
      }
    }

    return total;
  }

  static int getPassiveSpellSaveDcBonus({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final equippedItems = getEquippedItems(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    int total = 0;

    for (final item in equippedItems) {
      final modifiers = _itemModifiers(item);
      final modifierBonus = modifiers['spellSaveDcBonus'];

      if (modifierBonus is num) {
        total += modifierBonus.toInt();
      } else {
        total += item.equipmentItem?.spellSaveDcBonus ?? 0;
      }
    }

    return total;
  }

  static int getMainHandConditionalDamageBonus({
    required Character char,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final context = _buildConditionContext(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    if (context.mainHand == null) return 0;

    int total = 0;

    for (final item in context.equippedItems) {
      final modifiers = _itemModifiers(item);

      final conditionalDamageBonus =
          _readInt(modifiers['conditionalDamageBonus']) ?? 0;
      final condition =
          modifiers['conditionalDamageBonusCondition']?.toString().trim();

      if (conditionalDamageBonus == 0 ||
          condition == null ||
          condition.isEmpty) {
        continue;
      }

      if (evaluateCondition(condition, context)) {
        total += conditionalDamageBonus;
      }
    }

    return total;
  }

  static int calculateEffectiveArmorClass({
    required Character char,
    required int dexModifier,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
  }) {
    final resolvedArmor = getEquippedArmor(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    final resolvedShield = getEquippedShield(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    int armorClass;

    final armorItem = resolvedArmor?.effectiveItem;
    if (armorItem != null && armorItem.baseArmorClass != null) {
      armorClass = armorItem.baseArmorClass!;

      if (armorItem.allowsDexBonus) {
        int dexToAdd = dexModifier;

        final maxDexBonus = armorItem.maxDexBonus;
        if (maxDexBonus != null && dexToAdd > maxDexBonus) {
          dexToAdd = maxDexBonus;
        }

        armorClass += dexToAdd;
      }
    } else {
      armorClass = 10 + dexModifier;
    }

    armorClass += resolvedShield?.effectiveItem.armorClassBonus ?? 0;

    armorClass += getPassiveArmorClassBonus(
      char: char,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );

    return armorClass;
  }
}
