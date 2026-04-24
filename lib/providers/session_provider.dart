import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/session_cloud_repository.dart';
import '../services/session_storage.dart';

class SessionProvider extends ChangeNotifier {
  final SessionCloudRepository _cloudRepo = SessionCloudRepository();

  List<Session> _sessions = [];
  String? _activeCampaignId;

  List<Session> get sessions => _sessions;

  Future<void> loadSessions([String? campaignId]) async {
    _activeCampaignId = campaignId ?? _activeCampaignId;

    if (_activeCampaignId != null && _activeCampaignId!.isNotEmpty) {
      _sessions = await _cloudRepo.getSessionsByCampaign(_activeCampaignId!);
    } else {
      _sessions = await SessionStorage.loadSessions();
    }

    notifyListeners();
  }

  List<Session> getSessionsByCampaign(String campaignId) {
    return _sessions
        .where((session) => session.campaignId == campaignId)
        .toList();
  }

  Future<void> addSession(Session session) async {
    _sessions = [..._sessions, session];
    if (session.campaignId.isNotEmpty) {
      await _cloudRepo.saveSession(session);
      _activeCampaignId = session.campaignId;
    } else {
      await SessionStorage.saveSessions(_sessions);
    }
    notifyListeners();
  }

  Future<void> updateSession(Session updatedSession) async {
    _sessions = _sessions
        .map((session) =>
            session.id == updatedSession.id ? updatedSession : session)
        .toList();

    if (updatedSession.campaignId.isNotEmpty) {
      await _cloudRepo.saveSession(updatedSession);
      _activeCampaignId = updatedSession.campaignId;
    } else {
      await SessionStorage.saveSessions(_sessions);
    }
    notifyListeners();
  }

  Future<void> removeSession(String sessionId) async {
    Session? deleted;
    for (final session in _sessions) {
      if (session.id == sessionId) {
        deleted = session;
        break;
      }
    }

    _sessions = _sessions.where((session) => session.id != sessionId).toList();
    if (deleted != null && deleted.campaignId.isNotEmpty) {
      await _cloudRepo.deleteSession(sessionId);
    } else {
      await SessionStorage.saveSessions(_sessions);
    }
    notifyListeners();
  }
}
