import '../features/characters/models/resolved_inventory_item.dart';
import '../logic/character_option_effects.dart';
import '../models/character.dart';
import '../models/character_inventory_item.dart';
import '../models/compendium_entry.dart';
import '../models/equipment_compendium_item.dart';
import '../utils/character_equipment_effects.dart';
import 'character_multiclass_proficiency_service.dart';

class CharacterWeaponAttackService {
  const CharacterWeaponAttackService._();

  static int attackAbilityModifier({
    required Character character,
    required CharacterInventoryItem weaponItem,
    required int Function(String ability) getAbilityScore,
    required int Function(int score) getAbilityModifier,
  }) {
    final strMod = getAbilityModifier(getAbilityScore('STR'));
    final dexMod = getAbilityModifier(getAbilityScore('DEX'));
    final chaMod = getAbilityModifier(getAbilityScore('CHA'));

    if (weaponItem.isPactWeapon && character.hasPactOfTheBlade) {
      return chaMod;
    }

    if (weaponItem.isRanged) return dexMod;
    if (weaponItem.isFinesse) return dexMod > strMod ? dexMod : strMod;
    return strMod;
  }

  static String attackAbilityLabel({
    required Character character,
    required CharacterInventoryItem weaponItem,
    required int Function(String ability) getAbilityScore,
    required int Function(int score) getAbilityModifier,
  }) {
    final strMod = getAbilityModifier(getAbilityScore('STR'));
    final dexMod = getAbilityModifier(getAbilityScore('DEX'));

    if (weaponItem.isPactWeapon && character.hasPactOfTheBlade) {
      return 'CHA';
    }

    if (weaponItem.isRanged) return 'DEX';
    if (weaponItem.isFinesse) return dexMod > strMod ? 'DEX' : 'STR';
    return 'STR';
  }

  static bool isProficientWithWeapon({
    required Character character,
    required CharacterInventoryItem weaponItem,
    required EquipmentCompendiumItem? equipmentItem,
  }) {
    if (weaponItem.isPactWeapon && character.hasPactOfTheBlade) {
      return true;
    }

    return CharacterMulticlassProficiencyService.isProficientWithWeapon(
      character: character,
      weaponName: weaponItem.name,
      weaponCategory: equipmentItem?.weaponCategory,
    );
  }

  static int mainHandAttackBonus({
    required Character character,
    required ResolvedInventoryItem resolvedWeapon,
    required int Function(String ability) getAbilityScore,
    required int Function(int score) getAbilityModifier,
    required int proficiencyBonus,
  }) {
    final weaponItem = resolvedWeapon.effectiveItem;
    final abilityMod = attackAbilityModifier(
      character: character,
      weaponItem: weaponItem,
      getAbilityScore: getAbilityScore,
      getAbilityModifier: getAbilityModifier,
    );
    final proficiency = isProficientWithWeapon(
      character: character,
      weaponItem: weaponItem,
      equipmentItem: resolvedWeapon.equipmentItem,
    )
        ? proficiencyBonus
        : 0;

    final itemAttackBonus = resolvedWeapon.equipmentItem?.attackBonus ?? 0;
    final optionAttackBonus =
        CharacterOptionEffects.getMainHandAttackBonusFromOptions(
      character: character,
      isRangedWeapon: weaponItem.isRanged,
    );
    final pactAttackBonus = CharacterOptionEffects.getPactWeaponAttackBonus(
      character: character,
      weaponItem: weaponItem,
      equipmentItem: resolvedWeapon.equipmentItem,
    );
    final infusedWeaponAttackBonus =
        CharacterOptionEffects.getInfusedWeaponAttackBonus(
      character: character,
      weaponItem: weaponItem,
    );

    return abilityMod +
        proficiency +
        itemAttackBonus +
        optionAttackBonus +
        pactAttackBonus +
        infusedWeaponAttackBonus;
  }

  static int mainHandDamageBonus({
    required Character character,
    required ResolvedInventoryItem resolvedWeapon,
    required bool hasOffHandWeaponEquipped,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
    required int Function(String ability) getAbilityScore,
    required int Function(int score) getAbilityModifier,
  }) {
    final weaponItem = resolvedWeapon.effectiveItem;
    final abilityMod = attackAbilityModifier(
      character: character,
      weaponItem: weaponItem,
      getAbilityScore: getAbilityScore,
      getAbilityModifier: getAbilityModifier,
    );
    final itemDamageBonus = resolvedWeapon.equipmentItem?.damageBonus ?? 0;
    final conditionalDamageBonus =
        CharacterEquipmentEffects.getMainHandConditionalDamageBonus(
      char: character,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
    final isMeleeWeapon = !weaponItem.isRanged;
    final isOneHandedMeleeWeapon =
        !weaponItem.isTwoHanded && !weaponItem.isRanged;
    final optionDamageBonus =
        CharacterOptionEffects.getMainHandDamageBonusFromOptions(
      character: character,
      isMeleeWeapon: isMeleeWeapon,
      isOneHandedMeleeWeapon: isOneHandedMeleeWeapon,
      hasOffHandWeaponEquipped: hasOffHandWeaponEquipped,
    );
    final chaMod = getAbilityModifier(getAbilityScore('CHA'));
    final pactDamageBonus = CharacterOptionEffects.getPactWeaponDamageBonus(
      character: character,
      weaponItem: weaponItem,
      equipmentItem: resolvedWeapon.equipmentItem,
      charismaModifier: chaMod,
    );
    final infusedWeaponDamageBonus =
        CharacterOptionEffects.getInfusedWeaponDamageBonus(
      character: character,
      weaponItem: weaponItem,
    );

    return abilityMod +
        itemDamageBonus +
        conditionalDamageBonus +
        optionDamageBonus +
        pactDamageBonus +
        infusedWeaponDamageBonus;
  }

  static String damageText({
    required CharacterInventoryItem weaponItem,
    required int damageBonus,
    required String fallback,
  }) {
    final damageDice = weaponItem.damageDice?.trim();
    if (damageDice == null || damageDice.isEmpty) return fallback;

    final damageType = weaponItem.damageType?.trim();
    final bonusText = damageBonus == 0
        ? ''
        : (damageBonus > 0 ? ' + $damageBonus' : ' - ${damageBonus.abs()}');

    if (damageType != null && damageType.isNotEmpty) {
      return '$damageDice$bonusText $damageType';
    }

    return '$damageDice$bonusText';
  }

  static int parseDiceSides(String damageDice) {
    final match = _dicePattern.firstMatch(damageDice.trim().toLowerCase());
    if (match == null) return 0;
    return int.tryParse(match.group(2) ?? '') ?? 0;
  }

  static int parseDiceCount(String damageDice) {
    final match = _dicePattern.firstMatch(damageDice.trim().toLowerCase());
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  static final RegExp _dicePattern = RegExp(r'^(\d+)d(\d+)$');
}
