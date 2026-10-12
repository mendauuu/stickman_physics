// lib/game/decor.dart
// Pixel-art set dressing for every room, from the Xmas Decorations and Icons
// Mix packs: string lights in the hallway, armchairs and candles in Mira's
// corners, nutcracker guards in front of the Exam Hall, snowy pines on the
// walk into the morning. Candles glow, even in the dark rooms.

/// One decoration. [x] is a fraction of the room width (its centre), [y] is
/// where it stands (world units, 80 = the floor, 52 = a low shelf top) and
/// [h] its height in world units.
class Decor {
  final String sprite;
  final double x, y, h;
  final bool glow; // a warm, flickering halo (candles)
  final bool flip;
  final bool repeat; // tiled across the whole room at height [y]
  const Decor(this.sprite, this.x, this.y, this.h, {this.glow = false, this.flip = false, this.repeat = false});
}

const double _floor = 80, _shelf = 52, _board = 17.4, _table = 71;

/// Keyed by room label; 'escape' is the walk into the morning.
const Map<String, List<Decor>> kDecor = {
  // ── Floor 1 · The Hallway of Homework ──
  '1-1': [
    Decor('teddy', 0.25, _shelf, 6),
    Decor('gift_tall', 0.69, _floor, 6.5),
    Decor('gift', 0.735, _floor, 4.5),
    Decor('stocking', 0.71, _shelf, 5),
  ],
  '1-2': [
    Decor('lights', 0, 21, 3.5, repeat: true),
    Decor('bell', 0.5, _board, 6),
    Decor('stocking', 0.25, _shelf, 5),
    Decor('gift', 0.71, _shelf, 4.5),
  ],
  // ── Floor 2 · The Math Tower ──
  '2-1': [
    Decor('plant', 0.13, 60, 6),
    Decor('computer', 0.37, 46, 6),
    Decor('scissors', 0.85, 50, 4.5),
  ],
  '2-2': [
    Decor('computer', 0.16, 58, 6.5),
    Decor('wrench', 0.43, 42, 4),
    Decor('apple_big', 0.69, 28, 4.5),
  ],
  '2-3': [
    Decor('armchair', 0.30, _floor, 9),
    Decor('armchair', 0.70, _floor, 9, flip: true),
    Decor('candle', 0.46, _table, 5, glow: true),
    Decor('cocoa', 0.54, _table, 4),
    Decor('teddy2', 0.25, _shelf, 5.5),
    Decor('poinsettia', 0.71, _shelf, 6),
  ],
  // ── Floor 3 · The Silent Library ──
  '3-1': [
    Decor('candle_gold', 0.18, _shelf, 5, glow: true),
    Decor('candle_gold', 0.80, _shelf, 5, glow: true),
    Decor('book', 0.50, 34, 4),
  ],
  '3-2': [
    Decor('candle_arch', 0.5, _board, 7, glow: true),
    Decor('candle', 0.18, _shelf, 5, glow: true),
    Decor('candle', 0.80, _shelf, 5, glow: true),
  ],
  // ── Floor 4 · The Science Lab ──
  '4-1': [
    Decor('watering_can', 0.25, _shelf, 5.5),
    Decor('thermos', 0.71, _shelf, 6),
    Decor('plant', 0.90, _floor, 7),
    Decor('saw', 0.10, _floor, 4),
  ],
  '4-2': [
    Decor('computer', 0.25, _shelf, 6),
    Decor('computer', 0.71, _shelf, 6, flip: true),
    Decor('thermos', 0.88, _floor, 7),
  ],
  '4-3': [
    Decor('armchair', 0.30, _floor, 9),
    Decor('candle', 0.46, _table, 5, glow: true),
    Decor('kettle', 0.54, _table, 5),
    Decor('watering_can', 0.25, _shelf, 5),
    Decor('teddy', 0.71, _shelf, 5.5),
  ],
  // ── Floor 5 · The Office of Deadlines ──
  '5-1': [
    Decor('computer', 0.18, _shelf, 6),
    Decor('computer', 0.80, _shelf, 6, flip: true),
    Decor('thermometer', 0.50, 34, 8),
  ],
  '5-2': [
    Decor('computer', 0.18, _shelf, 6),
    Decor('candle', 0.80, _shelf, 5, glow: true),
    Decor('thermometer', 0.50, 34, 8),
  ],
  '5-3': [
    Decor('wreath', 0.5, _board, 6),
    Decor('nutcracker', 0.36, _floor, 16),
    Decor('nutcracker', 0.64, _floor, 16, flip: true),
    Decor('candle', 0.25, _shelf, 5, glow: true),
    Decor('candle', 0.71, _shelf, 5, glow: true),
  ],
  // ── Floor 6 · The Exam Hall ──
  '6-1': [
    Decor('candle_arch_red', 0.5, _board, 8, glow: true),
    Decor('nutcracker', 0.36, _floor, 18),
    Decor('nutcracker', 0.64, _floor, 18, flip: true),
    Decor('candle', 0.20, 50, 5, glow: true),
    Decor('candle', 0.80, 50, 5, glow: true),
  ],
  // ── Waking up: a snowy morning ──
  'escape': [
    Decor('pine_snow', 0.12, _floor, 32),
    Decor('snow_pile', 0.33, _floor, 5),
    Decor('snowman', 0.52, _floor, 11),
    Decor('pine_white', 0.74, _floor, 26),
    Decor('pine_small', 0.90, _floor, 20),
  ],
};
