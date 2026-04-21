import 'package:flutter/foundation.dart';
import '../models/campaign_event.dart';
import '../services/campaign_event_storage.dart';

class CampaignEventProvider extends ChangeNotifier {
  List<CampaignEvent> _events = [];

  List<CampaignEvent> get events => _events;

  Future<void> loadEvents() async {
    _events = await CampaignEventStorage.loadEvents();
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
    await CampaignEventStorage.saveEvents(_events);
    notifyListeners();
  }

  Future<void> updateEvent(CampaignEvent updatedEvent) async {
    _events = _events
        .map((event) => event.id == updatedEvent.id ? updatedEvent : event)
        .toList();

    await CampaignEventStorage.saveEvents(_events);
    notifyListeners();
  }

  Future<void> removeEvent(String eventId) async {
    _events = _events.where((event) => event.id != eventId).toList();
    await CampaignEventStorage.saveEvents(_events);
    notifyListeners();
  }
}
