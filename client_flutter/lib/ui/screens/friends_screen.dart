// lib/ui/screens/friends_screen.dart
import 'package:flutter/material.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/api_service.dart';
import '../../core/network/ws_client.dart';
import '../../models/user_profile.dart';
import '../widgets/kolom_avatar.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _friends = [];
  List<UserProfile> _facebookFriends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    final profile = UserSession().profile;
    final list = await ApiService().getFriends(profile.id);
    if (!mounted) return;
    setState(() {
      _friends = list;
      _isLoading = false;
    });
  }

  Future<void> _addFriend() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final profile = UserSession().profile;
    final added = await ApiService().addFriend(profile.id, query);
    if (!mounted) return;

    if (added != null) {
      _searchController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${added.username} (${added.tag}) added to friends list!'),
          backgroundColor: AppColors.emeraldTurn,
        ),
      );
      _loadFriends();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Player tag not found! (e.g. #KLM-8492)'),
          backgroundColor: AppColors.crimsonStrike,
        ),
      );
    }
  }

  Future<void> _removeFriend(UserProfile friend) async {
    final profile = UserSession().profile;
    final ok = await ApiService().removeFriend(profile.id, friend.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _friends.removeWhere((f) => f.id == friend.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${friend.username} removed from friends')),
      );
    }
  }

  void _challengeFriend(UserProfile friend) {
    final profile = UserSession().profile;
    KolomWsClient().connect(profile);
    KolomWsClient().sendFriendChallenge(
      targetUserId: friend.id,
      roomTypeId: 'primary_school',
      penModel: profile.equippedPen,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Challenge sent to ${friend.username}! Waiting for response...'),
        backgroundColor: AppColors.emeraldTurn,
      ),
    );
  }

  Future<void> _syncFacebook() async {
    setState(() => _isLoading = true);
    final profile = UserSession().profile;
    final simulatedFbFriends = [
      'fb_friend_shuvo',
      'fb_friend_rakib',
      'fb_friend_mim',
    ];
    final matched = await ApiService().syncFacebookFriends(
      profile.id,
      'fb_${profile.id}',
      simulatedFbFriends,
    );
    if (!mounted) return;
    setState(() {
      _facebookFriends = matched;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found ${matched.length} Facebook friends playing Kolom Khela!'),
        backgroundColor: const Color(0xFF1877F2),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserSession().profile;

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
                const Icon(Icons.people_alt_rounded, color: AppColors.goldTiffinCoin, size: 24),
                const SizedBox(width: 8),
                Text(
                  AppLocale.tr('friends'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.goldTiffinCoin,
              labelColor: AppColors.goldTiffinCoin,
              unselectedLabelColor: AppColors.slateMuted,
              tabs: [
                Tab(icon: const Icon(Icons.group_rounded), text: AppLocale.tr('friends')),
                const Tab(icon: Icon(Icons.facebook_rounded), text: 'Facebook Friends'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Search & Add Bar
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.glassSurface,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search player tag (e.g. #KLM-8492)',
                          hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: AppColors.goldTiffinCoin),
                          filled: true,
                          fillColor: AppColors.bgSurfaceDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.goldTiffinCoin),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _addFriend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldTiffinCoin,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add Friend', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. Regular Friends List
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.goldTiffinCoin))
                        : _friends.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.group_off_rounded, size: 54, color: AppColors.slateMuted),
                                    const SizedBox(height: 12),
                                    const Text('No friends added yet', style: TextStyle(color: Colors.white70, fontSize: 15)),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Share your tag: ${profile.tag}',
                                      style: const TextStyle(
                                        color: AppColors.goldTiffinCoin,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _friends.length,
                                itemBuilder: (context, index) {
                                  return _buildFriendCard(_friends[index]);
                                },
                              ),

                    // 2. Facebook Friends Discovery Tab
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 36),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sync Facebook Friends',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Connect with friends who have linked their Facebook accounts.',
                                        style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _syncFacebook,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1877F2),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Sync Now'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _facebookFriends.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Tap Sync to discover Facebook friends who play Kolom Khela.',
                                      style: TextStyle(color: AppColors.slateMuted),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _facebookFriends.length,
                                    itemBuilder: (context, index) {
                                      return _buildFriendCard(_facebookFriends[index]);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFriendCard(UserProfile friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          KolomAvatar(
            avatar: friend.avatar,
            size: 42,
            flagEmoji: friend.flagEmoji,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      friend.username,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if ((friend.clubTag ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '[${friend.clubTag}]',
                        style: const TextStyle(color: AppColors.cyanSpin, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      friend.tag,
                      style: const TextStyle(color: AppColors.goldTiffinCoin, fontSize: 12, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${friend.cupEmoji} ${friend.cupTitle}',
                      style: TextStyle(color: friend.cupColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _challengeFriend(friend),
            icon: const Icon(Icons.sports_esports_rounded, color: AppColors.emeraldTurn),
            tooltip: 'Challenge to Match',
          ),
          IconButton(
            onPressed: () => _removeFriend(friend),
            icon: const Icon(Icons.person_remove_rounded, color: AppColors.slateMuted),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
