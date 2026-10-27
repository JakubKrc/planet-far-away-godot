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

CONCRETE       = hexcolor("#b5b5bc")
CONCRETE_DARK  = hexcolor("#8b8785")
CONCRETE_LIGHT = hexcolor("#dcdce2")

def concrete():
    return blank(CONCRETE)

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

# ── upper floor and jump platforms ──

def gallery_floor():
    # A floor seen from both sides: planks on top, a finished edge underneath.
    tile = floor_top()
    hline(tile, 13, SLAB_LIGHT)
    hline(tile, 14, WALL_SHADE)
    hline(tile, 15, OUTLINE)
    return tile

def gallery_floor_offset():
    tile = floor_top_offset()
    hline(tile, 13, SLAB_LIGHT)
    hline(tile, 14, WALL_SHADE)
    hline(tile, 15, OUTLINE)
    return tile

# A jump-through shelf platform: planks on top, nothing below. Two tiles wide,
# a left and a right end, each closed off with the outline on its outer side.
def platform_left():
    tile = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    hline(tile, 0, OUTLINE)
    hline(tile, 1, WOOD_LIGHT)
    rect(tile, 0, 2, 15, 3, WOOD)
    hline(tile, 4, WOOD_DARK)
    hline(tile, 5, OUTLINE)
    vline(tile, 0, OUTLINE, 0, 5)
    rect(tile, 3, 6, 4, 9, OUTLINE)       # bracket into the wall
    return tile

def platform_right():
    return platform_left().transpose(Image.FLIP_LEFT_RIGHT)

# ── the arcology's facade ──
# A kit for building floors of any height, 4 tiles (one bay) wide. A floor with a
# window is: window top, window middle (repeated), window bottom, floor band.
# A floor without one is plain wall rows, then the floor band.

SKY = hexcolor("#8cb9e3")
BAY = 4 * T

def bay_row(paint):
    row = Image.new("RGBA", (BAY, T), CONCRETE)
    def fill(x0, y0, x1, y1, colour):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                row.putpixel((x, y), colour)
    fill(0, 0, 0, T - 1, CONCRETE_LIGHT)               # pier edge catching light
    fill(58, 0, 58, T - 1, CONCRETE_DARK)              # panel joint in the pier
    paint(fill)
    return [row.crop((x * T, 0, x * T + T, T)) for x in range(4)]

def window_columns(fill, y0, y1):
    # Frame sides, glass and mullion between rows y0 and y1 of one tile row.
    fill(4, y0, 4, y1, OUTLINE)
    fill(5, y0, 6, y1, WHITE)
    fill(7, y0, 50, y1, SKY)
    fill(28, y0, 29, y1, WHITE)
    fill(51, y0, 52, y1, WHITE)
    fill(53, y0, 53, y1, OUTLINE)

def window_top(fill):
    fill(4, 10, 53, 10, OUTLINE)
    fill(5, 11, 52, 12, WHITE)
    window_columns(fill, 13, 15)
    fill(5, 11, 6, 15, WHITE)
    fill(51, 11, 52, 15, WHITE)
    fill(28, 11, 29, 15, WHITE)

def window_middle(fill):
    window_columns(fill, 0, 15)

def window_bottom(fill):
    window_columns(fill, 0, 2)
    fill(5, 3, 52, 4, WHITE)
    fill(4, 5, 53, 5, OUTLINE)
    fill(2, 6, 55, 6, CONCRETE_LIGHT)                  # sill

def floor_band(fill):
    # Fills the whole row so its top lines up with the floor surface inside.
    fill(0, 0, BAY - 1, 1, CONCRETE_LIGHT)
    fill(0, 2, BAY - 1, 14, CONCRETE_DARK)
    fill(0, 15, BAY - 1, 15, OUTLINE)

def plain_wall(fill):
    fill(29, 0, 29, T - 1, CONCRETE_DARK)              # panel joint

FACADE_ROWS = [window_top, window_middle, window_bottom, floor_band, plain_wall]

LAYOUT = [
    [wall_plain, wall_panel_seam, wall_stripe, wall_crown],
    [wall_baseboard, wall_socket, floor_top, floor_top_offset],
    [ceiling_face, slab_fill, side_left, side_right],
    [gallery_floor, gallery_floor_offset, platform_left, platform_right],
]

DEFAULT_OUTPUT = "scenes/environment/apartment_zone/tiles/apartment_tiles.png"

def main(out_path):
    # Single tiles first, then the facade kit (rows 4-8 in FACADE_ROWS order), then
    # row 9: plain black, for building interior the player never sees into.
    tile_rows = [[draw() for draw in row] for row in LAYOUT]
    tile_rows += [bay_row(paint) for paint in FACADE_ROWS]
    tile_rows.append([blank(hexcolor("#000000")) for _ in range(4)])
    sheet = Image.new("RGBA", (T * 4, T * len(tile_rows)))
    for row_index, row in enumerate(tile_rows):
        for column_index, tile in enumerate(row):
            sheet.paste(tile, (column_index * T, row_index * T))
    sheet.save(out_path)

if __name__ == "__main__":
    # Run from the project folder: python3 tools/art/draw_apartment_tiles.py
    main(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUTPUT)
