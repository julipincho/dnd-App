import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/character_provider.dart';
import '../theme.dart';
import '../utils/image_path_utils.dart';
import '../widgets/stitch_codex_ui.dart';

class NameCharacterScreen extends StatefulWidget {
  const NameCharacterScreen({super.key});

  @override
  State<NameCharacterScreen> createState() => _NameCharacterScreenState();
}

class _NameCharacterScreenState extends State<NameCharacterScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;
  Uint8List? _portraitBytes;

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted || bytes.isEmpty) return;

      context.read<CharacterProvider>().setDraftPortrait(
        bytes: bytes,
        fileName: picked.name,
      );
      setState(() {
        _portraitBytes = bytes;
      });
    } catch (error) {
      debugPrint('Error selecting character portrait: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The portrait could not be opened. Try another image.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final char = context.read<CharacterProvider>().character;

    // Si por alguna razon se abre sin personaje -> no crashea
    if (char == null) return;

    _controller.text = char.name;
    final provider = context.read<CharacterProvider>();
    _portraitBytes = provider.draftPortraitBytes;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CharacterProvider>();
    final char = provider.character;

    if (char == null) {
      return const Scaffold(
        backgroundColor: StitchCodexPalette.ground,
        body: StitchCodexBackground(
          child: Center(
            child: Text(
              'No character loaded',
              style: TextStyle(
                color: StitchCodexPalette.crimsonBright,
                fontFamily: StitchTypography.body,
              ),
            ),
          ),
        ),
      );
    }

    final savedPortraitPath = char.portraitPath;
    final ImageProvider? portraitImage = _portraitBytes != null
        ? MemoryImage(_portraitBytes!)
        : hasDisplayableImagePath(savedPortraitPath)
            ? imageProviderFromPath(savedPortraitPath!)
            : null;

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'NAME YOUR CHARACTER',
          style: TextStyle(
            color: StitchCodexPalette.textPrimary,
            fontFamily: StitchTypography.display,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: StitchCodexBackground(
        child: SingleChildScrollView(
          child: StitchCodexContentWidth(
            maxWidth: 620,
            child: StitchCodexPanel(
              emphasized: true,
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StitchCodexPageHeader(
                    eyebrow: 'FINAL STEP · IDENTITY',
                    title: 'Name your hero',
                    subtitle:
                        'Give the character a face and the name the table will remember.',
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 118,
                        height: 138,
                        decoration: BoxDecoration(
                          color: StitchCodexPalette.surface,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: StitchCodexPalette.bronze
                                .withValues(alpha: 0.46),
                          ),
                          image: portraitImage != null
                              ? DecorationImage(
                                  image: portraitImage,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                )
                              : null,
                        ),
                        child: portraitImage == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: StitchCodexPalette.bronze,
                                    size: 30,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'ADD PORTRAIT',
                                    style: TextStyle(
                                      color: StitchCodexPalette.textMuted,
                                      fontFamily: StitchTypography.data,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    style: stitchCodexFieldTextStyle,
                    cursorColor: StitchCodexPalette.bronze,
                    decoration: stitchCodexInputDecoration(
                      labelText: 'Character name',
                      hintText: 'The name written in legend',
                      prefixIcon: Icons.edit_outlined,
                    ).copyWith(errorText: _errorMessage),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final name = _controller.text.trim();

                        if (name.length < 3) {
                          setState(() => _errorMessage =
                              'Name must be at least 3 characters');
                          return;
                        }

                        provider.update((ch) {
                          ch.name = name;
                        });

                        context.go('/summary');
                      },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Continue'),
                      style: stitchCodexPrimaryButtonStyle(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
