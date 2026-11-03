// lib/core/auth/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_profile.dart';
import '../network/api_service.dart';
import '../network/ws_client.dart';
import 'user_session.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isFirebaseInitialized = false;
  String? _firebaseConfigurationError;

  bool get isGoogleAvailable => _isFirebaseInitialized;
  String? get firebaseConfigurationError => _firebaseConfigurationError;

  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
          const appId = String.fromEnvironment('FIREBASE_APP_ID');
          const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
          const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
          const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
          if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty || projectId.isEmpty || authDomain.isEmpty) {
            throw const AuthException(
              'Google sign-in needs Firebase web configuration. Guest play remains available.',
            );
          }
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: apiKey,
              appId: appId,
              messagingSenderId: senderId,
              projectId: projectId,
              authDomain: authDomain,
            ),
          );
        } else {
          // Native Android reads the bundled google-services.json.
          await Firebase.initializeApp();
        }
      }
      _isFirebaseInitialized = true;
      if (!kIsWeb) await GoogleSignIn.instance.initialize();
    } catch (error) {
      _isFirebaseInitialized = false;
      _firebaseConfigurationError = error is AuthException ? error.message : 'Firebase is not configured: $error';
      debugPrint(_firebaseConfigurationError);
    }
  }

  Future<UserProfile?> restoreSession() async {
    final session = UserSession();
    if (!session.hasSessionToken) return null;
    try {
      final profile = await ApiService().restoreSession();
      await session.setProfile(profile);
      return profile;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await session.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<UserProfile> loginAsGuest({
    String? desiredName,
    required String division,
    required String region,
    required String flagEmoji,
  }) async {
    final auth = await ApiService().loginGuest(
      username: desiredName,
      division: division,
      region: region.toUpperCase(),
      flagEmoji: flagEmoji,
    );
    await UserSession().setAuthenticatedSession(auth);
    return auth.profile;
  }

  Future<UserProfile> signInWithGoogle() async {
    if (!_isFirebaseInitialized) {
      throw AuthException(_firebaseConfigurationError ?? 'Google sign-in is not configured for this build.');
    }

    String? idToken;
    try {
      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider();
        final credential = await fb.FirebaseAuth.instance.signInWithPopup(provider);
        idToken = await credential.user?.getIdToken(false);
      } else {
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        final credential = fb.GoogleAuthProvider.credential(idToken: googleAuth.idToken);
        final userCredential = await fb.FirebaseAuth.instance.signInWithCredential(credential);
        idToken = await userCredential.user?.getIdToken(false);
      }
    } catch (error) {
      throw AuthException('Google sign-in was not completed: $error');
    }
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Firebase did not return an ID token. Please try again.');
    }

    // The backend verifies signature, audience, issuer, expiry and provider.
    final auth = await ApiService().loginWithGoogle(idToken);
    await UserSession().setAuthenticatedSession(auth);
    await KolomWsClient().connect(auth.profile, forceReconnect: true);
    return auth.profile;
  }

  Future<void> logout() async {
    KolomWsClient().disconnect();
    try {
      if (UserSession().hasSessionToken) await ApiService().logout();
    } catch (_) {
      // Local credentials are still removed below. If the network is unavailable,
      // the revoked device's token is discarded and the server session expires normally.
    }
    try {
      if (_isFirebaseInitialized) {
        await fb.FirebaseAuth.instance.signOut();
        if (!kIsWeb) await GoogleSignIn.instance.signOut();
      }
    } catch (_) {
      // Provider logout is best-effort and never blocks local account switching.
    }
    await UserSession().clear();
  }
}
