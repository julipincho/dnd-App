import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/compendium_entry.dart';
import '../providers/campaign_provider.dart';
import '../providers/compendium_provider.dart';
import 'compendium_entry_detail_screen.dart';

class CompendiumScreen extends StatefulWidget {
  const CompendiumScreen({super.key});

  @override
  State<CompendiumScreen> createState() => _CompendiumScreenState();
}

class _CompendiumScreenState extends State<CompendiumScreen> {
  bool _didLoad = false;
  String _selectedType = 'all';
  String _searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didLoad) {
      _didLoad = true;
      context.read<CompendiumProvider>().loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignProvider = context.watch<CampaignProvider>();
    final compendiumProvider = context.watch<CompendiumProvider>();
    final activeCampaign = campaignProvider.activeCampaign;

    if (activeCampaign == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Compendium'),
        ),
        body: const Center(
          child: Text('No active campaign selected'),
        ),
      );
    }

    final allEntries = compendiumProvider
        .getEntriesByCampaign(activeCampaign.id)
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final typeFilteredEntries = _selectedType == 'all'
        ? allEntries
        : allEntries.where((entry) => entry.type == _selectedType).toList();

    final filteredEntries = _searchQuery.trim().isEmpty
        ? typeFilteredEntries
        : typeFilteredEntries.where((entry) {
            final query = _searchQuery.toLowerCase().trim();

            return entry.title.toLowerCase().contains(query) ||
                entry.description.toLowerCase().contains(query) ||
                entry.type.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${activeCampaign.name} Compendium'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search compendium',
                hintText: 'Search by title, description or type',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Filter by type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All'),
                ),
                DropdownMenuItem(
                  value: 'npc',
                  child: Text('NPC'),
                ),
                DropdownMenuItem(
                  value: 'location',
                  child: Text('Location'),
                ),
                DropdownMenuItem(
                  value: 'item',
                  child: Text('Item'),
                ),
                DropdownMenuItem(
                  value: 'faction',
                  child: Text('Faction'),
                ),
                DropdownMenuItem(
                  value: 'lore',
                  child: Text('Lore'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedType = value;
                });
              },
            ),
          ),
          Expanded(
            child: filteredEntries.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.trim().isEmpty && _selectedType == 'all'
                          ? 'No compendium entries yet'
                          : 'No matching entries found',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: (entry.imagePath != null &&
                                  entry.imagePath!.isNotEmpty &&
                                  File(entry.imagePath!).existsSync())
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(entry.imagePath!),
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : CircleAvatar(
                                  child: Icon(_iconForType(entry.type)),
                                ),
                          title: Text(entry.title),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CompendiumEntryDetailScreen(entry: entry),
                              ),
                            );
                          },
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Chip(
                                  label: Text(entry.type),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  entry.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _showEditEntryDialog(context, entry);
                              } else if (value == 'delete') {
                                await _confirmDeleteEntry(context, entry);
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEntryDialog(context, activeCampaign.id),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<String?> _pickCompendiumImage() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      return pickedFile?.path;
    } catch (e) {
      debugPrint('Error picking compendium image: $e');
      return null;
    }
  }

  Future<void> _confirmDeleteEntry(
    BuildContext context,
    CompendiumEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete entry'),
          content: Text(
            'Are you sure you want to delete "${entry.title}"?',
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

    await context.read<CompendiumProvider>().removeEntry(entry.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry deleted')),
    );
  }

  void _showCreateEntryDialog(BuildContext context, String campaignId) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'npc';
    String? selectedImagePath;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create entry'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
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
                          DropdownMenuItem(
                            value: 'npc',
                            child: Text('NPC'),
                          ),
                          DropdownMenuItem(
                            value: 'location',
                            child: Text('Location'),
                          ),
                          DropdownMenuItem(
                            value: 'item',
                            child: Text('Item'),
                          ),
                          DropdownMenuItem(
                            value: 'faction',
                            child: Text('Faction'),
                          ),
                          DropdownMenuItem(
                            value: 'lore',
                            child: Text('Lore'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickCompendiumImage();
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
                            width: double.infinity,
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
                    final description = descriptionController.text.trim();

                    if (title.isEmpty || description.isEmpty) return;

                    final entry = CompendiumEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      campaignId: campaignId,
                      title: title,
                      description: description,
                      type: selectedType,
                      imagePath: selectedImagePath,
                      createdAt: DateTime.now(),
                    );

                    await dialogContext
                        .read<CompendiumProvider>()
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

  void _showEditEntryDialog(BuildContext context, CompendiumEntry entry) {
    final titleController = TextEditingController(text: entry.title);
    final descriptionController =
        TextEditingController(text: entry.description);
    String selectedType = entry.type;
    String? selectedImagePath = entry.imagePath;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit entry'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
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
                          DropdownMenuItem(
                            value: 'npc',
                            child: Text('NPC'),
                          ),
                          DropdownMenuItem(
                            value: 'location',
                            child: Text('Location'),
                          ),
                          DropdownMenuItem(
                            value: 'item',
                            child: Text('Item'),
                          ),
                          DropdownMenuItem(
                            value: 'faction',
                            child: Text('Faction'),
                          ),
                          DropdownMenuItem(
                            value: 'lore',
                            child: Text('Lore'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickCompendiumImage();
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
                            width: double.infinity,
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
                    final description = descriptionController.text.trim();

                    if (title.isEmpty || description.isEmpty) return;

                    final updatedEntry = entry.copyWith(
                      title: title,
                      description: description,
                      type: selectedType,
                      imagePath: selectedImagePath,
                    );

                    await dialogContext
                        .read<CompendiumProvider>()
                        .updateEntry(updatedEntry);

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
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

  IconData _iconForType(String type) {
    switch (type) {
      case 'location':
        return Icons.place_outlined;
      case 'item':
        return Icons.inventory_2_outlined;
      case 'faction':
        return Icons.shield_outlined;
      case 'lore':
        return Icons.auto_stories_outlined;
      case 'npc':
      default:
        return Icons.person_outline;
    }
  }
}
