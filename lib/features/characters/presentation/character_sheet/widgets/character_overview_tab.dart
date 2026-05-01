import 'package:flutter/material.dart';

import '../../../../../models/character.dart';
import '../../../../../models/character_inventory_item.dart';
import '../../../../../providers/compendium_provider.dart';
import '../../../../../providers/equipment_provider.dart';
import 'character_combat_summary_section.dart';
import '../../../models/resolved_inventory_item.dart';

class CharacterOverviewTab extends StatelessWidget {
  final Character char;
  final EquipmentProvider equipmentProvider;
  final CompendiumProvider compendiumProvider;
  final Future<void> Function() onManageCampaign;
  final int Function(String) getStat;

  final Widget header;

  final Widget Function({
    required BuildContext context,
    required Character char,
    required bool isTablet,
    required bool isLargeTablet,
  }) buildHpQuickActionsCard;

  final Widget Function({
    required String label,
    required String value,
    required IconData icon,
    required bool isTablet,
    required bool isLargeTablet,
  }) buildSummaryCard;

  final Widget Function({
    required String label,
    required String value,
    required IconData icon,
    required bool isTablet,
    required bool isLargeTablet,
    required VoidCallback onTap,
  }) buildInteractiveSummaryCard;

  final Widget Function(
    Character char,
    String label,
    int score, {
    bool isTablet,
    bool isLargeTablet,
  }) buildAbilityCard;

  final Widget Function({
    required bool isTablet,
    required bool isLargeTablet,
  }) buildRecentDiceRolls;

  final Widget Function(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) buildSavingThrowsSection;

  final Widget Function(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) buildSkillsSection;

  final Widget Function(
    BuildContext context,
    Character char, {
    required bool isTablet,
    required bool isLargeTablet,
  }) buildDeathSavesSection;

  final Future<void> Function() onOpenDiceRoller;
  final Future<void> Function() onLevelUp;
  final VoidCallback onGoToCampaign;
  final Future<void> Function() onEditSpeed;
  final Future<void> Function({
    required String label,
    required int modifier,
  }) onRollFromSheet;

  final int Function(Character char) getProficiencyBonus;
  final int Function(int dexScore) getInitiative;
  final int Function(Character char, int wisScore) getPassivePerception;
  final int Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) getEffectiveArmorClass;
  final int Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) getSpellSaveDc;
  final int Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) getSpellAttackBonus;
  final String? Function(Character char) getNormalizedSpellcastingAbility;
  final int Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) getSpellcastingAbilityModifier;
  final String Function(int value) formatSigned;

  final ResolvedInventoryItem? Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) resolveEquippedMainHandItem;

  final bool Function(ResolvedInventoryItem? item) isMainHandWeapon;
  final bool Function(ResolvedInventoryItem? item) isMainHandFocus;

  final CharacterInventoryItem? Function(Character char, String? itemId)
      findInventoryItemById;

  final ResolvedInventoryItem Function(
    CharacterInventoryItem item,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) resolveInventoryItem;
  final Future<int> Function(Character char) getEffectiveSpeed;

  final int? Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) calculateMainHandAttackBonus;

  final String Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) buildMainHandDamageText;

  final String Function(
    Character char,
    CharacterInventoryItem weaponItem,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) getWeaponAttackAbilityLabel;

  final int Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) computeSpellAttackBonus;

  final String? Function(Character char) normalizedSpellcastingAbility;

  final Future<void> Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) rollMainHandAttack;

  final Future<void> Function(
    Character char,
    EquipmentProvider equipmentProvider,
    CompendiumProvider compendiumProvider,
  ) rollMainHandDamage;

  const CharacterOverviewTab({
    super.key,
    required this.header,
    required this.onManageCampaign,
    required this.getEffectiveSpeed,
    required this.char,
    required this.equipmentProvider,
    required this.compendiumProvider,
    required this.getStat,
    required this.buildHpQuickActionsCard,
    required this.buildSummaryCard,
    required this.buildInteractiveSummaryCard,
    required this.buildAbilityCard,
    required this.buildRecentDiceRolls,
    required this.buildSavingThrowsSection,
    required this.buildSkillsSection,
    required this.buildDeathSavesSection,
    required this.onOpenDiceRoller,
    required this.onLevelUp,
    required this.onGoToCampaign,
    required this.onEditSpeed,
    required this.onRollFromSheet,
    required this.getProficiencyBonus,
    required this.getInitiative,
    required this.getPassivePerception,
    required this.getEffectiveArmorClass,
    required this.getSpellSaveDc,
    required this.getSpellAttackBonus,
    required this.getNormalizedSpellcastingAbility,
    required this.getSpellcastingAbilityModifier,
    required this.formatSigned,
    required this.resolveEquippedMainHandItem,
    required this.isMainHandWeapon,
    required this.isMainHandFocus,
    required this.findInventoryItemById,
    required this.resolveInventoryItem,
    required this.calculateMainHandAttackBonus,
    required this.buildMainHandDamageText,
    required this.getWeaponAttackAbilityLabel,
    required this.computeSpellAttackBonus,
    required this.normalizedSpellcastingAbility,
    required this.rollMainHandAttack,
    required this.rollMainHandDamage,
  });
  List<String> _uniqueValues(List<String> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty) continue;

      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        result.add(normalized);
      }
    }

    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Widget _buildSheetPanel({
    required String title,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String label, List<String> values) {
    final cleanValues = _uniqueValues(values);
    if (cleanValues.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cleanValues.join(', '),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProficienciesPanel(Character char) {
    final armor = [
      ...char.racialArmorProficiencies,
      ...char.featArmorProficiencies,
    ];
    final weapons = [
      ...char.racialWeaponProficiencies,
      ...char.featWeaponProficiencies,
    ];
    final tools = [
      ...char.racialToolProficiencies,
      ...char.featToolProficiencies,
    ];
    final languages = [
      ...char.racialLanguageProficiencies,
      ...char.featLanguageProficiencies,
    ];

    return _buildSheetPanel(
      title: 'Proficiencies & Languages',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBlock('Armor', armor),
          _buildInfoBlock('Weapons', weapons),
          _buildInfoBlock('Tools', tools),
          _buildInfoBlock('Languages', languages),
          if ([armor, weapons, tools, languages].every((list) => list.isEmpty))
            Text(
              'No proficiencies recorded yet.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefensesPanel(Character char) {
    final resistances = [
      ...char.racialResistances,
      ...char.featResistances,
    ];
    final immunities = [
      ...char.racialImmunities,
      ...char.featImmunities,
    ];
    final conditionImmunities = [
      ...char.racialConditionImmunities,
      ...char.featConditionImmunities,
    ];
    final senses = [
      ...char.racialSenses,
      ...char.featSenses,
    ];

    return _buildSheetPanel(
      title: 'Defenses & Senses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBlock('Resistances', resistances),
          _buildInfoBlock('Immunities', immunities),
          _buildInfoBlock('Conditions', conditionImmunities),
          _buildInfoBlock('Senses', senses),
          if ([resistances, immunities, conditionImmunities, senses]
              .every((list) => list.isEmpty))
            Text(
              'No defenses or senses recorded yet.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommandBar({
    required bool isTablet,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (char.campaignId != null && char.campaignId!.isNotEmpty)
          _buildCommandButton(
            label: 'Campaign',
            icon: Icons.flag_outlined,
            color: Colors.deepPurpleAccent,
            onTap: onGoToCampaign,
          ),
        _buildCommandButton(
          label: char.campaignId == null || char.campaignId!.isEmpty
              ? 'Assign Campaign'
              : 'Manage Campaign',
          icon: Icons.groups_outlined,
          color: Colors.blueAccent,
          onTap: onManageCampaign,
        ),
        _buildCommandButton(
          label: 'Dice',
          icon: Icons.casino_outlined,
          color: Colors.redAccent,
          onTap: onOpenDiceRoller,
        ),
        _buildCommandButton(
          label: 'Level Up',
          icon: Icons.arrow_upward,
          color: Colors.greenAccent,
          onTap: onLevelUp,
        ),
      ],
    );
  }

  Widget _buildCommandButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.13),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricStrip({
    required List<Widget> cards,
    required int columns,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricDashboard({
    required Widget hpCard,
    required Widget initiativeCard,
    required List<Widget> cards,
    required int columns,
  }) {
    if (columns <= 1) {
      return _buildMetricStrip(
        cards: [hpCard, initiativeCard, ...cards],
        columns: 1,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final primaryWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        final secondaryColumns = columns - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: primaryWidth,
              child: Column(
                children: [
                  hpCard,
                  const SizedBox(height: spacing),
                  initiativeCard,
                ],
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: _buildMetricStrip(
                cards: cards,
                columns: secondaryColumns,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAbilityRail({
    required Character char,
    required bool isTablet,
    required bool isLargeTablet,
    required int statColumns,
    required double statAspectRatio,
    required int str,
    required int dex,
    required int con,
    required int intScore,
    required int wis,
    required int cha,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF191A22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'ABILITIES',
              style: TextStyle(
                color: Colors.white.withOpacity(0.68),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: statColumns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: statAspectRatio,
            children: [
              buildAbilityCard(
                char,
                "STR",
                str,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              buildAbilityCard(
                char,
                "DEX",
                dex,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              buildAbilityCard(
                char,
                "CON",
                con,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              buildAbilityCard(
                char,
                "INT",
                intScore,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              buildAbilityCard(
                char,
                "WIS",
                wis,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
              buildAbilityCard(
                char,
                "CHA",
                cha,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;

    final maxContentWidth = isLargeTablet ? 1180.0 : 900.0;
    final pagePadding = isLargeTablet ? 28.0 : (isTablet ? 24.0 : 16.0);
    final statColumns = isLargeTablet ? 6 : 3;
    final statAspectRatio = isLargeTablet ? 1.28 : (isTablet ? 1.12 : 0.98);
    final dashboardColumns = isLargeTablet ? 4 : (isTablet ? 3 : 2);

    final str = getStat("STR");
    final dex = getStat("DEX");
    final con = getStat("CON");
    final intScore = getStat("INT");
    final wis = getStat("WIS");
    final cha = getStat("CHA");

    final proficiency = getProficiencyBonus(char);
    final initiative = getInitiative(dex);
    final passivePerception = getPassivePerception(char, wis);

    final liveArmorClass = getEffectiveArmorClass(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    late final Future<int> speedFuture = getEffectiveSpeed(char);
    final spellAbilityKey = getNormalizedSpellcastingAbility(char);
    final spellAbilityModifier = getSpellcastingAbilityModifier(
      char,
      equipmentProvider,
      compendiumProvider,
    );
    final spellSaveDc = getSpellSaveDc(
      char,
      equipmentProvider,
      compendiumProvider,
    );
    final currentSpellAttackBonus = getSpellAttackBonus(
      char,
      equipmentProvider,
      compendiumProvider,
    );

    final hpCard = buildHpQuickActionsCard(
      context: context,
      char: char,
      isTablet: isTablet,
      isLargeTablet: isLargeTablet,
    );

    final initiativeCard = buildInteractiveSummaryCard(
      label: 'Initiative',
      value: formatSigned(initiative),
      icon: Icons.bolt_outlined,
      isTablet: isTablet,
      isLargeTablet: isLargeTablet,
      onTap: () => onRollFromSheet(
        label: 'Initiative',
        modifier: initiative,
      ),
    );

    final summaryCards = <Widget>[
      buildSummaryCard(
        label: 'AC',
        value: '$liveArmorClass',
        icon: Icons.shield_outlined,
        isTablet: isTablet,
        isLargeTablet: isLargeTablet,
      ),
      FutureBuilder<int>(
        future: speedFuture,
        builder: (context, snapshot) {
          final value = snapshot.hasData ? '${snapshot.data} ft' : '-';

          return buildInteractiveSummaryCard(
            label: 'Speed',
            value: value,
            icon: Icons.directions_run_outlined,
            isTablet: isTablet,
            isLargeTablet: isLargeTablet,
            onTap: () => onEditSpeed(),
          );
        },
      ),
      buildSummaryCard(
        label: 'Prof.',
        value: formatSigned(proficiency),
        icon: Icons.military_tech_outlined,
        isTablet: isTablet,
        isLargeTablet: isLargeTablet,
      ),
      buildSummaryCard(
        label: 'Passive Perception',
        value: '$passivePerception',
        icon: Icons.visibility_outlined,
        isTablet: isTablet,
        isLargeTablet: isLargeTablet,
      ),
      buildSummaryCard(
        label: 'Spell Save DC',
        value: spellAbilityKey == null ? '-' : '$spellSaveDc',
        icon: Icons.shield_moon_outlined,
        isTablet: isTablet,
        isLargeTablet: isLargeTablet,
      ),
      buildSummaryCard(
        label: 'Spell Attack',
        value: spellAbilityKey == null
            ? '-'
            : formatSigned(currentSpellAttackBonus),
        icon: Icons.bolt_outlined,
        isTablet: isTablet,
        isLargeTablet: isLargeTablet,
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(pagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _buildCommandBar(isTablet: isTablet),
              ),
              const SizedBox(height: 10),
              _buildMetricDashboard(
                hpCard: hpCard,
                initiativeCard: initiativeCard,
                cards: summaryCards,
                columns: dashboardColumns,
              ),
              const SizedBox(height: 10),
              _buildAbilityRail(
                char: char,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet,
                statColumns: statColumns,
                statAspectRatio: statAspectRatio,
                str: str,
                dex: dex,
                con: con,
                intScore: intScore,
                wis: wis,
                cha: cha,
              ),
              const SizedBox(height: 18),
              if (isLargeTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          buildSavingThrowsSection(
                            context,
                            char,
                            isTablet: isTablet,
                            isLargeTablet: isLargeTablet,
                          ),
                          const SizedBox(height: 12),
                          _buildDefensesPanel(char),
                          const SizedBox(height: 12),
                          _buildProficienciesPanel(char),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 300,
                      child: buildSkillsSection(
                        context,
                        char,
                        isTablet: isTablet,
                        isLargeTablet: isLargeTablet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          CharacterCombatSummarySection(
                            char: char,
                            equipmentProvider: equipmentProvider,
                            compendiumProvider: compendiumProvider,
                            isTablet: isTablet,
                            isLargeTablet: isLargeTablet,
                            resolveEquippedMainHandItem:
                                resolveEquippedMainHandItem,
                            isMainHandWeapon: isMainHandWeapon,
                            isMainHandFocus: isMainHandFocus,
                            findInventoryItemById: findInventoryItemById,
                            resolveInventoryItem: resolveInventoryItem,
                            calculateMainHandAttackBonus:
                                calculateMainHandAttackBonus,
                            buildMainHandDamageText: buildMainHandDamageText,
                            getWeaponAttackAbilityLabel:
                                getWeaponAttackAbilityLabel,
                            computeSpellAttackBonus: computeSpellAttackBonus,
                            normalizedSpellcastingAbility:
                                normalizedSpellcastingAbility,
                            rollMainHandAttack: rollMainHandAttack,
                            rollMainHandDamage: rollMainHandDamage,
                            formatSigned: formatSigned,
                          ),
                          const SizedBox(height: 12),
                          buildDeathSavesSection(
                            context,
                            char,
                            isTablet: isTablet,
                            isLargeTablet: isLargeTablet,
                          ),
                          const SizedBox(height: 12),
                          buildRecentDiceRolls(
                            isTablet: isTablet,
                            isLargeTablet: isLargeTablet,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                CharacterCombatSummarySection(
                  char: char,
                  equipmentProvider: equipmentProvider,
                  compendiumProvider: compendiumProvider,
                  isTablet: isTablet,
                  isLargeTablet: isLargeTablet,
                  resolveEquippedMainHandItem: resolveEquippedMainHandItem,
                  isMainHandWeapon: isMainHandWeapon,
                  isMainHandFocus: isMainHandFocus,
                  findInventoryItemById: findInventoryItemById,
                  resolveInventoryItem: resolveInventoryItem,
                  calculateMainHandAttackBonus: calculateMainHandAttackBonus,
                  buildMainHandDamageText: buildMainHandDamageText,
                  getWeaponAttackAbilityLabel: getWeaponAttackAbilityLabel,
                  computeSpellAttackBonus: computeSpellAttackBonus,
                  normalizedSpellcastingAbility: normalizedSpellcastingAbility,
                  rollMainHandAttack: rollMainHandAttack,
                  rollMainHandDamage: rollMainHandDamage,
                  formatSigned: formatSigned,
                ),
                const SizedBox(height: 12),
                buildSavingThrowsSection(
                  context,
                  char,
                  isTablet: isTablet,
                  isLargeTablet: isLargeTablet,
                ),
                const SizedBox(height: 12),
                buildSkillsSection(
                  context,
                  char,
                  isTablet: isTablet,
                  isLargeTablet: isLargeTablet,
                ),
                const SizedBox(height: 12),
                _buildDefensesPanel(char),
                const SizedBox(height: 12),
                _buildProficienciesPanel(char),
                const SizedBox(height: 12),
                buildDeathSavesSection(
                  context,
                  char,
                  isTablet: isTablet,
                  isLargeTablet: isLargeTablet,
                ),
                const SizedBox(height: 12),
                buildRecentDiceRolls(
                  isTablet: isTablet,
                  isLargeTablet: isLargeTablet,
                ),
              ],
              const SizedBox(height: 18),
              if (spellAbilityKey != null)
                Text(
                  'Spellcasting: $spellAbilityKey (${formatSigned(spellAbilityModifier)})',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
