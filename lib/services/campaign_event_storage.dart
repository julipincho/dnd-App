import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_event.dart';

class CampaignEventStorage {
  static const String _eventsKey = 'campaign_events';

  static Future<void> saveEvents(List<CampaignEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson =
        events.map((event) => jsonEncode(event.toJson())).toList();

    await prefs.setStringList(_eventsKey, eventsJson);
  }

  static Future<List<CampaignEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getStringList(_eventsKey) ?? [];

    return eventsJson
        .map((item) => CampaignEvent.fromJson(jsonDecode(item)))
        .toList();
  }
}
