import '../models/character.dart';
import '../models/character_inventory_item.dart';
import '../models/character_option_category.dart';
import '../models/character_option_definition.dart';
import '../models/character_options_repository.dart';
import '../models/equipment_compendium_item.dart';

class CharacterOptionEffects {
  const CharacterOptionEffects._();

  static List<String> getSelectedOptionIdsByCategory(
    Character character,
    CharacterOptionCategory category,
  ) {
    final result = <String>[];

    for (final group in character.selectedOptionGroups) {
      if (group.category == category) {
        result.addAll(group.selectedOptionIds);
      }
    }

    return result;
  }

  static List<CharacterOptionDefinition> getSelectedOptionsByCategory(
    Character character,
    CharacterOptionCategory category,
  ) {
    final repo = CharacterOptionsRepository.instance;
    final ids = getSelectedOptionIdsByCategory(character, category);
    return repo.getManyByIds(ids);
  }

  static bool hasSelectedOption(
    Character character,
    CharacterOptionCategory category,
    String optionId,
  ) {
    final normalizedTarget = _normalize(optionId);

    for (final group in character.selectedOptionGroups) {
      if (group.category != category) continue;

      for (final selectedId in group.selectedOptionIds) {
        if (_normalize(selectedId) == normalizedTarget) {
          return true;
        }
      }
    }

    return false;
  }

  static List<String> getSelectedFightingStyleIds(Character character) {
    return getSelectedOptionIdsByCategory(
      character,
      CharacterOptionCategory.fightingStyle,
    );
  }

  static List<CharacterOptionDefinition> getSelectedFightingStyles(
    Character character,
  ) {
    return getSelectedOptionsByCategory(
      character,
      CharacterOptionCategory.fightingStyle,
    );
  }

  static bool hasFightingStyle(Character character, String styleKey) {
    final normalizedTarget = _normalize(styleKey);
    final selectedStyles = getSelectedFightingStyles(character);

    for (final style in selectedStyles) {
      final normalizedId = _normalize(style.id);
      final normalizedName = _normalize(style.name);

      if (normalizedId == normalizedTarget ||
          normalizedName == normalizedTarget ||
          normalizedId.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedId)) {
        return true;
      }
    }

    return false;
  }

  static List<String> getSelectedInvocationIds(Character character) {
    return getSelectedOptionIdsByCategory(
      character,
      CharacterOptionCategory.invocation,
    );
  }

  static List<CharacterOptionDefinition> getSelectedInvocations(
    Character character,
  ) {
    return getSelectedOptionsByCategory(
      character,
      CharacterOptionCategory.invocation,
    );
  }

  static bool hasInvocation(Character character, String invocationKey) {
    final normalizedTarget = _normalize(invocationKey);
    final selectedInvocations = getSelectedInvocations(character);

    for (final invocation in selectedInvocations) {
      final normalizedId = _normalize(invocation.id);
      final normalizedName = _normalize(invocation.name);

      if (normalizedId == normalizedTarget ||
          normalizedName == normalizedTarget ||
          normalizedId.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedId)) {
        return true;
      }
    }

    return false;
  }

  static bool hasImprovedPactWeapon(Character character) =>
      hasInvocation(character, 'improved_pact_weapon');
  static bool hasSuperiorPactWeapon(Character character) =>
      hasInvocation(character, 'superior_pact_weapon');

  static bool hasUltimatePactWeapon(Character character) =>
      hasInvocation(character, 'ultimate_pact_weapon');

  static int getBestPactWeaponEnhancementBonus(Character character) {
    var bonus = 0;

    if (hasImprovedPactWeapon(character)) {
      bonus = 1;
    }

    if (hasSuperiorPactWeapon(character)) {
      bonus = 2;
    }

    if (hasUltimatePactWeapon(character)) {
      bonus = 3;
    }

    return bonus;
  }

  static bool hasLifedrinker(Character character) =>
      hasInvocation(character, 'lifedrinker');

  static int getPassiveArmorClassBonusFromOptions({
    required Character character,
    required bool isWearingArmor,
  }) {
    var bonus = 0;

    // Defense: +1 AC while wearing armor
    if (isWearingArmor && hasFightingStyle(character, 'defense')) {
      bonus += 1;
    }

    return bonus;
  }

  static List<String> getSelectedInfusionIds(Character character) {
    return getSelectedOptionIdsByCategory(
      character,
      CharacterOptionCategory.infusion,
    );
  }

  static List<CharacterOptionDefinition> getSelectedInfusions(
    Character character,
  ) {
    return getSelectedOptionsByCategory(
      character,
      CharacterOptionCategory.infusion,
    );
  }

  static bool hasInfusion(Character character, String infusionKey) {
    final normalizedTarget = _normalize(infusionKey);
    final selectedInfusions = getSelectedInfusions(character);

    for (final infusion in selectedInfusions) {
      final normalizedId = _normalize(infusion.id);
      final normalizedName = _normalize(infusion.name);

      if (normalizedId == normalizedTarget ||
          normalizedName == normalizedTarget ||
          normalizedId.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedId)) {
        return true;
      }
    }

    return false;
  }

  static bool isItemInfusedWith(
    CharacterInventoryItem item,
    String infusionKey,
  ) {
    final appliedId = item.appliedInfusionId?.trim();
    if (appliedId == null || appliedId.isEmpty) return false;

    final normalizedApplied = _normalize(appliedId);
    final normalizedTarget = _normalize(infusionKey);

    return normalizedApplied == normalizedTarget ||
        normalizedApplied.contains(normalizedTarget) ||
        normalizedTarget.contains(normalizedApplied);
  }

  static int getArtificerInfusionScalingBonus(
    Character character, {
    required int baseBonus,
    int scaledBonus = 2,
    int scaledLevel = 10,
  }) {
    final artificerLevel = character.levelForClass('artificer');
    if (artificerLevel <= 0) return 0;

    return artificerLevel >= scaledLevel ? scaledBonus : baseBonus;
  }

  static int getInfusedWeaponAttackBonus({
    required Character character,
    required CharacterInventoryItem weaponItem,
  }) {
    // Enhanced Weapon: +1, or +2 at artificer level 10
    if (isItemInfusedWith(weaponItem, 'enhanced_weapon')) {
      return getArtificerInfusionScalingBonus(
        character,
        baseBonus: 1,
        scaledBonus: 2,
        scaledLevel: 10,
      );
    }

    // Radiant Weapon: +1
    if (isItemInfusedWith(weaponItem, 'radiant_weapon')) {
      return 1;
    }

    // Returning Weapon: +1
    if (isItemInfusedWith(weaponItem, 'returning_weapon')) {
      return 1;
    }

    // Repeating Shot: +1 when used to make a ranged attack
    if (isItemInfusedWith(weaponItem, 'repeating_shot') &&
        weaponItem.isRanged) {
      return 1;
    }

    return 0;
  }

  static int getInfusedWeaponDamageBonus({
    required Character character,
    required CharacterInventoryItem weaponItem,
  }) {
    // Enhanced Weapon: +1, or +2 at artificer level 10
    if (isItemInfusedWith(weaponItem, 'enhanced_weapon')) {
      return getArtificerInfusionScalingBonus(
        character,
        baseBonus: 1,
        scaledBonus: 2,
        scaledLevel: 10,
      );
    }

    // Radiant Weapon: +1
    if (isItemInfusedWith(weaponItem, 'radiant_weapon')) {
      return 1;
    }

    // Returning Weapon: +1
    if (isItemInfusedWith(weaponItem, 'returning_weapon')) {
      return 1;
    }

    // Repeating Shot: +1 when used to make a ranged attack
    if (isItemInfusedWith(weaponItem, 'repeating_shot') &&
        weaponItem.isRanged) {
      return 1;
    }

    return 0;
  }

  static int getMainHandAttackBonusFromOptions({
    required Character character,
    required bool isRangedWeapon,
  }) {
    var bonus = 0;

    // Archery: +2 to attack rolls you make with ranged weapons
    if (isRangedWeapon && hasFightingStyle(character, 'archery')) {
      bonus += 2;
    }

    return bonus;
  }

  static int getInfusedArmorClassBonus({
    required Character character,
    required CharacterInventoryItem? armorItem,
    required CharacterInventoryItem? shieldItem,
  }) {
    var bonus = 0;

    // Enhanced Defense on armor or shield: +1, or +2 at artificer level 10
    if (armorItem != null && isItemInfusedWith(armorItem, 'enhanced_defense')) {
      bonus += getArtificerInfusionScalingBonus(
        character,
        baseBonus: 1,
        scaledBonus: 2,
        scaledLevel: 10,
      );
    } else if (shieldItem != null &&
        isItemInfusedWith(shieldItem, 'enhanced_defense')) {
      bonus += getArtificerInfusionScalingBonus(
        character,
        baseBonus: 1,
        scaledBonus: 2,
        scaledLevel: 10,
      );
    }

    // Repulsion Shield: +1 AC while wielding infused shield
    if (shieldItem != null &&
        isItemInfusedWith(shieldItem, 'repulsion_shield')) {
      bonus += 1;
    }

    return bonus;
  }

  static bool hasPactBoon(Character character, String pactId) {
    return hasSelectedOption(
      character,
      CharacterOptionCategory.pactBoon,
      pactId,
    );
  }

  static bool hasPactOfTheBlade(Character character) =>
      hasPactBoon(character, 'pact_of_the_blade');

  static bool hasPactOfTheChain(Character character) =>
      hasPactBoon(character, 'pact_of_the_chain');

  static bool hasPactOfTheTome(Character character) =>
      hasPactBoon(character, 'pact_of_the_tome');

  static bool hasPactOfTheTalisman(Character character) =>
      hasPactBoon(character, 'pact_of_the_talisman');

  static int getMainHandDamageBonusFromOptions({
    required Character character,
    required bool isMeleeWeapon,
    required bool isOneHandedMeleeWeapon,
    required bool hasOffHandWeaponEquipped,
  }) {
    var bonus = 0;

    // Dueling: +2 damage when wielding a melee weapon in one hand
    // and no other weapons
    if (isMeleeWeapon &&
        isOneHandedMeleeWeapon &&
        !hasOffHandWeaponEquipped &&
        hasFightingStyle(character, 'dueling')) {
      bonus += 2;
    }

    return bonus;
  }

  static int getPactWeaponAttackBonus({
    required Character character,
    required CharacterInventoryItem weaponItem,
    required EquipmentCompendiumItem? equipmentItem,
  }) {
    if (!weaponItem.isPactWeapon || !hasPactOfTheBlade(character)) {
      return 0;
    }

    final enhancementBonus = getBestPactWeaponEnhancementBonus(character);
    if (enhancementBonus <= 0) {
      return 0;
    }

    // No aplicar el bonus del pacto si el arma ya tiene bonus propio de ataque
    final itemHasOwnAttackBonus = (equipmentItem?.attackBonus ?? 0) > 0;
    if (itemHasOwnAttackBonus) {
      return 0;
    }

    return enhancementBonus;
  }

  static int getPactWeaponDamageBonus({
    required Character character,
    required CharacterInventoryItem weaponItem,
    required EquipmentCompendiumItem? equipmentItem,
    required int charismaModifier,
  }) {
    if (!weaponItem.isPactWeapon || !hasPactOfTheBlade(character)) {
      return 0;
    }

    var bonus = 0;

    final enhancementBonus = getBestPactWeaponEnhancementBonus(character);
    if (enhancementBonus > 0) {
      // No aplicar el bonus del pacto si el arma ya tiene bonus propio de daño
      final itemHasOwnDamageBonus = (equipmentItem?.damageBonus ?? 0) > 0;

      if (!itemHasOwnDamageBonus) {
        bonus += enhancementBonus;
      }
    }

    // Lifedrinker: add CHA modifier to damage, minimum 1
    if (hasLifedrinker(character)) {
      bonus += charismaModifier < 1 ? 1 : charismaModifier;
    }

    return bonus;
  }

  static bool _isValidArcaneFocusItem(
    CharacterInventoryItem item,
    EquipmentCompendiumItem? equipmentItem,
  ) {
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

  static int getInfusedSpellAttackBonus({
    required Character character,
    required CharacterInventoryItem? mainHandItem,
    required CharacterInventoryItem? offHandItem,
    required EquipmentCompendiumItem? mainHandEquipmentItem,
    required EquipmentCompendiumItem? offHandEquipmentItem,
  }) {
    final mainHandQualifies = mainHandItem != null &&
        isItemInfusedWith(mainHandItem, 'enhanced_arcane_focus') &&
        _isValidArcaneFocusItem(mainHandItem, mainHandEquipmentItem);

    final offHandQualifies = offHandItem != null &&
        isItemInfusedWith(offHandItem, 'enhanced_arcane_focus') &&
        _isValidArcaneFocusItem(offHandItem, offHandEquipmentItem);

    final holdingInfusedFocus = mainHandQualifies || offHandQualifies;

    if (!holdingInfusedFocus) {
      return 0;
    }

    return getArtificerInfusionScalingBonus(
      character,
      baseBonus: 1,
      scaledBonus: 2,
      scaledLevel: 10,
    );
  }

  static List<String> getSelectedManeuverIds(Character character) {
    return getSelectedOptionIdsByCategory(
      character,
      CharacterOptionCategory.maneuver,
    );
  }

  static List<CharacterOptionDefinition> getSelectedManeuvers(
    Character character,
  ) {
    return getSelectedOptionsByCategory(
      character,
      CharacterOptionCategory.maneuver,
    );
  }

  static bool hasManeuver(Character character, String maneuverKey) {
    final normalizedTarget = _normalize(maneuverKey);
    final selectedManeuvers = getSelectedManeuvers(character);

    for (final maneuver in selectedManeuvers) {
      final normalizedId = _normalize(maneuver.id);
      final normalizedName = _normalize(maneuver.name);

      if (normalizedId == normalizedTarget ||
          normalizedName == normalizedTarget ||
          normalizedId.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedId)) {
        return true;
      }
    }

    return false;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
