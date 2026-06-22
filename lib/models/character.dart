import '../models/character_inventory_item.dart';
import '../models/character_progression.dart';
import '../models/dnd_background.dart';
import '../models/character_feature.dart';
import '../models/character_resource.dart';
import '../models/character_selected_option_group.dart';

class Character {
  String? ownerUserId;
  String id;
  String name;
  String race;
  String? subrace;
  String? subclass;
  String charClass;
  List<String> spellIds;
  int level;
  CharacterProgression progression;
  List<CharacterFeature> features;
  List<CharacterResource> resources;
  String? campaignId;

  Map<String, int> stats;
  Map<String, int> racialBonuses;
  Map<String, int> featAbilityBonuses;
  DndBackground background;
  String? alignment;
  String? portraitPath;
  List<String> preparedSpellIds;
  List<String> classSkills;
  List<String> savingThrows;
  List<CharacterInventoryItem> inventory;
// -----------------------------
// Sprint 4: Class Options (Feats, Maneuvers, etc.)
// -----------------------------
  List<CharacterSelectedOptionGroup> selectedOptionGroups;
  // -----------------------------
  // Sprint 2: estado jugable
  // -----------------------------
  int? maxHp;
  int? currentHp;
  int? tempHp;
  int? armorClass;
  int? speed;
  int deathSaveSuccesses;
  int deathSaveFailures;

  // -----------------------------
  // Sprint 2: narrativa
  // -----------------------------
  String? backstory;
  String? notes;

  // -----------------------------
  // Sprint 2: spellcasting base
  // -----------------------------
  String? spellcastingAbility;
  Map<String, String> spellcastingAbilitiesByClass;
  List<String> knownSpells;
  List<String> preparedSpells;
  Map<String, List<String>> knownSpellIdsByClass;
  Map<String, List<String>> preparedSpellIdsByClass;
  Map<String, int> spellSlots;
  Map<String, int> pactMagicSlots;

  // -----------------------------
  // Sprint 3: Equipment
  // -----------------------------
  String? equippedMainHandItemId;
  String? equippedOffHandItemId;
  String? equippedArmorItemId;
  String? equippedShieldItemId;
  String? equippedAccessory1ItemId;
  String? equippedAccessory2ItemId;
  String? pactWeaponItemId;
  String? pactWeaponBaseItemId;
  List<String> selectedFeatIds;
  List<String> featArmorProficiencies;
  List<String> featWeaponProficiencies;
  List<String> featToolProficiencies;
  List<String> featLanguageProficiencies;
  List<String> featResistances;
  List<String> featImmunities;
  List<String> featConditionImmunities;
  List<String> featSenses;
  List<String> racialArmorProficiencies;
  List<String> racialWeaponProficiencies;
  List<String> racialToolProficiencies;
  List<String> racialLanguageProficiencies;
  List<String> racialResistances;
  List<String> racialImmunities;
  List<String> racialConditionImmunities;
  List<String> racialSenses;

  int featInitiativeBonus;
  int featSpeedBonus;
  String? get userId => ownerUserId;
  bool cannotBeSurprisedWhileConscious;
  bool unseenAttackersNoAdvantage;

  int conditionalArmorClassBonus;
  String? conditionalArmorClassBonusCondition;

  Map<String, dynamic>? damageReductionWhileWearingHeavyArmor;
  Map<String, dynamic> featSelections;
// -----------------------------
// Sprint 4: Class Options (Feats, Maneuvers, etc.)
// -----------------------------

  Character({
    this.ownerUserId,
    required this.id,
    required this.name,
    required this.race,
    required this.spellIds,
    required this.preparedSpellIds,
    this.selectedFeatIds = const [],
    this.featSelections = const {},
    this.subrace,
    this.subclass,
    required this.charClass,
    required this.level,
    CharacterProgression? progression,
    this.campaignId,
    required this.stats,
    required this.racialBonuses,
    this.featAbilityBonuses = const {
      'STR': 0,
      'DEX': 0,
      'CON': 0,
      'INT': 0,
      'WIS': 0,
      'CHA': 0,
    },
    required this.background,
    this.alignment,
    this.portraitPath,
    List<CharacterFeature>? features,
    List<CharacterResource>? resources,
    List<String>? classSkills,
    List<String>? savingThrows,
    List<CharacterInventoryItem>? inventory,
    List<CharacterSelectedOptionGroup>? selectedOptionGroups,
    this.maxHp,
    this.currentHp,
    this.tempHp,
    this.armorClass,
    this.speed,
    this.backstory,
    this.notes,
    this.spellcastingAbility,
    Map<String, String>? spellcastingAbilitiesByClass,
    List<String>? knownSpells,
    List<String>? preparedSpells,
    Map<String, List<String>>? knownSpellIdsByClass,
    Map<String, List<String>>? preparedSpellIdsByClass,
    Map<String, int>? spellSlots,
    Map<String, int>? pactMagicSlots,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    this.featArmorProficiencies = const [],
    this.featWeaponProficiencies = const [],
    this.featToolProficiencies = const [],
    this.featLanguageProficiencies = const [],
    this.featResistances = const [],
    this.featImmunities = const [],
    this.featConditionImmunities = const [],
    this.featSenses = const [],
    this.featInitiativeBonus = 0,
    this.featSpeedBonus = 0,
    this.racialArmorProficiencies = const [],
    this.racialWeaponProficiencies = const [],
    this.racialToolProficiencies = const [],
    this.racialLanguageProficiencies = const [],
    this.racialResistances = const [],
    this.racialImmunities = const [],
    this.racialConditionImmunities = const [],
    this.racialSenses = const [],
    this.cannotBeSurprisedWhileConscious = false,
    this.unseenAttackersNoAdvantage = false,
    this.conditionalArmorClassBonus = 0,
    this.conditionalArmorClassBonusCondition,
    this.damageReductionWhileWearingHeavyArmor,
    this.equippedMainHandItemId,
    this.pactWeaponItemId,
    this.pactWeaponBaseItemId,
    this.equippedOffHandItemId,
    this.equippedArmorItemId,
    this.equippedShieldItemId,
    this.equippedAccessory1ItemId,
    this.equippedAccessory2ItemId,
  })  : progression = progression ??
            CharacterProgression.legacy(
              className: charClass,
              totalLevel: level,
              subclassName: subclass,
            ),
        classSkills = classSkills ?? [],
        features = features ?? [],
        resources = resources ?? [],
        savingThrows = savingThrows ?? [],
        inventory = inventory ?? [],
        spellcastingAbilitiesByClass = _normalizeSpellcastingAbilitiesByClass(
          spellcastingAbilitiesByClass ?? const {},
        ),
        knownSpells = knownSpells ?? [],
        preparedSpells = preparedSpells ?? [],
        knownSpellIdsByClass = _normalizeSpellIdsByClass(
          knownSpellIdsByClass ?? const {},
        ),
        preparedSpellIdsByClass = _normalizeSpellIdsByClass(
          preparedSpellIdsByClass ?? const {},
        ),
        deathSaveSuccesses = deathSaveSuccesses ?? 0,
        deathSaveFailures = deathSaveFailures ?? 0,
        selectedOptionGroups = selectedOptionGroups ?? [],
        spellSlots = spellSlots ?? {},
        pactMagicSlots = pactMagicSlots ?? {} {
    spellIds = List<String>.from(spellIds);
    preparedSpellIds = List<String>.from(preparedSpellIds);
    selectedFeatIds = List<String>.from(selectedFeatIds);
    featSelections = _mutableDynamicMap(featSelections);

    stats = Map<String, int>.from(stats);
    racialBonuses = Map<String, int>.from(racialBonuses);
    featAbilityBonuses = Map<String, int>.from(featAbilityBonuses);

    this.features = List<CharacterFeature>.from(this.features);
    this.resources = List<CharacterResource>.from(this.resources);
    this.classSkills = List<String>.from(this.classSkills);
    this.savingThrows = List<String>.from(this.savingThrows);
    this.inventory = List<CharacterInventoryItem>.from(this.inventory);
    this.selectedOptionGroups = List<CharacterSelectedOptionGroup>.from(
      this.selectedOptionGroups,
    );

    this.spellcastingAbilitiesByClass = Map<String, String>.from(
      this.spellcastingAbilitiesByClass,
    );
    this.knownSpells = List<String>.from(this.knownSpells);
    this.preparedSpells = List<String>.from(this.preparedSpells);
    this.knownSpellIdsByClass = _mutableSpellIdsByClass(
      this.knownSpellIdsByClass,
    );
    this.preparedSpellIdsByClass = _mutableSpellIdsByClass(
      this.preparedSpellIdsByClass,
    );
    this.spellSlots = Map<String, int>.from(this.spellSlots);
    this.pactMagicSlots = Map<String, int>.from(this.pactMagicSlots);

    featArmorProficiencies = List<String>.from(featArmorProficiencies);
    featWeaponProficiencies = List<String>.from(featWeaponProficiencies);
    featToolProficiencies = List<String>.from(featToolProficiencies);
    featLanguageProficiencies = List<String>.from(
      featLanguageProficiencies,
    );
    featResistances = List<String>.from(featResistances);
    featImmunities = List<String>.from(featImmunities);
    featConditionImmunities = List<String>.from(featConditionImmunities);
    featSenses = List<String>.from(featSenses);

    racialArmorProficiencies = List<String>.from(racialArmorProficiencies);
    racialWeaponProficiencies = List<String>.from(racialWeaponProficiencies);
    racialToolProficiencies = List<String>.from(racialToolProficiencies);
    racialLanguageProficiencies = List<String>.from(
      racialLanguageProficiencies,
    );
    racialResistances = List<String>.from(racialResistances);
    racialImmunities = List<String>.from(racialImmunities);
    racialConditionImmunities = List<String>.from(
      racialConditionImmunities,
    );
    racialSenses = List<String>.from(racialSenses);

    if (damageReductionWhileWearingHeavyArmor != null) {
      damageReductionWhileWearingHeavyArmor = Map<String, dynamic>.from(
        damageReductionWhileWearingHeavyArmor!,
      );
    }
  }

  factory Character.empty() {
    return Character(
      ownerUserId: null,
      id: '',
      name: '',
      race: '',
      features: const [],
      resources: const [],
      spellIds: const [],
      preparedSpellIds: const [],
      charClass: '',
      level: 1,
      progression: const CharacterProgression(levels: []),
      campaignId: null,
      pactWeaponItemId: null,
      racialArmorProficiencies: const [],
      racialWeaponProficiencies: const [],
      racialToolProficiencies: const [],
      racialLanguageProficiencies: const [],
      racialResistances: const [],
      racialImmunities: const [],
      racialConditionImmunities: const [],
      racialSenses: const [],
      pactWeaponBaseItemId: null,
      stats: const {
        'STR': 10,
        'DEX': 10,
        'CON': 10,
        'INT': 10,
        'WIS': 10,
        'CHA': 10,
      },
      racialBonuses: const {
        'STR': 0,
        'DEX': 0,
        'CON': 0,
        'INT': 0,
        'WIS': 0,
        'CHA': 0,
      },
      featAbilityBonuses: const {
        'STR': 0,
        'DEX': 0,
        'CON': 0,
        'INT': 0,
        'WIS': 0,
        'CHA': 0,
      },
      background: DndBackground(
        index: 'none',
        name: 'Unassigned',
        featureName: '',
        featureDescription: const [],
        personalityTraits: const [],
        ideals: const [],
        bonds: const [],
        flaws: const [],
      ),
      alignment: 'True Neutral',
      classSkills: const [],
      savingThrows: const [],
      inventory: const [],
      maxHp: null,
      currentHp: null,
      tempHp: null,
      armorClass: null,
      speed: null,
      backstory: '',
      notes: '',
      spellcastingAbility: null,
      spellcastingAbilitiesByClass: const {},
      knownSpells: const [],
      preparedSpells: const [],
      knownSpellIdsByClass: const {},
      preparedSpellIdsByClass: const {},
      spellSlots: const {},
      deathSaveSuccesses: 0,
      deathSaveFailures: 0,
      equippedMainHandItemId: null,
      equippedOffHandItemId: null,
      equippedArmorItemId: null,
      equippedShieldItemId: null,
      equippedAccessory1ItemId: null,
      equippedAccessory2ItemId: null,
      selectedOptionGroups: const [],
      selectedFeatIds: const [],
      featSelections: const {},
      featArmorProficiencies: const [],
      featWeaponProficiencies: const [],
      featToolProficiencies: const [],
      featLanguageProficiencies: const [],
      featResistances: const [],
      featImmunities: const [],
      featConditionImmunities: const [],
      featSenses: const [],
      featInitiativeBonus: 0,
      featSpeedBonus: 0,
      cannotBeSurprisedWhileConscious: false,
      unseenAttackersNoAdvantage: false,
      conditionalArmorClassBonus: 0,
      conditionalArmorClassBonusCondition: null,
      damageReductionWhileWearingHeavyArmor: null,
    );
  }

  factory Character.fromJson(Map<String, dynamic> json) {
    final rawBg = json['background'];
    final background = (rawBg is Map)
        ? DndBackground.fromJson(
            Map<String, dynamic>.from(rawBg),
          )
        : DndBackground(
            index: 'unknown',
            name: 'Unknown Background',
            personalityTraits: const [],
            ideals: const [],
            bonds: const [],
            flaws: const [],
            featureName: '',
            featureDescription: const [],
          );

    final stats = (json['stats'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ) ??
        {};

    final bonuses = (json['racialBonuses'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ) ??
        {};
    final featAbilityBonuses = (json['featAbilityBonuses'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ) ??
        {
          'STR': 0,
          'DEX': 0,
          'CON': 0,
          'INT': 0,
          'WIS': 0,
          'CHA': 0,
        };
    final inventory = (json['inventory'] as List?)
            ?.map(
              (e) => CharacterInventoryItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        [];

    final spellIds =
        (json['spellIds'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final spellSlots = (json['spellSlots'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ) ??
        {};
    final pactMagicSlots = (json['pactMagicSlots'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ) ??
        {};

    final preparedSpellIds = (json['preparedSpellIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final knownSpellIdsByClass = _parseSpellIdsByClass(
      json['knownSpellIdsByClass'],
    );
    final preparedSpellIdsByClass = _parseSpellIdsByClass(
      json['preparedSpellIdsByClass'],
    );

    final features = (json['features'] as List?)
            ?.map(
              (e) => CharacterFeature.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        [];

    final resources = (json['resources'] as List?)
            ?.map(
              (e) => CharacterResource.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        [];
    final selectedOptionGroups = (json['selectedOptionGroups'] as List?)
            ?.map(
              (e) => CharacterSelectedOptionGroup.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        [];
    final charClass = json['charClass']?.toString() ?? '';
    final subclass = json['subclass']?.toString();
    final level = (json['level'] as num?)?.toInt() ?? 1;
    final rawProgression = json['progression'];
    final progression = rawProgression is Map
        ? CharacterProgression.fromJson(
            Map<String, dynamic>.from(rawProgression),
          )
        : CharacterProgression.legacy(
            className: charClass,
            totalLevel: level,
            subclassName: subclass,
          );

    return Character(
      ownerUserId: json['ownerUserId'],
      racialArmorProficiencies: (json['racialArmorProficiencies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      racialWeaponProficiencies: (json['racialWeaponProficiencies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      racialToolProficiencies: (json['racialToolProficiencies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      racialLanguageProficiencies:
          (json['racialLanguageProficiencies'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
      racialResistances: (json['racialResistances'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      racialImmunities: (json['racialImmunities'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      racialConditionImmunities: (json['racialConditionImmunities'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      racialSenses:
          (json['racialSenses'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      race: json['race']?.toString() ?? '',
      subrace: json['subrace']?.toString(),
      subclass: subclass,
      charClass: charClass,
      level: level,
      progression: progression,
      campaignId: json['campaignId']?.toString(),
      stats: stats,
      racialBonuses: bonuses,
      featAbilityBonuses: featAbilityBonuses,
      spellIds: spellIds,
      preparedSpellIds: preparedSpellIds,
      background: background,
      alignment: json['alignment']?.toString(),
      portraitPath: json['portraitPath']?.toString(),
      classSkills:
          (json['classSkills'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      savingThrows:
          (json['savingThrows'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      inventory: inventory,
      maxHp: (json['maxHp'] as num?)?.toInt(),
      currentHp: (json['currentHp'] as num?)?.toInt(),
      tempHp: (json['tempHp'] as num?)?.toInt(),
      armorClass: (json['armorClass'] as num?)?.toInt(),
      speed: (json['speed'] as num?)?.toInt(),
      backstory: json['backstory']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      spellcastingAbility: json['spellcastingAbility']?.toString(),
      spellcastingAbilitiesByClass: _parseSpellcastingAbilitiesByClass(
        json['spellcastingAbilitiesByClass'],
      ),
      knownSpells:
          (json['knownSpells'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      preparedSpells: (json['preparedSpells'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      knownSpellIdsByClass: knownSpellIdsByClass,
      preparedSpellIdsByClass: preparedSpellIdsByClass,
      spellSlots: spellSlots,
      pactMagicSlots: pactMagicSlots,
      features: features,
      resources: resources,
      deathSaveSuccesses: (json['deathSaveSuccesses'] as num?)?.toInt() ?? 0,
      deathSaveFailures: (json['deathSaveFailures'] as num?)?.toInt() ?? 0,
      equippedMainHandItemId: json['equippedMainHandItemId']?.toString(),
      equippedOffHandItemId: json['equippedOffHandItemId']?.toString(),
      equippedArmorItemId: json['equippedArmorItemId']?.toString(),
      equippedShieldItemId: json['equippedShieldItemId']?.toString(),
      equippedAccessory1ItemId: json['equippedAccessory1ItemId']?.toString(),
      equippedAccessory2ItemId: json['equippedAccessory2ItemId']?.toString(),
      selectedOptionGroups: selectedOptionGroups,
      selectedFeatIds: (json['selectedFeatIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featSelections: (json['featSelections'] as Map?)
              ?.map((key, value) => MapEntry(key.toString(), value)) ??
          {},
      pactWeaponItemId: json['pactWeaponItemId']?.toString(),
      pactWeaponBaseItemId: json['pactWeaponBaseItemId']?.toString(),
      featArmorProficiencies: (json['featArmorProficiencies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featWeaponProficiencies: (json['featWeaponProficiencies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featToolProficiencies: (json['featToolProficiencies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featLanguageProficiencies: (json['featLanguageProficiencies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featResistances: (json['featResistances'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featImmunities: (json['featImmunities'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featConditionImmunities: (json['featConditionImmunities'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featSenses:
          (json['featSenses'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      featInitiativeBonus: (json['featInitiativeBonus'] as num?)?.toInt() ?? 0,
      featSpeedBonus: (json['featSpeedBonus'] as num?)?.toInt() ?? 0,
      cannotBeSurprisedWhileConscious:
          json['cannotBeSurprisedWhileConscious'] == true,
      unseenAttackersNoAdvantage: json['unseenAttackersNoAdvantage'] == true,
      conditionalArmorClassBonus:
          (json['conditionalArmorClassBonus'] as num?)?.toInt() ?? 0,
      conditionalArmorClassBonusCondition:
          json['conditionalArmorClassBonusCondition']?.toString(),
      damageReductionWhileWearingHeavyArmor:
          (json['damageReductionWhileWearingHeavyArmor'] as Map?)
              ?.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Map<String, dynamic> toJson() {
    final effectiveProgression = normalizedProgression;

    return {
      'ownerUserId': ownerUserId,
      'id': id,
      'name': name,
      'race': race,
      'subrace': subrace,
      'subclass': subclass,
      'charClass': charClass,
      'level': effectiveProgression.totalLevel == 0
          ? level
          : effectiveProgression.totalLevel,
      'progression': effectiveProgression.toJson(),
      'campaignId': campaignId,
      'stats': stats,
      'racialBonuses': racialBonuses,
      'featAbilityBonuses': featAbilityBonuses,
      'background': background.toJson(),
      'alignment': alignment,
      'portraitPath': portraitPath,
      'classSkills': classSkills,
      'savingThrows': savingThrows,
      'inventory': inventory.map((item) => item.toJson()).toList(),
      'maxHp': maxHp,
      'currentHp': currentHp,
      'tempHp': tempHp,
      'armorClass': armorClass,
      'racialArmorProficiencies': racialArmorProficiencies,
      'racialWeaponProficiencies': racialWeaponProficiencies,
      'racialToolProficiencies': racialToolProficiencies,
      'racialLanguageProficiencies': racialLanguageProficiencies,
      'racialResistances': racialResistances,
      'racialImmunities': racialImmunities,
      'racialConditionImmunities': racialConditionImmunities,
      'racialSenses': racialSenses,
      'speed': speed,
      'backstory': backstory,
      'notes': notes,
      'spellcastingAbility': spellcastingAbility,
      'spellcastingAbilitiesByClass': spellcastingAbilitiesByClass,
      'knownSpells': knownSpells,
      'preparedSpells': preparedSpells,
      'knownSpellIdsByClass': knownSpellIdsByClass,
      'preparedSpellIdsByClass': preparedSpellIdsByClass,
      'spellIds': spellIds,
      'preparedSpellIds': preparedSpellIds,
      'spellSlots': spellSlots,
      'pactMagicSlots': pactMagicSlots,
      'features': features.map((e) => e.toJson()).toList(),
      'resources': resources.map((e) => e.toJson()).toList(),
      'deathSaveSuccesses': deathSaveSuccesses,
      'deathSaveFailures': deathSaveFailures,
      'equippedMainHandItemId': equippedMainHandItemId,
      'equippedOffHandItemId': equippedOffHandItemId,
      'equippedArmorItemId': equippedArmorItemId,
      'equippedShieldItemId': equippedShieldItemId,
      'equippedAccessory1ItemId': equippedAccessory1ItemId,
      'equippedAccessory2ItemId': equippedAccessory2ItemId,
      'pactWeaponItemId': pactWeaponItemId,
      'pactWeaponBaseItemId': pactWeaponBaseItemId,
      'selectedOptionGroups':
          selectedOptionGroups.map((e) => e.toJson()).toList(),
      'selectedFeatIds': selectedFeatIds,
      'featSelections': featSelections,
      'featArmorProficiencies': featArmorProficiencies,
      'featWeaponProficiencies': featWeaponProficiencies,
      'featToolProficiencies': featToolProficiencies,
      'featLanguageProficiencies': featLanguageProficiencies,
      'featResistances': featResistances,
      'featImmunities': featImmunities,
      'featConditionImmunities': featConditionImmunities,
      'featSenses': featSenses,
      'featInitiativeBonus': featInitiativeBonus,
      'featSpeedBonus': featSpeedBonus,
      'cannotBeSurprisedWhileConscious': cannotBeSurprisedWhileConscious,
      'unseenAttackersNoAdvantage': unseenAttackersNoAdvantage,
      'conditionalArmorClassBonus': conditionalArmorClassBonus,
      'conditionalArmorClassBonusCondition':
          conditionalArmorClassBonusCondition,
      'damageReductionWhileWearingHeavyArmor':
          damageReductionWhileWearingHeavyArmor,
    };
  }

  CharacterInventoryItem? _findInventoryItemById(String? itemId) {
    if (itemId == null || itemId.isEmpty) return null;

    for (final item in inventory) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  CharacterProgression get normalizedProgression {
    if (!progression.isEmpty) return progression;
    return CharacterProgression.legacy(
      className: charClass,
      totalLevel: level,
      subclassName: subclass,
    );
  }

  Map<String, int> get classLevels => normalizedProgression.levelsByClass;

  int levelForClass(String className) {
    return normalizedProgression.levelForClass(className);
  }

  String? subclassForClass(String className) {
    return normalizedProgression.subclassForClass(className);
  }

  String get classProgressionLabel {
    final entries = classLevels.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    if (entries.isEmpty) {
      return charClass.trim().isEmpty
          ? 'No class selected'
          : '$charClass $level';
    }

    return entries.map((entry) => '${entry.key} ${entry.value}').join(' / ');
  }

  void setPrimaryClassProgression({
    required String className,
    String? subclassName,
    int? totalLevel,
  }) {
    final safeLevel = totalLevel ?? (level < 1 ? 1 : level);
    charClass = className;
    subclass = subclassName;
    level = safeLevel;
    progression = CharacterProgression.legacy(
      className: className,
      totalLevel: safeLevel,
      subclassName: subclass,
    );
  }

  void setPrimaryClassLevel(int totalLevel) {
    final safeLevel = totalLevel < 1 ? 1 : totalLevel;
    level = safeLevel;
    progression = normalizedProgression.withPrimaryClassLevel(
      className: charClass,
      totalLevel: safeLevel,
      subclassName: subclass,
    );
  }

  void setSubclassForPrimaryClass(String subclassName) {
    subclass = subclassName;
    progression = normalizedProgression.withSubclassForClass(
      className: charClass,
      subclassName: subclassName,
    );
  }

  void addClassLevel({
    required String className,
    String? subclassName,
    int? hitDie,
    Map<String, dynamic> choices = const {},
  }) {
    progression = normalizedProgression.addClassLevel(
      className: className,
      subclassName: subclassName,
      hitDie: hitDie,
      choices: choices,
    );
    level = progression.totalLevel;
    if (charClass.trim().isEmpty) {
      charClass = className;
      subclass = subclassName;
    }
  }

  bool get hasPactOfTheBlade {
    return selectedOptionGroups.any(
      (g) => g.selectedOptionIds.contains('pact_of_the_blade'),
    );
  }

  CharacterInventoryItem? get equippedMainHand =>
      _findInventoryItemById(equippedMainHandItemId);

  CharacterInventoryItem? get equippedOffHand =>
      _findInventoryItemById(equippedOffHandItemId);

  CharacterInventoryItem? get equippedArmor =>
      _findInventoryItemById(equippedArmorItemId);

  CharacterInventoryItem? get equippedShield =>
      _findInventoryItemById(equippedShieldItemId);

  CharacterInventoryItem? get equippedAccessory1 =>
      _findInventoryItemById(equippedAccessory1ItemId);

  CharacterInventoryItem? get equippedAccessory2 =>
      _findInventoryItemById(equippedAccessory2ItemId);

  static Map<String, List<String>> _parseSpellIdsByClass(dynamic raw) {
    if (raw is! Map) return {};

    return _normalizeSpellIdsByClass(
      raw.map((key, value) {
        final ids = value is List
            ? value.map((e) => e.toString()).toList()
            : <String>[];
        return MapEntry(key.toString(), ids);
      }),
    );
  }

  static Map<String, dynamic> _mutableDynamicMap(Map<String, dynamic> value) {
    return value.map(
      (key, entryValue) => MapEntry(
        key,
        _mutableDynamicValue(entryValue),
      ),
    );
  }

  static dynamic _mutableDynamicValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(
          key.toString(),
          _mutableDynamicValue(entryValue),
        ),
      );
    }

    if (value is List) {
      return value.map(_mutableDynamicValue).toList();
    }

    return value;
  }

  static Map<String, List<String>> _mutableSpellIdsByClass(
    Map<String, List<String>> value,
  ) {
    return value.map(
      (key, ids) => MapEntry(key, List<String>.from(ids)),
    );
  }

  static Map<String, List<String>> _normalizeSpellIdsByClass(
    Map<String, List<String>> value,
  ) {
    final result = <String, List<String>>{};

    for (final entry in value.entries) {
      final key = _spellClassKey(entry.key);
      if (key.isEmpty) continue;

      final ids = <String>[];
      for (final id in entry.value) {
        final normalizedId = id.trim();
        if (normalizedId.isEmpty || ids.contains(normalizedId)) continue;
        ids.add(normalizedId);
      }

      if (ids.isNotEmpty) {
        result[key] = ids;
      }
    }

    return result;
  }

  static String _spellClassKey(String className) {
    return className.trim().toLowerCase();
  }

  static Map<String, String> _parseSpellcastingAbilitiesByClass(dynamic raw) {
    if (raw is! Map) return {};

    return _normalizeSpellcastingAbilitiesByClass(
      raw.map((key, value) => MapEntry(key.toString(), value.toString())),
    );
  }

  static Map<String, String> _normalizeSpellcastingAbilitiesByClass(
    Map<String, String> value,
  ) {
    final result = <String, String>{};

    for (final entry in value.entries) {
      final key = _spellClassKey(entry.key);
      final ability = _normalizeAbility(entry.value);
      if (key.isEmpty || ability == null) continue;
      result[key] = ability;
    }

    return result;
  }

  static String? _normalizeAbility(String? value) {
    final raw = value?.trim().toUpperCase();
    switch (raw) {
      case 'STR':
      case 'DEX':
      case 'CON':
      case 'INT':
      case 'WIS':
      case 'CHA':
        return raw;
      default:
        return null;
    }
  }

  String? spellcastingAbilityForClass(String className) {
    final key = _spellClassKey(className);
    final classAbility = spellcastingAbilitiesByClass[key];
    if (classAbility != null) return classAbility;

    if (key == _spellClassKey(charClass)) {
      return _normalizeAbility(spellcastingAbility);
    }

    return null;
  }

  bool get hasAnySpellcastingAbility {
    return _normalizeAbility(spellcastingAbility) != null ||
        spellcastingAbilitiesByClass.isNotEmpty;
  }

  void setSpellcastingAbilityForClass(String className, String? ability) {
    final key = _spellClassKey(className);
    if (key.isEmpty) return;

    final normalizedAbility = _normalizeAbility(ability);
    if (normalizedAbility == null) {
      spellcastingAbilitiesByClass.remove(key);
    } else {
      spellcastingAbilitiesByClass[key] = normalizedAbility;
    }

    if (key == _spellClassKey(charClass)) {
      spellcastingAbility = normalizedAbility;
    } else if (spellcastingAbility == null && normalizedAbility != null) {
      spellcastingAbility = normalizedAbility;
    }
  }

  List<String> knownSpellIdsForClass(String className) {
    final key = _spellClassKey(className);
    final classIds = knownSpellIdsByClass[key];
    if (classIds != null) return List.unmodifiable(classIds);

    if (knownSpellIdsByClass.isEmpty && key == _spellClassKey(charClass)) {
      return List.unmodifiable(spellIds);
    }

    return const [];
  }

  List<String> preparedSpellIdsForClass(String className) {
    final key = _spellClassKey(className);
    final classIds = preparedSpellIdsByClass[key];
    if (classIds != null) return List.unmodifiable(classIds);

    if (preparedSpellIdsByClass.isEmpty && key == _spellClassKey(charClass)) {
      return List.unmodifiable(preparedSpellIds);
    }

    return const [];
  }

  void addKnownSpellForClass(String className, String spellId) {
    final key = _spellClassKey(className);
    final normalizedId = spellId.trim();
    if (key.isEmpty || normalizedId.isEmpty) return;

    _ensureLegacySpellBucketsForPrimary();

    final ids = knownSpellIdsByClass.putIfAbsent(key, () => []);
    if (!ids.contains(normalizedId)) {
      ids.add(normalizedId);
    }

    _syncLegacySpellLists();
  }

  void removeKnownSpellForClass(String className, String spellId) {
    final key = _spellClassKey(className);
    final normalizedId = spellId.trim();
    if (key.isEmpty || normalizedId.isEmpty) return;

    _ensureLegacySpellBucketsForPrimary();

    knownSpellIdsByClass[key]?.remove(normalizedId);
    preparedSpellIdsByClass[key]?.remove(normalizedId);
    _removeEmptySpellClassBuckets();
    _syncLegacySpellLists();
  }

  void togglePreparedSpellForClass(String className, String spellId) {
    final key = _spellClassKey(className);
    final normalizedId = spellId.trim();
    if (key.isEmpty || normalizedId.isEmpty) return;

    _ensureLegacySpellBucketsForPrimary();

    final knownIds = knownSpellIdsByClass[key];
    if (knownIds != null && !knownIds.contains(normalizedId)) return;
    if (knownIds == null && !spellIds.contains(normalizedId)) return;

    final ids = preparedSpellIdsByClass.putIfAbsent(key, () => []);
    if (ids.contains(normalizedId)) {
      ids.remove(normalizedId);
    } else {
      ids.add(normalizedId);
    }

    _removeEmptySpellClassBuckets();
    _syncLegacySpellLists();
  }

  void removePreparedSpellForClass(String className, String spellId) {
    final key = _spellClassKey(className);
    final normalizedId = spellId.trim();
    if (key.isEmpty || normalizedId.isEmpty) return;

    _ensureLegacySpellBucketsForPrimary();

    preparedSpellIdsByClass[key]?.remove(normalizedId);
    _removeEmptySpellClassBuckets();
    _syncLegacySpellLists();
  }

  void clearPreparedSpellsForClass(String className) {
    _ensureLegacySpellBucketsForPrimary();
    preparedSpellIdsByClass.remove(_spellClassKey(className));
    _syncLegacySpellLists();
  }

  void _ensureLegacySpellBucketsForPrimary() {
    final primaryKey = _spellClassKey(charClass);
    if (primaryKey.isEmpty) return;

    if (knownSpellIdsByClass.isEmpty && spellIds.isNotEmpty) {
      knownSpellIdsByClass[primaryKey] = [...spellIds];
    }

    if (preparedSpellIdsByClass.isEmpty && preparedSpellIds.isNotEmpty) {
      preparedSpellIdsByClass[primaryKey] = [...preparedSpellIds];
    }
  }

  void _removeEmptySpellClassBuckets() {
    knownSpellIdsByClass.removeWhere((_, ids) => ids.isEmpty);
    preparedSpellIdsByClass.removeWhere((_, ids) => ids.isEmpty);
  }

  void _syncLegacySpellLists() {
    final allKnown = <String>[];
    for (final ids in knownSpellIdsByClass.values) {
      for (final id in ids) {
        if (!allKnown.contains(id)) allKnown.add(id);
      }
    }

    final allPrepared = <String>[];
    for (final ids in preparedSpellIdsByClass.values) {
      for (final id in ids) {
        if (!allPrepared.contains(id)) allPrepared.add(id);
      }
    }

    if (allKnown.isNotEmpty || knownSpellIdsByClass.isNotEmpty) {
      spellIds
        ..clear()
        ..addAll(allKnown);
      knownSpells
        ..clear()
        ..addAll(allKnown);
    }

    preparedSpellIds
      ..clear()
      ..addAll(allPrepared);
    preparedSpells
      ..clear()
      ..addAll(allPrepared);
  }
}
