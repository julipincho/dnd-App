import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/character_option_category.dart';
import '../models/character_option_definition.dart';

class CharacterOptionsRepository {
  CharacterOptionsRepository._();

  static final CharacterOptionsRepository instance =
      CharacterOptionsRepository._();

  static const String _infusionsPath =
      'assets/data/artificer_infusions_2014_v2.json';
  static const String _invocationsPath =
      'assets/data/eldritch_invocations_2014_v2.json';
  static const String _fightingStylesPath =
      'assets/data/fighting_styles_2014_v2.json';
  static const String _maneuversPath = 'assets/data/maneuvers_2014_v2.json';
  static const String _metamagicPath = 'assets/data/metamagic_2014_v2.json';
  static const String _warlockBoonsPath =
      'assets/data/class_options/warlock_pact_boons_2014_v1.json';
  bool _isLoaded = false;

  final List<CharacterOptionDefinition> _allOptions = [];
  final Map<String, CharacterOptionDefinition> _byId = {};
  final Map<CharacterOptionCategory, List<CharacterOptionDefinition>>
      _byCategory = {};

  Future<void> loadAll() async {
    if (_isLoaded) return;

    final results = await Future.wait([
      _loadCategoryFile(
        path: _infusionsPath,
        fallbackCategory: CharacterOptionCategory.infusion,
      ),
      _loadCategoryFile(
        path: _invocationsPath,
        fallbackCategory: CharacterOptionCategory.invocation,
      ),
      _loadCategoryFile(
        path: _fightingStylesPath,
        fallbackCategory: CharacterOptionCategory.fightingStyle,
      ),
      _loadCategoryFile(
        path: _maneuversPath,
        fallbackCategory: CharacterOptionCategory.maneuver,
      ),
      _loadCategoryFile(
        path: _metamagicPath,
        fallbackCategory: CharacterOptionCategory.metamagic,
      ),
      _loadCategoryFile(
        path: _warlockBoonsPath,
        fallbackCategory: CharacterOptionCategory.pactBoon,
      ),
    ]);

    _allOptions
      ..clear()
      ..addAll(results.expand((e) => e));

    _rebuildIndexes();
    print('Total options loaded: ${_allOptions.length}');
    print(
      'Pact boons loaded: ${_byCategory[CharacterOptionCategory.pactBoon]?.length ?? 0}',
    );
    print(
      'Pact boons: ${(_byCategory[CharacterOptionCategory.pactBoon] ?? []).map((e) => e.name).toList()}',
    );
    _isLoaded = true;
  }

  Future<void> reloadAll() async {
    _isLoaded = false;
    _allOptions.clear();
    _byId.clear();
    _byCategory.clear();
    await loadAll();
  }

  List<CharacterOptionDefinition> getAll() {
    return List.unmodifiable(_allOptions);
  }

  List<CharacterOptionDefinition> getByCategory(
    CharacterOptionCategory category,
  ) {
    final items = _byCategory[category] ?? const [];
    return List.unmodifiable(items);
  }

  CharacterOptionDefinition? getById(String id) {
    return _byId[id];
  }

  bool containsId(String id) {
    return _byId.containsKey(id);
  }

  List<CharacterOptionDefinition> searchByName(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getAll();

    return List.unmodifiable(
      _allOptions.where((option) {
        return option.name.toLowerCase().contains(q);
      }),
    );
  }

  List<CharacterOptionDefinition> getManyByIds(List<String> ids) {
    final result = <CharacterOptionDefinition>[];

    for (final id in ids) {
      final option = _byId[id];
      if (option != null) {
        result.add(option);
      }
    }

    return List.unmodifiable(result);
  }

  Future<List<CharacterOptionDefinition>> _loadCategoryFile({
    required String path,
    required CharacterOptionCategory fallbackCategory,
  }) async {
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw);

    if (decoded is! List) {
      throw FormatException(
        'El archivo $path no contiene una lista JSON válida.',
      );
    }

    return decoded.map<CharacterOptionDefinition>((entry) {
      final map = Map<String, dynamic>.from(entry as Map);

      // Si el archivo no trae "category", la inferimos por el archivo.
      map.putIfAbsent('category', () => fallbackCategory.key);

      return CharacterOptionDefinition.fromJson(map);
    }).toList();
  }

  void _rebuildIndexes() {
    _byId.clear();
    _byCategory.clear();

    for (final option in _allOptions) {
      _byId[option.id] = option;
      _byCategory.putIfAbsent(option.category, () => []);
      _byCategory[option.category]!.add(option);
    }

    for (final entry in _byCategory.entries) {
      entry.value.sort((a, b) => a.name.compareTo(b.name));
    }

    _allOptions.sort((a, b) {
      final categoryCompare = a.category.key.compareTo(b.category.key);
      if (categoryCompare != 0) return categoryCompare;
      return a.name.compareTo(b.name);
    });
  }
}
