class EquipmentCompendiumItem {
  final String id;
  final String name;
  final String source;
  final String type;
  final String subtype;
  final String? imagePath;

  final bool isEquippable;
  final List<String> allowedSlots;

  final String? weaponCategory;
  final String? damageDiceOneHanded;
  final String? damageDiceTwoHanded;
  final String? damageType;
  final String? range;
  final List<String> properties;
  final bool isRanged;
  final bool isFinesse;
  final bool isTwoHanded;

  final int? baseArmorClass;
  final int? armorClassBonus;
  final bool allowsDexBonus;
  final int? maxDexBonus;

  final int? weight;
  final int? valueCp;
  final bool requiresAttunement;
  final String rarity;
  final String? description;
  final String? baseItemRef;

  final int attackBonus;
  final int damageBonus;
  final int spellAttackBonus;
  final int spellSaveDcBonus;

  final Map<String, dynamic> modifiers;

  final bool isMagic;
  final bool hasActiveEffects;
  final bool hasImage;

  final bool isWeapon;
  final bool isArmor;
  final bool isShield;
  final bool isAccessory;

  final String displayCategory;

  const EquipmentCompendiumItem({
    required this.id,
    required this.name,
    required this.source,
    required this.type,
    required this.subtype,
    required this.imagePath,
    required this.isEquippable,
    required this.allowedSlots,
    required this.weaponCategory,
    required this.damageDiceOneHanded,
    required this.damageDiceTwoHanded,
    required this.damageType,
    required this.range,
    required this.properties,
    required this.isRanged,
    required this.isFinesse,
    required this.isTwoHanded,
    required this.baseArmorClass,
    required this.armorClassBonus,
    required this.allowsDexBonus,
    required this.maxDexBonus,
    required this.weight,
    required this.valueCp,
    required this.requiresAttunement,
    required this.rarity,
    required this.description,
    required this.baseItemRef,
    required this.attackBonus,
    required this.damageBonus,
    required this.spellAttackBonus,
    required this.spellSaveDcBonus,
    required this.modifiers,
    required this.isMagic,
    required this.hasActiveEffects,
    required this.hasImage,
    required this.isWeapon,
    required this.isArmor,
    required this.isShield,
    required this.isAccessory,
    required this.displayCategory,
  });

  factory EquipmentCompendiumItem.fromJson(Map<String, dynamic> json) {
    return EquipmentCompendiumItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      subtype: json['subtype']?.toString() ?? '',
      imagePath: json['imagePath']?.toString(),
      isEquippable: json['isEquippable'] as bool? ?? false,
      allowedSlots:
          (json['allowedSlots'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      weaponCategory: json['weaponCategory']?.toString(),
      damageDiceOneHanded: json['damageDiceOneHanded']?.toString(),
      damageDiceTwoHanded: json['damageDiceTwoHanded']?.toString(),
      damageType: json['damageType']?.toString(),
      range: json['range']?.toString(),
      properties:
          (json['properties'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      isRanged: json['isRanged'] as bool? ?? false,
      isFinesse: json['isFinesse'] as bool? ?? false,
      isTwoHanded: json['isTwoHanded'] as bool? ?? false,
      baseArmorClass: (json['baseArmorClass'] as num?)?.toInt(),
      armorClassBonus: (json['armorClassBonus'] as num?)?.toInt(),
      allowsDexBonus: json['allowsDexBonus'] as bool? ?? false,
      maxDexBonus: (json['maxDexBonus'] as num?)?.toInt(),
      weight: (json['weight'] as num?)?.toInt(),
      valueCp: (json['valueCp'] as num?)?.toInt(),
      requiresAttunement: json['requiresAttunement'] as bool? ?? false,
      rarity: json['rarity']?.toString() ?? 'none',
      description: json['description']?.toString(),
      baseItemRef: json['baseItemRef']?.toString(),
      attackBonus: (json['attackBonus'] as num?)?.toInt() ?? 0,
      damageBonus: (json['damageBonus'] as num?)?.toInt() ?? 0,
      spellAttackBonus: (json['spellAttackBonus'] as num?)?.toInt() ?? 0,
      spellSaveDcBonus: (json['spellSaveDcBonus'] as num?)?.toInt() ?? 0,
      modifiers: Map<String, dynamic>.from(
        json['modifiers'] as Map? ?? const {},
      ),
      isMagic: json['isMagic'] as bool? ?? false,
      hasActiveEffects: json['hasActiveEffects'] as bool? ?? false,
      hasImage: json['hasImage'] as bool? ?? false,
      isWeapon: json['isWeapon'] as bool? ?? false,
      isArmor: json['isArmor'] as bool? ?? false,
      isShield: json['isShield'] as bool? ?? false,
      isAccessory: json['isAccessory'] as bool? ?? false,
      displayCategory: json['displayCategory']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'source': source,
      'type': type,
      'subtype': subtype,
      'imagePath': imagePath,
      'isEquippable': isEquippable,
      'allowedSlots': allowedSlots,
      'weaponCategory': weaponCategory,
      'damageDiceOneHanded': damageDiceOneHanded,
      'damageDiceTwoHanded': damageDiceTwoHanded,
      'damageType': damageType,
      'range': range,
      'properties': properties,
      'isRanged': isRanged,
      'isFinesse': isFinesse,
      'isTwoHanded': isTwoHanded,
      'baseArmorClass': baseArmorClass,
      'armorClassBonus': armorClassBonus,
      'allowsDexBonus': allowsDexBonus,
      'maxDexBonus': maxDexBonus,
      'weight': weight,
      'valueCp': valueCp,
      'requiresAttunement': requiresAttunement,
      'rarity': rarity,
      'description': description,
      'baseItemRef': baseItemRef,
      'attackBonus': attackBonus,
      'damageBonus': damageBonus,
      'spellAttackBonus': spellAttackBonus,
      'spellSaveDcBonus': spellSaveDcBonus,
      'modifiers': modifiers,
      'isMagic': isMagic,
      'hasActiveEffects': hasActiveEffects,
      'hasImage': hasImage,
      'isWeapon': isWeapon,
      'isArmor': isArmor,
      'isShield': isShield,
      'isAccessory': isAccessory,
      'displayCategory': displayCategory,
    };
  }

  bool get isVersatile => properties.contains('versatile');

  bool get canGoInMainHand => allowedSlots.contains('weaponMainHand');

  bool get canGoInOffHand => allowedSlots.contains('weaponOffHand');

  bool get canGoInArmorSlot => allowedSlots.contains('armor');

  bool get canGoInShieldSlot => allowedSlots.contains('shield');

  bool get canGoInAccessorySlot => allowedSlots.contains('accessory');
}
