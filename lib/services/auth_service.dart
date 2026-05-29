// lib/services/auth_service.dart
//
// Persists login state in Hive so the user stays logged in across app restarts.
// No Firebase Auth used — stores phone number / Google sign-in flag locally.
//
// Usage:
//   await AuthService.instance.init();          // call once in main.dart
//   await AuthService.instance.loginWithPhone(phone);
//   await AuthService.instance.loginWithGoogle(name, email);
//   await AuthService.instance.loginAsGuest();
//   await AuthService.instance.logout();
//   AuthService.instance.isLoggedIn  → bool
//   AuthService.instance.isGuest     → bool
//   AuthService.instance.userName    → String

import 'package:hive_flutter/hive_flutter.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  static const _boxName = 'auth';
  static const _keyLoggedIn = 'logged_in';
  static const _keyIsGuest = 'is_guest';
  static const _keyUserName = 'user_name';
  static const _keyUserPhone = 'user_phone';
  static const _keyUserEmail = 'user_email';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isLoggedIn => _box?.get(_keyLoggedIn, defaultValue: false) ?? false;
  bool get isGuest => _box?.get(_keyIsGuest, defaultValue: true) ?? true;
  String get userName => _box?.get(_keyUserName, defaultValue: '') ?? '';
  String get userPhone => _box?.get(_keyUserPhone, defaultValue: '') ?? '';
  String get userEmail => _box?.get(_keyUserEmail, defaultValue: '') ?? '';

  // ── Login methods ──────────────────────────────────────────────────────────

  Future<void> loginWithPhone(String phone) async {
    await _box?.putAll({
      _keyLoggedIn: true,
      _keyIsGuest: false,
      _keyUserName: phone,
      _keyUserPhone: phone,
      _keyUserEmail: '',
    });
  }

  Future<void> loginWithGoogle({
    required String name,
    required String email,
  }) async {
    await _box?.putAll({
      _keyLoggedIn: true,
      _keyIsGuest: false,
      _keyUserName: name,
      _keyUserPhone: '',
      _keyUserEmail: email,
    });
  }

  Future<void> loginAsGuest() async {
    await _box?.putAll({
      _keyLoggedIn: true,
      _keyIsGuest: true,
      _keyUserName: '',
      _keyUserPhone: '',
      _keyUserEmail: '',
    });
  }

  Future<void> logout() async {
    await _box?.putAll({
      _keyLoggedIn: false,
      _keyIsGuest: true,
      _keyUserName: '',
      _keyUserPhone: '',
      _keyUserEmail: '',
    });
  }
}