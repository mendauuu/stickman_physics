// lib/game/sensors_controller.dart
// Pure Dart — no Vector2 of any kind. Returns plain doubles only.

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../constants/game_constants.dart';

class SensorData {
  final double gx;
  final double gy;
  final double magnitude;
  const SensorData(this.gx, this.gy, this.magnitude);
}

class SensorsController {
  SensorData data = const SensorData(0, kGravityStrength, 0);
  void Function(double dx, double dy)? onShake;

  StreamSubscription<AccelerometerEvent>? _sub;
  double _fx = 0, _fy = kGravityStrength;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  void start() {
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onEvent);
  }

  void dispose() { _sub?.cancel(); _sub = null; }

  void _onEvent(AccelerometerEvent e) {
    final rawX = -e.x, rawY = -e.y;
    final len = sqrt(rawX * rawX + rawY * rawY);
    double nx = 0, ny = kGravityStrength;
    if (len > 1.0) { nx = rawX / len * kGravityStrength; ny = rawY / len * kGravityStrength; }
    _fx = kSensorAlpha * nx + (1 - kSensorAlpha) * _fx;
    _fy = kSensorAlpha * ny + (1 - kSensorAlpha) * _fy;

    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final now = DateTime.now();
    if (mag > kShakeThreshold && now.difference(_lastShake).inMilliseconds > kShakeCooldownMs) {
      _lastShake = now;
      final il = sqrt(_fx * _fx + _fy * _fy);
      onShake?.call(il > 0.01 ? -_fx / il : 0, il > 0.01 ? -_fy / il : -1);
    }
    data = SensorData(_fx, _fy, mag);
  }
}
