// lib/game/particles.dart
// Uses ONLY dart:ui and dart:math. Zero package imports. Zero conflicts.

import 'dart:math';
import 'dart:ui';

import '../constants/game_constants.dart';

class _P {
  double x, y, vx, vy, life;
  final double maxLife;
  final Color color;
  _P(this.x, this.y, this.vx, this.vy, this.life, this.color) : maxLife = life;
}

class Particles {
  final _list = <_P>[];
  final _rng = Random();
  static const _colors = [
    Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFF4500),
    Color(0xFFFFFFFF), Color(0xFF00E5FF),
  ];

  void burst(double px, double py) {
    for (int i = 0; i < kParticleCount; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final s = (_rng.nextDouble() * 0.7 + 0.3) * kParticleMaxSpeed;
      _list.add(_P(px, py, cos(a) * s, sin(a) * s,
        kParticleLifespan * (0.5 + _rng.nextDouble() * 0.5),
        _colors[_rng.nextInt(_colors.length)]));
    }
  }

  void update(double dt) {
    for (final p in _list) { p.life -= dt; p.vy += 400 * dt; p.x += p.vx * dt; p.y += p.vy * dt; }
    _list.removeWhere((p) => p.life <= 0);
  }

  void render(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in _list) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      paint.color = p.color.withOpacity(t);
      canvas.drawCircle(Offset(p.x, p.y), kParticleRadius * t + 1, paint);
    }
  }
}
