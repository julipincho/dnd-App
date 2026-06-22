import 'package:flutter/material.dart';
import 'package:stitch_app/models/spell.dart';
import 'package:stitch_app/theme.dart';

class CharacterSpellbookSection extends StatelessWidget {
  final String title;
  final List<Spell> spells;
  final bool usesKnownCantrips;
  final bool usesKnownSpells;
  final bool usesPreparedSpells;
  final bool usesPreparedLimit;
  final Set<String> preparedSpellIds;
  final int selectedCantrips;
  final int selectedNonCantripSpells;
  final int knownCantripLimit;
  final int knownSpellLimit;
  final int preparedSpellsCount;
  final int preparedSpellLimit;
  final String? preparedSpellLimitLabel;
  final ValueChanged<Spell> onSpellTap;

  const CharacterSpellbookSection({
    super.key,
    required this.title,
    required this.spells,
    required this.usesKnownCantrips,
    required this.usesKnownSpells,
    required this.usesPreparedSpells,
    required this.usesPreparedLimit,
    required this.preparedSpellIds,
    required this.selectedCantrips,
    required this.selectedNonCantripSpells,
    required this.knownCantripLimit,
    required this.knownSpellLimit,
    required this.preparedSpellsCount,
    required this.preparedSpellLimit,
    required this.preparedSpellLimitLabel,
    required this.onSpellTap,
  });

  String _levelLabel(int level) {
    if (level == 0) return 'Cantrips';
    return 'Level $level';
  }

  Map<int, List<Spell>> get _spellsByLevel {
    final grouped = <int, List<Spell>>{};
    for (final spell in spells) {
      grouped.putIfAbsent(spell.level, () => []).add(spell);
    }
    for (final levelSpells in grouped.values) {
      levelSpells.sort((a, b) => a.name.compareTo(b.name));
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final spellsByLevel = _spellsByLevel;
    final sortedLevels = spellsByLevel.keys.toList()..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tokens.accentMagic.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: tokens.accentMagic.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.accentReadSoft.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProgressSpellPill(
                label: 'Selected',
                current: spells.length,
                max: null,
              ),
              if (usesKnownCantrips)
                _ProgressSpellPill(
                  label: 'Cantrips',
                  current: selectedCantrips,
                  max: knownCantripLimit,
                ),
              if (usesKnownSpells)
                _ProgressSpellPill(
                  label: 'Known',
                  current: selectedNonCantripSpells,
                  max: knownSpellLimit,
                ),
              if (usesPreparedSpells)
                _ProgressSpellPill(
                  label: 'Prepared',
                  current: preparedSpellsCount,
                  max: usesPreparedLimit ? preparedSpellLimit : null,
                ),
            ],
          ),
          if (usesPreparedSpells &&
              usesPreparedLimit &&
              preparedSpellLimitLabel != null) ...[
            const SizedBox(height: 10),
            Text(
              'Preparation: $preparedSpellLimitLabel',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (spells.isEmpty)
            _EmptySpellbook(title: title)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedLevels.map((level) {
                final levelSpells = spellsByLevel[level]!;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SpellLevelGroup(
                    label: _levelLabel(level),
                    spells: levelSpells,
                    usesPreparedSpells: usesPreparedSpells,
                    preparedSpellIds: preparedSpellIds,
                    onSpellTap: onSpellTap,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _SpellLevelGroup extends StatelessWidget {
  final String label;
  final List<Spell> spells;
  final bool usesPreparedSpells;
  final Set<String> preparedSpellIds;
  final ValueChanged<Spell> onSpellTap;

  const _SpellLevelGroup({
    required this.label,
    required this.spells,
    required this.usesPreparedSpells,
    required this.preparedSpellIds,
    required this.onSpellTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: tokens.accentReadSoft.withValues(alpha: 0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _SmallCountBadge(value: '${spells.length}'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: spells.map((spell) {
              final isPrepared =
                  usesPreparedSpells && preparedSpellIds.contains(spell.id);
              return _SpellChip(
                spell: spell,
                isPrepared: isPrepared,
                onPressed: () => onSpellTap(spell),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SpellChip extends StatelessWidget {
  final Spell spell;
  final bool isPrepared;
  final VoidCallback onPressed;

  const _SpellChip({
    required this.spell,
    required this.isPrepared,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;
    final color = isPrepared ? tokens.accentSuccess : tokens.accentMagic;

    return ActionChip(
      avatar: Icon(
        isPrepared ? Icons.check_circle : Icons.auto_awesome_outlined,
        size: 15,
        color: Colors.white,
      ),
      label: Text(spell.name),
      backgroundColor: color.withValues(alpha: isPrepared ? 0.18 : 0.12),
      side:
          BorderSide(color: color.withValues(alpha: isPrepared ? 0.34 : 0.22)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      onPressed: onPressed,
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
    final tokens = context.stitch;
    final isOverLimit = max != null && current > max!;
    final value = max == null ? '$current' : '$current / $max';
    final color = isOverLimit ? tokens.accentWarning : tokens.accentMagic;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: isOverLimit ? tokens.accentWarning : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallCountBadge extends StatelessWidget {
  final String value;

  const _SmallCountBadge({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.accentMagic.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.22)),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptySpellbook extends StatelessWidget {
  final String title;

  const _EmptySpellbook({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.stitch;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.accentMagic.withValues(alpha: 0.14)),
      ),
      child: Text(
        'No spells selected yet.',
        style: TextStyle(
          color: tokens.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
