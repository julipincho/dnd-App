import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dnd_class.dart';
import '../services/class_data_service.dart';
import '../providers/character_provider.dart';

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
        backgroundColor: Color(0xFF1E1E22),
        body: Center(child: CircularProgressIndicator()),
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
      backgroundColor: const Color(0xFF1E1E22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        title: const Text("Choose Skills"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (autoBackgroundSkills.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF17181F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Background Skills',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: autoBackgroundSkills.map((skill) {
                      return Chip(
                        label: Text(skill),
                        visualDensity: VisualDensity.compact,
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
                color: const Color(0xFF17181F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Choose ${choice.choose} skill${choice.choose > 1 ? 's' : ''}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
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

                    return Card(
                      color: Colors.black.withOpacity(0.2),
                      child: CheckboxListTile(
                        activeColor: Colors.greenAccent,
                        title: Text(
                          skill,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: backgroundGranted
                            ? const Text('Granted by background')
                            : alreadyUsedInAnotherGroup
                                ? const Text('Already chosen in another group')
                                : null,
                        value: backgroundGranted || isSelected,
                        onChanged: backgroundGranted
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
                    );
                  }).toList(),
                ],
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
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

                  await context.read<CharacterProvider>().saveCharacter();

                  if (!mounted) return;
                  context.go('/assign-stats');
                }
              : null,
          child: const Text("Continue"),
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
