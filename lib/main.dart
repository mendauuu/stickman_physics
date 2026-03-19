// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'game/stickman_game.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const StickmanApp());
}

class StickmanApp extends StatelessWidget {
  const StickmanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stickman Physics',
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
  final _game = StickmanGame();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hint': (context, game) => _HintOverlay(
                onDismiss: () => _game.overlays.remove('hint'),
              ),
        },
        initialActiveOverlays: const ['hint'],
      ),
    );
  }
}

class _HintOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const _HintOverlay({required this.onDismiss});
  @override
  State<_HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<_HintOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 500));
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }
  void _dismiss() {
    if (!mounted) return;
    _ctrl.forward().then((_) => widget.onDismiss());
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: FadeTransition(
        opacity: ReverseAnimation(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
        child: Container(
          alignment: Alignment.center,
          color: Colors.black.withOpacity(0.65),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_rotation, color: Colors.cyanAccent, size: 52),
              SizedBox(height: 18),
              Text('Tilt to move',
                  style: TextStyle(color: Colors.white, fontSize: 24,
                      fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              SizedBox(height: 10),
              Text('Shake for a surprise! 💥',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 17)),
              SizedBox(height: 28),
              Text('(tap to dismiss)',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
