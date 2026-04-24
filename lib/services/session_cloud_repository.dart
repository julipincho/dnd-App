import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session.dart';

class SessionCloudRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('sessions');

  Future<List<Session>> getSessionsByCampaign(String campaignId) async {
    final snapshot =
        await _collection.where('campaignId', isEqualTo: campaignId).get();

    return snapshot.docs.map((doc) => Session.fromJson(doc.data())).toList();
  }

  Future<void> saveSession(Session session) async {
    await _collection.doc(session.id).set(session.toJson());
  }

  Future<void> deleteSession(String sessionId) async {
    await _collection.doc(sessionId).delete();
  }
}
