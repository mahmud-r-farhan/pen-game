import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/wallpaper_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/gradient_button.dart';

class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  late TextEditingController _pexelsController;
  late TextEditingController _pixabayController;
  late TextEditingController _nasaController;

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _pexelsController = TextEditingController(text: storage.customPexelsKey ?? '');
    _pixabayController = TextEditingController(text: storage.customPixabayKey ?? '');
    _nasaController = TextEditingController(text: storage.customNasaKey ?? '');
  }

  @override
  void dispose() {
    _pexelsController.dispose();
    _pixabayController.dispose();
    _nasaController.dispose();
    super.dispose();
  }

  Future<void> _saveKeys() async {
    final storage = context.read<StorageService>();
    final repo = context.read<WallpaperRepository>();

    final pexels = _pexelsController.text.trim();
    final pixabay = _pixabayController.text.trim();
    final nasa = _nasaController.text.trim();

    await storage.setCustomKeys(
      pexelsKey: pexels.isNotEmpty ? pexels : null,
      pixabayKey: pixabay.isNotEmpty ? pixabay : null,
      nasaKey: nasa.isNotEmpty ? nasa : null,
    );

    repo.updateCustomKeys(
      pexelsKey: pexels.isNotEmpty ? pexels : null,
      pixabayKey: pixabay.isNotEmpty ? pixabay : null,
      nasaKey: nasa.isNotEmpty ? nasa : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('Custom API Keys saved successfully!', style: TextStyle(color: Colors.white)),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom API Keys'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Power User Configuration',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Lumina Paper already provides built-in rate-limit fallback keys. If you have personal developer accounts with higher rate limits, you can provide your own API keys below.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),

            _buildInputField('Pexels API Key', 'Authorization token for Pexels 4K Photos & Videos', _pexelsController),
            const SizedBox(height: 18),
            _buildInputField('Pixabay API Key', 'Key parameter for Pixabay high-res images & loops', _pixabayController),
            const SizedBox(height: 18),
            _buildInputField('NASA Open API Key', 'Developer key for Astronomy Picture of the Day', _nasaController),
            const SizedBox(height: 32),

            GradientButton(
              text: 'Save Custom Keys',
              icon: Icons.vpn_key_rounded,
              onPressed: _saveKeys,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String title, String subtitle, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder, width: 1),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Leave blank to use default public tokens',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
