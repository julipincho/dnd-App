import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/class_level_service.dart';
import '../services/class_data_service.dart';
import '../models/dnd_class_level.dart';
import '../providers/character_provider.dart';

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
      backgroundColor: const Color(0xFF1E1E22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        title: Text("Select Level - ${character?.charClass ?? ""}"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: levels.length,
              itemBuilder: (context, index) {
                final lvl = levels[index];

                return Card(
                  color: Colors.black.withOpacity(0.2),
                  margin:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: ListTile(
                    title: Text(
                      "Level ${lvl.level}",
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "Proficiency Bonus: +${lvl.profBonus}",
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 18, color: Colors.white),
                    onTap: () => _selectLevel(lvl),
                  ),
                );
              },
            ),
    );
  }
}
