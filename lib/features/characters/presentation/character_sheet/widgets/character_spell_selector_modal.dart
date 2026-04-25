import 'package:flutter/material.dart';
import 'package:stitch_app/models/spell.dart';

class CharacterSpellSelectorModal extends StatefulWidget {
  final List<Spell> spells;
  final Set<String> excludedSpellIds;
  final ValueChanged<Spell> onSelect;

  const CharacterSpellSelectorModal({
    super.key,
    required this.spells,
    required this.excludedSpellIds,
    required this.onSelect,
  });

  @override
  State<CharacterSpellSelectorModal> createState() =>
      _CharacterSpellSelectorModalState();
}

class _CharacterSpellSelectorModalState
    extends State<CharacterSpellSelectorModal> {
  String query = '';
  int? selectedLevel;

  List<Spell> get _filteredSpells {
    final normalizedQuery = query.trim().toLowerCase();

    final filtered = widget.spells.where((spell) {
      final notAlreadyAdded = !widget.excludedSpellIds.contains(spell.id);

      final matchesQuery = normalizedQuery.isEmpty ||
          spell.name.toLowerCase().contains(normalizedQuery) ||
          spell.school.toLowerCase().contains(normalizedQuery);

      final matchesLevel =
          selectedLevel == null || spell.level == selectedLevel;

      return notAlreadyAdded && matchesQuery && matchesLevel;
    }).toList();

    filtered.sort((a, b) {
      final levelCompare = a.level.compareTo(b.level);
      if (levelCompare != 0) return levelCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  Widget _buildSpellMetaChip(String label) {
    final IconData icon;

    if (label.contains('Level') || label == 'Cantrips') {
      icon = Icons.auto_awesome;
    } else if (label.contains('action')) {
      icon = Icons.flash_on;
    } else {
      icon = Icons.circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _levelLabel(int? level) {
    if (level == null) return 'All levels';
    if (level == 0) return 'Cantrips';
    return 'Level $level';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSpells;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: bottomInset + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Spell',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${filtered.length} available result${filtered.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or school...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF2A2A35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {
                    query = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All levels'),
                        selected: selectedLevel == null,
                        onSelected: (_) {
                          setState(() {
                            selectedLevel = null;
                          });
                        },
                      ),
                    ),
                    ...List.generate(10, (index) {
                      final level = index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_levelLabel(level)),
                          selected: selectedLevel == level,
                          onSelected: (_) {
                            setState(() {
                              selectedLevel = level;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No spells found with the current filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final spell = filtered[index];

                          return Material(
                            color: const Color(0xFF202028),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => widget.onSelect(spell),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurpleAccent
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        spell.level == 0
                                            ? 'C'
                                            : '${spell.level}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            spell.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              _buildSpellMetaChip(
                                                _levelLabel(spell.level),
                                              ),
                                              _buildSpellMetaChip(
                                                spell.school,
                                              ),
                                              if (spell.castingTime.isNotEmpty)
                                                _buildSpellMetaChip(
                                                  spell.castingTime,
                                                ),
                                            ],
                                          ),
                                          if (spell.description.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              spell.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.72),
                                                fontSize: 13,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
