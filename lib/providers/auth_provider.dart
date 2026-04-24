import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/supabase_storage_service.dart';
import '../services/user_profile_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserProfileRepository _profileRepository = UserProfileRepository();

  User? _user;
  UserProfile? _profile;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  UserProfile? get profile => _profile;
  String? get userId => _user?.uid;
  String get displayName {
    final profileName = _profile?.displayName.trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;
    final authName = _user?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;
    final email = _user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Adventurer';
  }

  String? get avatarPath {
    final profileAvatar = _profile?.avatarPath?.trim();
    if (profileAvatar != null && profileAvatar.isNotEmpty) {
      return profileAvatar;
    }
    final authAvatar = _user?.photoURL?.trim();
    if (authAvatar != null && authAvatar.isNotEmpty) return authAvatar;
    return null;
  }

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _user != null;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    if (_isLoading || _isInitialized) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.getCurrentUser();
      if (_user != null) {
        _profile = await _loadOrCreateProfile(_user!);
      }
      _isInitialized = true;
    } catch (e) {
      _errorMessage = 'Failed to initialize authentication.';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _profile = await _loadOrCreateProfile(_user!);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseAuthError(e);
      return false;
    } catch (_) {
      _errorMessage = 'Unexpected error while signing in.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    File? avatarFile,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final trimmedName = displayName.trim();
      String? avatarUrl;

      if (avatarFile != null) {
        avatarUrl = await SupabaseStorageService.uploadUserImage(
          file: avatarFile,
          ownerUserId: _user!.uid,
          folder: 'avatars',
          entityId: 'profile',
        );
      }

      await _authService.updateCurrentUserProfile(
        displayName: trimmedName,
        photoUrl: avatarUrl,
      );
      _user = _authService.currentUser ?? _user;

      final now = DateTime.now();
      _profile = UserProfile(
        id: _user!.uid,
        email: _user!.email ?? email.trim(),
        displayName: trimmedName,
        avatarPath: avatarUrl,
        createdAt: now,
        updatedAt: now,
      );
      await _profileRepository.saveProfile(_profile!);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseAuthError(e);
      return false;
    } catch (_) {
      _errorMessage = 'Unexpected error while creating the account.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    _user = _authService.currentUser;
    if (_user != null) {
      _profile = await _loadOrCreateProfile(_user!);
    }
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String displayName,
    File? avatarFile,
  }) async {
    if (_isLoading || _user == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final trimmedName = displayName.trim();
      var resolvedAvatarPath = avatarPath;

      if (avatarFile != null) {
        resolvedAvatarPath = await SupabaseStorageService.uploadUserImage(
          file: avatarFile,
          ownerUserId: _user!.uid,
          folder: 'avatars',
          entityId: 'profile',
        );
      }

      await _authService.updateCurrentUserProfile(
        displayName: trimmedName,
        photoUrl: resolvedAvatarPath,
      );
      await _profileRepository.updateProfile(
        userId: _user!.uid,
        displayName: trimmedName,
        avatarPath: resolvedAvatarPath,
      );

      _user = _authService.currentUser ?? _user;
      _profile = await _loadOrCreateProfile(_user!);
      return true;
    } catch (e) {
      debugPrint('AuthProvider updateProfile ERROR: $e');
      _errorMessage = 'Could not update your profile. Try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account was found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'That email is already in use.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication error.';
    }
  }

  Future<UserProfile> _loadOrCreateProfile(User user) async {
    final existing = await _profileRepository.getProfile(user.uid);
    if (existing != null) return existing;

    final now = DateTime.now();
    final profile = UserProfile(
      id: user.uid,
      email: user.email ?? '',
      displayName: _defaultDisplayNameFor(user),
      avatarPath: user.photoURL,
      createdAt: now,
      updatedAt: now,
    );
    await _profileRepository.saveProfile(profile);
    return profile;
  }

  String _defaultDisplayNameFor(User user) {
    final authName = user.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Adventurer';
  }
}
