import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/filter_options.dart';
import '../../../core/models/wallpaper_item.dart';
import '../../../shared/widgets/gradient_button.dart';

class SearchFilterSheet extends StatefulWidget {
  final FilterOptions initialOptions;
  final ValueChanged<FilterOptions> onApply;

  const SearchFilterSheet({
    super.key,
    required this.initialOptions,
    required this.onApply,
  });

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  late WallpaperSource? _source;
  late WallpaperOrientation _orientation;
  late WallpaperSort _sort;
  late bool _onlyAmoled;

  @override
  void initState() {
    super.initState();
    _source = widget.initialOptions.preferredSource;
    _orientation = widget.initialOptions.orientation;
    _sort = widget.initialOptions.sort;
    _onlyAmoled = widget.initialOptions.onlyAmoled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Wallpapers',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _source = null;
                    _orientation = WallpaperOrientation.portrait;
                    _sort = WallpaperSort.popular;
                    _onlyAmoled = false;
                  });
                },
                child: const Text('Reset', style: TextStyle(color: AppColors.secondary)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Provider Filter
          const Text('Content Source', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildChoiceChip('All Sources', _source == null, () => setState(() => _source = null)),
              _buildChoiceChip('Pexels 4K', _source == WallpaperSource.pexels, () => setState(() => _source = WallpaperSource.pexels)),
              _buildChoiceChip('Pixabay HD', _source == WallpaperSource.pixabay, () => setState(() => _source = WallpaperSource.pixabay)),
              _buildChoiceChip('Wallhaven', _source == WallpaperSource.wallhaven, () => setState(() => _source = WallpaperSource.wallhaven)),
              _buildChoiceChip('NASA APOD', _source == WallpaperSource.nasa, () => setState(() => _source = WallpaperSource.nasa)),
              _buildChoiceChip('Anime Stream', _source == WallpaperSource.waifu, () => setState(() => _source = WallpaperSource.waifu)),
            ],
          ),
          const SizedBox(height: 18),

          // Orientation Filter
          const Text('Aspect & Orientation', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChoiceChip('Portrait (9:16)', _orientation == WallpaperOrientation.portrait, () => setState(() => _orientation = WallpaperOrientation.portrait)),
              const SizedBox(width: 8),
              _buildChoiceChip('Landscape (16:9)', _orientation == WallpaperOrientation.landscape, () => setState(() => _orientation = WallpaperOrientation.landscape)),
              const SizedBox(width: 8),
              _buildChoiceChip('All', _orientation == WallpaperOrientation.all, () => setState(() => _orientation = WallpaperOrientation.all)),
            ],
          ),
          const SizedBox(height: 18),

          // Pure AMOLED Toggle
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pure AMOLED Black Only', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: const Text('Prioritize high true black percentage (#000000)', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            value: _onlyAmoled,
            activeTrackColor: AppColors.secondary,
            onChanged: (val) => setState(() => _onlyAmoled = val),
          ),
          const SizedBox(height: 24),

          // Apply Button
          GradientButton(
            text: 'Apply Filters',
            icon: Icons.check_rounded,
            onPressed: () {
              widget.onApply(
                FilterOptions(
                  preferredSource: _source,
                  orientation: _orientation,
                  sort: _sort,
                  onlyAmoled: _onlyAmoled,
                ),
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.glassBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
