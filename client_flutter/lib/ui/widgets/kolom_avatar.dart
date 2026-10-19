// lib/ui/widgets/kolom_avatar.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_profile.dart';

class KolomAvatar extends StatelessWidget {
  final String avatar;
  final double size;
  final String? flagEmoji;
  final Color? borderColor;
  final double borderWidth;
  final bool showGlow;

  const KolomAvatar({
    super.key,
    required this.avatar,
    this.size = 40,
    this.flagEmoji,
    this.borderColor,
    this.borderWidth = 1.8,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = AppAvatars.getAssetPath(avatar);

    Widget avatarImage;
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      avatarImage = Image.network(
        avatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    } else {
      avatarImage = Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    Widget content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.glassSurfaceHeavy,
        border: Border.all(
          color: borderColor ?? AppColors.glassBorder,
          width: borderWidth,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: (borderColor ?? AppColors.goldTiffinCoin).withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipOval(child: avatarImage),
    );

    if (flagEmoji != null && flagEmoji!.isNotEmpty) {
      content = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomRight,
        children: [
          content,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: AppColors.bgObsidian,
                shape: BoxShape.circle,
              ),
              child: Text(
                flagEmoji!,
                style: TextStyle(fontSize: size * 0.36),
              ),
            ),
          ),
        ],
      );
    }

    return content;
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      color: AppColors.glassSurfaceHeavy,
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: AppColors.goldTiffinCoin,
      ),
    );
  }
}
