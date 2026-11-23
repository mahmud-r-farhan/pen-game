// lib/core/auth/user_session.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_profile.dart';
import '../network/api_service.dart';

/// Holds a cached rendering profile, while every mutation is confirmed by the
/// backend. Authentication tokens use Keychain/Keystore on native platforms.
class UserSession with ChangeNotifier {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  static const String _prefKeyProfile = 'kolom_user_profile_v2';
  static const String _secureKeyToken = 'kolom_session_token_v2';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  UserProfile? _currentProfile;
  String? _sessionToken;

  UserProfile get profile {
    final current = _currentProfile;
    if (current == null)
      throw StateError('No authenticated player profile is available.');
    return current;
  }

  bool get hasProfile => _currentProfile != null;
  bool get hasSessionToken => _sessionToken != null;
  // Older versions could cache a local guest over an online profile. Do not
  // treat that cache as an authenticated identity when restoration fails.
  bool get hasOnlineCachedProfile =>
      hasSessionToken &&
      _currentProfile != null &&
      !_currentProfile!.id.startsWith('local_guest_');
  String? get sessionToken => _sessionToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _sessionToken = await _secureStorage.read(key: _secureKeyToken);
      final raw = prefs.getString(_prefKeyProfile);
      if (raw != null)
        _currentProfile = UserProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
    } catch (_) {
      _sessionToken = null;
    }
    ApiService().configureSessionToken(_sessionToken);
    notifyListeners();
  }

  Future<void> setAuthenticatedSession(AuthSessionData session) async {
    _sessionToken = session.sessionToken;
    ApiService().configureSessionToken(_sessionToken);
    await _secureStorage.write(
      key: _secureKeyToken,
      value: session.sessionToken,
    );
    await setProfile(session.profile);
  }

  Future<void> setProfile(UserProfile newProfile) async {
    _currentProfile = newProfile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyProfile, jsonEncode(newProfile.toJson()));
    notifyListeners();
  }

  Future<UserProfile> refreshProfile() async {
    final refreshed = await ApiService().getOwnProfile();
    await setProfile(refreshed);
    return refreshed;
  }

  Future<UserProfile> updateAvatar(String avatar) async {
    final updated = await ApiService().updateProfile(avatar: avatar);
    await setProfile(updated);
    return updated;
  }

  Future<UserProfile> updateRegion({
    required String region,
    required String flagEmoji,
    String? division,
  }) async {
    final updated = await ApiService().updateProfile(
      region: region,
      flagEmoji: flagEmoji,
      division: division,
    );
    await setProfile(updated);
    return updated;
  }

  Future<UserProfile> updateDivision(String division) async {
    final updated = await ApiService().updateProfile(division: division);
    await setProfile(updated);
    return updated;
  }

  Future<UserProfile> equipPen(String penId) async {
    final updated = await ApiService().equipPen(penId);
    await setProfile(updated);
    return updated;
  }

  Future<UserProfile> purchasePen(String penId) async {
    final updated = await ApiService().purchasePen(penId);
    await setProfile(updated);
    return updated;
  }

  Future<int?> claimDailyTiffin() async {
    final result = await ApiService().claimDailyReward();
    await setProfile(result.profile);
    return result.reward == 0 ? null : result.reward;
  }

  Future<void> clear() async {
    _currentProfile = null;
    _sessionToken = null;
    ApiService().configureSessionToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyProfile);
    try {
      await _secureStorage.delete(key: _secureKeyToken);
    } catch (_) {
      // The server session is revoked independently during logout.
    }
    notifyListeners();
  }
}
