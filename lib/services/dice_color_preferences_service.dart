import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

class DiceColorPreferencesService {
  DiceColorPreferencesService._();

  static const defaultKey = 'stitch.dice.color';
  static const defaultColor = Color(0xFF7DD3FC);
  static const palette = <Color>[
    Color(0xFF7DD3FC),
    Color(0xFF64F4A2),
    Color(0xFFFFB454),
    Color(0xFFFF5C6C),
    Color(0xFFB85CFF),
    Color(0xFFFFD166),
  ];

  static Future<Color> loadColor({String key = defaultKey}) async {
    final preferences = await SharedPreferences.getInstance();
    return colorFromHex(preferences.getString(key)) ?? defaultColor;
  }

  static Future<void> saveColor(
    Color color, {
    String key = defaultKey,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, colorToHex(color));
  }

  static String colorToHex(Color color) {
    final argb = colorToArgb(color).toRadixString(16).padLeft(8, '0');
    return '#${argb.substring(2).toUpperCase()}';
  }

  static int colorToArgb(Color color) {
    final alpha = (color.a * 255).round() & 0xFF;
    final red = (color.r * 255).round() & 0xFF;
    final green = (color.g * 255).round() & 0xFF;
    final blue = (color.b * 255).round() & 0xFF;
    return (alpha << 24) | (red << 16) | (green << 8) | blue;
  }

  static Color? colorFromHex(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final normalized = raw.startsWith('#') ? raw.substring(1) : raw;
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(normalized)) {
      return null;
    }

    final argb = normalized.length == 6 ? 'FF$normalized' : normalized;
    final parsed = int.tryParse(argb, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
