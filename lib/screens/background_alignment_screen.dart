import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/dnd_data_service.dart';
import '../models/dnd_background.dart';
import '../providers/character_provider.dart';

class BackgroundAlignmentScreen extends StatefulWidget {
  const BackgroundAlignmentScreen({super.key});

  @override
  State<BackgroundAlignmentScreen> createState() =>
      _BackgroundAlignmentScreenState();
}

class _BackgroundAlignmentScreenState extends State<BackgroundAlignmentScreen> {
  List<DndBackground> backgrounds = [];
  DndBackground? selectedBackground;

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

  String selectedAlignment = "Lawful Good";

  @override
  void initState() {
    super.initState();
    _loadBackgrounds();
  }

  Future<void> _loadBackgrounds() async {
    final list = await DndDataService.getBackgrounds();
    setState(() {
      backgrounds = list;
      selectedBackground = list.isNotEmpty ? list.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final character = context.watch<CharacterProvider>().character!;
    final race = character.race;
    final charClass = character.charClass;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E22),
      appBar: StitchAppBar(
        title: Text("Background & Alignment - $race, $charClass"),
        backgroundColor: const Color(0xFF121214),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose a Background",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DndBackground>(
              value: selectedBackground,
              dropdownColor: const Color(0xFF1E1E22),
              decoration: const InputDecoration(
                labelText: "Background",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.deepPurpleAccent),
                ),
              ),
              items: backgrounds
                  .map(
                    (bg) => DropdownMenuItem(
                      value: bg,
                      child: Text(bg.name,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedBackground = val);
              },
            ),
            const SizedBox(height: 32),
            const Text(
              "Choose an Alignment",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedAlignment,
              dropdownColor: const Color(0xFF1E1E22),
              decoration: const InputDecoration(
                labelText: "Alignment",
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.deepPurpleAccent),
                ),
              ),
              items: alignments
                  .map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child:
                          Text(a, style: const TextStyle(color: Colors.white)),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedAlignment = val);
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (selectedBackground == null) return;

                  context.read<CharacterProvider>().update((c) {
                    c.background = selectedBackground!;
                    c.alignment = selectedAlignment;
                  });

                  context.go('/assign-stats');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
