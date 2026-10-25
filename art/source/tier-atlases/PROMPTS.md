# Tiered asset prompts

All four transparent source sheets were made with the built-in image-generation tool for this self-contained game, using the approved mockup and existing original sprites only as style references. The original PNG atlases are in `art/source/tier-atlases/`. `tools/extract_tiers.py` extracts the 30 individual production sprites without using fixed grid crops, which would include neighboring art.

## Furniture

Use case: stylized-concept. Asset type: transparent production sprite atlas for the Godot game Little Lux. Input images: first is the approved game mockup as STYLE REFERENCE; second is the existing furniture sprite sheet as STYLE AND PERSPECTIVE REFERENCE. Create ONE transparent PNG atlas with exactly 3 columns and 3 rows of nine separate standalone furniture sprites, equal cells and generous clear gutters, no text, grid, labels, room or background. Isometric elevated camera must be identical across every tier. Rounded polished hand-painted mobile game art, warm brown outlines, soft shading, upper-left light.
Row 1: copper cauldron tiers, left modest copper pot with purple brew and low stone hearth; middle larger silver-rimmed copper cauldron, luminous violet runes, better hearth; right ornate golden and amethyst master cauldron with violet star crystal and elaborate sturdy stone hearth. Each full object, bottom-center anchor, visually progressively upgraded.
Row 2: potion display shelf tiers, left small honey-oak two-tier shelf, middle broader carved oak three-tier shelf with purple accents, right ornate gold-trimmed purple-oak four-tier grand display. Shelves EMPTY with clearly visible boards, no bottles.
Row 3: checkout counter tiers, left compact honey-oak counter and little navy terminal, middle larger carved oak counter with brass trim and better terminal, right polished purple-oak and gold grand counter with advanced navy terminal. No people.
Every object fits entirely within its own cell. Real transparent alpha, no brown or green background fill, no painted floor slab or long cast shadow, crisp clean silhouettes.

## Garden beds and crops

Use case: stylized-concept. Asset type: transparent production sprite atlas for Little Lux, a portrait 2D isometric potion-shop game. Input images: first is approved mockup STYLE reference; second is existing furniture kit PERSPECTIVE/STYLE reference. Generate ONE PNG atlas on TRUE TRANSPARENT background, exactly 3 columns × 3 rows of nine separate isolated sprites with spacious clear gutters. No text, labels, grid, floor or setting. Every row is one plant/bed family with THREE distinct progressive tiers left to right. Same elevated isometric camera and comparable object footprint within each row. Warm brown outlines, painted rounded cartoon, soft upper-left shading.
Row 1 raised square garden beds: basic oak rectangular soil bed; improved oak bed with carved rail and moist enchanted soil; grand ornate oak-and-gold raised bed with purple runic soil. All EMPTY SOIL for runtime plants to be drawn on top.
Row 2 peppermint foliage CLUMPS WITHOUT pots/soil: first small vivid mint leaves on short stems; second fuller thriving mint clump with dew; third lush magical mint bouquet with a few tiny pale-yellow sparkles and rich green leaves. Each full clump isolated.
Row 3 moonflower foliage CLUMPS WITHOUT pots/soil: first modest green leaves and 3 white five-petal flowers; second fuller blooming leaves and 6 white flowers; third lush moonflower bouquet with white luminous blossoms and soft lavender accents. Each full clump isolated.
Crisp outlines, proportional tier growth, no leaf trails across cells, no shared cast shadow. Export-ready alpha.

## Potions

Use case: stylized-concept. Asset type: transparent potion bottle sprite atlas for the Godot game Little Lux. Input images: approved shop mockup as STYLE reference; existing 3x3 character and potion sheet as EXACT bottle design/perspective reference. Create ONE transparent PNG atlas of six separate individual potion bottle cutouts, exactly 3 columns × 2 rows in equal cells with large clear gaps. No scene/background/grid/text/labels. Same elevated 3/4 camera, rounded hand-painted polished mobile cartoon, warm dark-brown outlines, glass highlights upper-left. Bottle and cap fully visible, same bottom baseline in each cell.
Top row Energy Brew variants: tier 1 small round amber-orange potion flask with cork and simple green leaf motif; tier 2 upgraded larger amber flask, brass collar and brighter green leaf emblem; tier 3 elaborate golden amber flask with engraved leafy gold filigree and glowing green crystal stopper.
Bottom row Dreamdrop variants: tier 1 small teardrop violet potion flask with cork and white crescent motif; tier 2 larger amethyst flask with silver collar and luminous lavender crescent; tier 3 ornate royal purple flask with gold-silver filigree, glowing moon crystal stopper and clear crescent emblem.
Do not duplicate bottles, no hands or shelves, no glow extending across cells. Alpha transparency real, not checkerboard, black or painted fill.

## Garden foliage

Use case: stylized-concept. Asset type: transparent environment foliage sprite atlas for Little Lux 2D potion-shop game. Use approved mockup and existing furniture atlas as STYLE and isometric CAMERA references only. Generate one TRUE transparent PNG atlas, exactly 3 columns × 2 rows in equal spacious cells; six independent cutout sprites, no grid/text/labels/background/floor. Polished warm hand-painted mobile cartoon, brown outlines, soft upper-left shading.
Top row are three progressive standalone shrub clusters, consistent elevated oblique view: tier 1 modest round deep-green bush with few white flowers; tier 2 wider lush mint-and-forest-green flowering bush with more white flowers; tier 3 splendid very lush flowering shrub with white flowers, delicate gold star blossoms and subtly sparkling leaves. Bushes remain believable garden plants, not giant fantasy trees.
Bottom row are three progressive potted plants, consistent terracotta pot anchor: tier 1 little leafy plant in simple clay pot; tier 2 larger glossy-leaved plant in carved clay pot; tier 3 magical fern and white blossom arrangement in ornate purple-and-gold ceramic pot. Each tier more decorative, all fit cells without overlap. Real clean alpha, no painted patches.
