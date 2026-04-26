import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dnd_class.dart';
import '../services/class_data_service.dart';
import '../providers/character_provider.dart';
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
  DndClass? dndClass;
  bool loading = true;
  ImageProvider? classImage;

  @override
  void initState() {
    super.initState();
    _loadClass();
  }

  Future<void> _loadClass() async {
    final cls = await ClassDataService.loadClass(widget.classIndex);
    final img = await _loadLocalImage(cls?.name ?? widget.classIndex);

    setState(() {
      dndClass = cls;
      classImage = img;
      loading = false;
    });
  }

  Future<ImageProvider?> _loadLocalImage(String className) async {
    final fileName = className.toLowerCase();
    final path = "assets/images/classes/$fileName.png";

    try {
      await rootBundle.load(path);
      return AssetImage(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    final c = dndClass;

    if (c == null) {
      return const Scaffold(
        body: Center(
          child: Text("Class not found", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 52, 1, 1),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(c.name, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _classCard(c),
            const SizedBox(height: 24),
            _infoGrid(c),
            const SizedBox(height: 24),
            _accordion(
              title: "Saving Throws",
              content: Text(
                c.savingThrows.join(", "),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            _accordion(
              title: "General Proficiencies",
              content: Text(
                c.proficiencies.join(", "),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            _accordion(
              title: "Skill Choices",
              content: _skillChoiceContent(c),
            ),
            _accordion(
              title: "Starting Equipment",
              content: Text(
                c.startingEquipment.join("\n"),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            _accordion(
              title: "Subclasses",
              content: Text(
                c.subclasses.map((s) => s.name).join(", "),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (c.spellcastingAbility != null)
              _accordion(
                title: "Spellcasting",
                content: Text(
                  "Casting Ability: ${c.spellcastingAbility!}",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 108, 0, 5),
                ),
                onPressed: () {
                  context.read<CharacterProvider>().update((ch) {
                    ch.setPrimaryClassProgression(className: c.name);
                    ch.savingThrows = List<String>.from(c.savingThrows);
                  });

                  context.go('/select-level');
                },
                child: const Text("Seleccionar esta clase"),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassProgressionScreen(cls: c),
                    ),
                  );
                },
                child: const Text("View Level Progression"),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _classCard(DndClass c) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromARGB(255, 63, 1, 1)),
        color: const Color(0xFF3B2525),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: classImage != null
                  ? DecorationImage(
                      image: classImage!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    )
                  : null,
              color: Colors.black26,
            ),
            child: classImage == null
                ? const Center(
                    child:
                        Icon(Icons.menu_book, color: Colors.white38, size: 70),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            c.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoGrid(DndClass c) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _infoRow("Hit Die", "d${c.hitDie}"),
          _divider(),
          _infoRow("Spellcasting Ability", c.spellcastingAbility ?? "None"),
          _divider(),
          _infoRow("Subclasses", c.subclasses.map((s) => s.name).join(", ")),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          SizedBox(
            width: 180,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(color: Colors.white24, height: 1);

  Widget _accordion({required String title, required Widget content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF3B2525),
      ),
      child: ExpansionTile(
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _skillChoiceContent(DndClass c) {
    if (c.skillChoices.isEmpty) {
      return const Text("None", style: TextStyle(color: Colors.white70));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: c.skillChoices
          .map(
            (choice) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "Choose ${choice.choose}: ${choice.from.join(", ")}",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(),
    );
  }
}
