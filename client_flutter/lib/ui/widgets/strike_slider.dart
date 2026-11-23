// lib/ui/widgets/strike_slider.dart
import 'package:flutter/material.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';

class StrikeSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const StrikeSlider({super.key, required this.value, required this.onChanged});

  bool get isCapSmash => value < -0.30;
  bool get isTipSpin => value > 0.30;
  bool get isCenterPush => !isCapSmash && !isTipSpin;

  Color get activeColor {
    if (isTipSpin) return AppColors.crimsonStrike;
    if (isCapSmash) return AppColors.cyanSpin;
    return AppColors.goldTiffinCoin;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glassSurfaceHeavy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Three Tactile Strike Indicator Pills (No floating numbers!)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStrikePill(
                label: AppLocale.tr('strike_cap'),
                icon: Icons.shield_rounded,
                isSelected: isCapSmash,
                color: AppColors.cyanSpin,
                targetValue: -0.65,
              ),
              const SizedBox(width: 6),
              _buildStrikePill(
                label: AppLocale.tr('strike_center'),
                icon: Icons.adjust_rounded,
                isSelected: isCenterPush,
                color: AppColors.goldTiffinCoin,
                targetValue: 0.0,
              ),
              const SizedBox(width: 6),
              _buildStrikePill(
                label: AppLocale.tr('strike_tip'),
                icon: Icons.flash_on_rounded,
                isSelected: isTipSpin,
                color: AppColors.crimsonStrike,
                targetValue: 0.65,
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 2. Smooth Tactile Slider with glowing thumb
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.white12,
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.25),
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
            ),
            child: Slider(
              value: value,
              min: -0.85,
              max: 0.85,
              onChanged: (val) {
                onChanged(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrikePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required double targetValue,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          SoundEffects().playPenSelect();
          onChanged(targetValue);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.white12,
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isSelected ? color : Colors.white54),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
