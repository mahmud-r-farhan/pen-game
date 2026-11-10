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

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  List<UserProfile> _friends = [];
  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;
  String? _challengingId;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ApiService().getFriends();
      if (mounted) setState(() => _friends = list);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addFriend() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _isMutating) return;
    setState(() => _isMutating = true);
    try {
      final added = await ApiService().addFriend(query);
      _searchController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${added.username} (${added.tag}) added to your friends.'),
          backgroundColor: AppColors.emeraldTurn,
        ),
      );
      await _loadFriends();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _removeFriend(UserProfile friend) async {
    if (_isMutating) return;
    setState(() => _isMutating = true);
    try {
      await ApiService().removeFriend(friend.id);
      if (mounted) setState(() => _friends.removeWhere((item) => item.id == friend.id));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _challengeFriend(UserProfile friend) async {
    if (_challengingId != null) return;
    setState(() => _challengingId = friend.id);
    try {
      final profile = UserSession().profile;
      await KolomWsClient().connect(profile);
      KolomWsClient().sendFriendChallenge(
        targetUserId: friend.id,
        roomTypeId: 'primary_school',
        penModel: profile.equippedPen,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge sent to ${friend.username}. Waiting for a response…'),
          backgroundColor: AppColors.emeraldTurn,
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _challengingId = null);
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserSession().profile;
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.currentCode,
      builder: (context, _, _) => Scaffold(
        backgroundColor: AppColors.bgObsidian,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurfaceDark,
          title: Text(AppLocale.tr('friends')),
          actions: [IconButton(onPressed: _loadFriends, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.glassSurface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _addFriend(),
                      decoration: InputDecoration(
                        hintText: 'Player tag or ID (for example ${profile.tag})',
                        hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: AppColors.goldTiffinCoin),
                        filled: true,
                        fillColor: AppColors.bgSurfaceDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isMutating ? null : _addFriend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldTiffinCoin,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    ),
                    child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(profile)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(UserProfile profile) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.goldTiffinCoin));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.crimsonStrike),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadFriends, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_off_rounded, size: 54, color: AppColors.slateMuted),
            const SizedBox(height: 12),
            const Text('No friends added yet', style: TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 8),
            Text('Share your tag: ${profile.tag}', style: const TextStyle(color: AppColors.goldTiffinCoin, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (context, index) => _buildFriendCard(_friends[index]),
      ),
    );
  }

  Widget _buildFriendCard(UserProfile friend) {
    final challenging = _challengingId == friend.id;
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
          KolomAvatar(avatar: friend.avatar, size: 42, flagEmoji: friend.flagEmoji),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.username, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text('${friend.tag} • ${friend.trophyPoints} RP', style: const TextStyle(color: AppColors.slateMuted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: challenging ? null : () => _challengeFriend(friend),
            icon: challenging
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sports_esports_rounded, color: AppColors.emeraldTurn),
            tooltip: 'Challenge to a match',
          ),
          IconButton(
            onPressed: _isMutating ? null : () => _removeFriend(friend),
            icon: const Icon(Icons.person_remove_rounded, color: AppColors.slateMuted),
            tooltip: 'Remove friend',
          ),
        ],
      ),
    );
  }
}
