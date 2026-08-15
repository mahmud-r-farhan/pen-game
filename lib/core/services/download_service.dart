import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final Dio _dio = Dio();

  Future<File?> downloadFile(String url, {String? customFileName, void Function(int received, int total)? onProgress}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      if (!await wallpaperDir.exists()) {
        await wallpaperDir.create(recursive: true);
      }

      final uri = Uri.parse(url);
      final extension = uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.')
          ? uri.pathSegments.last.split('.').last.split('?').first
          : 'jpg';

      final safeName = customFileName ?? 'lumina_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final savePath = '${wallpaperDir.path}/$safeName';

      final response = await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
      );

      if (response.statusCode == 200) {
        return File(savePath);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<int> getCacheSizeInBytes() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      if (!await wallpaperDir.exists()) return 0;

      int totalSize = 0;
      final files = wallpaperDir.listSync(recursive: true);
      for (final f in files) {
        if (f is File) {
          totalSize += await f.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> clearCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      if (await wallpaperDir.exists()) {
        await wallpaperDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
