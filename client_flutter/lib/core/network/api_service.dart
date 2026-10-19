// lib/core/network/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/user_profile.dart';
import 'network_config.dart';

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

  factory ClubData.fromJson(Map<String, dynamic> json) {
    return ClubData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Club',
      tag: json['tag'] as String? ?? '[WAR]',
      badgeIcon: json['badgeIcon'] as String? ?? 'badge_dragon',
      description: json['description'] as String? ?? '',
      leaderName: json['leaderName'] as String? ?? 'Leader',
      membersCount: json['membersCount'] as int? ?? 1,
      totalTrophies: json['totalTrophies'] as int? ?? 100,
      region: json['region'] as String? ?? 'BD',
      flagEmoji: json['flagEmoji'] as String? ?? '🇧🇩',
    );
  }
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _customBaseUrl;

  void configureBaseUrl(String url) {
    _customBaseUrl = url;
  }

  String get _baseUrl => _customBaseUrl ?? NetworkConfig.httpBaseUrl;

  Future<List<UserProfile>> getLeaderboard({
    String filter = 'global',
    String? division,
    String? userId,
  }) async {
    try {
      final queryParams = <String, String>{'filter': filter};
      if (division != null) queryParams['division'] = division;
      if (userId != null) queryParams['userId'] = userId;

      final uri = Uri.parse('$_baseUrl/api/leaderboard').replace(queryParameters: queryParams);
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<ClubData>> getClubs() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/clubs');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => ClubData.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<ClubData?> createClub({
    required String leaderId,
    required String name,
    required String tag,
    required String description,
    String badgeIcon = 'badge_dragon',
    String region = 'BD',
    String flagEmoji = '🇧🇩',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/clubs/create');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'leaderId': leaderId,
          'name': name,
          'tag': tag,
          'description': description,
          'badgeIcon': badgeIcon,
          'region': region,
          'flagEmoji': flagEmoji,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['club'] != null) {
          return ClubData.fromJson(data['club'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<ClubData?> joinClub({required String userId, required String clubId}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/clubs/join');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'clubId': clubId}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['club'] != null) {
          return ClubData.fromJson(data['club'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<UserProfile>> getFriends(String userId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/friends?userId=$userId');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<UserProfile?> addFriend(String userId, String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/friends/add');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'query': query}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['friend'] != null) {
          return UserProfile.fromJson(data['friend'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> removeFriend(String userId, String friendId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/friends/remove');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'friendId': friendId}),
      ).timeout(const Duration(seconds: 4));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<UserProfile>> syncFacebookFriends(
    String userId,
    String facebookId,
    List<String> friendIds,
  ) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/friends/facebook-sync');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'facebookId': facebookId,
          'facebookFriendIds': friendIds,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> list = data['matchedFriends'] ?? [];
        return list.map((e) => UserProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<UserProfile?> mergeGuestWithAccount({
    required String guestId,
    required String uid,
    required String name,
    required String email,
    required String avatar,
    String provider = 'google',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/merge');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'guestId': guestId,
          'googleUid': uid,
          'googleName': name,
          'googleEmail': email,
          'googleAvatar': avatar,
          'provider': provider,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['profile'] != null) {
          return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<UserProfile?> updateProfile({
    required String userId,
    String? avatar,
    String? username,
    String? equippedPen,
    String? googlePhotoUrl,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/user/update-profile');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'avatar': avatar,
          'username': username,
          'equippedPen': equippedPen,
          'googlePhotoUrl': googlePhotoUrl,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['profile'] != null) {
          return UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }
}

