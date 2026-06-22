import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/campaign.dart';
import '../services/campaign_cloud_repository.dart';
import '../services/campaign_storage.dart';

class CampaignProvider extends ChangeNotifier {
  final CampaignCloudRepository _cloudRepo = CampaignCloudRepository();

  List<Campaign> _campaigns = [];
  Campaign? _activeCampaign;
  String? _activeUserId;
  bool _isLoading = false;
  String? _errorMessage;

  List<Campaign> get campaigns => _campaigns;
  Campaign? get activeCampaign => _activeCampaign;
  String? get activeUserId => _activeUserId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCampaigns([String? userId]) async {
    final resolvedUserId = userId ?? _activeUserId;
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      _activeUserId = null;
      _campaigns = [];
      _activeCampaign = null;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    final switchedUser =
        _activeUserId != null && _activeUserId != resolvedUserId;
    _activeUserId = resolvedUserId;
    _isLoading = true;
    _errorMessage = null;
    if (switchedUser) {
      _campaigns = [];
      _activeCampaign = null;
    }
    notifyListeners();

    try {
      final loadedCampaigns = await _cloudRepo.getCampaignsByUser(
        resolvedUserId,
      );
      await _applyLoadedCampaigns(loadedCampaigns);
    } catch (e, st) {
      _errorMessage = _friendlyError(e);
      debugPrint('CampaignProvider.loadCampaigns ERROR: $e');
      debugPrint('$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _applyLoadedCampaigns(List<Campaign> loadedCampaigns) async {
    _campaigns = loadedCampaigns.where((c) => c.id.isNotEmpty).toList();

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
  }

  Future<bool> addCampaign(Campaign campaign, String userId) async {
    final cloudCampaign = campaign.copyWith(
      ownerUserId: userId,
      memberUserIds: [userId],
    );

    _activeUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _cloudRepo.saveCampaign(cloudCampaign);
      final loadedCampaigns = await _cloudRepo.getCampaignsByUser(userId);
      await _applyLoadedCampaigns(loadedCampaigns);
      await setActiveCampaignById(cloudCampaign.id);
      return true;
    } catch (e, st) {
      _errorMessage = _friendlyError(e);
      debugPrint('CampaignProvider.addCampaign ERROR: $e');
      debugPrint('$st');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  Future<bool> joinCampaign(String campaignId, String userId) async {
    _activeUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final joinedCampaign = await _cloudRepo.joinCampaign(
        campaignId: campaignId,
        userId: userId,
      );
      final loadedCampaigns = await _cloudRepo.getCampaignsByUser(userId);
      await _applyLoadedCampaigns(loadedCampaigns);

      if (!_campaigns.any((c) => c.id == joinedCampaign.id)) {
        _campaigns = [joinedCampaign, ..._campaigns];
      }
      await setActiveCampaignById(joinedCampaign.id);
      return true;
    } catch (e, st) {
      _errorMessage = _friendlyError(e);
      debugPrint('CampaignProvider.joinCampaign ERROR: $e');
      debugPrint('$st');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firestore denied access to this campaign. Check campaign membership or security rules.';
        case 'not-found':
          return 'Campaign not found. Check the campaign ID and try again.';
        case 'unavailable':
          return 'Firestore is unavailable right now. Check your connection and try again.';
        default:
          return error.message ?? 'Could not load campaigns from Firestore.';
      }
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid campaign request.';
    }

    return 'Could not load campaigns from Firestore.';
  }
}
