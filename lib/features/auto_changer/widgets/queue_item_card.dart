import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/wallpaper_item.dart';

class QueueItemCard extends StatelessWidget {
  final WallpaperItem item;
  final int index;
  final VoidCallback onRemove;

  const QueueItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Row(
        children: [
          // Order Number
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 50,
              height: 50,
              child: item.localCachedPath != null && File(item.localCachedPath!).existsSync()
                  ? Image.file(File(item.localCachedPath!), fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: item.previewUrl.isNotEmpty ? item.previewUrl : item.fullUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(color: AppColors.surfaceLight),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  item.author,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),

          // Remove Button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            onPressed: onRemove,
          ),

          // Reorder Drag Handle
          const Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted, size: 22),
        ],
      ),
    );
  }
}
