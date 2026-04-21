import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/feat_data.dart';

class FeatDataService {
  static List<FeatData>? _cache;

  static const String _assetPath = 'assets/data/feats_2014_clean.json';

  static Future<List<FeatData>> loadFeats() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as List<dynamic>;

    _cache = decoded
        .whereType<Map>()
        .map((e) => FeatData.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    _cache!.sort((a, b) => a.name.compareTo(b.name));
    return _cache!;
  }

  static Future<FeatData?> getFeatById(String featId) async {
    final feats = await loadFeats();
    for (final feat in feats) {
      if (feat.id == featId) return feat;
    }
    return null;
  }

  static Future<List<FeatData>> getFeatsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final feats = await loadFeats();
    final idSet = ids.toSet();
    return feats.where((f) => idSet.contains(f.id)).toList();
  }
}
