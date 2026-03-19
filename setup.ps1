# setup.ps1
# ============================================================
# Stickman Physics – one-click project setup for Windows
# ============================================================
# Run from the folder WHERE you want the project created:
#   cd C:\Users\HP\Desktop
#   .\setup.ps1
# ============================================================

$ProjectName = "stickman_physics"
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Stickman Physics – Project Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. flutter create ─────────────────────────────────────────────────────────
Write-Host "[1/5] Running 'flutter create $ProjectName' ..." -ForegroundColor Yellow
flutter create --org com.example --platforms android $ProjectName

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: flutter create failed. Make sure Flutter is installed and on PATH." -ForegroundColor Red
    exit 1
}

Set-Location $ProjectName
Write-Host "      Done." -ForegroundColor Green

# ── 2. Replace pubspec.yaml ────────────────────────────────────────────────────
Write-Host "[2/5] Writing pubspec.yaml ..." -ForegroundColor Yellow
$pubspec = @'
name: stickman_physics
description: A physics-based stickman game controlled by phone motion.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flame: ^1.18.0
  flame_forge2d: ^0.18.0
  sensors_plus: ^4.0.2
  vibration: ^1.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
'@
$pubspec | Set-Content -Encoding UTF8 "pubspec.yaml"
Write-Host "      Done." -ForegroundColor Green

# ── 3. Write all Dart source files ────────────────────────────────────────────
Write-Host "[3/5] Writing Dart source files ..." -ForegroundColor Yellow

# Create directories
New-Item -ItemType Directory -Force -Path "lib\constants" | Out-Null
New-Item -ItemType Directory -Force -Path "lib\game"      | Out-Null

# ── lib\main.dart ──────────────────────────────────────────────────────────────
@'
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/stickman_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const StickmanApp());
}

class StickmanApp extends StatelessWidget {
  const StickmanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stickman Physics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _GamePage(),
    );
  }
}

class _GamePage extends StatefulWidget {
  const _GamePage();
  @override
  State<_GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<_GamePage> {
  final _game = StickmanGame();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hint': (context, game) => _HintOverlay(
                onDismiss: () => _game.overlays.remove('hint'),
              ),
        },
        initialActiveOverlays: const ['hint'],
      ),
    );
  }
}

class _HintOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const _HintOverlay({required this.onDismiss});
  @override
  State<_HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<_HintOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }
  void _dismiss() {
    if (!mounted) return;
    _ctrl.forward().then((_) => widget.onDismiss());
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: FadeTransition(
        opacity: ReverseAnimation(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
        child: Container(
          alignment: Alignment.center,
          color: Colors.black.withOpacity(0.65),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_rotation, color: Colors.cyanAccent, size: 52),
              SizedBox(height: 18),
              Text('Tilt to move',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              SizedBox(height: 10),
              Text('Shake for a surprise! 💥',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 17)),
              SizedBox(height: 28),
              Text('(tap to dismiss)',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
'@ | Set-Content -Encoding UTF8 "lib\main.dart"

# ── lib\constants\game_constants.dart ─────────────────────────────────────────
@'
// lib/constants/game_constants.dart
const double kPixelsPerMeter       = 100.0;
const double kGravityStrength      = 28.0;
const double kSensorAlpha          = 0.12;
const double kShakeThreshold       = 18.0;
const int    kShakeCooldownMs      = 500;
const double kShakeImpulseStrength = 22.0;
const double kStickmanRadius       = 0.32;
const double kStickmanRestitution  = 0.55;
const double kStickmanFriction     = 0.35;
const double kStickmanDensity      = 1.2;
const double kStickmanLinearDamping  = 0.4;
const double kStickmanAngularDamping = 1.8;
const double kWallThickness        = 0.5;
const double kWallRestitution      = 0.45;
const double kWallFriction         = 0.4;
const int    kParticleCount        = 22;
const double kParticleLifespan     = 0.75;
const double kParticleMaxSpeed     = 700.0;
const double kParticleRadius       = 4.5;
const double kHudFontSize          = 12.5;
'@ | Set-Content -Encoding UTF8 "lib\constants\game_constants.dart"

# ── lib\game\sensors_controller.dart ──────────────────────────────────────────
@'
// lib/game/sensors_controller.dart
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';
import '../constants/game_constants.dart';

class SensorData {
  final Vector2 gravity;
  final double magnitude;
  const SensorData({required this.gravity, required this.magnitude});
}

class SensorsController {
  SensorData data = SensorData(gravity: Vector2(0, kGravityStrength), magnitude: 0);
  void Function(Vector2 direction)? onShake;

  StreamSubscription<AccelerometerEvent>? _sub;
  double _fx = 0;
  double _fy = kGravityStrength;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  void start() {
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onEvent);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _onEvent(AccelerometerEvent e) {
    final rawX = -e.x;
    final rawY = -e.y;
    final len = sqrt(rawX * rawX + rawY * rawY);
    double nx, ny;
    if (len > 1.0) {
      nx = (rawX / len) * kGravityStrength;
      ny = (rawY / len) * kGravityStrength;
    } else {
      nx = 0;
      ny = kGravityStrength;
    }
    _fx = kSensorAlpha * nx + (1 - kSensorAlpha) * _fx;
    _fy = kSensorAlpha * ny + (1 - kSensorAlpha) * _fy;

    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final now = DateTime.now();
    if (mag > kShakeThreshold &&
        now.difference(_lastShake).inMilliseconds > kShakeCooldownMs) {
      _lastShake = now;
      final dir = Vector2(-_fx, -_fy);
      if (dir.length > 0.01) dir.normalize();
      onShake?.call(dir);
    }
    data = SensorData(gravity: Vector2(_fx, _fy), magnitude: mag);
  }
}
'@ | Set-Content -Encoding UTF8 "lib\game\sensors_controller.dart"

# ── lib\game\world_walls.dart ──────────────────────────────────────────────────
@'
// lib/game/world_walls.dart
import 'package:flame_forge2d/flame_forge2d.dart';
import '../constants/game_constants.dart';

class WallBody extends BodyComponent {
  final Vector2 _pos;
  final Vector2 _halfSize;
  WallBody(this._pos, this._halfSize);

  @override
  Body createBody() {
    final body = world.createBody(BodyDef()
      ..type = BodyType.static
      ..position = _pos);
    final shape = PolygonShape()..setAsBoxXY(_halfSize.x, _halfSize.y);
    body.createFixture(FixtureDef(shape)
      ..restitution = kWallRestitution
      ..friction = kWallFriction
      ..density = 0);
    return body;
  }

  @override
  void render(Canvas canvas) {}
}

List<WallBody> buildWalls(Vector2 ws) {
  final w = ws.x, h = ws.y, t = kWallThickness;
  return [
    WallBody(Vector2(w / 2, h + t), Vector2(w / 2 + t, t)),
    WallBody(Vector2(w / 2, -t),    Vector2(w / 2 + t, t)),
    WallBody(Vector2(-t, h / 2),    Vector2(t, h / 2 + t)),
    WallBody(Vector2(w + t, h / 2), Vector2(t, h / 2 + t)),
  ];
}
'@ | Set-Content -Encoding UTF8 "lib\game\world_walls.dart"

# ── lib\game\particles.dart ────────────────────────────────────────────────────
@'
// lib/game/particles.dart
import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import '../constants/game_constants.dart';

class _P {
  Vector2 pos, vel;
  double life;
  final double maxLife;
  final Color color;
  _P({required this.pos, required this.vel, required this.life, required this.color})
      : maxLife = life;
}

class ParticleSystem extends Component {
  final _list = <_P>[];
  final _rng  = Random();
  static const _colors = [
    Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFF4500),
    Color(0xFFFFFFFF), Color(0xFF00E5FF),
  ];

  void burst(Vector2 worldPos) {
    final sp = worldPos * kPixelsPerMeter;
    for (int i = 0; i < kParticleCount; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = (_rng.nextDouble() * 0.7 + 0.3) * kParticleMaxSpeed;
      _list.add(_P(
        pos:   sp.clone(),
        vel:   Vector2(cos(angle) * speed, sin(angle) * speed),
        life:  kParticleLifespan * (0.5 + _rng.nextDouble() * 0.5),
        color: _colors[_rng.nextInt(_colors.length)],
      ));
    }
  }

  @override
  void update(double dt) {
    for (final p in _list) {
      p.life  -= dt;
      p.vel.y += 400 * dt;
      p.pos   += p.vel * dt;
    }
    _list.removeWhere((p) => p.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in _list) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      paint.color = p.color.withOpacity(t);
      canvas.drawCircle(Offset(p.pos.x, p.pos.y), kParticleRadius * t + 1, paint);
    }
  }
}
'@ | Set-Content -Encoding UTF8 "lib\game\particles.dart"

# ── lib\game\player.dart ───────────────────────────────────────────────────────
@'
// lib/game/player.dart
import 'dart:math';
import 'package:flame_forge2d/flame_forge2d.dart';
import '../constants/game_constants.dart';

class StickmanBody extends BodyComponent {
  final Vector2 startPosition;
  bool _flashActive = false;
  double _flashTimer = 0;

  StickmanBody({required this.startPosition});

  @override
  Body createBody() {
    final body = world.createBody(BodyDef()
      ..type = BodyType.dynamic
      ..position = startPosition
      ..linearDamping = kStickmanLinearDamping
      ..angularDamping = kStickmanAngularDamping
      ..fixedRotation = false);
    final shape = CircleShape()..radius = kStickmanRadius;
    body.createFixture(FixtureDef(shape)
      ..restitution = kStickmanRestitution
      ..friction = kStickmanFriction
      ..density = kStickmanDensity);
    return body;
  }

  void applyShakeImpulse(Vector2 direction) {
    body.applyLinearImpulse(direction.scaled(kShakeImpulseStrength));
    _flashActive = true;
    _flashTimer  = 0.22;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashActive) {
      _flashTimer -= dt;
      if (_flashTimer <= 0) _flashActive = false;
    }
  }

  @override
  void render(Canvas canvas) {
    final double r = kStickmanRadius * kPixelsPerMeter;
    final bodyFill = _flashActive ? const Color(0xFFFFFFFF) : const Color(0xFF00E5FF);
    const outline  = Color(0xFF005F73);
    const skin     = Color(0xFFFFD6A5);
    const dark     = Color(0xFF222222);

    final fillP   = Paint()..color = bodyFill..style = PaintingStyle.fill;
    final outlineP = Paint()..color = outline..style = PaintingStyle.stroke..strokeWidth = 2.2;
    final skinP   = Paint()..color = skin..style = PaintingStyle.fill;
    final lineP   = Paint()..color = outline..style = PaintingStyle.stroke
                            ..strokeCap = StrokeCap.round..strokeWidth = 2.8;
    final dotP    = Paint()..color = dark..style = PaintingStyle.fill;

    // Torso
    canvas.drawCircle(Offset.zero, r, fillP);
    canvas.drawCircle(Offset.zero, r, outlineP);

    // Head
    final hr = r * 0.52, hcy = -r * 1.05;
    canvas.drawCircle(Offset(0, hcy), hr, skinP);
    canvas.drawCircle(Offset(0, hcy), hr, outlineP);
    canvas.drawCircle(Offset(-hr * 0.30, hcy - hr * 0.08), hr * 0.13, dotP);
    canvas.drawCircle(Offset( hr * 0.30, hcy - hr * 0.08), hr * 0.13, dotP);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0, hcy + hr * 0.18), width: hr * 0.65, height: hr * 0.38),
      0, pi, false,
      Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 1.8,
    );

    // Arms
    canvas.drawLine(Offset(-r * 0.8, -r * 0.2), Offset(-r * 1.5,  r * 0.5), lineP);
    canvas.drawLine(Offset( r * 0.8, -r * 0.2), Offset( r * 1.5,  r * 0.5), lineP);

    // Legs
    canvas.drawLine(Offset(-r * 0.3, r * 0.82), Offset(-r * 0.72, r * 1.6), lineP);
    canvas.drawLine(Offset( r * 0.3, r * 0.82), Offset( r * 0.72, r * 1.6), lineP);
  }
}
'@ | Set-Content -Encoding UTF8 "lib\game\player.dart"

# ── lib\game\stickman_game.dart ────────────────────────────────────────────────
@'
// lib/game/stickman_game.dart
import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' show TextStyle, Color, Colors;
import 'package:vibration/vibration.dart';
import '../constants/game_constants.dart';
import 'particles.dart';
import 'player.dart';
import 'sensors_controller.dart';
import 'world_walls.dart';

class StickmanGame extends Forge2DGame {
  final _sensors = SensorsController();
  late StickmanBody _player;
  late ParticleSystem _particles;
  double _shakeAlpha = 0;

  StickmanGame()
      : super(gravity: Vector2(0, kGravityStrength), zoom: kPixelsPerMeter);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final ws = Vector2(size.x / kPixelsPerMeter, size.y / kPixelsPerMeter);
    await addAll(buildWalls(ws));
    _player = StickmanBody(startPosition: Vector2(ws.x / 2, ws.y / 2));
    await add(_player);
    _particles = ParticleSystem();
    await add(_particles);
    _sensors.onShake = _handleShake;
    _sensors.start();
  }

  @override
  void onRemove() {
    _sensors.dispose();
    super.onRemove();
  }

  @override
  void update(double dt) {
    world.setGravity(_sensors.data.gravity);
    if (_shakeAlpha > 0) _shakeAlpha = (_shakeAlpha - dt * 3.5).clamp(0.0, 1.0);
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF0A1628));
    _drawGrid(canvas);
    super.render(canvas);
    if (_shakeAlpha > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
          Paint()..color = const Color(0xFF00E5FF).withOpacity(_shakeAlpha * 0.22));
    }
    _drawHUD(canvas);
  }

  void _handleShake(Vector2 dir) {
    _player.applyShakeImpulse(dir);
    _particles.burst(_player.body.position);
    _shakeAlpha = 1.0;
    _vibrate();
  }

  void _vibrate() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 55, amplitude: 200);
      }
    } catch (_) {}
  }

  void _drawGrid(Canvas canvas) {
    final p = Paint()..color = const Color(0xFF162844)..strokeWidth = 0.6;
    for (double x = 0; x < size.x; x += 55) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), p);
    }
    for (double y = 0; y < size.y; y += 55) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), p);
    }
  }

  final _tp = TextPainter(textDirection: TextDirection.ltr);

  void _drawHUD(Canvas canvas) {
    final g = _sensors.data.gravity;
    final mag = _sensors.data.magnitude;
    _drawArrow(canvas, g);
    const style = TextStyle(color: Color(0xFF8ECAE6), fontSize: kHudFontSize, fontFamily: 'monospace');
    double y = 10;
    for (final l in [
      'G  x:${g.x.toStringAsFixed(1)}  y:${g.y.toStringAsFixed(1)}',
      'Shake: ${mag.toStringAsFixed(1)} / $kShakeThreshold m/s\u00B2',
    ]) {
      _tp..text = TextSpan(text: l, style: style)..layout();
      _tp.paint(canvas, Offset(60, y));
      y += kHudFontSize + 5;
    }
    final bx = 60.0, by = y + 2, bw = size.x - 72;
    final filled = (mag / (kShakeThreshold * 1.4)).clamp(0.0, 1.0) * bw;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, 5), const Radius.circular(3)),
        Paint()..color = const Color(0xFF1A3A5C));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, filled, 5), const Radius.circular(3)),
        Paint()..color = mag > kShakeThreshold ? const Color(0xFFFF4500) : const Color(0xFF00E5FF));
  }

  void _drawArrow(Canvas canvas, Vector2 g) {
    final len = g.length;
    if (len < 0.5) return;
    const cx = 30.0, cy = 30.0, al = 18.0;
    final nx = g.x / len, ny = g.y / len;
    final tx = cx + nx * al, ty = cy + ny * al;
    final ap = Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawCircle(const Offset(cx, cy), al + 5, Paint()..color = const Color(0x22FFFFFF));
    canvas.drawLine(Offset(cx, cy), Offset(tx, ty), ap);
    final ang = atan2(ny, nx);
    canvas.drawLine(Offset(tx, ty), Offset(tx - 7 * cos(ang - 0.45), ty - 7 * sin(ang - 0.45)), ap);
    canvas.drawLine(Offset(tx, ty), Offset(tx - 7 * cos(ang + 0.45), ty - 7 * sin(ang + 0.45)), ap);
  }
}
'@ | Set-Content -Encoding UTF8 "lib\game\stickman_game.dart"

Write-Host "      Done." -ForegroundColor Green

# ── 4. Patch AndroidManifest.xml to add VIBRATE permission ────────────────────
Write-Host "[4/5] Patching AndroidManifest.xml ..." -ForegroundColor Yellow
$manifestPath = "android\app\src\main\AndroidManifest.xml"
$manifest = Get-Content $manifestPath -Raw
if ($manifest -notmatch "VIBRATE") {
    $manifest = $manifest -replace '<manifest ', '<manifest xmlns:android="http://schemas.android.com/apk/res/android"' + "`n    "
    # Safer: just insert before <application
    $manifest = $manifest -replace '(<application)', '    <uses-permission android:name="android.permission.VIBRATE" />' + "`n    " + '$1'
    $manifest | Set-Content -Encoding UTF8 $manifestPath
    Write-Host "      VIBRATE permission added." -ForegroundColor Green
} else {
    Write-Host "      Already has VIBRATE permission." -ForegroundColor Green
}

# ── 5. flutter pub get ─────────────────────────────────────────────────────────
Write-Host "[5/5] Running 'flutter pub get' ..." -ForegroundColor Yellow
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: flutter pub get failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Connect your Android phone (USB debugging ON), then run:" -ForegroundColor Cyan
Write-Host ""
Write-Host "    flutter run --release" -ForegroundColor White
Write-Host ""
Write-Host "Or for debug mode:" -ForegroundColor Cyan
Write-Host "    flutter run" -ForegroundColor White
Write-Host ""
