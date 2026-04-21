import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../models/spell.dart';

class SpellProvider with ChangeNotifier {
  List<Spell> _spells = [];
  bool _isLoaded = false;

  List<Spell> get spells => _spells;
  bool get isLoaded => _isLoaded;

  // 🔹 Cargar JSON una sola vez
  Future<void> loadSpells() async {
    if (_isLoaded) return;

    final String jsonString =
        await rootBundle.loadString('assets/data/spells_enriched.json');

    final List<dynamic> jsonData = json.decode(jsonString);

    _spells = jsonData.map((e) => Spell.fromJson(e)).toList();

    _isLoaded = true;
    notifyListeners();
  }

  // 🔹 Buscar por nombre
  List<Spell> searchSpells(String query) {
    if (query.isEmpty) return _spells;

    return _spells
        .where(
            (spell) => spell.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // 🔹 Filtrar por nivel
  List<Spell> filterByLevel(int level) {
    return _spells.where((spell) => spell.level == level).toList();
  }

  // 🔹 Obtener por ID
  Spell? getById(String id) {
    try {
      return _spells.firstWhere((spell) => spell.id == id);
    } catch (e) {
      return null;
    }
  }
}
