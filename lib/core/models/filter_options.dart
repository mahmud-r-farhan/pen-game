import 'wallpaper_item.dart';

enum WallpaperOrientation {
  all,
  portrait,
  landscape,
}

enum WallpaperSort {
  popular,
  latest,
  curated,
}

class FilterOptions {
  final WallpaperSource? preferredSource;
  final WallpaperOrientation orientation;
  final WallpaperSort sort;
  final String? colorHex;
  final bool onlyAmoled;

  const FilterOptions({
    this.preferredSource,
    this.orientation = WallpaperOrientation.portrait,
    this.sort = WallpaperSort.popular,
    this.colorHex,
    this.onlyAmoled = false,
  });

  FilterOptions copyWith({
    WallpaperSource? preferredSource,
    WallpaperOrientation? orientation,
    WallpaperSort? sort,
    String? colorHex,
    bool? onlyAmoled,
    bool clearSource = false,
    bool clearColor = false,
  }) {
    return FilterOptions(
      preferredSource: clearSource ? null : (preferredSource ?? this.preferredSource),
      orientation: orientation ?? this.orientation,
      sort: sort ?? this.sort,
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      onlyAmoled: onlyAmoled ?? this.onlyAmoled,
    );
  }
}
