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

  Future<bool> claimDiceRollEvent({
    required String campaignId,
    required BoardToken token,
    required String ownerId,
    Duration lockDuration = const Duration(seconds: 12),
  }) async {
    if (token.lastEventId.isEmpty || ownerId.isEmpty) return false;

    final docRef = _tokensCollection(
      campaignId: campaignId,
      sceneId: token.sceneId,
    ).doc(token.id);

    return _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (data == null) return false;
      if (data['lastEventId']?.toString() != token.lastEventId) return false;
      if (_intList(data['lastEventRollValues']).isNotEmpty) return false;

      final now = DateTime.now();
      final currentOwner = data['lastEventRollClaimOwnerId']?.toString() ?? '';
      final claimedAt = _dateFromJson(data['lastEventRollClaimedAt']);
      final claimExpired =
          claimedAt == null || now.difference(claimedAt) > lockDuration;

      if (currentOwner.isNotEmpty && currentOwner != ownerId && !claimExpired) {
        return false;
      }

      transaction.update(docRef, {
        'lastEventRollClaimOwnerId': ownerId,
        'lastEventRollClaimedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      return true;
    });
  }

  Future<bool> saveDiceRollOutcomeIfClaimed({
    required String campaignId,
    required BoardToken token,
    required String ownerId,
    required int total,
    required int diceTotal,
    required List<int> values,
    required String label,
    required String detail,
  }) async {
    if (token.lastEventId.isEmpty || ownerId.isEmpty || values.isEmpty) {
      return false;
    }

    final docRef = _tokensCollection(
      campaignId: campaignId,
      sceneId: token.sceneId,
    ).doc(token.id);

    return _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (data == null) return false;
      if (data['lastEventId']?.toString() != token.lastEventId) return false;
      if (_intList(data['lastEventRollValues']).isNotEmpty) return false;

      final currentOwner = data['lastEventRollClaimOwnerId']?.toString() ?? '';
      if (currentOwner.isNotEmpty && currentOwner != ownerId) return false;

      final now = DateTime.now();
      transaction.update(docRef, {
        'lastEventResultLabel': label,
        'lastEventResultDetail': detail,
        'lastEventRollTotal': total,
        'lastEventRollDiceTotal': diceTotal,
        'lastEventRollValues': values,
        'lastEventRollClaimOwnerId': '',
        'lastEventRollClaimedAt': '',
        'updatedAt': now.toIso8601String(),
      });
      return true;
    });
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

List<int> _intList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
      .whereType<int>()
      .toList(growable: false);
}

DateTime? _dateFromJson(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  return DateTime.tryParse(value.toString());
}
