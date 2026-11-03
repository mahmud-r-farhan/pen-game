// lib/core/network/api_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/user_profile.dart';
import 'network_config.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  const ApiException(this.code, this.message, [this.statusCode = 0]);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class AuthSessionData {
  final UserProfile profile;
  final String sessionToken;
  final int expiresAt;

  const AuthSessionData({
    required this.profile,
    required this.sessionToken,
    required this.expiresAt,
  });

  factory AuthSessionData.fromJson(Map<String, dynamic> json) => AuthSessionData(
        profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
        sessionToken: json['sessionToken'] as String,
        expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
      );
}

class DailyRewardData {
  final UserProfile profile;
  final int reward;
  final int nextClaimAt;

  const DailyRewardData({required this.profile, required this.reward, required this.nextClaimAt});
}

class ClubMutationData {
  final ClubData club;
  final UserProfile profile;

  const ClubMutationData({required this.club, required this.profile});
}

class ClubData {
  final String id;
  final String name;
  final String tag;
  final String badgeIcon;
  final String description;
  final String leaderName;
  final int membersCount;
  final int totalTrophies;
  final String region;
  final String flagEmoji;

  const ClubData({
    required this.id,
    required this.name,
    required this.tag,
    required this.badgeIcon,
    required this.description,
    required this.leaderName,
    required this.membersCount,
    required this.totalTrophies,
    required this.region,
    required this.flagEmoji,
  });

  factory ClubData.fromJson(Map<String, dynamic> json) => ClubData(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Club',
        tag: json['tag'] as String? ?? '',
        badgeIcon: json['badgeIcon'] as String? ?? '🛡️',
        description: json['description'] as String? ?? '',
        leaderName: json['leaderName'] as String? ?? 'Leader',
        membersCount: (json['membersCount'] as num?)?.toInt() ?? 0,
        totalTrophies: (json['totalTrophies'] as num?)?.toInt() ?? 0,
        region: json['region'] as String? ?? 'GLOBAL',
        flagEmoji: json['flagEmoji'] as String? ?? '🌐',
      );
}

/// Typed backend gateway. Transport failures are never converted into fake
/// profiles, empty leaderboards, or successful-looking local transactions.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  String? _customBaseUrl;
  String? _sessionToken;

  void configureBaseUrl(String url) => _customBaseUrl = url;
  void configureSessionToken(String? token) => _sessionToken = token;
  String get _baseUrl => _customBaseUrl ?? NetworkConfig.httpBaseUrl;

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool requiresAuth = true,
  }) async {
    final base = Uri.parse('$_baseUrl$path');
    final uri = base.replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (_sessionToken != null) 'Authorization': 'Bearer $_sessionToken',
    };
    if (requiresAuth && _sessionToken == null) {
      throw const ApiException('AUTH_REQUIRED', 'Sign in to continue.', 401);
    }

    late http.Response response;
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = body == null ? '' : jsonEncode(body);
      final streamed = await _client.send(request).timeout(const Duration(seconds: 12));
      response = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const ApiException('NETWORK_TIMEOUT', 'The server took too long to respond. Check your connection and retry.');
    } on http.ClientException catch (error) {
      throw ApiException('NETWORK_UNAVAILABLE', 'Cannot reach the game server. ${error.message}');
    } catch (_) {
      throw const ApiException('NETWORK_UNAVAILABLE', 'Cannot reach the game server. Check your connection and retry.');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw ApiException('INVALID_SERVER_RESPONSE', 'The server returned an unreadable response.', response.statusCode);
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
      final code = error is Map<String, dynamic> ? error['code'] as String? : null;
      final message = error is Map<String, dynamic> ? error['message'] as String? : null;
      throw ApiException(
        code ?? 'HTTP_${response.statusCode}',
        message ?? 'The request failed (${response.statusCode}).',
        response.statusCode,
      );
    }
    return decoded;
  }

  Future<AuthSessionData> loginGuest({
    String? username,
    required String division,
    required String region,
    required String flagEmoji,
  }) async {
    final data = await _request('POST', '/api/auth/guest', body: {
      if (username != null && username.trim().isNotEmpty) 'username': username.trim(),
      'division': division,
      'region': region,
      'flagEmoji': flagEmoji,
    }, requiresAuth: false) as Map<String, dynamic>;
    return AuthSessionData.fromJson(data);
  }

  Future<UserProfile> restoreSession() async {
    final data = await _request('GET', '/api/auth/session') as Map<String, dynamic>;
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  Future<AuthSessionData> loginWithGoogle(String firebaseIdToken) async {
    final data = await _request('POST', '/api/auth/google', body: {
      'idToken': firebaseIdToken,
    }, requiresAuth: false) as Map<String, dynamic>;
    return AuthSessionData.fromJson(data);
  }

  Future<String> createWebSocketTicket() async {
    final data = await _request('POST', '/api/auth/ws-ticket', body: const {}) as Map<String, dynamic>;
    return data['ticket'] as String;
  }

  Future<void> logout() async {
    await _request('POST', '/api/auth/logout', body: const {});
  }

  Future<UserProfile> getOwnProfile() async {
    final data = await _request('GET', '/api/user/profile') as Map<String, dynamic>;
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  Future<List<UserProfile>> getLeaderboard({String filter = 'global', String? division}) async {
    final data = await _request('GET', '/api/leaderboard', query: {
      'filter': filter,
      if (division != null) 'division': division,
    }, requiresAuth: filter == 'friends') as List<dynamic>;
    return data.map((item) => UserProfile.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ClubData>> getClubs() async {
    final data = await _request('GET', '/api/clubs', requiresAuth: false) as List<dynamic>;
    return data.map((item) => ClubData.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ClubMutationData> createClub({
    required String name,
    required String tag,
    required String description,
    String badgeIcon = '🛡️',
    String region = 'BD',
    String flagEmoji = '🇧🇩',
  }) async {
    final data = await _request('POST', '/api/clubs/create', body: {
      'name': name,
      'tag': tag,
      'description': description,
      'badgeIcon': badgeIcon,
      'region': region,
      'flagEmoji': flagEmoji,
    }) as Map<String, dynamic>;
    return ClubMutationData(
      club: ClubData.fromJson(data['club'] as Map<String, dynamic>),
      profile: UserProfile.fromJson(data['profile'] as Map<String, dynamic>),
    );
  }

  Future<ClubMutationData> joinClub(String clubId) async {
    final data = await _request('POST', '/api/clubs/join', body: {'clubId': clubId}) as Map<String, dynamic>;
    return ClubMutationData(
      club: ClubData.fromJson(data['club'] as Map<String, dynamic>),
      profile: UserProfile.fromJson(data['profile'] as Map<String, dynamic>),
    );
  }

  Future<UserProfile> leaveClub() async {
    final data = await _request('POST', '/api/clubs/leave', body: const {}) as Map<String, dynamic>;
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  Future<List<UserProfile>> getFriends() async {
    final data = await _request('GET', '/api/friends') as List<dynamic>;
    return data.map((item) => UserProfile.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<UserProfile> addFriend(String query) async {
    final data = await _request('POST', '/api/friends/add', body: {'query': query}) as Map<String, dynamic>;
    return UserProfile.fromJson(data['friend'] as Map<String, dynamic>);
  }

  Future<void> removeFriend(String friendId) async {
    await _request('POST', '/api/friends/remove', body: {'friendId': friendId});
  }

  Future<UserProfile> updateProfile({
    String? avatar,
    String? username,
    String? region,
    String? flagEmoji,
    String? division,
  }) async {
    final data = await _request('POST', '/api/user/update-profile', body: {
      if (avatar != null) 'avatar': avatar,
      if (username != null) 'username': username,
      if (region != null) 'region': region,
      if (flagEmoji != null) 'flagEmoji': flagEmoji,
      if (division != null) 'division': division,
    }) as Map<String, dynamic>;
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  Future<UserProfile> purchasePen(String penId) async {
    final data = await _request('POST', '/api/shop/purchase', body: {'penId': penId}) as Map<String, dynamic>;
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  Future<UserProfile> equipPen(String penId) async {
    final data = await _request('POST', '/api/shop/equip', body: {'penId': penId}) as Map<String, dynamic>;
    return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  Future<DailyRewardData> claimDailyReward() async {
    final data = await _request('POST', '/api/rewards/daily', body: const {}) as Map<String, dynamic>;
    return DailyRewardData(
      profile: UserProfile.fromJson(data['profile'] as Map<String, dynamic>),
      reward: (data['reward'] as num?)?.toInt() ?? 0,
      nextClaimAt: (data['nextClaimAt'] as num?)?.toInt() ?? 0,
    );
  }
}
