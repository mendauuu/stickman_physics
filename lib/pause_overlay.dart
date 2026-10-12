part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PAUSE BUTTON — top-left corner, left of the player's health bar.
// ═══════════════════════════════════════════════════════════════════════════
class _PauseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PauseButton({required this.onTap});
  @override
  State<_PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<_PauseButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const Key('pause'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        setState(() => _down = true);
        widget.onTap();
      },
      onPointerUp: (_) {
        if (mounted) setState(() => _down = false);
      },
      onPointerCancel: (_) {
        if (mounted) setState(() => _down = false);
      },
      child: Padding(
        padding: const EdgeInsets.all(6), // bigger touch target than it looks
        child: PixelSquare(
          size: 32,
          color: SquareColor.green,
          pressed: _down,
          child: const _PauseBars(),
        ),
      ),
    );
  }
}

/// Two white pixel bars.
class _PauseBars extends StatelessWidget {
  const _PauseBars();
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 4, height: 13, color: Colors.white),
      const SizedBox(width: 4),
      Container(width: 4, height: 13, color: Colors.white),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAUSE MENU — fight status on the left, actions on the right.
// ═══════════════════════════════════════════════════════════════════════════
class _PauseOverlay extends StatefulWidget {
  final SchoolGame game;
  const _PauseOverlay({required this.game});
  @override
  State<_PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<_PauseOverlay> {
  bool _confirmQuit = false;

  SchoolGame get _g => widget.game;

  void _quit() {
    if (!_confirmQuit) {
      setState(() => _confirmQuit = true);
      return;
    }
    _g.toMenu();
  }

  @override
  Widget build(BuildContext context) {
    final d = _g.def;
    return Stack(
      children: [
        // Dimmed game behind the menu (a dither, not a blur). Tapping outside resumes.
        Positioned.fill(
          child: GestureDetector(onTap: _g.resumeGame, child: const _Dither()),
        ),
        SafeArea(
          child: Center(
            child: LayoutBuilder(builder: (context, box) {
              final compact = box.maxHeight < 340;
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 680, maxHeight: box.maxHeight - 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: PixelPanel(
                    accent: d.accent,
                    padding: const EdgeInsets.all(4),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 11, child: _statusPanel(compact)),
                          Container(width: kUiPx, color: kInk),
                          Expanded(flex: 9, child: _actionsPanel(compact)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Left: where you are and how the fight is going ────────────────────────
  Widget _statusPanel(bool compact) {
    final d = _g.def, p = _g.player, t = _g.teacher;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(8, compact ? 4 : 8, 12, compact ? 4 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text('PAUSED', style: pixelStyle(20, Colors.white, spacing: 2)),
            const Spacer(),
            _pill('⏱ ${_fmtTime(_g.runTime)}', Colors.white70),
          ]),
          SizedBox(height: compact ? 8 : 12),
          // Current fight
          Container(
            padding: const EdgeInsets.all(8),
            color: Color.lerp(const Color(0xFF1B2230), d.accent, 0.12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                color: d.accent,
                child: Text(_g.room.label, style: pixelStyle(10, kInk, shadow: false)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PText(_g.room.isBoss ? _g.bossName : _g.room.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: pixelStyle(11, Colors.white)),
                  const SizedBox(height: 3),
                  PText(
                      _g.room.isBoss
                          ? '${_g.rounds == 2 ? 'ROUND' : 'PHASE'} ${_g.round}/${_g.rounds} · ${_g.roundName}'
                          : 'WAVE ${_g.wave + 1}/${_g.room.waves.length}',
                      maxLines: 1,
                      style: pixelStyle(8, _g.isFinalRound && _g.room.isBoss ? const Color(0xFFFF8A80) : d.accent)),
                ]),
              ),
            ]),
          ),
          SizedBox(height: compact ? 8 : 12),
          // Bars
          _statBar('heart', 'YOU', p.hp / p.maxHp, '${p.hp.ceil()}',
              Color.lerp(const Color(0xFFFF1744), const Color(0xFF00E676), p.hp / p.maxHp)!),
          const SizedBox(height: 6),
          _statBar('bolt', 'POWER', p.energy / 100, '${p.energy.round()}%', _gold),
          const SizedBox(height: 6),
          if (_g.room.isBoss)
            _statBar('skull', 'BOSS', t.hp / t.maxHp, '${t.hp.ceil()}', t.rage ? const Color(0xFFFF1744) : d.accent)
          else
            _statBar('invader', 'HALL', _g.wave / _g.room.waves.length, '${_g.minionCount} left', d.accent),
          if (_g.perks.isNotEmpty) ...[
            const SizedBox(height: 8),
            PText('📄 ${_g.perks.map((p) => kPerks[p]!.emoji).join(' ')}', style: pixelStyle(9, Colors.white70)),
          ],
          if (!compact) ...[
            const SizedBox(height: 10),
            // Controls cheat-sheet
            const Wrap(spacing: 6, runSpacing: 6, children: [
              _KeyHint(icon: 'ui_right', label: 'Move'),
              _KeyHint(icon: 'ui_up', label: 'Jump x2'),
              _KeyHint(icon: 'ui_right', label: 'Roll', double: true),
              _KeyHint(icon: 'sword', label: 'Combo'),
              _KeyHint(icon: 'bolt', label: 'Power'),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Right: what to do next ────────────────────────────────────────────────
  Widget _actionsPanel(bool compact) {
    final d = _g.def;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, compact ? 4 : 8, 8, compact ? 4 : 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BigButton(label: 'RESUME  ▶', color: d.accent, onTap: _g.resumeGame, small: true, wide: true),
          SizedBox(height: compact ? 8 : 10),
          _MenuAction(
            icon: 'clock',
            label: 'RETAKE ROUND',
            sub: 'Full HP · restart ${_g.roundName.toLowerCase()}',
            onTap: _g.retryFloor,
          ),
          const SizedBox(height: 8),
          // Settings: music, sound effects, vibration (saved between sessions)
          Row(children: [
            Expanded(
              child: _SettingToggle(
                on: _g.musicOn,
                icon: 'note',
                label: 'MUSIC',
                onTap: () => setState(() => _g.setMusic(!_g.musicOn)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SettingToggle(
                on: _g.sfxOn,
                icon: 'bell',
                label: 'SOUND',
                onTap: () => setState(() => _g.setSfx(!_g.sfxOn)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _SettingToggle(
                on: _g.vibrationOn,
                icon: 'bolt',
                label: 'VIBRATE',
                onTap: () => setState(() => _g.setVibration(!_g.vibrationOn)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _MenuAction(
            icon: 'door',
            label: _confirmQuit ? 'TAP AGAIN TO QUIT' : 'QUIT TO MENU',
            sub: _confirmQuit ? 'This floor\'s progress will be lost' : 'Back to the main menu',
            danger: _confirmQuit,
            onTap: _quit,
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        color: kInk,
        child: PText(text, style: pixelStyle(9, color)),
      );

  Widget _statBar(String icon, String label, double value, String amount, Color color) {
    return Row(children: [
      PixelIcon(icon, size: 14),
      const SizedBox(width: 6),
      SizedBox(width: 52, child: Text(label, maxLines: 1, style: pixelStyle(8, Colors.white70))),
      Expanded(child: _PixelBar(value: value, color: color, height: 12)),
      SizedBox(
        width: 64,
        child: Text(amount, textAlign: TextAlign.right, maxLines: 1, style: pixelStyle(8, Colors.white)),
      ),
    ]);
  }
}

/// A health-style bar: ink outline, dark trough, fill in whole pixels with a
/// light top row.
class _PixelBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const _PixelBar({required this.value, required this.color, this.height = 12});

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, child: CustomPaint(painter: _BarPainter(value.clamp(0.0, 1.0), color)));
}

class _BarPainter extends CustomPainter {
  final double v;
  final Color color;
  _BarPainter(this.v, this.color);

  @override
  void paint(Canvas c, Size s) {
    const p = kUiPx;
    c.drawRect(Offset.zero & s, Paint()..color = kInk);
    final inner = Rect.fromLTWH(p, p, s.width - 2 * p, s.height - 2 * p);
    c.drawRect(inner, Paint()..color = const Color(0xFF2A2F3D));
    final w = ((inner.width * v) / p).floor() * p;
    if (w <= 0) return;
    c.drawRect(Rect.fromLTWH(inner.left, inner.top, w, inner.height), Paint()..color = color);
    c.drawRect(Rect.fromLTWH(inner.left, inner.top, w, p), Paint()..color = Color.lerp(color, Colors.white, 0.4)!);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.v != v || old.color != color;
}

/// A checkerboard of dark pixels over the game — the old-console way to dim.
class _Dither extends StatelessWidget {
  const _Dither();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DitherPainter(), child: const SizedBox.expand());
}

class _DitherPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = kInk.withValues(alpha: 0.55));
    final p = Paint()..color = kInk.withValues(alpha: 0.5);
    const d = kUiPx;
    for (var y = 0.0; y < s.height; y += d * 2) {
      for (var x = (y / d / 2).floor().isEven ? 0.0 : d; x < s.width; x += d * 2) {
        c.drawRect(Rect.fromLTWH(x, y, d, d), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DitherPainter old) => false;
}

class _MenuAction extends StatelessWidget {
  final String icon;
  final String label, sub;
  final VoidCallback onTap;
  final bool danger;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF5252) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        GameAudio.instance.play('click');
        onTap();
      },
      child: PixelPanel(
        color: danger ? const Color(0xFF4A1620) : const Color(0xFF242C3C),
        accent: danger ? const Color(0xFFFF5252) : null,
        px: 2,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(children: [
          PixelIcon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: pixelStyle(10, color)),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle(15, color.withValues(alpha: 0.6), shadow: false)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  final bool on;
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _SettingToggle({required this.on, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: PixelPanel(
        color: on ? const Color(0xFF2E4A2E) : const Color(0xFF1A1E26),
        accent: on ? const Color(0xFF69F0AE) : const Color(0xFF3A4050),
        px: 2,
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, children: [
            Opacity(opacity: on ? 1 : 0.35, child: PixelIcon(icon, size: 18)),
            if (!on) const PixelIcon('ui_x', size: 12),
          ]),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(on ? label : '$label OFF',
                maxLines: 1, style: pixelStyle(7, on ? Colors.white : Colors.white38, shadow: false)),
          ),
        ]),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String icon;
  final String label;
  final bool double;
  const _KeyHint({required this.icon, required this.label, this.double = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 6, 3),
      color: Colors.white.withValues(alpha: 0.06),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        PixelIcon(icon, size: 12),
        if (double) PixelIcon(icon, size: 12),
        const SizedBox(width: 5),
        Text(label, style: bodyStyle(15, Colors.white60, shadow: false)),
      ]),
    );
  }
}
