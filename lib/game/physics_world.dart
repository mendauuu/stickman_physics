// lib/game/physics_world.dart
// Owns the Forge2D world + all bodies. Uses forge2d directly (not flame_forge2d).
// Vector2 here comes ONLY from forge2d (which re-exports vector_math).
// No Flame, no sensors, no UI imports in this file.

import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Rect, Color,
    RRect, Radius, StrokeCap;
import 'dart:math' show pi, sqrt, cos, sin, atan2;

import 'package:forge2d/forge2d.dart';

import '../constants/game_constants.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Body _staticBox(World w, double cx, double cy, double hw, double hh) {
  final bd = BodyDef()..position = Vector2(cx, cy);
  final body = w.createBody(bd);
  final shape = PolygonShape()..setAsBoxXY(hw, hh);
  body.createFixture(FixtureDef(shape)
    ..restitution = kWallRestitution
    ..friction    = kWallFriction);
  return body;
}

// ── Physics world wrapper ─────────────────────────────────────────────────────

class PhysicsWorld {
  late final World _world;
  late final Body _stickman;

  // Stickman pixel position (updated each step)
  double sx = 0, sy = 0;

  void init(double screenW, double screenH) {
    final ww = screenW / kPixelsPerMeter;
    final wh = screenH / kPixelsPerMeter;

    _world = World(Vector2(0, kGravityStrength));

    // Walls
    final t = kWallThickness;
    _staticBox(_world, ww / 2, wh + t, ww / 2 + t, t); // floor
    _staticBox(_world, ww / 2, -t,    ww / 2 + t, t); // ceiling
    _staticBox(_world, -t,    wh / 2, t, wh / 2 + t); // left
    _staticBox(_world, ww + t, wh / 2, t, wh / 2 + t); // right

    // Stickman body
    final bd = BodyDef()
      ..type            = BodyType.dynamic
      ..position        = Vector2(ww / 2, wh / 2)
      ..linearDamping   = kStickmanLinearDamping
      ..angularDamping  = kStickmanAngularDamping
      ..fixedRotation   = false;
    _stickman = _world.createBody(bd);
    _stickman.createFixture(
      FixtureDef(CircleShape()..radius = kStickmanRadius)
        ..restitution = kStickmanRestitution
        ..friction    = kStickmanFriction
        ..density     = kStickmanDensity,
    );

    sx = screenW / 2;
    sy = screenH / 2;
  }

  void setGravity(double gx, double gy) {
    _world.gravity.x = gx;
    _world.gravity.y = gy;
  }

  void applyImpulse(double dx, double dy) {
    _stickman.applyLinearImpulse(
      Vector2(dx * kShakeImpulseStrength, dy * kShakeImpulseStrength),
    );
  }

  void step(double dt) {
    _world.stepDt(dt);
    sx = _stickman.position.x * kPixelsPerMeter;
    sy = _stickman.position.y * kPixelsPerMeter;
  }

  double get angle => _stickman.angle;

  void renderStickman(Canvas canvas, bool flash) {
    canvas.save();
    canvas.translate(sx, sy);
    canvas.rotate(angle);
    _drawStickman(canvas, flash);
    canvas.restore();
  }

  static void _drawStickman(Canvas canvas, bool flash) {
    final r = kStickmanRadius * kPixelsPerMeter;
    final bodyFill = flash ? const Color(0xFFFFFFFF) : const Color(0xFF00E5FF);
    const outline  = Color(0xFF005F73);
    const skin     = Color(0xFFFFD6A5);
    const dark     = Color(0xFF222222);

    final fillP    = Paint()..color = bodyFill..style = PaintingStyle.fill;
    final outlineP = Paint()..color = outline..style  = PaintingStyle.stroke..strokeWidth = 2.2;
    final skinP    = Paint()..color = skin..style     = PaintingStyle.fill;
    final lineP    = Paint()..color = outline..style  = PaintingStyle.stroke
                             ..strokeCap = StrokeCap.round..strokeWidth = 2.8;
    final dotP     = Paint()..color = dark..style     = PaintingStyle.fill;

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

    // Arms & Legs
    canvas.drawLine(Offset(-r * 0.8, -r * 0.2), Offset(-r * 1.5, r * 0.5), lineP);
    canvas.drawLine(Offset( r * 0.8, -r * 0.2), Offset( r * 1.5, r * 0.5), lineP);
    canvas.drawLine(Offset(-r * 0.3,  r * 0.82), Offset(-r * 0.72, r * 1.6), lineP);
    canvas.drawLine(Offset( r * 0.3,  r * 0.82), Offset( r * 0.72, r * 1.6), lineP);
  }
}
