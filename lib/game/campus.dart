// lib/game/campus.dart
// The Nightmare University: six floors, one hour each (3:00 → 8:00 AM).
// Every floor is a chain of rooms: monster halls, a guardian boss, and quiet
// corners where Mira waits. At 9:00 AM the Final Exam begins.

import 'dart:math' show min;

import 'package:flutter/material.dart' show Color;

import 'minions.dart';
import 'story.dart';
import 'teachers.dart';

enum RoomKind { hall, boss, rest }

/// One floor of the nightmare (kept as "building" so rooms can be grouped).
class BuildingDef {
  final String letter; // floor number: '1' … '6'
  final String name;
  final String emoji;
  final Color color;
  final String view; // landscape seen through its windows (see kScenes)
  final int hour; // the clock when Ozod arrives (AM)
  const BuildingDef(this.letter, this.name, this.emoji, this.color, this.view, this.hour);

  String get title => 'Floor $letter';
  String get time => '$hour:00 AM';
}

/// Climbing order: one floor per hour.
/// Every floor looks out on its own landscape (see kScenes). The monster
/// hall of each floor is open to it; the classrooms show it through windows.
const List<BuildingDef> kBuildings = [
  BuildingDef('1', 'The Hallway of Homework', '🎒', Color(0xFFFF7043), 'meadow', 3),
  BuildingDef('2', 'The Math Tower', '📐', Color(0xFF80DEEA), 'mountains', 4),
  BuildingDef('3', 'The Silent Library', '📚', Color(0xFFB388FF), 'forest', 5),
  BuildingDef('4', 'The Science Lab', '🧪', Color(0xFFFFEA00), 'cliffs', 6),
  BuildingDef('5', 'The Office of Deadlines', '⏳', Color(0xFFFFB300), 'clouds', 7),
  BuildingDef('6', 'The Exam Hall', '💀', Color(0xFFFF1744), 'gardens', 8),
];

class RoomDef {
  final String building; // floor number '1' … '6'
  final int number; // 1-based position inside the floor
  final String name;
  final RoomKind kind;
  final int teacher; // index into kFloors for boss rooms, otherwise -1
  final TeacherDef? theme; // look of hall / rest rooms
  final List<List<MinionKind>> waves; // hall rooms only
  final String? scene; // outdoor landscape (see kScenes); null = indoors

  /// Told when the student walks in (once per run).
  final List<StoryLine> story;

  /// Told after the room is cleared.
  final List<StoryLine> after;

  /// Mira hands over her Lost Note here.
  final bool gift;

  const RoomDef({
    required this.building,
    required this.number,
    required this.name,
    required this.kind,
    this.teacher = -1,
    this.theme,
    this.waves = const [],
    this.scene,
    this.story = const [],
    this.after = const [],
    this.gift = false,
  });

  bool get outdoors => scene != null && kind == RoomKind.hall;

  TeacherDef get def => kind == RoomKind.boss ? kFloors[teacher] : theme!;
  bool get isBoss => kind == RoomKind.boss;
  String get label => '$building-$number';
  BuildingDef get buildingDef => kBuildings.firstWhere((b) => b.letter == building);
  String get emoji => switch (kind) {
        RoomKind.hall => outdoors ? '🌳' : '👾',
        RoomKind.rest => def.emoji,
        RoomKind.boss => def.emoji,
      };
  String get subtitle => switch (kind) {
        RoomKind.hall => '${waves.length} monster waves',
        RoomKind.rest => 'Mira · heal${gift ? ' + her Lost Note' : ''}',
        RoomKind.boss => def.name,
      };

  /// The nightmare clock when the student walks in here, in minutes after
  /// midnight. Rooms share their floor's hour evenly.
  int get minutes {
    final rooms = [for (final r in kRooms) if (r.building == building) r];
    return buildingDef.hour * 60 + (60 * (number - 1) / rooms.length).floor();
  }
}

/// "3:20 AM" for [minutes] after midnight.
String clockText(int minutes) => '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')} AM';

/// "5h 40m left" until the Final Exam at 9:00 AM.
String timeLeftText(int minutes) {
  final left = 9 * 60 - minutes;
  if (left <= 0) return 'TIME\'S UP';
  final h = left ~/ 60, m = left % 60;
  return h == 0 ? '${m}m left' : (m == 0 ? '${h}h left' : '${h}h ${m}m left');
}

/// Look of a non-boss room. Hall/rest rooms reuse [TeacherDef] for their
/// colours, blackboard text, shelves and the monsters that appear there.
TeacherDef _theme({
  required String name,
  required String emoji,
  required Color wall,
  required Color wallDark,
  required Color accent,
  required List<String> board,
  List<PlatformDef> platforms = const [PlatformDef(0.16, 28, 0.18), PlatformDef(0.62, 28, 0.18)],
  List<MinionKind> minions = const [MinionKind.goblin],
  String intro = '',
  bool dark = false,
}) =>
    TeacherDef(
      floorLabel: '',
      floorName: name.toUpperCase(),
      name: name,
      subject: name.toUpperCase(),
      course: name,
      emoji: emoji,
      hue: 0,
      hp: 1,
      speed: 0,
      cooldown: 99,
      abilities: const [],
      intro: intro,
      finalLine: '',
      rage: '',
      defeat: '',
      taunts: const [''],
      wall: wall,
      wallDark: wallDark,
      accent: accent,
      board: board,
      platforms: platforms,
      minions: minions,
      dark: dark,
    );

const _shelves3 = [PlatformDef(0.10, 28, 0.16), PlatformDef(0.42, 46, 0.16), PlatformDef(0.72, 28, 0.16)];

/// Bumped when rooms change, so saved progress can be mapped onto the new list.
/// v1/v2: the Millat Umidi campus (buildings B → C → A). v3: the Nightmare University.
const int kRoomsVersion = 3;

/// Room kinds (Hall, Boss, Rest) of the campus before the story update.
const _legacyRooms = {1: 'HBHBRHBRHBHBRHBB', 2: 'HBHBRHHBRHBHHBRHBB'};
const _legacyTeachers = 7;

/// Converts a room index saved by an older campus version into today's
/// index: the student keeps the number of bosses they had beaten.
int migrateRoomIndex(int saved, int fromVersion) {
  final old = _legacyRooms[fromVersion];
  if (old == null) return saved.clamp(0, kRooms.length);
  if (saved >= old.length) return kRooms.length; // had graduated
  return roomAfterBosses('B'.allMatches(old.substring(0, saved.clamp(0, old.length))).length);
}

/// Same, for the oldest saves that counted teachers beaten.
int migrateTeacherFloor(int oldFloor) =>
    oldFloor >= _legacyTeachers ? kRooms.length : roomAfterBosses(oldFloor);

/// First room after the [n]th boss (never past the last boss's door).
int roomAfterBosses(int n) {
  final lastBoss = kRooms.lastIndexWhere((r) => r.isBoss);
  if (n <= 0) return 0;
  var seen = 0;
  for (var i = 0; i < kRooms.length; i++) {
    if (kRooms[i].isBoss && ++seen == n) return min(i + 1, lastBoss);
  }
  return lastBoss;
}

final List<RoomDef> kRooms = [
  // ── Floor 1 · 3:00 AM · The Hallway of Homework ────────────────────────
  RoomDef(
    building: '1',
    number: 1,
    name: 'The Red Hallway',
    kind: RoomKind.hall,
    scene: 'meadow',
    story: kMeetMira,
    theme: _theme(
      name: 'The Red Hallway',
      emoji: '🎒',
      wall: const Color(0xFF3A2222),
      wallDark: const Color(0xFF1A0E0E),
      accent: const Color(0xFFFF7043),
      board: const ['6 HOURS LEFT', 'Homework: OVERDUE', '⏰ 3:00 ⏰ 3:00 ⏰'],
      minions: const [MinionKind.goblin, MinionKind.eye],
      intro: 'Unfinished homework has come alive!\nPapers fly like bats, and backpacks bite.',
    ),
    waves: const [
      [MinionKind.goblin, MinionKind.goblin],
      [MinionKind.goblin, MinionKind.eye, MinionKind.eye],
    ],
  ),
  const RoomDef(building: '1', number: 2, name: 'Detention Hall', kind: RoomKind.boss, teacher: 0),

  // ── Floor 2 · 4:00 AM · The Math Tower ─────────────────────────────────
  RoomDef(
    building: '2',
    number: 1,
    name: 'The Shifting Stairs',
    kind: RoomKind.hall,
    scene: 'mountains',
    theme: _theme(
      name: 'The Shifting Stairs',
      emoji: '🪜',
      wall: const Color(0xFF243040),
      wallDark: const Color(0xFF0F1520),
      accent: const Color(0xFF80DEEA),
      board: const ['x + 1 = stairs', 'one wrong step…', '…and the floor is gone'],
      platforms: const [PlatformDef(0.06, 20, 0.14), PlatformDef(0.30, 34, 0.14), PlatformDef(0.54, 48, 0.14), PlatformDef(0.78, 30, 0.14)],
      minions: const [MinionKind.skeleton, MinionKind.goblin, MinionKind.eye],
      intro: 'The stairs rearrange like equations.\nOne wrong step and the floor disappears.',
    ),
    waves: const [
      [MinionKind.skeleton, MinionKind.goblin],
      [MinionKind.eye, MinionKind.skeleton, MinionKind.goblin],
    ],
  ),
  const RoomDef(building: '2', number: 2, name: 'The Tower Classroom', kind: RoomKind.boss, teacher: 1),
  RoomDef(
    building: '2',
    number: 3,
    name: "Mira's Hideout",
    kind: RoomKind.rest,
    theme: _theme(
      name: "Mira's Hideout",
      emoji: '🕯️',
      wall: const Color(0xFF2A2F3A),
      wallDark: const Color(0xFF14171E),
      accent: const Color(0xFFB2EBF2),
      board: const ['a quiet corner', 'the clocks are softer here', '🕯️'],
      intro: 'Sit for a moment. The clocks can\'t hear us in here.\nYou\'re doing better than I did.',
    ),
  ),

  // ── Floor 3 · 5:00 AM · The Silent Library ─────────────────────────────
  RoomDef(
    building: '3',
    number: 1,
    name: 'The Dark Stacks',
    kind: RoomKind.hall,
    scene: 'forest',
    theme: _theme(
      name: 'The Dark Stacks',
      emoji: '📚',
      wall: const Color(0xFF1E1828),
      wallDark: const Color(0xFF0B0812),
      accent: const Color(0xFFB388FF),
      board: const ['SILENCE', 'every sound…', '…wakes the books'],
      platforms: _shelves3,
      minions: const [MinionKind.eye, MinionKind.skeleton],
      dark: true,
      intro: 'Total darkness. Every sound you make wakes the books.\nStay close to the light.',
    ),
    waves: const [
      [MinionKind.eye, MinionKind.eye],
      [MinionKind.eye, MinionKind.skeleton, MinionKind.eye],
    ],
  ),
  const RoomDef(
      building: '3', number: 2, name: 'The Reading Room', kind: RoomKind.boss, teacher: 2, after: kLibraryBook),

  // ── Floor 4 · 6:00 AM · The Science Lab ────────────────────────────────
  RoomDef(
    building: '4',
    number: 1,
    name: 'Failed Experiments',
    kind: RoomKind.hall,
    scene: 'cliffs',
    theme: _theme(
      name: 'Failed Experiments',
      emoji: '🧪',
      wall: const Color(0xFF1C2A22),
      wallDark: const Color(0xFF0A140E),
      accent: const Color(0xFF76FF03),
      board: const ['EXPERIMENT #404', 'DO NOT OPEN THE JARS', '☣ ☣ ☣'],
      minions: const [MinionKind.flyAgaric, MinionKind.mushroom, MinionKind.eye],
      intro: 'Explosions. Acid floors.\nFailed experiments crawl out of their jars!',
    ),
    waves: const [
      [MinionKind.flyAgaric, MinionKind.mushroom],
      [MinionKind.flyAgaric, MinionKind.flyAgaric, MinionKind.eye],
    ],
  ),
  const RoomDef(building: '4', number: 2, name: 'The Volt Lab', kind: RoomKind.boss, teacher: 3),
  RoomDef(
    building: '4',
    number: 3,
    name: 'The Supply Closet',
    kind: RoomKind.rest,
    theme: _theme(
      name: 'The Supply Closet',
      emoji: '🕯️',
      wall: const Color(0xFF2A2F3A),
      wallDark: const Color(0xFF14171E),
      accent: const Color(0xFFB2EBF2),
      board: const ['6:40 AM', 'mops · buckets · a candle', '🕯️'],
      intro: 'Look outside. The sky is getting lighter.\nTwo more floors. Then him.',
    ),
  ),

  // ── Floor 5 · 7:00 AM · The Office of Deadlines ────────────────────────
  RoomDef(
    building: '5',
    number: 1,
    name: 'The Ticking Office',
    kind: RoomKind.hall,
    scene: 'clouds',
    theme: _theme(
      name: 'The Ticking Office',
      emoji: '⏰',
      wall: const Color(0xFF2E2A20),
      wallDark: const Color(0xFF15130E),
      accent: const Color(0xFFFFB300),
      board: const ['DUE: 7:00', 'DUE: 7:00', 'DUE: 7:00'],
      platforms: _shelves3,
      minions: const [MinionKind.mushroom, MinionKind.skeleton, MinionKind.eye],
      intro: 'Every clock here runs faster.\nThe walls are closing in, slowly…',
    ),
    waves: const [
      [MinionKind.mushroom, MinionKind.skeleton],
      [MinionKind.mushroom, MinionKind.mushroom, MinionKind.eye, MinionKind.skeleton],
    ],
  ),
  const RoomDef(building: '5', number: 2, name: 'The Deadline Office', kind: RoomKind.boss, teacher: 4),
  RoomDef(
    building: '5',
    number: 3,
    name: 'The Final Staircase',
    kind: RoomKind.rest,
    story: kFinalStairs,
    gift: true,
    theme: _theme(
      name: 'The Final Staircase',
      emoji: '🪜',
      wall: const Color(0xFF2A1C24),
      wallDark: const Color(0xFF120A0F),
      accent: const Color(0xFFB2EBF2),
      board: const ['EXAM HALL ↑', '8:00 AM', 'no turning back'],
      intro: 'If you beat him… maybe we all wake up.',
    ),
  ),

  // ── Floor 6 · 8:00 AM · The Exam Hall ──────────────────────────────────
  const RoomDef(building: '6', number: 1, name: 'The Exam Hall', kind: RoomKind.boss, teacher: 5),
];

// ── Lost Notes: pages of Ozod's notes. Each one restores a memory of what
// he studied and gives him a power for the rest of the run. ───────────────
enum Perk { tea, pencil, energy, sneakers, notes, hoodie }

class PerkDef {
  final String emoji, name, desc;
  const PerkDef(this.emoji, this.name, this.desc);
}

const Map<Perk, PerkDef> kPerks = {
  Perk.sneakers: PerkDef('⏰', 'Time Management', '+15% speed'),
  Perk.pencil: PerkDef('✏️', 'Show Your Work', '+20% damage'),
  Perk.notes: PerkDef('🤫', 'Quiet Focus', 'Start every room with 50 ⚡'),
  Perk.tea: PerkDef('😴', 'Rest Is Power', '+25 max HP'),
  Perk.energy: PerkDef('⚡', 'Do It Now', '+35% ⚡ charge'),
  Perk.hoodie: PerkDef('🛡️', 'Courage', '−20% damage taken'),
};

/// The Lost Note dropped by each floor's boss (by [kFloors] index); the last
/// one is Mira's gift at the final staircase.
const List<Perk> kLostNotes = [Perk.sneakers, Perk.pencil, Perk.notes, Perk.tea, Perk.energy, Perk.hoodie];
