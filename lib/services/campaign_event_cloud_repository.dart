import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/campaign_event.dart';

class CampaignEventCloudRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('campaign_events');

  Future<List<CampaignEvent>> getEventsByCampaign(String campaignId) async {
    final snapshot =
        await _collection.where('campaignId', isEqualTo: campaignId).get();

    return snapshot.docs
        .map((doc) => CampaignEvent.fromJson(doc.data()))
        .toList();
  }

  Future<void> saveEvent(CampaignEvent event) async {
    await _collection.doc(event.id).set(event.toJson());
  }

  Future<void> deleteEvent(String eventId) async {
    await _collection.doc(eventId).delete();
  }
}
