import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolom_fight/core/auth/local_practice_profile.dart';
import 'package:kolom_fight/core/auth/user_session.dart';
import 'package:kolom_fight/ui/screens/auth_screen.dart';
import 'package:kolom_fight/ui/screens/room_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'practice profile is local, persistent and separate from online cache',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kolom_user_profile_v2', 'online cache');
      final first = await LocalPracticeProfile.getOrCreate(
        desiredName: '  Player  ',
        region: 'bd',
        division: 'Rajshahi',
      );
      final restored = await LocalPracticeProfile.getOrCreate(
        desiredName: 'Different',
      );

      expect(first.id, startsWith('local_guest_'));
      expect(first.username, 'Player');
      expect(first.region, 'BD');
      expect(first.division, 'Rajshahi');
      expect(restored.id, first.id);
      expect(restored.username, first.username);
      expect(prefs.getString('kolom_user_profile_v2'), 'online cache');
      expect(
        jsonDecode(prefs.getString('kolom_local_practice_profile_v1')!)['id'],
        first.id,
      );
    },
  );

  test(
    'corrupt practice data is replaced without touching online data',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kolom_local_practice_profile_v1', '{broken');
      await prefs.setString('kolom_user_profile_v2', 'online cache');
      final profile = await LocalPracticeProfile.getOrCreate();
      expect(profile.id, startsWith('local_guest_'));
      expect(prefs.getString('kolom_user_profile_v2'), 'online cache');
    },
  );

  test('practice stats persist wins, losses and streaks locally', () async {
    var stats = await LocalPracticeProfile.recordPracticeResult(isWinner: true);
    expect(stats.wins, 1);
    expect(stats.streak, 1);
    expect(stats.bestStreak, 1);

    stats = await LocalPracticeProfile.recordPracticeResult(isWinner: true);
    expect(stats.wins, 2);
    expect(stats.bestStreak, 2);

    stats = await LocalPracticeProfile.recordPracticeResult(isWinner: false);
    expect(stats.losses, 1);
    expect(stats.streak, 0);
    expect(stats.bestStreak, 2);

    final restored = await LocalPracticeProfile.getPracticeStats();
    expect(restored.wins, 2);
    expect(restored.losses, 1);
    expect(restored.matches, 3);
  });

  test(
    'corrupt practice stats reset instead of crashing the arena screen',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('kolom_practice_stats_v1', '{broken');
      final stats = await LocalPracticeProfile.getPracticeStats();
      expect(stats.matches, 0);
      expect(prefs.containsKey('kolom_practice_stats_v1'), isFalse);
    },
  );

  testWidgets('sign-in screen opens offline arenas without an online session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    final button = find.byKey(const Key('offline_practice_button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    final screen = tester.widget<RoomSelectionScreen>(
      find.byType(RoomSelectionScreen),
    );
    expect(screen.isOnline, isFalse);
    expect(screen.practiceProfile!.id, startsWith('local_guest_'));
    expect(UserSession().hasSessionToken, isFalse);
    expect(find.text('Offline Bot Arenas'), findsOneWidget);
    final play = find.widgetWithText(ElevatedButton, 'PLAY WITH BOT').first;
    expect(tester.widget<ElevatedButton>(play).onPressed, isNotNull);
  });
}
