import 'package:flutter/material.dart';

import 'compendium_aware_text_field.dart';

class CampaignEventDraft {
  final String title;
  final String description;
  final String type;
  final DateTime date;

  const CampaignEventDraft({
    required this.title,
    required this.description,
    required this.type,
    required this.date,
  });
}

class CampaignEventComposerSheet extends StatefulWidget {
  final String title;
  final String actionLabel;
  final String campaignId;
  final String initialTitle;
  final String initialDescription;
  final String initialType;
  final DateTime initialDate;
  final Future<bool> Function(CampaignEventDraft draft) onSubmit;

  const CampaignEventComposerSheet({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.campaignId,
    required this.initialDate,
    required this.onSubmit,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialType = 'discovery',
  });

  @override
  State<CampaignEventComposerSheet> createState() =>
      _CampaignEventComposerSheetState();
}

class _CampaignEventComposerSheetState
    extends State<CampaignEventComposerSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late String _selectedType;
  bool _showTitleError = false;
  bool _showDescriptionError = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
    _selectedDate = widget.initialDate;
    _selectedType = widget.initialType;
    _titleController.addListener(_clearTitleError);
    _descriptionController.addListener(_clearDescriptionError);
  }

  @override
  void dispose() {
    _titleController.removeListener(_clearTitleError);
    _descriptionController.removeListener(_clearDescriptionError);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _clearTitleError() {
    if (_showTitleError && _titleController.text.trim().isNotEmpty) {
      setState(() {
        _showTitleError = false;
      });
    }
  }

  void _clearDescriptionError() {
    if (_showDescriptionError &&
        _descriptionController.text.trim().isNotEmpty) {
      setState(() {
        _showDescriptionError = false;
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

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      setState(() {
        _showTitleError = title.isEmpty;
        _showDescriptionError = description.isEmpty;
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final saved = await widget.onSubmit(
      CampaignEventDraft(
        title: title,
        description: description,
        type: _selectedType,
        date: _selectedDate,
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
    final canSubmit = _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        !_isSaving;

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
                        child: const Icon(Icons.bolt_outlined),
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
                    decoration: InputDecoration(
                      labelText: 'Event title',
                      hintText: 'The seal answers',
                      border: const OutlineInputBorder(),
                      errorText:
                          _showTitleError ? 'Give this event a title.' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'combat',
                              child: Text('Combat'),
                            ),
                            DropdownMenuItem(
                              value: 'dialogue',
                              child: Text('Dialogue'),
                            ),
                            DropdownMenuItem(
                              value: 'discovery',
                              child: Text('Discovery'),
                            ),
                            DropdownMenuItem(
                              value: 'travel',
                              child: Text('Travel'),
                            ),
                            DropdownMenuItem(
                              value: 'quest',
                              child: Text('Quest'),
                            ),
                          ],
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedType = value;
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(_formatDate(_selectedDate)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CompendiumAwareTextField(
                    controller: _descriptionController,
                    campaignId: widget.campaignId,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Describe what changed in the story...',
                      border: const OutlineInputBorder(),
                      errorText: _showDescriptionError
                          ? 'Describe what happened.'
                          : null,
                    ),
                    minLines: 7,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                  ),
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
                            : const Icon(Icons.check),
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
