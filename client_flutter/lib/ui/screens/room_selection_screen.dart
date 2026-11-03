// lib/ui/screens/room_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../models/arena_room.dart';
import '../../models/kolom_spec.dart';
import '../../models/user_profile.dart';
import '../widgets/coin_badge.dart';
import 'game_screen.dart';
import 'matchmaking_screen.dart';

class RoomSelectionScreen extends StatefulWidget {
  final bool isOnline;

  const RoomSelectionScreen({super.key, this.isOnline = true});

  @override
  State<RoomSelectionScreen> createState() => _RoomSelectionScreenState();
}

class _RoomSelectionScreenState extends State<RoomSelectionScreen> {
  late final PageController _pageController;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.82, initialPage: 0);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startMatch(ArenaRoom room, KolomSpec currentPen, UserProfile profile) {
    if (widget.isOnline && profile.coins < room.entryCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocale.tr('insufficient_coins')}! Need ${room.entryCoins} ${AppLocale.tr('coins')}.',
          ),
          backgroundColor: AppColors.crimsonStrike,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.isOnline
            ? MatchmakingScreen(room: room, playerPen: currentPen)
            : GameScreen(
                room: room,
                playerPen: currentPen,
                isOnline: false,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserSession().profile;
    final currentPen = KolomSpec.getById(profile.equippedPen);

    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.currentCode,
      builder: (context, langCode, _) {
        final title = widget.isOnline
            ? (langCode == 'bn' ? 'অনলাইন ১ বনাম ১ অ্যারেনা' : (langCode == 'hi' ? 'ऑनलाइन 1v1 अखाड़ा' : 'Online 1v1 Arenas'))
            : (langCode == 'bn' ? 'বট প্র্যাকটিস অ্যারেনা' : (langCode == 'hi' ? 'ऑफ़लाइन बॉट अखाड़ा' : 'Offline Bot Arenas'));

        return Scaffold(
          backgroundColor: AppColors.bgObsidian,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.chalkWhite),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CoinBadge(coins: profile.coins),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Subheader & Swipe hint
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swipe_rounded, color: AppColors.slateMuted, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        AppLocale.tr('swipe_hint'),
                        style: const TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Horizontal Carousel of Vertical Cards
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: ArenaRoom.rooms.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final room = ArenaRoom.rooms[index];
                      final bool canAfford = profile.coins >= room.entryCoins;

                      // Calculate 3D scale and opacity based on distance from current scroll position
                      final double diff = (_currentPage - index).abs();
                      final double scale = (1.0 - (diff * 0.12)).clamp(0.88, 1.0);
                      final double opacity = (1.0 - (diff * 0.35)).clamp(0.65, 1.0);

                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: _buildVerticalRoomCard(
                            room: room,
                            canAfford: canAfford,
                            langCode: langCode,
                            onTap: () => _startMatch(room, currentPen, profile),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Page Indicator Dots & Quick Jump Navigation
                _buildIndicatorRow(ArenaRoom.rooms.length),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalRoomCard({
    required ArenaRoom room,
    required bool canAfford,
    required String langCode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              room.tableColorStart.withValues(alpha: 0.95),
              room.tableColorEnd.withValues(alpha: 0.98),
              const Color(0xFF0D1117),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: room.neonGlowColor,
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: room.neonGlowColor.withValues(alpha: 0.40),
              blurRadius: 26,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              // Subtle ambient radial background glow
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                height: 220,
                child: Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          room.neonGlowColor.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Card Vertical Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top: Category and Tier Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: room.neonGlowColor.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            room.category.name.toUpperCase(),
                            style: TextStyle(
                              color: room.neonGlowColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (room.subCategory != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              room.subCategory!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Top: 3D Isometric Glowing Diorama Emblem
                    Expanded(
                      flex: 6,
                      child: Center(
                        child: Hero(
                          tag: 'arena_emblem_${room.id}',
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 230),
                            child: Image.asset(
                              room.assetPath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.account_balance_rounded,
                                  size: 110,
                                  color: room.neonGlowColor,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Name of the Room (Strictly localized)
                    Text(
                      room.localizedName(langCode),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Details / Description (Strictly localized)
                    Text(
                      room.localizedDescription(langCode),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Center: Entry Fee & Pot Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.goldTiffinCoin.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goldTiffinCoin.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Entry Fee
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocale.tr('entry_fee').toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.monetization_on_rounded, color: AppColors.goldTiffinCoin, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.isOnline
                                        ? NumberFormat.decimalPattern().format(room.entryCoins)
                                        : 'FREE',
                                    style: KolomTheme.monoNumeric(
                                      color: AppColors.goldTiffinCoin,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          Container(
                            height: 28,
                            width: 1,
                            color: Colors.white12,
                          ),

                          // Winner Pot
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocale.tr('winner_pot').toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.emeraldTurn,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.emoji_events_rounded, color: AppColors.emeraldTurn, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.isOnline
                                        ? NumberFormat.decimalPattern().format(room.payoutCoins)
                                        : 'PRACTICE',
                                    style: KolomTheme.monoNumeric(
                                      color: AppColors.emeraldTurn,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Table Surface & Physics Specs
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.speed_rounded, size: 14, color: AppColors.cyanSpin),
                              const SizedBox(width: 4),
                              Text(
                                room.localizedFriction(langCode),
                                style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.sports_baseball_rounded, size: 14, color: Colors.orangeAccent),
                              const SizedBox(width: 4),
                              Text(
                                '${(room.bounce * 100).toInt()}% Bounce',
                                style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Bottom: Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: canAfford ? onTap : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford ? room.neonGlowColor : Colors.grey.shade800,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey.shade900,
                          disabledForegroundColor: Colors.white30,
                          elevation: canAfford ? 8 : 0,
                          shadowColor: room.neonGlowColor.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              canAfford
                                  ? (widget.isOnline ? Icons.flash_on_rounded : Icons.smart_toy_rounded)
                                  : Icons.lock_outline_rounded,
                              size: 18,
                              color: canAfford ? Colors.black : Colors.white30,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              canAfford
                                  ? (widget.isOnline ? AppLocale.tr('play_1v1_duel') : AppLocale.tr('play_bot'))
                                  : AppLocale.tr('insufficient_coins'),
                              style: TextStyle(
                                color: canAfford ? Colors.black : Colors.white30,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorRow(int count) {
    final int activeIndex = _currentPage.round().clamp(0, count - 1);
    final activeRoom = ArenaRoom.rooms[activeIndex];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 16, color: Colors.white60),
          onPressed: activeIndex > 0
              ? () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                }
              : null,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (idx) {
            final bool isSelected = idx == activeIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? activeRoom.neonGlowColor : Colors.white24,
                borderRadius: BorderRadius.circular(3),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeRoom.neonGlowColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white60),
          onPressed: activeIndex < count - 1
              ? () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                }
              : null,
        ),
      ],
    );
  }
}
