import 'package:flutter/material.dart';

import '../utils/image_path_utils.dart';
import 'compendium_aware_text_field.dart';

class SessionDraft {
  final String title;
  final String rawNotes;
  final DateTime date;
  final String? imagePath;

  const SessionDraft({
    required this.title,
    required this.rawNotes,
    required this.date,
    this.imagePath,
  });
}

class SessionComposerSheet extends StatefulWidget {
  final String title;
  final String actionLabel;
  final String campaignId;
  final DateTime initialDate;
  final Future<String?> Function() onPickImage;
  final Future<bool> Function(SessionDraft draft) onSubmit;

  const SessionComposerSheet({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.campaignId,
    required this.initialDate,
    required this.onPickImage,
    required this.onSubmit,
  });

  @override
  State<SessionComposerSheet> createState() => _SessionComposerSheetState();
}

class _SessionComposerSheetState extends State<SessionComposerSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _selectedDate;
  String? _selectedImagePath;
  bool _showTitleError = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
    _selectedDate = widget.initialDate;
    _titleController.addListener(_handleTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleTitleChanged);
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleTitleChanged() {
    if (_showTitleError && _titleController.text.trim().isNotEmpty) {
      setState(() {
        _showTitleError = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;

    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  Future<void> _pickImage() async {
    final imagePath = await widget.onPickImage();
    if (!mounted || imagePath == null) return;

    setState(() {
      _selectedImagePath = imagePath;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _showTitleError = true;
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final saved = await widget.onSubmit(
      SessionDraft(
        title: title,
        rawNotes: _notesController.text.trim(),
        date: _selectedDate,
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
    final canSubmit = _titleController.text.trim().isNotEmpty && !_isSaving;

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
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: const Icon(Icons.auto_stories_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge,
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Session title',
                      hintText: 'Session 1 - The Broken Gate',
                      border: const OutlineInputBorder(),
                      errorText:
                          _showTitleError ? 'Give this session a title.' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(_formatDate(_selectedDate)),
                  ),
                  const SizedBox(height: 12),
                  CompendiumAwareTextField(
                    controller: _notesController,
                    campaignId: widget.campaignId,
                    decoration: const InputDecoration(
                      labelText: 'Initial notes',
                      hintText: 'What happened at the table?',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 8,
                    maxLines: 14,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _pickImage,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(
                            _selectedImagePath == null
                                ? 'Attach cover'
                                : 'Change cover',
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
                          tooltip: 'Remove cover',
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
                        height: 190,
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
                            : const Icon(Icons.add),
                        label: Text(_isSaving ? 'Saving' : widget.actionLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
