// lib/core/network/network_config.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkConfig {
  static const String keyCustomServerHost = 'custom_server_host';

  // Default Deno Deploy Production Domain (can be overridden via environment or Settings)
  static const String defaultProdHost = 'kolom-fight.deno.dev';

  // Compile-time environment variable: flutter run --dart-define=SERVER_HOST=my-deno-app.deno.dev
  static const String envHost = String.fromEnvironment('SERVER_HOST', defaultValue: '');

  static String _activeHost = '';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keyCustomServerHost);
    if (saved != null && saved.trim().isNotEmpty) {
      _activeHost = saved.trim();
    } else if (envHost.isNotEmpty) {
      _activeHost = envHost;
    } else if (kIsWeb) {
      // Local web debugging
      _activeHost = 'localhost:8080';
    } else {
      // Android / iOS Production
      _activeHost = defaultProdHost;
    }
  }

  static String get activeHost => _activeHost.isNotEmpty ? _activeHost : (kIsWeb ? 'localhost:8080' : defaultProdHost);

  static Future<void> setCustomHost(String host) async {
    _activeHost = host.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCustomServerHost, _activeHost);
  }

  static String get httpBaseUrl {
    final host = activeHost;
    final isLocal = host.contains('localhost') || host.contains('127.0.0.1') || host.contains('10.0.2.2');
    return isLocal ? 'http://$host' : 'https://$host';
  }

  static String get wsBaseUrl {
    final host = activeHost;
    final isLocal = host.contains('localhost') || host.contains('127.0.0.1') || host.contains('10.0.2.2');
    return isLocal ? 'ws://$host/ws' : 'wss://$host/ws';
  }
}
