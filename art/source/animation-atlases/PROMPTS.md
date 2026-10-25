# Directional character art source

Generated 25 October 2026 with the built-in image-generation tool, using each existing Little Lux character PNG as its own identity reference. The seven original PNGs are in this folder. No art from another game was used.

Each generation requested one transparent, equal-cell 4×4 atlas in the game's warm rounded painted style, viewed from its fixed elevated isometric camera. Columns were southwest/front-left, southeast/front-right, northwest/back-left, northeast/back-right. Rows were idle, exaggerated walking stride, floor pickup, and active work/interaction. The prompts required an identical face, outfit, body scale and foot anchor across poses, no room/floor/shadow, and one isolated pose per cell.

Character-specific references and work prompts:

| Atlas | Identity to preserve | Work pose |
| --- | --- | --- |
| `owner.png` | Purple pointed hat, dark hair, cream apron, dark dress and white shoes | Stir a potion bottle |
| `brewer.png` | Lavender beret, brown bun, lilac apron and wooden spoon | Stir with spoon |
| `cashier.png` | Brown hair bun, coral shirt, cream apron and payment tablet | Operate tablet |
| `gardener.png` | Straw hat, green clothes and potted herb | Tend/water herb |
| `customer0.png` | Curly hair, green hoodie and beige backpack | Inspect bottle |
| `customer1.png` | Long blond hair, blue coat and shoulder bag | Inspect bottle |
| `departing.png` | Tousled brown hair, cream hoodie and purple bottle | Admire bottle |

`tools/make_character_animations.py` separates touching silhouettes, fixes one scale and bottom-center anchor per character, and writes 1024×1024 RGBA runtime atlases to `game/art/animations/`.
