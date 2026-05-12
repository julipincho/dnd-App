import '../models/character.dart';
import '../models/feat_data.dart';

class FeatSyncService {
  static void applyFeatsToCharacter({
    required Character character,
    required List<FeatData> feats,
  }) {
    _ensureMutableFeatCollections(character);
    _clearPreviousFeatDerivedData(character);

    for (final feat in feats) {
      _applyAbilityIncreases(character, feat);
      _applyArmorProficiencies(character, feat);
      _applyWeaponProficiencies(character, feat);
      _applyToolProficiencies(character, feat);
      _applyLanguageProficiencies(character, feat);
      _applyResistances(character, feat);
      _applyImmunities(character, feat);
      _applyConditionImmunities(character, feat);
      _applySenses(character, feat);
      _applySimpleModifiers(character, feat);
      _applyAdditionalSpells(character, feat);
    }
  }

  static void _clearPreviousFeatDerivedData(Character character) {
    character.featAbilityBonuses = {
      'STR': 0,
      'DEX': 0,
      'CON': 0,
      'INT': 0,
      'WIS': 0,
      'CHA': 0,
    };
    character.featArmorProficiencies = [];
    character.featWeaponProficiencies = [];
    character.featToolProficiencies = [];
    character.featLanguageProficiencies = [];
    character.featResistances = [];
    character.featImmunities = [];
    character.featConditionImmunities = [];
    character.featSenses = [];

    character.featInitiativeBonus = 0;
    character.featSpeedBonus = 0;

    character.cannotBeSurprisedWhileConscious = false;
    character.unseenAttackersNoAdvantage = false;

    character.conditionalArmorClassBonus = 0;
    character.conditionalArmorClassBonusCondition = null;

    character.damageReductionWhileWearingHeavyArmor = null;

    final featGrantedKnownSpellIds = <String>{};
    final featGrantedPreparedSpellIds = <String>{};
    final featGrantedSpellIds = <String>{};

    for (final entry in character.featSelections.entries.toList()) {
      final value = entry.value;
      if (value is! Map) continue;

      final map = Map<String, dynamic>.from(value);

      final known = map['grantedKnownSpellIds'];
      if (known is List) {
        for (final spellId in known) {
          featGrantedKnownSpellIds.add(spellId.toString());
          featGrantedSpellIds.add(spellId.toString());
        }
      }

      final prepared = map['grantedPreparedSpellIds'];
      if (prepared is List) {
        for (final spellId in prepared) {
          featGrantedPreparedSpellIds.add(spellId.toString());
          featGrantedSpellIds.add(spellId.toString());
        }
      }

      final grantedSpellIds = map['grantedSpellIds'];
      if (grantedSpellIds is List) {
        for (final spellId in grantedSpellIds) {
          featGrantedSpellIds.add(spellId.toString());
        }
      }

      final daily = map['grantedDailySpellId'];
      if (daily != null) {
        featGrantedSpellIds.add(daily.toString());
      }

      final dailyList = map['grantedDailySpellIds'];
      if (dailyList is List) {
        for (final spellId in dailyList) {
          featGrantedSpellIds.add(spellId.toString());
        }
      }
      final selectedCantripId = map['selectedCantripId'];
      if (selectedCantripId != null &&
          selectedCantripId.toString().trim().isNotEmpty) {
        featGrantedSpellIds.add(selectedCantripId.toString().trim());
      }

      final selectedSpellId = map['selectedSpellId'];
      if (selectedSpellId != null &&
          selectedSpellId.toString().trim().isNotEmpty) {
        featGrantedSpellIds.add(selectedSpellId.toString().trim());
      }

      final selectedPreparedSpellId = map['selectedPreparedSpellId'];
      if (selectedPreparedSpellId != null &&
          selectedPreparedSpellId.toString().trim().isNotEmpty) {
        featGrantedSpellIds.add(selectedPreparedSpellId.toString().trim());
        featGrantedPreparedSpellIds
            .add(selectedPreparedSpellId.toString().trim());
      }

      map.remove('grantedKnownSpellIds');
      map.remove('grantedPreparedSpellIds');
      map.remove('grantedSpellIds');
      map.remove('grantedDailySpellId');
      map.remove('grantedDailySpellIds');
      map.remove('grantedSpellcastingAbility');
      map.remove('grantedDailySpellUses');
      map.remove('grantedDailySpellCastMode');

      character.featSelections[entry.key] = map;
    }

    character.knownSpells
        .removeWhere((spellId) => featGrantedKnownSpellIds.contains(spellId));

    character.preparedSpellIds.removeWhere(
        (spellId) => featGrantedPreparedSpellIds.contains(spellId));

    character.preparedSpells.removeWhere(
        (spellId) => featGrantedPreparedSpellIds.contains(spellId));

    character.spellIds
        .removeWhere((spellId) => featGrantedSpellIds.contains(spellId));
  }

  static void _ensureMutableFeatCollections(Character character) {
    character.knownSpells = List<String>.from(character.knownSpells);
    character.preparedSpellIds = List<String>.from(character.preparedSpellIds);
    character.preparedSpells = List<String>.from(character.preparedSpells);
    character.spellIds = List<String>.from(character.spellIds);
    character.featSelections = Map<String, dynamic>.from(
      character.featSelections,
    );
  }

  static void _applyAbilityIncreases(Character character, FeatData feat) {
    for (final entry in feat.abilityIncreases) {
      if (entry is! Map) continue;

      final map = Map<String, dynamic>.from(entry);

      for (final kv in map.entries) {
        final key = kv.key;
        final value = kv.value;

        if (value is int) {
          _increaseAbility(character, key, value);
        }
      }

      if (map.containsKey('choose')) {
        final choose = map['choose'];
        if (choose is Map) {
          final selection = character.featSelections[feat.id];
          if (selection is Map && selection['chosenAbility'] != null) {
            final chosenAbility = selection['chosenAbility'].toString();
            final amount =
                (choose['amount'] is int) ? choose['amount'] as int : 1;
            _increaseAbility(character, chosenAbility, amount);
          }
        }
      }
    }
  }

  static void _increaseAbility(
    Character character,
    String ability,
    int amount,
  ) {
    final normalized = ability.trim().toUpperCase();

    final current = character.featAbilityBonuses[normalized] ?? 0;
    character.featAbilityBonuses[normalized] = current + amount;
  }

  static void _applyArmorProficiencies(Character character, FeatData feat) {
    for (final entry in feat.armorProficiencies) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        map.forEach((key, value) {
          if (value == true) {
            _addUnique(character.featArmorProficiencies, key);
          }
        });
      }
    }
  }

  static void _applyWeaponProficiencies(Character character, FeatData feat) {
    for (final entry in feat.weaponProficiencies) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        map.forEach((key, value) {
          if (value == true) {
            _addUnique(character.featWeaponProficiencies, key);
          }
        });
      }
    }
  }

  static void _applyToolProficiencies(Character character, FeatData feat) {
    for (final entry in feat.toolProficiencies) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        map.forEach((key, value) {
          if (value == true) {
            _addUnique(character.featToolProficiencies, key);
          }
        });
      }
    }
  }

  static void _applyLanguageProficiencies(Character character, FeatData feat) {
    for (final entry in feat.languageProficiencies) {
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        map.forEach((key, value) {
          if (value == true) {
            _addUnique(character.featLanguageProficiencies, key);
          }
        });
      }
    }
  }

  static void _applyResistances(Character character, FeatData feat) {
    for (final entry in feat.resist) {
      if (entry is String) {
        _addUnique(character.featResistances, entry);
        continue;
      }

      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        final choose = map['choose'];

        if (choose is Map && choose['from'] is List) {
          final selection = character.featSelections[feat.id];

          if (selection is Map && selection['chosenDamageType'] != null) {
            final chosenDamageType =
                selection['chosenDamageType'].toString().trim().toLowerCase();

            _addUnique(character.featResistances, chosenDamageType);
          }
        }
      }
    }
  }

  static void _applyImmunities(Character character, FeatData feat) {
    for (final entry in feat.immune) {
      if (entry is String) {
        _addUnique(character.featImmunities, entry);
      }
    }
  }

  static void _applyConditionImmunities(Character character, FeatData feat) {
    for (final entry in feat.conditionImmune) {
      if (entry is String) {
        _addUnique(character.featConditionImmunities, entry);
      }
    }
  }

  static void _applySenses(Character character, FeatData feat) {
    for (final entry in feat.senses) {
      if (entry is String) {
        _addUnique(character.featSenses, entry);
      }
    }
  }

  static void _applySimpleModifiers(Character character, FeatData feat) {
    final m = feat.modifiers;

    if (m['initiativeBonus'] is int) {
      character.featInitiativeBonus += m['initiativeBonus'] as int;
    }

    if (m['cannotBeSurprisedWhileConscious'] == true) {
      character.cannotBeSurprisedWhileConscious = true;
    }

    if (m['unseenAttackersNoAdvantage'] == true) {
      character.unseenAttackersNoAdvantage = true;
    }

    if (m['conditionalArmorClassBonus'] is int) {
      character.conditionalArmorClassBonus +=
          m['conditionalArmorClassBonus'] as int;
      character.conditionalArmorClassBonusCondition =
          m['conditionalArmorClassBonusCondition']?.toString();
    }

    if (m['damageReductionWhileWearingHeavyArmor'] is Map) {
      character.damageReductionWhileWearingHeavyArmor =
          Map<String, dynamic>.from(
        m['damageReductionWhileWearingHeavyArmor'] as Map,
      );
    }
  }

  static void _applyAdditionalSpells(Character character, FeatData feat) {
    if (feat.additionalSpells.isEmpty) return;

    final rawSelection = character.featSelections[feat.id];
    final selection = rawSelection is Map
        ? Map<String, dynamic>.from(rawSelection)
        : <String, dynamic>{};

    final resolvedBlocks = _resolveAdditionalSpellBlocks(
      feat,
      selection,
    );

    if (resolvedBlocks.isEmpty) {
      character.featSelections[feat.id] = selection;
      return;
    }

    final grantedKnownSpellIds = <String>[];
    final grantedPreparedSpellIds = <String>[];
    final grantedSpellIds = <String>[];
    final grantedDailySpellIds = <String>[];

    for (final block in resolvedBlocks) {
      final ability = _resolveAdditionalSpellAbility(selection, block);
      if (ability != null && ability.isNotEmpty) {
        selection['grantedSpellcastingAbility'] = ability;
      }

      final directKnownSpellIds = _extractDirectKnownSpellIds(block);
      for (final spellId in directKnownSpellIds) {
        _grantKnownSpell(
          character,
          spellId,
          grantedKnownSpellIds,
          grantedSpellIds,
        );
      }

      final directPreparedSpellIds = _extractDirectPreparedSpellIds(block);
      for (final spellId in directPreparedSpellIds) {
        _grantPreparedSpell(
          character,
          spellId,
          grantedPreparedSpellIds,
          grantedSpellIds,
        );
      }

      final directInnateSpellIds = _extractDirectInnateSpellIds(block);
      for (final spellId in directInnateSpellIds) {
        _grantInnateSpell(
          character,
          spellId,
          grantedSpellIds,
          grantedDailySpellIds,
        );
      }
    }

    final selectedKnownSpellIds = <String>[
      ..._readStringList(selection['selectedCantripIds']),
      ..._readStringList(selection['selectedKnownSpellIds']),
      if (selection['selectedCantripId'] != null)
        selection['selectedCantripId'].toString().trim(),
      if (selection['selectedSpellId'] != null)
        selection['selectedSpellId'].toString().trim(),
    ].where((e) => e.isNotEmpty).toSet().toList();

    for (final spellId in selectedKnownSpellIds) {
      _grantKnownSpell(
        character,
        spellId,
        grantedKnownSpellIds,
        grantedSpellIds,
      );
    }

    final selectedPreparedSpellIds = <String>[
      ..._readStringList(selection['selectedPreparedSpellIds']),
      if (selection['selectedPreparedSpellId'] != null)
        selection['selectedPreparedSpellId'].toString().trim(),
    ].where((e) => e.isNotEmpty).toSet().toList();

    for (final spellId in selectedPreparedSpellIds) {
      _grantPreparedSpell(
        character,
        spellId,
        grantedPreparedSpellIds,
        grantedSpellIds,
      );
    }

    final selectedSpellId = selection['selectedSpellId']?.toString().trim();
    if (selectedSpellId != null && selectedSpellId.isNotEmpty) {
      _grantKnownSpell(
        character,
        selectedSpellId,
        grantedKnownSpellIds,
        grantedSpellIds,
      );
    }

    final selectedLevel1SpellId =
        selection['selectedLevel1SpellId']?.toString().trim();
    if (selectedLevel1SpellId != null && selectedLevel1SpellId.isNotEmpty) {
      _grantKnownSpell(
        character,
        selectedLevel1SpellId,
        grantedKnownSpellIds,
        grantedSpellIds,
      );
      _addUnique(grantedDailySpellIds, selectedLevel1SpellId);
    }

    final selectedInnateSpellIds =
        _readStringList(selection['selectedInnateSpellIds']);
    for (final spellId in selectedInnateSpellIds) {
      _grantInnateSpell(
        character,
        spellId,
        grantedSpellIds,
        grantedDailySpellIds,
      );
    }

    if (grantedKnownSpellIds.isNotEmpty) {
      selection['grantedKnownSpellIds'] = grantedKnownSpellIds;
    } else {
      selection.remove('grantedKnownSpellIds');
    }

    if (grantedPreparedSpellIds.isNotEmpty) {
      selection['grantedPreparedSpellIds'] = grantedPreparedSpellIds;
    } else {
      selection.remove('grantedPreparedSpellIds');
    }

    if (grantedSpellIds.isNotEmpty) {
      selection['grantedSpellIds'] = grantedSpellIds;
    } else {
      selection.remove('grantedSpellIds');
    }

    if (grantedDailySpellIds.isNotEmpty) {
      selection['grantedDailySpellIds'] = grantedDailySpellIds;
      selection['grantedDailySpellId'] = grantedDailySpellIds.first;
      selection['grantedDailySpellUses'] = 1;
      selection['grantedDailySpellCastMode'] = 'daily';
    } else {
      selection.remove('grantedDailySpellIds');
      selection.remove('grantedDailySpellId');
      selection.remove('grantedDailySpellUses');
      selection.remove('grantedDailySpellCastMode');
    }

    character.featSelections[feat.id] = selection;
  }

  static List<Map<String, dynamic>> _resolveAdditionalSpellBlocks(
    FeatData feat,
    Map<String, dynamic> selection,
  ) {
    final blocks = feat.additionalSpells
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (blocks.isEmpty) return const [];

    final unnamedBlocks = blocks.where((b) {
      final name = b['name']?.toString().trim();
      return name == null || name.isEmpty;
    }).toList();

    final namedBlocks = blocks.where((b) {
      final name = b['name']?.toString().trim();
      return name != null && name.isNotEmpty;
    }).toList();

    if (namedBlocks.isEmpty) {
      return unnamedBlocks;
    }

    if (namedBlocks.length == 1) {
      return [...unnamedBlocks, namedBlocks.first];
    }

    final rawSelectedBlockName = (selection['selectedBlock'] ??
            selection['chosenVariant'] ??
            selection['chosenMoon'] ??
            selection['chosenAlignment'] ??
            selection['chosenList'])
        ?.toString()
        .trim();

    final selectedBlockName =
        _normalizeMagicInitiateBlockName(rawSelectedBlockName);

    if (selectedBlockName == null || selectedBlockName.isEmpty) {
      return unnamedBlocks;
    }

    final matchedNamedBlocks = namedBlocks.where((block) {
      final blockName = block['name']?.toString().trim() ?? '';
      return _matchesAdditionalSpellBlock(blockName, selectedBlockName);
    }).toList();

    return [...unnamedBlocks, ...matchedNamedBlocks];
  }

  static String? _resolveAdditionalSpellAbility(
    Map<String, dynamic> selection,
    Map<String, dynamic> block,
  ) {
    final rawAbility = block['ability'];

    if (rawAbility is String) {
      final normalized = rawAbility.trim().toLowerCase();
      if (normalized == 'inherit') {
        return _readChosenSpellcastingAbility(selection);
      }
      return normalized.isEmpty ? null : normalized;
    }

    if (rawAbility is Map) {
      final choose = rawAbility['choose'];
      if (choose is List && choose.isNotEmpty) {
        final selected = _readChosenSpellcastingAbility(selection);
        if (selected != null && selected.isNotEmpty) {
          return selected;
        }
      }
    }

    return null;
  }

  static String? _readChosenSpellcastingAbility(
    Map<String, dynamic> selection,
  ) {
    final candidates = [
      selection['chosenSpellcastingAbility'],
      selection['chosenAbility'],
      selection['spellcastingAbility'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim().toLowerCase();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  static List<String> _extractDirectKnownSpellIds(Map<String, dynamic> block) {
    final known = block['known'];
    if (known == null) return const [];

    return _extractDirectSpellIdsFromNode(known);
  }

  static List<String> _extractDirectPreparedSpellIds(
      Map<String, dynamic> block) {
    final prepared = block['prepared'];
    if (prepared == null) return const [];

    return _extractDirectSpellIdsFromNode(prepared);
  }

  static List<String> _extractDirectInnateSpellIds(Map<String, dynamic> block) {
    final innate = block['innate'];
    if (innate == null) return const [];

    return _extractDirectSpellIdsFromNode(innate);
  }

  static List<String> _extractDirectSpellIdsFromNode(dynamic node) {
    final results = <String>[];

    void visit(dynamic value) {
      if (value is String) {
        final normalized = _normalizeSpellReferenceToId(value);
        if (normalized != null && normalized.isNotEmpty) {
          results.add(normalized);
        }
        return;
      }

      if (value is List) {
        for (final item in value) {
          visit(item);
        }
        return;
      }

      if (value is Map) {
        final map = Map<String, dynamic>.from(value);

        if (map.containsKey('choose')) {
          return;
        }

        for (final entryValue in map.values) {
          visit(entryValue);
        }
      }
    }

    visit(node);

    return results.toSet().toList();
  }

  static String? _normalizeSpellReferenceToId(String raw) {
    var value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;

    final hashIndex = value.indexOf('#');
    if (hashIndex >= 0) {
      value = value.substring(0, hashIndex);
    }

    final pipeIndex = value.indexOf('|');
    if (pipeIndex >= 0) {
      value = value.substring(0, pipeIndex);
    }

    value = value.trim();
    if (value.isEmpty) return null;

    value = value.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    value = value.replaceAll(RegExp(r'_+'), '_');
    value = value.replaceAll(RegExp(r'^_+|_+$'), '');

    return value.isEmpty ? null : value;
  }

  static void _grantKnownSpell(
    Character character,
    String spellId,
    List<String> grantedKnownSpellIds,
    List<String> grantedSpellIds,
  ) {
    final normalized = spellId.trim();
    if (normalized.isEmpty) return;

    _addUnique(character.knownSpells, normalized);
    _addUnique(character.spellIds, normalized);
    _addUnique(grantedKnownSpellIds, normalized);
    _addUnique(grantedSpellIds, normalized);
  }

  static void _grantPreparedSpell(
    Character character,
    String spellId,
    List<String> grantedPreparedSpellIds,
    List<String> grantedSpellIds,
  ) {
    final normalized = spellId.trim();
    if (normalized.isEmpty) return;

    _addUnique(character.spellIds, normalized);
    _addUnique(character.preparedSpellIds, normalized);
    _addUnique(character.preparedSpells, normalized);
    _addUnique(grantedPreparedSpellIds, normalized);
    _addUnique(grantedSpellIds, normalized);
  }

  static void _grantInnateSpell(
    Character character,
    String spellId,
    List<String> grantedSpellIds,
    List<String> grantedDailySpellIds,
  ) {
    final normalized = spellId.trim();
    if (normalized.isEmpty) return;

    _addUnique(character.spellIds, normalized);
    _addUnique(grantedSpellIds, normalized);
    _addUnique(grantedDailySpellIds, normalized);
  }

  static void _addUnique(List<String> target, String value) {
    if (!target.contains(value)) {
      target.add(value);
    }
  }

  static String? _normalizeMagicInitiateBlockName(String? raw) {
    if (raw == null) return null;

    final value = raw.trim();
    if (value.isEmpty) return null;

    return value.replaceAll(' Spells', '').trim();
  }

  static bool _matchesAdditionalSpellBlock(
    String blockName,
    String selectedBlockName,
  ) {
    final normalizedBlock = blockName.trim().toLowerCase();
    final normalizedSelected = selectedBlockName.trim().toLowerCase();

    if (normalizedBlock == normalizedSelected) return true;

    final withoutSuffix = normalizedBlock.replaceAll(' spells', '').trim();
    return withoutSuffix == normalizedSelected;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];

    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
