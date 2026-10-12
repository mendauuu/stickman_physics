part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MAIN MENU — title, characters and the selected room on the left; the map
// of the Nightmare University (floors 1 → 6, one per hour, and their rooms)
// on the right. Rooms unlock as Ozod reaches them and can be picked to start
// a run from there.
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
  String? _tab; // floor shown on the map; follows the selection by default
  final _heroScroll = ScrollController();
  int _heroScrolledTo = -1;

  SchoolGame get _g => widget.game;
  int get _selected => _g.menuFloor.value;
  bool get _graduated => _g.bestFloor >= kRooms.length;

  @override
  void dispose() {
    _heroScroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _select(int i) {
    GameAudio.instance.play('click');
    if (!_g.isUnlocked(i)) {
      final prev = kRooms[i - 1];
      setState(() => _lockedHint = '🔒 Clear ${prev.label} · ${prev.name} first');
      return;
    }
    setState(() {
      _lockedHint = null;
      _tab = kRooms[i].building;
    });
    _g.previewFloor(i);
  }

  void _selectBuilding(BuildingDef b) {
    final first = kRooms.indexWhere((r) => r.building == b.letter);
    if (!_g.isUnlocked(first)) {
      final prev = kBuildings[kBuildings.indexOf(b) - 1];
      setState(() => _lockedHint = '🔒 Finish ${prev.title} to climb to ${b.title}');
      return;
    }
    // Jump to the furthest unlocked room on that floor.
    var target = first;
    for (var i = first; i < kRooms.length && kRooms[i].building == b.letter; i++) {
      if (_g.isUnlocked(i)) target = i;
    }
    _select(target);
  }

  void _selectHero(int i) {
    GameAudio.instance.play('click');
    final h = kHeroes[i];
    if (!_g.isHeroUnlocked(i)) {
      setState(() => _lockedHint = h.unlockFloor >= kFloors.length
          ? '🔒 Wake up (beat the Grade Reaper) to unlock the ${h.name}'
          : '🔒 Beat ${h.unlockFloor} bosses to unlock the ${h.name} (${_g.bossesCleared}/${h.unlockFloor})');
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

  @override
  Widget build(BuildContext context) {
    // Rebuilds when a room is picked and once saved progress has loaded.
    return ValueListenableBuilder<int>(
      valueListenable: _g.menuFloor,
      builder: (context, _, __) => _layout(),
    );
  }

  Widget _layout() {
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxHeight < 360;
      final leftW = min(340.0, box.maxWidth * 0.43), rightW = min(262.0, box.maxWidth * 0.32);
      return Stack(children: [
        // Hard-edged shade behind the two columns; the live room shows in the middle.
        Positioned(left: 0, top: 0, bottom: 0, width: leftW + 34, child: Container(color: kInk.withValues(alpha: 0.72))),
        Positioned(right: 0, top: 0, bottom: 0, width: rightW + 24, child: Container(color: kInk.withValues(alpha: 0.6))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: leftW, child: _leftPanel(compact)),
                const Spacer(),
                SizedBox(width: rightW, child: _campus(compact)),
              ],
            ),
          ),
        ),
      ]);
    });
  }

  // ── Left: title, characters, selected room, play ─────────────────────────
  Widget _leftPanel(bool compact) {
    _scrollToHero();
    final r = kRooms[_selected];
    final d = r.def;
    final cleared = _g.isCleared(_selected) || _graduated;
    final roomsDone = _graduated ? kRooms.length : _g.bestFloor;
    final shown = compact ? 3 : 4;
    final chips = switch (r.kind) {
      RoomKind.boss => [for (final a in d.allAbilities) d.abilityName(a)],
      RoomKind.hall => {
          for (final w in r.waves)
            for (final m in w) '${kMinions[m]!.emoji} ${kMinions[m]!.name}'
        }.toList(),
      RoomKind.rest => ['👻 Mira', '❤️ Full heal', if (r.gift) '📄 Her Lost Note'],
    };
    final subtitle = switch (r.kind) {
      RoomKind.boss => '${d.course}  ·  ${d.rounds} ${d.rounds == 2 ? 'rounds' : 'phases'}',
      RoomKind.hall => 'Monster hall  ·  ${r.waves.length} waves',
      RoomKind.rest => "Mira's corner  ·  full heal",
    };
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
                  Row(children: [
                    const PixelIcon('clock', size: 16),
                    const SizedBox(width: 6),
                    Text('THE SAGA OF THE LAST NIGHT', style: pixelStyle(8, Colors.white60, spacing: 1)),
                  ]),
                  const SizedBox(height: 6),
                  // The title blinks between two colours in hard steps, like an arcade marquee.
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('EXAM ESCAPE',
                          style: pixelStyle(compact ? 26 : 32, _pulse.value > 0.5 ? _cyan : Colors.white, spacing: 1)
                              .copyWith(shadows: [
                            Shadow(color: const Color(0xFFFF1744), offset: Offset(compact ? 3 : 4, compact ? 3 : 4)),
                            Shadow(color: kInk, offset: Offset(compact ? 6 : 8, compact ? 6 : 8)),
                          ])),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _statPill('scroll', '$roomsDone/${kRooms.length} rooms'),
                    _statPill('skull', '${_g.bossesCleared}/${kFloors.length} bosses'),
                    if (_graduated)
                      _statPill('sun', _g.bestTime != null ? 'best ${_fmtTime(_g.bestTime!)}' : 'woke up'),
                  ]),
                  SizedBox(height: compact ? 6 : 10),

                  // Character picker (scrolls sideways: more characters than fit)
                  SizedBox(
                    height: 40,
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
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(16, Colors.white54, shadow: false)),
                  ],
                  SizedBox(height: compact ? 6 : 8),

                  // Selected room card
                  PixelPanel(
                    color: _panel,
                    accent: d.accent,
                    px: 2,
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text('${r.buildingDef.title.toUpperCase()} · ${clockText(r.minutes)} · ${r.label}',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: pixelStyle(7, d.accent)),
                          ),
                          if (cleared) ...[
                            const PixelIcon('ui_check', size: 9),
                            const SizedBox(width: 4),
                            Text('CLEARED', style: pixelStyle(7, const Color(0xFF00E676))),
                          ],
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          PText(r.emoji, style: pixelStyle(compact ? 20 : 24, Colors.white)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              PText(r.isBoss ? d.name : r.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: pixelStyle(12, Colors.white)),
                              const SizedBox(height: 2),
                              Text(subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: bodyStyle(15, Colors.white54, shadow: false)),
                            ]),
                          ),
                        ]),
                        if (!compact) const SizedBox(height: 6),
                        if (!compact)
                          Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            for (final c in chips.take(shown))
                              Container(
                                padding: const EdgeInsets.fromLTRB(5, 3, 5, 2),
                                color: Color.lerp(_panel, d.accent, 0.18),
                                child: PText(c, style: pixelStyle(7, Colors.white, shadow: false)),
                              ),
                            if (chips.length > shown)
                              Text('+${chips.length - shown} more', style: pixelStyle(7, Colors.white38, shadow: false)),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 6 : 10),
        _BigButton(
          label: _selected == 0 ? 'START  ▶' : 'PLAY ${r.label}  ▶',
          color: d.accent,
          small: true,
          wide: true,
          onTap: () => _g.startRun(fromFloor: _selected),
        ),
        const SizedBox(height: 6),
        Text(
          _lockedHint ??
              (_selected == 0
                  ? 'Six floors. Six hours. Wake up before 9:00 AM.'
                  : 'Best time only counts when you start from 1-1'),
          key: ValueKey(_lockedHint ?? 'room$_selected'),
          maxLines: 2,
          style: bodyStyle(16, _lockedHint != null ? const Color(0xFFFF8A80) : Colors.white38, shadow: false),
        ),
      ],
    );
  }

  Widget _statPill(String icon, String text) => Container(
        padding: const EdgeInsets.fromLTRB(5, 3, 7, 3),
        color: Colors.white.withValues(alpha: 0.08),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PixelIcon(icon, size: 13),
          const SizedBox(width: 5),
          Text(text, style: pixelStyle(8, _gold)),
        ]),
      );

  // ── Right: the map — floor tabs and that floor's rooms ──────────────────
  Widget _campus(bool compact) {
    final shown = _tab ?? kRooms[_selected].building;
    final b = kBuildings.firstWhere((x) => x.letter == shown);
    final ids = [
      for (var i = 0; i < kRooms.length; i++)
        if (kRooms[i].building == shown) i
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const PixelIcon('scroll', size: 14),
            const SizedBox(width: 6),
            Text('NIGHTMARE UNIVERSITY', style: pixelStyle(8, Colors.white70, spacing: 1)),
          ]),
        ),
        // Floor tabs, bottom to top
        Row(children: [
          for (var k = 0; k < kBuildings.length; k++)
            Expanded(
              child: _BuildingTab(
                b: kBuildings[k],
                selected: kBuildings[k].letter == shown,
                unlocked: _g.isUnlocked(kRooms.indexWhere((r) => r.building == kBuildings[k].letter)),
                done: _buildingDone(kBuildings[k]),
                onTap: () => _selectBuilding(kBuildings[k]),
              ),
            ),
        ]),
        SizedBox(height: compact ? 6 : 8),
        PText('${b.emoji} ${b.time} · ${b.name.toUpperCase()}',
            textAlign: TextAlign.center, maxLines: 1, style: pixelStyle(7, b.color)),
        SizedBox(height: compact ? 4 : 6),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final rowH = ((box.maxHeight - (ids.length - 1) * 4) / ids.length).clamp(30.0, 46.0);
            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: ids.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, j) {
                final i = ids[j];
                return _RoomRow(
                  room: kRooms[i],
                  height: rowH,
                  unlocked: _g.isUnlocked(i),
                  cleared: _g.isCleared(i) || _graduated,
                  isNew: i == _g.bestFloor && !_graduated && i > 0,
                  selected: i == _selected,
                  onTap: () => _select(i),
                );
              },
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Art: Ozzbit · Craftpix · BlackSkull-k · 0-mem0ry',
              textAlign: TextAlign.center, maxLines: 1, style: bodyStyle(13, Colors.white24, shadow: false)),
        ),
      ],
    );
  }

  bool _buildingDone(BuildingDef b) {
    final last = kRooms.lastIndexWhere((r) => r.building == b.letter);
    return _g.isCleared(last) || _graduated;
  }
}

class _BuildingTab extends StatelessWidget {
  final BuildingDef b;
  final bool selected, unlocked, done;
  final VoidCallback onTap;
  const _BuildingTab(
      {required this.b, required this.selected, required this.unlocked, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: selected ? Color.lerp(_panel, b.color, 0.3) : _panel,
            border: Border.all(color: selected ? b.color : (unlocked ? b.color.withValues(alpha: 0.4) : kInk), width: 2),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            unlocked
                ? Text(b.letter, style: pixelStyle(13, b.color, height: 1))
                : const PixelIcon('lock', size: 14),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(done ? 'DONE' : '${b.hour} AM',
                  maxLines: 1,
                  style: pixelStyle(6, done ? const Color(0xFF00E676) : Colors.white38, shadow: false, height: 1)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  final RoomDef room;
  final double height;
  final bool unlocked, cleared, isNew, selected;
  final VoidCallback onTap;

  const _RoomRow({
    required this.room,
    required this.height,
    required this.unlocked,
    required this.cleared,
    required this.isNew,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final def = room.def;
    final tall = height >= 38;
    final kindColor = switch (room.kind) {
      RoomKind.boss => def.accent,
      RoomKind.hall => const Color(0xFFFF8A65),
      RoomKind.rest => const Color(0xFF69F0AE),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: unlocked ? Color.lerp(def.wall, kInk, selected ? 0 : 0.35) : const Color(0xFF12161E),
          border: Border.all(
            color: selected ? def.accent : (unlocked ? def.accent.withValues(alpha: 0.3) : kInk),
            width: selected ? 3 : 2,
          ),
        ),
        child: Row(children: [
          // room label plate
          Container(
            width: 30,
            height: 20,
            alignment: Alignment.center,
            color: unlocked ? kindColor : Colors.white12,
            child: Text(room.label, style: pixelStyle(7, unlocked ? kInk : Colors.white38, shadow: false, height: 1)),
          ),
          const SizedBox(width: 6),
          unlocked ? PText(room.emoji, style: pixelStyle(tall ? 14 : 11, Colors.white)) : const PixelIcon('lock', size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unlocked ? (room.isBoss ? def.subject : room.name.toUpperCase()) : 'LOCKED',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pixelStyle(7, unlocked ? Colors.white : Colors.white30, height: 1.2)),
                if (tall)
                  Text(unlocked ? room.subtitle : '???',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyStyle(14, Colors.white54, shadow: false)),
              ],
            ),
          ),
          if (cleared)
            const PixelIcon('ui_check', size: 10)
          else if (isNew)
            Container(
              padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
              color: _gold,
              child: Text('NEW', style: pixelStyle(6, kInk, shadow: false, height: 1)),
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
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: selected ? Color.lerp(_panel, hero.color, 0.25) : _panel,
          border: Border.all(color: selected ? hero.color : (unlocked ? Colors.white24 : kInk), width: selected ? 3 : 2),
        ),
        child: Row(children: [
          unlocked ? PText(hero.emoji, style: pixelStyle(11, Colors.white)) : const PixelIcon('lock', size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(hero.name.toUpperCase(),
                      maxLines: 1, style: pixelStyle(7, unlocked ? Colors.white : Colors.white38, height: 1.2)),
                ),
                Text(
                    unlocked
                        ? '${hero.hp} HP'
                        : hero.unlockFloor >= kFloors.length
                            ? 'Wake up'
                            : 'Beat ${hero.unlockFloor} bosses',
                    maxLines: 1,
                    style: bodyStyle(13, unlocked ? hero.color : Colors.white30, shadow: false)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
