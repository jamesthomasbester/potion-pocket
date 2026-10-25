# Character animations

The seven playable character looks each have sixteen hand-painted transparent poses. Runtime sheets live in `game/art/animations/` and are ready for `draw_texture_rect_region` or an `AtlasTexture`: 4 columns × 4 rows, each frame 256×256 with its feet anchored at local `(128,248)`.

| Column | Facing | Row | Action |
| --- | --- | --- | --- |
| 0 | southwest | 0 | idle |
| 1 | southeast | 1 | stride |
| 2 | northwest | 2 | pickup |
| 3 | northeast | 3 | work / interaction |

The renderer alternates idle and stride while a character travels, and idle and work during active production or checkout. Pickup holds the crouched pose briefly before returning to the previous state. Facing derives from actual screen-space travel. Customers enter, queue, pick up their purchase, and leave without changing their appearance. The brewer animates through brewing progress, the cashier through service, and the gardener through growth/harvest; manual actions drive the owner.

Source sheets and generation details are in `art/source/animation-atlases/`. Regenerate the normalized runtime atlases with `python3 tools/make_character_animations.py`, then regenerate review sheets with `python3 tools/make_animation_catalog.py`. The source sheets intentionally remain separate from runtime atlases so silhouette cleanup and foot alignment are reproducible.

Review art: `docs/evidence/tiered/character-directions.png`, `character-actions.png`, and the four `animation-*.png` in-scene captures.
