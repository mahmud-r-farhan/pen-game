import '../constants/api_constants.dart';
import '../models/wallpaper_item.dart';
import 'api_client.dart';

class WallhavenProvider {
  final ApiClient _client;

  WallhavenProvider(this._client);

  Future<List<WallpaperItem>> search(String query, {int page = 1, String categories = '111', String purity = '100', String sorting = 'toplist'}) async {
    try {
      final response = await _client.dio.get(
        '${ApiConstants.wallhavenBaseUrl}/search',
        queryParameters: {
          'q': query.isEmpty ? 'aesthetic' : query,
          'categories': categories,
          'purity': purity, // 100 = Safe for Work (SFW)
          'sorting': sorting,
          'page': page,
          'ratios': '9x16,10x16,9x18', // Mobile portrait focus
        },
      );

      final data = response.data['data'] as List<dynamic>? ?? [];
      return data.map((item) => _mapWallhaven(item)).toList();
    } catch (e) {
      return [];
    }
  }

  WallpaperItem _mapWallhaven(dynamic json) {
    final id = (json['id'] ?? '').toString();
    final path = json['path'] as String? ?? '';
    final thumbs = json['thumbs'] as Map<String, dynamic>? ?? {};
    final previewUrl = thumbs['small'] ?? thumbs['original'] ?? path;
    final category = json['category'] as String? ?? 'General';
    final resolution = json['resolution'] as String? ?? '1080x1920';

    return WallpaperItem(
      id: 'wallhaven_$id',
      title: 'Wallhaven 4K #$id',
      author: 'Wallhaven Community',
      authorUrl: 'https://wallhaven.cc/w/$id',
      previewUrl: previewUrl,
      fullUrl: path,
      rawUrl: path,
      source: WallpaperSource.wallhaven,
      tags: ['wallhaven', '4k', category.toLowerCase(), resolution],
    );
  }
}
