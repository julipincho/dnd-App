import 'package:flutter/material.dart';

class CharacterSpellcastingClassSummary {
  final String className;
  final String? subclassName;
  final int classLevel;
  final String? ability;
  final int abilityModifier;
  final int saveDc;
  final int attackBonus;
  final int selectedSpells;
  final int? cantripsKnown;
  final int? cantripLimit;
  final int? knownSpells;
  final int? knownSpellLimit;
  final int? preparedSpells;
  final int? preparedSpellLimit;
  final bool isActive;

  const CharacterSpellcastingClassSummary({
    required this.className,
    required this.subclassName,
    required this.classLevel,
    required this.ability,
    required this.abilityModifier,
    required this.saveDc,
    required this.attackBonus,
    required this.selectedSpells,
    required this.cantripsKnown,
    required this.cantripLimit,
    required this.knownSpells,
    required this.knownSpellLimit,
    required this.preparedSpells,
    required this.preparedSpellLimit,
    required this.isActive,
  });
}

class CharacterSpellcastingClassesSection extends StatelessWidget {
  final List<CharacterSpellcastingClassSummary> summaries;
  final bool isTablet;
  final bool isLargeTablet;
  final ValueChanged<String> onSelectClass;

  const CharacterSpellcastingClassesSection({
    super.key,
    required this.summaries,
    required this.isTablet,
    required this.isLargeTablet,
    required this.onSelectClass,
  });

  @override
  Widget build(BuildContext context) {
    return _CharacterSheetSection(
      title: 'Spellcasting Classes',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = isLargeTablet ? 2 : 1;
          final width = constraints.maxWidth;
          final cardWidth = columns == 1 ? width : (width - 12) / columns;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: summaries.map((summary) {
              return SizedBox(
                width: cardWidth,
                child: _SpellcastingClassCard(
                  summary: summary,
                  isTablet: isTablet,
                  onTap: () => onSelectClass(summary.className),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _SpellcastingClassCard extends StatelessWidget {
  final CharacterSpellcastingClassSummary summary;
  final bool isTablet;
  final VoidCallback onTap;

  const _SpellcastingClassCard({
    required this.summary,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = summary.isActive
        ? Colors.deepPurpleAccent.withValues(alpha: 0.85)
        : Colors.deepPurpleAccent.withValues(alpha: 0.18);
    final backgroundColor =
        summary.isActive ? const Color(0xFF292133) : const Color(0xFF202028);
    final abilityLabel = summary.ability == null
        ? 'Not set'
        : '${summary.ability} ${_formatSigned(summary.abilityModifier)}';
    final detailLabel = (summary.subclassName?.trim().isNotEmpty ?? false)
        ? '${summary.subclassName!.trim()} - $abilityLabel'
        : abilityLabel;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: borderColor, width: summary.isActive ? 1.4 : 1),
          boxShadow: summary.isActive
              ? [
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _spellcastingClassIcon(summary.className),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${_formatClassName(summary.className)} ${summary.classLevel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 17 : 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (summary.isActive)
                            _CompactSpellBadge(
                              label: 'Active',
                              color: Colors.deepPurpleAccent,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detailLabel,
                        style: TextStyle(
                          color: summary.ability == null
                              ? Colors.orangeAccent
                              : Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  summary.isActive
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: summary.isActive
                      ? Colors.deepPurpleAccent
                      : Colors.white38,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SpellcastingMetricTile(
                    label: 'DC',
                    value: summary.ability == null ? '-' : '${summary.saveDc}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SpellcastingMetricTile(
                    label: 'Attack',
                    value: summary.ability == null
                        ? '-'
                        : _formatSigned(summary.attackBonus),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SpellcastingMetricTile(
                    label: 'Spells',
                    value: '${summary.selectedSpells}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (summary.cantripsKnown != null)
                  _ProgressSpellPill(
                    label: 'Cantrips',
                    current: summary.cantripsKnown!,
                    max: summary.cantripLimit,
                  ),
                if (summary.knownSpells != null)
                  _ProgressSpellPill(
                    label: 'Known',
                    current: summary.knownSpells!,
                    max: summary.knownSpellLimit,
                  ),
                if (summary.preparedSpells != null)
                  _ProgressSpellPill(
                    label: 'Prepared',
                    current: summary.preparedSpells!,
                    max: summary.preparedSpellLimit,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpellcastingMetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _SpellcastingMetricTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSpellPill extends StatelessWidget {
  final String label;
  final int current;
  final int? max;

  const _ProgressSpellPill({
    required this.label,
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final overLimit = max != null && current > max!;
    final value = max == null ? '$current' : '$current / $max';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: overLimit
            ? Colors.orangeAccent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: overLimit
              ? Colors.orangeAccent.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: overLimit ? Colors.orangeAccent : Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CompactSpellBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CompactSpellBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CharacterSheetSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CharacterSheetSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

IconData _spellcastingClassIcon(String className) {
  switch (className.trim().toLowerCase()) {
    case 'artificer':
      return Icons.construction_outlined;
    case 'bard':
      return Icons.music_note_outlined;
    case 'cleric':
      return Icons.church_outlined;
    case 'druid':
      return Icons.eco_outlined;
    case 'paladin':
      return Icons.shield_outlined;
    case 'ranger':
      return Icons.explore_outlined;
    case 'sorcerer':
      return Icons.flare_outlined;
    case 'warlock':
      return Icons.dark_mode_outlined;
    case 'wizard':
      return Icons.menu_book_outlined;
    default:
      return Icons.auto_awesome_outlined;
  }
}

String _formatClassName(String className) {
  final value = className.trim();
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _formatSigned(int value) => value >= 0 ? '+$value' : '$value';
