import 'combat_turn_models.dart';

class Combatant {
  final String id;
  final String? sourceId;
  final String? ownerUserId;
  final String name;
  final String role;
  final int initiative;
  final int initiativeBonus;
  final int hp;
  final int maxHp;
  final int tempHp;
  final int ac;
  final int speed;
  final CombatTeam team;
  final String? portraitAsset;
  final Map<String, int> resourceMaximums;
  final Map<String, dynamic> metadata;
  final List<String> conditions;

  const Combatant({
    this.id = '',
    this.sourceId,
    this.ownerUserId,
    required this.name,
    required this.role,
    required this.initiative,
    required this.initiativeBonus,
    required this.hp,
    required this.maxHp,
    this.tempHp = 0,
    required this.ac,
    required this.speed,
    required this.team,
    this.portraitAsset,
    this.resourceMaximums = const {},
    this.metadata = const {},
    required this.conditions,
  });

  double get hpRatio {
    if (maxHp <= 0) return 0;
    return (hp / maxHp).clamp(0.0, 1.0);
  }

  Combatant copyWith({
    String? id,
    String? sourceId,
    String? ownerUserId,
    int? initiative,
    int? hp,
    int? maxHp,
    int? tempHp,
    int? ac,
    int? speed,
    String? portraitAsset,
    Map<String, int>? resourceMaximums,
    Map<String, dynamic>? metadata,
    List<String>? conditions,
  }) {
    return Combatant(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name,
      role: role,
      initiative: initiative ?? this.initiative,
      initiativeBonus: initiativeBonus,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      tempHp: tempHp ?? this.tempHp,
      ac: ac ?? this.ac,
      speed: speed ?? this.speed,
      team: team,
      portraitAsset: portraitAsset ?? this.portraitAsset,
      resourceMaximums: resourceMaximums ?? this.resourceMaximums,
      metadata: metadata ?? this.metadata,
      conditions: conditions ?? this.conditions,
    );
  }
}

class IndexedCombatant {
  final int index;
  final Combatant combatant;

  const IndexedCombatant(this.index, this.combatant);
}
