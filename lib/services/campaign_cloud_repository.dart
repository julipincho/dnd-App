import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/campaign.dart';

class CampaignCloudRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('campaigns');

  Future<List<Campaign>> getCampaignsByUser(String userId) async {
    final snapshot =
        await _collection.where('memberUserIds', arrayContains: userId).get();

    return snapshot.docs.map((doc) => Campaign.fromJson(doc.data())).toList();
  }

  Future<void> saveCampaign(Campaign campaign) async {
    await _collection.doc(campaign.id).set(campaign.toJson());
  }

  Future<void> deleteCampaign(String campaignId) async {
    await _collection.doc(campaignId).delete();
  }

  Future<Campaign?> getCampaignById(String campaignId) async {
    final doc = await _collection.doc(campaignId).get();
    final data = doc.data();
    if (data == null) return null;
    return Campaign.fromJson(data);
  }

  Future<void> joinCampaign({
    required String campaignId,
    required String userId,
  }) async {
    final campaign = await getCampaignById(campaignId);
    if (campaign == null) return;

    final members = [...campaign.memberUserIds];
    if (!members.contains(userId)) {
      members.add(userId);
    }

    final updated = campaign.copyWith(
      memberUserIds: members,
    );

    await saveCampaign(updated);
  }
}
