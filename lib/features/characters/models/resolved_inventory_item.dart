import '../../../models/character_inventory_item.dart';
import '../../../models/compendium_entry.dart';
import '../../../models/equipment_compendium_item.dart';

class ResolvedInventoryItem {
  final CharacterInventoryItem originalItem;
  final CharacterInventoryItem effectiveItem;
  final EquipmentCompendiumItem? equipmentItem;
  final CompendiumEntry? campaignEntry;
  final String sourceLabel;
  final String? resolvedDescription;
  final String? resolvedImagePath;

  const ResolvedInventoryItem({
    required this.originalItem,
    required this.effectiveItem,
    required this.equipmentItem,
    required this.campaignEntry,
    required this.sourceLabel,
    required this.resolvedDescription,
    required this.resolvedImagePath,
  });
}
