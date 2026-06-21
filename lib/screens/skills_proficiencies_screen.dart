import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dnd_class.dart';
import '../services/class_data_service.dart';
import '../providers/character_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';

class SkillsProficienciesScreen extends StatefulWidget {
  const SkillsProficienciesScreen({super.key});

  @override
  State<SkillsProficienciesScreen> createState() =>
      _SkillsProficienciesScreenState();
}

class _SkillsProficienciesScreenState extends State<SkillsProficienciesScreen> {
  DndClass? classData;
  bool loading = true;

  final List<List<String>> selectedGroups = [];

  static const Map<String, List<String>> _backgroundSkills = {
    'Acolyte': ['Insight', 'Religion'],
    'Charlatan': ['Deception', 'Sleight of Hand'],
    'Criminal': ['Deception', 'Stealth'],
    'Entertainer': ['Acrobatics', 'Performance'],
    'Folk Hero': ['Animal Handling', 'Survival'],
    'Guild Artisan': ['Insight', 'Persuasion'],
    'Hermit': ['Medicine', 'Religion'],
    'Noble': ['History', 'Persuasion'],
    'Outlander': ['Athletics', 'Survival'],
    'Sage': ['Arcana', 'History'],
    'Sailor': ['Athletics', 'Perception'],
    'Soldier': ['Athletics', 'Intimidation'],
    'Urchin': ['Sleight of Hand', 'Stealth'],
  };

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final character = context.read<CharacterProvider>().character;
    if (character == null) return;

    final cls = await ClassDataService.loadClass(character.charClass);
    classData = cls;

    final choices = classData?.skillChoices ?? [];
    selectedGroups.clear();

    for (final _ in choices) {
      selectedGroups.add([]);
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterProvider>().character;

    if (loading || classData == null || character == null) {
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

    final choices = classData!.skillChoices;
    final backgroundName = character.background.name.trim();
    final autoBackgroundSkills = _backgroundSkills[backgroundName] ?? const [];

    bool isBackgroundSkill(String skill) {
      final target = _normalize(skill);
      return autoBackgroundSkills.any((s) => _normalize(s) == target);
    }

    bool isSelectedAnywhere(String skill) {
      final target = _normalize(skill);
      for (final group in selectedGroups) {
        if (group.any((s) => _normalize(s) == target)) return true;
      }
      return false;
    }

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'CHOOSE SKILLS',
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            const StitchCodexPageHeader(
              eyebrow: 'STEP 05 · PROFICIENCIES',
              title: 'Choose your skills',
              subtitle:
                  'Background talents are granted automatically. Choose the expertise earned through class training.',
            ),
            const SizedBox(height: 22),
            if (autoBackgroundSkills.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: StitchCodexPalette.surfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: StitchCodexPalette.success.withValues(alpha: 0.34),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BACKGROUND SKILLS',
                      style: TextStyle(
                        color: StitchCodexPalette.success,
                        fontFamily: StitchTypography.data,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: autoBackgroundSkills.map((skill) {
                        return StitchCodexTag(
                          label: skill.toUpperCase(),
                          color: StitchCodexPalette.success,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            ...List.generate(choices.length, (i) {
              final choice = choices[i];
              final selected = selectedGroups[i];

              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: StitchCodexPalette.surfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: StitchCodexPalette.bronze.withValues(alpha: 0.20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Choose ${choice.choose} skill${choice.choose > 1 ? 's' : ''}",
                      style: const TextStyle(
                        color: StitchCodexPalette.textPrimary,
                        fontFamily: StitchTypography.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...choice.from.map((skill) {
                      final backgroundGranted = isBackgroundSkill(skill);
                      final isSelected = selected.contains(skill);
                      final alreadyUsedInAnotherGroup =
                          isSelectedAnywhere(skill) && !isSelected;

                      final disabled = backgroundGranted ||
                          alreadyUsedInAnotherGroup ||
                          (!isSelected && selected.length >= choice.choose);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: StitchCodexPalette.surface,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: StitchCodexPalette.bronze
                                  .withValues(alpha: 0.14),
                            ),
                          ),
                          child: CheckboxListTile(
                            activeColor: StitchCodexPalette.crimson,
                            checkColor: StitchCodexPalette.textPrimary,
                            title: Text(
                              skill,
                              style: const TextStyle(
                                color: StitchCodexPalette.textSecondary,
                                fontFamily: StitchTypography.body,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: backgroundGranted
                                ? const Text('Granted by background')
                                : alreadyUsedInAnotherGroup
                                    ? const Text(
                                        'Already chosen in another group')
                                    : null,
                            value: backgroundGranted || isSelected,
                            onChanged: disabled
                                ? null
                                : (_) {
                                    setState(() {
                                      if (isSelected) {
                                        selected.remove(skill);
                                      } else {
                                        if (selected.length < choice.choose &&
                                            !alreadyUsedInAnotherGroup) {
                                          selected.add(skill);
                                        }
                                      }
                                    });
                                  },
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _isValid()
              ? () async {
                  final chosenList = selectedGroups.expand((x) => x).toList();

                  final finalSkills = <String>{
                    ...autoBackgroundSkills,
                    ...chosenList,
                  }.toList();

                  context.read<CharacterProvider>().update((c) {
                    c.classSkills = finalSkills;
                  });

                  final userId = context.read<AuthProvider>().userId;
                  if (userId == null) return;

                  await context.read<CharacterProvider>().saveCharacter(userId);

                  if (!context.mounted) return;
                  context.go('/assign-stats');
                }
              : null,
          style: stitchCodexPrimaryButtonStyle(),
          child: const Text('Continue'),
        ),
      ),
    );
  }

  bool _isValid() {
    for (int i = 0; i < (classData?.skillChoices.length ?? 0); i++) {
      if (selectedGroups[i].length != classData!.skillChoices[i].choose) {
        return false;
      }
    }
    return true;
  }
}
