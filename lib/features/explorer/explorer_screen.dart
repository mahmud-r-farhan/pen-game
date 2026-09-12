import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../core/api/wallpaper_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/category_model.dart';
import '../../core/models/filter_options.dart';
import '../../core/models/wallpaper_item.dart';
import '../../shared/widgets/glass_container.dart';
import 'widgets/category_selector.dart';
import 'widgets/search_filter_sheet.dart';
import 'widgets/shimmer_grid.dart';
import 'widgets/wallpaper_card.dart';

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<WallpaperItem> _wallpapers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _selectedCategoryId = 'curated';
  int _currentPage = 1;
  FilterOptions _filterOptions = const FilterOptions();
  int _requestRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadWallpapers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      if (!_isLoading && !_isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadWallpapers() async {
    final currentReqId = ++_requestRequestId;
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    final repo = context.read<WallpaperRepository>();
    List<WallpaperItem> results;

    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      results = await repo.searchWallpapers(query, page: 1, options: _filterOptions);
    } else if (_selectedCategoryId == 'curated') {
      results = await repo.getCuratedFeed(page: 1);
    } else {
      final cat = WallpaperCategory.defaultCategories.firstWhere((c) => c.id == _selectedCategoryId);
      results = await repo.searchWallpapers(cat.searchQuery, page: 1, options: _filterOptions);
    }

    if (mounted && currentReqId == _requestRequestId) {
      setState(() {
        _wallpapers = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final currentReqId = _requestRequestId;
    setState(() => _isLoadingMore = true);
    final repo = context.read<WallpaperRepository>();
    final nextPage = _currentPage + 1;

    List<WallpaperItem> newItems;
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      newItems = await repo.searchWallpapers(query, page: nextPage, options: _filterOptions);
    } else if (_selectedCategoryId == 'curated') {
      newItems = await repo.getCuratedFeed(page: nextPage);
    } else {
      final cat = WallpaperCategory.defaultCategories.firstWhere((c) => c.id == _selectedCategoryId);
      newItems = await repo.searchWallpapers(cat.searchQuery, page: nextPage, options: _filterOptions);
    }

    if (mounted && currentReqId == _requestRequestId) {
      setState(() {
        _currentPage = nextPage;
        _wallpapers.addAll(newItems);
        _isLoadingMore = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onCategorySelected(WallpaperCategory category) {
    if (_selectedCategoryId == category.id) return;
    _searchController.clear();
    setState(() {
      _selectedCategoryId = category.id;
    });
    _loadWallpapers();
  }

  void _openFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SearchFilterSheet(
        initialOptions: _filterOptions,
        onApply: (newOptions) {
          setState(() => _filterOptions = newOptions);
          _loadWallpapers();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.secondary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadWallpapers,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Lumina Paper App Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.appName,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            AppStrings.appTagline,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GlassContainer(
                        borderRadius: 14,
                        padding: const EdgeInsets.all(10),
                        onTap: _openFilterModal,
                        child: const Icon(Icons.tune_rounded, color: AppColors.secondary, size: 20),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GlassContainer(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: AppStrings.searchHint,
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                        icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 22),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadWallpapers();
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _loadWallpapers(),
                    ),
                  ),
                ),
              ),

              // Horizontal Category Filter
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: CategorySelector(
                    selectedCategoryId: _selectedCategoryId,
                    onCategorySelected: _onCategorySelected,
                  ),
                ),
              ),

              // Grid Content or Loading Shimmer
              if (_isLoading)
                const SliverToBoxAdapter(child: ShimmerGrid(itemCount: 8))
              else if (_wallpapers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 54),
                        const SizedBox(height: 12),
                        const Text(
                          'No wallpapers found',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try searching for another keyword or reset filters',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            _searchController.clear();
                            _filterOptions = const FilterOptions();
                            _loadWallpapers();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text('Reset Search', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    itemBuilder: (context, index) {
                      final item = _wallpapers[index];
                      return SizedBox(
                        height: (index % 3 == 0) ? 290 : 250,
                        child: WallpaperCard(item: item),
                      );
                    },
                    childCount: _wallpapers.length,
                  ),
                ),

              // Bottom Loader for Infinite Scroll
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.secondary, strokeWidth: 2.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
