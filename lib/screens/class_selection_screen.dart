import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dnd_class.dart';
import '../providers/character_provider.dart';
import '../services/class_data_service.dart';
import 'class_progression_screen.dart';

const Color _classBg = Color(0xFF1E1E22);
const Color _classAppBar = Color(0xFF121214);
const Color _classSurface = Color(0xFF17181F);
const Color _classSurfaceSelected = Color(0xFF24243A);
const Color _classSurfaceDeep = Color(0xFF101116);
const Color _classBorder = Color(0xFF4D4F72);
const Color _classAccent = Color(0xFF7C4DFF);

class ClassSelectionScreen extends StatefulWidget {
  const ClassSelectionScreen({super.key});

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  static const _classesDataPath = 'assets/data/classes_normalized.json';

  final ScrollController _classScrollController = ScrollController();
  final Map<String, Future<ImageProvider?>> _classImageFutures = {};

  List<DndClass> _classes = [];
  Map<String, dynamic> _rawClassDataById = {};
  double _classScrollOffset = 0;
  int _selectedIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _classScrollController.addListener(_rememberClassScrollOffset);
    _loadClasses();
  }

  @override
  void dispose() {
    _classScrollController.removeListener(_rememberClassScrollOffset);
    _classScrollController.dispose();
    super.dispose();
  }

  void _rememberClassScrollOffset() {
    if (!_classScrollController.hasClients) return;
    _classScrollOffset = _classScrollController.offset;
  }

  void _restoreClassScrollOffset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_classScrollController.hasClients) return;
      if (_classScrollOffset <= 0) return;

      final maxOffset = _classScrollController.position.maxScrollExtent;
      final target = _classScrollOffset.clamp(0.0, maxOffset);

      if ((_classScrollController.offset - target).abs() > 1) {
        _classScrollController.jumpTo(target);
      }
    });
  }

  Future<void> _loadClasses() async {
    final list = await ClassDataService.loadAllClasses();
    list.sort((a, b) => a.name.compareTo(b.name));

    final rawString = await rootBundle.loadString(_classesDataPath);
    final rawRoot = jsonDecode(rawString) as Map<String, dynamic>;
    final rawClasses = (rawRoot['classes'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final rawById = <String, dynamic>{};
    for (final entry in rawClasses) {
      final id = entry['id']?.toString().toLowerCase();
      final name = entry['name']?.toString().toLowerCase();
      if (id != null && id.isNotEmpty) rawById[id] = entry;
      if (name != null && name.isNotEmpty) rawById[name] = entry;
    }

    if (!mounted) return;

    setState(() {
      _classes = list;
      _rawClassDataById = rawById;
      _loading = false;
    });
  }

  DndClass? get _selectedClass {
    if (_classes.isEmpty) return null;
    return _classes[_selectedIndex.clamp(0, _classes.length - 1)];
  }

  Map<String, dynamic>? _rawForClass(DndClass cls) {
    return _rawClassDataById[cls.index.toLowerCase()] ??
        _rawClassDataById[cls.name.toLowerCase()];
  }

  String _classTagline(DndClass cls) {
    final spell = cls.spellcastingAbility;
    final saves = cls.savingThrows.isEmpty
        ? 'None listed'
        : _displayAbilities(cls.savingThrows);

    if (spell != null && spell.trim().isNotEmpty) {
      return 'Spellcasting: $spell. Hit Die: d${cls.hitDie}.';
    }

    return 'Hit Die: d${cls.hitDie}. Saving Throws: $saves.';
  }

  String _primaryAbility(DndClass cls) {
    if ((cls.spellcastingAbility ?? '').trim().isNotEmpty) {
      return cls.spellcastingAbility!;
    }

    final name = cls.name.toLowerCase();
    if (name.contains('barbarian')) return 'Strength';
    if (name.contains('fighter')) return 'Strength or Dexterity';
    if (name.contains('monk') || name.contains('rogue')) return 'Dexterity';
    if (name.contains('ranger')) return 'Dexterity & Wisdom';
    if (name.contains('paladin')) return 'Strength & Charisma';
    return cls.savingThrows.isEmpty
        ? 'Varies'
        : _displayAbilities(cls.savingThrows);
  }

  String _displayAbilities(List<String> values) {
    return values.map(_displayAbility).join(' & ');
  }

  String _displayAbility(String value) {
    switch (value.trim().toUpperCase()) {
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
        return value;
    }
  }

  List<_ClassFeaturePreview> _featurePreview(DndClass cls) {
    final raw = _rawForClass(cls);
    final progression = raw?['progression'] as List? ?? [];
    final features = <_ClassFeaturePreview>[];

    for (final levelEntry in progression) {
      if (levelEntry is! Map) continue;
      final level = (levelEntry['level'] as num?)?.toInt();
      final rawFeatures = levelEntry['features'] as List? ?? [];

      for (final feature in rawFeatures) {
        if (feature is! Map) continue;
        final name = feature['name']?.toString().trim() ?? '';
        final description = _cleanRulesText(
          feature['description']?.toString().trim() ?? '',
        );

        if (name.isEmpty || description.isEmpty) continue;
        features.add(
          _ClassFeaturePreview(
            name: name,
            level: level,
            description: description,
          ),
        );

        if (features.length >= 4) return features;
      }
    }

    return features;
  }

  String _cleanRulesText(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'\{@i ([^}]+)\}'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\{@b ([^}]+)\}'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\{@item ([^|}]+)(?:\|[^}]*)?\}'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\{@spell ([^|}]+)(?:\|[^}]*)?\}'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\{@[^ ]+ ([^}]+)\}'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<ImageProvider?> _classImage(String className) async {
    final assetName = className.trim().toLowerCase().replaceAll(' ', '-');
    final path = 'assets/images/classes/$assetName.png';
    try {
      await rootBundle.load(path);
      return AssetImage(path);
    } catch (_) {
      return null;
    }
  }

  Future<ImageProvider?> _cachedClassImage(String className) {
    final key = className.trim().toLowerCase();
    return _classImageFutures.putIfAbsent(key, () => _classImage(className));
  }

  void _selectClass(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _chooseClass(DndClass cls) {
    context.read<CharacterProvider>().update((ch) {
      ch.setPrimaryClassProgression(className: cls.name);
      ch.savingThrows = List<String>.from(cls.savingThrows);
      ch.classSkills = [];
    });

    context.go('/select-level');
  }

  void _openProgression(DndClass cls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassProgressionScreen(cls: cls),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _classBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final selected = _selectedClass;
    _restoreClassScrollOffset();

    if (selected == null) {
      return const Scaffold(
        backgroundColor: _classBg,
        body: Center(
          child: Text(
            'No classes available.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _classBg,
      appBar: StitchAppBar(
        backgroundColor: _classAppBar,
        elevation: 0,
        title: const Text(
          'Select a Class',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            SizedBox(
              height: 390,
              child: ListView.separated(
                key: const PageStorageKey<String>('class-selection-carousel'),
                controller: _classScrollController,
                scrollDirection: Axis.horizontal,
                restorationId: 'class-selection-carousel',
                itemCount: _classes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final cls = _classes[index];
                  return _ClassChoiceCard(
                    cls: cls,
                    selected: index == _selectedIndex,
                    tagline: _classTagline(cls),
                    imageLoader: () => _cachedClassImage(cls.name),
                    onTap: () => _selectClass(index),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: _SelectedClassPanel(
                  cls: selected,
                  tagline: _classTagline(selected),
                  primaryAbility: _primaryAbility(selected),
                  savingThrows: selected.savingThrows.isEmpty
                      ? 'None listed'
                      : _displayAbilities(selected.savingThrows),
                  features: _featurePreview(selected),
                  onViewProgression: () => _openProgression(selected),
                  onChoose: () => _chooseClass(selected),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cleanSummaryText(String value) {
  final text = value.trim();
  final proficiencyMatch =
      RegExp(r'''['"]proficiency['"]:\s*['"]([^'"]+)''').firstMatch(text);

  if (proficiencyMatch != null) {
    return proficiencyMatch.group(1) ?? text;
  }

  return text;
}

class _ClassChoiceCard extends StatelessWidget {
  final DndClass cls;
  final bool selected;
  final String tagline;
  final Future<ImageProvider?> Function() imageLoader;
  final VoidCallback onTap;

  const _ClassChoiceCard({
    required this.cls,
    required this.selected,
    required this.tagline,
    required this.imageLoader,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 275,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? _classSurfaceSelected : _classSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _classAccent : Colors.white24,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _classAccent.withOpacity(0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<ImageProvider?>(
                future: imageLoader(),
                builder: (context, snapshot) {
                  final image = snapshot.data;
                  return Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: _classSurfaceDeep,
                      borderRadius: BorderRadius.circular(9),
                      image: image == null
                          ? null
                          : DecorationImage(
                              image: image,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                    ),
                    child: image == null
                        ? Center(
                            child: Icon(
                              _iconForClass(cls.name),
                              color: Colors.white.withOpacity(0.45),
                              size: 72,
                            ),
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                cls.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tagline,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 15,
                  height: 1.28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForClass(String name) {
    switch (name.toLowerCase()) {
      case 'artificer':
        return Icons.science;
      case 'barbarian':
        return Icons.fitness_center;
      case 'bard':
        return Icons.music_note;
      case 'cleric':
        return Icons.healing;
      case 'druid':
        return Icons.eco;
      case 'fighter':
        return Icons.shield;
      case 'monk':
        return Icons.self_improvement;
      case 'paladin':
        return Icons.auto_fix_high;
      case 'ranger':
        return Icons.nature;
      case 'rogue':
        return Icons.visibility_off;
      case 'sorcerer':
        return Icons.flash_on;
      case 'warlock':
        return Icons.nights_stay;
      case 'wizard':
        return Icons.menu_book;
    }
    return Icons.star;
  }
}

class _SelectedClassPanel extends StatelessWidget {
  final DndClass cls;
  final String tagline;
  final String primaryAbility;
  final String savingThrows;
  final List<_ClassFeaturePreview> features;
  final VoidCallback onViewProgression;
  final VoidCallback onChoose;

  const _SelectedClassPanel({
    required this.cls,
    required this.tagline,
    required this.primaryAbility,
    required this.savingThrows,
    required this.features,
    required this.onViewProgression,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          cls.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 17,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 22),
        _InfoGrid(
          items: [
            _InfoGridItem('Hit Die', '1d${cls.hitDie} per class level'),
            _InfoGridItem('Primary Ability', primaryAbility),
            _InfoGridItem('Saving Throws', savingThrows),
            _InfoGridItem(
              'Armor & Weapon Profs',
              cls.proficiencies.isEmpty
                  ? 'None listed'
                  : cls.proficiencies.map(_cleanSummaryText).take(5).join(', '),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ClassAccordion(
          title: 'Class Features',
          initiallyExpanded: true,
          child: features.isEmpty
              ? const Text(
                  'No class features are listed for this class yet.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: features.map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.level == null
                                ? feature.name
                                : '${feature.name} - Level ${feature.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            feature.description,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              height: 1.45,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        _ClassAccordion(
          title: 'Proficiencies',
          child: _BulletText(
            items: [
              if (cls.proficiencies.isNotEmpty)
                ...cls.proficiencies.map(_cleanSummaryText),
              for (final choice in cls.skillChoices)
                'Choose ${choice.choose}: ${choice.from.join(', ')}',
            ],
            emptyText: 'No proficiencies listed.',
          ),
        ),
        _ClassAccordion(
          title: 'Starting Equipment',
          child: _BulletText(
            items: cls.startingEquipment,
            emptyText: 'No starting equipment listed.',
          ),
        ),
        _ClassAccordion(
          title: 'Subclasses',
          child: _BulletText(
            items: cls.subclasses.map((s) {
              final description = (s.description ?? '').trim();
              return description.isEmpty ? s.name : '${s.name}: $description';
            }).toList(),
            emptyText: 'No subclasses listed.',
          ),
        ),
        if (cls.spellcastingAbility != null)
          _ClassAccordion(
            title: 'Spellcasting',
            child: Text(
              'Spellcasting Ability: ${cls.spellcastingAbility}',
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onViewProgression,
            icon: const Icon(Icons.timeline_outlined),
            label: const Text('View Level Progression'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.25)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onChoose,
            style: FilledButton.styleFrom(
              backgroundColor: _classAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Choose ${cls.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoGridItem> items;

  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;

        return Container(
          decoration: BoxDecoration(
            color: _classSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _classBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: compact
                ? Column(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _InfoTile(
                          item: items[i],
                          border: Border(
                            bottom: i == items.length - 1
                                ? BorderSide.none
                                : BorderSide(color: _classBorder),
                          ),
                        ),
                    ],
                  )
                : Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _InfoTile(
                                item: items[0],
                                border: Border(
                                  right: BorderSide(color: _classBorder),
                                  bottom: BorderSide(color: _classBorder),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _InfoTile(
                                item: items[1],
                                border: Border(
                                  bottom: BorderSide(color: _classBorder),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _InfoTile(
                                item: items[2],
                                border: Border(
                                  right: BorderSide(color: _classBorder),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _InfoTile(item: items[3]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final _InfoGridItem item;
  final Border? border;

  const _InfoTile({
    required this.item,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassAccordion extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const _ClassAccordion({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _classSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _classBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final List<String> items;
  final String emptyText;

  const _BulletText({
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((item) => item.trim().isNotEmpty).toList();

    if (visibleItems.isEmpty) {
      return Text(
        emptyText,
        style: const TextStyle(color: Colors.white70, height: 1.4),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visibleItems.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '- $item',
            style: TextStyle(
              color: Colors.white.withOpacity(0.84),
              height: 1.4,
              fontSize: 15,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InfoGridItem {
  final String label;
  final String value;

  const _InfoGridItem(this.label, this.value);
}

class _ClassFeaturePreview {
  final String name;
  final int? level;
  final String description;

  const _ClassFeaturePreview({
    required this.name,
    required this.level,
    required this.description,
  });
}
