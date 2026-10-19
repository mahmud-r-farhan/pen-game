// lib/core/auth/user_session.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';
import '../network/api_service.dart';

class UserSession with ChangeNotifier {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  UserProfile? _currentProfile;
  UserProfile get profile => _currentProfile ?? UserProfile.guestDefault('guest_temp');
  bool get hasProfile => _currentProfile != null;

  static const String _prefKeyProfile = 'kolom_user_profile';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKeyProfile);
    if (raw != null) {
      try {
        _currentProfile = UserProfile.fromJson(jsonDecode(raw));
      } catch (_) {
        _currentProfile = null;
      }
    }
    notifyListeners();
  }

  Future<void> setProfile(UserProfile newProfile) async {
    _currentProfile = newProfile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyProfile, jsonEncode(newProfile.toJson()));
    notifyListeners();
  }

  Future<void> updateAvatar(String newAvatarId) async {
    if (_currentProfile != null) {
      _currentProfile = _currentProfile!.copyWith(avatar: newAvatarId);
      await setProfile(_currentProfile!);
      try {
        await ApiService().updateProfile(
          userId: _currentProfile!.id,
          avatar: newAvatarId,
        );
      } catch (_) {}
    }
  }

  Future<void> updateCoins(int newCoins) async {
    if (_currentProfile != null) {
      _currentProfile = _currentProfile!.copyWith(coins: newCoins);
      await setProfile(_currentProfile!);
    }
  }

  Future<void> updateTrophies(int newTrophies) async {
    if (_currentProfile != null) {
      String tier = 'bronze';
      if (newTrophies >= 5000) {
        tier = 'grandmaster';
      } else if (newTrophies >= 2500) {
        tier = 'diamond';
      } else if (newTrophies >= 1200) {
        tier = 'gold';
      } else if (newTrophies >= 500) {
        tier = 'silver';
      }

      _currentProfile = _currentProfile!.copyWith(
        trophyPoints: newTrophies,
        cupTier: tier,
      );
      await setProfile(_currentProfile!);
    }
  }

  Future<void> equipPen(String penId) async {
    if (_currentProfile != null) {
      _currentProfile = _currentProfile!.copyWith(equippedPen: penId);
      await setProfile(_currentProfile!);
    }
  }

  Future<void> unlockPen(String penId, int cost) async {
    if (_currentProfile != null) {
      final updatedList = List<String>.from(_currentProfile!.unlockedPens);
      if (!updatedList.contains(penId)) {
        updatedList.add(penId);
      }
      _currentProfile = _currentProfile!.copyWith(
        coins: _currentProfile!.coins - cost,
        equippedPen: penId,
        unlockedPens: updatedList,
      );
      await setProfile(_currentProfile!);
    }
  }

  Future<void> recordMatchOutcome({
    required bool isWin,
    required int coinsChange,
    int? trophyDelta,
  }) async {
    if (_currentProfile != null) {
      final oldStats = _currentProfile!.stats;
      final newStreak = isWin ? oldStats.winStreak + 1 : 0;
      final newStats = UserStats(
        totalMatches: oldStats.totalMatches + 1,
        wins: isWin ? oldStats.wins + 1 : oldStats.wins,
        losses: isWin ? oldStats.losses : oldStats.losses + 1,
        winStreak: newStreak,
        highestStreak: mathMax(oldStats.highestStreak, newStreak),
      );

      final delta = trophyDelta ?? (isWin ? 25 : -15);
      final newTrophies = mathMax(0, _currentProfile!.trophyPoints + delta);

      String tier = 'bronze';
      if (newTrophies >= 5000) {
        tier = 'grandmaster';
      } else if (newTrophies >= 2500) {
        tier = 'diamond';
      } else if (newTrophies >= 1200) {
        tier = 'gold';
      } else if (newTrophies >= 500) {
        tier = 'silver';
      }

      _currentProfile = _currentProfile!.copyWith(
        coins: mathMax(0, _currentProfile!.coins + coinsChange),
        trophyPoints: newTrophies,
        cupTier: tier,
        stats: newStats,
      );
      await setProfile(_currentProfile!);
    }
  }

  static const String _prefKeyDailyTiffin = 'pref_last_daily_tiffin_ms';

  Future<int?> claimDailyTiffin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClaimMs = prefs.getInt(_prefKeyDailyTiffin) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    // 20 hours cooldown
    if (now - lastClaimMs < 20 * 60 * 60 * 1000) {
      return null;
    }
    const rewardCoins = 200;
    await prefs.setInt(_prefKeyDailyTiffin, now);
    await updateCoins(profile.coins + rewardCoins);
    return rewardCoins;
  }

  Future<bool> canClaimDailyTiffin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastClaimMs = prefs.getInt(_prefKeyDailyTiffin) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastClaimMs >= 20 * 60 * 60 * 1000);
  }

  int mathMax(int a, int b) => a > b ? a : b;

  Future<void> clear() async {
    _currentProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyProfile);
    notifyListeners();
  }
}
