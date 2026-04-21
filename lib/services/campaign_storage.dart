import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign.dart';

class CampaignStorage {
  static const String _campaignsKey = 'campaigns';
  static const String _activeCampaignIdKey = 'active_campaign_id';

  static Future<void> saveCampaigns(List<Campaign> campaigns) async {
    final prefs = await SharedPreferences.getInstance();
    final campaignsJson =
        campaigns.map((campaign) => jsonEncode(campaign.toJson())).toList();

    await prefs.setStringList(_campaignsKey, campaignsJson);
  }

  static Future<List<Campaign>> loadCampaigns() async {
    final prefs = await SharedPreferences.getInstance();
    final campaignsJson = prefs.getStringList(_campaignsKey) ?? [];

    return campaignsJson
        .map((item) => Campaign.fromJson(jsonDecode(item)))
        .toList();
  }

  static Future<void> saveActiveCampaignId(String? campaignId) async {
    final prefs = await SharedPreferences.getInstance();

    if (campaignId == null) {
      await prefs.remove(_activeCampaignIdKey);
      return;
    }

    await prefs.setString(_activeCampaignIdKey, campaignId);
  }

  static Future<String?> loadActiveCampaignId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeCampaignIdKey);
  }
}
