# v0.2 visual update

Current build follows the supplied mockup. Read `REDESIGN.md` for current scope and validation; new evidence is under `evidence/redesign/`. Regenerate the source ZIP with `python3 tools/package_source.py`. The following foundation notes are retained for history.

# Handoff

Working folder: `/media/james/dev-drive/potion-pocket`. User explicitly requested a new self-contained folder with no existing game content. Earlier projects and asset collections are untouched. No commit, push, publication, purchase or paid service.

Entry: `game/main.tscn`; economy `game/economy.gd`; tuning `data/economy.json`; persistence `game/storage.gd`; art `game/room.gd`; audio `game/sound.gd` and reproducible `tools/make_audio.py`.

Runtime controls: Shop/Garden, two recipes/crops, contextual harvest/brew/stock/serve, Team and Improve panels, sound toggle, confirmed reset. All three workers, four production/capacity upgrades and renovation implemented. Local events and capped offline simulation implemented.

Evidence and validation: see VALIDATION.md. Rules 70/70; touch UI 18/18 at each of two aspect ratios. Android Pixel 6 five-minute touch progression reaches renovation at 205.8s, with the complete upgrade set around 250s. Final device lifecycle/build status is appended below when complete.

Important fix: do not restore runtime raw AudioStreamWAV looping. It reproducibly crashed the Android audio thread at the first loop boundary. Imported WAVs with finished-signal replay work on the device.

Next design step after delivery: user plays the fresh APK and reviews the actual screenshots. Prioritise clarity, tap burden and art feedback before generating any additional asset pack. No additional locations/monetisation systems planned for this demo.

Final validation: Pixel 6 sound-enabled five-minute run passed; 59.6–60.0 fps / 16.7 ms p95; 307 MiB PSS. Background + force-stop + relaunch preserved state and credited bounded actual offline production. Imported-audio fix remains stable. APK has only VIBRATE permission, no network permission. Project remains entirely local.

Delivery status: final APK signature verified, installed, native reset/cancel smoke passed; Pixel 6 left at a fresh shop. Source archive includes the entire runtime and docs; large recordings/APK are separate downloads. No background test process intentionally left running.
