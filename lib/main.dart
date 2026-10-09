import 'dart:math' show min;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/heroes.dart';
import 'game/school_game.dart';
import 'game/teachers.dart';

part 'menu_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ClassClashApp());
}

class ClassClashApp extends StatelessWidget {
  const ClassClashApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Class Clash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _GamePage(),
    );
  }
}

class _GamePage extends StatefulWidget {
  const _GamePage();
  @override
  State<_GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<_GamePage> {
  final _game = SchoolGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'menu': (ctx, _) => _MenuOverlay(game: _game),
          'intro': (ctx, _) => _IntroOverlay(game: _game),
          'controls': (ctx, _) => _ControlsOverlay(game: _game),
          'pause': (ctx, _) => _PauseOverlay(game: _game),
          'gameOver': (ctx, _) => _GameOverOverlay(game: _game),
          'victory': (ctx, _) => _VictoryOverlay(game: _game),
        },
        initialActiveOverlays: const ['menu'],
      ),
    );
  }
}

const _cyan = Color(0xFF00E5FF);
const _gold = Color(0xFFFFD54F);
const _panel = Color(0xEE111A2B);

String _fmtTime(double s) =>
    '${s ~/ 60}:${(s % 60).floor().toString().padLeft(2, '0')}';

// ═══════════════════════════════════════════════════════════════════════════
// FLOOR INTRO — the teacher introduces themselves
// ═══════════════════════════════════════════════════════════════════════════
class _IntroOverlay extends StatelessWidget {
  final SchoolGame game;
  const _IntroOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    final d = game.def;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: d.accent, width: 2),
                boxShadow: [BoxShadow(color: d.accent.withValues(alpha: 0.35), blurRadius: 24)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('FLOOR ${d.floorLabel}  ·  ROUND ${game.round}/$kRoundsPerFloor ${game.roundName}',
                      style: TextStyle(
                          color: d.accent, fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(d.emoji, style: const TextStyle(fontSize: 40)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                            Text('${d.course}  ·  ${game.teacher.maxHp.round()} HP',
                                style: const TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('“${game.isFinalRound ? d.finalLine : d.intro}”',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic, height: 1.35)),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('SPECIAL ABILITIES',
                        style: TextStyle(color: d.accent, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in game.currentAbilities)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: d.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: d.accent.withValues(alpha: 0.5)),
                          ),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(
                                text: kAbilityName[a],
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                            TextSpan(
                                text: '  ${kAbilityTip[a]}',
                                style: const TextStyle(color: Colors.white60, fontSize: 10)),
                          ])),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _BigButton(label: 'FIGHT!', color: d.accent, onTap: game.beginFight, small: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TOUCH CONTROLS
// ═══════════════════════════════════════════════════════════════════════════
class _ControlsOverlay extends StatelessWidget {
  final SchoolGame game;
  const _ControlsOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Pause
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 52),
                child: _TouchButton(
                  size: 34,
                  icon: Icons.pause,
                  color: Colors.white,
                  onDown: game.pauseGame,
                ),
              ),
            ),
          ),
          // Movement
          Positioned(
            left: 16,
            bottom: 14,
            child: Row(children: [
              _TouchButton(
                icon: Icons.arrow_back_rounded,
                color: Colors.white,
                onDown: () => game.left = true,
                onUp: () => game.left = false,
              ),
              const SizedBox(width: 14),
              _TouchButton(
                icon: Icons.arrow_forward_rounded,
                color: Colors.white,
                onDown: () => game.right = true,
                onUp: () => game.right = false,
              ),
            ]),
          ),
          // Actions
          Positioned(
            right: 16,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: game.energy,
                  builder: (_, e, __) => _TouchButton(
                    size: 58,
                    label: '⚡',
                    color: e >= 100 ? _gold : Colors.white24,
                    glow: e >= 100,
                    progress: e / 100,
                    onDown: game.pressSpecial,
                  ),
                ),
                const SizedBox(width: 10),
                _TouchButton(
                  size: 54,
                  icon: Icons.fast_forward_rounded,
                  color: const Color(0xFF80D8FF),
                  onDown: game.pressRoll,
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 46),
                  child: _TouchButton(
                    icon: Icons.keyboard_double_arrow_up_rounded,
                    color: _cyan,
                    onDown: game.pressJump,
                  ),
                ),
                const SizedBox(width: 12),
                _TouchButton(
                  size: 78,
                  label: '⚔',
                  color: const Color(0xFFFF5252),
                  onDown: game.pressAttack,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-touch friendly button: reacts on pointer down/up, not on tap.
class _TouchButton extends StatefulWidget {
  final double size;
  final IconData? icon;
  final String? label;
  final Color color;
  final bool glow;
  final double? progress;
  final VoidCallback onDown;
  final VoidCallback? onUp;

  const _TouchButton({
    this.size = 64,
    this.icon,
    this.label,
    required this.color,
    this.glow = false,
    this.progress,
    required this.onDown,
    this.onUp,
  });

  @override
  State<_TouchButton> createState() => _TouchButtonState();
}

class _TouchButtonState extends State<_TouchButton> {
  bool _down = false;

  void _press() {
    if (!mounted) return;
    setState(() => _down = true);
    widget.onDown();
  }

  void _release() {
    if (!_down) return;
    _down = false;
    if (mounted) setState(() {});
    widget.onUp?.call();
  }

  @override
  void dispose() {
    // The controls disappear when you die or pause; don't leave a key held.
    if (_down) widget.onUp?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        scale: _down ? 0.88 : 1,
        duration: const Duration(milliseconds: 60),
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.progress != null)
                SizedBox(
                  width: s,
                  height: s,
                  child: CircularProgressIndicator(
                    value: widget.progress!.clamp(0.0, 1.0),
                    strokeWidth: 4,
                    color: _gold,
                    backgroundColor: Colors.white10,
                  ),
                ),
              Container(
                width: s - 8,
                height: s - 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: _down ? 0.45 : 0.22),
                  border: Border.all(color: widget.color.withValues(alpha: 0.8), width: 2),
                  boxShadow: widget.glow
                      ? [BoxShadow(color: widget.color.withValues(alpha: 0.7), blurRadius: 18)]
                      : null,
                ),
                alignment: Alignment.center,
                child: widget.icon != null
                    ? Icon(widget.icon, color: Colors.white, size: s * 0.45)
                    : Text(widget.label ?? '', style: TextStyle(fontSize: s * 0.38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAUSE
// ═══════════════════════════════════════════════════════════════════════════
class _PauseOverlay extends StatelessWidget {
  final SchoolGame game;
  const _PauseOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('BREAK TIME ☕',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3)),
            const SizedBox(height: 20),
            _BigButton(label: 'RESUME', color: _cyan, onTap: game.resumeGame, small: true),
            const SizedBox(height: 10),
            TextButton(
              onPressed: game.toMenu,
              child: const Text('QUIT TO MENU', style: TextStyle(color: Color(0xFF8ECAE6), letterSpacing: 2)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GAME OVER
// ═══════════════════════════════════════════════════════════════════════════
class _GameOverOverlay extends StatelessWidget {
  final SchoolGame game;
  const _GameOverOverlay({required this.game});

  static const _lines = [
    'Your parents will be notified.',
    'See you at the retake exam.',
    'Maybe try studying next time?',
    'Detention for a week!',
    'That was NOT on the syllabus.',
  ];

  @override
  Widget build(BuildContext context) {
    final d = game.def;
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📝  FAILED!',
                  style: TextStyle(color: Color(0xFFFF5252), fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const SizedBox(height: 6),
              Text('${d.name} gave you an F in ${d.course}.',
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
              Text(_lines[(game.hitsLanded + game.floor) % _lines.length],
                  style: const TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic)),
              const SizedBox(height: 22),
              _BigButton(label: 'RETAKE FLOOR ${d.floorLabel}', color: _cyan, onTap: game.retryFloor, small: true),
              const SizedBox(height: 8),
              TextButton(
                onPressed: game.toMenu,
                child: const Text('MAIN MENU', style: TextStyle(color: Color(0xFF8ECAE6), letterSpacing: 2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VICTORY — graduated!
// ═══════════════════════════════════════════════════════════════════════════
class _VictoryOverlay extends StatefulWidget {
  final SchoolGame game;
  const _VictoryOverlay({required this.game});
  @override
  State<_VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<_VictoryOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final isBest = g.bestTime != null && g.runTime <= g.bestTime!;
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎓', style: TextStyle(fontSize: 56)),
                  const Text('YOU GRADUATED!',
                      style: TextStyle(color: _gold, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 4)),
                  const Text('Millat Umidi University is proud of you.',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stat('TIME', _fmtTime(g.runTime), isBest ? '🏆 BEST' : null),
                      _stat('HITS', '${g.hitsLanded}', null),
                      _stat('RETAKES', '${g.retries}', g.retries == 0 ? 'PERFECT' : null),
                      _stat('COMBO', '${g.maxCombo}', g.maxCombo >= 20 ? 'LEGEND' : null),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _BigButton(label: 'PLAY AGAIN', color: _cyan, onTap: g.startRun, small: true),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: g.toMenu,
                    child: const Text('MAIN MENU', style: TextStyle(color: Color(0xFF8ECAE6), letterSpacing: 2)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, String? badge) {
    return Container(
      width: 96,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badge != null ? _gold : Colors.white12, width: 1.5),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(color: Color(0xFF8ECAE6), fontSize: 11, letterSpacing: 2)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        if (badge != null) Text(badge, style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Shared button ─────────────────────────────────────────────────────────────
class _BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool small;
  final bool wide; // fill the available width; text shrinks to fit
  const _BigButton(
      {required this.label, required this.color, required this.onTap, this.small = false, this.wide = false});

  @override
  Widget build(BuildContext context) {
    // Dark text on light buttons (gold, green) so the label stays readable.
    final light = color.computeLuminance() > 0.45;
    final text = Text(label,
        maxLines: 1,
        style: TextStyle(
            color: light ? const Color(0xFF111111) : Colors.white,
            fontSize: small ? 18 : 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: light ? null : const [Shadow(color: Colors.black45, blurRadius: 4)]));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: wide ? double.infinity : null,
        alignment: wide ? Alignment.center : null,
        padding: EdgeInsets.symmetric(horizontal: wide ? 20 : (small ? 40 : 56), vertical: small ? 12 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.35)!]),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: 1)],
        ),
        child: wide ? FittedBox(fit: BoxFit.scaleDown, child: text) : text,
      ),
    );
  }
}
