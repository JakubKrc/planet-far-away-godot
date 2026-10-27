# Draws the apartment furniture with the same rules as the tiles: colours from
# palette.png, flat fills, a light top row, a dark bottom row, 1px outline.
# Sizes are measured against Igor, who is 32 px tall (about 18 px per metre).
# Run from the project folder: python3 tools/art/draw_apartment_furniture.py
from PIL import Image

OUTPUT_DIR = "scenes/environment/apartment_zone/objects/"

def hexcolor(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

CLEAR = (0, 0, 0, 0)
OUTLINE = hexcolor("#3b3842")
WHITE, PALE, GREY, MID_GREY = hexcolor("#ffffff"), hexcolor("#dcdce2"), hexcolor("#b5b5bc"), hexcolor("#8b8785")
ORANGE_DARK, ORANGE, ORANGE_LIGHT = hexcolor("#c45a1f"), hexcolor("#e88435"), hexcolor("#f5b05e")
TEAL_DARK, TEAL, TEAL_LIGHT = hexcolor("#337e87"), hexcolor("#5fb3b8"), hexcolor("#9ae0e0")
WOOD_DARKEST, WOOD_DARK, WOOD, WOOD_LIGHT = hexcolor("#4b2d23"), hexcolor("#6f3527"), hexcolor("#934c35"), hexcolor("#b27653")
GUITAR_WOOD, GUITAR_LIGHT = hexcolor("#c38f6b"), hexcolor("#e8c7a0")
BLUE_DARK, BLUE, BLUE_LIGHT, SKY, SKY_PALE = hexcolor("#274569"), hexcolor("#3a6aa1"), hexcolor("#5d8ac7"), hexcolor("#8cb9e3"), hexcolor("#cfe6f7")
GREEN, GREEN_LIGHT = hexcolor("#447835"), hexcolor("#7aa84a")
RED_DARK, RED, RED_LIGHT = hexcolor("#8a3636"), hexcolor("#db1616"), hexcolor("#f0a8a0")
AMP_BLACK, AMP_GREY, GRILLE, GRILLE_DARK = hexcolor("#1f1d26"), hexcolor("#3b3842"), hexcolor("#5d5a66"), hexcolor("#3b3842")
GOLD = hexcolor("#f5b05e")


class Sprite:
    def __init__(self, width, height):
        self.image = Image.new("RGBA", (width, height), CLEAR)

    def box(self, x0, y0, x1, y1, fill, top=None, bottom=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                colour = fill
                if top is not None and y == y0:
                    colour = top
                if bottom is not None and y == y1:
                    colour = bottom
                self.image.putpixel((x, y), colour)

    def pixel(self, x, y, colour):
        self.image.putpixel((x, y), colour)

    def hline(self, y, x0, x1, colour):
        self.box(x0, y, x1, y, colour)

    def vline(self, x, y0, y1, colour):
        self.box(x, y0, x, y1, colour)

    # Outline every transparent pixel that touches the silhouette, like the tiles.
    def outline(self):
        width, height = self.image.size
        solid = set()
        for y in range(height):
            for x in range(width):
                if self.image.getpixel((x, y))[3] > 0:
                    solid.add((x, y))
        for x, y in solid:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in solid:
                    self.image.putpixel((nx, ny), OUTLINE)

    # Paints a picture written as rows of letters; "." stays transparent.
    def paint(self, rows, colours, left=1, top=1):
        for y, row in enumerate(rows):
            for x, letter in enumerate(row):
                if letter != ".":
                    self.image.putpixel((left + x, top + y), colours[letter])

    def save(self, name):
        self.image.save(OUTPUT_DIR + name)


def couch():
    s = Sprite(44, 20)
    s.box(5, 1, 38, 10, ORANGE, top=ORANGE_LIGHT, bottom=ORANGE_DARK)   # backrest
    s.box(5, 10, 38, 14, ORANGE, top=ORANGE_LIGHT, bottom=ORANGE_DARK)  # seat
    s.box(1, 6, 6, 15, ORANGE, top=ORANGE_LIGHT, bottom=ORANGE_DARK)    # armrests
    s.box(37, 6, 42, 15, ORANGE, top=ORANGE_LIGHT, bottom=ORANGE_DARK)
    s.box(1, 15, 42, 16, ORANGE_DARK)
    s.hline(10, 5, 38, ORANGE_DARK)                                   # back / seat seam
    s.vline(21, 11, 14, ORANGE_DARK)                                  # two seat cushions
    s.vline(22, 11, 14, ORANGE_DARK)
    s.box(28, 5, 33, 9, TEAL, top=TEAL_LIGHT, bottom=TEAL_DARK)       # throw cushion
    s.outline()
    for x in (3, 4, 39, 40):                                          # legs
        s.pixel(x, 18, WOOD_DARK)
        s.pixel(x, 19, OUTLINE)
    s.save("couch.png")


def bed():
    s = Sprite(54, 22)
    s.box(1, 1, 5, 18, WOOD, top=WOOD_LIGHT, bottom=WOOD_DARK)        # headboard
    s.box(47, 9, 51, 18, WOOD, top=WOOD_LIGHT, bottom=WOOD_DARK)      # footboard
    s.box(5, 15, 47, 18, WOOD, top=WOOD_LIGHT, bottom=WOOD_DARK)      # frame
    s.box(5, 10, 47, 14, PALE, top=WHITE, bottom=GREY)                # mattress
    s.box(7, 7, 15, 10, WHITE, bottom=PALE)                           # pillow
    s.box(18, 9, 46, 14, BLUE, top=BLUE_LIGHT, bottom=BLUE_DARK)      # blanket
    s.hline(11, 18, 46, BLUE_LIGHT)
    s.vline(18, 9, 14, BLUE_DARK)
    s.outline()
    for x in (2, 3, 49, 50):
        s.pixel(x, 20, WOOD_DARKEST)
        s.pixel(x, 21, OUTLINE)
    s.save("bed.png")


def kitchen_counter():
    s = Sprite(50, 20)
    s.box(1, 1, 48, 3, WOOD_LIGHT, top=GUITAR_LIGHT, bottom=WOOD)     # worktop
    s.box(2, 4, 47, 18, PALE, top=GREY, bottom=GREY)                  # cabinets
    for x in (17, 32):                                                # module gaps
        s.vline(x, 4, 18, GREY)
    for x in (9, 40):                                                 # handles
        s.vline(x, 7, 9, MID_GREY)
    s.box(19, 6, 30, 16, OUTLINE)                                     # oven door
    s.box(20, 9, 29, 15, BLUE_DARK, top=BLUE)                         # oven window
    s.hline(7, 20, 29, MID_GREY)                                      # oven handle
    s.outline()
    for x in (21, 24, 27):                                            # burners on top
        s.pixel(x, 0, OUTLINE)
    s.pixel(41, 0, MID_GREY)                                          # tap
    s.save("kitchen.png")


def kitchen_cabinets():
    s = Sprite(50, 12)
    s.box(1, 1, 48, 10, PALE, top=WHITE, bottom=GREY)
    for x in (17, 32):
        s.vline(x, 1, 10, GREY)
    for x in (15, 19, 34):
        s.vline(x, 7, 8, MID_GREY)
    s.outline()
    s.save("kitchen_cabinets.png")


# Window frames sit around a hole in the wall tiles; the middle stays transparent so
# whatever is behind the room (the city, later) shows through.
def window_frame(hole_width, hole_height, mullions, file_name):
    border = 2
    width = hole_width + 2 * border + 2
    height = hole_height + 2 * border + 4
    s = Sprite(width, height)
    left, top = 1, 1
    right, bottom = left + hole_width + 2 * border - 1, top + hole_height + 2 * border - 1
    s.box(left, top, right, top + border - 1, WHITE)                   # top
    s.box(left, bottom - border + 1, right, bottom, GREY)              # bottom
    s.box(left, top, left + border - 1, bottom, PALE)                  # sides
    s.box(right - border + 1, top, right, bottom, PALE)
    for x in mullions:                                                 # glazing bars
        s.box(left + border + x, top, left + border + x + 1, bottom, PALE)
    s.box(0, bottom + 1, width - 1, bottom + 2, PALE, top=WHITE)       # sill
    s.outline()
    # The outline also traced the inside of the hole; that edge stays visible
    # and reads as the window reveal.
    s.save(file_name)


def electric_guitar():
    s = Sprite(13, 24)
    s.paint([
        "....HH.....",
        "....HH.....",
        ".....N.....",
        ".....N.....",
        ".....N.....",
        ".....N.....",
        ".....N.....",
        ".....N.....",
        ".R...N...R.",
        ".Rl..N..lR.",
        ".RlllNlllR.",
        ".RRRWPWRRR.",
        "..RRWWWRR..",
        "..RRWPWRR..",
        ".RRRWWWRRR.",
        "RRRRRWRRRKR",
        "RRRRRBRRRKR",
        "RRRRRRRRRRR",
        ".dRRRRRRRd.",
        "..ddddddd..",
    ], {"H": WOOD_DARKEST, "N": WOOD_LIGHT, "R": RED, "l": RED_LIGHT, "d": RED_DARK,
        "W": WHITE, "P": MID_GREY, "B": OUTLINE, "K": GOLD})
    s.outline()
    for x in (3, 9):                                                  # guitar stand legs
        s.pixel(x, 22, OUTLINE)
        s.pixel(x, 23, OUTLINE)
    s.save("electric_guitar.png")


def combo_amp():
    s = Sprite(20, 14)
    rows = ["CCCCCCCCCCCCCCCCCC",
            "CkCkCkCkCaaaaaaawC",
            "CCCCCCCCCCCCCCCCCC"]
    for i in range(8):
        rows.append("C" + ("g" if i % 2 == 0 else "G") * 16 + "C")
    rows.append("CCCCCCCCCCCCCCCCCC")
    s.paint(rows, {"C": AMP_BLACK, "a": AMP_GREY, "k": GOLD, "w": WHITE, "g": GRILLE, "G": GRILLE_DARK})
    s.outline()
    s.save("combo_amp.png")


def balcony_railing(width):
    # Thin rails and posts, so the city stays visible through it.
    s = Sprite(width, 20)
    s.box(1, 1, width - 2, 2, PALE, top=WHITE)                       # hand rail
    s.box(1, 12, width - 2, 12, GREY)                                # lower rail
    for x in range(1, width - 1, 16):
        s.box(x, 1, x + 1, 18, PALE, bottom=GREY)                     # posts
    s.box(width - 3, 1, width - 2, 18, PALE, bottom=GREY)
    s.outline()
    s.save("balcony_railing.png")


def balcony_door():
    # Glass door in the outer wall, 16 x 48 to fill the opening.
    s = Sprite(16, 48)
    s.box(0, 0, 15, 47, PALE, top=WHITE, bottom=GREY)                # frame
    s.box(2, 2, 13, 46, SKY)                                         # glass
    for i in range(10):                                              # reflection
        s.pixel(4 + i // 2, 6 + i, SKY_PALE)
        s.pixel(9 + i // 2, 20 + i, SKY_PALE)
    s.box(11, 24, 12, 27, GOLD)                                      # handle
    s.save("balcony_door.png")


def apartment_door():
    s = Sprite(22, 36)
    s.box(1, 1, 20, 34, PALE, top=WHITE)                              # frame
    s.box(3, 3, 18, 34, TEAL, top=TEAL_LIGHT, bottom=TEAL_DARK)       # door
    s.box(5, 6, 16, 15, TEAL_LIGHT)                                   # upper panel
    s.box(5, 19, 16, 31, TEAL_LIGHT)                                  # lower panel
    s.box(6, 7, 15, 14, TEAL)
    s.box(6, 20, 15, 30, TEAL)
    s.box(15, 17, 16, 18, GOLD)                                       # handle
    s.outline()
    s.save("apartment_door.png")


if __name__ == "__main__":
    couch()
    bed()
    kitchen_counter()
    kitchen_cabinets()
    window_frame(32, 32, [15], "window.png")
    window_frame(64, 48, [20, 42], "big_window.png")
    electric_guitar()
    combo_amp()
    apartment_door()
    balcony_railing(130)
    balcony_door()
