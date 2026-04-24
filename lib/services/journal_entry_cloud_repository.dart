import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/journal_entry.dart';

class JournalEntryCloudRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('journal_entries');

  Future<List<JournalEntry>> getEntriesByCampaign(String campaignId) async {
    final snapshot =
        await _collection.where('campaignId', isEqualTo: campaignId).get();

    return snapshot.docs
        .map((doc) => JournalEntry.fromJson(doc.data()))
        .toList();
  }

  Future<void> saveEntry(JournalEntry entry) async {
    await _collection.doc(entry.id).set(entry.toJson());
  }

  Future<void> deleteEntry(String entryId) async {
    await _collection.doc(entryId).delete();
  }
}
