import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/wallpaper_item.dart';
import 'api_client.dart';

class PexelsProvider {
  final ApiClient _client;
  String? customApiKey;

  PexelsProvider(this._client, {this.customApiKey});

  String get _apiKey => customApiKey?.isNotEmpty == true ? customApiKey! : ApiConstants.defaultPexelsKey;

  Options get _authOptions => Options(
        headers: {'Authorization': _apiKey},
      );

  Future<List<WallpaperItem>> getCurated({int page = 1, int perPage = 25}) async {
    try {
      final response = await _client.dio.get(
        '${ApiConstants.pexelsBaseUrl}/curated',
        queryParameters: {'page': page, 'per_page': perPage},
        options: _authOptions,
      );

      final photos = response.data['photos'] as List<dynamic>? ?? [];
      return photos.map((p) => _mapPexelsPhoto(p)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<WallpaperItem>> search(String query, {int page = 1, int perPage = 25, String orientation = 'portrait'}) async {
    try {
      final response = await _client.dio.get(
        '${ApiConstants.pexelsBaseUrl}/search',
        queryParameters: {
          'query': query,
          'page': page,
          'per_page': perPage,
          'orientation': orientation,
        },
        options: _authOptions,
      );

      final photos = response.data['photos'] as List<dynamic>? ?? [];
      return photos.map((p) => _mapPexelsPhoto(p)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<WallpaperItem>> getPopularVideos({int page = 1, int perPage = 15}) async {
    try {
      final response = await _client.dio.get(
        '${ApiConstants.pexelsVideosBaseUrl}/popular',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'min_width': 1080,
          'min_duration': 5,
          'max_duration': 30,
        },
        options: _authOptions,
      );

      final videos = response.data['videos'] as List<dynamic>? ?? [];
      return videos.map((v) => _mapPexelsVideo(v)).whereType<WallpaperItem>().toList();
    } catch (e) {
      return [];
    }
  }

  WallpaperItem _mapPexelsPhoto(dynamic json) {
    final src = json['src'] as Map<String, dynamic>? ?? {};
    final id = (json['id'] ?? '').toString();
    final photographer = json['photographer'] as String? ?? 'Pexels Creator';
    final photographerUrl = json['photographer_url'] as String? ?? '';
    final alt = json['alt'] as String? ?? 'Aesthetic 4K Wallpaper';

    return WallpaperItem(
      id: 'pexels_$id',
      title: alt.isNotEmpty ? alt : 'Pexels HD #$id',
      author: photographer,
      authorUrl: photographerUrl,
      previewUrl: src['medium'] ?? src['portrait'] ?? src['large'] ?? '',
      fullUrl: src['portrait'] ?? src['large2x'] ?? src['original'] ?? '',
      rawUrl: src['original'] ?? src['large2x'] ?? '',
      width: json['width'] as int? ?? 1080,
      height: json['height'] as int? ?? 1920,
      source: WallpaperSource.pexels,
      tags: ['pexels', '4k', if (alt.isNotEmpty) alt.toLowerCase()],
    );
  }

  WallpaperItem? _mapPexelsVideo(dynamic json) {
    final id = (json['id'] ?? '').toString();
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final videoFiles = json['video_files'] as List<dynamic>? ?? [];
    final videoPictures = json['video_pictures'] as List<dynamic>? ?? [];

    if (videoFiles.isEmpty) return null;

    // Pick best HD mp4 file
    dynamic bestFile;
    for (final file in videoFiles) {
      if (file['file_type'] == 'video/mp4') {
        if (bestFile == null || (file['width'] as int? ?? 0) > (bestFile['width'] as int? ?? 0)) {
          bestFile = file;
        }
      }
    }
    bestFile ??= videoFiles.first;

    final previewUrl = videoPictures.isNotEmpty ? videoPictures.first['picture'] as String? ?? '' : json['image'] as String? ?? '';

    return WallpaperItem(
      id: 'pexels_v_$id',
      title: 'Live Loop #$id',
      author: user['name'] as String? ?? 'Pexels Motion',
      authorUrl: user['url'] as String? ?? '',
      previewUrl: previewUrl,
      fullUrl: previewUrl,
      rawUrl: previewUrl,
      videoUrl: bestFile['link'] as String?,
      mediaType: WallpaperMediaType.video,
      source: WallpaperSource.pexels,
      tags: ['live', 'video', 'loop'],
    );
  }
}
