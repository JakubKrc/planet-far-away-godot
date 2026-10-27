# Draws the arcology lobby: its tiles, furniture, residents and the view across the
# atrium behind it, using only colours from palette.png.
# Run from the project folder: python3 tools/art/draw_lobby.py
import os
import random
from PIL import Image

ZONE = "scenes/environment/apartment_zone/"
OBJECTS = ZONE + "objects/"
TILES_PATH = ZONE + "tiles/lobby_tiles.png"
RESIDENTS = "scenes/common/characters/residents/"
ATRIUM = "scenes/environment/atrium/"
T = 16

def hexcolor(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

CLEAR = (0, 0, 0, 0)
BLACK = hexcolor("#000000")
WHITE = hexcolor("#ffffff")
OUTLINE = hexcolor("#3b3842")
DARKEST = hexcolor("#1f1d26")
STEEL_DARK, STEEL = hexcolor("#5d5a66"), hexcolor("#8b8785")
CONCRETE_DARK, CONCRETE, CONCRETE_LIGHT = hexcolor("#8b8785"), hexcolor("#b5b5bc"), hexcolor("#dcdce2")
WALL, WALL_SHADE = hexcolor("#dcdce2"), hexcolor("#b5b5bc")
TEAL_DEEP, TEAL_DARK, TEAL, TEAL_LIGHT, TEAL_PALE = (hexcolor(h) for h in ("#0f2b33", "#337e87", "#5fb3b8", "#9ae0e0", "#d2f5ef"))
SKY, SKY_PALE, SKY_DEEP = hexcolor("#8cb9e3"), hexcolor("#cfe6f7"), hexcolor("#3a6aa1")
NAVY, NAVY_DARK = hexcolor("#274569"), hexcolor("#111a2e")
LEAF_DARKEST, LEAF_DARK, LEAF, LEAF_MID, LEAF_LIGHT, LEAF_PALE = (hexcolor(h) for h in ("#123b23", "#1b5a28", "#447835", "#7aa84a", "#9ec96a", "#c9e68a"))
WOOD_LINE, WOOD_DARK, WOOD, WOOD_LIGHT = hexcolor("#6f3527"), hexcolor("#934c35"), hexcolor("#b27653"), hexcolor("#c38f6b")
LAMP, LAMP_WARM, AMBER = hexcolor("#faf3a0"), hexcolor("#f5b05e"), hexcolor("#e88435")
GROW_DARK, GROW, GROW_LIGHT = hexcolor("#8a4ba4"), hexcolor("#c67cdc"), hexcolor("#e3b8ef")
TOMATO = hexcolor("#bf3434")


class Canvas:
    def __init__(self, width, height, colour=CLEAR):
        self.image = Image.new("RGBA", (width, height), colour)
        self.width, self.height = width, height

    def pixel(self, x, y, colour):
        if 0 <= x < self.width and 0 <= y < self.height:
            self.image.putpixel((x, y), colour)

    def box(self, x0, y0, x1, y1, colour):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.pixel(x, y, colour)

    def hline(self, y, colour, x0=0, x1=None):
        self.box(x0, y, self.width - 1 if x1 is None else x1, y, colour)

    def vline(self, x, colour, y0=0, y1=None):
        self.box(x, y0, x, self.height - 1 if y1 is None else y1, colour)

    def outline_box(self, x0, y0, x1, y1, fill, edge=OUTLINE):
        self.box(x0, y0, x1, y1, edge)
        self.box(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)

    def blob(self, cx, cy, rx, ry, colour):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1:
                    self.pixel(x, y, colour)

    def letters(self, x0, y0, rows, colours):
        for y, row in enumerate(rows):
            for x, letter in enumerate(row):
                if letter != ".":
                    self.pixel(x0 + x, y0 + y, colours[letter])

    def save(self, path):
        self.image.save(path)


# ── tiles ──

def tile(colour=CLEAR):
    return Canvas(T, T, colour)

def floor_stone(offset):
    # Polished stone, a teal inlay line, slab underneath.
    t = tile(CONCRETE)
    t.hline(0, OUTLINE)
    t.hline(1, WHITE)
    t.box(0, 2, 15, 5, CONCRETE_LIGHT)
    t.hline(6, TEAL)
    t.hline(7, OUTLINE)
    t.vline(15 if offset else 7, WALL_SHADE, 2, 5)
    for x, y in ((3, 11), (11, 13), (7, 10)):
        t.pixel(x, y, CONCRETE_LIGHT)
    return t

def slab():
    t = tile(CONCRETE)
    t.pixel(4, 5, CONCRETE_LIGHT)
    t.pixel(12, 11, CONCRETE_DARK)
    return t

def wall_plain(seam):
    t = tile(WALL)
    if seam:
        t.vline(0, WALL_SHADE)
    return t

def wall_baseboard():
    t = tile(WALL)
    t.hline(11, TEAL_LIGHT)
    t.box(0, 12, 15, 14, TEAL)
    t.hline(15, TEAL_DARK)
    return t

def wall_lights():
    # Just under the ceiling: a shadow line and recessed lamps.
    t = tile(WALL)
    t.box(0, 0, 15, 1, WALL_SHADE)
    t.box(5, 0, 10, 1, LAMP)
    t.hline(2, LAMP, 4, 11)
    for x in range(3, 13, 2):
        t.pixel(x, 3, LAMP)
    return t

def side_wall(facing_right):
    t = tile(CONCRETE)
    t.vline(14, CONCRETE_LIGHT)
    t.vline(15, OUTLINE)
    if not facing_right:
        t.image = t.image.transpose(Image.FLIP_LEFT_RIGHT)
    return t

def pillar(facing_right, base):
    # The corner where the floors above stop and the open atrium begins.
    t = tile(CONCRETE)
    t.vline(0, CONCRETE_LIGHT)
    t.vline(1, CONCRETE_LIGHT)
    t.vline(12, CONCRETE_DARK)
    t.vline(13, TEAL)
    t.vline(14, TEAL_DARK)
    t.vline(15, OUTLINE)
    if base:
        t.box(0, 11, 15, 15, CONCRETE_DARK)
        t.hline(11, CONCRETE_LIGHT)
        t.hline(15, OUTLINE)
    if not facing_right:
        t.image = t.image.transpose(Image.FLIP_LEFT_RIGHT)
    return t

# The galleries above the lobby: floor after floor of homes facing the atrium.
# Each row is one 4-tile bay; a floor is top, upper, lower, rail, band.
BAY = 4 * T

def bay(paint):
    row = Canvas(BAY, T, CONCRETE)
    row.vline(0, CONCRETE_LIGHT)
    row.vline(63, CONCRETE_DARK)
    paint(row)
    return [row.image.crop((x * T, 0, x * T + T, T)) for x in range(4)]

DOOR_X0, DOOR_X1 = 6, 19
WINDOW_X0, WINDOW_X1 = 26, 57

def gallery_top(row):
    # Vines hang from the planters on the floor above.
    for x, length in ((30, 6), (33, 10), (36, 4), (40, 8), (44, 12), (47, 5), (51, 9), (55, 3)):
        row.vline(x, LEAF, 0, length)
        row.pixel(x, length, LEAF_LIGHT)
        row.pixel(x + 1, length // 2, LEAF_MID)
    row.box(DOOR_X0 + 4, 9, DOOR_X1 - 4, 11, LAMP)          # lamp over the door
    row.hline(12, CONCRETE_DARK, DOOR_X0 + 4, DOOR_X1 - 4)

def gallery_upper(row):
    row.outline_box(DOOR_X0, 2, DOOR_X1, 17, TEAL)
    row.vline(DOOR_X0 + 1, TEAL_LIGHT, 3)
    row.box(DOOR_X0 + 4, 5, DOOR_X1 - 4, 9, TEAL_LIGHT)     # door window
    row.box(WINDOW_X0, 4, WINDOW_X1, 15, OUTLINE)
    row.box(WINDOW_X0 + 1, 5, WINDOW_X1 - 1, 15, LAMP)
    row.box(WINDOW_X0 + 1, 5, WINDOW_X1 - 1, 6, LAMP_WARM)  # warm light inside
    row.vline((WINDOW_X0 + WINDOW_X1) // 2, OUTLINE, 5)

def gallery_lower(row):
    row.box(DOOR_X0, 0, DOOR_X0, 15, OUTLINE)
    row.box(DOOR_X1, 0, DOOR_X1, 15, OUTLINE)
    row.box(DOOR_X0 + 1, 0, DOOR_X1 - 1, 15, TEAL)
    row.vline(DOOR_X0 + 1, TEAL_LIGHT)
    row.pixel(DOOR_X1 - 3, 4, AMBER)                        # handle
    row.box(WINDOW_X0, 0, WINDOW_X1, 8, OUTLINE)
    row.box(WINDOW_X0 + 1, 0, WINDOW_X1 - 1, 7, LAMP)
    row.vline((WINDOW_X0 + WINDOW_X1) // 2, OUTLINE, 0, 7)
    row.hline(9, CONCRETE_LIGHT, WINDOW_X0 - 2, WINDOW_X1 + 2)  # sill

def gallery_rail(row):
    # A railing in front of the walkway, with a planter box behind it.
    row.box(DOOR_X0, 0, DOOR_X1, 7, TEAL)
    row.vline(DOOR_X0, OUTLINE, 0, 7)
    row.vline(DOOR_X1, OUTLINE, 0, 7)
    row.box(30, 7, 58, 11, WOOD)
    row.hline(7, WOOD_LIGHT, 30, 58)
    row.hline(11, WOOD_DARK, 30, 58)
    rng = random.Random(7)
    for x in range(30, 59):
        height = rng.randint(1, 5)
        row.vline(x, LEAF if x % 2 else LEAF_MID, 7 - height, 6)
        row.pixel(x, 7 - height, LEAF_LIGHT)
    row.hline(4, OUTLINE)                                    # handrail
    row.hline(5, TEAL)
    for x in range(2, BAY, 6):
        row.vline(x, OUTLINE, 5, 15)

def gallery_band(row):
    # The walkway's edge; its top lines up with the floor the residents walk on.
    row.box(0, 0, BAY - 1, 1, CONCRETE_LIGHT)
    row.box(0, 2, BAY - 1, 13, CONCRETE_DARK)
    row.hline(14, STEEL_DARK)
    row.hline(15, OUTLINE)
    for x in range(8, BAY, 16):
        row.box(x, 6, x + 3, 8, CONCRETE)

def green_upper(row):
    # A living wall instead of a home.
    living_wall(row, 0)

def green_lower(row):
    living_wall(row, 1)

def living_wall(row, seed):
    row.box(4, 0, 59, 15, LEAF_DARK)
    rng = random.Random(20 + seed)
    for _ in range(90):
        x, y = rng.randint(4, 59), rng.randint(0, 15)
        row.pixel(x, y, rng.choice((LEAF, LEAF_MID, LEAF_LIGHT, LEAF)))
    row.vline(4, OUTLINE)
    row.vline(59, OUTLINE)

TILE_ROWS = [
    [floor_stone(False), floor_stone(True), slab(), tile(BLACK)],
    [wall_plain(False), wall_plain(True), wall_baseboard(), wall_lights()],
    [side_wall(True), side_wall(False), pillar(True, False), pillar(False, False)],
    [pillar(True, True), pillar(False, True), tile(), tile()],
]
GALLERY_ROWS = [gallery_top, gallery_upper, gallery_lower, gallery_rail, gallery_band, green_upper, green_lower]

def draw_tiles():
    rows = [[t.image for t in row] for row in TILE_ROWS]
    rows += [bay(paint) for paint in GALLERY_ROWS]
    sheet = Image.new("RGBA", (T * 4, T * len(rows)))
    for y, row in enumerate(rows):
        for x, image in enumerate(row):
            sheet.paste(image, (x * T, y * T))
    sheet.save(TILES_PATH)


# ── the arcology's homes, seen across the atrium ──
# A kit for big, bright apartments: floor-to-ceiling windows built from a 9-slice
# frame, balconies with glass railings, and things standing on them.

GLASS_COLOUR = SKY_PALE
INSIDE, INSIDE_DARK = SKY, hexcolor("#5d8ac7")      # furniture seen through the glass
FRAME = 3                                            # frame thickness in pixels
CURTAIN, CURTAIN_LIGHT = GROW, GROW_LIGHT

def glass():
    return tile(GLASS_COLOUR)

def frame_top(t):
    t.hline(0, OUTLINE)
    t.box(0, 1, 15, FRAME - 1, WHITE)

def frame_bottom(t):
    t.box(0, 16 - FRAME, 15, 14, WHITE)
    t.hline(15, OUTLINE)

def frame_left(t):
    t.vline(0, OUTLINE)
    t.box(1, 0, FRAME - 1, 15, WHITE)

def frame_right(t):
    t.box(16 - FRAME, 0, 14, 15, WHITE)
    t.vline(15, OUTLINE)

def window_piece(top=False, bottom=False, left=False, right=False):
    t = glass()
    if top:
        frame_top(t)
    if bottom:
        frame_bottom(t)
    if left:
        frame_left(t)
        if top:
            t.hline(0, OUTLINE)
        if bottom:
            t.hline(15, OUTLINE)
    if right:
        frame_right(t)
        if top:
            t.hline(0, OUTLINE)
        if bottom:
            t.hline(15, OUTLINE)
    return t

def mullion(t):
    t.box(7, 0, 8, 15, WHITE)
    t.vline(9, CONCRETE_LIGHT)

def reflection(t, offset, width):
    for i in range(16):
        for w in range(width):
            t.pixel(offset + i // 2 + w, 15 - i, WHITE)

def glass_reflect_a():
    t = glass()
    reflection(t, 2, 2)
    reflection(t, 7, 1)
    return t

def glass_reflect_b():
    t = glass()
    reflection(t, 5, 1)
    return t

def glass_mullion():
    t = glass()
    mullion(t)
    return t

def glass_transom(with_mullion):
    # The edge of an inner gallery: a two-storey home.
    t = glass()
    t.box(0, 6, 15, 7, WHITE)
    t.hline(8, INSIDE)
    t.box(0, 9, 15, 10, INSIDE)
    for x in range(1, 16, 4):
        t.vline(x, INSIDE, 3, 5)                     # its railing
    t.hline(3, INSIDE)
    if with_mullion:
        mullion(t)
    return t

def glass_curtain(on_left):
    t = glass()
    t.box(0, 0, 4, 15, CURTAIN)
    for x in (1, 3):
        t.vline(x, CURTAIN_LIGHT)
    t.box(5, 0, 5, 15, GROW_DARK)
    if not on_left:
        t.image = t.image.transpose(Image.FLIP_LEFT_RIGHT)
    return t

def window_top_lamp():
    t = window_piece(top=True)
    t.vline(8, INSIDE, FRAME, 8)
    t.box(5, 9, 11, 10, LAMP_WARM)
    t.hline(9, AMBER, 6, 10)
    for x in range(4, 13, 2):
        t.pixel(x, 12, LAMP)
    return t

def window_top_mullion():
    t = window_piece(top=True)
    t.box(7, FRAME, 8, 15, WHITE)
    t.vline(9, CONCRETE_LIGHT, FRAME)
    return t

def window_bottom_mullion():
    t = window_piece(bottom=True)
    t.box(7, 0, 8, 12, WHITE)
    t.vline(9, CONCRETE_LIGHT, 0, 12)
    return t

def window_bottom_plant():
    t = window_piece(bottom=True)
    t.box(5, 9, 10, 12, INSIDE_DARK)                 # pot
    for x, height in ((4, 4), (6, 8), (8, 9), (10, 6), (12, 3)):
        t.vline(x, INSIDE_DARK, 9 - height, 8)
        t.pixel(x + 1, 9 - height + 1, INSIDE)
    return t

def window_bottom_sofa():
    t = window_piece(bottom=True)
    t.box(1, 5, 15, 12, INSIDE)
    t.box(1, 5, 2, 12, INSIDE_DARK)                  # armrest
    t.hline(9, INSIDE_DARK, 3, 15)
    return t

def window_bottom_lamp():
    t = window_piece(bottom=True)
    t.vline(8, INSIDE_DARK, 3, 12)
    t.box(6, 12, 10, 12, INSIDE_DARK)
    t.box(5, 0, 11, 2, LAMP_WARM)
    t.hline(0, AMBER, 6, 10)
    for x in range(5, 12, 2):
        t.pixel(x, 4, LAMP)
    return t

def facade_wall():
    t = tile(CONCRETE)
    t.pixel(4, 6, CONCRETE_LIGHT)
    t.pixel(11, 12, CONCRETE_DARK)
    return t

def facade_wall_joint(vertical):
    t = facade_wall()
    if vertical:
        t.vline(15, CONCRETE_DARK)
    else:
        t.hline(15, CONCRETE_DARK)
    return t

def facade_sconce():
    t = facade_wall()
    t.outline_box(6, 5, 9, 9, LAMP)
    t.hline(6, LAMP_WARM, 7, 8)
    for x in (5, 10):
        t.pixel(x, 7, LAMP)
    return t

def building_edge(on_right):
    # Where a floor ends toward the open atrium.
    t = facade_wall()
    t.vline(12, CONCRETE_LIGHT)
    t.vline(13, CONCRETE_DARK)
    t.vline(14, STEEL_DARK)
    t.vline(15, OUTLINE)
    if not on_right:
        t.image = t.image.transpose(Image.FLIP_LEFT_RIGHT)
    return t

def facade_slab(left_end=False, right_end=False, lights=False, joint=False):
    # The floor of a balcony seen edge-on; it is also the ceiling of the home below.
    t = tile(CONCRETE)
    t.hline(0, OUTLINE)
    t.hline(1, WHITE)
    t.box(0, 2, 15, 3, CONCRETE_LIGHT)
    t.hline(11, CONCRETE_DARK)
    t.box(0, 12, 15, 14, STEEL_DARK)
    t.hline(15, OUTLINE)
    if joint:
        t.vline(15, CONCRETE_DARK, 4, 10)
    if lights:
        t.box(6, 13, 9, 14, LAMP)
    if left_end:
        t.vline(0, OUTLINE)
        t.vline(1, CONCRETE_LIGHT, 2, 10)
    if right_end:
        t.vline(15, OUTLINE)
        t.vline(14, CONCRETE_DARK, 2, 10)
    return t

# Balcony things. The railing sits in front of the bottom window row; furniture
# stands behind it in a layer of its own.

def rail(left_post=False, right_post=False):
    t = tile()
    t.hline(5, OUTLINE)
    t.hline(6, TEAL)
    t.hline(7, TEAL_DARK)
    for y in range(8, 15):
        for x in range(16):
            if (x + y) % 2 == 0:
                t.pixel(x, y, TEAL_PALE)
    t.hline(15, STEEL_DARK)
    if left_post:
        t.box(0, 5, 1, 15, OUTLINE)
    if right_post:
        t.box(14, 5, 15, 15, OUTLINE)
    return t

def deck_chair():
    t = tile()
    for i in range(6):                               # tilted backrest
        t.box(2 + i // 2, 4 + i, 3 + i // 2, 4 + i, WHITE)
        t.pixel(1 + i // 2, 4 + i, OUTLINE)
    t.box(4, 10, 14, 11, WHITE)
    t.hline(12, TEAL, 4, 14)
    t.hline(9, OUTLINE, 6, 14)
    for x in (5, 13):
        t.vline(x, OUTLINE, 13, 15)
    return t

def bistro_table():
    t = tile()
    t.box(4, 8, 11, 8, OUTLINE)
    t.hline(7, WHITE, 4, 11)
    t.vline(8, OUTLINE, 9, 15)
    t.box(6, 15, 10, 15, OUTLINE)
    t.vline(1, OUTLINE, 6, 15)                       # chair
    t.box(1, 11, 3, 11, OUTLINE)
    t.vline(14, OUTLINE, 6, 15)
    t.box(12, 11, 14, 11, OUTLINE)
    t.pixel(6, 6, LAMP_WARM)                         # a glass of something
    return t

def potted_tree_top():
    t = tile()
    t.blob(8, 9, 7, 6, LEAF_DARKEST)
    t.blob(8, 9, 6, 5, LEAF_DARK)
    t.blob(7, 8, 4, 3, LEAF)
    t.blob(6, 7, 2, 1, LEAF_MID)
    t.pixel(10, 10, LEAF_LIGHT)
    t.pixel(4, 11, LEAF_LIGHT)
    return t

def potted_tree_bottom():
    t = tile()
    t.box(7, 0, 8, 8, WOOD_DARK)
    t.box(4, 9, 11, 15, OUTLINE)
    t.box(5, 10, 10, 14, WHITE)
    t.hline(10, CONCRETE_LIGHT, 5, 10)
    return t

def parasol_canopy(part):
    # Three tiles wide; the pole runs down the middle tile. `part` is 0, 1 or 2.
    canopy = Canvas(3 * T, T)
    for y in range(5, 12):
        reach = 6 + (y - 5) * 3
        for x in range(24 - reach, 24 + reach):
            stripe = (x // 6) % 2 == 0
            canopy.pixel(x, y, AMBER if stripe else LAMP)
        canopy.pixel(24 - reach, y, OUTLINE)
        canopy.pixel(23 + reach, y, OUTLINE)
    canopy.hline(4, OUTLINE, 18, 29)
    canopy.hline(12, OUTLINE, 1, 46)
    canopy.box(23, 2, 24, 3, OUTLINE)
    canopy.box(23, 13, 24, 15, OUTLINE)
    t = tile()
    t.image = canopy.image.crop((part * T, 0, part * T + T, T))
    return t

def parasol_pole():
    t = tile()
    t.box(7, 0, 8, 13, OUTLINE)
    t.box(4, 14, 11, 15, OUTLINE)
    return t

def plant_pot(t, x0, x1):
    t.box(x0, 11, x1, 15, OUTLINE)
    t.box(x0 + 1, 11, x1 - 1, 14, hexcolor("#c45a1f"))
    t.hline(11, hexcolor("#e88435"), x0 + 1, x1 - 1)

def flowering_bush():
    t = tile()
    t.blob(8, 6, 7, 5, LEAF_DARK)
    t.blob(7, 5, 5, 3, LEAF)
    rng = random.Random(51)
    for _ in range(14):
        x, y = rng.randint(2, 14), rng.randint(2, 10)
        if t.image.getpixel((x, y))[3]:
            t.pixel(x, y, rng.choice((hexcolor("#e08594"), hexcolor("#f7c4cc"), WHITE)))
    plant_pot(t, 4, 11)
    return t

def cactus():
    t = tile()
    t.box(6, 2, 9, 10, LEAF_DARK)
    t.box(7, 2, 8, 10, LEAF_MID)
    t.box(3, 5, 5, 6, LEAF_DARK)                     # arms
    t.box(3, 3, 4, 5, LEAF_DARK)
    t.box(10, 6, 12, 7, LEAF_DARK)
    t.box(11, 4, 12, 6, LEAF_DARK)
    t.pixel(7, 1, hexcolor("#e08594"))               # a flower on top
    plant_pot(t, 4, 11)
    return t

PALM_TOP = [
    "................",
    "................",
    ".....MM...MM....",
    "..MMMLLM.MLLMMM.",
    ".MLL..MLLMM..LLM",
    "ML...MLDDLM....L",
    "L...ML.WW.LM....",
    "...ML..WW..LM...",
    "..ML...WW...LM..",
    "..L....WW....L..",
    ".......WW.......",
    ".......WW.......",
    ".......WD.......",
    ".......WW.......",
    ".......WD.......",
    ".......WW.......",
]

def palm_top():
    t = tile()
    t.letters(0, 0, PALM_TOP, {"M": LEAF_MID, "L": LEAF, "D": LEAF_DARK, "W": WOOD})
    return t

def palm_pot():
    t = tile()
    for y in range(0, 11):
        t.box(7, y, 8, y, WOOD if y % 3 else WOOD_DARK)
    plant_pot(t, 4, 11)
    return t

def bamboo_top():
    t = tile()
    for x in (4, 7, 10, 12):
        t.vline(x, LEAF_MID, 6 - x % 3, 15)
        t.pixel(x - 1, 6 - x % 3, LEAF_LIGHT)
        t.pixel(x + 1, 8 - x % 3, LEAF)
    for x, y in ((3, 3), (9, 2), (13, 4), (6, 5)):
        t.box(x, y, x + 1, y, LEAF)
    return t

def bamboo_planter():
    t = tile()
    for x in (4, 7, 10, 12):
        t.vline(x, LEAF_MID, 0, 10)
        t.pixel(x, 4, LEAF_DARK)
        t.pixel(x, 8, LEAF_DARK)
    t.box(2, 11, 13, 15, OUTLINE)
    t.box(3, 11, 12, 14, WHITE)
    t.hline(11, CONCRETE_LIGHT, 3, 12)
    return t

def lemon_tree_top():
    t = potted_tree_top()
    rng = random.Random(61)
    for _ in range(6):
        x, y = rng.randint(3, 13), rng.randint(5, 13)
        if t.image.getpixel((x, y))[3]:
            t.pixel(x, y, hexcolor("#e6dc2e"))
    return t

def planter_box():
    t = tile()
    rng = random.Random(31)
    for x in range(1, 15):
        height = rng.randint(2, 7)
        t.vline(x, LEAF if x % 2 else LEAF_MID, 10 - height, 9)
        t.pixel(x, 10 - height, LEAF_LIGHT)
    t.box(0, 10, 15, 15, WOOD)
    t.hline(10, WOOD_LIGHT)
    t.hline(15, WOOD_LINE)
    t.vline(0, WOOD_LINE, 10)
    t.vline(15, WOOD_LINE, 10)
    return t

def hanging_vines(seed):
    t = tile()
    rng = random.Random(seed)
    for x in range(0, 16, 2):
        if rng.random() < 0.25:
            continue
        length = rng.randint(3, 15)
        x_here = x + rng.randint(0, 1)
        t.vline(x_here, LEAF if rng.random() < 0.6 else LEAF_DARK, 0, length)
        t.pixel(x_here, length, LEAF_LIGHT)
        if length > 5:
            t.pixel(x_here + 1, length // 2, LEAF_MID)
    return t

def living_wall_tile(seed, ragged_top=False):
    t = tile(LEAF_DARK)
    rng = random.Random(seed)
    for _ in range(60):
        t.pixel(rng.randint(0, 15), rng.randint(0, 15), rng.choice((LEAF, LEAF_MID, LEAF_LIGHT, LEAF)))
    if ragged_top:
        for x in range(16):
            for y in range(rng.randint(0, 4)):
                t.pixel(x, y, CLEAR)
    return t

FACADE_PATH = ZONE + "tiles/arcology_facade_tiles.png"

# Eight columns per row; the build script names each tile by its column and row.
FACADE_ROWS = [
    [facade_wall(), facade_wall_joint(True), facade_wall_joint(False), facade_sconce(),
     building_edge(False), building_edge(True), tile(), tile()],
    [facade_slab(left_end=True), facade_slab(), facade_slab(right_end=True), facade_slab(lights=True),
     facade_slab(joint=True), tile(), tile(), tile()],
    [window_piece(top=True, left=True), window_piece(top=True), window_piece(top=True, right=True), window_top_lamp(),
     window_top_mullion(), glass(), glass_reflect_a(), glass_reflect_b()],
    [window_piece(left=True), glass_mullion(), window_piece(right=True), glass_transom(False),
     glass_transom(True), glass_curtain(True), glass_curtain(False), tile()],
    [window_piece(bottom=True, left=True), window_piece(bottom=True), window_piece(bottom=True, right=True), window_bottom_mullion(),
     window_bottom_plant(), window_bottom_sofa(), window_bottom_lamp(), tile()],
    [rail(left_post=True), rail(), rail(right_post=True), deck_chair(),
     bistro_table(), potted_tree_bottom(), parasol_pole(), planter_box()],
    [hanging_vines(1), hanging_vines(2), hanging_vines(3), potted_tree_top(),
     parasol_canopy(0), parasol_canopy(1), parasol_canopy(2), tile()],
    [living_wall_tile(40, ragged_top=True), living_wall_tile(41), living_wall_tile(42), living_wall_tile(43),
     flowering_bush(), cactus(), palm_pot(), bamboo_planter()],
    [palm_top(), bamboo_top(), lemon_tree_top(), tile(), tile(), tile(), tile(), tile()],
]

def draw_facade_tiles():
    sheet = Image.new("RGBA", (T * 8, T * len(FACADE_ROWS)))
    for y, row in enumerate(FACADE_ROWS):
        for x, t in enumerate(row):
            sheet.paste(t.image, (x * T, y * T))
    sheet.save(FACADE_PATH)


# ── lobby furniture ──

def entrance_door():
    # Glass sliding doors to the transit platform.
    c = Canvas(44, 52)
    c.box(0, 0, 43, 5, OUTLINE)
    c.box(1, 1, 42, 4, STEEL)
    c.hline(2, LAMP, 4, 39)
    c.box(0, 6, 43, 51, OUTLINE)
    c.box(2, 7, 41, 51, SKY_DEEP)
    for x0 in (2, 22):
        c.box(x0, 7, x0 + 19, 51, SKY)
        c.box(x0, 7, x0 + 19, 8, SKY_PALE)
        for i in range(12):                                 # a glint across the glass
            c.pixel(x0 + 4 + i // 2, 30 - i, SKY_PALE)
            c.pixel(x0 + 6 + i // 2, 30 - i, WHITE)
        c.vline(x0, OUTLINE, 7)
        c.vline(x0 + 19, OUTLINE, 7)
        c.hline(28, OUTLINE, x0, x0 + 19)
    c.vline(21, OUTLINE, 7)
    c.vline(22, OUTLINE, 7)
    return c

def elevator():
    # Doors, the floor display above, and a call button beside.
    c = Canvas(44, 60)
    c.outline_box(4, 0, 35, 9, DARKEST)
    c.letters(9, 2, ["..X..", ".XXX.", "XXXXX", "..X..", "..X.."], {"X": LAMP_WARM})   # going up
    c.box(17, 4, 30, 6, AMBER)
    c.box(0, 10, 39, 59, OUTLINE)
    c.box(1, 11, 38, 59, STEEL)
    c.box(1, 11, 38, 12, CONCRETE)
    c.box(4, 14, 35, 59, OUTLINE)
    c.box(5, 15, 19, 59, CONCRETE_LIGHT)
    c.box(20, 15, 34, 59, CONCRETE_LIGHT)
    c.vline(19, CONCRETE_DARK, 15)
    c.vline(20, OUTLINE, 15)
    c.vline(5, WHITE, 15)
    c.vline(21, WHITE, 15)
    c.outline_box(39, 30, 43, 38, STEEL)
    c.pixel(41, 32, AMBER)
    c.pixel(41, 35, STEEL_DARK)
    return c

def parcel_lockers():
    c = Canvas(52, 40)
    c.box(0, 0, 51, 39, OUTLINE)
    c.box(1, 1, 50, 38, STEEL_DARK)
    for row in range(3):
        for col in range(4):
            x0, y0 = 2 + col * 12, 2 + row * 12
            c.outline_box(x0, y0, x0 + 11, y0 + 11, TEAL_DARK, DARKEST)
            c.hline(y0 + 1, TEAL, x0 + 1, x0 + 10)
            c.pixel(x0 + 9, y0 + 6, AMBER if (row * 4 + col) % 5 == 1 else TEAL_DEEP)
    return c

def info_screen():
    c = Canvas(40, 26)
    c.box(0, 0, 39, 25, OUTLINE)
    c.box(1, 1, 38, 24, DARKEST)
    c.box(2, 2, 37, 23, NAVY_DARK)
    # The arcology as a stepped shape, a little green on its terraces.
    for step, (x0, x1) in enumerate(((10, 18), (8, 20), (6, 22), (4, 24))):
        c.box(x0, 6 + step * 4, x1, 21, TEAL)
        c.hline(6 + step * 4, LEAF_LIGHT, x0, x1)
    c.vline(14, TEAL_LIGHT, 3, 5)
    for y, length in ((6, 9), (10, 7), (14, 8), (18, 5)):
        c.hline(y, TEAL_LIGHT, 27, 27 + length)
    c.pixel(35, 21, AMBER)
    return c

def tree_planter():
    c = Canvas(84, 124)
    # trunk, reaching up into the crown, which is drawn over its top
    c.box(38, 40, 45, 112, WOOD_DARK)
    c.vline(38, WOOD_LINE, 40, 112)
    c.vline(45, WOOD_LINE, 40, 112)
    c.vline(40, WOOD, 66, 110)
    for i in range(10):                                     # branches into the side clumps
        c.box(30 + i, 54 - i // 2, 31 + i, 55 - i // 2, WOOD_DARK)
        c.box(52 - i, 52 - i // 2, 53 - i, 53 - i // 2, WOOD_DARK)
    # canopy: dark mass, lighter clumps on top, a few bright highlights
    rng = random.Random(11)
    clumps = [(42, 34, 30, 22), (22, 50, 18, 12), (62, 48, 18, 12), (42, 18, 20, 14), (30, 30, 14, 10), (56, 30, 14, 10), (42, 54, 14, 7)]
    for cx, cy, rx, ry in clumps:
        c.blob(cx, cy, rx + 1, ry + 1, LEAF_DARKEST)
    for cx, cy, rx, ry in clumps:
        c.blob(cx, cy, rx, ry, LEAF_DARK)
    for cx, cy, rx, ry in clumps:
        c.blob(cx - 2, cy - 3, rx - 4, ry - 4, LEAF)
    for cx, cy, rx, ry in clumps:
        c.blob(cx - 4, cy - 5, rx // 3, ry // 3, LEAF_MID)
    for _ in range(40):
        x, y = rng.randint(10, 74), rng.randint(6, 64)
        if c.image.getpixel((x, y)) in (LEAF, LEAF_MID):
            c.pixel(x, y, LEAF_LIGHT)
    # round planter with a teal band
    c.box(14, 104, 69, 123, OUTLINE)
    c.box(15, 105, 68, 122, CONCRETE)
    c.hline(105, CONCRETE_LIGHT, 15, 68)
    c.box(15, 112, 68, 114, TEAL)
    c.hline(112, TEAL_LIGHT, 15, 68)
    c.hline(122, CONCRETE_DARK, 15, 68)
    c.box(12, 102, 71, 104, OUTLINE)
    c.box(13, 102, 70, 103, CONCRETE_LIGHT)
    for x in range(16, 68, 3):
        c.pixel(x, 101, LEAF_MID if x % 2 else LEAF)
    return c

def bench():
    c = Canvas(40, 14)
    c.box(0, 4, 39, 7, OUTLINE)
    c.box(1, 5, 38, 6, WOOD)
    c.hline(5, WOOD_LIGHT, 1, 38)
    c.box(0, 0, 39, 2, OUTLINE)
    c.hline(1, WOOD, 1, 38)
    for x in (4, 34):
        c.box(x, 7, x + 1, 13, OUTLINE)
        c.vline(x, STEEL, 0, 3)
    return c

def hydroponic_rack():
    # Food grows in the lobby: three shelves of trays under purple grow lights.
    c = Canvas(64, 56)
    rng = random.Random(5)
    for shelf in range(3):
        y = 4 + shelf * 17
        c.box(2, y, 61, y + 1, OUTLINE)                     # light bar
        c.hline(y + 1, GROW_LIGHT, 4, 59)
        for x in range(4, 60):                              # glow falling on the plants
            if (x + shelf) % 3 == 0:
                c.pixel(x, y + 3, GROW_DARK)
        tray = y + 13
        for x in range(4, 60, 4):                           # plants
            kind = rng.random()
            height = rng.randint(5, 9)
            for dx in range(3):
                c.vline(x + dx, LEAF if dx == 1 else LEAF_MID, tray - height + abs(dx - 1) * 2, tray - 1)
            c.pixel(x + 1, tray - height, LEAF_LIGHT)
            if kind < 0.35:
                c.pixel(x, tray - height + 3, TOMATO)
                c.pixel(x + 2, tray - height + 5, TOMATO)
        c.box(2, tray, 61, tray + 2, OUTLINE)
        c.box(3, tray, 60, tray + 1, TEAL_DARK)
        c.hline(tray, TEAL, 3, 60)
    for x in (0, 62):                                       # frame
        c.box(x, 2, x + 1, 55, OUTLINE)
        c.vline(x + 1, STEEL, 2, 54)
    c.box(0, 2, 63, 3, OUTLINE)
    return c


# ── residents ──
# Front-facing, 16x32 like Igor and Kristin; feet on the image's bottom row.

def resident(path, rows, colours):
    width = max(len(row) for row in rows)
    c = Canvas(width, len(rows))
    c.letters(0, 0, rows, colours)
    c.save(path)

GARDENER = [
    "....oooooo..........",
    "...ohhHHhhoo........",
    "..ohhhhhhhhho.......",
    "..ohsssssssho.......",
    "..ossssssssso.......",
    "..osEEsssEEso.......",
    "..osssssssSso.......",
    "..osbbbbbbbso.......",
    "..obbbmmmbbbo.......",
    "..oobbbbbbboo.......",
    "..owwgwSwgwwo.......",
    ".owwwgggggwwwo......",
    ".owwogggggowwo......",
    ".owwogGGGgowwo......",
    ".owwogGGGgowwo......",
    ".oswogggggowso......",
    "..sso.ggggg.ossccc..",
    "..sso.ggggg.osCCCCCq",
    "......ggggg..cCCCCCq",
    "....oggggggo.cCCCC.q",
    "....ogggGgggo.cccc..",
    "....ogggogggo.......",
    "....ogggogggo.......",
    "....ogggogggo.......",
    "....ogggogggo.......",
    "....ogggogggo.......",
    "....ogggogggo.......",
    "....ogggogggo.......",
    "....ogggogggo.......",
    "....ogggogggo.......",
    "....zzzzozzzz.......",
    "....ZZZZoZZZZ.......",
]
GARDENER_COLOURS = {
    "o": OUTLINE, "h": STEEL, "H": CONCRETE,                  # grey hair
    "s": hexcolor("#e8c7a0"), "S": hexcolor("#d9ab84"),
    "E": NAVY, "m": WOOD_LINE, "b": CONCRETE_LIGHT,           # white beard
    "w": SKY, "g": LEAF, "G": LEAF_MID,                       # shirt, overalls
    "c": TEAL_DARK, "C": TEAL, "q": TEAL_LIGHT,               # watering can
    "z": WOOD_LINE, "Z": hexcolor("#362119"),
}

READER = [                                                   # sitting, tablet in hand
    "....oooooo......",
    "...ohhhhhhoo....",
    "..ohhhhhhhhho...",
    "..ohssssssho....",
    "..ohsssssssho...",
    "..ohsEsssEsho...",
    "..ohssssssSho...",
    "..ohssmmmssho...",
    "...ohssssshho...",
    "....oSSSSSo.....",
    "..ojjjjSjjjjo...",
    ".ojjjjjjjjjjjo..",
    ".ojjojjjjjojjo..",
    ".ojjoJjjjJojjo..",
    ".ojjoTTTTTojjo..",
    ".ossoTtttTosso..",
    "..s.oTtttTo.s...",
    "....ojjjjjo.....",
    "..ppppppppppp...",
    "..ppppppppppp...",
    "..pppp...pppp...",
    "...ppp...ppp....",
    "...ppp...ppp....",
    "...ppp...ppp....",
    "...zzz...zzz....",
    "...ZZZ...ZZZ....",
]
READER_COLOURS = {
    "o": DARKEST, "h": DARKEST, "s": hexcolor("#934c35"), "S": hexcolor("#6f3527"),
    "E": DARKEST, "m": hexcolor("#4b2d23"),
    "j": hexcolor("#e88435"), "J": hexcolor("#f5b05e"),       # orange jacket
    "T": OUTLINE, "t": TEAL_LIGHT,                            # tablet, glowing
    "p": NAVY, "z": OUTLINE, "Z": DARKEST,
}

COMMUTER = [                                                 # waiting for the lift, headphones on
    "....oooooo......",
    "...ohhhhhhoo....",
    "..ohhHhhHhhho...",
    ".kohssssssshok..",
    ".kohsssssssok...",
    ".kosEsssEsso....",
    "..ossssssSso....",
    "..osssmmmsso....",
    "...ossssssoo....",
    "....oSSSSo......",
    "..orrrrSrrrro...",
    ".orrrrrrrrrrro..",
    ".orrorrrrrorro..",
    ".orroRRRRRorro..",
    ".orrorrrrrorro..",
    ".orrorrrrrorro..",
    ".ossorrrrrosso..",
    ".....rrrrr......",
    "....oqqqqqqo....",
    "...oqqqqqqqqo...",
    "...oqqqoqqqqo...",
    "...oqqqoqqqo....",
    "...oqqqoqqqo....",
    "...oqqqoqqqo....",
    "...oqqqoqqqo....",
    "...oqqqoqqqo....",
    "...oqqqoqqqo....",
    "...oqqqoqqqo....",
    "...oqqqoqqqo....",
    "...oqqqoqqqo....",
    "...zzzzoWWWW....",
    "...ZZZZoZZZZ....",
]
COMMUTER_COLOURS = {
    "o": OUTLINE, "h": hexcolor("#211410"), "H": hexcolor("#4b2d23"),
    "s": hexcolor("#d9ab84"), "S": hexcolor("#c38f6b"), "E": NAVY, "m": WOOD_LINE,
    "k": AMBER,                                               # headphones
    "r": hexcolor("#ab4f6d"), "R": hexcolor("#e08594"),       # hoodie
    "q": STEEL_DARK, "z": WHITE, "W": WHITE, "Z": CONCRETE,
}

def cleaning_bot():
    # Two frames: the little light blinks.
    frames = [
        ["...oooooo...", "..oCCCCCCo..", ".oCCCCCCCCo.", "oDDDDDDDDDDo", "oDDLDDDDDDDo", ".oKoooooKo..", "..o......o.."],
        ["...oooooo...", "..oCCCCCCo..", ".oCCCCCCCCo.", "oDDDDDDDDDDo", "oDDdDDDDDDDo", ".oKoooooKo..", "..o......o.."],
    ]
    colours = {"o": OUTLINE, "C": CONCRETE_LIGHT, "D": TEAL, "L": AMBER, "d": TEAL_DARK, "K": DARKEST}
    c = Canvas(12 * len(frames), 7)
    for index, rows in enumerate(frames):
        c.letters(index * 12, 0, rows, colours)
    c.save(OBJECTS + "cleaning_bot.png")


# ── the view across the atrium ──
# The far side of the atrium: hundreds of homes, hazy with distance, gardens
# hanging between them, a glass roof far above. Seen through the open middle of
# the lobby. Tiles sideways every WIDTH pixels.

WIDTH, HEIGHT = 640, 640

def atrium_far():
    # The arcology across the gap: a wall of homes, hazy with distance, from top to bottom.
    c = Canvas(WIDTH, HEIGHT, WALL)
    rng = random.Random(3)
    for floor_y in range(0, HEIGHT, 20):
        c.box(0, floor_y, WIDTH - 1, floor_y + 1, CONCRETE)
        for x in range(0, WIDTH, 16):
            kind = rng.random()
            if kind < 0.55:
                c.box(x + 3, floor_y + 7, x + 8, floor_y + 13, SKY_PALE if rng.random() < 0.6 else LAMP)
            elif kind < 0.7:
                c.box(x + 5, floor_y + 6, x + 8, floor_y + 18, TEAL_LIGHT)
        c.hline(floor_y + 18, WALL_SHADE)                  # railing line
        c.hline(floor_y + 19, WALL_SHADE)
        # gardens spilling over the railings
        x = rng.randint(0, 60)
        while x < WIDTH:
            length = rng.randint(10, 50)
            for gx in range(x, x + length):
                drop = rng.randint(1, 6)
                c.vline(gx % WIDTH, LEAF_LIGHT if rng.random() < 0.7 else LEAF_PALE, floor_y + 18, floor_y + 18 + drop)
            x += length + rng.randint(40, 140)
    c.save(ATRIUM + "atrium_far.png")

# Nearer: three arcology towers with gaps between them, where glass lift shafts
# run and bridges cross. The scene puts lifts and walkers on these spots.
MID_TOWERS = [(30, 160), (240, 410), (480, 610)]
MID_SHAFTS = [189, 434]
MID_BRIDGES = [(160, 240, 120), (160, 240, 250), (160, 240, 470), (410, 480, 170), (410, 480, 330)]
MID_FLOOR = 28

def atrium_mid():
    c = Canvas(WIDTH, HEIGHT)
    rng = random.Random(9)
    for x0, x1 in MID_TOWERS:
        mid_tower(c, x0, x1, rng)
    for x0, x1, y in MID_BRIDGES:
        for x in range(x0, x1):
            c.pixel(x, y - 6, OUTLINE)                     # handrail
            if x % 6 == 0:
                c.vline(x, OUTLINE, y - 5, y - 1)
            c.pixel(x, y, TEAL)
            c.pixel(x, y + 1, STEEL_DARK)
            c.pixel(x, y + 2, OUTLINE)
            if rng.random() < 0.6:                          # hanging garden
                drop = rng.randint(2, 12)
                c.vline(x, LEAF_MID, y + 3, y + 2 + drop)
                c.pixel(x, y + 3 + drop, LEAF_LIGHT)
    for x0 in MID_SHAFTS:
        width = 22
        for y in range(HEIGHT):
            for x in range(x0 + 2, x0 + width - 2):
                if (x + y) % 2 == 0:
                    c.pixel(x, y, TEAL_PALE)
        c.vline(x0, TEAL_DARK)
        c.vline(x0 + 1, TEAL)
        c.vline(x0 + width - 2, TEAL)
        c.vline(x0 + width - 1, TEAL_DARK)
        c.vline(x0 + width // 2, TEAL)                     # the cable
        for y in range(0, HEIGHT, 40):
            c.hline(y, TEAL_DARK, x0, x0 + width - 1)
    c.save(ATRIUM + "atrium_mid.png")

def mid_tower(c, x0, x1, rng):
    # Big glass homes floor after floor, smaller and paler than the ones up close.
    c.box(x0, 0, x1, HEIGHT - 1, CONCRETE_LIGHT)
    for floor_y in range(0, HEIGHT, MID_FLOOR):
        slab = floor_y + MID_FLOOR - 5
        x = x0 + 4
        while x < x1 - 12:
            width = rng.randint(22, 46)
            right = min(x + width, x1 - 4)
            c.box(x, floor_y + 4, right, slab - 1, CONCRETE_DARK)  # window frame
            c.box(x + 1, floor_y + 5, right - 1, slab - 1, WHITE)
            c.box(x + 2, floor_y + 6, right - 2, slab - 1, SKY_PALE)
            for mx in range(x + 12, right - 4, 12):               # mullions
                c.vline(mx, WHITE, floor_y + 6, slab - 1)
            if rng.random() < 0.4:                                # a lamp inside
                lamp_x = rng.randint(x + 4, right - 4)
                c.box(lamp_x - 1, floor_y + 8, lamp_x + 1, floor_y + 8, LAMP_WARM)
            if rng.random() < 0.75:                               # balcony
                c.hline(slab - 5, TEAL, x, right)
                for gx in range(x, right + 1):
                    if (gx + floor_y) % 2 == 0:
                        c.box(gx, slab - 4, gx, slab - 1, TEAL_PALE)
                for gx in range(x + 2, right - 1):
                    if rng.random() < 0.3:
                        c.vline(gx, LEAF_MID, slab - 5 - rng.randint(1, 5), slab - 5)
            x = right + rng.randint(4, 8)
        c.box(x0, slab, x1, slab + 4, CONCRETE)                   # the floor slab
        c.hline(slab, WHITE, x0, x1)
        c.hline(slab + 4, CONCRETE_DARK, x0, x1)
        for vx in range(x0, x1, 3):                               # vines under some slabs
            if rng.random() < 0.15:
                c.vline(vx, LEAF, slab + 5, slab + 5 + rng.randint(1, 6))
    c.vline(x0, WHITE)
    c.vline(x1 - 1, CONCRETE)
    c.vline(x1, CONCRETE_DARK)

def lift_capsule():
    c = Canvas(16, 18)
    c.box(0, 0, 15, 17, OUTLINE)
    c.box(1, 1, 14, 16, CONCRETE_LIGHT)
    c.box(2, 3, 13, 12, SKY_PALE)
    c.box(5, 6, 7, 12, NAVY)                                 # somebody inside
    c.pixel(6, 5, NAVY)
    c.box(1, 13, 14, 16, CONCRETE)
    c.pixel(7, 15, AMBER)
    c.save(ATRIUM + "lift_capsule.png")

def tiny_walker():
    # Someone crossing a bridge, two steps.
    frames = [[".h.", "xxx", "xxx", "l.l"], [".h.", "xxx", "xxx", ".l."]]
    c = Canvas(6, 4)
    for index, rows in enumerate(frames):
        c.letters(index * 3, 0, rows, {"h": hexcolor("#4b2d23"), "x": hexcolor("#ab4f6d"), "l": NAVY})
    c.save(ATRIUM + "tiny_walker.png")


if __name__ == "__main__":
    for folder in (OBJECTS, RESIDENTS, ATRIUM, ZONE + "tiles/"):
        os.makedirs(folder, exist_ok=True)
    draw_tiles()
    draw_facade_tiles()
    entrance_door().save(OBJECTS + "entrance_door.png")
    elevator().save(OBJECTS + "elevator.png")
    parcel_lockers().save(OBJECTS + "parcel_lockers.png")
    info_screen().save(OBJECTS + "info_screen.png")
    tree_planter().save(OBJECTS + "tree_planter.png")
    bench().save(OBJECTS + "bench.png")
    hydroponic_rack().save(OBJECTS + "hydroponic_rack.png")
    cleaning_bot()
    resident(RESIDENTS + "gardener.png", GARDENER, GARDENER_COLOURS)
    resident(RESIDENTS + "reader.png", READER, READER_COLOURS)
    resident(RESIDENTS + "commuter.png", COMMUTER, COMMUTER_COLOURS)
    atrium_far()
    atrium_mid()
    lift_capsule()
    tiny_walker()
