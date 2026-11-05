#!/usr/bin/env python3
"""Generates the PropCare Track launcher icon + adaptive foreground.

Run from the project root:  python3 tool/generate_icons.py
Requires Pillow.
"""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "branding")

INK = (8, 13, 28)
INK_2 = (14, 22, 46)
MINT = (92, 242, 180)
CYAN = (76, 201, 240)
CORAL = (255, 122, 89)
WHITE = (242, 247, 255)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, top_left, bottom_right):
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)], fill=lerp(top_left, bottom_right, t))
    # diagonal wash
    overlay = Image.new("L", (size, size), 0)
    od = ImageDraw.Draw(overlay)
    for x in range(0, size * 2, 8):
        od.line([(x, 0), (x - size, size)], fill=18, width=8)
    img = Image.composite(Image.new("RGB", (size, size), (20, 34, 64)), img, overlay)
    return img


def radial_glow(size, center, radius, color, alpha):
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 34
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(alpha * (1 - i / steps) ** 1.6)
        d.ellipse(
            [center[0] - r, center[1] - r, center[0] + r, center[1] + r],
            fill=color + (a,),
        )
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.16))


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def pin_mask(size, cx, cy, r, tip_y, scale=1.0):
    """Teardrop pin as a mask."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    r = r * scale
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    # shoulders -> tip with quadratic-ish sides
    left = (cx - r * 0.96, cy + r * 0.30)
    right = (cx + r * 0.96, cy + r * 0.30)
    tip = (cx, tip_y)
    d.polygon([left, right, tip], fill=255)
    # soften the join
    d.ellipse([cx - r * 0.96, cy - r * 0.30, cx + r * 0.96, cy + r * 0.62], fill=255)
    return mask


def draw_dashed_arc(draw, box, start, end, color, width, dash=26, gap=20):
    a = start
    while a < end:
        b = min(a + dash, end)
        draw.arc(box, a, b, fill=color, width=width)
        a = b + gap


def build_mark(size, scale=1.0, with_bg=False):
    """Returns RGBA image of the brand mark."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = size // 2
    cy = int(size * 0.455)
    r = int(size * 0.205)
    tip = int(size * 0.80)

    # orbit rings
    orbit = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    od = ImageDraw.Draw(orbit)
    box = [int(size * 0.14), int(size * 0.14), int(size * 0.86), int(size * 0.86)]
    od.arc(box, 0, 360, fill=MINT + (58,), width=max(3, int(size * 0.008)))
    draw_dashed_arc(od, box, -60, 210, CYAN + (235,), max(4, int(size * 0.012)))
    od.arc(box, 236, 300, fill=CORAL + (255,), width=max(4, int(size * 0.014)))

    # orbit dot
    ang = math.radians(268)
    ox = cx + math.cos(ang) * (size * 0.36)
    oy = cy + math.sin(ang) * (size * 0.36)
    dot_r = size * 0.028
    od.ellipse([ox - dot_r * 2.4, oy - dot_r * 2.4, ox + dot_r * 2.4, oy + dot_r * 2.4], fill=CORAL + (48,))
    od.ellipse([ox - dot_r, oy - dot_r, ox + dot_r, oy + dot_r], fill=CORAL + (255,))
    img = Image.alpha_composite(img, orbit)

    # pin body with vertical gradient
    mask = pin_mask(size, cx, cy, r, tip, scale=scale)
    body = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    for y in range(size):
        t = max(0.0, min(1.0, (y - (cy - r)) / (tip - (cy - r))))
        bd.line([(0, y), (size, y)], fill=lerp(WHITE, (176, 244, 226), t) + (255,))
    body.putalpha(mask)

    # inner cutout ring (background coloured so it works on any bg)
    hole = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hole)
    hr = int(r * 0.44)
    hd.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=(9, 15, 32, 255))
    # coral core
    cr = int(r * 0.22)
    hd.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=CORAL + (255,))
    img = Image.alpha_composite(img, body)
    img = Image.alpha_composite(img, hole)
    return img


def build_icon(size=1024):
    base = gradient(size, INK, INK_2).convert("RGBA")
    base = Image.alpha_composite(base, radial_glow(size, (int(size * 0.80), int(size * 0.14)), int(size * 0.55), MINT, 60))
    base = Image.alpha_composite(base, radial_glow(size, (int(size * 0.12), int(size * 0.88)), int(size * 0.52), CYAN, 46))
    base = Image.alpha_composite(base, radial_glow(size, (int(size * 0.62), int(size * 0.72)), int(size * 0.36), CORAL, 26))

    # faint grid
    grid = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    step = size // 16
    for i in range(1, 16):
        gd.line([(i * step, 0), (i * step, size)], fill=(255, 255, 255, 7), width=1)
        gd.line([(0, i * step), (size, i * step)], fill=(255, 255, 255, 7), width=1)
    base = Image.alpha_composite(base, grid)

    base = Image.alpha_composite(base, build_mark(size))
    return base.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)

    icon = build_icon(SIZE)
    icon.save(os.path.join(OUT, "app_icon.png"))

    # rounded preview (not used by launchers, handy for docs/marketing)
    rounded = icon.convert("RGBA")
    rounded.putalpha(rounded_mask(SIZE, int(SIZE * 0.225)))
    rounded.save(os.path.join(OUT, "app_icon_rounded.png"))

    # Android adaptive foreground: mark only, inside the 66% safe zone
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    mark = build_mark(SIZE)
    small = mark.resize((int(SIZE * 0.66), int(SIZE * 0.66)), Image.LANCZOS)
    fg.alpha_composite(small, (int(SIZE * 0.17), int(SIZE * 0.17)))
    fg.save(os.path.join(OUT, "app_icon_foreground.png"))

    # transparent logo for splash / docs
    mark.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "logo_mark.png"))
    print("Wrote brand assets to", OUT)


if __name__ == "__main__":
    main()
