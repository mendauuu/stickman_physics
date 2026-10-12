// lib/pixel/pixel_ui.dart
// Pixel-art widgets for every screen: text in the pixel font (emoji become
// sprites), framed panels, glossy plate buttons from the UI sheet and the
// square touch buttons. Nothing here is smooth: no rounded corners, no blur,
// no gradients — just hard pixels.

import 'package:flutter/material.dart';

import 'pixel_art.dart';

/// Size of one art pixel in the menus (logical px).
const double kUiPx = 3;

/// Ink used for outlines and hard text shadows.
const Color kInk = Color(0xFF0E0A14);

/// Pixel-font text style. The shadow is a hard 1-font-pixel drop, never a blur.
TextStyle pixelStyle(double size, Color color, {double spacing = 0, bool shadow = true, double height = 1.35}) =>
    TextStyle(
      fontFamily: kPixelFont,
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      height: height,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      shadows: shadow ? [Shadow(color: kInk, offset: Offset(size / 8, size / 8))] : null,
    );

/// The tall, narrow pixel font for longer passages (story, descriptions).
TextStyle bodyStyle(double size, Color color, {bool shadow = true, double height = 1.1}) => TextStyle(
      fontFamily: kPixelBodyFont,
      fontFamilyFallback: const [kPixelFont],
      fontSize: size,
      color: color,
      height: height,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      shadows: shadow ? [Shadow(color: kInk, offset: Offset(size / 12, size / 12))] : null,
    );

/// Text in the pixel font; any emoji in [data] is drawn as a pixel sprite.
class PText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PText(this.data, {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) {
    if (!hasIcons(data)) {
      return Text(pixelSafe(data), style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
    }
    final base = DefaultTextStyle.of(context).style.merge(style);
    final h = (base.fontSize ?? 12) * 1.4;
    return Text.rich(
      TextSpan(children: [
        for (final p in textPieces(data))
          if (p.icon != null)
            WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(padding: EdgeInsets.symmetric(horizontal: h * 0.12), child: PixelIcon(p.icon!, size: h)))
          else
            TextSpan(text: p.text),
      ]),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// A sprite from the pixel sheets, [size] tall.
class PixelIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? tint;
  final bool flip;
  const PixelIcon(this.name, {super.key, this.size = 24, this.tint, this.flip = false});

  @override
  Widget build(BuildContext context) {
    final w = PixelArt.widthAt(name, size);
    return SizedBox(
      width: w == 0 ? size : w,
      height: size,
      child: CustomPaint(painter: _SpritePainter(name, tint, flip)),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final String name;
  final Color? tint;
  final bool flip;
  _SpritePainter(this.name, this.tint, this.flip);

  @override
  void paint(Canvas c, Size size) {
    final p = Paint()..filterQuality = FilterQuality.none;
    if (tint != null) p.colorFilter = ColorFilter.mode(tint!, BlendMode.srcIn);
    PixelArt.drawSprite(c, name, Offset.zero & size, paint: p, flip: flip);
  }

  @override
  bool shouldRepaint(_SpritePainter old) => old.name != name || old.tint != tint || old.flip != flip;
}

/// A framed pixel panel: ink outline with notched corners, a lighter rim, a
/// bright top edge and little corner studs in [accent].
class PixelPanel extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final double px;
  const PixelPanel({
    super.key,
    required this.child,
    this.color = const Color(0xFF1B2230),
    this.accent,
    this.padding = const EdgeInsets.all(10),
    this.px = kUiPx,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PanelPainter(color, accent, px),
      child: Padding(padding: EdgeInsets.all(px * 3).add(padding), child: child),
    );
  }
}

class _PanelPainter extends CustomPainter {
  final Color color;
  final Color? accent;
  final double px;
  _PanelPainter(this.color, this.accent, this.px);

  /// Rectangle with its corner pixels knocked off.
  void _notched(Canvas c, Rect r, double cut, Paint p) {
    c.drawRect(Rect.fromLTRB(r.left + cut, r.top, r.right - cut, r.bottom), p);
    c.drawRect(Rect.fromLTRB(r.left, r.top + cut, r.right, r.bottom - cut), p);
  }

  @override
  void paint(Canvas c, Size size) {
    final s = Offset.zero & size;
    final rim = accent ?? Color.lerp(color, Colors.white, 0.28)!;
    _notched(c, s, px, Paint()..color = kInk);
    _notched(c, s.deflate(px), px, Paint()..color = rim);
    final inner = s.deflate(px * 2);
    c.drawRect(inner, Paint()..color = color);
    // bevel: light top row, dark bottom row
    c.drawRect(Rect.fromLTWH(inner.left, inner.top, inner.width, px),
        Paint()..color = Color.lerp(color, Colors.white, 0.18)!);
    c.drawRect(Rect.fromLTWH(inner.left, inner.bottom - px, inner.width, px),
        Paint()..color = Color.lerp(color, Colors.black, 0.35)!);
    // corner studs
    final stud = Paint()..color = Color.lerp(rim, Colors.white, 0.35)!;
    for (final o in [
      Offset(inner.left + px, inner.top + px),
      Offset(inner.right - 2 * px, inner.top + px),
      Offset(inner.left + px, inner.bottom - 2 * px),
      Offset(inner.right - 2 * px, inner.bottom - 2 * px),
    ]) {
      c.drawRect(Rect.fromLTWH(o.dx, o.dy, px, px), stud);
    }
  }

  @override
  bool shouldRepaint(_PanelPainter old) => old.color != color || old.accent != accent || old.px != px;
}

/// Draws a 32x10 plate sprite stretched to [size] without smearing it:
/// the ends are drawn once and the middle is repeated at the same scale.
class PlatePainter extends CustomPainter {
  final PixelSprite sprite;
  PlatePainter(this.sprite);

  @override
  void paint(Canvas c, Size size) {
    final img = PixelArt.images[sprite.sheet];
    if (img == null) return;
    final src = sprite.src;
    final k = size.height / src.height; // screen px per art px
    const cap = 3.0;
    final p = Paint()..filterQuality = FilterQuality.none;
    // ends
    c.drawImageRect(img, Rect.fromLTWH(src.left, src.top, cap, src.height), Rect.fromLTWH(0, 0, cap * k, size.height), p);
    c.drawImageRect(img, Rect.fromLTWH(src.right - cap, src.top, cap, src.height),
        Rect.fromLTWH(size.width - cap * k, 0, cap * k, size.height), p);
    // repeated middle
    final mid = src.width - cap * 2;
    var x = cap * k;
    final end = size.width - cap * k;
    while (x < end - 0.01) {
      final w = (end - x).clamp(0.0, mid * k);
      c.drawImageRect(img, Rect.fromLTWH(src.left + cap, src.top, w / k, src.height), Rect.fromLTWH(x, 0, w, size.height), p);
      x += w;
    }
  }

  @override
  bool shouldRepaint(PlatePainter old) => old.sprite.src != sprite.src;
}

/// A glossy pixel button from the UI sheet; darker while pressed.
class PixelButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool small;
  final bool wide;
  const PixelButton(
      {super.key, required this.label, required this.color, required this.onTap, this.small = false, this.wide = false});

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final plate = plateFor(widget.color);
    final h = widget.small ? 36.0 : 44.0;
    final text = PText(widget.label,
        maxLines: 1, style: pixelStyle(widget.small ? 12 : 15, Colors.white, spacing: 1, height: 1));
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: CustomPaint(
        painter: PlatePainter(uiPlate(plate, _down ? 2 : 0)),
        child: Container(
          height: h,
          width: widget.wide ? double.infinity : null,
          padding: EdgeInsets.fromLTRB(widget.small ? 22 : 30, _down ? 3 : 0, widget.small ? 22 : 30, 0),
          child: widget.wide
              ? Center(child: FittedBox(fit: BoxFit.scaleDown, child: text))
              : Row(mainAxisSize: MainAxisSize.min, children: [text]),
        ),
      ),
    );
  }
}

/// A plain text link drawn in the pixel font (instead of a Material ripple).
class PixelLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  const PixelLink(this.label, {super.key, this.onTap, this.color = const Color(0xFF8ECAE6), this.size = 11});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: PText(label, style: pixelStyle(size, color, spacing: 1)),
      ),
    );
  }
}

/// Square button frames from the UI sheet, by colour family.
enum SquareColor { red, salmon, orange, blue, green }

/// A square pixel button: a plain frame from the UI sheet with an icon on it.
class PixelSquare extends StatelessWidget {
  final double size; // width; the frame is 10x12 art pixels
  final Widget child;
  final SquareColor color;
  final bool pressed;
  final bool glow;
  final double? progress; // fills from the bottom (in steps)
  const PixelSquare({
    super.key,
    required this.size,
    required this.child,
    this.color = SquareColor.blue,
    this.pressed = false,
    this.glow = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final h = size * 1.2;
    return SizedBox(
      width: size,
      height: h,
      child: CustomPaint(
        painter: _SquarePainter(color, pressed, glow, progress),
        child: Padding(
          padding: EdgeInsets.only(top: pressed ? size * 0.14 : size * 0.04, bottom: size * 0.16),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _SquarePainter extends CustomPainter {
  final SquareColor color;
  final bool pressed, glow;
  final double? progress;
  _SquarePainter(this.color, this.pressed, this.glow, this.progress);

  @override
  void paint(Canvas c, Size size) {
    final px = size.width / 10;
    if (glow) {
      // a 1-pixel gold ring around the frame
      c.drawRect(Rect.fromLTWH(-px, px, size.width + 2 * px, size.height - 2 * px),
          Paint()..color = const Color(0xFFFFD54F));
      c.drawRect(Rect.fromLTWH(px, -px, size.width - 2 * px, size.height + 2 * px),
          Paint()..color = const Color(0xFFFFD54F));
    }
    final s = uiSquare(color.index, pressed ? 8 : 6);
    final img = PixelArt.images[s.sheet];
    if (img != null) {
      c.drawImageRect(img, s.src, Offset.zero & size, Paint()..filterQuality = FilterQuality.none);
    }
    if (progress != null && progress! < 1) {
      // charge meter: dark cover that shrinks from the top, in whole pixels
      final steps = 9;
      final filled = (progress!.clamp(0.0, 1.0) * steps).floor();
      final top = px, bottom = size.height - 2 * px;
      final covered = (bottom - top) * (steps - filled) / steps;
      c.drawRect(Rect.fromLTWH(px, top, size.width - 2 * px, (covered / px).roundToDouble() * px),
          Paint()..color = kInk.withValues(alpha: 0.55));
    }
  }

  @override
  bool shouldRepaint(_SquarePainter old) =>
      old.color != color || old.pressed != pressed || old.glow != glow || old.progress != progress;
}
