"""Draws the game's own 16x16 pixel icons (the few things the bought icon
packs don't have: a clock, a padlock, a lightning bolt, Mira's ghost...)
into assets/pixel/extra_icons.png, one icon per 16px column.

Run from the project root:  python tools/make_pixel_icons.py
The order of ICONS must match kExtraIcons in lib/pixel/pixel_art.dart.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'pixel', 'extra_icons.png')

PALETTE = {
    '.': (0, 0, 0, 0),
    'k': (26, 20, 32, 255),  # outline
    'w': (244, 240, 232, 255),
    'g': (184, 184, 200, 255),
    'd': (110, 106, 128, 255),
    'y': (255, 216, 74, 255),
    'o': (240, 138, 42, 255),
    'r': (216, 52, 58, 255),
    'R': (138, 28, 42, 255),
    'P': (240, 150, 170, 255),
    'b': (90, 168, 232, 255),
    'n': (138, 90, 52, 255),
    'N': (90, 58, 34, 255),
    'p': (150, 110, 230, 255),
    'm': (214, 250, 246, 255),
    'M': (140, 208, 204, 255),
}

PENCIL = [
    '................',
    '............kk..',
    '...........kPPk.',
    '..........kyykk.',
    '.........kyyyk..',
    '........kyyyk...',
    '.......kyyyk....',
    '......kyyyk.....',
    '.....kyyyk......',
    '....kyyyk.......',
    '...knyyk........',
    '...kwnk.........',
    '..kwwk..........',
    '..kkk...........',
    '................',
    '................',
]

ICONS = {
    'bolt': [
        '................',
        '.........kkkkk..',
        '........kyyyyk..',
        '.......kyyyyk...',
        '......kyyyyk....',
        '.....kyyyyk.....',
        '....kyyyykkkkk..',
        '...kyyyyyyyyyk..',
        '...kkkkkyyyyk...',
        '.......kyyyk....',
        '......kyyyk.....',
        '.....kyyyk......',
        '....kyyk........',
        '....kyk.........',
        '....kk..........',
        '................',
    ],
    'clock': [
        '................',
        '..kk........kk..',
        '.krrk.kkkk.krrk.',
        '.krkkkwwwwkkkrk.',
        '..kkwwwwwwwwkk..',
        '..kwwwwkwwwwwk..',
        '.kwwwwwkwwwwwwk.',
        '.kwwwwwkwwwwwwk.',
        '.kwwwwwkkkkwwwk.',
        '.kwwwwwwwwwwwwk.',
        '.kwwwwwwwwwwwwk.',
        '..kwwwwwwwwwwk..',
        '..kkwwwwwwwwkk..',
        '..krkkkkkkkkrk..',
        '..kk........kk..',
        '................',
    ],
    'lock': [
        '................',
        '.....kkkkkk.....',
        '....kggggggk....',
        '...kgkkkkkkgk...',
        '...kgk....kgk...',
        '...kgk....kgk...',
        '..kkkkkkkkkkkk..',
        '..kyyyyyyyyyyk..',
        '..kyyyyyyyyyyk..',
        '..kyyyykkyyyyk..',
        '..kyyyykkyyyyk..',
        '..kyyyyyyyyyyk..',
        '..kooooooooook..',
        '..kkkkkkkkkkkk..',
        '................',
        '................',
    ],
    'ghost': [
        '................',
        '.....kkkkkk.....',
        '....kmmmmmmk....',
        '...kmmmmmmmmk...',
        '..kmmmmmmmmmmk..',
        '..kmmkkmmkkmmk..',
        '..kmmkkmmkkmmk..',
        '..kmmmmmmmmmmk..',
        '..kmmmmmmmmmmk..',
        '..kmmmmMMmmmmk..',
        '..kmmmmmmmmmmk..',
        '..kMmmmmmmmmMk..',
        '..kMMmMMMMmMMk..',
        '..kMkkMkkMkkMk..',
        '..kk..k..k..kk..',
        '................',
    ],
    'hourglass': [
        '................',
        '...kkkkkkkkkk...',
        '...knnnnnnnnk...',
        '....kyyyyyyk....',
        '....kwyyyywk....',
        '.....kwyywk.....',
        '......kyyk......',
        '......kwwk......',
        '.....kwwywk.....',
        '....kwwyywwk....',
        '....kwyyyywk....',
        '...knnnnnnnnk...',
        '...kkkkkkkkkk...',
        '................',
        '................',
        '................',
    ],
    'pencil': PENCIL,
    'redpen': [row.replace('y', 'r').replace('P', 'R') for row in PENCIL],
    'note': [
        '................',
        '.......kkkkk....',
        '.......kwwwwk...',
        '.......kwkkwk...',
        '.......kwk.kk...',
        '.......kwk......',
        '.......kwk......',
        '.......kwk......',
        '....kkkkwk......',
        '...kwwwwwk......',
        '...kwwwwwk......',
        '...kwwwwk.......',
        '....kkkk........',
        '................',
        '................',
        '................',
    ],
    'eye': [
        '................',
        '................',
        '................',
        '....kkkkkkkk....',
        '...kwwwwwwwwk...',
        '..kwwwkkkkwwwk..',
        '.kwwwkrrrrkwwwk.',
        '.kwwwkrkkrkwwwk.',
        '.kwwwkrkkrkwwwk.',
        '.kwwwkrrrrkwwwk.',
        '..kwwwkkkkwwwk..',
        '...kwwwwwwwwk...',
        '....kkkkkkkk....',
        '................',
        '................',
        '................',
    ],
    'moon': [
        '................',
        '......kkkk......',
        '....kkyyyk......',
        '...kyyyk........',
        '..kyyyk.........',
        '..kyyk..........',
        '.kyyyk..........',
        '.kyyyk..........',
        '.kyyyk..........',
        '.kyyyyk.........',
        '..kyyyyk....kk..',
        '..kyyyyykkkkyk..',
        '...kyyyyyyyyk...',
        '....kkyyyykk....',
        '......kkkk......',
        '................',
    ],
    'door': [
        '................',
        '...kkkkkkkkkk...',
        '...knnnnnnnnk...',
        '...knNNNNNNnk...',
        '...knNnnnnNnk...',
        '...knNnnnnNnk...',
        '...knNNNNNNnk...',
        '...knnnnnnyyk...',
        '...knNNNNNNnk...',
        '...knNnnnnNnk...',
        '...knNnnnnNnk...',
        '...knNNNNNNnk...',
        '...knnnnnnnnk...',
        '...kkkkkkkkkk...',
        '................',
        '................',
    ],
    'ladder': [
        '................',
        '...kk......kk...',
        '...knkkkkkknk...',
        '...knnnnnnnnk...',
        '...knkkkkkknk...',
        '...kn......nk...',
        '...knkkkkkknk...',
        '...knnnnnnnnk...',
        '...knkkkkkknk...',
        '...kn......nk...',
        '...knkkkkkknk...',
        '...knnnnnnnnk...',
        '...knkkkkkknk...',
        '...kn......nk...',
        '...kk......kk...',
        '................',
    ],
    'trophy': [
        '................',
        '...kkkkkkkkkk...',
        '.kkkywyyyyyykkk.',
        '.kykywyyyyyykyk.',
        '.kykyyyyyyyykyk.',
        '..kkyyyyyyyykk..',
        '....kyyyyyyk....',
        '.....kyyyyk.....',
        '......kyyk......',
        '.......kk.......',
        '......kyyk......',
        '.....kyyyyk.....',
        '....kkkkkkkk....',
        '....knnnnnnk....',
        '....kkkkkkkk....',
        '................',
    ],
}

# The classic invader, for "monsters".
_INVADER = [
    '..X.....X..',
    '...X...X...',
    '..XXXXXXX..',
    '.XXkXXXkXX.',
    'XXXXXXXXXXX',
    'X.XXXXXXX.X',
    'X.X.....X.X',
    '...XX.XX...',
]
ICONS['invader'] = (['.' * 16] * 4 + ['..' + r.replace('X', 'p') + '...' for r in _INVADER] + ['.' * 16] * 4)


def main():
    names = list(ICONS)
    img = Image.new('RGBA', (16 * len(names), 16), (0, 0, 0, 0))
    for i, name in enumerate(names):
        rows = ICONS[name]
        assert len(rows) == 16, (name, len(rows))
        for y, row in enumerate(rows):
            assert len(row) == 16, (name, y, row, len(row))
            for x, ch in enumerate(row):
                img.putpixel((i * 16 + x, y), PALETTE[ch])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print('wrote', OUT)
    print(', '.join(f"'{n}'" for n in names))


if __name__ == '__main__':
    main()
