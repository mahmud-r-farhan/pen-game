// lib/ui/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../game/rendering/procedural_kolom_painter.dart';
import '../../models/kolom_spec.dart';
import 'auth_screen.dart';
import 'main_lobby_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _penSpinAnimation;
  String? _startupError;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _penSpinAnimation = Tween<double>(begin: -0.4, end: 0.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
      _startupError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        AuthService().restoreSession(),
        Future<void>.delayed(const Duration(milliseconds: 1200)),
      ]);
      if (!mounted) return;
      final restored =
          results[0] != null || UserSession().hasOnlineCachedProfile;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              restored ? const MainLobbyScreen() : const AuthScreen(),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (UserSession().hasOnlineCachedProfile) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainLobbyScreen()),
        );
        return;
      }
      setState(() => _startupError = error.toString());
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pen = KolomSpec.catalog[KolomModel.oceanGelPro]!;

    return Scaffold(
      backgroundColor: AppColors.bgObsidian,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF1E2633), Color(0xFF0F141C)],
                  ),
                  border: Border.all(
                    color: AppColors.goldTiffinCoin.withValues(alpha: 0.6),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldTiffinCoin.withValues(alpha: 0.25),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _penSpinAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _penSpinAnimation.value,
                        child: CustomPaint(
                          size: const Size(110, 40),
                          painter: _PenPreviewPainter(pen),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'KOLOM FIGHT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'CLASSROOM PEN BATTLE',
              style: TextStyle(
                color: AppColors.goldTiffinCoin,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Text(
                'Authentic Bangladeshi classroom tabletop duels 🖋️',
                style: TextStyle(color: AppColors.slateMuted, fontSize: 13),
              ),
            ),
            const SizedBox(height: 36),
            if (_startupError == null)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.goldTiffinCoin,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      _startupError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isRetrying ? null : _initApp,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry server connection'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                      },
                      icon: const Icon(Icons.offline_bolt_rounded),
                      label: const Text('Continue to offline practice'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PenPreviewPainter extends CustomPainter {
  final KolomSpec spec;
  _PenPreviewPainter(this.spec);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    ProceduralKolomPainter.drawPen(canvas, spec, scale: 20.0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
