# Little Lux — analysis and feature proposals

Goal: chart on Google Play Games. This document covers where the game stands today, what blocks that goal, and the features to build, in order.

## Where the game stands (v0.2.1)

**What is good**
- Cozy art in one consistent style. Readable characters and a clear shop/garden split. This is the hardest part to fix later, and it is already right.
- The core loop is immediately understandable: grow → brew → stock → serve. A first sale lands about 5 seconds in.
- Automation lands at the right time: Pip at ~22 s, Momo at ~52 s, Sol at ~84 s.
- Solid technically: 60 fps on a Pixel 6, a 30 MB APK, atomic saves with backup, capped offline simulation, and economy plus UI tests.

**What stops it charting**
1. **The game ends in about 4 minutes.** All 9 purchases are done by ~250 s (`docs/evidence/redesign/playthrough.log`). After that, income tops out around 5 coins/s, limited by one customer arrival every 3 s with a queue of 3. There is nothing left to spend it on. Idle games keep players through day 30 and beyond on a long upgrade curve, and this game has none.
2. **No reason to come back.** Offline earnings exist (2 h cap), but nothing to buy with them, no daily goals, no events, no notifications.
3. **One-time upgrades only.** Every purchase is a single on/off switch. The genre runs on *levels*: costs that grow exponentially, rewards that grow, and milestones that feel like jumps.
4. **Too little content.** 2 crops, 2 recipes, 2 beds, 3 workers, 1 room.
5. **No monetization or analytics.** Revenue funds user acquisition, and Top Grossing is its own chart. Events are only logged locally, so retention can't be measured.
6. **Not shippable yet.** It is a debug-signed APK. Play needs a release-signed Android App Bundle (AAB), a store listing and, for new personal developer accounts, a closed test before production. Check Play Console for the current tester count and duration.

**How charts work, plainly.** Top Free ranks mostly on recent install velocity. Top Grossing ranks on revenue. Both are filtered by quality signals: ratings, Android vitals (crash and ANR rates) and retention. Features earn retention and ratings. Install velocity usually comes from paid user acquisition, featuring, or a viral or creator push. So the realistic route is: build retention, then prove it in a soft launch, then put revenue into acquisition. The features below are ordered to support that route.

## Phase 1 — make it a real idle game (retention core)

These turn a 4-minute demo into a game that lasts weeks. Build them before anything else.

1. **Leveled stations with exponential costs.** The cauldron, each bed, the shelf, the counter and each worker get levels 1–100. Cost grows ×1.12–1.18 per level, and output grows. Every 10/25/50 levels a milestone gives ×2 output with a visible star burst. The card under the scene already shows "Lv. N → next", so this fits the UI as-is.
2. **More recipes as a collection.** Grow to 8–12 potions, each needing 1–2 herbs and selling for more as you go. A **Recipe Book** screen shows locked silhouettes. Collections drive "one more unlock" sessions.
3. **Garden expansion.** The locked plot is already drawn. Make it purchasable and expand to 6 plots, with crops tied to recipes (peppermint, moonflower, then ember root, frost fern, starbloom…).
4. **Customer variety and requests.** Regular customers buy anything. **Requests** ask for a specific potion within a time limit and pay ×3. **VIPs** pay ×10 and appear briefly. This gives active players a reason to tap while idle players lose nothing.
5. **Prestige: "Open a new branch".** Around hour 2–4, the player can reset the shop for **Moon Stars**. Each Moon Star is a permanent +X% to all income, spendable on a talent tree. This is the main long-term loop of the genre. Branches can reuse the room code with a new theme (seaside, snowy mountain, night market).
6. **A better welcome back.** Show what each worker did. Add upgrades that raise the offline cap (2 h → 4 h → 8 h). Later, an optional "×2 for watching an ad" button.
7. **Daily quests and achievements.** 3 dailies (for example "serve 50 customers", "brew 10 Dreamdrops") and a 7-day login track. Achievements tie into Play Games Services.

## Phase 2 — reasons to return and share

8. **Seasonal events.** A Halloween potion festival is the obvious first one. Each event gets its own currency, 3–4 limited recipes, a cosmetic reward and a 2-week run. Events are when lapsed players come back, and they make good store screenshots.
9. **Decor and renovation tiers.** Furniture, wallpaper, floors, signs and outfits. Some give small bonuses, most are pure cozy self-expression. This is a natural spend for the current art direction, and screenshots of it spread.
10. **A familiar.** A shop cat or owl with a small passive bonus that reacts to taps. Cheap to build and drives attachment and reviews.
11. **Opt-in notifications.** "Your moonflowers are ready", "Offline earnings are full", "Event ends in 24 h". Ask for permission after the player has felt the value, not on first launch.
12. **Play Games Services.** Cloud save (players reinstall and switch phones), achievements, and an optional weekly leaderboard for "coins earned this week".

## Phase 3 — monetization (needed for Top Grossing and to fund user acquisition)

Keep it fair. Cozy-game audiences punish aggressive monetization in reviews, and ratings feed ranking.
- **Rewarded ads only.** Opt-in boosts: ×2 income for 30 min, instant brew, ×2 offline earnings. No forced interstitials in the first sessions.
- **Starter pack:** a one-time discount (gems, a cosmetic and a permanent ×2 income).
- **Remove ads plus a permanent ×2 rewards** purchase, for players who would rather pay than watch.
- **Gems** as a premium currency for skips and cosmetics.
- **A season pass** tied to events once Phase 2 exists: a free track plus a paid track of cosmetics and boosts.

The README currently states "no ad SDK, purchases". This phase deliberately changes that, so update it when the phase starts.

## Prerequisites outside features

- **Release pipeline:** an upload key, a release-signed AAB, version-code automation, and the current Play target API level.
- **Analytics:** Firebase or a similar tool for D1/D7/D30 retention, funnel steps (which already exist locally in `events.jsonl`), session length and ad/IAP events, plus remote config so the economy can be tuned without a release.
- **Soft launch:** release in 2–3 smaller markets first. Tune until D1 and D7 retention are competitive for idle games, then launch globally. Spending on acquisition before that is wasted.
- **Store listing (ASO):** the title should carry keywords ("Little Lux: Potion Shop Idle"). Use a strong icon, 5–8 screenshots with captions, a 15–30 s video of the loop and the glow-up, a feature graphic, and localization (EN, ES, PT-BR, DE, FR, JA, KO to start).
- **Quality bar for featuring:** low crash and ANR rates, fast startup, tablet and large-screen layouts, readable text sizes and a content rating. Featuring is free install velocity.

## Suggested order

| Step | Build | Why now |
|---|---|---|
| 1 | Leveled stations + milestone ×2 | Fixes the 4-minute ceiling; everything else stacks on it |
| 2 | Recipe Book (8 potions) + garden expansion | Content to fill the new curve |
| 3 | Prestige + offline cap upgrades | Week-long retention |
| 4 | Dailies, achievements, notifications, cloud save | Daily habit |
| 5 | Analytics, release AAB, closed test | Measure before spending |
| 6 | Rewarded ads + starter pack | Revenue to fund acquisition |
| 7 | Soft launch → tune → global launch with first event | Chart push |

Idle games spend most effort on content and balancing, not code. The economy already lives in `data/economy.json` and is covered by tests, so it is a good base for the long curve.
