// lib/game/vibes.dart
// The look and feel of every room: ambient particles, decorations, lighting
// and the people (NPCs) trapped in the dream: Mira, and students who never
// woke up. They talk when you arrive, hide during the fight and cheer after.

import 'package:flutter/material.dart' show Color;

enum Particle { none, dust, chalk, code, steam, spores, data, fireflies, leaves, paper, sparkles, letters, embers, rain }

enum Prop {
  sunbeams,
  lockers,
  desks,
  posters,
  monitors,
  servers,
  tables,
  bookshelves,
  vines,
  plants,
  hologrid,
  spotlights,
  curtains,
  ticker,
  chandeliers,
  pillars,
  banners,
  portraits,
  alarm,
}

class NpcDef {
  final String name;
  final String body; // sprite set (only its Idle animation is used)
  final double hue;
  final double x; // fraction of the room width
  final String hello; // said when you arrive
  final String cheer; // said after the room is cleared
  final bool ghost; // pale and see-through (Mira); shown even if you play the same body
  const NpcDef(this.name, this.body, this.x, this.hello, this.cheer, {this.hue = 0, this.ghost = false});
}

class RoomVibe {
  final Particle particle;
  final Color particleColor;
  final List<Prop> props;
  final Color? tint; // mood light over the whole room
  final double tintAlpha;
  final List<NpcDef> npcs;

  const RoomVibe({
    this.particle = Particle.dust,
    this.particleColor = const Color(0xFFFFFFFF),
    this.props = const [],
    this.tint,
    this.tintAlpha = 0.06,
    this.npcs = const [],
  });
}

/// Mira: a pale, glowing girl in an old uniform. She fell asleep before her
/// exam ten years ago and never woke up.
NpcDef _mira(double x, String hello, String cheer) => NpcDef('Mira', 'Enchantress', x, hello, cheer, hue: 160, ghost: true);

/// Keyed by room label (1-1 … 6-1).
final Map<String, RoomVibe> kVibes = {
  // ── Floor 1 · The Hallway of Homework ──────────────────────────────────
  '1-1': RoomVibe(
    particle: Particle.paper,
    props: [Prop.lockers, Prop.alarm],
    tint: const Color(0xFFFF1744),
    tintAlpha: 0.05,
    npcs: [
      _mira(0.30, 'You still have a chance. I didn\'t. Don\'t waste it.', 'Good. Now the Hall Monitor… he hates the late.'),
    ],
  ),
  '1-2': const RoomVibe(
    particle: Particle.paper,
    props: [Prop.lockers, Prop.posters],
    tint: Color(0xFFFF5722),
    tintAlpha: 0.05,
    npcs: [
      NpcDef('Late student', 'Swordsman', 0.24, 'He gave me detention… forty years ago.', 'You… you got past him?!',
          hue: 30),
    ],
  ),

  // ── Floor 2 · The Math Tower ───────────────────────────────────────────
  '2-1': const RoomVibe(
    particle: Particle.chalk,
    props: [Prop.posters],
    tint: Color(0xFF80DEEA),
    tintAlpha: 0.04,
    npcs: [
      NpcDef('Lost freshman', 'Goblin', 0.22, 'The stairs moved again! Which way is UP?', 'Up! It was up!'),
    ],
  ),
  '2-2': const RoomVibe(
    particle: Particle.chalk,
    props: [Prop.desks, Prop.posters],
    npcs: [
      NpcDef('Chalk-dusted student', 'Knight', 0.24, 'I\'ve been showing my work for six years…',
          'He said "correct"! He NEVER says correct!', hue: 200),
    ],
  ),
  '2-3': RoomVibe(
    particle: Particle.fireflies,
    particleColor: const Color(0xFFB2EBF2),
    props: [Prop.tables],
    tint: const Color(0xFF80DEEA),
    tintAlpha: 0.06,
    npcs: [
      _mira(0.30, 'The library is next. Whatever you hear… stay quiet.', 'Go. I\'ll find you upstairs.'),
    ],
  ),

  // ── Floor 3 · The Silent Library ───────────────────────────────────────
  '3-1': RoomVibe(
    particle: Particle.letters,
    particleColor: const Color(0xFFB388FF),
    props: [Prop.bookshelves],
    tint: const Color(0xFF311B92),
    tintAlpha: 0.08,
    npcs: [
      _mira(0.26, '(whispering) …shh. The books are sleeping.', '(whispering) …the Librarian is just ahead.'),
    ],
  ),
  '3-2': const RoomVibe(
    particle: Particle.dust,
    props: [Prop.bookshelves, Prop.portraits],
    tint: Color(0xFF4527A0),
    tintAlpha: 0.08,
  ),

  // ── Floor 4 · The Science Lab ──────────────────────────────────────────
  '4-1': const RoomVibe(
    particle: Particle.spores,
    particleColor: Color(0xFF76FF03),
    props: [Prop.plants, Prop.vines],
    tint: Color(0xFF64DD17),
    tintAlpha: 0.07,
    npcs: [
      NpcDef('Lab partner', 'Samurai', 0.24, 'Don\'t touch the jars. I touched the jars.', '…I can feel my hands again.',
          hue: 90),
    ],
  ),
  '4-2': const RoomVibe(
    particle: Particle.data,
    particleColor: Color(0xFFFFEA00),
    props: [Prop.servers, Prop.monitors],
    tint: Color(0xFFFFEA00),
    tintAlpha: 0.04,
    npcs: [
      NpcDef('Sleepless student', 'Hero', 0.22, 'Day 900 without sleep! I feel GREAT! …help.', 'Finally… I can… sleep…'),
    ],
  ),
  '4-3': RoomVibe(
    particle: Particle.fireflies,
    particleColor: const Color(0xFFB2EBF2),
    props: [Prop.tables, Prop.sunbeams],
    tint: const Color(0xFFFFAB40),
    tintAlpha: 0.07,
    npcs: [
      _mira(0.30, 'Look… the sky outside is getting lighter.', 'Two more floors. Then him.'),
    ],
  ),

  // ── Floor 5 · The Office of Deadlines ──────────────────────────────────
  '5-1': const RoomVibe(
    particle: Particle.paper,
    props: [Prop.ticker, Prop.desks],
    tint: Color(0xFFFFB300),
    tintAlpha: 0.05,
    npcs: [
      NpcDef('Intern', 'Knight', 0.22, 'I\'ll start my essay tomorrow. I\'ve said that for ten years.', 'Today. I\'ll do it TODAY.',
          hue: 45),
    ],
  ),
  '5-2': const RoomVibe(
    particle: Particle.dust,
    props: [Prop.ticker, Prop.portraits, Prop.alarm],
    tint: Color(0xFFD50000),
    tintAlpha: 0.04,
  ),
  '5-3': RoomVibe(
    particle: Particle.embers,
    particleColor: const Color(0xFFB2EBF2),
    props: [Prop.pillars],
    tint: const Color(0xFFB71C1C),
    tintAlpha: 0.06,
    npcs: [
      _mira(0.30, 'This is as far as I go.', 'Wake up, Ozod. For both of us.'),
    ],
  ),

  // ── Floor 6 · The Exam Hall ────────────────────────────────────────────
  '6-1': const RoomVibe(
    particle: Particle.embers,
    particleColor: Color(0xFFFF1744),
    props: [Prop.desks, Prop.banners],
    npcs: [
      NpcDef('Sleeping student', 'Senior', 0.20, 'Zzz… just five more minutes…', '…mm? Is it… morning?'),
      NpcDef('Sleeping student', 'SilverKnight', 0.40, 'Zzz… I\'ll pass… I\'ll definitely pass…', '…where am I?'),
    ],
  ),
};

/// After the Grade Reaper falls the student walks out into the morning light.
const RoomVibe kEscapeVibe = RoomVibe(
  particle: Particle.sparkles,
  particleColor: Color(0xFFFFE0B2),
  tint: Color(0xFFFFE0B2),
  tintAlpha: 0.08,
);
