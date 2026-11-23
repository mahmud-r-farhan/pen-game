import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/user_profile.dart';

/// A device-local practice identity, independent of any online account.
class LocalPracticeProfile {
  static const _key = 'kolom_local_practice_profile_v1';

  static Future<UserProfile> getOrCreate({
    String? desiredName,
    String division = 'Dhaka',
    String region = 'BD',
    String flagEmoji = '🇧🇩',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      try {
        return UserProfile.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {
        // A damaged local profile can be replaced without touching online data.
      }
    }

    final id = const Uuid().v4();
    final shortId = id.substring(0, 6).toUpperCase();
    final name = desiredName?.trim();
    final profile = UserProfile(
      id: 'local_guest_$id',
      tag: '#LOCAL-$shortId',
      username: name != null && name.isNotEmpty ? name : 'Guest_$shortId',
      avatar: 'avatar_shuvo',
      coins: 0,
      trophyPoints: 0,
      cupTier: 'bronze',
      region: region.toUpperCase(),
      flagEmoji: flagEmoji,
      equippedPen: 'hiSchoolClassic',
      unlockedPens: const ['hiSchoolClassic'],
      isGuest: true,
      division: division,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(_key, jsonEncode(profile.toJson()));
    return profile;
  }
}
