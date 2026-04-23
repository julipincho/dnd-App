import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
  }

  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'No user was returned after sign in.',
        );
      }

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e, st) {
      debugPrint('AuthService signInWithEmailAndPassword ERROR: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<User> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'No user was returned after registration.',
        );
      }

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e, st) {
      debugPrint('AuthService createUserWithEmailAndPassword ERROR: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
