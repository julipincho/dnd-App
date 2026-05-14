import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/campaign_event.dart';
import '../models/character.dart';
import '../models/compendium_entry.dart';
import '../models/journal_entry.dart';
import '../models/session.dart';
import '../providers/campaign_provider.dart';
import '../providers/campaign_event_provider.dart';
import '../providers/character_provider.dart';
import '../providers/compendium_provider.dart';
import '../providers/journal_entry_provider.dart';
import '../providers/session_provider.dart';
import '../services/supabase_storage_service.dart';
import '../utils/image_path_utils.dart';
import '../widgets/compendium_aware_text_field.dart';
import '../widgets/journal_entry_composer_dialog.dart';
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

    context
        .read<CampaignEventProvider>()
        .loadEvents(_currentSession.campaignId);
    context.read<CompendiumProvider>().loadEntries();
    context
        .read<JournalEntryProvider>()
        .loadEntries(_currentSession.campaignId);

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
    if (!_isCurrentUserDm()) return;

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
    if (!_isCurrentUserDm()) return;

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

  bool _isCurrentUserDm() {
    final userId = context.read<AuthProvider>().userId;
    final campaignProvider = context.read<CampaignProvider>();
    final activeCampaign = campaignProvider.activeCampaign;

    if (userId == null || activeCampaign == null) return false;
    return activeCampaign.id == _currentSession.campaignId &&
        activeCampaign.ownerUserId == userId;
  }

  Future<String?> _uploadImageIfNeeded(
    String? imagePath, {
    required String? ownerUserId,
    required String folder,
    required String entityId,
  }) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    if (isRemoteImagePath(imagePath) || isAssetImagePath(imagePath)) {
      return imagePath;
    }
    if (ownerUserId == null || ownerUserId.trim().isEmpty) {
      throw StateError('Cannot upload an image without an owner user id.');
    }
    if (!File(imagePath).existsSync()) {
      throw StateError('Cannot upload an image because the file is missing.');
    }

    return SupabaseStorageService.uploadUserImage(
      file: File(imagePath),
      ownerUserId: ownerUserId,
      folder: folder,
      entityId: entityId,
    );
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
    final campaignProvider = context.watch<CampaignProvider>();
    final currentUserId = context.watch<AuthProvider>().userId;
    final activeCampaign = campaignProvider.activeCampaign;
    final isDm = currentUserId != null &&
        activeCampaign != null &&
        activeCampaign.id == _currentSession.campaignId &&
        activeCampaign.ownerUserId == currentUserId;

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
    final playerCharacters = currentUserId == null
        ? <Character>[]
        : campaignCharacters
            .where((character) => character.ownerUserId == currentUserId)
            .toList();

    final hasSessionImage = hasDisplayableImagePath(_currentSession.imagePath);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0916),
      appBar: StitchAppBar(
        title: const Text('Session'),
        backgroundColor: const Color(0xFF0C0916),
        elevation: 0,
        actions: [
          if (!isDm && playerCharacters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _showCreateJournalEntryDialog(
                  context,
                  playerCharacters,
                ),
                icon: const Icon(Icons.edit_note),
                label: const Text('Add note'),
              ),
            ),
        ],
      ),
      floatingActionButton: isDm
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateEventDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Event'),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final maxWidth = isWide ? 1120.0 : 760.0;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 28 : 16,
                12,
                isWide ? 28 : 16,
                96,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSessionHero(
                          context,
                          isDm: isDm,
                          hasSessionImage: hasSessionImage,
                          currentUserId: currentUserId,
                          eventsCount: sessionEvents.length,
                          notesCount: journalEntries.length,
                        ),
                        const SizedBox(height: 18),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildSessionContent(
                                  context,
                                  isDm: isDm,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                flex: 4,
                                child: _buildSessionTools(
                                  context,
                                  isDm: isDm,
                                  hasSessionImage: hasSessionImage,
                                  currentUserId: currentUserId,
                                  playerCharacters: playerCharacters,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _buildSessionContent(context, isDm: isDm),
                          const SizedBox(height: 18),
                          _buildSessionTools(
                            context,
                            isDm: isDm,
                            hasSessionImage: hasSessionImage,
                            currentUserId: currentUserId,
                            playerCharacters: playerCharacters,
                          ),
                        ],
                        const SizedBox(height: 22),
                        _buildActivityHeader(
                          context,
                          isDm: isDm,
                          playerCharacters: playerCharacters,
                        ),
                        const SizedBox(height: 12),
                        if (activityItems.isEmpty)
                          _buildEmptyActivityCard(context, isDm: isDm)
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _changeSessionCover(
    BuildContext context, {
    required String? currentUserId,
  }) async {
    final path = await _pickSessionImage();
    if (path == null) return;

    String? imagePath;
    try {
      imagePath = await _uploadImageIfNeeded(
        path,
        ownerUserId: currentUserId,
        folder: 'session-covers',
        entityId: _currentSession.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not upload the cover image.'),
        ),
      );
      return;
    }

    final updatedSession = _currentSession.copyWith(imagePath: imagePath);
    await context.read<SessionProvider>().updateSession(updatedSession);

    if (!mounted) return;
    setState(() {
      _currentSession = updatedSession;
    });
  }

  Future<void> _removeSessionCover(BuildContext context) async {
    final updatedSession = _currentSession.copyWith(imagePath: '');
    await context.read<SessionProvider>().updateSession(updatedSession);

    if (!mounted) return;
    setState(() {
      _currentSession = updatedSession;
    });
  }

  Widget _buildSessionHero(
    BuildContext context, {
    required bool isDm,
    required bool hasSessionImage,
    required String? currentUserId,
    required int eventsCount,
    required int notesCount,
  }) {
    final title = _currentSession.title.trim().isEmpty
        ? 'Untitled session'
        : _currentSession.title.trim();
    final summary = (_currentSession.summary ?? '').trim();
    final hasSummary = summary.isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF17132A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: hasSessionImage
                ? buildImageFromPath(
                    _currentSession.imagePath!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF283B5D),
                          Color(0xFF17132A),
                          Color(0xFF321F4E),
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(hasSessionImage ? 0.12 : 0.0),
                    Colors.black.withOpacity(0.72),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 92, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoPill(
                      icon: Icons.calendar_month_outlined,
                      label: _formatDate(_currentSession.date),
                    ),
                    _buildInfoPill(
                      icon: isDm
                          ? Icons.admin_panel_settings_outlined
                          : Icons.groups_outlined,
                      label: isDm ? 'DM view' : 'Player view',
                    ),
                    _buildInfoPill(
                      icon: Icons.bolt_outlined,
                      label: '$eventsCount event${eventsCount == 1 ? '' : 's'}',
                    ),
                    _buildInfoPill(
                      icon: Icons.edit_note,
                      label: '$notesCount note${notesCount == 1 ? '' : 's'}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isDm)
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Session title',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                      ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  )
                else
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.06,
                    ),
                  ),
                if (!isDm && hasSummary) ...[
                  const SizedBox(height: 12),
                  Text(
                    summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (hasSessionImage)
                      FilledButton.tonalIcon(
                        onPressed: () => _showImageReader(
                          context,
                          _currentSession.imagePath!,
                        ),
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('Open cover'),
                      ),
                    if (isDm)
                      OutlinedButton.icon(
                        onPressed: () => _changeSessionCover(
                          context,
                          currentUserId: currentUserId,
                        ),
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          hasSessionImage ? 'Change cover' : 'Add cover',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionContent(BuildContext context, {required bool isDm}) {
    final summary = (_currentSession.summary ?? '').trim();
    final notes = _currentSession.rawNotes.trim();

    return Column(
      children: [
        _buildSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPanelHeader(
                icon: Icons.auto_stories_outlined,
                title: 'Session Summary',
                subtitle: 'The clean read for everyone at the table.',
              ),
              const SizedBox(height: 14),
              if (isDm)
                _buildSessionTextField(
                  controller: _summaryController,
                  hint: 'Write a concise recap of what mattered most...',
                  minLines: 5,
                  maxLines: 8,
                )
              else
                _buildReadableText(
                  text: summary.isEmpty ? 'No summary yet.' : summary,
                  isMuted: summary.isEmpty,
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPanelHeader(
                icon: Icons.menu_book_outlined,
                title: 'DM Notes',
                subtitle: isDm
                    ? 'Private editorial control for the session record.'
                    : 'The canonical record available to the party.',
              ),
              const SizedBox(height: 14),
              if (isDm)
                _buildSessionTextField(
                  controller: _notesController,
                  hint: 'Write the full session notes...',
                  minLines: 10,
                  maxLines: 18,
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: LinkedCompendiumText(
                    text: notes.isEmpty ? 'No session notes available.' : notes,
                    campaignId: _currentSession.campaignId,
                    style: TextStyle(
                      color: notes.isEmpty
                          ? Colors.white.withOpacity(0.48)
                          : Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      height: 1.58,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTools(
    BuildContext context, {
    required bool isDm,
    required bool hasSessionImage,
    required String? currentUserId,
    required List<Character> playerCharacters,
  }) {
    return _buildSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            icon: isDm ? Icons.tune : Icons.edit_note,
            title: isDm ? 'DM Tools' : 'Player Contribution',
            subtitle: isDm
                ? 'Shape the official record and create structured lore.'
                : 'Add your character perspective to the session chronicle.',
          ),
          const SizedBox(height: 16),
          if (isDm) ...[
            _buildToolButton(
              icon: Icons.bolt_outlined,
              label: 'Add Event',
              onPressed: () => _showCreateEventDialog(context),
            ),
            const SizedBox(height: 10),
            _buildToolButton(
              icon: Icons.auto_awesome_outlined,
              label: 'Event From Summary',
              onPressed: () => _showCreateEventFromSummaryDialog(context),
            ),
            const SizedBox(height: 10),
            _buildToolButton(
              icon: Icons.library_books_outlined,
              label: 'Compendium From Summary',
              onPressed: () =>
                  _showCreateCompendiumEntryFromSummaryDialog(context),
            ),
            const SizedBox(height: 10),
            _buildToolButton(
              icon: Icons.add,
              label: 'Manual Compendium Entry',
              onPressed: () => _showCreateCompendiumEntryDialog(context),
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 12),
            _buildToolButton(
              icon: Icons.image_outlined,
              label: hasSessionImage ? 'Change Cover' : 'Add Cover',
              onPressed: () => _changeSessionCover(
                context,
                currentUserId: currentUserId,
              ),
            ),
            if (hasSessionImage) ...[
              const SizedBox(height: 10),
              _buildToolButton(
                icon: Icons.close,
                label: 'Remove Cover',
                isDestructive: true,
                onPressed: () => _removeSessionCover(context),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  _isSaving
                      ? Icons.sync
                      : _hasUnsavedChanges
                          ? Icons.pending_outlined
                          : Icons.check_circle_outline,
                  size: 16,
                  color: Colors.white.withOpacity(0.64),
                ),
                const SizedBox(width: 8),
                Text(
                  _buildStatusText(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.64),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else if (playerCharacters.isNotEmpty) ...[
            _buildToolButton(
              icon: Icons.edit_note,
              label: 'Add Character Note',
              onPressed: () => _showCreateJournalEntryDialog(
                context,
                playerCharacters,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your note becomes part of the shared timeline while the DM keeps control of the official session record.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                height: 1.45,
              ),
            ),
          ] else
            Text(
              'Create or assign one of your characters to this campaign before adding notes.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityHeader(
    BuildContext context, {
    required bool isDm,
    required List<Character> playerCharacters,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildPanelHeader(
            icon: Icons.timeline_outlined,
            title: 'Session Activity',
            subtitle: 'Events and player perspectives in table order.',
          ),
        ),
        const SizedBox(width: 12),
        if (!isDm && playerCharacters.isNotEmpty)
          FilledButton.icon(
            onPressed: () => _showCreateJournalEntryDialog(
              context,
              playerCharacters,
            ),
            icon: const Icon(Icons.edit_note),
            label: const Text('Add note'),
          ),
      ],
    );
  }

  Widget _buildEmptyActivityCard(BuildContext context, {required bool isDm}) {
    return _buildSurface(
      child: Column(
        children: [
          Icon(
            isDm ? Icons.bolt_outlined : Icons.edit_note,
            size: 36,
            color: Colors.white.withOpacity(0.42),
          ),
          const SizedBox(height: 12),
          Text(
            isDm ? 'No events yet' : 'No player notes yet',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isDm
                ? 'Add key moments so the session reads like a campaign chronicle.'
                : 'Player notes will appear here as the party adds their perspective.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurface({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17132A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.075)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPanelHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF4DA8FF).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF8FD2FF),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.58),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTextField({
    required TextEditingController controller,
    required String hint,
    required int minLines,
    required int maxLines,
  }) {
    return CompendiumAwareTextField(
      controller: controller,
      campaignId: _currentSession.campaignId,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: TextInputType.multiline,
      style: TextStyle(
        color: Colors.white.withOpacity(0.92),
        fontSize: 15,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.36)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF8FD2FF)),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildReadableText({
    required String text,
    bool isMuted = false,
  }) {
    final style = TextStyle(
      color: isMuted
          ? Colors.white.withOpacity(0.48)
          : Colors.white.withOpacity(0.9),
      fontSize: 16,
      height: 1.58,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: LinkedCompendiumText(
        text: text,
        campaignId: _currentSession.campaignId,
        style: style,
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.redAccent : const Color(0xFF8FD2FF);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.36)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.34),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.82)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
    final hasImage =
        item.entry != null && hasDisplayableImagePath(item.entry!.imagePath);

    final lineHeight = isEvent ? 112.0 : (hasImage ? 260.0 : 150.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isEvent
                      ? const Color(0xFF4DA8FF).withOpacity(0.18)
                      : const Color(0xFF8B5CF6).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isEvent
                        ? const Color(0xFF8FD2FF).withOpacity(0.24)
                        : const Color(0xFFC4B5FD).withOpacity(0.22),
                  ),
                ),
                child: Icon(
                  isEvent ? _iconForType(item.event!.type) : Icons.edit_note,
                  color: isEvent
                      ? const Color(0xFF8FD2FF)
                      : const Color(0xFFC4B5FD),
                  size: 20,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 2,
                height: lineHeight,
                color: Colors.white.withOpacity(0.08),
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
                  ),
          ),
        ],
      ),
    );
  }

  void _showImageReader(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.75,
                maxScale: 4,
                child: buildImageFromPath(
                  imagePath,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height * 0.82,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineEventCard(
    BuildContext context,
    CampaignEvent event,
    bool isDm,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17132A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4DA8FF).withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(16),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
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
            padding: const EdgeInsets.all(14),
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
                fontSize: 15,
                height: 1.52,
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
  ) {
    final currentUserId = context.watch<AuthProvider>().userId;
    final isOwnedByCurrentUser =
        currentUserId != null && entry.authorUserId == currentUserId;

    final hasAuthorPortrait =
        hasDisplayableImagePath(entry.authorCharacterPortraitPath);

    final hasAttachedImage = hasDisplayableImagePath(entry.imagePath);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17132A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC4B5FD).withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(16),
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
                    ? imageProviderFromPath(entry.authorCharacterPortraitPath!)
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
              if (isOwnedByCurrentUser)
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
            padding: const EdgeInsets.all(14),
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
                height: 1.56,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          if (hasAttachedImage) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onTap: () => _showImageReader(context, entry.imagePath!),
                child: buildImageFromPath(
                  entry.imagePath!,
                  width: double.infinity,
                  height: 190,
                  fit: BoxFit.cover,
                ),
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
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
    final currentUserId = context.read<AuthProvider>().userId;
    final editableCharacters = currentUserId == null
        ? <Character>[]
        : campaignCharacters
            .where((character) => character.ownerUserId == currentUserId)
            .toList();

    if (editableCharacters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No editable characters available for this note.'),
        ),
      );
      return;
    }

    final journalProvider = context.read<JournalEntryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (_) {
        return JournalEntryComposerDialog(
          title: 'Edit journal entry',
          actionLabel: 'Save note',
          campaignId: _currentSession.campaignId,
          characters: editableCharacters,
          initialCharacterId: entry.authorCharacterId,
          initialContent: entry.content,
          initialImagePath: entry.imagePath,
          onPickImage: _pickJournalImage,
          onSubmit: (draft) async {
            final characterName = draft.character.name.isEmpty
                ? 'Unnamed Character'
                : draft.character.name;

            String? imagePath;
            try {
              imagePath = await _uploadImageIfNeeded(
                draft.imagePath,
                ownerUserId: entry.authorUserId ?? currentUserId,
                folder: 'journal-entries',
                entityId: entry.id,
              );
            } catch (e) {
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not upload the image.'),
                  ),
                );
              }
              return false;
            }

            final updatedEntry = JournalEntry(
              id: entry.id,
              campaignId: entry.campaignId,
              sessionId: entry.sessionId,
              authorRole: entry.authorRole,
              authorName: characterName,
              authorCharacterName: characterName,
              authorCharacterPortraitPath: draft.character.portraitPath,
              authorCharacterId: draft.character.id,
              authorUserId: entry.authorUserId ?? currentUserId,
              content: draft.content,
              imagePath: imagePath,
              createdAt: entry.createdAt,
            );

            await journalProvider.updateEntry(updatedEntry);

            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Journal entry updated')),
              );
            }

            return true;
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

    final authProvider = context.read<AuthProvider>();
    final journalProvider = context.read<JournalEntryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (_) {
        return JournalEntryComposerDialog(
          title: 'Create journal entry',
          actionLabel: 'Publish note',
          campaignId: _currentSession.campaignId,
          characters: campaignCharacters,
          onPickImage: _pickJournalImage,
          onSubmit: (draft) async {
            final currentUserId = authProvider.userId;
            final entryId = DateTime.now().millisecondsSinceEpoch.toString();
            final characterName = draft.character.name.isEmpty
                ? 'Unnamed Character'
                : draft.character.name;

            String? imagePath;
            try {
              imagePath = await _uploadImageIfNeeded(
                draft.imagePath,
                ownerUserId: currentUserId,
                folder: 'journal-entries',
                entityId: entryId,
              );
            } catch (e) {
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not upload the image.'),
                  ),
                );
              }
              return false;
            }

            final entry = JournalEntry(
              id: entryId,
              campaignId: _currentSession.campaignId,
              sessionId: _currentSession.id,
              authorRole: 'player',
              authorName: characterName,
              authorCharacterName: characterName,
              authorCharacterPortraitPath: draft.character.portraitPath,
              authorCharacterId: draft.character.id,
              authorUserId: currentUserId,
              content: draft.content,
              imagePath: imagePath,
              createdAt: DateTime.now(),
            );

            await journalProvider.addEntry(entry);

            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Journal entry created')),
              );
            }

            return true;
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
