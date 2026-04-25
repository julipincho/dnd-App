import 'package:flutter/material.dart';
import 'package:stitch_app/models/spell.dart';

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
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final spellsByLevel = _spellsByLevel;
    final sortedLevels = spellsByLevel.keys.toList()..sort();

    return _SpellbookFrame(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (spells.isEmpty)
            const Text(
              'No spells selected yet.',
              style: TextStyle(color: Colors.white70),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedLevels.map((level) {
                final levelSpells = spellsByLevel[level]!;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _levelLabel(level),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: levelSpells.map(_buildSpellChip).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSpellChip(Spell spell) {
    final isPrepared =
        usesPreparedSpells && preparedSpellIds.contains(spell.id);

    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrepared) ...[
            const Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              spell.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: isPrepared
          ? Colors.deepPurpleAccent.withValues(alpha: 0.35)
          : const Color(0xFF2A2A35),
      labelStyle: const TextStyle(color: Colors.white),
      onPressed: () => onSpellTap(spell),
    );
  }
}

class _SpellbookFrame extends StatelessWidget {
  final String title;
  final Widget child;

  const _SpellbookFrame({
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
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
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
    final isOverLimit = max != null && current > max!;
    final value = max == null ? '$current' : '$current / $max';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOverLimit
            ? Colors.orangeAccent.withValues(alpha: 0.18)
            : Colors.deepPurpleAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isOverLimit
              ? Colors.orangeAccent.withValues(alpha: 0.45)
              : Colors.deepPurpleAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: isOverLimit ? Colors.orangeAccent : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
