import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickman_physics/game/school_game.dart';
import 'package:stickman_physics/main.dart';

Future<SchoolGame> _boot(WidgetTester tester, Size size, {int bestFloor = 3}) async {
  SharedPreferences.setMockInitialValues({'best_floor': bestFloor});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late SchoolGame game;
  await tester.runAsync(() async {
    await tester.pumpWidget(const ClassClashApp());
    game = tester.widget<GameWidget<SchoolGame>>(find.byType(GameWidget<SchoolGame>)).game!;
    for (var i = 0; i < 60 && !game.isReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });
  await tester.pump();
  // Let the building finish scrolling to the selected floor.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  return game;
}

void main() {
  for (final size in const [Size(844, 390), Size(640, 320)]) {
    testWidgets('menu lays out without overflow at $size', (tester) async {
      final game = await _boot(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('CLASS CLASH'), findsOneWidget);
      expect(find.text('LOCKED'), findsWidgets); // floors above 3
      expect(find.text('NEW'), findsOneWidget); // floor 3
      expect(game.floor, 3, reason: 'menu previews the furthest unlocked floor');
    });
  }

  testWidgets('locked floors cannot be picked; unlocked floors start a run there', (tester) async {
    final game = await _boot(tester, const Size(844, 390));

    await tester.tap(find.text('LOCKED').hitTestable().first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('to unlock'), findsOneWidget);
    expect(game.floor, 3);

    await tester.tap(find.text('HUMAN & AI').hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.floor, 2, reason: 'selecting previews that room');
    expect(find.text('PLAY FLOOR 2  ▶'), findsOneWidget);

    await tester.tap(find.text('PLAY FLOOR 2  ▶'));
    await tester.pump();
    expect(game.phase, Phase.intro);
    expect(game.floor, 2);
    expect(game.fullRun, isFalse);
  });

  testWidgets('a new player only has the basement unlocked', (tester) async {
    final game = await _boot(tester, const Size(844, 390), bestFloor: 0);
    expect(find.text('LOCKED'), findsWidgets);
    expect(game.isUnlocked(1), isFalse);
    expect(find.text('START  ▶'), findsOneWidget);
    await tester.tap(find.text('START  ▶'));
    await tester.pump();
    expect(game.floor, 0);
    expect(game.fullRun, isTrue);
  });

  testWidgets('characters unlock as you climb and can be selected', (tester) async {
    final game = await _boot(tester, const Size(844, 390), bestFloor: 1);
    expect(game.heroIndex, 0);
    await tester.tap(find.text('SWORDSMAN'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Reach floor 2'), findsOneWidget);
    expect(game.heroIndex, 0);
  });

  testWidgets('unlocked characters can be switched', (tester) async {
    final game2 = await _boot(tester, const Size(844, 390), bestFloor: 5);
    await tester.tap(find.text('MAGE'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(game2.heroIndex, 2);
    expect(game2.player.maxHp, 80);
    await tester.ensureVisible(find.text('DARK KNIGHT'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('DARK KNIGHT').hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
    expect(game2.heroIndex, 3);
    expect(game2.player.maxHp, 125);
  });
}
