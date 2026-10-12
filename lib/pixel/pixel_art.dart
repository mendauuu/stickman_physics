// lib/pixel/pixel_art.dart
// Every icon in the game is pixel art. This file knows where each one lives:
// the bought packs are used as they are (never modified) and sprites are cut
// out of them at draw time; the few icons no pack had are our own, drawn by
// tools/make_pixel_icons.py.
//
//  · Icons Mix Mega Pack 4 — BlackSkull-k (credit required)
//  · Xmas Decorations — 0-mem0ry (itch.io)
//  · item icons + UI buttons sheets ("icons .png", "bottoms and icons .png")
//
// Emoji in any game text are swapped for these sprites, so nothing is ever
// drawn with the phone's emoji font.

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;

const kItemsSheet = 'assets/icons .png';
const kUiSheet = 'assets/bottoms and icons .png';
const kXmasSheet = 'assets/Xmas/Xmas_Decorations.png';
const kExtraSheet = 'assets/pixel/extra_icons.png';
String _mega(int i) => 'assets/Icons Mix Mega Pack (4)/${i.toString().padLeft(3, '0')}.png';

/// Pixel fonts (SIL Open Font License).
const kPixelFont = 'PressStart2P'; // headings, buttons, HUD
const kPixelBodyFont = 'VT323'; // longer story text

/// A sprite: a rectangle inside one sheet.
class PixelSprite {
  final String sheet;
  final Rect src;
  const PixelSprite(this.sheet, this.src);
}

PixelSprite _it(double x, double y, double w, double h) => PixelSprite(kItemsSheet, Rect.fromLTWH(x, y, w, h));
PixelSprite _xm(double x, double y, double w, double h) => PixelSprite(kXmasSheet, Rect.fromLTWH(x, y, w, h));
PixelSprite _ui(double x, double y, double w, double h) => PixelSprite(kUiSheet, Rect.fromLTWH(x, y, w, h));
PixelSprite _mg(int i) => PixelSprite(_mega(i), const Rect.fromLTWH(0, 0, 32, 32));

/// Order of the icons in extra_icons.png (see tools/make_pixel_icons.py).
const kExtraIcons = [
  'bolt', 'clock', 'lock', 'ghost', 'hourglass', 'pencil', 'redpen', //
  'note', 'eye', 'moon', 'door', 'ladder', 'trophy', 'invader',
];

final Map<String, PixelSprite> kSprites = {
  // ── items ("icons .png") ──
  'book_open': _it(155, 182, 12, 11),
  'potion': _it(178, 182, 9, 12),
  'sword': _it(199, 182, 12, 12),
  'fire': _it(222, 183, 8, 12),
  'sprout': _it(90, 199, 11, 10),
  'mushroom': _it(109, 199, 10, 13),
  'chili': _it(122, 199, 12, 14),
  'key': _it(154, 207, 13, 8),
  'bag': _it(177, 207, 11, 10),
  'dagger': _it(199, 205, 12, 12),
  'coin': _it(221, 206, 11, 10),
  'pumpkin': _it(90, 216, 13, 13),
  'apple': _it(106, 218, 13, 13),
  'skull': _it(154, 227, 13, 15),
  'heart': _it(177, 230, 12, 10),
  'gem': _it(198, 230, 12, 10),
  'shield': _it(221, 228, 12, 13),
  'orange': _it(76, 234, 9, 10),
  'meat': _it(85, 251, 16, 14),
  'bread': _it(124, 251, 11, 11),
  'scroll': _it(154, 250, 13, 14),
  'book': _it(179, 252, 7, 10),
  'envelope': _it(199, 253, 11, 9),
  'rock': _it(219, 251, 15, 12),
  // round badges (same items in a frame)
  'badge_scroll': _it(148, 104, 21, 22),
  'badge_heart': _it(170, 81, 21, 22),
  'badge_skull': _it(148, 81, 21, 22),
  'badge_shield': _it(214, 81, 21, 22),
  'badge_fire': _it(214, 35, 21, 22),
  'badge_key': _it(148, 58, 21, 22),
  // ── Icons Mix Mega Pack 4 ──
  'computer': _mg(0),
  'scissors': _mg(1),
  'cupcake': _mg(2),
  'saw': _mg(5),
  'plant': _mg(6),
  'wrench': _mg(7),
  'spaghetti': _mg(8),
  'apple_big': _mg(10),
  'kettle': _mg(11),
  'thermos': _mg(12),
  'watering_can': _mg(13),
  'armchair': _mg(14),
  // ── Xmas decorations ──
  'candle': _xm(113, 160, 15, 16),
  'candle_gold': _xm(113, 256, 15, 16),
  'bell': _xm(193, 337, 14, 14),
  'mug': _xm(3, 292, 10, 10),
  'cocoa': _xm(115, 305, 11, 14),
  'stew': _xm(49, 289, 14, 13),
  'plate_carrot': _xm(65, 289, 14, 13),
  'cookies': _xm(81, 289, 14, 13),
  'ginger': _xm(225, 321, 14, 14),
  'gift': _xm(210, 369, 12, 14),
  'gift_tall': _xm(1, 172, 14, 19),
  'sparkle': _xm(389, 3, 7, 9),
  'teddy': _xm(113, 139, 14, 19),
  'teddy2': _xm(129, 139, 14, 17),
  'sun': _xm(0, 353, 31, 30),
  'tree_small': _xm(33, 97, 13, 30),
  'lights': _xm(64, 130, 48, 12),
  'lights_gold': _xm(64, 226, 48, 12),
  'garland': _xm(75, 98, 74, 13),
  'stocking': _xm(50, 101, 13, 18),
  'candle_arch': _xm(321, 296, 31, 23),
  'candle_arch_red': _xm(289, 298, 31, 21),
  'nutcracker': _xm(307, 249, 13, 38),
  'poinsettia': _xm(101, 327, 20, 20),
  'thermometer': _xm(357, 290, 7, 29),
  'letter': _xm(273, 353, 14, 14),
  'pine_snow': _xm(4, 17, 42, 79),
  'pine_white': _xm(147, 17, 42, 79),
  'pine_small': _xm(244, 28, 37, 68),
  'snowman': _xm(290, 32, 27, 31),
  'xmas_tree': _xm(214, 97, 35, 79),
  'pine': _xm(307, 125, 25, 50),
  'gnome': _xm(242, 300, 11, 19),
  'candy_cane': _xm(196, 321, 10, 14),
  'pudding': _xm(257, 353, 14, 14),
  'cracker': _xm(257, 337, 14, 14),
  'turkey': _xm(215, 299, 18, 18),
  'snow_pile': _xm(322, 65, 29, 24),
  'wreath': _xm(7, 102, 18, 19),
  // ── UI sheet glyphs ──
  'ui_up': _ui(193, 171, 5, 6),
  'ui_down': _ui(211, 171, 5, 6),
  'ui_plus': _ui(240, 171, 6, 6),
  'ui_check': _ui(263, 183, 7, 6),
  'ui_x': _ui(261, 234, 6, 5),
  'ui_left': _ui(199, 247, 6, 5),
  'ui_right': _ui(220, 247, 6, 5),
  'ui_question': _ui(119, 166, 4, 6),
  // ── our own (extra_icons.png) ──
  for (var i = 0; i < kExtraIcons.length; i++)
    kExtraIcons[i]: PixelSprite(kExtraSheet, Rect.fromLTWH(i * 16.0, 0, 16, 16)),
};

/// Square UI buttons (10x12): [row] 0 red, 1 salmon, 2 orange, 3 blue, 4 green;
/// [col] 0-2 with an icon (normal, light, pressed), 3-5 second icon, 6-11 plain.
PixelSprite uiSquare(int row, int col) =>
    _ui(118.0 + 11 * col, const [15.0, 28.0, 41.0, 54.0, 67.0][row], 10, 12);

/// Wide glossy buttons (32x10), one per [PlateColor]; [state] 0 normal,
/// 1 highlighted, 2 pressed.
PixelSprite uiPlate(PlateColor color, int state) => _ui(10.0 + 33 * state, 18.0 + 11 * color.index, 32, 10);

enum PlateColor { orange, red, salmon, blue, green, mauve, pink, tan, slate, dark }

const Map<PlateColor, Color> kPlateColors = {
  PlateColor.orange: Color(0xFFC4823C),
  PlateColor.red: Color(0xFFA83A3A),
  PlateColor.salmon: Color(0xFF9B4A41),
  PlateColor.blue: Color(0xFF425A67),
  PlateColor.green: Color(0xFF3F4E2E),
  PlateColor.mauve: Color(0xFF7D605E),
  PlateColor.pink: Color(0xFF916767),
  PlateColor.tan: Color(0xFFA98763),
  PlateColor.slate: Color(0xFF586267),
  PlateColor.dark: Color(0xFF454A3F),
};

/// The plate whose colour family is closest to [c] (by hue, then brightness).
PlateColor plateFor(Color c) {
  final h = HSVColor.fromColor(c);
  if (h.saturation < 0.18) return h.value > 0.55 ? PlateColor.slate : PlateColor.dark;
  final hue = h.hue;
  if (hue < 15 || hue >= 330) return PlateColor.red;
  if (hue < 50) return PlateColor.orange;
  if (hue < 70) return PlateColor.tan;
  if (hue < 160) return PlateColor.green;
  if (hue < 260) return PlateColor.blue;
  return PlateColor.mauve;
}

/// Emoji → sprite name. The variation selector (U+FE0F) is ignored.
const Map<String, String> kEmojiSprites = {
  '⚡': 'bolt', '⏰': 'clock', '🕒': 'clock', '⏱': 'clock', '🔒': 'lock', //
  '📄': 'scroll', '🗺': 'scroll', '💀': 'skull', '☠': 'skull', '🕯': 'candle',
  '🎒': 'bag', '👻': 'ghost', '👋': 'ghost', '📚': 'book', '📓': 'book', '🦸': 'book',
  '📕': 'book_open', '🤫': 'book_open', '👾': 'invader', '👺': 'invader', '🐛': 'invader',
  '🐝': 'invader', '🧪': 'potion', '☣': 'potion', '🪜': 'ladder', '⚔': 'sword', '⛩': 'sword',
  '🗡': 'dagger', '✓': 'ui_check', '❔': 'ui_question', '⏭': 'ui_right', '⬇': 'ui_down',
  '📉': 'ui_down', '📐': 'computer', '🤖': 'computer', '⏳': 'hourglass', '⌛': 'hourglass',
  '⚖': 'hourglass', '✏': 'pencil', '🖊': 'redpen', '🛡': 'shield', '🧍': 'shield',
  '🍄': 'mushroom', '👁': 'eye', '♪': 'note', '♫': 'note', '♬': 'note', '♩': 'note',
  '💤': 'moon', '😴': 'moon', '🌙': 'moon', '🏆': 'trophy', '❤': 'heart', '🌳': 'tree_small',
  '🍲': 'stew', '🥟': 'bread', '☕': 'cocoa', '✨': 'sparkle', '✦': 'sparkle', '★': 'sparkle',
  '🌿': 'sprout', '💰': 'coin', '✉': 'envelope', '🫖': 'kettle', '🌅': 'sun', '🏃': 'door',
  '🚪': 'door', '🍎': 'apple', '🏐': 'orange', '📯': 'bell', '🎁': 'gift',
};

/// One piece of game text: plain [text], or a sprite [icon].
class TextPiece {
  final String? text, icon;
  const TextPiece.text(this.text) : icon = null;
  const TextPiece.icon(this.icon) : text = null;
}

final _emojiRe = RegExp(
    '(${(kEmojiSprites.keys.toList()..sort((a, b) => b.length - a.length)).map(RegExp.escape).join('|')})️?');

/// Anything else that would fall back to the phone's emoji font.
final _strayRe = RegExp('[\u{1F000}-\u{1FFFF}☀-➿⬀-⯿⌀-⏿️‍]', unicode: true);

/// Characters the pixel fonts don't have, spelled with ones they do.
const _glyphFixes = {'⅓': '1/3', '⅔': '2/3', '⅛': '1/8', '⁺': '+', '−': '-', '▸': '▶'};

/// Makes [s] drawable with the pixel fonts (no icons).
String pixelSafe(String s) {
  for (final e in _glyphFixes.entries) {
    if (s.contains(e.key)) s = s.replaceAll(e.key, e.value);
  }
  return s.replaceAll(_strayRe, '');
}

final _pieceCache = <String, List<TextPiece>>{};

/// Splits game text into text runs and sprite icons.
List<TextPiece> textPieces(String s) {
  final hit = _pieceCache[s];
  if (hit != null) return hit;
  final out = <TextPiece>[];
  var at = 0;
  for (final m in _emojiRe.allMatches(s)) {
    if (m.start > at) out.add(TextPiece.text(pixelSafe(s.substring(at, m.start))));
    out.add(TextPiece.icon(kEmojiSprites[m.group(1)]));
    at = m.end;
  }
  if (at < s.length) out.add(TextPiece.text(pixelSafe(s.substring(at))));
  out.removeWhere((p) => p.text != null && p.text!.isEmpty);
  if (_pieceCache.length > 800) _pieceCache.clear();
  return _pieceCache[s] = out;
}

bool hasIcons(String s) => _emojiRe.hasMatch(s);

/// Loaded sheets.
class PixelArt {
  PixelArt._();
  static final images = <String, ui.Image>{};
  static Future<void>? _loading;

  static bool get ready => images.length >= _sheets.length;

  static final _sheets = {for (final s in kSprites.values) s.sheet};

  /// Loads every sheet once (safe to call many times).
  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    for (final path in _sheets) {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      images[path] = (await codec.getNextFrame()).image;
    }
  }

  static final _paint = Paint()..filterQuality = FilterQuality.none;

  /// Draws sprite [name] into [dst] (stretched to fill it).
  static void drawSprite(Canvas c, String name, Rect dst, {Paint? paint, bool flip = false}) {
    final s = kSprites[name];
    if (s == null) return;
    final img = images[s.sheet];
    if (img == null) return;
    if (flip) {
      c.save();
      c.translate(dst.center.dx, 0);
      c.scale(-1, 1);
      c.translate(-dst.center.dx, 0);
    }
    c.drawImageRect(img, s.src, dst, paint ?? _paint);
    if (flip) c.restore();
  }

  /// Draws sprite [name] [height] tall (keeping its shape), centred on [center].
  static void drawIcon(Canvas c, String name, Offset center, double height, {Paint? paint}) {
    final s = kSprites[name];
    if (s == null) return;
    final h = height, w = height * s.src.width / s.src.height;
    drawSprite(c, name, Rect.fromCenter(center: center, width: w, height: h), paint: paint);
  }

  /// Draws sprite [name] standing on ([x], [bottom]), [height] tall.
  static void drawStanding(Canvas c, String name, double x, double bottom, double height,
      {Paint? paint, bool flip = false}) {
    final s = kSprites[name];
    if (s == null) return;
    final w = height * s.src.width / s.src.height;
    drawSprite(c, name, Rect.fromLTWH(x - w / 2, bottom - height, w, height), paint: paint, flip: flip);
  }

  /// Width of sprite [name] drawn [height] tall.
  static double widthAt(String name, double height) {
    final s = kSprites[name];
    return s == null ? 0 : height * s.src.width / s.src.height;
  }
}
