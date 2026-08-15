import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/native_wallpaper_service.dart';

class SetWallpaperDialog extends StatelessWidget {
  final ValueChanged<WallpaperTarget> onSelectTarget;

  const SetWallpaperDialog({
    super.key,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.glassBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.applyWallpaper,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select where you would like to set this wallpaper',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildOption(
              icon: Icons.home_rounded,
              title: AppStrings.homeScreen,
              subtitle: 'Apply strictly to your main Home Screen',
              onTap: () {
                Navigator.of(context).pop();
                onSelectTarget(WallpaperTarget.home);
              },
            ),
            const SizedBox(height: 10),
            _buildOption(
              icon: Icons.lock_outline_rounded,
              title: AppStrings.lockScreen,
              subtitle: 'Apply to phone lock screen only',
              onTap: () {
                Navigator.of(context).pop();
                onSelectTarget(WallpaperTarget.lock);
              },
            ),
            const SizedBox(height: 10),
            _buildOption(
              icon: Icons.smartphone_rounded,
              title: AppStrings.bothScreens,
              subtitle: 'Apply seamlessly across both screens',
              isGradient: true,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTarget(WallpaperTarget.both);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isGradient = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isGradient ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGradient ? AppColors.primary : AppColors.glassBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isGradient ? AppColors.primary : AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}
