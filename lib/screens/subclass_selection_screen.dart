import 'package:flutter/material.dart';

import '../widgets/stitch_navigation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/dnd_class.dart';
import '../services/class_data_service.dart';
import '../screens/subclass_detail_screen.dart';
import '../theme.dart';
import '../widgets/stitch_codex_ui.dart';

class SubclassSelectionScreen extends StatefulWidget {
  final String classIndex;

  const SubclassSelectionScreen({
    super.key,
    required this.classIndex,
  });

  @override
  State<SubclassSelectionScreen> createState() =>
      _SubclassSelectionScreenState();
}

class _SubclassSelectionScreenState extends State<SubclassSelectionScreen> {
  DndClass? _cls;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cls = await ClassDataService.loadClass(widget.classIndex);
    if (!mounted) return;

    setState(() {
      _cls = cls;
      _loading = false;
    });
  }

  Future<ImageProvider?> _loadSubclassImage(String subName) async {
    final fileName = subName.toLowerCase().replaceAll(" ", "-");
    final path = "assets/images/subclasses/$fileName.png";

    try {
      await rootBundle.load(path);
      return AssetImage(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _cls == null) {
      return const Scaffold(
        backgroundColor: StitchCodexPalette.ground,
        body: StitchCodexBackground(
          child: Center(
            child: CircularProgressIndicator(
              color: StitchCodexPalette.bronze,
            ),
          ),
        ),
      );
    }

    final subs = _cls!.subclasses;

    return Scaffold(
      backgroundColor: StitchCodexPalette.ground,
      appBar: StitchAppBar(
        showBrand: false,
        backgroundColor: StitchCodexPalette.ground,
        title: const Text(
          'CHOOSE SUBCLASS',
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
        child: ListView.builder(
          itemCount: subs.length + 1,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: StitchCodexPageHeader(
                  eyebrow: 'SPECIALIZATION · ${_cls!.name.toUpperCase()}',
                  title: 'Choose your path',
                  subtitle:
                      'A subclass defines the tradition and specialized talents your hero develops.',
                ),
              );
            }
            final sub = subs[i - 1];

            return FutureBuilder<ImageProvider?>(
              future: _loadSubclassImage(sub.name),
              builder: (_, snapshot) {
                final img = snapshot.data;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(2),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubclassDetailScreen(
                              classIndex: _cls!.index,
                              subclassName: sub.name,
                            ),
                          ),
                        );
                      },
                      child: Ink(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: StitchCodexPalette.surfaceMuted,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: StitchCodexPalette.bronze
                                .withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: img != null
                                  ? Image(
                                      image: img,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 70,
                                      height: 70,
                                      color: StitchCodexPalette.surface,
                                      child: const Icon(
                                        Icons.menu_book_outlined,
                                        color: StitchCodexPalette.bronze,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sub.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontFamily: StitchTypography.display,
                                      fontWeight: FontWeight.w600,
                                      color: StitchCodexPalette.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    sub.description?.isNotEmpty == true
                                        ? sub.description!
                                        : "No description available.",
                                    maxLines: 4,
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
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
