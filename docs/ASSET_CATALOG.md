# Little Lux asset suite

The production kit contains **30 transparent PNG sprites** and **6 scalable SVG décor swatches**. Every variant is loaded or selectable in the game; the source atlases and generation prompts are in [`art/source/tier-atlases/`](../../art/source/tier-atlases/). The sprites follow the existing elevated camera, bottom-centre anchors, warm outlines and light direction.

| Family | Tiers and use |
|---|---|
| Cauldron, shelf, counter | Oak/copper → carved oak with violet accents → gold and amethyst. Each swaps into the shop when that station reaches level **1, 3 or 7**. |
| Raised garden bed | Basic soil → enchanted carved bed → runic gold bed, using the Garden level. |
| Peppermint, moonflower | Three progressively fuller plant clumps per crop. Six clumps are placed on each bed and scale with actual growth progress. |
| Energy Brew, Dreamdrop | Three bottle designs per recipe, shown on the shelf and during stocking. Bottle art follows Cauldron level. Recipe availability still follows the economy unlock. |
| Bushes, potted plants | Three decorative tiers each, following Garden level in both scenes. |

Floor and wall finishes are independent, mixable choices. Open **gear → Décor • floors & walls** to preview all six. Locked looks explain their requirement.

| Finish | Unlock | Where used |
|---|---|---|
| Cream checker / cream plaster | Starting look | Shop floor and cutaway walls |
| Moon mosaic / lavender panels | Grand glow-up renovation | Shop floor and walls; garden house wall |
| Botanical tile | Garden level 7 | Shop floor |
| Ivy & gold | Counter or Shelf level 7 | Shop walls and garden house wall |

The next unlocked look applies automatically until the player selects a finish. A manual choice persists across upgrades and save/load. Decoration never alters prices or timers. Old version 1 and 2 saves migrate to the new decoration fields; an existing renovation keeps its lavender look.

The SVG files in `game/art/decor/` are menu swatches for the same palettes and motifs that the renderer draws in perspective. Source generation: `python3 tools/make_decor.py`. PNG extraction: `python3 tools/extract_tiers.py`; alpha and resource check: `python3 tools/check_assets.py`. Individual game sprites are in `game/art/` and their source sheets are preserved for future edits.

Browse the [complete catalog](evidence/tiered/asset-catalog.png) and [shop level 1](evidence/tiered/shop-tier-1.png), [shop level 3](evidence/tiered/shop-tier-2.png), [shop level 7](evidence/tiered/shop-tier-3.png) previews. The preview script seeds the tiers and full-grown beds only for screenshots; actual gameplay earns levels and waits for crops normally.
