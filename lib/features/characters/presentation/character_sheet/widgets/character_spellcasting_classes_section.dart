import 'package:flutter/material.dart';
import 'package:stitch_app/theme.dart';
import 'package:stitch_app/widgets/stitch_codex_ui.dart';

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
        ? StitchCodexPalette.crimsonBright.withValues(alpha: 0.70)
        : StitchCodexPalette.bronze.withValues(alpha: 0.18);
    final backgroundColor = summary.isActive
        ? StitchCodexPalette.crimson.withValues(alpha: 0.10)
        : StitchCodexPalette.surface;
    final abilityLabel = summary.ability == null
        ? 'Not set'
        : '${summary.ability} ${_formatSigned(summary.abilityModifier)}';
    final detailLabel = (summary.subclassName?.trim().isNotEmpty ?? false)
        ? '${summary.subclassName!.trim()} - $abilityLabel'
        : abilityLabel;

    return InkWell(
      borderRadius: BorderRadius.circular(2),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(2),
          border:
              Border.all(color: borderColor, width: summary.isActive ? 1.4 : 1),
          boxShadow: summary.isActive
              ? [
                  BoxShadow(
                    color: StitchCodexPalette.crimsonBright
                        .withValues(alpha: 0.14),
                    blurRadius: 14,
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
                    color:
                        StitchCodexPalette.crimson.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: StitchCodexPalette.crimsonBright
                          .withValues(alpha: 0.24),
                    ),
                  ),
                  child: Icon(
                    _spellcastingClassIcon(summary.className),
                    color: StitchCodexPalette.crimsonBright,
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
                              color: StitchCodexPalette.textPrimary,
                              fontFamily: StitchTypography.display,
                              fontSize: isTablet ? 17 : 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (summary.isActive)
                            _CompactSpellBadge(
                              label: 'Active',
                              color: StitchCodexPalette.crimsonBright,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        detailLabel,
                        style: TextStyle(
                          color: summary.ability == null
                              ? StitchCodexPalette.crimsonBright
                              : StitchCodexPalette.textMuted,
                          fontFamily: StitchTypography.body,
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
                  color:
                      summary.isActive
                          ? StitchCodexPalette.crimsonBright
                          : StitchCodexPalette.textMuted,
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
        color: StitchCodexPalette.surface,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: StitchCodexPalette.textMuted,
              fontFamily: StitchTypography.body,
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
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.data,
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
            : StitchCodexPalette.bronze.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: overLimit
              ? Colors.orangeAccent.withValues(alpha: 0.55)
              : StitchCodexPalette.bronze.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: overLimit
              ? Colors.orangeAccent
              : StitchCodexPalette.textSecondary,
          fontFamily: StitchTypography.data,
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
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: StitchCodexPalette.textSecondary,
          fontFamily: StitchTypography.data,
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
    return StitchCodexPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: StitchCodexPalette.crimson.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: StitchCodexPalette.crimsonBright
                        .withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: StitchCodexPalette.crimsonBright,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: StitchCodexPalette.textPrimary,
                    fontFamily: StitchTypography.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0,
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
