import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/download_service.dart';
import '../../core/services/native_wallpaper_service.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/glass_container.dart';
import 'about_screen.dart';
import 'api_keys_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _cacheSize = 'Calculating...';
  bool _isLiveActive = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
    _checkLiveStatus();
  }

  Future<void> _loadCacheSize() async {
    final bytes = await context.read<DownloadService>().getCacheSizeInBytes();
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    if (mounted) {
      setState(() => _cacheSize = '$mb MB');
    }
  }

  Future<void> _checkLiveStatus() async {
    final active = await NativeWallpaperService.isLiveWallpaperActive();
    if (mounted) {
      setState(() => _isLiveActive = active);
    }
  }

  Future<void> _clearCache() async {
    await context.read<DownloadService>().clearCache();
    await _loadCacheSize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('Cache cleared successfully!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.navSettings,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Preferences & Engine Configuration',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Visual Themes
              const Text('Appearance', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(AppStrings.amoledMode, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('True pure black (#000000) for OLED battery savings', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  value: storage.isAmoledTheme,
                  activeTrackColor: AppColors.secondary,
                  onChanged: (val) => storage.setAmoledTheme(val),
                ),
              ),
              const SizedBox(height: 20),

              // Wallpaper Engines Status
              const Text('Engine Diagnostics', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStatusRow(
                      icon: Icons.screen_lock_portrait_rounded,
                      title: 'Screen Unlock Receiver',
                      status: storage.autoChangerEnabled ? 'Active' : 'Disabled',
                      isPositive: storage.autoChangerEnabled,
                    ),
                    const Divider(color: AppColors.glassBorder, height: 20),
                    _buildStatusRow(
                      icon: Icons.videocam_rounded,
                      title: 'Live Wallpaper Service',
                      status: _isLiveActive ? 'Active Engine' : 'Ready (Idle)',
                      isPositive: _isLiveActive,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Storage & Cache
              const Text('Data & Storage', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.cleaning_services_rounded, color: AppColors.secondary, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Temporary Cache', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                          Text('Usage: $_cacheSize', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _clearCache,
                      child: const Text('Clear', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Advanced & Developer
              const Text('Advanced Settings', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GlassContainer(
                borderRadius: 18,
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _buildNavTile(
                      icon: Icons.vpn_key_rounded,
                      title: AppStrings.customApiKeys,
                      subtitle: 'Configure personal Pexels, Pixabay, or NASA keys',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
                        );
                      },
                    ),
                    const Divider(color: AppColors.glassBorder, height: 1),
                    _buildNavTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About Lumina Paper',
                      subtitle: 'App version, licenses, and architecture',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        );
                      },
                    ),
                    const Divider(color: AppColors.glassBorder, height: 1),
                    _buildNavTile(
                      icon: Icons.star_rate_rounded,
                      title: AppStrings.rateApp,
                      subtitle: 'Support development on Google Play Console',
                      onTap: () async {
                        final uri = Uri.parse('market://details?id=com.bb.luminapaper');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
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

  Widget _buildStatusRow({required IconData icon, required String title, required String status, required bool isPositive}) {
    return Row(
      children: [
        Icon(icon, color: isPositive ? AppColors.success : AppColors.textMuted, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPositive ? AppColors.success.withValues(alpha: 0.15) : AppColors.surfaceHover,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isPositive ? AppColors.success.withValues(alpha: 0.4) : AppColors.glassBorder, width: 1),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: isPositive ? AppColors.success : AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.secondary, size: 22),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
      onTap: onTap,
    );
  }
}
