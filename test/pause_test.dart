import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickman_physics/game/school_game.dart';
import 'package:stickman_physics/main.dart';

Future<SchoolGame> _bootInFight(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({'best_floor': 2});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late SchoolGame game;
  await tester.runAsync(() async {
    await tester.pumpWidget(const ExamEscapeApp());
    game = tester.widget<GameWidget<SchoolGame>>(find.byType(GameWidget<SchoolGame>)).game!;
    for (var i = 0; i < 60 && !game.isReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });
  game.startRun(fromFloor: 1);
  game.beginFight();
  await tester.pump();
  return game;
}

Future<void> _pauseViaButton(WidgetTester tester, SchoolGame game) async {
  await tester.tap(find.byKey(const Key('pause')));
  await tester.pump(const Duration(milliseconds: 300));
  expect(game.isPaused, isTrue);
  expect(find.text('PAUSED'), findsOneWidget);
}

void main() {
  for (final size in const [Size(844, 390), Size(640, 320)]) {
    testWidgets('pause menu opens from the corner button and fits at $size', (tester) async {
      final game = await _bootInFight(tester, size);
      await _pauseViaButton(tester, game);
      expect(tester.takeException(), isNull);
      expect(find.text('RESUME  ▶'), findsOneWidget);
      expect(find.text('RETAKE ROUND'), findsOneWidget);

      await tester.tap(find.text('RESUME  ▶'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(game.isPaused, isFalse);
      expect(find.text('PAUSED'), findsNothing);
    });
  }

  testWidgets('retake round restarts the fight and un-pauses', (tester) async {
    final game = await _bootInFight(tester, const Size(844, 390));
    game.player.hp = 10;
    await _pauseViaButton(tester, game);
    await tester.tap(find.text('RETAKE ROUND'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.isPaused, isFalse);
    expect(game.phase, Phase.intro);
    expect(game.floor, 1);
    expect(game.player.hp, game.player.maxHp);
  });

  testWidgets('quit needs a second tap; music, sound and vibration toggles are saved', (tester) async {
    final game = await _bootInFight(tester, const Size(844, 390));
    await _pauseViaButton(tester, game);

    await tester.tap(find.text('VIBRATE'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.vibrationOn, isFalse);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect((await SharedPreferences.getInstance()).getBool('vibration'), isFalse);

    await tester.tap(find.text('MUSIC'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.musicOn, isFalse);
    expect(find.text('MUSIC OFF'), findsOneWidget);
    await tester.tap(find.text('SOUND'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.sfxOn, isFalse);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('music'), isFalse);
    expect(prefs.getBool('sfx'), isFalse);
    // Restore for other tests (the audio manager is shared).
    game.setMusic(true);
    game.setSfx(true);

    await tester.tap(find.text('QUIT TO MENU'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.phase, isNot(Phase.menu), reason: 'first tap only asks to confirm');
    expect(find.text('TAP AGAIN TO QUIT'), findsOneWidget);
    await tester.tap(find.text('TAP AGAIN TO QUIT'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.phase, Phase.menu);
    expect(game.isPaused, isFalse);
  });

  testWidgets('back button pauses a fight and resumes it', (tester) async {
    final game = await _bootInFight(tester, const Size(844, 390));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.isPaused, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.isPaused, isFalse);
  });

  testWidgets('leaving the app mid-fight pauses it', (tester) async {
    final game = await _bootInFight(tester, const Size(844, 390));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.isPaused, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(game.isPaused, isTrue, reason: 'stays paused until the player taps resume');
  });
}
