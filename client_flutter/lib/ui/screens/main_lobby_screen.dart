// lib/ui/screens/main_lobby_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/ws_client.dart';
import '../../game/rendering/procedural_kolom_painter.dart';
import '../../models/arena_room.dart';
import '../../models/kolom_spec.dart';
import '../widgets/coin_badge.dart';
import '../widgets/kolom_avatar.dart';
import 'clubs_screen.dart';
import 'friends_screen.dart';
import 'garage_shop_screen.dart';
import 'leaderboard_screen.dart';
import 'private_room_screen.dart';
import 'profile_screen.dart';
import 'room_selection_screen.dart';
import 'settings_screen.dart';

class MainLobbyScreen extends StatefulWidget {
  const MainLobbyScreen({super.key});

  @override
  State<MainLobbyScreen> createState() => _MainLobbyScreenState();
}

class _MainLobbyScreenState extends State<MainLobbyScreen> {
  int _currentNavIndex = 0;
  StreamSubscription? _challengeSub;

  @override
  void initState() {
    super.initState();
    UserSession().addListener(_onUserSessionUpdated);

    // Connect to WebSocket on lobby entry
    final profile = UserSession().profile;
    KolomWsClient().connect(profile);

    // Listen for incoming friend challenge invites!
    _challengeSub = KolomWsClient().onChallengeReceived.listen((data) {
      _showChallengeDialog(data);
    });
  }

  void _onUserSessionUpdated() {
    if (mounted) setState(() {});
  }

  void _showChallengeDialog(Map<String, dynamic> data) {
    final fromUser = data['fromUser'] as Map<String, dynamic>? ?? {};
    final fromName = fromUser['username'] as String? ?? 'Friend';
    final challengeId = data['challengeId'] as String? ?? '';
    final roomTypeId = data['roomTypeId'] as String? ?? 'primary_school';
    final arena = ArenaRoom.getById(roomTypeId);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.glassSurfaceHeavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.sports_esports_rounded, color: AppColors.goldTiffinCoin),
            SizedBox(width: 8),
            Text('Match Challenge!', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          '$fromName challenged you to a match in "${arena.name}" (${arena.entryCoins} Coins)!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              KolomWsClient().respondFriendChallenge(
                challengeId: challengeId,
                accept: false,
              );
            },
            child: const Text('Decline', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              final profile = UserSession().profile;
              KolomWsClient().respondFriendChallenge(
                challengeId: challengeId,
                accept: true,
                penModel: profile.equippedPen,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldTurn,
              foregroundColor: Colors.black,
            ),
            child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _watchAdForCoins() {
    SoundEffects().playCoin();
    final isBn = AppLocale.isBengali;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glassSurfaceHeavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.video_library_rounded, color: AppColors.goldTiffinCoin),
            const SizedBox(width: 8),
            Text(
              isBn ? 'ফ্রি কয়েন পান' : 'Watch Ad for Coins',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBn
                  ? 'একটি সংক্ষিপ্ত ভিডিও বিজ্ঞাপন দেখে ২৫০ কয়েন বিনামূল্যে অর্জন করুন!'
                  : 'Watch a short sponsored video ad to earn 250 Free Coins!',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.goldTiffinCoin.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.goldTiffinCoin.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: AppColors.goldTiffinCoin, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '+250 Coins Reward',
                    style: TextStyle(color: AppColors.goldTiffinCoin, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocale.tr('cancel'), style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isBn ? 'গেমটি বেটা মোডে আছে, সাথেই থাকুন! 🚀' : 'Game in beta mode, stay tuned! 🚀',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppColors.cyanSpin,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldTiffinCoin,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isBn ? 'কয়েন পান' : 'Earn Coins',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    UserSession().removeListener(_onUserSessionUpdated);
    _challengeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserSession().profile;
    final equippedPen = KolomSpec.getById(profile.equippedPen);

    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.currentCode,
      builder: (context, langCode, _) {
        return Scaffold(
          backgroundColor: AppColors.bgObsidian,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Top Bar: Profile, Flags, Cups, Coins & Settings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                        child: KolomAvatar(
                          avatar: profile.avatar,
                          size: 44,
                          flagEmoji: profile.flagEmoji,
                          borderColor: AppColors.goldTiffinCoin,
                          borderWidth: 1.8,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.username,
                              style: const TextStyle(
                                color: AppColors.chalkWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${profile.tag} • ${AppLocale.tr('level_label')} ${profile.level}',
                                  style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: profile.cupColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${profile.cupEmoji} ${profile.trophyPoints} ${AppLocale.tr('xp_label')}',
                                    style: TextStyle(color: profile.cupColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      CoinBadge(
                        coins: profile.coins,
                        onAddTap: _watchAdForCoins,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          ).then((_) => setState(() {}));
                        },
                        icon: const Icon(Icons.settings_rounded, color: AppColors.slateMuted, size: 22),
                      ),
                    ],
                  ),
                ),

                // 2. Equipped Pen Hero Stage (Slender 3D Vector Preview)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        equippedPen.accentColor.withValues(alpha: 0.18),
                        AppColors.glassSurfaceHeavy,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: equippedPen.accentColor.withValues(alpha: 0.4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                langCode == 'bn' ? 'সক্রিয় কলম' : (langCode == 'hi' ? 'सुसज्जित कलम' : 'EQUIPPED PEN'),
                                style: const TextStyle(color: AppColors.slateMuted, fontSize: 10, letterSpacing: 1.0),
                              ),
                              Text(
                                equippedPen.name,
                                style: const TextStyle(
                                  color: AppColors.chalkWhite,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const GarageShopScreen()),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: equippedPen.accentColor,
                              side: BorderSide(color: equippedPen.accentColor.withValues(alpha: 0.6)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.storefront_rounded, size: 14),
                            label: Text(AppLocale.tr('garage'), style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CustomPaint(
                        size: const Size(280, 48),
                        painter: _LobbyPenPainter(equippedPen),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        langCode == 'bn' ? equippedPen.tagLineBn : equippedPen.tagLineEn,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: equippedPen.accentColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // 3. Competitive Game Modes
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    children: [
                      // Daily Tiffin Retention Bonus
                      _buildDailyTiffinCard(langCode),
                      const SizedBox(height: 10),
                      _buildGameModeCard(
                        title: AppLocale.tr('quick_play'),
                        subtitle: AppLocale.tr('quick_play_sub'),
                        icon: Icons.flash_on_rounded,
                        accentColor: AppColors.goldTiffinCoin,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RoomSelectionScreen(isOnline: true)),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildGameModeCard(
                        title: AppLocale.tr('clubs'),
                        subtitle: AppLocale.tr('clubs_sub'),
                        icon: Icons.shield_rounded,
                        accentColor: AppColors.cyanSpin,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ClubsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildGameModeCard(
                        title: AppLocale.tr('private_room'),
                        subtitle: AppLocale.tr('private_room_sub'),
                        icon: Icons.group_rounded,
                        accentColor: AppColors.emeraldTurn,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PrivateRoomScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildGameModeCard(
                        title: AppLocale.tr('bot_practice'),
                        subtitle: AppLocale.tr('bot_practice_sub'),
                        icon: Icons.smart_toy_rounded,
                        accentColor: AppColors.slateMuted,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RoomSelectionScreen(isOnline: false)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentNavIndex,
            backgroundColor: AppColors.glassSurfaceHeavy,
            selectedItemColor: AppColors.goldTiffinCoin,
            unselectedItemColor: AppColors.slateMuted,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() => _currentNavIndex = index);
              if (index == 0) return;
              if (index == 1) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GarageShopScreen()));
              } else if (index == 2) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
              } else if (index == 3) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClubsScreen()));
              } else if (index == 4) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendsScreen()));
              }
            },
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.home_rounded), label: langCode == 'bn' ? 'লবি' : 'Lobby'),
              BottomNavigationBarItem(icon: const Icon(Icons.storefront_rounded), label: AppLocale.tr('garage')),
              BottomNavigationBarItem(icon: const Icon(Icons.leaderboard_rounded), label: langCode == 'bn' ? 'র‍্যাংক' : 'Ranks'),
              BottomNavigationBarItem(icon: const Icon(Icons.shield_rounded), label: langCode == 'bn' ? 'ক্লাব' : 'Clubs'),
              BottomNavigationBarItem(icon: const Icon(Icons.people_alt_rounded), label: langCode == 'bn' ? 'বন্ধুমহল' : 'Friends'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: KolomTheme.glassCardDecoration(radius: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.chalkWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTiffinCard(String langCode) {
    final isBn = langCode == 'bn';
    return InkWell(
      onTap: () async {
        final reward = await UserSession().claimDailyTiffin();
        if (!mounted) return;
        if (reward != null) {
          SoundEffects().playCoin();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isBn
                    ? '🎉 অভিনন্দন! টিফিন বাবদ +$reward কয়েন যোগ হয়েছে!'
                    : '🎉 Congratulations! +$reward Daily Tiffin Coins added!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppColors.emeraldTurn,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isBn
                    ? 'আজকের টিফিন ইতোমধ্যে নিয়েছেন! পরবর্তী টিফিন আগামীকাল পাবেন। 🎒'
                    : 'Already claimed today! Next tiffin allowance ready tomorrow. 🎒',
              ),
              backgroundColor: AppColors.cyanSpin,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.goldTiffinCoin.withValues(alpha: 0.20),
              AppColors.emeraldTurn.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldTiffinCoin.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.goldTiffinCoin.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Text('🎒', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBn ? 'দৈনিক টিফিন ভাতা (Free Coins)' : 'Daily Tiffin Bonus (Free Coins)',
                    style: const TextStyle(
                      color: AppColors.goldTiffinCoin,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    isBn
                        ? 'প্রতিদিন লগইন করে বিনামূল্যে +২০০ কয়েন বুঝে নিন!'
                        : 'Tap daily to collect +200 free allowance coins!',
                    style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.goldTiffinCoin,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isBn ? 'সংগ্রহ' : 'Claim',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LobbyPenPainter extends CustomPainter {
  final KolomSpec spec;
  _LobbyPenPainter(this.spec);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    ProceduralKolomPainter.drawPen(canvas, spec, scale: 28.0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
