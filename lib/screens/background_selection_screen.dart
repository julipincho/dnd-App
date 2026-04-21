import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/dnd_background.dart';
import '../services/dnd_data_service.dart';

class BackgroundSelectionScreen extends StatefulWidget {
  const BackgroundSelectionScreen({super.key});

  @override
  State<BackgroundSelectionScreen> createState() =>
      _BackgroundSelectionScreenState();
}

class _BackgroundSelectionScreenState extends State<BackgroundSelectionScreen> {
  List<DndBackground> _backgrounds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBackgrounds();
  }

  Future<void> _loadBackgrounds() async {
    final list = await DndDataService.getBackgrounds();

    setState(() {
      _backgrounds = list;
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

    return Scaffold(
      backgroundColor: const Color(0xFF2B1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3C2A2A),
        title: const Text('Choose Background'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _backgrounds.length,
        itemBuilder: (context, index) {
          final bg = _backgrounds[index];
          return _backgroundCard(context, bg);
        },
      ),
    );
  }

  Widget _backgroundCard(BuildContext context, DndBackground bg) {
    final hasFeature = bg.featureName.isNotEmpty;
    final hasDescription = bg.featureDescription.isNotEmpty;

    return GestureDetector(
      onTap: () {
        context.push(
          '/background-detail',
          extra: bg,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF3B2525),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre
            Text(
              bg.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            if (hasFeature) ...[
              const SizedBox(height: 6),
              Text(
                bg.featureName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orangeAccent,
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Descripción breve
            Text(
              hasDescription
                  ? bg.featureDescription.first
                  : 'No description available.',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
