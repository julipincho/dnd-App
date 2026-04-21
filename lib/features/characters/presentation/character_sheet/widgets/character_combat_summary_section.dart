import 'package:flutter/material.dart';

import '../../../../../models/character.dart';
import '../../../../../models/character_inventory_item.dart';
import '../../../../../providers/compendium_provider.dart';
import '../../../../../providers/equipment_provider.dart';
import '../../../models/resolved_inventory_item.dart';

class CharacterCombatSummarySection extends StatelessWidget {
  final Character char;
  final EquipmentProvider equipmentProvider;
  final CompendiumProvider compendiumProvider;
  final bool isTablet;
  final bool isLargeTablet;

  final ResolvedInventoryItem? Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) resolveEquippedMainHandItem;

  final bool Function(ResolvedInventoryItem? item) isMainHandWeapon;
  final bool Function(ResolvedInventoryItem? item) isMainHandFocus;

  final CharacterInventoryItem? Function(Character char, String? itemId)
      findInventoryItemById;

  final ResolvedInventoryItem Function(
    CharacterInventoryItem item,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) resolveInventoryItem;

  final int? Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) calculateMainHandAttackBonus;

  final String Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) buildMainHandDamageText;

  final String Function(
    Character char,
    CharacterInventoryItem weaponItem,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) getWeaponAttackAbilityLabel;

  final int Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) computeSpellAttackBonus;

  final String? Function(Character char) normalizedSpellcastingAbility;

  final Future<void> Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) rollMainHandAttack;

  final Future<void> Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) rollMainHandDamage;

  final String Function(int value) formatSigned;

  const CharacterCombatSummarySection({
    super.key,
    required this.char,
    required this.equipmentProvider,
    required this.compendiumProvider,
    required this.isTablet,
    required this.isLargeTablet,
    required this.resolveEquippedMainHandItem,
    required this.isMainHandWeapon,
    required this.isMainHandFocus,
    required this.findInventoryItemById,
    required this.resolveInventoryItem,
    required this.calculateMainHandAttackBonus,
    required this.buildMainHandDamageText,
    required this.getWeaponAttackAbilityLabel,
    required this.computeSpellAttackBonus,
    required this.normalizedSpellcastingAbility,
    required this.rollMainHandAttack,
    required this.rollMainHandDamage,
    required this.formatSigned,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedMainHand = resolveEquippedMainHandItem(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    final isWeapon =
        resolvedMainHand != null && isMainHandWeapon(resolvedMainHand);
    final isFocus =
        resolvedMainHand != null && isMainHandFocus(resolvedMainHand);

    final rawArmor = findInventoryItemById(char, char.equippedArmorItemId);
    final rawShield = findInventoryItemById(char, char.equippedShieldItemId);

    final resolvedArmor = rawArmor == null
        ? null
        : resolveInventoryItem(
            rawArmor,
            equipmentProvider,
            compendiumProvider,
          );

    final resolvedShield = rawShield == null
        ? null
        : resolveInventoryItem(
            rawShield,
            equipmentProvider,
            compendiumProvider,
          );

    final int? attackBonus = isWeapon
        ? calculateMainHandAttackBonus(
            char,
            equipmentProvider,
            compendiumProvider,
          )
        : null;

    final String damageText = isWeapon
        ? buildMainHandDamageText(
            char,
            equipmentProvider,
            compendiumProvider,
          )
        : '—';

    final CharacterInventoryItem? mainHandInventoryItem =
        findInventoryItemById(char, char.equippedMainHandItemId);

    final String attackAbilityLabel = isWeapon && mainHandInventoryItem != null
        ? getWeaponAttackAbilityLabel(
            char,
            mainHandInventoryItem,
            equipmentProvider,
            compendiumProvider,
          )
        : '—';

    final int? computedSpellAttackBonus = isFocus
        ? computeSpellAttackBonus(
            char,
            equipmentProvider,
            compendiumProvider,
          )
        : null;

    final String spellAbility =
        isFocus ? (normalizedSpellcastingAbility(char) ?? '—') : '—';

    String armorText = 'Unarmored';
    if (resolvedArmor != null) {
      final armor = resolvedArmor.effectiveItem;
      if (armor.baseArmorClass != null) {
        armorText =
            '${resolvedArmor.effectiveItem.name} • AC ${armor.baseArmorClass}';
      } else {
        armorText = resolvedArmor.effectiveItem.name;
      }
    }

    String shieldText = 'None';
    if (resolvedShield != null) {
      final shieldBonus = resolvedShield.effectiveItem.armorClassBonus ?? 0;
      shieldText = shieldBonus > 0
          ? '${resolvedShield.effectiveItem.name} • +$shieldBonus AC'
          : resolvedShield.effectiveItem.name;
    }

    String mainHandLabel = 'None equipped';
    if (resolvedMainHand != null) {
      mainHandLabel = resolvedMainHand.effectiveItem.name;
    }

    String mainHandTypeText = '—';
    if (resolvedMainHand != null) {
      if (isFocus) {
        final displayCategory =
            resolvedMainHand.equipmentItem?.displayCategory.trim();
        mainHandTypeText =
            (displayCategory != null && displayCategory.isNotEmpty)
                ? displayCategory
                : 'Arcane Focus';
      } else if (isWeapon) {
        final displayCategory =
            resolvedMainHand.equipmentItem?.displayCategory.trim();
        mainHandTypeText =
            (displayCategory != null && displayCategory.isNotEmpty)
                ? displayCategory
                : 'Weapon';
      }
    }

    Widget statTile({
      required String label,
      required String value,
      IconData? icon,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF262632),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.deepPurpleAccent.withOpacity(0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(height: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 15 : 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Combat Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: isLargeTablet ? 18 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: isLargeTablet ? 3 : (isTablet ? 2 : 1),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isLargeTablet ? 2.2 : 2.5,
            children: [
              statTile(
                label: 'Main Hand',
                value: mainHandLabel,
                icon: isFocus ? Icons.auto_awesome : Icons.gavel_outlined,
              ),
              statTile(
                label: 'Type',
                value: mainHandTypeText,
                icon: isFocus
                    ? Icons.menu_book_outlined
                    : Icons.category_outlined,
              ),
              statTile(
                label: isFocus ? 'Spell Attack' : 'Attack Bonus',
                value: isFocus
                    ? (computedSpellAttackBonus == null
                        ? '—'
                        : formatSigned(computedSpellAttackBonus))
                    : (attackBonus == null ? '—' : formatSigned(attackBonus)),
                icon: isFocus
                    ? Icons.bolt_outlined
                    : Icons.track_changes_outlined,
              ),
              statTile(
                label: isFocus ? 'Spellcasting Stat' : 'Attack Stat',
                value: isFocus ? spellAbility : attackAbilityLabel,
                icon: Icons.fitness_center_outlined,
              ),
              statTile(
                label: isFocus ? 'Weapon Damage' : 'Damage',
                value: isFocus ? '—' : damageText,
                icon: Icons.auto_fix_high_outlined,
              ),
              statTile(
                label: 'Armor',
                value: armorText,
                icon: Icons.shield_outlined,
              ),
              statTile(
                label: 'Shield',
                value: shieldText,
                icon: Icons.security_outlined,
              ),
            ],
          ),
          if (isWeapon && resolvedMainHand != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => rollMainHandAttack(
                    char,
                    equipmentProvider,
                    compendiumProvider,
                  ),
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Roll Attack'),
                ),
                OutlinedButton.icon(
                  onPressed: () => rollMainHandDamage(
                    char,
                    equipmentProvider,
                    compendiumProvider,
                  ),
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  label: const Text('Roll Damage'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
