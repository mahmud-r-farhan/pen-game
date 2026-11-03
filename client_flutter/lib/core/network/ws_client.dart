// lib/core/network/ws_client.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/match_packet.dart';
import '../../models/user_profile.dart';
import 'api_service.dart';
import 'network_config.dart';

enum WsConnectionState { disconnected, connecting, connected, reconnecting }

class KolomWsClient {
  static final KolomWsClient _instance = KolomWsClient._internal();
  factory KolomWsClient() => _instance;
  KolomWsClient._internal();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Future<void>? _connecting;
  UserProfile? _profile;
  String? _customServerUrl;
  WsConnectionState _state = WsConnectionState.disconnected;
  bool _shouldStayConnected = false;
  int _generation = 0;
  int _reconnectAttempt = 0;

  final _matchStartController = StreamController<MatchStartData>.broadcast();
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
  final _queueWaitingController = StreamController<QueueWaitingData>.broadcast();
  final _authSuccessController = StreamController<UserProfile>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _stateController = StreamController<WsConnectionState>.broadcast();

  Stream<MatchStartData> get onMatchStart => _matchStartController.stream;
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
  Stream<QueueWaitingData> get onQueueWaiting => _queueWaitingController.stream;
  Stream<UserProfile> get onAuthSuccess => _authSuccessController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<WsConnectionState> get onConnectionState => _stateController.stream;

  bool get isConnected => _state == WsConnectionState.connected;
  WsConnectionState get connectionState => _state;
  String get _serverUrl => _customServerUrl ?? NetworkConfig.wsBaseUrl;

  void configureServerUrl(String url) => _customServerUrl = url;

  void _setState(WsConnectionState state) {
    if (_state == state) return;
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  Future<void> connect(UserProfile profile, {bool forceReconnect = false}) {
    final sameProfile = _profile?.id == profile.id;
    _profile = profile;
    _shouldStayConnected = true;
    if (!forceReconnect && isConnected && sameProfile) return Future.value();
    if (_connecting != null) return _connecting!;

    final future = _openConnection(forceReconnect: forceReconnect);
    _connecting = future;
    return future.whenComplete(() => _connecting = null);
  }

  Future<void> _openConnection({bool forceReconnect = false}) async {
    final profile = _profile;
    if (profile == null) throw StateError('No player profile for WebSocket connection.');
    final generation = ++_generation;
    _reconnectTimer?.cancel();
    if (forceReconnect || _channel != null) await _closeChannel();
    _setState(_reconnectAttempt > 0 ? WsConnectionState.reconnecting : WsConnectionState.connecting);

    try {
      final ticket = await ApiService().createWebSocketTicket();
      if (generation != _generation || !_shouldStayConnected) return;
      final uri = Uri.parse(_serverUrl).replace(queryParameters: {'ticket': ticket});
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _socketSubscription = channel.stream.listen(
        _handleIncomingMessage,
        onError: (Object error) {
          if (generation != _generation) return;
          debugPrint('WebSocket error: $error');
          _errorController.add('Live connection error. Attempting to reconnect…');
        },
        onDone: () {
          if (generation != _generation) return;
          _channel = null;
          _setState(WsConnectionState.disconnected);
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
      await channel.ready.timeout(const Duration(seconds: 12));
      if (generation != _generation) return;
      _reconnectAttempt = 0;
      _setState(WsConnectionState.connected);
    } catch (error) {
      if (generation != _generation) return;
      await _closeChannel();
      _setState(WsConnectionState.disconnected);
      final message = error is ApiException ? error.message : 'Could not connect to the live game server.';
      _errorController.add(message);
      _scheduleReconnect();
      throw ApiException('WEBSOCKET_UNAVAILABLE', message);
    }
  }

  void _scheduleReconnect() {
    if (!_shouldStayConnected || _profile == null || _reconnectTimer != null) return;
    _reconnectAttempt++;
    final int seconds;
    if (_reconnectAttempt == 1) {
      seconds = 1;
    } else if (_reconnectAttempt == 2) {
      seconds = 2;
    } else if (_reconnectAttempt == 3) {
      seconds = 5;
    } else {
      seconds = 15;
    }
    _setState(WsConnectionState.reconnecting);
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      if (_shouldStayConnected && _profile != null) {
        connect(_profile!).catchError((_) {});
      }
    });
  }

  void _handleIncomingMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      switch (data['type']) {
        case 'AUTH_SUCCESS':
          _authSuccessController.add(UserProfile.fromJson(data['profile'] as Map<String, dynamic>));
          break;
        case 'MATCH_START':
          _matchStartController.add(MatchStartData.fromJson(data));
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
          _walletSyncController.add((data['coins'] as num?)?.toInt() ?? 0);
          break;
        case 'FRIEND_CHALLENGE_RECEIVED':
          _challengeController.add(data);
          break;
        case 'REMATCH_OFFER':
          _rematchOfferController.add(data);
          break;
        case 'REMATCH_DECLINED':
          _rematchDeclinedController.add(data['reason'] as String? ?? 'Opponent declined the rematch.');
          break;
        case 'QUEUE_WAITING':
          _queueWaitingController.add(QueueWaitingData.fromJson(data));
          break;
        case 'ERROR':
          _errorController.add(data['message'] as String? ?? 'The game action failed.');
          break;
      }
    } catch (error) {
      debugPrint('Ignored malformed WebSocket packet: $error');
      _errorController.add('Received an invalid update from the game server.');
    }
  }

  bool _send(Map<String, dynamic> packet) {
    final channel = _channel;
    if (!isConnected || channel == null) {
      _errorController.add('The live server is still connecting. Please wait and retry.');
      return false;
    }
    channel.sink.add(jsonEncode(packet));
    return true;
  }

  void joinQueue({required String roomTypeId, required String penModel}) {
    _send({'type': 'QUEUE_JOIN', 'roomTypeId': roomTypeId, 'penModel': penModel});
  }

  void leaveQueue() => _send({'type': 'QUEUE_LEAVE'});

  void createPrivateRoom({required String roomTypeId, required String penModel}) {
    _send({'type': 'ROOM_CODE_CREATE', 'roomTypeId': roomTypeId, 'penModel': penModel});
  }

  void joinPrivateRoom({required String roomCode, required String penModel}) {
    _send({'type': 'ROOM_CODE_JOIN', 'roomCode': roomCode, 'penModel': penModel});
  }

  void cancelPrivateRoom() => _send({'type': 'ROOM_CODE_CANCEL'});

  void sendFriendChallenge({required String targetUserId, required String roomTypeId, required String penModel}) {
    _send({'type': 'FRIEND_CHALLENGE_SEND', 'targetUserId': targetUserId, 'roomTypeId': roomTypeId, 'penModel': penModel});
  }

  void respondFriendChallenge({required String challengeId, required bool accept, String? penModel}) {
    _send({
      'type': 'FRIEND_CHALLENGE_RESPOND',
      'challengeId': challengeId,
      'accept': accept,
      if (penModel != null) 'penModel': penModel,
    });
  }

  void submitFlick({required double impulseX, required double impulseY, required double strikeOffset}) {
    _send({
      'type': 'FLICK_SUBMIT',
      'impulseX': impulseX,
      'impulseY': impulseY,
      'strikeOffset': strikeOffset,
    });
  }

  void submitShot({required double ang, required double power, double rx = 0, double ry = 0}) {
    _send({'type': 'SHOT_SUBMIT', 'ang': ang, 'power': power, 'rx': rx, 'ry': ry});
  }

  void updateAiming({required bool isAiming, required double pullX, required double pullY, required double strikeOffset}) {
    _send({
      'type': 'AIMING_UPDATE',
      'isAiming': isAiming,
      'pullX': pullX,
      'pullY': pullY,
      'strikeOffset': strikeOffset,
    });
  }

  void passTurn() => _send({'type': 'PASS_TURN'});

  void sendEmojiChat({required String emojiId, required String textBn, String? textEn}) {
    _send({'type': 'EMOJI_CHAT', 'emojiId': emojiId, 'textBn': textBn, 'textEn': textEn ?? textBn});
  }

  void surrender() => _send({'type': 'SURRENDER'});
  void forfeitMatch() => surrender();
  void sendRematchRequest() => _send({'type': 'REMATCH_REQUEST'});
  void respondRematch({required bool accept}) => _send({'type': 'REMATCH_RESPOND', 'accept': accept});

  Future<void> _closeChannel() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) await channel.sink.close().catchError((_) {});
  }

  void disconnect() {
    _shouldStayConnected = false;
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    unawaited(_closeChannel());
    _setState(WsConnectionState.disconnected);
  }
}
