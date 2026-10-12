// lib/game/minions.dart
// Monster minions that teachers summon during a fight.

import 'package:flutter/material.dart' show Color, Offset, Rect;

enum MinionKind { goblin, mushroom, skeleton, eye, flyAgaric }

class MinionDef {
  final String name;
  final String emoji;
  final String tip;
  final String body; // sprite set
  final double height; // world units
  final double hp;
  final double speed;
  final int dmg;
  final double reach; // attack range in front
  final double hitTime; // seconds into the Attack animation when it hits
  final bool flying;
  final bool shield; // blocks hits from the front
  final bool lunge; // big lunge; if it misses, the minion gets stuck (stunned)
  final bool facesLeft; // sprite sheet drawn facing left
  final Color color;

  const MinionDef({
    required this.name,
    required this.emoji,
    required this.tip,
    required this.body,
    required this.height,
    required this.hp,
    required this.speed,
    required this.dmg,
    required this.reach,
    required this.hitTime,
    this.flying = false,
    this.shield = false,
    this.lunge = false,
    this.facesLeft = false,
    required this.color,
  });
}

const Map<MinionKind, MinionDef> kMinions = {
  MinionKind.goblin: MinionDef(
    name: 'Homework Goblin',
    emoji: '👺',
    tip: 'Fast — slash it quickly',
    body: 'Goblin',
    height: 17,
    hp: 22,
    speed: 52,
    dmg: 8,
    reach: 16,
    hitTime: 0.38,
    color: Color(0xFF8BC34A),
  ),
  MinionKind.mushroom: MinionDef(
    name: 'Deadline Shroom',
    emoji: '🍄',
    tip: 'Leaves poison on the floor',
    body: 'Mushroom',
    height: 16,
    hp: 34,
    speed: 22,
    dmg: 9,
    reach: 15,
    hitTime: 0.45,
    color: Color(0xFFE57373),
  ),
  MinionKind.skeleton: MinionDef(
    name: 'Exam Skeleton',
    emoji: '💀',
    tip: 'Shield! Jump over and hit its back',
    body: 'Skeleton',
    height: 22,
    hp: 40,
    speed: 26,
    dmg: 11,
    reach: 19,
    hitTime: 0.45,
    shield: true,
    color: Color(0xFFBDBDBD),
  ),
  MinionKind.eye: MinionDef(
    name: 'Proctor Eye',
    emoji: '👁️',
    tip: 'Flies and dive-bombs you',
    body: 'FlyingEye',
    height: 12,
    hp: 16,
    speed: 45,
    dmg: 8,
    reach: 10,
    hitTime: 0,
    flying: true,
    color: Color(0xFFFF8A65),
  ),
  MinionKind.flyAgaric: MinionDef(
    name: 'Fly Agaric',
    emoji: '🍄',
    tip: 'LUNGES far — dodge it and it gets STUCK (double damage)',
    body: 'FlyAgaric',
    height: 19,
    hp: 46,
    speed: 30,
    dmg: 12,
    reach: 26,
    hitTime: 0.3,
    lunge: true,
    facesLeft: true,
    color: Color(0xFFFF5252),
  ),
};

enum MState { move, attack, hurt, shield, stunned, dead }

class Minion {
  final MinionKind kind;
  MinionDef get def => kMinions[kind]!;
  double x, y, vx = 0, vy = 0;
  int facing = -1;
  double hp;
  MState state = MState.move;
  String anim = 'Idle';
  double t = 0;
  double cd = 1.0; // attack cooldown
  bool hitDone = false;
  double flash = 0;
  double phase; // hover wobble for flyers
  double dive = 0; // flying-eye dive time left
  double turnT = 0; // how long the student has been behind it
  bool remove = false;

  Minion(this.kind, this.x, this.y, this.phase) : hp = kMinions[kind]!.hp;

  Rect get rect {
    final h = def.height * 0.85, w = def.height * 0.5;
    return def.flying
        ? Rect.fromCenter(center: Offset(x, y - def.height / 2), width: w * 1.4, height: h * 0.8)
        : Rect.fromLTWH(x - w / 2, y - h, w, h);
  }
}
