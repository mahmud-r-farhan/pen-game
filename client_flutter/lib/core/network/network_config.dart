// lib/core/network/network_config.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkConfig {
  static const String keyCustomServerHost = 'custom_server_host_v2';
  static const String defaultProdHost = 'kolom-fight.deno.dev';
  static const String envHost = String.fromEnvironment('SERVER_HOST', defaultValue: '');

  static String _activeHost = '';
  static String? _webOrigin;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keyCustomServerHost);
    if (saved != null && saved.trim().isNotEmpty) {
      _activeHost = saved.trim();
    } else if (envHost.isNotEmpty) {
      _activeHost = envHost;
    } else if (kIsWeb) {
      if (kReleaseMode) {
        // Deno serves the compiled Flutter web bundle and API from one origin.
        _webOrigin = Uri.base.origin;
        _activeHost = Uri.base.authority;
      } else {
        _activeHost = 'localhost:8080';
      }
    } else if (kDebugMode) {
      // Android emulator loopback. Set SERVER_HOST for a physical device.
      _activeHost = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2:8080' : 'localhost:8080';
    } else {
      _activeHost = defaultProdHost;
    }
  }

  static String get activeHost => _activeHost;

  static Future<void> setCustomHost(String host) async {
    final normalized = host.trim().replaceFirst(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/$'), '');
    if (normalized.isNotEmpty &&
        (!RegExp(r'^[a-zA-Z0-9.-]+(?::\d{1,5})?$').hasMatch(normalized) || normalized.contains('..'))) {
      throw const FormatException('Enter a valid host, optionally followed by a port.');
    }
    _webOrigin = null;
    _activeHost = normalized;
    final prefs = await SharedPreferences.getInstance();
    if (normalized.isEmpty) {
      await prefs.remove(keyCustomServerHost);
      await init();
    } else {
      await prefs.setString(keyCustomServerHost, normalized);
    }
  }

  static bool get _isLocal {
    final host = activeHost;
    return host.startsWith('localhost') || host.startsWith('127.0.0.1') || host.startsWith('10.0.2.2');
  }

  static String get httpBaseUrl {
    if (_webOrigin != null) return _webOrigin!;
    return _isLocal ? 'http://$activeHost' : 'https://$activeHost';
  }

  static String get wsBaseUrl {
    if (_webOrigin != null) {
      final origin = Uri.parse(_webOrigin!);
      return '${origin.scheme == 'https' ? 'wss' : 'ws'}://${origin.authority}/ws';
    }
    return _isLocal ? 'ws://$activeHost/ws' : 'wss://$activeHost/ws';
  }
}
