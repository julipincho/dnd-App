import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/character.dart';

class CharacterStorage {
  static const String key = "saved_characters";

  /// Notifica a la UI cada vez que cambia la lista.
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  // ============================================================
  // AGREGAR PERSONAJE
  // ============================================================
  static Future<void> addCharacter(Character character) async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getStringList(key) ?? [];
    final jsonStr = jsonEncode(character.toJson());

    existing.add(jsonStr);

    await prefs.setStringList(key, existing);
    refreshNotifier.value++;
  }

  // ============================================================
  // CARGAR PERSONAJES
  // ============================================================
  static Future<List<Character>> getCharacters() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.reload();
    final rawList = prefs.getStringList(key) ?? [];

    final List<Character> characters = [];

    for (final jsonStr in rawList) {
      try {
        final map = jsonDecode(jsonStr);
        characters.add(Character.fromJson(map));
      } catch (e) {
        debugPrint("❌ Error decoding saved character → $e");
      }
    }

    return characters;
  }

  // ============================================================
  // OBTENER PERSONAJE POR ID
  // ============================================================
  static Future<Character?> getCharacterById(String id) async {
    final characters = await getCharacters();

    try {
      return characters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ACTUALIZAR PERSONAJE POR ID
  // ============================================================
  static Future<void> updateCharacterById(String id, Character updated) async {
    final prefs = await SharedPreferences.getInstance();
    final characters = await getCharacters();

    final index = characters.indexWhere((c) => c.id == id);
    if (index == -1) return;

    characters[index] = updated;

    final encodedList =
        characters.map((character) => jsonEncode(character.toJson())).toList();

    await prefs.setStringList(key, encodedList);
    refreshNotifier.value++;
  }

  // ============================================================
  // ELIMINAR PERSONAJE POR ID
  // ============================================================
  static Future<void> deleteCharacterById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final characters = await getCharacters();

    characters.removeWhere((c) => c.id == id);

    final encodedList =
        characters.map((character) => jsonEncode(character.toJson())).toList();

    await prefs.setStringList(key, encodedList);
    refreshNotifier.value++;
  }

  // ============================================================
  // BORRAR TODO
  // ============================================================
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    refreshNotifier.value++;
  }
}
