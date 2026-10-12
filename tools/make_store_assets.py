"""Builds the Google Play store graphics for Class Clash.

Run from the project root:  python tools/make_store_assets.py
Writes everything into store/.

All lettering is drawn at low resolution without anti-aliasing and then scaled
up with nearest-neighbour, so it matches the game's pixel art.
"""
import glob
import os

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'store')
A = os.path.join(ROOT, 'assets')
NATURE = os.path.join(A, 'Nature Landscapes Free Pixel Art')
FONT = 'C:/Windows/Fonts/impact.ttf'
FONT_SMALL = 'C:/Windows/Fonts/arialbd.ttf'

CYAN = [(0xB8, 0xFF, 0xFF), (0x4D, 0xF0, 0xFF), (0x18, 0xB4, 0xE8)]
GOLD = [(0xFF, 0xF4, 0xB0), (0xFF, 0xD5, 0x4F), (0xFF, 0x9E, 0x2C)]
INK = (0x10, 0x14, 0x2A)


# ── Pixel lettering ─────────────────────────────────────────────────────────
def pixel_text(text, px, bands, scale, font=FONT, outline=INK, shadow=(0, 0, 0, 150), spacing=1):
    """Text rendered at [px] pixels tall, banded colour fill, 1px highlight,
    dark outline and drop shadow, then blown up [scale] times."""
    f = ImageFont.truetype(font, px)
    # measure each glyph so we can control letter spacing
    widths = [f.getbbox(ch)[2] - f.getbbox(ch)[0] if ch != ' ' else px // 3 for ch in text]
    w = sum(widths) + spacing * (len(text) - 1) + 8
    h = px * 2
    mask = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.fontmode = '1'
    x = 4
    for ch, cw in zip(text, widths):
        if ch != ' ':
            d.text((x - f.getbbox(ch)[0], 2), ch, font=f, fill=255)
        x += cw + spacing
    bbox = mask.getbbox()
    mask = mask.crop((bbox[0] - 3, bbox[1] - 3, bbox[2] + 4, bbox[3] + 5))
    w, h = mask.size

    # banded vertical fill
    top, bottom = bbox[1], bbox[3]
    fill = Image.new('RGBA', (w, h))
    fp = fill.load()
    glyph_h = mask.getbbox()[3] - mask.getbbox()[1]
    y0 = mask.getbbox()[1]
    for y in range(h):
        k = (y - y0) / max(1, glyph_h)
        c = bands[0] if k < 0.38 else bands[1] if k < 0.7 else bands[2]
        for xx in range(w):
            fp[xx, y] = c + (255,)
    # highlight: top edge of every stroke
    below = ImageChops.offset(mask, 0, 1)
    edge = ImageChops.subtract(mask, below)
    hl = Image.new('RGBA', (w, h), (255, 255, 255, 255))

    outl = mask.filter(ImageFilter.MaxFilter(3))
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    sh = Image.new('RGBA', (w, h), shadow)
    img.paste(sh, (0, 0), ImageChops.offset(outl, 1, 2))
    img.paste(Image.new('RGBA', (w, h), outline + (255,)), (0, 0), outl)
    img.paste(fill, (0, 0), mask)
    img.paste(hl, (0, 0), edge)
    return img.resize((w * scale, h * scale), Image.NEAREST)


def logo(scale=8):
    """CLASS / CLASH stacked, with a sword-slash underline."""
    top = pixel_text('CLASS', 22, CYAN, scale)
    bottom = pixel_text('CLASH', 22, GOLD, scale)
    tag = pixel_text('CAMPUS BRAWLER', 11, [(255, 255, 255), (235, 240, 255), (200, 212, 240)], scale, spacing=2)
    w = max(top.width, bottom.width, tag.width)
    gap = -3 * scale
    h = top.height + bottom.height + tag.height + gap
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    img.alpha_composite(top, ((w - top.width) // 2, 0))
    img.alpha_composite(bottom, ((w - bottom.width) // 2, top.height + gap))
    img.alpha_composite(tag, ((w - tag.width) // 2, top.height + bottom.height + gap - scale))
    return img


def logo_wide(scale=6):
    """One-line logo for wide banners."""
    t = pixel_text('CLASS', 22, CYAN, scale)
    c = pixel_text('CLASH', 22, GOLD, scale)
    tag = pixel_text('CAMPUS BRAWLER', 11, [(255, 255, 255), (235, 240, 255), (200, 212, 240)], scale, spacing=2)
    gap = 2 * scale
    w = t.width + gap + c.width
    h = t.height + tag.height - scale * 2
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    img.alpha_composite(t, (0, 0))
    img.alpha_composite(c, (t.width + gap, 0))
    img.alpha_composite(tag, ((w - tag.width) // 2, t.height - scale * 2))
    return img


# ── Sprites and scenery ─────────────────────────────────────────────────────
def frame(path, fw, fh, i, flip=False):
    sheet = Image.open(path).convert('RGBA')
    f = sheet.crop((i * fw, 0, (i + 1) * fw, fh))
    f = f.crop(f.getbbox())
    return f.transpose(Image.FLIP_LEFT_RIGHT) if flip else f


def big(img, scale):
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def scene(n, w, h, anchor_y=0.8):
    """Landscape cover-cropped to w×h (pixel crisp), ground kept in view."""
    img = Image.open(os.path.join(NATURE, f'nature_{n}', 'orig.png')).convert('RGBA')
    s = max(w / img.width, h / img.height)
    s = max(1, round(s + 0.49)) if s > 1 else s
    img = img.resize((round(img.width * s), round(img.height * s)), Image.NEAREST)
    x = (img.width - w) // 2
    y = int((img.height - h) * anchor_y)
    return img.crop((x, y, x + w, y + h))


def vignette(img, strength=0.55):
    w, h = img.size
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).ellipse((-w * 0.25, -h * 0.35, w * 1.25, h * 1.35), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(min(w, h) // 5))
    dark = Image.new('RGBA', (w, h), (6, 8, 20, int(255 * strength)))
    out = img.copy()
    out.alpha_composite(Image.composite(Image.new('RGBA', (w, h), (0, 0, 0, 0)), dark, m))
    return out


def glow(sprite, color, radius):
    a = sprite.getchannel('A').filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(radius))
    g = Image.new('RGBA', sprite.size, color)
    g.putalpha(a.point(lambda v: int(v * 0.85)))
    return g


def paste_glow(base, sprite, xy, color, radius=14):
    pad = radius * 3
    canvas = Image.new('RGBA', (sprite.width + pad * 2, sprite.height + pad * 2), (0, 0, 0, 0))
    canvas.alpha_composite(sprite, (pad, pad))
    base.alpha_composite(glow(canvas, color, radius), (xy[0] - pad, xy[1] - pad))
    base.alpha_composite(sprite, xy)


def shadow(base, cx, y, w):
    sh = Image.new('RGBA', base.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((cx - w // 2, y - w // 10, cx + w // 2, y + w // 10), fill=(0, 0, 0, 120))
    base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4)))


SAMURAI = os.path.join(A, 'Martial Hero', 'Sprites')
DEMON = os.path.join(A, 'Demon_sword', 'strips')
GOBLIN = os.path.join(A, 'Monsters_Creatures_Fantasy', 'Goblin')
SHROOM = os.path.join(A, 'Forest_Monsters_FREE', 'Mushroom', 'Mushroom with VFX')
EYE = os.path.join(A, 'Monsters_Creatures_Fantasy', 'Flying eye')


def red_tint(img):
    r, g, b, a = img.split()
    r = r.point(lambda v: min(255, int(v * 1.6 + 60)))
    g = g.point(lambda v: int(v * 0.5 + 8))
    b = b.point(lambda v: int(v * 0.55 + 14))
    return Image.merge('RGBA', (r, g, b, a))


# ── Assets ──────────────────────────────────────────────────────────────────
def make_icon():
    S = 512
    bg = scene(1, S, S, anchor_y=0.55)
    bg = ImageEnhance.Brightness(bg).enhance(0.62)
    # warm light burst behind the hero
    burst = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(burst).ellipse((60, 70, 452, 462), fill=(255, 214, 79, 190))
    bg.alpha_composite(burst.filter(ImageFilter.GaussianBlur(60)))
    bg = vignette(bg, 0.6)
    hero = big(frame(os.path.join(SAMURAI, 'Attack1.png'), 200, 200, 3), 5)
    x = (S - hero.width) // 2 + 10
    y = S - hero.height - 58
    shadow(bg, S // 2, S - 60, 230)
    paste_glow(bg, hero, (x, y), (255, 240, 200, 255), radius=10)
    # pixel frame
    d = ImageDraw.Draw(bg)
    for i, c in enumerate([(16, 20, 42), (77, 240, 255), (16, 20, 42)]):
        d.rectangle((i * 8, i * 8, S - 1 - i * 8, S - 1 - i * 8), outline=c, width=8)
    mark = pixel_text('CC', 22, GOLD, 4)
    bg.alpha_composite(mark, (S - mark.width - 30, 30))
    bg.convert('RGB').save(os.path.join(OUT, 'icon_512.png'))
    # a 1024 copy for the app launcher icon
    bg.resize((1024, 1024), Image.NEAREST).convert('RGB').save(os.path.join(OUT, 'icon_1024.png'))


def make_feature():
    W, H = 1024, 500
    bg = scene(3, W, H, anchor_y=0.62)
    bg = vignette(bg, 0.5)
    # dark band at the top so the logo pops
    band = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)
    for y in range(H):
        a = int(170 * max(0, 1 - y / 300) ** 1.6)
        bd.line((0, y, W, y), fill=(8, 10, 28, a))
    bg.alpha_composite(band)

    ground = 470
    reaper = red_tint(big(frame(os.path.join(DEMON, 'Idle.png'), 128, 64, 0, flip=True), 5))
    shadow(bg, 820, ground, 240)
    paste_glow(bg, reaper, (820 - reaper.width // 2, ground - reaper.height), (255, 40, 80, 255), 22)

    gob = big(frame(os.path.join(GOBLIN, 'Run.png'), 150, 150, 2, flip=True), 3)
    shadow(bg, 610, ground, 90)
    bg.alpha_composite(gob, (610 - gob.width // 2, ground - gob.height))
    shroom = big(frame(os.path.join(SHROOM, 'Mushroom-Idle.png'), 80, 64, 0, flip=True), 3)
    shadow(bg, 690, ground, 90)
    bg.alpha_composite(shroom, (690 - shroom.width // 2, ground - shroom.height))
    eye = big(frame(os.path.join(EYE, 'Flight.png'), 150, 150, 1, flip=True), 3)
    bg.alpha_composite(eye, (650, 250))

    hero = big(frame(os.path.join(SAMURAI, 'Attack1.png'), 200, 200, 3), 4)
    shadow(bg, 250, ground, 200)
    paste_glow(bg, hero, (250 - hero.width // 2 + 30, ground - hero.height), (255, 236, 179, 255), 12)

    lg = logo_wide(5)
    bg.alpha_composite(lg, ((W - lg.width) // 2, 22))
    bg.convert('RGB').save(os.path.join(OUT, 'feature_graphic_1024x500.png'))


SHOTS = [
    # (source screenshot number, caption line 1, caption line 2, background scene, accent)
    (5, 'ESCAPE THE CLASSROOM', 'into hand-crafted pixel worlds', 1, GOLD),
    (4, 'SLASH THROUGH MONSTERS', 'goblins, flying eyes and deadly mushrooms', 4, CYAN),
    (2, 'SURVIVE THE GRADE REAPER', 'the final exam fights back', 6, [(255, 205, 210), (255, 82, 82), (213, 0, 0)]),
    (3, 'REST, HEAL, LEVEL UP', 'plov on the rooftop and a new perk', 5, GOLD),
    (1, '7 HEROES  ·  7 BOSSES', '18 rooms across three buildings', 3, CYAN),
]


def make_screens(src_dir):
    W, H = 1920, 1080
    for k, (n, line1, line2, sc, accent) in enumerate(SHOTS, 1):
        shot = Image.open(os.path.join(src_dir, f'{n}.jpg')).convert('RGBA')
        # trim the black strip the phone's camera cut-out leaves on the left
        gray = shot.convert('L')
        left = 0
        while left < shot.width // 4 and max(gray.crop((left, 0, left + 1, shot.height)).getdata()) < 24:
            left += 1
        shot = shot.crop((left, 0, shot.width, shot.height))
        bg = scene(sc, W, H, anchor_y=0.6).filter(ImageFilter.GaussianBlur(10))
        bg = ImageEnhance.Brightness(bg).enhance(0.55)
        bg = vignette(bg, 0.5)

        tw = 1640
        th = round(shot.height * tw / shot.width)
        shot = shot.resize((tw, th), Image.LANCZOS)
        x, y = (W - tw) // 2, H - th - 70
        # rounded screenshot with a glowing border
        m = Image.new('L', shot.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, tw - 1, th - 1), 26, fill=255)
        glow_l = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(glow_l).rounded_rectangle((x - 10, y - 10, x + tw + 10, y + th + 10), 34,
                                                 fill=accent[1] + (200,))
        bg.alpha_composite(glow_l.filter(ImageFilter.GaussianBlur(22)))
        frame_l = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(frame_l).rounded_rectangle((x - 6, y - 6, x + tw + 6, y + th + 6), 30, fill=INK + (255,))
        bg.alpha_composite(frame_l)
        bg.paste(shot, (x, y), m)

        t1 = pixel_text(line1, 22, accent, 4)
        bg.alpha_composite(t1, ((W - t1.width) // 2, 36))
        t2 = pixel_text(line2.upper(), 15, [(255, 255, 255), (230, 236, 255), (200, 210, 240)], 3, spacing=2)
        bg.alpha_composite(t2, ((W - t2.width) // 2, 36 + t1.height - 10))
        bg.convert('RGB').save(os.path.join(OUT, f'screenshot_{k}.png'))


if __name__ == '__main__':
    import sys
    os.makedirs(OUT, exist_ok=True)
    logo(8).save(os.path.join(OUT, 'logo.png'))
    logo_wide(8).save(os.path.join(OUT, 'logo_wide.png'))
    make_icon()
    make_feature()
    shots = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, 'raw')
    if glob.glob(os.path.join(shots, '*.jpg')):
        make_screens(shots)
    print('done')
