"""Slice and foot-align the seven generated 4x4 character pose sheets.

Atlas columns: southwest, southeast, northwest, northeast.
Atlas rows: idle, stride, pickup, work. Each game cell is 256x256 RGBA.
Run after replacing any source sheet in art/source/animation-atlases.
"""
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter
from collections import deque

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/animation-atlases"
DEST = ROOT / "game/art/animations"
NAMES = ("owner", "brewer", "cashier", "gardener", "customer0", "customer1", "departing")
CELL = 256


def make(name: str) -> None:
    im = Image.open(SOURCE / f"{name}.png").convert("RGBA")
    pieces = isolate(im, name)
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


def isolate(im: Image.Image, name: str) -> list[Image.Image]:
    """Separate touching poses by growing eroded silhouette seeds."""
    small = im.getchannel("A")
    small.thumbnail((500, 400), Image.Resampling.NEAREST)
    w, h = small.size
    components = []
    erosion = 0
    for size in (0, 3, 5, 7, 9, 11):
        core = small.point(lambda a: 255 if a > 100 else 0)
        if size:
            core = core.filter(ImageFilter.MinFilter(size))
        px = core.load()
        seen: set[tuple[int, int]] = set()
        components = []
        for y in range(h):
            for x in range(w):
                if (x, y) in seen or not px[x, y]:
                    continue
                stack = [(x, y)]
                seen.add((x, y))
                points = []
                while stack:
                    a, b = stack.pop()
                    points.append((a, b))
                    for u, v in ((a-1, b), (a+1, b), (a, b-1), (a, b+1)):
                        if 0 <= u < w and 0 <= v < h and (u, v) not in seen and px[u, v]:
                            seen.add((u, v))
                            stack.append((u, v))
                if len(points) > 60:
                    components.append(points)
        if len(components) == 16:
            erosion = size
            break
    if len(components) != 16:
        raise ValueError(f"{name}: found {len(components)} silhouettes, expected 16")
    components.sort(key=lambda ps: sum(y for _, y in ps) / len(ps))
    ordered = []
    for row in range(4):
        ordered += sorted(components[row*4:row*4+4], key=lambda ps: sum(x for x, _ in ps) / len(ps))

    # Flood the original alpha from all sixteen intact cores at once. This
    # divides narrow contacts without cutting off a shoe or a hat brim.
    owner = [-1] * (w*h)
    queue = deque()
    for label, points in enumerate(ordered):
        for x, y in points:
            idx = y*w+x
            owner[idx] = label
            queue.append((x, y))
    alpha = small.load()
    while queue:
        x, y = queue.popleft()
        label = owner[y*w+x]
        for u, v in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0 <= u < w and 0 <= v < h and owner[v*w+u] == -1 and alpha[u,v] >= 18:
                owner[v*w+u] = label
                queue.append((u,v))
    parts = []
    for label in range(16):
        mask = Image.new("L", (w,h))
        mask.putdata([255 if n == label else 0 for n in owner])
        mask = mask.resize(im.size, Image.Resampling.NEAREST).filter(ImageFilter.MaxFilter(3))
        part = im.copy()
        part.putalpha(ImageChops.multiply(im.getchannel("A"), mask))
        box = part.getchannel("A").getbbox()
        parts.append(part.crop(box))
    print(f"  {name}: erosion {erosion}, all 16 silhouettes separated")
    return parts


if __name__ == "__main__":
    for character in NAMES:
        make(character)
