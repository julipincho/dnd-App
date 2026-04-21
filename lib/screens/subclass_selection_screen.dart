import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/dnd_class.dart';
import '../services/class_data_service.dart';
import '../screens/subclass_detail_screen.dart';

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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final subs = _cls!.subclasses;

    return Scaffold(
      backgroundColor: const Color(0xFF2B1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3C2A2A),
        title: Text("Choose ${_cls!.name} Subclass"),
      ),
      body: ListView.builder(
        itemCount: subs.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, i) {
          final sub = subs[i];

          return FutureBuilder<ImageProvider?>(
            future: _loadSubclassImage(sub.name),
            builder: (_, snapshot) {
              final img = snapshot.data;

              return GestureDetector(
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
                child: Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurpleAccent),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
                                color: Colors.black26,
                                child: const Icon(
                                  Icons.menu_book,
                                  color: Colors.white38,
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
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
