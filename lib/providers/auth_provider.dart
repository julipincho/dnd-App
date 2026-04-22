import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isInitialized = false;
  bool _isLoading = false;

  User? get user => _user;
  String? get userId => _user?.uid;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _user != null;

  Future<void> init() async {
    if (_isLoading || _isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.ensureSignedInAnonymously();
      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    _user = _authService.currentUser;
    notifyListeners();
  }
}
