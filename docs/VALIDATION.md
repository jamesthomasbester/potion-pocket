# v0.2 visual revision

See `REDESIGN.md` and `evidence/redesign/` for current results. The foundation benchmark below is historical v0.1 evidence, not a performance claim for the redesigned art.

# Validation — 24 October 2026

## Evidence boundaries
This is a locally tested demo, not validation of retention or revenue. The implementation uses original in-engine vector geometry and original synthesized WAVs. All PNGs are captured from running Godot; no generated scene image is used as gameplay.

## Automated rules
`python3 tools/run_tests.py`: **70 checks, zero failures**. Covers both recipe quantities, rapid repeated harvest/brew/stock/serve/purchase calls, every upgrade charge, displayed duration/capacity/price effects, ingredient shortages, full shelves, in-flight recipe switching, independent helper roles, full old-herb-bin recovery, online/offline equivalence, two-hour cap, negative-clock high-water handling, repeated loading of the same offline interval, atomic save round trip, backup recovery and future-version refusal.

## Rendered desktop touch tests
`tools/ui_tests.gd`: **18 checks per aspect ratio**, run at 540×960 and 540×1200. Native touch events complete harvest → brew → stock → checkout. All principal controls stay within the viewport and are >=64 logical pixels tall. Tab switching preserves the entire economy state. Tests cover crop-switch recovery, background notification save, and confirmed/cancelled development reset.

`--qa` playthrough uses real native buttons with simulated elapsed seconds, never inventory/coin injection. Revised tuning reaches the gardener around 22 seconds, brewer 53, cashier 85, second recipe 102 and renovation 208; remaining upgrades around 250. Exact events are in `docs/evidence/playthrough-events.json`. These are efficient scripted runs, not novice playtest results. The accelerated AVI is 24.5 seconds of genuinely rendered gameplay representing about five simulated minutes.

## Physical Android
Connected Pixel 6, 1080×2400, Android 17, arm64, GL Compatibility. A fresh five-minute run uses `adb input tap` on real controls; read-only inspection of the local save selects the next action. No balance edits, accelerated clock or injected money. Package identity is separate from other installed games.

Physical milestone observations: gardener 23.1s; brewer 51.1s; cashier 82.0s; Moonflower recipe 99.5s; renovation/tutorial 205.8s; growing upgrade 217.4s; copper cauldron 233.7s; capacity 244.4s; service 250.0s. Costs were paid from actual sales. Raw results and final state: `docs/evidence/android-milestones.json`.

Device performance samples during play: approximately 59.6–60.0 fps and p95 frame time 16.7 ms. End-of-run PSS was 314,610 KB (about 307 MiB). This is one Pixel 6, not a low-end-device or thermal/battery study. Godot reports and Android memory data are saved in `builds/android-performance.txt`. Cold activity display was 423 ms on the successful fixed-audio launch; this is Android's activity timing, not time to first usable control.

Lifecycle passed on the physical phone: mute toggle persisted; Home/background, force-stop, 12-second wait and relaunch retained workers, tutorial and selected crop/recipe. The report showed 13 simulated offline seconds and 64 offline coins; the state inspected two seconds after launch included one further valid live sale (80 total delta). Evidence: `android-lifecycle.json`, `android-welcome-back.png`, `android-events.jsonl`.

Final art-only refinements and dialog styling were regression-tested on desktop; the final package was then reinstalled for a device smoke and reset check. The 100-second real-time Android introduction recording predates the last proprietor/sign/vial art polish; the 24.5-second desktop recording shows that polish.

## Problems found and fixed
- Initial scene minimum width clipped UI; isolated the fixed art canvas from native UI minimum width.
- JSON float-versus-integer enum membership rejected valid saves; validation now checks numeric integer values explicitly.
- Floating point growth endpoint could delay harvest; endpoint snaps within a small tolerance.
- Switching recipes with saturated peppermint bins could strand the new crop; changing crop freely replants both beds.
- First tuning purchased every upgrade too quickly; raised main progression costs after a fresh-save run.
- Raw PCM loop boundaries crashed the Pixel 6 audio thread after about four seconds. Replaced runtime looping with imported non-looping WAVs replayed on completion. Device playthrough runs with sound enabled after this fix.
- Starting staff silhouettes obscured the value of hiring; final art has one proprietor and separately added role-specific helpers.
- Shelf details, gold renovated sign and a filling vial improve production/upgrade readability.

## Remaining limitations
- Art, branding, synthesized audio and tuning are provisional pending user review. No external novice playtest, no engagement or monetisation claim.
- Worker walking paths are illustrative; they do not implement collisions or transport latency. Production quantities and timers are authoritative.
- Android screenrecord captures video without game audio. Audible quality and physical haptic sensation have not been independently assessed by a person.
- Negative-clock and two-hour cap are automated rule tests; the physical phone clock was not changed. Sudden power loss during a write is not tested; backup/rename are not a production-grade durability guarantee.
- No emulator, low-end Android device, extended battery/thermal test, TalkBack audit or store-release configuration.
- The forced-exit Movie Maker capture reports one resource still in use at shutdown; the recording completes. The final rendered UI test runs exit cleanly. This capture-only cleanup warning remains to investigate.
- This introduction has a finite upgrade set. Once fully upgraded it keeps producing; additional long-term progression is outside this milestone.

Final package check: debug signature verified (APK v2/v3), reinstalled on Pixel 6, existing progression retained. Native cancel-reset preserved workers; confirmed-reset restored zero coins/no helpers/tutorial start and synchronized mute state. The installed app is left at a fresh shop. `android-final-reset.json` and `android-final-fresh.png` capture this. One minor visual limitation remains: native dialog title decoration is less integrated than the custom game controls.
