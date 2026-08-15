import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/native_wallpaper_service.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/glass_container.dart';
import 'widgets/queue_item_card.dart';

class AutoChangerScreen extends StatelessWidget {
  const AutoChangerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final queue = storage.autoQueue;
    final isEnabled = storage.autoChangerEnabled;
    final autoTarget = storage.autoTarget;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Top Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.autoChangerTitle,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Screen Unlock Rotation Engine',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Master Auto-Changer Switch Card
                    GlassContainer(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Unlock Auto-Changer',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isEnabled ? 'Active: Switches on every unlock' : 'Disabled',
                                    style: TextStyle(
                                      color: isEnabled ? AppColors.success : AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: isEnabled,
                                activeTrackColor: AppColors.secondary,
                                onChanged: (val) {
                                  if (val && queue.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please add at least 1 wallpaper to your queue first!'),
                                      ),
                                    );
                                    return;
                                  }
                                  storage.toggleAutoChanger(val);
                                },
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.glassBorder, height: 24),

                          // Zero Battery Drain Guarantee Badge
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: AppColors.success, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Zero Standby Drain: Listens purely to ACTION_USER_PRESENT with no background wake-locks.',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Target Screen Selector
                    const Text('Target Screens', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTargetChip(context, 'Home Screen', WallpaperTarget.home, autoTarget),
                        const SizedBox(width: 8),
                        _buildTargetChip(context, 'Lock Screen', WallpaperTarget.lock, autoTarget),
                        const SizedBox(width: 8),
                        _buildTargetChip(context, 'Both', WallpaperTarget.both, autoTarget),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rotation Queue (${queue.length})',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (queue.isNotEmpty)
                          const Text(
                            'Hold & drag to reorder',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Queue List or Empty State
            if (queue.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.playlist_add_rounded, color: AppColors.textMuted, size: 64),
                        const SizedBox(height: 12),
                        const Text(
                          AppStrings.queueEmptyTitle,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          AppStrings.queueEmptySubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverReorderableList(
                  itemCount: queue.length,
                  onReorderItem: (oldIndex, newIndex) => storage.reorderQueue(oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('queue_${item.id}'),
                      index: index,
                      child: QueueItemCard(
                        item: item,
                        index: index,
                        onRemove: () => storage.removeFromQueue(item.id),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetChip(BuildContext context, String label, WallpaperTarget target, WallpaperTarget current) {
    final isSelected = current == target;
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<StorageService>().setAutoTarget(target),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.secondary : AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
