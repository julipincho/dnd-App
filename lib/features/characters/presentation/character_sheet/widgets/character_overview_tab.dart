import 'package:flutter/material.dart';

import '../../../../../models/character.dart';
import '../../../../../models/character_inventory_item.dart';
import '../../../../../providers/compendium_provider.dart';
import '../../../../../providers/equipment_provider.dart';
import '../../../../../theme.dart';
import '../../../../../widgets/stitch_codex_ui.dart';
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
  final VoidCallback onOpenCombatMode;
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
    required this.onOpenCombatMode,
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
    required IconData icon,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return StitchCodexPanel(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      StitchCodexPalette.bronze.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color:
                        StitchCodexPalette.bronze.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(
                  icon,
                  color: StitchCodexPalette.bronze,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StitchCodexPalette.textPrimary,
                    fontFamily: StitchTypography.display,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
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
            style: const TextStyle(
              color: StitchCodexPalette.bronze,
              fontFamily: StitchTypography.data,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cleanValues.join(', '),
            style: const TextStyle(
              color: StitchCodexPalette.textSecondary,
              fontFamily: StitchTypography.body,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
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
      icon: Icons.workspace_premium_outlined,
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
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
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
      icon: Icons.health_and_safety_outlined,
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
              style: const TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
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
    return StitchCodexPanel(
      padding: const EdgeInsets.all(10),
      emphasized: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: isTablet ? WrapAlignment.end : WrapAlignment.center,
        children: [
          if (char.campaignId != null && char.campaignId!.isNotEmpty)
            _buildCommandButton(
              label: 'Campaign',
              icon: Icons.flag_outlined,
              color: StitchCodexPalette.bronze,
              onTap: onGoToCampaign,
            ),
          _buildCommandButton(
            label: char.campaignId == null || char.campaignId!.isEmpty
                ? 'Assign Campaign'
                : 'Manage Campaign',
            icon: Icons.groups_outlined,
            color: StitchCodexPalette.textSecondary,
            onTap: onManageCampaign,
          ),
          _buildCommandButton(
            label: 'Dice',
            icon: Icons.casino_outlined,
            color: StitchCodexPalette.crimsonBright,
            onTap: onOpenDiceRoller,
          ),
          _buildCommandButton(
            label: 'Combat',
            icon: Icons.sports_martial_arts_outlined,
            color: StitchCodexPalette.bronze,
            onTap: onOpenCombatMode,
          ),
          _buildCommandButton(
            label: 'Level Up',
            icon: Icons.arrow_upward,
            color: StitchCodexPalette.success,
            onTap: onLevelUp,
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: StitchCodexPalette.textSecondary,
                  fontFamily: StitchTypography.data,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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

  Widget _buildTopCombatDashboard({
    required Widget hpCard,
    required Widget initiativeCard,
    required List<Widget> summaryCards,
    required Widget abilityRail,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final leftWidth = constraints.maxWidth < 1120 ? 330.0 : 355.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: leftWidth,
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
              child: Column(
                children: [
                  _buildMetricStrip(
                    cards: summaryCards,
                    columns: 3,
                  ),
                  const SizedBox(height: spacing),
                  abilityRail,
                ],
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
    bool compact = false,
    required int statColumns,
    required double statAspectRatio,
    required int str,
    required int dex,
    required int con,
    required int intScore,
    required int wis,
    required int cha,
  }) {
    final panelPadding = compact ? 10.0 : 12.0;
    final titleBottomPadding = compact ? 6.0 : 8.0;
    final gridSpacing = compact ? 6.0 : 8.0;

    return StitchCodexPanel(
      padding: EdgeInsets.all(panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 2, bottom: titleBottomPadding),
            child: Text(
              'ABILITIES',
              style: const TextStyle(
                color: StitchCodexPalette.bronze,
                fontFamily: StitchTypography.data,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: statColumns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
            childAspectRatio: statAspectRatio,
            children: [
              buildAbilityCard(
                char,
                "STR",
                str,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet && !compact,
              ),
              buildAbilityCard(
                char,
                "DEX",
                dex,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet && !compact,
              ),
              buildAbilityCard(
                char,
                "CON",
                con,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet && !compact,
              ),
              buildAbilityCard(
                char,
                "INT",
                intScore,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet && !compact,
              ),
              buildAbilityCard(
                char,
                "WIS",
                wis,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet && !compact,
              ),
              buildAbilityCard(
                char,
                "CHA",
                cha,
                isTablet: isTablet,
                isLargeTablet: isLargeTablet && !compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsColumn({
    required List<Widget> children,
    double spacing = 12,
  }) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(height: spacing),
          children[index],
        ],
      ],
    );
  }

  Widget _buildLargeDetailsLayout({
    required BuildContext context,
    required bool useDesktopColumns,
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    final savingThrows = buildSavingThrowsSection(
      context,
      char,
      isTablet: isTablet,
      isLargeTablet: isLargeTablet,
    );
    final skills = buildSkillsSection(
      context,
      char,
      isTablet: isTablet,
      isLargeTablet: isLargeTablet,
    );
    final combat = CharacterCombatSummarySection(
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
    );
    final deathSaves = buildDeathSavesSection(
      context,
      char,
      isTablet: isTablet,
      isLargeTablet: isLargeTablet,
    );
    final recentRolls = buildRecentDiceRolls(
      isTablet: isTablet,
      isLargeTablet: isLargeTablet,
    );
    final defenses = _buildDefensesPanel(char);
    final proficiencies = _buildProficienciesPanel(char);

    if (useDesktopColumns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 292,
            child: _buildDetailsColumn(
              children: [
                savingThrows,
                defenses,
                proficiencies,
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 318,
            child: skills,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDetailsColumn(
              children: [
                combat,
                deathSaves,
                recentRolls,
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 8,
          child: _buildDetailsColumn(
            children: [
              savingThrows,
              skills,
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 9,
          child: _buildDetailsColumn(
            children: [
              combat,
              deathSaves,
              defenses,
              proficiencies,
              recentRolls,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStackedDetailsLayout({
    required BuildContext context,
    required bool isTablet,
    required bool isLargeTablet,
  }) {
    return _buildDetailsColumn(
      children: [
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
        buildSavingThrowsSection(
          context,
          char,
          isTablet: isTablet,
          isLargeTablet: isLargeTablet,
        ),
        buildSkillsSection(
          context,
          char,
          isTablet: isTablet,
          isLargeTablet: isLargeTablet,
        ),
        _buildDefensesPanel(char),
        _buildProficienciesPanel(char),
        buildDeathSavesSection(
          context,
          char,
          isTablet: isTablet,
          isLargeTablet: isLargeTablet,
        ),
        buildRecentDiceRolls(
          isTablet: isTablet,
          isLargeTablet: isLargeTablet,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;
    final useDesktopColumns = screenWidth >= 1180;

    final maxContentWidth = useDesktopColumns ? 1280.0 : 1040.0;
    final pagePadding = useDesktopColumns ? 26.0 : (isTablet ? 20.0 : 14.0);
    final statColumns = isLargeTablet ? 6 : 3;
    final statAspectRatio = isLargeTablet ? 1.28 : (isTablet ? 1.12 : 0.98);
    final compactStatAspectRatio = isLargeTablet ? 1.42 : statAspectRatio;
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
                _buildCommandBar(isTablet: isTablet),
                const SizedBox(height: 10),
                if (isLargeTablet)
                  _buildTopCombatDashboard(
                    hpCard: hpCard,
                    initiativeCard: initiativeCard,
                    summaryCards: summaryCards,
                    abilityRail: _buildAbilityRail(
                      char: char,
                      isTablet: isTablet,
                      isLargeTablet: isLargeTablet,
                      compact: true,
                      statColumns: statColumns,
                      statAspectRatio: compactStatAspectRatio,
                      str: str,
                      dex: dex,
                      con: con,
                      intScore: intScore,
                      wis: wis,
                      cha: cha,
                    ),
                  )
                else ...[
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
                ],
                const SizedBox(height: 18),
                if (isLargeTablet)
                  _buildLargeDetailsLayout(
                    context: context,
                    useDesktopColumns: useDesktopColumns,
                    isTablet: isTablet,
                    isLargeTablet: isLargeTablet,
                  )
                else
                  _buildStackedDetailsLayout(
                    context: context,
                    isTablet: isTablet,
                    isLargeTablet: isLargeTablet,
                  ),
                const SizedBox(height: 18),
                if (spellAbilityKey != null)
                  Text(
                    'Spellcasting: $spellAbilityKey (${formatSigned(spellAbilityModifier)})',
                    style: const TextStyle(
                      color: StitchCodexPalette.textMuted,
                      fontFamily: StitchTypography.data,
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
