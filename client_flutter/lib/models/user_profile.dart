// lib/models/user_profile.dart
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class UserStats {
  final int totalMatches;
  final int wins;
  final int losses;
  final int winStreak;
  final int highestStreak;

  const UserStats({
    this.totalMatches = 0,
    this.wins = 0,
    this.losses = 0,
    this.winStreak = 0,
    this.highestStreak = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalMatches: json['totalMatches'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      winStreak: json['winStreak'] as int? ?? 0,
      highestStreak: json['highestStreak'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalMatches': totalMatches,
    'wins': wins,
    'losses': losses,
    'winStreak': winStreak,
    'highestStreak': highestStreak,
  };
}

class UserProfile {
  final String id;
  final String tag;
  final String username;
  final String? email;
  final String avatar;
  final int coins; // Virtual Currency (Guest: 75, Google: 120)
  final int trophyPoints; // Skill Rating Points (RP) - Distinct from coins!
  final String cupTier; // bronze, silver, gold, diamond, grandmaster
  final String region;
  final String flagEmoji;
  final String? clubId;
  final String? clubName;
  final String? clubTag;
  final String? clubRole;
  final String equippedPen;
  final List<String> unlockedPens;
  final bool isGuest;
  final String? googleId;
  final String? googlePhotoUrl;
  final String division;
  final List<String> friends;
  final UserStats stats;
  final int createdAt;

  const UserProfile({
    required this.id,
    required this.tag,
    required this.username,
    this.email,
    required this.avatar,
    required this.coins,
    this.trophyPoints = 100,
    this.cupTier = 'bronze',
    this.region = 'GLOBAL',
    this.flagEmoji = '🌐',
    this.clubId,
    this.clubName,
    this.clubTag,
    this.clubRole,
    required this.equippedPen,
    required this.unlockedPens,
    required this.isGuest,
    this.googleId,
    this.googlePhotoUrl,
    this.division = 'Dhaka',
    this.friends = const [],
    this.stats = const UserStats(),
    this.createdAt = 0,
  });

  int get level => (stats.wins ~/ 3) + 1;
  int get currentLevelXp => stats.wins % 3;
  double get xpProgress => currentLevelXp / 3.0;
  double get winRate =>
      stats.totalMatches > 0 ? (stats.wins / stats.totalMatches) * 100 : 0.0;

  String get cupTitle {
    switch (cupTier.toLowerCase()) {
      case 'grandmaster':
        return 'Grandmaster Cup 👑';
      case 'diamond':
        return 'Diamond Master Cup 💎';
      case 'gold':
        return 'Gold Cup 🥇';
      case 'silver':
        return 'Silver Cup 🥈';
      default:
        return 'Bronze Cup 🥉';
    }
  }

  String get cupEmoji {
    switch (cupTier.toLowerCase()) {
      case 'grandmaster':
        return '👑';
      case 'diamond':
        return '💎';
      case 'gold':
        return '🥇';
      case 'silver':
        return '🥈';
      default:
        return '🥉';
    }
  }

  Color get cupColor {
    switch (cupTier.toLowerCase()) {
      case 'grandmaster':
        return AppColors.grandmasterCup;
      case 'diamond':
        return AppColors.diamondCup;
      case 'gold':
        return AppColors.goldCup;
      case 'silver':
        return AppColors.silverCup;
      default:
        return AppColors.bronzeCup;
    }
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final trophies = (json['trophyPoints'] as num).toInt();
    String tier = json['cupTier'] as String? ?? 'bronze';
    if (trophies >= 5000) {
      tier = 'grandmaster';
    } else if (trophies >= 2500) {
      tier = 'diamond';
    } else if (trophies >= 1200) {
      tier = 'gold';
    } else if (trophies >= 500) {
      tier = 'silver';
    }

    return UserProfile(
      id: json['id'] as String,
      tag: json['tag'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      avatar: json['avatar'] as String,
      coins: (json['coins'] as num).toInt(),
      trophyPoints: trophies,
      cupTier: tier,
      region: json['region'] as String? ?? 'GLOBAL',
      flagEmoji: json['flagEmoji'] as String? ?? '🌐',
      clubId: json['clubId'] as String?,
      clubName: json['clubName'] as String?,
      clubTag: json['clubTag'] as String?,
      clubRole: json['clubRole'] as String?,
      equippedPen: json['equippedPen'] as String,
      unlockedPens: (json['unlockedPens'] as List<dynamic>)
          .map((e) => e as String)
          .toList(growable: false),
      isGuest: json['isGuest'] as bool,
      googleId: json['googleId'] as String?,
      googlePhotoUrl: json['googlePhotoUrl'] as String?,
      division: json['division'] as String? ?? 'Dhaka',
      friends: (json['friends'] as List<dynamic>)
          .map((e) => e as String)
          .toList(growable: false),
      stats: json['stats'] != null
          ? UserStats.fromJson(json['stats'] as Map<String, dynamic>)
          : const UserStats(),
      createdAt: json['createdAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tag': tag,
    'username': username,
    'email': email,
    'avatar': avatar,
    'coins': coins,
    'trophyPoints': trophyPoints,
    'cupTier': cupTier,
    'region': region,
    'flagEmoji': flagEmoji,
    'clubId': clubId,
    'clubName': clubName,
    'clubTag': clubTag,
    'clubRole': clubRole,
    'equippedPen': equippedPen,
    'unlockedPens': unlockedPens,
    'isGuest': isGuest,
    'googleId': googleId,
    'googlePhotoUrl': googlePhotoUrl,
    'division': division,
    'friends': friends,
    'stats': stats.toJson(),
    'createdAt': createdAt,
  };

  UserProfile copyWith({
    String? id,
    String? tag,
    String? username,
    String? email,
    String? avatar,
    int? coins,
    int? trophyPoints,
    String? cupTier,
    String? region,
    String? flagEmoji,
    String? clubId,
    String? clubName,
    String? clubTag,
    String? clubRole,
    String? equippedPen,
    List<String>? unlockedPens,
    bool? isGuest,
    String? googleId,
    String? googlePhotoUrl,
    String? division,
    List<String>? friends,
    UserStats? stats,
  }) {
    return UserProfile(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      coins: coins ?? this.coins,
      trophyPoints: trophyPoints ?? this.trophyPoints,
      cupTier: cupTier ?? this.cupTier,
      region: region ?? this.region,
      flagEmoji: flagEmoji ?? this.flagEmoji,
      clubId: clubId ?? this.clubId,
      clubName: clubName ?? this.clubName,
      clubTag: clubTag ?? this.clubTag,
      clubRole: clubRole ?? this.clubRole,
      equippedPen: equippedPen ?? this.equippedPen,
      unlockedPens: unlockedPens ?? this.unlockedPens,
      isGuest: isGuest ?? this.isGuest,
      googleId: googleId ?? this.googleId,
      googlePhotoUrl: googlePhotoUrl ?? this.googlePhotoUrl,
      division: division ?? this.division,
      friends: friends ?? this.friends,
      stats: stats ?? this.stats,
      createdAt: createdAt,
    );
  }
}

class BotProfile {
  final String id;
  final String name;
  final String tag;
  final String flagEmoji;
  final String avatar;
  final String penModel;
  final String title;

  const BotProfile({
    required this.id,
    required this.name,
    required this.tag,
    required this.flagEmoji,
    required this.avatar,
    required this.penModel,
    required this.title,
  });

  static const List<BotProfile> predefined = [
    // Bangladesh Divisions & Educational Centers
    BotProfile(
      id: 'bot_dhaka',
      name: 'Shuvo Hasan',
      tag: '#BOT-DHAKA',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_boy_headset',
      penModel: 'hiSchoolClassic',
      title: 'Dhaka School Legend',
    ),
    BotProfile(
      id: 'bot_ctg',
      name: 'Mimi Chowdhury',
      tag: '#BOT-CTG',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_girl_afro',
      penModel: 'oceanGelPro',
      title: 'Chittagong Ace',
    ),
    BotProfile(
      id: 'bot_ruet',
      name: 'Arafat Hossain',
      tag: '#BOT-RUET',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_boy_hoodie',
      penModel: 'econoStriker',
      title: 'Rajshahi Pen Master',
    ),
    BotProfile(
      id: 'bot_kuet',
      name: 'Tanvir Cyber',
      tag: '#BOT-KUET',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_gamer_glasses',
      penModel: 'hectorMetalTank',
      title: 'Khulna Cyber Striker',
    ),
    BotProfile(
      id: 'bot_sylhet',
      name: 'Priya Saha',
      tag: '#BOT-SYLHET',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_girl_hijab',
      penModel: 'oceanGelPro',
      title: 'Sylhet Nature Striker',
    ),
    BotProfile(
      id: 'bot_barishal',
      name: 'DJ Rakib',
      tag: '#BOT-BARISAL',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_dj_headset',
      penModel: 'econoStriker',
      title: 'Barishal Quick-Spin',
    ),
    BotProfile(
      id: 'bot_rangpur',
      name: 'Nahid Hossain',
      tag: '#BOT-RANGPUR',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_boy_beanie',
      penModel: 'hiSchoolClassic',
      title: 'Rangpur Table Tactician',
    ),
    BotProfile(
      id: 'bot_mymensingh',
      name: 'Rohit Neon',
      tag: '#BOT-MYM',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_boy_anime',
      penModel: 'neonSpinner',
      title: 'Mymensingh Cyber Prodigy',
    ),
    BotProfile(
      id: 'bot_comilla',
      name: 'Karim Bhai Pro',
      tag: '#BOT-COMILLA',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_boy_cap',
      penModel: 'doubleCapMod',
      title: 'Comilla Veteran Fighter',
    ),
    BotProfile(
      id: 'bot_bogura',
      name: 'Meherun Nesa',
      tag: '#BOT-BOGURA',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_girl_bun',
      penModel: 'oceanGelPro',
      title: 'Bogura Curfew Striker',
    ),
    // Regional & Global Competitors
    BotProfile(
      id: 'bot_kolkata',
      name: 'Aarav Sen',
      tag: '#BOT-KOLKATA',
      flagEmoji: '🇮🇳',
      avatar: 'avatar_gamer_pro_boy',
      penModel: 'oceanGelPro',
      title: 'Kolkata Gel Master',
    ),
    BotProfile(
      id: 'bot_delhi',
      name: 'Rohan Sharma',
      tag: '#BOT-DELHI',
      flagEmoji: '🇮🇳',
      avatar: 'avatar_pro_streamer',
      penModel: 'hectorMetalTank',
      title: 'Delhi Power Smasher',
    ),
    BotProfile(
      id: 'bot_lahore',
      name: 'Zayn Malik',
      tag: '#BOT-LAHORE',
      flagEmoji: '🇵🇰',
      avatar: 'avatar_boy_jacket',
      penModel: 'doubleCapMod',
      title: 'Lahore Speed Flicker',
    ),
    BotProfile(
      id: 'bot_london',
      name: 'Oliver Smith',
      tag: '#BOT-LONDON',
      flagEmoji: '🇬🇧',
      avatar: 'avatar_boy_blonde',
      penModel: 'oceanGelPro',
      title: 'London Esports Champ',
    ),
    BotProfile(
      id: 'bot_global',
      name: 'Alex Rivera',
      tag: '#BOT-GLOBAL',
      flagEmoji: '🌐',
      avatar: 'avatar_girl_cap_glasses',
      penModel: 'neonSpinner',
      title: 'Global Tabletop Ace',
    ),
    BotProfile(
      id: 'bot_titanium',
      name: 'Titanium Tanvir',
      tag: '#BOT-TITAN',
      flagEmoji: '🇧🇩',
      avatar: 'avatar_tanvir_cyber',
      penModel: 'titaniumStriker',
      title: 'National Bench Champion',
    ),
  ];

  static BotProfile getRandom() {
    return predefined[DateTime.now().millisecondsSinceEpoch %
        predefined.length];
  }
}

enum AvatarCategory { cartoon, animal, pixel }

class AvatarOption {
  final String id;
  final String name;
  final String assetPath;
  final AvatarCategory category;

  const AvatarOption({
    required this.id,
    required this.name,
    required this.assetPath,
    this.category = AvatarCategory.cartoon,
  });
}

class AppAvatars {
  // 1. Cute Mascot Animals (10 avatars)
  static const List<AvatarOption> cuteAnimals = [
    AvatarOption(
      id: 'avatar_fox',
      name: 'Snowy Fox',
      assetPath: 'assets/avatars/avatar_fox.webp',
      category: AvatarCategory.animal,
    ),
    AvatarOption(
      id: 'avatar_polar_bear',
      name: 'Polar Bear',
      assetPath: 'assets/avatars/avatar_polar_bear.webp',
      category: AvatarCategory.animal,
    ),
    AvatarOption(
      id: 'avatar_penguin',
      name: 'Pippy Penguin',
      assetPath: 'assets/avatars/avatar_penguin.webp',
      category: AvatarCategory.animal,
    ),
    AvatarOption(
      id: 'avatar_deer',
      name: 'Forest Fawn',
      assetPath: 'assets/avatars/avatar_deer.webp',
      category: AvatarCategory.animal,
    ),
    AvatarOption(
      id: 'avatar_seal',
      name: 'Sammie Seal',
      assetPath: 'assets/avatars/avatar_seal.webp',
      category: AvatarCategory.animal,
    ),
    AvatarOption(
      id: 'avatar_owl',
      name: 'Wise Owl',
      assetPath: 'assets/avatars/avatar_owl.webp',
      category: AvatarCategory.animal,
    ),
    AvatarOption(
      id: 'avatar_red_panda',
      name: 'Rusty Panda',
      assetPath: 'assets/avatars/avatar_red_panda.webp',
      category: AvatarCategory.animal,
    ),
    AvatarOption(
      id: 'avatar_shiba',
      name: 'Hachi Shiba',
      assetPath: 'assets/avatars/avatar_shiba.webp',
      category: AvatarCategory.animal,
    ),
    AvatarOption(
      id: 'avatar_calico_cat',
      name: 'Mochi Cat',
      assetPath: 'assets/avatars/avatar_calico_cat.webp',
      category: AvatarCategory.animal,
    ),
    AvatarOption(
      id: 'avatar_otter',
      name: 'Ollie Otter',
      assetPath: 'assets/avatars/avatar_otter.webp',
      category: AvatarCategory.animal,
    ),
  ];

  // 2. Diverse Modern Cartoon People (24 avatars)
  static const List<AvatarOption> cartoonHumans = [
    AvatarOption(
      id: 'avatar_girl_afro',
      name: 'Amara (Afro)',
      assetPath: 'assets/avatars/avatar_girl_afro.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_headset',
      name: 'Tariq (Headset)',
      assetPath: 'assets/avatars/avatar_boy_headset.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_girl_hijab',
      name: 'Nusrat (Hijab)',
      assetPath: 'assets/avatars/avatar_girl_hijab.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_cap',
      name: 'Rahim (Street Cap)',
      assetPath: 'assets/avatars/avatar_boy_cap.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_hoodie',
      name: 'Siam (Hoodie)',
      assetPath: 'assets/avatars/avatar_boy_hoodie.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_girl_pink_hair',
      name: 'Sakura (Pink)',
      assetPath: 'assets/avatars/avatar_girl_pink_hair.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_gamer_glasses',
      name: 'Fahim (Pro Gamer)',
      assetPath: 'assets/avatars/avatar_gamer_glasses.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_girl_bun',
      name: 'Meher (Bun)',
      assetPath: 'assets/avatars/avatar_girl_bun.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_anime',
      name: 'Riku (Anime)',
      assetPath: 'assets/avatars/avatar_boy_anime.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_blonde',
      name: 'Leon (Smile)',
      assetPath: 'assets/avatars/avatar_boy_blonde.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_beanie',
      name: 'Arman (Beanie)',
      assetPath: 'assets/avatars/avatar_boy_beanie.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_girl_cap_glasses',
      name: 'Anika (Cap)',
      assetPath: 'assets/avatars/avatar_girl_cap_glasses.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_gamer_pro_boy',
      name: 'Sami (Esports)',
      assetPath: 'assets/avatars/avatar_gamer_pro_boy.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_pro_streamer',
      name: 'Rayhan (Streamer)',
      assetPath: 'assets/avatars/avatar_pro_streamer.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_curly',
      name: 'Zubair (Curly)',
      assetPath: 'assets/avatars/avatar_boy_curly.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_dj_headset',
      name: 'DJ Shakil',
      assetPath: 'assets/avatars/avatar_dj_headset.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_jacket',
      name: 'Kabir (Jacket)',
      assetPath: 'assets/avatars/avatar_boy_jacket.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_girl_blonde',
      name: 'Maya (Blonde)',
      assetPath: 'assets/avatars/avatar_girl_blonde.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_winter_hat',
      name: 'Rifat (Winter)',
      assetPath: 'assets/avatars/avatar_boy_winter_hat.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_girl_blue_hair',
      name: 'Zara (Blue Hair)',
      assetPath: 'assets/avatars/avatar_girl_blue_hair.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_girl_casual',
      name: 'Tasnim (Casual)',
      assetPath: 'assets/avatars/avatar_girl_casual.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_boy_nerd_glasses',
      name: 'Nabil (Glasses)',
      assetPath: 'assets/avatars/avatar_boy_nerd_glasses.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_girl_cyan_hair',
      name: 'Nova (Cyan)',
      assetPath: 'assets/avatars/avatar_girl_cyan_hair.webp',
      category: AvatarCategory.cartoon,
    ),
    AvatarOption(
      id: 'avatar_girl_wavy',
      name: 'Rhea (Wavy)',
      assetPath: 'assets/avatars/avatar_girl_wavy.webp',
      category: AvatarCategory.cartoon,
    ),
  ];

  // 3. Pixel Art Legends (10 avatars)
  static const List<AvatarOption> pixelChamps = [
    AvatarOption(
      id: 'avatar_shuvo',
      name: 'Shuvo (Student)',
      assetPath: 'assets/avatars/avatar_shuvo.webp',
      category: AvatarCategory.pixel,
    ),
    AvatarOption(
      id: 'avatar_tania_vr',
      name: 'Tania (VR Gamer)',
      assetPath: 'assets/avatars/avatar_tania_vr.webp',
      category: AvatarCategory.pixel,
    ),
    AvatarOption(
      id: 'avatar_arafat',
      name: 'Arafat (Striker)',
      assetPath: 'assets/avatars/avatar_arafat.webp',
      category: AvatarCategory.pixel,
    ),
    AvatarOption(
      id: 'avatar_mimi_cat',
      name: 'Mimi (Kawaii)',
      assetPath: 'assets/avatars/avatar_mimi_cat.webp',
      category: AvatarCategory.pixel,
    ),
    AvatarOption(
      id: 'avatar_tanvir_cyber',
      name: 'Tanvir (Cyber)',
      assetPath: 'assets/avatars/avatar_tanvir_cyber.webp',
      category: AvatarCategory.pixel,
    ),
    AvatarOption(
      id: 'avatar_rakib_dj',
      name: 'Rakib (DJ Beats)',
      assetPath: 'assets/avatars/avatar_rakib_dj.webp',
      category: AvatarCategory.pixel,
    ),
    AvatarOption(
      id: 'avatar_priya_elf',
      name: 'Priya (Nature)',
      assetPath: 'assets/avatars/avatar_priya_elf.webp',
      category: AvatarCategory.pixel,
    ),
    AvatarOption(
      id: 'avatar_karim_pro',
      name: 'Karim (Veteran)',
      assetPath: 'assets/avatars/avatar_karim_pro.webp',
      category: AvatarCategory.pixel,
    ),
    AvatarOption(
      id: 'avatar_samia_sun',
      name: 'Samia (Summer)',
      assetPath: 'assets/avatars/avatar_samia_sun.webp',
      category: AvatarCategory.pixel,
    ),
    AvatarOption(
      id: 'avatar_rohit_neon',
      name: 'Rohit (Neon)',
      assetPath: 'assets/avatars/avatar_rohit_neon.webp',
      category: AvatarCategory.pixel,
    ),
  ];

  static List<AvatarOption> get all => [
    ...cartoonHumans,
    ...cuteAnimals,
    ...pixelChamps,
  ];
  static List<AvatarOption> get list => all;

  static String getRandomId() {
    final allList = all;
    return allList[DateTime.now().microsecondsSinceEpoch % allList.length].id;
  }

  static String getAssetPath(String avatarId) {
    if (avatarId.startsWith('http://') || avatarId.startsWith('https://')) {
      return avatarId;
    }
    if (avatarId == 'avatar_student_boy' || avatarId.isEmpty) {
      return 'assets/avatars/avatar_shuvo.webp';
    }
    if (avatarId == 'avatar_pro_bangla') {
      return 'assets/avatars/avatar_karim_pro.webp';
    }
    if (avatarId.startsWith('assets/')) return avatarId;
    if (avatarId.endsWith('.webp')) return 'assets/avatars/$avatarId';
    return 'assets/avatars/$avatarId.webp';
  }
}
