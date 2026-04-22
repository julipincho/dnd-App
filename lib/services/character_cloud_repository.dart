import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/character.dart';

class CharacterCloudRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('characters');

  Future<List<Character>> getCharactersByUser(String userId) async {
    final snapshot =
        await _collection.where('ownerUserId', isEqualTo: userId).get();

    return snapshot.docs.map((doc) => Character.fromJson(doc.data())).toList();
  }

  Future<void> saveCharacter(Character character) async {
    await _collection.doc(character.id).set(character.toJson());
  }

  Future<void> deleteCharacter(String id) async {
    await _collection.doc(id).delete();
  }
}
