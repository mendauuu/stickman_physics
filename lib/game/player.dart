// lib/game/player.dart
// Stickman dynamic body. Uses ONLY flame_forge2d's Vector2.

import 'dart:math' show pi;
import 'dart:ui';
import 'package:flame_forge2d/flame_forge2d.dart';
import '../constants/game_constants.dart';

class StickmanBody extends BodyComponent {
  final Vector2 startPosition;
  bool   _flashActive = false;
  double _flashTimer  = 0;

  StickmanBody({required this.startPosition});

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef()
        ..type             = BodyType.dynamic
        ..position         = startPosition
        ..linearDamping    = kStickmanLinearDamping
        ..angularDamping   = kStickmanAngularDamping
        ..fixedRotation    = false,
    );
    body.createFixture(
      FixtureDef(CircleShape()..radius = kStickmanRadius)
        ..restitution = kStickmanRestitution
        ..friction    = kStickmanFriction
        ..density     = kStickmanDensity,
    );
    return body;
  }

  /// Called by the game on a shake event.
  /// [dx], [dy] are the normalised impulse direction.
  void applyShakeImpulse(double dx, double dy) {
    body.applyLinearImpulse(
      Vector2(dx * kShakeImpulseStrength, dy * kShakeImpulseStrength),
    );
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

    final bodyFill  = _flashActive ? const Color(0xFFFFFFFF) : const Color(0xFF00E5FF);
    const outline   = Color(0xFF005F73);
    const skin      = Color(0xFFFFD6A5);
    const dark      = Color(0xFF222222);

    final fillP    = Paint()..color = bodyFill..style = PaintingStyle.fill;
    final outlineP = Paint()..color = outline..style = PaintingStyle.stroke..strokeWidth = 2.2;
    final skinP    = Paint()..color = skin..style = PaintingStyle.fill;
    final lineP    = Paint()..color = outline..style = PaintingStyle.stroke
                             ..strokeCap = StrokeCap.round..strokeWidth = 2.8;
    final dotP     = Paint()..color = dark..style = PaintingStyle.fill;

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
