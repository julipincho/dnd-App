import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/battle_scene.dart';
import '../models/board_token.dart';
import '../services/battle_board_repository.dart';

class BattleBoardProvider extends ChangeNotifier {
  final BattleBoardRepository _repository = BattleBoardRepository();

  List<BattleScene> _scenes = [];
  BattleScene? _activeScene;
  List<BoardToken> _tokens = [];
  String? _activeCampaignId;
  String? _activeSceneId;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<BattleScene?>? _sceneSubscription;
  StreamSubscription<List<BoardToken>>? _tokenSubscription;

  List<BattleScene> get scenes => _scenes;
  BattleScene? get activeScene => _activeScene;
  List<BoardToken> get tokens => _tokens;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadScenes(String campaignId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _scenes = await _repository.getScenes(campaignId);
      _activeCampaignId = campaignId;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void watchScene({
    required String campaignId,
    required String sceneId,
  }) {
    if (_activeCampaignId == campaignId && _activeSceneId == sceneId) return;

    _sceneSubscription?.cancel();
    _tokenSubscription?.cancel();

    _activeCampaignId = campaignId;
    _activeSceneId = sceneId;
    _activeScene = null;
    _tokens = [];
    _error = null;
    notifyListeners();

    _sceneSubscription =
        _repository.watchScene(campaignId: campaignId, sceneId: sceneId).listen(
      (scene) {
        _activeScene = scene;
        notifyListeners();
      },
      onError: (Object error) {
        _error = error.toString();
        notifyListeners();
      },
    );

    _tokenSubscription = _repository
        .watchTokens(campaignId: campaignId, sceneId: sceneId)
        .listen(
      (tokens) {
        _tokens = tokens;
        notifyListeners();
      },
      onError: (Object error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  Future<BattleScene> createScene({
    required String campaignId,
    required String name,
    String mapImageUrl = '',
    int gridSize = 64,
    int gridColumns = 24,
    int gridRows = 16,
    bool combatActive = true,
  }) async {
    final scene = BattleScene.create(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      campaignId: campaignId,
      name: name,
      mapImageUrl: mapImageUrl,
      gridSize: gridSize,
      gridColumns: gridColumns,
      gridRows: gridRows,
      combatActive: combatActive,
    );

    await saveScene(scene);
    return scene;
  }

  Future<void> saveScene(BattleScene scene) async {
    final updatedScene = scene.copyWith(updatedAt: DateTime.now());
    await _repository.saveScene(updatedScene);
    _activeCampaignId = updatedScene.campaignId;
    _scenes = [
      ..._scenes.where((item) => item.id != updatedScene.id),
      updatedScene,
    ];
    if (_activeScene?.id == updatedScene.id) {
      _activeScene = updatedScene;
    }
    notifyListeners();
  }

  Future<void> saveToken({
    required String campaignId,
    required BoardToken token,
  }) async {
    await _repository.saveToken(
      campaignId: campaignId,
      token: token.copyWith(updatedAt: DateTime.now()),
    );
  }

  Future<void> moveToken({
    required String campaignId,
    required BoardToken token,
    required int x,
    required int y,
  }) async {
    await saveToken(
      campaignId: campaignId,
      token: token.copyWith(x: x, y: y),
    );
  }

  Future<void> deleteToken({
    required String campaignId,
    required String sceneId,
    required String tokenId,
  }) async {
    await _repository.deleteToken(
      campaignId: campaignId,
      sceneId: sceneId,
      tokenId: tokenId,
    );
  }

  Future<void> replaceSceneTokens({
    required String campaignId,
    required String sceneId,
    required List<BoardToken> tokens,
  }) async {
    final existingTokens = _tokens.where((token) => token.sceneId == sceneId);
    for (final token in existingTokens) {
      await deleteToken(
        campaignId: campaignId,
        sceneId: sceneId,
        tokenId: token.id,
      );
    }

    for (final token in tokens) {
      await saveToken(campaignId: campaignId, token: token);
    }
  }

  @override
  void dispose() {
    _sceneSubscription?.cancel();
    _tokenSubscription?.cancel();
    super.dispose();
  }
}
