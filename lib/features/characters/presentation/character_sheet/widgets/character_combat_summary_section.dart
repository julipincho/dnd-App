import 'package:flutter/material.dart';

import '../../../../../models/character.dart';
import '../../../../../models/character_inventory_item.dart';
import '../../../../../providers/compendium_provider.dart';
import '../../../../../providers/equipment_provider.dart';
import '../../../models/resolved_inventory_item.dart';

class CharacterCombatSummarySection extends StatelessWidget {
  static const Color _panelColor = Color(0xFF151922);
  static const Color _accentColor = Color(0xFFE14658);
  static const Color _supportColor = Color(0xFF8BAA6F);

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

    final mainHandInventoryItem =
        findInventoryItemById(char, char.equippedMainHandItemId);

    final attackBonus = isWeapon
        ? calculateMainHandAttackBonus(
            char,
            equipmentProvider,
            compendiumProvider,
          )
        : null;

    final damageText = isWeapon
        ? buildMainHandDamageText(
            char,
            equipmentProvider,
            compendiumProvider,
          )
        : '-';

    final attackAbilityLabel = isWeapon && mainHandInventoryItem != null
        ? getWeaponAttackAbilityLabel(
            char,
            mainHandInventoryItem,
            equipmentProvider,
            compendiumProvider,
          )
        : '-';

    final spellAttackBonus = isFocus
        ? computeSpellAttackBonus(
            char,
            equipmentProvider,
            compendiumProvider,
          )
        : null;

    final spellAbility =
        isFocus ? (normalizedSpellcastingAbility(char) ?? '-') : '-';

    final armorText = _armorLabel(resolvedArmor);
    final shieldText = _shieldLabel(resolvedShield);
    final mainHandLabel = resolvedMainHand?.effectiveItem.name ?? 'None';
    final mainHandType = _mainHandTypeLabel(
      resolvedMainHand,
      isWeapon: isWeapon,
      isFocus: isFocus,
    );

    final primaryAction = isWeapon
        ? _CombatPrimaryAction.weapon(
            title: mainHandLabel,
            subtitle: mainHandType,
            attackBonus: attackBonus == null ? '-' : formatSigned(attackBonus),
            damage: damageText,
            ability: attackAbilityLabel,
            onAttack: () => rollMainHandAttack(
              char,
              equipmentProvider,
              compendiumProvider,
            ),
            onDamage: () => rollMainHandDamage(
              char,
              equipmentProvider,
              compendiumProvider,
            ),
          )
        : isFocus
            ? _CombatPrimaryAction.focus(
                title: mainHandLabel,
                subtitle: mainHandType,
                attackBonus: spellAttackBonus == null
                    ? '-'
                    : formatSigned(spellAttackBonus),
                ability: spellAbility,
              )
            : const _CombatPrimaryAction.empty();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _supportColor.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.sports_martial_arts_outlined,
                  color: _accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ACTIONS & COMBAT',
                  style: TextStyle(
                    color: _supportColor.withValues(alpha: 0.88),
                    fontSize: isLargeTablet ? 12 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _CompactBadge(
                label: isWeapon
                    ? 'Weapon'
                    : isFocus
                        ? 'Spell Focus'
                        : 'No Action',
                color: isWeapon || isFocus
                    ? Colors.deepPurpleAccent
                    : Colors.white54,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PrimaryActionCard(
            action: primaryAction,
            isTablet: isTablet,
          ),
          const SizedBox(height: 12),
          _CombatMetricsGrid(
            isTablet: isTablet,
            isLargeTablet: isLargeTablet,
            children: [
              _CombatMetricTile(
                label: 'Main Hand',
                value: mainHandLabel,
                icon: isFocus ? Icons.auto_awesome : Icons.gavel_outlined,
              ),
              _CombatMetricTile(
                label: 'Attack',
                value: isFocus
                    ? (spellAttackBonus == null
                        ? '-'
                        : formatSigned(spellAttackBonus))
                    : (attackBonus == null ? '-' : formatSigned(attackBonus)),
                icon: isFocus
                    ? Icons.bolt_outlined
                    : Icons.track_changes_outlined,
              ),
              _CombatMetricTile(
                label: isFocus ? 'Casting Stat' : 'Attack Stat',
                value: isFocus ? spellAbility : attackAbilityLabel,
                icon: Icons.fitness_center_outlined,
              ),
              _CombatMetricTile(
                label: 'Damage',
                value: isFocus ? '-' : damageText,
                icon: Icons.auto_fix_high_outlined,
              ),
              _CombatMetricTile(
                label: 'Armor',
                value: armorText,
                icon: Icons.shield_outlined,
              ),
              _CombatMetricTile(
                label: 'Shield',
                value: shieldText,
                icon: Icons.security_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _armorLabel(ResolvedInventoryItem? resolvedArmor) {
    if (resolvedArmor == null) return 'Unarmored';

    final armor = resolvedArmor.effectiveItem;
    if (armor.baseArmorClass != null) {
      return '${armor.name} - AC ${armor.baseArmorClass}';
    }

    return armor.name;
  }

  String _shieldLabel(ResolvedInventoryItem? resolvedShield) {
    if (resolvedShield == null) return 'None';

    final shield = resolvedShield.effectiveItem;
    final shieldBonus = shield.armorClassBonus ?? 0;
    if (shieldBonus > 0) {
      return '${shield.name} - +$shieldBonus AC';
    }

    return shield.name;
  }

  String _mainHandTypeLabel(
    ResolvedInventoryItem? resolvedMainHand, {
    required bool isWeapon,
    required bool isFocus,
  }) {
    if (resolvedMainHand == null) return '-';

    final displayCategory =
        resolvedMainHand.equipmentItem?.displayCategory.trim();
    if (displayCategory != null && displayCategory.isNotEmpty) {
      return displayCategory;
    }

    if (isFocus) return 'Spell Focus';
    if (isWeapon) return 'Weapon';
    return resolvedMainHand.sourceLabel;
  }
}

class _CombatPrimaryAction {
  final String title;
  final String subtitle;
  final String attackBonus;
  final String damage;
  final String ability;
  final bool canRollDamage;
  final VoidCallback? onAttack;
  final VoidCallback? onDamage;

  const _CombatPrimaryAction({
    required this.title,
    required this.subtitle,
    required this.attackBonus,
    required this.damage,
    required this.ability,
    required this.canRollDamage,
    this.onAttack,
    this.onDamage,
  });

  factory _CombatPrimaryAction.weapon({
    required String title,
    required String subtitle,
    required String attackBonus,
    required String damage,
    required String ability,
    required VoidCallback onAttack,
    required VoidCallback onDamage,
  }) {
    return _CombatPrimaryAction(
      title: title,
      subtitle: subtitle,
      attackBonus: attackBonus,
      damage: damage,
      ability: ability,
      canRollDamage: true,
      onAttack: onAttack,
      onDamage: onDamage,
    );
  }

  factory _CombatPrimaryAction.focus({
    required String title,
    required String subtitle,
    required String attackBonus,
    required String ability,
  }) {
    return _CombatPrimaryAction(
      title: title,
      subtitle: subtitle,
      attackBonus: attackBonus,
      damage: '-',
      ability: ability,
      canRollDamage: false,
    );
  }

  const _CombatPrimaryAction.empty()
      : title = 'No primary action equipped',
        subtitle = 'Equip a weapon or spell focus to surface combat actions.',
        attackBonus = '-',
        damage = '-',
        ability = '-',
        canRollDamage = false,
        onAttack = null,
        onDamage = null;
}

class _PrimaryActionCard extends StatelessWidget {
  final _CombatPrimaryAction action;
  final bool isTablet;

  const _PrimaryActionCard({
    required this.action,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2230),
            Color(0xFF111720),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE14658).withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.sports_martial_arts_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CompactBadge(
                label: 'Attack ${action.attackBonus}',
                color: Colors.redAccent,
              ),
              _CompactBadge(
                label: 'Damage ${action.damage}',
                color: Colors.deepPurpleAccent,
              ),
              _CompactBadge(
                label: action.ability,
                color: Colors.blueAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: action.onAttack,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Attack'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE14658),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: action.canRollDamage ? action.onDamage : null,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Damage'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.28),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CombatMetricsGrid extends StatelessWidget {
  final bool isTablet;
  final bool isLargeTablet;
  final List<Widget> children;

  const _CombatMetricsGrid({
    required this.isTablet,
    required this.isLargeTablet,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isLargeTablet ? 3 : (isTablet ? 2 : 1);
        const spacing = 12.0;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CombatMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CombatMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111720),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF8BAA6F).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF8BAA6F).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFB7D28A), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CompactBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.34),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
