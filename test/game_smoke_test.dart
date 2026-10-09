import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickman_physics/game/entities.dart';
import 'package:stickman_physics/game/heroes.dart';
import 'package:stickman_physics/game/minions.dart';
import 'package:stickman_physics/game/school_game.dart';
import 'package:stickman_physics/game/teachers.dart';

void main() {
  testWidgets('a student can fight through every floor and graduate', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final game = SchoolGame();
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: GameWidget(
          game: game,
          overlayBuilderMap: {
            for (final n in kAllOverlays) n: (_, __) => const SizedBox(),
          },
          initialActiveOverlays: const ['menu'],
        ),
      ));
      for (var i = 0; i < 50 && !game.isReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    expect(game.isReady, isTrue);

    void frames(int n) {
      for (var i = 0; i < n; i++) {
        game.update(1 / 60);
        if (i % 7 == 0) {
          final rec = ui.PictureRecorder();
          game.render(Canvas(rec));
          rec.endRecording().dispose();
        }
      }
    }

    game.startRun();
    expect(game.phase, Phase.intro);

    var tookDamage = false;
    for (var f = 0; f < kFloors.length; f++) {
      expect(game.floor, f);
      game.beginFight();
      expect(game.phase, Phase.fight);

      // Let the teacher use abilities for a while; keep the student alive.
      for (var s = 0; s < 900; s++) {
        if (game.player.hp < game.player.maxHp) tookDamage = true;
        game.player.hp = 100;
        game.right = s % 120 < 60;
        game.left = !game.right;
        if (s % 40 == 0) game.pressJump();
        if (s % 9 == 0) game.pressAttack();
        if (s % 200 == 0) game.pressSpecial();
        frames(1);
      }
      game.left = game.right = false;

      // Finish the teacher off with sword hits: MIDTERM, then FINAL EXAM.
      var sawFinal = false;
      for (var s = 0; s < 2400 && game.phase != Phase.cleared; s++) {
        if (game.phase == Phase.fight) game.teacher.hp = min(game.teacher.hp, 1);
        if (game.isFinalRound) sawFinal = true;
        game.player.hp = 100;
        final dx = game.teacher.x - game.player.x;
        game.right = dx > 10;
        game.left = dx < -10;
        if (dx.abs() < 14 && game.player.facing != dx.sign) {
          dx > 0 ? game.right = true : game.left = true;
        }
        if (dx.abs() < 18) game.pressAttack();
        frames(1);
      }
      expect(game.phase, Phase.cleared, reason: 'floor $f teacher should be beaten');
      expect(sawFinal, isTrue, reason: 'floor $f should have a FINAL EXAM round');
      expect(game.teacher.state, TState.dead);

      // Walk to the stairs.
      game.left = false;
      game.right = true;
      for (var s = 0; s < 600 && game.phase == Phase.cleared; s++) {
        frames(1);
      }
      game.right = false;
      frames(80); // fade transition
    }
    expect(game.phase, Phase.victory);
    expect(game.bestFloor, kFloors.length);
    expect(tookDamage, isTrue, reason: 'teachers should be able to hurt the student');

    // Retry flow
    game.startRun();
    game.beginFight();
    game.player.hp = 1;
    game.player.invuln = 0;
    for (var s = 0; s < 2000 && game.phase == Phase.fight; s++) {
      frames(1);
    }
    expect(game.phase, Phase.gameOver);
    frames(120);
    game.retryFloor();
    expect(game.phase, Phase.intro);
    expect(game.player.hp, game.player.maxHp);
  });

  testWidgets('dying to any teacher (including hazards) never freezes the game', (tester) async {
    final game = await _loadGame(tester);
    for (var f = 0; f < kFloors.length; f++) {
      _goToFloor(game, f);
      game.beginFight();
      for (var s = 0; s < 60 * 60 && game.phase == Phase.fight; s++) {
        game.player.hp = min(game.player.hp, 5);
        game.update(1 / 60); // throws if the loop crashes
      }
      expect(game.phase, Phase.gameOver, reason: 'floor $f');
      for (var s = 0; s < 120; s++) {
        game.update(1 / 60);
      }
      game.retryFloor();
      expect(game.phase, Phase.intro);
      expect(game.left || game.right, isFalse);
    }
  });

  testWidgets('every character can fight every teacher', (tester) async {
    final game = await _loadGame(tester);
    game.bestFloor = kFloors.length; // unlock everything
    for (var h = 0; h < kHeroes.length; h++) {
    game.selectHero(h);
    expect(game.heroIndex, h);
    for (var f = 0; f < kFloors.length; f++) {
      _goToFloor(game, f);
      game.beginFight();
      final startHp = game.teacher.hp;
      var hits = 0;
      var last = startHp;
      for (var s = 0; s < 60 * 30 && (game.phase == Phase.fight || game.phase == Phase.roundBreak); s++) {
        game.player.hp = 100;
        final dx = game.teacher.x - game.player.x;
        game.right = dx > 14;
        game.left = dx < -14;
        if (dx.abs() <= 14 && game.player.facing != dx.sign && dx != 0) {
          dx > 0 ? game.right = true : game.left = true;
        }
        // Mage keeps its distance and shoots; sword users get close.
        final reach = kHeroes[h].attack == HeroAttack.magic ? 70 : 22;
        if (kHeroes[h].attack == HeroAttack.magic) {
          game.right = dx > 60;
          game.left = dx < -60 || (dx.abs() < 30 && dx > 0);
          if (dx.abs() < 70 && game.player.facing != dx.sign && dx != 0 && !game.left) {
            dx > 0 ? game.right = true : game.left = true;
          }
        }
        if (dx.abs() < reach) game.pressAttack();
        if (s % 300 == 150) game.player.energy = 100;
        if (s % 300 == 151) game.pressSpecial();
        game.update(1 / 60);
        if (game.teacher.hp < last) hits++;
        last = game.teacher.hp;
      }
      // ~20 seconds of honest fighting should land plenty of hits.
      expect(hits > 15 || game.phase == Phase.cleared, isTrue, reason: 'floor $f: only $hits hits landed');
      debugPrint('${kHeroes[h].name} floor $f: $hits hits, teacher ${game.teacher.hp.round()}/$startHp HP, ${game.phase}');
    }
    }
  });

  testWidgets('dodge roll makes you invincible and rewards a perfect dodge', (tester) async {
    final game = await _loadGame(tester);
    _goToFloor(game, 0);
    game.beginFight();
    game.teacher.cooldown = 999;
    game.player
      ..energy = 0
      ..x = game.teacher.x - 2; // standing inside the teacher
    game.pressRoll();
    for (var i = 0; i < 12; i++) {
      game.update(1 / 60);
    }
    expect(game.player.hp, game.player.maxHp, reason: 'rolling through the teacher should not hurt');
    expect(game.player.energy, greaterThanOrEqualTo(15), reason: 'perfect dodge bonus');
  });

  testWidgets('skeletons block from the front but not from behind; minions die and build combos', (tester) async {
    final game = await _loadGame(tester);
    _goToFloor(game, 5);
    game.beginFight();
    game.teacher.cooldown = 999;
    game.teacher.x = game.W - 15;
    game.player
      ..x = 40
      ..facing = 1;
    final sk = game.debugSpawnMinion(MinionKind.skeleton, 58)..facing = -1;
    void run(int n) {
      for (var i = 0; i < n; i++) {
        game.player.hp = game.player.maxHp;
        game.update(1 / 60);
      }
    }

    game.pressAttack();
    run(25);
    expect(sk.hp, sk.def.hp, reason: 'shield blocks a hit from the front');

    // Jump over it and strike its back before it turns around.
    game.player
      ..x = sk.x + 12
      ..facing = -1;
    game.pressAttack();
    run(20);
    expect(sk.hp, lessThan(sk.def.hp), reason: 'hit from behind lands');

    final gob = game.debugSpawnMinion(MinionKind.goblin, game.player.x - 14);
    for (var i = 0; i < 300 && gob.state != MState.dead; i++) {
      game.player.facing = gob.x < game.player.x ? -1 : 1;
      game.pressAttack();
      run(1);
    }
    expect(gob.state, MState.dead);
    expect(game.maxCombo, greaterThanOrEqualTo(3));
  });

  testWidgets('samurai Iaido teleports behind the teacher and slashes', (tester) async {
    final game = await _loadGame(tester);
    game.bestFloor = kFloors.length;
    game.selectHero(kHeroes.indexWhere((h) => h.name == 'Samurai'));
    _goToFloor(game, 0);
    game.beginFight();
    game.teacher.cooldown = 999;
    game.player
      ..x = 20
      ..energy = 100;
    final hp = game.teacher.hp;
    game.pressSpecial();
    for (var i = 0; i < 30; i++) {
      game.update(1 / 60);
    }
    expect(game.teacher.hp, lessThan(hp));
    expect(game.player.x, greaterThan(game.teacher.x), reason: 'ended up behind the teacher');
  });
}

Future<SchoolGame> _loadGame(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final game = SchoolGame();
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: GameWidget(
        game: game,
        overlayBuilderMap: {for (final n in kAllOverlays) n: (_, __) => const SizedBox()},
      ),
    ));
    for (var i = 0; i < 50 && !game.isReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });
  return game;
}

/// Skips straight to floor [f] by beating each earlier teacher.
void _goToFloor(SchoolGame game, int f) {
  game.startRun();
  while (game.floor < f) {
    game.beginFight();
    for (var i = 0; i < 2000 && game.phase != Phase.cleared; i++) {
      if (game.phase == Phase.fight) {
        game.teacher.hp = min(game.teacher.hp, 1);
        game.player.x = max(6, game.teacher.x - 10);
        game.player.facing = 1;
        game.pressAttack();
      }
      game.player.hp = game.player.maxHp;
      game.update(1 / 60);
    }
    game.player.x = game.W - 10;
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
    }
  }
}
