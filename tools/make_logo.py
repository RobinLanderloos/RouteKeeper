"""Draws RouteKeeper's project logo (a dungeon map on dark parchment with a
dotted route between numbered pins, ending at a skull-free boss marker) to
media/logo.png. Original artwork, no game assets.

    python tools/make_logo.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 4  # supersampling
W = 400 * S
COPPER = (210, 125, 69)
GOLD = (236, 200, 120)
INK = (58, 44, 30)

img = Image.new("RGB", (W, W), (20, 16, 12))


def p(x, y):
    return (x * S, y * S)


# Parchment sheet with a soft warm light in the middle.
sheet = Image.new("L", (W, W), 0)
ImageDraw.Draw(sheet).rounded_rectangle(p(34, 34) + p(366, 366), radius=26 * S, fill=255)
img.paste(Image.new("RGB", (W, W), (64, 50, 36)), (0, 0), sheet)
light = Image.new("L", (W, W), 0)
ImageDraw.Draw(light).ellipse(p(60, 60) + p(340, 340), fill=255)
light = light.filter(ImageFilter.GaussianBlur(60 * S))
img.paste(Image.new("RGB", (W, W), (112, 90, 62)), (0, 0), Image.composite(light, Image.new("L", (W, W), 0), sheet))
d = ImageDraw.Draw(img)

# Cave rooms: rounded blobs joined by corridors, drawn in dark ink.
rooms = [(98, 288, 44), (178, 214, 38), (268, 254, 34), (292, 132, 46), (150, 116, 30)]
for (ax, ay, _), (bx, by, _) in zip(rooms, rooms[1:]):
    d.line(p(ax, ay) + p(bx, by), fill=INK, width=26 * S)
for x, y, r in rooms:
    d.ellipse(p(x - r, y - r) + p(x + r, y + r), fill=INK)

# The route: a dotted curve through the rooms.
route = [(98, 288), (178, 214), (268, 254), (292, 132)]


def bezier(a, b, bend):
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    nx, ny = -(b[1] - a[1]), b[0] - a[0]
    n = math.hypot(nx, ny) or 1
    c = (mx + nx / n * bend, my + ny / n * bend)
    pts = []
    for i in range(41):
        t = i / 40
        pts.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t * t * b[0],
                    (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t * t * b[1]))
    return pts


path = []
for i, (a, b) in enumerate(zip(route, route[1:])):
    path += bezier(a, b, 22 if i % 2 == 0 else -22)
dist = 0
last = path[0]
for pt in path[1:]:
    dist += math.hypot(pt[0] - last[0], pt[1] - last[1])
    if int(dist / 9) % 2 == 0:
        d.line(p(*last) + p(*pt), fill=GOLD, width=5 * S)
    last = pt

# Numbered pins on the first three stops, a flag on the last.
try:
    font = ImageFont.truetype("arialbd.ttf", 22 * S)
except OSError:
    font = ImageFont.load_default()
for i, (x, y) in enumerate(route[:-1], 1):
    d.ellipse(p(x - 19, y - 19) + p(x + 19, y + 19), fill=(30, 22, 16))
    d.ellipse(p(x - 16, y - 16) + p(x + 16, y + 16), fill=COPPER)
    d.text(p(x, y + 1), str(i), fill=(255, 244, 225), font=font, anchor="mm")

fx, fy = route[-1]
halo = Image.new("L", (W, W), 0)
ImageDraw.Draw(halo).ellipse(p(fx - 46, fy - 46) + p(fx + 46, fy + 46), fill=255)
halo = halo.filter(ImageFilter.GaussianBlur(18 * S))
img.paste(Image.new("RGB", (W, W), COPPER), (0, 0), halo.point(lambda v: int(v * 0.6)))
d = ImageDraw.Draw(img)
d.rounded_rectangle(p(fx - 3, fy - 44) + p(fx + 3, fy + 14), radius=2 * S, fill=(245, 232, 205))
d.polygon([p(fx + 3, fy - 44), p(fx + 40, fy - 32), p(fx + 3, fy - 20)], fill=COPPER)
d.ellipse(p(fx - 12, fy + 8) + p(fx + 12, fy + 18), fill=(30, 22, 16))

# Thin copper frame on the sheet.
d.rounded_rectangle(p(46, 46) + p(354, 354), radius=18 * S, outline=COPPER, width=3 * S)

out = os.path.join(os.path.dirname(__file__), "..", "media", "logo.png")
img.resize((400, 400), Image.LANCZOS).save(out)
print(os.path.normpath(out))
