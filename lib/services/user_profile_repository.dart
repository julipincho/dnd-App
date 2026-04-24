import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

class UserProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users');

  Future<UserProfile?> getProfile(String userId) async {
    final doc = await _collection.doc(userId).get();
    final data = doc.data();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _collection.doc(profile.id).set(profile.toJson());
  }

  Future<void> updateProfile({
    required String userId,
    required String displayName,
    String? avatarPath,
  }) async {
    final data = <String, dynamic>{
      'displayName': displayName,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (avatarPath != null) {
      data['avatarPath'] = avatarPath;
    }

    await _collection.doc(userId).set(data, SetOptions(merge: true));
  }
}
