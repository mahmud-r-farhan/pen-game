import '../constants/api_constants.dart';
import '../models/wallpaper_item.dart';
import 'api_client.dart';

class WaifuProvider {
  final ApiClient _client;

  WaifuProvider(this._client);

  Future<List<WallpaperItem>> getAestheticAnime({int count = 20}) async {
    try {
      final response = await _client.dio.post(
        '${ApiConstants.waifuPicsBaseUrl}/many/sfw/waifu',
        data: {'exclude': []},
      );

      final files = response.data['files'] as List<dynamic>? ?? [];
      return files.take(count).map((url) {
        final uri = url.toString();
        final filename = uri.split('/').last.replaceAll('.jpg', '').replaceAll('.png', '');
        return WallpaperItem(
          id: 'waifu_$filename',
          title: 'Anime Aesthetic #$filename',
          author: 'Waifu Community Art',
          previewUrl: uri,
          fullUrl: uri,
          rawUrl: uri,
          source: WallpaperSource.waifu,
          tags: ['anime', 'waifu', 'art', 'illustration'],
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
