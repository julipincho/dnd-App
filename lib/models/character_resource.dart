class CharacterResource {
  String id;
  String name;
  int current;
  int max;
  String rechargeType; // shortRest, longRest, manual
  String? notes;

  CharacterResource({
    required this.id,
    required this.name,
    required this.current,
    required this.max,
    required this.rechargeType,
    this.notes,
  });

  factory CharacterResource.fromJson(Map<String, dynamic> json) {
    return CharacterResource(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      current: (json['current'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
      rechargeType: json['rechargeType']?.toString() ?? 'manual',
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'current': current,
      'max': max,
      'rechargeType': rechargeType,
      'notes': notes,
    };
  }
}
