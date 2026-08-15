import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/wallpaper_item.dart';
import '../../core/services/download_service.dart';
import '../../core/services/native_wallpaper_service.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/gradient_button.dart';

class VideoPreviewScreen extends StatefulWidget {
  final WallpaperItem? item;
  final String? localVideoPath;

  const VideoPreviewScreen({
    super.key,
    this.item,
    this.localVideoPath,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isDownloading = false;
  String? _resolvedVideoPath;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.localVideoPath != null) {
      _resolvedVideoPath = widget.localVideoPath;
      _controller = VideoPlayerController.file(File(widget.localVideoPath!));
    } else if (widget.item?.videoUrl != null) {
      final videoUri = Uri.parse(widget.item!.videoUrl!);
      _controller = VideoPlayerController.networkUrl(videoUri);
    }

    if (_controller != null) {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(0.0); // Muted for live wallpaper
      await _controller!.play();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _applyLiveWallpaper() async {
    setState(() => _isDownloading = true);

    String? localPath = _resolvedVideoPath;

    // Download remote video if needed
    if (localPath == null && widget.item?.videoUrl != null) {
      final downloadService = context.read<DownloadService>();
      final file = await downloadService.downloadFile(
        widget.item!.videoUrl!,
        customFileName: 'live_loop_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      if (file != null) {
        localPath = file.path;
      }
    }

    if (localPath != null && mounted) {
      final success = await NativeWallpaperService.setLiveWallpaper(videoPath: localPath);
      if (mounted) {
        setState(() => _isDownloading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.surface,
              content: Text('Opening Live Wallpaper Settings...', style: TextStyle(color: Colors.white)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Could not launch Live Wallpaper service on this device.'),
            ),
          );
        }
      }
    } else if (mounted) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Failed to prepare video file.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video Playback Area
          if (_isInitialized && _controller != null)
            Center(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            ),

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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.liveBadgeGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('LIVE LOOP PREVIEW', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.item?.title ?? 'Custom Gallery Video',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Native hardware-accelerated playback with 0% standby drain',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    text: AppStrings.applyLiveWallpaper,
                    icon: Icons.play_circle_filled_rounded,
                    isLoading: _isDownloading,
                    onPressed: _applyLiveWallpaper,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
