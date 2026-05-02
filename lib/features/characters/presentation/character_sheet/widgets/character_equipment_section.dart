import 'package:flutter/material.dart';

import '../../../../../theme.dart';
import '../../../models/resolved_inventory_item.dart';

class CharacterEquipmentSection extends StatelessWidget {
  final bool isTablet;
  final bool isLargeTablet;
  final Widget? pactWeaponSection;
  final List<CharacterEquipmentSlotViewData> slots;
  final String? Function(ResolvedInventoryItem item) buildDescription;

  const CharacterEquipmentSection({
    super.key,
    required this.isTablet,
    required this.isLargeTablet,
    required this.slots,
    required this.buildDescription,
    this.pactWeaponSection,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final filledSlots = slots.where((slot) => slot.item != null).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentRead.withValues(alpha: 0.24)),
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
                  color: tokens.accentRead.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: tokens.accentRead.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: tokens.accentReadSoft,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EQUIPPED LOADOUT',
                      style: TextStyle(
                        color: tokens.accentReadSoft.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$filledSlots / ${slots.length} slots filled',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pactWeaponSection != null) ...[
            const SizedBox(height: 12),
            pactWeaponSection!,
          ],
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: slots.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLargeTablet ? 3 : (isTablet ? 2 : 1),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: isLargeTablet ? 206 : (isTablet ? 196 : 176),
            ),
            itemBuilder: (_, index) {
              final slot = slots[index];
              return _EquipmentSlotCard(
                slot: slot,
                isTablet: isTablet,
                buildDescription: buildDescription,
              );
            },
          ),
        ],
      ),
    );
  }
}

class CharacterEquipmentSlotViewData {
  final String label;
  final ResolvedInventoryItem? item;
  final String metaLabel;
  final VoidCallback? onUnequip;

  const CharacterEquipmentSlotViewData({
    required this.label,
    required this.item,
    required this.metaLabel,
    required this.onUnequip,
  });
}

class _EquipmentSlotCard extends StatelessWidget {
  final CharacterEquipmentSlotViewData slot;
  final bool isTablet;
  final String? Function(ResolvedInventoryItem item) buildDescription;

  const _EquipmentSlotCard({
    required this.slot,
    required this.isTablet,
    required this.buildDescription,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final item = slot.item;
    final description = item == null ? null : buildDescription(item);
    final accent = item == null ? tokens.textMuted : _slotAccent(item, tokens);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: item == null
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B2230),
                  Color(0xFF111720),
                ],
              ),
        color: item == null ? tokens.surface : null,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: accent.withValues(alpha: item == null ? 0.16 : 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: item == null ? 0.07 : 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: accent.withValues(alpha: item == null ? 0.12 : 0.24),
                  ),
                ),
                child: Icon(
                  _slotIcon(slot.label),
                  color: item == null ? tokens.textMuted : accent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slot.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item?.effectiveItem.name ?? 'Empty',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: isTablet ? 15 : 14,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (item != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _EquipmentPill(
                  text: item.sourceLabel,
                  color: accent,
                ),
                if (slot.metaLabel.isNotEmpty)
                  _EquipmentPill(
                    text: slot.metaLabel,
                    color: tokens.accentInfo,
                  ),
              ],
            ),
            if (description != null && description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'No item assigned to this slot.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          if (item != null && slot.onUnequip != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: slot.onUnequip,
                icon: const Icon(Icons.close, size: 17),
                label: const Text('Unequip'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: accent.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _slotIcon(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('hand')) return Icons.gavel_outlined;
    if (normalized.contains('armor')) return Icons.shield_outlined;
    if (normalized.contains('shield')) return Icons.security_outlined;
    if (normalized.contains('accessory')) return Icons.diamond_outlined;
    return Icons.inventory_2_outlined;
  }

  Color _slotAccent(ResolvedInventoryItem item, StitchThemeTokens tokens) {
    final equipment = item.equipmentItem;
    final effective = item.effectiveItem;
    if (equipment?.isMagic == true ||
        (effective.appliedInfusionId ?? '').trim().isNotEmpty) {
      return tokens.accentMagic;
    }
    if (equipment?.isWeapon == true || effective.itemType.name == 'weapon') {
      return tokens.accentAction;
    }
    if (equipment?.isArmor == true ||
        equipment?.isShield == true ||
        effective.itemType.name == 'armor' ||
        effective.itemType.name == 'shield') {
      return tokens.accentRead;
    }
    return tokens.accentInfo;
  }
}

class _EquipmentPill extends StatelessWidget {
  final String text;
  final Color color;

  const _EquipmentPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
