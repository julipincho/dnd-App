import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/class_level_service.dart';
import '../services/class_data_service.dart';
import '../models/dnd_class_level.dart';
import '../providers/character_provider.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';

class SelectLevelScreen extends StatefulWidget {
  const SelectLevelScreen({super.key});

  @override
  State<SelectLevelScreen> createState() => _SelectLevelScreenState();
}

class _SelectLevelScreenState extends State<SelectLevelScreen> {
  bool loading = true;
  List<DndClassLevel> levels = [];

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    final character =
        context.read<CharacterProvider>().character; // tomamos del provider

    if (character == null) return;

    final Map<int, DndClassLevel> loaded =
        await ClassLevelService.loadLevelsForClass(
      character.charClass.toLowerCase().trim(),
    );

    setState(() {
      levels = loaded.values.toList()
        ..sort((a, b) => a.level.compareTo(b.level));
      loading = false;
    });
  }

  Future<void> _selectLevel(DndClassLevel lvl) async {
    final provider = context.read<CharacterProvider>();
    final character = provider.character;
    if (character == null) return;

    final className = character.charClass.trim();
    final subclassChoiceLevel =
        await ClassDataService.getSubclassChoiceLevel(className);
    final classData = await ClassDataService.loadClass(className);
    final shouldChooseSubclass = subclassChoiceLevel != null &&
        lvl.level >= subclassChoiceLevel &&
        (classData?.subclasses.isNotEmpty ?? false);

    if (!mounted) return;

    provider.update((c) {
      c.subclass = null;
      c.setPrimaryClassLevel(lvl.level);
    });

    if (shouldChooseSubclass) {
      context.go('/subclass-selection', extra: className);
    } else {
      context.go('/select-background');
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterProvider>().character;

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'SELECT LEVEL',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: StitchCodexPalette.bronze,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                itemCount: levels.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: StitchCodexPageHeader(
                        eyebrow: 'STEP 03 · EXPERIENCE',
                        title: 'Select a level',
                        subtitle:
                            'Choose the starting power of your ${character?.charClass ?? 'character'}.',
                      ),
                    );
                  }

                  final lvl = levels[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(2),
                        onTap: () => _selectLevel(lvl),
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: StitchCodexPalette.surfaceMuted,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: StitchCodexPalette.bronze
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: StitchCodexPalette.crimson
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(
                                    color: StitchCodexPalette.crimson
                                        .withValues(alpha: 0.34),
                                  ),
                                ),
                                child: Text(
                                  '${lvl.level}',
                                  style: const TextStyle(
                                    color: StitchCodexPalette.crimsonBright,
                                    fontFamily: StitchTypography.data,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Level ${lvl.level}',
                                      style: const TextStyle(
                                        color: StitchCodexPalette.textPrimary,
                                        fontFamily: StitchTypography.display,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Proficiency bonus +${lvl.profBonus}',
                                      style: const TextStyle(
                                        color: StitchCodexPalette.textMuted,
                                        fontFamily: StitchTypography.body,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: StitchCodexPalette.bronze,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
