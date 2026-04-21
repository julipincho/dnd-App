import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

class SessionStorage {
  static const String _sessionsKey = 'sessions';

  static Future<void> saveSessions(List<Session> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson =
        sessions.map((session) => jsonEncode(session.toJson())).toList();

    await prefs.setStringList(_sessionsKey, sessionsJson);
  }

  static Future<List<Session>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getStringList(_sessionsKey) ?? [];

    return sessionsJson
        .map((item) => Session.fromJson(jsonDecode(item)))
        .toList();
  }
}
