import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SimulatedLockScreen extends StatelessWidget {
  const SimulatedLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm').format(now);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, color: Colors.white70, size: 18),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w200,
                letterSpacing: -2,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
            ),
            Text(
              dateStr,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleIcon(Icons.flashlight_on_rounded),
                const Text(
                  'Swipe up to unlock',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _buildCircleIcon(Icons.camera_alt_rounded),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
