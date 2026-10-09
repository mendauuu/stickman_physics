// lib/game/sprites.dart
// Sprite-sheet animation helpers for the character sheets.

import 'dart:math' show pi, cos, sin, max;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Frame layout of a sprite sheet: frame size, the point on the character's
/// feet, and how tall the visible character is (all in sprite pixels).
class SpriteGeom {
  final double frameW, frameH, anchorX, anchorY, bodyPx;
  const SpriteGeom(this.frameW, this.frameH, this.anchorX, this.anchorY, this.bodyPx);
}

/// Knight / Enchantress / Swordsman sheets (128x128 frames).
const kCraftpixGeom = SpriteGeom(128, 128, 50, 125, 67);

/// FreeKnight sheets (120x80 frames).
const kFreeKnightGeom = SpriteGeom(120, 80, 55, 80, 37);

class SpriteAnim {
  final ui.Image image;
  final SpriteGeom geom;
  final int frames;
  final double fps;
  final bool loop;

  SpriteAnim(this.image, {required this.fps, this.loop = true, this.geom = kCraftpixGeom})
      : frames = max(1, image.width ~/ geom.frameW);

  double get duration => frames / fps;

  int frameAt(double t) {
    final f = (t * fps).floor();
    return loop ? f % frames : f.clamp(0, frames - 1);
  }

  bool isDone(double t) => !loop && t >= duration;

  /// Draws the frame for time [t] with the feet at ([x], [y]), scaled so the
  /// character is [height] world units tall.
  void draw(Canvas c, double t, double x, double y, double height,
      {bool flip = false, Paint? paint}) {
    final f = frameAt(t);
    final scale = height / geom.bodyPx;
    c.save();
    c.translate(x, y);
    c.scale(flip ? -scale : scale, scale);
    c.drawImageRect(
      image,
      Rect.fromLTWH(f * geom.frameW, 0, geom.frameW, geom.frameH),
      Rect.fromLTWH(-geom.anchorX, -geom.anchorY, geom.frameW, geom.frameH),
      paint ?? pixelPaint,
    );
    c.restore();
  }
}

final Paint pixelPaint = Paint()..filterQuality = FilterQuality.none;

/// Paint that rotates the sprite's hue, used to give every teacher a
/// different outfit colour from the same Enchantress sheet.
Paint huePaint(double degrees) {
  if (degrees == 0) return pixelPaint;
  final r = degrees * pi / 180;
  final c = cos(r), s = sin(r);
  return Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = ColorFilter.matrix(<double>[
      0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0, //
      0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0, //
      0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
}

/// White flash used when a character takes damage.
final Paint flashPaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = const ColorFilter.matrix(<double>[
    1, 0, 0, 0, 170, //
    0, 1, 0, 0, 170, //
    0, 0, 1, 0, 170, //
    0, 0, 0, 1, 0,
  ]);

/// Loads every animation of a character folder (e.g. "Knight").
Map<String, SpriteAnim> buildAnims(
    Map<String, ui.Image> images, Map<String, double> fps,
    {Set<String> once = const {}, SpriteGeom geom = kCraftpixGeom}) {
  return {
    for (final e in images.entries)
      e.key: SpriteAnim(e.value,
          fps: fps[e.key] ?? 10, loop: !once.contains(e.key), geom: geom),
  };
}

/// Small cache so canvas text is laid out once, not every frame.
class TextCache {
  final _cache = <String, TextPainter>{};

  TextPainter get(String text, double size, Color color,
      {FontWeight weight = FontWeight.w900, double maxWidth = double.infinity}) {
    final key = '$text|$size|${color.toARGB32()}|${weight.index}|$maxWidth';
    if (_cache.length > 600) _cache.clear();
    return _cache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: weight,
            height: 1.0,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth),
    );
  }

  /// Draws [text] centred on ([x], [y]). [alpha] is quantised to keep the
  /// cache small.
  void draw(Canvas c, String text, double x, double y, double size,
      Color color,
      {double alpha = 1, FontWeight weight = FontWeight.w900, bool left = false}) {
    final a = (alpha.clamp(0.0, 1.0) * 10).round() / 10;
    if (a <= 0) return;
    final tp = get(text, size, color.withValues(alpha: color.a * a),
        weight: weight);
    tp.paint(c, Offset(left ? x : x - tp.width / 2, y - tp.height / 2));
  }
}
