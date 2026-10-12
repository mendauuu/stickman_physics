// lib/game/scenery.dart
// Outdoor scenery built from the "Nature Landscapes Free Pixel Art" pack
// (craftpix.net). Each landscape is a stack of layers drawn back to front
// with parallax. Layers move in whole source pixels so the pixel art stays
// crisp. Also generates a pixel-art ground strip that matches each landscape,
// swaying foreground grass, birds and soft light shafts.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum Ground { grass, roof }

class SceneDef {
  final int pack; // nature_<pack>
  final List<int> layers; // file numbers, back to front
  final Set<int> drift; // layer indexes (into [layers]) that drift slowly, e.g. clouds
  final Ground ground;
  final Color grass, grassDark, soil, soilDark; // ground palette sampled from the art
  final bool birds;
  final bool rays;
  final bool night;

  const SceneDef(
    this.pack,
    this.layers, {
    this.drift = const {},
    this.ground = Ground.grass,
    this.grass = const Color(0xFF59B455),
    this.grassDark = const Color(0xFF429B63),
    this.soil = const Color(0xFF6D4C3A),
    this.soilDark = const Color(0xFF3E2A22),
    this.birds = true,
    this.rays = false,
    this.night = false,
  });

  String file(int layer) => 'Nature Landscapes Free Pixel Art/nature_$pack/$layer.png';
}

/// Every landscape the game uses, by name.
const Map<String, SceneDef> kScenes = {
  'gardens': SceneDef(1, [1, 2, 3, 5, 6, 7, 8, 10],
      drift: {1}, grass: Color(0xFF7BCB5C), grassDark: Color(0xFF429B63), rays: true),
  'meadow': SceneDef(2, [1, 2, 3, 4], drift: {1}, grass: Color(0xFF6CC35A), grassDark: Color(0xFF4FA760)),
  'mountains': SceneDef(3, [1, 2, 3, 4],
      drift: {1}, grass: Color(0xFF5E8A4A), grassDark: Color(0xFF2A4017), soil: Color(0xFF5A4632), rays: true),
  'forest': SceneDef(4, [1, 2, 3, 4],
      grass: Color(0xFF6E9A58), grassDark: Color(0xFF38593A), soil: Color(0xFF4F3B2C), rays: true),
  'clouds': SceneDef(5, [1, 2, 3, 4, 5],
      drift: {1}, ground: Ground.roof, grass: Color(0xFF6CB184), grassDark: Color(0xFF428F41)),
  'aurora': SceneDef(6, [1, 2, 3], ground: Ground.roof, birds: false, night: true),
  'cliffs': SceneDef(7, [1, 2], grass: Color(0xFF7D8A2A), grassDark: Color(0xFF64711D)),
  'coast': SceneDef(8, [1], grass: Color(0xFF8BA853), grassDark: Color(0xFF738F44)),
};

/// Where the student walks after waking up.
const String kEscapeScene = 'mountains';

/// How far (world units) the nearest layer moves as the player crosses the room.
const double kParallax = 9;

/// A loaded landscape, ready to draw.
class Landscape {
  final SceneDef def;
  final List<ui.Image> layers;
  final ui.Image groundTile;
  Landscape(this.def, this.layers, this.groundTile);

  static const srcW = 576.0, srcH = 324.0;

  static Future<Landscape> load(SceneDef def, Future<ui.Image> Function(String path) loadImage, int seed) async {
    final layers = [for (final l in def.layers) await loadImage(def.file(l))];
    final tile = await _groundTile(def, Random(seed));
    return Landscape(def, layers, tile);
  }

  /// World units per source pixel when the landscape fills a room [w] wide.
  static double pixelSize(double w) => max(100 / srcH, (w + 2 * kParallax) / srcW);

  /// Draws all layers. [cam] runs from -0.5 (player at the left) to 0.5.
  /// [lift] raises the picture (used for the view from a window up high).
  void draw(Canvas c, double w, double cam, double time, {double lift = 0, Paint? paint}) {
    final s = pixelSize(w);
    final iw = srcW * s, ih = srcH * s;
    // Line the art's own ground up with the game floor (y = 80) so wide screens
    // crop the hidden bottom instead of the sky, but never leave a gap on top.
    final x0 = (w - iw) / 2, y0 = min(0.0, 80 - ih * 0.8) - lift;
    final p = paint ?? (Paint()..filterQuality = FilterQuality.none);
    final n = layers.length;
    for (var i = 0; i < n; i++) {
      final depth = n == 1 ? 0.0 : i / (n - 1);
      var shift = -cam * depth * kParallax;
      if (def.drift.contains(i)) shift += sin(time * 0.05 + i) * 4;
      shift = (shift / s).roundToDouble() * s; // whole source pixels: no shimmer
      c.drawImageRect(layers[i], const Rect.fromLTWH(0, 0, srcW, srcH), Rect.fromLTWH(x0 + shift, y0, iw, ih), p);
    }
  }

  /// The walkable ground: a pixel tile repeated along the floor line.
  void drawGround(Canvas c, double w, double groundY, {Paint? paint}) {
    final s = pixelSize(w);
    final tw = groundTile.width * s, th = groundTile.height * s;
    final top = groundY - _bladeRows * s;
    final p = paint ?? (Paint()..filterQuality = FilterQuality.none);
    for (double x = 0; x < w; x += tw) {
      c.drawImageRect(groundTile, Rect.fromLTWH(0, 0, groundTile.width.toDouble(), groundTile.height.toDouble()),
          Rect.fromLTWH(x, top, tw + 0.05, th), p);
    }
  }

  static const _bladeRows = 4; // tile rows above the walking line (grass tips / roof rim)

  /// Builds a 160x80 pixel ground tile in the landscape's own palette.
  static Future<ui.Image> _groundTile(SceneDef d, Random r) async {
    const tw = 160, th = 80;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final p = Paint();
    void px(int x, int y, Color col, [int w = 1, int h = 1]) {
      p.color = col;
      c.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()), p);
    }

    const b = _bladeRows;
    if (d.ground == Ground.grass) {
      final light = Color.lerp(d.grass, Colors.white, 0.18)!;
      // soil, darker as it goes down, with stones and roots
      for (var y = b + 7; y < th; y++) {
        final k = ((y - b - 7) / (th - b - 7)).clamp(0.0, 1.0);
        px(0, y, Color.lerp(d.soil, d.soilDark, k)!, tw);
      }
      for (var y = b + 10; y < th; y += 2) {
        for (var x = 0; x < tw; x++) {
          if (r.nextDouble() < 0.06) px(x, y, Color.lerp(d.soil, Colors.black, 0.25)!);
          if (r.nextDouble() < 0.02) px(x, y, Color.lerp(d.soil, Colors.white, 0.2)!);
        }
      }
      // a darker layer of earth half way down
      for (var x = 0; x < tw; x++) {
        final y = b + 34 + (sin(x * 0.09) * 3 + sin(x * 0.23) * 1.5).round();
        px(x, y, Color.lerp(d.soil, Colors.black, 0.18)!, 1, 2 + r.nextInt(2));
      }
      // stones of different sizes
      for (var i = 0; i < 7; i++) {
        final sw = 3 + r.nextInt(5);
        final sx = r.nextInt(tw - sw - 2), sy = b + 12 + r.nextInt(th - b - 20);
        final stone = Color.lerp(const Color(0xFF8D8D8D), d.soil, 0.35 + r.nextDouble() * 0.3)!;
        px(sx + 1, sy, stone, sw - 2, 1);
        px(sx, sy + 1, stone, sw, 2);
        px(sx + 1, sy + 1, Color.lerp(stone, Colors.white, 0.25)!, max(1, sw ~/ 2 - 1), 1);
        px(sx + 1, sy + 3, Color.lerp(stone, Colors.black, 0.3)!, sw - 2, 1);
      }
      // roots hanging from the grass
      for (var i = 0; i < 6; i++) {
        var x = r.nextInt(tw);
        final len = 4 + r.nextInt(8);
        for (var y = 0; y < len; y++) {
          if (r.nextDouble() < 0.3) x += r.nextBool() ? 1 : -1;
          px(x.clamp(0, tw - 1), b + 8 + y, Color.lerp(d.soil, const Color(0xFFD7B98E), 0.25)!);
        }
      }
      // grass band with a ragged lower edge hanging over the soil
      px(0, b, d.grass, tw, 4);
      px(0, b + 4, d.grassDark, tw, 3);
      for (var x = 0; x < tw; x++) {
        final drip = r.nextInt(4);
        if (drip > 0) px(x, b + 7, d.grassDark, 1, drip);
        if (r.nextDouble() < 0.5) px(x, b, light);
      }
      // blades sticking up above the walking line
      for (var x = 0; x < tw; x++) {
        final h = r.nextDouble() < 0.45 ? 1 + r.nextInt(b) : 0;
        if (h > 0) px(x, b - h, r.nextBool() ? d.grass : light, 1, h);
      }
      // a few flowers
      const petals = [Color(0xFFFFF59D), Color(0xFFFFFFFF), Color(0xFFF48FB1), Color(0xFF90CAF9)];
      for (var i = 0; i < 7; i++) {
        final fx = 2 + r.nextInt(tw - 4);
        px(fx, b - 2, petals[r.nextInt(petals.length)]);
        px(fx, b - 1, d.grassDark);
      }
    } else {
      // Rooftop: a stone parapet rim, then tar and gravel
      const rim = Color(0xFF9E9E9E), rimLight = Color(0xFFCFCFCF), rimDark = Color(0xFF616161);
      px(0, b - 1, rimLight, tw, 1);
      px(0, b, rim, tw, 3);
      px(0, b + 3, rimDark, tw, 1);
      for (var x = 0; x < tw; x += 20) {
        px(x, b, rimDark, 1, 3);
      }
      for (var y = b + 4; y < th; y++) {
        final k = (y - b - 4) / (th - b - 4);
        px(0, y, Color.lerp(const Color(0xFF4A4A52), const Color(0xFF1E1E24), k)!, tw);
      }
      for (var y = b + 5; y < th; y++) {
        for (var x = 0; x < tw; x++) {
          final v = r.nextDouble();
          if (v < 0.05) px(x, y, const Color(0xFF6B6B75));
          if (v > 0.97) px(x, y, const Color(0xFF15151A));
        }
      }
      for (var y = b + 14; y < th; y += 14) {
        px(0, y, const Color(0x33000000), tw, 1);
      }
      // moss in the cracks
      for (var i = 0; i < 3; i++) {
        final mx = r.nextInt(tw - 4);
        px(mx, b - 1, d.grass, 3, 1);
        px(mx + 1, b - 2, d.grass, 1, 1);
      }
    }
    final pic = rec.endRecording();
    return pic.toImage(tw, th);
  }
}

/// A bird gliding across the sky; flaps now and then.
class Bird {
  double x, y, vx, phase;
  Bird(this.x, this.y, this.vx, this.phase);
}

/// Foreground grass, birds and light rays for outdoor rooms.
class SceneLife {
  final birds = <Bird>[];
  double _birdIn = 2;
  final _tufts = <(double x, int blades, int seed)>[];
  double _tuftW = -1;

  void update(double dt, double w, Random rng, {required bool birdsOn}) {
    for (final b in birds) {
      b.x += b.vx * dt;
      b.y += sin(b.phase + b.x * 0.05) * dt * 1.5;
      b.phase += dt;
    }
    birds.removeWhere((b) => b.x < -10 || b.x > w + 10);
    if (!birdsOn) return;
    _birdIn -= dt;
    if (_birdIn <= 0) {
      _birdIn = 5 + rng.nextDouble() * 8;
      final fromLeft = rng.nextBool();
      final n = 1 + rng.nextInt(4);
      final y = 14 + rng.nextDouble() * 22;
      final speed = (9 + rng.nextDouble() * 6) * (fromLeft ? 1 : -1);
      for (var i = 0; i < n; i++) {
        // a loose V
        birds.add(Bird(fromLeft ? -4 - i * 3.5 : w + 4 + i * 3.5, y + (i.isOdd ? 1.6 : -1.6) * ((i + 1) ~/ 2),
            speed, rng.nextDouble() * 6));
      }
    }
  }

  void drawBirds(Canvas c, double w, double time, Color color) {
    final s = Landscape.pixelSize(w);
    final p = Paint()..color = color;
    for (final b in birds) {
      final up = sin(time * 9 + b.phase * 3) > 0.2;
      final x = (b.x / s).roundToDouble() * s, y = (b.y / s).roundToDouble() * s;
      // 5-pixel wide bird: wings up (V) or down (^)
      c.drawRect(Rect.fromLTWH(x, y, s, s), p);
      for (final dx in [-1, 1]) {
        c.drawRect(Rect.fromLTWH(x + dx * s, y + (up ? -s : s * 0.0), s, s), p);
        c.drawRect(Rect.fromLTWH(x + dx * 2 * s, y + (up ? -2 * s : s), s, s), p);
      }
    }
  }

  /// Soft diagonal light shafts from the top left.
  void drawRays(Canvas c, double w, double time) {
    final p = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 4; i++) {
      final x = w * (0.08 + i * 0.22);
      final a = 0.035 + 0.025 * sin(time * 0.4 + i * 1.7);
      p.shader = ui.Gradient.linear(Offset(x, 0), Offset(x + 30, 80),
          [const Color(0xFFFFF4C2).withValues(alpha: a), const Color(0x00FFF4C2)]);
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 6 + i * 2, 0)
        ..lineTo(x + 40 + i * 4, 80)
        ..lineTo(x + 24, 80)
        ..close();
      c.drawPath(path, p);
    }
  }

  /// Dark grass clumps along the bottom edge, in front of everything.
  void drawForeground(Canvas c, double w, double time, Color color) {
    final s = Landscape.pixelSize(w);
    if (_tuftW != w) {
      _tuftW = w;
      _tufts.clear();
      final r = Random(7);
      for (double x = r.nextDouble() * 8; x < w; x += 9 + r.nextDouble() * 14) {
        _tufts.add((x, 5 + r.nextInt(6), r.nextInt(1000)));
      }
    }
    final p = Paint()..color = color;
    final hi = Paint()..color = Color.lerp(color, Colors.white, 0.12)!;
    for (final (x0, blades, seed) in _tufts) {
      final r = Random(seed);
      final sway = sin(time * 1.6 + x0 * 0.13);
      for (var i = 0; i < blades; i++) {
        final h = 4 + r.nextInt(9); // pixels
        final bx = ((x0 / s).roundToDouble() + i - blades ~/ 2) * s;
        final lean = (sway * (h / 6)).round(); // tips move, roots stay
        final base = 100.0;
        final split = (h * 0.55).round();
        c.drawRect(Rect.fromLTWH(bx, base - split * s, s, split * s), p);
        c.drawRect(Rect.fromLTWH(bx + lean * s, base - h * s, s, (h - split) * s), i.isEven ? p : hi);
      }
    }
  }
}
