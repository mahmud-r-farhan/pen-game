import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/wallpaper_item.dart';
import '../../core/services/download_service.dart';
import '../../core/services/native_wallpaper_service.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/gradient_button.dart';
import 'image_cropper_screen.dart';
import 'widgets/set_wallpaper_dialog.dart';
import 'widgets/simulated_home_screen.dart';
import 'widgets/simulated_lock_screen.dart';

enum PreviewMode {
  clean,
  lock,
  home,
}

class PreviewScreen extends StatefulWidget {
  final WallpaperItem item;

  const PreviewScreen({super.key, required this.item});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  PreviewMode _previewMode = PreviewMode.clean;
  bool _isDownloading = false;
  bool _isSetting = false;

  Future<void> _applyWallpaper(WallpaperTarget target) async {
    setState(() => _isSetting = true);
    final downloadService = context.read<DownloadService>();

    // Download high-res version to disk first
    final file = await downloadService.downloadFile(widget.item.fullUrl);
    if (file != null && mounted) {
      final success = await NativeWallpaperService.setStaticWallpaper(
        filePath: file.path,
        target: target,
      );

      if (mounted) {
        setState(() => _isSetting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? AppColors.surface : AppColors.error,
            content: Text(
              success ? 'Successfully set wallpaper to ${target.name.toUpperCase()} screen!' : 'Failed to apply wallpaper.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } else if (mounted) {
      setState(() => _isSetting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Failed to download image file for setting.'),
        ),
      );
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isDownloading = true);
    final downloadService = context.read<DownloadService>();
    final file = await downloadService.downloadFile(widget.item.fullUrl);

    if (mounted) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: file != null ? AppColors.surface : AppColors.error,
          content: Text(
            file != null ? 'Saved to phone storage: ${file.path.split('/').last}' : 'Failed to download wallpaper.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _addToAutoQueue() async {
    final storage = context.read<StorageService>();
    final downloadService = context.read<DownloadService>();

    // If item doesn't have a local cached path, download it so the Native Receiver can read it offline
    WallpaperItem itemToQueue = widget.item;
    if (widget.item.localCachedPath == null || !File(widget.item.localCachedPath!).existsSync()) {
      final file = await downloadService.downloadFile(widget.item.fullUrl);
      if (file != null) {
        itemToQueue = widget.item.copyWith(localCachedPath: file.path);
      }
    }

    await storage.addToQueue(itemToQueue);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('Added to Auto-Changer Queue (Screen Unlock)', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  void _shareWallpaper() {
    Share.share(
      'Check out this stunning 4K wallpaper "${widget.item.title}" by ${widget.item.author} on Lumina Paper! ${widget.item.fullUrl}',
      subject: widget.item.title,
    );
  }

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_rounded, color: AppColors.textMuted, size: 16),
                const SizedBox(width: 6),
                Text('Author: ${widget.item.author}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.source_rounded, color: AppColors.textMuted, size: 16),
                const SizedBox(width: 6),
                Text('Provider: ${widget.item.source.name.toUpperCase()}', style: const TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            if (widget.item.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.item.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                  ),
                  child: Text('#$tag', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // High-Res Wallpaper Image
          Hero(
            tag: 'wallpaper_${widget.item.id}',
            child: widget.item.localCachedPath != null && File(widget.item.localCachedPath!).existsSync()
                ? Image.file(
                    File(widget.item.localCachedPath!),
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: widget.item.fullUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.secondary),
                      ),
                    ),
                  ),
          ),

          // Overlays based on Preview Mode
          if (_previewMode == PreviewMode.lock) const SimulatedLockScreen(),
          if (_previewMode == PreviewMode.home) const SimulatedHomeScreen(),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GlassContainer(
                      borderRadius: 14,
                      padding: const EdgeInsets.all(8),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                    ),
                    const Spacer(),
                    // Preview Mode Switcher Chips
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.glassBorder, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeChip('Clean', PreviewMode.clean),
                          _buildModeChip('Lock', PreviewMode.lock),
                          _buildModeChip('Home', PreviewMode.home),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassContainer(
                      borderRadius: 14,
                      padding: const EdgeInsets.all(8),
                      onTap: _showInfoSheet,
                      child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Glass Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Secondary Quick Utilities (Crop, Auto Queue, Save, Share)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickAction(
                        icon: Icons.crop_rounded,
                        label: 'Crop',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ImageCropperScreen(item: widget.item),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Auto Queue',
                        onTap: _addToAutoQueue,
                      ),
                      _buildQuickAction(
                        icon: _isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded,
                        label: 'Save',
                        onTap: _saveToGallery,
                      ),
                      _buildQuickAction(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        onTap: _shareWallpaper,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Main "Set as Wallpaper" Button
                  GradientButton(
                    text: AppStrings.applyWallpaper,
                    icon: Icons.wallpaper_rounded,
                    isLoading: _isSetting,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => SetWallpaperDialog(
                          onSelectTarget: (target) => _applyWallpaper(target),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, PreviewMode mode) {
    final isSelected = _previewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _previewMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassContainer(
          borderRadius: 16,
          padding: const EdgeInsets.all(10),
          onTap: onTap,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
