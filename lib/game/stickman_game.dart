// lib/game/stickman_game.dart
// Pure Flame game — NO flame_forge2d, NO Vector2 conflicts.
// Physics live in PhysicsWorld (forge2d only).
// Rendering is raw canvas. Particles are raw dart:ui.

import 'dart:math' show sqrt, atan2, cos, sin;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/painting.dart'
    show TextPainter, TextSpan, TextStyle, TextDirection;
import 'package:flutter/material.dart' show Color;
import 'package:vibration/vibration.dart';

import '../constants/game_constants.dart';
import 'particles.dart';
import 'physics_world.dart';
import 'sensors_controller.dart';

class StickmanGame extends Game {
  final _sensors = SensorsController();
  final _physics = PhysicsWorld();
  final _particles = Particles();
  final _tp = TextPainter(textDirection: TextDirection.ltr);

  bool _ready = false;
  bool _flash = false;
  double _flashTimer = 0;
  double _shakeAlpha = 0;

  @override
  Future<void> onLoad() async {
    _physics.init(size.x, size.y);
    _sensors.onShake = _onShake;
    _sensors.start();
    _ready = true;
  }

  @override
  void onRemove() {
    _sensors.dispose();
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (!_ready) return;
    _physics.setGravity(_sensors.data.gx, _sensors.data.gy);
    _physics.step(dt);
    _particles.update(dt);
    if (_shakeAlpha > 0) _shakeAlpha = (_shakeAlpha - dt * 3.5).clamp(0.0, 1.0);
    if (_flash) {
      _flashTimer -= dt;
      if (_flashTimer <= 0) _flash = false;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_ready) return;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF0A1628));

    _drawGrid(canvas);
    _particles.render(canvas);
    _physics.renderStickman(canvas, _flash);

    // Screen flash on shake
    if (_shakeAlpha > 0) {
      canvas.drawRect(
          Rect.fromLTWH(0, 0, size.x, size.y),
          Paint()
            ..color = const Color(0xFF00E5FF).withOpacity(_shakeAlpha * 0.22));
    }

    _drawHUD(canvas);
  }

  void _onShake(double dx, double dy) {
    _physics.applyImpulse(dx, dy);
    _particles.burst(_physics.sx, _physics.sy);
    _flash = true;
    _flashTimer = 0.22;
    _shakeAlpha = 1.0;
    _vibrate();
  }

  void _vibrate() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 55, amplitude: 200);
      }
    } catch (_) {}
  }

  void _drawGrid(Canvas canvas) {
    final p = Paint()
      ..color = const Color(0xFF162844)
      ..strokeWidth = 0.6;
    for (double x = 0; x < size.x; x += 55)
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), p);
    for (double y = 0; y < size.y; y += 55)
      canvas.drawLine(Offset(0, y), Offset(size.x, y), p);
  }

  void _drawHUD(Canvas canvas) {
    final gx = _sensors.data.gx,
        gy = _sensors.data.gy,
        mag = _sensors.data.magnitude;

    // Gravity arrow
    final len = sqrt(gx * gx + gy * gy);
    if (len > 0.5) {
      const cx = 30.0, cy = 30.0, al = 18.0;
      final nx = gx / len, ny = gy / len;
      final tx = cx + nx * al, ty = cy + ny * al;
      final ap = Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(const Offset(cx, cy), al + 5,
          Paint()..color = const Color(0x22FFFFFF));
      canvas.drawLine(Offset(cx, cy), Offset(tx, ty), ap);
      final ang = atan2(ny, nx);
      canvas.drawLine(Offset(tx, ty),
          Offset(tx - 7 * cos(ang - 0.45), ty - 7 * sin(ang - 0.45)), ap);
      canvas.drawLine(Offset(tx, ty),
          Offset(tx - 7 * cos(ang + 0.45), ty - 7 * sin(ang + 0.45)), ap);
    }

    // Text
    const style = TextStyle(
        color: Color(0xFF8ECAE6),
        fontSize: kHudFontSize,
        fontFamily: 'monospace');
    double y = 10;
    for (final l in [
      'G  x:${gx.toStringAsFixed(1)}  y:${gy.toStringAsFixed(1)}',
      'Shake: ${mag.toStringAsFixed(1)} / $kShakeThreshold m/s\u00B2',
    ]) {
      _tp
        ..text = TextSpan(text: l, style: style)
        ..layout();
      _tp.paint(canvas, Offset(60, y));
      y += kHudFontSize + 5;
    }

    // Shake bar
    const bx = 60.0;
    final by = y + 2, bw = size.x - 72;
    final filled = (mag / (kShakeThreshold * 1.4)).clamp(0.0, 1.0) * bw;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bw, 5), const Radius.circular(3)),
        Paint()..color = const Color(0xFF1A3A5C));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, filled, 5), const Radius.circular(3)),
        Paint()
          ..color = mag > kShakeThreshold
              ? const Color(0xFFFF4500)
              : const Color(0xFF00E5FF));
  }
}
