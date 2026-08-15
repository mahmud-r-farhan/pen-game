import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/wallpaper_item.dart';
import '../../core/services/download_service.dart';
import '../../core/services/native_wallpaper_service.dart';
import '../../shared/widgets/gradient_button.dart';
import 'widgets/set_wallpaper_dialog.dart';

class ImageCropperScreen extends StatefulWidget {
  final WallpaperItem item;

  const ImageCropperScreen({super.key, required this.item});

  @override
  State<ImageCropperScreen> createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  final TransformationController _transformController = TransformationController();
  bool _isApplying = false;

  Future<void> _applyFramedWallpaper(WallpaperTarget target) async {
    setState(() => _isApplying = true);
    final downloadService = context.read<DownloadService>();

    // Download full file to disk first
    final file = await downloadService.downloadFile(
      widget.item.fullUrl,
      customFileName: 'custom_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    if (file != null && mounted) {
      final success = await NativeWallpaperService.setStaticWallpaper(
        filePath: file.path,
        target: target,
      );

      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? AppColors.surface : AppColors.error,
            content: Text(
              success ? 'Wallpaper successfully set to ${target.name.toUpperCase()} screen!' : 'Failed to set wallpaper',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
        if (success) {
          Navigator.of(context).pop();
        }
      }
    } else if (mounted) {
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Failed to download image file for setting.'),
        ),
      );
    }
  }

  void _showSetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SetWallpaperDialog(
        onSelectTarget: (target) => _applyFramedWallpaper(target),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Frame & Aspect Ratio (9:16)'),
        backgroundColor: Colors.black54,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset Zoom',
            onPressed: () {
              _transformController.value = Matrix4.identity();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Crop Viewport with 9:16 Aspect Framing Guide
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.secondary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 1.0,
                      maxScale: 4.0,
                      panEnabled: true,
                      scaleEnabled: true,
                      child: widget.item.localCachedPath != null
                          ? Image.file(
                              File(widget.item.localCachedPath!),
                              fit: BoxFit.cover,
                            )
                          : CachedNetworkImage(
                              imageUrl: widget.item.fullUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(color: AppColors.secondary),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GradientButton(
                    text: 'Set Framed Wallpaper',
                    icon: Icons.check_circle_rounded,
                    isLoading: _isApplying,
                    onPressed: _showSetDialog,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
