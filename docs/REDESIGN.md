# Reference-led visual redesign

User-approved direction: art/reference/approved-mockup.png. Keep this self-contained project and all working economy/save rules. No previous-project assets.

Plan:
1. Generate a compact transparent furniture/character kit using the supplied mockup as the shared style reference.
2. Rebuild the scene as a large cutaway cream-tile shop with timber walls, rear garden, front entrance, visible inventory and animated characters/effects.
3. Replace the stacked control dashboard with a cream title bar, lavender objective strip, contextual bottom card and two large tabs. Keep manual actions accessible and all upgrades functional.
4. Capture and critique actual engine screens, test both portrait ratios and all existing economy/save behavior, then export/install an updated Android build.

Checklist:
- [x] Preserve previous renderer/UI source under art/source for comparison.
- [x] Copy user mockup as approved reference.
- [x] Transparent sprite kit inspected, cropped and integrated.
- [x] Scene composition and responsive native UI rebuilt.
- [x] Rendered fresh/garden/automated/renovated captures reviewed.
- [x] Economy regression and new touch flows checked.
- [x] Android build, device smoke and final evidence.

No economy timing or prices will be copied blindly from the mockup: displayed values will describe actual game rules. Generation prompts and source sheets will be preserved in art/source.

## Implemented, 24 October 2026

- New 18-sprite furniture/character/potion kit generated with the built-in image tool using the supplied mockup as reference. Source sheets and prompts retained; no old game assets used.
- Warm timber/plaster cutaway shop, cream tiled floor, rear garden, gate, ingredient crates, potted plants, cauldron, shelf, terminal/counter, helpers and moving customers.
- Cream/navy title and actual coin balance; lavender objective; native contextual upgrade card with real duration and price; selected lavender Shop/Garden tabs.
- Gear opens Team, Improve, sound/reset and recipe/crop choices. Hire/upgrade objectives can also open management. Manual action buttons remain until their corresponding helper is hired.
- Character motion is sprite translation/bobbing, not an authored walk-cycle animation. Proprietor's bottles are decorative; shelf stock/progress/staff reflect live state.
- Uniform scene scaling and clipping at 540×960 and 540×1200, plus Android safe areas. Cached static floor geometry and 10 Hz UI refresh avoid per-frame rebuild work.

## Validation

70 economy/save assertions pass. 22 native touch/layout assertions pass at each portrait size, including the full manual sale loop, crop recovery, persistence/reset, real contextual upgrade purchase, duration change and integer balance. Accelerated input-driven five-minute playthrough unlocks every upgrade and completes the tutorial. Captures are in `docs/evidence/redesign/`.

Pixel 6: installed in place with existing save retained; actual taps completed harvest → brew → stock → sale, resulting in 8 coins, 3 remaining peppermint and 1 stocked bottle. Reopening retained progress. APK v0.2.0 is debug signed. The older five-minute device benchmark/videos in the original validation doc describe v0.1; this visual revision has a device smoke test and new performance sample, not another five-minute physical benchmark.

Current art follows the reference as a playable layered implementation; it is not pixel-identical to the mockup. Fresh shops have fewer workers and bottles until earned. The mockup's fictional 240 balance/120 price/6→4 duration were not copied into the economy.

### Final device/rendering check

Final 30-second Pixel 6 sample: 58.4 fps, p95 frame interval 19.0 ms (process 11049 in `pixel6-performance.log`). The earlier samples in that file show the pre-optimization regressions. The final renderer caches floor line geometry, avoids rebuilding tab themes, refreshes text at 10 Hz and redraws animated scenery at up to 30 Hz. A fixed 540-wide internal viewport scales to the phone: this improves frame rate with some reduction in text/edge sharpness versus native-resolution rendering. This short sample is not a sustained thermal benchmark.

Both final portrait UI test runs: 22/22, zero failures. Debug APK signature verifies with v2/v3. Real device repeated sale preserved prior progress and increased balance from 8 to 16. Desktop input-driven playthrough reached all upgrades/tutorial completion by five simulated minutes and exited cleanly. Final APK installed; local game remains open on Pixel 6.
