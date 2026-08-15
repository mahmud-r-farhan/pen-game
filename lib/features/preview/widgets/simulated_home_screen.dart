import 'package:flutter/material.dart';

class SimulatedHomeScreen extends StatelessWidget {
  const SimulatedHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Search Widget Simulator
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: Colors.white70, size: 20),
                  SizedBox(width: 12),
                  Text('Search phone and web...', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  Spacer(),
                  Icon(Icons.mic_rounded, color: Colors.white70, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // App Icons Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAppIcon(Icons.camera_alt_rounded, 'Camera', Colors.pinkAccent),
                _buildAppIcon(Icons.mail_rounded, 'Mail', Colors.redAccent),
                _buildAppIcon(Icons.photo_library_rounded, 'Photos', Colors.blueAccent),
                _buildAppIcon(Icons.map_rounded, 'Maps', Colors.greenAccent),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAppIcon(Icons.play_arrow_rounded, 'Play', Colors.orangeAccent),
                _buildAppIcon(Icons.music_note_rounded, 'Music', Colors.purpleAccent),
                _buildAppIcon(Icons.chat_bubble_rounded, 'Chat', Colors.tealAccent),
                _buildAppIcon(Icons.settings_rounded, 'Settings', Colors.grey),
              ],
            ),
            const Spacer(),

            // Bottom Dock
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDockIcon(Icons.phone_rounded, Colors.green),
                  _buildDockIcon(Icons.message_rounded, Colors.blue),
                  _buildDockIcon(Icons.language_rounded, Colors.indigo),
                  _buildDockIcon(Icons.folder_rounded, Colors.amber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  Widget _buildDockIcon(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}
