// lib/ui/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/network_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _sound = SoundEffects();
  late bool _soundEnabled;
  late bool _vibrationEnabled;

  @override
  void initState() {
    super.initState();
    _soundEnabled = _sound.soundEnabled;
    _vibrationEnabled = _sound.vibrationEnabled;
  }

  @override
  Widget build(BuildContext context) {
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
          AppLocale.tr('settings'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: AppLocale().currentLanguage,
        builder: (context, currentLang, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Language Selector
              _buildSectionHeader(AppLocale.tr('language')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: KolomTheme.glassCardDecoration(radius: 16),
                child: Column(
                  children: [
                    _buildLanguageTile(
                      label: 'English (Default)',
                      code: 'en',
                      flag: '🇺🇸',
                      selected: currentLang == 'en',
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    _buildLanguageTile(
                      label: 'বাংলা (Bengali)',
                      code: 'bn',
                      flag: '🇧🇩',
                      selected: currentLang == 'bn',
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    _buildLanguageTile(
                      label: 'हिन्दी (Hindi)',
                      code: 'hi',
                      flag: '🇮🇳',
                      selected: currentLang == 'hi',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Region & Flag Selector
              _buildSectionHeader(AppLocale.tr('region')),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: KolomTheme.glassCardDecoration(radius: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildRegionChip('Bangladesh', 'BD', '🇧🇩'),
                    _buildRegionChip('India', 'IN', '🇮🇳'),
                    _buildRegionChip('Pakistan', 'PK', '🇵🇰'),
                    _buildRegionChip('United States', 'US', '🇺🇸'),
                    _buildRegionChip('United Kingdom', 'GB', '🇬🇧'),
                    _buildRegionChip('Global', 'GLOBAL', '🌐'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Regional Division / District Selector
              _buildSectionHeader('Regional Division / District'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: KolomTheme.glassCardDecoration(radius: 16),
                child: Builder(
                  builder: (context) {
                    final user = UserSession().profile;
                    final divisions = _getDivisionsForRegion(user.region);
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: divisions.map((div) {
                        final isDivSelected = user.division == div;
                        return ChoiceChip(
                          label: Text(div),
                          selected: isDivSelected,
                          selectedColor: AppColors.goldTiffinCoin,
                          backgroundColor: AppColors.glassSurfaceHeavy,
                          labelStyle: TextStyle(
                            color: isDivSelected ? Colors.black : Colors.white70,
                            fontWeight: isDivSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (selected) async {
                            if (selected) {
                              await UserSession().setProfile(user.copyWith(division: div));
                              setState(() {});
                            }
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Audio & Feedback
              _buildSectionHeader('Audio & Haptics'),
              Container(
                decoration: KolomTheme.glassCardDecoration(radius: 16),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(AppLocale.tr('sound_effects'), style: const TextStyle(color: Colors.white)),
                      subtitle: const Text('Flicks, collision clacks, and victory fanfares', style: TextStyle(color: AppColors.slateMuted, fontSize: 12)),
                      activeThumbColor: AppColors.goldTiffinCoin,
                      value: _soundEnabled,
                      onChanged: (val) {
                        setState(() => _soundEnabled = val);
                        _sound.toggleSound(val);
                      },
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    SwitchListTile(
                      title: Text(AppLocale.tr('vibration'), style: const TextStyle(color: Colors.white)),
                      subtitle: const Text('Tactile haptic pulses on table impact and 30s timer warning', style: TextStyle(color: AppColors.slateMuted, fontSize: 12)),
                      activeThumbColor: AppColors.goldTiffinCoin,
                      value: _vibrationEnabled,
                      onChanged: (val) {
                        setState(() => _vibrationEnabled = val);
                        _sound.toggleVibration(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Server & Multiplayer Backend
              _buildSectionHeader('Multiplayer Backend (Deno Deploy)'),
              Container(
                decoration: KolomTheme.glassCardDecoration(radius: 16),
                child: ListTile(
                  leading: const Icon(Icons.cloud_sync_rounded, color: AppColors.cyanSpin),
                  title: const Text('Server Host', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    NetworkConfig.activeHost,
                    style: const TextStyle(color: AppColors.slateMuted, fontSize: 12, fontFamily: 'monospace'),
                  ),
                  trailing: const Icon(Icons.edit_rounded, color: AppColors.slateMuted, size: 18),
                  onTap: _showEditServerDialog,
                ),
              ),

              const SizedBox(height: 28),

              // Version / Build info
              Center(
                child: Text(
                  AppLocale.tr('version'),
                  style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.slateMuted,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required String label,
    required String code,
    required String flag,
    required bool selected,
  }) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.goldTiffinCoin : Colors.white,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.goldTiffinCoin)
          : null,
      onTap: () {
        AppLocale().setLanguage(code);
      },
    );
  }

  Widget _buildRegionChip(String label, String code, String flag) {
    final currentRegion = AppLocale().currentRegion.value;
    final isSelected = currentRegion == code;

    return InkWell(
      onTap: () async {
        await AppLocale().setRegion(code, flag);
        final user = UserSession().profile;
        await UserSession().setProfile(user.copyWith(region: code, flagEmoji: flag));
        setState(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.goldTiffinCoin.withValues(alpha: 0.2) : AppColors.glassSurfaceHeavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.goldTiffinCoin : AppColors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.goldTiffinCoin : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServerDialog() {
    final controller = TextEditingController(text: NetworkConfig.activeHost);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cloud_sync_rounded, color: AppColors.cyanSpin),
            SizedBox(width: 8),
            Text('Server Host', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Deno Deploy domain (e.g. your-app.deno.dev) or local test IP:',
              style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.glassSurfaceHeavy,
                hintText: 'kolom-fight.deno.dev',
                hintStyle: const TextStyle(color: Colors.white30),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              NetworkConfig.setCustomHost('').then((_) {
                if (mounted) setState(() {});
              });
            },
            child: const Text('Reset Default', style: TextStyle(color: AppColors.slateMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final newHost = controller.text.trim();
              Navigator.of(ctx).pop();
              if (newHost.isNotEmpty) {
                NetworkConfig.setCustomHost(newHost).then((_) {
                  if (mounted) setState(() {});
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldTiffinCoin,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<String> _getDivisionsForRegion(String region) {
    switch (region.toUpperCase()) {
      case 'BD':
      case 'BANGLADESH':
        return [
          'Dhaka',
          'Chattogram',
          'Sylhet',
          'Rajshahi',
          'Khulna',
          'Barishal',
          'Rangpur',
          'Mymensingh',
          'Comilla',
          'Bogura',
          'Pabna',
        ];
      case 'IN':
      case 'INDIA':
        return ['Kolkata', 'Delhi', 'Mumbai', 'Punjab', 'Bangalore', 'Hyderabad'];
      case 'PK':
      case 'PAKISTAN':
        return ['Lahore', 'Karachi', 'Islamabad', 'Peshawar', 'Rawalpindi'];
      case 'US':
      case 'UNITED STATES':
        return ['California', 'New York', 'Texas', 'Florida', 'Washington'];
      case 'GB':
      case 'UNITED KINGDOM':
        return ['London', 'Manchester', 'Birmingham', 'Leeds'];
      default:
        return ['International', 'Esports Global', 'Asia-Pacific', 'Europe', 'Americas'];
    }
  }
}
