// lib/game/teachers.dart
// Floor + boss definitions. Each floor of the Nightmare University has one
// guardian built from a student's fear; its powers come from that fear.

import 'package:flutter/material.dart' show Color;

import 'minions.dart';

enum Ability {
  energyBall,
  appleRain,
  gravityPull,
  numberSpread,
  infinity,
  popQuiz,
  potionLob,
  bubbles,
  letterWave,
  grammarShout,
  bugSwarm,
  syntaxLaser,
  // Biology
  beeSwarm,
  vineTrap,
  // PE / melee teachers
  slash,
  charge,
  dodgeball,
  // History
  arrowVolley,
  catapult,
  // Geography
  earthquake,
  tornado,
  // Music
  noteWave,
  bassDrop,
  lullaby,
  // Economics
  coinRain,
  marketCrash,
  tax,
  // Human & AI
  aiDrones,
  binaryWave,
  scanLaser,
  // Business communication
  emailSpam,
  // Everyone
  summon,
  // The Grade Reaper (villain)
  shadowDash,
  spinSlash,
  bloodRain,
  shadowTeleport,
  lightsOut,
  redPen,
}

const Map<Ability, String> kAbilityName = {
  Ability.energyBall: 'Force Ball',
  Ability.appleRain: "Newton's Apples",
  Ability.gravityPull: 'Gravity Well',
  Ability.numberSpread: 'Number Storm',
  Ability.infinity: 'Infinity Boomerang',
  Ability.popQuiz: 'Pop Quiz Spikes',
  Ability.potionLob: 'Acid Potions',
  Ability.bubbles: 'Toxic Bubbles',
  Ability.letterWave: 'Alphabet Wave',
  Ability.grammarShout: '"SILENCE!" Shockwave',
  Ability.bugSwarm: 'Bug Swarm',
  Ability.syntaxLaser: 'Syntax Error Laser',
  Ability.beeSwarm: 'Bee Swarm',
  Ability.vineTrap: 'Root Vines',
  Ability.slash: 'Close Slash',
  Ability.charge: 'Charge!',
  Ability.dodgeball: 'Dodgeball',
  Ability.arrowVolley: 'Arrow Volley',
  Ability.catapult: 'Catapult',
  Ability.earthquake: 'Earthquake',
  Ability.tornado: 'Tornado',
  Ability.noteWave: 'Melody Wave',
  Ability.bassDrop: 'Bass Drop',
  Ability.lullaby: 'Lullaby',
  Ability.coinRain: 'Coin Rain',
  Ability.marketCrash: 'Market Crash',
  Ability.tax: 'Deadline Tax',
  Ability.aiDrones: 'AI Drones',
  Ability.binaryWave: 'Binary Stream',
  Ability.scanLaser: 'Face-Scan Laser',
  Ability.emailSpam: 'Email Spam',
  Ability.summon: 'Summon Minions',
  Ability.shadowDash: 'Shadow Dash',
  Ability.spinSlash: 'Spin Slash',
  Ability.bloodRain: 'Blood Rain',
  Ability.shadowTeleport: 'Shadow Teleport',
  Ability.lightsOut: 'Lights Out',
  Ability.redPen: 'Red Pen "F"',
};

const Map<Ability, String> kAbilityTip = {
  Ability.energyBall: 'Slash it or jump over it',
  Ability.appleRain: 'Watch the shadows on the floor',
  Ability.gravityPull: 'Run away from the pull!',
  Ability.numberSpread: 'Your sword can cut numbers',
  Ability.infinity: 'It comes back. Always.',
  Ability.popQuiz: 'Move off the "?" marks',
  Ability.potionLob: "Don't stand in green acid",
  Ability.bubbles: 'Pop them with your sword',
  Ability.letterWave: 'Cut through the letters',
  Ability.grammarShout: 'JUMP over the shockwave',
  Ability.bugSwarm: 'Bugs chase you — slash them',
  Ability.syntaxLaser: 'Change height before it fires',
  Ability.beeSwarm: 'Bees chase you — slash them',
  Ability.vineTrap: 'Vines slow you down — dodge them',
  Ability.slash: "Don't stand too close!",
  Ability.charge: 'Jump over the charge',
  Ability.dodgeball: 'Balls bounce — time your jump',
  Ability.arrowVolley: 'Arrows fall from above',
  Ability.catapult: 'Rocks make small shockwaves',
  Ability.earthquake: 'Get on a shelf!',
  Ability.tornado: 'It pulls you in — run!',
  Ability.noteWave: 'Notes wave up and down',
  Ability.bassDrop: 'Double shockwave — jump twice',
  Ability.lullaby: 'Makes you sleepy and SLOW',
  Ability.coinRain: 'Money falls from the sky',
  Ability.marketCrash: 'Find the gap in the crash',
  Ability.tax: 'Steals half your ⚡ power',
  Ability.aiDrones: 'Drones chase you — slash them',
  Ability.binaryWave: '0s and 1s wave at you',
  Ability.scanLaser: 'Change height before it fires',
  Ability.emailSpam: 'Cut through the inbox!',
  Ability.summon: 'Monsters join the fight!',
  Ability.shadowDash: 'It crosses the room — JUMP or ROLL',
  Ability.spinSlash: 'Red ring = get away NOW',
  Ability.bloodRain: 'Blades fall from the sky',
  Ability.shadowTeleport: 'It appears behind you… roll!',
  Ability.lightsOut: 'Darkness. Eyes. Stay calm.',
  Ability.redPen: 'The "F" burns the floor — step off',
};

/// Floating platform: [x] and [w] are fractions of the arena width,
/// [h] is the height above the floor in world units (world height = 100).
class PlatformDef {
  final double x, h, w;
  const PlatformDef(this.x, this.h, this.w);
}

const _twoShelves = [PlatformDef(0.16, 28, 0.18), PlatformDef(0.62, 28, 0.18)];
const _threeShelves = [PlatformDef(0.10, 28, 0.16), PlatformDef(0.42, 46, 0.16), PlatformDef(0.72, 28, 0.16)];

//// Most bosses are fought twice: a MIDTERM round, then a harder FINAL round.
const int kRoundsPerFloor = 2;

const _mathGlyphs = ['π', '√2', '∑', 'x²', '7', '∞', '÷', '%', '42', '0', 'Δ', 'sin'];

class TeacherDef {
  final String floorLabel; // "1", "2" ... "6"
  final String floorName;
  final String name;
  final String subject; // short, for the HUD and blackboard
  final String course; // full title / epithet
  final String emoji;
  final String body; // sprite set: Enchantress, Knight, Swordsman, DarkKnight, SilverKnight, Demon
  final double hue; // hue rotation (degrees) applied to the sprite
  final double scale;
  final int hp; // first-round HP; later rounds have more
  final double speed;
  final double cooldown;
  final List<Ability> abilities;
  final List<Ability> finalAbilities; // added in round 2 (or used alone with [finalReplaces])
  final bool finalReplaces;
  final String intro;
  final String finalLine;
  final String rage;
  final String defeat;
  final List<String> taunts;
  final Color wall, wallDark, accent;
  final List<String> board;
  final List<PlatformDef> platforms;
  final List<MinionKind> minions; // summoned with Ability.summon
  final bool scary; // villain room: darkness, lightning, horror music
  final bool dark; // the lights are off: you only see around yourself

  /// Rounds fought in a row. The Grade Reaper has three phases.
  final int rounds;
  final List<String> roundNames;

  /// Said when a round (not the last one) is won, one per round.
  final List<String> breakLines;

  /// The Reaper's last phase: he cannot be hurt, only outlasted by standing still.
  final List<Ability> fearAbilities;
  final String fearLine;

  /// Per-boss flavour: names, tips and the things their powers throw.
  final Map<Ability, String> names;
  final Map<Ability, String> tips;
  final String shout; // floats over a shockwave
  final List<String> words; // letter wave: calm word, angry word
  final List<String> glyphs; // number spread
  final String orb, loop, rain, ball, spike, laser;

  /// Two bosses sharing one health bar who take turns. Hitting one makes
  /// the other stronger. Each twin has its own move set.
  final List<String> twins;
  final List<String> twinLines;
  final List<List<Ability>> twinAbilities;

  /// Abilities the Reaper borrows from bosses beaten earlier (ability →
  /// index into [kFloors]); their shadow rises when he uses one.
  final Map<Ability, int> echoes;

  /// Drawn as a dark silhouette.
  final bool shadow;

  const TeacherDef({
    required this.floorLabel,
    required this.floorName,
    required this.name,
    required this.subject,
    required this.course,
    required this.emoji,
    this.body = 'Enchantress',
    required this.hue,
    this.scale = 1.0,
    required this.hp,
    required this.speed,
    required this.cooldown,
    required this.abilities,
    this.finalAbilities = const [],
    this.finalReplaces = false,
    required this.intro,
    required this.finalLine,
    required this.rage,
    required this.defeat,
    required this.taunts,
    required this.wall,
    required this.wallDark,
    required this.accent,
    required this.board,
    required this.platforms,
    this.minions = const [MinionKind.goblin],
    this.scary = false,
    this.dark = false,
    this.rounds = kRoundsPerFloor,
    this.roundNames = const ['MIDTERM', 'FINAL EXAM'],
    this.breakLines = const ['Not bad... but that was only the midterm!'],
    this.fearAbilities = const [],
    this.fearLine = '',
    this.names = const {},
    this.tips = const {},
    this.shout = 'SILENCE!',
    this.words = const ['ESSAY', 'DETENTION'],
    this.glyphs = _mathGlyphs,
    this.orb = 'H⁺',
    this.loop = '∞',
    this.rain = '🍎',
    this.ball = '🏐',
    this.spike = '?',
    this.laser = 'AI: face detected · scanning...',
    this.twins = const [],
    this.twinLines = const [],
    this.twinAbilities = const [],
    this.echoes = const {},
    this.shadow = false,
  });

  String abilityName(Ability a) => names[a] ?? kAbilityName[a]!;
  String abilityTip(Ability a) => tips[a] ?? kAbilityTip[a]!;

  /// What the boss says as round [round] begins.
  String lineFor(int round) => switch (round) {
        1 => intro,
        2 => finalLine,
        _ => fearLine,
      };

  String roundName(int round) => roundNames[(round - 1).clamp(0, roundNames.length - 1)];

  /// Every ability this boss can use in the first round (both twins).
  List<Ability> get allAbilities => twins.isEmpty ? abilities : {for (final l in twinAbilities) ...l}.toList();
}

// The six guardians of the Nightmare University, one per floor (one per hour).
const List<TeacherDef> kFloors = [
  // ── Floor 1 · 3:00 AM ──────────────────────────────────────────────────
  TeacherDef(
    floorLabel: '1',
    floorName: 'THE HALLWAY OF HOMEWORK',
    name: 'The Hall Monitor',
    subject: 'DETENTION',
    course: 'A giant with a whistle who punishes the late',
    emoji: '📯',
    body: 'SilverKnight',
    hue: 0,
    scale: 1.35,
    hp: 130,
    speed: 30,
    cooldown: 2.1,
    abilities: [Ability.grammarShout, Ability.dodgeball, Ability.charge, Ability.summon],
    finalAbilities: [Ability.slash, Ability.letterWave],
    minions: [MinionKind.goblin, MinionKind.eye],
    names: {
      Ability.grammarShout: 'Whistle Blast',
      Ability.dodgeball: 'Biting Backpacks',
      Ability.charge: 'No Running!',
      Ability.letterWave: '"LATE!" Wave',
      Ability.summon: 'Homework Swarm',
    },
    tips: {
      Ability.grammarShout: 'JUMP over the whistle blast',
      Ability.dodgeball: 'Backpacks bounce — time your jump',
    },
    shout: 'LATE!',
    words: ['LATE', 'TOO LATE'],
    ball: '🎒',
    intro: 'Late! LATE! You are always late!',
    finalLine: 'The bell is ringing! DETENTION starts NOW!',
    breakLines: ['Where is your hall pass?! Get back here!'],
    rage: 'LATE! LATE! LATE!',
    defeat: '…Fine. Go. But the bell is still ringing.',
    taunts: ['Where is your hall pass?', 'The bell rang an HOUR ago!', 'No running in the hallway!'],
    wall: Color(0xFF3A2424),
    wallDark: Color(0xFF1C1010),
    accent: Color(0xFFFF7043),
    board: ['LATE  LATE  LATE', 'Homework due: YESTERDAY', '⏰ 3:00 AM'],
    platforms: _twoShelves,
  ),
  // ── Floor 2 · 4:00 AM ──────────────────────────────────────────────────
  TeacherDef(
    floorLabel: '2',
    floorName: 'THE MATH TOWER',
    name: 'Professor Calculus',
    subject: 'CALCULUS',
    course: 'Made of chalk and numbers · splits into fractions',
    emoji: '📐',
    body: 'Swordsman',
    hue: 200,
    hp: 150,
    speed: 34,
    cooldown: 1.95,
    abilities: [Ability.numberSpread, Ability.infinity, Ability.popQuiz, Ability.summon],
    finalAbilities: [Ability.gravityPull, Ability.slash],
    minions: [MinionKind.goblin, MinionKind.skeleton],
    names: {
      Ability.numberSpread: 'Fraction Split',
      Ability.infinity: 'Infinite Series',
      Ability.popQuiz: 'Show Your Work',
      Ability.gravityPull: 'Divide by Zero',
    },
    tips: {
      Ability.numberSpread: 'He splits into fractions — cut them',
      Ability.gravityPull: 'Everything falls into the zero — run!',
    },
    glyphs: ['½', '⅓', '¼', '⅔', '¾', '÷', '∫', 'dx', 'π', '∑', '⅛', '√'],
    intro: 'Show your work, boy. ALL of it.',
    finalLine: 'Now the hard part. Show me the PROOF!',
    breakLines: ['Partial credit. That is all you get... so far.'],
    rage: 'Let me SPLIT this problem into PIECES!',
    defeat: 'Correct… for once.',
    taunts: ['Where is your working?', 'Wrong sign. Again.', 'That step does NOT follow!'],
    wall: Color(0xFF263040),
    wallDark: Color(0xFF111722),
    accent: Color(0xFFE0F7FA),
    board: ['∫ fear dx = ?', 'lim sleep → 0', '4:00 AM ≠ enough time'],
    platforms: [PlatformDef(0.08, 22, 0.16), PlatformDef(0.36, 38, 0.14), PlatformDef(0.62, 52, 0.14)],
  ),
  // ── Floor 3 · 5:00 AM ──────────────────────────────────────────────────
  TeacherDef(
    floorLabel: '3',
    floorName: 'THE SILENT LIBRARY',
    name: 'The Librarian',
    subject: 'SILENCE',
    course: 'No face. One finger, always pressed to her lips',
    emoji: '🤫',
    body: 'Enchantress',
    hue: 250,
    hp: 165,
    speed: 30,
    cooldown: 1.9,
    dark: true,
    abilities: [Ability.grammarShout, Ability.letterWave, Ability.lullaby, Ability.summon],
    finalAbilities: [Ability.lightsOut, Ability.popQuiz],
    minions: [MinionKind.eye, MinionKind.skeleton],
    names: {
      Ability.grammarShout: 'Shhhh Wave',
      Ability.letterWave: 'Flying Books',
      Ability.lullaby: 'Bedtime Story',
      Ability.summon: 'Wake the Books',
      Ability.popQuiz: 'Overdue Notices',
    },
    tips: {
      Ability.grammarShout: 'JUMP over the silence',
      Ability.summon: 'Every sound wakes the books',
    },
    shout: 'SHHHHHH…',
    words: ['SHHH', 'SILENCE'],
    spike: '!',
    intro: 'Shhhhhhh…',
    finalLine: 'Shhhhhhhhhhhhhhhhh…',
    breakLines: ['…'],
    rage: 'SHHHHHHHHHHHHHHH!',
    defeat: '*lowers her finger… and fades away in silence*',
    taunts: ['Shhh…', 'Shhhhhh…', '…'],
    wall: Color(0xFF221A30),
    wallDark: Color(0xFF0E0A16),
    accent: Color(0xFFB388FF),
    board: ['SILENCE', 'Students Who Never Woke Up', '— overdue —'],
    platforms: _threeShelves,
  ),
  // ── Floor 4 · 6:00 AM ──────────────────────────────────────────────────
  TeacherDef(
    floorLabel: '4',
    floorName: 'THE SCIENCE LAB',
    name: 'Dr. Volt',
    subject: 'NO SLEEP',
    course: 'Turned himself into electricity to never sleep again',
    emoji: '⚡',
    body: 'DarkKnight',
    hue: 45,
    hp: 185,
    speed: 36,
    cooldown: 1.75,
    abilities: [Ability.energyBall, Ability.scanLaser, Ability.potionLob, Ability.bubbles, Ability.summon],
    finalAbilities: [Ability.gravityPull, Ability.charge],
    minions: [MinionKind.flyAgaric, MinionKind.mushroom],
    names: {
      Ability.energyBall: 'Volt Ball',
      Ability.scanLaser: '100,000 Volts',
      Ability.potionLob: 'Failed Experiments',
      Ability.bubbles: 'Acid Bubbles',
      Ability.gravityPull: 'Magnet Field',
      Ability.charge: 'Overcharge',
      Ability.summon: 'Escaped Specimens',
    },
    orb: '⚡',
    laser: 'ZZZAP! · 100,000 VOLTS',
    intro: 'Sleep is weakness! I removed it from my body!',
    finalLine: 'MORE POWER! I will NEVER sleep again!',
    breakLines: ['Ha! A minor short circuit. Recharging...'],
    rage: 'MAXIMUM VOLTAGE!',
    defeat: 'So… tired…',
    taunts: ['Who needs sleep when you have VOLTS?', 'Coffee is for amateurs!', 'Bzzzt! Stay AWAKE!'],
    wall: Color(0xFF1E2A26),
    wallDark: Color(0xFF0C1411),
    accent: Color(0xFFFFEA00),
    board: ['V = I × R', 'SLEEP = 0', 'DO NOT TOUCH THE JARS'],
    platforms: _twoShelves,
  ),
  // ── Floor 5 · 7:00 AM ──────────────────────────────────────────────────
  TeacherDef(
    floorLabel: '5',
    floorName: 'THE OFFICE OF DEADLINES',
    name: 'The Deadline Twins',
    subject: 'DEADLINES',
    course: 'Two identical shadows: Tomorrow and Too Late',
    emoji: '⏳',
    body: 'Knight',
    hue: 0,
    scale: 1.1,
    shadow: true,
    hp: 200,
    speed: 38,
    cooldown: 1.7,
    abilities: [Ability.lullaby, Ability.tax, Ability.appleRain, Ability.summon],
    twins: ['Tomorrow', 'Too Late'],
    twinLines: ['Relax, you can do it later…', '…and later never comes.'],
    twinAbilities: [
      [Ability.lullaby, Ability.tax, Ability.appleRain, Ability.summon],
      [Ability.marketCrash, Ability.shadowTeleport, Ability.charge, Ability.slash],
    ],
    finalAbilities: [Ability.popQuiz],
    minions: [MinionKind.mushroom, MinionKind.skeleton],
    names: {
      Ability.lullaby: 'Relax…',
      Ability.tax: 'Procrastinate',
      Ability.appleRain: 'Falling Clocks',
      Ability.marketCrash: 'TOO LATE!',
      Ability.shadowTeleport: 'Right Behind You',
      Ability.charge: 'Deadline Rush',
      Ability.popQuiz: 'Ticking Timers',
      Ability.summon: 'Deadline Shrooms',
    },
    tips: {
      Ability.marketCrash: 'Find the gap before time runs out',
      Ability.lullaby: 'Hit one twin, the other gets stronger',
    },
    rain: '⏰',
    spike: '⌛',
    intro: 'Tomorrow: Relax, you can do it later…\nToo Late: …and later never comes.',
    finalLine: 'Tomorrow is already here. And it is TOO LATE.',
    breakLines: ['Tomorrow: Take a break… you deserve it…'],
    rage: 'The clock is running FASTER!',
    defeat: '*the two shadows merge into one… and vanish into a clock*',
    taunts: ['Later… later…', 'Tick. Tock.', 'You still have time… or do you?'],
    wall: Color(0xFF2E2A22),
    wallDark: Color(0xFF15130F),
    accent: Color(0xFFFFB300),
    board: ['DUE: 7:00 AM', 'DUE: 7:00 AM', 'DUE: NOW'],
    platforms: _threeShelves,
  ),
  // ── Floor 6 · 8:00 AM — the villain ────────────────────────────────────
  TeacherDef(
    floorLabel: '6',
    floorName: 'THE EXAM HALL',
    name: 'The Grade Reaper',
    subject: 'FINAL EXAM',
    course: 'Feeds on fear · his scythe is a giant red pen',
    emoji: '💀',
    body: 'Demon',
    hue: 0,
    scale: 1.5,
    hp: 260,
    speed: 44,
    cooldown: 1.45,
    rounds: 3,
    roundNames: ['RED PEN', 'SHADOWS', 'FEAR'],
    abilities: [Ability.redPen, Ability.shadowDash, Ability.spinSlash, Ability.shadowTeleport, Ability.bloodRain],
    // Phase 2: the shadows of every boss you beat
    finalAbilities: [
      Ability.dodgeball,
      Ability.numberSpread,
      Ability.grammarShout,
      Ability.energyBall,
      Ability.marketCrash,
      Ability.shadowDash,
      Ability.redPen,
    ],
    finalReplaces: true,
    echoes: {
      Ability.dodgeball: 0,
      Ability.numberSpread: 1,
      Ability.grammarShout: 2,
      Ability.energyBall: 3,
      Ability.marketCrash: 4,
    },
    fearAbilities: [Ability.bloodRain, Ability.letterWave, Ability.redPen, Ability.shadowTeleport],
    names: {
      Ability.bloodRain: 'Red Ink Rain',
      Ability.letterWave: '"FAIL" Wave',
      Ability.dodgeball: "Hall Monitor's Shadow",
      Ability.numberSpread: "Calculus' Shadow",
      Ability.grammarShout: "Librarian's Shadow",
      Ability.energyBall: "Dr. Volt's Shadow",
      Ability.marketCrash: "The Twins' Shadow",
    },
    tips: {
      Ability.letterWave: 'You cannot cut fear… stand still',
    },
    words: ['FAIL', 'PANIC'],
    orb: '⚡',
    ball: '🎒',
    glyphs: ['½', '⅓', '¼', '⅔', '¾', '÷', '∫', 'dx'],
    shout: 'SHHHHHH…',
    rain: '⏰',
    intro: "Look around you. Every one of them was sure they'd pass.\nEvery one of them panicked. Now they are mine.",
    finalLine: 'Remember them? They remember YOU. Rise, all of you!',
    fearLine: "I am not your enemy. I am your fear.\nYou can't kill me… you can only stop running.",
    breakLines: ['You fight well… for someone so afraid.', 'Enough. Look at me. LOOK AT MY FACE.'],
    rage: 'Panic, little student. PANIC!',
    defeat: '…you stopped running.',
    taunts: ['Every one of them panicked.', 'Tick… tock… 9:00 AM.', 'Your name is already in the book.'],
    wall: Color(0xFF140A10),
    wallDark: Color(0xFF050204),
    accent: Color(0xFFFF1744),
    board: ['FINAL EXAM', 'F  F  F  F  F', '9:00 AM'],
    platforms: [PlatformDef(0.12, 30, 0.16), PlatformDef(0.72, 30, 0.16)],
    minions: [MinionKind.eye, MinionKind.skeleton],
    scary: true,
  ),
];

/// Bumped when the floor list changes, so old best times don't compare.
const int kFloorsVersion = 6;
