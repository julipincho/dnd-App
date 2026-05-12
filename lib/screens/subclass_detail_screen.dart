import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/class_data_service.dart';
import '../models/subclass_progress_feature.dart';
import '../providers/character_provider.dart';

class SubclassDetailScreen extends StatefulWidget {
  final String classIndex;
  final String subclassName;

  const SubclassDetailScreen({
    super.key,
    required this.classIndex,
    required this.subclassName,
  });

  @override
  State<SubclassDetailScreen> createState() => _SubclassDetailScreenState();
}

class _SubclassDetailScreenState extends State<SubclassDetailScreen> {
  bool _loading = true;
  Map<int, List<SubclassProgressFeature>> _progression = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ClassDataService.loadSubclassProgression(
      widget.classIndex,
      widget.subclassName,
    );

    setState(() {
      _progression = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2B1A1A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final levels = _progression.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFF2B1A1A),
      appBar: StitchAppBar(
        backgroundColor: const Color(0xFF3C2A2A),
        title: Text(widget.subclassName),
        centerTitle: true,
      ),
      body: levels.isEmpty
          ? _noData()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: levels.length,
              itemBuilder: (_, i) {
                final lvl = levels[i];
                final feats = _progression[lvl]!;

                return _levelBlock(lvl, feats);
              },
            ),

      // * BOTON CONTINUAR
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orangeAccent,
        onPressed: () {
          context.read<CharacterProvider>().setSubclass(widget.subclassName);
          context.go('/select-background');
        },
        label: const Text(
          "Continuar",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _noData() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          "No subclass progression data available.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }

  Widget _levelBlock(int level, List<SubclassProgressFeature> features) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B2525),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Level $level",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map(_featureBlock),
        ],
      ),
    );
  }

  Widget _featureBlock(SubclassProgressFeature feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feature.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            feature.description.isNotEmpty
                ? feature.description
                : "No description available.",
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
