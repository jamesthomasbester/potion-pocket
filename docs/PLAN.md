# Potion Pocket — implementation plan
1. Build an original, isolated Godot 4.7.2 portrait project. No previous game content.
2. Separate deterministic economy and JSON tuning from reusable native scene art/UI.
3. Complete harvest → brew → stock → sale, then workers, upgrades and renovation.
4. Add atomic local persistence, bounded offline simulation, sound and onboarding.
5. Run focused rules tests, real rendered touch-input playthroughs, two aspect ratios; export Android and test connected Pixel 6 where available.
6. Deliver evidence, tuning and candid handoff. No commit/publish or paid services.

# Persistent checklist
- [x] Audit: engine 4.7.2; Android SDK/JDK/templates present; Pixel 6 connected.
- [x] New folder requested by user: no reuse of code/art/audio/game data.
- [x] Core loop and original compact art kit
- [x] Initial in-engine screenshot for review
- [x] Automation, upgrades, renovation, two recipes
- [x] Save/offline/events/audio
- [x] Economy tests and five-minute input playthrough
- [x] Two aspect ratios and Android lifecycle/performance
- [x] APK, recording, evidence and handoff

Tools: Godot CanvasItem drawing/tweens for original layered art and animation; image-generation tool available but unnecessary for the first geometric kit; original synthesized PCM sound via Godot; viewport PNG capture; Android adb screenrecord and screenshots. No commercial art/audio services enabled.

Evidence update: first screenshot shown in chat; native art retained as provisional. Rules 70/70, touch UI 18/18 on each aspect. Revised fresh Pixel 6 run reaches renovation at 205.8 seconds. Final lifecycle/package checks ongoing.

Completed evidence: Android fresh real-time five-minute run; 100-second device MP4; 24.5-second accelerated desktop AVI; starting/garden/automated/renovated screenshots; physical lifecycle and audio crash regression; 70 rules + 36 UI assertions. See VALIDATION.md for boundaries and remaining human/device work.
