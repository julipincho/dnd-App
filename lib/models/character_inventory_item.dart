enum EquipSlot {
  weaponMainHand,
  weaponOffHand,
  armor,
  shield,
  accessory,
}

enum EquipItemType {
  generic,
  weapon,
  armor,
  shield,
  accessory,
}

enum InventoryItemSourceType {
  manual,
  equipmentCompendium,
  campaignCompendium,
}

class CharacterInventoryItem {
  final String id;
  final String name;
  final String? compendiumEntryId;
  final InventoryItemSourceType sourceType;
  final int quantity;
  final String? notes;
  final String? description;
  final String? imagePath;
  final DateTime createdAt;

  // Equipment support
  final bool isEquippable;
  final EquipItemType itemType;
  final List<EquipSlot> allowedSlots;
  final bool isEquipped;
  final String? appliedInfusionId;
  final String? appliedInfusionName;
  // Weapon data
  final String? damageDice; // ej: "1d8"
  final String? damageType; // ej: "slashing"
  final bool isFinesse;
  final bool isRanged;
  final bool isTwoHanded;
  final bool isPactWeapon;
  // Armor / shield data
  final int? armorClassBonus; // para shield o accesorios defensivos
  final int? baseArmorClass; // ej: leather 11, chain mail 16
  final bool allowsDexBonus;
  final int? maxDexBonus;

  CharacterInventoryItem({
    required this.id,
    required this.name,
    this.compendiumEntryId,
    this.sourceType = InventoryItemSourceType.manual,
    required this.quantity,
    this.notes,
    this.description,
    this.imagePath,
    required this.createdAt,
    this.isEquippable = false,
    this.itemType = EquipItemType.generic,
    this.allowedSlots = const [],
    this.isEquipped = false,
    this.damageDice,
    this.damageType,
    this.isFinesse = false,
    this.isRanged = false,
    this.isTwoHanded = false,
    this.armorClassBonus,
    this.baseArmorClass,
    this.allowsDexBonus = true,
    this.maxDexBonus,
    this.isPactWeapon = false,
    this.appliedInfusionId,
    this.appliedInfusionName,
  });

  factory CharacterInventoryItem.fromJson(Map<String, dynamic> json) {
    return CharacterInventoryItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      compendiumEntryId: json['compendiumEntryId']?.toString(),
      sourceType: _sourceTypeFromString(json['sourceType']?.toString()),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      notes: json['notes']?.toString(),
      description: json['description']?.toString(),
      imagePath: json['imagePath']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      isEquippable: json['isEquippable'] as bool? ?? false,
      itemType: _equipItemTypeFromString(json['itemType']?.toString()),
      allowedSlots: _equipSlotsFromJson(json['allowedSlots']),
      isEquipped: json['isEquipped'] as bool? ?? false,
      damageDice: json['damageDice']?.toString(),
      damageType: json['damageType']?.toString(),
      isFinesse: json['isFinesse'] as bool? ?? false,
      isRanged: json['isRanged'] as bool? ?? false,
      isTwoHanded: json['isTwoHanded'] as bool? ?? false,
      armorClassBonus: (json['armorClassBonus'] as num?)?.toInt(),
      baseArmorClass: (json['baseArmorClass'] as num?)?.toInt(),
      allowsDexBonus: json['allowsDexBonus'] as bool? ?? true,
      maxDexBonus: (json['maxDexBonus'] as num?)?.toInt(),
      isPactWeapon: json['isPactWeapon'] as bool? ?? false,
      appliedInfusionId: json['appliedInfusionId']?.toString(),
      appliedInfusionName: json['appliedInfusionName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'compendiumEntryId': compendiumEntryId,
      'sourceType': sourceType.name,
      'quantity': quantity,
      'notes': notes,
      'description': description,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'isEquippable': isEquippable,
      'itemType': itemType.name,
      'allowedSlots': allowedSlots.map((e) => e.name).toList(),
      'isEquipped': isEquipped,
      'damageDice': damageDice,
      'damageType': damageType,
      'isFinesse': isFinesse,
      'isRanged': isRanged,
      'isTwoHanded': isTwoHanded,
      'armorClassBonus': armorClassBonus,
      'baseArmorClass': baseArmorClass,
      'allowsDexBonus': allowsDexBonus,
      'maxDexBonus': maxDexBonus,
      'isPactWeapon': isPactWeapon,
      'appliedInfusionId': appliedInfusionId,
      'appliedInfusionName': appliedInfusionName,
    };
  }

  CharacterInventoryItem copyWith({
    String? id,
    String? name,
    String? compendiumEntryId,
    InventoryItemSourceType? sourceType,
    int? quantity,
    String? notes,
    String? description,
    String? imagePath,
    DateTime? createdAt,
    bool? isEquippable,
    EquipItemType? itemType,
    List<EquipSlot>? allowedSlots,
    bool? isEquipped,
    String? damageDice,
    String? damageType,
    bool? isFinesse,
    bool? isRanged,
    bool? isTwoHanded,
    int? armorClassBonus,
    int? baseArmorClass,
    bool? allowsDexBonus,
    int? maxDexBonus,
    bool? isPactWeapon,
    String? appliedInfusionId,
    String? appliedInfusionName,
  }) {
    return CharacterInventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      compendiumEntryId: compendiumEntryId ?? this.compendiumEntryId,
      sourceType: sourceType ?? this.sourceType,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      isEquippable: isEquippable ?? this.isEquippable,
      itemType: itemType ?? this.itemType,
      allowedSlots: allowedSlots ?? this.allowedSlots,
      isEquipped: isEquipped ?? this.isEquipped,
      damageDice: damageDice ?? this.damageDice,
      damageType: damageType ?? this.damageType,
      isFinesse: isFinesse ?? this.isFinesse,
      isRanged: isRanged ?? this.isRanged,
      isTwoHanded: isTwoHanded ?? this.isTwoHanded,
      armorClassBonus: armorClassBonus ?? this.armorClassBonus,
      baseArmorClass: baseArmorClass ?? this.baseArmorClass,
      allowsDexBonus: allowsDexBonus ?? this.allowsDexBonus,
      maxDexBonus: maxDexBonus ?? this.maxDexBonus,
      isPactWeapon: isPactWeapon ?? this.isPactWeapon,
      appliedInfusionId: appliedInfusionId ?? this.appliedInfusionId,
      appliedInfusionName: appliedInfusionName ?? this.appliedInfusionName,
    );
  }

  bool get isManual => sourceType == InventoryItemSourceType.manual;

  bool get isFromEquipmentCompendium =>
      sourceType == InventoryItemSourceType.equipmentCompendium;

  bool get isFromCampaignCompendium =>
      sourceType == InventoryItemSourceType.campaignCompendium;
  bool get hasInfusion => appliedInfusionId != null;
  static EquipItemType _equipItemTypeFromString(String? value) {
    switch (value) {
      case 'weapon':
        return EquipItemType.weapon;
      case 'armor':
        return EquipItemType.armor;
      case 'shield':
        return EquipItemType.shield;
      case 'accessory':
        return EquipItemType.accessory;
      case 'generic':
      default:
        return EquipItemType.generic;
    }
  }

  static InventoryItemSourceType _sourceTypeFromString(String? value) {
    switch (value) {
      case 'equipmentCompendium':
        return InventoryItemSourceType.equipmentCompendium;
      case 'campaignCompendium':
        return InventoryItemSourceType.campaignCompendium;
      case 'manual':
      default:
        return InventoryItemSourceType.manual;
    }
  }

  static List<EquipSlot> _equipSlotsFromJson(dynamic value) {
    if (value is! List) return [];

    return value
        .map((slot) => _equipSlotFromString(slot?.toString()))
        .whereType<EquipSlot>()
        .toList();
  }

  static EquipSlot? _equipSlotFromString(String? value) {
    switch (value) {
      case 'weaponMainHand':
        return EquipSlot.weaponMainHand;
      case 'weaponOffHand':
        return EquipSlot.weaponOffHand;
      case 'armor':
        return EquipSlot.armor;
      case 'shield':
        return EquipSlot.shield;
      case 'accessory':
        return EquipSlot.accessory;
      default:
        return null;
    }
  }
}
