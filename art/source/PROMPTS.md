# Reference-led sprite kit
Generated using the built-in image_gen tool, 24 October 2026. Both requests used art/reference/approved-mockup.png as style reference and requested real transparency. No previous game assets were used. tools/extract_art.py extracts the individual sprites and excludes neighboring atlas fragments.

## Furniture prompt
Use case: stylized-concept. Production asset sheet for an actual 2D Godot game. The supplied mockup is STYLE REFERENCE ONLY. Generate ONE transparent PNG sprite atlas, 3 columns x 3 rows, nine equal square cells, each object fully isolated with generous transparent padding and NO labels/grid/text. Match the mockup's polished rounded hand-painted mobile cartoon style: warm brown outlines, soft cel shading, honey oak wood, cream highlights, upper-left light, fixed 2:1 isometric camera viewed from above. Do NOT generate the room or UI.
Exactly these nine standalone props in row-major order:
1 copper cauldron with PURPLE liquid, stone plinth and small orange fire, no people, no floating particles, no progressbar.
2 empty two-tier honey oak potion display shelf, front-facing three-quarter view matching mockup right wall, no bottles or other contents.
3 honey oak checkout counter, front and top visible, small modern navy payment terminal on top, no person.
4 square wooden ingredient crate filled with green peppermint leaves, leaf emblem on front.
5 matching crate filled with white five-petal moonflowers and greenery, white flower emblem.
6 empty raised rectangular garden bed with brown soil and oak rim, no plants.
7 rounded cluster of green garden shrubs with a few tiny white flowers.
8 leafy plant in terracotta pot.
9 small wooden garden gate between two timber posts.
Consistent perspective and coherent scale, sharp clean silhouettes and real transparent alpha. No floor tile attached except cauldron's small stone base. No shadows extending across neighboring cells. Asset sheet only, not a screenshot.

## Character prompt
Create a production transparent sprite sheet, 3 columns by 3 rows with generous blank padding between nine isolated assets. Match supplied reference's warm polished rounded cartoon game art, brown outlines, soft cel shading, isometric view from above. No backdrop, no room, no labels, true transparent alpha. Equal cells. Row1: purple pointed-hat witch shop proprietor cream apron full body facing viewer three-quarter; lavender beret and apron brewer holding stirring spoon full body; coral shirt cream apron cashier full body. Row2: straw hat green gardener full body; dark curly-haired customer green hoodie beige backpack facing away three-quarter; blond blue-coat customer shoulder bag facing away three-quarter. Row3: cream hoodie brown haired departing customer facing viewer full body; golden round potion bottle leaf emblem; purple teardrop potion bottle crescent moon emblem. Each separate, no overlap. Cute substantial heads and small bodies, exactly like reference style, consistent camera.

## Engine composition
Floor, walls, plant growth, coin icon, UI, progress bars and effects are original engine/vector elements. Character movement uses sprite translation and bobbing, not frame-by-frame walk cycles. Shelf bottles represent actual inventory; carried proprietor bottles are decorative artwork. Previous renderer/UI remain as text for comparison and are excluded from the APK.
