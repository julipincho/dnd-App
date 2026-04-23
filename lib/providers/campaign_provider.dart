import 'package:flutter/foundation.dart';

import '../models/campaign.dart';
import '../services/campaign_cloud_repository.dart';
import '../services/campaign_storage.dart';

class CampaignProvider extends ChangeNotifier {
  final CampaignCloudRepository _cloudRepo = CampaignCloudRepository();

  List<Campaign> _campaigns = [];
  Campaign? _activeCampaign;
  String? _activeUserId;

  List<Campaign> get campaigns => _campaigns;
  Campaign? get activeCampaign => _activeCampaign;
  String? get activeUserId => _activeUserId;

  Future<void> loadCampaigns([String? userId]) async {
    final resolvedUserId = userId ?? _activeUserId;
    if (resolvedUserId == null || resolvedUserId.isEmpty) return;

    _activeUserId = resolvedUserId;
    _campaigns = await _cloudRepo.getCampaignsByUser(resolvedUserId);

    final savedActiveCampaignId = await CampaignStorage.loadActiveCampaignId();

    if (_activeCampaign != null) {
      final index = _campaigns.indexWhere((c) => c.id == _activeCampaign!.id);
      _activeCampaign = index != -1 ? _campaigns[index] : null;
    }

    if (_activeCampaign == null &&
        savedActiveCampaignId != null &&
        savedActiveCampaignId.isNotEmpty) {
      try {
        _activeCampaign =
            _campaigns.firstWhere((c) => c.id == savedActiveCampaignId);
      } catch (_) {
        _activeCampaign = null;
      }
    }

    if (_activeCampaign == null && _campaigns.isNotEmpty) {
      _activeCampaign = _campaigns.first;
    }

    notifyListeners();
  }

  Future<void> addCampaign(Campaign campaign, String userId) async {
    final cloudCampaign = campaign.copyWith(
      ownerUserId: userId,
      memberUserIds: [userId],
    );

    _activeUserId = userId;
    await _cloudRepo.saveCampaign(cloudCampaign);
    await loadCampaigns(userId);
    await setActiveCampaignById(cloudCampaign.id);
  }

  Future<void> deleteCampaignById(String campaignId) async {
    final userId = _activeUserId;
    if (userId == null) return;

    await _cloudRepo.deleteCampaign(campaignId);

    if (_activeCampaign?.id == campaignId) {
      _activeCampaign = null;
    }

    await loadCampaigns(userId);
  }

  Future<void> joinCampaign(String campaignId, String userId) async {
    _activeUserId = userId;
    await _cloudRepo.joinCampaign(
      campaignId: campaignId,
      userId: userId,
    );
    await loadCampaigns(userId);
    await setActiveCampaignById(campaignId);
  }

  Future<void> setActiveCampaign(Campaign campaign) async {
    _activeCampaign = campaign;
    await CampaignStorage.saveActiveCampaignId(campaign.id);
    notifyListeners();
  }

  Future<void> setActiveCampaignById(String campaignId) async {
    try {
      _activeCampaign = _campaigns.firstWhere((c) => c.id == campaignId);
      await CampaignStorage.saveActiveCampaignId(_activeCampaign!.id);
    } catch (_) {
      _activeCampaign = null;
      await CampaignStorage.saveActiveCampaignId(null);
    }
    notifyListeners();
  }

  Future<void> clearActiveCampaign() async {
    _activeCampaign = null;
    await CampaignStorage.saveActiveCampaignId(null);
    notifyListeners();
  }
}
