import '../features/characters/models/resolved_inventory_item.dart';
import '../logic/character_option_effects.dart';
import '../models/character.dart';
import '../models/character_feature.dart';
import '../models/character_inventory_item.dart';
import '../models/character_resource.dart';
import '../models/combat_encounter.dart';
import '../models/compendium_entry.dart';
import '../models/equipment_compendium_item.dart';
import '../models/spell.dart';
import '../utils/character_equipment_effects.dart';
import 'character_inventory_service.dart';
import 'character_spell_slot_service.dart';
import 'character_weapon_attack_service.dart';

class CharacterCombatBuild {
  final Combatant combatant;
  final List<PreparedCombatAction> availableActions;

  const CharacterCombatBuild({
    required this.combatant,
    required this.availableActions,
  });
}

class _IntrinsicAttackSpec {
  final String idSuffix;
  final String name;
  final String abilityLabel;
  final int abilityModifier;
  final String? damageDice;
  final int? flatDamage;
  final String damageType;
  final String source;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  const _IntrinsicAttackSpec({
    required this.idSuffix,
    required this.name,
    required this.abilityLabel,
    required this.abilityModifier,
    required this.damageType,
    required this.source,
    this.damageDice,
    this.flatDamage,
    this.tags = const [],
    this.metadata = const {},
  });
}

class _NaturalWeaponPattern {
  final String id;
  final String name;
  final List<String> keywords;
  final String defaultDice;
  final String damageType;

  const _NaturalWeaponPattern({
    required this.id,
    required this.name,
    required this.keywords,
    required this.defaultDice,
    required this.damageType,
  });
}

class CharacterCombatBuilderService {
  const CharacterCombatBuilderService._();

  static CharacterCombatBuild build({
    required Character character,
    required List<EquipmentCompendiumItem> equipmentItems,
    required List<CompendiumEntry> compendiumEntries,
    required List<Spell> spells,
  }) {
    final maxHp = (character.maxHp ?? 0) <= 0 ? 1 : character.maxHp!;
    final currentHp = (character.currentHp ?? maxHp).clamp(0, maxHp).toInt();
    final rawTempHp = character.tempHp ?? 0;
    final tempHp = rawTempHp < 0 ? 0 : rawTempHp;
    final dexScore = _effectiveAbilityScore(
      character,
      'DEX',
      equipmentItems,
      compendiumEntries,
    );
    final initiativeBonus =
        _abilityModifier(dexScore) + character.featInitiativeBonus;
    final name = character.name.trim().isEmpty ? 'Hero' : character.name.trim();
    final role = [
      if (character.race.trim().isNotEmpty) character.race.trim(),
      character.classProgressionLabel,
    ].where((item) => item.trim().isNotEmpty).join(' - ');
    final proficiencyBonus = _proficiencyBonus(character.level);

    final availableActions = _buildAvailableActions(
      character,
      equipmentItems,
      compendiumEntries,
      spells,
    );

    return CharacterCombatBuild(
      combatant: Combatant(
        id: _combatantIdForCharacter(character),
        name: name,
        sourceId: character.id,
        kind: CombatantKind.playerCharacter,
        team: CombatantTeam.party,
        role: role,
        initiative: 10 + initiativeBonus,
        initiativeBonus: initiativeBonus,
        hp: currentHp,
        maxHp: maxHp,
        tempHp: tempHp,
        armorClass: _effectiveArmorClass(
          character,
          equipmentItems,
          compendiumEntries,
        ),
        speed: (character.speed ?? 30) + character.featSpeedBonus,
        resources: _resourceMap(character),
        effects: _passiveEffects(character),
        metadata: {
          'characterId': character.id,
          if ((character.ownerUserId ?? '').trim().isNotEmpty)
            'ownerUserId': character.ownerUserId!.trim(),
          if ((character.portraitPath ?? '').trim().isNotEmpty)
            'portraitPath': character.portraitPath!.trim(),
          'race': character.race,
          'classProgression': character.classProgressionLabel,
          'abilityScores': {
            for (final ability in ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'])
              ability: _effectiveAbilityScore(
                character,
                ability,
                equipmentItems,
                compendiumEntries,
              ),
          },
          'savingThrowBonuses': {
            for (final ability in ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'])
              ability: _savingThrowBonus(
                character,
                ability,
                equipmentItems,
                compendiumEntries,
                proficiencyBonus,
              ),
          },
          'proficiencyBonus': proficiencyBonus,
          'availableActionCount': availableActions.length,
        },
      ),
      availableActions: availableActions,
    );
  }

  static List<PreparedCombatAction> _buildAvailableActions(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    List<Spell> spells,
  ) {
    final actions = <PreparedCombatAction>[];
    final proficiencyBonus = _proficiencyBonus(character.level);
    final weapons = _prioritizedCombatWeapons(
      character,
      equipmentItems,
      compendiumEntries,
    );
    final attackActionCount = _extraAttackCount(character);

    for (final resolvedWeapon in weapons.take(6)) {
      final weapon = resolvedWeapon.effectiveItem;
      final abilityLabel = CharacterWeaponAttackService.attackAbilityLabel(
        character: character,
        weaponItem: weapon,
        getAbilityScore: (ability) => _effectiveAbilityScore(
          character,
          ability,
          equipmentItems,
          compendiumEntries,
        ),
        getAbilityModifier: _abilityModifier,
      );
      final attackBonus = _weaponAttackBonus(
        character,
        resolvedWeapon,
        equipmentItems,
        compendiumEntries,
        proficiencyBonus,
      );
      final damageBonus = _weaponDamageBonus(
        character,
        resolvedWeapon,
        equipmentItems,
        compendiumEntries,
      );
      final damageDice = (weapon.damageDice ?? '').trim();
      final damageFormula = damageDice.isEmpty
          ? null
          : _formatRollFormula(damageDice, damageBonus);
      final damageType = weapon.damageType?.trim();

      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'weapon', weapon.id),
          name: weapon.name.trim().isEmpty ? 'Weapon Attack' : weapon.name,
          timing: CombatActionTiming.action,
          rollKind: CombatActionRollKind.attack,
          attackFormula: _formatRollFormula('d20', attackBonus),
          damageFormula: damageFormula,
          tags: [
            abilityLabel,
            if (weapon.isEquipped) 'Equipped',
            if (weapon.isFinesse) 'Finesse',
            if (weapon.isRanged) 'Ranged' else 'Melee',
            if (resolvedWeapon.equipmentItem?.isMagic == true) 'Magic',
            if (weapon.hasInfusion) 'Infused',
            if (damageType != null && damageType.isNotEmpty) damageType,
          ],
          metadata: {
            'source': 'weapon',
            'inventoryItemId': weapon.id,
            'weaponType': weapon.isRanged ? 'ranged' : 'melee',
            'damageType': damageType,
            'criticalDamageFormula': damageDice.isEmpty
                ? null
                : _formatRollFormula(
                    _doubleDiceFormula(damageDice),
                    damageBonus,
                  ),
          },
        ),
      );

      if (attackActionCount > 1) {
        actions.add(
          PreparedCombatAction(
            id: _actionId(
              character,
              'weapon_multi',
              '${weapon.id}_x$attackActionCount',
            ),
            name:
                '${weapon.name.trim().isEmpty ? 'Weapon' : weapon.name} x$attackActionCount',
            timing: CombatActionTiming.action,
            rollKind: CombatActionRollKind.attack,
            tags: [
              abilityLabel,
              'Extra Attack',
              '$attackActionCount attacks',
              if (weapon.isRanged) 'Ranged' else 'Melee',
              if (damageType != null && damageType.isNotEmpty) damageType,
            ],
            metadata: {
              'source': 'weaponMultiattack',
              'baseWeaponActionId': weapon.id,
              'attackCount': attackActionCount,
              'multiattack': true,
              'multiAttackSteps': [
                for (var index = 0; index < attackActionCount; index++)
                  {
                    'name': weapon.name.trim().isEmpty
                        ? 'Weapon Attack'
                        : weapon.name,
                    'attackFormula': _formatRollFormula('d20', attackBonus),
                    'damageFormula': damageFormula,
                    if (damageFormula != null)
                      'criticalDamageFormula': _formatRollFormula(
                        _doubleDiceFormula(damageDice),
                        damageBonus,
                      ),
                    'tags': [
                      abilityLabel,
                      if (weapon.isRanged) 'Ranged' else 'Melee',
                      if (damageType != null && damageType.isNotEmpty)
                        damageType,
                    ],
                  },
              ],
            },
          ),
        );
      }
    }

    actions.addAll(
      _intrinsicAttackActions(
        character,
        equipmentItems,
        compendiumEntries,
        proficiencyBonus,
        attackActionCount,
      ),
    );

    final spellActions = _spellActions(
      character,
      spells,
      equipmentItems,
      compendiumEntries,
      proficiencyBonus,
    );
    actions.addAll(spellActions);

    final spellAttack = _spellAttackAction(
      character,
      equipmentItems,
      compendiumEntries,
      proficiencyBonus,
    );
    if (spellAttack != null && spellActions.isEmpty) actions.add(spellAttack);
    actions.addAll(_featureActions(character));
    actions.addAll(_resourceActions(character));

    return actions;
  }

  static List<ResolvedInventoryItem> _prioritizedCombatWeapons(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    final weaponIds = {
      character.equippedMainHandItemId,
      character.equippedOffHandItemId,
      character.pactWeaponItemId,
    }.whereType<String>().where((id) => id.trim().isNotEmpty).toSet();

    final weapons = character.inventory
        .map(
          (item) => CharacterInventoryService.resolveInventoryItem(
            inventoryItem: item,
            equipmentItems: equipmentItems,
            compendiumEntries: compendiumEntries,
          ),
        )
        .where(_isCombatWeapon)
        .toList();

    weapons.sort((a, b) {
      final aEquipped =
          weaponIds.contains(a.originalItem.id) || a.effectiveItem.isEquipped;
      final bEquipped =
          weaponIds.contains(b.originalItem.id) || b.effectiveItem.isEquipped;
      if (aEquipped != bEquipped) return aEquipped ? -1 : 1;
      return a.effectiveItem.name
          .toLowerCase()
          .compareTo(b.effectiveItem.name.toLowerCase());
    });
    return weapons;
  }

  static bool _isCombatWeapon(ResolvedInventoryItem item) {
    final effective = item.effectiveItem;
    return effective.itemType == EquipItemType.weapon ||
        item.equipmentItem?.isWeapon == true ||
        effective.allowedSlots.contains(EquipSlot.weaponMainHand) ||
        effective.allowedSlots.contains(EquipSlot.weaponOffHand) ||
        (effective.damageDice ?? '').trim().isNotEmpty;
  }

  static List<PreparedCombatAction> _intrinsicAttackActions(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
    int attackActionCount,
  ) {
    final strMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'STR',
        equipmentItems,
        compendiumEntries,
      ),
    );
    final dexMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'DEX',
        equipmentItems,
        compendiumEntries,
      ),
    );
    final monkLevel = _classLevel(character, const ['monk', 'monje']);
    final bestMartialMod = dexMod > strMod ? dexMod : strMod;
    final bestMartialAbility = dexMod > strMod ? 'DEX' : 'STR';
    final baseUnarmedDamage = 1 + strMod;
    final specs = <_IntrinsicAttackSpec>[
      _IntrinsicAttackSpec(
        idSuffix: 'unarmed_strike',
        name: 'Unarmed Strike',
        abilityLabel: monkLevel > 0 ? bestMartialAbility : 'STR',
        abilityModifier: monkLevel > 0 ? bestMartialMod : strMod,
        damageDice: monkLevel > 0 ? _martialArtsDie(monkLevel) : null,
        flatDamage: monkLevel > 0
            ? null
            : baseUnarmedDamage < 1
                ? 1
                : baseUnarmedDamage,
        damageType: 'Bludgeoning',
        source: 'unarmed',
        tags: [
          'Unarmed',
          if (monkLevel > 0) 'Martial Arts',
        ],
        metadata: {
          if (monkLevel > 0) 'monkLevel': monkLevel,
        },
      ),
      ..._naturalWeaponSpecs(
        character,
        equipmentItems,
        compendiumEntries,
      ),
    ];

    final actions = <PreparedCombatAction>[];
    for (final spec in specs) {
      final action = _intrinsicAttackAction(
        character,
        spec,
        proficiencyBonus,
      );
      actions.add(action);

      if (attackActionCount > 1) {
        actions.add(
          _intrinsicMultiattackAction(
            character,
            spec,
            proficiencyBonus,
            attackActionCount,
            action,
          ),
        );
      }
    }

    return actions;
  }

  static PreparedCombatAction _intrinsicAttackAction(
    Character character,
    _IntrinsicAttackSpec spec,
    int proficiencyBonus,
  ) {
    final attackBonus = spec.abilityModifier + proficiencyBonus;
    final damageFormula = _intrinsicDamageFormula(spec);
    final criticalDamageFormula = _intrinsicCriticalDamageFormula(spec);

    return PreparedCombatAction(
      id: _actionId(character, spec.source, spec.idSuffix),
      name: spec.name,
      timing: CombatActionTiming.action,
      rollKind: CombatActionRollKind.attack,
      attackFormula: _formatRollFormula('d20', attackBonus),
      damageFormula: damageFormula,
      tags: [
        spec.abilityLabel,
        ...spec.tags,
        'Melee',
        spec.damageType,
      ],
      metadata: {
        'source': spec.source,
        'weaponType': 'melee',
        'damageType': spec.damageType,
        'intrinsicAttack': true,
        ...spec.metadata,
        if (criticalDamageFormula != null)
          'criticalDamageFormula': criticalDamageFormula,
      },
    );
  }

  static PreparedCombatAction _intrinsicMultiattackAction(
    Character character,
    _IntrinsicAttackSpec spec,
    int proficiencyBonus,
    int attackActionCount,
    PreparedCombatAction baseAction,
  ) {
    final attackBonus = spec.abilityModifier + proficiencyBonus;
    final damageFormula = _intrinsicDamageFormula(spec);
    final criticalDamageFormula = _intrinsicCriticalDamageFormula(spec);

    return PreparedCombatAction(
      id: _actionId(
        character,
        '${spec.source}_multi',
        '${spec.idSuffix}_x$attackActionCount',
      ),
      name: '${spec.name} x$attackActionCount',
      timing: CombatActionTiming.action,
      rollKind: CombatActionRollKind.attack,
      tags: [
        spec.abilityLabel,
        'Extra Attack',
        '$attackActionCount attacks',
        ...spec.tags,
        'Melee',
        spec.damageType,
      ],
      metadata: {
        'source': '${spec.source}Multiattack',
        'baseActionId': baseAction.id,
        'attackCount': attackActionCount,
        'multiattack': true,
        'intrinsicAttack': true,
        ...spec.metadata,
        'multiAttackSteps': [
          for (var index = 0; index < attackActionCount; index++)
            {
              'name': spec.name,
              'attackFormula': _formatRollFormula('d20', attackBonus),
              'damageFormula': damageFormula,
              if (criticalDamageFormula != null)
                'criticalDamageFormula': criticalDamageFormula,
              'tags': [
                spec.abilityLabel,
                ...spec.tags,
                'Melee',
                spec.damageType,
              ],
            },
        ],
      },
    );
  }

  static List<_IntrinsicAttackSpec> _naturalWeaponSpecs(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    final strMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        'STR',
        equipmentItems,
        compendiumEntries,
      ),
    );
    final specs = <_IntrinsicAttackSpec>[];
    final seen = <String>{};
    for (final feature in character.features) {
      final searchText = _normalizedSearchText(
        '${feature.name} ${feature.description}',
      );
      for (final pattern in _naturalWeaponPatterns) {
        if (!pattern.keywords.any(searchText.contains)) continue;

        final dice = _naturalWeaponDice(searchText, pattern);
        final key = '${pattern.id}|$dice|${pattern.damageType}';
        if (!seen.add(key)) continue;

        specs.add(
          _IntrinsicAttackSpec(
            idSuffix: '${feature.id}_${pattern.id}',
            name: pattern.name,
            abilityLabel: 'STR',
            abilityModifier: strMod,
            damageDice: dice,
            damageType: pattern.damageType,
            source: 'naturalWeapon',
            tags: [
              'Natural Weapon',
              _featureSourceLabel(feature),
            ],
            metadata: {
              'featureId': feature.id,
              'featureSource': feature.source,
            },
          ),
        );
      }
    }
    return specs;
  }

  static const List<_NaturalWeaponPattern> _naturalWeaponPatterns = [
    _NaturalWeaponPattern(
      id: 'claws',
      name: 'Claws',
      keywords: ['claw', 'claws', 'garra', 'garras'],
      defaultDice: '1d4',
      damageType: 'Slashing',
    ),
    _NaturalWeaponPattern(
      id: 'bite',
      name: 'Bite',
      keywords: ['bite', 'fang', 'fangs', 'mordida', 'colmillo', 'colmillos'],
      defaultDice: '1d6',
      damageType: 'Piercing',
    ),
    _NaturalWeaponPattern(
      id: 'horns',
      name: 'Horns',
      keywords: ['horn', 'horns', 'cuerno', 'cuernos'],
      defaultDice: '1d6',
      damageType: 'Piercing',
    ),
    _NaturalWeaponPattern(
      id: 'talons',
      name: 'Talons',
      keywords: ['talon', 'talons'],
      defaultDice: '1d4',
      damageType: 'Slashing',
    ),
    _NaturalWeaponPattern(
      id: 'hooves',
      name: 'Hooves',
      keywords: ['hoof', 'hooves', 'pezuna', 'pezunas'],
      defaultDice: '1d4',
      damageType: 'Bludgeoning',
    ),
    _NaturalWeaponPattern(
      id: 'tail',
      name: 'Tail',
      keywords: ['tail', 'cola'],
      defaultDice: '1d8',
      damageType: 'Piercing',
    ),
  ];

  static String _naturalWeaponDice(
    String searchText,
    _NaturalWeaponPattern pattern,
  ) {
    for (final keyword in pattern.keywords) {
      final index = searchText.indexOf(keyword);
      if (index < 0) continue;
      final start = index - 120 < 0 ? 0 : index - 120;
      final end =
          index + 220 > searchText.length ? searchText.length : index + 220;
      final nearby = searchText.substring(start, end);
      final formula = _firstDiceFormula(nearby);
      if (formula != null) return _diceOnlyFormula(formula);
    }
    return pattern.defaultDice;
  }

  static String _intrinsicDamageFormula(_IntrinsicAttackSpec spec) {
    if (spec.damageDice != null) {
      return _formatRollFormula(spec.damageDice!, spec.abilityModifier);
    }
    return '${spec.flatDamage ?? 1}';
  }

  static String? _intrinsicCriticalDamageFormula(_IntrinsicAttackSpec spec) {
    if (spec.damageDice == null) return _intrinsicDamageFormula(spec);
    return _formatRollFormula(
      _doubleDiceFormula(spec.damageDice!),
      spec.abilityModifier,
    );
  }

  static int _weaponAttackBonus(
    Character character,
    ResolvedInventoryItem resolvedWeapon,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    if (resolvedWeapon.originalItem.id == character.equippedMainHandItemId) {
      return CharacterWeaponAttackService.mainHandAttackBonus(
        character: character,
        resolvedWeapon: resolvedWeapon,
        getAbilityScore: (ability) => _effectiveAbilityScore(
          character,
          ability,
          equipmentItems,
          compendiumEntries,
        ),
        getAbilityModifier: _abilityModifier,
        proficiencyBonus: proficiencyBonus,
      );
    }

    final weapon = resolvedWeapon.effectiveItem;
    final abilityMod = CharacterWeaponAttackService.attackAbilityModifier(
      character: character,
      weaponItem: weapon,
      getAbilityScore: (ability) => _effectiveAbilityScore(
        character,
        ability,
        equipmentItems,
        compendiumEntries,
      ),
      getAbilityModifier: _abilityModifier,
    );
    final proficiency = CharacterWeaponAttackService.isProficientWithWeapon(
      character: character,
      weaponItem: weapon,
      equipmentItem: resolvedWeapon.equipmentItem,
    )
        ? proficiencyBonus
        : 0;
    final itemAttackBonus = resolvedWeapon.equipmentItem?.attackBonus ?? 0;
    return abilityMod + proficiency + itemAttackBonus;
  }

  static int _weaponDamageBonus(
    Character character,
    ResolvedInventoryItem resolvedWeapon,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    if (resolvedWeapon.originalItem.id == character.equippedMainHandItemId) {
      return CharacterWeaponAttackService.mainHandDamageBonus(
        character: character,
        resolvedWeapon: resolvedWeapon,
        hasOffHandWeaponEquipped:
            (character.equippedOffHandItemId ?? '').trim().isNotEmpty,
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
        getAbilityScore: (ability) => _effectiveAbilityScore(
          character,
          ability,
          equipmentItems,
          compendiumEntries,
        ),
        getAbilityModifier: _abilityModifier,
      );
    }

    final weapon = resolvedWeapon.effectiveItem;
    final abilityMod = CharacterWeaponAttackService.attackAbilityModifier(
      character: character,
      weaponItem: weapon,
      getAbilityScore: (ability) => _effectiveAbilityScore(
        character,
        ability,
        equipmentItems,
        compendiumEntries,
      ),
      getAbilityModifier: _abilityModifier,
    );
    final itemDamageBonus = resolvedWeapon.equipmentItem?.damageBonus ?? 0;
    return abilityMod + itemDamageBonus;
  }

  static PreparedCombatAction? _spellAttackAction(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final ability = _spellcastingAbility(character);
    if (ability == null) return null;

    final abilityMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        ability,
        equipmentItems,
        compendiumEntries,
      ),
    );
    final attackBonus = abilityMod +
        proficiencyBonus +
        _passiveSpellAttackBonus(character, equipmentItems, compendiumEntries);

    return PreparedCombatAction(
      id: _actionId(character, 'spellcasting', 'spell_attack'),
      name: 'Spell Attack',
      timing: CombatActionTiming.action,
      rollKind: CombatActionRollKind.attack,
      attackFormula: _formatRollFormula('d20', attackBonus),
      tags: [ability, 'Manual Damage'],
      metadata: {
        'source': 'spellcasting',
        'spellcastingAbility': ability,
      },
    );
  }

  static List<PreparedCombatAction> _spellActions(
    Character character,
    List<Spell> spells,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final spellById = {for (final spell in spells) spell.id: spell};
    final spellIds = <String>{
      ...character.preparedSpellIds,
      ...character.preparedSpells,
      ...character.preparedSpellIdsByClass.values.expand((ids) => ids),
    }..removeWhere((id) => id.trim().isEmpty);

    if (spellIds.isEmpty) {
      spellIds.addAll(character.spellIds.take(8));
    }

    final ability = _spellcastingAbility(character);
    final spellAttackBonus = ability == null
        ? 0
        : _abilityModifier(
              _effectiveAbilityScore(
                character,
                ability,
                equipmentItems,
                compendiumEntries,
              ),
            ) +
            proficiencyBonus +
            _passiveSpellAttackBonus(
              character,
              equipmentItems,
              compendiumEntries,
            );

    final actions = <PreparedCombatAction>[];
    for (final spellId in spellIds) {
      final spell = spellById[spellId];
      if (spell == null) continue;

      final damageFormula = _firstDiceFormula(spell.description);
      final usesAttackRoll = _spellUsesAttackRoll(spell);
      final mentionsSave = _spellMentionsSave(spell);
      final saveAbility =
          mentionsSave ? _firstSaveAbility(spell.description) : null;
      final healingSpell = _spellLooksLikeHealing(spell.description);
      final saveDc = saveAbility == null
          ? null
          : _spellSaveDc(
              character,
              equipmentItems,
              compendiumEntries,
              proficiencyBonus,
            );
      final spellFlow = usesAttackRoll
          ? 'attack'
          : saveAbility != null
              ? 'save'
              : healingSpell
                  ? 'healing'
                  : damageFormula != null
                      ? 'damage'
                      : 'effect';
      actions.add(
        PreparedCombatAction(
          id: _actionId(character, 'spell', spell.id),
          name: spell.name,
          timing: _timingFromCastingTime(spell.castingTime),
          rollKind: usesAttackRoll
              ? CombatActionRollKind.attack
              : saveAbility != null
                  ? CombatActionRollKind.savingThrow
                  : healingSpell
                      ? CombatActionRollKind.healing
                      : damageFormula != null
                          ? CombatActionRollKind.damage
                          : CombatActionRollKind.none,
          attackFormula: usesAttackRoll
              ? _formatRollFormula('d20', spellAttackBonus)
              : null,
          damageFormula: healingSpell ? null : damageFormula,
          healingFormula: healingSpell ? damageFormula : null,
          saveAbility: saveAbility,
          saveDc: saveDc,
          resourceKey: spell.level > 0 ? 'spellSlot:${spell.level}' : null,
          resourceCost: spell.level > 0 ? 1 : 0,
          tags: [
            spell.school,
            spell.range,
            if (spell.level == 0) 'Cantrip' else 'Slot ${spell.level}',
            if (spell.duration.toLowerCase().contains('concentration'))
              'Concentration',
            if (saveAbility != null && saveDc != null)
              '$saveAbility DC $saveDc',
            if (usesAttackRoll) 'Spell Attack',
            if (healingSpell) 'Healing',
          ],
          metadata: {
            'source': 'spell',
            'spellFlow': spellFlow,
            'spellId': spell.id,
            'level': spell.level,
            'castingTime': spell.castingTime,
            'duration': spell.duration,
            'halfDamageOnSave': _spellDealsHalfDamageOnSave(spell.description),
            'criticalDamageFormula': usesAttackRoll && damageFormula != null
                ? _doubleDamageFormula(damageFormula)
                : null,
          },
        ),
      );
    }
    return actions;
  }

  static List<PreparedCombatAction> _featureActions(Character character) {
    return character.features.where(_isUsableCombatFeature).map((feature) {
      final diceFormula = _firstDiceFormula(feature.description);
      final grantsActionSurge = _isActionSurgeText(
        '${feature.name} ${feature.description}',
      );
      return PreparedCombatAction(
        id: _actionId(character, 'feature', feature.id),
        name: feature.name.trim().isEmpty ? 'Class Feature' : feature.name,
        timing: _timingForFeature(feature),
        rollKind: diceFormula == null
            ? CombatActionRollKind.none
            : _looksLikeHealing(feature.description)
                ? CombatActionRollKind.healing
                : CombatActionRollKind.damage,
        damageFormula:
            _looksLikeHealing(feature.description) ? null : diceFormula,
        healingFormula:
            _looksLikeHealing(feature.description) ? diceFormula : null,
        resourceKey: (feature.linkedResourceId ?? '').trim().isEmpty
            ? null
            : feature.linkedResourceId!.trim(),
        resourceCost: (feature.linkedResourceId ?? '').trim().isEmpty ? 0 : 1,
        tags: [
          _featureSourceLabel(feature),
          if (grantsActionSurge) 'Extra Action',
          if (feature.unlockedAtLevel != null)
            'Level ${feature.unlockedAtLevel}',
          if ((feature.linkedResourceId ?? '').trim().isNotEmpty) 'Resource',
        ],
        metadata: {
          'source': 'feature',
          'featureId': feature.id,
          'featureSource': feature.source,
          'description': feature.description,
          if (grantsActionSurge) 'combatEffect': 'actionSurge',
          if (grantsActionSurge) 'grantsAction': true,
        },
      );
    }).toList();
  }

  static bool _isUsableCombatFeature(CharacterFeature feature) {
    final linkedResource = (feature.linkedResourceId ?? '').trim();
    final text = '${feature.name} ${feature.description}'.toLowerCase();

    if (linkedResource.isNotEmpty) return true;
    if (_firstDiceFormula(feature.description) != null) return true;

    final activeSignals = [
      'as an action',
      'use your action',
      'bonus action',
      'reaction',
      'when you hit',
      'when you take damage',
      'when you are hit',
      'you can use',
      'you may use',
      'you can expend',
      'you can spend',
      'activate',
      'rage',
      'bardic inspiration',
      'channel divinity',
      'lay on hands',
      'second wind',
      'action surge',
      'wild shape',
      'superiority die',
      'ki point',
    ];
    if (activeSignals.any(text.contains)) return true;

    final passiveSignals = [
      'you gain proficiency',
      'you are proficient',
      'your speed increases',
      'your walking speed',
      'darkvision',
      'resistance to',
      'you have resistance',
      'you have advantage',
      'you can speak',
      'you know',
      'your maximum',
      'unarmored defense',
      'fighting style',
      'extra attack',
      'ability score',
      'language',
      'armor class',
    ];
    if (passiveSignals.any(text.contains)) return false;

    return false;
  }

  static List<PreparedCombatAction> _resourceActions(Character character) {
    return character.resources.map((resource) {
      final diceFormula = _firstDiceFormula(resource.notes ?? '');
      final healing =
          _looksLikeHealing('${resource.name} ${resource.notes ?? ''}');
      final grantsActionSurge = _isActionSurgeText(
        '${resource.name} ${resource.notes ?? ''}',
      );
      return PreparedCombatAction(
        id: _actionId(character, 'resource', resource.id),
        name: resource.name.trim().isEmpty ? 'Resource' : resource.name,
        timing: _timingForResource(resource),
        rollKind: diceFormula == null
            ? CombatActionRollKind.resource
            : healing
                ? CombatActionRollKind.healing
                : CombatActionRollKind.damage,
        damageFormula: healing ? null : diceFormula,
        healingFormula: healing ? diceFormula : null,
        resourceKey: resource.id,
        resourceCost: 1,
        tags: [
          '${resource.current}/${resource.max}',
          _resourceRechargeLabel(resource),
          if (grantsActionSurge) 'Extra Action',
        ],
        metadata: {
          'source': 'resource',
          'resourceId': resource.id,
          'rechargeType': resource.rechargeType,
          'notes': resource.notes,
          if (grantsActionSurge) 'combatEffect': 'actionSurge',
          if (grantsActionSurge) 'grantsAction': true,
        },
      );
    }).toList();
  }

  static List<CombatEffect> _passiveEffects(Character character) {
    final effects = <CombatEffect>[];
    final targetId = _combatantIdForCharacter(character);

    void addEffect({
      required String id,
      required String name,
      required CombatEffectKind kind,
      Map<String, dynamic> mechanics = const {},
    }) {
      effects.add(
        CombatEffect(
          id: _actionId(character, 'passive_effect', id),
          name: name,
          kind: kind,
          sourceCombatantId: targetId,
          targetCombatantId: targetId,
          mechanics: mechanics,
        ),
      );
    }

    for (final resistance in [
      ...character.racialResistances,
      ...character.featResistances,
    ]) {
      addEffect(
        id: 'resist_${_slug(resistance)}',
        name: 'Resist $resistance',
        kind: CombatEffectKind.buff,
        mechanics: {'resistance': resistance},
      );
    }

    for (final immunity in [
      ...character.racialImmunities,
      ...character.featImmunities,
    ]) {
      addEffect(
        id: 'immune_${_slug(immunity)}',
        name: 'Immune $immunity',
        kind: CombatEffectKind.buff,
        mechanics: {'immunity': immunity},
      );
    }

    if (character.cannotBeSurprisedWhileConscious) {
      addEffect(
        id: 'cannot_be_surprised',
        name: 'Cannot be surprised',
        kind: CombatEffectKind.buff,
      );
    }

    if (character.unseenAttackersNoAdvantage) {
      addEffect(
        id: 'no_unseen_advantage',
        name: 'No unseen advantage',
        kind: CombatEffectKind.buff,
      );
    }

    return effects;
  }

  static Map<String, int> _resourceMap(Character character) {
    final result = {
      for (final resource in character.resources)
        if (resource.id.trim().isNotEmpty) resource.id: resource.current,
    };

    for (var level = 1; level <= 9; level++) {
      if (CharacterSpellSlotService.slotMaxForLevel(character, level) > 0) {
        result['spellSlot:$level'] =
            CharacterSpellSlotService.slotRemainingForLevel(character, level);
      }
      if (CharacterSpellSlotService.pactMagicSlotMaxForLevel(
            character,
            level,
          ) >
          0) {
        result['pactMagicSlot:$level'] =
            CharacterSpellSlotService.pactMagicSlotRemainingForLevel(
          character,
          level,
        );
      }
    }

    return result;
  }

  static int _savingThrowBonus(
    Character character,
    String ability,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final normalizedAbility = ability.toUpperCase();
    final score = _effectiveAbilityScore(
      character,
      normalizedAbility,
      equipmentItems,
      compendiumEntries,
    );
    final proficient = character.savingThrows.any(
      (item) => _normalizeSavingThrowAbility(item) == normalizedAbility,
    );
    return _abilityModifier(score) + (proficient ? proficiencyBonus : 0);
  }

  static String _normalizeSavingThrowAbility(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.contains('STRENGTH')) return 'STR';
    if (normalized.contains('DEXTERITY')) return 'DEX';
    if (normalized.contains('CONSTITUTION')) return 'CON';
    if (normalized.contains('INTELLIGENCE')) return 'INT';
    if (normalized.contains('WISDOM')) return 'WIS';
    if (normalized.contains('CHARISMA')) return 'CHA';
    if (normalized.contains('STR')) return 'STR';
    if (normalized.contains('DEX')) return 'DEX';
    if (normalized.contains('CON')) return 'CON';
    if (normalized.contains('INT')) return 'INT';
    if (normalized.contains('WIS')) return 'WIS';
    if (normalized.contains('CHA')) return 'CHA';
    const aliases = {
      'STRENGTH': 'STR',
      'DEXTERITY': 'DEX',
      'CONSTITUTION': 'CON',
      'INTELLIGENCE': 'INT',
      'WISDOM': 'WIS',
      'CHARISMA': 'CHA',
    };
    return aliases[normalized] ?? normalized;
  }

  static int _effectiveAbilityScore(
    Character character,
    String ability,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    return CharacterEquipmentEffects.getEffectiveAbilityScore(
      char: character,
      ability: ability,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
  }

  static int _effectiveArmorClass(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    final dexScore = _effectiveAbilityScore(
      character,
      'DEX',
      equipmentItems,
      compendiumEntries,
    );
    final dexModifier = _abilityModifier(dexScore);
    final baseAc = CharacterEquipmentEffects.calculateEffectiveArmorClass(
      char: character,
      dexModifier: dexModifier,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
    final resolvedArmor = _resolveInventoryItemById(
      character,
      character.equippedArmorItemId,
      equipmentItems,
      compendiumEntries,
    );
    final resolvedShield = _resolveInventoryItemById(
      character,
      character.equippedShieldItemId,
      equipmentItems,
      compendiumEntries,
    );
    final isWearingArmor = resolvedArmor != null &&
        resolvedArmor.effectiveItem.itemType == EquipItemType.armor;
    final optionBonus =
        CharacterOptionEffects.getPassiveArmorClassBonusFromOptions(
      character: character,
      isWearingArmor: isWearingArmor,
    );
    final infusedArmorBonus = CharacterOptionEffects.getInfusedArmorClassBonus(
      character: character,
      armorItem: resolvedArmor?.effectiveItem,
      shieldItem: resolvedShield?.effectiveItem,
    );
    return baseAc + optionBonus + infusedArmorBonus;
  }

  static int _passiveSpellAttackBonus(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    final passiveBonus = CharacterEquipmentEffects.getPassiveSpellAttackBonus(
      char: character,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
    final resolvedMainHand = _resolveInventoryItemById(
      character,
      character.equippedMainHandItemId,
      equipmentItems,
      compendiumEntries,
    );
    final resolvedOffHand = _resolveInventoryItemById(
      character,
      character.equippedOffHandItemId,
      equipmentItems,
      compendiumEntries,
    );
    final infusedBonus = CharacterOptionEffects.getInfusedSpellAttackBonus(
      character: character,
      mainHandItem: resolvedMainHand?.effectiveItem,
      offHandItem: resolvedOffHand?.effectiveItem,
      mainHandEquipmentItem: resolvedMainHand?.equipmentItem,
      offHandEquipmentItem: resolvedOffHand?.equipmentItem,
    );
    return passiveBonus + infusedBonus;
  }

  static int? _spellSaveDc(
    Character character,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
    int proficiencyBonus,
  ) {
    final ability = _spellcastingAbility(character);
    if (ability == null) return null;
    final abilityMod = _abilityModifier(
      _effectiveAbilityScore(
        character,
        ability,
        equipmentItems,
        compendiumEntries,
      ),
    );
    final passiveBonus = CharacterEquipmentEffects.getPassiveSpellSaveDcBonus(
      char: character,
      equipmentItems: equipmentItems,
      compendiumEntries: compendiumEntries,
    );
    return 8 + proficiencyBonus + abilityMod + passiveBonus;
  }

  static ResolvedInventoryItem? _resolveInventoryItemById(
    Character character,
    String? itemId,
    List<EquipmentCompendiumItem> equipmentItems,
    List<CompendiumEntry> compendiumEntries,
  ) {
    if (itemId == null || itemId.trim().isEmpty) return null;
    for (final item in character.inventory) {
      if (item.id != itemId) continue;
      return CharacterInventoryService.resolveInventoryItem(
        inventoryItem: item,
        equipmentItems: equipmentItems,
        compendiumEntries: compendiumEntries,
      );
    }
    return null;
  }

  static String? _spellcastingAbility(Character character) {
    final direct = character.spellcastingAbility?.trim().toUpperCase();
    if (direct != null && direct.isNotEmpty) return direct;

    for (final value in character.spellcastingAbilitiesByClass.values) {
      final normalized = value.trim().toUpperCase();
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  static int _abilityModifier(int score) => ((score - 10) / 2).floor();

  static int _classLevel(Character character, List<String> classNames) {
    final normalizedNames = classNames.map(_normalizedSearchText).toSet();
    var result = 0;
    for (final entry in character.classLevels.entries) {
      if (!normalizedNames.contains(_normalizedSearchText(entry.key))) {
        continue;
      }
      if (entry.value > result) result = entry.value;
    }
    return result;
  }

  static String _martialArtsDie(int monkLevel) {
    if (monkLevel >= 17) return '1d10';
    if (monkLevel >= 11) return '1d8';
    if (monkLevel >= 5) return '1d6';
    return '1d4';
  }

  static int _proficiencyBonus(int level) {
    final safeLevel = level < 1 ? 1 : level;
    return 2 + ((safeLevel - 1) ~/ 4);
  }

  static String _formatRollFormula(String dice, int modifier) {
    if (modifier == 0) return dice;
    return modifier > 0 ? '$dice+$modifier' : '$dice$modifier';
  }

  static String? _firstDiceFormula(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(
      r'(\d+d\d+(?:\s*[+-]\s*\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;
    return match.group(1)?.replaceAll(' ', '').toLowerCase();
  }

  static String _diceOnlyFormula(String formula) {
    final match = RegExp(
      r'^(\d*)d(\d+)',
      caseSensitive: false,
    ).firstMatch(formula.trim());
    if (match == null) return formula.trim().toLowerCase();
    final count = (match.group(1) ?? '').isEmpty ? '1' : match.group(1)!;
    return '${count}d${match.group(2)}'.toLowerCase();
  }

  static String? _doubleDamageFormula(String formula) {
    final match = RegExp(
      r'^(\d*)d(\d+)([+-]\d+)?$',
      caseSensitive: false,
    ).firstMatch(formula.trim());
    if (match == null) return null;

    final rawCount = match.group(1);
    final count =
        rawCount == null || rawCount.isEmpty ? 1 : int.tryParse(rawCount) ?? 1;
    final sides = match.group(2);
    final modifier = match.group(3) ?? '';
    if (sides == null || sides.isEmpty) return null;
    return '${count * 2}d$sides$modifier';
  }

  static String _doubleDiceFormula(String dice) {
    final match =
        RegExp(r'^(\d*)d(\d+)$', caseSensitive: false).firstMatch(dice.trim());
    if (match == null) return dice;

    final rawCount = match.group(1);
    final count =
        rawCount == null || rawCount.isEmpty ? 1 : int.tryParse(rawCount) ?? 1;
    final sides = match.group(2);
    if (sides == null || sides.isEmpty) return dice;
    return '${count * 2}d$sides';
  }

  static bool _spellUsesAttackRoll(Spell spell) {
    final text = '${spell.description} ${spell.range}'.toLowerCase();
    return text.contains('spell attack') || text.contains('ranged attack');
  }

  static bool _spellMentionsSave(Spell spell) {
    final text = spell.description.toLowerCase();
    return text.contains('saving throw') || text.contains('save');
  }

  static bool _spellDealsHalfDamageOnSave(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('half as much') ||
        normalized.contains('half damage') ||
        normalized.contains('half the damage');
  }

  static bool _spellLooksLikeHealing(String text) {
    final lower = text.toLowerCase();
    return lower.contains('regain') ||
        lower.contains('healing') ||
        lower.contains('heals') ||
        lower.contains('restore');
  }

  static String? _firstSaveAbility(String text) {
    final match = RegExp(
      r'(strength|dexterity|constitution|intelligence|wisdom|charisma)\s+saving throw',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.substring(0, 3).toUpperCase();
  }

  static CombatActionTiming _timingFromCastingTime(String castingTime) {
    final text = castingTime.toLowerCase();
    if (text.contains('bonus')) return CombatActionTiming.bonusAction;
    if (text.contains('reaction')) return CombatActionTiming.reaction;
    return CombatActionTiming.action;
  }

  static int _extraAttackCount(Character character) {
    var count = 1;
    for (final feature in character.features) {
      final text = '${feature.name} ${feature.description}'.toLowerCase();
      if (!text.contains('extra attack')) continue;
      if (text.contains('four times') ||
          text.contains('four attacks') ||
          text.contains('three additional')) {
        count = count < 4 ? 4 : count;
      } else if (text.contains('three times') ||
          text.contains('three attacks') ||
          text.contains('two additional')) {
        count = count < 3 ? 3 : count;
      } else {
        count = count < 2 ? 2 : count;
      }
    }
    return count;
  }

  static CombatActionTiming _timingForFeature(CharacterFeature feature) {
    final text = '${feature.name} ${feature.description}'.toLowerCase();
    if (text.contains('reaction')) return CombatActionTiming.reaction;
    if (_isActionSurgeText(text)) return CombatActionTiming.bonusAction;
    if (text.contains('bonus action') ||
        text.contains('rage') ||
        text.contains('second wind') ||
        text.contains('bardic inspiration')) {
      return CombatActionTiming.bonusAction;
    }
    if (text.contains('when you hit')) return CombatActionTiming.onHit;
    if (text.contains('when you take damage')) {
      return CombatActionTiming.onDamageTaken;
    }
    return CombatActionTiming.action;
  }

  static String _featureSourceLabel(CharacterFeature feature) {
    final source = feature.source.trim().toLowerCase();
    if (source.isEmpty) return 'Feature';
    if (source.contains('race') || source.contains('racial')) {
      return 'Racial Feature';
    }
    if (source.contains('feat')) return 'Feat Feature';
    if (source.contains('background')) return 'Background Feature';
    if (source.contains('subclass')) return 'Subclass Feature';
    if (source.contains('class')) return 'Class Feature';
    return '${source[0].toUpperCase()}${source.substring(1)} Feature';
  }

  static CombatActionTiming _timingForResource(CharacterResource resource) {
    final text = '${resource.name} ${resource.notes ?? ''}'.toLowerCase();
    if (text.contains('reaction')) return CombatActionTiming.reaction;
    if (_isActionSurgeText(text)) return CombatActionTiming.bonusAction;
    if (text.contains('bonus')) return CombatActionTiming.bonusAction;
    return CombatActionTiming.action;
  }

  static String _resourceRechargeLabel(CharacterResource resource) {
    return switch (resource.rechargeType) {
      'shortRest' => 'Short Rest',
      'longRest' => 'Long Rest',
      _ => 'Manual',
    };
  }

  static bool _looksLikeHealing(String text) {
    final lower = text.toLowerCase();
    return lower.contains('heal') ||
        lower.contains('regain') ||
        lower.contains('recover') ||
        lower.contains('hit points');
  }

  static bool _isActionSurgeText(String text) {
    final lower = text.toLowerCase();
    final normalized = lower
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    return normalized.contains('action surge') ||
        normalized.contains('action sourge') ||
        (normalized.contains('action') &&
            (normalized.contains('surge') || normalized.contains('sourge'))) ||
        normalized.contains('additional action') ||
        normalized.contains('one additional action') ||
        normalized.contains('accion adicional') ||
        normalized.contains('oleada de accion');
  }

  static String _normalizedSearchText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('\u00e1', 'a')
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00ed', 'i')
        .replaceAll('\u00f3', 'o')
        .replaceAll('\u00fa', 'u')
        .replaceAll('\u00f1', 'n')
        .replaceAll('\u00c3\u00a1', 'a')
        .replaceAll('\u00c3\u00a9', 'e')
        .replaceAll('\u00c3\u00ad', 'i')
        .replaceAll('\u00c3\u00b3', 'o')
        .replaceAll('\u00c3\u00ba', 'u')
        .replaceAll('\u00c3\u00b1', 'n');
  }

  static String _combatantIdForCharacter(Character character) {
    return 'character_${character.id}';
  }

  static String _actionId(Character character, String source, String value) {
    return '${_combatantIdForCharacter(character)}_${source}_${_slug(value)}';
  }

  static String _slug(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
