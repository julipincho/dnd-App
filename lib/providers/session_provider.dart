import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/session_storage.dart';

class SessionProvider extends ChangeNotifier {
  List<Session> _sessions = [];

  List<Session> get sessions => _sessions;

  Future<void> loadSessions() async {
    _sessions = await SessionStorage.loadSessions();
    notifyListeners();
  }

  List<Session> getSessionsByCampaign(String campaignId) {
    return _sessions
        .where((session) => session.campaignId == campaignId)
        .toList();
  }

  Future<void> addSession(Session session) async {
    _sessions = [..._sessions, session];
    await SessionStorage.saveSessions(_sessions);
    notifyListeners();
  }

  Future<void> updateSession(Session updatedSession) async {
    _sessions = _sessions
        .map((session) =>
            session.id == updatedSession.id ? updatedSession : session)
        .toList();

    await SessionStorage.saveSessions(_sessions);
    notifyListeners();
  }

  Future<void> removeSession(String sessionId) async {
    _sessions = _sessions.where((session) => session.id != sessionId).toList();
    await SessionStorage.saveSessions(_sessions);
    notifyListeners();
  }
}
