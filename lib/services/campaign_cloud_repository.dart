import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/campaign.dart';

class CampaignCloudRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('campaigns');

  Future<List<Campaign>> getCampaignsByUser(String userId) async {
    final campaignsById = <String, Campaign>{};

    final memberSnapshot =
        await _collection.where('memberUserIds', arrayContains: userId).get();
    for (final doc in memberSnapshot.docs) {
      final campaign = _campaignFromDoc(doc);
      if (campaign.id.isNotEmpty) {
        campaignsById[campaign.id] = campaign;
      }
    }

    final ownerSnapshot =
        await _collection.where('ownerUserId', isEqualTo: userId).get();
    for (final doc in ownerSnapshot.docs) {
      final campaign = _campaignFromDoc(doc);
      if (campaign.id.isEmpty) continue;

      final normalized = _withOwnerMembership(campaign, userId);
      campaignsById[normalized.id] = normalized;

      if (normalized.memberUserIds.length != campaign.memberUserIds.length) {
        await _repairOwnerMembership(
          campaignId: normalized.id,
          userId: userId,
        );
      }
    }

    final campaigns = campaignsById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return campaigns;
  }

  Future<void> saveCampaign(Campaign campaign) async {
    await _collection.doc(campaign.id).set(
          campaign.toJson(),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteCampaign(String campaignId) async {
    await _collection.doc(campaignId).delete();
  }

  Future<Campaign?> getCampaignById(String campaignId) async {
    final doc = await _collection.doc(campaignId).get();
    final data = doc.data();
    if (data == null) return null;
    return Campaign.fromJson(data, fallbackId: doc.id);
  }

  Future<Campaign> joinCampaign({
    required String campaignId,
    required String userId,
  }) async {
    final normalizedCampaignId = campaignId.trim();
    if (normalizedCampaignId.isEmpty) {
      throw ArgumentError('Campaign ID is required.');
    }

    final docRef = _collection.doc(normalizedCampaignId);

    await docRef.update({
      'memberUserIds': FieldValue.arrayUnion([userId]),
    });

    final joinedDoc = await docRef.get();
    final data = joinedDoc.data();
    if (data == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'Campaign was not found.',
      );
    }

    return Campaign.fromJson(data, fallbackId: joinedDoc.id);
  }

  Campaign _campaignFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return Campaign.fromJson(doc.data(), fallbackId: doc.id);
  }

  Campaign _withOwnerMembership(Campaign campaign, String userId) {
    if (campaign.ownerUserId != userId ||
        campaign.memberUserIds.contains(userId)) {
      return campaign;
    }

    return campaign.copyWith(
      memberUserIds: [...campaign.memberUserIds, userId],
    );
  }

  Future<void> _repairOwnerMembership({
    required String campaignId,
    required String userId,
  }) async {
    try {
      await _collection.doc(campaignId).set(
        {
          'id': campaignId,
          'memberUserIds': FieldValue.arrayUnion([userId]),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Could not repair campaign membership for $campaignId: $e');
    }
  }
}
