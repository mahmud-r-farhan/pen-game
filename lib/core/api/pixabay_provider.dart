import '../constants/api_constants.dart';
import '../models/wallpaper_item.dart';
import 'api_client.dart';

class PixabayProvider {
  final ApiClient _client;
  String? customApiKey;

  PixabayProvider(this._client, {this.customApiKey});

  String get _apiKey => customApiKey?.isNotEmpty == true ? customApiKey! : ApiConstants.defaultPixabayKey;

  Future<List<WallpaperItem>> search(String query, {int page = 1, int perPage = 25, String orientation = 'vertical'}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.pixabayBaseUrl,
        queryParameters: {
          'key': _apiKey,
          'q': query,
          'image_type': 'photo',
          'orientation': orientation,
          'safesearch': 'true',
          'per_page': perPage,
          'page': page,
        },
      );

      final hits = response.data['hits'] as List<dynamic>? ?? [];
      return hits.map((h) => _mapPixabayPhoto(h)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<WallpaperItem>> getVideos(String query, {int page = 1, int perPage = 15}) async {
    try {
      final response = await _client.dio.get(
        '${ApiConstants.pixabayBaseUrl}/videos/',
        queryParameters: {
          'key': _apiKey,
          'q': query.isEmpty ? 'background' : query,
          'safesearch': 'true',
          'per_page': perPage,
          'page': page,
        },
      );

      final hits = response.data['hits'] as List<dynamic>? ?? [];
      return hits.map((h) => _mapPixabayVideo(h)).whereType<WallpaperItem>().toList();
    } catch (e) {
      return [];
    }
  }

  WallpaperItem _mapPixabayPhoto(dynamic json) {
    final id = (json['id'] ?? '').toString();
    final user = json['user'] as String? ?? 'Pixabay Artist';
    final userImageURL = json['userImageURL'] as String? ?? '';
    final tags = (json['tags'] as String? ?? '').split(',').map((t) => t.trim()).toList();

    final previewUrl = json['webformatURL'] as String? ?? json['previewURL'] as String? ?? '';
    final fullUrl = json['largeImageURL'] as String? ?? previewUrl;

    return WallpaperItem(
      id: 'pixabay_$id',
      title: tags.isNotEmpty ? tags.first.toUpperCase() : 'Pixabay 4K #$id',
      author: user,
      authorUrl: userImageURL,
      previewUrl: previewUrl,
      fullUrl: fullUrl,
      rawUrl: fullUrl,
      width: json['imageWidth'] as int? ?? 1080,
      height: json['imageHeight'] as int? ?? 1920,
      source: WallpaperSource.pixabay,
      tags: ['pixabay', ...tags],
    );
  }

  WallpaperItem? _mapPixabayVideo(dynamic json) {
    final id = (json['id'] ?? '').toString();
    final user = json['user'] as String? ?? 'Pixabay Motion';
    final videos = json['videos'] as Map<String, dynamic>? ?? {};

    // Get medium or large video mp4 url
    final large = videos['large'] as Map<String, dynamic>?;
    final medium = videos['medium'] as Map<String, dynamic>?;
    final small = videos['small'] as Map<String, dynamic>?;

    final videoUrl = large?['url'] ?? medium?['url'] ?? small?['url'];
    if (videoUrl == null) return null;

    final pictureId = json['picture_id'] as String? ?? '';
    final previewUrl = pictureId.isNotEmpty
        ? 'https://i.vimeocdn.com/video/${pictureId}_640x360.jpg'
        : 'https://images.pexels.com/photos/1037992/pexels-photo-1037992.jpeg?auto=compress&cs=tinysrgb&w=600';

    final tags = (json['tags'] as String? ?? '').split(',').map((t) => t.trim()).toList();

    return WallpaperItem(
      id: 'pixabay_v_$id',
      title: tags.isNotEmpty ? 'Live ${tags.first}' : 'Live Loop #$id',
      author: user,
      previewUrl: previewUrl,
      fullUrl: previewUrl,
      rawUrl: previewUrl,
      videoUrl: videoUrl as String,
      mediaType: WallpaperMediaType.video,
      source: WallpaperSource.pixabay,
      tags: ['live', 'pixabay', ...tags],
    );
  }
}
