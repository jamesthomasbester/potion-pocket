"""Slice and foot-align the seven generated 4x4 character pose sheets.

Atlas columns: southwest, southeast, northwest, northeast.
Atlas rows: idle, stride, pickup, work. Each game cell is 256x256 RGBA.
Run after replacing any source sheet in art/source/animation-atlases.
"""
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/animation-atlases"
DEST = ROOT / "game/art/animations"
NAMES = ("owner", "brewer", "cashier", "gardener", "customer0", "customer1", "departing")
CELL = 256


def make(name: str) -> None:
    im = Image.open(SOURCE / f"{name}.png").convert("RGBA")
    pieces = isolate(im)
    # One scale per character prevents size jitter between actions/directions.
    largest_w = max(p.width for p in pieces)
    largest_h = max(p.height for p in pieces)
    scale = min(228 / largest_w, 236 / largest_h)
    atlas = Image.new("RGBA", (CELL * 4, CELL * 4))
    for i, part in enumerate(pieces):
        w, h = max(1, round(part.width * scale)), max(1, round(part.height * scale))
        part = part.resize((w, h), Image.Resampling.LANCZOS)
        # Floor contact is always at y=248; each pose pivots around its soles.
        x = (i % 4) * CELL + (CELL - w) // 2
        y = (i // 4) * CELL + 248 - h
        atlas.alpha_composite(part, (x, y))
    DEST.mkdir(parents=True, exist_ok=True)
    atlas.save(DEST / f"{name}.png", optimize=True)
    print(f"{name}: 16 poses, {largest_w}x{largest_h} source max, scale {scale:.3f}")


def isolate(im: Image.Image) -> list[Image.Image]:
    """Prefer whole silhouettes; two sheets have deliberately touching poses."""
    small = im.getchannel("A")
    small.thumbnail((500, 400), Image.Resampling.NEAREST)
    w, h = small.size
    px = small.load()
    seen: set[tuple[int, int]] = set()
    components = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or px[x, y] < 100:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            points = []
            while stack:
                a, b = stack.pop()
                points.append((a, b))
                for u, v in ((a-1, b), (a+1, b), (a, b-1), (a, b+1)):
                    if 0 <= u < w and 0 <= v < h and (u, v) not in seen and px[u, v] >= 100:
                        seen.add((u, v))
                        stack.append((u, v))
            if len(points) > 60:
                components.append(points)

    if len(components) == 16:
        components.sort(key=lambda ps: sum(y for _, y in ps) / len(ps))
        ordered = []
        for row in range(4):
            group = components[row*4:row*4+4]
            ordered += sorted(group, key=lambda ps: sum(x for x, _ in ps) / len(ps))
        parts = []
        for points in ordered:
            mask = Image.new("L", small.size)
            pix = mask.load()
            for x, y in points:
                pix[x, y] = 255
            mask = mask.resize(im.size, Image.Resampling.NEAREST).filter(ImageFilter.MaxFilter(11))
            part = im.copy()
            part.putalpha(ImageChops.multiply(im.getchannel("A"), mask))
            box = part.getchannel("A").getbbox()
            parts.append(part.crop(box))
        return parts

    # The brewer and blue-coat customer poses touch across some row boundaries.
    # Their underlying atlas is regular, so a cell crop keeps every frame isolated.
    parts = []
    for row in range(4):
        for col in range(4):
            bounds = (round(col*im.width/4), round(row*im.height/4),
                      round((col+1)*im.width/4), round((row+1)*im.height/4))
            part = im.crop(bounds)
            opaque = part.getchannel("A").point(lambda a: 255 if a > 18 else 0)
            box = opaque.getbbox()
            if box is None:
                raise ValueError(f"missing frame {row},{col}")
            parts.append(part.crop(box))
    return parts


if __name__ == "__main__":
    for character in NAMES:
        make(character)
