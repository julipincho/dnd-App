import '../models/character.dart';
import '../models/character_feature.dart';
import '../models/dnd_race.dart';
import '../models/dnd_subrace.dart';
import 'dnd_data_service.dart';
import '../models/character_resource.dart';

class RaceSyncResult {
  final List<CharacterFeature> features;
  final List<String> armorProficiencies;
  final List<String> weaponProficiencies;
  final List<String> toolProficiencies;
  final List<String> languageProficiencies;
  final List<String> resistances;
  final List<String> immunities;
  final List<String> conditionImmunities;
  final List<String> senses;
  final List<CharacterResource> resources;

  const RaceSyncResult({
    required this.features,
    this.armorProficiencies = const [],
    this.weaponProficiencies = const [],
    this.toolProficiencies = const [],
    this.languageProficiencies = const [],
    this.resistances = const [],
    this.immunities = const [],
    this.conditionImmunities = const [],
    this.senses = const [],
    this.resources = const [],
  });
}

class RaceSyncService {
  static const String _raceSource = 'race';
  static const String _subraceSource = 'subrace';

  static Future<RaceSyncResult> buildForCharacter(Character character) async {
    final race = await getRaceForCharacter(character);

    if (race == null) {
      return const RaceSyncResult(features: []);
    }

    final raceOwnerId = _safeId(race.id, race.name);

    final features = <CharacterFeature>[
      _buildRaceOverviewFeature(race, raceOwnerId),
      ...race.traits.map(
        (trait) => _buildTraitFeature(
          traitName: _traitName(trait),
          traitDescription: _traitDescription(trait),
          source: _raceSource,
          ownerId: raceOwnerId,
        ),
      ),
    ];

    final armorProficiencies = <String>[];
    final weaponProficiencies = <String>[];
    final toolProficiencies = <String>[];
    final languageProficiencies = <String>[
      ...race.languages,
    ];
    final resistances = <String>[];
    final immunities = <String>[];
    final conditionImmunities = <String>[];
    final senses = <String>[];
    final resources = <CharacterResource>[];

    _extractTraitEffects(
      traits: race.traits,
      armorProficiencies: armorProficiencies,
      weaponProficiencies: weaponProficiencies,
      toolProficiencies: toolProficiencies,
      languageProficiencies: languageProficiencies,
      resistances: resistances,
      immunities: immunities,
      conditionImmunities: conditionImmunities,
      senses: senses,
      resources: resources,
    );

    final subrace = getSubraceForCharacter(character, race);
    if (subrace != null) {
      final subraceOwnerId = _safeId(subrace.id, subrace.name);

      features.add(
        _buildSubraceOverviewFeature(subrace, subraceOwnerId),
      );

      features.addAll(
        subrace.traits.map(
          (trait) => _buildTraitFeature(
            traitName: _traitName(trait),
            traitDescription: _traitDescription(trait),
            source: _subraceSource,
            ownerId: subraceOwnerId,
          ),
        ),
      );

      _extractTraitEffects(
        traits: subrace.traits,
        armorProficiencies: armorProficiencies,
        weaponProficiencies: weaponProficiencies,
        toolProficiencies: toolProficiencies,
        languageProficiencies: languageProficiencies,
        resistances: resistances,
        immunities: immunities,
        conditionImmunities: conditionImmunities,
        senses: senses,
        resources: resources,
      );
    }

    return RaceSyncResult(
      features: _dedupeFeatures(features),
      armorProficiencies: _dedupeStrings(armorProficiencies),
      weaponProficiencies: _dedupeStrings(weaponProficiencies),
      toolProficiencies: _dedupeStrings(toolProficiencies),
      languageProficiencies: _dedupeStrings(languageProficiencies),
      resistances: _dedupeStrings(resistances),
      immunities: _dedupeStrings(immunities),
      conditionImmunities: _dedupeStrings(conditionImmunities),
      senses: _dedupeStrings(senses),
      resources: _dedupeResources(resources),
    );
  }

  static Future<DndRace?> getRaceForCharacter(Character character) async {
    final raceName = character.race.trim().toLowerCase();
    if (raceName.isEmpty) return null;

    final races = await DndDataService.getRaces();

    try {
      return races.firstWhere(
        (r) => r.name.trim().toLowerCase() == raceName,
      );
    } catch (_) {
      return null;
    }
  }

  static DndSubrace? getSubraceForCharacter(
    Character character,
    DndRace race,
  ) {
    final subraceName = character.subrace?.trim().toLowerCase();
    if (subraceName == null || subraceName.isEmpty) {
      return null;
    }

    try {
      return race.subraces.firstWhere(
        (s) => s.name.trim().toLowerCase() == subraceName,
      );
    } catch (_) {
      return null;
    }
  }

  static CharacterFeature _buildRaceOverviewFeature(
    DndRace race,
    String ownerId,
  ) {
    final bonusText = race.abilityBonuses
        .map((b) => '${b['ability']} +${b['bonus']}')
        .join(', ');

    final languageText = race.languages.isEmpty
        ? ''
        : 'Languages: ${race.languages.join(', ')}.';

    final parts = <String>[
      if (bonusText.isNotEmpty) 'Ability bonuses: $bonusText.',
      if (race.speed > 0) 'Speed: ${race.speed} ft.',
      if (race.size.isNotEmpty) 'Size: ${race.size}.',
      if (languageText.isNotEmpty) languageText,
      if (race.description.isNotEmpty) race.description,
    ];

    return CharacterFeature(
      id: 'race_$ownerId',
      name: race.name,
      description: parts.join('\n\n').trim(),
      source: _raceSource,
      unlockedAtLevel: 1,
    );
  }

  static CharacterFeature _buildSubraceOverviewFeature(
    DndSubrace subrace,
    String ownerId,
  ) {
    final bonusText = subrace.abilityBonuses
        .map((b) => '${b['ability']} +${b['bonus']}')
        .join(', ');

    final parts = <String>[
      if (bonusText.isNotEmpty) 'Ability bonuses: $bonusText.',
      if (subrace.description.isNotEmpty) subrace.description,
    ];

    return CharacterFeature(
      id: 'subrace_$ownerId',
      name: subrace.name,
      description: parts.join('\n\n').trim(),
      source: _subraceSource,
      unlockedAtLevel: 1,
    );
  }

  static CharacterFeature _buildTraitFeature({
    required String traitName,
    required String traitDescription,
    required String source,
    required String ownerId,
  }) {
    return CharacterFeature(
      id: '${source}_${ownerId}_${_slug(traitName)}',
      name: traitName.isEmpty ? 'Unnamed Trait' : traitName,
      description: traitDescription,
      source: source,
      unlockedAtLevel: 1,
    );
  }

  static int? getSubraceSpeedOverride(DndSubrace? subrace) {
    if (subrace == null) return null;

    for (final trait in subrace.traits) {
      final name = (trait['name'] ?? '').trim().toLowerCase();
      final description = (trait['description'] ?? '').trim().toLowerCase();

      if (name == 'fleet of foot') {
        final match = RegExp(r'(\d+)\s*feet').firstMatch(description);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }

      if (description.contains('base walking speed increases to')) {
        final match = RegExp(r'(\d+)\s*feet').firstMatch(description);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }
    }

    return null;
  }

  static void _extractTraitEffects({
    required List<Map<String, String>> traits,
    required List<String> armorProficiencies,
    required List<String> weaponProficiencies,
    required List<String> toolProficiencies,
    required List<String> languageProficiencies,
    required List<String> resistances,
    required List<String> immunities,
    required List<String> conditionImmunities,
    required List<String> senses,
    required List<CharacterResource> resources,
  }) {
    for (final trait in traits) {
      final originalName = _traitName(trait).trim();
      final originalDescription = _traitDescription(trait).trim();

      final name = originalName.toLowerCase();
      final description = originalDescription.toLowerCase();

      // -----------------------------
      // Generic racial resources
      // -----------------------------
      final rechargeType = _extractRechargeType(description);
      if (rechargeType != null) {
        resources.add(
          CharacterResource(
            id: 'racial_${_slug(originalName)}',
            name: originalName.isEmpty ? 'Racial Trait' : originalName,
            current: 1,
            max: 1,
            rechargeType: rechargeType,
            notes: originalDescription,
          ),
        );
      }

      // -----------------------------
      // Senses
      // -----------------------------
      if (name.contains('darkvision') || description.contains('darkvision')) {
        final match = RegExp(r'(\d+)\s*feet').firstMatch(description);
        if (match != null) {
          senses.add('Darkvision ${match.group(1)} ft.');
        } else {
          senses.add('Darkvision');
        }
      }

      // -----------------------------
      // Resistances
      // -----------------------------
      if (description.contains('resistance to fire damage')) {
        resistances.add('Fire');
      }
      if (description.contains('resistance to cold damage')) {
        resistances.add('Cold');
      }
      if (description.contains('resistance to poison damage')) {
        resistances.add('Poison');
      }
      if (description.contains('resistance to necrotic damage')) {
        resistances.add('Necrotic');
      }
      if (description.contains('resistance to radiant damage')) {
        resistances.add('Radiant');
      }
      if (description.contains('resistance to lightning damage')) {
        resistances.add('Lightning');
      }
      if (description.contains('resistance to acid damage')) {
        resistances.add('Acid');
      }
      if (description.contains('resistance to thunder damage')) {
        resistances.add('Thunder');
      }
      if (description.contains('resistance to psychic damage')) {
        resistances.add('Psychic');
      }
      if (description.contains('resistance to force damage')) {
        resistances.add('Force');
      }

      // -----------------------------
      // Passive protections / condition notes
      // -----------------------------
      if (description
          .contains('advantage on saving throws against being charmed')) {
        conditionImmunities.add('Charm Advantage');
      }

      if (description.contains('magic can’t put you to sleep') ||
          description.contains("magic can't put you to sleep")) {
        conditionImmunities.add('Magic Sleep');
      }

      // -----------------------------
      // Weapon proficiencies
      // -----------------------------
      if (name.contains('dwarven combat training') ||
          description.contains('battleaxe') ||
          description.contains('handaxe') ||
          description.contains('light hammer') ||
          description.contains('warhammer')) {
        weaponProficiencies.addAll([
          'Battleaxe',
          'Handaxe',
          'Light Hammer',
          'Warhammer',
        ]);
      }

      if (name.contains('elf weapon training') ||
          description.contains('longsword') ||
          description.contains('shortsword') ||
          description.contains('shortbow') ||
          description.contains('longbow')) {
        weaponProficiencies.addAll([
          'Longsword',
          'Shortsword',
          'Shortbow',
          'Longbow',
        ]);
      }

      // -----------------------------
      // Tool proficiencies
      // -----------------------------
      if (name.contains('tool proficiency') ||
          description.contains('smith') ||
          description.contains('brewer') ||
          description.contains('mason')) {
        if (description.contains('smith')) {
          toolProficiencies.add("Smith's Tools");
        }
        if (description.contains('brewer')) {
          toolProficiencies.add("Brewer's Supplies");
        }
        if (description.contains('mason')) {
          toolProficiencies.add("Mason's Tools");
        }
      }

      // -----------------------------
      // Extra languages from traits
      // -----------------------------
      if (description.contains('you can speak, read, and write')) {
        if (description.contains('common')) {
          languageProficiencies.add('Common');
        }
        if (description.contains('elvish')) {
          languageProficiencies.add('Elvish');
        }
        if (description.contains('dwarvish')) {
          languageProficiencies.add('Dwarvish');
        }
        if (description.contains('draconic')) {
          languageProficiencies.add('Draconic');
        }
        if (description.contains('orc')) {
          languageProficiencies.add('Orc');
        }
        if (description.contains('gnomish')) {
          languageProficiencies.add('Gnomish');
        }
        if (description.contains('halfling')) {
          languageProficiencies.add('Halfling');
        }
        if (description.contains('infernal')) {
          languageProficiencies.add('Infernal');
        }
        if (description.contains('celestial')) {
          languageProficiencies.add('Celestial');
        }
        if (description.contains('goblin')) {
          languageProficiencies.add('Goblin');
        }
      }
    }
  }

  static String? _extractRechargeType(String description) {
    final normalized = description.toLowerCase();

    final hasUsageClause = normalized.contains('once you use this trait') ||
        normalized.contains('once you use this ability') ||
        normalized.contains('once you use this feature') ||
        normalized.contains('once you use it') ||
        normalized.contains("can't use it again") ||
        normalized.contains("cannot use it again") ||
        normalized.contains("can’t use it again") ||
        normalized.contains("can't use this trait again") ||
        normalized.contains("cannot use this trait again") ||
        normalized.contains("can’t use this trait again") ||
        normalized.contains("can't use this ability again") ||
        normalized.contains("cannot use this ability again") ||
        normalized.contains("can’t use this ability again") ||
        normalized.contains("can't use this feature again") ||
        normalized.contains("cannot use this feature again") ||
        normalized.contains("can’t use this feature again");

    if (!hasUsageClause) return null;

    if (normalized.contains('short or long rest') ||
        normalized.contains('short rest or long rest') ||
        normalized.contains('finish a short or long rest') ||
        normalized.contains('until you finish a short or long rest')) {
      return 'shortRest';
    }

    if (normalized.contains('finish a long rest') ||
        normalized.contains('until you finish a long rest') ||
        normalized.contains('once per long rest')) {
      return 'longRest';
    }

    if (normalized.contains('finish a short rest') ||
        normalized.contains('until you finish a short rest') ||
        normalized.contains('once per short rest')) {
      return 'shortRest';
    }

    return null;
  }

  static List<CharacterFeature> _dedupeFeatures(
    List<CharacterFeature> input,
  ) {
    final byId = <String, CharacterFeature>{};
    for (final feature in input) {
      byId[feature.id] = feature;
    }
    return byId.values.toList();
  }

  static List<String> _dedupeStrings(List<String> input) {
    final byKey = <String, String>{};

    for (final value in input) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      byKey.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
    }

    return byKey.values.toList();
  }

  static List<CharacterResource> _dedupeResources(
    List<CharacterResource> input,
  ) {
    final byId = <String, CharacterResource>{};

    for (final resource in input) {
      byId[resource.id] = resource;
    }

    return byId.values.toList();
  }

  static String _safeId(String? id, String fallbackName) {
    final value = (id ?? '').trim();
    if (value.isNotEmpty) return _slug(value);
    return _slug(fallbackName);
  }

  static String _traitName(Map<String, String> trait) {
    return (trait['name'] ?? '').trim();
  }

  static String _traitDescription(Map<String, String> trait) {
    return (trait['description'] ?? '').trim();
  }

  static String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
