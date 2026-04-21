import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/dnd_class.dart';
import '../models/subclass_progress_feature.dart';

class SubclassProgressFeature {
  final String name;
  final int level;
  final String description;

  SubclassProgressFeature({
    required this.name,
    required this.level,
    required this.description,
  });
}
