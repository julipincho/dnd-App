import 'package:flutter/material.dart';

import 'combat_feedback.dart';

class CombatAction {
  final String id;
  final String name;
  final String type;
  final String timing;
  final String? attackFormula;
  final String? saveAbility;
  final int? saveDc;
  final String? damageFormula;
  final String? damageType;
  final String? critFormula;
  final int? rangeFeet;
  final int? longRangeFeet;
  final String areaShape;
  final int areaFeet;
  final int criticalThreshold;
  final List<String> tags;
  final IconData icon;
  final CombatAccentKind accentKind;
  final String? resourceKey;
  final int resourceCost;
  final bool targetsSelf;
  final String targetPolicy;
  final bool isHealing;
  final bool halfDamageOnSave;
  final bool grantsAction;
  final bool usesAttackAction;
  final int actionAttackSlots;
  final List<MultiAttackStep> multiAttackSteps;

  const CombatAction({
    this.id = '',
    required this.name,
    required this.type,
    required this.timing,
    required this.attackFormula,
    this.saveAbility,
    this.saveDc,
    required this.damageFormula,
    this.damageType,
    required this.critFormula,
    this.rangeFeet,
    this.longRangeFeet,
    this.areaShape = '',
    this.areaFeet = 0,
    this.criticalThreshold = 20,
    required this.tags,
    required this.icon,
    required this.accentKind,
    this.resourceKey,
    this.resourceCost = 0,
    this.targetsSelf = false,
    this.targetPolicy = '',
    this.isHealing = false,
    this.halfDamageOnSave = false,
    this.grantsAction = false,
    this.usesAttackAction = false,
    this.actionAttackSlots = 1,
    this.multiAttackSteps = const [],
  });

  bool get requiresSavingThrow => saveAbility != null && saveDc != null;
  bool get hasMultiAttack => multiAttackSteps.isNotEmpty;
  bool get hasAreaEffect => areaFeet > 0 && areaShape.trim().isNotEmpty;
}

class MultiAttackStep {
  final String name;
  final String? attackFormula;
  final String? damageFormula;
  final String? critFormula;
  final List<String> tags;

  const MultiAttackStep({
    required this.name,
    required this.attackFormula,
    required this.damageFormula,
    required this.critFormula,
    required this.tags,
  });
}
