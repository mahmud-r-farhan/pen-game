import 'package:flutter/services.dart';

enum WallpaperTarget {
  home,
  lock,
  both,
}

class NativeWallpaperService {
  static const MethodChannel _channel = MethodChannel('com.bb.luminapaper/wallpaper');

  static Future<bool> setStaticWallpaper({
    required String filePath,
    WallpaperTarget target = WallpaperTarget.both,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('setStaticWallpaper', {
        'filePath': filePath,
        'target': target.name,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> setLiveWallpaper({required String videoPath}) async {
    try {
      final result = await _channel.invokeMethod<bool>('setLiveWallpaper', {
        'videoPath': videoPath,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> setAutoChangerConfig({
    required bool enabled,
    required List<String> queueFilePaths,
    WallpaperTarget target = WallpaperTarget.both,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('setAutoChangerConfig', {
        'enabled': enabled,
        'queue': queueFilePaths,
        'target': target.name,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getAutoChangerConfig() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getAutoChangerConfig');
      return result ?? {};
    } on PlatformException catch (_) {
      return {};
    }
  }

  static Future<bool> isLiveWallpaperActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLiveWallpaperActive');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
