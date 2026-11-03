// lib/ui/screens/clubs_screen.dart
import 'package:flutter/material.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/api_service.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ClubData> _clubs = [];
  bool _isLoading = true;
  bool _isMutating = false;
  String? _loadError;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final list = await ApiService().getClubs();
      if (mounted) setState(() => _clubs = list);
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _selectedBadge = '🛡️';
  String _selectedClubRegion = 'Bangladesh';
  String _selectedClubFlag = '🇧🇩';

  static const List<String> badgeLogos = ['🛡️', '⚔️', '🦅', '🐅', '⚡', '👑', '🎯', '🔥'];

  final List<Map<String, String>> _clubRegions = [
    {'name': 'Bangladesh', 'code': 'BD', 'flag': '🇧🇩'},
    {'name': 'India', 'code': 'IN', 'flag': '🇮🇳'},
    {'name': 'Pakistan', 'code': 'PK', 'flag': '🇵🇰'},
    {'name': 'United States', 'code': 'US', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'code': 'GB', 'flag': '🇬🇧'},
    {'name': 'Global', 'code': 'GLOBAL', 'flag': '🌐'},
  ];

  Future<void> _handleCreateClub() async {
    if (_isMutating) return;
    final name = _nameController.text.trim();
    final tag = _tagController.text.trim().toUpperCase();
    final desc = _descController.text.trim();
    if (name.length < 2 || !RegExp(r'^[A-Z0-9]{3,4}$').hasMatch(tag)) {
      _showError('Enter a club name and a 3-4 character alphanumeric tag.');
      return;
    }
    setState(() => _isMutating = true);
    try {
      final region = _clubRegions.firstWhere((item) => item['name'] == _selectedClubRegion);
      final result = await ApiService().createClub(
        name: name,
        tag: tag,
        description: desc,
        badgeIcon: _selectedBadge,
        region: region['code']!,
        flagEmoji: region['flag']!,
      );
      await UserSession().setProfile(result.profile);
      _nameController.clear();
      _tagController.clear();
      _descController.clear();
      _tabController.animateTo(0);
      await _loadClubs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Club "${result.club.name}" founded for 20,000 coins! 🛡️'),
            backgroundColor: AppColors.emeraldTurn,
          ),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _handleLeaveClub() async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final profile = await ApiService().leaveClub();
      await UserSession().setProfile(profile);
      await _loadClubs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left club successfully.')));
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _handleJoinClub(ClubData club) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      final result = await ApiService().joinClub(club.id);
      await UserSession().setProfile(result.profile);
      await _loadClubs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined club "${club.name}"!')));
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString()), backgroundColor: AppColors.crimsonStrike),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _tagController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession().profile;

    return Scaffold(
      backgroundColor: AppColors.bgObsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.chalkWhite),
        ),
        title: Text(
          AppLocale.tr('clubs'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.goldTiffinCoin,
          labelColor: AppColors.goldTiffinCoin,
          unselectedLabelColor: AppColors.slateMuted,
          tabs: const [
            Tab(text: 'Browse Clubs 🛡️'),
            Tab(text: 'Create Club ⚔️'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Browse Clubs
          _isLoading
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
                            ElevatedButton(onPressed: _loadClubs, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : _clubs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 64, color: AppColors.slateMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'No clubs yet. Be the first to create one!',
                            style: TextStyle(color: AppColors.slateMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _clubs.length,
                      itemBuilder: (context, index) {
                        final club = _clubs[index];
                        final isMember = user.clubId == club.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: KolomTheme.glassCardDecoration(radius: 16),
                          child: Row(
                            children: [
                              // Flag & Badge
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.glassSurfaceHeavy,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.goldTiffinCoin.withValues(alpha: 0.4)),
                                ),
                                alignment: Alignment.center,
                                child: Text(club.flagEmoji, style: const TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 12),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          club.name,
                                          style: const TextStyle(
                                            color: AppColors.chalkWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          club.tag,
                                          style: const TextStyle(
                                            color: AppColors.cyanSpin,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${club.membersCount} Members • ${club.totalTrophies} Total Trophies 🏆',
                                      style: const TextStyle(color: AppColors.slateMuted, fontSize: 11),
                                    ),
                                    if (club.description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        club.description,
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Join / Member badge
                              isMember
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.emeraldTurn.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.emeraldTurn),
                                      ),
                                      child: const Text(
                                        'Joined',
                                        style: TextStyle(
                                          color: AppColors.emeraldTurn,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _handleJoinClub(club),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.goldTiffinCoin,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Join', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                            ],
                          ),
                        );
                      },
                    ),

          // Tab 2: Create Club / Active Membership
          Builder(
            builder: (context) {
              final user = UserSession().profile;
              if (user.clubId != null && user.clubId!.isNotEmpty) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: KolomTheme.glassCardDecoration(radius: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.goldTiffinCoin.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Text('🛡️', style: TextStyle(fontSize: 28)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.clubName ?? 'Your Club',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tag: [${user.clubTag ?? "TAG"}] • Role: ${(user.clubRole ?? "Member").toUpperCase()}',
                                    style: const TextStyle(color: AppColors.cyanSpin, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.glassSurfaceHeavy,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Text(
                            'You are already affiliated with a tactical club. Each student or esports athlete can only belong to one club at a time. If you wish to found a new club (20,000 Coins), you must first leave your current club.',
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _handleLeaveClub,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.crimsonStrike,
                              side: const BorderSide(color: AppColors.crimsonStrike),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                            label: const Text('Leave Current Club', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: KolomTheme.glassCardDecoration(radius: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Found a Tactical Club',
                            style: TextStyle(
                              color: AppColors.chalkWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.goldTiffinCoin.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.goldTiffinCoin.withValues(alpha: 0.6)),
                            ),
                            child: const Text(
                              'Fee: 20k Coins',
                              style: TextStyle(color: AppColors.goldTiffinCoin, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Lead your school, college, or national clan to glory in competitive Pen Wars!',
                        style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // Badge Logo Selector
                      const Text('Choose Club Badge Logo', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: badgeLogos.map((badge) {
                          final isSelected = _selectedBadge == badge;
                          return InkWell(
                            onTap: () => setState(() => _selectedBadge = badge),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.goldTiffinCoin.withValues(alpha: 0.25) : AppColors.glassSurfaceHeavy,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.goldTiffinCoin : Colors.white12,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(badge, style: const TextStyle(fontSize: 20)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Region / Flag Selector
                      const Text('Club Regional Headquarters', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.glassSurfaceHeavy,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedClubRegion,
                            isExpanded: true,
                            dropdownColor: AppColors.bgObsidian,
                            items: _clubRegions.map((r) {
                              return DropdownMenuItem<String>(
                                value: r['name'],
                                child: Text(
                                  '${r['flag']} ${r['name']}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final found = _clubRegions.firstWhere((r) => r['name'] == val);
                                setState(() {
                                  _selectedClubRegion = val;
                                  _selectedClubFlag = found['flag']!;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Club Name field
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Club Name',
                          labelStyle: const TextStyle(color: AppColors.slateMuted),
                          hintText: 'e.g. Dhaka Strikers',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: AppColors.glassSurfaceHeavy,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tag field
                      TextField(
                        controller: _tagController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Club Tag (3-4 characters)',
                          labelStyle: const TextStyle(color: AppColors.slateMuted),
                          hintText: 'e.g. DHK',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: AppColors.glassSurfaceHeavy,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      TextField(
                        controller: _descController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Motto / Description',
                          labelStyle: const TextStyle(color: AppColors.slateMuted),
                          hintText: 'e.g. Classroom legends united for competitive Pen Wars.',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: AppColors.glassSurfaceHeavy,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _handleCreateClub,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldTiffinCoin,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Found Club (20,000 Coins) 🛡️',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
