import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../utils/image_path_utils.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().userId;
      if (userId == null) return;

      context.read<CharacterProvider>().loadCharacters(userId);
    });
  }

  Future<bool> _confirmDelete(BuildContext context, Character c) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E22),
            title: const Text(
              "Delete Character",
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              "Are you sure you want to delete '${c.name}'?",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final characters = provider.characters;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        elevation: 4,
        title: const Text(
          "My Characters & Campaigns",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final userId = context.read<AuthProvider>().userId;
          if (userId == null) return;

          await provider.loadCharacters(userId);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Create New Character",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                onPressed: () {
                  provider.startNewCharacter(
                    campaignId: null,
                    source: CharacterCreationSource.home,
                  );
                  context.go('/welcome');
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Your Characters",
              style: TextStyle(
                fontSize: 20,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (characters.isEmpty)
              const Text(
                "No characters yet. Create one!",
                style: TextStyle(color: Colors.white70),
              ),
            ...characters.map(
              (character) => _characterCard(context, provider, character),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _characterCard(
    BuildContext context,
    CharacterProvider provider,
    Character c,
  ) {
    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) => _confirmDelete(context, c),
      onDismissed: (_) async {
        await provider.deleteCharacterById(c.id);
      },
      child: GestureDetector(
        onTap: () {
          context.push('/character/${c.id}');
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A31),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.deepPurpleAccent.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.deepPurpleAccent,
                backgroundImage: hasDisplayableImagePath(c.portraitPath)
                    ? imageProviderFromPath(c.portraitPath!)
                    : null,
                child: !hasDisplayableImagePath(c.portraitPath)
                    ? const Icon(Icons.person, size: 32, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name.isEmpty ? 'Unnamed Character' : c.name,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${c.race} ${c.charClass} · Level ${c.level}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
