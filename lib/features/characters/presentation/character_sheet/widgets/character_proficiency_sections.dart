import 'package:flutter/material.dart';
import 'package:stitch_app/models/character.dart';

typedef CharacterStatBonusBuilder = int Function(
  Character character,
  String statName,
);

typedef CharacterStatProficiencyBuilder = bool Function(
  Character character,
  String statName,
);

typedef CharacterStatRollHandler = Future<void> Function({
  required String label,
  required int modifier,
});

class CharacterSavingThrowsSection extends StatelessWidget {
  static const List<String> abilities = [
    'STR',
    'DEX',
    'CON',
    'INT',
    'WIS',
    'CHA',
  ];

  final Character character;
  final bool isExpanded;
  final bool isTablet;
  final bool isLargeTablet;
  final VoidCallback onToggleExpanded;
  final CharacterStatBonusBuilder getSavingThrowBonus;
  final CharacterStatProficiencyBuilder isSavingThrowProficient;
  final String Function(String ability) getAbilityLabel;
  final String Function(int value) formatSigned;
  final CharacterStatRollHandler onRoll;

  const CharacterSavingThrowsSection({
    super.key,
    required this.character,
    required this.isExpanded,
    required this.isTablet,
    required this.isLargeTablet,
    required this.onToggleExpanded,
    required this.getSavingThrowBonus,
    required this.isSavingThrowProficient,
    required this.getAbilityLabel,
    required this.formatSigned,
    required this.onRoll,
  });

  @override
  Widget build(BuildContext context) {
    return _ExpandableStatSection(
      title: 'Saving Throws',
      isExpanded: isExpanded,
      isTablet: isTablet,
      onToggleExpanded: onToggleExpanded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                isLargeTablet && constraints.maxWidth > 420 ? 2 : 1;
            const spacing = 10.0;
            final itemWidth = crossAxisCount == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - spacing) / crossAxisCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: abilities.map((ability) {
                final bonus = getSavingThrowBonus(character, ability);
                final proficient = isSavingThrowProficient(character, ability);

                return SizedBox(
                  width: itemWidth,
                  child: _RollableStatRow(
                    label: ability,
                    subtitle: getAbilityLabel(ability),
                    value: formatSigned(bonus),
                    isProficient: proficient,
                    onRoll: () => onRoll(
                      label: '$ability Save',
                      modifier: bonus,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class CharacterSkillsSection extends StatelessWidget {
  static const Map<String, List<String>> skillsByAbility = {
    'STR': ['Athletics'],
    'DEX': ['Acrobatics', 'Sleight of Hand', 'Stealth'],
    'INT': ['Arcana', 'History', 'Investigation', 'Nature', 'Religion'],
    'WIS': ['Animal Handling', 'Insight', 'Medicine', 'Perception', 'Survival'],
    'CHA': ['Deception', 'Intimidation', 'Performance', 'Persuasion'],
  };

  static int get totalSkills {
    return skillsByAbility.values.fold<int>(
      0,
      (total, skills) => total + skills.length,
    );
  }

  final Character character;
  final bool isExpanded;
  final bool isTablet;
  final bool isLargeTablet;
  final ScrollController scrollController;
  final VoidCallback onToggleExpanded;
  final CharacterStatBonusBuilder getSkillBonus;
  final CharacterStatProficiencyBuilder isSkillProficient;
  final String Function(int value) formatSigned;
  final CharacterStatRollHandler onRoll;

  const CharacterSkillsSection({
    super.key,
    required this.character,
    required this.isExpanded,
    required this.isTablet,
    required this.isLargeTablet,
    required this.scrollController,
    required this.onToggleExpanded,
    required this.getSkillBonus,
    required this.isSkillProficient,
    required this.formatSigned,
    required this.onRoll,
  });

  @override
  Widget build(BuildContext context) {
    final expandedBodyHeight = isLargeTablet ? 484.0 : 420.0;

    return _ExpandableStatSection(
      title: 'Skills ($totalSkills)',
      isExpanded: isExpanded,
      isTablet: isTablet,
      onToggleExpanded: onToggleExpanded,
      child: SizedBox(
        height: expandedBodyHeight,
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: skillsByAbility.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SkillGroup(
                    character: character,
                    ability: entry.key,
                    skills: entry.value,
                    getSkillBonus: getSkillBonus,
                    isSkillProficient: isSkillProficient,
                    formatSigned: formatSigned,
                    onRoll: onRoll,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandableStatSection extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final bool isTablet;
  final VoidCallback onToggleExpanded;
  final Widget child;

  const _ExpandableStatSection({
    required this.title,
    required this.isExpanded,
    required this.isTablet,
    required this.onToggleExpanded,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    isExpanded ? 'Hide' : 'Show',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Colors.white12),
            child,
          ],
        ],
      ),
    );
  }
}

class _SkillGroup extends StatelessWidget {
  final Character character;
  final String ability;
  final List<String> skills;
  final CharacterStatBonusBuilder getSkillBonus;
  final CharacterStatProficiencyBuilder isSkillProficient;
  final String Function(int value) formatSigned;
  final CharacterStatRollHandler onRoll;

  const _SkillGroup({
    required this.character,
    required this.ability,
    required this.skills,
    required this.getSkillBonus,
    required this.isSkillProficient,
    required this.formatSigned,
    required this.onRoll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            ability,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...skills.map((skillName) {
          final bonus = getSkillBonus(character, skillName);
          final proficient = isSkillProficient(character, skillName);

          return _RollableStatRow(
            label: skillName,
            subtitle: proficient ? 'Proficient' : 'Normal',
            value: formatSigned(bonus),
            isProficient: proficient,
            onRoll: () => onRoll(
              label: skillName,
              modifier: bonus,
            ),
          );
        }),
      ],
    );
  }
}

class _RollableStatRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final bool isProficient;
  final VoidCallback onRoll;

  const _RollableStatRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isProficient,
    required this.onRoll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onRoll,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A2A38),
                  Color(0xFF22222E),
                ],
              ),
              border: Border.all(
                color: isProficient
                    ? Colors.deepPurpleAccent.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                if (isProficient)
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.10),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Row(
              children: [
                _ProficiencyIndicator(isProficient: isProficient),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _BonusBadge(
                  value: value,
                  isProficient: isProficient,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProficiencyIndicator extends StatelessWidget {
  final bool isProficient;

  const _ProficiencyIndicator({
    required this.isProficient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isProficient
            ? Colors.deepPurpleAccent.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: isProficient
              ? Colors.deepPurpleAccent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        isProficient ? Icons.check_rounded : Icons.circle_outlined,
        size: isProficient ? 17 : 13,
        color: Colors.white70,
      ),
    );
  }
}

class _BonusBadge extends StatelessWidget {
  final String value;
  final bool isProficient;

  const _BonusBadge({
    required this.value,
    required this.isProficient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isProficient
            ? Colors.deepPurpleAccent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: isProficient
              ? Colors.deepPurpleAccent.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
