"""Recolour tiered crop and potion sprites into the Recipe Book's new families.

Only pixels inside a source hue band (or, for petals, near-white pixels) are
changed, so outlines, corks, gold trims and highlights keep their colour.
Run from the project root: python3 tools/make_variants.py
"""
import colorsys
from pathlib import Path
from PIL import Image

ART = Path(__file__).resolve().parents[1] / "game" / "art"

def in_band(h, lo, hi):
    return lo <= h <= hi if lo <= hi else h >= lo or h <= hi

def shift(src, dst, band, target, sat=1.0):
    """Move hues inside band (degrees) to target, keeping each pixel's offset from the band centre."""
    lo, hi = band
    centre = ((lo + hi) / 2 if lo <= hi else ((lo + hi + 360) / 2) % 360)
    im = Image.open(ART / src).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            deg = h * 360
            if s < 0.18 or not in_band(deg, lo, hi):
                continue
            off = ((deg - centre + 540) % 360) - 180
            nh = ((target + off * 0.6) % 360) / 360
            nr, ng, nb = colorsys.hls_to_rgb(nh, l, min(1.0, s * sat))
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    im.save(ART / dst)

def gild_petals(src, dst):
    """Turn white and lilac petals gold while leaving green leaves alone."""
    im = Image.open(ART / src).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            deg = h * 360
            leaf = in_band(deg, 60, 175) and s > 0.2
            petal = not leaf and (l > 0.55 or in_band(deg, 250, 330))
            if not petal:
                continue
            nr, ng, nb = colorsys.hls_to_rgb(44 / 360, 0.38 + l * 0.42, 0.9)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    im.save(ART / dst)

GREEN = (70, 160)
PURPLE = (245, 310)
ORANGE = (20, 55)

for t in (1, 2, 3):
    shift(f"mint_t{t}.png", f"ember_t{t}.png", GREEN, 12, 1.1)
    shift(f"mint_t{t}.png", f"frost_t{t}.png", GREEN, 192, 0.8)
    gild_petals(f"moonflower_t{t}.png", f"starbloom_t{t}.png")
    shift(f"dream_t{t}.png", f"potion2_t{t}.png", PURPLE, 135)
    shift(f"dream_t{t}.png", f"potion3_t{t}.png", PURPLE, 358, 1.1)
    shift(f"dream_t{t}.png", f"potion4_t{t}.png", PURPLE, 192)
    shift(f"dream_t{t}.png", f"potion5_t{t}.png", PURPLE, 48, 1.05)
    shift(f"energy_t{t}.png", f"potion6_t{t}.png", ORANGE, 350, 1.1)
    shift(f"dream_t{t}.png", f"potion7_t{t}.png", PURPLE, 322)
print("variants written to", ART)
