// lib/core/auth/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_profile.dart';
import '../network/api_service.dart';
import 'user_session.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isFirebaseInitialized = false;

  Future<void> init() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseInitialized = true;
      }
    } catch (_) {
      _isFirebaseInitialized = false;
    }
  }

  /// 1. Guest Mode Login (75 Coins starter bonus)
  Future<UserProfile> loginAsGuest({
    String? desiredName,
    String? division,
    String? region,
    String? flagEmoji,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String? savedGuestId = prefs.getString('saved_guest_uid');

    if (savedGuestId == null) {
      savedGuestId = 'guest_${const Uuid().v4().substring(0, 8)}';
      await prefs.setString('saved_guest_uid', savedGuestId);
    }

    UserProfile profile = UserProfile.guestDefault(savedGuestId);
    if (desiredName != null && desiredName.isNotEmpty) {
      profile = profile.copyWith(username: desiredName);
    }
    if (division != null) {
      profile = profile.copyWith(division: division);
    }
    if (region != null) {
      profile = profile.copyWith(region: region);
    }
    if (flagEmoji != null) {
      profile = profile.copyWith(flagEmoji: flagEmoji);
    }

    await UserSession().setProfile(profile);
    return profile;
  }

  /// 2. Google Sign-In with Automatic Guest Account Merging (+120 Coins bonus)
  Future<UserProfile?> signInWithGoogle({
    String? simulatedEmail,
    String? simulatedName,
  }) async {
    final currentGuest = UserSession().profile;
    final bool wasGuest = currentGuest.isGuest;

    String googleUid = '';
    String googleName = simulatedName ?? 'Google Kolom Player';
    String googleEmail = simulatedEmail ?? 'player@kolomkhela.bd';
    String googleAvatar = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=256&q=80';

    // Try real Firebase Google Sign-In if configured
    if (_isFirebaseInitialized && !kIsWeb) {
      try {
        final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final auth = fb.FirebaseAuth.instance;
        if (wasGuest && auth.currentUser != null && auth.currentUser!.isAnonymous) {
          final linkResult = await auth.currentUser!.linkWithCredential(credential);
          googleUid = linkResult.user?.uid ?? googleUser.id;
        } else {
          final userCred = await auth.signInWithCredential(credential);
          googleUid = userCred.user?.uid ?? googleUser.id;
        }
        googleName = googleUser.displayName ?? googleName;
        googleEmail = googleUser.email;
        if (googleUser.photoUrl != null && googleUser.photoUrl!.isNotEmpty) {
          googleAvatar = googleUser.photoUrl!;
        }
      } catch (e) {
        debugPrint('Firebase Google Sign-In note: $e. Falling back to account bridge.');
      }
    }

    if (googleUid.isEmpty) {
      googleUid = 'goog_${(simulatedEmail ?? "player@kolomkhela.bd").hashCode.abs()}';
    }

    // Call backend atomic account merge API
    if (wasGuest) {
      final merged = await ApiService().mergeGuestWithAccount(
        guestId: currentGuest.id,
        uid: googleUid,
        name: googleName,
        email: googleEmail,
        avatar: googleAvatar,
        provider: 'google',
      );

      if (merged != null) {
        final withGooglePhoto = merged.copyWith(googlePhotoUrl: googleAvatar);
        await UserSession().setProfile(withGooglePhoto);
        return withGooglePhoto;
      }
    }

    // Fallback local upgrade (120 coins initial if fresh)
    final updatedProfile = currentGuest.copyWith(
      id: googleUid,
      googleId: googleUid,
      username: googleName,
      email: googleEmail,
      avatar: googleAvatar,
      googlePhotoUrl: googleAvatar,
      coins: currentGuest.coins < 120 ? 120 : currentGuest.coins,
      isGuest: false,
    );

    await UserSession().setProfile(updatedProfile);
    return updatedProfile;
  }

  /// 3. Facebook Sign-In with Guest Merging & Mutual Friend Discovery
  Future<UserProfile?> signInWithFacebook({
    String? facebookId,
    String? facebookName,
    List<String> friendFbIds = const [],
  }) async {
    final currentGuest = UserSession().profile;
    final fbId = facebookId ?? 'fb_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final fbName = facebookName ?? 'FB Kolom Warrior';

    if (currentGuest.isGuest) {
      final merged = await ApiService().mergeGuestWithAccount(
        guestId: currentGuest.id,
        uid: fbId,
        name: fbName,
        email: '',
        avatar: 'avatar_pro_bangla',
        provider: 'facebook',
      );

      if (merged != null) {
        await UserSession().setProfile(merged);
        if (friendFbIds.isNotEmpty) {
          await ApiService().syncFacebookFriends(merged.id, fbId, friendFbIds);
        }
        return merged;
      }
    }

    final updated = currentGuest.copyWith(
      id: fbId,
      facebookId: fbId,
      username: fbName,
      coins: currentGuest.coins < 120 ? 120 : currentGuest.coins,
      isGuest: false,
    );

    await UserSession().setProfile(updated);

    if (friendFbIds.isNotEmpty) {
      await ApiService().syncFacebookFriends(updated.id, fbId, friendFbIds);
    }

    return updated;
  }

  /// Logout / Switch Account
  Future<void> logout() async {
    try {
      if (_isFirebaseInitialized) {
        await fb.FirebaseAuth.instance.signOut();
      }
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await UserSession().clear();
  }
}
