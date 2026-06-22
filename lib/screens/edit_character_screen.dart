import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/dnd_class.dart';
import '../models/dnd_background.dart';
import '../models/character.dart';
import '../providers/character_provider.dart';
import '../services/class_data_service.dart';
import '../services/dnd_data_service.dart';
import '../models/feat_data.dart';
import '../services/feat_data_service.dart';
import '../services/feat_validation_service.dart';
import '../services/supabase_storage_service.dart';
import '../theme.dart';
import '../utils/image_path_utils.dart';
import '../widgets/stitch_codex_ui.dart';

class EditCharacterScreen extends StatefulWidget {
  final String characterId;

  const EditCharacterScreen({
    super.key,
    required this.characterId,
  });

  @override
  State<EditCharacterScreen> createState() => _EditCharacterScreenState();
}

class _EditCharacterScreenState extends State<EditCharacterScreen> {
  late TextEditingController _nameController;
  late TextEditingController _backstoryController;
  late TextEditingController _notesController;
  late TextEditingController _maxHpController;
  late TextEditingController _currentHpController;
  late TextEditingController _acController;
  late TextEditingController _speedController;

  Uint8List? _portraitBytes;
  String? _portraitFileName;
  String? _portraitPath;
  List<FeatData> _allFeats = [];
  List<DndBackground> backgrounds = [];
  DndBackground? selectedBackground;
  DndClass? _loadedClassData;
  final Map<String, DndClass?> _progressionClassData = {};
  final Map<String, int?> _subclassChoiceLevelsByClass = {};
  bool _backgroundsLoaded = false;
  String? _backgroundsLoadError;

  final List<String> alignments = [
    "Lawful Good",
    "Neutral Good",
    "Chaotic Good",
    "Lawful Neutral",
    "True Neutral",
    "Chaotic Neutral",
    "Lawful Evil",
    "Neutral Evil",
    "Chaotic Evil",
  ];

  String? selectedAlignment;
  Character? character;

  static const Map<String, List<String>> _classSkillOptions = {
    'barbarian': [
      'Animal Handling',
      'Athletics',
      'Intimidation',
      'Nature',
      'Perception',
      'Survival',
    ],
    'bard': [
      'Acrobatics',
      'Animal Handling',
      'Arcana',
      'Athletics',
      'Deception',
      'History',
      'Insight',
      'Intimidation',
      'Investigation',
      'Medicine',
      'Nature',
      'Perception',
      'Performance',
      'Persuasion',
      'Religion',
      'Sleight of Hand',
      'Stealth',
      'Survival',
    ],
    'cleric': [
      'History',
      'Insight',
      'Medicine',
      'Persuasion',
      'Religion',
    ],
    'druid': [
      'Arcana',
      'Animal Handling',
      'Insight',
      'Medicine',
      'Nature',
      'Perception',
      'Religion',
      'Survival',
    ],
    'fighter': [
      'Acrobatics',
      'Animal Handling',
      'Athletics',
      'History',
      'Insight',
      'Intimidation',
      'Perception',
      'Survival',
    ],
    'monk': [
      'Acrobatics',
      'Athletics',
      'History',
      'Insight',
      'Religion',
      'Stealth',
    ],
    'paladin': [
      'Athletics',
      'Insight',
      'Intimidation',
      'Medicine',
      'Persuasion',
      'Religion',
    ],
    'ranger': [
      'Animal Handling',
      'Athletics',
      'Insight',
      'Investigation',
      'Nature',
      'Perception',
      'Stealth',
      'Survival',
    ],
    'rogue': [
      'Acrobatics',
      'Athletics',
      'Deception',
      'Insight',
      'Intimidation',
      'Investigation',
      'Perception',
      'Performance',
      'Persuasion',
      'Sleight of Hand',
      'Stealth',
    ],
    'sorcerer': [
      'Arcana',
      'Deception',
      'Insight',
      'Intimidation',
      'Persuasion',
      'Religion',
    ],
    'warlock': [
      'Arcana',
      'Deception',
      'History',
      'Intimidation',
      'Investigation',
      'Nature',
      'Religion',
    ],
    'wizard': [
      'Arcana',
      'History',
      'Insight',
      'Investigation',
      'Medicine',
      'Religion',
    ],
    'artificer': [
      'Arcana',
      'History',
      'Investigation',
      'Medicine',
      'Nature',
      'Perception',
      'Sleight of Hand',
    ],
  };

  static const Map<String, int> _classSkillChoices = {
    'barbarian': 2,
    'bard': 3,
    'cleric': 2,
    'druid': 2,
    'fighter': 2,
    'monk': 2,
    'paladin': 2,
    'ranger': 3,
    'rogue': 4,
    'sorcerer': 2,
    'warlock': 2,
    'wizard': 2,
    'artificer': 2,
  };

  String _normalizeClassName(String value) {
    return value.trim().toLowerCase();
  }

  List<String> _getAvailableSkillsForClass(String className) {
    return _classSkillOptions[_normalizeClassName(className)] ?? const [];
  }

  int _getSkillChoiceCountForClass(String className) {
    return _classSkillChoices[_normalizeClassName(className)] ?? 2;
  }

  String _normalizeSkill(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  void initState() {
    super.initState();

    final provider = context.read<CharacterProvider>();

    try {
      character = provider.getCharacterById(widget.characterId);
    } catch (_) {
      character = null;
    }

    _nameController = TextEditingController(text: character?.name ?? '');
    _backstoryController =
        TextEditingController(text: character?.backstory ?? '');
    _notesController = TextEditingController(text: character?.notes ?? '');
    _maxHpController =
        TextEditingController(text: character?.maxHp.toString() ?? '0');
    _currentHpController =
        TextEditingController(text: character?.currentHp.toString() ?? '0');
    _acController =
        TextEditingController(text: character?.armorClass.toString() ?? '10');
    _speedController =
        TextEditingController(text: character?.speed.toString() ?? '30');

    if (character == null) return;

    _portraitPath = character!.portraitPath;

    selectedAlignment = alignments.contains(character!.alignment)
        ? character!.alignment
        : "True Neutral";

    _loadBackgrounds(character!.background.name);
    _loadClassData();
    _loadProgressionClassData();
    _loadFeats();
  }

  Future<void> _loadBackgrounds(String currentBg) async {
    try {
      final list = await DndDataService.getBackgrounds();

      if (!mounted) return;

      setState(() {
        backgrounds = _dedupeBackgrounds(list);
        selectedBackground = _resolveSelectedBackground(currentBg);
        _backgroundsLoaded = true;
        _backgroundsLoadError = null;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading backgrounds for edit screen: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        backgrounds = const [];
        selectedBackground = null;
        _backgroundsLoaded = true;
        _backgroundsLoadError = 'Background options could not be loaded.';
      });
    }
  }

  List<DndBackground> _dedupeBackgrounds(List<DndBackground> source) {
    final seen = <String>{};
    final result = <DndBackground>[];

    for (final background in source) {
      final key = background.index.trim().isNotEmpty
          ? background.index.trim().toLowerCase()
          : background.name.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(background);
    }

    return result;
  }

  DndBackground? _resolveSelectedBackground(String currentBg) {
    if (backgrounds.isEmpty) return null;

    final normalizedCurrent = currentBg.trim().toLowerCase();
    for (final background in backgrounds) {
      if (background.name.trim().toLowerCase() == normalizedCurrent ||
          background.index.trim().toLowerCase() == normalizedCurrent) {
        return background;
      }
    }

    return backgrounds.first;
  }

  Future<void> _loadClassData() async {
    if (character == null) return;

    try {
      final classData = await ClassDataService.loadClass(character!.charClass);
      if (!mounted) return;

      setState(() {
        _loadedClassData = classData;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadedClassData = null;
      });
    }
  }

  Future<void> _loadProgressionClassData() async {
    if (character == null) return;

    final classNames = character!.classLevels.keys
        .where((className) => className.trim().isNotEmpty)
        .toList();

    if (classNames.isEmpty && character!.charClass.trim().isNotEmpty) {
      classNames.add(character!.charClass);
    }

    final classDataByName = <String, DndClass?>{};
    final choiceLevelsByClass = <String, int?>{};

    for (final className in classNames) {
      final key = _normalizeClassName(className);
      classDataByName[key] = await ClassDataService.loadClass(className);
      choiceLevelsByClass[key] =
          await ClassDataService.getSubclassChoiceLevel(className);
    }

    if (!mounted) return;

    setState(() {
      _progressionClassData
        ..clear()
        ..addAll(classDataByName);
      _subclassChoiceLevelsByClass
        ..clear()
        ..addAll(choiceLevelsByClass);
    });
  }

  Future<void> _loadFeats() async {
    try {
      final feats = await FeatDataService.loadFeats();
      if (!mounted) return;

      setState(() {
        _allFeats = feats;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _allFeats = [];
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted || bytes.isEmpty) return;

      setState(() {
        _portraitBytes = bytes;
        _portraitFileName = picked.name;
        _portraitPath = picked.path;
      });
    } catch (e) {
      debugPrint('Error picking portrait: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The portrait could not be opened. Try another image.'),
        ),
      );
    }
  }

  Future<void> _showSkillSelectionDialog() async {
    if (character == null) return;

    final availableSkills = _getAvailableSkillsForClass(character!.charClass);
    final maxChoices = _getSkillChoiceCountForClass(character!.charClass);

    if (availableSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No skill options configured for this class yet.'),
        ),
      );
      return;
    }

    final selectedSkills = [...character!.classSkills];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isSelected(String skill) {
              final target = _normalizeSkill(skill);
              return selectedSkills.any(
                (selected) => _normalizeSkill(selected) == target,
              );
            }

            void toggleSkill(String skill) {
              final target = _normalizeSkill(skill);
              final alreadySelected = selectedSkills.any(
                (selected) => _normalizeSkill(selected) == target,
              );

              if (alreadySelected) {
                selectedSkills.removeWhere(
                  (selected) => _normalizeSkill(selected) == target,
                );
                return;
              }

              if (selectedSkills.length >= maxChoices) return;
              selectedSkills.add(skill);
            }

            return AlertDialog(
              title: Text('Choose $maxChoices skills'),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${character!.charClass} \u2022 ${selectedSkills.length} / $maxChoices selected',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...availableSkills.map((skill) {
                        final selected = isSelected(skill);
                        final disabled =
                            !selected && selectedSkills.length >= maxChoices;

                        return CheckboxListTile(
                          value: selected,
                          onChanged: disabled
                              ? null
                              : (_) {
                                  setDialogState(() {
                                    toggleSkill(skill);
                                  });
                                },
                          title: Text(skill),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedSkills.length == maxChoices
                      ? () async {
                          final provider = context.read<CharacterProvider>();

                          await provider.updateCharacterById(
                            widget.characterId,
                            (ch) {
                              ch.classSkills =
                                  List<String>.from(selectedSkills);
                            },
                          );

                          if (!mounted) return;

                          setState(() {
                            character =
                                provider.getCharacterById(widget.characterId);
                          });

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                        }
                      : null,
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showFeatSelectionDialog() async {
    if (character == null) return;

    final provider = context.read<CharacterProvider>();
    final selectedIds = List<String>.from(character!.selectedFeatIds);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildMetaChip(String text, {IconData? icon}) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.deepPurpleAccent.withOpacity(0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 12, color: Colors.white70),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            final sortedFeats = [..._allFeats]..sort((a, b) {
                final aErrors =
                    FeatValidationService.getValidationErrors(character!, a);
                final bErrors =
                    FeatValidationService.getValidationErrors(character!, b);

                final aUnavailable = aErrors.isNotEmpty &&
                    !(aErrors.length == 1 &&
                        aErrors.first == 'Already selected');
                final bUnavailable = bErrors.isNotEmpty &&
                    !(bErrors.length == 1 &&
                        bErrors.first == 'Already selected');

                if (aUnavailable != bUnavailable) {
                  return aUnavailable ? 1 : -1;
                }

                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(
                    child: Text('Choose Feats'),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${selectedIds.length} selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                height: 520,
                child: _allFeats.isEmpty
                    ? const Center(
                        child: Text(
                          'No feats loaded.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        itemCount: sortedFeats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final feat = sortedFeats[index];
                          final isSelected = selectedIds.contains(feat.id);

                          final errors =
                              FeatValidationService.getValidationErrors(
                            character!,
                            feat,
                          );

                          final onlyAlreadySelected = errors.length == 1 &&
                              errors.first == 'Already selected';

                          final canInteract = errors.isEmpty ||
                              isSelected ||
                              onlyAlreadySelected;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: !canInteract
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        if (isSelected) {
                                          selectedIds.remove(feat.id);
                                        } else {
                                          selectedIds.add(feat.id);
                                        }
                                      });
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: !canInteract
                                      ? const Color(0xFF202028)
                                          .withOpacity(0.55)
                                      : isSelected
                                          ? Colors.deepPurpleAccent
                                              .withOpacity(0.16)
                                          : const Color(0xFF202028),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: !canInteract
                                        ? Colors.redAccent.withOpacity(0.22)
                                        : isSelected
                                            ? Colors.deepPurpleAccent
                                            : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: !canInteract
                                          ? null
                                          : (value) {
                                              setDialogState(() {
                                                if (value == true) {
                                                  if (!selectedIds
                                                      .contains(feat.id)) {
                                                    selectedIds.add(feat.id);
                                                  }
                                                } else {
                                                  selectedIds.remove(feat.id);
                                                }
                                              });
                                            },
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  feat.name,
                                                  style: TextStyle(
                                                    color: !canInteract
                                                        ? Colors.white
                                                            .withOpacity(0.72)
                                                        : Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (isSelected)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    left: 8,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors
                                                        .deepPurpleAccent
                                                        .withOpacity(0.22),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: const Text(
                                                    'Selected',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                )
                                              else if (!canInteract)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    left: 8,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent
                                                        .withOpacity(0.18),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: const Text(
                                                    'Unavailable',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              buildMetaChip(
                                                feat.source,
                                                icon: Icons.menu_book_outlined,
                                              ),
                                              if (feat.hasChoices)
                                                buildMetaChip(
                                                  'Has choices',
                                                  icon: Icons.tune,
                                                ),
                                              if (feat.repeatable)
                                                buildMetaChip(
                                                  'Repeatable',
                                                  icon: Icons.repeat,
                                                ),
                                            ],
                                          ),
                                          if (feat.description
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              feat.description.trim(),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.72),
                                                fontSize: 13,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                          if (errors.isNotEmpty &&
                                              !onlyAlreadySelected) ...[
                                            const SizedBox(height: 10),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: errors.map((error) {
                                                return Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent
                                                        .withOpacity(0.14),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                    border: Border.all(
                                                      color: Colors.redAccent
                                                          .withOpacity(0.20),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    error,
                                                    style: const TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final featSelections = Map<String, dynamic>.from(
                      character!.featSelections,
                    );

                    for (final feat in _allFeats) {
                      final isSelected = selectedIds.contains(feat.id);
                      final needsAbilityChoice = _featNeedsAbilityChoice(feat);
                      final needsDamageTypeChoice =
                          _featNeedsDamageTypeChoice(feat);
                      final needsSpellcastingAbilityChoice =
                          _featNeedsSpellcastingAbilityChoice(feat);
                      final needsVariantChoice = _featNeedsVariantChoice(feat);
                      if (!isSelected) {
                        featSelections.remove(feat.id);
                        continue;
                      }

                      if (!needsAbilityChoice &&
                          !needsDamageTypeChoice &&
                          !needsSpellcastingAbilityChoice &&
                          !needsVariantChoice) {
                        continue;
                      }

                      final existingSelection = (featSelections[feat.id] is Map)
                          ? Map<String, dynamic>.from(featSelections[feat.id])
                          : <String, dynamic>{};

                      if (needsVariantChoice) {
                        final currentChosenVariant =
                            existingSelection['chosenVariant']
                                ?.toString()
                                .trim();

                        final chosenVariant =
                            await _showFeatVariantChoiceDialog(
                          feat,
                          initialValue: currentChosenVariant,
                        );

                        if (chosenVariant == null) {
                          return;
                        }

                        existingSelection['chosenVariant'] = chosenVariant;
                      }
                      if (needsAbilityChoice) {
                        final currentChosenAbility =
                            existingSelection['chosenAbility']
                                ?.toString()
                                .trim()
                                .toUpperCase();

                        final chosenAbility =
                            await _showFeatAbilityChoiceDialog(
                          feat,
                          initialValue: currentChosenAbility,
                        );

                        if (chosenAbility == null) {
                          return;
                        }

                        existingSelection['chosenAbility'] = chosenAbility;
                      }
                      if (needsDamageTypeChoice) {
                        final currentChosenDamageType =
                            existingSelection['chosenDamageType']
                                ?.toString()
                                .trim()
                                .toLowerCase();

                        final chosenDamageType =
                            await _showFeatDamageTypeChoiceDialog(
                          feat,
                          initialValue: currentChosenDamageType,
                        );

                        if (chosenDamageType == null) {
                          return;
                        }

                        existingSelection['chosenDamageType'] =
                            chosenDamageType;
                      }

                      if (needsSpellcastingAbilityChoice) {
                        final currentChosenSpellcastingAbility =
                            existingSelection['chosenSpellcastingAbility']
                                ?.toString()
                                .trim()
                                .toUpperCase();

                        final chosenSpellcastingAbility =
                            await _showFeatSpellcastingAbilityChoiceDialog(
                          feat,
                          initialValue: currentChosenSpellcastingAbility,
                        );

                        if (chosenSpellcastingAbility == null) {
                          return;
                        }

                        existingSelection['chosenSpellcastingAbility'] =
                            chosenSpellcastingAbility;
                      }

                      featSelections[feat.id] = existingSelection;
                    }

                    await provider.updateCharacterById(character!.id, (ch) {
                      ch.selectedFeatIds = List<String>.from(selectedIds);
                      ch.featSelections =
                          Map<String, dynamic>.from(featSelections);
                    });

                    await provider.syncFeats(character!.id);

                    if (!mounted) return;

                    setState(() {
                      character = provider.getCharacterById(widget.characterId);
                    });

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _featNeedsAbilityChoice(FeatData feat) {
    for (final entry in feat.abilityIncreases) {
      if (entry is! Map) continue;

      final map = Map<String, dynamic>.from(entry);
      final choose = map['choose'];

      if (choose is Map && choose['from'] is List) {
        return true;
      }
    }

    return false;
  }

  bool _featNeedsDamageTypeChoice(FeatData feat) {
    const manualDamageTypeChoiceFeatIds = {
      'elemental_adept_phb',
    };

    if (manualDamageTypeChoiceFeatIds.contains(feat.id)) {
      return true;
    }

    if (feat.resist.isNotEmpty) {
      for (final entry in feat.resist) {
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          final choose = map['choose'];
          if (choose is Map && choose['from'] is List) {
            return true;
          }
        }
      }
    }

    if (feat.modifiers.isNotEmpty) {
      final chooseFrom = feat.modifiers['chooseDamageTypeFrom'];
      if (chooseFrom is List && chooseFrom.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  List<String> _getFeatDamageTypeChoiceOptions(FeatData feat) {
    for (final entry in feat.resist) {
      if (entry is! Map) continue;

      final map = Map<String, dynamic>.from(entry);
      final choose = map['choose'];

      if (choose is Map && choose['from'] is List) {
        return (choose['from'] as List)
            .map((e) => e.toString().trim().toLowerCase())
            .toList();
      }
    }

    final chooseFrom = feat.modifiers['chooseDamageTypeFrom'];
    if (chooseFrom is List) {
      return chooseFrom.map((e) => e.toString().trim().toLowerCase()).toList();
    }

    return const [];
  }

  String? _getChosenDamageTypeForFeat(FeatData feat) {
    final featSelections =
        character?.featSelections ?? const <String, dynamic>{};
    final selection = featSelections[feat.id];

    if (selection is Map && selection['chosenDamageType'] != null) {
      return selection['chosenDamageType'].toString().trim().toLowerCase();
    }
    return null;
  }

  bool _featNeedsSpellcastingAbilityChoice(FeatData feat) {
    for (final entry in feat.additionalSpells) {
      if (entry is! Map) continue;

      final map = Map<String, dynamic>.from(entry);

      if (map['chooseAbility'] == true) {
        return true;
      }

      final ability = map['ability'];
      if (ability is Map) {
        final choose = ability['choose'];

        if (choose == true) {
          return true;
        }

        if (choose is List && choose.isNotEmpty) {
          return true;
        }

        if (choose is Map && choose['from'] is List) {
          return true;
        }
      }
    }

    return false;
  }

  List<String> _getFeatSpellcastingAbilityChoiceOptions(FeatData feat) {
    const defaultOptions = ['INT', 'WIS', 'CHA'];

    for (final entry in feat.additionalSpells) {
      if (entry is! Map) continue;

      final map = Map<String, dynamic>.from(entry);

      if (map['chooseAbility'] == true) {
        return defaultOptions;
      }

      final ability = map['ability'];
      if (ability is Map) {
        final choose = ability['choose'];

        if (choose is List && choose.isNotEmpty) {
          return choose.map((e) => e.toString().trim().toUpperCase()).toList();
        }

        if (choose is Map && choose['from'] is List) {
          return (choose['from'] as List)
              .map((e) => e.toString().trim().toUpperCase())
              .toList();
        }

        if (choose == true) {
          return defaultOptions;
        }
      }
    }

    return const [];
  }

  String? _getChosenSpellcastingAbilityForFeat(FeatData feat) {
    final featSelections =
        character?.featSelections ?? const <String, dynamic>{};
    final selection = featSelections[feat.id];

    if (selection is Map && selection['chosenSpellcastingAbility'] != null) {
      return selection['chosenSpellcastingAbility']
          .toString()
          .trim()
          .toUpperCase();
    }
    return null;
  }

  bool _featNeedsVariantChoice(FeatData feat) {
    if (feat.additionalSpells.length <= 1) return false;

    final variantNames = <String>[];

    for (final entry in feat.additionalSpells) {
      if (entry is! Map) continue;

      final map = Map<String, dynamic>.from(entry);
      final name = map['name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        variantNames.add(name);
      }
    }

    return variantNames.length >= 2;
  }

  List<String> _getFeatVariantOptions(FeatData feat) {
    final options = <String>[];

    for (final entry in feat.additionalSpells) {
      if (entry is! Map) continue;

      final map = Map<String, dynamic>.from(entry);
      final name = map['name']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        options.add(name);
      }
    }

    return options;
  }

  String? _getChosenVariantForFeat(FeatData feat) {
    final featSelections =
        character?.featSelections ?? const <String, dynamic>{};
    final selection = featSelections[feat.id];

    if (selection is Map && selection['chosenVariant'] != null) {
      return selection['chosenVariant'].toString().trim();
    }
    return null;
  }

  List<String> _getFeatAbilityChoiceOptions(FeatData feat) {
    for (final entry in feat.abilityIncreases) {
      if (entry is! Map) continue;

      final map = Map<String, dynamic>.from(entry);
      final choose = map['choose'];

      if (choose is Map && choose['from'] is List) {
        return (choose['from'] as List)
            .map((e) => e.toString().trim().toUpperCase())
            .toList();
      }
    }

    return const [];
  }

  String? _getChosenAbilityForFeat(FeatData feat) {
    final featSelections =
        character?.featSelections ?? const <String, dynamic>{};
    final selection = featSelections[feat.id];

    if (selection is Map && selection['chosenAbility'] != null) {
      return selection['chosenAbility'].toString().trim().toUpperCase();
    }
    return null;
  }

  Future<String?> _showFeatAbilityChoiceDialog(
    FeatData feat, {
    String? initialValue,
  }) async {
    final options = _getFeatAbilityChoiceOptions(feat);
    if (options.isEmpty) return null;

    String? selected = initialValue ?? options.first;

    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Choose ability for ${feat.name}'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This feat requires choosing an ability score increase.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...options.map((ability) {
                      return RadioListTile<String>(
                        value: ability,
                        groupValue: selected,
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selected = value;
                          });
                        },
                        title: Text(ability),
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(dialogContext, selected),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showFeatDamageTypeChoiceDialog(
    FeatData feat, {
    String? initialValue,
  }) async {
    final options = _getFeatDamageTypeChoiceOptions(feat);
    if (options.isEmpty) return null;

    String? selected = initialValue ?? options.first;

    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Choose damage type for ${feat.name}'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This feat requires choosing a damage type.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...options.map((damageType) {
                      return RadioListTile<String>(
                        value: damageType,
                        groupValue: selected,
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selected = value;
                          });
                        },
                        title: Text(
                          damageType[0].toUpperCase() + damageType.substring(1),
                        ),
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(dialogContext, selected),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showFeatSpellcastingAbilityChoiceDialog(
    FeatData feat, {
    String? initialValue,
  }) async {
    final options = _getFeatSpellcastingAbilityChoiceOptions(feat);
    if (options.isEmpty) return null;

    String? selected = initialValue ?? options.first;

    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Choose spellcasting ability for ${feat.name}'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This feat requires choosing a spellcasting ability.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...options.map((ability) {
                      return RadioListTile<String>(
                        value: ability,
                        groupValue: selected,
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selected = value;
                          });
                        },
                        title: Text(ability),
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(dialogContext, selected),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showFeatVariantChoiceDialog(
    FeatData feat, {
    String? initialValue,
  }) async {
    final options = _getFeatVariantOptions(feat);
    if (options.isEmpty) return null;

    String? selected = initialValue ?? options.first;

    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Choose variant for ${feat.name}'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This feat requires choosing one of its available variants.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...options.map((variant) {
                      return RadioListTile<String>(
                        value: variant,
                        groupValue: selected,
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selected = value;
                          });
                        },
                        title: Text(variant),
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(dialogContext, selected),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignSubclassDialog({String? className}) async {
    if (character == null) return;

    final targetClassName = className ?? character!.charClass;
    final hasSubclass =
        character!.subclassForClass(targetClassName)?.trim().isNotEmpty ??
            false;
    if (hasSubclass) return;

    final classKey = _normalizeClassName(targetClassName);
    var classData = _progressionClassData[classKey];
    classData ??= classKey == _normalizeClassName(character!.charClass)
        ? _loadedClassData
        : null;
    classData ??= await ClassDataService.loadClass(targetClassName);

    if (!mounted) return;

    if (classData == null || classData.subclasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subclass options found for this class.'),
        ),
      );
      return;
    }
    final selectedClassData = classData;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF17181F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: const [
                        Expanded(
                          child: Text(
                            'Assign Subclass',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Choose a subclass for $targetClassName. Once assigned, it cannot be changed from this screen.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: selectedClassData.subclasses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final subclass = selectedClassData.subclasses[index];

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final provider =
                                  context.read<CharacterProvider>();

                              await provider.updateCharacterById(
                                character!.id,
                                (ch) {
                                  final alreadyHasSubclass = ch
                                          .subclassForClass(targetClassName)
                                          ?.trim()
                                          .isNotEmpty ??
                                      false;

                                  if (alreadyHasSubclass) return;
                                  ch.progression = ch.normalizedProgression
                                      .withSubclassForClass(
                                    className: targetClassName,
                                    subclassName: subclass.name,
                                  );
                                  if (_normalizeClassName(ch.charClass) ==
                                      _normalizeClassName(targetClassName)) {
                                    ch.subclass = subclass.name;
                                  }
                                },
                              );

                              await provider
                                  .syncFeaturesAndResources(character!.id);

                              if (!mounted) return;

                              setState(() {
                                character = provider
                                    .getCharacterById(widget.characterId);
                              });
                              await _loadProgressionClassData();

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF202028),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.deepPurpleAccent.withOpacity(
                                    0.22,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subclass.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if ((subclass.description ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      subclass.description!.trim(),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.72),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
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
      },
    );
  }

  Future<void> _saveChanges() async {
    final provider = context.read<CharacterProvider>();
    final maxHp = int.tryParse(_maxHpController.text) ?? 0;
    final currentHp = int.tryParse(_currentHpController.text) ?? 0;
    final ac = int.tryParse(_acController.text) ?? 10;
    final speed = int.tryParse(_speedController.text) ?? 30;

    final safeCurrentHp = currentHp.clamp(0, maxHp > 0 ? maxHp : currentHp);
    if (character == null) return;

    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    var resolvedPortraitPath = _portraitPath ?? character!.portraitPath;
    if (_portraitBytes != null) {
      try {
        resolvedPortraitPath =
            await SupabaseStorageService.uploadUserImageBytes(
          bytes: _portraitBytes!,
          fileName: _portraitFileName ?? 'character-portrait.jpg',
          ownerUserId: userId,
          folder: 'character-portraits',
          entityId: character!.id,
        );
      } catch (e) {
        debugPrint('Error uploading portrait to Supabase: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not upload the portrait. Try again.'),
          ),
        );
        return;
      }
    }

    await provider.updateCharacterById(character!.id, (ch) {
      ch.name = _nameController.text.trim();
      ch.maxHp = maxHp;
      ch.currentHp = safeCurrentHp;
      ch.armorClass = ac;
      ch.speed = speed;
      ch.background = selectedBackground ?? ch.background;
      ch.alignment = selectedAlignment ?? ch.alignment;
      ch.portraitPath = resolvedPortraitPath;
      ch.backstory = _backstoryController.text.trim().isEmpty
          ? null
          : _backstoryController.text.trim();
      ch.notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
    });

    if (!mounted) return;
    context.go('/character/${widget.characterId}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _backstoryController.dispose();
    _notesController.dispose();
    _maxHpController.dispose();
    _currentHpController.dispose();
    _acController.dispose();
    _speedController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return stitchCodexInputDecoration(
      labelText: label,
      hintText: hint,
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsets? padding,
  }) {
    return StitchCodexPanel(
      padding: padding ?? const EdgeInsets.all(18),
      child: child,
    );
  }

  TextStyle get _sectionTitleStyle {
    return const TextStyle(
      color: StitchCodexPalette.textPrimary,
      fontFamily: StitchTypography.display,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );
  }

  TextStyle get _sectionDescriptionStyle {
    return const TextStyle(
      color: StitchCodexPalette.textMuted,
      fontFamily: StitchTypography.body,
      fontSize: 15,
      height: 1.4,
    );
  }

  Widget _portraitEditor(double radius) {
    final ImageProvider? portraitImage = _portraitBytes != null
        ? MemoryImage(_portraitBytes!)
        : hasDisplayableImagePath(_portraitPath)
            ? imageProviderFromPath(_portraitPath!)
            : null;

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: radius * 2,
        height: radius * 2.25,
        decoration: BoxDecoration(
          color: StitchCodexPalette.surfaceRaised,
          border: Border.all(
            color: StitchCodexPalette.bronze.withValues(alpha: 0.44),
          ),
          image: portraitImage != null
              ? DecorationImage(
                  image: portraitImage,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                )
              : null,
        ),
        child: portraitImage == null
            ? const Icon(
                Icons.add_a_photo_outlined,
                size: 32,
                color: StitchCodexPalette.bronze,
              )
            : null,
      ),
    );
  }

  Widget _buildBackgroundField() {
    if (backgrounds.isEmpty) {
      return TextFormField(
        enabled: false,
        initialValue: character?.background.name ?? 'Unknown',
        style: const TextStyle(color: Colors.white70),
        decoration: _inputDecoration(
          'Background',
          hint: _backgroundsLoadError ?? 'No background options available.',
        ),
      );
    }

    return DropdownButtonFormField<DndBackground>(
      initialValue:
          backgrounds.contains(selectedBackground) ? selectedBackground : null,
      dropdownColor: StitchCodexPalette.surfaceRaised,
      style: stitchCodexFieldTextStyle,
      decoration: _inputDecoration('Background'),
      items: backgrounds
          .map(
            (bg) => DropdownMenuItem(
              value: bg,
              child: Text(
                bg.name,
                style: stitchCodexFieldTextStyle,
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        setState(() => selectedBackground = val);
      },
    );
  }

  Widget _buildAlignmentField() {
    return DropdownButtonFormField<String>(
      initialValue:
          alignments.contains(selectedAlignment) ? selectedAlignment : null,
      dropdownColor: StitchCodexPalette.surfaceRaised,
      style: stitchCodexFieldTextStyle,
      decoration: _inputDecoration('Alignment'),
      items: alignments
          .map(
            (alignment) => DropdownMenuItem(
              value: alignment,
              child: Text(
                alignment,
                style: stitchCodexFieldTextStyle,
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        setState(() => selectedAlignment = val);
      },
    );
  }

  Widget _buildSubclassEditorCard() {
    if (character == null) return const SizedBox.shrink();

    final classEntries = character!.classLevels.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    if (classEntries.isEmpty && character!.charClass.trim().isNotEmpty) {
      classEntries.add(MapEntry(character!.charClass, character!.level));
    }

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Class Progression",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Review subclasses per class. Use this only to repair legacy or manually edited characters.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (classEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF202028),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: const Text(
                'No class progression found.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ...classEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildClassProgressionSubclassTile(
                  className: entry.key,
                  classLevel: entry.value,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassProgressionSubclassTile({
    required String className,
    required int classLevel,
  }) {
    final classKey = _normalizeClassName(className);
    final classData = _progressionClassData[classKey];
    final choiceLevel = _subclassChoiceLevelsByClass[classKey];
    final subclassName = character!.subclassForClass(className)?.trim();
    final hasSubclass = subclassName != null && subclassName.isNotEmpty;
    final hasSubclassOptions = classData?.subclasses.isNotEmpty ?? false;
    final canAssign = !hasSubclass &&
        hasSubclassOptions &&
        choiceLevel != null &&
        classLevel >= choiceLevel;

    String status;
    Color statusColor;

    if (hasSubclass) {
      status = subclassName;
      statusColor = Colors.white;
    } else if (!hasSubclassOptions && classData == null) {
      status = 'Loading subclass data...';
      statusColor = Colors.white60;
    } else if (!hasSubclassOptions) {
      status = 'No subclass options found';
      statusColor = Colors.white60;
    } else if (choiceLevel == null) {
      status = 'Subclass choice level unknown';
      statusColor = Colors.amberAccent;
    } else if (classLevel < choiceLevel) {
      status = 'Subclass available at $className $choiceLevel';
      statusColor = Colors.white60;
    } else {
      status = 'Missing subclass';
      statusColor = Colors.amberAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF202028),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canAssign
              ? Colors.deepPurpleAccent.withOpacity(0.38)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$className $classLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canAssign)
            OutlinedButton.icon(
              onPressed: () => _showAssignSubclassDialog(className: className),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Assign'),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillsEditorCard() {
    if (character == null) return const SizedBox.shrink();

    final availableSkills = _getAvailableSkillsForClass(character!.charClass);
    final maxChoices = _getSkillChoiceCountForClass(character!.charClass);
    final currentSkills = character!.classSkills;

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Skill Proficiencies",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Choose $maxChoices skill proficiencies for your ${character!.charClass}.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
            ),
          ),
          const SizedBox(height: 14),
          if (availableSkills.isEmpty)
            const Text(
              'No class skill options configured yet.',
              style: TextStyle(color: Colors.white70),
            )
          else if (currentSkills.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF202028),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: const Text(
                'No skills selected yet.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: currentSkills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    skill,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showSkillSelectionDialog,
            icon: const Icon(Icons.tune),
            label: Text(
              currentSkills.isEmpty ? 'Choose Skills' : 'Edit Skills',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatsEditorCard() {
    if (character == null) return const SizedBox.shrink();

    final selectedIds = character!.selectedFeatIds;
    final selectedFeats = _allFeats
        .where((feat) => selectedIds.contains(feat.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    Widget buildMetaChip(String text, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.deepPurpleAccent.withOpacity(0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: Colors.white70),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildFeatCard(FeatData feat) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF202028),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.deepPurpleAccent.withOpacity(0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              feat.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildMetaChip(feat.source, icon: Icons.menu_book_outlined),
                if (feat.hasChoices)
                  buildMetaChip(
                    'Has choices',
                    icon: Icons.tune,
                  ),
                if (_featNeedsVariantChoice(feat) &&
                    _getChosenVariantForFeat(feat) != null)
                  buildMetaChip(
                    'Variant: ${_getChosenVariantForFeat(feat)!}',
                    icon: Icons.account_tree_outlined,
                  ),
                if (_featNeedsAbilityChoice(feat) &&
                    _getChosenAbilityForFeat(feat) != null)
                  buildMetaChip(
                    'Ability: ${_getChosenAbilityForFeat(feat)!}',
                    icon: Icons.fitness_center,
                  ),
                if (_featNeedsDamageTypeChoice(feat) &&
                    _getChosenDamageTypeForFeat(feat) != null)
                  buildMetaChip(
                    'Damage: ${_getChosenDamageTypeForFeat(feat)!}',
                    icon: Icons.local_fire_department_outlined,
                  ),
                if (_featNeedsSpellcastingAbilityChoice(feat) &&
                    _getChosenSpellcastingAbilityForFeat(feat) != null)
                  buildMetaChip(
                    'Spellcasting: ${_getChosenSpellcastingAbilityForFeat(feat)!}',
                    icon: Icons.auto_awesome,
                  ),
                if (feat.repeatable)
                  buildMetaChip(
                    'Repeatable',
                    icon: Icons.repeat,
                  ),
              ],
            ),
            if (feat.description.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                feat.description.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Feats",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${selectedFeats.length} selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Manage the feats selected for this character.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
            ),
          ),
          const SizedBox(height: 14),
          if (selectedFeats.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF202028),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.workspace_premium_outlined,
                    color: Colors.white.withOpacity(0.45),
                    size: 28,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No feats selected yet.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose feats to start defining this character further.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                ...selectedFeats.map((feat) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: buildFeatCard(feat),
                  );
                }),
              ],
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showFeatSelectionDialog,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(
                selectedFeats.isEmpty ? 'Choose Feats' : 'Edit Feats',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (character == null) {
      return const Scaffold(
        backgroundColor: StitchCodexPalette.ground,
        body: StitchCodexBackground(
          child: Center(
            child: Text(
              'Character not found',
              style: TextStyle(
                color: StitchCodexPalette.textMuted,
                fontFamily: StitchTypography.body,
              ),
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 700;
    final isLarge = screenWidth >= 1050;

    final horizontalPadding = isLarge ? 32.0 : (isTablet ? 24.0 : 16.0);
    final maxWidth = isLarge ? 1100.0 : 850.0;
    final avatarRadius = isLarge ? 58.0 : (isTablet ? 52.0 : 46.0);
    final titleSize = isLarge ? 28.0 : (isTablet ? 24.0 : 21.0);

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        title: const Text(
          'EDIT CHARACTER',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: StitchCodexPalette.ground,
      ),
      body: StitchCodexBackground(
        child: !_backgroundsLoaded
            ? const Center(
                child: CircularProgressIndicator(
                  color: StitchCodexPalette.bronze,
                ),
              )
            : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionCard(
                          padding: EdgeInsets.all(isTablet ? 22 : 16),
                          child: isTablet
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _portraitEditor(avatarRadius),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Identity',
                                            style: _sectionTitleStyle.copyWith(
                                              fontSize: titleSize,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Edit the core information of your character. Portrait, name, background, alignment and narrative details live here.',
                                            style: _sectionDescriptionStyle,
                                          ),
                                          const SizedBox(height: 14),
                                          OutlinedButton.icon(
                                            onPressed: _pickImage,
                                            style:
                                                stitchCodexOutlineButtonStyle(),
                                            icon: const Icon(
                                              Icons.image_outlined,
                                            ),
                                            label: const Text(
                                              "Change portrait",
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _portraitEditor(avatarRadius),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Identity',
                                      style: _sectionTitleStyle.copyWith(
                                        fontSize: titleSize,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Edit the core information of your character.',
                                      textAlign: TextAlign.center,
                                      style: _sectionDescriptionStyle,
                                    ),
                                    const SizedBox(height: 14),
                                    OutlinedButton.icon(
                                      onPressed: _pickImage,
                                      style: stitchCodexOutlineButtonStyle(),
                                      icon: const Icon(Icons.image_outlined),
                                      label: const Text("Change portrait"),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 18),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Basic Info',
                                style: _sectionTitleStyle,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _nameController,
                                style: stitchCodexFieldTextStyle,
                                decoration: _inputDecoration(
                                  "Name",
                                  hint: "Character name",
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (isLarge)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildBackgroundField(),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildAlignmentField(),
                                    ),
                                  ],
                                )
                              else ...[
                                _buildBackgroundField(),
                                const SizedBox(height: 16),
                                _buildAlignmentField(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildSubclassEditorCard(),
                        const SizedBox(height: 18),
                        _buildSkillsEditorCard(),
                        const SizedBox(height: 18),
                        _buildFeatsEditorCard(),
                        const SizedBox(height: 18),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Narrative',
                                style: _sectionTitleStyle,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This is the part that makes the sheet feel alive.',
                                style: _sectionDescriptionStyle,
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _backstoryController,
                                style: stitchCodexFieldTextStyle,
                                maxLines: 7,
                                decoration: _inputDecoration(
                                  "Backstory",
                                  hint:
                                      "Who is this character? Where do they come from? What shaped them?",
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _notesController,
                                style: stitchCodexFieldTextStyle,
                                maxLines: 7,
                                decoration: _inputDecoration(
                                  "Notes",
                                  hint:
                                      "Goals, secrets, reminders, unresolved threads, personality details...",
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Combat Stats',
                                style: _sectionTitleStyle,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Core combat values of your character.',
                                style: _sectionDescriptionStyle,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _maxHpController,
                                      keyboardType: TextInputType.number,
                                      style: stitchCodexFieldTextStyle,
                                      decoration: _inputDecoration("Max HP"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _currentHpController,
                                      keyboardType: TextInputType.number,
                                      style: stitchCodexFieldTextStyle,
                                      decoration:
                                          _inputDecoration("Current HP"),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _acController,
                                      keyboardType: TextInputType.number,
                                      style: stitchCodexFieldTextStyle,
                                      decoration:
                                          _inputDecoration("Armor Class"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _speedController,
                                      keyboardType: TextInputType.number,
                                      style: stitchCodexFieldTextStyle,
                                      decoration: _inputDecoration("Speed"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: stitchCodexPrimaryButtonStyle(),
                            onPressed: _saveChanges,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text(
                              'Save Changes',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
