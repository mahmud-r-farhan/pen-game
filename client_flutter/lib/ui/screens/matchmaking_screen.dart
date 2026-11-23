// lib/ui/screens/matchmaking_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/ws_client.dart';
import '../../models/arena_room.dart';
import '../../models/kolom_spec.dart';
import 'game_screen.dart';

/// Waits for a real MATCH_START packet; no opponent or match state is invented.
class MatchmakingScreen extends StatefulWidget {
  final ArenaRoom room;
  final KolomSpec playerPen;

  const MatchmakingScreen({
    super.key,
    required this.room,
    required this.playerPen,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  StreamSubscription<String>? _errorSub;
  StreamSubscription<WsConnectionState>? _stateSub;
  Timer? _searchTimer;
  int _searchSeconds = 0;
  String? _error;
  bool _queued = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _errorSub = KolomWsClient().onError.listen((message) {
      if (mounted) setState(() => _error = message);
    });
    _stateSub = KolomWsClient().onConnectionState.listen((state) {
      if (state == WsConnectionState.connected && !_queued && !_cancelled)
        _joinQueue();
    });
    _connectAndJoin();
  }

  Future<void> _connectAndJoin() async {
    setState(() => _error = null);
    try {
      await KolomWsClient().connect(UserSession().profile);
      _joinQueue();
    } catch (_) {
      // The client's error stream contains the actionable transport message.
    }
  }

  void _joinQueue() {
    if (_queued || _cancelled || !KolomWsClient().isConnected) return;
    setState(() => _error = null);
    KolomWsClient().joinQueue(
      roomTypeId: widget.room.id,
      penModel: widget.playerPen.id,
    );
    _queued = true;
    _searchTimer?.cancel();
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _searchSeconds++);
      } else {
        timer.cancel();
      }
    });
  }

  void _cancel() {
    _cancelled = true;
    _searchTimer?.cancel();
    if (KolomWsClient().isConnected) KolomWsClient().leaveQueue();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    if (!_cancelled && KolomWsClient().isConnected)
      KolomWsClient().leaveQueue();
    _errorSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgObsidian,
        appBar: AppBar(
          title: const Text('Human 1v1 Matchmaking'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _cancel,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.room.neonGlowColor.withValues(
                          alpha: 0.12,
                        ),
                        border: Border.all(
                          color: widget.room.neonGlowColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.sports_esports_rounded,
                        size: 42,
                        color: widget.room.neonGlowColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.room.localizedName('en'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.room.entryCoins} coin entry • ${widget.room.payoutCoins} coin winner payout',
                      style: const TextStyle(
                        color: AppColors.goldTiffinCoin,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_error == null) ...[
                      const CircularProgressIndicator(
                        color: AppColors.goldTiffinCoin,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _queued
                            ? 'Searching for a real opponent…'
                            : 'Establishing a secure live connection…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You can cancel anytime. Entry coins are escrowed only when both players are matched.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      if (_searchSeconds >= 6) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glassSurfaceHeavy,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Opponent search is taking longer than usual.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _cancel();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => GameScreen(
                                        room: widget.room,
                                        playerPen: widget.playerPen,
                                        isOnline: false,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.cyanSpin,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.smart_toy_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Play vs AI Bot Now',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: AppColors.crimsonStrike,
                        size: 42,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () {
                          _queued = false;
                          _connectAndJoin();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry matchmaking'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _cancel,
                      child: const Text('Cancel and return'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
