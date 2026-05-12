import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dnd_race.dart';
import '../models/dnd_subrace.dart';
import '../providers/character_provider.dart';

const Color _raceBg = Color(0xFF1E1E22);
const Color _raceAppBar = Color(0xFF121214);
const Color _raceSurface = Color(0xFF17181F);
const Color _raceSurfaceAlt = Color(0xFF24243A);
const Color _raceImageBg = Color(0xFF101116);
const Color _raceBorder = Color(0xFF4D4F72);
const Color _raceAccent = Color(0xFF7C4DFF);
const Color _raceBlue = Color(0xFF4DA8FF);

class RaceDetailScreen extends StatefulWidget {
  final DndRace race;

  const RaceDetailScreen({super.key, required this.race});

  @override
  State<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends State<RaceDetailScreen> {
  DndSubrace? selectedSubrace;
  ImageProvider? _raceImage;

  @override
  void initState() {
    super.initState();
    _loadRaceImage();
  }

  Future<void> _loadRaceImage() async {
    final path =
        'assets/images/races/${_assetNameForRace(widget.race.name)}.png';

    try {
      await rootBundle.load(path);
      if (!mounted) return;
      setState(() => _raceImage = AssetImage(path));
    } catch (_) {
      if (!mounted) return;
      setState(() => _raceImage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final race = widget.race;
    final description = _bestDescription(race);

    return Scaffold(
      backgroundColor: _raceBg,
      appBar: StitchAppBar(
        backgroundColor: _raceAppBar,
        elevation: 0,
        title: Text(
          race.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _chooseRace,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text('Choose ${race.name}'),
            style: FilledButton.styleFrom(
              backgroundColor: _raceAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RaceHero(
                    race: race,
                    image: _raceImage,
                    description: description,
                  ),
                  const SizedBox(height: 18),
                  _OverviewGrid(
                    items: [
                      _OverviewItem(
                        icon: Icons.directions_run_rounded,
                        label: 'Speed',
                        value: '${race.speed} ft.',
                      ),
                      _OverviewItem(
                        icon: Icons.height_rounded,
                        label: 'Size',
                        value: race.size.isEmpty ? 'Unknown' : race.size,
                      ),
                      _OverviewItem(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Bonuses',
                        value: _abilitySummary(race.abilityBonuses),
                      ),
                      _OverviewItem(
                        icon: Icons.translate_rounded,
                        label: 'Languages',
                        value: race.languages.isEmpty
                            ? 'None listed'
                            : race.languages.join(', '),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (race.subraces.isNotEmpty)
                    _RacePanel(
                      title: 'Subraces',
                      icon: Icons.account_tree_rounded,
                      child: _SubracePicker(
                        race: race,
                        selectedSubrace: selectedSubrace,
                        onSelected: (subrace) {
                          setState(() => selectedSubrace = subrace);
                        },
                      ),
                    ),
                  _RacePanel(
                    title: 'Traits',
                    icon: Icons.stars_rounded,
                    child: _TraitList(traits: race.traits),
                  ),
                  _RacePanel(
                    title: 'Culture',
                    icon: Icons.menu_book_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReadableBlock(
                          title: 'Alignment',
                          text: race.alignment,
                        ),
                        _ReadableBlock(
                          title: 'Age',
                          text: race.age,
                        ),
                        _ReadableBlock(
                          title: 'Size',
                          text: race.sizeDescription,
                        ),
                        _ReadableBlock(
                          title: 'Languages',
                          text: race.languageDesc,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _bestDescription(DndRace race) {
    if (race.description.trim().isNotEmpty) return race.description.trim();
    if (race.sizeDescription.trim().isNotEmpty) {
      return race.sizeDescription.trim();
    }
    if (race.languageDesc.trim().isNotEmpty) return race.languageDesc.trim();
    if (race.alignment.trim().isNotEmpty) return race.alignment.trim();
    return 'No detailed description available.';
  }

  String _abilitySummary(List<Map<String, dynamic>> bonuses) {
    if (bonuses.isEmpty) return 'None listed';

    return bonuses.map((bonus) {
      final ability = _abilityName(bonus['ability']?.toString() ?? '');
      final value = bonus['bonus'];
      return '$ability +$value';
    }).join(', ');
  }

  String _abilityName(String value) {
    switch (value.toUpperCase()) {
      case 'STR':
        return 'Strength';
      case 'DEX':
        return 'Dexterity';
      case 'CON':
        return 'Constitution';
      case 'INT':
        return 'Intelligence';
      case 'WIS':
        return 'Wisdom';
      case 'CHA':
        return 'Charisma';
      default:
        return value.isEmpty ? 'Ability' : value;
    }
  }

  void _chooseRace() {
    final provider = context.read<CharacterProvider>();
    final bonuses = <String, int>{};

    for (final bonus in widget.race.abilityBonuses) {
      final ability = bonus['ability']?.toString();
      final value = bonus['bonus'];
      if (ability == null || value is! int) continue;
      bonuses[ability] = value;
    }

    provider.setRace(widget.race.name, bonuses);

    if (selectedSubrace != null) {
      provider.setSubrace(selectedSubrace!);
    }

    context.go('/select-class');
  }
}

class _RaceHero extends StatelessWidget {
  final DndRace race;
  final ImageProvider? image;
  final String description;

  const _RaceHero({
    required this.race,
    required this.image,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _raceSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _raceBorder.withOpacity(0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.36,
              child: _HeroImage(raceName: race.name, image: image),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          race.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1.04,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _SourcePill(source: race.source),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.74),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String raceName;
  final ImageProvider? image;

  const _HeroImage({
    required this.raceName,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _raceImageBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            Image(
              image: image!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            )
          else
            _RacePlaceholder(raceName: raceName),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.12),
                  Colors.black.withOpacity(0.62),
                ],
                stops: const [0.42, 0.70, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final String source;

  const _SourcePill({required this.source});

  @override
  Widget build(BuildContext context) {
    if (source.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _raceBlue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _raceBlue.withOpacity(0.18)),
      ),
      child: Text(
        source,
        style: const TextStyle(
          color: Color(0xFFBBDFFF),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  final List<_OverviewItem> items;

  const _OverviewGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 4 ? 1.22 : 1.48,
          ),
          itemBuilder: (context, index) => _OverviewTile(item: items[index]),
        );
      },
    );
  }
}

class _OverviewTile extends StatelessWidget {
  final _OverviewItem item;

  const _OverviewTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _raceSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _raceBorder.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: const Color(0xFF8FD2FF), size: 22),
          const SizedBox(height: 10),
          Text(
            item.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewItem {
  final IconData icon;
  final String label;
  final String value;

  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _RacePanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _RacePanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _raceSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _raceBorder.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8FD2FF), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SubracePicker extends StatelessWidget {
  final DndRace race;
  final DndSubrace? selectedSubrace;
  final ValueChanged<DndSubrace> onSelected;

  const _SubracePicker({
    required this.race,
    required this.selectedSubrace,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: race.subraces.map((subrace) {
        final selected = selectedSubrace?.id == subrace.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelected(subrace),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? _raceSurfaceAlt : _raceImageBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      selected ? _raceAccent : Colors.white.withOpacity(0.10),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subrace.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? const Color(0xFF8FD2FF)
                            : Colors.white.withOpacity(0.44),
                      ),
                    ],
                  ),
                  if (subrace.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      subrace.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.66),
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (subrace.abilityBonuses.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ChipWrap(
                      items: subrace.abilityBonuses.map((bonus) {
                        final ability = bonus['ability']?.toString() ?? '';
                        final value = bonus['bonus'];
                        return '$ability +$value';
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TraitList extends StatelessWidget {
  final List<Map<String, String>> traits;

  const _TraitList({required this.traits});

  @override
  Widget build(BuildContext context) {
    if (traits.isEmpty) {
      return Text(
        'No racial traits listed.',
        style: TextStyle(color: Colors.white.withOpacity(0.66)),
      );
    }

    return Column(
      children: traits.map((trait) {
        final name = trait['name'] ?? '';
        final description = trait['description'] ?? '';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _raceImageBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Trait' : name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    height: 1.42,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ReadableBlock extends StatelessWidget {
  final String title;
  final String text;

  const _ReadableBlock({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.74),
              height: 1.42,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> items;

  const _ChipWrap({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .where((item) => item.trim().isNotEmpty)
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _raceBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _raceBlue.withOpacity(0.18)),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  color: Color(0xFFBBDFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RacePlaceholder extends StatelessWidget {
  final String raceName;

  const _RacePlaceholder({required this.raceName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _raceSurfaceAlt,
            Color(0xFF101C32),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _iconForRace(raceName),
          color: const Color(0xFF8FD2FF),
          size: 58,
        ),
      ),
    );
  }

  IconData _iconForRace(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('dragonborn')) return Icons.local_fire_department;
    if (normalized.contains('dwarf')) return Icons.hardware;
    if (normalized.contains('elf')) return Icons.auto_awesome;
    if (normalized.contains('gnome')) return Icons.psychology_alt;
    if (normalized.contains('halfling')) return Icons.explore;
    if (normalized.contains('orc')) return Icons.shield;
    if (normalized.contains('tiefling')) return Icons.dark_mode;
    if (normalized.contains('aasimar')) return Icons.wb_twilight;
    if (normalized.contains('aarakocra')) return Icons.air;
    return Icons.person_rounded;
  }
}

String _assetNameForRace(String name) {
  return name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"['.]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
