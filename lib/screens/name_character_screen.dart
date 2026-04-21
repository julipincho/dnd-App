import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';

class NameCharacterScreen extends StatefulWidget {
  const NameCharacterScreen({super.key});

  @override
  State<NameCharacterScreen> createState() => _NameCharacterScreenState();
}

class _NameCharacterScreenState extends State<NameCharacterScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;

  File? _portrait;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _portrait = File(picked.path);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final char = context.read<CharacterProvider>().character;

    // Si por alguna razón se abre sin personaje → no crashea
    if (char == null) return;

    _controller.text = char.name;

    if (char.portraitPath != null && File(char.portraitPath!).existsSync()) {
      _portrait = File(char.portraitPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final char = provider.character;

    if (char == null) {
      return const Scaffold(
        body: Center(
          child:
              Text("No character loaded", style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        title: const Text("Name Your Character"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose a name for your hero",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // -------------------------------
            // PORTRAIT PICKER
            // -------------------------------
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 52,
                  backgroundImage:
                      _portrait != null ? FileImage(_portrait!) : null,
                  backgroundColor: Colors.grey.shade800,
                  child: _portrait == null
                      ? const Icon(Icons.camera_alt,
                          color: Colors.white, size: 32)
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // -------------------------------
            // NAME FIELD
            // -------------------------------
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Character Name",
                labelStyle: const TextStyle(color: Colors.white70),
                errorText: _errorMessage,
                filled: true,
                fillColor: const Color(0xFF2A2A31),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurpleAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Colors.deepPurple, width: 2),
                ),
              ),
            ),

            const Spacer(),

            // -------------------------------
            // CONTINUE BUTTON
            // -------------------------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = _controller.text.trim();

                  if (name.length < 3) {
                    setState(() =>
                        _errorMessage = "Name must be at least 3 characters");
                    return;
                  }

                  // ACTUALIZA el personaje vivo en el Provider
                  provider.update((ch) {
                    ch.name = name;
                    ch.portraitPath = _portrait?.path;
                  });

                  context.go('/summary'); // ya no enviamos Character por extra
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
