# Little Lux — a pocket potion shop

A standalone portrait Godot 4.7.2 / GDScript Android demo. All game code, generated sprite art, engine scenery, icon and synthesized audio were created for this folder. No content from earlier games is included. No server, ad SDK, purchases or paid service.

## Run
Open `project.godot` in Godot 4.7.2 and press F6 on `game/main.tscn`, or F5 for the project. Desktop: `godot --path .`. The 540×960 internal viewport expands vertically on taller phones and scales to the display.

Android: install `builds/little-lux-debug.apk`. Package: `org.littlelux.demo`; arm64, Android 7 / API 24 minimum, API 36 target. This is a debug-signed local test build, not a store release. With Android platform tools: `adb install -r builds/little-lux-debug.apk`. Launch **Little Lux** from the phone launcher.

## Play
1. Open Garden. Harvest both beds with the large **Harvest + replant** button. Planting is free.
2. Open Shop. Tap **Brew potion**, then **Stock potion** when ready. Tap **Serve** to complete checkout and earn coins.
3. Open the **gear** menu and hire Pip, Momo and Sol in **Team**. They respectively harvest/replant, brew/restock and serve. The simulation continues in either tab and while upgrade panels are open.
4. Open the gear menu to unlock Moonflower in **Improve**. The same menu contains crop/recipe choices: select Moonflower in Garden and Dream in Shop. Changing a crop freely replants both beds immediately, resetting their growth; brewed/brewing inventory is retained.
5. Choose upgrades and save for the visible renovation. Play continues after the tutorial.

Sound toggles ambience and effects; short Android haptics accompany sales/upgrades. The gear menu’s Reset requires confirmation. No worker wages, seed cost, hidden rescue coins or forced session cutoff.

## Persistence
Local `user://little_lux.json`, temporary file and backup. JSON is validated before replacement. Inventory, partial timers, décor choices, staffing, tutorial and mute setting are saved after transactions, every five seconds and on backgrounding. `user://events.jsonl` contains local milestones with elapsed fresh-run time. No event upload.

On resuming, the same fixed-step simulation processes at most two hours. Only hired workers perform automatic actions; ingredients, chosen recipes and capacities still constrain production. A high-water timestamp clamps negative clock changes and prevents replaying the same interval. The result is saved before showing the welcome-back report; dismissing never awards more money. This is local prototype time handling, not tamper-proof validation. Atomic rename plus backup is used; sudden power loss is not proven safe.

## Build and test
Set `GODOT` to your Godot executable. `python3 tools/run_tests.py` runs economy/save checks. Rendered UI tests: `godot --path . -s res://tools/ui_tests.gd -- --ui-test`. Input-driven accelerated playthrough: `godot --path . -- --qa` (dedicated test save, real buttons, simulated elapsed time). Add `--resolution 540x1200 -- --qa --tall` for the tall capture. Tests never modify a normal desktop save.

`python3 tools/build_android.py` uses the locally installed Godot toolchain and JDK; on another machine set `GODOT` and `JAVA_HOME`, install matching Godot Android export templates and configure the Android SDK/debug keystore in Godot Editor Settings. The project itself has no external content dependencies. The machine-specific fallback paths in tools are conveniences only.

`tools/make_audio.py` reproduces every audio clip with Python's standard library. Art combines new transparent sprites in `game/art/` with layered scenery in `game/room.gd`. Source sheets, exact generation prompts and the approved reference are in `art/`; `tools/extract_art.py` and `tools/extract_tiers.py` reproduce sprite extraction.

See `ART_DIRECTION.md`, `docs/ECONOMY.md`, `docs/VALIDATION.md`, `docs/HANDOFF.md` and `docs/evidence/`. Art and feel remain provisional pending user playtesting. Developer runs do not establish retention or revenue.

## Visual foundation (0.2.0)
The approved mockup drives the new warm timber, cream tiles, purple cauldron, rounded characters, cream/navy header, lavender goal/tabs and green upgrade card. Native manual controls collapse after hiring their worker. Gear opens management and recipe choices; tapping a hire/upgrade objective opens its management panel. Prices and timing reflect actual game data. See `docs/REDESIGN.md` and `docs/evidence/redesign/` for current screenshots and validation. Earlier videos/screenshots below document the previous foundation.

## Station levels (0.3)
Garden beds, Cauldron, Counter and Shelf level 1–100 with exponential costs; levels 10/25/50/75/100 double that station. Tap a station in the scene (each shows its level badge) to pick it on the card, or use Improve. Details: `docs/ECONOMY.md`.

## Polish pass
Raised, squishy buttons; a counting coin balance; a goal banner with a progress bar toward its coin target; inventory chips; icon tabs; Team/Improve as sprite cards. The scene answers each action: leaf puffs on harvest, cauldron splash and squash on brew, an arcing bottle and shelf sparkle on stock, coin bursts with floating +N on sales, a sparkle burst on purchases and glints on anything ready to collect. During onboarding the next control to tap glows softly.

The shop room, its furniture and customer paths sit on one oblique grid (`U`/`V` in `game/room.gd`) matched to the sprites. The garden tab is an outdoor scene: house front, picket fence, stone path, two raised beds of tiered sprite peppermint/moonflower, and a locked third plot. Feature roadmap: `docs/FEATURE_PROPOSALS.md`. The APK in `builds/` includes this pass.

## Tiered asset suite (0.4.0)
Thirty new transparent variants cover furniture, beds, crop plants, decorative foliage and both potion recipes. Levels 1, 3 and 7 visibly change the corresponding art. Six floor and wall finishes are previewable under **gear → Décor • floors & walls**; upgrades unlock new looks, and your selection is saved. See `docs/ASSET_CATALOG.md`, `docs/evidence/tiered/asset-catalog.png` and the source sheets in `art/source/tier-atlases/`.

Regenerate and validate with `python3 tools/extract_tiers.py`, `python3 tools/check_assets.py`, and `godot --path . -s res://tools/art_preview.gd -- --ui-test`.

## Directional character animations (0.5.0)
All seven characters now use 4-direction, 4-action transparent atlases. Travel uses actual facing and alternating stride frames; pickups and active station work have their own poses. Customers keep their identity from queue through departure. See `docs/CHARACTER_ANIMATIONS.md`, the `character-directions.png` / `character-actions.png` review sheets, and the Pixel 6 `pixel6-animations.mp4` capture in `docs/evidence/tiered/`.

## Team levels, talents and branch themes (0.6.0)
Pip, Momo and Sol level 1–100 in **Team** once hired: Pip speeds growth, Momo speeds brewing and Sol adds tips to every sale, each doubling at levels 10/25/50/75/100. Moon Stars now buy six permanent talents in **Improve**; spending a star never lowers its price bonus. Each branch has its own outdoor look (seaside, snow, night market lanterns, sunflowers, starfall). Preview every branch and both panels with `godot --path . -s res://tools/branch_preview.gd -- --ui-test`, which writes `docs/evidence/branches/`. Details: `docs/ECONOMY.md`.

## Shop scene (0.7.0)
`game/main.tscn` is the authored shop scene and the main scene. **World** holds the room backdrop, the floor decals (rug, doormat) and the furniture in a y-sorted **Props** node. Each piece stands on its foot, so the team and customers layer correctly in front of and behind it. **HUD** is a CanvasLayer with:
- the top bar: coins, the shop's name, daily goals and settings;
- the goal banner;
- the **Stage**, the gap the room is fitted into;
- the station card;
- the bottom navigation: Shop, Garden, Team, Recipes and Upgrades.

`game/shop_view.gd` drives the room:
- it swaps each piece between its t1/t2/t3 art;
- it places Momo, Sol, the owner, the queue (up to three customers, with a "+N" by the door) and special visitors on the measured floor;
- it draws badges and effects.

Furniture tiers: stations follow their level. The lectern, books and bookcase follow recipes unlocked, and the workbench follows Momo's level. The rug, doormat and plant follow the Décor choice. Tap the cauldron, potion shelf or counter to select it, the lectern to open the Recipe Book, and a special visitor to serve them. `game/actor.gd` draws a character from the existing pose sheets.

The new art's sources are in `art/v2/`. `art/` is excluded from export, so `python3 tools/import_v2_art.py` copies the chosen cut-outs into `game/art/shop/` and `game/art/ui/`. It halves the furniture size, and the picks are listed at the top of the script.

## The Grimoire (0.8.0)
A research tree studied at the lectern. Lore comes from brewing, first brews, special visitors, milestones and daily goals. Each page takes real game time, and every learned page lasts through every branch. There are four chapters of five pages (Herbology, Brewing, Commerce, Arcana), plus the Celestial chapter, which now holds the Moon Star talents. Open it from **Grimoire** in the bottom bar or by tapping the lectern. While a study runs, the lectern glows and the owner reads beside it. `game/research_tree.gd` draws a chapter. Pages, costs and timings are in `data/research.json`. Details: `docs/ECONOMY.md`.

## Garden scene
The garden tab is now the painted yard from `art/v2/garden/`, set up in `game/main.tscn` under **Garden**:
- **Beds:** each bed bought shows a planter at its growth stage: bare soil, sprouts, then leaves (Peppermint, Ember root, Frost fern) or flowers (Moonflower, Starbloom). The next plot shows a padlock and its price; tap it to buy.
- **Props:** they arrive with the garden's level. Watering can and barrel from the start, wheelbarrow and soil sack at Lv. 3, bench and bird bath at Lv. 7, beehive at Lv. 10, a stack of pots at Lv. 25. Each stands on open lawn, clear of the painted path, fences, bushes and pots.
- **Characters:** Pip (or the owner, before Pip is hired) works the first bed, using the existing character sprites.
- **Branches:** each branch tints the yard and adds gulls, snow, fireflies or stars.

`game/garden_view.gd` drives it. `game/scene_view.gd` holds what the shop and garden share: characters, effects, badges and bars. `tools/import_v2_art.py` also copies the garden picks into `game/art/garden/`.

## Deliverables
- `builds/little-lux-debug.apk`: verified debug-signed installable Android package.
- `builds/little-lux-project.zip`: self-contained source, docs and screenshot evidence (excludes the APK, videos and import cache).
- `docs/evidence/android-intro.mp4`: 100 seconds of real-time Pixel 6 touch play, prior to the last small art polish.
- `docs/evidence/accelerated-intro.avi`: 24.5-second final-art desktop capture, representing five simulated minutes.
- `docs/evidence/{starting-shop,garden,automated-shop,renovated-shop}.png`: original in-engine 9:16 screenshots.
- `docs/evidence/android-final-fresh.png` and `android-final-resume.png`: final art on the actual phone.
