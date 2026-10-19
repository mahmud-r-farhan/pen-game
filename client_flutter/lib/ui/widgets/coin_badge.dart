// lib/ui/widgets/coin_badge.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';

class CoinBadge extends StatelessWidget {
  final int coins;
  final VoidCallback? onAddTap;

  const CoinBadge({
    super.key,
    required this.coins,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat.compact().format(coins);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.goldTiffinCoin.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldTiffinCoin.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded, color: AppColors.goldTiffinCoin, size: 18),
          const SizedBox(width: 6),
          Text(
            formatted,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
          if (onAddTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.emeraldTurn,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.black, size: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
