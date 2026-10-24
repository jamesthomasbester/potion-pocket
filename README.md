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
Local `user://little_lux.json`, temporary file and backup. JSON is validated before replacement. Inventory, partial timers, choices, staffing, tutorial and mute setting are saved after transactions, every five seconds and on backgrounding. `user://events.jsonl` contains local milestones with elapsed fresh-run time. No event upload.

On resuming, the same fixed-step simulation processes at most two hours. Only hired workers perform automatic actions; ingredients, chosen recipes and capacities still constrain production. A high-water timestamp clamps negative clock changes and prevents replaying the same interval. The result is saved before showing the welcome-back report; dismissing never awards more money. This is local prototype time handling, not tamper-proof validation. Atomic rename plus backup is used; sudden power loss is not proven safe.

## Build and test
Set `GODOT` to your Godot executable. `python3 tools/run_tests.py` runs economy/save checks. Rendered UI tests: `godot --path . -s res://tools/ui_tests.gd -- --ui-test`. Input-driven accelerated playthrough: `godot --path . -- --qa` (dedicated test save, real buttons, simulated elapsed time). Add `--resolution 540x1200 -- --qa --tall` for the tall capture. Tests never modify a normal desktop save.

`python3 tools/build_android.py` uses the locally installed Godot toolchain and JDK; on another machine set `GODOT` and `JAVA_HOME`, install matching Godot Android export templates and configure the Android SDK/debug keystore in Godot Editor Settings. The project itself has no external content dependencies. The machine-specific fallback paths in tools are conveniences only.

`tools/make_audio.py` reproduces every audio clip with Python's standard library. Art combines new transparent sprites in `game/art/` with layered scenery in `game/room.gd`. Source sheets, exact generation prompts and the approved reference are in `art/`; `tools/extract_art.py` reproduces sprite extraction.

See `ART_DIRECTION.md`, `docs/ECONOMY.md`, `docs/VALIDATION.md`, `docs/HANDOFF.md` and `docs/evidence/`. Art and feel remain provisional pending user playtesting. Developer runs do not establish retention or revenue.

## Current visual redesign (0.2.0)
The approved mockup drives the new warm timber, cream tiles, purple cauldron, rounded characters, cream/navy header, lavender goal/tabs and green upgrade card. Native manual controls collapse after hiring their worker. Gear opens management and recipe choices; tapping a hire/upgrade objective opens its management panel. Prices and timing reflect actual game data. See `docs/REDESIGN.md` and `docs/evidence/redesign/` for current screenshots and validation. Earlier videos/screenshots below document the previous foundation.

## Polish pass
Raised, squishy buttons; a counting coin balance; a goal banner with a progress bar toward its coin target; inventory chips; icon tabs; Team/Improve as sprite cards. The scene answers each action: leaf puffs on harvest, cauldron splash and squash on brew, an arcing bottle and shelf sparkle on stock, coin bursts with floating +N on sales, a sparkle burst on purchases and glints on anything ready to collect. During onboarding the next control to tap glows softly.

The shop room, its furniture and customer paths sit on one oblique grid (`U`/`V` in `game/room.gd`) matched to the sprites. The garden tab is an outdoor scene: house front, picket fence, stone path, two raised beds of vector peppermint/moonflower, and a locked third plot. Feature roadmap: `docs/FEATURE_PROPOSALS.md`. The APK in `builds/` predates this pass; rebuild with `python3 tools/build_android.py`.

## Deliverables
- `builds/little-lux-debug.apk`: verified debug-signed installable Android package.
- `builds/little-lux-project.zip`: self-contained source, docs and screenshot evidence (excludes the APK, videos and import cache).
- `docs/evidence/android-intro.mp4`: 100 seconds of real-time Pixel 6 touch play, prior to the last small art polish.
- `docs/evidence/accelerated-intro.avi`: 24.5-second final-art desktop capture, representing five simulated minutes.
- `docs/evidence/{starting-shop,garden,automated-shop,renovated-shop}.png`: original in-engine 9:16 screenshots.
- `docs/evidence/android-final-fresh.png` and `android-final-resume.png`: final art on the actual phone.
