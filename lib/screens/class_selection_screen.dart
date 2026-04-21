import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dnd_class.dart';
import '../services/class_data_service.dart';
import '../providers/character_provider.dart';

class ClassSelectionScreen extends StatefulWidget {
  const ClassSelectionScreen({super.key});

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  List<DndClass> _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final list = await ClassDataService.loadAllClasses();
    list.sort((a, b) => a.name.compareTo(b.name));

    setState(() {
      _classes = list;
      _loading = false;
    });

    print("=== CLASSES LOADED ===");
    for (final c in list) print("• ${c.name}");
  }

  IconData _iconForClass(String name) {
    switch (name) {
      case 'Artificer':
        return Icons.science;
      case 'Barbarian':
        return Icons.fitness_center;
      case 'Bard':
        return Icons.music_note;
      case 'Cleric':
        return Icons.healing;
      case 'Druid':
        return Icons.eco;
      case 'Fighter':
        return Icons.shield;
      case 'Monk':
        return Icons.self_improvement;
      case 'Paladin':
        return Icons.auto_fix_high;
      case 'Ranger':
        return Icons.nature;
      case 'Rogue':
        return Icons.visibility_off;
      case 'Sorcerer':
        return Icons.flash_on;
      case 'Warlock':
        return Icons.nights_stay;
      case 'Wizard':
        return Icons.book;
    }
    return Icons.star;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Choose Class")),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _classes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final c = _classes[i];

          return GestureDetector(
            onTap: () async {
              final selected = await context.push<String>(
                '/class-detail',
                extra: c.index,
              );

              if (selected == null) return;

              final full = await ClassDataService.loadClass(selected);
              if (full == null) return;

              context.read<CharacterProvider>().update((ch) {
                ch.charClass = full.name;
                ch.savingThrows = List<String>.from(full.savingThrows);
                ch.classSkills = [];
              });

              context.go('/background-alignment');
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurpleAccent),
              ),
              child: Row(
                children: [
                  Icon(_iconForClass(c.name), size: 32, color: Colors.white),
                  const SizedBox(width: 16),
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
