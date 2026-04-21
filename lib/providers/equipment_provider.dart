import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/equipment_compendium_item.dart';

class EquipmentProvider extends ChangeNotifier {
  final List<EquipmentCompendiumItem> _items = [];
  bool _isLoaded = false;

  List<EquipmentCompendiumItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _isLoaded;

  List<EquipmentCompendiumItem> get equippableItems =>
      _items.where((item) => item.isEquippable).toList();

  List<EquipmentCompendiumItem> get weapons =>
      _items.where((item) => item.isWeapon).toList();

  List<EquipmentCompendiumItem> get armors =>
      _items.where((item) => item.isArmor).toList();

  List<EquipmentCompendiumItem> get shields =>
      _items.where((item) => item.isShield).toList();

  List<EquipmentCompendiumItem> get accessories =>
      _items.where((item) => item.isAccessory).toList();

  Future<void> loadEquipment() async {
    if (_isLoaded) return;

    try {
      final rawJson = await rootBundle.loadString(
        'assets/data/equipment_final_2014_enriched.json',
      );

      final decoded = jsonDecode(rawJson);

      if (decoded is! List) {
        throw Exception('equipment_final_2014.json must contain a JSON list.');
      }

      _items
        ..clear()
        ..addAll(
          decoded.map(
            (item) => EquipmentCompendiumItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );

      _items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      _isLoaded = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error loading equipment_final_2014.json: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> reloadEquipment() async {
    _isLoaded = false;
    _items.clear();
    notifyListeners();
    await loadEquipment();
  }

  EquipmentCompendiumItem? getById(String id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  List<EquipmentCompendiumItem> getByIds(List<String> ids) {
    final idSet = ids.toSet();
    return _items.where((item) => idSet.contains(item.id)).toList();
  }

  List<EquipmentCompendiumItem> searchByName(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return items;

    return _items
        .where((item) => item.name.toLowerCase().contains(normalized))
        .toList();
  }

  List<EquipmentCompendiumItem> getByType(String type) {
    final normalized = type.trim().toLowerCase();

    return _items
        .where((item) => item.type.trim().toLowerCase() == normalized)
        .toList();
  }

  List<EquipmentCompendiumItem> getByAllowedSlot(String slotName) {
    final normalized = slotName.trim();

    return _items
        .where((item) => item.allowedSlots.contains(normalized))
        .toList();
  }

  EquipmentCompendiumItem? getFromInventoryCompendiumId(
      String? compendiumEntryId) {
    if (compendiumEntryId == null || compendiumEntryId.trim().isEmpty) {
      return null;
    }

    return getById(compendiumEntryId);
  }
}
