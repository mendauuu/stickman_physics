"""Generates every sound effect and music loop for Class Clash.

All audio is synthesised here (retro chiptune style), so it is 100% original
and free of licensing questions. Re-run after editing to regenerate:

    python tools/make_audio.py

Writes 22.05 kHz mono 16-bit WAV files into assets/audio/.
"""

import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
rng = np.random.default_rng(1234)


# ── building blocks ────────────────────────────────────────────────────────
def secs(d):
    return np.arange(int(SR * d)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def phase_of(freq, n):
    """Phase (in cycles) for a constant or per-sample frequency."""
    f = np.full(n, freq, dtype=float) if np.isscalar(freq) else np.asarray(freq, dtype=float)
    return np.cumsum(f) / SR


def square(freq, d, duty=0.5):
    n = int(SR * d)
    return np.where(phase_of(freq, n) % 1 < duty, 1.0, -1.0)


def tri(freq, d):
    n = int(SR * d)
    p = phase_of(freq, n) % 1
    return 4 * np.abs(p - 0.5) - 1


def sine(freq, d):
    n = int(SR * d)
    return np.sin(2 * np.pi * phase_of(freq, n))


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def sweep(f0, f1, d, curve=1.0):
    x = np.linspace(0, 1, int(SR * d)) ** curve
    return f0 + (f1 - f0) * x


def env(n, attack=0.004, release=0.03, decay_pow=None):
    """Attack/release envelope, optionally with a power-law decay."""
    e = np.ones(n)
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    e[:a] = np.linspace(0, 1, a)
    if decay_pow is not None:
        e *= np.linspace(1, 0, n) ** decay_pow
    e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x, k=6):
    return np.convolve(x, np.ones(k) / k, mode='same')


def highpass(x, k=6):
    return x - lowpass(x, k)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(*parts, gap=0.0):
    """Concatenate sounds, each starting right after the previous one."""
    g = np.zeros(int(SR * gap))
    out = []
    for p in parts:
        out += [p, g]
    return np.concatenate(out)


def save(name, x, peak=0.85):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) or 1
    data = (x / m * peak * 32767).astype('<i2')
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ── sound effects ──────────────────────────────────────────────────────────
def tone(freq, d, kind=square, **kw):
    s = kind(freq, d, **kw) if kind is square else kind(freq, d)
    return s * env(len(s), decay_pow=1.5)


def make_sfx():
    # Sword swish: filtered noise with a falling "whoosh"
    n = noise(0.16)
    save('swing', lowpass(n, 4) * env(len(n), 0.01, 0.05, 2) + 0.15 * tone(sweep(900, 300, 0.16), 0.16, sine))
    # Hit: punchy square drop + crunch
    d = 0.12
    save('hit', mix(tone(sweep(220, 60, d), d) * 0.8, lowpass(noise(d), 3) * env(int(SR * d), 0.001, 0.02, 3)))
    # Heavy hit: deeper boom + long crunch
    d = 0.35
    save('hit_heavy', mix(tone(sweep(160, 35, d, 0.6), d, sine), 0.6 * tone(sweep(120, 40, d), d),
                          lowpass(noise(d), 8) * env(int(SR * d), 0.001, 0.05, 2)))
    # Hurt: descending buzzy blip
    save('hurt', tone(sweep(520, 140, 0.25), 0.25, duty=0.25))
    # Jump: quick rising chirp
    save('jump', tone(sweep(280, 760, 0.12, 0.7), 0.12, duty=0.25) * 0.8)
    # Roll: soft airy swoosh
    n = noise(0.22)
    save('roll', lowpass(n, 10) * env(len(n), 0.05, 0.08), peak=0.6)
    # Power: rising arpeggio with sparkle
    arp = seq(*[tone(midi(m), 0.07, duty=0.25) for m in (60, 64, 67, 72, 76, 79, 84)])
    sparkle = highpass(noise(len(arp) / SR), 2) * np.linspace(0, 1, len(arp)) * 0.15
    save('power', arp + sparkle)
    # Magic bolt (Mage): bright zap
    save('magic', tone(sweep(1400, 500, 0.14), 0.14, sine) + 0.4 * tone(sweep(2000, 900, 0.14), 0.14, duty=0.12))
    # Pickup: classic two-tone coin
    save('pickup', seq(tone(midi(83), 0.06, duty=0.25), tone(midi(88), 0.16, duty=0.25)))
    # Shield block: metallic clink (inharmonic sines)
    d = 0.18
    save('block', sum(tone(f, d, sine) * a for f, a in ((1800, 1), (2710, 0.6), (4100, 0.35))))
    # Monster poof
    d = 0.32
    save('poof', mix(lowpass(noise(d), 12) * env(int(SR * d), 0.005, 0.05, 1.5), 0.5 * tone(sweep(300, 70, d), d, tri)))
    # Teacher casting a big spell: shimmering rise
    d = 0.3
    save('cast', tone(sweep(400, 1200, d), d, sine) * 0.6 + 0.3 * tone(sweep(600, 1800, d), d, duty=0.125))
    # Shockwave / earthquake rumble
    d = 0.5
    save('quake', mix(lowpass(noise(d), 30) * env(int(SR * d), 0.01, 0.1, 1.2) * 1.5, tone(sweep(70, 40, d), d, sine)))
    # Perfect dodge: high "ting"
    save('perfect', seq(tone(midi(91), 0.05, sine), tone(midi(96), 0.25, sine)))
    # Perk chosen: magical chime
    save('perk', seq(*[tone(midi(m), 0.09, tri) for m in (72, 76, 79, 84)], tone(midi(88), 0.35, tri)))
    # Wave incoming: two-tone alarm
    save('wave', seq(*[tone(f, 0.11, duty=0.5) for f in (880, 660, 880, 660)]) * 0.7)
    # UI click
    save('click', tone(1200, 0.035, duty=0.5) * 0.6, peak=0.5)
    # Door / next room whoosh
    n = noise(0.45)
    save('door', lowpass(n, 18) * env(len(n), 0.12, 0.15) + 0.3 * tone(sweep(200, 500, 0.45), 0.45, tri))
    # Jingles
    save('midterm', seq(*[tone(midi(m), 0.11, duty=0.25) for m in (72, 76, 79)], tone(midi(84), 0.45, duty=0.25)))
    save('victory', seq(*[tone(midi(m), 0.1, duty=0.25) for m in (67, 72, 76, 79, 76, 79)], tone(midi(84), 0.7, duty=0.25)))
    grad = [(72, .15), (72, .15), (72, .15), (76, .45), (74, .15), (76, .15), (79, .3), (84, .9)]
    melody = seq(*[tone(midi(m), d, duty=0.25) for m, d in grad])
    bass = seq(*[tone(midi(m - 24), d, tri) for m, d in grad])
    save('graduate', mix(melody, bass * 0.6))
    save('gameover', seq(*[tone(midi(m), d, tri) for m, d in ((67, .25), (66, .25), (65, .25), (64, .9))]))

    # ── villain / horror ──
    # Demonic laugh: falling, growly "HA-ha-ha-ha" pulses
    has = []
    for k in range(6):
        d = 0.13
        f0 = 210 - k * 18
        growl = square(sweep(f0, f0 * 0.8, d), d, 0.3) * 0.6 + lowpass(noise(d), 3) * 0.4
        has.append(lowpass(growl, 3) * env(int(SR * d), 0.01, 0.04, 0.8) * (1 - k * 0.1))
    save('laugh', seq(*has, gap=0.04))
    # Thunder: sharp crack, then a long rolling rumble
    crack = highpass(noise(0.08), 2) * env(int(SR * 0.08), 0.001, 0.03, 2)
    rumble = lowpass(noise(2.2), 60) * env(int(SR * 2.2), 0.05, 0.6, 1.4) * 4
    save('thunder', mix(crack, np.concatenate([np.zeros(int(SR * 0.05)), rumble])))
    # Heartbeat: lub-dub
    def thump(v):
        d = 0.14
        return sine(sweep(70, 38, d), d) * env(int(SR * d), 0.003, 0.04, 1.6) * v
    save('heartbeat', seq(thump(1.0), thump(0.7), gap=0.12))


# ── music ──────────────────────────────────────────────────────────────────
HOLD = -1  # extend the previous note
REST = 0


def render_track(name, bpm, chords, lead, *, drums='rock', arp=True, lead_duty=0.25,
                 lead_vol=0.22, bass_style='eighths', double_second_half=True, peak=0.8, drone=False):
    """chords: list of (bass midi, [chord tones]) per bar; lead: 8 eighth-notes per bar."""
    beat = 60 / bpm
    eighth = beat / 2
    bars = len(chords)
    total = int(SR * beat * 4 * bars)
    out = np.zeros(total)

    def put(start_s, x):
        i = int(start_s * SR)
        idx = (np.arange(len(x)) + i) % total  # wrap tails so the loop is seamless
        np.add.at(out, idx, x)

    # Lead (8 eighths per bar)
    notes = []
    for bar, row in enumerate(lead):
        for k, m in enumerate(row):
            t0 = (bar * 8 + k) * eighth
            if m == HOLD and notes:
                notes[-1][2] += eighth
            elif m != REST:
                notes.append([t0, m, eighth])
    for t0, m, d in notes:
        s = square(midi(m), d * 0.95, lead_duty) * env(int(SR * d * 0.95), 0.004, 0.03)
        # gentle vibrato on long notes
        put(t0, s * lead_vol)
        if double_second_half and t0 >= total / SR / 2:
            put(t0, square(midi(m - 12), d * 0.95, 0.5) * env(int(SR * d * 0.95), 0.004, 0.03) * lead_vol * 0.35)

    # Bass + arpeggio
    for bar, (root, tones) in enumerate(chords):
        t_bar = bar * 4 * beat
        if bass_style == 'eighths':
            for k in range(8):
                m = root if k % 2 == 0 else root + 12
                s = tri(midi(m), eighth * 0.9) * env(int(SR * eighth * 0.9), 0.003, 0.02)
                put(t_bar + k * eighth, s * 0.32)
        elif bass_style == 'sixteenths':
            for k in range(16):
                m = root + (12 if k % 4 == 2 else 0)
                d = eighth / 2
                s = square(midi(m), d * 0.85, 0.5) * env(int(SR * d * 0.85), 0.002, 0.015)
                put(t_bar + k * d, lowpass(s, 4) * 0.2)
        else:  # whole-ish notes
            for k in range(2):
                s = tri(midi(root), beat * 2 * 0.95) * env(int(SR * beat * 2 * 0.95), 0.02, 0.2)
                put(t_bar + k * 2 * beat, s * 0.3)
        if arp:
            step = eighth / 2
            for k in range(16):
                m = tones[k % len(tones)] + 12
                s = square(midi(m), step * 0.8, 0.125) * env(int(SR * step * 0.8), 0.002, 0.02)
                put(t_bar + k * step, s * 0.05)

    # Drone: a dark, slowly swelling tritone pad under every bar
    if drone:
        for bar, (root, _) in enumerate(chords):
            d = beat * 4
            n = int(SR * d)
            swell = np.sin(np.linspace(0, np.pi, n)) ** 0.7
            pad = tri(midi(root + 12), d) + tri(midi(root + 18) * 1.004, d) * 0.6 + tri(midi(root) * 0.997, d) * 0.8
            put(bar * d, lowpass(pad, 6) * swell * 0.09)

    # Drums
    def kick():
        d = 0.16
        return sine(sweep(140, 40, d, 0.5), d) * env(int(SR * d), 0.001, 0.03, 1.5) * 0.55

    def snare():
        d = 0.14
        return (highpass(noise(d), 3) * 0.6 + tri(190, d) * 0.3) * env(int(SR * d), 0.001, 0.03, 2) * 0.35

    def hat(v=0.12):
        d = 0.04
        return highpass(noise(d), 2) * env(int(SR * d), 0.001, 0.01, 2) * v

    for bar in range(bars):
        t_bar = bar * 4 * beat
        if drums == 'rock':
            for b in (0, 2):
                put(t_bar + b * beat, kick())
            put(t_bar + 2.5 * beat, kick() * 0.7)
            for b in (1, 3):
                put(t_bar + b * beat, snare())
            for k in range(8):
                put(t_bar + k * eighth, hat(0.1 if k % 2 else 0.14))
        elif drums == 'fast':
            for b in range(4):
                put(t_bar + b * beat, kick())
            for b in (1, 3):
                put(t_bar + b * beat, snare())
            for k in range(16):
                put(t_bar + k * eighth / 2, hat(0.07 if k % 2 else 0.11))
        elif drums == 'soft':
            for k in range(4):
                put(t_bar + k * beat + eighth, hat(0.06))
        elif drums == 'heartbeat':
            for b in (0, 2):
                put(t_bar + b * beat, kick() * 0.9)
                put(t_bar + b * beat + beat * 0.3, kick() * 0.6)
        elif drums == 'march':
            put(t_bar, kick())
            put(t_bar + 2 * beat, kick())
            put(t_bar + 3.5 * beat, snare() * 0.6)
            for k in range(4):
                put(t_bar + k * beat + eighth, hat(0.08))

    save(name, out, peak=peak)
    return total / SR


H = HOLD


def make_music():
    Am, F, C, G = (45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])
    menu_lead = [
        [76, H, 74, 72, 74, H, 69, H], [72, H, 74, 76, 77, H, 76, 74],
        [72, H, 67, H, 72, 74, 76, H], [74, H, 71, H, 67, H, H, REST],
        [76, H, 79, H, 81, H, 79, 76], [77, H, 76, 74, 72, H, 74, H],
        [76, H, 74, 72, 71, H, 72, 74], [71, H, 67, 71, 69, H, H, REST],
    ]
    render_track('menu', 100, [Am, F, C, G] * 2 * 2, menu_lead * 2, drums='march')

    Em, D = (40, [52, 55, 59]), (38, [50, 54, 57])
    explore_lead = [
        [76, H, 71, H, 74, 76, H, 71], [72, H, 67, H, 72, 74, 76, H],
        [74, H, 71, 67, H, 71, 74, H], [74, 76, 78, H, 76, 74, H, REST],
        [79, H, 76, H, 71, H, 76, 79], [81, H, 79, 76, H, 72, H, 76],
        [74, H, 79, H, 78, H, 74, 71], [74, H, H, H, 78, H, 76, REST],
    ]
    render_track('explore', 128, [Em, C, G, D] * 2 * 2, explore_lead * 2, drums='rock')

    Dm, Bb, A = (38, [50, 53, 57]), (34, [46, 50, 53]), (33, [45, 49, 52])
    boss_lead = [
        [74, H, 77, H, 81, H, 77, 74], [82, H, 81, H, 77, H, 74, H],
        [79, H, 76, H, 72, H, 76, 79], [81, H, 80, H, 81, H, H, REST],
        [86, H, 84, H, 81, H, 77, H], [82, H, 81, 79, 77, H, 74, H],
        [76, H, 79, H, 84, H, 79, 76], [73, H, 76, H, 81, H, 80, REST],
    ]
    render_track('boss', 140, [Dm, Bb, C, A] * 2 * 2, boss_lead * 2, drums='fast',
                 bass_style='sixteenths', lead_duty=0.5, lead_vol=0.18)

    Fm = (41, [53, 57, 60])
    final_lead = [
        [76, H, 77, H, 76, H, 71, H], [77, H, 81, H, 77, H, 72, H],
        [79, H, 83, H, 86, H, 83, 79], [81, H, 77, H, 76, H, 77, H],
        [88, H, H, 86, 84, H, 83, H], [81, H, 84, H, 81, H, 77, H],
        [79, H, 77, H, 76, H, 74, H], [77, H, 76, H, H, H, REST, REST],
    ]
    render_track('final', 152, [Em, Fm, G, Fm] * 2 * 2, final_lead * 2, drums='fast',
                 bass_style='sixteenths', lead_duty=0.5, lead_vol=0.18)

    Cmaj, Am7, Dm7, G7 = (36, [52, 55, 59, 64]), (45, [55, 60, 64, 67]), (38, [53, 57, 60, 65]), (43, [53, 55, 59, 62])
    rest_lead = [
        [76, H, H, 79, H, H, 76, 74], [72, H, H, H, 69, H, 72, H],
        [74, H, 77, H, 81, H, 77, H], [79, H, H, 77, 76, H, 74, H],
        [76, H, 79, H, 84, H, 83, 79], [81, H, H, 79, 76, H, H, REST],
        [77, H, 76, 74, 72, H, 74, H], [71, H, 74, H, 79, H, H, REST],
    ]
    render_track('rest', 88, [Cmaj, Am7, Dm7, G7] * 2, rest_lead, drums='soft', bass_style='long',
                 lead_duty=0.5, lead_vol=0.14, double_second_half=False, peak=0.5)

    # The Grade Reaper: slow, dissonant, heartbeat drums and a creeping drone
    Cdim, Gb, Cs, B = (36, [48, 51, 54]), (42, [54, 57, 60]), (37, [49, 52, 55]), (35, [47, 50, 53])
    demon_lead = [
        [84, H, H, 83, H, H, 82, H], [81, H, H, H, REST, REST, 78, H],
        [84, H, 85, H, 84, H, 81, H], [79, H, H, H, H, H, REST, REST],
        [90, H, H, 89, H, 88, H, H], [87, H, H, H, 84, H, 81, H],
        [84, H, 81, H, 78, H, 75, H], [72, H, H, H, H, H, REST, REST],
    ]
    render_track('demon', 76, [Cdim, Gb, Cs, B] * 2, demon_lead, drums='heartbeat', bass_style='long',
                 lead_duty=0.125, lead_vol=0.12, peak=0.75, drone=True)


if __name__ == '__main__':
    make_sfx()
    make_music()
    files = sorted(os.listdir(OUT))
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in files)
    print(f'{len(files)} files, {total / 1e6:.1f} MB in {os.path.abspath(OUT)}')
