import 'package:flutter/material.dart';

import '../models/character.dart';
import '../utils/image_path_utils.dart';
import 'compendium_aware_text_field.dart';
import 'compendium_mention_chips.dart';

class JournalEntryDraft {
  final Character character;
  final String content;
  final String? imagePath;

  const JournalEntryDraft({
    required this.character,
    required this.content,
    this.imagePath,
  });
}

class JournalEntryComposerDialog extends StatefulWidget {
  final String title;
  final String actionLabel;
  final String campaignId;
  final List<Character> characters;
  final String? initialCharacterId;
  final String initialContent;
  final String? initialImagePath;
  final Future<String?> Function() onPickImage;
  final Future<bool> Function(JournalEntryDraft draft) onSubmit;

  const JournalEntryComposerDialog({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.campaignId,
    required this.characters,
    required this.onPickImage,
    required this.onSubmit,
    this.initialCharacterId,
    this.initialContent = '',
    this.initialImagePath,
  });

  @override
  State<JournalEntryComposerDialog> createState() =>
      _JournalEntryComposerDialogState();
}

class _JournalEntryComposerDialogState
    extends State<JournalEntryComposerDialog> {
  late final TextEditingController _contentController;
  late Character _selectedCharacter;
  String? _selectedImagePath;
  bool _showContentError = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _contentController = TextEditingController(text: widget.initialContent);
    _contentController.addListener(_handleContentChanged);
    _selectedImagePath = widget.initialImagePath;

    _selectedCharacter = widget.characters.firstWhere(
      (character) => character.id == widget.initialCharacterId,
      orElse: () => widget.characters.first,
    );
  }

  @override
  void dispose() {
    _contentController.removeListener(_handleContentChanged);
    _contentController.dispose();
    super.dispose();
  }

  void _handleContentChanged() {
    if (_showContentError && _contentController.text.trim().isNotEmpty) {
      setState(() {
        _showContentError = false;
      });
      return;
    }

    setState(() {});
  }

  Future<void> _pickImage() async {
    final imagePath = await widget.onPickImage();
    if (!mounted || imagePath == null) return;

    setState(() {
      _selectedImagePath = imagePath;
    });
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      setState(() {
        _showContentError = true;
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final saved = await widget.onSubmit(
      JournalEntryDraft(
        character: _selectedCharacter,
        content: content,
        imagePath: _selectedImagePath,
      ),
    );

    if (!mounted) return;

    if (saved) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _contentController.text.trim().isNotEmpty && !_isSaving;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CharacterAvatar(character: _selectedCharacter),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _characterName(_selectedCharacter),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<Character>(
                      value: _selectedCharacter,
                      decoration: const InputDecoration(
                        labelText: 'Character',
                        border: OutlineInputBorder(),
                      ),
                      items: widget.characters.map((character) {
                        return DropdownMenuItem<Character>(
                          value: character,
                          child: Row(
                            children: [
                              _CharacterAvatar(
                                  character: character, radius: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _characterName(character),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedCharacter = value;
                              });
                            },
                    ),
                    const SizedBox(height: 14),
                    CompendiumAwareTextField(
                      controller: _contentController,
                      campaignId: widget.campaignId,
                      decoration: InputDecoration(
                        labelText: 'Note',
                        hintText: 'What did your character notice or decide?',
                        border: const OutlineInputBorder(),
                        errorText: _showContentError
                            ? 'Write a note before saving.'
                            : null,
                      ),
                      minLines: 7,
                      maxLines: 12,
                      keyboardType: TextInputType.multiline,
                    ),
                    if (_contentController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      CompendiumMentionChips(
                        text: _contentController.text,
                        campaignId: widget.campaignId,
                        maxItems: 5,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _pickImage,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              _selectedImagePath == null
                                  ? 'Attach image'
                                  : 'Change image',
                            ),
                          ),
                        ),
                        if (_selectedImagePath != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _selectedImagePath = null;
                                    });
                                  },
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove image',
                          ),
                        ],
                      ],
                    ),
                    if (_selectedImagePath != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: buildImageFromPath(
                          _selectedImagePath!,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: canSubmit ? _submit : null,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.publish_outlined),
                          label:
                              Text(_isSaving ? 'Saving' : widget.actionLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _characterName(Character character) {
    return character.name.isEmpty ? 'Unnamed Character' : character.name;
  }
}

class _CharacterAvatar extends StatelessWidget {
  final Character character;
  final double radius;

  const _CharacterAvatar({
    required this.character,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final hasPortrait = hasDisplayableImagePath(character.portraitPath);

    return CircleAvatar(
      radius: radius,
      backgroundImage:
          hasPortrait ? imageProviderFromPath(character.portraitPath!) : null,
      child: hasPortrait ? null : const Icon(Icons.person_outline),
    );
  }
}
