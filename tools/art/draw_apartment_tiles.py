# Draws the 16x16 apartment interior tileset, using only colours from palette.png,
# in the flat, outlined style of the castle tiles. Rerun after changing a colour.
import sys
from PIL import Image

def hexcolor(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

OUTLINE    = hexcolor("#3b3842")
WALL       = hexcolor("#dcdce2")
WALL_SHADE = hexcolor("#b5b5bc")
WHITE      = hexcolor("#ffffff")
TEAL_DARK  = hexcolor("#337e87")
TEAL       = hexcolor("#5fb3b8")
TEAL_LIGHT = hexcolor("#9ae0e0")
WOOD_LINE  = hexcolor("#6f3527")
WOOD_DARK  = hexcolor("#934c35")
WOOD       = hexcolor("#b27653")
WOOD_LIGHT = hexcolor("#c38f6b")
SLAB_DARK  = hexcolor("#3b3842")
SLAB       = hexcolor("#8b8785")
SLAB_LIGHT = hexcolor("#b5b5bc")

T = 16

def blank(colour):
    return Image.new("RGBA", (T, T), colour)

def hline(tile, y, colour, x0=0, x1=T - 1):
    for x in range(x0, x1 + 1):
        tile.putpixel((x, y), colour)

def vline(tile, x, colour, y0=0, y1=T - 1):
    for y in range(y0, y1 + 1):
        tile.putpixel((x, y), colour)

def rect(tile, x0, y0, x1, y1, colour):
    for y in range(y0, y1 + 1):
        hline(tile, y, colour, x0, x1)

# A few fixed specks so concrete is not a flat grey, same in every tile.
CONCRETE_SPECKS = [(3, 4), (12, 2), (8, 11), (14, 13)]

def concrete():
    tile = blank(SLAB)
    for x, y in CONCRETE_SPECKS:
        tile.putpixel((x, y), SLAB_LIGHT)
    return tile

# ── background wall (no collision) ──

def wall_plain():
    return blank(WALL)

def wall_panel_seam():
    tile = blank(WALL)
    vline(tile, 0, WALL_SHADE)
    return tile

def wall_baseboard():
    tile = blank(WALL)
    hline(tile, 11, TEAL_LIGHT)
    rect(tile, 0, 12, 15, 14, TEAL)
    hline(tile, 15, TEAL_DARK)
    return tile

def wall_crown():
    tile = blank(WALL)
    rect(tile, 0, 0, 15, 1, TEAL_DARK)
    hline(tile, 2, TEAL)
    hline(tile, 3, WALL_SHADE)
    return tile

def wall_stripe():
    tile = blank(WALL)
    hline(tile, 7, TEAL_LIGHT)
    hline(tile, 8, TEAL)
    return tile

def wall_socket():
    tile = wall_baseboard()
    rect(tile, 6, 6, 10, 9, OUTLINE)
    rect(tile, 7, 7, 9, 8, WHITE)
    tile.putpixel((7, 7), OUTLINE)
    tile.putpixel((9, 7), OUTLINE)
    return tile

# ── solid structure (collision) ──

def floor_top():
    tile = concrete()
    hline(tile, 0, OUTLINE)
    hline(tile, 1, WOOD_LIGHT)
    rect(tile, 0, 2, 15, 4, WOOD)
    hline(tile, 5, WOOD_DARK)
    hline(tile, 6, OUTLINE)
    vline(tile, 7, WOOD_LINE, 2, 4)   # plank joint
    return tile

def floor_top_offset():
    tile = floor_top()
    vline(tile, 7, WOOD, 2, 4)
    vline(tile, 15, WOOD_LINE, 2, 4)
    return tile

def ceiling_face():
    tile = concrete()
    hline(tile, 13, SLAB_LIGHT)
    hline(tile, 14, WALL_SHADE)
    hline(tile, 15, OUTLINE)
    return tile

def slab_fill():
    return concrete()

def side_left():
    # Solid wall on the room's left: its face looks right, into the room.
    tile = concrete()
    vline(tile, 14, SLAB_LIGHT)
    vline(tile, 15, OUTLINE)
    return tile

def side_right():
    return side_left().transpose(Image.FLIP_LEFT_RIGHT)

LAYOUT = [
    [wall_plain, wall_panel_seam, wall_stripe, wall_crown],
    [wall_baseboard, wall_socket, floor_top, floor_top_offset],
    [ceiling_face, slab_fill, side_left, side_right],
]

DEFAULT_OUTPUT = "scenes/environment/apartment_zone/tiles/apartment_tiles.png"

def main(out_path):
    sheet = Image.new("RGBA", (T * len(LAYOUT[0]), T * len(LAYOUT)))
    for row_index, row in enumerate(LAYOUT):
        for column_index, draw in enumerate(row):
            sheet.paste(draw(), (column_index * T, row_index * T))
    sheet.save(out_path)

if __name__ == "__main__":
    # Run from the project folder: python3 tools/art/draw_apartment_tiles.py
    main(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUTPUT)
