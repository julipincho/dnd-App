import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/compendium_entry.dart';
import '../providers/campaign_provider.dart';
import '../providers/compendium_provider.dart';
import '../theme.dart';
import '../utils/image_path_utils.dart';
import '../widgets/stitch_codex_ui.dart';
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
        backgroundColor: StitchCodexPalette.ground,
        appBar: StitchAppBar(
          showBrand: false,
          backgroundColor: StitchCodexPalette.ground,
          title: const Text(
            'COMPENDIUM',
            style: TextStyle(
              color: StitchCodexPalette.textPrimary,
              fontFamily: StitchTypography.display,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
        ),
        body: const StitchCodexBackground(
          child: SingleChildScrollView(
            child: StitchCodexContentWidth(
              child: StitchCodexEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No active campaign',
                message: 'Select a campaign before opening its compendium.',
              ),
            ),
          ),
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
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'COMPENDIUM',
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: StitchCodexPageHeader(
                    eyebrow: 'CAMPAIGN LORE',
                    title: activeCampaign.name,
                    subtitle:
                        'People, places, relics, factions, and discoveries gathered by the party.',
                    trailing: StitchCodexTag(
                      label: '${filteredEntries.length} ENTRIES',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 620;
                      final search = TextField(
                        style: stitchCodexFieldTextStyle,
                        cursorColor: StitchCodexPalette.bronze,
                        decoration: stitchCodexInputDecoration(
                          labelText: 'Search compendium',
                          hintText: 'Title, description or type',
                          prefixIcon: Icons.search,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      );
                      final filter = DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        dropdownColor: StitchCodexPalette.surface,
                        style: stitchCodexFieldTextStyle,
                        decoration: stitchCodexInputDecoration(
                          labelText: 'Filter by type',
                          prefixIcon: Icons.filter_alt_outlined,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
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
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      );

                      if (compact) {
                        return Column(
                          children: [
                            search,
                            const SizedBox(height: 12),
                            filter,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 2, child: search),
                          const SizedBox(width: 12),
                          Expanded(child: filter),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: filteredEntries.isEmpty
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                          child: StitchCodexEmptyState(
                            icon: Icons.auto_stories_outlined,
                            title: _searchQuery.trim().isEmpty &&
                                    _selectedType == 'all'
                                ? 'The codex is empty'
                                : 'No matching lore',
                            message: _searchQuery.trim().isEmpty &&
                                    _selectedType == 'all'
                                ? 'Create the first entry for this campaign.'
                                : 'Try another search or category.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                          itemCount: filteredEntries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = filteredEntries[index];
                            return _CompendiumEntryCard(
                              entry: entry,
                              icon: _iconForType(entry.type),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CompendiumEntryDetailScreen(
                                      entry: entry,
                                    ),
                                  ),
                                );
                              },
                              onAction: (value) async {
                                if (value == 'edit') {
                                  _showEditEntryDialog(context, entry);
                                } else if (value == 'delete') {
                                  await _confirmDeleteEntry(context, entry);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEntryDialog(context, activeCampaign.id),
        backgroundColor: StitchCodexPalette.crimson,
        foregroundColor: StitchCodexPalette.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        child: const Icon(Icons.add_rounded),
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
          backgroundColor: StitchCodexPalette.surface,
          shape: stitchCodexDialogShape(),
          title: const Text(
            'Delete entry',
            style: stitchCodexDialogTitleStyle,
          ),
          content: Text(
            'Are you sure you want to delete "${entry.title}"?',
            style: const TextStyle(
              color: StitchCodexPalette.textMuted,
              fontFamily: StitchTypography.body,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: stitchCodexPrimaryButtonStyle(),
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
              backgroundColor: StitchCodexPalette.surface,
              shape: stitchCodexDialogShape(),
              title: const Text(
                'Create entry',
                style: stitchCodexDialogTitleStyle,
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        style: stitchCodexFieldTextStyle,
                        decoration: stitchCodexInputDecoration(
                          labelText: 'Title',
                          hintText: 'Example: Vargash',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        style: stitchCodexFieldTextStyle,
                        decoration: stitchCodexInputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe this entry...',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        dropdownColor: StitchCodexPalette.surface,
                        style: stitchCodexFieldTextStyle,
                        decoration: stitchCodexInputDecoration(
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
                              style: stitchCodexOutlineButtonStyle(),
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
                  style: stitchCodexPrimaryButtonStyle(),
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
              backgroundColor: StitchCodexPalette.surface,
              shape: stitchCodexDialogShape(),
              title: const Text(
                'Edit entry',
                style: stitchCodexDialogTitleStyle,
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        style: stitchCodexFieldTextStyle,
                        decoration: stitchCodexInputDecoration(
                          labelText: 'Title',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        style: stitchCodexFieldTextStyle,
                        decoration: stitchCodexInputDecoration(
                          labelText: 'Description',
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        dropdownColor: StitchCodexPalette.surface,
                        style: stitchCodexFieldTextStyle,
                        decoration: stitchCodexInputDecoration(
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
                              style: stitchCodexOutlineButtonStyle(),
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
                  style: stitchCodexPrimaryButtonStyle(),
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

class _CompendiumEntryCard extends StatelessWidget {
  final CompendiumEntry entry;
  final IconData icon;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  const _CompendiumEntryCard({
    required this.entry,
    required this.icon,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = hasDisplayableImagePath(entry.imagePath);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StitchCodexPalette.surfaceMuted,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: StitchCodexPalette.bronze.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 66,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: StitchCodexPalette.surface,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: StitchCodexPalette.bronze.withValues(alpha: 0.28),
                  ),
                ),
                child: hasImage
                    ? buildImageFromPath(
                        entry.imagePath!,
                        width: 58,
                        height: 66,
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        icon,
                        color: StitchCodexPalette.bronze,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: StitchCodexPalette.textPrimary,
                              fontFamily: StitchTypography.display,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StitchCodexTag(
                          label: entry.type.toUpperCase(),
                          color: _colorForCompendiumType(entry.type),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StitchCodexPalette.textMuted,
                        fontFamily: StitchTypography.body,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                color: StitchCodexPalette.surface,
                iconColor: StitchCodexPalette.textMuted,
                onSelected: onAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForCompendiumType(String type) {
    switch (type) {
      case 'npc':
        return StitchCodexPalette.crimsonBright;
      case 'location':
        return const Color(0xFF5C7EA8);
      case 'item':
        return StitchCodexPalette.bronze;
      case 'faction':
        return const Color(0xFF7B68C8);
      case 'lore':
        return StitchCodexPalette.success;
      default:
        return StitchCodexPalette.textMuted;
    }
  }
}
