import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/campaign_event.dart';
import '../models/character.dart';
import '../models/compendium_entry.dart';
import '../models/journal_entry.dart';
import '../models/session.dart';
import '../providers/app_role_provider.dart';
import '../providers/campaign_event_provider.dart';
import '../providers/character_provider.dart';
import '../providers/compendium_provider.dart';
import '../providers/journal_entry_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/compendium_aware_text_field.dart';
import '../widgets/linked_compendium_text.dart';

class SessionDetailScreen extends StatefulWidget {
  final Session session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _notesController;

  Timer? _debounce;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _didLoad = false;
  late Session _currentSession;

  @override
  void initState() {
    super.initState();

    _currentSession = widget.session;

    _titleController = TextEditingController(text: _currentSession.title);
    _summaryController =
        TextEditingController(text: _currentSession.summary ?? '');
    _notesController = TextEditingController(text: _currentSession.rawNotes);

    _titleController.addListener(_onContentChanged);
    _summaryController.addListener(_onContentChanged);
    _notesController.addListener(_onContentChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoad) return;
    _didLoad = true;

    context.read<CampaignEventProvider>().loadEvents();
    context.read<CompendiumProvider>().loadEntries();
    context.read<JournalEntryProvider>().loadEntries();

    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      context.read<CharacterProvider>().loadCharacters(userId);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();

    _titleController.removeListener(_onContentChanged);
    _summaryController.removeListener(_onContentChanged);
    _notesController.removeListener(_onContentChanged);

    _titleController.dispose();
    _summaryController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _saveSessionSilently();
    });
  }

  Future<String?> _pickSessionImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      return pickedFile?.path;
    } catch (e) {
      debugPrint('Error picking session image: $e');
      return null;
    }
  }

  Future<String?> _pickJournalImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      return pickedFile?.path;
    } catch (e) {
      debugPrint('Error picking journal image: $e');
      return null;
    }
  }

  Future<void> _saveSessionSilently() async {
    final trimmedTitle = _titleController.text.trim();
    final trimmedSummary = _summaryController.text.trim();
    final trimmedNotes = _notesController.text.trim();

    if (trimmedTitle.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final updatedSession = _currentSession.copyWith(
      title: trimmedTitle,
      summary: trimmedSummary.isEmpty ? null : trimmedSummary,
      rawNotes: trimmedNotes,
      imagePath: _currentSession.imagePath,
    );
    await context.read<SessionProvider>().updateSession(updatedSession);

    if (!mounted) return;

    setState(() {
      _currentSession = updatedSession;
      _isSaving = false;
      _hasUnsavedChanges = false;
    });
  }

  String _buildStatusText() {
    if (_isSaving) return 'Saving...';
    if (_hasUnsavedChanges) return 'Unsaved changes';
    return 'Saved';
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<CampaignEventProvider>();
    final journalProvider = context.watch<JournalEntryProvider>();
    final characterProvider = context.watch<CharacterProvider>();
    final roleProvider = context.watch<AppRoleProvider>();
    final isDm = roleProvider.isDm;

    final sessionEvents = eventProvider
        .getEventsBySession(_currentSession.id)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final journalEntries = journalProvider
        .getEntriesBySession(_currentSession.id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final activityItems = <_SessionActivityItem>[
      ...sessionEvents.map(_SessionActivityItem.fromEvent),
      ...journalEntries.map(_SessionActivityItem.fromJournalEntry),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final campaignCharacters = characterProvider
        .getCharactersByCampaignSafe(_currentSession.campaignId)
        .toList();

    final hasSessionImage = _currentSession.imagePath != null &&
        _currentSession.imagePath!.isNotEmpty &&
        File(_currentSession.imagePath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session'),
      ),
      floatingActionButton: isDm
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateEventDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add event'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (isDm) ...[
              Text(
                _buildStatusText(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            isDm
                ? TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Session title',
                    ),
                  )
                : Text(
                    _currentSession.title.isEmpty
                        ? 'Untitled session'
                        : _currentSession.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
            const SizedBox(height: 16),
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            isDm
                ? TextField(
                    controller: _summaryController,
                    decoration: const InputDecoration(
                      hintText: 'Write a short summary of the session...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (_currentSession.summary ?? '').trim().isEmpty
                          ? 'No summary yet'
                          : _currentSession.summary!,
                    ),
                  ),
            const SizedBox(height: 24),
            Text(
              'Session notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            isDm
                ? SizedBox(
                    height: 320,
                    child: TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        hintText: 'Write the full session notes...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                    ),
                  )
                : Container(
                    constraints: const BoxConstraints(minHeight: 120),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: LinkedCompendiumText(
                      text: _currentSession.rawNotes.trim().isEmpty
                          ? 'No session notes available'
                          : _currentSession.rawNotes,
                      campaignId: _currentSession.campaignId,
                    ),
                  ),
            const SizedBox(height: 24),
            if (hasSessionImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_currentSession.imagePath!),
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isDm) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final path = await _pickSessionImage();
                        if (path == null) return;

                        final updatedSession = _currentSession.copyWith(
                          imagePath: path,
                        );

                        await context
                            .read<SessionProvider>()
                            .updateSession(updatedSession);

                        if (!mounted) return;

                        setState(() {
                          _currentSession = updatedSession;
                        });
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        hasSessionImage
                            ? 'Change cover image'
                            : 'Add cover image',
                      ),
                    ),
                  ),
                  if (hasSessionImage) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final updatedSession = _currentSession.copyWith(
                          imagePath: '',
                        );

                        await context
                            .read<SessionProvider>()
                            .updateSession(updatedSession);

                        if (!mounted) return;

                        setState(() {
                          _currentSession = updatedSession;
                        });
                      },
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove cover image',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Compendium shortcuts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showCreateCompendiumEntryFromSummaryDialog(context),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('From summary'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showCreateCompendiumEntryDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Manual entry'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Session activity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isDm) ...[
                  TextButton.icon(
                    onPressed: () => _showCreateEventFromSummaryDialog(context),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('From summary'),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreateEventDialog(context),
                    icon: const Icon(Icons.bolt_outlined),
                    label: const Text('Event'),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCreateJournalEntryDialog(
                      context,
                      campaignCharacters,
                    ),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Journal'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (activityItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No activity linked to this session yet'),
                ),
              )
            else
              ...activityItems.map(
                (item) => _buildActivityTimelineItem(
                  context,
                  item,
                  campaignCharacters,
                  isDm,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTimelineItem(
    BuildContext context,
    _SessionActivityItem item,
    List<Character> campaignCharacters,
    bool isDm,
  ) {
    final isEvent = item.event != null;
    final hasImage = item.entry != null &&
        item.entry!.imagePath != null &&
        item.entry!.imagePath!.isNotEmpty &&
        File(item.entry!.imagePath!).existsSync();

    final lineHeight = isEvent ? 115.0 : (hasImage ? 250.0 : 145.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isEvent
                    ? Colors.deepPurpleAccent.withOpacity(0.9)
                    : const Color(0xFF5B4B8A),
                child: Icon(
                  isEvent
                      ? _iconForType(item.event!.type)
                      : Icons.menu_book_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 2,
                height: lineHeight,
                color: Colors.deepPurpleAccent.withOpacity(0.25),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isEvent
                ? _buildTimelineEventCard(
                    context,
                    item.event!,
                    isDm,
                  )
                : _buildTimelineJournalCard(
                    context,
                    item.entry!,
                    campaignCharacters,
                    isDm,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEventCard(
    BuildContext context,
    CampaignEvent event,
    bool isDm,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetaChip(event.type),
                        _buildMetaChip(_formatDate(event.date)),
                        _buildMetaChip('Event'),
                      ],
                    ),
                  ],
                ),
              ),
              if (isDm)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white.withOpacity(0.75),
                  ),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEditEventDialog(context, event);
                    } else if (value == 'delete') {
                      await _confirmDeleteEvent(context, event);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: LinkedCompendiumText(
              text: event.description,
              campaignId: _currentSession.campaignId,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineJournalCard(
    BuildContext context,
    JournalEntry entry,
    List<Character> campaignCharacters,
    bool isDm,
  ) {
    final hasAuthorPortrait = entry.authorCharacterPortraitPath != null &&
        entry.authorCharacterPortraitPath!.isNotEmpty &&
        File(entry.authorCharacterPortraitPath!).existsSync();

    final hasAttachedImage = entry.imagePath != null &&
        entry.imagePath!.isNotEmpty &&
        File(entry.imagePath!).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF5B4B8A),
                backgroundImage: hasAuthorPortrait
                    ? FileImage(File(entry.authorCharacterPortraitPath!))
                    : null,
                child: !hasAuthorPortrait
                    ? const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (entry.authorCharacterName ?? entry.authorName)
                              .trim()
                              .isEmpty
                          ? 'Unknown'
                          : (entry.authorCharacterName ?? entry.authorName),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildMetaChip(
                          entry.authorRole == 'dm' ? 'DM' : 'Player',
                        ),
                        _buildMetaChip(_formatDate(entry.createdAt)),
                        _buildMetaChip('Journal'),
                      ],
                    ),
                  ],
                ),
              ),
              if (isDm)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white.withOpacity(0.75),
                  ),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      _showEditJournalEntryDialog(
                        context,
                        entry,
                        campaignCharacters,
                      );
                    } else if (value == 'delete') {
                      await _confirmDeleteJournalEntry(context, entry);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            child: LinkedCompendiumText(
              text: entry.content,
              campaignId: _currentSession.campaignId,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          if (hasAttachedImage) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(entry.imagePath!),
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.22),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showEditJournalEntryDialog(
    BuildContext context,
    JournalEntry entry,
    List<Character> campaignCharacters,
  ) {
    final contentController = TextEditingController(text: entry.content);

    Character? selectedCharacter;
    String? selectedImagePath = entry.imagePath;

    if (entry.authorCharacterId != null) {
      try {
        selectedCharacter = campaignCharacters.firstWhere(
          (c) => c.id == entry.authorCharacterId,
        );
      } catch (_) {
        selectedCharacter = null;
      }
    }

    selectedCharacter ??=
        campaignCharacters.isNotEmpty ? campaignCharacters.first : null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit journal entry'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedCharacter != null)
                        DropdownButtonFormField<Character>(
                          value: selectedCharacter,
                          decoration: const InputDecoration(
                            labelText: 'Character',
                          ),
                          items: campaignCharacters.map((character) {
                            final characterName = character.name.isEmpty
                                ? 'Unnamed Character'
                                : character.name;

                            return DropdownMenuItem<Character>(
                              value: character,
                              child: Text(characterName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              selectedCharacter = value;
                            });
                          },
                        ),
                      const SizedBox(height: 12),
                      CompendiumAwareTextField(
                        controller: contentController,
                        campaignId: _currentSession.campaignId,
                        decoration: const InputDecoration(
                          labelText: 'Entry content',
                          hintText: 'Update this journal entry...',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickJournalImage();
                                if (path == null) return;

                                setDialogState(() {
                                  selectedImagePath = path;
                                });
                              },
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                selectedImagePath == null
                                    ? 'Attach image'
                                    : 'Change image',
                              ),
                            ),
                          ),
                          if (selectedImagePath != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  selectedImagePath = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                              tooltip: 'Remove image',
                            ),
                          ],
                        ],
                      ),
                      if (selectedImagePath != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          width: 320,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(selectedImagePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final content = contentController.text.trim();
                    if (content.isEmpty || selectedCharacter == null) return;

                    final characterName = selectedCharacter!.name.isEmpty
                        ? 'Unnamed Character'
                        : selectedCharacter!.name;

                    final updatedEntry = JournalEntry(
                      id: entry.id,
                      campaignId: entry.campaignId,
                      sessionId: entry.sessionId,
                      authorRole: entry.authorRole,
                      authorName: characterName,
                      authorCharacterName: characterName,
                      authorCharacterPortraitPath:
                          selectedCharacter!.portraitPath,
                      authorCharacterId: selectedCharacter!.id,
                      content: content,
                      imagePath: selectedImagePath,
                      createdAt: entry.createdAt,
                    );

                    await dialogContext
                        .read<JournalEntryProvider>()
                        .updateEntry(updatedEntry);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Journal entry updated')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditEventDialog(BuildContext context, CampaignEvent event) {
    final titleController = TextEditingController(text: event.title);
    final descriptionController =
        TextEditingController(text: event.description);
    String selectedType = event.type;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Event type',
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
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();

                    if (title.isEmpty || description.isEmpty) return;

                    final updatedEvent = event.copyWith(
                      title: title,
                      description: description,
                      type: selectedType,
                    );

                    await dialogContext
                        .read<CampaignEventProvider>()
                        .updateEvent(updatedEvent);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event updated')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteJournalEntry(
    BuildContext context,
    JournalEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete journal entry'),
          content: const Text(
            'Are you sure you want to delete this journal entry?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<JournalEntryProvider>().removeEntry(entry.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Journal entry deleted')),
    );
  }

  Future<void> _confirmDeleteEvent(
    BuildContext context,
    CampaignEvent event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete event'),
          content: Text(
            'Are you sure you want to delete "${event.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<CampaignEventProvider>().removeEvent(event.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event deleted')),
    );
  }

  void _showCreateJournalEntryDialog(
    BuildContext context,
    List<Character> campaignCharacters,
  ) {
    if (campaignCharacters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No characters available in this campaign'),
        ),
      );
      return;
    }

    final contentController = TextEditingController();
    Character selectedCharacter = campaignCharacters.first;
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create journal entry'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<Character>(
                        value: selectedCharacter,
                        decoration: const InputDecoration(
                          labelText: 'Character',
                        ),
                        items: campaignCharacters.map((character) {
                          final characterName = character.name.isEmpty
                              ? 'Unnamed Character'
                              : character.name;

                          return DropdownMenuItem<Character>(
                            value: character,
                            child: Text(characterName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedCharacter = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      CompendiumAwareTextField(
                        controller: contentController,
                        campaignId: _currentSession.campaignId,
                        decoration: const InputDecoration(
                          labelText: 'Entry content',
                          hintText: 'Write what this character experienced...',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickJournalImage();
                                if (path == null) return;

                                setDialogState(() {
                                  selectedImagePath = path;
                                });
                              },
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                selectedImagePath == null
                                    ? 'Attach image'
                                    : 'Change image',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (selectedImagePath != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          width: 320,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(selectedImagePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final content = contentController.text.trim();

                    if (content.isEmpty) return;

                    final characterName = selectedCharacter.name.isEmpty
                        ? 'Unnamed Character'
                        : selectedCharacter.name;

                    final entry = JournalEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      campaignId: _currentSession.campaignId,
                      sessionId: _currentSession.id,
                      authorRole: 'player',
                      authorName: characterName,
                      authorCharacterName: characterName,
                      authorCharacterPortraitPath:
                          selectedCharacter.portraitPath,
                      authorCharacterId: selectedCharacter.id,
                      content: content,
                      imagePath: selectedImagePath,
                      createdAt: DateTime.now(),
                    );

                    await dialogContext
                        .read<JournalEntryProvider>()
                        .addEntry(entry);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateCompendiumEntryFromSummaryDialog(BuildContext context) {
    final summaryText = _summaryController.text.trim();

    if (summaryText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write a session summary first'),
        ),
      );
      return;
    }

    final suggestedTitle = _titleController.text.trim().isNotEmpty
        ? '${_titleController.text.trim()} entry'
        : 'New entry';

    final titleController = TextEditingController(text: suggestedTitle);
    final descriptionController = TextEditingController(text: summaryText);
    String selectedType = 'lore';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create entry from summary'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'npc', child: Text('NPC')),
                        DropdownMenuItem(
                          value: 'location',
                          child: Text('Location'),
                        ),
                        DropdownMenuItem(value: 'item', child: Text('Item')),
                        DropdownMenuItem(
                          value: 'faction',
                          child: Text('Faction'),
                        ),
                        DropdownMenuItem(value: 'lore', child: Text('Lore')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();

                    if (title.isEmpty || description.isEmpty) return;

                    final entry = CompendiumEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      campaignId: _currentSession.campaignId,
                      title: title,
                      description: description,
                      type: selectedType,
                      createdAt: DateTime.now(),
                    );

                    await dialogContext
                        .read<CompendiumProvider>()
                        .addEntry(entry);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Compendium entry created from summary'),
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateCompendiumEntryDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'npc';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create compendium entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Example: Vargash',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe this entry...',
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'npc', child: Text('NPC')),
                        DropdownMenuItem(
                          value: 'location',
                          child: Text('Location'),
                        ),
                        DropdownMenuItem(value: 'item', child: Text('Item')),
                        DropdownMenuItem(
                          value: 'faction',
                          child: Text('Faction'),
                        ),
                        DropdownMenuItem(value: 'lore', child: Text('Lore')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();

                    if (title.isEmpty || description.isEmpty) return;

                    final entry = CompendiumEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      campaignId: _currentSession.campaignId,
                      title: title,
                      description: description,
                      type: selectedType,
                      createdAt: DateTime.now(),
                    );

                    await dialogContext
                        .read<CompendiumProvider>()
                        .addEntry(entry);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Compendium entry created'),
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'discovery';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event title',
                        hintText: 'Example: The party found the hidden vault',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe what happened...',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Event type',
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
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();

                    if (title.isEmpty || description.isEmpty) return;

                    final event = CampaignEvent(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      campaignId: _currentSession.campaignId,
                      sessionId: _currentSession.id,
                      title: title,
                      description: description,
                      date: DateTime.now(),
                      type: selectedType,
                    );

                    await dialogContext
                        .read<CampaignEventProvider>()
                        .addEvent(event);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateEventFromSummaryDialog(BuildContext context) {
    final summaryText = _summaryController.text.trim();

    if (summaryText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write a session summary first'),
        ),
      );
      return;
    }

    final suggestedTitle = _titleController.text.trim().isNotEmpty
        ? '${_titleController.text.trim()} event'
        : 'New event';

    final titleController = TextEditingController(text: suggestedTitle);
    final descriptionController = TextEditingController(text: summaryText);
    String selectedType = 'discovery';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create event from summary'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Event type',
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
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();

                    if (title.isEmpty || description.isEmpty) return;

                    final event = CampaignEvent(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      campaignId: _currentSession.campaignId,
                      sessionId: _currentSession.id,
                      title: title,
                      description: description,
                      date: DateTime.now(),
                      type: selectedType,
                    );

                    await dialogContext
                        .read<CampaignEventProvider>()
                        .addEvent(event);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Event created from summary'),
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'combat':
        return Icons.flash_on_outlined;
      case 'dialogue':
        return Icons.forum_outlined;
      case 'travel':
        return Icons.map_outlined;
      case 'quest':
        return Icons.assignment_outlined;
      case 'discovery':
      default:
        return Icons.visibility_outlined;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}

class _SessionActivityItem {
  final CampaignEvent? event;
  final JournalEntry? entry;
  final DateTime createdAt;

  const _SessionActivityItem({
    required this.event,
    required this.entry,
    required this.createdAt,
  });

  factory _SessionActivityItem.fromEvent(CampaignEvent event) {
    return _SessionActivityItem(
      event: event,
      entry: null,
      createdAt: event.date,
    );
  }

  factory _SessionActivityItem.fromJournalEntry(JournalEntry entry) {
    return _SessionActivityItem(
      event: null,
      entry: entry,
      createdAt: entry.createdAt,
    );
  }
}
