import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../shared/widgets/glass_container.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Lumina Paper'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Logo & Badge
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.appName,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Version ${AppStrings.appVersion} (Production Release)',
              style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),

            // Description
            GlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(18),
              child: const Text(
                'Lumina Paper is an ultra-lightweight, hardware-accelerated 4K wallpaper and live video wallpaper engine. It features an intelligent Screen Unlock Auto-Changer with zero standby battery drain and multi-source API failover.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Source Attribution
            GlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Content Partners & Attribution', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildPartnerRow('Pexels API', 'High quality 4K royalty-free photos & live loops'),
                  _buildPartnerRow('Pixabay API', 'Diverse global community photo & video repository'),
                  _buildPartnerRow('Wallhaven CC', 'Aesthetic 4K UHD and digital artwork streams'),
                  _buildPartnerRow('NASA APOD', 'Daily Astronomy Picture of the Day from JPL/NASA'),
                  _buildPartnerRow('Waifu.pics', 'Anime illustration feeds'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Copyright
            const Text(
              'Designed & Engineered for Google Play Console\n© 2026 Lumina Paper Team',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerRow(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
