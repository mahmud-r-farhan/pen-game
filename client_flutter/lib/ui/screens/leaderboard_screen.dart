// lib/ui/screens/leaderboard_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/api_service.dart';
import '../../models/user_profile.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _activeFilter = 'global'; // 'global', 'division', 'friends'
  String _selectedDivision = 'Dhaka';
  List<UserProfile> _leaderboard = [];
  bool _isLoading = true;
  String? _loadError;

  final List<String> _divisions = [
    'Dhaka',
    'Chattogram',
    'Rajshahi',
    'Khulna',
    'Sylhet',
    'Barishal',
    'Rangpur',
    'Mymensingh',
    'Delhi',
    'Kolkata',
    'Lahore',
    'International',
  ];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final list = await ApiService().getLeaderboard(
        filter: _activeFilter,
        division: _activeFilter == 'division' ? _selectedDivision : null,
      );
      if (mounted) setState(() => _leaderboard = list);
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.currentCode,
      builder: (context, code, child) {
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
                const Icon(Icons.leaderboard_rounded, color: AppColors.goldTiffinCoin, size: 24),
                const SizedBox(width: 8),
                Text(
                  AppLocale.tr('leaderboard'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                tooltip: 'Refresh',
                onPressed: _loadLeaderboard,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Ranking Rule Banner (Ranked by XP, not coins!)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                color: const Color(0xFF1A2234),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 15, color: AppColors.goldTiffinCoin),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        code == 'bn'
                            ? 'অফিসিয়াল র‍্যাংকিং: প্লেয়ার এক্সপি ও ট্রফি রেটিং অনুযায়ী নির্ধারিত (কয়েন নয়)'
                            : (code == 'hi'
                                ? 'आधिकारिक स्टैंडिंग्स: खिलाड़ी के XP और RP के आधार पर (कॉइन्स नहीं)'
                                : 'Official Standings: Ranked strictly by Player XP & RP (Not Coins)'),
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Tabs
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.glassSurface,
                child: Row(
                  children: [
                    _buildFilterTab(AppLocale.tr('global_standings'), 'global', Icons.public_rounded),
                    const SizedBox(width: 8),
                    _buildFilterTab(AppLocale.tr('regional_division'), 'division', Icons.location_city_rounded),
                    const SizedBox(width: 8),
                    _buildFilterTab(AppLocale.tr('friends'), 'friends', Icons.people_alt_rounded),
                  ],
                ),
              ),

              // Division Dropdown
              if (_activeFilter == 'division')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF161A22),
                    border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Select Division: ',
                        style: TextStyle(color: AppColors.slateMuted, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedDivision,
                        dropdownColor: AppColors.bgSurfaceDark,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.goldTiffinCoin),
                        style: const TextStyle(color: AppColors.goldTiffinCoin, fontWeight: FontWeight.bold),
                        items: _divisions.map((d) {
                          return DropdownMenuItem(value: d, child: Text(d));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedDivision = val);
                            _loadLeaderboard();
                          }
                        },
                      ),
                    ],
                  ),
                ),

              // Rankings List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.goldTiffinCoin))
                    : _loadError != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.crimsonStrike),
                                  const SizedBox(height: 12),
                                  Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 12),
                                  ElevatedButton(onPressed: _loadLeaderboard, child: const Text('Retry')),
                                ],
                              ),
                            ),
                          )
                        : _leaderboard.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_outlined, size: 56, color: AppColors.slateMuted),
                                const SizedBox(height: 12),
                                Text(
                                  AppLocale.tr('empty_leaderboard'),
                                  style: const TextStyle(color: AppColors.slateMuted, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _leaderboard.length,
                            itemBuilder: (context, index) {
                              final item = _leaderboard[index];
                              final rank = index + 1;
                              final isTop3 = rank <= 3;
                              final medalColor = rank == 1
                                  ? const Color(0xFFFFD700)
                                  : rank == 2
                                      ? const Color(0xFFE0E0E0)
                                      : const Color(0xFFCD7F32);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isTop3
                                      ? medalColor.withValues(alpha: 0.12)
                                      : AppColors.glassSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isTop3 ? medalColor : AppColors.glassBorder,
                                    width: isTop3 ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Rank Number or Medal
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isTop3 ? medalColor : Colors.white10,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$rank',
                                          style: TextStyle(
                                            color: isTop3 ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Player Info & Regional Flag
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                item.flagEmoji,
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  item.username,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              if ((item.clubTag ?? '').isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.cyanSpin.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: AppColors.cyanSpin, width: 0.8),
                                                  ),
                                                  child: Text(
                                                    '[${item.clubTag}]',
                                                    style: const TextStyle(
                                                      color: AppColors.cyanSpin,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                '${item.cupEmoji} ${item.cupTitle}',
                                                style: TextStyle(
                                                  color: item.cupColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '• ${item.division}',
                                                style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '• 🔥 ${item.stats.winStreak}',
                                                style: const TextStyle(color: AppColors.crimsonStrike, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Player XP, Level, and Win-Rate (Ranked by XP!)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: item.cupColor.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: item.cupColor.withValues(alpha: 0.7)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.bolt_rounded, size: 16, color: item.cupColor),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${item.trophyPoints} ${AppLocale.tr('xp_label')}',
                                                style: TextStyle(
                                                  color: item.cupColor,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'LVL ${((item.trophyPoints) / 100).floor() + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              item.stats.totalMatches > 0
                                                  ? '${((item.stats.wins / item.stats.totalMatches) * 100).toInt()}% ${AppLocale.tr('win_rate')}'
                                                  : '0% ${AppLocale.tr('win_rate')}',
                                              style: const TextStyle(
                                                color: AppColors.slateMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
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

  Widget _buildFilterTab(String label, String value, IconData icon) {
    final isSelected = _activeFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeFilter = value);
          _loadLeaderboard();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.goldTiffinCoin : AppColors.bgSurfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.goldTiffinCoin : AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : AppColors.slateMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
