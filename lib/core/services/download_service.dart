import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final Dio _dio;

  DownloadService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  Future<File?> downloadFile(String url, {String? customFileName, void Function(int received, int total)? onProgress}) async {
    String? savePath;
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
      savePath = '${wallpaperDir.path}/$safeName';

      final response = await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
      );

      if (response.statusCode == 200) {
        final downloadedFile = File(savePath);
        if (await downloadedFile.exists() && await downloadedFile.length() > 0) {
          return downloadedFile;
        }
      }
      _cleanupIncompleteFile(savePath);
      return null;
    } catch (e) {
      _cleanupIncompleteFile(savePath);
      return null;
    }
  }

  void _cleanupIncompleteFile(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
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
