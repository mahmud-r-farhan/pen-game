import 'package:flutter_test/flutter_test.dart';
import 'package:luminapaper/core/api/curated_presets.dart';
import 'package:luminapaper/core/constants/app_colors.dart';
import 'package:luminapaper/core/constants/app_strings.dart';
import 'package:luminapaper/core/models/category_model.dart';
import 'package:luminapaper/core/models/filter_options.dart';
import 'package:luminapaper/core/models/wallpaper_item.dart';

void main() {
  group('Lumina Paper Core Tests', () {
    test('WallpaperItem serialization and deserialization', () {
      final item = WallpaperItem(
        id: 'test_123',
        title: 'Test 4K Wallpaper',
        author: 'Senior Engineer',
        previewUrl: 'https://example.com/preview.jpg',
        fullUrl: 'https://example.com/full.jpg',
        rawUrl: 'https://example.com/raw.jpg',
        source: WallpaperSource.pexels,
        tags: ['amoled', 'space', '4k'],
        width: 1440,
        height: 2560,
      );

      final json = item.toJson();
      expect(json['id'], 'test_123');
      expect(json['title'], 'Test 4K Wallpaper');
      expect(json['source'], 'pexels');

      final deserialized = WallpaperItem.fromJson(json);
      expect(deserialized.id, item.id);
      expect(deserialized.title, item.title);
      expect(deserialized.author, item.author);
      expect(deserialized.source, WallpaperSource.pexels);
      expect(deserialized.tags.length, 3);
      expect(deserialized.isVideo, false);
    });

    test('Live Video Wallpaper detection', () {
      final videoItem = WallpaperItem(
        id: 'video_1',
        title: 'Neon Loop',
        author: 'Motion Studio',
        previewUrl: 'https://example.com/preview.jpg',
        fullUrl: 'https://example.com/full.jpg',
        rawUrl: 'https://example.com/raw.jpg',
        videoUrl: 'https://example.com/loop.mp4',
        mediaType: WallpaperMediaType.video,
        source: WallpaperSource.curated,
      );

      expect(videoItem.isVideo, true);
      expect(videoItem.videoUrl, 'https://example.com/loop.mp4');
    });

    test('CuratedPresets dataset validity', () {
      final wallpapers = CuratedPresets.getCuratedWallpapers();
      expect(wallpapers.isNotEmpty, true);
      for (final w in wallpapers) {
        expect(w.id.isNotEmpty, true);
        expect(w.fullUrl.startsWith('http'), true);
        expect(w.previewUrl.startsWith('http'), true);
        expect(w.tags.isNotEmpty, true);
      }

      final videos = CuratedPresets.getCuratedLiveVideos();
      expect(videos.isNotEmpty, true);
      for (final v in videos) {
        expect(v.isVideo, true);
        expect(v.videoUrl?.isNotEmpty, true);
      }
    });

    test('Default Wallpaper Categories validity', () {
      final categories = WallpaperCategory.defaultCategories;
      expect(categories.length >= 6, true);
      expect(categories.any((c) => c.id == 'curated'), true);
      expect(categories.any((c) => c.id == 'amoled'), true);
      expect(categories.any((c) => c.id == 'anime'), true);
      expect(categories.any((c) => c.id == 'space'), true);
    });

    test('FilterOptions copyWith behavior', () {
      const initial = FilterOptions(
        orientation: WallpaperOrientation.portrait,
        sort: WallpaperSort.popular,
      );

      final updated = initial.copyWith(
        preferredSource: WallpaperSource.wallhaven,
        onlyAmoled: true,
      );

      expect(updated.preferredSource, WallpaperSource.wallhaven);
      expect(updated.onlyAmoled, true);
      expect(updated.orientation, WallpaperOrientation.portrait);

      final cleared = updated.copyWith(clearSource: true);
      expect(cleared.preferredSource, null);
    });

    test('App metadata integrity', () {
      expect(AppStrings.appName, 'Lumina Paper');
      expect(AppColors.background, isNotNull);
      expect(AppColors.primary, isNotNull);
    });

    test('WallpaperItem copyWith behavior and localCachedPath', () {
      final original = WallpaperItem(
        id: 'orig_1',
        title: 'Original Title',
        author: 'Original Author',
        previewUrl: 'https://example.com/p.jpg',
        fullUrl: 'https://example.com/f.jpg',
        rawUrl: 'https://example.com/r.jpg',
        source: WallpaperSource.pexels,
      );

      final updated = original.copyWith(
        localCachedPath: '/data/user/0/com.bb.luminapaper/app_flutter/wallpapers/lumina_123.jpg',
      );

      expect(updated.id, original.id);
      expect(updated.localCachedPath, '/data/user/0/com.bb.luminapaper/app_flutter/wallpapers/lumina_123.jpg');
      expect(updated.source, WallpaperSource.pexels);
    });
  });
}
