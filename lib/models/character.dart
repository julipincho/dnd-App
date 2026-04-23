import '../models/character_inventory_item.dart';
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
  List<String> knownSpells;
  List<String> preparedSpells;
  Map<String, int> spellSlots;

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
    this.armorClass,
    this.speed,
    this.backstory,
    this.notes,
    this.spellcastingAbility,
    List<String>? knownSpells,
    List<String>? preparedSpells,
    Map<String, int>? spellSlots,
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
  })  : classSkills = classSkills ?? [],
        features = features ?? [],
        resources = resources ?? [],
        savingThrows = savingThrows ?? [],
        inventory = inventory ?? [],
        knownSpells = knownSpells ?? [],
        preparedSpells = preparedSpells ?? [],
        deathSaveSuccesses = deathSaveSuccesses ?? 0,
        deathSaveFailures = deathSaveFailures ?? 0,
        selectedOptionGroups = selectedOptionGroups ?? [],
        spellSlots = spellSlots ?? {};

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
      armorClass: null,
      speed: null,
      backstory: '',
      notes: '',
      spellcastingAbility: null,
      knownSpells: const [],
      preparedSpells: const [],
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

    final preparedSpellIds = (json['preparedSpellIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

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
      subclass: json['subclass']?.toString(),
      charClass: json['charClass']?.toString() ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
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
      armorClass: (json['armorClass'] as num?)?.toInt(),
      speed: (json['speed'] as num?)?.toInt(),
      backstory: json['backstory']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      spellcastingAbility: json['spellcastingAbility']?.toString(),
      knownSpells:
          (json['knownSpells'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      preparedSpells: (json['preparedSpells'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      spellSlots: spellSlots,
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
    return {
      'ownerUserId': ownerUserId,
      'id': id,
      'name': name,
      'race': race,
      'subrace': subrace,
      'subclass': subclass,
      'charClass': charClass,
      'level': level,
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
      'knownSpells': knownSpells,
      'preparedSpells': preparedSpells,
      'spellIds': spellIds,
      'preparedSpellIds': preparedSpellIds,
      'spellSlots': spellSlots,
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
}
