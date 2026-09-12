import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../core/api/wallpaper_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/wallpaper_item.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/gradient_button.dart';
import '../explorer/widgets/shimmer_grid.dart';
import 'video_preview_screen.dart';

class LiveWallpaperScreen extends StatefulWidget {
  const LiveWallpaperScreen({super.key});

  @override
  State<LiveWallpaperScreen> createState() => _LiveWallpaperScreenState();
}

class _LiveWallpaperScreenState extends State<LiveWallpaperScreen> {
  List<WallpaperItem> _videos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLiveVideos();
  }

  Future<void> _loadLiveVideos() async {
    setState(() => _isLoading = true);
    final repo = context.read<WallpaperRepository>();
    final results = await repo.getLiveVideos(page: 1);
    if (mounted) {
      setState(() {
        _videos = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickLocalVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (!mounted) return;

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPreviewScreen(localVideoPath: path),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.secondary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadLiveVideos,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppColors.liveBadgeGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.liveTitle,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Hardware-accelerated 60fps video engine',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Custom Gallery Video Action Card
                      GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.movie_creation_rounded, color: AppColors.secondary, size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Create from Local Video',
                                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Select any MP4 from your phone gallery to set as a looping background',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            GradientButton(
                              text: AppStrings.pickCustomVideo,
                              icon: Icons.folder_open_rounded,
                              height: 46,
                              onPressed: _pickLocalVideo,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Trending Live Loops',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Video Grid
              if (_isLoading)
                const SliverToBoxAdapter(child: ShimmerGrid(itemCount: 4))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    itemBuilder: (context, index) {
                      final item = _videos[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VideoPreviewScreen(item: item),
                            ),
                          );
                        },
                        child: Container(
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.glassBorder, width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  item.previewUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surfaceLight),
                                ),
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white30, width: 1.5),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  left: 10,
                                  right: 10,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        item.author,
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _videos.length,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
