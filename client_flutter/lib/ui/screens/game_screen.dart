// lib/ui/screens/game_screen.dart
import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../core/audio/sound_effects.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme.dart';
import '../../core/localization/app_strings.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/network/ws_client.dart';
import '../../game/bot/offline_bot_ai.dart';
import '../../game/kolom_game_engine.dart';
import '../../models/arena_room.dart';
import '../../models/kolom_spec.dart';
import '../../models/match_packet.dart';
import '../../models/user_profile.dart';
import '../widgets/emoji_picker_overlay.dart';
import '../widgets/kolom_avatar.dart';
import '../widgets/strike_slider.dart';
import '../widgets/victory_dialog.dart';

class GameScreen extends StatefulWidget {
  final ArenaRoom room;
  final KolomSpec playerPen;
  final bool isOnline;
  final BotDifficulty botDifficulty;
  final MatchStartData? match;

  const GameScreen({
    super.key,
    required this.room,
    required this.playerPen,
    this.isOnline = true,
    this.botDifficulty = BotDifficulty.medium,
    this.match,
  }) : assert(!isOnline || match != null, 'Online games require an authoritative MATCH_START packet.');

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late KolomGameEngine _gameEngine;
  double _strikeOffset = 0.65;
  bool _showEmojiPicker = false;

  String? _incomingEmojiText;
  Timer? _emojiDisplayTimer;

  // 30-Second Turn Countdown
  int _secondsLeft = 30;
  Timer? _turnCountdownTimer;

  StreamSubscription? _aimingSub;
  StreamSubscription? _timerSub;
  StreamSubscription? _timeoutSub;
  StreamSubscription? _emojiSub;
  StreamSubscription? _matchOverSub;
  StreamSubscription? _rematchOfferSub;
  StreamSubscription? _rematchDeclinedSub;
  StreamSubscription? _shotResultSub;
  bool _isWaitingForRematch = false;

  late KolomSpec _opponentPen;
  late String _opponentName;
  late String _opponentTag;
  late String _opponentFlag;
  late String _opponentAvatar;

  String? _matchOverRoomId;

  MatchPlayer? get _onlineOpponent {
    final match = widget.match;
    if (match == null) return null;
    final ownId = UserSession().profile.id;
    return match.p1.id == ownId ? match.p2 : match.p1;
  }

  @override
  void initState() {
    super.initState();
    final opponent = _onlineOpponent;
    if (opponent != null) {
      _opponentPen = KolomSpec.getById(opponent.penModel);
      _opponentName = opponent.username;
      _opponentTag = opponent.tag;
      _opponentFlag = opponent.flagEmoji;
      _opponentAvatar = opponent.avatar;
    } else {
      final bot = BotProfile.getRandom();
      _opponentPen = KolomSpec.getById(bot.penModel);
      _opponentName = bot.name;
      _opponentTag = bot.tag;
      _opponentFlag = bot.flagEmoji;
      _opponentAvatar = bot.avatar;
    }
    _initGameEngine();
    if (widget.isOnline) {
      _listenToOnlineEvents();
      _startServerSynchronizedTicker();
    } else {
      _startLocalTurnTimer();
    }
  }

  void _initGameEngine() {
    final match = widget.match;
    final ownId = UserSession().profile.id;
    final localSide = match?.p1.id == ownId ? 0 : 1;
    _gameEngine = KolomGameEngine(
      room: widget.room,
      playerSpec: widget.playerPen,
      opponentSpec: _opponentPen,
      mode: widget.isOnline ? GameMode.onlineMultiplayer : GameMode.offlineBot,
      botDifficulty: widget.botDifficulty,
      onlineInitialState: match?.initialState,
      localSide: localSide,
      onlinePlayerFirst: match?.firstTurn == ownId,
      onlineInputLocked: match?.inputLocked ?? false,
      onMatchEnd: (isPlayerWinner) {
        // Only explicit offline practice reaches this local callback.
        _stopTurnTimer();
        _showMatchOverDialog(isPlayerWinner, 0, 0);
      },
      onOnlineFlickSubmit: (impulse, strikeOffset) {
        KolomWsClient().submitFlick(
          impulseX: impulse.x,
          impulseY: impulse.y,
          strikeOffset: strikeOffset,
        );
      },
      onOnlineAimingUpdate: (isAiming, pullX, pullY, strikeOffset) {
        KolomWsClient().updateAiming(
          isAiming: isAiming,
          pullX: pullX,
          pullY: pullY,
          strikeOffset: strikeOffset,
        );
      },
      onTurnPassed: () {
        if (widget.isOnline) KolomWsClient().passTurn();
      },
    );
  }

  void _startServerSynchronizedTicker() {
    _turnCountdownTimer?.cancel();
    _turnCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _secondsLeft <= 0) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 5) SoundEffects().playTimerWarning();
    });
  }

  void _startLocalTurnTimer() {
    _turnCountdownTimer?.cancel();
    _secondsLeft = 30;
    _turnCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 5 && _secondsLeft > 0) SoundEffects().playTimerWarning();
      } else {
        _secondsLeft = 30;
        _gameEngine.passTurnDueToTimeout();
      }
    });
  }

  void _resetTurnTimer() {
    if (mounted) setState(() => _secondsLeft = 30);
  }

  void _stopTurnTimer() => _turnCountdownTimer?.cancel();

  void _listenToOnlineEvents() {
    final client = KolomWsClient();
    _shotResultSub = client.onShotResult.listen((shot) {
      if (!mounted || (shot.roomId.isNotEmpty && shot.roomId != widget.match?.roomId)) return;
      for (final event in shot.events) {
        SoundEffects().playCollision(intensity: (event.impact / 300.0).clamp(0.2, 1.0));
      }
      _gameEngine.playOnlineShot(
        shot.frames,
        isNowPlayerTurn: shot.nextTurn == UserSession().profile.id,
      );
    });

    _aimingSub = client.onAimingSync.listen((aim) {
      if ((aim.roomId.isEmpty || aim.roomId == widget.match?.roomId) && aim.actorId != UserSession().profile.id) {
        _gameEngine.setRemoteAiming(
          isAiming: aim.isAiming,
          pullX: aim.pullX,
          pullY: aim.pullY,
          strikeOffset: aim.strikeOffset,
        );
      }
    });

    _timerSub = client.onTurnTimerTick.listen((tick) {
      if (!mounted || (tick.roomId.isNotEmpty && tick.roomId != widget.match?.roomId)) return;
      setState(() => _secondsLeft = tick.secondsLeft);
      _gameEngine.setOnlineTurn(tick.activeUserId == UserSession().profile.id);
    });

    _timeoutSub = client.onTurnTimeout.listen((timeout) {
      if (timeout.roomId.isNotEmpty && timeout.roomId != widget.match?.roomId) return;
      _resetTurnTimer();
      _gameEngine.setOnlineTurn(timeout.nextTurnUserId == UserSession().profile.id);
    });

    _emojiSub = client.onEmojiBroadcast.listen((emoji) {
      if (!mounted) return;
      setState(() => _incomingEmojiText = emoji.textEn.isNotEmpty ? emoji.textEn : emoji.textBn);
      _emojiDisplayTimer?.cancel();
      _emojiDisplayTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _incomingEmojiText = null);
      });
    });

    _rematchOfferSub = client.onRematchOffer.listen(_showIncomingRematchOfferDialog);
    _rematchDeclinedSub = client.onRematchDeclined.listen((reason) {
      if (!mounted || !_isWaitingForRematch) return;
      setState(() => _isWaitingForRematch = false);
      Navigator.of(context, rootNavigator: true).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: AppColors.crimsonStrike),
      );
    });

    _matchOverSub = client.onMatchOver.listen((result) async {
      if (!mounted ||
          (result.roomId.isNotEmpty && result.roomId != widget.match?.roomId) ||
          _matchOverRoomId == widget.match?.roomId) {
        return;
      }
      _matchOverRoomId = widget.match?.roomId;
      _stopTurnTimer();
      _gameEngine.endOnlineMatch();
      if (result.profile != null) {
        await UserSession().setProfile(result.profile!);
      } else {
        await UserSession().refreshProfile();
      }
      if (!mounted) return;
      final isWinner = result.winnerId == UserSession().profile.id;
      _showMatchOverDialog(isWinner, isWinner ? result.payout : 0, result.trophyDelta);
    });
  }

  void _showIncomingRematchOfferDialog(Map<String, dynamic> data) {
    final requesterName = data['requesterName'] as String? ?? 'Opponent';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glassSurfaceHeavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: AppColors.goldTiffinCoin),
            SizedBox(width: 8),
            Text('Rematch Request!', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          '$requesterName wants to play again! Accept rematch?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              KolomWsClient().respondRematch(accept: false);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              KolomWsClient().respondRematch(accept: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldTurn,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Accept ⚔️', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmExitMatch() async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.glassSurfaceHeavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.crimsonStrike),
            SizedBox(width: 8),
            Text('Exit Match?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          widget.isOnline
              ? 'Are you sure you want to exit? If you leave now, you will forfeit and your opponent will automatically win the pot!'
              : 'Are you sure you want to exit the match and return to lobby?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocale.tr('cancel'), style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crimsonStrike,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Exit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      if (widget.isOnline) {
        KolomWsClient().forfeitMatch();
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
      return true;
    }
    return false;
  }

  void _showMatchOverDialog(bool isWinner, int payout, int trophyDelta) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => VictoryDialog(
        isWinner: isWinner,
        payout: payout,
        trophyDelta: trophyDelta,
        onRematch: () {
          if (widget.isOnline) {
            Navigator.of(context).pop(); // dismiss victory dialog
            setState(() => _isWaitingForRematch = true);
            KolomWsClient().sendRematchRequest();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.glassSurfaceHeavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.cyanSpin),
                    ),
                    SizedBox(width: 12),
                    Text('Waiting for Opponent...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
                content: const Text(
                  'Rematch offer sent to opponent. Waiting for response...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() => _isWaitingForRematch = false);
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop(); // return to lobby
                    },
                    child: const Text('Cancel & Return to Lobby', style: TextStyle(color: Colors.white60)),
                  ),
                ],
              ),
            );
          } else {
            Navigator.of(context).pop();
            // Pick a fresh random regional bot for endless offline replayability!
            final freshBot = BotProfile.getRandom();
            setState(() {
              _opponentPen = KolomSpec.getById(freshBot.penModel);
              _opponentName = freshBot.name;
              _opponentTag = freshBot.tag;
              _opponentFlag = freshBot.flagEmoji;
              _opponentAvatar = freshBot.avatar;
            });
            _gameEngine.resetRound();
            _startLocalTurnTimer();
          }
        },
        onLobby: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  void dispose() {
    _stopTurnTimer();
    _shotResultSub?.cancel();
    _aimingSub?.cancel();
    _timerSub?.cancel();
    _timeoutSub?.cancel();
    _emojiSub?.cancel();
    _rematchOfferSub?.cancel();
    _rematchDeclinedSub?.cancel();
    _matchOverSub?.cancel();
    _emojiDisplayTimer?.cancel();
    if (widget.match != null) AppNavigation.matchClosed(widget.match!.roomId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession().profile;
    final isPlayerTurn = _gameEngine.isPlayerTurn;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmExitMatch();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgObsidian,
        body: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Center 72% Flame 2D Physics Game Canvas (Direct Slingshot Touch Pass-through)
              Positioned.fill(
                child: GameWidget(game: _gameEngine),
              ),

              // 2. Incoming Opponent Emoji Bubble Overlay
              if (_incomingEmojiText != null)
                Positioned(
                  top: 90,
                  right: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurfaceHeavy,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cyanSpin, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyanSpin.withValues(alpha: 0.3),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Text(
                      _incomingEmojiText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

              // 3. Top Safe Zone: HUD Blueprint from UI_UX_MASTER_GUIDE.md
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Back button (with confirmation)
                        IconButton(
                          onPressed: _confirmExitMatch,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                        ),

                    // Player 1 Card (You) + Clan Tag + 30s Countdown Rounded Timer Ring
                    _buildPlayerCard(
                      name: user.username,
                      tag: user.tag,
                      flag: user.flagEmoji,
                      avatar: user.avatar,
                      clanTag: user.clubTag,
                      isActiveTurn: isPlayerTurn,
                      secondsLeft: isPlayerTurn ? _secondsLeft : 30,
                    ),

                    // Center Stake Pot Badge & Turn Status
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.glassSurfaceHeavy,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.goldTiffinCoin, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldTiffinCoin.withValues(alpha: 0.25),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.monetization_on_rounded, color: AppColors.goldTiffinCoin, size: 18),
                              const SizedBox(width: 5),
                              Text(
                                widget.isOnline
                                    ? '${widget.room.potCoins} ${AppLocale.tr('pot_label')}'
                                    : 'PRACTICE',
                                style: KolomTheme.monoNumeric(
                                  color: AppColors.goldTiffinCoin,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<String>(
                          valueListenable: _gameEngine.turnStatus,
                          builder: (context, status, child) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // Player 2 Card (Opponent / Bot) + Clan Tag + 30s Countdown Rounded Timer Ring
                    _buildPlayerCard(
                      name: _opponentName,
                      tag: _opponentTag,
                      flag: _opponentFlag,
                      avatar: _opponentAvatar,
                      clanTag: _onlineOpponent?.clubTag,
                      isActiveTurn: !isPlayerTurn,
                      secondsLeft: !isPlayerTurn ? _secondsLeft : 30,
                    ),

                    // Pass Turn button (ONLY visible and enabled on active player's turn!)
                    if (isPlayerTurn)
                      IconButton(
                        onPressed: () {
                          _gameEngine.passTurnDueToTimeout();
                        },
                        icon: const Icon(Icons.flag_rounded, color: AppColors.goldTiffinCoin),
                        tooltip: 'Pass Turn',
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Thumb Zone: Mobile-First Landscape Ergonomics
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bottom-Left Thumb Zone: [💬 Emoji Chat]
                InkWell(
                  onTap: () {
                    setState(() {
                      _showEmojiPicker = !_showEmojiPicker;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurfaceHeavy,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.cyanSpin, size: 22),
                  ),
                ),

                const SizedBox(width: 14),

                // Center Thumb Zone: [🎯 STRIKE POINT SLIDER]
                Expanded(
                  child: StrikeSlider(
                    value: _strikeOffset,
                    onChanged: (val) {
                      setState(() {
                        _strikeOffset = val;
                        _gameEngine.strikeOffset = val;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 14),

                // Bottom-Right Thumb Zone: [🔄 Reset / Center Camera]
                InkWell(
                  onTap: () {
                    SoundEffects().playFlick();
                    _gameEngine.camera.viewfinder.position = Vector2.zero();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glassSurfaceHeavy,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.center_focus_strong_rounded, color: AppColors.emeraldTurn, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // 5. Emoji Picker Popover Modal
          if (_showEmojiPicker)
            Positioned(
              left: 20,
              bottom: 80,
              child: EmojiPickerOverlay(
                onSelect: (emojiId, text) {
                  setState(() => _showEmojiPicker = false);
                  if (widget.isOnline) {
                    KolomWsClient().sendEmojiChat(emojiId: emojiId, textBn: text);
                  }
                  setState(() => _incomingEmojiText = text);
                  _emojiDisplayTimer?.cancel();
                  _emojiDisplayTimer = Timer(const Duration(seconds: 3), () {
                    if (mounted) setState(() => _incomingEmojiText = null);
                  });
                },
              ),
            ),
        ],
      ),
    ),
  ),
);
}

  Widget _buildPlayerCard({
    required String name,
    required String tag,
    required String flag,
    required String avatar,
    String? clanTag,
    required bool isActiveTurn,
    required int secondsLeft,
  }) {
    // Timer color: Emerald -> Gold -> Pulsing Crimson
    Color timerColor = AppColors.emeraldTurn;
    if (secondsLeft <= 5) {
      timerColor = AppColors.crimsonStrike;
    } else if (secondsLeft <= 10) {
      timerColor = AppColors.goldTiffinCoin;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: isActiveTurn
          ? KolomTheme.activeTurnDecoration(isYourTurn: isActiveTurn)
          : KolomTheme.glassCardDecoration(radius: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Countdown Timer around player indicator
          // NOTE: Numerical timer count removed; only the rounded timer ring is shown!
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: isActiveTurn ? (secondsLeft / 30.0) : 1.0,
                  strokeWidth: 3.0,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isActiveTurn ? timerColor : Colors.white24,
                  ),
                ),
              ),
              KolomAvatar(
                avatar: avatar,
                size: 34,
                flagEmoji: flag,
                borderColor: isActiveTurn ? timerColor : Colors.white24,
                borderWidth: 1.5,
              ),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (clanTag != null && clanTag.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyanSpin.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.cyanSpin, width: 0.8),
                      ),
                      child: Text(
                        '[$clanTag]',
                        style: const TextStyle(
                          color: AppColors.cyanSpin,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    name.length > 10 ? '${name.substring(0, 9)}…' : name,
                    style: const TextStyle(
                      color: AppColors.chalkWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                tag,
                style: const TextStyle(color: AppColors.slateMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
