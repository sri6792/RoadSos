// lib/services/app_state.dart
// In-memory app state shared across screens.
// For persistent storage use AuthService (Hive).

import '../models/models.dart';

class AppState {
  AppState._();
  static final AppState instance = AppState._();

  // Auth
  bool isGuest = true;
  String userId = '';
  String userName = '';

  // Profile fields (editable)
  String bloodGroup = '';
  String allergies = '';
  String conditions = '';
  String vehicle = '';
  String registration = '';

  // Emergency contacts (personal — shown when logged in)
  // Emergency contacts (personal — shown when logged in)
  List<EmergencyContact> personalContacts = List.from(SampleData.contacts);

// SOS Numbers Logic
// First use personal emergency contacts.
// If no contacts exist, fallback to national helplines.
  List<String> get sosNumbers {
    if (personalContacts.isNotEmpty) {
      return personalContacts
          .map((e) => e.phone.trim())
          .where((number) => number.isNotEmpty)
          .toList();
    }

    // Fallback numbers
    return ['112', '108', '100', '101'];
  }

  // National SOS numbers as plain strings (e.g. '112', '108')
  // Used by sos_active_screen for quick dial

  // Responder
  bool isFirstResponder = false;
  double? lastLat;
  double? lastLng;
}