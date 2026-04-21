import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/dnd_race.dart';
import '../services/dnd_data_service.dart';

class RaceSelectionScreen extends StatefulWidget {
  const RaceSelectionScreen({super.key});

  @override
  State<RaceSelectionScreen> createState() => _RaceSelectionScreenState();
}

class _RaceSelectionScreenState extends State<RaceSelectionScreen> {
  late Future<List<DndRace>> _futureRaces;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _futureRaces = DndDataService.getRaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        title: const Text(
          "Choose Race",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search race...",
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF2A2A31),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() => _search = value.toLowerCase());
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<DndRace>>(
              future: _futureRaces,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepPurpleAccent,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      "Error loading races",
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                final races = snapshot.data ?? [];

                final filtered = races.where((r) {
                  return _search.isEmpty ||
                      r.name.toLowerCase().contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      "No races found.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final race = filtered[i];
                    final desc = race.description.isNotEmpty
                        ? race.description
                        : race.alignment;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        context.push('/race-detail', extra: race);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A31),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurpleAccent),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              race.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              desc.length > 140
                                  ? "${desc.substring(0, 140)}..."
                                  : desc,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
