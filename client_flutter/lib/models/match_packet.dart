// lib/models/match_packet.dart
import '../game/kolom_physics_sim.dart';
import 'user_profile.dart';

class MatchPlayer {
  final String id;
  final String username;
  final String tag;
  final String avatar;
  final String penModel;
  final int trophyPoints;
  final String cupTier;
  final String flagEmoji;
  final String? clubTag;

  const MatchPlayer({
    required this.id,
    required this.username,
    required this.tag,
    required this.avatar,
    required this.penModel,
    this.trophyPoints = 100,
    this.cupTier = 'bronze',
    this.flagEmoji = '🌐',
    this.clubTag,
  });

  factory MatchPlayer.fromJson(Map<String, dynamic> json) {
    return MatchPlayer(
      id: json['id'] as String,
      username: json['username'] as String,
      tag: json['tag'] as String,
      avatar: json['avatar'] as String,
      penModel: json['penModel'] as String,
      trophyPoints: json['trophyPoints'] as int? ?? 100,
      cupTier: json['cupTier'] as String? ?? 'bronze',
      flagEmoji: json['flagEmoji'] as String? ?? '🌐',
      clubTag: json['clubTag'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'tag': tag,
    'avatar': avatar,
    'penModel': penModel,
    'trophyPoints': trophyPoints,
    'cupTier': cupTier,
    'flagEmoji': flagEmoji,
    'clubTag': clubTag,
  };
}

class MatchStartData {
  final String roomId;
  final String roomTypeId;
  final int pot;
  final String firstTurn;
  final MatchPlayer p1;
  final MatchPlayer p2;
  final SimState initialState;
  final bool inputLocked;
  final bool isBot;

  const MatchStartData({
    required this.roomId,
    required this.roomTypeId,
    required this.pot,
    required this.firstTurn,
    required this.p1,
    required this.p2,
    required this.initialState,
    this.inputLocked = false,
    this.isBot = false,
  });

  factory MatchStartData.fromJson(Map<String, dynamic> json) {
    return MatchStartData(
      roomId: json['roomId'] as String,
      roomTypeId: json['roomTypeId'] as String,
      pot: (json['pot'] as num).toInt(),
      firstTurn: json['firstTurn'] as String,
      p1: MatchPlayer.fromJson(json['p1'] as Map<String, dynamic>),
      p2: MatchPlayer.fromJson(json['p2'] as Map<String, dynamic>),
      initialState: SimState.fromJson(
        json['initialState'] as Map<String, dynamic>,
      ),
      inputLocked: json['inputLocked'] as bool? ?? false,
      isBot: json['isBot'] as bool? ?? false,
    );
  }
}

class QueueWaitingData {
  final String roomTypeId;
  final double? estimatedSeconds;

  const QueueWaitingData({required this.roomTypeId, this.estimatedSeconds});

  factory QueueWaitingData.fromJson(Map<String, dynamic> json) =>
      QueueWaitingData(
        roomTypeId: json['roomTypeId'] as String? ?? '',
        estimatedSeconds: (json['estimatedSec'] as num?)?.toDouble(),
      );
}

class FlickData {
  final String actorId;
  final double impulseX;
  final double impulseY;
  final double strikeOffset;
  final String nextTurn;

  const FlickData({
    required this.actorId,
    required this.impulseX,
    required this.impulseY,
    required this.strikeOffset,
    required this.nextTurn,
  });

  factory FlickData.fromJson(Map<String, dynamic> json) {
    return FlickData(
      actorId: json['actorId'] as String? ?? '',
      impulseX: (json['impulseX'] as num?)?.toDouble() ?? 0.0,
      impulseY: (json['impulseY'] as num?)?.toDouble() ?? 0.0,
      strikeOffset: (json['strikeOffset'] as num?)?.toDouble() ?? 0.0,
      nextTurn: json['nextTurn'] as String? ?? '',
    );
  }
}

class ShotResultData {
  final String roomId;
  final String actorId;
  final List<SimKeyframe> frames;
  final List<SimHitEvent> events;
  final int fell;
  final int winner;
  final String nextTurn;

  const ShotResultData({
    this.roomId = '',
    required this.actorId,
    required this.frames,
    required this.events,
    required this.fell,
    required this.winner,
    required this.nextTurn,
  });

  factory ShotResultData.fromJson(Map<String, dynamic> json) {
    final framesRaw = json['frames'] as List<dynamic>? ?? [];
    final eventsRaw = json['events'] as List<dynamic>? ?? [];

    return ShotResultData(
      roomId: json['roomId'] as String? ?? '',
      actorId: json['actorId'] as String? ?? '',
      frames: framesRaw
          .map((f) => SimKeyframe.fromList(f as List<dynamic>))
          .toList(),
      events: eventsRaw
          .map((e) => SimHitEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      fell: (json['fell'] as num?)?.toInt() ?? -1,
      winner: (json['winner'] as num?)?.toInt() ?? -1,
      nextTurn: json['nextTurn'] as String? ?? '',
    );
  }
}

class AimingData {
  final String roomId;
  final String actorId;
  final bool isAiming;
  final double pullX;
  final double pullY;
  final double strikeOffset;

  const AimingData({
    this.roomId = '',
    required this.actorId,
    required this.isAiming,
    required this.pullX,
    required this.pullY,
    required this.strikeOffset,
  });

  factory AimingData.fromJson(Map<String, dynamic> json) {
    return AimingData(
      roomId: json['roomId'] as String? ?? '',
      actorId: json['actorId'] as String? ?? '',
      isAiming: json['isAiming'] as bool? ?? false,
      pullX: (json['pullX'] as num?)?.toDouble() ?? 0.0,
      pullY: (json['pullY'] as num?)?.toDouble() ?? 0.0,
      strikeOffset: (json['strikeOffset'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TurnTimerData {
  final String roomId;
  final int secondsLeft;
  final String activeUserId;

  const TurnTimerData({
    this.roomId = '',
    required this.secondsLeft,
    required this.activeUserId,
  });

  factory TurnTimerData.fromJson(Map<String, dynamic> json) {
    return TurnTimerData(
      roomId: json['roomId'] as String? ?? '',
      secondsLeft: json['secondsLeft'] as int? ?? 30,
      activeUserId: json['activeUserId'] as String? ?? '',
    );
  }
}

class TurnTimeoutData {
  final String roomId;
  final String timedOutUserId;
  final String nextTurnUserId;
  final String reason;

  const TurnTimeoutData({
    this.roomId = '',
    required this.timedOutUserId,
    required this.nextTurnUserId,
    this.reason = 'timeout',
  });

  factory TurnTimeoutData.fromJson(Map<String, dynamic> json) {
    return TurnTimeoutData(
      roomId: json['roomId'] as String? ?? '',
      timedOutUserId: json['timedOutUserId'] as String? ?? '',
      nextTurnUserId: json['nextTurnUserId'] as String? ?? '',
      reason: json['reason'] as String? ?? 'timeout',
    );
  }
}

class EmojiData {
  final String senderId;
  final String emojiId;
  final String textBn;
  final String textEn;

  const EmojiData({
    required this.senderId,
    required this.emojiId,
    required this.textBn,
    this.textEn = '',
  });

  factory EmojiData.fromJson(Map<String, dynamic> json) {
    return EmojiData(
      senderId: json['senderId'] as String? ?? '',
      emojiId: json['emojiId'] as String? ?? 'smile',
      textBn: json['textBn'] as String? ?? '',
      textEn: json['textEn'] as String? ?? json['textBn'] as String? ?? '',
    );
  }
}

class MatchOverData {
  final String roomId;
  final String winnerId;
  final int payout;
  final int newBalance;
  final int trophyDelta;
  final int newTrophies;
  final String cupTier;
  final UserProfile? profile;

  const MatchOverData({
    this.roomId = '',
    required this.winnerId,
    required this.payout,
    required this.newBalance,
    this.trophyDelta = 0,
    this.newTrophies = 0,
    this.cupTier = 'bronze',
    this.profile,
  });

  factory MatchOverData.fromJson(Map<String, dynamic> json) {
    return MatchOverData(
      roomId: json['roomId'] as String? ?? '',
      winnerId: json['winnerId'] as String? ?? '',
      payout: json['payout'] as int? ?? 0,
      newBalance: json['newBalance'] as int? ?? 0,
      trophyDelta: (json['trophyDelta'] as num?)?.toInt() ?? 0,
      newTrophies: (json['newTrophies'] as num?)?.toInt() ?? 0,
      cupTier: json['cupTier'] as String? ?? 'bronze',
      profile: json['profile'] is Map<String, dynamic>
          ? UserProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }
}
