// lib/game/school_game.dart
// "Class Clash" — a Millat Umidi student fights their way from the basement
// to the top floor. Every floor has a teacher boss with subject-based powers.
//
// The world is measured in units where the screen height is 100; the canvas
// is scaled by [unit] when drawing.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import 'entities.dart';
import 'heroes.dart';
import 'minions.dart';
import 'sprites.dart';
import 'teachers.dart';

const double kGround = 80;
const double kGravity = 330;
const double kJumpSpeed = 150;
const double kCharHeight = 24; // world units

const kAllOverlays = ['menu', 'intro', 'controls', 'pause', 'gameOver', 'victory'];

enum Phase { menu, intro, fight, roundBreak, cleared, transition, gameOver, victory }

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
  'FlyingEye': (
    'Monsters_Creatures_Fantasy/Flying eye',
    SpriteGeom(150, 150, 77, 92, 31),
    {
      'Idle': ('Flight', 12), 'Run': ('Flight', 14), 'Attack_1': ('Attack', 14),
      'Hurt': ('Take Hit', 12), 'Dead': ('Death', 10),
    },
  ),
};

const _freeKnightFolders = {
  'DarkKnight': 'FreeKnight_v1/Colour1/NoOutline/120x80_PNGSheets',
  'SilverKnight': 'FreeKnight_v1/Colour2/NoOutline/120x80_PNGSheets',
};

const _animNames = [
  'Idle', 'Walk', 'Run', 'Jump', 'Attack_1', 'Attack_2', 'Attack_3', 'Attack_4', 'Hurt', 'Dead',
];
const _oneShot = {'Jump', 'Attack_1', 'Attack_2', 'Attack_3', 'Attack_4', 'Hurt', 'Dead', 'Shield'};

class SchoolGame extends Game with KeyboardEvents {
  final rng = Random();
  final _text = TextCache();
  final _bodies = <String, Map<String, SpriteAnim>>{};
  Map<String, SpriteAnim> get _heroAnims => _bodies[hero.body]!;
  Map<String, SpriteAnim> get _teacherAnims => _bodies[def.body]!;
  bool _ready = false;
  bool get isReady => _ready;

  /// World width (height is always 100).
  double W = 180;
  double get unit => size.y / 100;

  // ── Public state for overlays ───────────────────────────────────────────
  Phase phase = Phase.menu;
  bool isPaused = false;
  int floor = 0;
  int bestFloor = 0; // highest floor index reached; kFloors.length = graduated
  double runTime = 0;
  double? bestTime;
  int hitsLanded = 0;
  int retries = 0;
  final energy = ValueNotifier<double>(0);

  TeacherDef get def => kFloors[floor];

  /// 1 = MIDTERM, 2 = FINAL EXAM.
  int round = 1;
  bool get isFinalRound => round == kRoundsPerFloor;
  String get roundName => isFinalRound ? 'FINAL EXAM' : 'MIDTERM';
  List<Ability> get currentAbilities => _abilities;
  List<Ability> get _abilities => isFinalRound ? [...def.abilities, ...def.finalAbilities] : def.abilities;
  double _roundBreak = 0;
  bool get isLastFloor => floor == kFloors.length - 1;

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

    final prefs = await SharedPreferences.getInstance();
    bestFloor = (prefs.getInt('best_floor') ?? 0).clamp(0, kFloors.length);
    bestTime = prefs.getDouble('best_time_$kFloorsVersion');
    selectHero(prefs.getInt('hero') ?? 0, save: false);

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
  int get furthestFloor => bestFloor.clamp(0, kFloors.length - 1);

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
  bool isHeroUnlocked(int i) => bestFloor >= kHeroes[i].unlockFloor;

  void selectHero(int i, {bool save = true}) {
    if (i < 0 || i >= kHeroes.length || !isHeroUnlocked(i)) i = 0;
    heroIndex = i;
    _heroPaint = huePaint(hero.hue);
    player
      ..maxHp = hero.hp.toDouble()
      ..hp = hero.hp.toDouble()
      ..anim = 'Idle'
      ..state = PState.idle
      ..t = 0;
    if (save) {
      SharedPreferences.getInstance().then((prefs) => prefs.setInt('hero', i));
    }
  }

  void startRun({int fromFloor = 0}) {
    if (!isUnlocked(fromFloor)) fromFloor = 0;
    startFloor = fromFloor;
    player.maxHp = hero.hp.toDouble();
    runTime = 0;
    hitsLanded = 0;
    maxCombo = 0;
    retries = 0;
    player
      ..hp = player.maxHp
      ..energy = 0;
    _setupFloor(fromFloor);
    _showOnly('intro');
    phase = Phase.intro;
  }

  void beginFight() {
    _showOnly('controls');
    phase = Phase.fight;
    _banner = 'FIGHT!';
    _bannerTime = 1.4;
    teacher.say(def.taunts[rng.nextInt(def.taunts.length)]);
  }

  void retryFloor() {
    retries++;
    player
      ..hp = player.maxHp
      ..energy = 50;
    _setupFloor(floor, round: round); // retake the round you lost
    _showOnly('intro');
    phase = Phase.intro;
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
  }

  void resumeGame() {
    isPaused = false;
    overlays.remove('pause');
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
    _teacherPaint = huePaint(def.hue);
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
    t.maxHp = isFinalRound ? (def.hp * 1.3).roundToDouble() : def.hp.toDouble();
    t.hp = t.maxHp;
    return t;
  }

  void _buildPlatforms() {
    _platforms = [
      for (final p in def.platforms) Platform(p.x * W, kGround - p.h, p.w * W),
    ];
  }

  void _goUpstairs() {
    if (isLastFloor) {
      _win();
      return;
    }
    phase = Phase.transition;
    _fadingOut = true;
    overlays.remove('controls');
    left = right = false;
  }

  void _arriveNextFloor() {
    final hp = player.hp, en = player.energy;
    _setupFloor(floor + 1);
    player
      ..hp = min(player.maxHp, hp + 40)
      ..energy = en;
    if (floor > bestFloor) {
      bestFloor = floor;
      _save();
    }
    phase = Phase.intro;
    _showOnly('intro');
  }

  void _win() {
    phase = Phase.victory;
    left = right = false;
    bestFloor = kFloors.length;
    if (fullRun && (bestTime == null || runTime < bestTime!)) bestTime = runTime;
    _save();
    _showOnly('victory');
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best_floor', bestFloor);
    if (bestTime != null) await prefs.setDouble('best_time_$kFloorsVersion', bestTime!);
  }

  // ══════════════════════════════════════════════════════════════════════
  // Update
  // ══════════════════════════════════════════════════════════════════════
  @override
  void update(double dt) {
    if (!_ready || isPaused) return;
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
      if (_roundBreak <= 0) _startFinalRound();
    }

    _updatePlayer(dt);
    _updateTeacher(dt);
    _updateMinions(dt);
    _updateProjectiles(dt);
    _updateHazards(dt);
    _updatePickups(dt);
    _updateFx(dt);

    _jumpQ = _attackQ = _specialQ = _rollQ = false;
    energy.value = player.energy;
    if (_bannerTime > 0) _bannerTime -= dt;
    if (_comboPop > 0) _comboPop = max(0, _comboPop - dt * 4);
    if (comboCount > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) comboCount = 0;
    }

    if (_gameOverDelay > 0) {
      _gameOverDelay -= dt;
      if (_gameOverDelay <= 0) _showOnly('gameOver');
    }

    if (phase == Phase.cleared && player.x > W - 15 && player.onGround) {
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
      p.vx = dir * hero.speed * (p.slow > 0 ? 0.5 : 1) * (p.frenzy > 0 ? 1.35 : 1);
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
      if (p.state == PState.attack) {
        p.queued = true;
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
        if (p.rollT <= 0) _setP(PState.idle, 'Idle');
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
        p.energy = min(100, p.energy + 6);
        _burst(pr.x, pr.y, pr.color, n: 8);
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
        p.energy = min(100, p.energy + 15);
        _slowMo = max(_slowMo, 0.35);
        _floats.add(FloatText('PERFECT DODGE!', p.x, p.y - 30, const Color(0xFF80D8FF), size: 3.8, life: 1));
      }
      return;
    }
    comboCount = 0;
    p.hp -= dmg;
    p.invuln = 0.9;
    _floats.add(FloatText('-$dmg', p.x, p.y - 28, const Color(0xFFFF5252), size: 4.5));
    _burst(p.x, p.y - 12, const Color(0xFFFF5252), n: 10);
    _shake = max(_shake, 2.5);
    _vibrate(45);
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
          t.x = (t.x + t.dashDir * 150 * dt).clamp(10.0, W - 12);
          if (rng.nextBool()) _burst(t.x, t.y - 2, def.accent, n: 1, speed: 20);
        }
        final anim = _teacherAnims[t.anim]!;
        if (t.dash <= 0 && t.t >= max(anim.duration, t.fireAt + 0.1)) {
          _setT(TState.idle, 'Idle');
          t.cooldown = def.cooldown * (t.rage ? 0.65 : 1) * (isFinalRound ? 0.85 : 1) * (0.8 + rng.nextDouble() * 0.4);
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
          t.say('Class dismissed... over THERE!', 1.4);
        }

        _setT(move != 0 ? TState.walk : TState.idle, move != 0 ? 'Walk' : 'Idle');

        t.cooldown -= dt;
        if (t.cooldown <= 0) _startCast();

        t.tauntTimer -= dt;
        if (t.tauntTimer <= 0) {
          t.tauntTimer = 7 + rng.nextDouble() * 5;
          if (t.speechTime <= 0) t.say(def.taunts[rng.nextInt(def.taunts.length)]);
        }
    }

    // Touching the teacher hurts.
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
    final big = _bigAbilities.contains(a);
    final animName = a == Ability.slash ? (rng.nextBool() ? 'Attack_2' : 'Attack_3') : (big ? 'Attack_4' : 'Attack_1');
    final dur = _teacherAnims[animName]!.duration;
    t
      ..casting = a
      ..fired = false
      ..state = TState.cast
      ..anim = animName
      ..t = 0
      ..fireAt = a == Ability.slash ? dur * 0.5 : (big ? max(0.42, dur * 0.6) : max(0.24, dur * 0.55));
    if (big) t.say('${kAbilityName[a]!.toUpperCase()}!', 1.3);
  }

  void _damageTeacher(double dmg, double knock) {
    final t = teacher;
    if (t.state == TState.dead) return;
    t.hp -= dmg;
    t.flash = 0.12;
    hitsLanded++;
    _addCombo();
    if (player.frenzy > 0) player.hp = min(player.maxHp, player.hp + 2);
    player.energy = min(100, player.energy + 11);
    _floats.add(FloatText('-${dmg.round()}', t.x, t.y - 28 * t.s, Colors.white, size: 4.5));
    _burst(t.x, t.chestY, def.accent, n: 10);
    _hitStop = dmg >= 30 ? 0.12 : 0.05;
    _shake = max(_shake, dmg >= 30 ? 4 : 1.5);
    _vibrate(25);
    t.x = (t.x + knock * 0.2).clamp(10.0, W - 12);
    if (t.state != TState.cast) _setT(TState.hurt, 'Hurt');
    if (t.state == TState.hurt) t.t = 0;

    if (!t.rage && t.hp <= t.maxHp / 2) {
      t.rage = true;
      t.say(def.rage, 2.6);
      _banner = 'TEACHER IS ANGRY!';
      _bannerTime = 1.6;
    }
    if (t.hp <= 0) isFinalRound ? _defeatTeacher() : _midtermPassed();
  }

  /// Round 1 won: short break, then the teacher returns for the FINAL EXAM.
  void _midtermPassed() {
    final t = teacher;
    t
      ..hp = 0
      ..pullTime = 0
      ..dash = 0
      ..state = TState.dead
      ..anim = 'Dead'
      ..t = 0;
    t.say('Not bad... but that was only the midterm!', 2.6);
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
    _banner = 'MIDTERM PASSED!';
    _bannerTime = 2.4;
    _burst(t.x, t.chestY, def.accent, n: 30, speed: 80);
    _vibrate(120);
  }

  void _startFinalRound() {
    final old = teacher;
    round = kRoundsPerFloor;
    teacher = _newTeacher(old.x)..cooldown = 1.2;
    teacher.say(def.finalLine, 3);
    phase = Phase.fight;
    _banner = 'ROUND 2 · FINAL EXAM!';
    _bannerTime = 1.8;
    _shake = 4;
    _burst(teacher.x, teacher.chestY, def.accent, n: 30, speed: 80);
    _burst(teacher.x, teacher.chestY, Colors.white, n: 15, speed: 50);
    _summon(2); // the final exam starts with backup
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
    _banner = isLastFloor ? 'YOU PASSED! →  EXIT' : 'FLOOR CLEARED! → STAIRS';
    _bannerTime = 4;
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
    final t = teacher, p = player;
    final ox = t.x + t.facing * 8 * t.s, oy = t.chestY;
    final acc = def.accent;
    final dx = p.x - ox, dy = (p.y - 11) - oy;
    final len = max(0.001, sqrt(dx * dx + dy * dy));
    final ax = dx / len, ay = dy / len;

    switch (a) {
      case Ability.energyBall:
        _projectiles.add(Projectile(
            kind: ProjKind.orb, x: ox, y: oy, vx: ax * 95, vy: ay * 95, r: 3.5, dmg: 10,
            color: acc, glyph: _orbGlyph));
        if (t.rage) {
          _projectiles.add(Projectile(
              kind: ProjKind.orb, x: ox, y: oy, vx: ax * 70, vy: ay * 70 - 25, r: 3.5, dmg: 10,
              color: acc, glyph: _orbGlyph));
        }

      case Ability.appleRain:
        _rain('🍎', const Color(0xFFFF5252), t.rage ? 8 : 6, 9);

      case Ability.gravityPull:
        t.pullTime = t.rage ? 3.0 : 2.3;
        _floats.add(FloatText('GRAVITY!', t.x, t.y - 34, acc, size: 5, life: 1.2));

      case Ability.numberSpread:
        const glyphs = ['π', '√2', '∑', 'x²', '7', '∞', '÷', '%', '42', '0', 'Δ', 'sin'];
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
            dmg: 11, glyph: def.subject.startsWith('PROGRAMMING') ? '{ }' : '∞', color: acc, destructible: false, life: 3.2,
            phase: t.facing.toDouble()));

      case Ability.popQuiz:
        _spikes('?', acc, t.rage ? 4 : 3, roots: false);

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
        final word = t.rage ? 'DETENTION' : 'ESSAY';
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
        _floats.add(FloatText('SILENCE!', t.x, t.y - 36, acc, size: 6, life: 1.2));

      case Ability.bugSwarm:
        _swarm('🐛', ox, oy, t.rage ? 4 : 3);

      case Ability.beeSwarm:
        _swarm('🐝', ox, oy, t.rage ? 5 : 4);

      case Ability.vineTrap:
        _spikes('🌿', acc, t.rage ? 4 : 3, roots: true);

      case Ability.summon:
        _summon(t.rage ? 3 : 2);

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
              gravity: 220, r: 3.5, dmg: 10, glyph: def.emoji == '🌍' ? '🌍' : '🏐', color: acc, life: 4.5));
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
        _laser('AI: face detected · scanning...', acc);

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

  String get _orbGlyph => switch (def.subject) {
        'PHYSICS' => 'F',
        'HUMAN & AI' => 'AI',
        _ => 'H⁺',
      };

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

  // ── Combo ───────────────────────────────────────────────────────────────
  void _addCombo() {
    comboCount++;
    _comboTimer = 1.8;
    _comboPop = 1;
    maxCombo = max(maxCombo, comboCount);
    if (comboCount % 10 == 0) {
      player.energy = min(100, player.energy + 15);
      _banner = switch (comboCount) { 10 => 'GREAT! +⚡', 20 => 'AMAZING! +⚡', _ => 'MILLAT LEGEND! +⚡' };
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
    final fromFront = (fromX - m.x).sign == m.facing.sign;
    if (d.shield && !unblockable && fromFront && m.state != MState.attack) {
      _setM(m, MState.shield, 'Shield');
      m.t = 0;
      _floats.add(FloatText('BLOCKED!', m.x, m.y - d.height - 3, Colors.white70, size: 3));
      _burst(m.x + m.facing * 5, m.y - d.height * 0.6, Colors.white, n: 6, speed: 40);
      return false;
    }
    m.hp -= dmg;
    m.flash = 0.1;
    _floats.add(FloatText('-${dmg.round()}', m.x, m.y - d.height - 2, Colors.white, size: 3.2, life: 0.7));
    _burst(m.x, m.y - d.height / 2, d.color, n: 8);
    _addCombo();
    final p = player;
    p.energy = min(100, p.energy + 4);
    if (p.frenzy > 0) p.hp = min(p.maxHp, p.hp + 2);
    if (m.hp <= 0) {
      m.hp = 0;
      m.dive = 0;
      _setM(m, MState.dead, 'Dead');
      p.energy = min(100, p.energy + 6);
      _floats.add(FloatText('KO!', m.x, m.y - d.height - 6, d.color, size: 4, life: 0.9));
      if (rng.nextDouble() < 0.15) _pickups.add(Pickup(PickupKind.somsa, m.x, m.y - 10));
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
            if (fighting && box.overlaps(p.rect)) _hurtPlayer(d.dmg, m.x);
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
          pr.dead = true;
          _burst(pr.x, pr.y, pr.color, n: 25, speed: 80);
          _damageTeacher(pr.dmg.toDouble(), pr.vx.sign * (pr.kind == ProjKind.wave ? 60 : 10));
        }
        for (final m in _minions) {
          if (m.state == MState.dead || pr.dead || pr.hits.contains(m)) continue;
          if (m.rect.inflate(pr.r).contains(Offset(pr.x, pr.y))) {
            pr.hits.add(m);
            final wave = pr.kind == ProjKind.wave;
            _hitMinion(m, wave ? pr.dmg * 0.7 : pr.dmg.toDouble(), pr.x - pr.vx.sign * 5, unblockable: wave);
            if (!wave) pr.dead = true;
          }
        }
        // Waves erase everything; bolts trade with destructible projectiles.
        final isWave = pr.kind == ProjKind.wave;
        for (final o in _projectiles) {
          if (o.fromPlayer || o.dead || pr.dead || (!isWave && !o.destructible)) continue;
          if ((o.x - pr.x).abs() < pr.r + o.r && (o.y - pr.y).abs() < pr.r * 2 + o.r) {
            o.dead = true;
            if (!isWave) pr.dead = true;
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
            p.energy = min(100, p.energy + 50);
        }
        _floats.add(FloatText(pk.label, pk.x, pk.y - 26, const Color(0xFF69F0AE), size: 3.6, life: 1.3));
        _burst(pk.x, pk.y - 4, const Color(0xFF69F0AE), n: 12);
        _vibrate(30);
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

  void _vibrate(int ms) async {
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
  void render(Canvas c) {
    if (!_ready || size.y <= 0) return;
    final u = unit;
    c.save();
    if (_shake > 0) {
      c.translate((rng.nextDouble() - 0.5) * _shake * u, (rng.nextDouble() - 0.5) * _shake * u);
    }
    c.scale(u);
    _drawRoom(c);
    _drawPlatforms(c);
    _drawHazards(c, under: true);
    _drawPickups(c);
    _drawTeacher(c);
    _drawMinions(c);
    _drawPlayer(c);
    _drawProjectiles(c);
    _drawHazards(c, under: false);
    _drawFx(c);
    _drawSpeech(c);
    c.restore();

    if (phase != Phase.menu) {
      c.save();
      c.scale(u);
      _drawHud(c);
      c.restore();
    }

    if (_fade > 0) {
      c.drawRect(Offset.zero & Size(size.x, size.y),
          Paint()..color = Colors.black.withValues(alpha: _fade.clamp(0.0, 1.0)));
    }
  }

  // ── Room ────────────────────────────────────────────────────────────────
  void _drawRoom(Canvas c) {
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

    if (floor == 0) {
      _drawBasement(c);
    } else {
      _drawWindows(c);
    }
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
    c.drawLine(Offset(0, kGround + 9), Offset(W, kGround + 9), line);

    _drawDoors(c);
  }

  void _drawBasement(Canvas c) {
    final pipe = Paint()..color = const Color(0xFF546E7A);
    final pipeDark = Paint()..color = const Color(0xFF37474F);
    c.drawRect(Rect.fromLTWH(0, 17, W, 3), pipe);
    c.drawRect(Rect.fromLTWH(0, 19.5, W, 0.6), pipeDark);
    c.drawRect(Rect.fromLTWH(0, 23, W, 1.8), pipeDark);
    for (double x = 8; x < W; x += 36) {
      c.drawRect(Rect.fromLTWH(x, 16, 2, 9), pipeDark);
    }
    // hanging bulbs
    for (final x in [W * 0.15, W * 0.85]) {
      c.drawLine(Offset(x, 20), Offset(x, 30), Paint()
        ..color = Colors.black
        ..strokeWidth = 0.4);
      final flicker = 0.25 + 0.1 * sin(_clock * 13 + x);
      c.drawCircle(Offset(x, 32), 14, Paint()..color = const Color(0xFFFFE082).withValues(alpha: flicker * 0.35));
      c.drawCircle(Offset(x, 31.5), 1.8, Paint()..color = const Color(0xFFFFF59D));
    }
    _text.draw(c, '⚠ BASEMENT', W * 0.15, 42, 2.6, const Color(0xFFFFD54F));
  }

  void _drawWindows(Canvas c) {
    final t = floor / (kFloors.length - 1);
    final skyTop = Color.lerp(const Color(0xFF64B5F6), const Color(0xFFFF7043), t)!;
    final skyBottom = Color.lerp(const Color(0xFFBBDEFB), const Color(0xFFFFCC80), t)!;
    for (final wx in [W * 0.06, W * 0.80]) {
      final r = Rect.fromLTWH(wx, 22, 24, 30);
      c.drawRect(r.inflate(1.5), Paint()..color = const Color(0xFFD7CCC8));
      c.drawRect(r, Paint()..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [skyTop, skyBottom]));
      c.save();
      c.clipRect(r);
      // clouds drift
      final cx = wx + ((_clock * 2 + wx) % 34) - 6;
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.8);
      c.drawCircle(Offset(cx, 29), 2.5, cloud);
      c.drawCircle(Offset(cx + 3, 28), 3, cloud);
      c.drawCircle(Offset(cx + 6, 29.5), 2.2, cloud);
      // city skyline sinks as you climb higher
      final base = r.bottom + floor * 2.2 - 4;
      final city = Paint()..color = const Color(0xFF455A64);
      for (var i = 0; i < 6; i++) {
        final h = 6.0 + ((i * 37 + wx.toInt()) % 9);
        c.drawRect(Rect.fromLTWH(wx + i * 4.2, base - h, 3.6, h + 10), city);
      }
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
    _text.draw(c, 'MILLAT UMIDI UNIVERSITY', W / 2, by + 3.5, 2.4, Colors.white.withValues(alpha: 0.55));
    _text.draw(c, '${d.subject} CLASS', W / 2, by + 8.5, 3.2, d.accent);
    for (var i = 0; i < d.board.length; i++) {
      _text.draw(c, d.board[i], W / 2, by + 15 + i * 5.2, 3.4, Colors.white.withValues(alpha: 0.85),
          weight: FontWeight.w600);
    }
    c.drawRect(Rect.fromLTWH(bx + 4, by + bh + 1.6, bw - 8, 1.2), Paint()..color = const Color(0xFF8D6E63));
  }

  void _drawDoors(Canvas c) {
    // Entrance (left)
    final l = Rect.fromLTWH(1, kGround - 30, 12, 30);
    c.drawRect(l, Paint()..color = const Color(0xFF4E342E));
    c.drawRect(l.deflate(1.5), Paint()..color = const Color(0xFF6D4C41));
    _text.draw(c, floor == 0 ? '⬇ IN' : '▼', l.center.dx, l.top - 3, 2.4, Colors.white54);

    // Stairs (right)
    final r = Rect.fromLTWH(W - 13, kGround - 30, 12, 30);
    final open = phase == Phase.cleared || phase == Phase.transition || phase == Phase.victory;
    if (open) {
      final glow = 0.5 + 0.5 * sin(_clock * 6);
      c.drawRect(r.inflate(2 + glow), Paint()..color = def.accent.withValues(alpha: 0.25 + glow * 0.2));
      c.drawRect(r, Paint()..color = const Color(0xFF121212));
      final step = Paint()..color = const Color(0xFF5D4037);
      for (var i = 0; i < 6; i++) {
        c.drawRect(Rect.fromLTWH(r.left + i * 2, r.bottom - (i + 1) * 4.5, r.width - i * 2, 1.2), step);
      }
      final bob = sin(_clock * 5) * 1.5;
      _text.draw(c, isLastFloor ? '🎓' : '▲', r.center.dx, r.top - 5 + bob, 5, def.accent);
      _text.draw(c, isLastFloor ? 'GRADUATE' : 'NEXT FLOOR', r.center.dx - 4, r.top - 10 + bob, 2.6, Colors.white);
    } else {
      c.drawRect(r, Paint()..color = const Color(0xFF4E342E));
      c.drawRect(r.deflate(1.5), Paint()..color = const Color(0xFF5D4037));
      _text.draw(c, '🔒', r.center.dx, r.center.dy, 4, Colors.white);
    }
  }

  void _drawPlatforms(Canvas c) {
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
    _teacherAnims[t.anim]!.draw(c, t.t, t.x, t.y, s,
        flip: t.facing < 0, paint: t.flash > 0 ? flashPaint : _teacherPaint);
    if (t.state != TState.dead) {
      _text.draw(c, def.emoji, t.x, t.y - 29 * t.s, 3.6, Colors.white);
    }
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
      anim.draw(c, m.t, m.x, m.y, d.height, flip: m.facing < 0, paint: m.flash > 0 ? flashPaint : null);
      if (m.state != MState.dead && m.hp < d.hp) {
        final top = m.y - d.height - 2.5;
        c.drawRect(Rect.fromLTWH(m.x - 5, top, 10, 1.2), Paint()..color = Colors.black54);
        c.drawRect(Rect.fromLTWH(m.x - 5, top, 10 * (m.hp / d.hp), 1.2), Paint()..color = d.color);
      }
    }
  }

  void _drawSpeech(Canvas c) {
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
    tp.paint(c, Offset(cx - tp.width / 2, top + 1.5));
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
          c.rotate(pr.t * 10);
          _text.draw(c, pr.glyph, 0, 0, 9, pr.color);
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
          c.drawOval(Rect.fromCenter(center: Offset(h.x, h.y - 0.4), width: h.w, height: 2.6),
              Paint()..color = h.color.withValues(alpha: 0.65 * fade));
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
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(0.5), const Radius.circular(1.2)),
        Paint()..color = Colors.black.withValues(alpha: 0.6));
    final w = r.width * v.clamp(0.0, 1.0);
    final fill = fromRight ? Rect.fromLTWH(r.right - w, r.top, w, r.height) : Rect.fromLTWH(r.left, r.top, w, r.height);
    c.drawRRect(RRect.fromRectAndRadius(fill, const Radius.circular(1)), Paint()..color = color);
  }

  void _drawHud(Canvas c) {
    final p = player, t = teacher;
    // Player
    _text.draw(c, '${hero.emoji} ${hero.name.toUpperCase()} · MILLAT UMIDI', 3, 4, 2.6, Colors.white, left: true);
    final hpFrac = p.hp / p.maxHp;
    _bar(c, Rect.fromLTWH(3, 7, 46, 3.2), hpFrac,
        Color.lerp(const Color(0xFFFF1744), const Color(0xFF00E676), hpFrac)!);
    _text.draw(c, '${p.hp.ceil()}', 26, 8.6, 2.4, Colors.white);
    final full = p.energy >= 100;
    _bar(c, Rect.fromLTWH(3, 11.5, 34, 1.8), p.energy / 100,
        full ? Color.lerp(const Color(0xFFFFD54F), Colors.white, 0.5 + 0.5 * sin(_clock * 10))! : const Color(0xFFFFB300));
    _text.draw(c, full ? '⚡ POWER READY!' : '⚡', 39, 12.4, 2.2, const Color(0xFFFFD54F), left: true);

    // Teacher
    _text.draw(c, t.def.name, W - 3 - _text.get(t.def.name, 2.6, Colors.white).width, 4, 2.6,
        Colors.white, left: true);
    _bar(c, Rect.fromLTWH(W - 55, 7, 52, 3.2), t.hp / t.maxHp, t.rage ? const Color(0xFFFF1744) : def.accent,
        fromRight: true);

    // Floor tracker (B → 5)
    final n = kFloors.length;
    const step = 6.0;
    final startX = W / 2 - (n - 1) * step / 2;
    for (var i = 0; i < n; i++) {
      final x = startX + i * step;
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
      _text.draw(c, kFloors[i].floorLabel, x, 6.6, kFloors[i].floorLabel.length > 1 ? 2.2 : 2.8,
          current ? Colors.black : Colors.white);
    }
    final mins = (runTime ~/ 60).toString(), secs = (runTime % 60).floor().toString().padLeft(2, '0');
    _text.draw(c, '${def.subject}  ·  ROUND $round/$kRoundsPerFloor $roundName  ·  $mins:$secs', W / 2, 12.4, 2.2,
        isFinalRound ? const Color(0xFFFF8A80) : Colors.white70);

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
