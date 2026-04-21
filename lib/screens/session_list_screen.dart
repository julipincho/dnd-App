import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/campaign_provider.dart';
import '../providers/session_provider.dart';
import '../models/session.dart';

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

    if (!_didLoad) {
      _didLoad = true;
      context.read<SessionProvider>().loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignProvider = context.watch<CampaignProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final activeCampaign = campaignProvider.activeCampaign;

    if (activeCampaign == null) {
      return Scaffold(
        appBar: AppBar(
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

    return Scaffold(
      appBar: AppBar(
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

                final hasImage = session.imagePath != null &&
                    session.imagePath!.isNotEmpty &&
                    File(session.imagePath!).existsSync();

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
                          Image.file(
                            File(session.imagePath!),
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
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'delete') {
                                await _confirmDeleteSession(context, session);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSessionDialog(context, activeCampaign.id),
        child: const Icon(Icons.add),
      ),
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

  void _showCreateSessionDialog(BuildContext context, String campaignId) {
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
                          child: Image.file(
                            File(selectedImagePath!),
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

                    final session = Session(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      campaignId: campaignId,
                      title: title,
                      date: DateTime.now(),
                      rawNotes: notes,
                      summary: null,
                      imagePath: selectedImagePath,
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
