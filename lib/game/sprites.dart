// lib/game/sprites.dart
// Sprite-sheet animation helpers for the character sheets.

import 'dart:math' show pi, cos, sin, max;
import 'dart:typed_data' show Float64List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../pixel/pixel_art.dart';

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

  /// Size of one buffer pixel in world units (0 = no snapping).
  static double snap = 0;

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
    // Stand on whole pixels of the low-res buffer, so sprites don't shimmer.
    if (snap > 0) {
      x = (x / snap).roundToDouble() * snap;
      y = (y / snap).roundToDouble() * snap;
    }
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

//// A text draw that waits for the crisp pass (see [TextCache.defer]).
class TextOp {
  final Float64List transform;
  final void Function(Canvas c) paint;
  TextOp(this.transform, this.paint);
}

/// Canvas text in the pixel font, laid out once and cached. Emoji in the
/// text are drawn as pixel sprites.
///
/// The world is drawn into a low-resolution buffer so everything shares one
/// pixel grid; text would turn to mush there, so while [defer] is set text
/// draws are recorded (with the canvas transform at that moment) and painted
/// later at full resolution by [replay].
class TextCache {
  final _cache = <String, TextPainter>{};
  List<TextOp>? defer;

  TextPainter get(String text, double size, Color color,
      {FontWeight weight = FontWeight.w400, double maxWidth = double.infinity}) {
    final key = '$text|$size|${color.toARGB32()}|$maxWidth';
    if (_cache.length > 600) _cache.clear();
    return _cache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          // Icons take about two letters of room.
          text: [for (final p in textPieces(text)) p.text ?? '  '].join(),
          style: TextStyle(fontFamily: kPixelFont, fontSize: size, color: color, height: 1.0),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth),
    );
  }

  /// Paints a laid-out [tp] at [offset] (deferred like [draw]).
  void paint(Canvas c, TextPainter tp, Offset offset) {
    final sink = defer;
    if (sink == null) {
      tp.paint(c, offset);
    } else {
      sink.add(TextOp(c.getTransform(), (cc) => tp.paint(cc, offset)));
    }
  }

  /// Draws [text] centred on ([x], [y]). [alpha] is quantised to keep the
  /// cache small. A lone icon is drawn straight into the pixel buffer.
  void draw(Canvas c, String text, double x, double y, double size, Color color,
      {double alpha = 1, FontWeight weight = FontWeight.w400, bool left = false}) {
    final a = (alpha.clamp(0.0, 1.0) * 10).round() / 10;
    if (a <= 0) return;
    final pieces = textPieces(text);
    if (pieces.length == 1 && pieces.first.icon != null) {
      final h = size * 1.15;
      final name = pieces.first.icon!;
      final w = PixelArt.widthAt(name, h);
      PixelArt.drawIcon(c, name, Offset(left ? x + w / 2 : x, y), h, paint: _alphaPaint(a));
      return;
    }
    final sink = defer;
    if (sink == null) {
      _drawNow(c, pieces, x, y, size, color, a, left);
    } else {
      sink.add(TextOp(c.getTransform(), (cc) => _drawNow(cc, pieces, x, y, size, color, a, left)));
    }
  }

  /// Paints the recorded text ops; [scale] maps buffer pixels to the screen.
  void replay(Canvas c, List<TextOp> ops, double scale) {
    for (final op in ops) {
      c.save();
      c.scale(scale);
      c.transform(op.transform);
      op.paint(c);
      c.restore();
    }
  }

  static final _alphaPaints = <double, Paint>{};
  Paint _alphaPaint(double a) => _alphaPaints.putIfAbsent(
      a,
      () => Paint()
        ..filterQuality = FilterQuality.none
        ..color = Colors.white.withValues(alpha: a));

  void _drawNow(Canvas c, List<TextPiece> pieces, double x, double y, double size, Color color, double a, bool left) {
    final col = color.withValues(alpha: color.a * a);
    if (pieces.every((p) => p.text != null)) {
      final tp = get(pieces.map((p) => p.text).join(), size, col);
      tp.paint(c, Offset(left ? x : x - tp.width / 2, y - tp.height / 2));
      return;
    }
    // Text and icons in a row.
    final ih = size * 1.4;
    final widths = [
      for (final p in pieces) p.icon != null ? PixelArt.widthAt(p.icon!, ih) + size * 0.3 : get(p.text!, size, col).width
    ];
    var cx = left ? x : x - widths.fold(0.0, (s, w) => s + w) / 2;
    for (var i = 0; i < pieces.length; i++) {
      final p = pieces[i];
      if (p.icon != null) {
        PixelArt.drawIcon(c, p.icon!, Offset(cx + widths[i] / 2, y), ih, paint: _alphaPaint(a));
      } else {
        final tp = get(p.text!, size, col);
        tp.paint(c, Offset(cx, y - tp.height / 2));
      }
      cx += widths[i];
    }
  }
}
