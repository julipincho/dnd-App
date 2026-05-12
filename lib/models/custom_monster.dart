import 'combat_encounter.dart';

class CustomMonster {
  final String id;
  final String name;
  final String size;
  final String type;
  final String? subtype;
  final String? challengeRating;
  final String? portraitPath;
  final int armorClass;
  final int hitPoints;
  final int speed;
  final int initiativeBonus;
  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;
  final bool hideHpFromPlayers;
  final List<CustomMonsterAction> actions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomMonster({
    required this.id,
    required this.name,
    required this.size,
    required this.type,
    this.subtype,
    this.challengeRating,
    this.portraitPath,
    required this.armorClass,
    required this.hitPoints,
    required this.speed,
    required this.initiativeBonus,
    required this.strength,
    required this.dexterity,
    required this.constitution,
    required this.intelligence,
    required this.wisdom,
    required this.charisma,
    required this.hideHpFromPlayers,
    required this.actions,
    required this.createdAt,
    required this.updatedAt,
  });

  String get role {
    final subtypeText =
        subtype == null || subtype!.trim().isEmpty ? '' : ' ${subtype!.trim()}';
    final crText = challengeRating == null || challengeRating!.trim().isEmpty
        ? ''
        : ' - CR ${challengeRating!.trim()}';
    return '${size.trim()} ${type.trim()}$subtypeText$crText';
  }

  int get passiveCount =>
      actions.where((item) => item.timing == CombatActionTiming.passive).length;

  int get activeActionCount => actions.length - passiveCount;

  factory CustomMonster.fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.now();
    return CustomMonster(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Custom Monster',
      size: json['size']?.toString() ?? 'Medium',
      type: json['type']?.toString() ?? 'creature',
      subtype: _nullableString(json['subtype']),
      challengeRating: _nullableString(json['challengeRating']),
      portraitPath: _nullableString(json['portraitPath']),
      armorClass: _intFromJson(json['armorClass'], fallback: 10),
      hitPoints: _intFromJson(json['hitPoints'], fallback: 1),
      speed: _intFromJson(json['speed'], fallback: 30),
      initiativeBonus: _intFromJson(json['initiativeBonus'], fallback: 0),
      strength: _intFromJson(json['strength'], fallback: 10),
      dexterity: _intFromJson(json['dexterity'], fallback: 10),
      constitution: _intFromJson(json['constitution'], fallback: 10),
      intelligence: _intFromJson(json['intelligence'], fallback: 10),
      wisdom: _intFromJson(json['wisdom'], fallback: 10),
      charisma: _intFromJson(json['charisma'], fallback: 10),
      hideHpFromPlayers: json['hideHpFromPlayers'] as bool? ?? true,
      actions: _listOfMaps(json['actions'])
          .map(CustomMonsterAction.fromJson)
          .toList(growable: false),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? timestamp,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'size': size,
      'type': type,
      'subtype': subtype,
      'challengeRating': challengeRating,
      'portraitPath': portraitPath,
      'armorClass': armorClass,
      'hitPoints': hitPoints,
      'speed': speed,
      'initiativeBonus': initiativeBonus,
      'strength': strength,
      'dexterity': dexterity,
      'constitution': constitution,
      'intelligence': intelligence,
      'wisdom': wisdom,
      'charisma': charisma,
      'hideHpFromPlayers': hideHpFromPlayers,
      'actions': actions.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  CustomMonster copyWith({
    String? id,
    String? name,
    String? size,
    String? type,
    String? subtype,
    String? challengeRating,
    String? portraitPath,
    int? armorClass,
    int? hitPoints,
    int? speed,
    int? initiativeBonus,
    int? strength,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
    bool? hideHpFromPlayers,
    List<CustomMonsterAction>? actions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomMonster(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      challengeRating: challengeRating ?? this.challengeRating,
      portraitPath: portraitPath ?? this.portraitPath,
      armorClass: armorClass ?? this.armorClass,
      hitPoints: hitPoints ?? this.hitPoints,
      speed: speed ?? this.speed,
      initiativeBonus: initiativeBonus ?? this.initiativeBonus,
      strength: strength ?? this.strength,
      dexterity: dexterity ?? this.dexterity,
      constitution: constitution ?? this.constitution,
      intelligence: intelligence ?? this.intelligence,
      wisdom: wisdom ?? this.wisdom,
      charisma: charisma ?? this.charisma,
      hideHpFromPlayers: hideHpFromPlayers ?? this.hideHpFromPlayers,
      actions: actions ?? this.actions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CustomMonsterAction {
  final String id;
  final String name;
  final String description;
  final CombatActionTiming timing;
  final CombatActionRollKind rollKind;
  final int? attackBonus;
  final String? damageFormula;
  final String? damageType;
  final String? healingFormula;
  final String? saveAbility;
  final int? saveDc;
  final bool halfDamageOnSave;
  final bool targetsSelf;
  final bool isRanged;
  final List<String> tags;
  final List<CustomMonsterMultiattackStep> multiattackSteps;

  const CustomMonsterAction({
    required this.id,
    required this.name,
    required this.description,
    required this.timing,
    required this.rollKind,
    this.attackBonus,
    this.damageFormula,
    this.damageType,
    this.healingFormula,
    this.saveAbility,
    this.saveDc,
    this.halfDamageOnSave = false,
    this.targetsSelf = false,
    this.isRanged = false,
    this.tags = const [],
    this.multiattackSteps = const [],
  });

  bool get isPassive => timing == CombatActionTiming.passive;

  factory CustomMonsterAction.fromJson(Map<String, dynamic> json) {
    return CustomMonsterAction(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Action',
      description: json['description']?.toString() ?? '',
      timing: _enumFromName(
        CombatActionTiming.values,
        json['timing']?.toString(),
        CombatActionTiming.action,
      ),
      rollKind: _enumFromName(
        CombatActionRollKind.values,
        json['rollKind']?.toString(),
        CombatActionRollKind.none,
      ),
      attackBonus: _optionalIntFromJson(json['attackBonus']),
      damageFormula: _nullableString(json['damageFormula']),
      damageType: _nullableString(json['damageType']),
      healingFormula: _nullableString(json['healingFormula']),
      saveAbility: _nullableString(json['saveAbility']),
      saveDc: _optionalIntFromJson(json['saveDc']),
      halfDamageOnSave: json['halfDamageOnSave'] as bool? ?? false,
      targetsSelf: json['targetsSelf'] as bool? ?? false,
      isRanged: json['isRanged'] as bool? ?? false,
      tags: _stringList(json['tags']),
      multiattackSteps: _listOfMaps(json['multiattackSteps'])
          .map(CustomMonsterMultiattackStep.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'timing': timing.name,
      'rollKind': rollKind.name,
      'attackBonus': attackBonus,
      'damageFormula': damageFormula,
      'damageType': damageType,
      'healingFormula': healingFormula,
      'saveAbility': saveAbility,
      'saveDc': saveDc,
      'halfDamageOnSave': halfDamageOnSave,
      'targetsSelf': targetsSelf,
      'isRanged': isRanged,
      'tags': tags,
      'multiattackSteps':
          multiattackSteps.map((item) => item.toJson()).toList(),
    };
  }

  CustomMonsterAction copyWith({
    String? id,
    String? name,
    String? description,
    CombatActionTiming? timing,
    CombatActionRollKind? rollKind,
    int? attackBonus,
    String? damageFormula,
    String? damageType,
    String? healingFormula,
    String? saveAbility,
    int? saveDc,
    bool? halfDamageOnSave,
    bool? targetsSelf,
    bool? isRanged,
    List<String>? tags,
    List<CustomMonsterMultiattackStep>? multiattackSteps,
  }) {
    return CustomMonsterAction(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      timing: timing ?? this.timing,
      rollKind: rollKind ?? this.rollKind,
      attackBonus: attackBonus ?? this.attackBonus,
      damageFormula: damageFormula ?? this.damageFormula,
      damageType: damageType ?? this.damageType,
      healingFormula: healingFormula ?? this.healingFormula,
      saveAbility: saveAbility ?? this.saveAbility,
      saveDc: saveDc ?? this.saveDc,
      halfDamageOnSave: halfDamageOnSave ?? this.halfDamageOnSave,
      targetsSelf: targetsSelf ?? this.targetsSelf,
      isRanged: isRanged ?? this.isRanged,
      tags: tags ?? this.tags,
      multiattackSteps: multiattackSteps ?? this.multiattackSteps,
    );
  }
}

class CustomMonsterMultiattackStep {
  final String actionName;
  final int count;

  const CustomMonsterMultiattackStep({
    required this.actionName,
    required this.count,
  });

  factory CustomMonsterMultiattackStep.fromJson(Map<String, dynamic> json) {
    return CustomMonsterMultiattackStep(
      actionName: json['actionName']?.toString() ?? '',
      count: _intFromJson(json['count'], fallback: 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionName': actionName,
      'count': count,
    };
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

int _intFromJson(Object? raw, {required int fallback}) {
  return _optionalIntFromJson(raw) ?? fallback;
}

int? _optionalIntFromJson(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toInt();
  final text = raw.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  return int.tryParse(text);
}

List<Map<String, dynamic>> _listOfMaps(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

T _enumFromName<T extends Enum>(
  List<T> values,
  String? name,
  T fallback,
) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
