// lib/ui/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../models/user_profile.dart';
import '../widgets/brand_icons.dart';
import '../widgets/kolom_avatar.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLinking = false;

  Future<void> _handleGoogleLink() async {
    if (_isLinking) return;
    setState(() => _isLinking = true);
    try {
      await AuthService().signInWithGoogle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.tr('merge_success')), backgroundColor: AppColors.emeraldTurn),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: AppColors.crimsonStrike),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _handleLogout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession().profile;

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
          AppLocale.tr('profile'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) => setState(() {}));
            },
            icon: const Icon(Icons.settings_rounded, color: AppColors.goldTiffinCoin),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. Avatar & Identity Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: KolomTheme.glassCardDecoration(radius: 24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showAvatarPicker(user),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        KolomAvatar(
                          avatar: user.avatar,
                          size: 80,
                          flagEmoji: user.flagEmoji,
                          borderColor: AppColors.goldTiffinCoin,
                          borderWidth: 2.5,
                          showGlow: true,
                        ),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppColors.goldTiffinCoin,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 14, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.username,
                    style: const TextStyle(
                      color: AppColors.chalkWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Player Tag: ${user.tag}',
                        style: KolomTheme.monoNumeric(
                          color: AppColors.goldTiffinCoin,
                          fontSize: 13,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: user.tag));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tag copied to clipboard!')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Region & Club Tags Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.glassSurfaceHeavy,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Text(
                          '${user.flagEmoji} ${user.region}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      if (user.clubName != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.cyanSpin.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.cyanSpin.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            '🛡️ ${user.clubTag ?? "[CLUB]"} ${user.clubName}',
                            style: const TextStyle(
                              color: AppColors.cyanSpin,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Currencies & Trophy Cup Status Card (Coins != Points!)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: KolomTheme.glassCardDecoration(radius: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Virtual Currency Coins Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.glassSurfaceHeavy,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.goldTiffinCoin.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.monetization_on_rounded, color: AppColors.goldTiffinCoin, size: 18),
                                  SizedBox(width: 5),
                                  Text(
                                    'Virtual Coins',
                                    style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${user.coins}',
                                style: KolomTheme.monoNumeric(
                                  color: AppColors.goldTiffinCoin,
                                  fontSize: 20,
                                ),
                              ),
                              const Text(
                                'Match Stakes & Garage',
                                style: TextStyle(color: Colors.white30, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Skill Rating Trophy Points Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.glassSurfaceHeavy,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: user.cupColor.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.military_tech_rounded, color: user.cupColor, size: 18),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'Rating Points',
                                    style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${user.trophyPoints} RP',
                                style: KolomTheme.monoNumeric(
                                  color: user.cupColor,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                user.cupTitle,
                                style: TextStyle(
                                  color: user.cupColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Level & Career Statistics
            Container(
              padding: const EdgeInsets.all(16),
              decoration: KolomTheme.glassCardDecoration(radius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Level ${user.level}',
                        style: const TextStyle(
                          color: AppColors.goldTiffinCoin,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Next Level: ${(user.xpProgress * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: user.xpProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      color: AppColors.goldTiffinCoin,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _buildStatBox('Total Matches', '${user.stats.totalMatches}', Colors.white70),
                      _buildStatBox('Wins', '${user.stats.wins}', AppColors.emeraldTurn),
                      _buildStatBox('Win Rate', '${user.winRate.toStringAsFixed(1)}%', AppColors.goldTiffinCoin),
                      _buildStatBox('Streak', '${user.stats.winStreak}🔥', AppColors.crimsonStrike),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Account Link & Cloud Synchronization (Guest vs Authenticated)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: user.isGuest
                    ? AppColors.goldTiffinCoin.withValues(alpha: 0.10)
                    : AppColors.emeraldTurn.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: user.isGuest ? AppColors.goldTiffinCoin : AppColors.emeraldTurn,
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        user.isGuest ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                        color: user.isGuest ? AppColors.goldTiffinCoin : AppColors.emeraldTurn,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user.isGuest ? 'Guest Mode Account' : 'Verified Google Account',
                        style: TextStyle(
                          color: user.isGuest ? AppColors.goldTiffinCoin : AppColors.emeraldTurn,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.isGuest
                        ? 'You are playing as a Guest. Link your Google account to merge your coins, unlocked pens, and trophies safely to the cloud!'
                        : 'Your progress, coins, and trophies are safely synced to the cloud.',
                    style: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                  ),
                  if (user.isGuest) ...[
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _isLinking ? null : _handleGoogleLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldTiffinCoin,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const GoogleGLogo(size: 20),
                          const SizedBox(width: 8),
                          Text(
                            AppLocale.tr('link_google'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 5. Logout & Switch Account
            Container(
              decoration: KolomTheme.glassCardDecoration(radius: 16),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.crimsonStrike),
                title: const Text('Logout / Switch Account', style: TextStyle(color: AppColors.crimsonStrike)),
                onTap: _handleLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarPicker(UserProfile user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AvatarPickerModal(
        currentUser: user,
        onAvatarSelected: (selectedId) async {
          await UserSession().updateAvatar(selectedId);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.glassSurfaceHeavy,
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.slateMuted, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _AvatarPickerModal extends StatefulWidget {
  final UserProfile currentUser;
  final ValueChanged<String> onAvatarSelected;

  const _AvatarPickerModal({
    required this.currentUser,
    required this.onAvatarSelected,
  });

  @override
  State<_AvatarPickerModal> createState() => _AvatarPickerModalState();
}

class _AvatarPickerModalState extends State<_AvatarPickerModal> {
  int _selectedCategoryIndex = 0; // 0: All, 1: Cartoon, 2: Animals, 3: Pixel

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final hasGooglePhoto = (user.googlePhotoUrl != null && user.googlePhotoUrl!.isNotEmpty);
    final isGooglePhotoActive = user.avatar == user.googlePhotoUrl;

    List<AvatarOption> displayedList;
    switch (_selectedCategoryIndex) {
      case 1:
        displayedList = AppAvatars.cartoonHumans;
        break;
      case 2:
        displayedList = AppAvatars.cuteAnimals;
        break;
      case 3:
        displayedList = AppAvatars.pixelChamps;
        break;
      default:
        displayedList = AppAvatars.all;
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.bgSurfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Profile Picture',
                    style: TextStyle(
                      color: AppColors.chalkWhite,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Select from 44 avatars or use Google account photo',
                    style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Google Account Photo Restore Card (Visible if signed in with Google)
          if (hasGooglePhoto) ...[
            InkWell(
              onTap: () {
                widget.onAvatarSelected(user.googlePhotoUrl!);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile picture set to your Google account photo!'),
                    backgroundColor: AppColors.emeraldTurn,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isGooglePhotoActive
                      ? Colors.blueAccent.withValues(alpha: 0.15)
                      : AppColors.glassSurfaceHeavy,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isGooglePhotoActive ? Colors.blueAccent : AppColors.glassBorder,
                    width: isGooglePhotoActive ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    KolomAvatar(
                      avatar: user.googlePhotoUrl!,
                      size: 46,
                      borderColor: isGooglePhotoActive ? Colors.blueAccent : Colors.white24,
                      borderWidth: 2.0,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Google Account Photo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isGooglePhotoActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.emeraldTurn,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isGooglePhotoActive
                                ? 'Your Google profile picture is currently active.'
                                : 'Tap to switch back to your Google profile picture anytime.',
                            style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.sync_rounded, color: Colors.blueAccent, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip(0, 'All (${AppAvatars.all.length})', Icons.auto_awesome_rounded),
                const SizedBox(width: 8),
                _buildCategoryChip(1, '🧑 Cartoon (${AppAvatars.cartoonHumans.length})', Icons.person_rounded),
                const SizedBox(width: 8),
                _buildCategoryChip(2, '🐾 Animals (${AppAvatars.cuteAnimals.length})', Icons.pets_rounded),
                const SizedBox(width: 8),
                _buildCategoryChip(3, '👾 Pixel (${AppAvatars.pixelChamps.length})', Icons.sports_esports_rounded),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Avatars Grid
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: displayedList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final opt = displayedList[index];
                final isSelected = user.avatar == opt.id;

                return InkWell(
                  onTap: () {
                    widget.onAvatarSelected(opt.id);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Avatar changed to ${opt.name}!'),
                        backgroundColor: AppColors.emeraldTurn,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.goldTiffinCoin.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.goldTiffinCoin : Colors.white12,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.goldTiffinCoin.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        KolomAvatar(
                          avatar: opt.id,
                          size: 44,
                          borderColor: isSelected ? AppColors.goldTiffinCoin : Colors.transparent,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          opt.name.split(' ').first,
                          style: TextStyle(
                            color: isSelected ? AppColors.goldTiffinCoin : Colors.white70,
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int index, String label, IconData icon) {
    final isSelected = _selectedCategoryIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedCategoryIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.goldTiffinCoin : AppColors.glassSurfaceHeavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.goldTiffinCoin : AppColors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

