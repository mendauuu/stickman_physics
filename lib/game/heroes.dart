// lib/game/heroes.dart
// Playable dreamers. Ozod is the hero of the story; more forms unlock as he
// climbs higher through the Nightmare University.

import 'package:flutter/material.dart' show Color;

enum HeroAttack { melee, magic }

enum HeroSpecial { wave, dash, nova, combo, iaido, frenzy, blade }

class Swing {
  final String anim;
  final double hitTime;
  final int dmg;
  final double knock;
  const Swing(this.anim, this.hitTime, this.dmg, this.knock);
}

class HeroDef {
  final String name;
  final String title;
  final String emoji;
  final String body; // sprite folder
  final double hue;
  final int hp;
  final double speed;
  final List<Swing> swings; // played in order as a combo
  final HeroAttack attack;
  final HeroSpecial special;
  final String specialName;
  final String desc;
  final Color color;

  /// Attack animations play this much faster than normal.
  final double attackSpeed;

  /// Sword reach in front of the student (world units).
  final double reach;

  /// Floor index the student must have reached to unlock this character.
  final int unlockFloor;

  const HeroDef({
    required this.name,
    required this.title,
    required this.emoji,
    required this.body,
    this.hue = 0,
    required this.hp,
    required this.speed,
    required this.swings,
    this.attack = HeroAttack.melee,
    required this.special,
    required this.specialName,
    required this.desc,
    required this.color,
    this.attackSpeed = 1,
    this.reach = 25,
    this.unlockFloor = 0,
  });
}

const List<HeroDef> kHeroes = [
  HeroDef(
    name: 'Knight',
    title: 'Balanced fighter',
    emoji: '🛡️',
    body: 'Knight',
    hp: 100,
    speed: 62,
    swings: [
      Swing('Attack_1', 0.19, 7, 10),
      Swing('Attack_2', 0.10, 7, 10),
      Swing('Attack_3', 0.17, 13, 45),
    ],
    special: HeroSpecial.wave,
    specialName: 'A+ Wave',
    desc: 'Balanced 3-hit sword combo. Power: a golden A+ wave.',
    color: Color(0xFFFFD54F),
  ),
  HeroDef(
    name: 'Swordsman',
    title: 'Fast & sharp',
    emoji: '⚡',
    body: 'Swordsman',
    hp: 85,
    speed: 76,
    swings: [
      Swing('Attack_1', 0.19, 6, 8),
      Swing('Attack_2', 0.15, 6, 8),
      Swing('Attack_3', 0.25, 11, 40),
    ],
    special: HeroSpecial.dash,
    specialName: 'Lightning Dash',
    desc: 'Fastest student. Power: dash straight through the teacher.',
    color: Color(0xFF40C4FF),
    unlockFloor: 2,
  ),
  HeroDef(
    name: 'Mage',
    title: 'Ranged magic',
    emoji: '✨',
    body: 'Enchantress',
    hue: 150,
    hp: 80,
    speed: 64,
    swings: [Swing('Attack_1', 0.2, 9, 6)],
    attackSpeed: 1.45,
    attack: HeroAttack.magic,
    special: HeroSpecial.nova,
    specialName: 'Knowledge Nova',
    desc: 'Shoots magic bolts from far away. Power: triple nova + heal.',
    color: Color(0xFF64FFDA),
    unlockFloor: 3,
  ),
  HeroDef(
    name: 'Dark Knight',
    title: 'Heavy armour',
    emoji: '🗡️',
    body: 'DarkKnight',
    hp: 125,
    speed: 56,
    swings: [
      Swing('Attack_1', 0.09, 8, 10),
      Swing('Attack_2', 0.15, 9, 10),
      Swing('Attack_3', 0.22, 14, 45),
    ],
    special: HeroSpecial.combo,
    specialName: 'Shadow Combo',
    desc: 'Slow but tough, hits hard. Power: a 6-hit shadow combo.',
    color: Color(0xFFB388FF),
    unlockFloor: 5,
  ),
  HeroDef(
    name: 'Samurai',
    title: 'Long blade',
    emoji: '⛩️',
    body: 'Samurai',
    hp: 90,
    speed: 70,
    swings: [
      Swing('Attack_1', 0.22, 10, 12),
      Swing('Attack_2', 0.22, 13, 40),
    ],
    reach: 32,
    special: HeroSpecial.iaido,
    specialName: 'Iaido Strike',
    desc: 'Longest sword reach. Power: teleport behind the boss and slash.',
    color: Color(0xFFFF5252),
    unlockFloor: 4,
  ),
  HeroDef(
    name: 'Goblin',
    title: 'Secret character',
    emoji: '👺',
    body: 'Goblin',
    hp: 85,
    speed: 82,
    swings: [Swing('Attack_1', 0.38, 9, 10)],
    attackSpeed: 1.6,
    reach: 22,
    special: HeroSpecial.frenzy,
    specialName: 'Goblin Frenzy',
    desc: 'Wake up to unlock! Super fast. Power: frenzy — faster + heals on hit.',
    color: Color(0xFF8BC34A),
    unlockFloor: 6, // after waking up (every boss, including the Grade Reaper)
  ),
  HeroDef(
    name: 'Ozod',
    title: 'First-year student',
    emoji: '🦸',
    body: 'Hero',
    hp: 105,
    speed: 72,
    swings: [
      Swing('Attack_1', 0.12, 9, 10),
      Swing('Attack_2', 0.10, 12, 40),
    ],
    reach: 30,
    special: HeroSpecial.blade,
    specialName: 'Blade of Hope',
    desc: 'The hero of the story. Power: a Blade of Hope that comes back. (Art: Ozzbit Games)',
    color: Color(0xFF18FFFF),
  ),
];

/// The story's hero, picked for new players.
final int kOzod = kHeroes.indexWhere((h) => h.name == 'Ozod');
