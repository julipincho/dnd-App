import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/battle_scene.dart';
import '../models/board_token.dart';

class BattleBoardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _scenesCollection(
    String campaignId,
  ) {
    return _firestore
        .collection('campaigns')
        .doc(campaignId)
        .collection('scenes');
  }

  CollectionReference<Map<String, dynamic>> _tokensCollection({
    required String campaignId,
    required String sceneId,
  }) {
    return _scenesCollection(campaignId).doc(sceneId).collection('tokens');
  }

  Future<List<BattleScene>> getScenes(String campaignId) async {
    final snapshot = await _scenesCollection(campaignId).get();

    return snapshot.docs
        .map((doc) => BattleScene.fromJson(doc.data()))
        .toList();
  }

  Stream<BattleScene?> watchScene({
    required String campaignId,
    required String sceneId,
  }) {
    return _scenesCollection(campaignId).doc(sceneId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return BattleScene.fromJson(data);
    });
  }

  Stream<List<BoardToken>> watchTokens({
    required String campaignId,
    required String sceneId,
  }) {
    return _tokensCollection(campaignId: campaignId, sceneId: sceneId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BoardToken.fromJson(doc.data()))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
        );
  }

  Future<void> saveScene(BattleScene scene) async {
    await _scenesCollection(scene.campaignId).doc(scene.id).set(scene.toJson());
  }

  Future<void> deleteScene({
    required String campaignId,
    required String sceneId,
  }) async {
    await _scenesCollection(campaignId).doc(sceneId).delete();
  }

  Future<void> saveToken({
    required String campaignId,
    required BoardToken token,
  }) async {
    await _tokensCollection(
      campaignId: campaignId,
      sceneId: token.sceneId,
    ).doc(token.id).set(token.toJson());
  }

  Future<void> deleteToken({
    required String campaignId,
    required String sceneId,
    required String tokenId,
  }) async {
    await _tokensCollection(
      campaignId: campaignId,
      sceneId: sceneId,
    ).doc(tokenId).delete();
  }
}
