import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickman_physics/game/campus.dart';
import 'package:stickman_physics/game/heroes.dart';
import 'package:stickman_physics/game/school_game.dart';
import 'package:stickman_physics/main.dart';

/// [bestRoom] is the furthest room reached (kRooms index).
Future<SchoolGame> _boot(WidgetTester tester, Size size, {int bestRoom = 3}) async {
  SharedPreferences.setMockInitialValues({'best_room': bestRoom, 'rooms_v': kRoomsVersion});
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
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  return game;
}

/// Scrolls the character picker (the first list on screen) back to its start.
Future<void> _heroListToStart(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(900, 0));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f.hitTestable().first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final size in const [Size(844, 390), Size(640, 320)]) {
    testWidgets('menu lays out without overflow at $size', (tester) async {
      final game = await _boot(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('EXAM ESCAPE'), findsOneWidget);
      expect(find.text('NIGHTMARE UNIVERSITY'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget); // 2-2, the furthest room reached
      expect(find.text('LOCKED'), findsOneWidget); // 2-3, Mira's hideout, is still locked
      expect(game.floor, 3, reason: 'menu previews the furthest room reached');
    });
  }

  testWidgets('locked rooms cannot be picked; unlocked rooms start a run there', (tester) async {
    final game = await _boot(tester, const Size(844, 390));

    await _tap(tester, find.text('LOCKED'));
    expect(find.textContaining('first'), findsOneWidget);
    expect(game.floor, 3);

    await _tap(tester, find.text('THE SHIFTING STAIRS'));
    expect(game.floor, 2, reason: 'selecting previews that room');
    expect(find.text('PLAY 2-1  ▶'), findsOneWidget);

    await _tap(tester, find.text('PLAY 2-1  ▶'));
    expect(game.phase, Phase.intro);
    expect(game.floor, 2);
    expect(game.fullRun, isFalse);
  });

  testWidgets('floor tabs: locked floors say why, open ones jump to their rooms', (tester) async {
    final hideout = kRooms.indexWhere((r) => r.name == "Mira's Hideout");
    final game = await _boot(tester, const Size(844, 390), bestRoom: hideout);
    expect(game.room.building, '2');

    await _tap(tester, find.text('5 AM'));
    expect(find.textContaining('Finish Floor 2'), findsOneWidget);
    expect(game.room.building, '2');

    await _tap(tester, find.text('DONE'));
    expect(game.room.building, '1');
    expect(game.floor, kRooms.lastIndexWhere((r) => r.building == '1'));
    expect(find.text('DETENTION'), findsOneWidget);
  });

  testWidgets('a new player only has the first room unlocked; starting tells the prologue', (tester) async {
    final game = await _boot(tester, const Size(844, 390), bestRoom: 0);
    expect(find.text('LOCKED'), findsWidgets);
    expect(game.isUnlocked(1), isFalse);
    await _tap(tester, find.text('START  ▶'));
    expect(game.floor, 0);
    expect(game.fullRun, isTrue);
    expect(game.phase, Phase.story);
    expect(find.textContaining('2:59 AM'), findsWidgets);
    await _tap(tester, find.text('SKIP ▶▶'));
    expect(game.phase, Phase.story, reason: 'then Ozod meets Mira');
    expect(find.textContaining('pale, glowing girl'), findsWidgets);
    await _tap(tester, find.text('1/5   TAP ▶')); // the first tap finishes typing the line
    await _tap(tester, find.text('1/5   TAP ▶')); // the second moves on
    expect(find.text('MIRA'), findsOneWidget);
    await _tap(tester, find.text('SKIP ▶▶'));
    expect(game.phase, Phase.intro);
    expect(tester.takeException(), isNull);
  });

  testWidgets('characters unlock by beating bosses', (tester) async {
    final game = await _boot(tester, const Size(844, 390), bestRoom: 1);
    expect(game.bossesCleared, 0);
    await _heroListToStart(tester); // the picker opens scrolled to Ozod
    await _tap(tester, find.text('SWORDSMAN'));
    expect(find.textContaining('to unlock the Swordsman'), findsOneWidget);
    expect(game.heroIndex, kOzod, reason: 'new players start as Ozod');
  });

  testWidgets('those who woke up can switch to any character', (tester) async {
    final game = await _boot(tester, const Size(844, 390), bestRoom: kRooms.length);
    await _heroListToStart(tester); // the picker opens scrolled to Ozod
    await _tap(tester, find.text('MAGE'));
    expect(game.heroIndex, 2);
    expect(game.player.maxHp, 80);
    await tester.ensureVisible(find.text('DARK KNIGHT'));
    await tester.pump(const Duration(milliseconds: 300));
    await _tap(tester, find.text('DARK KNIGHT'));
    expect(game.heroIndex, 3);
    expect(game.player.maxHp, 125);
  });
}
