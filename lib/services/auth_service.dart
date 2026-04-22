import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User> ensureSignedInAnonymously() async {
    final existingUser = _auth.currentUser;

    if (existingUser != null) {
      debugPrint('AuthService: existing user ${existingUser.uid}');
      return existingUser;
    }

    try {
      debugPrint('AuthService: signing in anonymously...');
      final credential = await _auth.signInAnonymously();

      final user = credential.user;
      if (user == null) {
        throw Exception('AuthService: user is null after sign in');
      }

      debugPrint('AuthService: signed in ${user.uid}');
      return user;
    } catch (e, st) {
      debugPrint('AuthService ERROR: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
