import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallpaper_item.dart';
import 'native_wallpaper_service.dart';

class StorageService extends ChangeNotifier {
  static const String _keyFavorites = 'lumina_favorites';
  static const String _keyAutoQueue = 'lumina_auto_queue';
  static const String _keyAutoEnabled = 'lumina_auto_enabled';
  static const String _keyAutoTarget = 'lumina_auto_target';
  static const String _keyAmoledTheme = 'lumina_amoled_theme';
  static const String _keyPexelsKey = 'lumina_custom_pexels_key';
  static const String _keyPixabayKey = 'lumina_custom_pixabay_key';
  static const String _keyNasaKey = 'lumina_custom_nasa_key';

  late SharedPreferences _prefs;
  List<WallpaperItem> _favorites = [];
  List<WallpaperItem> _autoQueue = [];
  bool _autoChangerEnabled = false;
  WallpaperTarget _autoTarget = WallpaperTarget.both;
  bool _isAmoledTheme = true;

  String? _customPexelsKey;
  String? _customPixabayKey;
  String? _customNasaKey;

  List<WallpaperItem> get favorites => List.unmodifiable(_favorites);
  List<WallpaperItem> get autoQueue => List.unmodifiable(_autoQueue);
  bool get autoChangerEnabled => _autoChangerEnabled;
  WallpaperTarget get autoTarget => _autoTarget;
  bool get isAmoledTheme => _isAmoledTheme;

  String? get customPexelsKey => _customPexelsKey;
  String? get customPixabayKey => _customPixabayKey;
  String? get customNasaKey => _customNasaKey;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load Favorites
    final favString = _prefs.getString(_keyFavorites);
    if (favString != null && favString.isNotEmpty) {
      try {
        final list = jsonDecode(favString) as List<dynamic>;
        _favorites = list.map((e) => WallpaperItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _favorites = [];
      }
    }

    // Load Auto-Changer Queue
    final queueString = _prefs.getString(_keyAutoQueue);
    if (queueString != null && queueString.isNotEmpty) {
      try {
        final list = jsonDecode(queueString) as List<dynamic>;
        _autoQueue = list.map((e) => WallpaperItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        _autoQueue = [];
      }
    }

    _autoChangerEnabled = _prefs.getBool(_keyAutoEnabled) ?? false;
    final targetName = _prefs.getString(_keyAutoTarget) ?? WallpaperTarget.both.name;
    _autoTarget = WallpaperTarget.values.firstWhere((e) => e.name == targetName, orElse: () => WallpaperTarget.both);
    _isAmoledTheme = _prefs.getBool(_keyAmoledTheme) ?? true;

    _customPexelsKey = _prefs.getString(_keyPexelsKey);
    _customPixabayKey = _prefs.getString(_keyPixabayKey);
    _customNasaKey = _prefs.getString(_keyNasaKey);

    notifyListeners();
  }

  // Favorites
  bool isFavorite(String id) => _favorites.any((item) => item.id == id);

  Future<void> toggleFavorite(WallpaperItem item) async {
    if (isFavorite(item.id)) {
      _favorites.removeWhere((w) => w.id == item.id);
    } else {
      _favorites.insert(0, item);
    }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final list = _favorites.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyFavorites, jsonEncode(list));
  }

  // Auto Changer Queue
  bool isInQueue(String id) => _autoQueue.any((item) => item.id == id);

  Future<void> addToQueue(WallpaperItem item) async {
    if (!isInQueue(item.id)) {
      _autoQueue.add(item);
      await _saveQueue();
      await _syncNativeAutoChanger();
      notifyListeners();
    }
  }

  Future<void> removeFromQueue(String id) async {
    _autoQueue.removeWhere((item) => item.id == id);
    await _saveQueue();
    await _syncNativeAutoChanger();
    notifyListeners();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _autoQueue.removeAt(oldIndex);
    _autoQueue.insert(newIndex, item);
    await _saveQueue();
    await _syncNativeAutoChanger();
    notifyListeners();
  }

  Future<void> toggleAutoChanger(bool enable) async {
    _autoChangerEnabled = enable;
    await _prefs.setBool(_keyAutoEnabled, enable);
    await _syncNativeAutoChanger();
    notifyListeners();
  }

  Future<void> setAutoTarget(WallpaperTarget target) async {
    _autoTarget = target;
    await _prefs.setString(_keyAutoTarget, target.name);
    await _syncNativeAutoChanger();
    notifyListeners();
  }

  Future<void> _saveQueue() async {
    final list = _autoQueue.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyAutoQueue, jsonEncode(list));
  }

  Future<void> _syncNativeAutoChanger() async {
    // Send cached paths to native receiver
    final paths = _autoQueue
        .map((e) => e.localCachedPath)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toList();

    await NativeWallpaperService.setAutoChangerConfig(
      enabled: _autoChangerEnabled && paths.isNotEmpty,
      queueFilePaths: paths,
      target: _autoTarget,
    );
  }

  // Settings
  Future<void> setAmoledTheme(bool val) async {
    _isAmoledTheme = val;
    await _prefs.setBool(_keyAmoledTheme, val);
    notifyListeners();
  }

  Future<void> setCustomKeys({String? pexelsKey, String? pixabayKey, String? nasaKey}) async {
    _customPexelsKey = pexelsKey;
    _customPixabayKey = pixabayKey;
    _customNasaKey = nasaKey;

    if (pexelsKey != null) await _prefs.setString(_keyPexelsKey, pexelsKey);
    if (pixabayKey != null) await _prefs.setString(_keyPixabayKey, pixabayKey);
    if (nasaKey != null) await _prefs.setString(_keyNasaKey, nasaKey);

    notifyListeners();
  }
}
