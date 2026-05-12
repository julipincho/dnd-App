import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/session_provider.dart';
import '../models/session.dart';
import '../services/supabase_storage_service.dart';
import '../utils/image_path_utils.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoad) return;
    _didLoad = true;

    final activeCampaign = context.read<CampaignProvider>().activeCampaign;
    if (activeCampaign == null) return;

    context.read<SessionProvider>().loadSessions(activeCampaign.id);
  }

  @override
  Widget build(BuildContext context) {
    final campaignProvider = context.watch<CampaignProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final currentUserId = context.watch<AuthProvider>().userId;
    final activeCampaign = campaignProvider.activeCampaign;

    if (activeCampaign == null) {
      return Scaffold(
        appBar: StitchAppBar(
          title: const Text('Sessions'),
        ),
        body: const Center(
          child: Text('No active campaign selected'),
        ),
      );
    }

    final sessions = sessionProvider
        .getSessionsByCampaign(activeCampaign.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final isDm =
        currentUserId != null && activeCampaign.ownerUserId == currentUserId;

    return Scaffold(
      appBar: StitchAppBar(
        title: Text('${activeCampaign.name} Sessions'),
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Text('No sessions yet'),
            )
          : ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final session = sessions[index];

                final hasImage = hasDisplayableImagePath(session.imagePath);

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      context.push(
                        '/session-detail',
                        extra: session,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasImage)
                          buildImageFromPath(
                            session.imagePath!,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: !hasImage
                              ? const CircleAvatar(
                                  child: Icon(Icons.auto_stories_outlined),
                                )
                              : null,
                          title: Text(
                            session.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(session.date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _buildPreviewText(session),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          trailing: isDm
                              ? PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'delete') {
                                      await _confirmDeleteSession(
                                        context,
                                        session,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: isDm
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateSessionDialog(
                context,
                activeCampaign.id,
                currentUserId,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Session'),
            )
          : null,
    );
  }

  String _buildPreviewText(Session session) {
    final summary = session.summary?.trim();
    final notes = session.rawNotes.trim();

    if (summary != null && summary.isNotEmpty) {
      return summary;
    }

    if (notes.isNotEmpty) {
      return notes;
    }

    return 'No notes yet';
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

  Future<void> _confirmDeleteSession(
    BuildContext context,
    Session session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete session'),
          content: Text(
            'Are you sure you want to delete "${session.title}"?',
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

    await context.read<SessionProvider>().removeSession(session.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session deleted')),
    );
  }

  Future<String?> _uploadSessionImageIfNeeded(
    String? imagePath, {
    required String ownerUserId,
    required String sessionId,
  }) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    if (isRemoteImagePath(imagePath) || isAssetImagePath(imagePath)) {
      return imagePath;
    }
    if (!File(imagePath).existsSync()) {
      throw StateError(
        'Cannot upload session image because the file is missing.',
      );
    }

    return SupabaseStorageService.uploadUserImage(
      file: File(imagePath),
      ownerUserId: ownerUserId,
      folder: 'session-covers',
      entityId: sessionId,
    );
  }

  void _showCreateSessionDialog(
    BuildContext context,
    String campaignId,
    String ownerUserId,
  ) {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create session'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Session title',
                          hintText: 'Example: Session 1 - The Broken Gate',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Initial notes',
                          hintText: 'Write the session notes...',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickSessionImage();
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: buildImageFromPath(
                            selectedImagePath!,
                            height: 150,
                            width: 320,
                            fit: BoxFit.cover,
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
                    final title = titleController.text.trim();
                    final notes = notesController.text.trim();

                    if (title.isEmpty) return;

                    final sessionId =
                        DateTime.now().millisecondsSinceEpoch.toString();
                    String? imagePath;
                    try {
                      imagePath = await _uploadSessionImageIfNeeded(
                        selectedImagePath,
                        ownerUserId: ownerUserId,
                        sessionId: sessionId,
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Could not upload the cover image.'),
                        ),
                      );
                      return;
                    }

                    final session = Session(
                      id: sessionId,
                      campaignId: campaignId,
                      title: title,
                      date: DateTime.now(),
                      rawNotes: notes,
                      summary: null,
                      imagePath: imagePath,
                    );

                    await dialogContext
                        .read<SessionProvider>()
                        .addSession(session);

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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
