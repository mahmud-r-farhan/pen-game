import '../constants/api_constants.dart';
import '../models/wallpaper_item.dart';
import 'api_client.dart';

class NasaProvider {
  final ApiClient _client;
  String? customApiKey;

  NasaProvider(this._client, {this.customApiKey});

  String get _apiKey => customApiKey?.isNotEmpty == true ? customApiKey! : ApiConstants.defaultNasaKey;

  Future<List<WallpaperItem>> getApodFeed({int count = 15}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.nasaApodUrl,
        queryParameters: {
          'api_key': _apiKey,
          'count': count,
          'thumbs': 'true',
        },
      );

      if (response.data is List) {
        final list = response.data as List<dynamic>;
        return list
            .where((item) => item['media_type'] == 'image')
            .map((item) => _mapApod(item))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  WallpaperItem _mapApod(dynamic json) {
    final title = json['title'] as String? ?? 'Astronomy Picture of the Day';
    final copyright = json['copyright'] as String? ?? 'NASA / JPL';
    final date = json['date'] as String? ?? '';
    final url = json['url'] as String? ?? '';
    final hdurl = json['hdurl'] as String? ?? url;

    return WallpaperItem(
      id: 'nasa_${date.replaceAll('-', '_')}',
      title: title,
      author: copyright.trim(),
      previewUrl: url,
      fullUrl: hdurl,
      rawUrl: hdurl,
      source: WallpaperSource.nasa,
      tags: ['nasa', 'space', 'astronomy', 'apod', date],
    );
  }
}
