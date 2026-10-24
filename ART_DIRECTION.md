# Little Lux — approved mockup direction

Reference: `art/reference/approved-mockup.png`. Original self-contained art kit, generated specifically for this game with the built-in image tool. Prompts and full source sheets: `art/source/PROMPTS.md`.

Warm honey timber, cream plaster and tiled floor, navy type (#191b43), pale lavender interface (#cdb3fa), copper cauldron, purple potion, green purchase buttons. Rounded cartoon people use brown outlines, soft shading and large expressive heads. Upper-left light; fixed elevated oblique view. Layered props, scene geometry and native UI remain independently editable.

18 extracted transparent props/people/bottles in `game/art/`. Floor, timber walls, crop growth, shadows, progress pills, sparkles and coin icon are engine/vector elements. Sprite extraction separates neighboring atlas fragments. Character pivots are bottom centre; camera scales uniformly to fit portrait ratios. Android respects safe areas. Manual actions use 64 logical pixels and tabs 74.

Actual stock appears on shelf. Grow/brew progress, selected recipe, staffing, automation and renovation lights reflect game state. Proprietor’s carried bottles are decorative; character movement uses static sprite translation/bobbing, not a frame animation set. Customer routes are illustrative, not collision simulation.

Native UI uses the live balance, prices and duration. Gear reveals team/upgrades, sound/reset and recipe/crop selection. Manual buttons disappear when their employee is hired. The contextual cauldron/garden upgrade card has a functional purchase button. Existing synthesized audio and save rules are retained.

The supplied image is a visual target, not a flattened playable background. Previous direction is archived in `art/source/ART_DIRECTION-v1.md`.
