// lib/core/navigation/app_navigation.dart
import 'package:flutter/material.dart';

import '../../models/arena_room.dart';
import '../../models/kolom_spec.dart';
import '../../models/match_packet.dart';
import '../../ui/screens/game_screen.dart';
import '../auth/user_session.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Single owner for MATCH_START navigation. Lobby, private rooms, challenges
/// and rematches therefore cannot open duplicate game screens for one packet.
class AppNavigation {
  static String? _visibleMatchId;

  static void openMatch(MatchStartData match) {
    if (_visibleMatchId == match.roomId) return;
    final navigator = appNavigatorKey.currentState;
    final context = appNavigatorKey.currentContext;
    if (navigator == null || context == null) return;
    final profile = UserSession().profile;
    if (match.p1.id != profile.id && match.p2.id != profile.id) return;

    _visibleMatchId = match.roomId;
    final ownPlayer = match.p1.id == profile.id ? match.p1 : match.p2;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/match/${match.roomId}'),
        builder: (_) => GameScreen(
          room: ArenaRoom.getById(match.roomTypeId),
          playerPen: KolomSpec.getById(ownPlayer.penModel),
          isOnline: true,
          match: match,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  static void matchClosed(String roomId) {
    if (_visibleMatchId == roomId) _visibleMatchId = null;
  }
}
