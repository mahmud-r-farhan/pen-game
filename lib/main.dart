import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/api/api_client.dart';
import 'core/api/wallpaper_repository.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/services/download_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auto_changer/auto_changer_screen.dart';
import 'features/explorer/explorer_screen.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/live_wallpaper/live_wallpaper_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shared/widgets/custom_nav_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive dark status bar and navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final storageService = StorageService();
  await storageService.init();

  final apiClient = ApiClient();
  final wallpaperRepository = WallpaperRepository(apiClient: apiClient);
  final downloadService = DownloadService();

  // Apply stored custom keys if any
  wallpaperRepository.updateCustomKeys(
    pexelsKey: storageService.customPexelsKey,
    pixabayKey: storageService.customPixabayKey,
    nasaKey: storageService.customNasaKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storageService),
        Provider.value(value: wallpaperRepository),
        Provider.value(value: downloadService),
      ],
      child: const LuminaPaperApp(),
    ),
  );
}

class LuminaPaperApp extends StatelessWidget {
  const LuminaPaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isAmoled = context.select<StorageService, bool>((s) => s.isAmoledTheme);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme.copyWith(
        scaffoldBackgroundColor: isAmoled ? Colors.black : AppColors.background,
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ExplorerScreen(),
    LiveWallpaperScreen(),
    AutoChangerScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
