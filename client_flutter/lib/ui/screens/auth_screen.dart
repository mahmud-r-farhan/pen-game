// lib/ui/screens/auth_screen.dart
import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/local_practice_profile.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../widgets/brand_icons.dart';
import 'main_lobby_screen.dart';
import 'room_selection_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedRegion = 'bd';
  String _selectedDivision = 'Dhaka';
  bool _isLoading = false;

  final List<Map<String, String>> _regions = [
    {'code': 'bd', 'name': 'Bangladesh', 'flag': '🇧🇩'},
    {'code': 'in', 'name': 'India', 'flag': '🇮🇳'},
    {'code': 'pk', 'name': 'Pakistan', 'flag': '🇵🇰'},
    {'code': 'us', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': 'global', 'name': 'Global / Other', 'flag': '🌐'},
  ];

  final List<String> _divisions = [
    'Dhaka',
    'Chattogram',
    'Rajshahi',
    'Khulna',
    'Sylhet',
    'Barishal',
    'Rangpur',
    'Mymensingh',
    'Delhi',
    'Kolkata',
    'Mumbai',
    'Punjab',
    'New York',
    'California',
    'International',
  ];

  Future<void> _handleGuestLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final reg = _regions.firstWhere((r) => r['code'] == _selectedRegion);
      await AuthService().loginAsGuest(
        desiredName: name.isNotEmpty ? name : null,
        division: _selectedDivision,
        region: reg['code']!,
        flagEmoji: reg['flag']!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainLobbyScreen()),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOfflinePractice() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final region = _regions.firstWhere((r) => r['code'] == _selectedRegion);
      final profile = await LocalPracticeProfile.getOrCreate(
        desiredName: _nameController.text,
        division: _selectedDivision,
        region: region['code']!,
        flagEmoji: region['flag']!,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              RoomSelectionScreen(isOnline: false, practiceProfile: profile),
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final profile = await AuthService().signInWithGoogle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome ${profile.username}! Your cloud profile is synchronized.',
          ),
          backgroundColor: AppColors.emeraldTurn,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainLobbyScreen()),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: AppColors.crimsonStrike,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.currentCode,
      builder: (context, code, child) {
        return Scaffold(
          backgroundColor: AppColors.bgObsidian,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Branding
                      const Icon(
                        Icons.sports_esports_rounded,
                        color: AppColors.goldTiffinCoin,
                        size: 54,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'KOLOM FIGHT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocale.tr('physics_kolom_championship'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.goldTiffinCoin,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Nickname Input
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.glassSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            icon: Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.goldTiffinCoin,
                            ),
                            hintText: 'Enter player nickname',
                            hintStyle: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Region & Flag Selector
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.glassSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.public_rounded,
                              color: AppColors.cyanSpin,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Country / Region:',
                              style: TextStyle(
                                color: AppColors.slateMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRegion,
                                  isExpanded: true,
                                  dropdownColor: AppColors.bgSurfaceDark,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items: _regions.map((r) {
                                    return DropdownMenuItem(
                                      value: r['code'],
                                      child: Row(
                                        children: [
                                          Text(
                                            r['flag']!,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              r['name']!,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => _selectedRegion = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Division Dropdown
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.glassSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.crimsonStrike,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Division / City:',
                              style: TextStyle(
                                color: AppColors.slateMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedDivision,
                                  isExpanded: true,
                                  dropdownColor: AppColors.bgSurfaceDark,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  items: _divisions.map((d) {
                                    return DropdownMenuItem(
                                      value: d,
                                      child: Text(
                                        d,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => _selectedDivision = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.goldTiffinCoin,
                          ),
                        )
                      else ...[
                        // 1. Guest Login Button (75 coins)
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleGuestLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldTiffinCoin,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                AppLocale.tr('play_as_guest'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '75 Coins',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Google Login Button (120 coins)
                        if (!AuthService().isGoogleAvailable)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              AppLocale.tr('google_unavailable'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.slateMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        OutlinedButton(
                          onPressed:
                              _isLoading || !AuthService().isGoogleAvailable
                              ? null
                              : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: AppColors.glassBorder,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: AppColors.glassSurface,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const GoogleGLogo(size: 20),
                              const SizedBox(width: 8),
                              Text(
                                AppLocale.tr('sign_in_google'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (AuthService().isGoogleAvailable) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.goldTiffinCoin.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.goldTiffinCoin,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    '120 Coins',
                                    style: TextStyle(
                                      color: AppColors.goldTiffinCoin,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          key: const Key('offline_practice_button'),
                          onPressed: _isLoading ? null : _handleOfflinePractice,
                          icon: const Icon(Icons.smart_toy_rounded),
                          label: Text(AppLocale.tr('practice_offline')),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocale.tr('practice_offline_note'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.glassSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: AppColors.cyanSpin,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tip: You can start with Guest mode (75 coins) and merge later with Google to preserve your trophies and pens!',
                                  style: TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
