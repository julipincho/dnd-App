import 'package:flutter/material.dart';
import '../models/dnd_class.dart' hide DndClassLevel;
import '../models/dnd_class_level.dart';
import '../services/class_level_service.dart';

class ClassProgressionScreen extends StatefulWidget {
  final DndClass cls;

  const ClassProgressionScreen({
    super.key,
    required this.cls,
  });

  @override
  State<ClassProgressionScreen> createState() => _ClassProgressionScreenState();
}

class _ClassProgressionScreenState extends State<ClassProgressionScreen> {
  Map<int, DndClassLevel>? levels;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    final data = await ClassLevelService.loadLevelsForClass(widget.cls.index);

    setState(() {
      levels = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasLevels = levels != null && levels!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF2A1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1E1E),
        title: Text("${widget.cls.name} Progression"),
        actions: [
          if (!hasLevels)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  "5ETOOLS DATA",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : hasLevels
              ? _buildProgressionList()
              : _buildNoLevelsMessage(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orangeAccent,
        onPressed: () => Navigator.pop(context, widget.cls.index),
        label: const Text(
          "Continuar",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildNoLevelsMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.info_outline, color: Colors.orangeAccent, size: 80),
            SizedBox(height: 20),
            Text(
              "No hay progresión disponible en el SRD para esta clase.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Text(
              "Puedes continuar igualmente: la clase y subclase funcionan normalmente.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressionList() {
    final sorted = levels!.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, index) {
        final lvl = sorted[index].value;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3B2525),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Level ${lvl.level}",
                  style: const TextStyle(
                      color: Colors.orangeAccent, fontSize: 18)),
              const SizedBox(height: 8),
              Text("Proficiency Bonus: +${lvl.profBonus}",
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              _features(lvl),
              _spellcasting(lvl),
            ],
          ),
        );
      },
    );
  }

  Widget _features(DndClassLevel lvl) {
    if (lvl.features.isEmpty) {
      return const Text("No features", style: TextStyle(color: Colors.white70));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Features:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ...lvl.features.map(
          (f) => Text("• $f", style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _spellcasting(DndClassLevel lvl) {
    if (lvl.spellcasting == null) return const SizedBox.shrink();

    final s = lvl.spellcasting!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text("Spellcasting:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text("Cantrips Known: ${s.cantripsKnown}",
            style: const TextStyle(color: Colors.white70)),
        Text("Spells Known: ${s.spellsKnown}",
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        const Text("Spell Slots:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ...List.generate(9, (i) {
          final amount = s.spellSlots[i];
          if (amount == 0) return const SizedBox.shrink();
          return Text("• Level ${i + 1}: $amount slots",
              style: const TextStyle(color: Colors.white));
        }),
      ],
    );
  }
}
