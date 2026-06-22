import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../models/dnd_class.dart';
import '../providers/character_provider.dart';
import '../services/character_level_up_service.dart';
import '../services/character_multiclass_proficiency_service.dart';
import '../services/character_spell_slot_service.dart';
import '../services/class_data_service.dart';
import '../services/dnd_data_service.dart';
import '../services/multiclass_rules_service.dart';
import '../services/multiclass_spellcasting_service.dart';

class LevelUpScreen extends StatefulWidget {
  final String characterId;

  const LevelUpScreen({
    super.key,
    required this.characterId,
  });

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  bool _loading = true;
  bool _saving = false;
  List<DndClass> _classes = [];
  DndClass? _selectedClass;
  DndSubclass? _selectedSubclass;
  int? _subclassChoiceLevel;
  List<Map<String, String>> _levelFeatures = [];
  String _hpMethod = 'average';
  int _hpGain = 1;
  bool _rollLocked = false;
  String? _selectedMulticlassSkill;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final character = context.read<CharacterProvider>().getCharacterById(
          widget.characterId,
        );
    if (character == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final classes = await DndDataService.getAllClasses();
    if (!mounted) return;

    final selected = classes.firstWhere(
      (cls) => cls.name.toLowerCase() == character.charClass.toLowerCase(),
      orElse: () => classes.first,
    );

    setState(() {
      _classes = classes;
      _selectedClass = selected;
      _hpGain = _averageHpGain(character, selected.hitDie);
      _loading = false;
    });

    await _loadSelectedClassDetails(character);
  }

  Future<void> _loadSelectedClassDetails(Character character) async {
    final selectedClass = _selectedClass;
    if (selectedClass == null) return;

    final nextClassLevel = character.levelForClass(selectedClass.name) + 1;
    final subclassChoiceLevel =
        await ClassDataService.getSubclassChoiceLevel(selectedClass.name);
    final features = await ClassDataService.getClassLevelFeatures(
      classIndex: selectedClass.name,
      level: nextClassLevel,
    );

    if (!mounted) return;
    setState(() {
      _subclassChoiceLevel = subclassChoiceLevel;
      _levelFeatures = features;
      final needsSubclass = _needsSubclassChoice(character);
      if (!needsSubclass) {
        _selectedSubclass = null;
      } else if (_selectedSubclass == null &&
          selectedClass.subclasses.isNotEmpty) {
        _selectedSubclass = selectedClass.subclasses.first;
      }
    });
  }

  Character? _character(BuildContext context) {
    return context.watch<CharacterProvider>().getCharacterById(
          widget.characterId,
        );
  }

  bool _needsSubclassChoice(Character character) {
    final selectedClass = _selectedClass;
    final subclassChoiceLevel = _subclassChoiceLevel;
    if (selectedClass == null || subclassChoiceLevel == null) return false;
    if (character.subclassForClass(selectedClass.name) != null) return false;
    final nextClassLevel = character.levelForClass(selectedClass.name) + 1;
    return nextClassLevel >= subclassChoiceLevel &&
        selectedClass.subclasses.isNotEmpty;
  }

  bool _needsMulticlassSkillChoice(Character character) {
    final selectedClass = _selectedClass;
    if (selectedClass == null) return false;
    if (character.levelForClass(selectedClass.name) > 0) return false;
    return _availableMulticlassSkillOptions(character).isNotEmpty;
  }

  List<String> _availableMulticlassSkillOptions(Character character) {
    final selectedClass = _selectedClass;
    if (selectedClass == null) return const [];

    final ownedSkills = character.classSkills
        .map((skill) => skill.trim().toLowerCase())
        .toSet();

    return CharacterMulticlassProficiencyService.multiclassSkillOptionsForClass(
            selectedClass.name)
        .where((skill) => !ownedSkills.contains(skill.trim().toLowerCase()))
        .toList();
  }

  int _effectiveConScore(Character character) {
    return (character.stats['CON'] ?? 10) +
        (character.racialBonuses['CON'] ?? 0) +
        (character.featAbilityBonuses['CON'] ?? 0);
  }

  int _conModifier(Character character) {
    return ((_effectiveConScore(character) - 10) / 2).floor();
  }

  int _averageHpGain(Character character, int hitDie) {
    final hpGain = ((hitDie / 2).floor() + 1) + _conModifier(character);
    return hpGain < 1 ? 1 : hpGain;
  }

  int _rollHpGain(Character character, int hitDie) {
    final rolledValue = 1 + (DateTime.now().microsecondsSinceEpoch % hitDie);
    final hpGain = rolledValue + _conModifier(character);
    return hpGain < 1 ? 1 : hpGain;
  }

  Future<void> _selectClass(Character character, DndClass cls) async {
    setState(() {
      _selectedClass = cls;
      _selectedSubclass = null;
      _selectedMulticlassSkill = null;
      _hpMethod = 'average';
      _rollLocked = false;
      _hpGain = _averageHpGain(character, cls.hitDie);
      _levelFeatures = [];
    });
    await _loadSelectedClassDetails(character);
  }

  Future<void> _confirm(Character character) async {
    final selectedClass = _selectedClass;
    if (selectedClass == null || _saving) return;

    if (_needsSubclassChoice(character) && _selectedSubclass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a subclass to continue.')),
      );
      return;
    }

    if (_needsMulticlassSkillChoice(character) &&
        _selectedMulticlassSkill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a multiclass skill proficiency.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final provider = context.read<CharacterProvider>();
      await provider.updateCharacterById(character.id, (ch) {
        CharacterLevelUpService.applyLevelUp(
          character: ch,
          decision: CharacterLevelUpDecision(
            className: selectedClass.name,
            subclassName: _selectedSubclass?.name,
            hpGain: _hpGain,
            hitDie: selectedClass.hitDie,
            skillProficiencies: [
              if (_selectedMulticlassSkill != null) _selectedMulticlassSkill!,
            ],
          ),
        );
      });

      await provider.syncFeaturesAndResources(character.id);

      final updated = provider.getCharacterById(character.id);
      if (updated != null &&
          MulticlassSpellcastingService.hasAutoSlots(updated)) {
        await provider.updateCharacterById(character.id, (ch) {
          CharacterSpellSlotService.applyAutoSlotState(
            ch,
            preserveUsed: true,
          );
        });
      }

      if (!mounted) return;
      context.pop();
    } catch (error, stackTrace) {
      debugPrint('Error applying character level up: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The level could not be applied. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final character = _character(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0E13),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (character == null || _classes.isEmpty || _selectedClass == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0E13),
        appBar: StitchAppBar(title: const Text('Level Up')),
        body: const Center(
          child: Text('Character or class data unavailable.'),
        ),
      );
    }

    final selectedClass = _selectedClass!;
    final currentClassLevel = character.levelForClass(selectedClass.name);
    final nextClassLevel = currentClassLevel + 1;
    final nextTotalLevel = character.level + 1;
    final isNewClass = currentClassLevel == 0;
    final validation = MulticlassRulesService.validateEntry(
      character: character,
      targetClassName: selectedClass.name,
    );
    final needsSubclass = _needsSubclassChoice(character);
    final needsMulticlassSkill = _needsMulticlassSkillChoice(character);
    final canConfirm = (!isNewClass || validation.canMulticlass) &&
        (!needsSubclass || _selectedSubclass != null) &&
        (!needsMulticlassSkill || _selectedMulticlassSkill != null);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E13),
      appBar: StitchAppBar(
        backgroundColor: const Color(0xFF101117),
        elevation: 0,
        title: const Text(
          'Level Up',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      bottomNavigationBar: _LevelUpActionBar(
        canConfirm: canConfirm,
        saving: _saving,
        className: selectedClass.name,
        nextClassLevel: nextClassLevel,
        onConfirm: () => _confirm(character),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;
          final pagePadding = isWide ? 28.0 : 16.0;

          final mainContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroSummary(
                character: character,
                selectedClass: selectedClass,
                nextClassLevel: nextClassLevel,
                nextTotalLevel: nextTotalLevel,
                hpGain: _hpGain,
                isNewClass: isNewClass,
              ),
              const SizedBox(height: 14),
              _ClassAdvancePanel(
                character: character,
                classes: _classes,
                selectedClass: selectedClass,
                validation: validation,
                onSelectClass: (cls) => _selectClass(character, cls),
                saving: _saving,
              ),
              const SizedBox(height: 14),
              _HpDecisionPanel(
                character: character,
                selectedClass: selectedClass,
                hpMethod: _hpMethod,
                hpGain: _hpGain,
                rollLocked: _rollLocked,
                averageHpGain: _averageHpGain(
                  character,
                  selectedClass.hitDie,
                ),
                conModifier: _conModifier(character),
                onTakeAverage: _rollLocked
                    ? null
                    : () {
                        setState(() {
                          _hpMethod = 'average';
                          _hpGain = _averageHpGain(
                            character,
                            selectedClass.hitDie,
                          );
                        });
                      },
                onRoll: _rollLocked
                    ? null
                    : () {
                        setState(() {
                          _hpMethod = 'roll';
                          _hpGain = _rollHpGain(
                            character,
                            selectedClass.hitDie,
                          );
                          _rollLocked = true;
                        });
                      },
              ),
              if (needsSubclass) ...[
                const SizedBox(height: 14),
                _SubclassPanel(
                  selectedClass: selectedClass,
                  selectedSubclass: _selectedSubclass,
                  subclassChoiceLevel: _subclassChoiceLevel,
                  onChanged: (subclass) {
                    setState(() => _selectedSubclass = subclass);
                  },
                ),
              ],
              if (needsMulticlassSkill) ...[
                const SizedBox(height: 14),
                _MulticlassSkillPanel(
                  className: selectedClass.name,
                  options: _availableMulticlassSkillOptions(character),
                  selectedSkill: _selectedMulticlassSkill,
                  onChanged: (skill) {
                    setState(() => _selectedMulticlassSkill = skill);
                  },
                ),
              ],
            ],
          );

          final sideContent = Column(
            children: [
              _LevelGainsPanel(
                selectedClass: selectedClass,
                nextClassLevel: nextClassLevel,
                hpGain: _hpGain,
                features: _levelFeatures,
                needsSubclass: needsSubclass,
                selectedSubclass: _selectedSubclass,
                selectedMulticlassSkill: _selectedMulticlassSkill,
              ),
              const SizedBox(height: 14),
              _ProgressionPanel(character: character),
            ],
          );

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              pagePadding,
              pagePadding,
              pagePadding,
              pagePadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: mainContent),
                          const SizedBox(width: 16),
                          SizedBox(width: 370, child: sideContent),
                        ],
                      )
                    : Column(
                        children: [
                          mainContent,
                          const SizedBox(height: 14),
                          sideContent,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LevelUpActionBar extends StatelessWidget {
  final bool canConfirm;
  final bool saving;
  final String className;
  final int nextClassLevel;
  final VoidCallback onConfirm;

  const _LevelUpActionBar({
    required this.canConfirm,
    required this.saving,
    required this.className,
    required this.nextClassLevel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101117),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canConfirm && !saving ? onConfirm : null,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                  label: Text(
                    saving
                        ? 'Applying...'
                        : 'Confirm $className $nextClassLevel',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE14658),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.10),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final Character character;
  final DndClass selectedClass;
  final int nextClassLevel;
  final int nextTotalLevel;
  final int hpGain;
  final bool isNewClass;

  const _HeroSummary({
    required this.character,
    required this.selectedClass,
    required this.nextClassLevel,
    required this.nextTotalLevel,
    required this.hpGain,
    required this.isNewClass,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = _classImagePath(selectedClass.name);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF171923),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF171923),
                    const Color(0xFF171923).withValues(alpha: 0.92),
                    const Color(0xFF171923).withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaPill(
                  label: isNewClass ? 'MULTICLASS' : 'CLASS ADVANCEMENT',
                  color:
                      isNewClass ? Colors.lightBlueAccent : Colors.greenAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  character.name.isEmpty ? 'Unnamed Character' : character.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${character.classProgressionLabel} -> ${selectedClass.name} $nextClassLevel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroMetric(
                      label: 'Total Level',
                      value: '$nextTotalLevel',
                      icon: Icons.stars_outlined,
                    ),
                    _HeroMetric(
                      label: 'Class Level',
                      value: '$nextClassLevel',
                      icon: Icons.military_tech_outlined,
                    ),
                    _HeroMetric(
                      label: 'Hit Die',
                      value: 'd${selectedClass.hitDie}',
                      icon: Icons.casino_outlined,
                    ),
                    _HeroMetric(
                      label: 'HP Gain',
                      value: '+$hpGain',
                      icon: Icons.favorite_border,
                    ),
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

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _ClassAdvancePanel extends StatelessWidget {
  final Character character;
  final List<DndClass> classes;
  final DndClass selectedClass;
  final MulticlassValidationResult validation;
  final ValueChanged<DndClass> onSelectClass;
  final bool saving;

  const _ClassAdvancePanel({
    required this.character,
    required this.classes,
    required this.selectedClass,
    required this.validation,
    required this.onSelectClass,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Choose Advancement',
      subtitle: 'Advance an existing class or enter a new one.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 154,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: classes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final cls = classes[index];
                final currentLevel = character.levelForClass(cls.name);
                final isSelected = cls.name == selectedClass.name;
                final validation = MulticlassRulesService.validateEntry(
                  character: character,
                  targetClassName: cls.name,
                );
                final isLocked = currentLevel == 0 && !validation.canMulticlass;

                return _ClassChoiceCard(
                  cls: cls,
                  currentLevel: currentLevel,
                  isSelected: isSelected,
                  isLocked: isLocked,
                  onTap: saving ? null : () => onSelectClass(cls),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (character.levelForClass(selectedClass.name) == 0)
            _RequirementBanner(validation: validation)
          else
            _InlineInfo(
              icon: Icons.check_circle_outline,
              color: Colors.greenAccent,
              text:
                  'Continuing ${selectedClass.name}. Multiclass requirements are not needed.',
            ),
        ],
      ),
    );
  }
}

class _ClassChoiceCard extends StatelessWidget {
  final DndClass cls;
  final int currentLevel;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback? onTap;

  const _ClassChoiceCard({
    required this.cls,
    required this.currentLevel,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = _classImagePath(cls.name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          width: 162,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1C25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFE14658)
                  : Colors.white.withValues(alpha: 0.10),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF20232C),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.84),
                      ],
                    ),
                  ),
                ),
                if (isLocked)
                  ColoredBox(color: Colors.black.withValues(alpha: 0.46)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isLocked)
                            const Icon(
                              Icons.lock_outline,
                              color: Colors.white70,
                              size: 16,
                            )
                          else if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFFE14658),
                              size: 16,
                            ),
                          const Spacer(),
                          _TinyPill(
                            text: currentLevel > 0 ? 'LV $currentLevel' : 'NEW',
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        cls.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Next: ${cls.name} ${currentLevel + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _HpDecisionPanel extends StatelessWidget {
  final Character character;
  final DndClass selectedClass;
  final String hpMethod;
  final int hpGain;
  final bool rollLocked;
  final int averageHpGain;
  final int conModifier;
  final VoidCallback? onTakeAverage;
  final VoidCallback? onRoll;

  const _HpDecisionPanel({
    required this.character,
    required this.selectedClass,
    required this.hpMethod,
    required this.hpGain,
    required this.rollLocked,
    required this.averageHpGain,
    required this.conModifier,
    required this.onTakeAverage,
    required this.onRoll,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Hit Points',
      subtitle: 'Choose how this level increases survivability.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _HpMethodCard(
                  title: 'Take Average',
                  detail: 'd${selectedClass.hitDie} average + CON',
                  value: '+$averageHpGain',
                  selected: hpMethod == 'average',
                  locked: rollLocked,
                  onTap: onTakeAverage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HpMethodCard(
                  title: rollLocked ? 'Rolled Result' : 'Roll Once',
                  detail:
                      'd${selectedClass.hitDie} + CON ${_signed(conModifier)}',
                  value: '+$hpGain',
                  selected: hpMethod == 'roll',
                  locked: rollLocked && hpMethod != 'roll',
                  onTap: onRoll,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InlineInfo(
            icon: Icons.favorite_border,
            color: Colors.redAccent,
            text:
                'HP will become ${(character.maxHp ?? 0) + hpGain} max / ${(character.currentHp ?? 0) + hpGain} current.',
          ),
        ],
      ),
    );
  }
}

class _HpMethodCard extends StatelessWidget {
  final String title;
  final String detail;
  final String value;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  const _HpMethodCard({
    required this.title,
    required this.detail,
    required this.value,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: locked ? null : onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE14658).withValues(alpha: 0.14)
                : const Color(0xFF20232C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE14658)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubclassPanel extends StatelessWidget {
  final DndClass selectedClass;
  final DndSubclass? selectedSubclass;
  final int? subclassChoiceLevel;
  final ValueChanged<DndSubclass> onChanged;

  const _SubclassPanel({
    required this.selectedClass,
    required this.selectedSubclass,
    required this.subclassChoiceLevel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Subclass Choice',
      subtitle:
          'This class chooses a subclass at level ${subclassChoiceLevel ?? '?'}',
      child: Column(
        children: [
          for (final subclass in selectedClass.subclasses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SubclassCard(
                subclass: subclass,
                selected: selectedSubclass?.name == subclass.name,
                onTap: () => onChanged(subclass),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubclassCard extends StatelessWidget {
  final DndSubclass subclass;
  final bool selected;
  final VoidCallback onTap;

  const _SubclassCard({
    required this.subclass,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? Colors.lightBlueAccent.withValues(alpha: 0.13)
                : const Color(0xFF20232C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? Colors.lightBlueAccent
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.circle_outlined,
                color: selected ? Colors.lightBlueAccent : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subclass.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if ((subclass.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subclass.description!.trim(),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          height: 1.35,
                        ),
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
  }
}

class _MulticlassSkillPanel extends StatelessWidget {
  final String className;
  final List<String> options;
  final String? selectedSkill;
  final ValueChanged<String> onChanged;

  const _MulticlassSkillPanel({
    required this.className,
    required this.options,
    required this.selectedSkill,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Multiclass Proficiency',
      subtitle: '$className grants one extra skill when entered this way.',
      child: options.isEmpty
          ? Text(
              'No eligible skill proficiencies remain for $className.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in options)
                  ChoiceChip(
                    label: Text(skill),
                    selected: selectedSkill == skill,
                    onSelected: (_) => onChanged(skill),
                  ),
              ],
            ),
    );
  }
}

class _LevelGainsPanel extends StatelessWidget {
  final DndClass selectedClass;
  final int nextClassLevel;
  final int hpGain;
  final List<Map<String, String>> features;
  final bool needsSubclass;
  final DndSubclass? selectedSubclass;
  final String? selectedMulticlassSkill;

  const _LevelGainsPanel({
    required this.selectedClass,
    required this.nextClassLevel,
    required this.hpGain,
    required this.features,
    required this.needsSubclass,
    required this.selectedSubclass,
    required this.selectedMulticlassSkill,
  });

  @override
  Widget build(BuildContext context) {
    final gains = <_GainItem>[
      _GainItem(
        icon: Icons.favorite_border,
        title: 'Hit Points',
        detail: '+$hpGain HP',
        color: Colors.redAccent,
      ),
      if (needsSubclass && selectedSubclass != null)
        _GainItem(
          icon: Icons.account_tree_outlined,
          title: 'Subclass',
          detail: selectedSubclass!.name,
          color: Colors.lightBlueAccent,
        ),
      if (selectedMulticlassSkill != null)
        _GainItem(
          icon: Icons.psychology_alt_outlined,
          title: 'Skill Proficiency',
          detail: selectedMulticlassSkill!,
          color: Colors.greenAccent,
        ),
      for (final feature in features)
        _GainItem(
          icon: Icons.auto_awesome_outlined,
          title: feature['name'] ?? 'Feature',
          detail: (feature['description'] ?? '').trim().isEmpty
              ? 'Unlocked at this level.'
              : feature['description']!.trim(),
          color: const Color(0xFFE14658),
        ),
    ];

    return _SectionPanel(
      title: '${selectedClass.name} $nextClassLevel Gains',
      subtitle: 'Preview what will be applied after confirmation.',
      child: gains.isEmpty
          ? Text(
              'No class features listed for this level in the current dataset.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
            )
          : Column(
              children: [
                for (final gain in gains)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GainRow(gain: gain),
                  ),
              ],
            ),
    );
  }
}

class _GainItem {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  const _GainItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });
}

class _GainRow extends StatelessWidget {
  final _GainItem gain;

  const _GainRow({
    required this.gain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF20232C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: gain.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gain.color.withValues(alpha: 0.26)),
            ),
            child: Icon(gain.icon, color: gain.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gain.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  gain.detail,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _ProgressionPanel extends StatelessWidget {
  final Character character;

  const _ProgressionPanel({
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    final entries = character.classLevels.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return _SectionPanel(
      title: 'Current Progression',
      subtitle: 'Snapshot before this level is applied.',
      child: entries.isEmpty
          ? Text(
              character.classProgressionLabel,
              style: const TextStyle(color: Colors.white),
            )
          : Column(
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _TinyPill(text: 'Level ${entry.value}'),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionPanel({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171923),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RequirementBanner extends StatelessWidget {
  final MulticlassValidationResult validation;

  const _RequirementBanner({required this.validation});

  @override
  Widget build(BuildContext context) {
    final ok = validation.canMulticlass;
    return _InlineInfo(
      icon: ok ? Icons.check_circle_outline : Icons.lock_outline,
      color: ok ? Colors.greenAccent : Colors.redAccent,
      text: ok
          ? 'Requirements met: ${validation.requirementsLabel}'
          : 'Missing: ${validation.unmetRequirements.join(', ')}',
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InlineInfo({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.3,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String text;

  const _TinyPill({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

String _classImagePath(String className) {
  final slug = className.trim().toLowerCase().replaceAll(' ', '-');
  return 'assets/images/classes/$slug.png';
}

String _signed(int value) => value >= 0 ? '+$value' : '$value';
