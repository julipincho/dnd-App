import '../models/character.dart';
import '../models/character_feature.dart';
import '../models/dnd_race.dart';
import '../models/dnd_subrace.dart';
import 'dnd_data_service.dart';

class RaceSyncResult {
  final List<CharacterFeature> features;

  const RaceSyncResult({
    required this.features,
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
    }

    return RaceSyncResult(
      features: _dedupeFeatures(features),
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

  static List<CharacterFeature> _dedupeFeatures(
    List<CharacterFeature> input,
  ) {
    final byId = <String, CharacterFeature>{};
    for (final feature in input) {
      byId[feature.id] = feature;
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
