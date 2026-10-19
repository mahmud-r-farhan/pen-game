// lib/ui/screens/garage_shop_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../game/rendering/procedural_kolom_painter.dart';
import '../../models/kolom_spec.dart';
import '../widgets/coin_badge.dart';

class GarageShopScreen extends StatefulWidget {
  const GarageShopScreen({super.key});

  @override
  State<GarageShopScreen> createState() => _GarageShopScreenState();
}

class _GarageShopScreenState extends State<GarageShopScreen> {
  late KolomSpec _selectedPen;
  final double _previewAngle = -0.05;

  @override
  void initState() {
    super.initState();
    final profile = UserSession().profile;
    _selectedPen = KolomSpec.getById(profile.equippedPen);
  }

  void _equipPen(KolomSpec pen) {
    UserSession().equipPen(pen.id);
    SoundEffects().playCoin();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pen.nameEn} equipped!'),
        backgroundColor: AppColors.emeraldTurn,
      ),
    );
  }

  void _buyPen(KolomSpec pen) {
    final profile = UserSession().profile;
    if (profile.coins < pen.unlockPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough coins! Win matches to earn more.'),
          backgroundColor: AppColors.crimsonStrike,
        ),
      );
      return;
    }

    UserSession().unlockPen(pen.id, pen.unlockPrice);
    SoundEffects().playVictory();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pen.nameEn} unlocked and equipped!'),
        backgroundColor: AppColors.emeraldTurn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserSession().profile;
    final bool isEquipped = profile.equippedPen == _selectedPen.id;
    final bool isUnlocked = profile.unlockedPens.contains(_selectedPen.id);

    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.currentCode,
      builder: (context, code, child) {
        final isBn = AppLocale.isBengali;
        return Scaffold(
          backgroundColor: AppColors.bgObsidian,
          appBar: AppBar(
            backgroundColor: AppColors.bgSurfaceDark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppColors.goldTiffinCoin, size: 22),
                const SizedBox(width: 8),
                Text(
                  AppLocale.tr('pen_garage'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: CoinBadge(coins: profile.coins)),
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Interactive 2D Pen Inspection Showcase
              Container(
                height: 180,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _selectedPen.accentColor.withValues(alpha: 0.25),
                      AppColors.glassSurface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _selectedPen.accentColor.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Transform.rotate(
                        angle: _previewAngle,
                        child: CustomPaint(
                          size: const Size(300, 60),
                          painter: _GaragePenPainter(_selectedPen),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isBn ? _selectedPen.nameBn : _selectedPen.nameEn,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            isBn ? _selectedPen.tagLineBn : _selectedPen.tagLineEn,
                            style: TextStyle(
                              color: _selectedPen.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Stat Bars (Mass, Grip, Speed, Whip-Spin)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildStatBar('Pen Mass & Weight', _selectedPen.massRating, AppColors.goldTiffinCoin),
                    _buildStatBar('Rubber Grip Friction', _selectedPen.gripRating, AppColors.emeraldTurn),
                    _buildStatBar('Slide Top Speed', _selectedPen.speedRating, AppColors.cyanSpin),
                    _buildStatBar('Whip-Spin Torque', _selectedPen.whipSpinRating, AppColors.crimsonStrike),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Equip / Buy Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isEquipped
                        ? null
                        : isUnlocked
                            ? () => _equipPen(_selectedPen)
                            : () => _buyPen(_selectedPen),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEquipped
                          ? AppColors.glassSurface
                          : isUnlocked
                              ? AppColors.emeraldTurn
                              : AppColors.goldTiffinCoin,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AppColors.glassBorder,
                      disabledForegroundColor: AppColors.slateMuted,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      isEquipped
                          ? 'Equipped'
                          : isUnlocked
                              ? 'Equip Pen'
                              : 'Unlock (${NumberFormat.decimalPattern().format(_selectedPen.unlockPrice)} Coins)',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Pen Catalog Carousel / Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: KolomSpec.catalog.values.length,
                  itemBuilder: (context, index) {
                    final pen = KolomSpec.catalog.values.toList()[index];
                    final isSelected = pen.id == _selectedPen.id;
                    final isOwned = profile.unlockedPens.contains(pen.id);
                    final isCurrent = profile.equippedPen == pen.id;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedPen = pen);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? pen.accentColor.withValues(alpha: 0.15)
                              : AppColors.glassSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? pen.accentColor
                                : isCurrent
                                    ? AppColors.emeraldTurn
                                    : AppColors.glassBorder,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isBn ? pen.nameBn : pen.nameEn,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isCurrent)
                                  const Icon(Icons.check_circle, color: AppColors.emeraldTurn, size: 16)
                                else if (!isOwned)
                                  const Icon(Icons.lock, color: AppColors.slateMuted, size: 14),
                              ],
                            ),
                            const Spacer(),
                            Center(
                              child: CustomPaint(
                                size: const Size(130, 24),
                                painter: _GaragePenPainter(pen),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              isOwned
                                  ? 'Owned'
                                  : '${NumberFormat.compact().format(pen.unlockPrice)} Coins',
                              style: TextStyle(
                                color: isOwned ? AppColors.emeraldTurn : AppColors.goldTiffinCoin,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBar(String title, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(title, style: const TextStyle(color: AppColors.slateMuted, fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100.0,
                minHeight: 8,
                backgroundColor: AppColors.bgSurfaceDark,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$value%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _GaragePenPainter extends CustomPainter {
  final KolomSpec spec;
  _GaragePenPainter(this.spec);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    ProceduralKolomPainter.drawPen(canvas, spec, scale: 22.0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
