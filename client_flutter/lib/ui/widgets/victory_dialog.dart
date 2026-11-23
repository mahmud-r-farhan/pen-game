// lib/ui/widgets/victory_dialog.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/audio/sound_effects.dart';
import '../../models/user_profile.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme.dart';
import '../../core/localization/app_strings.dart';

class VictoryDialog extends StatefulWidget {
  final bool isWinner;
  final int payout;
  final int trophyDelta;
  final VoidCallback onRematch;
  final VoidCallback onLobby;
  final UserProfile profile;
  final bool isPractice;

  const VictoryDialog({
    super.key,
    required this.isWinner,
    required this.payout,
    this.trophyDelta = 25,
    required this.onRematch,
    required this.onLobby,
    required this.profile,
    this.isPractice = false,
  });

  @override
  State<VictoryDialog> createState() => _VictoryDialogState();
}

class _VictoryDialogState extends State<VictoryDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<_RibbonPiece> _ribbons = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Spawn 28 festive ribbons / confetti particles
    final colors = widget.isWinner
        ? [
            const Color(0xFFFFD700), // Gold
            const Color(0xFF00E676), // Emerald
            const Color(0xFFFF1744), // Crimson
            const Color(0xFF00E5FF), // Cyan
            const Color(0xFFFF4081), // Pink Ribbon
            const Color(0xFF7C4DFF), // Purple Ribbon
          ]
        : [
            const Color(0xFFFFB300), // Warm Amber
            const Color(0xFF4FC3F7), // Hope Cyan
            const Color(0xFFAB47BC), // Resilience Purple
            const Color(0xFF81C784), // Growth Green
          ];

    for (int i = 0; i < 28; i++) {
      _ribbons.add(
        _RibbonPiece(
          x: _random.nextDouble(),
          y: _random.nextDouble() * -1.0, // Start above dialog
          length: 12.0 + _random.nextDouble() * 20.0,
          width: 3.0 + _random.nextDouble() * 4.0,
          speed: 0.15 + _random.nextDouble() * 0.35,
          rotationSpeed: (_random.nextDouble() - 0.5) * 6.0,
          color: colors[_random.nextInt(colors.length)],
          isRibbonStrip: i % 2 == 0,
        ),
      );
    }

    // Play celebratory sound on win, motivational chime on loss
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isWinner) {
        SoundEffects().playRibbonFanfare();
      } else {
        SoundEffects().playDefeatMotivation();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.profile;
    final int displayedTrophyDelta = widget.trophyDelta;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Confetti & Ribbons Animation Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RibbonConfettiPainter(
                      progress: _animController.value,
                      ribbons: _ribbons,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Main Dialog Card
          Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: AppColors.glassSurfaceHeavy,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isWinner
                    ? AppColors.emeraldTurn
                    : AppColors.goldTiffinCoin,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (widget.isWinner
                              ? AppColors.emeraldTurn
                              : AppColors.crimsonStrike)
                          .withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Ribbon Banner
                _buildTopRibbonBanner(),
                const SizedBox(height: 16),

                // Icon Trophy / Motivation Badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isWinner
                          ? [
                              AppColors.goldTiffinCoin.withValues(alpha: 0.25),
                              AppColors.emeraldTurn.withValues(alpha: 0.15),
                            ]
                          : [
                              Colors.amber.withValues(alpha: 0.2),
                              Colors.deepOrange.withValues(alpha: 0.1),
                            ],
                    ),
                    border: Border.all(
                      color: widget.isWinner
                          ? AppColors.goldTiffinCoin
                          : Colors.amber,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    widget.isWinner
                        ? Icons.emoji_events_rounded
                        : Icons.auto_awesome_rounded,
                    color: widget.isWinner
                        ? AppColors.goldTiffinCoin
                        : Colors.amberAccent,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle / Motivational Bangla-English Quote
                Text(
                  widget.isWinner
                      ? 'দারুণ খেলেছো! Magnificent Strike!'
                      : 'Never Give Up! Keep Training!',
                  style: TextStyle(
                    color: widget.isWinner
                        ? AppColors.emeraldTurn
                        : Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isWinner
                      ? AppLocale.tr('knockout_win')
                      : 'প্রতিটি পরাজয়ই নতুন বিজয়ের প্রস্তুতি! ঘুরে দাঁড়াও বীরের মতো।',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),

                // Accolades Row (Coins & Trophy RP)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Coins badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.glassSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.goldTiffinCoin.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            color: AppColors.goldTiffinCoin,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isPractice
                                ? 'No coins'
                                : (widget.isWinner
                                      ? '+${widget.payout} Coins'
                                      : '-Stake Coins'),
                            style: KolomTheme.monoNumeric(
                              color: AppColors.goldTiffinCoin,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Trophy Points badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.glassSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.isWinner
                              ? AppColors.emeraldTurn
                              : AppColors.crimsonStrike,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.military_tech_rounded,
                            color: widget.isWinner
                                ? AppColors.emeraldTurn
                                : AppColors.crimsonStrike,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isPractice
                                ? 'No RP change'
                                : '${displayedTrophyDelta >= 0 ? '+' : ''}$displayedTrophyDelta RP',
                            style: KolomTheme.monoNumeric(
                              color: widget.isWinner
                                  ? AppColors.emeraldTurn
                                  : AppColors.crimsonStrike,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Achievement Cup Tier Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgObsidian.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: user.cupColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    'Achievement Cup: ${user.cupTitle} (${user.trophyPoints} RP)',
                    style: TextStyle(
                      color: user.cupColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onLobby,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.chalkWhite,
                          side: const BorderSide(color: AppColors.glassBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.isPractice
                              ? AppLocale.tr('back')
                              : AppLocale.tr('lobby'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onRematch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isWinner
                              ? AppColors.emeraldTurn
                              : AppColors.goldTiffinCoin,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocale.tr('rematch'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      final streak = user.stats.winStreak;
                      final shareText = widget.isWinner
                          ? '🏆 ${user.username} just KNOCKED OUT an opponent in Kolom Fight (কলম খেলা)! 🖊️💥\nRank: ${user.cupTitle} (${user.trophyPoints} RP) | Streak: $streak 🔥\nCan you beat my streak on the classroom desk? Join the duel now! #KolomKhela #PenFight'
                          : '⚔️ Training hard in Kolom Fight (কলম খেলা)! 🖊️\nRank: ${user.cupTitle} (${user.trophyPoints} RP)\nChallenge me on the desk duel! #KolomKhela #PenFight';

                      Clipboard.setData(ClipboardData(text: shareText));
                      SoundEffects().playCoin();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Victory card copied! Share with your school friends on Messenger & Facebook! 🚀',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: AppColors.cyanSpin,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.share_rounded,
                      size: 16,
                      color: AppColors.goldTiffinCoin,
                    ),
                    label: Text(
                      AppLocale.isBengali
                          ? 'চ্যালেঞ্জ শেয়ার করুন (Messenger/FB)'
                          : 'Share Match Card (Messenger/FB)',
                      style: const TextStyle(
                        color: AppColors.goldTiffinCoin,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRibbonBanner() {
    if (widget.isWinner) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF8F00), Color(0xFFFFD700)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎗️', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'VICTORY CHAMPION',
              style: TextStyle(
                color: Color(0xFF212121),
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(width: 8),
            Text('🎗️', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7E57C2), Color(0xFF5E35B1), Color(0xFF7E57C2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎗️', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'KEEP TRAINING!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(width: 8),
            Text('🎗️', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }
  }
}

class _RibbonPiece {
  double x;
  double y;
  final double length;
  final double width;
  final double speed;
  final double rotationSpeed;
  final Color color;
  final bool isRibbonStrip;

  _RibbonPiece({
    required this.x,
    required this.y,
    required this.length,
    required this.width,
    required this.speed,
    required this.rotationSpeed,
    required this.color,
    required this.isRibbonStrip,
  });
}

class _RibbonConfettiPainter extends CustomPainter {
  final double progress;
  final List<_RibbonPiece> ribbons;

  _RibbonConfettiPainter({required this.progress, required this.ribbons});

  @override
  void paint(Canvas canvas, Size size) {
    for (final ribbon in ribbons) {
      // Calculate animated vertical position with wrap-around
      final currentY = ((ribbon.y + progress * ribbon.speed * 2.0) % 1.4) - 0.2;
      final px = ribbon.x * size.width;
      final py = currentY * size.height;

      final paint = Paint()
        ..color = ribbon.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(progress * ribbon.rotationSpeed * math.pi);

      if (ribbon.isRibbonStrip) {
        // Draw curvy ribbon strip
        final path = Path();
        path.moveTo(-ribbon.length / 2, 0);
        path.quadraticBezierTo(0, ribbon.width * 2.5, ribbon.length / 2, 0);
        path.quadraticBezierTo(0, -ribbon.width * 2.5, -ribbon.length / 2, 0);
        path.close();
        canvas.drawPath(path, paint);
      } else {
        // Draw fluttering confetti rectangle
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: ribbon.width * 2.0,
          height: ribbon.length * 0.7,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RibbonConfettiPainter oldDelegate) => true;
}
