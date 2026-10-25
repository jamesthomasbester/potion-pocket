"""Render review sheets from the exact game animation atlases."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "game/art/animations"
OUT = ROOT / "docs/evidence/tiered"
NAMES = ("owner", "brewer", "cashier", "gardener", "customer0", "customer1", "departing")


def sheet(kind: str) -> None:
    canvas = Image.new("RGBA", (800, len(NAMES)*250+48), "#fff7ec")
    draw = ImageDraw.Draw(canvas)
    labels = ("SW", "SE", "NW", "NE") if kind == "directions" else ("idle", "stride", "pickup", "work")
    for col, label in enumerate(labels):
        draw.text((col*200+78, 12), label, fill="#191b43")
    for row, name in enumerate(NAMES):
        atlas = Image.open(ATLAS / f"{name}.png").convert("RGBA")
        for col in range(4):
            x = col if kind == "directions" else 0
            y = 0 if kind == "directions" else col
            frame = atlas.crop((x*256, y*256, (x+1)*256, (y+1)*256))
            frame.thumbnail((180, 215))
            canvas.alpha_composite(frame, (col*200+10, row*250+38))
        draw.text((10, row*250+240), name, fill="#191b43")
    OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT / f"character-{kind}.png")


for layout in ("directions", "actions"):
    sheet(layout)
