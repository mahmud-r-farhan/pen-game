// lib/models/match_packet.dart
import '../game/kolom_physics_sim.dart';

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
      id: json['id'] as String? ?? 'p_anon',
      username: json['username'] as String? ?? 'Player',
      tag: json['tag'] as String? ?? '#KLM-0000',
      avatar: json['avatar'] as String? ?? 'avatar_student_boy',
      penModel: json['penModel'] as String? ?? 'hiSchoolClassic',
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

  const MatchStartData({
    required this.roomId,
    required this.roomTypeId,
    required this.pot,
    required this.firstTurn,
    required this.p1,
    required this.p2,
  });

  factory MatchStartData.fromJson(Map<String, dynamic> json) {
    return MatchStartData(
      roomId: json['roomId'] as String? ?? '',
      roomTypeId: json['roomTypeId'] as String? ?? 'primary_school',
      pot: json['pot'] as int? ?? 100,
      firstTurn: json['firstTurn'] as String? ?? '',
      p1: MatchPlayer.fromJson(json['p1'] as Map<String, dynamic>? ?? {}),
      p2: MatchPlayer.fromJson(json['p2'] as Map<String, dynamic>? ?? {}),
    );
  }
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
  final String actorId;
  final List<SimKeyframe> frames;
  final List<SimHitEvent> events;
  final int fell;
  final int winner;
  final String nextTurn;

  const ShotResultData({
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
      actorId: json['actorId'] as String? ?? '',
      frames: framesRaw.map((f) => SimKeyframe.fromList(f as List<dynamic>)).toList(),
      events: eventsRaw.map((e) => SimHitEvent.fromJson(e as Map<String, dynamic>)).toList(),
      fell: (json['fell'] as num?)?.toInt() ?? -1,
      winner: (json['winner'] as num?)?.toInt() ?? -1,
      nextTurn: json['nextTurn'] as String? ?? '',
    );
  }
}

class AimingData {
  final String actorId;
  final bool isAiming;
  final double pullX;
  final double pullY;
  final double strikeOffset;

  const AimingData({
    required this.actorId,
    required this.isAiming,
    required this.pullX,
    required this.pullY,
    required this.strikeOffset,
  });

  factory AimingData.fromJson(Map<String, dynamic> json) {
    return AimingData(
      actorId: json['actorId'] as String? ?? '',
      isAiming: json['isAiming'] as bool? ?? false,
      pullX: (json['pullX'] as num?)?.toDouble() ?? 0.0,
      pullY: (json['pullY'] as num?)?.toDouble() ?? 0.0,
      strikeOffset: (json['strikeOffset'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TurnTimerData {
  final int secondsLeft;
  final String activeUserId;

  const TurnTimerData({
    required this.secondsLeft,
    required this.activeUserId,
  });

  factory TurnTimerData.fromJson(Map<String, dynamic> json) {
    return TurnTimerData(
      secondsLeft: json['secondsLeft'] as int? ?? 30,
      activeUserId: json['activeUserId'] as String? ?? '',
    );
  }
}

class TurnTimeoutData {
  final String timedOutUserId;
  final String nextTurnUserId;

  const TurnTimeoutData({
    required this.timedOutUserId,
    required this.nextTurnUserId,
  });

  factory TurnTimeoutData.fromJson(Map<String, dynamic> json) {
    return TurnTimeoutData(
      timedOutUserId: json['timedOutUserId'] as String? ?? '',
      nextTurnUserId: json['nextTurnUserId'] as String? ?? '',
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
  final String winnerId;
  final int payout;
  final int newBalance;
  final int trophyDelta;
  final int newTrophies;
  final String cupTier;

  const MatchOverData({
    required this.winnerId,
    required this.payout,
    required this.newBalance,
    this.trophyDelta = 25,
    this.newTrophies = 125,
    this.cupTier = 'bronze',
  });

  factory MatchOverData.fromJson(Map<String, dynamic> json) {
    return MatchOverData(
      winnerId: json['winnerId'] as String? ?? '',
      payout: json['payout'] as int? ?? 0,
      newBalance: json['newBalance'] as int? ?? 0,
      trophyDelta: json['trophyDelta'] as int? ?? 25,
      newTrophies: json['newTrophies'] as int? ?? 125,
      cupTier: json['cupTier'] as String? ?? 'bronze',
    );
  }
}
