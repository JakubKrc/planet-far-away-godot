# Draws the futuristic city background as parallax layers, using only colours
# from palette.png. Each layer tiles seamlessly sideways (width WIDTH).
# Run from the project folder: python3 tools/art/draw_city.py
import random
from PIL import Image

OUTPUT_DIR = "scenes/environment/city/"
WIDTH, HEIGHT = 640, 480
# Everything is drawn as if the image were 300 tall, then pushed down by SHIFT so
# there is extra sky above; buildings still run to the bottom. The extra height
# keeps a zoomed-out camera from seeing past the image.
SHIFT = 120
BOTTOM = HEIGHT - 1 - SHIFT

def hexcolor(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

CLEAR = (0, 0, 0, 0)
WHITE, PALE = hexcolor("#ffffff"), hexcolor("#dcdce2")
SKY_HIGH, SKY_MID, SKY_LOW = hexcolor("#8cb9e3"), hexcolor("#cfe6f7"), hexcolor("#ffffff")
FAR, FAR_LIGHT = hexcolor("#dcdce2"), hexcolor("#ffffff")   # hazy, lighter than the sky
MID_DARK, MID, MID_LIGHT = hexcolor("#3a6aa1"), hexcolor("#5d8ac7"), hexcolor("#8cb9e3")
NEAR_DARK, NEAR, NEAR_LIGHT = hexcolor("#111a2e"), hexcolor("#274569"), hexcolor("#3a6aa1")
WINDOW_COOL, WINDOW_WARM = hexcolor("#cfe6f7"), hexcolor("#faf3a0")
TEAL_LIGHT, TEAL = hexcolor("#9ae0e0"), hexcolor("#5fb3b8")
FAR_GREEN = hexcolor("#c9e68a")                              # gardens, faded by distance
FAR_SHADE = hexcolor("#b5b5bc")
GREEN, GREEN_LIGHT = hexcolor("#447835"), hexcolor("#9ec96a")


class Layer:
    def __init__(self):
        self.image = Image.new("RGBA", (WIDTH, HEIGHT), CLEAR)

    # x wraps around, so shapes crossing the right edge continue on the left
    # and the layer tiles without a seam.
    def pixel(self, x, y, colour):
        y += SHIFT
        if 0 <= y < HEIGHT:
            self.image.putpixel((x % WIDTH, y), colour)

    def box(self, x0, y0, x1, y1, colour):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.pixel(x, y, colour)

    def dome(self, centre_x, base_y, radius, colour):
        for y in range(base_y - radius, base_y + 1):
            for x in range(centre_x - radius, centre_x + radius + 1):
                if (x - centre_x) ** 2 + ((y - base_y) * 1.3) ** 2 <= radius ** 2:
                    self.pixel(x, y, colour)

    def save(self, name):
        self.image.save(OUTPUT_DIR + name)


def sky():
    # Deeper blue at the top, paler towards the horizon, checker-dithered between.
    layer = Layer()
    bands = [(0, SKY_HIGH), (110, SKY_MID)]
    for y in range(-SHIFT, HEIGHT - SHIFT):   # the whole image, extra sky included
        colour = SKY_HIGH if y < bands[1][0] else SKY_MID
        for x in range(WIDTH):
            near_border = bands[1][0] - 8 <= y < bands[1][0]
            if near_border and (x + y) % 2 == 0:
                layer.pixel(x, y, SKY_MID)
            else:
                layer.pixel(x, y, colour)
    for x0, y0, length in ((80, 40, 30), (300, 25, 44), (470, 55, 26)):   # thin clouds
        layer.box(x0, y0, x0 + length, y0, WHITE)
        layer.box(x0 + 6, y0 - 1, x0 + length - 8, y0 - 1, WHITE)
    layer.save("city_sky.png")


def far_arcologies(rng):
    # Huge, hazy, stepped megastructures on the horizon, with sky between them.
    layer = Layer()
    arcologies = []
    x = 0
    while x < WIDTH - 40:
        width = rng.randint(40, 80)
        top = rng.randint(60, 125)
        steps = rng.randint(2, 4)
        step_height = (BOTTOM + 1 - top) // (steps * 2)
        arcologies.append({"x": x, "width": width, "top": top, "steps": steps, "step_height": step_height})
        for step in range(steps):
            inset = (steps - 1 - step) * width // (2 * steps + 2)
            layer.box(x + inset, top + step * step_height, x + width - inset, BOTTOM, FAR)
        layer.box(x + width // 2, top - rng.randint(10, 30), x + width // 2, top, FAR)   # spire
        for wy in range(top + 6, BOTTOM + 1, 6):
            for wx in range(x + 4, x + width - 3, 4):
                if rng.random() < 0.2:
                    layer.pixel(wx, wy, FAR_LIGHT)
        x += width + rng.randint(8, 30)
    far_bridges(layer, arcologies)
    layer.save("city_far.png")

def far_bridges(layer, arcologies):
    # Arcologies are linked: hazy skybridges between neighbours, at a few heights.
    # Their own random numbers, so adding them does not move the buildings.
    bridge_rng = random.Random(21)
    first_again = dict(arcologies[0], x=arcologies[0]["x"] + WIDTH)   # the layer wraps around
    for left, right in zip(arcologies, arcologies[1:] + [first_again]):
        lowest_top = max(left["top"], right["top"])
        for _ in range(bridge_rng.randint(1, 3)):
            y = bridge_rng.randint(lowest_top + 10, BOTTOM - 40)
            # From wall to wall at this height: the buildings step in higher up.
            start = left["x"] + left["width"] - step_inset(left, y) + 1
            end = right["x"] + step_inset(right, y) - 1
            layer.box(start, y, end, y + 3, FAR)
            layer.box(start, y, end, y, FAR_LIGHT)
            layer.box(start, y + 3, end, y + 3, FAR_SHADE)
            for bx in range(start, end, 3):               # a garden hanging off some
                if bridge_rng.random() < 0.35:
                    layer.box(bx, y + 3, bx, y + 3 + bridge_rng.randint(0, 3), FAR_GREEN)


# How far the arcology's outline is stepped in from its full width at height y.
def step_inset(arcology, y):
    steps, width = arcology["steps"], arcology["width"]
    step = min(steps - 1, (y - arcology["top"]) // arcology["step_height"])
    return (steps - 1 - step) * width // (2 * steps + 2)


def mid_towers(rng):
    # Slim towers with window grids, garden terraces and skybridges.
    layer = Layer()
    towers = []
    x = 0
    while x < WIDTH - 20:
        width = rng.randint(22, 40)
        top = rng.randint(95, 150)
        towers.append((x, width, top))
        x += width + rng.randint(14, 34)
    for x0, width, top in towers:
        layer.box(x0, top, x0 + width, BOTTOM, MID)
        layer.box(x0, top, x0 + 1, BOTTOM, MID_LIGHT)                 # lit edge
        layer.box(x0 + width - 1, top, x0 + width, BOTTOM, MID_DARK)  # shaded edge
        if rng.random() < 0.5:
            layer.dome(x0 + width // 2, top, width // 2 - 2, MID)          # rounded crown
        else:
            layer.box(x0 + width // 2, top - rng.randint(12, 28), x0 + width // 2, top, MID_DARK)
        for wy in range(top + 6, BOTTOM + 1, 6):
            for wx in range(x0 + 4, x0 + width - 3, 4):
                if rng.random() < 0.55:
                    layer.pixel(wx, wy, WINDOW_COOL)
        for terrace_y in range(top + 20, BOTTOM - 19, rng.randint(28, 40)):
            layer.box(x0 - 2, terrace_y, x0 + width + 2, terrace_y + 1, PALE)
            for gx in range(x0 - 1, x0 + width + 2, 2):
                layer.pixel(gx, terrace_y - 1, GREEN_LIGHT if rng.random() < 0.6 else GREEN)
    for (x0, width, top), (x1, _, top1) in zip(towers, towers[1:]):
        if rng.random() < 0.6:                                             # skybridge
            y = max(top, top1) + rng.randint(15, 40)
            layer.box(x0 + width, y - 2, x1, y + 3, MID_DARK)
            layer.box(x0 + width, y - 2, x1, y - 2, TEAL_LIGHT)
            for wx in range(x0 + width + 2, x1 - 1, 3):          # windows along it
                layer.pixel(wx, y, WINDOW_COOL)
            garden_rng = random.Random(x0)
            for gx in range(x0 + width, x1):
                if garden_rng.random() < 0.4:
                    layer.box(gx, y + 4, gx, y + 4 + garden_rng.randint(0, 4), GREEN_LIGHT)
    layer.save("city_mid.png")


def near_towers(rng):
    # Darker, closer towers whose lit windows glow warm.
    layer = Layer()
    towers = []
    x = 0
    while x < WIDTH - 30:
        width = rng.randint(34, 56)
        top = rng.randint(150, 195)
        towers.append((x, width, top))
        layer.box(x, top, x + width, BOTTOM, NEAR)
        layer.box(x, top, x + 1, BOTTOM, NEAR_LIGHT)
        layer.box(x, top, x + width, top + 1, NEAR_LIGHT)
        layer.box(x + width // 2 - 1, top - rng.randint(6, 16), x + width // 2, top, NEAR_DARK)
        for wy in range(top + 6, BOTTOM + 1, 5):
            for wx in range(x + 4, x + width - 3, 5):
                if rng.random() < 0.35:
                    layer.box(wx, wy, wx + 1, wy, WINDOW_WARM)
        layer.box(x + 3, top + 3, x + 3, BOTTOM, TEAL)                # light strip
        x += width + rng.randint(30, 60)
    near_bridges(layer, towers)
    layer.save("city_near.png")

def near_bridges(layer, towers):
    # Close by, a covered walkway or two with lit windows along it.
    bridge_rng = random.Random(22)
    for (x0, width0, top0), (x1, _, top1) in zip(towers, towers[1:]):
        if bridge_rng.random() < 0.4:
            continue
        y = bridge_rng.randint(max(top0, top1) + 12, BOTTOM - 30)
        start, end = x0 + width0 + 1, x1 - 1
        layer.box(start, y, end, y + 5, NEAR_DARK)
        layer.box(start, y, end, y, NEAR_LIGHT)
        for wx in range(start + 2, end - 1, 4):
            layer.box(wx, y + 2, wx + 1, y + 3, WINDOW_WARM if bridge_rng.random() < 0.6 else TEAL)


# ── drones ──
# Each drone image holds its frames side by side (rotors spun out, then tucked in);
# the game flips between them. Letters: X body, O outline, L light, H highlight.

def drone(name, frames, colours):
    width = len(frames[0][0])
    height = len(frames[0])
    image = Image.new("RGBA", (width * len(frames), height), CLEAR)
    for index, rows in enumerate(frames):
        for y, row in enumerate(rows):
            for x, letter in enumerate(row):
                if letter != ".":
                    image.putpixel((index * width + x, y), colours[letter])
    image.save(OUTPUT_DIR + name)


def drones():
    # Far away: three pixels and a light.
    drone("drone_far.png", [[".X.", "XLX"]], {"X": MID, "L": WINDOW_WARM})
    drone("drone_mid.png", [
        ["XX.X.XX", ".XXXXX.", "..XLX.."],
        [".X.X.X.", ".XXXXX.", "..XLX.."],
    ], {"X": MID_DARK, "L": WINDOW_WARM})
    drone("drone_near.png", [
        ["XXX.......XXX", "..X.......X..", "..XXXXXXXXX..", "...XXXXXXX...", ".....XLX....."],
        [".X.........X.", "..X.......X..", "..XXXXXXXXX..", "...XXXXXXX...", ".....XLX....."],
    ], {"X": NEAR_DARK, "L": TEAL_LIGHT})
    # The one that passes in front of the building: bigger, outlined, a cargo box.
    front = {"O": hexcolor("#1f1d26"), "X": hexcolor("#5d5a66"), "H": hexcolor("#8b8785"),
             "L": hexcolor("#db1616"), "C": hexcolor("#c45a1f"), "c": hexcolor("#7a3414")}
    drone("drone_front.png", [
        ["OOOOOOO..............OOOOOOO",
         "...OO..................OO...",
         "...OOOOOOOOOOOOOOOOOOOOOO...",
         "....OHHHHHHHHHHHHHHHHHHO....",
         "....OXXXXXXXXXXXXXXXXXXO....",
         ".....OXXXXXXXLLXXXXXXXO.....",
         "......OOOOOOOOOOOOOOOO......",
         "..........O......O..........",
         ".........OCCCCCCCCO.........",
         ".........OCCCCCCCCO.........",
         ".........OccccccccO.........",
         ".........OOOOOOOOOO........."],
        ["..OOO..................OOO..",
         "...OO..................OO...",
         "...OOOOOOOOOOOOOOOOOOOOOO...",
         "....OHHHHHHHHHHHHHHHHHHO....",
         "....OXXXXXXXXXXXXXXXXXXO....",
         ".....OXXXXXXXLLXXXXXXXO.....",
         "......OOOOOOOOOOOOOOOO......",
         "..........O......O..........",
         ".........OCCCCCCCCO.........",
         ".........OCCCCCCCCO.........",
         ".........OccccccccO.........",
         ".........OOOOOOOOOO........."],
    ], front)


if __name__ == "__main__":
    import os
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    rng = random.Random(4)   # fixed seed: the same city every run
    sky()
    far_arcologies(rng)
    mid_towers(rng)
    near_towers(rng)
    drones()
