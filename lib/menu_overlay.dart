part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MAIN MENU — title + selected floor on the left, the university building
// (one row per floor, B at the bottom) on the right. Floors unlock as the
// student reaches them and can be picked to start a run from there.
// ═══════════════════════════════════════════════════════════════════════════
class _MenuOverlay extends StatefulWidget {
  final SchoolGame game;
  const _MenuOverlay({required this.game});
  @override
  State<_MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<_MenuOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  String? _lockedHint;
  final _floorKeys = List.generate(kFloors.length, (_) => GlobalKey());
  int _scrolledTo = -1;
  final _heroScroll = ScrollController();
  int _heroScrolledTo = -1;

  SchoolGame get _g => widget.game;
  int get _selected => _g.menuFloor.value;
  bool get _graduated => _g.bestFloor >= kFloors.length;

  @override
  void dispose() {
    _heroScroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (!_g.isUnlocked(i)) {
      final prev = kFloors[i - 1];
      setState(() => _lockedHint = '🔒 Beat ${prev.name} (floor ${prev.floorLabel}) to unlock');
      return;
    }
    setState(() => _lockedHint = null);
    _g.previewFloor(i);
  }

  void _selectHero(int i) {
    final h = kHeroes[i];
    if (!_g.isHeroUnlocked(i)) {
      setState(() => _lockedHint = h.unlockFloor >= kFloors.length
          ? '🔒 Graduate (beat all ${kFloors.length} floors) to unlock the ${h.name}'
          : '🔒 Reach floor ${kFloors[h.unlockFloor].floorLabel} to unlock the ${h.name}');
      return;
    }
    _g.selectHero(i);
    _g.previewFloor(_selected); // redraw the preview with the new student
    setState(() => _lockedHint = null);
  }

  /// Keeps the selected student's chip in view.
  void _scrollToHero() {
    if (_heroScrolledTo == _g.heroIndex) return;
    final first = _heroScrolledTo == -1;
    _heroScrolledTo = _g.heroIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_heroScroll.hasClients) return;
      final target = (_g.heroIndex * 102.0 - 60).clamp(0.0, _heroScroll.position.maxScrollExtent);
      first
          ? _heroScroll.jumpTo(target)
          : _heroScroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  /// Keeps the selected floor visible in the scrolling building.
  void _scrollToSelected() {
    if (_scrolledTo == _selected) return;
    final first = _scrolledTo == -1;
    _scrolledTo = _selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _floorKeys[_selected].currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.5, duration: first ? Duration.zero : const Duration(milliseconds: 250));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when a floor is picked and once saved progress has loaded.
    return ValueListenableBuilder<int>(
      valueListenable: _g.menuFloor,
      builder: (context, _, __) => _layout(),
    );
  }

  Widget _layout() {
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxHeight < 360;
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xF5070D1A), Color(0xC0070D1A), Color(0x30070D1A), Color(0xD0070D1A)],
            stops: [0, 0.38, 0.6, 0.78],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: min(330.0, box.maxWidth * 0.42), child: _leftPanel(compact)),
                const Spacer(),
                SizedBox(width: min(250.0, box.maxWidth * 0.3), child: _building()),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Left: title, selected floor, play ─────────────────────────────────────
  Widget _leftPanel(bool compact) {
    _scrollToHero();
    final d = kFloors[_selected];
    final cleared = _g.isCleared(_selected) || _graduated;
    final floorsDone = _graduated ? kFloors.length : _g.bestFloor;
    final shown = compact ? 3 : 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info scrolls if it doesn't fit; the Play button below always stays visible.
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MILLAT UMIDI UNIVERSITY',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 11, letterSpacing: 4, fontWeight: FontWeight.w800)),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Text('CLASS CLASH',
                        style: TextStyle(
                          color: _cyan,
                          fontSize: compact ? 30 : 40,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: [Shadow(color: _cyan.withValues(alpha: 0.4 + _pulse.value * 0.4), blurRadius: 22)],
                        )),
                  ),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _statPill('🏢', '$floorsDone/${kFloors.length} floors passed'),
                    if (_graduated)
                      _statPill('🎓', _g.bestTime != null ? 'best ${_fmtTime(_g.bestTime!)}' : 'graduated'),
                  ]),
                  SizedBox(height: compact ? 6 : 10),

                  // Character picker (scrolls sideways: more students than fit)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      controller: _heroScroll,
                      scrollDirection: Axis.horizontal,
                      itemCount: kHeroes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => SizedBox(
                        width: 96,
                        child: _HeroChip(
                          hero: kHeroes[i],
                          unlocked: _g.isHeroUnlocked(i),
                          selected: i == _g.heroIndex,
                          onTap: () => _selectHero(i),
                        ),
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text('${_g.hero.title} · ${_g.hero.desc}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                  SizedBox(height: compact ? 6 : 10),

                  // Selected floor card
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xE6101827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: d.accent.withValues(alpha: 0.8), width: 1.5),
                      boxShadow: [BoxShadow(color: d.accent.withValues(alpha: 0.25), blurRadius: 18)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text('FLOOR ${d.floorLabel} · ${d.floorName}',
                                style: TextStyle(
                                    color: d.accent, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900)),
                          ),
                          if (cleared)
                            const Text('✓ PASSED',
                                style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.w900)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text(d.emoji, style: TextStyle(fontSize: compact ? 26 : 32)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                              Text('${d.course}  ·  2 rounds',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                            ]),
                          ),
                        ]),
                        if (!compact) const SizedBox(height: 6),
                        if (!compact)
                          Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            for (final a in d.abilities.take(shown))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: d.accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(kAbilityName[a]!,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
                              ),
                            if (d.abilities.length > shown)
                              Text('+${d.abilities.length - shown} more',
                                  style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        _BigButton(
          label: _selected == 0 ? 'START  ▶' : 'PLAY FLOOR ${d.floorLabel}  ▶',
          color: d.accent,
          small: true,
          wide: true,
          onTap: () => _g.startRun(fromFloor: _selected),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _lockedHint ??
                (_selected == 0
                    ? 'Climb all ${kFloors.length} floors to graduate!'
                    : 'Best time only counts when you start from the basement'),
            key: ValueKey(_lockedHint ?? 'floor$_selected'),
            style: TextStyle(color: _lockedHint != null ? const Color(0xFFFF8A80) : Colors.white38, fontSize: 10.5),
          ),
        ),
      ],
    );
  }

  Widget _statPill(String icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$icon $text', style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  // ── Right: the university building, one row per floor ─────────────────────
  Widget _building() {
    _scrollToSelected();
    const rowH = 40.0, gap = 4.0;
    final rows = <Widget>[];
    // ListView(reverse: true) lays children bottom-up, so B sits at the bottom.
    for (var i = 0; i < kFloors.length; i++) {
      rows.add(Padding(
        key: _floorKeys[i],
        padding: const EdgeInsets.only(bottom: gap),
        child: _FloorRow(
          def: kFloors[i],
          height: rowH,
          unlocked: _g.isUnlocked(i),
          cleared: _g.isCleared(i) || _graduated,
          isNew: i == _g.bestFloor && !_graduated && i > 0,
          selected: i == _selected,
          onTap: () => _select(i),
        ),
      ));
      if (i == 0) rows.add(_street(14));
    }
    return Column(
      children: [
        _roof(30),
        Expanded(
          child: ShaderMask(
            // Fade rows out at the top edge to hint that the building scrolls.
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white, Colors.white],
              stops: [0, 0.06, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: ListView(
              reverse: true,
              padding: const EdgeInsets.only(top: 6),
              children: rows,
            ),
          ),
        ),
      ],
    );
  }

  Widget _roof(double h) => SizedBox(
        height: h,
        child: CustomPaint(
          painter: _RoofPainter(),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('🎓 MILLAT UMIDI',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          ),
        ),
      );

  Widget _street(double h) => Container(
        height: h,
        margin: const EdgeInsets.only(bottom: 4),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF66BB6A), width: 2)),
        ),
        child: const Text('STREET LEVEL', style: TextStyle(color: Colors.white30, fontSize: 7, letterSpacing: 3)),
      );
}

class _RoofPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height - 2)
      ..lineTo(size.width * 0.12, 2)
      ..lineTo(size.width * 0.88, 2)
      ..lineTo(size.width, size.height - 2)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF8D2C2C));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _gold.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloorRow extends StatelessWidget {
  final TeacherDef def;
  final double height;
  final bool unlocked, cleared, isNew, selected;
  final VoidCallback onTap;

  const _FloorRow({
    required this.def,
    required this.height,
    required this.unlocked,
    required this.cleared,
    required this.isNew,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tall = height >= 38;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: unlocked ? Color.lerp(def.wall, Colors.black, selected ? 0 : 0.3) : const Color(0xFF151A23),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? def.accent : (unlocked ? def.accent.withValues(alpha: 0.25) : Colors.white10),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: def.accent.withValues(alpha: 0.5), blurRadius: 14)] : null,
        ),
        child: Row(children: [
          // floor number plate
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unlocked ? def.accent : Colors.white12,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(def.floorLabel,
                style: TextStyle(
                    color: unlocked ? Colors.black : Colors.white38, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Text(unlocked ? def.emoji : '🔒', style: TextStyle(fontSize: tall ? 18 : 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unlocked ? def.subject : 'LOCKED',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: unlocked ? Colors.white : Colors.white30, fontSize: 11, fontWeight: FontWeight.w900)),
                if (tall)
                  Text(unlocked ? def.name : '???',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
              ],
            ),
          ),
          if (cleared)
            const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 16)
          else if (isNew)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(6)),
              child: const Text('NEW', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
            ),
        ]),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final HeroDef hero;
  final bool unlocked, selected;
  final VoidCallback onTap;

  const _HeroChip({required this.hero, required this.unlocked, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? hero.color.withValues(alpha: 0.18) : const Color(0xCC101827),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? hero.color : (unlocked ? Colors.white24 : Colors.white10),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Text(unlocked ? hero.emoji : '🔒', style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hero.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: unlocked ? Colors.white : Colors.white38, fontSize: 10, fontWeight: FontWeight.w900)),
                Text(
                    unlocked
                        ? '${hero.hp} HP'
                        : hero.unlockFloor >= kFloors.length
                            ? 'Graduate'
                            : 'Floor ${kFloors[hero.unlockFloor].floorLabel}',
                    maxLines: 1, style: TextStyle(color: unlocked ? hero.color : Colors.white30, fontSize: 8.5)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
