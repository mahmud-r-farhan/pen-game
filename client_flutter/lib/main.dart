// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/audio/sound_effects.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/user_session.dart';
import 'core/constants/app_theme.dart';
import 'core/localization/app_strings.dart';
import 'core/network/network_config.dart';
import 'core/navigation/app_navigation.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer landscape orientation for authentic tabletop bench perspective
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // Make system navigation transparent for immersive gaming feel
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize core services
  await NetworkConfig.init();
  await AppLocale().init();
  await SoundEffects().init();
  await AuthService().init();
  await UserSession().init();

  runApp(const KolomFightApp());
}

class KolomFightApp extends StatelessWidget {
  const KolomFightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Kolom Fight Online',
      debugShowCheckedModeBanner: false,
      theme: KolomTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
