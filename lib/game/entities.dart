// lib/game/entities.dart
// Plain data objects for everything that moves in the arena.
// All positions are in world units (world height = 100).

import 'package:flutter/material.dart' show Color, Rect;

import 'teachers.dart';

enum PState { idle, run, jump, attack, special, roll, hurt, dead }

class Player {
  double x = 16, y = 0, vx = 0, vy = 0;
  bool onGround = true;
  int jumpsLeft = 2;
  int facing = 1;
  double hp = 100, maxHp = 100;
  double energy = 0;
  PState state = PState.idle;
  String anim = 'Idle';
  double t = 0; // time spent in current animation
  int combo = 0;
  bool hitDone = false;
  bool queued = false;
  double invuln = 0;
  double slow = 0; // seconds left of being slowed (vines, lullaby)
  double dashT = 0; // Swordsman special dash time left
  int multi = 0; // Dark Knight combo hits landed so far
  double rollT = 0; // dodge roll time left
  double rollCd = 0;
  bool perfectDodged = false;
  double frenzy = 0; // Goblin special time left
  final dashHits = <Object>{}; // minions already hit by this dash
  bool dashHit = false;

  Rect get rect => Rect.fromLTWH(x - 5, y - 21, 10, 21);
  bool get busy =>
      state == PState.roll ||
      state == PState.attack || state == PState.special || state == PState.hurt || state == PState.dead;
}

enum TState { idle, walk, cast, hurt, dead }

class Teacher {
  final TeacherDef def;
  double x, y, vy = 0;
  int facing = -1;
  double hp;
  double maxHp;
  TState state = TState.idle;
  String anim = 'Idle';
  double t = 0;
  double cooldown = 2.2;
  Ability? casting;
  bool fired = false;
  double fireAt = 0.35;
  double flash = 0;
  bool rage = false;
  String speech = '';
  double speechTime = 0;
  double tauntTimer = 7;
  double pullTime = 0;
  double teleportCd = 0;
  double dash = 0; // charge attack time left
  double dashDir = 0;

  Teacher(this.def, this.x, this.y)
      : hp = def.hp.toDouble(),
        maxHp = def.hp.toDouble();

  double get s => def.scale;
  Rect get rect => Rect.fromLTWH(x - 6 * s, y - 22 * s, 12 * s, 22 * s);
  double get chestY => y - 13 * s;

  void say(String text, [double time = 2.4]) {
    speech = text;
    speechTime = time;
  }
}

enum ProjKind { orb, glyph, letter, apple, potion, bubble, bug, boomerang, wave, ball, arrow, rock }

class Projectile {
  final ProjKind kind;
  double x, y, vx, vy;
  double r;
  final int dmg;
  final bool fromPlayer;
  final bool destructible;
  final String glyph;
  final Color color;
  double gravity;
  double life;
  double t = 0;
  double baseY;
  double phase;
  bool dead = false;
  final hits = <Object>{}; // enemies a piercing wave already hit

  Projectile({
    required this.kind,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.r = 3,
    this.dmg = 10,
    this.fromPlayer = false,
    this.destructible = true,
    this.glyph = '',
    required this.color,
    this.gravity = 0,
    this.life = 6,
    this.phase = 0,
  }) : baseY = y;
}

enum HazardKind { spike, puddle, laser, shockwave, tornado }

class Hazard {
  final HazardKind kind;
  double x, y, w, h;
  double warn; // telegraph time before it hurts
  double active; // time it stays dangerous
  final int dmg;
  final double vx;
  final Color color;
  final String glyph;
  final bool roots; // slows the student on hit
  double t = 0;

  Hazard({
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.warn = 0,
    required this.active,
    required this.dmg,
    this.vx = 0,
    required this.color,
    this.glyph = '?',
    this.roots = false,
  });

  bool get armed => t >= warn;
  bool get done => t >= warn + active;
  Rect get rect => Rect.fromLTWH(x - w / 2, y - h, w, h);
}

enum PickupKind { plov, somsa, coffee }

class Pickup {
  final PickupKind kind;
  double x, y, vy = 0;
  double life = 12;
  double t = 0;
  Pickup(this.kind, this.x, this.y);

  String get emoji => switch (kind) {
        PickupKind.plov => '🍲',
        PickupKind.somsa => '🥟',
        PickupKind.coffee => '☕',
      };
  String get label => switch (kind) {
        PickupKind.plov => 'PLOV +35 HP',
        PickupKind.somsa => 'SOMSA +20 HP',
        PickupKind.coffee => 'COFFEE +50 ⚡',
      };
}

class Spark {
  double x, y, vx, vy, life, size;
  final double maxLife;
  final Color color;
  Spark(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color)
      : maxLife = life;
}

class FloatText {
  final String text;
  double x, y, life;
  final double maxLife, size;
  final Color color;
  FloatText(this.text, this.x, this.y, this.color, {this.life = 0.9, this.size = 5})
      : maxLife = life;
}

class Platform {
  final double x, y, w;
  const Platform(this.x, this.y, this.w);
}
