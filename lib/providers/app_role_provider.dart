import 'package:flutter/foundation.dart';

enum AppRole {
  dm,
  player,
}

class AppRoleProvider extends ChangeNotifier {
  AppRole _role = AppRole.dm;

  AppRole get role => _role;

  bool get isDm => _role == AppRole.dm;
  bool get isPlayer => _role == AppRole.player;

  void setRole(AppRole role) {
    if (_role == role) return;
    _role = role;
    notifyListeners();
  }

  void toggleRole() {
    _role = _role == AppRole.dm ? AppRole.player : AppRole.dm;
    notifyListeners();
  }
}
