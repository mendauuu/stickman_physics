// lib/game/school_game.dart
// "Exam Escape: The Saga of the Last Night" — Ozod fell asleep before his
// Final Exam and woke up at 3:00 AM inside the Nightmare University. He has
// six hours to climb six floors and face the Grade Reaper. Boss rooms hold
// the guardians of each fear; halls hold monster waves; Mira waits in the
// quiet corners. Bosses drop Lost Notes: pages that give Ozod new powers.
//
// The world is measured in units where the screen height is 100; the canvas
// is scaled by [unit] when drawing.

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../pixel/pixel_art.dart';
import 'audio.dart';
import 'campus.dart';
import 'decor.dart';
import 'entities.dart';
import 'heroes.dart';
import 'minions.dart';
import 'scenery.dart';
import 'sprites.dart';
import 'story.dart';
import 'teachers.dart';
import 'vibes.dart';

const double kGround = 80;

/// The world is drawn this many pixels tall, then scaled up with hard
/// pixels: every sprite, shape and effect sits on one chunky pixel grid.
const double kPixelRows = 144;
const double kGravity = 330;
const double kJumpSpeed = 150;
const double kCharHeight = 24; // world units

/// Left edge of the player HUD (world units); the pause button sits left of it.
const double kHudLeft = 14;

const kAllOverlays = ['menu', 'intro', 'story', 'rest', 'controls', 'pause', 'gameOver', 'victory'];

enum Phase { menu, intro, story, fight, roundBreak, rest, cleared, transition, gameOver, victory }

const _bodyFps = <String, Map<String, double>>{
  'Knight': {
    'Idle': 8, 'Walk': 10, 'Run': 12, 'Jump': 10, 'Attack_1': 16,
    'Attack_2': 10, 'Attack_3': 14, 'Attack_4': 12, 'Hurt': 10, 'Dead': 8,
  },
  'Enchantress': {
    'Idle': 8, 'Walk': 9, 'Run': 12, 'Jump': 10, 'Attack_1': 14,
    'Attack_2': 10, 'Attack_3': 10, 'Attack_4': 14, 'Hurt': 10, 'Dead': 7,
  },
  'Swordsman': {
    'Idle': 8, 'Walk': 10, 'Run': 12, 'Jump': 10, 'Attack_1': 16,
    'Attack_2': 14, 'Attack_3': 16, 'Attack_4': 12, 'Hurt': 8, 'Dead': 7,
  },
};

/// FreeKnight sheets use different file names; map them onto ours.
const _freeKnightFiles = <String, (String, double)>{
  'Idle': ('_Idle', 10),
  'Walk': ('_Run', 8),
  'Run': ('_Run', 14),
  'Jump': ('_Jump', 10),
  'Attack_1': ('_Attack', 12),
  'Attack_2': ('_Attack2', 14),
  'Attack_3': ('_AttackCombo', 18),
  'Attack_4': ('_AttackCombo', 16),
  'Hurt': ('_Hit', 4),
  'Dead': ('_Death', 12),
};
const _samuraiGeom = SpriteGeom(200, 200, 94, 122, 53);

/// Other sprite packs: body name → (folder, frame layout, our anim name → (file, fps)).
const _packBodies = <String, (String, SpriteGeom, Map<String, (String, double)>)>{
  'Samurai': (
    'Martial Hero/Sprites',
    _samuraiGeom,
    {
      'Idle': ('Idle', 10), 'Walk': ('Run', 10), 'Run': ('Run', 14), 'Jump': ('Jump', 8),
      'Attack_1': ('Attack1', 18), 'Attack_2': ('Attack2', 18), 'Attack_3': ('Attack1', 18),
      'Attack_4': ('Attack2', 16), 'Hurt': ('Take Hit', 14), 'Dead': ('Death', 10),
    },
  ),
  'Goblin': (
    'Monsters_Creatures_Fantasy/Goblin',
    SpriteGeom(150, 150, 74, 101, 36),
    {
      'Idle': ('Idle', 8), 'Walk': ('Run', 10), 'Run': ('Run', 14), 'Jump': ('Run', 10),
      'Attack_1': ('Attack', 16), 'Attack_2': ('Attack', 16), 'Attack_3': ('Attack', 16),
      'Attack_4': ('Attack', 16), 'Hurt': ('Take Hit', 12), 'Dead': ('Death', 10),
    },
  ),
  'Mushroom': (
    'Monsters_Creatures_Fantasy/Mushroom',
    SpriteGeom(150, 150, 75, 101, 37),
    {
      'Idle': ('Idle', 8), 'Run': ('Run', 10), 'Attack_1': ('Attack', 16),
      'Hurt': ('Take Hit', 12), 'Dead': ('Death', 10),
    },
  ),
  'Skeleton': (
    'Monsters_Creatures_Fantasy/Skeleton',
    SpriteGeom(150, 150, 82, 101, 51),
    {
      'Idle': ('Idle', 8), 'Run': ('Walk', 8), 'Attack_1': ('Attack', 16),
      'Hurt': ('Take Hit', 12), 'Dead': ('Death', 10), 'Shield': ('Shield', 12),
    },
  ),
  'Hero': (
    'male_hero_free/individual_sheets',
    SpriteGeom(128, 128, 57, 80, 37),
    {
      'Idle': ('male_hero-idle', 10), 'Walk': ('male_hero-walk', 10), 'Run': ('male_hero-run', 14),
      'Jump': ('male_hero-jump', 10), 'Attack_1': ('male_hero-combo_1', 14), 'Attack_2': ('male_hero-combo_1_end', 16),
      'Attack_3': ('male_hero-combo_1', 14), 'Attack_4': ('male_hero-combo_1_end', 12),
      'Hurt': ('male_hero-fall', 12), 'Dead': ('male_hero-fall', 8),
    },
  ),
  'Demon': (
    'Demon_sword/strips',
    SpriteGeom(128, 64, 31, 50, 23),
    {
      'Idle': ('Idle', 10), 'Walk': ('Walk', 10), 'Run': ('Run2', 14), 'Jump': ('Idle', 10),
      'Attack_1': ('Attack', 14), 'Attack_2': ('Attack', 14), 'Attack_3': ('AttackCombo', 14),
      'Attack_4': ('AttackCombo', 14), 'Hurt': ('Hit', 8), 'Dead': ('Death', 10),
    },
  ),
  'Senior': (
    'MainCharacter(FreePack)',
    SpriteGeom(192, 128, 97, 95, 58),
    {'Idle': ('Idle', 8)},
  ),
  'FlyAgaric': (
    'Forest_Monsters_FREE/Mushroom/Mushroom with VFX',
    SpriteGeom(80, 64, 40, 64, 33),
    {
      'Idle': ('Mushroom-Idle', 8), 'Run': ('Mushroom-Run', 10), 'Attack_1': ('Mushroom-Attack', 14),
      'Hurt': ('Mushroom-Hit', 12), 'Dead': ('Mushroom-Die', 12), 'Stun': ('Mushroom-Stun', 12),
    },
  ),
  'FlyingEye': (
    'Monsters_Creatures_Fantasy/Flying eye',
    SpriteGeom(150, 150, 77, 92, 31),
    {
      'Idle': ('Flight', 12), 'Run': ('Flight', 14), 'Attack_1': ('Attack', 14),
      'Hurt': ('Take Hit', 12), 'Dead': ('Death', 10),
    },
  ),
};

/// How far (sprite px) the demon's body has moved inside each AttackCombo
/// frame — its dash is drawn into the sheet, so the hitbox follows this curve.
const _demonDash = [1, 29, 58, 69, 70, 64, 64, 64];

const _freeKnightFolders = {
  'DarkKnight': 'FreeKnight_v1/Colour1/NoOutline/120x80_PNGSheets',
  'SilverKnight': 'FreeKnight_v1/Colour2/NoOutline/120x80_PNGSheets',
};

const _animNames = [
  'Idle', 'Walk', 'Run', 'Jump', 'Attack_1', 'Attack_2', 'Attack_3', 'Attack_4', 'Hurt', 'Dead',
];
const _oneShot = {'Jump', 'Attack_1', 'Attack_2', 'Attack_3', 'Attack_4', 'Hurt', 'Dead', 'Shield'};

class SchoolGame extends Game with KeyboardEvents {
  final Random rng;

  /// [seed] makes fights repeatable (used by tests).
  SchoolGame({int? seed}) : rng = Random(seed);
  final _text = TextCache();
  final _bodies = <String, Map<String, SpriteAnim>>{};
  Map<String, SpriteAnim> get _heroAnims => _bodies[hero.body]!;
  Map<String, SpriteAnim> get _teacherAnims => _bodies[_tBody]!;

  /// Sprite set the boss is drawn with. Unmasked, the Reaper has your face.
  String get _tBody => fearPhase ? hero.body : def.body;
  bool _ready = false;
  bool get isReady => _ready;

  /// World width (height is always 100).
  double W = 180;
  double get unit => size.y / 100;

  // ── Public state for overlays ───────────────────────────────────────────
  Phase phase = Phase.menu;
  bool isPaused = false;
  int floor = 0; // index into kRooms
  int bestFloor = 0; // highest room index reached; kRooms.length = graduated
  double runTime = 0;
  double? bestTime;
  int hitsLanded = 0;
  int retries = 0;
  final energy = ValueNotifier<double>(0);

  RoomDef get room => kRooms[floor];
  TeacherDef get def => room.def;
  bool get _boss => room.isBoss && !escaping;

  /// True after the Grade Reaper falls: the student walks out into the light.
  bool escaping = false;

  // ── Story ──────────────────────────────────────────────────────────────
  /// Lines shown by the 'story' overlay; [endStory] runs what comes next.
  List<StoryLine> story = const [];
  VoidCallback? _afterStory;
  Phase _storyFrom = Phase.intro;
  final _told = <Object>{}; // story beats already told this run
  double _storyIn = 0; // countdown to the story told after a boss falls

  /// The nightmare clock, in minutes after midnight.
  int get clockMinutes => escaping ? 8 * 60 + 59 : room.minutes;

  /// A memory Ozod says out loud when he picks up a Lost Note.
  String _memory = '';
  double _memoryTime = 0;

  /// Landscape shown in the current room (null indoors).
  String? get sceneName => escaping ? kEscapeScene : room.scene;
  Landscape? get _scene => sceneName == null ? null : _scenes[sceneName];
  final _scenes = <String, Landscape>{};
  final _life = SceneLife();
  double _cam = 0; // -0.5 … 0.5, follows the player for parallax

  /// How much colour the world outside has: 0 = all grey (3:00 AM, nothing
  /// remembered), 1 = full colour (awake). Each boss beaten adds a sixth.
  double get worldColor => _color;
  double _color = 0;
  bool _bossFell = false; // this room's boss is down (its colour flows in)

  double get _colorTarget {
    if (escaping) return 1;
    var n = kRooms.take(floor).where((r) => r.isBoss).length;
    if (_bossFell) n++;
    return (n / kFloors.length).clamp(0.0, 1.0);
  }

  final _greyPaints = <int, Paint>{};

  /// Paint that desaturates the landscape to the current [worldColor].
  Paint get _scenePaint {
    final k = (_color * 30).round(); // a few steps, cached
    return _greyPaints.putIfAbsent(k, () {
      final s = k / 30;
      // Saturation matrix; grey is also a little darker and flatter.
      const lr = 0.2126, lg = 0.7152, lb = 0.0722;
      final dim = 0.82 + 0.18 * s, lift = 10 * (1 - s);
      List<double> row(double r, double g, double b) => [r * dim, g * dim, b * dim, 0, lift];
      return Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.matrix([
          ...row(lr * (1 - s) + s, lg * (1 - s), lb * (1 - s)),
          ...row(lr * (1 - s), lg * (1 - s) + s, lb * (1 - s)),
          ...row(lr * (1 - s), lg * (1 - s), lb * (1 - s) + s),
          0, 0, 0, 1, 0,
        ]);
    });
  }

  /// Teachers beaten so far (unlocks characters).
  int get bossesCleared =>
      bestFloor >= kRooms.length ? kFloors.length : kRooms.take(bestFloor).where((r) => r.isBoss).length;

  // Hall rooms: monster waves
  int wave = 0;
  double _waveDelay = 0;

  // Perks picked at rest stops (last for the whole run)
  final perks = <Perk>{};
  List<Perk> perkChoices = [];
  double get _dmgMul => perks.contains(Perk.pencil) ? 1.2 : 1;
  double get _speedMul => perks.contains(Perk.sneakers) ? 1.15 : 1;
  double get _maxHpFor => hero.hp + (perks.contains(Perk.tea) ? 25.0 : 0);

  void _charge(double amount) {
    player.energy = min(100, player.energy + amount * (perks.contains(Perk.energy) ? 1.35 : 1));
  }

  /// 1 = MIDTERM, 2 = FINAL EXAM (the Grade Reaper has a third phase).
  int round = 1;
  int get rounds => def.rounds;
  bool get isFinalRound => round == rounds;
  String get roundName => def.roundName(round);
  List<Ability> get currentAbilities => _abilities;
  List<Ability> get _abilities {
    if (fearPhase) return def.fearAbilities;
    final base = def.twins.isEmpty ? def.abilities : def.twinAbilities[room.isBoss ? teacher.twin : 0];
    if (round == 1) return base;
    return def.finalReplaces ? def.finalAbilities : [...base, ...def.finalAbilities];
  }

  /// The Reaper's last phase: he can't be hurt. Only standing still — with
  /// every Lost Note you found — makes him shrink.
  bool get fearPhase => def.fearAbilities.isNotEmpty && round >= 3;

  /// Name over the boss health bar.
  String get bossName => def.twins.isNotEmpty
      ? def.twins[teacher.twin]
      : fearPhase
          ? 'YOUR FEAR'
          : def.name;

  /// Lost Notes collected this run.
  int get notesFound => perks.length;
  double _roundBreak = 0;
  bool get isLastFloor => floor == kRooms.length - 1;

  // ── World ───────────────────────────────────────────────────────────────
  final player = Player();
  late Teacher teacher;
  final _projectiles = <Projectile>[];
  final _minions = <Minion>[];
  List<Minion> get minions => _minions;
  int get minionCount => _minions.where((m) => m.state != MState.dead).length;

  // Combo counter
  int comboCount = 0;
  int maxCombo = 0;
  double _comboTimer = 0, _comboPop = 0;
  final _hazards = <Hazard>[];
  final _pickups = <Pickup>[];
  final _sparks = <Spark>[];
  final _floats = <FloatText>[];
  List<Platform> _platforms = [];
  Paint _teacherPaint = pixelPaint;

  // ── Input ───────────────────────────────────────────────────────────────
  bool left = false, right = false;
  bool _jumpQ = false, _attackQ = false, _specialQ = false, _rollQ = false;
  bool _keyLeft = false, _keyRight = false;

  void pressJump() => _jumpQ = true;
  void pressAttack() => _attackQ = true;
  void pressSpecial() => _specialQ = true;
  void pressRoll() => _rollQ = true;

  // ── Game feel ───────────────────────────────────────────────────────────
  double _shake = 0, _hitStop = 0, _slowMo = 0, _fade = 0;
  bool _fadingOut = false;
  double _pickupTimer = 10;
  double _gameOverDelay = -1;
  String _banner = '';
  double _bannerTime = 0;
  double _clock = 0;

  // Atmosphere: villain darkness, lightning, low-HP heartbeat, flicker
  double _lightsOut = 0, _lightning = 0, _lightningIn = 6, _heartbeatIn = 0, _flicker = 0, _laughIn = -1;
  bool get _scary => def.scary && !escaping;
  bool get _dark => (def.scary || def.dark) && !escaping;

  // Room vibe: ambient particles, NPC classmates
  RoomVibe get vibe => escaping ? kEscapeVibe : kVibes[room.label] ?? const RoomVibe();
  final _ambient = <_Amb>[];
  final npcs = <Npc>[];
  bool _npcsCheered = false;

  // ══════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════
  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/';
    Future<Map<String, ui.Image>> load(String who) async =>
        {for (final n in _animNames) n: await images.load('$who/$n.png')};

    for (final e in _bodyFps.entries) {
      _bodies[e.key] = buildAnims(await load(e.key), e.value, once: _oneShot);
    }
    for (final e in _freeKnightFolders.entries) {
      _bodies[e.key] = buildAnims(
        {for (final a in _freeKnightFiles.entries) a.key: await images.load('${e.value}/${a.value.$1}.png')},
        {for (final a in _freeKnightFiles.entries) a.key: a.value.$2},
        once: _oneShot,
        geom: kFreeKnightGeom,
      );
    }
    for (final e in _packBodies.entries) {
      final (folder, geom, files) = e.value;
      _bodies[e.key] = buildAnims(
        {for (final a in files.entries) a.key: await images.load('$folder/${a.value.$1}.png')},
        {for (final a in files.entries) a.key: a.value.$2},
        once: _oneShot,
        geom: geom,
      );
    }

    await PixelArt.load();

    var seed = 11;
    for (final e in kScenes.entries) {
      _scenes[e.key] = await Landscape.load(e.value, images.load, seed++);
    }

    final prefs = await SharedPreferences.getInstance();
    final savedRoom = prefs.getInt('best_room');
    final roomsVersion = prefs.getInt('rooms_v') ?? 1;
    final oldFloor = prefs.getInt('best_floor');
    if (savedRoom != null) {
      bestFloor = roomsVersion < kRoomsVersion
          ? migrateRoomIndex(savedRoom, roomsVersion) // the rooms changed since this save
          : savedRoom.clamp(0, kRooms.length);
    } else if (oldFloor != null) {
      // Older saves counted teachers beaten; keep that many bosses beaten.
      bestFloor = migrateTeacherFloor(oldFloor);
    }
    if (roomsVersion < kRoomsVersion) {
      await prefs.setInt('rooms_v', kRoomsVersion);
      if (savedRoom != null || oldFloor != null) await prefs.setInt('best_room', bestFloor);
    }
    bestTime = prefs.getDouble('best_time_$kFloorsVersion');
    vibrationOn = prefs.getBool('vibration') ?? true;
    audio.musicOn = prefs.getBool('music') ?? true;
    audio.sfxOn = prefs.getBool('sfx') ?? true;
    unawaited(audio.init());
    selectHero(prefs.getInt('hero') ?? kOzod, save: false);

    // The menu is already on screen; open it at the furthest floor reached.
    phase = Phase.menu;
    previewFloor(furthestFloor);
    _ready = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.y > 0) W = size.x / size.y * 100;
    if (_ready) _buildPlatforms();
  }

  // ══════════════════════════════════════════════════════════════════════
  // Public API (called by Flutter overlays)
  // ══════════════════════════════════════════════════════════════════════
  /// Floor the current run started on. Only runs from the basement count
  /// towards the best graduation time.
  int startFloor = 0;
  bool get fullRun => startFloor == 0;

  /// A floor can be picked from the menu once the student has reached it.
  bool isUnlocked(int f) => f <= bestFloor;
  bool isCleared(int f) => f < bestFloor;

  /// Floor highlighted in the main menu (shown live behind it).
  final menuFloor = ValueNotifier<int>(0);
  int get furthestFloor => bestFloor.clamp(0, kRooms.length - 1);

  /// Shows floor [f] behind the menu while the player is choosing.
  void previewFloor(int f) {
    if (phase != Phase.menu || !isUnlocked(f)) return;
    menuFloor.value = f;
    _setupFloor(f);
    // Stand the student and teacher in the open middle of the menu screen.
    player.x = W * 0.47;
    teacher
      ..x = W * 0.62
      ..facing = -1;
  }

  // ── Playable characters ────────────────────────────────────────────────
  int heroIndex = 0;
  HeroDef get hero => kHeroes[heroIndex];
  Paint _heroPaint = pixelPaint;
  bool isHeroUnlocked(int i) => bossesCleared >= kHeroes[i].unlockFloor;

  void selectHero(int i, {bool save = true}) {
    if (i < 0 || i >= kHeroes.length || !isHeroUnlocked(i)) i = 0;
    heroIndex = i;
    _heroPaint = huePaint(hero.hue);
    player
      ..maxHp = _maxHpFor
      ..hp = _maxHpFor
      ..anim = 'Idle'
      ..state = PState.idle
      ..t = 0;
    if (save) {
      SharedPreferences.getInstance().then((prefs) => prefs.setInt('hero', i));
    }
  }

  void startRun({int fromFloor = 0}) {
    isPaused = false;
    if (!isUnlocked(fromFloor)) fromFloor = 0;
    startFloor = fromFloor;
    perks.clear();
    _told.clear();
    // Starting further up: the notes from the floors below are remembered.
    for (final r in kRooms.take(fromFloor)) {
      if (r.isBoss && r.teacher < kLostNotes.length - 1) perks.add(kLostNotes[r.teacher]);
      if (r.gift) perks.add(kLostNotes.last);
    }
    player.maxHp = _maxHpFor;
    runTime = 0;
    hitsLanded = 0;
    maxCombo = 0;
    retries = 0;
    player
      ..hp = player.maxHp
      ..energy = 0;
    _setupFloor(fromFloor);
    if (fromFloor == 0 && _told.add('prologue')) {
      _tell(kPrologue, _enterRoom);
    } else {
      _enterRoom();
    }
  }

  /// Shows the right screen for the room the student just walked into.
  void _enterRoom() {
    // A story beat first, the first time this run.
    if (room.story.isNotEmpty && _told.add(room)) {
      _tell(room.story, _enterRoom);
      return;
    }
    if (room.kind == RoomKind.rest) {
      player.hp = player.maxHp; // Mira watches over you while you rest
      if (room.gift) _gotNote(kLostNotes.length - 1);
      phase = Phase.rest;
      audio.play('pickup');
      _showOnly('rest');
    } else {
      phase = Phase.intro;
      _showOnly('intro');
    }
  }

  /// Leave Mira's corner and head for the exit.
  void leaveRest() {
    if (phase != Phase.rest) return;
    phase = Phase.cleared;
    _showOnly('controls');
    _banner = 'EXIT →';
    _bannerTime = 1.6;
  }

  /// Shows [lines] in the story overlay, then runs [then].
  void _tell(List<StoryLine> lines, VoidCallback then) {
    story = lines;
    _afterStory = then;
    _storyFrom = phase;
    phase = Phase.story;
    left = right = false;
    _showOnly('story');
  }

  /// Called by the story overlay after its last line (or when skipped).
  void endStory() {
    if (phase != Phase.story) return;
    final then = _afterStory;
    _afterStory = null;
    story = const [];
    phase = _storyFrom;
    then?.call();
  }

  /// Lost Note [i] found: a memory comes back, and a power with it.
  void _gotNote(int i) {
    final perk = kLostNotes[i];
    if (!perks.add(perk)) return;
    if (perk == Perk.tea) {
      player
        ..maxHp = _maxHpFor
        ..hp = min(_maxHpFor, player.hp + 25);
    }
    final d = kPerks[perk]!;
    _floats.add(FloatText('📄 LOST NOTE ${perks.length}/${kLostNotes.length}', player.x, player.y - 40,
        const Color(0xFFFFF59D), size: 4, life: 2.4));
    _floats.add(FloatText('${d.emoji} ${d.name.toUpperCase()} · ${d.desc}', player.x, player.y - 34,
        const Color(0xFFFFD54F), size: 3, life: 2.6));
    _memory = kNoteMemories[i];
    _memoryTime = 4.5;
    _burst(player.x, player.y - 12, const Color(0xFFFFF59D), n: 24, speed: 50);
    audio.play('perk');
    _vibrate(60);
  }

  void beginFight() {
    _showOnly('controls');
    phase = Phase.fight;
    if (perks.contains(Perk.notes)) player.energy = max(player.energy, 50);
    if (_boss) {
      _banner = _scary ? 'SURVIVE.' : (def.twins.isNotEmpty ? 'TWO OF THEM!' : 'FIGHT!');
      if (_scary) {
        audio.play('laugh');
        _strikeLightning();
      }
      _bannerTime = 1.4;
      teacher.say(def.taunts[rng.nextInt(def.taunts.length)]);
    } else {
      _spawnWave(0);
    }
  }

  void retryFloor() {
    isPaused = false;
    retries++;
    player
      ..hp = player.maxHp
      ..energy = 50;
    _setupFloor(floor, round: round); // retake the round you lost
    _enterRoom();
  }

  void toMenu() {
    isPaused = false;
    phase = Phase.menu;
    previewFloor(furthestFloor);
    _showOnly('menu');
  }

  void pauseGame() {
    if (phase != Phase.fight && phase != Phase.cleared && phase != Phase.roundBreak) return;
    isPaused = true;
    left = right = false;
    overlays.add('pause');
    audio.duck(true);
  }

  void resumeGame() {
    isPaused = false;
    overlays.remove('pause');
    audio.duck(false);
  }

  void _showOnly(String name) {
    overlays.removeAll(kAllOverlays);
    overlays.add(name);
  }

  // ══════════════════════════════════════════════════════════════════════
  // Floors
  // ══════════════════════════════════════════════════════════════════════
  void _setupFloor(int i, {int round = 1}) {
    floor = i;
    escaping = false;
    _life.birds.clear();
    this.round = round;
    _roundBreak = 0;
    left = right = false;
    _projectiles.clear();
    _hazards.clear();
    _pickups.clear();
    _sparks.clear();
    _floats.clear();
    _minions.clear();
    comboCount = 0;
    _buildPlatforms();
    player
      ..x = 16
      ..y = kGround
      ..vx = 0
      ..vy = 0
      ..onGround = true
      ..jumpsLeft = 2
      ..facing = 1
      ..state = PState.idle
      ..anim = 'Idle'
      ..t = 0
      ..invuln = 0
      ..slow = 0
      ..dashT = 0
      ..rollT = 0
      ..rollCd = 0
      ..frenzy = 0
      ..queued = false;
    teacher = _newTeacher(W - 40);
    if (!_boss) {
      // No teacher in halls and rest stops.
      teacher
        ..hp = 0
        ..state = TState.dead
        ..anim = 'Dead';
    }
    wave = 0;
    _waveDelay = 0;
    _setupNpcs();
    _lightsOut = 0;
    _lightning = 0;
    _lightningIn = 4;
    _flicker = 0;
    _laughIn = -1;
    _storyIn = 0;
    _memoryTime = 0;
    _bossFell = false;
    _color = _colorTarget;
    _still = 0;
    _fearHint = 0;
    _fearSwings = 0;
    _echoes.clear();
    _teacherPaint = _paintFor();
    _pickupTimer = 12;
    _gameOverDelay = -1;
    _banner = '';
    _bannerTime = 0;
    _slowMo = 0;
    _hitStop = 0;
    energy.value = player.energy;
  }

  Teacher _newTeacher(double x) {
    final t = Teacher(def, x, kGround)..cooldown = 1.6;
    // The fear bar: how big the Reaper still is.
    t.maxHp = fearPhase ? 100 : (round > 1 ? (def.hp * 1.3).roundToDouble() : def.hp.toDouble());
    t.hp = t.maxHp;
    return t;
  }

  static final _shadowPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFF3A3150), BlendMode.modulate);
  static final _fearPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = const ColorFilter.mode(Color(0xFFFF6E6E), BlendMode.modulate);

  Paint _paintFor() => fearPhase
      ? _fearPaint
      : def.shadow
          ? _shadowPaint
          : huePaint(def.hue);

  void _buildPlatforms() {
    _platforms = [
      for (final p in def.platforms) Platform(p.x * W, kGround - p.h, p.w * W),
    ];
  }

  void _goUpstairs() {
    if (isLastFloor && escaping) {
      _win();
      return;
    }
    phase = Phase.transition;
    _fadingOut = true;
    audio.play('door');
    overlays.remove('controls');
    left = right = false;
  }

  void _arriveNextFloor() {
    if (isLastFloor) {
      _beginEscape();
      return;
    }
    final hp = player.hp, en = player.energy;
    _setupFloor(floor + 1);
    player
      ..hp = min(player.maxHp, hp + 20)
      ..energy = en;
    if (floor > bestFloor) {
      bestFloor = floor;
      _save();
    }
    _enterRoom();
  }

  /// The Grade Reaper is beaten: the walls fade and the student walks into
  /// the morning light. Reaching the far side wakes him up.
  void _beginEscape() {
    final hp = player.hp, en = player.energy;
    _setupFloor(floor, round: round);
    escaping = true;
    teacher
      ..hp = 0
      ..state = TState.dead
      ..anim = 'Dead';
    _setupNpcs();
    _cam = -0.5;
    player
      ..hp = hp
      ..energy = en;
    phase = Phase.cleared;
    _showOnly('controls');
    _banner = 'WAKE UP →';
    _bannerTime = 2.6;
    audio.play('perfect');
  }

  void _win() {
    left = right = false;
    bestFloor = kRooms.length;
    if (fullRun && (bestTime == null || runTime < bestTime!)) bestTime = runTime;
    _save();
    audio.play('graduate');
    _tell(kEnding, () {
      phase = Phase.victory;
      _showOnly('victory');
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best_room', bestFloor);
    if (bestTime != null) await prefs.setDouble('best_time_$kFloorsVersion', bestTime!);
  }

  // ══════════════════════════════════════════════════════════════════════
  // Update
  // ══════════════════════════════════════════════════════════════════════
  @override
  void update(double dt) {
    if (!_ready) return;
    audio.music(_wantedTrack);
    if (isPaused) return;
    dt = min(dt, 1 / 30);
    _clock += dt;

    if (_fadingOut) {
      _fade += dt * 2.2;
      if (_fade >= 1) {
        _fade = 1;
        _fadingOut = false;
        _arriveNextFloor();
      }
      return;
    } else if (_fade > 0) {
      _fade = max(0, _fade - dt * 2);
    }

    if (_shake > 0) _shake = max(0, _shake - dt * 12);
    if (_hitStop > 0) {
      _hitStop -= dt;
      return;
    }
    if (_slowMo > 0) {
      _slowMo -= dt;
      dt *= 0.3;
    }
    if (phase == Phase.fight || phase == Phase.cleared || phase == Phase.roundBreak) runTime += dt;

    if (phase == Phase.roundBreak) {
      _roundBreak -= dt;
      if (_roundBreak <= 0) _startNextRound();
    }
    if (phase == Phase.fight && _boss && fearPhase) _updateFear(dt);
    if (_storyIn > 0 && phase == Phase.cleared) {
      _storyIn -= dt;
      if (_storyIn <= 0) _tell(room.after, () => _showOnly('controls'));
    }
    if (_memoryTime > 0) _memoryTime -= dt;
    for (final e in _echoes) {
      e.t += dt;
    }
    _echoes.removeWhere((e) => e.t > 1.6);

    _updatePlayer(dt);
    _updateTeacher(dt);
    _updateMinions(dt);
    if (phase == Phase.fight && room.kind == RoomKind.hall) _updateWaves(dt);
    _updateProjectiles(dt);
    _updateHazards(dt);
    _updatePickups(dt);
    _updateFx(dt);

    _jumpQ = _attackQ = _specialQ = _rollQ = false;
    energy.value = player.energy;
    if (_bannerTime > 0) _bannerTime -= dt;
    _updateAtmosphere(dt);
    _updateVibe(dt);
    _updateScene(dt);
    if (_comboPop > 0) _comboPop = max(0, _comboPop - dt * 4);
    if (comboCount > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) comboCount = 0;
    }

    if (_gameOverDelay > 0) {
      _gameOverDelay -= dt;
      if (_gameOverDelay <= 0) _showOnly('gameOver');
    }

    // The exit waits for the story and for a dropped Lost Note to reach you.
    if (phase == Phase.cleared &&
        player.x > W - 15 &&
        player.onGround &&
        _storyIn <= 0 &&
        !_pickups.any((pk) => pk.kind == PickupKind.note)) {
      _goUpstairs();
    }
  }

  // ── Player ──────────────────────────────────────────────────────────────
  void _setP(PState s, String anim) {
    final p = player;
    if (p.state == s && p.anim == anim) return;
    p
      ..state = s
      ..anim = anim
      ..t = 0;
  }

  void _startSwing(int combo) {
    audio.play(hero.attack == HeroAttack.magic ? 'magic' : 'swing');
    player
      ..state = PState.attack
      ..combo = combo
      ..anim = hero.swings[combo].anim
      ..t = 0
      ..hitDone = false
      ..queued = false;
  }

  void _updatePlayer(double dt) {
    final p = player;
    p.t += p.state == PState.attack ? dt * hero.attackSpeed * (p.frenzy > 0 ? 1.6 : 1) : dt;
    if (p.rollCd > 0) p.rollCd -= dt;
    if (p.frenzy > 0) {
      p.frenzy -= dt;
      if (rng.nextDouble() < 0.4) {
        _sparks.add(Spark(p.x + (rng.nextDouble() - 0.5) * 8, p.y - rng.nextDouble() * 20, 0, -25, 0.4, 0.9,
            const Color(0xFFFF5252)));
      }
    }
    if (p.invuln > 0) p.invuln -= dt;
    if (p.slow > 0) p.slow -= dt;
    final control = phase == Phase.fight || phase == Phase.cleared || phase == Phase.roundBreak;

    int dir = 0;
    if (control && p.state != PState.hurt && p.state != PState.dead) {
      if (left) dir -= 1;
      if (right) dir += 1;
    }

    // Horizontal movement
    if (p.state == PState.hurt || p.state == PState.dead) {
      p.vx *= pow(0.03, dt);
    } else {
      p.vx = dir * hero.speed * (p.slow > 0 ? 0.5 : 1) * (p.frenzy > 0 ? 1.35 : 1) * _speedMul;
      if (p.state == PState.attack || p.state == PState.special) p.vx *= 0.55;
    }
    if (p.rollT > 0) {
      p.rollT -= dt;
      p.vx = p.facing * 165.0;
      if (rng.nextBool()) {
        _sparks.add(Spark(p.x, p.y - 3 - rng.nextDouble() * 12, -p.facing * 30.0, -5, 0.25, 1.1,
            Colors.white.withValues(alpha: 0.7)));
      }
    }
    if (p.dashT > 0) {
      p.dashT -= dt;
      for (final m in _minions) {
        if (m.state != MState.dead && !p.dashHits.contains(m) && p.rect.inflate(4).overlaps(m.rect)) {
          p.dashHits.add(m);
          _hitMinion(m, 25, p.x, unblockable: true);
        }
      }
      p.vx = p.facing * 230.0;
      _sparks.add(Spark(p.x, p.y - 6 - rng.nextDouble() * 14, -p.facing * 20.0, 0, 0.25, 1.4, hero.color));
      if (!p.dashHit && phase == Phase.fight && teacher.state != TState.dead &&
          p.rect.inflate(4).overlaps(teacher.rect)) {
        p.dashHit = true;
        _damageTeacher(32, p.facing * 30.0);
      }
      for (final pr in _projectiles) {
        if (!pr.fromPlayer && pr.destructible && p.rect.inflate(pr.r + 2).contains(Offset(pr.x, pr.y))) {
          pr.dead = true;
        }
      }
    }
    if (!p.busy && dir != 0) p.facing = dir;
    if (teacher.pullTime > 0 && p.state != PState.dead) {
      p.vx += (teacher.x > p.x ? 1 : -1) * 40;
    }

    // Jump / double jump
    if (control && _jumpQ && p.state != PState.hurt && p.state != PState.dead && p.jumpsLeft > 0) {
      p.vy = -(p.jumpsLeft == 2 ? kJumpSpeed : kJumpSpeed * 0.85);
      p.jumpsLeft--;
      p.onGround = false;
      _burst(p.x, p.y, const Color(0xFFBCAAA4), n: 6, speed: 30);
      audio.play('jump');
    }

    // Integrate
    final prevY = p.y;
    p.vy += kGravity * dt;
    p.x = (p.x + p.vx * dt).clamp(6.0, W - 6);
    p.y += p.vy * dt;
    final land = _landY(p.x, prevY, p.y, p.vy);
    if (land != null) {
      if (!p.onGround && p.vy > 120) _burst(p.x, land, const Color(0xFFBCAAA4), n: 5, speed: 25);
      p
        ..y = land
        ..vy = 0
        ..onGround = true
        ..jumpsLeft = 2;
    } else {
      p.onGround = false;
    }

    // Dodge roll: a quick dash with invincibility frames.
    if (control && _rollQ && p.rollCd <= 0 && p.state != PState.hurt && p.state != PState.dead &&
        p.state != PState.special && p.state != PState.roll) {
      if (dir != 0) p.facing = dir;
      p
        ..state = PState.roll
        ..anim = _heroAnims.containsKey('Roll') ? 'Roll' : 'Run'
        ..t = 0
        ..rollT = 0.3
        ..rollCd = 0.75
        ..perfectDodged = false
        ..invuln = max(p.invuln, 0.36)
        ..queued = false;
      _burst(p.x, p.y - 2, const Color(0xFFBCAAA4), n: 6, speed: 35);
      audio.play('roll');
    }

    // Actions
    if (control && _specialQ && p.energy >= 100 && p.state != PState.hurt && p.state != PState.dead &&
        p.state != PState.special && p.state != PState.roll) {
      p
        ..state = PState.special
        ..anim = 'Attack_4'
        ..t = 0
        ..hitDone = false;
    } else if (control && _attackQ) {
      if (p.state == PState.attack || p.state == PState.roll) {
        p.queued = true; // attack as soon as the swing / roll finishes
      } else if (!p.busy) {
        _startSwing(0);
      }
    }

    switch (p.state) {
      case PState.attack:
        final sw = hero.swings[p.combo];
        if (!p.hitDone && p.t >= sw.hitTime) {
          p.hitDone = true;
          hero.attack == HeroAttack.magic ? _castBolt(sw) : _swordHit(sw);
        }
        if (_heroAnims[sw.anim]!.isDone(p.t)) {
          if (p.queued) {
            _startSwing((p.combo + 1) % hero.swings.length);
          } else {
            _setP(PState.idle, 'Idle');
          }
        }
      case PState.special:
        if (!p.hitDone && p.t >= (hero.special == HeroSpecial.dash ? 0.08 : 0.22)) {
          p.hitDone = true;
          _launchSpecial();
        }
        if (hero.special == HeroSpecial.combo && p.hitDone) {
          // Six quick hits while the combo animation plays.
          final due = min(6, ((p.t - 0.05) / 0.09).floor());
          while (p.multi < due) {
            p.multi++;
            _swordHit(const Swing('Attack_4', 0, 7, 6), unblockable: true);
          }
          p.vx = p.facing * 30.0;
        }
        if (_heroAnims['Attack_4']!.isDone(p.t) && p.dashT <= 0) _setP(PState.idle, 'Idle');
      case PState.roll:
        if (p.rollT <= 0) {
          if (p.queued) {
            _startSwing(0);
          } else {
            _setP(PState.idle, 'Idle');
          }
        }
      case PState.hurt:
        if (p.t >= 0.35) _setP(PState.idle, 'Idle');
      case PState.dead:
        break;
      default:
        if (!p.onGround) {
          _setP(PState.jump, 'Jump');
        } else if (dir != 0) {
          _setP(PState.run, 'Run');
        } else {
          _setP(PState.idle, 'Idle');
        }
    }
  }

  /// Mage attack: a magic bolt instead of a sword swing.
  void _castBolt(Swing sw) {
    final p = player;
    _projectiles.add(Projectile(
      kind: ProjKind.orb,
      x: p.x + p.facing * 8,
      y: p.y - 13,
      vx: p.facing * 140.0,
      r: 2.6,
      dmg: sw.dmg,
      fromPlayer: true,
      destructible: false,
      color: hero.color,
      life: 1.4,
    ));
    _burst(p.x + p.facing * 8, p.y - 13, hero.color, n: 4, speed: 30);
  }

  void _swordHit(Swing sw, {bool unblockable = false}) {
    final p = player;
    final reach = hero.reach;
    final box = Rect.fromLTWH(p.facing > 0 ? p.x - 2 : p.x - reach + 2, p.y - 26, reach, 25);
    for (final m in _minions) {
      if (m.state != MState.dead && box.overlaps(m.rect)) {
        _hitMinion(m, sw.dmg.toDouble(), p.x, unblockable: unblockable);
      }
    }
    final tipX = p.x + p.facing * 14;
    for (var i = 0; i < 4; i++) {
      _sparks.add(Spark(tipX, p.y - 12 + rng.nextDouble() * 6 - 3, p.facing * (40 + rng.nextDouble() * 40),
          rng.nextDouble() * 20 - 10, 0.18, 0.8, Colors.white));
    }
    if (phase == Phase.fight && teacher.state != TState.dead && box.overlaps(teacher.rect)) {
      _damageTeacher(sw.dmg.toDouble(), sw.knock * p.facing);
    }
    for (final pr in _projectiles) {
      if (pr.fromPlayer || !pr.destructible || pr.dead) continue;
      if (box.inflate(pr.r).contains(Offset(pr.x, pr.y))) {
        pr.dead = true;
        _charge(6);
        _burst(pr.x, pr.y, pr.color, n: 8);
        audio.play('block');
        _floats.add(FloatText('SLASH!', pr.x, pr.y - 4, Colors.white, size: 3));
      }
    }
  }

  void _launchSpecial() {
    final p = player;
    p.energy = 0;
    switch (hero.special) {
      case HeroSpecial.wave:
        _projectiles.add(Projectile(
          kind: ProjKind.wave,
          x: p.x + p.facing * 8,
          y: p.y - 12,
          vx: p.facing * 150.0,
          r: 7,
          dmg: 35,
          fromPlayer: true,
          destructible: false,
          glyph: 'A+',
          color: hero.color,
          life: 2,
        ));
      case HeroSpecial.combo:
        p
          ..multi = 0
          ..invuln = max(p.invuln, 0.7);
      case HeroSpecial.iaido:
        _iaido();
      case HeroSpecial.blade:
        _projectiles.add(Projectile(
          kind: ProjKind.boomerang,
          x: p.x + p.facing * 8,
          y: p.y - 12,
          vx: p.facing * 170.0,
          r: 6,
          dmg: 18,
          fromPlayer: true,
          destructible: false,
          color: hero.color,
          life: 2.4,
          phase: p.facing.toDouble(),
        ));
      case HeroSpecial.frenzy:
        p
          ..frenzy = 6
          ..hp = min(p.maxHp, p.hp + 10);
      case HeroSpecial.dash:
        p.dashHits.clear();
        p
          ..dashT = 0.32
          ..dashHit = false
          ..invuln = max(p.invuln, 0.5);
      case HeroSpecial.nova:
        for (final ang in const [-0.32, 0.0, 0.32]) {
          _projectiles.add(Projectile(
            kind: ProjKind.wave,
            x: p.x + p.facing * 8,
            y: p.y - 12,
            vx: p.facing * 140 * cos(ang),
            vy: 140 * sin(ang),
            r: 6,
            dmg: 16,
            fromPlayer: true,
            destructible: false,
            glyph: '✦',
            color: hero.color,
            life: 2,
          ));
        }
        p.hp = min(p.maxHp, p.hp + 10);
    }
    _shake = max(_shake, 3);
    _floats.add(FloatText(hero.specialName.toUpperCase(), p.x, p.y - 32, hero.color, size: 4.5, life: 1.2));
    _burst(p.x + p.facing * 8, p.y - 12, hero.color, n: 20, speed: 70);
    _vibrate(60);
    audio.play('power');
  }

  /// Samurai special: blink behind the teacher, slashing everything on the way.
  void _iaido() {
    final p = player, t = teacher;
    final fromX = p.x;
    if (phase == Phase.fight && t.state != TState.dead) {
      final side = p.x < t.x ? 1 : -1;
      p.x = (t.x + side * 16).clamp(6.0, W - 6);
      p.facing = -side;
      _damageTeacher(34, side * 20.0);
    } else {
      p.x = (p.x + p.facing * 50).clamp(6.0, W - 6);
    }
    p.invuln = max(p.invuln, 0.6);
    final lo = min(fromX, p.x), hi = max(fromX, p.x);
    for (final m in _minions) {
      if (m.state != MState.dead && m.x >= lo - 6 && m.x <= hi + 6) _hitMinion(m, 25, fromX, unblockable: true);
    }
    for (double x = lo; x <= hi; x += 3) {
      _sparks.add(Spark(x, p.y - 12 + rng.nextDouble() * 4 - 2, 0, 0, 0.35, 1.2, hero.color));
    }
    _hitStop = 0.1;
  }

  void _hurtPlayer(int dmg, double fromX) {
    final p = player;
    if (p.state == PState.dead || phase != Phase.fight) return;
    if (p.invuln > 0) {
      // Dodged something mid-roll: reward it.
      if (p.rollT > 0 && !p.perfectDodged) {
        p.perfectDodged = true;
        _charge(15);
        _slowMo = max(_slowMo, 0.35);
        audio.play('perfect');
        _floats.add(FloatText('PERFECT DODGE!', p.x, p.y - 30, const Color(0xFF80D8FF), size: 3.8, life: 1));
      }
      return;
    }
    if (_brave) {
      // Standing still in front of your fear: it can't touch you.
      if (_noFearCd <= 0) {
        _noFearCd = 0.7;
        _floats.add(FloatText('NO FEAR', p.x, p.y - 30, const Color(0xFFFFF59D), size: 3.6, life: 0.9));
      }
      return;
    }
    if (perks.contains(Perk.hoodie)) dmg = max(1, (dmg * 0.8).round());
    comboCount = 0;
    p.hp -= dmg;
    p.invuln = 0.9;
    _floats.add(FloatText('-$dmg', p.x, p.y - 28, const Color(0xFFFF5252), size: 4.5));
    _burst(p.x, p.y - 12, const Color(0xFFFF5252), n: 10);
    _shake = max(_shake, 2.5);
    _vibrate(45);
    audio.play('hurt');
    if (p.hp <= 0) {
      p
        ..hp = 0
        ..state = PState.dead
        ..anim = 'Dead'
        ..t = 0
        ..vx = 0;
      phase = Phase.gameOver;
      left = right = false;
      overlays.remove('controls');
      _slowMo = 0.8;
      _gameOverDelay = 1.5;
      audio.play('gameover');
      teacher.say('See you at the RETAKE!', 4);
      for (final pr in _projectiles) {
        pr.dead = true;
      }
      for (final h in _hazards) {
        h.t = 1e9; // marks it done; removed safely after the hazard loop
      }
    } else {
      p
        ..state = PState.hurt
        ..anim = 'Hurt'
        ..t = 0
        ..vx = (p.x < fromX ? -1 : 1) * 55
        ..vy = -70
        ..onGround = false;
    }
  }

  // ── Teacher ─────────────────────────────────────────────────────────────
  void _setT(TState s, String anim) {
    final t = teacher;
    if (t.state == s && t.anim == anim) return;
    t
      ..state = s
      ..anim = anim
      ..t = 0;
  }

  void _updateTeacher(double dt) {
    if (!_boss) return;
    final t = teacher, p = player;
    t.t += dt;
    if (t.flash > 0) t.flash -= dt;
    if (t.speechTime > 0) t.speechTime -= dt;
    if (t.pullTime > 0) t.pullTime -= dt;
    if (t.teleportCd > 0) t.teleportCd -= dt;
    if (t.state == TState.dead) return;

    final fighting = phase == Phase.fight;
    if (t.state != TState.cast) t.facing = p.x < t.x ? -1 : 1;

    switch (t.state) {
      case TState.hurt:
        if (t.t >= 0.28) _setT(TState.idle, 'Idle');
      case TState.cast:
        if (!t.fired && t.t >= t.fireAt) {
          t.fired = true;
          if (fighting) _castAbility(t.casting!);
        }
        if (t.dash > 0) {
          t.dash -= dt;
          if (_tBody == 'Demon' && t.anim == 'Attack_4') {
            final f = _teacherAnims['Attack_4']!.frameAt(t.t).clamp(0, _demonDash.length - 1);
            t.x = (t.dashStartX + t.dashDir * _demonDash[f] * _demonPx).clamp(10.0, W - 12);
            for (var k = 0; k < 2; k++) {
              _sparks.add(Spark(t.x - t.dashDir * rng.nextDouble() * 20, t.chestY + rng.nextDouble() * 12 - 6,
                  -t.dashDir * 30, 0, 0.35, 1.3, const Color(0xFFFF1744)));
            }
          } else {
            t.x = (t.x + t.dashDir * t.dashSpeed * dt).clamp(10.0, W - 12);
            if (rng.nextBool()) _burst(t.x, t.y - 2, def.accent, n: 1, speed: 20);
          }
        }
        final anim = _teacherAnims[t.anim]!;
        if (t.dash <= 0 && t.t >= max(anim.duration, t.fireAt + 0.1)) {
          _setT(TState.idle, 'Idle');
          t.cooldown = def.cooldown *
              (t.rage ? 0.65 : 1) *
              (round > 1 ? 0.85 : 1) *
              _twinMul *
              (0.8 + rng.nextDouble() * 0.4);
        }
      default:
        if (!fighting) {
          _setT(TState.idle, 'Idle');
          break;
        }
        final dist = (p.x - t.x).abs();
        final speed = def.speed * (t.rage ? 1.3 : 1);
        double move = 0;
        if (dist < 12) {
          move = -t.facing.toDouble();
        } else if (dist > 60) {
          move = t.facing.toDouble();
        }
        t.x = (t.x + move * speed * dt).clamp(10.0, W - 12);

        // Cornered? Teleport to the other side of the room in a puff of magic.
        final cornered = t.x <= 10.5 || t.x >= W - 12.5;
        if (cornered && dist < 26 && t.teleportCd <= 0) {
          _burst(t.x, t.chestY, def.accent, n: 18, speed: 50);
          t.x = p.x < W / 2 ? W - 30 : 30;
          t.teleportCd = 4;
          _burst(t.x, t.chestY, def.accent, n: 18, speed: 50);
          t.say(def.scary ? 'You cannot run from me...' : 'Class dismissed... over THERE!', 1.4);
        }

        _setT(move != 0 ? TState.walk : TState.idle, move != 0 ? 'Walk' : 'Idle');

        // The Deadline Twins take turns.
        if (def.twins.isNotEmpty) {
          t.twinSwap -= dt;
          if (t.twinSwap <= 0) _swapTwins();
        }

        t.cooldown -= dt;
        if (t.cooldown <= 0) _startCast();

        t.tauntTimer -= dt;
        if (t.tauntTimer <= 0) {
          t.tauntTimer = 7 + rng.nextDouble() * 5;
          if (t.speechTime <= 0) t.say(def.taunts[rng.nextInt(def.taunts.length)]);
        }
    }

    // Touching the teacher hurts.
    // Shadow-teleport slash lands a moment after the demon reappears.
    if (t.pendingSlash > 0) {
      t.pendingSlash -= dt;
      if (t.pendingSlash <= 0) {
        final box = Rect.fromLTWH(t.facing > 0 ? t.x : t.x - 28, t.y - 30, 28, 30);
        _burst(t.x + t.facing * 14, t.chestY, const Color(0xFFFF1744), n: 14, speed: 60);
        audio.play('swing');
        if (fighting && box.overlaps(p.rect)) _hurtPlayer(14, t.x);
      }
    }
    if (fighting && t.rect.deflate(2).overlaps(p.rect)) _hurtPlayer(t.dash > 0 ? 14 : 8, t.x);
  }

  static const _bigAbilities = {
    Ability.appleRain,
    Ability.gravityPull,
    Ability.popQuiz,
    Ability.grammarShout,
    Ability.syntaxLaser,
    Ability.bugSwarm,
    Ability.beeSwarm,
    Ability.vineTrap,
    Ability.charge,
    Ability.arrowVolley,
    Ability.earthquake,
    Ability.tornado,
    Ability.bassDrop,
    Ability.lullaby,
    Ability.marketCrash,
    Ability.tax,
    Ability.aiDrones,
    Ability.scanLaser,
    Ability.summon,
    Ability.shadowDash,
    Ability.bloodRain,
    Ability.shadowTeleport,
    Ability.lightsOut,
    Ability.redPen,
  };

  void _startCast() {
    final t = teacher;
    final close = (player.x - t.x).abs() < 26;
    // Sword teachers slash when the student is close; otherwise use a power.
    final ranged = _abilities.where((a) => a != Ability.slash).toList();
    Ability a;
    if (close && _abilities.contains(Ability.slash) && rng.nextDouble() < 0.7) {
      a = Ability.slash;
    } else {
      a = ranged[rng.nextInt(ranged.length)];
      if (a == t.casting && ranged.length > 1) a = ranged[rng.nextInt(ranged.length)];
      // Don't flood the room with minions.
      if (a == Ability.summon && minionCount >= 3 && ranged.length > 1) {
        a = ranged.where((x) => x != Ability.summon).elementAt(rng.nextInt(ranged.length - 1));
      }
    }
    _startCastWith(a);
  }

  void _startCastWith(Ability a) {
    final t = teacher;
    final big = _bigAbilities.contains(a);
    final animName = switch (a) {
      Ability.slash => rng.nextBool() ? 'Attack_2' : 'Attack_3',
      Ability.shadowDash => 'Attack_4',
      Ability.spinSlash || Ability.shadowTeleport || Ability.redPen => 'Attack_1',
      // The demon's Attack_4 is its dash; it casts everything else with Attack_1.
      _ when _tBody == 'Demon' => 'Attack_1',
      _ => big ? 'Attack_4' : 'Attack_1',
    };
    final dur = _teacherAnims[animName]!.duration;
    t
      ..casting = a
      ..fired = false
      ..state = TState.cast
      ..anim = animName
      ..t = 0
      ..fireAt = a == Ability.slash ? dur * 0.5 : (big ? max(0.42, dur * 0.6) : max(0.24, dur * 0.55));
    // Villain moves: hold the first frame (negative time) as a readable wind-up.
    switch (a) {
      case Ability.shadowDash:
        t
          ..t = -0.55
          ..fireAt = 0;
        audio.play('laugh');
      case Ability.spinSlash:
        t
          ..t = -0.35
          ..fireAt = 0.29;
      case Ability.shadowTeleport:
        t
          ..t = -0.25
          ..fireAt = 0;
      default:
        break;
    }
    if (big) audio.play('cast');
    if (big) t.say('${def.abilityName(a).toUpperCase()}!', 1.3);
    // Phase 2: the shadow of a boss you beat rises behind the Reaper.
    final echo = round == 2 ? def.echoes[a] : null;
    t.echo = echo ?? -1;
    if (echo != null) {
      final e = kFloors[echo];
      _echoes.add(_Echo(e, (t.x - t.facing * 18).clamp(8.0, W - 8), t.facing));
      t.say('${e.name.toUpperCase()}… RISE!', 1.4);
      audio.play('laugh');
    }
  }

  // ── Deadline Twins ──────────────────────────────────────────────────────
  /// Attack speed of the twin on stage: hits on the other one made it stronger.
  double get _twinMul =>
      def.twins.isEmpty || !room.isBoss ? 1 : 1 / (1 + teacher.twinPower[teacher.twin] / 100).clamp(1.0, 1.8);

  /// Where the twin off stage waits: the far side from the one fighting.
  double get _twinSpot => teacher.x < W / 2 ? W - 28 : 28;

  void _swapTwins() {
    final t = teacher;
    _burst(t.x, t.chestY, def.accent, n: 18, speed: 50);
    t.twinPower[t.twin] = 0; // its turn is over; the power is spent
    t
      ..twin = 1 - t.twin
      ..x = _twinSpot
      ..twinSwap = 6 + rng.nextDouble() * 2
      ..cooldown = min(t.cooldown, 0.9);
    _burst(t.x, t.chestY, def.accent, n: 18, speed: 50);
    t.say(def.twinLines[t.twin], 2.2);
    final stronger = _twinMul < 0.95 ? ' · STRONGER!' : '';
    _floats.add(FloatText('${def.twins[t.twin].toUpperCase()}$stronger', t.x, t.y - 34 * t.s, def.accent,
        size: 3.6, life: 1.6));
    audio.play('cast');
  }

  // ── The Grade Reaper, unmasked ──────────────────────────────────────────
  double _still = 0, _fearHint = 0, _noFearCd = 0;
  int _fearSwings = 0;
  final _echoes = <_Echo>[];

  /// Standing still long enough in the fear phase.
  bool get _brave => _boss && fearPhase && phase == Phase.fight && _still >= 0.5;

  void _updateFear(double dt) {
    final p = player, t = teacher;
    if (_noFearCd > 0) _noFearCd -= dt;
    final still = !left && !right && p.onGround && p.state == PState.idle;
    _still = still ? _still + dt : 0;
    if (_brave) {
      // Every Lost Note makes him shrink faster.
      t.hp = max(0, t.hp - 9.0 * (1 + 0.25 * notesFound) * dt);
      if (rng.nextDouble() < dt * 25) {
        final a = rng.nextDouble() * pi * 2;
        _sparks.add(Spark(p.x + cos(a) * 10, p.y - 12 + sin(a) * 10, 0, -14, 0.6, 0.9, const Color(0xFFFFF59D)));
      }
      _fearHint = 0;
      if (t.hp <= 0) {
        _defeatTeacher();
        return;
      }
    } else {
      t.hp = min(t.maxHp, t.hp + 2.5 * dt); // running away feeds it
      _fearHint += dt;
      if (_fearHint > 9) {
        _fearHint = 0;
        _floats.add(FloatText('Mira: "Stand still, Ozod…"', p.x, p.y - 36, const Color(0xFFB2EBF2), size: 3.2, life: 2.8));
      }
    }
    t.size = 0.25 + 0.75 * (t.hp / t.maxHp);
  }

  /// Hitting your fear only makes it bigger.
  void _fearSwing() {
    final t = teacher;
    t.flash = 0.06;
    t.hp = min(t.maxHp, t.hp + 3);
    if (_noFearCd > 0) return;
    _noFearCd = 0.6;
    _fearSwings++;
    _floats.add(FloatText(_fearSwings >= 3 ? 'STOP RUNNING. STAND STILL.' : "YOU CAN'T KILL FEAR", t.x,
        t.y - 30 * t.s, const Color(0xFFFF8A80), size: 3.4, life: 1.4));
    if (_fearSwings == 3) {
      _banner = 'STAND STILL';
      _bannerTime = 2;
    }
  }

  void _damageTeacher(double dmg, double knock) {
    final t = teacher;
    if (t.state == TState.dead) return;
    if (fearPhase) {
      _fearSwing();
      return;
    }
    dmg *= _dmgMul;
    if (def.twins.isNotEmpty) t.twinPower[1 - t.twin] += dmg; // the other one gets stronger
    t.hp -= dmg;
    t.flash = 0.12;
    hitsLanded++;
    _addCombo();
    if (player.frenzy > 0) player.hp = min(player.maxHp, player.hp + 2);
    _charge(11);
    _floats.add(FloatText('-${dmg.round()}', t.x, t.y - 28 * t.s, Colors.white, size: 4.5));
    _burst(t.x, t.chestY, def.accent, n: 10);
    _hitStop = dmg >= 30 ? 0.12 : 0.05;
    _shake = max(_shake, dmg >= 30 ? 4 : 1.5);
    _vibrate(25);
    audio.play(dmg >= 30 ? 'hit_heavy' : 'hit');
    t.x = (t.x + knock * 0.2).clamp(10.0, W - 12);
    if (t.state != TState.cast) _setT(TState.hurt, 'Hurt');
    if (t.state == TState.hurt) t.t = 0;

    if (!t.rage && t.hp <= t.maxHp / 2) {
      t.rage = true;
      t.say(def.rage, 2.6);
      _banner = 'RAGE MODE!';
      _bannerTime = 1.6;
    }
    if (t.hp <= 0) isFinalRound ? _defeatTeacher() : _roundWon();
  }

  /// A round won (not the last): short break, then the boss returns stronger.
  void _roundWon() {
    final t = teacher;
    t
      ..hp = 0
      ..pullTime = 0
      ..dash = 0
      ..state = TState.dead
      ..anim = 'Dead'
      ..t = 0;
    t.say(def.breakLines[(round - 1).clamp(0, def.breakLines.length - 1)], 2.6);
    _killAllMinions();
    phase = Phase.roundBreak;
    _roundBreak = 2.8;
    for (final pr in _projectiles) {
      if (!pr.fromPlayer) pr.dead = true;
    }
    for (final h in _hazards) {
      h.t = 1e9; // marks it done; removed safely after the hazard loop
    }
    player.hp = min(player.maxHp, player.hp + 25);
    _floats.add(FloatText('+25 HP', player.x, player.y - 30, const Color(0xFF69F0AE), size: 4));
    _slowMo = 0.6;
    _shake = 4;
    _banner = rounds == 2 ? 'MIDTERM PASSED!' : 'PHASE $round CLEARED!';
    audio.play('midterm');
    _bannerTime = 2.4;
    _burst(t.x, t.chestY, def.accent, n: 30, speed: 80);
    _vibrate(120);
  }

  void _startNextRound() {
    final old = teacher;
    round++;
    teacher = _newTeacher(old.x)..cooldown = 1.2;
    teacher.say(def.lineFor(round), 3);
    _teacherPaint = _paintFor();
    phase = Phase.fight;
    _banner = rounds == 2 ? 'ROUND 2 · FINAL EXAM!' : 'PHASE $round · $roundName';
    audio.play('cast');
    _bannerTime = 1.8;
    _shake = 4;
    _burst(teacher.x, teacher.chestY, def.accent, n: 30, speed: 80);
    _burst(teacher.x, teacher.chestY, Colors.white, n: 15, speed: 50);
    if (fearPhase) {
      // The hood comes off.
      _still = 0;
      _fearHint = 0;
      _fearSwings = 0;
      teacher.cooldown = 2.5;
      _tell(kUnmasked, () {
        _showOnly('controls');
        _banner = 'STOP RUNNING.';
        _bannerTime = 2.4;
      });
      return;
    }
    _summon(2); // the final round starts with backup
  }

  void _defeatTeacher() {
    final t = teacher;
    t
      ..hp = 0
      ..pullTime = 0
      ..state = TState.dead
      ..anim = 'Dead'
      ..t = 0;
    t.say(def.defeat, 5);
    audio.play('victory');
    final nextBoss = kRooms.skip(floor + 1).where((r) => r.isBoss).firstOrNull;
    if (nextBoss != null && nextBoss.def.scary) _laughIn = 2.2; // ...something laughs upstairs
    _killAllMinions();
    phase = Phase.cleared;
    for (final pr in _projectiles) {
      if (!pr.fromPlayer) pr.dead = true;
    }
    for (final h in _hazards) {
      h.t = 1e9; // marks it done; removed safely after the hazard loop
    }
    _slowMo = 0.9;
    _shake = 5;
    _banner = isLastFloor ? 'FEAR FACED! → WAKE UP' : 'FLOOR BOSS DOWN! → NEXT';
    _bannerTime = 4;
    if (fearPhase) {
      // He shrinks until he is just a tiny red pen on the floor.
      t.size = 0.12;
      _floats.add(FloatText('🖊️', t.x, t.y - 4, Colors.white, size: 6, life: 6));
    }
    // A page of Ozod's notes flutters out.
    if (room.teacher < kLostNotes.length - 1) {
      _pickups.add(Pickup(PickupKind.note, t.x, t.y - 30)..note = room.teacher);
    }
    if (room.after.isNotEmpty) _storyIn = 3.2;
    if (!_bossFell) {
      _bossFell = true;
      if (_colorTarget < 1) {
        _floats.add(FloatText('THE WORLD REMEMBERS ITS COLOUR', W / 2, 26, const Color(0xFFB9F6CA), size: 2.6, life: 3));
      }
    }
    for (var i = 0; i < 40; i++) {
      final a = rng.nextDouble() * pi * 2, s = 30 + rng.nextDouble() * 80;
      _sparks.add(Spark(t.x, t.chestY, cos(a) * s, sin(a) * s - 40, 1.2, 1.2,
          [def.accent, const Color(0xFFFFD54F), Colors.white, const Color(0xFFFF4081)][i % 4]));
    }
    _pickups.add(Pickup(PickupKind.plov, t.x, t.y - 30));
    _vibrate(200);
  }

  // ── Abilities ───────────────────────────────────────────────────────────
  void _castAbility(Ability a) {
    if (const {Ability.grammarShout, Ability.earthquake, Ability.bassDrop}.contains(a)) audio.play('quake');
    final t = teacher, p = player;
    final ox = t.x + t.facing * 8 * t.s, oy = t.chestY;
    // Shadows of earlier bosses throw their own things.
    final fx = t.echo >= 0 ? kFloors[t.echo] : def;
    t.echo = -1;
    final acc = fx.accent;
    final dx = p.x - ox, dy = (p.y - 11) - oy;
    final len = max(0.001, sqrt(dx * dx + dy * dy));
    final ax = dx / len, ay = dy / len;

    switch (a) {
      case Ability.energyBall:
        _projectiles.add(Projectile(
            kind: ProjKind.orb, x: ox, y: oy, vx: ax * 95, vy: ay * 95, r: 3.5, dmg: 10,
            color: acc, glyph: fx.orb));
        if (t.rage) {
          _projectiles.add(Projectile(
              kind: ProjKind.orb, x: ox, y: oy, vx: ax * 70, vy: ay * 70 - 25, r: 3.5, dmg: 10,
              color: acc, glyph: fx.orb));
        }

      case Ability.appleRain:
        _rain(fx.rain, const Color(0xFFFF5252), t.rage ? 8 : 6, 9);

      case Ability.gravityPull:
        t.pullTime = t.rage ? 3.0 : 2.3;
        _floats.add(FloatText('GRAVITY!', t.x, t.y - 34, acc, size: 5, life: 1.2));

      case Ability.numberSpread:
        final glyphs = fx.glyphs;
        final base = atan2(ay, ax);
        final n = t.rage ? 7 : 5;
        for (var i = 0; i < n; i++) {
          final ang = base + (i - (n - 1) / 2) * 0.17;
          _projectiles.add(Projectile(
              kind: ProjKind.glyph, x: ox, y: oy, vx: cos(ang) * 85, vy: sin(ang) * 85, r: 3,
              dmg: 8, glyph: glyphs[rng.nextInt(glyphs.length)], color: acc));
        }

      case Ability.infinity:
        _projectiles.add(Projectile(
            kind: ProjKind.boomerang, x: ox, y: oy, vx: t.facing * 140.0, vy: ay * 20, r: 4.5,
            dmg: 11, glyph: fx.loop, color: acc, destructible: false, life: 3.2,
            phase: t.facing.toDouble()));

      case Ability.popQuiz:
        _spikes(fx.spike, acc, t.rage ? 4 : 3, roots: false);

      case Ability.potionLob:
        final n = t.rage ? 3 : 2;
        for (var i = 0; i < n; i++) {
          final tx = (p.x + (i - (n - 1) / 2) * 18 + rng.nextDouble() * 8 - 4).clamp(5.0, W - 5);
          const flight = 1.0, g = 150.0;
          _projectiles.add(Projectile(
              kind: ProjKind.potion, x: ox, y: oy, vx: (tx - ox) / flight,
              vy: (kGround - oy - 0.5 * g * flight * flight) / flight, gravity: g, r: 3.5, dmg: 8,
              glyph: '🧪', color: acc));
        }

      case Ability.bubbles:
        final n = t.rage ? 6 : 4;
        for (var i = 0; i < n; i++) {
          _projectiles.add(Projectile(
              kind: ProjKind.bubble, x: ox, y: oy - 6 + rng.nextDouble() * 12,
              vx: t.facing * (26 + i * 7.0), r: 4 + rng.nextDouble() * 1.5, dmg: 9, life: 6.5,
              phase: rng.nextDouble() * 6, color: acc));
        }

      case Ability.letterWave:
        final word = t.rage ? fx.words.last : fx.words.first;
        for (var i = 0; i < word.length; i++) {
          _projectiles.add(Projectile(
              kind: ProjKind.letter, x: ox - t.facing * i * 8, y: oy, vx: t.facing * 72.0, r: 3,
              dmg: 8, glyph: word[i], phase: i * 0.9, life: 5,
              color: i.isEven ? acc : const Color(0xFFFF5252)));
        }

      case Ability.grammarShout:
        final waves = t.rage ? 2 : 1;
        for (var k = 0; k < waves; k++) {
          _hazards.add(Hazard(
              kind: HazardKind.shockwave, x: t.x, y: kGround, w: 7, h: 9, warn: k * 0.6,
              active: 3, dmg: 12, vx: t.facing * 105.0, color: acc));
        }
        _shake = max(_shake, 3);
        _floats.add(FloatText(fx.shout, t.x, t.y - 36, acc, size: 6, life: 1.2));

      case Ability.bugSwarm:
        _swarm('🐛', ox, oy, t.rage ? 4 : 3);

      case Ability.beeSwarm:
        _swarm('🐝', ox, oy, t.rage ? 5 : 4);

      case Ability.vineTrap:
        _spikes('🌿', acc, t.rage ? 4 : 3, roots: true);

      case Ability.summon:
        _summon(t.rage ? 3 : 2);

      case Ability.shadowDash:
        t
          ..dashStartX = t.x
          ..dashDir = t.facing.toDouble()
          ..dash = _teacherAnims['Attack_4']!.duration;
        _shake = max(_shake, 3);

      case Ability.spinSlash:
        _burst(t.x, t.chestY, const Color(0xFFFF1744), n: 24, speed: 70);
        _shake = max(_shake, 2);
        audio.play('hit_heavy');
        if ((p.x - t.x).abs() < 30 && (p.y - t.y).abs() < 30) _hurtPlayer(15, t.x);

      case Ability.bloodRain:
        final n = t.rage ? 11 : 8;
        for (var i = 0; i < n; i++) {
          _projectiles.add(Projectile(
              kind: ProjKind.arrow, x: (p.x + (i - n / 2) * 11 + rng.nextDouble() * 4).clamp(3.0, W - 3),
              y: -6.0 - i * 7, vy: 60, gravity: 140, r: 2.6, dmg: 9, color: const Color(0xFFFF1744), life: 4));
        }
        _strikeLightning();

      case Ability.shadowTeleport:
        _burst(t.x, t.chestY, const Color(0xFF311B92), n: 20, speed: 50);
        final side = p.facing; // appear behind the student
        t
          ..x = (p.x - side * 16).clamp(10.0, W - 12)
          ..facing = side
          ..t = 0
          ..pendingSlash = 0.38;
        _burst(t.x, t.chestY, const Color(0xFF311B92), n: 20, speed: 50);
        audio.play('laugh');
        t.say('Behind you...', 1.2);

      case Ability.redPen:
        // Red "F" marks that burn the floor around the student.
        final n = t.rage || fearPhase ? 4 : 3;
        for (var i = 0; i < n; i++) {
          final x = (p.x + (i - (n - 1) / 2) * 22 + rng.nextDouble() * 6 - 3).clamp(6.0, W - 6);
          _hazards.add(Hazard(
              kind: HazardKind.puddle, x: x, y: _surfaceBelow(x, p.y - 1), w: 14, h: 3, warn: 0.7,
              active: 3.2, dmg: 9, color: const Color(0xFFFF1744), glyph: 'F'));
        }
        _floats.add(FloatText('F', t.x, t.y - 36 * t.s, const Color(0xFFFF1744), size: 8, life: 1));
        audio.play('swing');

      case Ability.lightsOut:
        _lightsOut = 5;
        for (var i = 0; i < 2 && minionCount < 4; i++) {
          final x = i.isEven ? 20.0 : W - 20;
          _minions.add(Minion(MinionKind.eye, x, 36, rng.nextDouble() * 6)..cd = 1.5);
        }
        audio.play('laugh');
        _strikeLightning();

      case Ability.slash:
        final box = Rect.fromLTWH(t.facing > 0 ? t.x : t.x - 24 * t.s, t.y - 24 * t.s, 24 * t.s, 24 * t.s);
        for (var i = 0; i < 5; i++) {
          _sparks.add(Spark(t.x + t.facing * 14, t.chestY + rng.nextDouble() * 8 - 4,
              t.facing * (40 + rng.nextDouble() * 40), rng.nextDouble() * 20 - 10, 0.2, 0.9, acc));
        }
        if (box.overlaps(p.rect)) _hurtPlayer(12, t.x);

      case Ability.charge:
        t
          ..dash = t.rage ? 0.75 : 0.55
          ..dashDir = t.facing.toDouble();
        _floats.add(FloatText('CHARGE!', t.x, t.y - 34, acc, size: 5, life: 1));

      case Ability.dodgeball:
        final n = t.rage ? 3 : 2;
        for (var i = 0; i < n; i++) {
          _projectiles.add(Projectile(
              kind: ProjKind.ball, x: ox, y: oy, vx: t.facing * (60.0 + i * 22), vy: -70.0 - i * 25,
              gravity: 220, r: 3.5, dmg: 10, glyph: fx.ball, color: acc, life: 4.5));
        }

      case Ability.arrowVolley:
        final n = t.rage ? 10 : 7;
        for (var i = 0; i < n; i++) {
          _projectiles.add(Projectile(
              kind: ProjKind.arrow, x: (p.x - t.facing * 20 + (i - n / 2) * 9).clamp(2.0, W - 2),
              y: -4.0 - i * 7, vx: t.facing * 22.0, vy: 50, gravity: 110, r: 2.5, dmg: 8, color: acc, life: 4));
        }

      case Ability.catapult:
        final n = t.rage ? 3 : 2;
        for (var i = 0; i < n; i++) {
          final tx = (p.x + (i - (n - 1) / 2) * 22 + rng.nextDouble() * 6 - 3).clamp(5.0, W - 5);
          const flight = 1.1, g = 150.0;
          _projectiles.add(Projectile(
              kind: ProjKind.rock, x: ox, y: oy, vx: (tx - ox) / flight,
              vy: (kGround - oy - 0.5 * g * flight * flight) / flight, gravity: g, r: 4, dmg: 11,
              color: const Color(0xFF9E9E9E)));
        }

      case Ability.earthquake:
        _shake = max(_shake, 6);
        for (final dir in const [-1.0, 1.0]) {
          _hazards.add(Hazard(
              kind: HazardKind.shockwave, x: t.x, y: kGround, w: 7, h: 8, active: 3, dmg: 11,
              vx: dir * 95, color: acc));
        }
        _rain('', const Color(0xFF8D6E63), t.rage ? 6 : 4, 9);
        _floats.add(FloatText('EARTHQUAKE!', t.x, t.y - 36, acc, size: 5, life: 1.2));

      case Ability.tornado:
        _hazards.add(Hazard(
            kind: HazardKind.tornado, x: t.x + t.facing * 10, y: kGround, w: 12, h: 44, warn: 0.3,
            active: t.rage ? 4.5 : 3.5, dmg: 10, vx: t.facing * 26.0, color: acc));

      case Ability.noteWave:
        const notes = ['♪', '♫', '♬', '♩'];
        final n = t.rage ? 8 : 6;
        for (var i = 0; i < n; i++) {
          _projectiles.add(Projectile(
              kind: ProjKind.letter, x: ox - t.facing * i * 8, y: oy - 2, vx: t.facing * 70.0, r: 3,
              dmg: 8, glyph: notes[i % notes.length], phase: i * 1.1, life: 5, color: acc));
        }

      case Ability.bassDrop:
        for (var k = 0; k < (t.rage ? 3 : 2); k++) {
          for (final dir in const [-1.0, 1.0]) {
            _hazards.add(Hazard(
                kind: HazardKind.shockwave, x: t.x, y: kGround, w: 7, h: 9, warn: k * 0.55,
                active: 3, dmg: 11, vx: dir * 100, color: acc));
          }
        }
        _shake = max(_shake, 4);
        _floats.add(FloatText('DROP THE BASS!', t.x, t.y - 36, acc, size: 5, life: 1.2));

      case Ability.lullaby:
        if (phase == Phase.fight) p.slow = t.rage ? 3.5 : 2.5;
        _floats.add(FloatText('Zzz... SLOWED', p.x, p.y - 30, const Color(0xFFB388FF), size: 3.6, life: 1.4));
        _projectiles.add(Projectile(
            kind: ProjKind.orb, x: ox, y: oy, vx: ax * 90, vy: ay * 90, r: 3.5, dmg: 9, color: acc, glyph: '♪'));

      case Ability.coinRain:
        _rain('💰', const Color(0xFFFFD54F), t.rage ? 9 : 7, 9);

      case Ability.marketCrash:
        // A wall of falling arrows with one safe gap.
        final gap = 18 + rng.nextDouble() * (W - 36);
        for (double x = 5; x < W - 3; x += 9) {
          if ((x - gap).abs() < 12) continue;
          _projectiles.add(Projectile(
              kind: ProjKind.apple, x: x, y: -6.0 - rng.nextDouble() * 6, gravity: 80, r: 3, dmg: 10,
              glyph: '⬇', color: const Color(0xFFFF1744), destructible: false, life: 5));
        }
        _floats.add(FloatText('📉 MARKET CRASH', W / 2, 24, const Color(0xFFFF1744), size: 5, life: 1.4));

      case Ability.tax:
        if (phase == Phase.fight) p.energy *= 0.5;
        _floats.add(FloatText('TAX! −50% ⚡', p.x, p.y - 30, const Color(0xFFFFD54F), size: 4, life: 1.4));
        _projectiles.add(Projectile(
            kind: ProjKind.orb, x: ox, y: oy, vx: ax * 100, vy: ay * 100, r: 3.5, dmg: 9, color: acc, glyph: '%'));

      case Ability.syntaxLaser:
        _laser('SyntaxError: unexpected student', const Color(0xFFFF1744));

      case Ability.scanLaser:
        _laser(fx.laser, acc);

      case Ability.aiDrones:
        _swarm('🤖', ox, oy, t.rage ? 4 : 3);

      case Ability.binaryWave:
        final n = t.rage ? 9 : 7;
        for (var i = 0; i < n; i++) {
          _projectiles.add(Projectile(
              kind: ProjKind.letter, x: ox - t.facing * i * 7, y: oy, vx: t.facing * 75.0, r: 3,
              dmg: 8, glyph: rng.nextBool() ? '1' : '0', phase: i * 0.8, life: 5, color: acc));
        }

      case Ability.emailSpam:
        final n = t.rage ? 7 : 5;
        for (var i = 0; i < n; i++) {
          _projectiles.add(Projectile(
              kind: ProjKind.letter, x: ox - t.facing * i * 9, y: oy - 2, vx: t.facing * 70.0, r: 3,
              dmg: 8, glyph: i.isEven ? '✉' : '@', phase: i * 1.0, life: 5,
              color: i.isEven ? Colors.white : acc));
        }
    }
  }

  /// Things falling from the ceiling around the student.
  void _rain(String glyph, Color color, int n, int dmg) {
    final p = player;
    for (var i = 0; i < n; i++) {
      _projectiles.add(Projectile(
        kind: ProjKind.apple,
        x: (p.x + (i - (n - 1) / 2) * 12 + rng.nextDouble() * 4).clamp(4.0, W - 4),
        y: -6.0 - i * 12,
        gravity: 140,
        r: 3.5,
        dmg: dmg,
        glyph: glyph,
        color: color,
        life: 5,
      ));
    }
  }

  /// Telegraphed spikes erupting under and around the student.
  void _spikes(String glyph, Color color, int n, {required bool roots}) {
    final p = player;
    for (var i = 0; i < n; i++) {
      final x = (p.x + (i - (n - 1) / 2) * 20).clamp(6.0, W - 6);
      _hazards.add(Hazard(
          kind: HazardKind.spike, x: x, y: _surfaceBelow(x, p.y - 1), w: 9, h: 24,
          warn: 0.75 + i * 0.12, active: 0.45, dmg: roots ? 9 : 12, color: color, glyph: glyph, roots: roots));
    }
  }

  /// Horizontal beam at the student's height, after a warning line.
  void _laser(String label, Color color) {
    final y = player.y - 11;
    _hazards.add(Hazard(
        kind: HazardKind.laser, x: W / 2, y: y + 3, w: W, h: 6, warn: 0.9, active: 0.35,
        dmg: 15, color: color, glyph: label));
  }

  /// Small homing critters.
  void _swarm(String glyph, double ox, double oy, int n) {
    final t = teacher;
    for (var i = 0; i < n; i++) {
      _projectiles.add(Projectile(
          kind: ProjKind.bug, x: ox, y: oy - 6 + i * 5, vx: t.facing * 40.0, vy: -30.0 + i * 20,
          r: 3, dmg: 8, glyph: glyph, color: def.accent, life: 4.5));
    }
  }

  // ── Room vibes: NPCs, particles, props, mood light ──────────────────────
  void _setupNpcs() {
    npcs.clear();
    _ambient.clear();
    _npcsCheered = false;
    var k = 0;
    for (final d in vibe.npcs) {
      // Don't clone the student you're playing, or the teacher you're fighting.
      if (!d.ghost && (d.body == hero.body || (_boss && d.body == def.body))) continue;
      if (!_bodies.containsKey(d.body)) continue;
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = d.hue == 0 ? null : huePaint(d.hue).colorFilter;
      npcs.add(Npc(d, d.x * W, paint)
        ..t = rng.nextDouble() * 2
        ..say(d.hello, 4.5, delay: 0.6 + k * 1.6));
      k++;
    }
  }

  void _updateVibe(double dt) {
    // NPCs hide during fights and come back to cheer when the room is clear.
    final hide = phase == Phase.fight || phase == Phase.roundBreak || phase == Phase.gameOver;
    for (final n in npcs) {
      n.t += dt;
      n.alpha = (n.alpha + (hide ? -dt * 3 : dt * 2)).clamp(0.0, 1.0);
      if (n.sayDelay > 0) {
        n.sayDelay -= dt;
      } else if (n.sayTime > 0) {
        n.sayTime -= dt;
      }
    }
    if (phase == Phase.cleared && !_npcsCheered && room.kind != RoomKind.rest) {
      _npcsCheered = true;
      var k = 0;
      for (final n in npcs) {
        n.say(n.def.cheer, 3.5, delay: 0.8 + k++ * 1.2);
      }
    }

    // Ambient particles
    for (final a in _ambient) {
      a.life -= dt;
      a.x += a.vx * dt;
      a.y += a.vy * dt;
      if (a.kind == Particle.leaves || a.kind == Particle.spores || a.kind == Particle.fireflies) {
        a.x += sin(_clock * 2 + a.phase) * 4 * dt;
      }
    }
    _ambient.removeWhere((a) => a.life <= 0 || a.y > 104 || a.y < 8);
    final v = vibe;
    final rate = switch (v.particle) {
      Particle.none => 0.0,
      Particle.rain => 80.0,
      Particle.code => 16.0,
      Particle.spores || Particle.data || Particle.embers || Particle.sparkles => 9.0,
      Particle.chalk || Particle.dust || Particle.steam || Particle.letters => 6.0,
      Particle.fireflies || Particle.leaves => 3.5,
      Particle.paper => 2.5,
    };
    if (_ambient.length < 90 && rng.nextDouble() < rate * dt) _spawnAmbient(v);
    if (v.particle == Particle.rain && _ambient.length < 90) _spawnAmbient(v);
  }

  void _spawnAmbient(RoomVibe v) {
    final x = rng.nextDouble() * W;
    final a = switch (v.particle) {
      Particle.dust => _Amb(v.particle, x, 18 + rng.nextDouble() * 60, rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1, 5),
      Particle.chalk => _Amb(v.particle, W / 2 + (rng.nextDouble() - 0.5) * 80, 50, rng.nextDouble() - 0.5, 6, 4),
      Particle.code => _Amb(v.particle, x, 16, 0, 22 + rng.nextDouble() * 10, 3)..glyph = rng.nextBool() ? '1' : '0',
      Particle.steam => _Amb(v.particle, W * (rng.nextBool() ? 0.3 : 0.7) + (rng.nextDouble() - 0.5) * 6, kGround - 10, 0,
          -6, 2.5),
      Particle.spores => _Amb(v.particle, x, kGround - rng.nextDouble() * 5, 0, -5 - rng.nextDouble() * 4, 6),
      Particle.data => _Amb(v.particle, x, kGround, 0, -10 - rng.nextDouble() * 8, 5),
      Particle.fireflies => _Amb(v.particle, x, 40 + rng.nextDouble() * 38, rng.nextDouble() * 4 - 2, rng.nextDouble() * 2 - 1, 6),
      Particle.leaves => _Amb(v.particle, x, 16, rng.nextDouble() * 4 - 2, 7 + rng.nextDouble() * 4, 9),
      Particle.paper => _Amb(v.particle, x, 16, rng.nextDouble() * 4 - 2, 6 + rng.nextDouble() * 3, 11),
      Particle.sparkles => _Amb(v.particle, x, 18 + rng.nextDouble() * 60, 0, 0, 1.2),
      Particle.letters => _Amb(v.particle, x, kGround, 0, -4, 6)..glyph = String.fromCharCode(65 + rng.nextInt(26)),
      Particle.embers => _Amb(v.particle, x, kGround, rng.nextDouble() * 4 - 2, -8 - rng.nextDouble() * 8, 3),
      Particle.rain => _Amb(v.particle, x + 10, 10 + rng.nextDouble() * 10, -14, 95, 1.2),
      Particle.none => null,
    };
    if (a == null) return;
    a.phase = rng.nextDouble() * 6;
    _ambient.add(a);
  }

  void _drawAmbient(Canvas c) {
    final col = vibe.particleColor;
    final paint = Paint();
    for (final a in _ambient) {
      final k = (a.life / a.maxLife).clamp(0.0, 1.0);
      final fade = min(1.0, min(k * 3, (1 - k) * 6));
      switch (a.kind) {
        case Particle.dust || Particle.chalk:
          paint.color = col.withValues(alpha: 0.35 * fade * (0.6 + 0.4 * sin(_clock * 3 + a.phase)));
          c.drawCircle(Offset(a.x, a.y), a.kind == Particle.chalk ? 0.3 : 0.25, paint);
        case Particle.code || Particle.letters:
          _text.draw(c, a.glyph, a.x, a.y, a.kind == Particle.code ? 2.6 : 3, col,
              alpha: (a.kind == Particle.code ? 0.35 : 0.22) * fade, weight: FontWeight.w700);
        case Particle.steam:
          paint.color = Colors.white.withValues(alpha: 0.13 * fade);
          c.drawCircle(Offset(a.x + sin(a.phase + a.life * 3) * 1.5, a.y), 1 + (1 - k) * 3, paint);
        case Particle.spores || Particle.fireflies || Particle.embers:
          final glow = a.kind == Particle.fireflies ? (0.5 + 0.5 * sin(_clock * 4 + a.phase)) : 1.0;
          paint.color = col.withValues(alpha: 0.25 * fade * glow);
          c.drawCircle(Offset(a.x, a.y), a.kind == Particle.embers ? 0.9 : 1.4, paint);
          paint.color = col.withValues(alpha: 0.85 * fade * glow);
          c.drawCircle(Offset(a.x, a.y), a.kind == Particle.embers ? 0.35 : 0.45, paint);
        case Particle.data:
          paint.color = col.withValues(alpha: 0.4 * fade);
          c.drawRect(Rect.fromCenter(center: Offset(a.x, a.y), width: 0.8, height: 0.8), paint);
        case Particle.leaves || Particle.paper:
          c.save();
          c.translate(a.x, a.y);
          c.rotate(a.phase + _clock * (a.kind == Particle.paper ? 1.5 : 2.5));
          paint.color = (a.kind == Particle.paper ? Colors.white : (a.phase > 3 ? const Color(0xFFFF9100) : const Color(0xFF76FF03)))
              .withValues(alpha: 0.7 * fade);
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: a.kind == Particle.paper ? 2 : 1.4, height: a.kind == Particle.paper ? 2.6 : 0.8), paint);
          c.restore();
        case Particle.sparkles:
          paint
            ..color = col.withValues(alpha: 0.8 * sin(k * pi))
            ..strokeWidth = 0.25;
          c.drawLine(Offset(a.x - 1, a.y), Offset(a.x + 1, a.y), paint);
          c.drawLine(Offset(a.x, a.y - 1), Offset(a.x, a.y + 1), paint);
        case Particle.rain:
          paint
            ..color = col.withValues(alpha: 0.45)
            ..strokeWidth = 0.25;
          c.drawLine(Offset(a.x, a.y), Offset(a.x - 0.5, a.y + 3.2), paint);
        case Particle.none:
          break;
      }
    }
  }

  void _drawTint(Canvas c) {
    final v = vibe;
    if (v.tint == null) return;
    var a = v.tintAlpha;
    if (v.props.contains(Prop.alarm)) a *= 1 + sin(_clock * 4); // red alarm pulse
    c.drawRect(Rect.fromLTWH(0, 0, W, 100), Paint()..color = v.tint!.withValues(alpha: a.clamp(0.0, 0.3)));
  }

  List<Decor> get _decor => kDecor[escaping ? 'escape' : room.label] ?? const [];

  /// Pixel-art set dressing (see decor.dart).
  void _drawDecor(Canvas c) {
    for (final d in _decor) {
      if (d.repeat) {
        final w = PixelArt.widthAt(d.sprite, d.h);
        for (var x = 0.0; x < W; x += w) {
          PixelArt.drawStanding(c, d.sprite, x + w / 2, d.y, d.h);
        }
        continue;
      }
      PixelArt.drawStanding(c, d.sprite, d.x * W, d.y, d.h, flip: d.flip);
    }
  }

  /// Candle light, drawn over the darkness so it still shows in dark rooms.
  void _drawDecorGlow(Canvas c) {
    for (final d in _decor) {
      if (!d.glow) continue;
      final flick = 0.8 + 0.2 * sin(_clock * 9 + d.x * 40) * sin(_clock * 5.3 + d.x * 17);
      final center = Offset(d.x * W, d.y - d.h * 0.75);
      c.drawCircle(center, d.h * 1.6 * flick, Paint()..color = const Color(0xFFFFB74D).withValues(alpha: 0.10));
      c.drawCircle(center, d.h * 0.8 * flick, Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.16));
    }
  }

  void _drawNpcs(Canvas c) {
    for (final n in npcs) {
      if (n.alpha <= 0.01) continue;
      final anim = _bodies[n.def.body]!['Idle']!;
      final ghost = n.def.ghost;
      n.paint.color = Colors.white.withValues(alpha: n.alpha * (ghost ? 0.6 + 0.12 * sin(_clock * 2.4) : 1));
      final faceLeft = player.x < n.x;
      if (ghost) {
        // Mira: a pale glow, floating just above the floor
        c.drawCircle(Offset(n.x, kGround - 11), 12,
            Paint()..color = const Color(0xFFB2EBF2).withValues(alpha: 0.10 * n.alpha));
      } else {
        _shadow(c, n.x, kGround, 8);
      }
      anim.draw(c, n.t, n.x, kGround, 21, flip: faceLeft, paint: n.paint);
      _text.draw(c, n.def.name, n.x, kGround - 25, 2.2, Colors.white70, alpha: n.alpha, weight: FontWeight.w700);
      if (n.sayDelay <= 0 && n.sayTime > 0) _bubble(c, n.text, n.x, kGround - 28, min(1, n.sayTime / 0.3) * n.alpha);
    }
  }

  /// Small speech bubble whose tail points down at ([x], [bottom]).
  void _bubble(Canvas c, String text, double x, double bottom, double alpha) {
    if (alpha <= 0.02) return;
    final tp = _text.get(text, 2.6, const Color(0xFF111111), weight: FontWeight.w800, maxWidth: min(60.0, W - 10));
    final w = tp.width + 4, h = tp.height + 2.6;
    final cx = x.clamp(w / 2 + 2, W - w / 2 - 2);
    final top = max(16.0, bottom - h - 2);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.92 * alpha);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2, top, w, h), const Radius.circular(1.6)), paint);
    c.drawPath(
        Path()
          ..moveTo(x - 1.2, top + h)
          ..lineTo(x + 1.2, top + h)
          ..lineTo(x, top + h + 2)
          ..close(),
        paint);
    if (alpha > 0.5) _text.paint(c, tp, Offset(cx - tp.width / 2, top + 1.3));
  }

  void _drawProps(Canvas c) {
    final outside = _scene != null;
    for (final pr in vibe.props) {
      if (outside && pr != Prop.plants) continue; // only potted plants make sense under the sky
      switch (pr) {
        case Prop.sunbeams:
          for (final wx in [W * 0.06, W * 0.80]) {
            c.drawPath(
                Path()
                  ..moveTo(wx, 52)
                  ..lineTo(wx + 24, 52)
                  ..lineTo(wx + 44, kGround)
                  ..lineTo(wx + 14, kGround)
                  ..close(),
                Paint()..color = const Color(0xFFFFF8E1).withValues(alpha: 0.06 + 0.02 * sin(_clock * 0.7)));
          }
        case Prop.lockers:
          for (var i = 0; i < 6; i++) {
            final x = W * 0.36 + i * 6.2;
            c.drawRect(Rect.fromLTWH(x, kGround - 22, 5.8, 22), Paint()..color = const Color(0xFF546E7A));
            c.drawRect(Rect.fromLTWH(x + 0.3, kGround - 21.5, 5.2, 21), Paint()..color = const Color(0xFF607D8B));
            for (var v = 0; v < 3; v++) {
              c.drawRect(Rect.fromLTWH(x + 1.2, kGround - 20 + v * 1.2, 3.4, 0.4), Paint()..color = Colors.black26);
            }
            c.drawRect(Rect.fromLTWH(x + 4.4, kGround - 12, 0.6, 2), Paint()..color = Colors.black45);
          }
        case Prop.desks:
          for (final f in const [0.3, 0.5, 0.7]) {
            final x = W * f;
            c.drawRect(Rect.fromLTWH(x - 7, kGround - 8, 14, 1.4), Paint()..color = const Color(0xFF8D6E63));
            c.drawRect(Rect.fromLTWH(x - 6, kGround - 6.6, 1, 6.6), Paint()..color = const Color(0xFF5D4037));
            c.drawRect(Rect.fromLTWH(x + 5, kGround - 6.6, 1, 6.6), Paint()..color = const Color(0xFF5D4037));
          }
        case Prop.posters:
          final colors = [const Color(0xFFE53935), const Color(0xFF1E88E5), const Color(0xFF43A047)];
          for (var i = 0; i < 3; i++) {
            final x = [W * 0.27, W * 0.68, W * 0.73][i], y = [56.0, 54.0, 62.0][i];
            c.drawRect(Rect.fromLTWH(x, y, 7, 9), Paint()..color = const Color(0xFFF5F5F5));
            c.drawRect(Rect.fromLTWH(x + 0.8, y + 0.8, 5.4, 3), Paint()..color = colors[i]);
            c.drawRect(Rect.fromLTWH(x + 0.8, y + 4.8, 5.4, 0.5), Paint()..color = Colors.black26);
            c.drawRect(Rect.fromLTWH(x + 0.8, y + 6, 3.8, 0.5), Paint()..color = Colors.black26);
          }
        case Prop.monitors:
          for (final f in const [0.3, 0.42, 0.58, 0.7]) {
            final x = W * f;
            final on = sin(_clock * 7 + f * 40) > -0.9;
            c.drawRect(Rect.fromLTWH(x - 6, kGround - 9, 12, 1.2), Paint()..color = const Color(0xFF424242));
            c.drawRect(Rect.fromLTWH(x - 4, kGround - 16, 8, 6), Paint()..color = const Color(0xFF212121));
            c.drawRect(Rect.fromLTWH(x - 3.4, kGround - 15.4, 6.8, 4.8),
                Paint()..color = vibe.particleColor.withValues(alpha: on ? 0.55 : 0.15));
            c.drawRect(Rect.fromLTWH(x - 0.5, kGround - 10, 1, 1), Paint()..color = const Color(0xFF212121));
          }
        case Prop.servers:
          for (final f in const [0.33, 0.64]) {
            final x = W * f;
            c.drawRect(Rect.fromLTWH(x, kGround - 30, 8, 30), Paint()..color = const Color(0xFF263238));
            for (var r = 0; r < 9; r++) {
              c.drawRect(Rect.fromLTWH(x + 0.8, kGround - 29 + r * 3.2, 6.4, 2.4), Paint()..color = const Color(0xFF37474F));
              final blink = sin(_clock * (3 + r) + f * 9 + r) > 0.2;
              c.drawCircle(Offset(x + 6, kGround - 27.8 + r * 3.2), 0.35,
                  Paint()..color = (r.isEven ? const Color(0xFF00E676) : const Color(0xFF40C4FF)).withValues(alpha: blink ? 1 : 0.2));
            }
          }
        case Prop.tables:
          for (final f in const [0.3, 0.7]) {
            final x = W * f;
            c.drawRect(Rect.fromLTWH(x - 9, kGround - 8, 18, 1.6), Paint()..color = const Color(0xFFA1887F));
            c.drawRect(Rect.fromLTWH(x - 1, kGround - 6.4, 2, 6.4), Paint()..color = const Color(0xFF6D4C41));
            c.drawArc(Rect.fromCenter(center: Offset(x - 4, kGround - 8), width: 5, height: 3.4), 0, pi, true,
                Paint()..color = const Color(0xFFFFB74D));
            c.drawArc(Rect.fromCenter(center: Offset(x + 4, kGround - 8), width: 5, height: 3.4), 0, pi, true,
                Paint()..color = const Color(0xFFFFCC80));
          }
        case Prop.bookshelves:
          final bookColors = [0xFFE53935, 0xFF1E88E5, 0xFF43A047, 0xFFFDD835, 0xFF8E24AA, 0xFFFF7043];
          for (final f in const [0.21, 0.67]) {
            final x = W * f, w = W * 0.12;
            c.drawRect(Rect.fromLTWH(x, 22, w, kGround - 22), Paint()..color = const Color(0xFF4E342E));
            for (var r = 0; r < 5; r++) {
              final y = 24 + r * 11.0;
              c.drawRect(Rect.fromLTWH(x + 0.8, y + 9, w - 1.6, 1), Paint()..color = const Color(0xFF6D4C41));
              var bx = x + 1.2;
              var i = r * 3;
              while (bx < x + w - 2) {
                final bw = 1.2 + (i * 7 % 5) * 0.25, bh = 6 + (i * 13 % 3).toDouble();
                c.drawRect(Rect.fromLTWH(bx, y + 9 - bh, bw, bh), Paint()..color = Color(bookColors[i % bookColors.length]));
                bx += bw + 0.25;
                i++;
              }
            }
          }
        case Prop.vines:
          final vine = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..color = const Color(0xFF33691E);
          for (double x = 4; x < W; x += 9.5) {
            final len = 10 + ((x * 7) % 16);
            final path = Path()..moveTo(x, 16);
            for (double y = 16; y < 16 + len; y += 2) {
              path.lineTo(x + sin(y * 0.4 + x + _clock * 0.8) * 1.2, y);
            }
            c.drawPath(path, vine);
            c.drawCircle(Offset(x + sin(len * 0.4 + x) * 1.2, 16 + len), 0.9, Paint()..color = const Color(0xFF558B2F));
          }
        case Prop.plants:
          for (final f in const [0.24, 0.76]) {
            final x = W * f;
            c.drawPath(
                Path()
                  ..moveTo(x - 3, kGround - 6)
                  ..lineTo(x + 3, kGround - 6)
                  ..lineTo(x + 2.2, kGround)
                  ..lineTo(x - 2.2, kGround)
                  ..close(),
                Paint()..color = const Color(0xFF8D6E63));
            for (var i = 0; i < 6; i++) {
              final a = -pi / 2 + (i - 2.5) * 0.4 + sin(_clock + i) * 0.05;
              c.drawOval(Rect.fromCenter(center: Offset(x + cos(a) * 4, kGround - 6 + sin(a) * 5), width: 3.4, height: 1.6),
                  Paint()..color = const Color(0xFF43A047));
            }
          }
        case Prop.hologrid:
          final grid = Paint()
            ..color = vibe.particleColor.withValues(alpha: 0.08)
            ..strokeWidth = 0.2;
          for (double x = 0; x < W; x += 8) {
            c.drawLine(Offset(x, 16), Offset(x, kGround), grid);
          }
          for (double y = 16; y < kGround; y += 8) {
            c.drawLine(Offset(0, y), Offset(W, y), grid);
          }
          final hy = 56 + sin(_clock * 1.5) * 1.5;
          c.drawRect(Rect.fromLTWH(W * 0.62, hy, 12, 8), Paint()..color = vibe.particleColor.withValues(alpha: 0.18));
          _text.draw(c, 'AI', W * 0.62 + 6, hy + 4, 3, vibe.particleColor, alpha: 0.6);
        case Prop.spotlights:
          for (final f in const [0.28, 0.72]) {
            final x = W * f, sweep = sin(_clock * 0.8 + f * 6) * 18;
            c.drawPath(
                Path()
                  ..moveTo(x - 1, 16)
                  ..lineTo(x + 1, 16)
                  ..lineTo(x + sweep + 10, kGround)
                  ..lineTo(x + sweep - 10, kGround)
                  ..close(),
                Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.08));
            c.drawOval(Rect.fromCenter(center: Offset(x + sweep, kGround), width: 20, height: 2),
                Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.12));
          }
        case Prop.curtains:
          final bw = min(W * 0.36, 84.0), bx = W / 2 - bw / 2;
          for (final x in [bx - 13, bx + bw + 1]) {
            c.drawRect(Rect.fromLTWH(x, 16, 12, kGround - 16), Paint()..color = const Color(0xFF8E0000));
            for (var i = 1; i < 4; i++) {
              c.drawRect(Rect.fromLTWH(x + i * 3, 16, 0.6, kGround - 16), Paint()..color = Colors.black26);
            }
          }
        case Prop.ticker:
          c.drawRect(Rect.fromLTWH(0, 16.5, W, 3.4), Paint()..color = const Color(0xCC000000));
          const msg = 'DUE ▲7:00   SLEEP ▼0h   PANIC ▲99%   COFFEE ▲∞   TOMORROW ▶ TOO LATE   TIME LEFT ▼2h   ';
          final tp = _text.get(msg, 2.4, const Color(0xFF00E676), weight: FontWeight.w700);
          final off = -(_clock * 10 % tp.width);
          for (var x = off; x < W; x += tp.width) {
            _text.paint(c, tp, Offset(x, 17));
          }
        case Prop.chandeliers:
          for (final f in const [0.3, 0.7]) {
            final x = W * f;
            c.drawLine(Offset(x, 16), Offset(x, 21), Paint()
              ..color = const Color(0xFFBCAAA4)
              ..strokeWidth = 0.3);
            c.drawCircle(Offset(x, 24), 6, Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.12 + 0.03 * sin(_clock * 3)));
            c.drawArc(Rect.fromCenter(center: Offset(x, 22), width: 9, height: 5), 0, pi, false,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 0.6
                  ..color = const Color(0xFFFFC107));
            for (var i = -2; i <= 2; i++) {
              c.drawCircle(Offset(x + i * 2, 22.6 - (i.abs() * 0.3)), 0.4, Paint()..color = const Color(0xFFFFF59D));
            }
          }
        case Prop.pillars:
          for (final f in const [0.215, 0.765]) {
            final x = W * f;
            c.drawRect(Rect.fromLTWH(x, 18, 6, kGround - 18), Paint()..color = const Color(0xFFD7CCC8));
            c.drawRect(Rect.fromLTWH(x - 1, 16, 8, 2.4), Paint()..color = const Color(0xFFBCAAA4));
            c.drawRect(Rect.fromLTWH(x - 1, kGround - 2.4, 8, 2.4), Paint()..color = const Color(0xFFBCAAA4));
            for (var i = 1; i < 3; i++) {
              c.drawRect(Rect.fromLTWH(x + i * 2, 18, 0.4, kGround - 20), Paint()..color = Colors.black12);
            }
          }
        case Prop.banners:
          for (final f in const [0.27, 0.71]) {
            final x = W * f, sway = sin(_clock + f * 10) * 0.6;
            c.drawPath(
                Path()
                  ..moveTo(x, 17)
                  ..lineTo(x + 6, 17)
                  ..lineTo(x + 6 + sway, 36)
                  ..lineTo(x + 3 + sway, 33)
                  ..lineTo(x + sway, 36)
                  ..close(),
                Paint()..color = def.accent.withValues(alpha: 0.85));
            _text.draw(c, '★', x + 3 + sway * 0.5, 24, 3, Colors.white);
          }
        case Prop.portraits:
          for (final f in const [0.26, 0.72]) {
            final x = W * f, y = 26.0;
            c.drawRect(Rect.fromLTWH(x - 5, y - 6, 10, 12), Paint()..color = const Color(0xFF8D6E63));
            c.drawRect(Rect.fromLTWH(x - 4, y - 5, 8, 10), Paint()..color = const Color(0xFF3E2723));
            c.drawCircle(Offset(x, y - 1), 2.6, Paint()..color = const Color(0xFFBCAAA4));
            // The eyes follow you...
            final look = ((player.x - x) / 60).clamp(-0.5, 0.5);
            for (final ex in [-1.0, 1.0]) {
              c.drawCircle(Offset(x + ex, y - 1.5), 0.55, Paint()..color = Colors.white);
              c.drawCircle(Offset(x + ex + look, y - 1.5), 0.3, Paint()..color = const Color(0xFFD50000));
            }
          }
        case Prop.alarm:
          final x = W / 2, a = _clock * 3;
          c.drawCircle(Offset(x, 17.5), 1.4, Paint()..color = const Color(0xFFFF1744));
          c.drawPath(
              Path()
                ..moveTo(x, 17.5)
                ..lineTo(x + cos(a) * 60 - 6, 17.5 + sin(a).abs() * 60)
                ..lineTo(x + cos(a) * 60 + 6, 17.5 + sin(a).abs() * 60)
                ..close(),
              Paint()..color = const Color(0xFFFF1744).withValues(alpha: 0.06));
      }
    }
  }

  // ── Atmosphere ──────────────────────────────────────────────────────────
  double get _demonPx => kCharHeight * def.scale / 23;

  void _strikeLightning() {
    _lightning = 0.18;
    _shake = max(_shake, 2);
    audio.play('thunder');
  }

  void _updateAtmosphere(double dt) {
    if (_lightning > 0) _lightning -= dt;
    if (_lightsOut > 0) _lightsOut -= dt;
    if (_flicker > 0) _flicker -= dt;
    if (_laughIn > 0) {
      _laughIn -= dt;
      if (_laughIn <= 0) {
        audio.play('laugh');
        _flicker = 0.5;
        _banner = '...?';
        _bannerTime = 1.5;
      }
    }
    final fighting = phase == Phase.fight || phase == Phase.roundBreak;
    // Villain room: random lightning
    if (_scary && fighting) {
      _lightningIn -= dt;
      if (_lightningIn <= 0) {
        _lightningIn = 5 + rng.nextDouble() * 5;
        _strikeLightning();
      }
    }
    // The Office of Deadlines: the lights flicker now and then (something is coming...)
    if (room.building == '5' && !_scary && fighting && rng.nextDouble() < dt * 0.12) _flicker = 0.12 + rng.nextDouble() * 0.15;
    // Low HP: heartbeat
    final p = player;
    if (phase == Phase.fight && p.state != PState.dead && p.hp < p.maxHp * 0.3) {
      _heartbeatIn -= dt;
      if (_heartbeatIn <= 0) {
        _heartbeatIn = p.hp < p.maxHp * 0.15 ? 0.75 : 1.1;
        audio.play('heartbeat');
      }
    } else {
      _heartbeatIn = 0;
    }
  }

  /// Darkness, lightning and the low-HP red pulse, drawn over the world.
  void _drawAtmosphere(Canvas c) {
    final p = player;
    if (_dark && phase != Phase.menu) {
      final r = (_lightsOut > 0 ? 26.0 : (_scary ? 62.0 : 48.0)) + sin(_clock * 3) * 2;
      final center = Offset(p.x, p.y - 12);
      c.drawRect(
        Rect.fromLTWH(-10, -10, W + 20, 120),
        Paint()
          ..shader = ui.Gradient.radial(center, r, [
            Colors.transparent,
            Colors.black.withValues(alpha: _lightsOut > 0 ? 0.92 : (_scary ? 0.6 : 0.72)),
          ], [
            0.55,
            1.0
          ]),
      );
    }
    if (_flicker > 0) {
      c.drawRect(Rect.fromLTWH(0, 0, W, 100), Paint()..color = Colors.black.withValues(alpha: 0.45));
    }
    // Facing your fear: a calm light grows around you while you stand still.
    if (_boss && fearPhase && phase == Phase.fight && _still > 0) {
      final k = (_still / 0.5).clamp(0.0, 1.0);
      c.drawCircle(Offset(p.x, p.y - 12), 10 + k * 6 + sin(_clock * 5) * 0.8,
          Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.10 + 0.14 * k));
    }
    if (_lightning > 0) {
      c.drawRect(Rect.fromLTWH(0, 0, W, 100),
          Paint()..color = Colors.white.withValues(alpha: (_lightning / 0.18).clamp(0.0, 1.0) * 0.55));
    }
    if (phase == Phase.fight && p.hp < p.maxHp * 0.3 && p.state != PState.dead) {
      final pulse = 0.5 + 0.5 * sin(_clock * (p.hp < p.maxHp * 0.15 ? 9 : 6));
      c.drawRect(
        Rect.fromLTWH(0, 0, W, 100),
        Paint()
          ..shader = ui.Gradient.radial(Offset(W / 2, 50), W * 0.6, [
            Colors.transparent,
            const Color(0xFFD50000).withValues(alpha: 0.18 + pulse * 0.22),
          ], [
            0.6,
            1.0
          ]),
      );
    }
  }

  // ── Monster halls ───────────────────────────────────────────────────────
  void _spawnWave(int i) {
    wave = i;
    final list = room.waves[i];
    for (var k = 0; k < list.length; k++) {
      final kind = list[k];
      final d = kMinions[kind]!;
      // The first wave comes through the far door; later ones from both sides.
      final fromLeft = i > 0 && k.isOdd;
      final x = fromLeft ? 8.0 + k * 3 : W - 8 - k * 3;
      final y = d.flying ? 34.0 + rng.nextDouble() * 12 : kGround;
      _minions.add(Minion(kind, x, y, rng.nextDouble() * 6)
        ..cd = 1.2 + rng.nextDouble()
        ..facing = fromLeft ? 1 : -1);
      _burst(x, y - d.height / 2, d.color, n: 12, speed: 45);
      _floats.add(FloatText(d.name, x, y - d.height - 4, d.color, size: 2.8, life: 1.2));
    }
    _banner = 'WAVE ${i + 1}/${room.waves.length}';
    audio.play('wave');
    _bannerTime = 1.3;
  }

  void _updateWaves(double dt) {
    if (minionCount > 0) {
      _waveDelay = 1.0;
      return;
    }
    _waveDelay -= dt;
    if (_waveDelay > 0) return;
    if (wave < room.waves.length - 1) {
      _spawnWave(wave + 1);
    } else {
      phase = Phase.cleared;
      _banner = 'ROOM CLEARED! → EXIT';
      audio.play('midterm');
      _bannerTime = 2.5;
      _slowMo = 0.5;
      _pickups.add(Pickup(rng.nextBool() ? PickupKind.somsa : PickupKind.coffee, W / 2, 20));
      _vibrate(120);
    }
  }

  // ── Combo ───────────────────────────────────────────────────────────────
  void _addCombo() {
    comboCount++;
    _comboTimer = 1.8;
    _comboPop = 1;
    maxCombo = max(maxCombo, comboCount);
    if (comboCount % 10 == 0) {
      _charge(15);
      _banner = switch (comboCount) { 10 => 'GREAT! +⚡', 20 => 'AMAZING! +⚡', _ => 'DREAM LEGEND! +⚡' };
      _bannerTime = 1.2;
    }
  }

  // ── Minions ─────────────────────────────────────────────────────────────
  void _summon(int n) {
    for (var i = 0; i < n; i++) {
      if (minionCount >= 4) break;
      final kind = def.minions[rng.nextInt(def.minions.length)];
      final d = kMinions[kind]!;
      final side = i.isEven ? -1 : 1;
      final x = (teacher.x + side * (12 + rng.nextDouble() * 14)).clamp(8.0, W - 8);
      final y = d.flying ? 40.0 + rng.nextDouble() * 10 : kGround;
      _minions.add(Minion(kind, x, y, rng.nextDouble() * 6)..cd = 0.8 + rng.nextDouble());
      _burst(x, y - d.height / 2, d.color, n: 14, speed: 50);
      _floats.add(FloatText(d.name, x, y - d.height - 4, d.color, size: 2.8, life: 1.2));
    }
  }

  @visibleForTesting
  Minion debugSpawnMinion(MinionKind kind, double x) {
    final d = kMinions[kind]!;
    final m = Minion(kind, x, d.flying ? 45 : kGround, 0)..cd = 5;
    _minions.add(m);
    return m;
  }

  @visibleForTesting
  void debugKillMinions() => _killAllMinions();

  /// Boss shadows currently rising behind the Reaper (tests).
  @visibleForTesting
  int get debugEchoes => _echoes.length;

  /// True while standing still has made the student fearless (tests).
  @visibleForTesting
  bool get debugBrave => _brave;
  void debugEscape() => _beginEscape();

  /// Makes the teacher cast [a] right now (tests).
  @visibleForTesting
  void debugCast(Ability a) {
    final t = teacher;
    t.facing = player.x < t.x ? -1 : 1;
    _startCastWith(a);
  }

  void _killAllMinions() {
    for (final m in _minions) {
      if (m.state == MState.dead) continue;
      _setM(m, MState.dead, 'Dead');
      m.dive = 0;
      _burst(m.x, m.y - m.def.height / 2, m.def.color, n: 10, speed: 40);
    }
  }

  void _setM(Minion m, MState s, String anim) {
    if (m.state == s && m.anim == anim) return;
    m
      ..state = s
      ..anim = anim
      ..t = 0;
  }

  /// Returns false when the hit was blocked.
  bool _hitMinion(Minion m, double dmg, double fromX, {bool unblockable = false}) {
    if (m.state == MState.dead) return false;
    final d = m.def;
    dmg *= _dmgMul;
    final stuck = m.state == MState.stunned;
    if (stuck) dmg *= 2; // punish the stuck mushroom
    final fromFront = (fromX - m.x).sign == m.facing.sign;
    if (d.shield && !unblockable && fromFront && m.state != MState.attack) {
      _setM(m, MState.shield, 'Shield');
      m.t = 0;
      audio.play('block');
      _floats.add(FloatText('BLOCKED!', m.x, m.y - d.height - 3, Colors.white70, size: 3));
      _burst(m.x + m.facing * 5, m.y - d.height * 0.6, Colors.white, n: 6, speed: 40);
      return false;
    }
    m.hp -= dmg;
    m.flash = 0.1;
    audio.play('hit');
    _floats.add(FloatText('-${dmg.round()}', m.x, m.y - d.height - 2, Colors.white, size: 3.2, life: 0.7));
    _burst(m.x, m.y - d.height / 2, d.color, n: 8);
    _addCombo();
    final p = player;
    _charge(4);
    if (p.frenzy > 0) p.hp = min(p.maxHp, p.hp + 2);
    if (m.hp <= 0) {
      m.hp = 0;
      m.dive = 0;
      _setM(m, MState.dead, 'Dead');
      _charge(6);
      audio.play('poof');
      _floats.add(FloatText('KO!', m.x, m.y - d.height - 6, d.color, size: 4, life: 0.9));
      if (rng.nextDouble() < 0.15) _pickups.add(Pickup(PickupKind.somsa, m.x, m.y - 10));
    } else if (stuck) {
      _floats.add(FloatText('×2', m.x + 4, m.y - d.height - 6, const Color(0xFFFFD54F), size: 3.4, life: 0.6));
    } else if (m.dive <= 0) {
      _setM(m, MState.hurt, 'Hurt');
      m.t = 0;
      if (!d.flying) m.x = (m.x + (m.x - fromX).sign * 4).clamp(4.0, W - 4);
    }
    return true;
  }

  void _updateMinions(double dt) {
    final p = player;
    final fighting = phase == Phase.fight;
    for (final m in _minions) {
      final d = m.def;
      final anims = _bodies[d.body]!;
      m.t += dt;
      if (m.flash > 0) m.flash -= dt;
      if (m.cd > 0) m.cd -= dt;
      if (m.state == MState.dead) {
        if (m.t > anims['Dead']!.duration + 0.6) m.remove = true;
        continue;
      }
      final dx = p.x - m.x;
      final want = dx < 0 ? -1 : 1;
      if (d.flying) {
        if (m.state != MState.attack && m.dive <= 0) m.facing = want;
      } else if (m.state == MState.attack || want == m.facing) {
        m.turnT = 0;
      } else {
        // Ground minions take a moment to turn around — the shielded
        // skeleton is slow, so jumping over it opens its back.
        m.turnT += dt;
        if (m.turnT >= (d.shield ? 0.7 : 0.15)) {
          m.facing = want;
          m.turnT = 0;
        }
      }

      if (d.flying) {
        _updateFlyer(m, dt, fighting);
        continue;
      }
      final prevY = m.y;
      m.vy += kGravity * dt;
      m.y += m.vy * dt;
      final land = _landY(m.x, prevY, m.y, m.vy);
      if (land != null) {
        m
          ..y = land
          ..vy = 0;
      }

      switch (m.state) {
        case MState.attack:
          if (!m.hitDone && m.t >= d.hitTime) {
            m.hitDone = true;
            final box = Rect.fromLTWH(m.facing > 0 ? m.x : m.x - d.reach, m.y - d.height, d.reach, d.height);
            final landed = fighting && box.overlaps(p.rect) && p.invuln <= 0;
            if (fighting && box.overlaps(p.rect)) _hurtPlayer(d.dmg, m.x);
            if (d.lunge && !landed) {
              // Missed (or you rolled through it): its cap gets stuck in the floor.
              _setM(m, MState.stunned, 'Stun');
              m.t = 0;
              _floats.add(FloatText('STUCK!', m.x, m.y - d.height - 4, const Color(0xFFFFD54F), size: 3.6, life: 1));
              audio.play('block');
            }
            if (m.kind == MinionKind.mushroom) {
              _hazards.add(Hazard(
                  kind: HazardKind.puddle, x: m.x + m.facing * 9, y: m.y, w: 14, h: 3, active: 2.5, dmg: 5,
                  color: const Color(0xFFAB47BC)));
            }
          }
          if (anims['Attack_1']!.isDone(m.t)) {
            _setM(m, MState.move, 'Idle');
            m.cd = 1.1 + rng.nextDouble() * 0.8;
          }
        case MState.hurt:
          if (m.t >= 0.3) _setM(m, MState.move, 'Idle');
        case MState.shield:
          if (m.t >= 0.4) _setM(m, MState.move, 'Idle');
        case MState.stunned:
          if (m.t >= 2.2) {
            _setM(m, MState.move, 'Idle');
            m.cd = 1.2;
          }
        default:
          if (!fighting) {
            _setM(m, MState.move, 'Idle');
            break;
          }
          if (dx.abs() > d.reach * 0.75) {
            m.x = (m.x + dx.sign * d.speed * dt).clamp(4.0, W - 4);
            _setM(m, MState.move, 'Run');
          } else {
            _setM(m, MState.move, 'Idle');
            if (m.cd <= 0 && (p.y - m.y).abs() < 20) {
              m
                ..state = MState.attack
                ..anim = 'Attack_1'
                ..t = 0
                ..hitDone = false;
            }
          }
      }
    }
    _minions.removeWhere((m) => m.remove);
  }

  /// Flying eyes hover near the student and dive-bomb them.
  void _updateFlyer(Minion m, double dt, bool fighting) {
    final p = player, d = m.def;
    if (m.state == MState.hurt && m.t >= 0.3) _setM(m, MState.move, 'Run');
    if (m.dive > 0) {
      m.dive -= dt;
      m.x = (m.x + m.vx * dt).clamp(4.0, W - 4);
      m.y = (m.y + m.vy * dt).clamp(16.0, kGround);
      if (fighting && m.rect.overlaps(p.rect)) {
        _hurtPlayer(d.dmg, m.x);
        m.dive = 0;
      }
      if (m.dive <= 0) _setM(m, MState.move, 'Run');
      return;
    }
    final tx = p.x + sin(_clock * 0.9 + m.phase) * 22;
    final ty = min(p.y - 28, 58.0) + sin(_clock * 2.2 + m.phase) * 4;
    final ddx = tx - m.x, ddy = ty - m.y;
    final dist = sqrt(ddx * ddx + ddy * ddy);
    if (dist > 1.5) {
      m.x = (m.x + ddx / dist * d.speed * dt).clamp(4.0, W - 4);
      m.y = (m.y + ddy / dist * d.speed * dt).clamp(16.0, kGround - 4);
    }
    if (m.state == MState.move) _setM(m, MState.move, 'Run');
    final px = p.x - m.x, py = (p.y - 12) - (m.y - d.height / 2);
    final pd = sqrt(px * px + py * py);
    if (fighting && m.cd <= 0 && pd < 48 && m.state == MState.move) {
      m
        ..dive = 0.5
        ..vx = px / pd * 105
        ..vy = py / pd * 105
        ..cd = 2 + rng.nextDouble() * 1.5
        ..state = MState.attack
        ..anim = 'Attack_1'
        ..t = 0;
      m.facing = px < 0 ? -1 : 1;
    }
  }

  // ── Projectiles / hazards / pickups ─────────────────────────────────────
  void _updateProjectiles(double dt) {
    final p = player;
    for (final pr in _projectiles) {
      if (pr.dead) continue;
      pr.t += dt;
      pr.life -= dt;
      switch (pr.kind) {
        case ProjKind.boomerang:
          pr.vx -= pr.phase * 135 * dt;
        case ProjKind.bubble:
          pr.vy = sin(pr.t * 3 + pr.phase) * 12;
        case ProjKind.bug:
          final dx = p.x - pr.x, dy = (p.y - 11) - pr.y;
          final d = sqrt(dx * dx + dy * dy) + 0.001;
          const sp = 52.0;
          pr.vx += (dx / d * sp - pr.vx) * dt * 2.2;
          pr.vy += (dy / d * sp - pr.vy) * dt * 2.2;
        default:
          break;
      }
      pr.vy += pr.gravity * dt;
      final prevY = pr.y;
      pr.x += pr.vx * dt;
      if (pr.kind == ProjKind.letter) {
        pr.baseY += pr.vy * dt;
        pr.y = pr.baseY + sin(pr.t * 7 + pr.phase) * 7;
      } else {
        pr.y += pr.vy * dt;
      }

      if (pr.kind == ProjKind.potion) {
        final land = _landY(pr.x, prevY, pr.y, pr.vy);
        if (land != null) {
          pr.dead = true;
          _burst(pr.x, land, pr.color, n: 10, speed: 40);
          _hazards.add(Hazard(
              kind: HazardKind.puddle, x: pr.x, y: land, w: 20, h: 3, active: 3.5, dmg: 6,
              color: pr.color));
        }
      } else if (pr.kind == ProjKind.rock) {
        final land = _landY(pr.x, prevY, pr.y, pr.vy);
        if (land != null) {
          pr.dead = true;
          _burst(pr.x, land, pr.color, n: 12, speed: 45);
          _shake = max(_shake, 2);
          for (final dir in const [-1.0, 1.0]) {
            _hazards.add(Hazard(
                kind: HazardKind.shockwave, x: pr.x, y: land, w: 5, h: 5, active: 0.9, dmg: 8,
                vx: dir * 70, color: pr.color));
          }
        }
      } else if (pr.kind == ProjKind.ball) {
        final land = _landY(pr.x, prevY, pr.y, pr.vy);
        if (land != null) {
          pr.y = land - 0.01;
          pr.vy = -max(70.0, pr.vy * 0.78);
        }
        if (pr.x < 4 || pr.x > W - 4) pr.vx = -pr.vx;
      } else if ((pr.kind == ProjKind.apple || pr.kind == ProjKind.arrow) && pr.y >= kGround) {
        pr.dead = true;
        _burst(pr.x, kGround, pr.color, n: 6, speed: 30);
      }
      if (pr.life <= 0 || pr.x < -20 || pr.x > W + 20 || pr.y > 110) pr.dead = true;
      if (pr.dead) continue;

      if (pr.fromPlayer) {
        if (phase == Phase.fight &&
            teacher.state != TState.dead &&
            teacher.rect.inflate(pr.r).contains(Offset(pr.x, pr.y))) {
          if (pr.kind == ProjKind.boomerang) {
            // The blade pierces: one hit on the way out, one on the way back.
            final key = 'teacher${pr.vx.sign}';
            if (!pr.hits.contains(key)) {
              pr.hits.add(key);
              _burst(pr.x, pr.y, pr.color, n: 16, speed: 70);
              _damageTeacher(pr.dmg.toDouble(), pr.vx.sign * 20);
            }
          } else {
            pr.dead = true;
            _burst(pr.x, pr.y, pr.color, n: 25, speed: 80);
            _damageTeacher(pr.dmg.toDouble(), pr.vx.sign * (pr.kind == ProjKind.wave ? 60 : 10));
          }
        }
        for (final m in _minions) {
          if (m.state == MState.dead || pr.dead || pr.hits.contains(m)) continue;
          if (m.rect.inflate(pr.r).contains(Offset(pr.x, pr.y))) {
            pr.hits.add(m);
            final pierce = pr.kind == ProjKind.wave || pr.kind == ProjKind.boomerang;
            _hitMinion(m, pierce ? pr.dmg * 0.7 : pr.dmg.toDouble(), pr.x - pr.vx.sign * 5, unblockable: pierce);
            if (!pierce) pr.dead = true;
          }
        }
        // Waves erase everything; bolts trade with destructible projectiles.
        final isWave = pr.kind == ProjKind.wave;
        for (final o in _projectiles) {
          if (o.fromPlayer || o.dead || pr.dead || (!isWave && !o.destructible)) continue;
          if ((o.x - pr.x).abs() < pr.r + o.r && (o.y - pr.y).abs() < pr.r * 2 + o.r) {
            o.dead = true;
            // Bolts and blades cut through homework; only enemies stop them.
            if (!isWave && pr.kind != ProjKind.boomerang && pr.kind != ProjKind.orb) pr.dead = true;
            _burst(o.x, o.y, o.color, n: 6);
          }
        }
      } else if (phase == Phase.fight && p.rect.inflate(pr.r * 0.7).contains(Offset(pr.x, pr.y))) {
        pr.dead = true;
        _burst(pr.x, pr.y, pr.color, n: 8);
        _hurtPlayer(pr.dmg, pr.x);
      }
    }
    _projectiles.removeWhere((pr) => pr.dead);
  }

  void _updateHazards(double dt) {
    final p = player;
    for (final h in _hazards) {
      h.t += dt;
      if (!h.armed || h.done) continue;
      if (h.kind == HazardKind.tornado) {
        h.x = (h.x + h.vx * dt).clamp(6.0, W - 6);
        final d = h.x - p.x;
        if (phase == Phase.fight && d.abs() < 32 && p.state != PState.dead) {
          p.x = (p.x + d.sign * 24 * dt).clamp(6.0, W - 6);
        }
      }
      if (h.kind == HazardKind.shockwave) {
        h.x += h.vx * dt;
        if (rng.nextDouble() < 0.5) {
          _sparks.add(Spark(h.x, kGround, -h.vx.sign * 15, -30 - rng.nextDouble() * 30, 0.3, 0.9, h.color));
        }
      }
      if (phase == Phase.fight && h.rect.overlaps(p.rect)) {
        if (h.roots && p.invuln <= 0) p.slow = 2;
        _hurtPlayer(h.dmg, h.x);
      }
    }
    _hazards.removeWhere((h) => h.done || h.x < -20 || h.x > W + 20);
  }

  void _updatePickups(double dt) {
    final p = player;
    if (phase == Phase.fight) {
      _pickupTimer -= dt;
      if (_pickupTimer <= 0) {
        _pickupTimer = 11 + rng.nextDouble() * 6;
        if (_pickups.length < 2) {
          final kind = p.hp < 60
              ? PickupKind.plov
              : (rng.nextBool() ? PickupKind.coffee : PickupKind.somsa);
          _pickups.add(Pickup(kind, 15 + rng.nextDouble() * (W - 30), 14));
        }
      }
    }
    for (final pk in _pickups) {
      pk.t += dt;
      if (pk.kind == PickupKind.note) {
        // A page of notes flutters up, then drifts into your hands.
        if (pk.t < 0.9) {
          pk.y -= 8 * dt;
        } else {
          // Faster than you can run, so it always catches up.
          final dx = p.x - pk.x, dy = p.y - 10 - pk.y;
          final dist = sqrt(dx * dx + dy * dy);
          final step = min(dist, max(130.0, dist * 5) * dt);
          if (dist > 0) {
            pk.x += dx / dist * step;
            pk.y += dy / dist * step;
          }
        }
        if (p.state != PState.dead && (pk.x - p.x).abs() < 6 && (pk.y - (p.y - 10)).abs() < 8) {
          pk.life = 0;
          _gotNote(pk.note);
        }
        continue;
      }
      pk.life -= dt;
      final prevY = pk.y;
      pk.vy += 120 * dt;
      pk.y += pk.vy * dt;
      final land = _landY(pk.x, prevY, pk.y, pk.vy);
      if (land != null) {
        pk
          ..y = land
          ..vy = 0;
      }
      if (p.state != PState.dead && (pk.x - p.x).abs() < 8 && pk.y > p.y - 24 && pk.y < p.y + 4) {
        pk.life = 0;
        switch (pk.kind) {
          case PickupKind.plov:
            p.hp = min(p.maxHp, p.hp + 35);
          case PickupKind.somsa:
            p.hp = min(p.maxHp, p.hp + 20);
          case PickupKind.coffee:
            _charge(50);
          case PickupKind.note:
            break;
        }
        _floats.add(FloatText(pk.label, pk.x, pk.y - 26, const Color(0xFF69F0AE), size: 3.6, life: 1.3));
        _burst(pk.x, pk.y - 4, const Color(0xFF69F0AE), n: 12);
        _vibrate(30);
        audio.play('pickup');
      }
    }
    _pickups.removeWhere((pk) => pk.life <= 0);
  }

  void _updateFx(double dt) {
    for (final s in _sparks) {
      s.life -= dt;
      s.vy += 120 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    _sparks.removeWhere((s) => s.life <= 0);
    for (final f in _floats) {
      f.life -= dt;
      f.y -= 12 * dt;
    }
    _floats.removeWhere((f) => f.life <= 0);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  /// Surface a falling body lands on this frame, if any.
  double? _landY(double x, double prevY, double y, double vy) {
    if (vy < 0) return null;
    if (y >= kGround) return kGround;
    for (final pl in _platforms) {
      if (x >= pl.x && x <= pl.x + pl.w && prevY <= pl.y + 0.01 && y >= pl.y) return pl.y;
    }
    return null;
  }

  /// First surface at or below [y] at column [x].
  double _surfaceBelow(double x, double y) {
    var best = kGround;
    for (final pl in _platforms) {
      if (x >= pl.x && x <= pl.x + pl.w && pl.y >= y - 0.5 && pl.y < best) best = pl.y;
    }
    return best;
  }

  void _burst(double x, double y, Color color, {int n = 10, double speed = 55}) {
    for (var i = 0; i < n; i++) {
      final a = rng.nextDouble() * pi * 2, s = speed * (0.3 + rng.nextDouble() * 0.7);
      _sparks.add(Spark(x, y, cos(a) * s, sin(a) * s, 0.3 + rng.nextDouble() * 0.3,
          0.6 + rng.nextDouble() * 0.8, color));
    }
  }

  // ── Settings ────────────────────────────────────────────────────────────
  bool vibrationOn = true;
  final audio = GameAudio.instance;
  bool get musicOn => audio.musicOn;
  bool get sfxOn => audio.sfxOn;

  void setMusic(bool on) {
    audio.setMusic(on);
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('music', on));
  }

  void setSfx(bool on) {
    audio.setSfx(on);
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('sfx', on));
    if (on) audio.play('click');
  }

  /// Background track for the current screen.
  String? get _wantedTrack => switch (phase) {
        Phase.menu || Phase.victory => 'menu',
        Phase.gameOver => null,
        Phase.rest => 'rest',
        Phase.story => _boss && def.scary ? 'demon' : 'rest',
        _ when escaping => 'explore',
        _ => switch (room.kind) {
            RoomKind.rest => 'rest',
            RoomKind.hall => 'explore',
            RoomKind.boss => def.scary ? 'demon' : (isFinalRound ? 'final' : 'boss'),
          },
      };

  void setVibration(bool on) {
    vibrationOn = on;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('vibration', on));
    if (on) _vibrate(40);
  }

  /// True while a floor is being played (the pause menu makes sense).
  bool get inFight => phase == Phase.fight || phase == Phase.roundBreak || phase == Phase.cleared;

  void _vibrate(int ms) async {
    if (!vibrationOn) return;
    try {
      if (await Vibration.hasVibrator() == true) {
        await Vibration.vibrate(duration: ms, amplitude: min(255, 60 + ms));
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════
  // Keyboard (desktop / emulator testing)
  // ══════════════════════════════════════════════════════════════════════
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final kl = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    final kr = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);
    if (kl != _keyLeft) left = _keyLeft = kl;
    if (kr != _keyRight) right = _keyRight = kr;

    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
        pressJump();
      } else if (k == LogicalKeyboardKey.keyJ || k == LogicalKeyboardKey.keyF) {
        pressAttack();
      } else if (k == LogicalKeyboardKey.keyL || k == LogicalKeyboardKey.shiftLeft) {
        pressRoll();
      } else if (k == LogicalKeyboardKey.keyK || k == LogicalKeyboardKey.keyE) {
        pressSpecial();
      } else if (k == LogicalKeyboardKey.enter) {
        if (phase == Phase.intro) beginFight();
        if (phase == Phase.menu) startRun();
      } else if (k == LogicalKeyboardKey.escape) {
        isPaused ? resumeGame() : pauseGame();
      }
    }
    return KeyEventResult.handled;
  }

  // ══════════════════════════════════════════════════════════════════════
  // Render
  // ══════════════════════════════════════════════════════════════════════
  @override
  void render(Canvas canvas) {
    if (!_ready || size.y <= 0) return;
    // 1) Everything but text goes into a small buffer (world units → pixels).
    const px = kPixelRows / 100; // buffer pixels per world unit
    final bufW = (W * px).ceil(), bufH = kPixelRows.toInt();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(px);
    _textOps.clear();
    _text.defer = _textOps;
    SpriteAnim.snap = 1 / px;
    c.save();
    if (_shake > 0) {
      // Shake by whole pixels.
      c.translate(((rng.nextDouble() - 0.5) * _shake * px).roundToDouble() / px,
          ((rng.nextDouble() - 0.5) * _shake * px).roundToDouble() / px);
    }
    _drawRoom(c);
    _drawProps(c);
    _drawPlatforms(c);
    _drawDecor(c);
    _drawHazards(c, under: true);
    _drawPickups(c);
    _drawNpcs(c);
    _drawTeacher(c);
    _drawMinions(c);
    _drawPlayer(c);
    _drawProjectiles(c);
    _drawHazards(c, under: false);
    _drawFx(c);
    _drawAmbient(c);
    _drawSceneForeground(c);
    _drawTint(c);
    _drawAtmosphere(c);
    _drawDecorGlow(c);
    _drawVignette(c);
    _drawSpeech(c);
    _drawMemory(c);
    c.restore();
    if (phase != Phase.menu) _drawHud(c);
    if (_fade > 0) {
      // Fade in steps, like old consoles.
      final f = (_fade.clamp(0.0, 1.0) * 6).round() / 6;
      c.drawRect(Rect.fromLTWH(-5, -5, W + 10, 110), Paint()..color = Colors.black.withValues(alpha: f));
    }
    _text.defer = null;
    SpriteAnim.snap = 0;
    final pic = rec.endRecording();
    _frame?.dispose();
    _frame = pic.toImageSync(bufW, bufH);
    pic.dispose();

    // 2) Blow the buffer up to the screen with nearest-neighbour.
    final k = size.y / bufH;
    canvas.drawImageRect(_frame!, Rect.fromLTWH(0, 0, bufW.toDouble(), bufH.toDouble()),
        Rect.fromLTWH(0, 0, bufW * k, size.y), pixelPaint);

    // 3) Text in the pixel font, sharp at full resolution.
    _text.replay(canvas, _textOps, k);
    if (_fade > 0.5) {
      canvas.drawRect(Offset.zero & Size(size.x, size.y),
          Paint()..color = Colors.black.withValues(alpha: ((_fade - 0.5) * 2).clamp(0.0, 1.0)));
    }
  }

  ui.Image? _frame;
  final _textOps = <TextOp>[];

  // ── Room ────────────────────────────────────────────────────────────────
  void _drawRoom(Canvas c) {
    final scene = _scene;
    if (scene != null) {
      _drawOutdoor(c, scene);
      return;
    }
    final d = def;
    c.drawRect(
      Rect.fromLTWH(0, 0, W, kGround),
      Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, kGround), [d.wall, d.wallDark]),
    );
    final panel = Paint()..color = Colors.black.withValues(alpha: 0.13);
    for (double x = 0; x < W; x += 28) {
      c.drawRect(Rect.fromLTWH(x, 16, 0.8, kGround - 16), panel);
    }
    // wainscot
    c.drawRect(Rect.fromLTWH(0, kGround - 10, W, 10), Paint()..color = Colors.black.withValues(alpha: 0.18));
    c.drawRect(Rect.fromLTWH(0, kGround - 10, W, 0.8), Paint()..color = d.accent.withValues(alpha: 0.35));

    _drawWindows(c);
    _drawBoard(c);

    // floor
    c.drawRect(Rect.fromLTWH(0, kGround, W, 22), Paint()..color = const Color(0xFF3E3027));
    c.drawRect(Rect.fromLTWH(0, kGround, W, 1.2), Paint()..color = const Color(0xFF7A5C47));
    final line = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 0.4;
    for (double x = 0; x < W + 10; x += 14) {
      c.drawLine(Offset(x, kGround + 1.2), Offset(x - 8, 100), line);
    }
    c.drawLine(const Offset(0, kGround + 9), Offset(W, kGround + 9), line);

    _drawDoors(c);
  }

  // ── Outdoors ────────────────────────────────────────────────────────────
  void _updateScene(double dt) {
    final ct = _colorTarget;
    if (_color != ct) _color = ct > _color ? min(ct, _color + dt * 0.12) : max(ct, _color - dt * 0.5);
    final target = (player.x / W - 0.5).clamp(-0.5, 0.5);
    _cam += (target - _cam) * min(1.0, dt * 2.5);
    final sd = _scene?.def;
    _life.update(dt, W, rng, birdsOn: sd != null && sd.birds && !_scary);
  }

  void _drawOutdoor(Canvas c, Landscape l) {
    final paint = _scenePaint;
    l.draw(c, W, _cam, _clock, paint: paint);
    if (l.def.rays && !_scary && _color > 0.5) _life.drawRays(c, W, _clock);
    _life.drawBirds(c, W, _clock, const Color(0xFF2B3A42));
    l.drawGround(c, W, kGround, paint: paint);
    // soft shade towards the bottom of the ground
    c.drawRect(
        Rect.fromLTWH(0, kGround + 2, W, 18),
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, kGround + 2), const Offset(0, 100),
              [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.35)]));
    if (room.outdoors || escaping) {
      _drawOutdoorExits(c);
    } else {
      _drawDoors(c); // rooftops still have the stairwell doors
    }
  }

  /// Grass in front of the action, along the bottom of outdoor scenes.
  void _drawSceneForeground(Canvas c) {
    final l = _scene;
    if (l == null || l.def.ground != Ground.grass) return;
    final grass = Color.lerp(l.def.grassDark, Colors.black, 0.5)!;
    _life.drawForeground(c, W, _clock, Color.lerp(const Color(0xFF3A3A3A), grass, _color)!);
  }

  void _drawVignette(Canvas c) {
    c.drawRect(
        Rect.fromLTWH(0, 0, W, 100),
        Paint()
          ..shader = ui.Gradient.radial(Offset(W / 2, 48), W * 0.62, [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: _scene != null ? 0.32 : 0.4),
          ], [0.0, 0.55, 1.0]));
  }

  /// The building you came out of on the left; the next building's door (or
  /// the open road) on the right.
  void _drawOutdoorExits(Canvas c) {
    final open = phase == Phase.cleared || phase == Phase.transition || phase == Phase.victory;
    final here = room.buildingDef;
    _facade(c, -4, 18, here, onLeft: true, doorOpen: true);
    if (escaping) {
      // A signpost pointing at the horizon
      final x = W - 12, bob = sin(_clock * 4) * 0.8;
      c.drawRect(Rect.fromLTWH(x - 0.8, kGround - 18, 1.6, 18), Paint()..color = const Color(0xFF5D4037));
      final board = Path()
        ..moveTo(x - 9, kGround - 17)
        ..lineTo(x + 6, kGround - 17)
        ..lineTo(x + 9, kGround - 14)
        ..lineTo(x + 6, kGround - 11)
        ..lineTo(x - 9, kGround - 11)
        ..close();
      c.drawPath(board, Paint()..color = const Color(0xFF8D6E63));
      c.drawRect(Rect.fromLTWH(x - 9, kGround - 11.8, 15, 0.8), Paint()..color = const Color(0xFF5D4037));
      _text.draw(c, 'WAKE UP', x - 1.5, kGround - 14, 2.2, const Color(0xFFFFF8E1), weight: FontWeight.w900);
      _text.draw(c, '→', x + 4, kGround - 22 + bob, 4, const Color(0xFFFFD54F));
      return;
    }
    final next = isLastFloor ? null : kRooms[floor + 1];
    final nb = next?.buildingDef ?? here;
    _facade(c, W - 16, 20, nb, onLeft: false, doorOpen: open);
    if (open) {
      final bob = sin(_clock * 5) * 1.5;
      _text.draw(c, '▲', W - 8, kGround - 33 + bob, 4.5, nb.color);
      _text.draw(c, 'FLOOR ${nb.letter}', W - 12, kGround - 38 + bob, 2.6, Colors.white);
    }
  }

  void _facade(Canvas c, double x, double w, BuildingDef b, {required bool onLeft, required bool doorOpen}) {
    const h = 50.0;
    const top = kGround - h;
    final wall = Color.lerp(const Color(0xFFB0A49A), b.color, 0.18)!;
    final wallDark = Color.lerp(wall, Colors.black, 0.35)!;
    c.drawRect(Rect.fromLTWH(x, top, w, h),
        Paint()..shader = ui.Gradient.linear(Offset(x, top), Offset(x, kGround), [wall, wallDark]));
    // bricks
    final mortar = Paint()..color = Colors.black.withValues(alpha: 0.14);
    for (var row = 0; row * 2.4 < h; row++) {
      final y = top + row * 2.4;
      c.drawRect(Rect.fromLTWH(x, y, w, 0.4), mortar);
      for (var bx = x + (row.isEven ? 0 : 2.5); bx < x + w; bx += 5) {
        c.drawRect(Rect.fromLTWH(bx, y, 0.4, 2.4), mortar);
      }
    }
    // cornice, and the inner edge in shadow to sell the depth
    c.drawRect(Rect.fromLTWH(x - 1, top - 2, w + 2, 2.4), Paint()..color = Color.lerp(wall, Colors.white, 0.2)!);
    final edgeX = onLeft ? x + w - 1.6 : x;
    c.drawRect(Rect.fromLTWH(edgeX, top, 1.6, h), Paint()..color = Colors.black.withValues(alpha: 0.25));
    // lit windows
    for (var i = 0; i < 2; i++) {
      final wx = onLeft ? x + w - 9 : x + 3;
      final wy = top + 5 + i * 9;
      final lit = 0.75 + 0.25 * sin(_clock * 0.7 + i * 2 + x);
      c.drawRect(Rect.fromLTWH(wx - 0.6, wy - 0.6, 6.2, 6.2), Paint()..color = const Color(0xFF5D4037));
      c.drawRect(Rect.fromLTWH(wx, wy, 5, 5), Paint()..color = const Color(0xFFFFE082).withValues(alpha: lit));
      c.drawRect(Rect.fromLTWH(wx + 2.2, wy, 0.6, 5), Paint()..color = const Color(0xFF5D4037));
    }
    // door
    final dx = onLeft ? x + w - 13 : x + 3;
    final door = Rect.fromLTWH(dx, kGround - 22, 10, 22);
    c.drawRect(door.inflate(1.2), Paint()..color = const Color(0xFF4E342E));
    if (doorOpen) {
      if (!onLeft) {
        final glow = 0.5 + 0.5 * sin(_clock * 6);
        c.drawRect(door.inflate(2 + glow), Paint()..color = b.color.withValues(alpha: 0.18 + glow * 0.15));
      }
      c.drawRect(
          door,
          Paint()
            ..shader = ui.Gradient.linear(
                door.topCenter, door.bottomCenter, [const Color(0xFFFFE9A8), const Color(0xFFFFB74D)]));
    } else {
      c.drawRect(door, Paint()..color = const Color(0xFF6D4C41));
      c.drawRect(Rect.fromLTWH(door.center.dx - 0.3, door.top, 0.6, door.height),
          Paint()..color = const Color(0xFF4E342E));
      _text.draw(c, '🔒', door.center.dx, door.center.dy, 3.6, Colors.white);
    }
    // building letter plate above the door
    c.drawRect(Rect.fromCenter(center: Offset(door.center.dx, door.top - 4), width: 6, height: 4.4),
        Paint()..color = const Color(0xFF263238));
    _text.draw(c, b.letter, door.center.dx, door.top - 3.9, 3, b.color, weight: FontWeight.w900);
  }

  void _drawWindows(Canvas c) {
    final t = floor / (kRooms.length - 1);
    final skyTop = Color.lerp(const Color(0xFF64B5F6), const Color(0xFFFF7043), t)!;
    final skyBottom = Color.lerp(const Color(0xFFBBDEFB), const Color(0xFFFFCC80), t)!;
    for (final wx in [W * 0.06, W * 0.80]) {
      final r = Rect.fromLTWH(wx, 22, 24, 30);
      c.drawRect(r.inflate(1.5), Paint()..color = const Color(0xFFD7CCC8));
      c.drawRect(r, Paint()..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [skyTop, skyBottom]));
      c.save();
      c.clipRect(r);
      final view = _scenes[room.buildingDef.view];
      if (!_scary && view != null) {
        // The real landscape outside; it shifts as you walk past the window,
        // and is as grey as the world still is.
        // The whole landscape, shrunk into the window: a wide view of sky,
        // hills and trees. It slides as you walk (parallax), and the horizon
        // sinks the higher you climb.
        const k = 0.42;
        c.save();
        c.translate(wx + 12 - W * k / 2 - _cam * 10, r.top - (12 + t * 14) * k);
        c.scale(k);
        view.draw(c, W, _cam * 1.5, _clock, paint: _scenePaint);
        c.restore();
        c.drawRect(r, Paint()..color = const Color(0xFFFF9E40).withValues(alpha: t * 0.12 * _color)); // dawn light
      }
      if (_scary) {
        // Night: dark sky, stars, a blood moon
        c.drawRect(r, Paint()..color = const Color(0xFF0B0410));
        for (var i = 0; i < 6; i++) {
          c.drawCircle(Offset(wx + (i * 7.3 + wx) % 24, 23 + (i * 5.1) % 26), 0.35, Paint()..color = Colors.white70);
        }
        if (wx > W / 2) c.drawCircle(Offset(wx + 15, 30), 5, Paint()..color = const Color(0xFFB71C1C));
      } else if (room.building == '5' && (sin(_clock * 0.6 + wx) > 0.93)) {
        // ...something is watching from outside
        c.drawCircle(Offset(wx + 10, 38), 0.8, Paint()..color = const Color(0xFFFF1744));
        c.drawCircle(Offset(wx + 13, 38), 0.8, Paint()..color = const Color(0xFFFF1744));
      }
      // drawn clouds, only if the landscape is missing
      if (!_scary && view == null) {
        final cx = wx + ((_clock * 2 + wx) % 34) - 6;
        final cloud = Paint()..color = Colors.white.withValues(alpha: 0.8);
        c.drawCircle(Offset(cx, 29), 2.5, cloud);
        c.drawCircle(Offset(cx + 3, 28), 3, cloud);
        c.drawCircle(Offset(cx + 6, 29.5), 2.2, cloud);
      }
      if (view == null) {
        // city skyline sinks as you climb higher
        final base = r.bottom + t * 11 - 4;
        final city = Paint()..color = const Color(0xFF455A64);
        for (var i = 0; i < 6; i++) {
          final h = 6.0 + ((i * 37 + wx.toInt()) % 9);
          c.drawRect(Rect.fromLTWH(wx + i * 4.2, base - h, 3.6, h + 10), city);
        }
      }
      // glass glare
      c.drawRect(Rect.fromLTWH(wx + 2, 22, 3, 30), Paint()..color = Colors.white.withValues(alpha: 0.07));
      c.restore();
      final frame = Paint()
        ..color = const Color(0xFFD7CCC8)
        ..strokeWidth = 0.8;
      c.drawLine(r.topCenter, r.bottomCenter, frame);
      c.drawLine(r.centerLeft, r.centerRight, frame);
    }
  }

  void _drawBoard(Canvas c) {
    final d = def;
    final bw = min(W * 0.36, 84.0), bx = W / 2 - bw / 2;
    const by = 19.0, bh = 31.0;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx - 1.6, by - 1.6, bw + 3.2, bh + 3.2), const Radius.circular(1)),
        Paint()..color = const Color(0xFF6D4C41));
    c.drawRect(Rect.fromLTWH(bx, by, bw, bh), Paint()..color = const Color(0xFF1F3D2B));
    _text.draw(c, 'NIGHTMARE UNIVERSITY', W / 2, by + 3.5, 2.4, Colors.white.withValues(alpha: 0.55));
    _text.draw(c, _boss ? d.subject : '${room.buildingDef.title.toUpperCase()} · ${room.name.toUpperCase()}',
        W / 2, by + 8.5, 3.2, d.accent);
    for (var i = 0; i < d.board.length; i++) {
      _text.draw(c, d.board[i], W / 2, by + 15 + i * 5.2, 3.4, Colors.white.withValues(alpha: 0.85),
          weight: FontWeight.w600);
    }
    c.drawRect(Rect.fromLTWH(bx + 4, by + bh + 1.6, bw - 8, 1.2), Paint()..color = const Color(0xFF8D6E63));
  }

  void _drawDoors(Canvas c) {
    // Entrance (left)
    final l = const Rect.fromLTWH(1, kGround - 30, 12, 30);
    c.drawRect(l, Paint()..color = const Color(0xFF4E342E));
    c.drawRect(l.deflate(1.5), Paint()..color = const Color(0xFF6D4C41));
    _text.draw(c, room.number == 1 ? 'IN' : '◀', l.center.dx, l.top - 3, 2.4, Colors.white54);

    // Stairs (right)
    final r = Rect.fromLTWH(W - 13, kGround - 30, 12, 30);
    final open = phase == Phase.cleared || phase == Phase.transition || phase == Phase.victory;
    // Mira's corners: a table with a candle.
    if (room.kind == RoomKind.rest) {
      final tx = W * 0.5;
      c.drawRect(Rect.fromLTWH(tx - 16, kGround - 9, 32, 2), Paint()..color = const Color(0xFF8D6E63));
      c.drawRect(Rect.fromLTWH(tx - 14, kGround - 7, 1.5, 7), Paint()..color = const Color(0xFF5D4037));
      c.drawRect(Rect.fromLTWH(tx + 12.5, kGround - 7, 1.5, 7), Paint()..color = const Color(0xFF5D4037));
      if (room.gift) _text.draw(c, '📄', tx + 7, kGround - 12, 5, Colors.white);
    }
    if (open) {
      final glow = 0.5 + 0.5 * sin(_clock * 6);
      c.drawRect(r.inflate(2 + glow), Paint()..color = def.accent.withValues(alpha: 0.25 + glow * 0.2));
      c.drawRect(r, Paint()..color = const Color(0xFF121212));
      final step = Paint()..color = const Color(0xFF5D4037);
      for (var i = 0; i < 6; i++) {
        c.drawRect(Rect.fromLTWH(r.left + i * 2, r.bottom - (i + 1) * 4.5, r.width - i * 2, 1.2), step);
      }
      final bob = sin(_clock * 5) * 1.5;
      final ominous = !isLastFloor && kRooms[floor + 1].def.scary;
      _text.draw(c, isLastFloor ? '⏰' : (ominous ? '☠' : '▲'), r.center.dx, r.top - 5 + bob, 5,
          ominous ? const Color(0xFFFF1744) : def.accent);
      final next = isLastFloor ? null : kRooms[floor + 1];
      _text.draw(
          c,
          next == null
              ? 'WAKE UP'
              : next.def.scary
                  ? '8:00 AM'
                  : next.building != room.building
                      ? 'FLOOR ${next.building}'
                      : 'NEXT ROOM',
          r.center.dx - 4,
          r.top - 10 + bob,
          2.6,
          Colors.white);
    } else {
      c.drawRect(r, Paint()..color = const Color(0xFF4E342E));
      c.drawRect(r.deflate(1.5), Paint()..color = const Color(0xFF5D4037));
      _text.draw(c, '🔒', r.center.dx, r.center.dy, 4, Colors.white);
    }
  }

  void _drawPlatforms(Canvas c) {
    final scene = _scene;
    if (scene != null) {
      _drawLedges(c, scene.def);
      return;
    }
    final top = Paint()..color = const Color(0xFF8D6E63);
    final front = Paint()..color = const Color(0xFF5D4037);
    final bracket = Paint()..color = const Color(0xFF3E2723);
    final bookColors = [const Color(0xFFE53935), const Color(0xFF1E88E5), const Color(0xFF43A047), const Color(0xFFFDD835)];
    for (final pl in _platforms) {
      c.drawRect(Rect.fromLTWH(pl.x, pl.y, pl.w, 1.6), top);
      c.drawRect(Rect.fromLTWH(pl.x, pl.y + 1.6, pl.w, 2.2), front);
      c.drawRect(Rect.fromLTWH(pl.x + 2, pl.y + 3.8, 1.2, 3), bracket);
      c.drawRect(Rect.fromLTWH(pl.x + pl.w - 3.2, pl.y + 3.8, 1.2, 3), bracket);
      // books hanging under the shelf
      for (var i = 0; i < 4; i++) {
        c.drawRect(Rect.fromLTWH(pl.x + pl.w / 2 - 5 + i * 2.6, pl.y + 3.8, 2.2, 4 + (i % 2)),
            Paint()..color = bookColors[i]);
      }
    }
  }

  /// Outdoor platforms: mossy stone ledges with hanging vines.
  void _drawLedges(Canvas c, SceneDef sd) {
    final px = Landscape.pixelSize(W);
    const stone = Color(0xFF8A8F96), stoneDark = Color(0xFF5B5F66), stoneLight = Color(0xFFB4B9C0);
    for (final pl in _platforms) {
      final body = Rect.fromLTWH(pl.x, pl.y + px, pl.w, 3.6);
      c.drawOval(Rect.fromLTWH(pl.x + 2, body.bottom + 0.6, pl.w - 4, 1.4),
          Paint()..color = Colors.black.withValues(alpha: 0.18));
      c.drawRect(body, Paint()..color = stone);
      c.drawRect(Rect.fromLTWH(pl.x, body.bottom - px, pl.w, px), Paint()..color = stoneDark);
      c.drawRect(Rect.fromLTWH(pl.x, body.top, pl.w, px * 0.8), Paint()..color = stoneLight);
      // two courses of blocks with staggered joints
      final seam = Paint()..color = stoneDark;
      final mid = body.top + body.height / 2;
      c.drawRect(Rect.fromLTWH(pl.x, mid, pl.w, px * 0.6), seam);
      for (var k = 0; k < 2; k++) {
        final y = k == 0 ? body.top + px : mid;
        for (var bx = pl.x + (k == 0 ? 6.0 : 3.0); bx < pl.x + pl.w - 2; bx += 7.5) {
          c.drawRect(Rect.fromLTWH(bx, y, px * 0.7, body.height / 2 - px), seam);
        }
      }
      // moss on top, vines hanging under
      c.drawRect(Rect.fromLTWH(pl.x - px, pl.y, pl.w + 2 * px, px * 1.6), Paint()..color = sd.grass);
      final vine = Paint()..color = sd.grassDark;
      for (var i = 0; i < pl.w / 4.5; i++) {
        if (i % 3 == 1) continue;
        final vx = pl.x + 1.5 + i * 4.5 + (i * 7 % 3) * 0.6;
        final len = 1.6 + (i * 13 % 5) * 0.9 + 0.3 * sin(_clock * 1.3 + i);
        c.drawRect(Rect.fromLTWH(vx, pl.y + px, px, len), vine);
        c.drawRect(Rect.fromLTWH(vx + px, pl.y + px + len - px, px, px), vine); // curl at the tip
      }
    }
  }

  // ── Characters ──────────────────────────────────────────────────────────
  void _shadow(Canvas c, double x, double y, double w) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: 1.6),
        Paint()..color = Colors.black.withValues(alpha: 0.35));
  }

  void _drawPlayer(Canvas c) {
    final p = player;
    _shadow(c, p.x, _surfaceBelow(p.x, p.y - 0.5), 9);
    if (p.invuln > 0 && p.state != PState.hurt && p.state != PState.dead && (p.invuln * 14).floor().isOdd) {
      return;
    }
    if (p.energy >= 100 && p.state != PState.dead) {
      final pulse = 0.5 + 0.5 * sin(_clock * 8);
      c.drawCircle(Offset(p.x, p.y - 11), 13 + pulse * 2,
          Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.12 + pulse * 0.1));
    }
    var t = p.t;
    if (p.anim == 'Jump') {
      final f = p.vy < -80 ? 1 : p.vy < 0 ? 2 : p.vy < 80 ? 3 : 4;
      t = f / 10 + 0.001;
    }
    if (p.state == PState.roll) {
      // Ghost trail behind the roll.
      for (var i = 1; i <= 2; i++) {
        _heroAnims[p.anim]!.draw(c, t, p.x - p.facing * i * 6, p.y, kCharHeight,
            flip: p.facing < 0, paint: Paint()..color = Colors.white.withValues(alpha: 0.25 / i));
      }
    }
    if (p.frenzy > 0) {
      final pulse = 0.5 + 0.5 * sin(_clock * 12);
      c.drawCircle(Offset(p.x, p.y - 11), 12 + pulse * 2,
          Paint()..color = const Color(0xFFFF1744).withValues(alpha: 0.12 + pulse * 0.08));
    }
    _heroAnims[p.anim]!.draw(c, t, p.x, p.y, kCharHeight,
        flip: p.facing < 0, paint: p.state == PState.hurt && p.t < 0.12 ? flashPaint : _heroPaint);
    if (p.slow > 0) {
      _text.draw(c, 'z', p.x + 4 + sin(_clock * 3) * 2, p.y - 27 - (_clock * 8 % 6), 3, const Color(0xFFB388FF));
    }
    if (phase == Phase.intro) {
      _text.draw(c, 'YOU', p.x, p.y - 30 + sin(_clock * 4), 3, const Color(0xFF00E5FF));
    }
  }

  void _drawTeacher(Canvas c) {
    if (!_boss) return;
    final t = teacher;
    final s = kCharHeight * t.s;
    _shadow(c, t.x, t.y, 10 * t.s);
    if (t.rage && t.state != TState.dead) {
      final pulse = 0.5 + 0.5 * sin(_clock * 10);
      c.drawCircle(Offset(t.x, t.chestY), 14 * t.s + pulse * 2,
          Paint()..color = const Color(0xFFFF1744).withValues(alpha: 0.10 + pulse * 0.1));
    }
    if (t.pullTime > 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = def.accent.withValues(alpha: 0.6);
      for (var i = 0; i < 4; i++) {
        final r = ((1 - ((_clock * 1.6 + i / 4) % 1)) * 60) + 4;
        c.drawCircle(Offset(t.x, t.chestY), r, ring);
      }
    }
    // Telegraphs for the villain's big moves
    if (t.state == TState.cast && !t.fired) {
      if (t.casting == Ability.spinSlash) {
        final k = ((t.t + 0.35) / 0.64).clamp(0.0, 1.0);
        c.drawCircle(Offset(t.x, t.chestY), 30 * k, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFFF1744).withValues(alpha: 0.4 + 0.5 * k));
      } else if (t.casting == Ability.shadowDash) {
        final blink = (_clock * 12).floor().isEven;
        c.drawRect(Rect.fromLTWH(t.facing > 0 ? t.x : t.x - 100, t.y - 1, 100, 1.2),
            Paint()..color = const Color(0xFFFF1744).withValues(alpha: blink ? 0.8 : 0.3));
      }
    }
    // Shadows of beaten bosses rising behind the Reaper (phase 2).
    for (final e in _echoes) {
      final a = (e.t < 0.3 ? e.t / 0.3 : 1 - (e.t - 0.3) / 1.3).clamp(0.0, 1.0);
      final anims = _bodies[e.def.body]!;
      anims['Attack_1']!.draw(c, e.t, e.x, kGround, kCharHeight * e.def.scale, flip: e.facing < 0,
          paint: Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = const ColorFilter.mode(Color(0xFF1A0610), BlendMode.modulate)
            ..color = Colors.white.withValues(alpha: 0.75 * a));
      _text.draw(c, e.def.name, e.x, kGround - 28 * e.def.scale, 2.2, const Color(0xFFFF8A80), alpha: a);
    }
    // The other Deadline Twin waits in the shadows, growing stronger.
    if (def.twins.isNotEmpty && t.state != TState.dead) {
      final ox = _twinSpot;
      _teacherAnims['Idle']!.draw(c, _clock, ox, t.y, s, flip: t.x < ox,
          paint: Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = _shadowPaint.colorFilter
            ..color = Colors.white.withValues(alpha: 0.3));
      final power = t.twinPower[1 - t.twin];
      _text.draw(c, def.twins[1 - t.twin], ox, t.y - 27 * t.s, 2.2, Colors.white54);
      if (power > 0) {
        _text.draw(c, '+${power.round()}% ⚡', ox, t.y - 31 * t.s, 2.4, def.accent);
      }
    }
    var drawX = t.x;
    if (_tBody == 'Demon' && t.anim == 'Attack_4' && t.state == TState.cast) {
      // The dash is drawn inside the sprite; keep the image where the dash began.
      final f = _teacherAnims['Attack_4']!.frameAt(t.t).clamp(0, _demonDash.length - 1);
      drawX = t.x - t.facing * _demonDash[f] * _demonPx;
    }
    _teacherAnims[t.anim]!.draw(c, t.t, drawX, t.y, s,
        flip: t.facing < 0, paint: t.flash > 0 ? flashPaint : _teacherPaint);
    if (t.state != TState.dead && !fearPhase) {
      _text.draw(c, def.emoji, t.x, t.y - 29 * t.s, 3.6, Colors.white);
    }
  }

  /// The boss's own icon (its emoji as a pixel sprite).
  String get _bossIcon => textPieces(def.emoji).map((p) => p.icon).whereType<String>().firstOrNull ?? 'skull';

  /// What Ozod remembers when he picks up a Lost Note.
  void _drawMemory(Canvas c) {
    if (_memoryTime <= 0 || _memory.isEmpty) return;
    _bubble(c, _memory, player.x, player.y - 28, min(1.0, _memoryTime / 0.4));
  }

  void _drawMinions(Canvas c) {
    for (final m in _minions) {
      final d = m.def;
      final anims = _bodies[d.body]!;
      final anim = anims[m.anim] ?? anims['Idle']!;
      if (!d.flying) _shadow(c, m.x, m.y, d.height * 0.45);
      if (m.state == MState.dead) {
        final fade = 1 - ((m.t - anim.duration) / 0.6).clamp(0.0, 1.0);
        if (fade <= 0) continue;
      }
      anim.draw(c, m.t, m.x, m.y, d.height,
          flip: d.facesLeft ? m.facing > 0 : m.facing < 0, paint: m.flash > 0 ? flashPaint : null);
      if (m.state != MState.dead && m.hp < d.hp) {
        final top = m.y - d.height - 2.5;
        c.drawRect(Rect.fromLTWH(m.x - 5, top, 10, 1.2), Paint()..color = Colors.black54);
        c.drawRect(Rect.fromLTWH(m.x - 5, top, 10 * (m.hp / d.hp), 1.2), Paint()..color = d.color);
      }
    }
  }

  void _drawSpeech(Canvas c) {
    if (!_boss) return;
    final t = teacher;
    if (t.speechTime <= 0 || t.speech.isEmpty) return;
    final a = t.speechTime.clamp(0.0, 0.3) / 0.3;
    final tp = _text.get(t.speech, 3, const Color(0xFF111111).withValues(alpha: (a * 10).round() / 10),
        weight: FontWeight.w800, maxWidth: min(70.0, W - 10));
    final w = tp.width + 4, h = tp.height + 3;
    final cx = w >= W - 4 ? W / 2 : t.x.clamp(w / 2 + 2, W - w / 2 - 2);
    final top = max(16.0, t.y - 34 * t.s - h);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2, top, w, h), const Radius.circular(2));
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.95 * a);
    c.drawRRect(r, bubble);
    final tail = Path()
      ..moveTo(t.x - 1.5, top + h)
      ..lineTo(t.x + 1.5, top + h)
      ..lineTo(t.x, top + h + 2.5)
      ..close();
    c.drawPath(tail, bubble);
    _text.paint(c, tp, Offset(cx - tp.width / 2, top + 1.5));
  }

  // ── Projectiles / hazards / pickups / fx ────────────────────────────────
  void _drawProjectiles(Canvas c) {
    for (final pr in _projectiles) {
      switch (pr.kind) {
        case ProjKind.orb:
          c.drawCircle(Offset(pr.x, pr.y), pr.r + 1.5, Paint()..color = pr.color.withValues(alpha: 0.3));
          c.drawCircle(Offset(pr.x, pr.y), pr.r, Paint()..color = pr.color);
          c.drawCircle(Offset(pr.x, pr.y), pr.r * 0.5, Paint()..color = Colors.white);
          if (pr.glyph.isNotEmpty) _text.draw(c, pr.glyph, pr.x, pr.y, 2.6, const Color(0xFF111111));
        case ProjKind.apple:
          _shadow(c, pr.x, _surfaceBelow(pr.x, pr.y), 5);
          if (pr.glyph.isEmpty) {
            c.drawCircle(Offset(pr.x, pr.y), pr.r, Paint()..color = pr.color);
            c.drawCircle(Offset(pr.x - 1, pr.y - 1), pr.r * 0.4, Paint()..color = Colors.white24);
          } else {
            _text.draw(c, pr.glyph, pr.x, pr.y, 6, pr.glyph == '⬇' ? pr.color : Colors.white);
          }
        case ProjKind.ball:
          _shadow(c, pr.x, _surfaceBelow(pr.x, pr.y), 5);
          c.save();
          c.translate(pr.x, pr.y);
          c.rotate(pr.t * 8 * pr.vx.sign);
          _text.draw(c, pr.glyph, 0, 0, 6.5, Colors.white);
          c.restore();
        case ProjKind.arrow:
          c.save();
          c.translate(pr.x, pr.y);
          c.rotate(atan2(pr.vy, pr.vx));
          c.drawLine(const Offset(-5, 0), const Offset(3, 0), Paint()
            ..color = const Color(0xFF8D6E63)
            ..strokeWidth = 0.8);
          c.drawPath(
              Path()
                ..moveTo(5, 0)
                ..lineTo(2.5, -1.4)
                ..lineTo(2.5, 1.4)
                ..close(),
              Paint()..color = pr.color);
          c.drawLine(const Offset(-5, 0), const Offset(-6.5, -1.2), Paint()
            ..color = Colors.white
            ..strokeWidth = 0.6);
          c.drawLine(const Offset(-5, 0), const Offset(-6.5, 1.2), Paint()
            ..color = Colors.white
            ..strokeWidth = 0.6);
          c.restore();
        case ProjKind.rock:
          c.save();
          c.translate(pr.x, pr.y);
          c.rotate(pr.t * 5);
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: Offset.zero, radius: pr.r), const Radius.circular(1.5)),
              Paint()..color = pr.color);
          c.drawCircle(const Offset(-1, -1), 1, Paint()..color = Colors.black26);
          c.restore();
        case ProjKind.potion:
        case ProjKind.bug:
          c.save();
          c.translate(pr.x, pr.y);
          c.rotate(pr.kind == ProjKind.potion ? pr.t * 8 : atan2(pr.vy, pr.vx));
          _text.draw(c, pr.glyph, 0, 0, 6, Colors.white);
          c.restore();
        case ProjKind.bubble:
          c.drawCircle(Offset(pr.x, pr.y), pr.r, Paint()..color = pr.color.withValues(alpha: 0.25));
          c.drawCircle(Offset(pr.x, pr.y), pr.r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.6
                ..color = pr.color);
          c.drawCircle(Offset(pr.x - pr.r * 0.35, pr.y - pr.r * 0.35), pr.r * 0.25,
              Paint()..color = Colors.white.withValues(alpha: 0.8));
        case ProjKind.boomerang:
          c.save();
          c.translate(pr.x, pr.y);
          c.rotate(pr.t * (pr.fromPlayer ? 16 : 10));
          if (pr.glyph.isEmpty) {
            // Umid's energy blade: two glowing crescents
            final glow = Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round;
            for (final a in const [0.0, pi]) {
              c.drawArc(Rect.fromCircle(center: Offset.zero, radius: pr.r), a, 2.2, false,
                  glow
                    ..strokeWidth = 2.6
                    ..color = pr.color.withValues(alpha: 0.35));
              c.drawArc(Rect.fromCircle(center: Offset.zero, radius: pr.r), a, 2.2, false,
                  glow
                    ..strokeWidth = 1.1
                    ..color = Colors.white);
            }
          } else {
            _text.draw(c, pr.glyph, 0, 0, 9, pr.color);
          }
          c.restore();
        case ProjKind.wave:
          final dir = pr.vx.sign;
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = pr.color;
          for (var i = 0; i < 3; i++) {
            c.drawArc(Rect.fromCircle(center: Offset(pr.x - dir * i * 3, pr.y), radius: pr.r - i),
                dir > 0 ? -pi / 2.5 : pi - pi / 2.5, pi / 1.25, false,
                paint..color = pr.color.withValues(alpha: 1 - i * 0.3));
          }
          _text.draw(c, pr.glyph, pr.x + dir * 2, pr.y, 6, Colors.white);
        case ProjKind.glyph:
        case ProjKind.letter:
          _text.draw(c, pr.glyph, pr.x + 0.3, pr.y + 0.3, 5.5, Colors.black54);
          _text.draw(c, pr.glyph, pr.x, pr.y, 5.5, pr.color);
      }
    }
  }

  void _drawHazards(Canvas c, {required bool under}) {
    for (final h in _hazards) {
      final isUnder = h.kind == HazardKind.puddle;
      if (isUnder != under) continue;
      switch (h.kind) {
        case HazardKind.puddle:
          final fade = (h.warn + h.active - h.t).clamp(0.0, 0.5) / 0.5;
          final blink = !h.armed && (h.t * 10).floor().isEven;
          c.drawOval(Rect.fromCenter(center: Offset(h.x, h.y - 0.4), width: h.w, height: 2.6),
              Paint()..color = h.color.withValues(alpha: (h.armed ? 0.65 : (blink ? 0.4 : 0.15)) * fade));
          if (h.glyph != '?') _text.draw(c, h.glyph, h.x, h.y - 3.2, 5, h.color, alpha: h.armed ? fade : 0.6);
          if (rng.nextDouble() < 0.08) {
            _sparks.add(Spark(h.x + (rng.nextDouble() - 0.5) * h.w, h.y - 1, 0, -18, 0.4, 0.7, h.color));
          }
        case HazardKind.spike:
          if (!h.armed) {
            final blink = (h.t * 10).floor().isEven;
            c.drawRect(Rect.fromLTWH(h.x - h.w / 2, h.y - 1, h.w, 1),
                Paint()..color = h.color.withValues(alpha: blink ? 0.9 : 0.4));
            _text.draw(c, h.glyph, h.x, h.y - 5, 5, h.color, alpha: blink ? 1 : 0.5);
          } else {
            final grow = ((h.t - h.warn) / 0.08).clamp(0.0, 1.0);
            final path = Path()
              ..moveTo(h.x - h.w / 2, h.y)
              ..lineTo(h.x, h.y - h.h * grow)
              ..lineTo(h.x + h.w / 2, h.y)
              ..close();
            c.drawPath(path, Paint()..color = h.color);
            _text.draw(c, h.glyph, h.x, h.y - h.h * grow * 0.45, 4, const Color(0xFF111111));
          }
        case HazardKind.laser:
          final rr = h.rect;
          if (!h.armed) {
            final blink = (h.t * 12).floor().isEven;
            c.drawRect(Rect.fromLTWH(0, rr.center.dy - 0.3, W, 0.6),
                Paint()..color = h.color.withValues(alpha: blink ? 0.9 : 0.3));
            _text.draw(c, h.glyph, W / 2, rr.top - 3, 2.8, h.color);
          } else {
            c.drawRect(rr.inflate(1.5), Paint()..color = h.color.withValues(alpha: 0.35));
            c.drawRect(rr, Paint()..color = h.color);
            c.drawRect(Rect.fromLTWH(0, rr.center.dy - 0.8, W, 1.6), Paint()..color = Colors.white);
          }
        case HazardKind.tornado:
          final a = h.armed ? 1.0 : h.t / max(0.01, h.warn);
          final swirl = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = h.color.withValues(alpha: 0.75 * a);
          for (var i = 0; i < 7; i++) {
            final f = i / 6;
            final w = 3 + f * h.w;
            final y = h.y - f * h.h;
            final wob = sin(_clock * 9 + i) * 2;
            c.drawOval(Rect.fromCenter(center: Offset(h.x + wob, y), width: w, height: 2.4), swirl);
          }
          if (rng.nextDouble() < 0.3) {
            _sparks.add(Spark(h.x + (rng.nextDouble() - 0.5) * 10, h.y - rng.nextDouble() * h.h,
                (rng.nextDouble() - 0.5) * 40, -10, 0.3, 0.7, h.color));
          }
        case HazardKind.shockwave:
          if (!h.armed) continue;
          final rr = h.rect;
          final path = Path()
            ..moveTo(rr.left - 3, rr.bottom)
            ..quadraticBezierTo(rr.center.dx, rr.top - 4, rr.right + 3, rr.bottom)
            ..close();
          c.drawPath(path, Paint()..color = h.color.withValues(alpha: 0.75));
          _text.draw(c, '!', rr.center.dx, rr.center.dy, 4, Colors.white);
      }
    }
  }

  void _drawPickups(Canvas c) {
    for (final pk in _pickups) {
      if (pk.life < 3 && (pk.life * 6).floor().isOdd) continue;
      final bob = pk.vy == 0 ? sin(pk.t * 4) * 0.8 : 0.0;
      c.drawCircle(Offset(pk.x, pk.y - 4 + bob), 4.5,
          Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.2));
      _text.draw(c, pk.emoji, pk.x, pk.y - 4 + bob, 6, Colors.white);
    }
  }

  void _drawFx(Canvas c) {
    for (final s in _sparks) {
      final a = (s.life / s.maxLife).clamp(0.0, 1.0);
      c.drawRect(Rect.fromCenter(center: Offset(s.x, s.y), width: s.size, height: s.size),
          Paint()..color = s.color.withValues(alpha: a));
    }
    for (final f in _floats) {
      _text.draw(c, f.text, f.x, f.y, f.size, f.color, alpha: f.life / f.maxLife * 1.5);
    }
  }

  // ── HUD ─────────────────────────────────────────────────────────────────
  void _bar(Canvas c, Rect r, double v, Color color, {bool fromRight = false}) {
    const p = 100 / kPixelRows; // one buffer pixel
    c.drawRect(r.inflate(p), Paint()..color = const Color(0xFF0E0A14));
    c.drawRect(r, Paint()..color = const Color(0xFF2A2F3D));
    final w = ((r.width * v.clamp(0.0, 1.0)) / p).floor() * p;
    if (w <= 0) return;
    final fill = fromRight ? Rect.fromLTWH(r.right - w, r.top, w, r.height) : Rect.fromLTWH(r.left, r.top, w, r.height);
    c.drawRect(fill, Paint()..color = color);
    c.drawRect(Rect.fromLTWH(fill.left, fill.top, fill.width, p), Paint()..color = Color.lerp(color, Colors.white, 0.45)!);
    if (fill.height > 2 * p) {
      c.drawRect(Rect.fromLTWH(fill.left, fill.bottom - p, fill.width, p),
          Paint()..color = Color.lerp(color, Colors.black, 0.3)!);
    }
  }

  void _drawHud(Canvas c) {
    final p = player, t = teacher;
    // Player (starts at kHudLeft: the pause button sits to its left)
    const hx = kHudLeft;
    _text.draw(c, '${hero.emoji} ${hero.name.toUpperCase()} · 🕒 ${clockText(clockMinutes)} · ${timeLeftText(clockMinutes)}',
        hx, 4, 2.6, Colors.white,
        left: true);
    final hpFrac = p.hp / p.maxHp;
    PixelArt.drawIcon(c, 'heart', const Offset(hx + 1.6, 8.6), 3.4);
    _bar(c, const Rect.fromLTWH(hx + 4, 7, 46, 3.2), hpFrac,
        Color.lerp(const Color(0xFFFF1744), const Color(0xFF00E676), hpFrac)!);
    _text.draw(c, '${p.hp.ceil()}', hx + 27, 8.6, 2.2, Colors.white);
    final full = p.energy >= 100;
    PixelArt.drawIcon(c, 'bolt', const Offset(hx + 1.6, 12.4), 3.2);
    _bar(c, const Rect.fromLTWH(hx + 4, 11.5, 34, 1.8), p.energy / 100,
        full ? ((_clock * 6).floor().isEven ? const Color(0xFFFFF59D) : const Color(0xFFFFD54F)) : const Color(0xFFFFB300));
    if (full) _text.draw(c, 'POWER READY!', hx + 40, 12.4, 2.0, const Color(0xFFFFD54F), left: true);

    // Right side: the teacher in classrooms, the monster wave in halls
    if (_boss) {
      final name = bossName;
      final nw = _text.get(name, 2.6, Colors.white).width;
      _text.draw(c, name, W - 3 - nw, 4, 2.6, Colors.white, left: true);
      PixelArt.drawIcon(c, fearPhase ? 'skull' : _bossIcon, Offset(W - 6 - nw, 4), 3.6);
      _bar(c, Rect.fromLTWH(W - 55, 7, 52, 3.2), t.hp / t.maxHp,
          fearPhase
              ? const Color(0xFF8E0000)
              : t.rage
                  ? const Color(0xFFFF1744)
                  : def.accent,
          fromRight: true);
    } else if (escaping) {
      const label = '🌅 MORNING · WAKE UP!';
      _text.draw(c, label, W - 3 - _text.get(label, 2.6, Colors.white).width, 4, 2.6, Colors.white, left: true);
    } else if (room.kind == RoomKind.hall) {
      final label = phase == Phase.cleared ? 'ALL MONSTERS DEFEATED' : '👾 MONSTERS LEFT: $minionCount';
      _text.draw(c, label, W - 3 - _text.get(label, 2.6, Colors.white).width, 4, 2.6, Colors.white, left: true);
      final total = room.waves.length;
      final progress = phase == Phase.cleared ? 1.0 : wave / total;
      _bar(c, Rect.fromLTWH(W - 55, 7, 52, 3.2), 1 - progress, def.accent, fromRight: true);
    }

    // Rooms on this floor
    final ids = [for (var i = 0; i < kRooms.length; i++) if (kRooms[i].building == room.building) i];
    final n = ids.length;
    const step = 6.0;
    final startX = W / 2 - (n - 1) * step / 2;
    final bc = room.buildingDef.color;
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(startX - 8, 6.5), width: 7, height: 5),
            const Radius.circular(1)),
        Paint()..color = bc.withValues(alpha: 0.25));
    _text.draw(c, room.building, startX - 8, 6.6, 3, bc);
    for (var j = 0; j < n; j++) {
      final i = ids[j];
      final x = startX + j * step;
      final done = i < floor || (i == floor && phase == Phase.cleared);
      final current = i == floor;
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 6.5), width: 5, height: 5), const Radius.circular(1)),
        Paint()
          ..color = current
              ? def.accent
              : done
                  ? const Color(0xFF00E676)
                  : Colors.white.withValues(alpha: 0.15),
      );
      _text.draw(c, kRooms[i].kind == RoomKind.hall ? '!' : kRooms[i].kind == RoomKind.rest ? '+' : '${kRooms[i].number}',
          x, 6.6, 2.6, current ? Colors.black : Colors.white);
    }
    final mins = (runTime ~/ 60).toString(), secs = (runTime % 60).floor().toString().padLeft(2, '0');
    final info = switch (room.kind) {
      RoomKind.boss => '${def.subject}  ·  ${rounds == 2 ? 'ROUND' : 'PHASE'} $round/$rounds $roundName',
      RoomKind.hall => '${room.name.toUpperCase()}  ·  WAVE ${wave + 1}/${room.waves.length}',
      RoomKind.rest => '${room.name.toUpperCase()}  ·  MIRA',
    };
    _text.draw(c, '$info  ·  $mins:$secs', W / 2, 12.4, 2.2,
        _boss && isFinalRound ? const Color(0xFFFF8A80) : Colors.white70);
    if (perks.isNotEmpty) {
      // Lost Notes found, as a row of pixel icons
      PixelArt.drawIcon(c, 'scroll', const Offset(kHudLeft + 1.6, 17), 3.2);
      var nx = kHudLeft + 5.0;
      for (final pk in perks) {
        final icon = textPieces(kPerks[pk]!.emoji).first.icon;
        if (icon == null) continue;
        PixelArt.drawIcon(c, icon, Offset(nx + 1.5, 17), 3);
        nx += 4.2;
      }
    }

    // Combo counter
    if (comboCount >= 3) {
      final col = comboCount >= 20
          ? const Color(0xFFFF4081)
          : comboCount >= 10
              ? const Color(0xFFFFD54F)
              : Colors.white;
      c.save();
      c.translate(W - 14, 24);
      c.scale(1 + _comboPop * 0.45);
      _text.draw(c, '$comboCount', 0.3, 0.3, 7, Colors.black54);
      _text.draw(c, '$comboCount', 0, 0, 7, col);
      c.restore();
      _text.draw(c, 'HIT COMBO', W - 14, 29.6, 2.4, col);
    }

    // Banner
    if (_bannerTime > 0) {
      final a = min(1.0, _bannerTime * 2);
      final scale = 1 + max(0.0, (_bannerTime - 1.2)) * 0.2;
      c.save();
      c.translate(W / 2, 36);
      c.scale(scale);
      _text.draw(c, _banner, 0.5, 0.5, 9, Colors.black, alpha: a * 0.6);
      _text.draw(c, _banner, 0, 0, 9, const Color(0xFFFFD54F), alpha: a);
      c.restore();
    }
  }
}

/// The shadow of a beaten boss, rising for one attack (Reaper phase 2).
class _Echo {
  final TeacherDef def;
  final double x;
  final int facing;
  double t = 0;
  _Echo(this.def, this.x, this.facing);
}

/// An ambient vibe particle (dust, code rain, spores, fireflies…).
class _Amb {
  final Particle kind;
  double x, y, vx, vy, life;
  final double maxLife;
  double phase = 0;
  String glyph = '';
  _Amb(this.kind, this.x, this.y, this.vx, this.vy, this.life) : maxLife = life;
}

/// A classmate standing in the room (decoration that talks).
class Npc {
  final NpcDef def;
  final double x;
  final Paint paint;
  double t = 0, alpha = 1, sayTime = 0, sayDelay = 0;
  String text = '';
  Npc(this.def, this.x, this.paint);

  void say(String line, double time, {double delay = 0}) {
    text = line;
    sayTime = time;
    sayDelay = delay;
  }
}
