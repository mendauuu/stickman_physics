part of 'main.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MIRA'S CORNER — a quiet room between fights: full heal, a few words from
// Mira, and the Lost Notes found so far. At the final staircase she hands
// over her own note.
// ═══════════════════════════════════════════════════════════════════════════
class _RestOverlay extends StatelessWidget {
  final SchoolGame game;
  const _RestOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    final g = game, r = g.room, d = r.def;
    final gift = kPerks[kLostNotes.last]!;
    return Container(
      color: kInk.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: PixelPanel(
                color: _panel,
                accent: d.accent,
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  PText('ROOM ${r.label}  ·  🕒 ${clockText(r.minutes)}  ·  ${timeLeftText(r.minutes).toUpperCase()}',
                      style: pixelStyle(8, d.accent)),
                  const SizedBox(height: 6),
                  PText('${d.emoji}  ${r.name.toUpperCase()}', style: pixelStyle(16, Colors.white, spacing: 1)),
                  const SizedBox(height: 4),
                  PText('👻 Mira watches over you. ❤️ HP fully restored.',
                      style: bodyStyle(18, const Color(0xFF69F0AE))),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const PixelIcon('ghost', size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: kInk.withValues(alpha: 0.6),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: 'MIRA  ', style: pixelStyle(9, const Color(0xFFB2EBF2))),
                          TextSpan(
                              text: '“${pixelSafe(d.intro)}”',
                              style: bodyStyle(20, const Color(0xFFB2EBF2), height: 1.05)),
                        ])),
                      ),
                    ),
                  ]),
                  if (r.gift) ...[
                    const SizedBox(height: 8),
                    PText('📄 Mira gave you her Lost Note: ${gift.emoji} ${gift.name.toUpperCase()} · ${gift.desc}',
                        textAlign: TextAlign.center, style: pixelStyle(9, _gold)),
                  ],
                  const SizedBox(height: 10),
                  Text('LOST NOTES  ${g.notesFound}/${kLostNotes.length}', style: pixelStyle(8, Colors.white60, spacing: 1)),
                  const SizedBox(height: 6),
                  Row(children: [
                    for (var i = 0; i < kLostNotes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Expanded(
                          child: _NoteCard(perk: kLostNotes[i], found: g.perks.contains(kLostNotes[i]), accent: d.accent)),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  _BigButton(label: 'CONTINUE ▶', color: d.accent, onTap: g.leaveRest, small: true),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Perk perk;
  final bool found;
  final Color accent;
  const _NoteCard({required this.perk, required this.found, required this.accent});

  @override
  Widget build(BuildContext context) {
    final p = kPerks[perk]!;
    return PixelPanel(
      color: found ? const Color(0xFF243044) : const Color(0xFF12161E),
      accent: found ? accent : const Color(0xFF2A3040),
      px: 2,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
      child: Column(children: [
        found ? PText(p.emoji, style: pixelStyle(16, Colors.white)) : const PixelIcon('lock', size: 22),
        const SizedBox(height: 4),
        SizedBox(
          height: 18,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(found ? p.name.toUpperCase() : '???',
                textAlign: TextAlign.center, maxLines: 2, style: pixelStyle(6, found ? Colors.white : Colors.white30)),
          ),
        ),
        if (found)
          Text(p.desc,
              textAlign: TextAlign.center, maxLines: 2, style: bodyStyle(13, accent, shadow: false, height: 0.95)),
      ]),
    );
  }
}
