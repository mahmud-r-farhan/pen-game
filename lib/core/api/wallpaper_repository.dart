import '../models/filter_options.dart';
import '../models/wallpaper_item.dart';
import 'api_client.dart';
import 'curated_presets.dart';
import 'nasa_provider.dart';
import 'pexels_provider.dart';
import 'pixabay_provider.dart';
import 'waifu_provider.dart';
import 'wallhaven_provider.dart';

class WallpaperRepository {
  final ApiClient apiClient;
  late PexelsProvider pexels;
  late PixabayProvider pixabay;
  late WallhavenProvider wallhaven;
  late NasaProvider nasa;
  late WaifuProvider waifu;

  WallpaperRepository({required this.apiClient}) {
    pexels = PexelsProvider(apiClient);
    pixabay = PixabayProvider(apiClient);
    wallhaven = WallhavenProvider(apiClient);
    nasa = NasaProvider(apiClient);
    waifu = WaifuProvider(apiClient);
  }

  void updateCustomKeys({String? pexelsKey, String? pixabayKey, String? nasaKey}) {
    if (pexelsKey != null) pexels.customApiKey = pexelsKey;
    if (pixabayKey != null) pixabay.customApiKey = pixabayKey;
    if (nasaKey != null) nasa.customApiKey = nasaKey;
  }

  Future<List<WallpaperItem>> getCuratedFeed({int page = 1, int perPage = 25}) async {
    // 1. Try Pexels Curated
    final pexelsResults = await pexels.getCurated(page: page, perPage: perPage);
    if (pexelsResults.isNotEmpty) return pexelsResults;

    // 2. Failover to Pixabay High Quality Search
    final pixabayResults = await pixabay.search('wallpaper 4k aesthetic', page: page, perPage: perPage);
    if (pixabayResults.isNotEmpty) return pixabayResults;

    // 3. Failover to Wallhaven Toplist
    final wallhavenResults = await wallhaven.search('aesthetic', page: page);
    if (wallhavenResults.isNotEmpty) return wallhavenResults;

    // 4. Ultimate Local Curated Preset Fallback (ensures 100% offline resilience)
    return CuratedPresets.getCuratedWallpapers();
  }

  Future<List<WallpaperItem>> searchWallpapers(
    String query, {
    int page = 1,
    int perPage = 25,
    FilterOptions options = const FilterOptions(),
  }) async {
    final orientationStr = options.orientation == WallpaperOrientation.landscape
        ? 'landscape'
        : (options.orientation == WallpaperOrientation.portrait ? 'portrait' : 'all');

    // Specific Preferred Source routing
    if (options.preferredSource == WallpaperSource.wallhaven) {
      final res = await wallhaven.search(query, page: page);
      if (res.isNotEmpty) return res;
    } else if (options.preferredSource == WallpaperSource.pixabay) {
      final res = await pixabay.search(query, page: page, perPage: perPage, orientation: orientationStr == 'portrait' ? 'vertical' : 'horizontal');
      if (res.isNotEmpty) return res;
    } else if (options.preferredSource == WallpaperSource.nasa || query.toLowerCase().contains('nasa') || query.toLowerCase().contains('space')) {
      final res = await nasa.getApodFeed(count: perPage);
      if (res.isNotEmpty) return res;
    } else if (options.preferredSource == WallpaperSource.waifu || query.toLowerCase().contains('anime') || query.toLowerCase().contains('waifu')) {
      final res = await waifu.getAestheticAnime(count: perPage);
      if (res.isNotEmpty) return res;
    }

    // Default Waterfall Failover Strategy
    // 1. Pexels search
    final pexelsRes = await pexels.search(query, page: page, perPage: perPage, orientation: orientationStr);
    if (pexelsRes.isNotEmpty) return pexelsRes;

    // 2. Pixabay search fallback
    final pixabayRes = await pixabay.search(query, page: page, perPage: perPage, orientation: orientationStr == 'portrait' ? 'vertical' : 'horizontal');
    if (pixabayRes.isNotEmpty) return pixabayRes;

    // 3. Wallhaven search fallback
    final wallhavenRes = await wallhaven.search(query, page: page);
    if (wallhavenRes.isNotEmpty) return wallhavenRes;

    // Filter curated presets if offline/matches
    return CuratedPresets.getCuratedWallpapers()
        .where((item) => item.tags.any((t) => t.toLowerCase().contains(query.toLowerCase())) || item.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<List<WallpaperItem>> getLiveVideos({int page = 1, int perPage = 15}) async {
    // 1. Try Pexels Video API
    final pexelsVideos = await pexels.getPopularVideos(page: page, perPage: perPage);
    if (pexelsVideos.isNotEmpty) return pexelsVideos;

    // 2. Try Pixabay Video API
    final pixabayVideos = await pixabay.getVideos('vertical background loop', page: page, perPage: perPage);
    if (pixabayVideos.isNotEmpty) return pixabayVideos;

    // 3. Fallback to Curated Live Loops
    return CuratedPresets.getCuratedLiveVideos();
  }
}
