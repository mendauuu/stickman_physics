import 'dart:math' show min;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/audio.dart';
import 'game/campus.dart';
import 'game/heroes.dart';
import 'game/minions.dart';
import 'game/school_game.dart';
import 'game/story.dart';
import 'game/teachers.dart';
import 'pixel/pixel_art.dart';
import 'pixel/pixel_ui.dart';

part 'menu_overlay.dart';
part 'pause_overlay.dart';
part 'rest_overlay.dart';
part 'story_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await PixelArt.load(); // icons and buttons are ready before the first frame
  runApp(const ExamEscapeApp());
}

class ExamEscapeApp extends StatelessWidget {
  const ExamEscapeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exam Escape',
      debugShowCheckedModeBanner: false,
      // Everything is pixel art: pixel fonts, no ripples, no rounded Material bits.
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: kPixelFont,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const _GamePage(),
    );
  }
}

class _GamePage extends StatefulWidget {
  const _GamePage();
  @override
  State<_GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<_GamePage> with WidgetsBindingObserver {
  final _game = SchoolGame();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Switching apps or getting a call mid-fight pauses the game.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _game.inFight && !_game.isPaused) _game.pauseGame();
  }

  /// Android back button: pause/resume during a fight, back to the menu
  /// from other screens, and only leave the app from the main menu.
  void _onBack() {
    final g = _game;
    if (g.isPaused) {
      g.resumeGame();
    } else if (g.phase == Phase.story) {
      g.endStory(); // skip the story
    } else if (g.inFight) {
      g.pauseGame();
    } else if (g.phase == Phase.menu) {
      SystemNavigator.pop();
    } else {
      g.toMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'menu': (ctx, _) => _MenuOverlay(game: _game),
          'intro': (ctx, _) => _IntroOverlay(game: _game),
          'story': (ctx, _) => _StoryOverlay(game: _game),
          'rest': (ctx, _) => _RestOverlay(game: _game),
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
const _panel = Color(0xFF161D2A);

String _fmtTime(double s) => '${s ~/ 60}:${(s % 60).floor().toString().padLeft(2, '0')}';

// ═══════════════════════════════════════════════════════════════════════════
// ROOM INTRO — the boss introduces themselves (or the hall is described)
// ═══════════════════════════════════════════════════════════════════════════
class _IntroOverlay extends StatelessWidget {
  final SchoolGame game;
  const _IntroOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    final d = game.def, r = game.room;
    final boss = r.isBoss;
    final monsters = {for (final w in r.waves) ...w}.toList();
    final b = r.buildingDef;
    final abilities = d.twins.isNotEmpty
        ? [...d.allAbilities, if (game.round > 1) ...d.finalAbilities]
        : game.currentAbilities;
    return Container(
      color: kInk.withValues(alpha: 0.5),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: PixelPanel(
                color: _panel,
                accent: d.accent,
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (r.number == 1 && game.round == 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: PText('${b.emoji}  FLOOR ${b.letter} · ${b.name.toUpperCase()}',
                            textAlign: TextAlign.center, style: pixelStyle(12, b.color, spacing: 1)),
                      ),
                    PText('🕒 ${clockText(r.minutes)}  ·  ${timeLeftText(r.minutes).toUpperCase()}',
                        style: pixelStyle(8, Colors.white54)),
                    const SizedBox(height: 4),
                    Text(
                        boss
                            ? 'ROOM ${r.label}  ·  ${game.rounds == 2 ? 'ROUND' : 'PHASE'} ${game.round}/${game.rounds} ${game.roundName}'
                            : 'ROOM ${r.label}  ·  MONSTER HALL',
                        textAlign: TextAlign.center,
                        style: pixelStyle(9, d.accent)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        PText(r.emoji, style: pixelStyle(26, Colors.white)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PText(boss ? d.name : r.name, style: pixelStyle(16, Colors.white)),
                              const SizedBox(height: 3),
                              Text(
                                  boss
                                      ? '${d.course}  ·  ${game.fearPhase ? 'cannot be hurt' : '${game.teacher.maxHp.round()} HP'}'
                                      : '${b.name}  ·  ${r.waves.length} waves of monsters',
                                  style: bodyStyle(16, Colors.white60, shadow: false)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: kInk.withValues(alpha: 0.6),
                      child: PText(boss ? '“${d.lineFor(game.round)}”' : d.intro,
                          style: bodyStyle(20, Colors.white, height: 1.05)),
                    ),
                    if (boss && game.fearPhase)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: PText(
                            '🧍 Stop running. STAND STILL and he shrinks. Every Lost Note makes him shrink faster '
                            '(${game.notesFound}/${kLostNotes.length}).',
                            style: bodyStyle(17, const Color(0xFFFFF59D))),
                      ),
                    if (boss && d.twins.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: PText('⚖️ They take turns. Hit one, and the other gets stronger.',
                            style: bodyStyle(17, const Color(0xFFFFE082))),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(boss ? 'SPECIAL ABILITIES' : 'MONSTERS IN THIS HALL',
                          style: pixelStyle(8, d.accent, spacing: 1)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (name, tip) in boss
                            ? [for (final a in abilities) (d.abilityName(a), d.abilityTip(a))]
                            : [
                                for (final m in monsters) ('${kMinions[m]!.emoji} ${kMinions[m]!.name}', kMinions[m]!.tip)
                              ])
                          Container(
                            padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
                            decoration: BoxDecoration(
                              color: Color.lerp(_panel, d.accent, 0.14),
                              border: Border(left: BorderSide(color: d.accent, width: kUiPx)),
                            ),
                            child: Text.rich(TextSpan(children: [
                              TextSpan(text: pixelSafe(name), style: pixelStyle(8, Colors.white)),
                              TextSpan(text: '  ${pixelSafe(tip)}', style: bodyStyle(15, Colors.white60, shadow: false)),
                            ])),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _BigButton(
                        label: boss ? 'FIGHT!' : 'CLEAR THE HALL!', color: d.accent, onTap: game.beginFight, small: true),
                  ],
                ),
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
    return Stack(
      children: [
        // Pause — lines up with the canvas HUD, so it ignores the safe area.
        Positioned(
          top: 2,
          left: 2,
          child: _PauseButton(onTap: game.pauseGame),
        ),
        SafeArea(
          child: Stack(
            children: [
              // Movement
              Positioned(
                left: 16,
                bottom: 10,
                child: Row(children: [
                  _TouchButton(
                    icon: 'ui_left',
                    color: SquareColor.blue,
                    onDown: () => game.left = true,
                    onUp: () => game.left = false,
                  ),
                  const SizedBox(width: 12),
                  _TouchButton(
                    icon: 'ui_right',
                    color: SquareColor.blue,
                    onDown: () => game.right = true,
                    onUp: () => game.right = false,
                  ),
                ]),
              ),
              // Actions
              Positioned(
                right: 16,
                bottom: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: game.energy,
                      builder: (_, e, __) => _TouchButton(
                        size: 50,
                        icon: 'bolt',
                        tint: false,
                        color: e >= 100 ? SquareColor.orange : SquareColor.salmon,
                        glow: e >= 100,
                        progress: e / 100,
                        onDown: game.pressSpecial,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TouchButton(
                      size: 48,
                      icon: 'ui_right',
                      twice: true,
                      color: SquareColor.blue,
                      onDown: game.pressRoll,
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: _TouchButton(
                        icon: 'ui_up',
                        color: SquareColor.green,
                        onDown: game.pressJump,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _TouchButton(
                      size: 66,
                      icon: 'sword',
                      tint: false,
                      color: SquareColor.red,
                      onDown: game.pressAttack,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Multi-touch friendly pixel button: reacts on pointer down/up, not on tap.
class _TouchButton extends StatefulWidget {
  final double size;
  final String icon;
  final bool twice; // the icon drawn twice (roll)
  final bool tint; // draw the icon in white
  final SquareColor color;
  final bool glow;
  final double? progress;
  final VoidCallback onDown;
  final VoidCallback? onUp;

  const _TouchButton({
    this.size = 54,
    required this.icon,
    this.twice = false,
    this.tint = true,
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
    final glyph = widget.icon.startsWith('ui_');
    final iconH = glyph ? s * 0.32 : s * 0.5;
    final icon = PixelIcon(widget.icon, size: iconH, tint: widget.tint ? Colors.white : null);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: Opacity(
        opacity: 0.88,
        child: PixelSquare(
          size: s,
          color: widget.color,
          pressed: _down,
          glow: widget.glow,
          progress: widget.progress,
          child: widget.twice ? Row(mainAxisSize: MainAxisSize.min, children: [icon, icon]) : icon,
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
    'The bell is still ringing…',
    'Your name is written in pencil. For now.',
    'Every student who sleeps comes to my school. Few wake up.',
    'The clock is still ticking. Get up.',
    'Mira is waiting for you. Try again.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kInk.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PText('💤  STILL ASLEEP', style: pixelStyle(28, const Color(0xFFFF5252), spacing: 2)),
                const SizedBox(height: 12),
                PText(
                    game.room.isBoss
                        ? '${game.bossName} kept you in the dream.'
                        : 'The nightmare swallowed ${game.room.name}.',
                    textAlign: TextAlign.center,
                    style: pixelStyle(11, Colors.white)),
                const SizedBox(height: 6),
                Text(_lines[(game.hitsLanded + game.floor) % _lines.length],
                    textAlign: TextAlign.center, style: bodyStyle(20, Colors.white54, shadow: false)),
                const SizedBox(height: 20),
                _BigButton(label: 'TRY AGAIN ${game.room.label}', color: _cyan, onTap: game.retryFloor, small: true),
                const SizedBox(height: 6),
                PixelLink('MAIN MENU', onTap: game.toMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VICTORY — Ozod wakes up at 8:59 AM
// ═══════════════════════════════════════════════════════════════════════════
class _VictoryOverlay extends StatelessWidget {
  final SchoolGame game;
  const _VictoryOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final isBest = g.bestTime != null && g.runTime <= g.bestTime!;
    return Container(
      // After the walk out into the light, let the landscape show through.
      color: kInk.withValues(alpha: g.escaping ? 0.55 : 0.85),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  PixelIcon('sun', size: 40),
                  SizedBox(width: 14),
                  PixelIcon('clock', size: 44),
                  SizedBox(width: 14),
                  PixelIcon('sparkle', size: 34),
                ]),
                const SizedBox(height: 10),
                Text('YOU WOKE UP!', style: pixelStyle(30, _gold, spacing: 2)),
                const SizedBox(height: 10),
                Text('8:59 AM. You reached the Exam Hall just as the doors closed — and you remember everything.',
                    textAlign: TextAlign.center, style: bodyStyle(20, Colors.white70)),
                PText('📄 Lost Notes found: ${g.notesFound}/${kLostNotes.length}  ·  👻 Mira woke up too.',
                    textAlign: TextAlign.center, style: bodyStyle(19, const Color(0xFFB2EBF2))),
                const SizedBox(height: 4),
                PText(kPostCredit,
                    textAlign: TextAlign.center, style: bodyStyle(17, const Color(0xFFFF8A80), shadow: false)),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stat('TIME', _fmtTime(g.runTime), isBest ? '🏆 BEST' : null),
                    _stat('HITS', '${g.hitsLanded}', null),
                    _stat('RETRIES', '${g.retries}', g.retries == 0 ? 'PERFECT' : null),
                    _stat('COMBO', '${g.maxCombo}', g.maxCombo >= 20 ? 'LEGEND' : null),
                  ],
                ),
                const SizedBox(height: 14),
                _BigButton(label: 'PLAY AGAIN', color: _cyan, onTap: g.startRun, small: true),
                PixelLink('MAIN MENU', onTap: g.toMenu),
                Text('Icons: BlackSkull-k · Xmas: 0-mem0ry · Hero art: Ozzbit Games',
                    style: bodyStyle(14, Colors.white30, shadow: false)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, String? badge) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 104,
        child: PixelPanel(
          color: _panel,
          accent: badge != null ? _gold : const Color(0xFF3A4458),
          px: 2,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(children: [
            Text(label, style: pixelStyle(8, const Color(0xFF8ECAE6))),
            const SizedBox(height: 4),
            Text(value, style: pixelStyle(16, Colors.white)),
            if (badge != null) ...[const SizedBox(height: 3), PText(badge, style: pixelStyle(7, _gold))],
          ]),
        ),
      ),
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
    return PixelButton(
      label: label,
      color: color,
      small: small,
      wide: wide,
      onTap: () {
        GameAudio.instance.play('click');
        onTap();
      },
    );
  }
}
