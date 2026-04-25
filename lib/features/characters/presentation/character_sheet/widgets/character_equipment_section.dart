import 'package:flutter/material.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Equipment',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: isLargeTablet ? 22 : (isTablet ? 20 : 18),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (pactWeaponSection != null) ...[
          pactWeaponSection!,
          const SizedBox(height: 16),
        ],
        GridView.builder(
          itemCount: slots.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isLargeTablet ? 3 : (isTablet ? 2 : 1),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: isLargeTablet ? 238 : (isTablet ? 226 : 214),
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
    final item = slot.item;
    final description = item == null ? null : buildDescription(item);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            slot.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item?.effectiveItem.name ?? 'Empty',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 15 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (item != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.sourceLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (slot.metaLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                slot.metaLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (description != null) ...[
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
          const Spacer(),
          if (item != null && slot.onUnequip != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: slot.onUnequip,
                icon: const Icon(Icons.close),
                label: const Text('Unequip'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
