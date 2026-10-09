// lib/game/teachers.dart
// Floor + teacher definitions. Each floor of the university has one teacher
// boss whose special abilities come from the subject they teach.

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
};

/// Floating platform: [x] and [w] are fractions of the arena width,
/// [h] is the height above the floor in world units (world height = 100).
class PlatformDef {
  final double x, h, w;
  const PlatformDef(this.x, this.h, this.w);
}

const _twoShelves = [PlatformDef(0.16, 28, 0.18), PlatformDef(0.62, 28, 0.18)];
const _threeShelves = [PlatformDef(0.10, 28, 0.16), PlatformDef(0.42, 46, 0.16), PlatformDef(0.72, 28, 0.16)];

/// Every teacher is fought twice: a MIDTERM round, then a harder FINAL round.
const int kRoundsPerFloor = 2;

class TeacherDef {
  final String floorLabel; // "B", "1", "2" ...
  final String floorName;
  final String name;
  final String subject; // short, for the HUD and blackboard
  final String course; // full course title
  final String emoji;
  final String body; // sprite set: Enchantress, Knight, Swordsman, DarkKnight, SilverKnight
  final double hue; // hue rotation (degrees) applied to the sprite
  final double scale;
  final int hp; // midterm HP; the final round has more
  final double speed;
  final double cooldown;
  final List<Ability> abilities;
  final List<Ability> finalAbilities; // added in the FINAL round
  final String intro;
  final String finalLine;
  final String rage;
  final String defeat;
  final List<String> taunts;
  final Color wall, wallDark, accent;
  final List<String> board;
  final List<PlatformDef> platforms;
  final List<MinionKind> minions; // summoned with Ability.summon

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
  });
}

const List<TeacherDef> kFloors = [
  TeacherDef(
    floorLabel: 'B',
    floorName: 'BASEMENT',
    name: 'Abdurasul Bobonazarov',
    subject: 'APPLIED MATH 1',
    course: 'Applied Mathematics 1',
    emoji: '📐',
    body: 'Swordsman',
    hue: 35,
    hp: 130,
    speed: 30,
    cooldown: 2.2,
    abilities: [Ability.numberSpread, Ability.infinity, Ability.popQuiz, Ability.summon],
    minions: [MinionKind.goblin],
    finalAbilities: [Ability.slash, Ability.charge],
    intro: 'Welcome to Applied Mathematics 1!\nShow your work... or show yourself out!',
    finalLine: 'Midterm solved. Now the FINAL EXAM!',
    rage: 'Now the problems get HARDER!',
    defeat: 'Correct answer. Full marks — go upstairs!',
    taunts: ['Derivative of your chances = 0!', 'Did you forget the minus sign?', 'Check your units!'],
    wall: Color(0xFF2B3140),
    wallDark: Color(0xFF161A24),
    accent: Color(0xFFFFB74D),
    board: ['f(x) = ax² + bx + c', 'det(A) = ad − bc', 'lim sin(x)/x = 1'],
    platforms: [PlatformDef(0.18, 26, 0.18), PlatformDef(0.62, 26, 0.18)],
  ),
  TeacherDef(
    floorLabel: '1',
    floorName: 'FIRST FLOOR',
    name: 'Aziz Turgunov',
    subject: 'PROGRAMMING 1',
    course: 'Introduction to Programming 1',
    emoji: '💻',
    body: 'Knight',
    hue: 160,
    hp: 150,
    speed: 34,
    cooldown: 2.0,
    abilities: [Ability.bugSwarm, Ability.syntaxLaser, Ability.infinity, Ability.summon],
    minions: [MinionKind.eye, MinionKind.goblin],
    finalAbilities: [Ability.slash, Ability.charge],
    intro: "Introduction to Programming 1.\nLet's see if your code compiles!",
    finalLine: 'Midterm compiled. Now the FINAL PROJECT!',
    rage: 'Runtime error: student.exe',
    defeat: 'Build successful! You may push upstairs.',
    taunts: ['Missing semicolon;', 'It works on MY machine!', 'while(true) { practice(); }'],
    wall: Color(0xFF1E2A38),
    wallDark: Color(0xFF0D141C),
    accent: Color(0xFF00E5FF),
    board: ['print("Hello, World")', 'for i in range(10):', 'if passed: graduate()'],
    platforms: _threeShelves,
  ),
  TeacherDef(
    floorLabel: '2',
    floorName: 'SECOND FLOOR',
    name: 'Muxammadamin Saloxiddinov',
    subject: 'HUMAN & AI',
    course: 'Human and AI Interaction in Education',
    emoji: '🤖',
    body: 'DarkKnight',
    hue: 120, // green "robot" tint so it differs from the Dark Knight student
    hp: 165,
    speed: 32,
    cooldown: 1.9,
    abilities: [Ability.aiDrones, Ability.binaryWave, Ability.scanLaser, Ability.summon],
    minions: [MinionKind.eye, MinionKind.skeleton],
    finalAbilities: [Ability.gravityPull, Ability.slash],
    intro: 'Human and AI Interaction in Education.\nMy AI predicts you will lose: 99.9%!',
    finalLine: 'Model retrained. FINAL EXAM loading...',
    rage: 'Switching to DEEP LEARNING mode!',
    defeat: 'Prediction error... You win. Proceed!',
    taunts: ['Did you ask ChatGPT for help?', 'Training data says: you lose!', 'Beep boop. Try again.'],
    wall: Color(0xFF263238),
    wallDark: Color(0xFF101619),
    accent: Color(0xFF69F0AE),
    board: ['Human + AI = 🤝', 'Prompt → Response', 'Ethics first!'],
    platforms: _twoShelves,
  ),
  TeacherDef(
    floorLabel: '3',
    floorName: 'THIRD FLOOR',
    name: 'Zaynabxon Yusupova',
    subject: 'BUSINESS COMM.',
    course: 'Business Communication Skills',
    emoji: '💼',
    body: 'Enchantress',
    hue: 285,
    hp: 180,
    speed: 32,
    cooldown: 1.8,
    abilities: [Ability.emailSpam, Ability.coinRain, Ability.tax, Ability.summon],
    minions: [MinionKind.mushroom, MinionKind.goblin],
    finalAbilities: [Ability.marketCrash, Ability.lullaby],
    intro: 'Business Communication Skills.\nPlease introduce yourself... professionally!',
    finalLine: 'Thank you for the midterm. Now — the FINAL PRESENTATION!',
    rage: 'This meeting could have been an EMAIL!',
    defeat: 'Excellent communication! You may proceed.',
    taunts: ['Per my last email...', 'Eye contact, please!', "Let's circle back on that!"],
    wall: Color(0xFF4A3550),
    wallDark: Color(0xFF261A2A),
    accent: Color(0xFFE040FB),
    board: ['Clear · Concise · Polite', 'Dear Sir / Madam,', 'Best regards'],
    platforms: _threeShelves,
  ),
  TeacherDef(
    floorLabel: '4',
    floorName: 'FOURTH FLOOR',
    name: 'Tohirjon Qadirov',
    subject: 'ENGLISH (EAP)',
    course: 'English for Academic Purposes',
    emoji: '📚',
    body: 'Swordsman',
    hue: 200,
    hp: 200,
    speed: 36,
    cooldown: 1.75,
    abilities: [Ability.letterWave, Ability.grammarShout, Ability.popQuiz, Ability.summon],
    minions: [MinionKind.goblin, MinionKind.mushroom, MinionKind.eye],
    finalAbilities: [Ability.slash, Ability.charge, Ability.vineTrap],
    intro: 'English for Academic Purposes.\nWhere is your thesis statement?',
    finalLine: 'Midterm essay done. Now the FINAL RESEARCH PAPER!',
    rage: 'CITATION NEEDED!',
    defeat: 'Well argued. Grade: A. Go on!',
    taunts: ['Paraphrase, do not copy!', 'Too informal!', '250 words minimum!'],
    wall: Color(0xFF35506B),
    wallDark: Color(0xFF1C2B3B),
    accent: Color(0xFF40C4FF),
    board: ['Thesis statement', 'Cite your sources!', 'APA 7th edition'],
    platforms: [PlatformDef(0.08, 26, 0.18), PlatformDef(0.40, 44, 0.18), PlatformDef(0.72, 26, 0.18)],
  ),
  TeacherDef(
    floorLabel: '5',
    floorName: 'TOP FLOOR',
    name: "In'omjon Qo'chqorov",
    subject: 'UZBEK HISTORY',
    course: 'Most Recent History of Uzbekistan',
    emoji: '🏛️',
    body: 'SilverKnight',
    hue: 0,
    scale: 1.2,
    hp: 260,
    speed: 36,
    cooldown: 1.6,
    abilities: [Ability.arrowVolley, Ability.catapult, Ability.earthquake, Ability.slash, Ability.summon],
    minions: [MinionKind.skeleton, MinionKind.goblin, MinionKind.eye],
    finalAbilities: [Ability.charge, Ability.tornado],
    intro: 'Most Recent History of Uzbekistan.\nDo you know the date of Independence?',
    finalLine: 'The last chapter... the FINAL EXAM!',
    rage: 'History will remember THIS battle!',
    defeat: '1991... and today YOU made history. Graduate!',
    taunts: ['September 1, 1991!', 'Learn from the past!', 'Name all the regions of Uzbekistan!'],
    wall: Color(0xFF4E3B2A),
    wallDark: Color(0xFF261C13),
    accent: Color(0xFFFFD54F),
    board: ['1991 · Independence', 'New Uzbekistan', 'Tashkent · Samarkand · Bukhara'],
    platforms: _threeShelves,
  ),
];

/// Bumped when the floor list changes, so old best times don't compare.
const int kFloorsVersion = 3;
