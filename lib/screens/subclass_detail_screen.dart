import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/subclass_progress_feature.dart';
import '../providers/character_provider.dart';
import '../services/class_data_service.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';
import '../widgets/stitch_navigation.dart';

class SubclassDetailScreen extends StatefulWidget {
  final String classIndex;
  final String subclassName;

  const SubclassDetailScreen({
    super.key,
    required this.classIndex,
    required this.subclassName,
  });

  @override
  State<SubclassDetailScreen> createState() => _SubclassDetailScreenState();
}

class _SubclassDetailScreenState extends State<SubclassDetailScreen> {
  bool _loading = true;
  Map<int, List<SubclassProgressFeature>> _progression = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progression = await ClassDataService.loadSubclassProgression(
      widget.classIndex,
      widget.subclassName,
    );
    if (!mounted) return;

    setState(() {
      _progression = progression;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final levels = _progression.keys.toList()..sort();

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: Text(
          widget.subclassName.toUpperCase(),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: StitchCodexPalette.bronze,
                ),
              )
            : SingleChildScrollView(
                child: StitchCodexContentWidth(
                  maxWidth: 820,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SubclassHero(
                        className: widget.classIndex,
                        subclassName: widget.subclassName,
                        featureCount: _progression.values.fold<int>(
                          0,
                          (total, features) => total + features.length,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (levels.isEmpty)
                        const StitchCodexEmptyState(
                          icon: Icons.account_tree_outlined,
                          title: 'No progression recorded',
                          message:
                              'This subclass does not have progression data available yet.',
                        )
                      else ...[
                        const StitchCodexPageHeader(
                          eyebrow: 'SUBCLASS PROGRESSION',
                          title: 'Features by class level',
                          subtitle:
                              'These abilities unlock as this class advances.',
                        ),
                        const SizedBox(height: 18),
                        for (final level in levels)
                          _SubclassLevelBlock(
                            level: level,
                            features: _progression[level]!,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: StitchCodexPalette.ground,
            border: Border(
              top: BorderSide(
                color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
              ),
            ),
          ),
          child: FilledButton.icon(
            onPressed: () {
              context
                  .read<CharacterProvider>()
                  .setSubclass(widget.subclassName);
              context.go('/select-background');
            },
            style: stitchCodexPrimaryButtonStyle(),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Choose This Subclass'),
          ),
        ),
      ),
    );
  }
}

class _SubclassHero extends StatelessWidget {
  final String className;
  final String subclassName;
  final int featureCount;

  const _SubclassHero({
    required this.className,
    required this.subclassName,
    required this.featureCount,
  });

  @override
  Widget build(BuildContext context) {
    return StitchCodexPanel(
      emphasized: true,
      accent: StitchCodexPalette.crimsonBright,
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 76,
            decoration: BoxDecoration(
              color: StitchCodexPalette.crimson.withValues(alpha: 0.12),
              border: Border.all(
                color:
                    StitchCodexPalette.crimsonBright.withValues(alpha: 0.44),
              ),
            ),
            child: const Icon(
              Icons.account_tree_outlined,
              color: StitchCodexPalette.crimsonBright,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className.toUpperCase(),
                  style: const TextStyle(
                    color: StitchCodexPalette.bronze,
                    fontFamily: StitchTypography.data,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subclassName,
                  style: const TextStyle(
                    color: StitchCodexPalette.textPrimary,
                    fontFamily: StitchTypography.display,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StitchCodexTag(
                      label: '$featureCount FEATURES',
                      color: StitchCodexPalette.crimsonBright,
                    ),
                    const StitchCodexTag(label: '2014 RULESET'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubclassLevelBlock extends StatelessWidget {
  final int level;
  final List<SubclassProgressFeature> features;

  const _SubclassLevelBlock({
    required this.level,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StitchCodexPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: StitchCodexPalette.bronze.withValues(alpha: 0.08),
                border: Border.all(
                  color: StitchCodexPalette.bronze.withValues(alpha: 0.30),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'LEVEL',
                    style: TextStyle(
                      color: StitchCodexPalette.textMuted,
                      fontFamily: StitchTypography.data,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$level',
                    style: const TextStyle(
                      color: StitchCodexPalette.bronze,
                      fontFamily: StitchTypography.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < features.length; index++) ...[
                    _SubclassFeature(feature: features[index]),
                    if (index != features.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Divider(
                          height: 1,
                          color: StitchCodexPalette.bronze
                              .withValues(alpha: 0.14),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubclassFeature extends StatelessWidget {
  final SubclassProgressFeature feature;

  const _SubclassFeature({required this.feature});

  @override
  Widget build(BuildContext context) {
    final description = feature.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          feature.name,
          style: const TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          description.isEmpty ? 'No description available.' : description,
          style: const TextStyle(
            color: StitchCodexPalette.textSecondary,
            fontFamily: StitchTypography.body,
            fontSize: 15,
            height: 1.48,
          ),
        ),
      ],
    );
  }
}
