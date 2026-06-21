import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';

import '../models/dnd_race.dart';
import '../services/dnd_data_service.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';

const Color _raceBg = StitchCodexPalette.ground;
const Color _raceAppBar = StitchCodexPalette.ground;
const Color _raceSurface = StitchCodexPalette.surfaceMuted;
const Color _raceSurfaceAlt = StitchCodexPalette.surfaceRaised;
const Color _raceImageBg = StitchCodexPalette.surface;
const Color _raceBorder = StitchCodexPalette.bronzeMuted;
const Color _raceAccent = StitchCodexPalette.crimson;
const Color _raceBlue = StitchCodexPalette.bronze;

class RaceSelectionScreen extends StatefulWidget {
  const RaceSelectionScreen({super.key});

  @override
  State<RaceSelectionScreen> createState() => _RaceSelectionScreenState();
}

class _RaceSelectionScreenState extends State<RaceSelectionScreen> {
  late Future<List<DndRace>> _futureRaces;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _futureRaces = DndDataService.getRaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _raceBg,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: _raceAppBar,
        elevation: 0,
        title: const Text(
          'CHOOSE RACE',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: SafeArea(
          child: FutureBuilder<List<DndRace>>(
            future: _futureRaces,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _raceAccent),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading races',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              final races = snapshot.data ?? [];
              final filtered = races.where((race) {
                final query = _search.trim().toLowerCase();
                if (query.isEmpty) return true;
                return race.name.toLowerCase().contains(query) ||
                    race.subraces.any(
                      (subrace) => subrace.name.toLowerCase().contains(query),
                    );
              }).toList();

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const StitchCodexPageHeader(
                            eyebrow: 'STEP 01 · LINEAGE',
                            title: 'Pick your ancestry',
                            subtitle:
                                'Choose the people, heritage, and traits that shaped your hero.',
                          ),
                          const SizedBox(height: 18),
                          _RaceSearchField(
                            onChanged: (value) {
                              setState(() => _search = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No races found.',
                          style: const TextStyle(
                            color: StitchCodexPalette.textMuted,
                            fontFamily: StitchTypography.body,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns = width >= 920
                              ? 4
                              : width >= 660
                                  ? 3
                                  : 2;

                          return SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final race = filtered[index];
                                return _RaceCard(
                                  race: race,
                                  imageLoader: () => _raceImage(race),
                                  onTap: () {
                                    context.push('/race-detail', extra: race);
                                  },
                                );
                              },
                              childCount: filtered.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: columns == 2 ? 0.68 : 0.72,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<ImageProvider?> _raceImage(DndRace race) async {
    final path = 'assets/images/races/${_assetNameForRace(race.name)}.png';

    try {
      await rootBundle.load(path);
      return AssetImage(path);
    } catch (_) {
      return null;
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
}

class _RaceSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _RaceSearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: stitchCodexFieldTextStyle,
      cursorColor: StitchCodexPalette.bronze,
      decoration: stitchCodexInputDecoration(
        labelText: 'Search lineage',
        hintText: 'Race or subrace...',
        prefixIcon: Icons.search_rounded,
      ),
      onChanged: onChanged,
    );
  }
}

class _RaceCard extends StatelessWidget {
  final DndRace race;
  final Future<ImageProvider?> Function() imageLoader;
  final VoidCallback onTap;

  const _RaceCard({
    required this.race,
    required this.imageLoader,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: _raceSurface,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: _raceBorder.withValues(alpha: 0.42),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FutureBuilder<ImageProvider?>(
                    future: imageLoader(),
                    builder: (context, snapshot) {
                      final image = snapshot.data;
                      return _RaceImageFrame(
                        raceName: race.name,
                        image: image,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        race.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: StitchCodexPalette.textPrimary,
                          fontFamily: StitchTypography.display,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SubraceTags(race: race),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RaceImageFrame extends StatelessWidget {
  final String raceName;
  final ImageProvider? image;

  const _RaceImageFrame({
    required this.raceName,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _raceImageBg,
        image: image == null
            ? null
            : DecorationImage(
                image: image!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image == null) _RacePlaceholder(raceName: raceName),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.62),
                ],
                stops: const [0.45, 0.72, 1],
              ),
            ),
          ),
        ],
      ),
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
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _raceBlue.withValues(alpha: 0.10),
            border: Border.all(color: _raceBlue.withValues(alpha: 0.24)),
          ),
          child: Icon(
            _iconForRace(raceName),
            color: StitchCodexPalette.bronze,
            size: 34,
          ),
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

class _SubraceTags extends StatelessWidget {
  final DndRace race;

  const _SubraceTags({required this.race});

  @override
  Widget build(BuildContext context) {
    if (race.subraces.isEmpty) {
      return Text(
        'No subraces',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: StitchCodexPalette.textFaint,
          fontFamily: StitchTypography.data,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      );
    }

    final visible = race.subraces.take(2).toList();
    final remaining = race.subraces.length - visible.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final subrace in visible)
          _RaceTag(label: _compactSubraceName(subrace.name, race.name)),
        if (remaining > 0) _RaceTag(label: '+$remaining'),
      ],
    );
  }

  String _compactSubraceName(String subraceName, String raceName) {
    final cleaned = subraceName
        .replaceAll(
          RegExp('\\b${RegExp.escape(raceName)}\\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.isEmpty ? subraceName : cleaned;
  }
}

class _RaceTag extends StatelessWidget {
  final String label;

  const _RaceTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _raceBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _raceBlue.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: StitchCodexPalette.bronze,
          fontFamily: StitchTypography.data,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
