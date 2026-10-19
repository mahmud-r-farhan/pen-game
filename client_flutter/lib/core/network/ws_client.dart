// lib/core/network/ws_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/match_packet.dart';
import '../../models/user_profile.dart';
import 'network_config.dart';

class KolomWsClient {
  static final KolomWsClient _instance = KolomWsClient._internal();
  factory KolomWsClient() => _instance;
  KolomWsClient._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _customServerUrl;

  String get _serverUrl => _customServerUrl ?? NetworkConfig.wsBaseUrl;

  final _matchStartController = StreamController<MatchStartData>.broadcast();
  final _flickController = StreamController<FlickData>.broadcast();
  final _shotResultController = StreamController<ShotResultData>.broadcast();
  final _aimingController = StreamController<AimingData>.broadcast();
  final _emojiController = StreamController<EmojiData>.broadcast();
  final _matchOverController = StreamController<MatchOverData>.broadcast();
  final _roomCodeController = StreamController<String>.broadcast();
  final _walletSyncController = StreamController<int>.broadcast();
  final _challengeController = StreamController<Map<String, dynamic>>.broadcast();
  final _turnTimerController = StreamController<TurnTimerData>.broadcast();
  final _turnTimeoutController = StreamController<TurnTimeoutData>.broadcast();
  final _rematchOfferController = StreamController<Map<String, dynamic>>.broadcast();
  final _rematchDeclinedController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<MatchStartData> get onMatchStart => _matchStartController.stream;
  Stream<FlickData> get onFlickExecute => _flickController.stream;
  Stream<ShotResultData> get onShotResult => _shotResultController.stream;
  Stream<AimingData> get onAimingSync => _aimingController.stream;
  Stream<EmojiData> get onEmojiBroadcast => _emojiController.stream;
  Stream<MatchOverData> get onMatchOver => _matchOverController.stream;
  Stream<String> get onRoomCodeCreated => _roomCodeController.stream;
  Stream<int> get onWalletSync => _walletSyncController.stream;
  Stream<Map<String, dynamic>> get onChallengeReceived => _challengeController.stream;
  Stream<TurnTimerData> get onTurnTimerTick => _turnTimerController.stream;
  Stream<TurnTimeoutData> get onTurnTimeout => _turnTimeoutController.stream;
  Stream<Map<String, dynamic>> get onRematchOffer => _rematchOfferController.stream;
  Stream<String> get onRematchDeclined => _rematchDeclinedController.stream;
  Stream<String> get onError => _errorController.stream;

  bool get isConnected => _isConnected;

  void configureServerUrl(String url) {
    _customServerUrl = url;
  }

  Future<void> connect(UserProfile profile) async {
    disconnect();

    try {
      final uri = Uri.parse(_serverUrl).replace(queryParameters: {
        'uid': profile.id,
        'isGuest': profile.isGuest.toString(),
        'name': profile.username,
        'avatar': profile.avatar,
        'pen': profile.equippedPen,
        'division': profile.division,
        'region': profile.region,
        'flag': profile.flagEmoji,
      });

      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _isConnected = true;
      debugPrint('Connected to Kolom Fight Deno WebSocket: $uri');

      _channel!.stream.listen(
        _handleIncomingMessage,
        onError: (err) {
          debugPrint('WebSocket error: $err');
          _isConnected = false;
          _errorController.add('Connection error: $err');
        },
        onDone: () {
          debugPrint('WebSocket disconnected');
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      _isConnected = false;
      _errorController.add('Failed to connect to server: $e');
    }
  }

  void _handleIncomingMessage(dynamic raw) {
    try {
      final Map<String, dynamic> data = jsonDecode(raw.toString());
      final type = data['type'] as String?;

      switch (type) {
        case 'MATCH_START':
          _matchStartController.add(MatchStartData.fromJson(data));
          break;
        case 'FLICK_EXECUTE':
          _flickController.add(FlickData.fromJson(data));
          break;
        case 'SHOT_RESULT':
          _shotResultController.add(ShotResultData.fromJson(data));
          break;
        case 'AIMING_SYNC':
          _aimingController.add(AimingData.fromJson(data));
          break;
        case 'TURN_TIMER_TICK':
          _turnTimerController.add(TurnTimerData.fromJson(data));
          break;
        case 'TURN_TIMEOUT':
          _turnTimeoutController.add(TurnTimeoutData.fromJson(data));
          break;
        case 'EMOJI_BROADCAST':
          _emojiController.add(EmojiData.fromJson(data));
          break;
        case 'MATCH_OVER':
          _matchOverController.add(MatchOverData.fromJson(data));
          break;
        case 'ROOM_CODE_CREATED':
          _roomCodeController.add(data['roomCode'] as String? ?? '');
          break;
        case 'WALLET_SYNC':
          _walletSyncController.add(data['coins'] as int? ?? 0);
          break;
        case 'FRIEND_CHALLENGE_RECEIVED':
          _challengeController.add(data);
          break;
        case 'REMATCH_OFFER':
          _rematchOfferController.add(data);
          break;
        case 'REMATCH_DECLINED':
          _rematchDeclinedController.add(data['reason'] as String? ?? 'Opponent declined rematch');
          break;
        case 'ERROR':
          _errorController.add(data['message'] as String? ?? 'Unknown error');
          break;
      }
    } catch (e) {
      debugPrint('Error parsing incoming WS packet: $e');
    }
  }

  void joinQueue({required String roomTypeId, required String penModel}) {
    _send({
      'type': 'QUEUE_JOIN',
      'roomTypeId': roomTypeId,
      'penModel': penModel,
    });
  }

  void leaveQueue() {
    _send({'type': 'QUEUE_LEAVE'});
  }

  void createPrivateRoom({required String roomTypeId, required String penModel}) {
    _send({
      'type': 'ROOM_CODE_CREATE',
      'roomTypeId': roomTypeId,
      'penModel': penModel,
    });
  }

  void joinPrivateRoom({required String roomCode, required String penModel}) {
    _send({
      'type': 'ROOM_CODE_JOIN',
      'roomCode': roomCode,
      'penModel': penModel,
    });
  }

  void sendFriendChallenge({
    required String targetUserId,
    required String roomTypeId,
    required String penModel,
  }) {
    _send({
      'type': 'FRIEND_CHALLENGE_SEND',
      'targetUserId': targetUserId,
      'roomTypeId': roomTypeId,
      'penModel': penModel,
    });
  }

  void respondFriendChallenge({
    required String challengeId,
    required bool accept,
    String? penModel,
  }) {
    final Map<String, dynamic> packet = {
      'type': 'FRIEND_CHALLENGE_RESPOND',
      'challengeId': challengeId,
      'accept': accept,
    };
    if (penModel != null) packet['penModel'] = penModel;
    _send(packet);
  }

  void submitFlick({
    required double impulseX,
    required double impulseY,
    required double strikeOffset,
  }) {
    _send({
      'type': 'FLICK_SUBMIT',
      'impulseX': impulseX,
      'impulseY': impulseY,
      'strikeOffset': strikeOffset,
    });
  }

  void submitShot({
    required double ang,
    required double power,
    double rx = 0.0,
    double ry = 0.0,
  }) {
    _send({
      'type': 'SHOT_SUBMIT',
      'ang': ang,
      'power': power,
      'rx': rx,
      'ry': ry,
    });
  }

  void updateAiming({
    required bool isAiming,
    required double pullX,
    required double pullY,
    required double strikeOffset,
  }) {
    _send({
      'type': 'AIMING_UPDATE',
      'isAiming': isAiming,
      'pullX': pullX,
      'pullY': pullY,
      'strikeOffset': strikeOffset,
    });
  }

  void passTurn() {
    _send({'type': 'PASS_TURN'});
  }

  void sendEmojiChat({required String emojiId, required String textBn, String? textEn}) {
    _send({
      'type': 'EMOJI_CHAT',
      'emojiId': emojiId,
      'textBn': textBn,
      'textEn': textEn ?? textBn,
    });
  }

  void reportKnockout({required String winnerId}) {
    _send({
      'type': 'MATCH_KNOCKOUT',
      'winnerId': winnerId,
    });
  }

  void surrender() {
    _send({'type': 'SURRENDER'});
  }

  void forfeitMatch() {
    _send({'type': 'SURRENDER'});
  }

  void sendRematchRequest() {
    _send({'type': 'REMATCH_REQUEST'});
  }

  void respondRematch({required bool accept}) {
    _send({
      'type': 'REMATCH_RESPOND',
      'accept': accept,
    });
  }

  void _send(Map<String, dynamic> packet) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(packet));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}
