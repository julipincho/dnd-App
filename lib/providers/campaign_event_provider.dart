import 'package:flutter/foundation.dart';
import '../models/campaign_event.dart';
import '../services/campaign_event_cloud_repository.dart';
import '../services/campaign_event_storage.dart';

class CampaignEventProvider extends ChangeNotifier {
  final CampaignEventCloudRepository _cloudRepo = CampaignEventCloudRepository();

  List<CampaignEvent> _events = [];
  String? _activeCampaignId;

  List<CampaignEvent> get events => _events;

  Future<void> loadEvents([String? campaignId]) async {
    _activeCampaignId = campaignId ?? _activeCampaignId;

    if (_activeCampaignId != null && _activeCampaignId!.isNotEmpty) {
      _events = await _cloudRepo.getEventsByCampaign(_activeCampaignId!);
    } else {
      _events = await CampaignEventStorage.loadEvents();
    }

    notifyListeners();
  }

  List<CampaignEvent> getEventsByCampaign(String campaignId) {
    return _events.where((event) => event.campaignId == campaignId).toList();
  }

  List<CampaignEvent> getEventsBySession(String sessionId) {
    return _events.where((event) => event.sessionId == sessionId).toList();
  }

  Future<void> addEvent(CampaignEvent event) async {
    _events = [..._events, event];
    if (event.campaignId.isNotEmpty) {
      await _cloudRepo.saveEvent(event);
      _activeCampaignId = event.campaignId;
    } else {
      await CampaignEventStorage.saveEvents(_events);
    }
    notifyListeners();
  }

  Future<void> updateEvent(CampaignEvent updatedEvent) async {
    _events = _events
        .map((event) => event.id == updatedEvent.id ? updatedEvent : event)
        .toList();

    if (updatedEvent.campaignId.isNotEmpty) {
      await _cloudRepo.saveEvent(updatedEvent);
      _activeCampaignId = updatedEvent.campaignId;
    } else {
      await CampaignEventStorage.saveEvents(_events);
    }
    notifyListeners();
  }

  Future<void> removeEvent(String eventId) async {
    CampaignEvent? deleted;
    for (final event in _events) {
      if (event.id == eventId) {
        deleted = event;
        break;
      }
    }

    _events = _events.where((event) => event.id != eventId).toList();
    if (deleted != null && deleted.campaignId.isNotEmpty) {
      await _cloudRepo.deleteEvent(eventId);
    } else {
      await CampaignEventStorage.saveEvents(_events);
    }
    notifyListeners();
  }
}
