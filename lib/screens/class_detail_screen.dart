import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dnd_class.dart';
import '../providers/character_provider.dart';
import '../services/class_data_service.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';
import 'class_progression_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final String classIndex;

  const ClassDetailScreen({
    super.key,
    required this.classIndex,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  DndClass? _dndClass;
  bool _loading = true;
  ImageProvider? _classImage;

  @override
  void initState() {
    super.initState();
    _loadClass();
  }

  Future<void> _loadClass() async {
    final loadedClass = await ClassDataService.loadClass(widget.classIndex);
    final image =
        await _loadLocalImage(loadedClass?.name ?? widget.classIndex);
    if (!mounted) return;

    setState(() {
      _dndClass = loadedClass;
      _classImage = image;
      _loading = false;
    });
  }

  Future<ImageProvider?> _loadLocalImage(String className) async {
    final path = 'assets/images/classes/${className.toLowerCase()}.png';
    try {
      await rootBundle.load(path);
      return AssetImage(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: StitchCodexPalette.ground,
        body: StitchCodexBackground(
          child: Center(
            child: CircularProgressIndicator(
              color: StitchCodexPalette.bronze,
            ),
          ),
        ),
      );
    }

    final dndClass = _dndClass;
    if (dndClass == null) {
      return const Scaffold(
        backgroundColor: StitchCodexPalette.ground,
        body: StitchCodexBackground(
          child: Center(
            child: Text(
              'Class not found',
              style: TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: Text(
          dndClass.name.toUpperCase(),
          style: const TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: SingleChildScrollView(
          child: StitchCodexContentWidth(
            maxWidth: 960,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ClassHero(dndClass: dndClass, image: _classImage),
                const SizedBox(height: 20),
                _ClassMetrics(dndClass: dndClass),
                const SizedBox(height: 22),
                _ClassDetailSection(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Saving Throws',
                  body: _textOrFallback(dndClass.savingThrows),
                ),
                _ClassDetailSection(
                  icon: Icons.shield_outlined,
                  title: 'General Proficiencies',
                  body: _textOrFallback(dndClass.proficiencies),
                ),
                _ClassDetailSection(
                  icon: Icons.psychology_alt_outlined,
                  title: 'Skill Choices',
                  child: _SkillChoices(dndClass: dndClass),
                ),
                _ClassDetailSection(
                  icon: Icons.inventory_2_outlined,
                  title: 'Starting Equipment',
                  body: _textOrFallback(
                    dndClass.startingEquipment,
                    separator: '\n',
                  ),
                ),
                _ClassDetailSection(
                  icon: Icons.account_tree_outlined,
                  title: 'Subclasses',
                  body: _textOrFallback(
                    dndClass.subclasses.map((subclass) => subclass.name),
                  ),
                ),
                if (dndClass.spellcastingAbility != null)
                  _ClassDetailSection(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Spellcasting',
                    body:
                        'Primary casting ability: ${dndClass.spellcastingAbility}',
                    accent: StitchCodexPalette.crimsonBright,
                  ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final chooseButton = FilledButton.icon(
                      onPressed: () => _chooseClass(dndClass),
                      style: stitchCodexPrimaryButtonStyle(),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Choose This Class'),
                    );
                    final progressionButton = OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ClassProgressionScreen(cls: dndClass),
                          ),
                        );
                      },
                      style: stitchCodexOutlineButtonStyle(),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('View Level Progression'),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          chooseButton,
                          const SizedBox(height: 10),
                          progressionButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: chooseButton),
                        const SizedBox(width: 12),
                        Expanded(child: progressionButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _chooseClass(DndClass dndClass) {
    context.read<CharacterProvider>().update((character) {
      character.setPrimaryClassProgression(className: dndClass.name);
      character.savingThrows = List<String>.from(dndClass.savingThrows);
    });
    context.go('/select-level');
  }

  String _textOrFallback(
    Iterable<String> values, {
    String separator = ', ',
  }) {
    final clean = values.where((value) => value.trim().isNotEmpty).toList();
    return clean.isEmpty ? 'None listed.' : clean.join(separator);
  }
}

class _ClassHero extends StatelessWidget {
  final DndClass dndClass;
  final ImageProvider? image;

  const _ClassHero({
    required this.dndClass,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: StitchCodexPalette.card,
        border: Border.all(
          color: StitchCodexPalette.bronze.withValues(alpha: 0.42),
        ),
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
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x26000000),
                  Color(0x66000000),
                  Color(0xF20C0906),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          if (image == null)
            const Center(
              child: Icon(
                Icons.menu_book_outlined,
                color: StitchCodexPalette.textFaint,
                size: 74,
              ),
            ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CLASS DOSSIER',
                  style: TextStyle(
                    color: StitchCodexPalette.bronze,
                    fontFamily: StitchTypography.data,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dndClass.name,
                  style: const TextStyle(
                    color: StitchCodexPalette.textPrimary,
                    fontFamily: StitchTypography.display,
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  dndClass.spellcastingAbility == null
                      ? 'A martial path defined by training, resilience and decisive action.'
                      : 'A path where discipline and magic become a single adventuring craft.',
                  style: const TextStyle(
                    color: StitchCodexPalette.textSecondary,
                    fontFamily: StitchTypography.body,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassMetrics extends StatelessWidget {
  final DndClass dndClass;

  const _ClassMetrics({required this.dndClass});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        icon: Icons.casino_outlined,
        label: 'HIT DIE',
        value: 'd${dndClass.hitDie}',
      ),
      (
        icon: Icons.auto_awesome_outlined,
        label: 'SPELLCASTING',
        value: dndClass.spellcastingAbility ?? 'None',
      ),
      (
        icon: Icons.account_tree_outlined,
        label: 'SUBCLASSES',
        value: '${dndClass.subclasses.length}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 620
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth,
                child: StitchCodexPanel(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Icon(
                        metric.icon,
                        color: StitchCodexPalette.bronze,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.label,
                              style: const TextStyle(
                                color: StitchCodexPalette.textMuted,
                                fontFamily: StitchTypography.data,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              metric.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: StitchCodexPalette.textPrimary,
                                fontFamily: StitchTypography.display,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ClassDetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? child;
  final Color accent;

  const _ClassDetailSection({
    required this.icon,
    required this.title,
    this.body,
    this.child,
    this.accent = StitchCodexPalette.bronze,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StitchCodexPanel(
        padding: EdgeInsets.zero,
        accent: accent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: accent,
            collapsedIconColor: StitchCodexPalette.textMuted,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 3,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 17),
            leading: Icon(icon, color: accent, size: 20),
            title: Text(
              title,
              style: const TextStyle(
                color: StitchCodexPalette.textPrimary,
                fontFamily: StitchTypography.display,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: child ??
                    Text(
                      body ?? 'None listed.',
                      style: const TextStyle(
                        color: StitchCodexPalette.textSecondary,
                        fontFamily: StitchTypography.body,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillChoices extends StatelessWidget {
  final DndClass dndClass;

  const _SkillChoices({required this.dndClass});

  @override
  Widget build(BuildContext context) {
    if (dndClass.skillChoices.isEmpty) {
      return const Text(
        'None listed.',
        style: TextStyle(
          color: StitchCodexPalette.textMuted,
          fontFamily: StitchTypography.body,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final choice in dndClass.skillChoices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Choose ${choice.choose}: ${choice.from.join(', ')}',
              style: const TextStyle(
                color: StitchCodexPalette.textSecondary,
                fontFamily: StitchTypography.body,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}
