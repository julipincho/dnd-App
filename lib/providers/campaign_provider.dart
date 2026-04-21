import 'package:flutter/foundation.dart';
import '../models/campaign.dart';
import '../services/campaign_storage.dart';

class CampaignProvider extends ChangeNotifier {
  Campaign? _activeCampaign;
  List<Campaign> _campaigns = [];

  Campaign? get activeCampaign => _activeCampaign;
  List<Campaign> get campaigns => _campaigns;

  Future<void> loadCampaigns() async {
    _campaigns = await CampaignStorage.loadCampaigns();

    final activeCampaignId = await CampaignStorage.loadActiveCampaignId();

    if (_campaigns.isEmpty) {
      _activeCampaign = null;
    } else if (activeCampaignId != null) {
      try {
        _activeCampaign = _campaigns
            .firstWhere((campaign) => campaign.id == activeCampaignId);
      } catch (_) {
        _activeCampaign = _campaigns.first;
      }
    } else {
      _activeCampaign = _campaigns.first;
    }

    notifyListeners();
  }

  Future<void> setActiveCampaign(Campaign campaign) async {
    _activeCampaign = campaign;
    await CampaignStorage.saveActiveCampaignId(campaign.id);
    notifyListeners();
  }

  Future<void> setCampaigns(List<Campaign> campaigns) async {
    _campaigns = campaigns;

    if (_campaigns.isEmpty) {
      _activeCampaign = null;
      await CampaignStorage.saveActiveCampaignId(null);
    } else if (_activeCampaign == null) {
      _activeCampaign = _campaigns.first;
      await CampaignStorage.saveActiveCampaignId(_activeCampaign!.id);
    }

    await CampaignStorage.saveCampaigns(_campaigns);
    notifyListeners();
  }

  Future<void> addCampaign(Campaign campaign) async {
    _campaigns = [..._campaigns, campaign];
    await CampaignStorage.saveCampaigns(_campaigns);
    notifyListeners();
  }

  Future<void> removeCampaign(String id) async {
    _campaigns = _campaigns.where((c) => c.id != id).toList();

    if (_activeCampaign?.id == id) {
      _activeCampaign = _campaigns.isNotEmpty ? _campaigns.first : null;
      await CampaignStorage.saveActiveCampaignId(_activeCampaign?.id);
    }

    await CampaignStorage.saveCampaigns(_campaigns);
    notifyListeners();
  }
}
