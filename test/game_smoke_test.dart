import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stickman_physics/game/campus.dart';
import 'package:stickman_physics/game/heroes.dart';
import 'package:stickman_physics/game/minions.dart';
import 'package:stickman_physics/game/school_game.dart';
import 'package:stickman_physics/game/story.dart';
import 'package:stickman_physics/game/teachers.dart';
import 'package:stickman_physics/game/vibes.dart';

Future<SchoolGame> _loadGame(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final game = SchoolGame(seed: 7);
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

void _frames(SchoolGame game, int n, {bool render = false}) {
  for (var i = 0; i < n; i++) {
    game.update(1 / 60);
    if (render && i % 7 == 0) {
      final rec = ui.PictureRecorder();
      game.render(Canvas(rec));
      rec.endRecording().dispose();
    }
  }
}

/// Taps through any story panels on screen.
void _skipStories(SchoolGame game) {
  for (var i = 0; i < 5 && game.phase == Phase.story; i++) {
    game.endStory();
  }
}

/// Starts a run directly in room [r] (unlocking it first), past any story.
void _goToRoom(SchoolGame game, int r) {
  game.bestFloor = max(game.bestFloor, r);
  game.startRun(fromFloor: r);
  _skipStories(game);
}

final _bossRooms = [for (var i = 0; i < kRooms.length; i++) if (kRooms[i].isBoss) i];
final _reaperRoom = kRooms.length - 1;

/// Wins the boss round in progress (boss at 1 HP, one sword hit).
void _winRound(SchoolGame game) {
  final start = game.round;
  for (var i = 0; i < 600 && game.round == start && game.phase == Phase.fight; i++) {
    game.player.hp = game.player.maxHp;
    game.teacher.hp = min(game.teacher.hp, 1);
    game.player
      ..x = max(6, game.teacher.x - 10)
      ..facing = 1;
    game.pressAttack();
    _frames(game, 1);
  }
}

/// Clears the current room quickly (bosses at 1 HP, waves wiped out, and
/// the Grade Reaper's fear faced by standing still).
void _clearRoom(SchoolGame game, {bool render = false}) {
  if (game.phase == Phase.rest) {
    game.leaveRest();
    return;
  }
  game.beginFight();
  for (var i = 0; i < 4000 && game.phase != Phase.cleared; i++) {
    _skipStories(game);
    game.player.hp = game.player.maxHp;
    if (game.room.isBoss) {
      if (game.phase == Phase.fight && game.fearPhase) {
        game.left = game.right = false; // stop running
      } else if (game.phase == Phase.fight) {
        game.teacher.hp = min(game.teacher.hp, 1);
        game.player.x = max(6, game.teacher.x - 10);
        game.player.facing = 1;
        game.pressAttack();
      }
    } else if (i % 20 == 0) {
      game.debugKillMinions();
    }
    _frames(game, 1, render: render && i % 3 == 0);
  }
}

/// Walks through the open exit and waits for the next room to load.
void _walkToExit(SchoolGame game) {
  game.left = false;
  game.right = true;
  for (var s = 0; s < 900 && (game.phase == Phase.cleared || game.phase == Phase.story); s++) {
    if (game.phase == Phase.story) {
      game.endStory();
      game.right = true;
    }
    _frames(game, 1);
  }
  game.right = false;
  _frames(game, 80); // fade transition
  _skipStories(game);
}

void main() {
  testWidgets('Ozod climbs all six floors, finds every Lost Note and wakes up', (tester) async {
    final game = await _loadGame(tester);
    game.startRun();
    expect(game.phase, Phase.story, reason: 'the prologue opens the run');
    expect(game.story, kPrologue);
    game.endStory();
    expect(game.story, kMeetMira, reason: 'then Ozod meets Mira');
    game.endStory();
    var bosses = 0, waves = 0;
    for (var r = 0; r < kRooms.length; r++) {
      expect(game.floor, r, reason: 'should be in room ${kRooms[r].label}');
      final room = kRooms[r];
      if (room.kind == RoomKind.rest) {
        expect(game.phase, Phase.rest);
        expect(game.player.hp, game.player.maxHp, reason: 'Mira\'s corners heal fully');
      } else {
        expect(game.phase, Phase.intro);
      }
      _clearRoom(game, render: true);
      if (room.isBoss) bosses++;
      if (room.kind == RoomKind.hall) waves += room.waves.length;
      expect(game.phase, Phase.cleared, reason: '${room.label} should be cleared');
      _walkToExit(game);
    }
    expect(game.notesFound, kLostNotes.length, reason: 'every Lost Note was picked up');
    // Beating the Grade Reaper: walk into the morning light...
    expect(game.escaping, isTrue);
    expect(game.sceneName, isNotNull);
    expect(game.phase, Phase.cleared);
    expect(game.clockMinutes, 8 * 60 + 59);
    _frames(game, 30, render: true);
    game.right = true;
    for (var s = 0; s < 900 && game.phase == Phase.cleared; s++) {
      _frames(game, 1);
    }
    // ...and wake up.
    expect(game.phase, Phase.story);
    expect(game.story, kEnding);
    game.endStory();
    expect(game.phase, Phase.victory);
    expect(game.bestFloor, kRooms.length);
    expect(game.bossesCleared, kFloors.length);
    expect(bosses, kFloors.length, reason: '5 guardians + the Grade Reaper');
    expect(waves, greaterThanOrEqualTo(10));
  });

  testWidgets('monster halls spawn every wave, then open the exit (honest bot)', (tester) async {
    final game = await _loadGame(tester);
    _goToRoom(game, 0);
    game.beginFight();
    var maxWaveSeen = 0;
    for (var s = 0; s < 60 * 60 && game.phase == Phase.fight; s++) {
      game.player.hp = game.player.maxHp;
      final alive = game.minions.where((m) => m.state != MState.dead).toList();
      if (alive.isNotEmpty) {
        alive.sort((a, b) => (a.x - game.player.x).abs().compareTo((b.x - game.player.x).abs()));
        final m = alive.first;
        final dx = m.x - game.player.x;
        game.right = dx > 10;
        game.left = dx < -10;
        if (dx.abs() <= 10 && dx != 0 && game.player.facing != dx.sign) dx > 0 ? game.right = true : game.left = true;
        if (m.def.flying && s % 25 == 0) game.pressJump();
        if (dx.abs() < 24) game.pressAttack();
      }
      if (s % 400 == 200) game.player.energy = 100;
      if (s % 400 == 201) game.pressSpecial();
      maxWaveSeen = max(maxWaveSeen, game.wave);
      _frames(game, 1);
    }
    expect(maxWaveSeen, kRooms[0].waves.length - 1, reason: 'every wave should spawn');
    // Cleared — or already walking out, if the last monster fell by the exit door.
    expect(game.phase, isIn([Phase.cleared, Phase.transition]), reason: 'clearing all waves opens the exit');
  });

  testWidgets("Mira's corners heal; at the final staircase she gives her Lost Note", (tester) async {
    final game = await _loadGame(tester);
    final hideout = kRooms.indexWhere((r) => r.kind == RoomKind.rest);
    _goToRoom(game, hideout);
    expect(game.phase, Phase.rest);
    expect(game.notesFound, 2, reason: 'notes from the two floors below are remembered');
    game.leaveRest();
    expect(game.phase, Phase.cleared);

    final stairs = kRooms.indexWhere((r) => r.gift);
    game.bestFloor = stairs;
    game.startRun(fromFloor: stairs);
    expect(game.phase, Phase.story);
    expect(game.story, kFinalStairs);
    game.endStory();
    expect(game.phase, Phase.rest);
    expect(game.perks, contains(kLostNotes.last));
    expect(game.notesFound, kLostNotes.length);
    expect(game.player.maxHp, kHeroes[game.heroIndex].hp + 25, reason: '"Rest Is Power" adds max HP');
    expect(game.player.hp, game.player.maxHp);
  });

  testWidgets('dying anywhere (including hazards and monsters) never freezes the game', (tester) async {
    final game = await _loadGame(tester);
    for (final r in [0, ..._bossRooms]) {
      _goToRoom(game, r);
      game.beginFight();
      for (var s = 0; s < 60 * 90 && game.phase != Phase.gameOver; s++) {
        game.player.hp = min(game.player.hp, 5);
        game.update(1 / 60); // throws if the loop crashes
      }
      expect(game.phase, Phase.gameOver, reason: 'room ${kRooms[r].label}');
      _frames(game, 120);
      game.retryFloor();
      expect(game.phase, Phase.intro, reason: 'retrying skips the story you already saw');
      expect(game.left || game.right, isFalse);
    }
  });

  testWidgets('every character can fight every boss', (tester) async {
    final game = await _loadGame(tester);
    game.bestFloor = kRooms.length; // unlock everything
    for (var h = 0; h < kHeroes.length; h++) {
      game.selectHero(h);
      expect(game.heroIndex, h);
      for (final r in _bossRooms) {
        _goToRoom(game, r);
        game.beginFight();
        final startHp = game.teacher.hp;
        var hits = 0;
        var last = startHp;
        for (var s = 0; s < 60 * 30 && (game.phase == Phase.fight || game.phase == Phase.roundBreak); s++) {
          game.player.hp = game.player.maxHp;
          final dx = game.teacher.x - game.player.x;
          game.right = dx > 14;
          game.left = dx < -14;
          if (dx.abs() <= 14 && game.player.facing != dx.sign && dx != 0) {
            dx > 0 ? game.right = true : game.left = true;
          }
          // Mage keeps its distance and shoots; sword users get close.
          final magic = kHeroes[h].attack == HeroAttack.magic;
          if (magic) {
            game.right = dx > 60;
            game.left = dx < -60 || (dx.abs() < 30 && dx > 0);
            if (dx.abs() < 70 && game.player.facing != dx.sign && dx != 0 && !game.left) {
              dx > 0 ? game.right = true : game.left = true;
            }
          }
          if (dx.abs() < (magic ? 70 : 22)) game.pressAttack();
          if (s % 300 == 150) game.player.energy = 100;
          if (s % 300 == 151) game.pressSpecial();
          game.update(1 / 60);
          if (game.teacher.hp < last) hits++;
          last = game.teacher.hp;
        }
        // (The Librarian's flying books soak up some of the Mage's bolts.)
        expect(hits > 12 || game.phase == Phase.cleared, isTrue,
            reason: '${kHeroes[h].name} vs ${kRooms[r].label}: only $hits hits landed');
      }
    }
  });

  testWidgets('dodge roll makes you invincible and rewards a perfect dodge', (tester) async {
    final game = await _loadGame(tester);
    _goToRoom(game, _bossRooms.first);
    game.beginFight();
    game.teacher.cooldown = 999;
    game.player
      ..energy = 0
      ..x = game.teacher.x - 2; // standing inside the boss
    game.pressRoll();
    _frames(game, 12);
    expect(game.player.hp, game.player.maxHp, reason: 'rolling through the boss should not hurt');
    expect(game.player.energy, greaterThanOrEqualTo(15), reason: 'perfect dodge bonus');
  });

  testWidgets('skeletons block from the front but not from behind; minions die and build combos', (tester) async {
    final game = await _loadGame(tester);
    _goToRoom(game, _bossRooms.last);
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

  testWidgets('samurai Iaido teleports behind the boss and slashes', (tester) async {
    final game = await _loadGame(tester);
    game.bestFloor = kRooms.length;
    game.selectHero(kHeroes.indexWhere((h) => h.name == 'Samurai'));
    _goToRoom(game, _bossRooms.first);
    game.beginFight();
    game.teacher.cooldown = 999;
    game.player
      ..x = 20
      ..energy = 100;
    final hp = game.teacher.hp;
    game.pressSpecial();
    _frames(game, 30);
    expect(game.teacher.hp, lessThan(hp));
    expect(game.player.x, greaterThan(game.teacher.x), reason: 'ended up behind the boss');
  });

  testWidgets('old saves keep the number of bosses beaten', (tester) async {
    // The oldest saves counted teachers beaten.
    var game = await _loadGame(tester, prefs: {'best_floor': 3});
    expect(game.bossesCleared, 3);
    expect(kRooms[game.bestFloor].label, '4-1', reason: 'resumes on the floor after the 3rd boss');

    // Campus v1: the C lobby came after two teachers.
    game = await _loadGame(tester, prefs: {'best_room': 5});
    expect(game.bossesCleared, 2);
    expect(kRooms[game.bestFloor].label, '2-3');

    expect(migrateRoomIndex(16, 1), kRooms.length, reason: 'graduates are still awake');
    expect(migrateRoomIndex(18, 2), kRooms.length);
    expect(migrateRoomIndex(17, 2), _reaperRoom, reason: 'reached the Grade Reaper → still at his door');
    expect(migrateTeacherFloor(7), kRooms.length);
  });

  testWidgets('the Grade Reaper: dash, teleport-behind slash and lights out', (tester) async {
    final game = await _loadGame(tester);
    expect(kRooms[_reaperRoom].def.scary, isTrue, reason: 'the villain waits in the last room');
    _goToRoom(game, _reaperRoom);
    game.beginFight();
    game.teacher.cooldown = 999;
    void run(int n) {
      for (var i = 0; i < n; i++) {
        game.player.hp = game.player.maxHp;
        game.update(1 / 60);
      }
    }

    // Shadow dash crosses a big part of the room.
    game.player.x = 20;
    game.teacher.x = game.W - 30;
    run(2);
    final startX = game.teacher.x;
    game.debugCast(Ability.shadowDash);
    var furthest = 0.0;
    for (var i = 0; i < 90; i++) {
      run(1);
      furthest = max(furthest, (game.teacher.x - startX).abs());
    }
    expect(furthest, greaterThan(60), reason: 'the demon dashed across the room');

    // Teleport lands behind the student, then slashes.
    game.player
      ..x = game.W / 2
      ..facing = 1
      ..invuln = 0;
    game.debugCast(Ability.shadowTeleport);
    var hurt = false;
    for (var i = 0; i < 90; i++) {
      game.player.facing = 1; // keep looking away from it
      game.update(1 / 60);
      if (game.player.hp < game.player.maxHp) hurt = true;
      if (i == 25) expect(game.teacher.x, lessThan(game.player.x), reason: 'appeared behind');
    }
    expect(hurt, isTrue, reason: 'standing still gets you slashed (before he unmasks)');

    game.player.hp = game.player.maxHp;
    final eyes = game.minionCount;
    game.debugCast(Ability.lightsOut);
    run(80);
    expect(game.minionCount, greaterThan(eyes), reason: 'eyes come out in the dark');
  });

  testWidgets('the Grade Reaper\'s three phases: red pen, boss shadows, and the fear you face standing still',
      (tester) async {
    final game = await _loadGame(tester);
    _goToRoom(game, _reaperRoom);
    expect(game.notesFound, kLostNotes.length, reason: 'all notes from the floors below');
    game.beginFight();
    game.teacher.cooldown = 999;

    // Phase 1: the red pen burns "F" marks into the floor.
    game.player
      ..x = 40
      ..invuln = 0;
    game.debugCast(Ability.redPen);
    _frames(game, 90, render: true);
    expect(game.player.hp, lessThan(game.player.maxHp), reason: 'standing on a burning F hurts');

    _winRound(game);
    expect(game.phase, Phase.roundBreak);
    _frames(game, 200);
    expect(game.round, 2);
    expect(game.roundName, 'SHADOWS');

    // Phase 2: the shadow of a beaten boss rises for each borrowed attack.
    game.teacher.cooldown = 999;
    game.debugCast(Ability.numberSpread);
    _frames(game, 10, render: true);
    expect(game.debugEchoes, 1, reason: "Professor Calculus' shadow rises");
    _frames(game, 120);
    expect(game.debugEchoes, 0, reason: 'shadows fade away');

    // Phase 3: the hood comes off.
    _winRound(game);
    _frames(game, 200);
    expect(game.phase, Phase.story);
    expect(game.story, kUnmasked);
    game.endStory();
    expect(game.phase, Phase.fight);
    expect(game.fearPhase, isTrue);
    expect(game.bossName, 'YOUR FEAR');
    game.teacher.cooldown = 999;

    // Fighting fear only feeds it.
    final fear = game.teacher.hp;
    for (var i = 0; i < 120; i++) {
      game.player.hp = game.player.maxHp;
      game.player
        ..x = game.teacher.x - 12
        ..facing = 1;
      game.pressAttack();
      _frames(game, 1);
    }
    expect(game.teacher.hp, greaterThanOrEqualTo(fear), reason: 'you can\'t kill fear');
    expect(game.phase, Phase.fight);

    // Standing still: nothing can hurt you, and he shrinks.
    game.player
      ..x = 30
      ..hp = game.player.maxHp;
    game.teacher.x = game.W - 30;
    game.left = game.right = false;
    _frames(game, 60);
    expect(game.debugBrave, isTrue);
    final hp = game.player.hp;
    game.debugCast(Ability.bloodRain);
    var frames = 0;
    for (; frames < 60 * 15 && game.phase == Phase.fight; frames++) {
      _frames(game, 1);
    }
    expect(game.player.hp, hp, reason: 'fear cannot touch you while you stand still');
    expect(game.phase, Phase.cleared, reason: 'he shrank to nothing');
    expect(frames, lessThan(60 * 8), reason: 'six Lost Notes make it quick');
    expect(game.teacher.size, lessThan(0.3), reason: 'just a tiny red pen on the floor');
  });

  testWidgets('the Deadline Twins take turns; hitting one makes the other stronger', (tester) async {
    final game = await _loadGame(tester);
    final office = kRooms.indexWhere((r) => r.isBoss && r.def.twins.isNotEmpty);
    _goToRoom(game, office);
    game.beginFight();
    game.teacher.cooldown = 999;
    expect(game.bossName, 'Tomorrow');
    expect(game.currentAbilities, kFloors[4].twinAbilities[0]);

    for (var i = 0; i < 60; i++) {
      game.player.hp = game.player.maxHp;
      game.player
        ..x = game.teacher.x - 10
        ..facing = 1;
      game.pressAttack();
      _frames(game, 1);
    }
    expect(game.teacher.twinPower[1], greaterThan(0), reason: 'Too Late grew stronger');

    // They swap once the twin on stage stops flinching.
    game.teacher.twinSwap = 0;
    for (var i = 0; i < 60 && game.bossName == 'Tomorrow'; i++) {
      game.player.hp = game.player.maxHp;
      _frames(game, 1, render: i % 10 == 0);
    }
    expect(game.bossName, 'Too Late');
    expect(game.currentAbilities, kFloors[4].twinAbilities[1]);
    expect(game.teacher.twinPower[1], greaterThan(0), reason: 'Too Late comes out stronger');
    expect(game.teacher.twinPower[0], 0);
  });

  testWidgets('after the Librarian fades, Mira finds the book; her note drops', (tester) async {
    final game = await _loadGame(tester);
    final reading = kRooms.indexWhere((r) => r.isBoss && r.def.name == 'The Librarian');
    _goToRoom(game, reading);
    expect(kRooms[reading].def.dark, isTrue);
    game.beginFight();
    for (var i = 0; i < 3000 && game.phase != Phase.cleared; i++) {
      game.player.hp = game.player.maxHp;
      if (game.phase == Phase.fight) {
        game.teacher.hp = min(game.teacher.hp, 1);
        game.player
          ..x = max(6, game.teacher.x - 10)
          ..facing = 1;
        game.pressAttack();
      }
      _frames(game, 1, render: i % 9 == 0);
    }
    expect(game.phase, Phase.cleared);
    for (var i = 0; i < 400 && game.phase == Phase.cleared; i++) {
      _frames(game, 1);
    }
    expect(game.perks, contains(kLostNotes[2]), reason: 'the Librarian\'s Lost Note flew to Ozod');
    expect(game.phase, Phase.story);
    expect(game.story, kLibraryBook);
    game.endStory();
    expect(game.phase, Phase.cleared);
    _walkToExit(game);
    expect(game.room.label, '4-1');
  });

  testWidgets('the landscape starts grey and gets a sixth more colour with every boss', (tester) async {
    final game = await _loadGame(tester);
    _goToRoom(game, 0);
    expect(game.sceneName, 'meadow', reason: 'the first hall is open to the landscape');
    expect(game.worldColor, 0, reason: 'at 3:00 AM the world is grey');
    final firstBoss = _bossRooms.first;
    _goToRoom(game, firstBoss);
    expect(game.worldColor, 0);
    _clearRoom(game);
    _frames(game, 60 * 12); // the colour flows back in
    expect(game.worldColor, closeTo(1 / kFloors.length, 0.001));
    _goToRoom(game, firstBoss + 1);
    expect(game.worldColor, closeTo(1 / kFloors.length, 0.001), reason: 'it stays for the next floor');
    _goToRoom(game, _reaperRoom);
    expect(game.worldColor, closeTo(5 / kFloors.length, 0.001));
    game.debugEscape();
    _frames(game, 60 * 4);
    expect(game.worldColor, 1, reason: 'awake: full colour');
    for (final b in kBuildings) {
      expect(kRooms.any((r) => r.building == b.letter && r.scene != null) || b.letter == '6', isTrue,
          reason: 'floor ${b.letter} has an open-air hall');
    }
  });

  testWidgets('the nightmare clock: one floor per hour, 9:00 AM is the exam', (tester) async {
    for (final b in kBuildings) {
      final first = kRooms.firstWhere((r) => r.building == b.letter);
      expect(first.minutes, b.hour * 60, reason: 'floor ${b.letter} starts at ${b.time}');
    }
    expect(kBuildings.map((b) => b.hour), [3, 4, 5, 6, 7, 8]);
    expect(clockText(kRooms.first.minutes), '3:00 AM');
    expect(timeLeftText(kRooms.first.minutes), '6h left');
    expect(clockText(kRooms[1].minutes), '3:30 AM');
    expect(timeLeftText(8 * 60 + 59), '1m left');
    expect(kLostNotes.toSet().length, kLostNotes.length, reason: 'six different notes');
  });

  testWidgets("Ozod's Blade of Hope hits on the way out and back", (tester) async {
    final game = await _loadGame(tester);
    game.bestFloor = kRooms.length;
    game.selectHero(kOzod);
    _goToRoom(game, _bossRooms.first);
    game.beginFight();
    game.teacher
      ..cooldown = 999
      ..x = 70;
    game.player
      ..x = 30
      ..facing = 1
      ..energy = 100;
    final hp = game.teacher.hp;
    var hits = 0;
    var last = hp;
    game.pressSpecial();
    for (var i = 0; i < 160; i++) {
      game.player.hp = game.player.maxHp;
      game.teacher.x = 70; // hold still
      game.update(1 / 60);
      if (game.teacher.hp < last) hits++;
      last = game.teacher.hp;
    }
    expect(hits, 2);
  });

  testWidgets('every room has a vibe; Mira and the dreamers hide in fights and cheer after', (tester) async {
    final game = await _loadGame(tester);
    game.selectHero(0); // play the Knight, so the dreamer who shares Ozod's body shows up
    final seen = <String>{};
    for (var r = 0; r < kRooms.length; r++) {
      expect(kVibes.containsKey(kRooms[r].label), isTrue, reason: 'room ${kRooms[r].label} needs a vibe');
      _goToRoom(game, r);
      for (final n in game.npcs) {
        seen.add(n.def.body);
      }
      _frames(game, 30, render: true); // particles + props must draw without errors
    }
    expect(seen, containsAll(['Senior', 'Hero', 'Samurai', 'Goblin', 'Enchantress', 'Swordsman', 'SilverKnight']));

    // 1-1: Mira greets you, hides during the fight, then speaks again.
    _goToRoom(game, 0);
    expect(game.npcs.single.def.name, 'Mira');
    _frames(game, 60);
    expect(game.npcs.single.text, contains('chance'));
    game.beginFight();
    _frames(game, 40);
    expect(game.npcs.single.alpha, lessThan(0.1), reason: 'NPCs hide while monsters attack');
    for (var i = 0; i < 400 && game.phase != Phase.cleared; i++) {
      game.player.hp = game.player.maxHp;
      if (i % 20 == 0) game.debugKillMinions();
      _frames(game, 1);
    }
    _frames(game, 120);
    expect(game.npcs.single.alpha, greaterThan(0.9));
    expect(game.npcs.single.text, contains('Hall Monitor'));

    // Mira is a ghost: she appears even when you play a character with her body.
    game.bestFloor = kRooms.length;
    game.selectHero(kHeroes.indexWhere((h) => h.body == 'Enchantress'));
    _goToRoom(game, 0);
    expect(game.npcs.map((n) => n.def.name), contains('Mira'));
  });

  testWidgets('Fly Agaric: dodge its lunge and it gets stuck, taking double damage', (tester) async {
    final game = await _loadGame(tester);
    final lab = kRooms.indexWhere((r) => r.waves.any((w) => w.contains(MinionKind.flyAgaric)));
    _goToRoom(game, lab);
    game.beginFight();
    game.debugKillMinions();
    _frames(game, 5);
    game.player
      ..x = 60
      ..facing = -1;
    final shroom = game.debugSpawnMinion(MinionKind.flyAgaric, 80)..cd = 0;
    // Wait for the lunge to start, then roll through it.
    for (var i = 0; i < 200 && shroom.state != MState.attack; i++) {
      game.player.hp = game.player.maxHp;
      _frames(game, 1);
    }
    expect(shroom.state, MState.attack);
    game.pressRoll();
    for (var i = 0; i < 60 && shroom.state != MState.stunned; i++) {
      _frames(game, 1);
    }
    expect(shroom.state, MState.stunned, reason: 'a missed lunge leaves it stuck');
    expect(game.player.hp, game.player.maxHp);

    final before = shroom.hp;
    game.player
      ..x = shroom.x + 12
      ..facing = -1;
    game.pressAttack();
    _frames(game, 40); // the attack is buffered until the roll ends
    expect(before - shroom.hp, greaterThanOrEqualTo(kHeroes[game.heroIndex].swings.first.dmg * 2 - 0.01),
        reason: 'stuck mushrooms take double damage');
  });
}
