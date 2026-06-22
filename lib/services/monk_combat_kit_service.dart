enum MonkCombatFeatureRole {
  action,
  resource,
  reaction,
  passive,
  contextualEffect,
}

enum MonkSubclassCombatKind {
  none,
  openHand,
  shadow,
  fourElements,
  mercy,
  astralSelf,
  drunkenMaster,
  kensei,
  sunSoul,
  longDeath,
  unknown,
}

class MonkCombatFeatureReference {
  final String name;
  final MonkCombatFeatureRole role;
  final int? level;
  final String detail;
  final bool implemented;

  const MonkCombatFeatureReference({
    required this.name,
    required this.role,
    this.level,
    this.detail = '',
    this.implemented = false,
  });
}

class MonkSubclassCombatProfile {
  final MonkSubclassCombatKind kind;
  final String name;
  final String shortName;
  final String themeLabel;
  final List<MonkCombatFeatureReference> features;

  const MonkSubclassCombatProfile({
    required this.kind,
    required this.name,
    required this.shortName,
    required this.themeLabel,
    this.features = const [],
  });

  bool get hasSubclass => kind != MonkSubclassCombatKind.none;
  bool get isOpenHand => kind == MonkSubclassCombatKind.openHand;

  bool get hasOpenHandTechnique {
    if (!isOpenHand) return false;
    return features.any((feature) =>
        MonkCombatKitService.normalize(feature.name)
            .contains('open hand technique') ||
        MonkCombatKitService.normalize(feature.detail)
            .contains('flurry of blows'));
  }

  List<MonkCombatFeatureReference> get contextualEffects => features
      .where(
          (feature) => feature.role == MonkCombatFeatureRole.contextualEffect)
      .toList(growable: false);

  List<MonkCombatFeatureReference> get passiveReferences => features
      .where((feature) => feature.role == MonkCombatFeatureRole.passive)
      .toList(growable: false);

  List<MonkCombatFeatureReference> get actionableReferences => features
      .where((feature) =>
          feature.role == MonkCombatFeatureRole.action ||
          feature.role == MonkCombatFeatureRole.reaction)
      .toList(growable: false);
}

class MonkCombatKitService {
  const MonkCombatKitService._();

  static String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  static MonkSubclassCombatProfile profileFromMetadata({
    required String? subclassName,
    required Object? featureEntries,
  }) {
    final detected = _detectSubclassKind(subclassName);
    final features = _featuresFor(
      detected,
      rawSubclassName: subclassName,
      featureEntries: featureEntries,
    );
    return _profileFor(detected, subclassName, features);
  }

  static MonkSubclassCombatKind _detectSubclassKind(String? subclassName) {
    final text = normalize(subclassName ?? '');
    if (text.isEmpty) return MonkSubclassCombatKind.none;
    if (text.contains('open hand') || text.contains('mano abierta')) {
      return MonkSubclassCombatKind.openHand;
    }
    if (text.contains('shadow') || text.contains('sombra')) {
      return MonkSubclassCombatKind.shadow;
    }
    if (text.contains('four elements') ||
        text.contains('4 elements') ||
        text.contains('element')) {
      return MonkSubclassCombatKind.fourElements;
    }
    if (text.contains('mercy') || text.contains('misericordia')) {
      return MonkSubclassCombatKind.mercy;
    }
    if (text.contains('astral self') || text.contains('astral')) {
      return MonkSubclassCombatKind.astralSelf;
    }
    if (text.contains('drunken') || text.contains('ebrio')) {
      return MonkSubclassCombatKind.drunkenMaster;
    }
    if (text.contains('kensei')) return MonkSubclassCombatKind.kensei;
    if (text.contains('sun soul') || text.contains('sol')) {
      return MonkSubclassCombatKind.sunSoul;
    }
    if (text.contains('long death') || text.contains('larga muerte')) {
      return MonkSubclassCombatKind.longDeath;
    }
    return MonkSubclassCombatKind.unknown;
  }

  static MonkSubclassCombatProfile _profileFor(
    MonkSubclassCombatKind kind,
    String? rawName,
    List<MonkCombatFeatureReference> features,
  ) {
    switch (kind) {
      case MonkSubclassCombatKind.none:
        return const MonkSubclassCombatProfile(
          kind: MonkSubclassCombatKind.none,
          name: '',
          shortName: '',
          themeLabel: 'Monk base',
        );
      case MonkSubclassCombatKind.openHand:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Way of the Open Hand'),
          shortName: 'Open Hand',
          themeLabel: 'control y precision',
          features: features,
        );
      case MonkSubclassCombatKind.shadow:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Way of Shadow'),
          shortName: 'Shadow',
          themeLabel: 'sigilo y movilidad',
          features: features,
        );
      case MonkSubclassCombatKind.fourElements:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Way of the Four Elements'),
          shortName: 'Four Elements',
          themeLabel: 'disciplinas elementales',
          features: features,
        );
      case MonkSubclassCombatKind.mercy:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Way of Mercy'),
          shortName: 'Mercy',
          themeLabel: 'curacion y dano preciso',
          features: features,
        );
      case MonkSubclassCombatKind.astralSelf:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Way of the Astral Self'),
          shortName: 'Astral Self',
          themeLabel: 'manifestacion espiritual',
          features: features,
        );
      case MonkSubclassCombatKind.drunkenMaster:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Way of the Drunken Master'),
          shortName: 'Drunken Master',
          themeLabel: 'movimiento impredecible',
          features: features,
        );
      case MonkSubclassCombatKind.kensei:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Way of the Kensei'),
          shortName: 'Kensei',
          themeLabel: 'arma y disciplina',
          features: features,
        );
      case MonkSubclassCombatKind.sunSoul:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Way of the Sun Soul'),
          shortName: 'Sun Soul',
          themeLabel: 'energia radiante',
          features: features,
        );
      case MonkSubclassCombatKind.longDeath:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Way of the Long Death'),
          shortName: 'Long Death',
          themeLabel: 'resistencia y temor',
          features: features,
        );
      case MonkSubclassCombatKind.unknown:
        return MonkSubclassCombatProfile(
          kind: kind,
          name: _safeName(rawName, 'Monastic Tradition'),
          shortName: _safeName(rawName, 'Tradition'),
          themeLabel: 'tradicion detectada',
          features: features,
        );
    }
  }

  static List<MonkCombatFeatureReference> _featuresFor(
    MonkSubclassCombatKind kind, {
    required String? rawSubclassName,
    required Object? featureEntries,
  }) {
    final detected = _featureReferencesFromEntries(featureEntries);
    final result = <MonkCombatFeatureReference>[
      ...detected.where((feature) => _featureBelongsTo(kind, feature.name)),
    ];

    if (result.isEmpty && kind != MonkSubclassCombatKind.none) {
      result.add(
        MonkCombatFeatureReference(
          name: _safeName(rawSubclassName, 'Monastic Tradition'),
          role: MonkCombatFeatureRole.passive,
          level: 3,
          detail: 'Subclass identity detected; combat logic pending.',
          implemented: false,
        ),
      );
    }

    return result;
  }

  static List<MonkCombatFeatureReference> _featureReferencesFromEntries(
    Object? raw,
  ) {
    if (raw is! Iterable) return const [];
    final result = <MonkCombatFeatureReference>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final description = entry['description']?.toString().trim() ?? '';
      final levelValue = entry['level'];
      final level = levelValue is num
          ? levelValue.toInt()
          : int.tryParse(levelValue?.toString() ?? '');
      result.add(
        MonkCombatFeatureReference(
          name: name,
          role: _classifyFeature(name, description),
          level: level,
          detail: description,
          implemented: _implementedFeature(name, description),
        ),
      );
    }
    return result;
  }

  static bool _featureBelongsTo(
    MonkSubclassCombatKind kind,
    String featureName,
  ) {
    final text = normalize(featureName);
    return switch (kind) {
      MonkSubclassCombatKind.openHand => text.contains('open hand') ||
          text.contains('wholeness') ||
          text.contains('tranquility') ||
          text.contains('quivering palm'),
      MonkSubclassCombatKind.shadow => text.contains('shadow') ||
          text.contains('cloak') ||
          text.contains('opportunist'),
      MonkSubclassCombatKind.fourElements =>
        text.contains('element') || text.contains('discipline'),
      MonkSubclassCombatKind.mercy => text.contains('mercy') ||
          text.contains('healing') ||
          text.contains('harm') ||
          text.contains('physician'),
      MonkSubclassCombatKind.astralSelf => text.contains('astral'),
      MonkSubclassCombatKind.drunkenMaster => text.contains('drunken') ||
          text.contains('tipsy') ||
          text.contains('drunkard') ||
          text.contains('intoxicated'),
      MonkSubclassCombatKind.kensei => text.contains('kensei') ||
          text.contains('blade') ||
          text.contains('unerring'),
      MonkSubclassCombatKind.sunSoul =>
        text.contains('sun') || text.contains('searing'),
      MonkSubclassCombatKind.longDeath => text.contains('long death') ||
          text.contains('reaping') ||
          text.contains('death'),
      MonkSubclassCombatKind.none || MonkSubclassCombatKind.unknown => false,
    };
  }

  static MonkCombatFeatureRole _classifyFeature(
    String name,
    String description,
  ) {
    final text = normalize('$name $description');
    if (text.contains('reaction')) return MonkCombatFeatureRole.reaction;
    if (text.contains('whenever you hit') ||
        text.contains('when you hit') ||
        text.contains('flurry of blows')) {
      return MonkCombatFeatureRole.contextualEffect;
    }
    if (text.contains('ki point') || text.contains('spend')) {
      return MonkCombatFeatureRole.action;
    }
    if (text.contains('bonus action') || text.contains('as an action')) {
      return MonkCombatFeatureRole.action;
    }
    return MonkCombatFeatureRole.passive;
  }

  static bool _implementedFeature(String name, String description) {
    final text = normalize('$name $description');
    return text.contains('open hand technique');
  }

  static String _safeName(String? raw, String fallback) {
    final value = raw?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }
}
