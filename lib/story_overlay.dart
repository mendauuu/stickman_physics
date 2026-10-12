part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
// STORY — one line at a time: the prologue, Mira, the library book, the
// Reaper's face and the wake-up ending. Tap to continue, or skip it all.
// Text types itself out, letter by letter, like an old RPG dialogue box.
// ═══════════════════════════════════════════════════════════════════════════
class _StoryOverlay extends StatefulWidget {
  final SchoolGame game;
  const _StoryOverlay({required this.game});
  @override
  State<_StoryOverlay> createState() => _StoryOverlayState();
}

class _StoryOverlayState extends State<_StoryOverlay> with SingleTickerProviderStateMixin {
  List<StoryLine> _lines = const [];
  int _i = 0;
  late final AnimationController _type = AnimationController(vsync: this);

  @override
  void dispose() {
    _type.dispose();
    super.dispose();
  }

  void _startTyping() {
    final n = _lines.isEmpty ? 0 : _lines[_i].text.length;
    _type
      ..duration = Duration(milliseconds: 28 * n + 1)
      ..forward(from: 0);
  }

  void _next() {
    GameAudio.instance.play('click');
    if (_type.isAnimating) {
      _type.value = 1; // first tap shows the whole line
      return;
    }
    if (_i + 1 < _lines.length) {
      setState(() => _i++);
      _startTyping();
    } else {
      _skip();
    }
  }

  /// Ends this story. The game may start another one straight away, so
  /// rebuild to pick it up.
  void _skip() {
    widget.game.endStory();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // The game can chain two stories back to back; start each one from the top.
    if (!identical(_lines, widget.game.story)) {
      _lines = widget.game.story;
      _i = 0;
      _startTyping();
    }
    if (_lines.isEmpty) return const SizedBox();
    final line = _lines[_i];
    final narrator = line.who == Speaker.narrator;
    final picture = line.emoji.isNotEmpty
        ? textPieces(line.emoji).map((p) => p.icon).whereType<String>().firstOrNull
        : (line.who == Speaker.mira ? 'ghost' : line.who == Speaker.reaper ? 'skull' : null);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      child: Container(
        color: kInk.withValues(alpha: 0.86),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (picture != null) ...[
                          PixelIcon(picture, size: 64),
                          const SizedBox(height: 10),
                        ],
                        PixelPanel(
                          color: const Color(0xFF141A26),
                          accent: narrator ? const Color(0xFF55607A) : line.color,
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!narrator)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(line.name, style: pixelStyle(11, line.color, spacing: 2)),
                                ),
                              AnimatedBuilder(
                                animation: _type,
                                builder: (_, __) {
                                  final shown = (line.text.length * _type.value).round();
                                  return SizedBox(
                                    width: double.infinity,
                                    // The full text keeps the box from growing while it types.
                                    child: Stack(children: [
                                      Opacity(opacity: 0, child: PText(line.text, style: _style(line))),
                                      PText(line.text.substring(0, shown), style: _style(line)),
                                    ]),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 10,
                child: Text('${_i + 1}/${_lines.length}   TAP ▶', style: pixelStyle(8, Colors.white38, shadow: false)),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: PixelLink('SKIP ▶▶', onTap: _skip),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _style(StoryLine line) =>
      bodyStyle(24, line.who == Speaker.narrator ? Colors.white : line.color, height: 1.05);
}
