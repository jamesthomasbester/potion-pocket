# Economy and introduction tuning

Source of truth: `data/economy.json`. All quantities, prices, capacities, production times and purchase costs live there. Presentation only selects icons/labels and displays calculated benefits.

| Recipe | Herb per bottle | Grow time / yield per bed | Brew time | Sale price |
|---|---|---|---|---|
| Energy Brew | 1 Peppermint | 6 seconds / 2 herbs | 3 seconds | 8 coins |
| Dreamdrop | 1 Moonflower | 8 seconds / 2 herbs | 4 seconds | 13 coins |

Two beds; initial shelf has one Energy Brew; zero starting coins and herbs. Herb bins hold 24 per type. Shelf holds 6 total (12 upgraded). Customer arrivals every 3 seconds, queue capped at 3. Service takes 1.8 seconds (0.9 upgraded). Gardening never costs coins.

| Purchase | Cost | Exact effect |
|---|---:|---|
| Pip • gardener | 32 | Harvests + replants both beds |
| Momo • brewer | 56 | Brews + stocks automatically |
| Sol • cashier | 80 | Serves waiting customers |
| Moonflower recipe | 48 | Unlock Dreamdrop • sells for 13 |
| Enchanted soil | 48 | Growth 6 / 8s → 4 / 5.3s |
| Copper cauldron | 64 | Brewing 3 / 4s → 2 / 2.7s |
| Tap-to-pay terminal | 40 | Checkout 1.8s → 0.9s |
| Roomy shelves | 56 | Shelf capacity 6 → 12 bottles |
| The grand glow-up | 320 | New tiles, walls + sign; sales +25% |

Renovated prices round to integers: Energy 10, Dreamdrop 16. Growth and brewing upgrades divide duration by 1.5; they do not alter per-batch quantities. Both herbs stay useful after the second recipe unlock.

## Tuning from fresh-save playthrough
First pass was too fast: efficient touch automation renovated at roughly 116 simulated seconds and bought every upgrade by 160. Costs were revised (gardener 24→32, brewer 40→56, cashier 48→80, recipe 32→48, renovation 120→320). The revised desktop input run renovates around 208 simulated seconds and buys the remaining upgrades near 250 seconds. These are script-driven timings, not guarantees for a new player. Physical-device timings are recorded separately in VALIDATION.md.

The first garden wait is six seconds, with a stocked bottle available to sell meanwhile. Before automation the player alternates between harvest, brewing and service; after each hire one class of taps disappears. No reward is awarded just because a timer milestone passed. A crop switch can always recover from a full bin of the old herb: it replants both beds for free.

Two-hour offline cap: 72,000 fixed 0.1-second steps at most. A manual shop finishes its active crop/brew/checkout, but does not spontaneously harvest, start new brews or start new sales. No maximum-income shortcut.

Physical Pixel 6 run confirmed the revised timing: first sale 5.5s (starter stock), first harvest 6.4s, first brewed-and-stocked potion 10.6s, gardener 22.0s, brewer 50.1s, cashier 81.1s, recipe 98.6s and renovation/tutorial 205.1s in the local event log. Wall-clock observations differ by approximately one second due to app startup and readback. All upgrades purchased by about 250 wall seconds.

## Station levels (v0.3)
Four stations level from 1 to `max_level` (100). Level-up cost is `station.cost × level_growth^(level−1)`, with `level_growth` 1.18 and base costs garden 40, cauldron 50, counter 60, shelf 90.

| Station | Each level | Each milestone (Lv 10/25/50/75/100) |
|---|---|---|
| Garden beds | +6% grow speed, +2 herb bin | ×2 grow speed |
| Cauldron | +6% brew speed | ×2 brew speed |
| Counter | +6% customer arrival and checkout speed | ×2 both, +1 queue spot |
| Shelf | +10% potion price, +1 bottle space | ×2 price |

A station's multiplier is `(1 + level_speed × (level−1)) × 2^milestones`. At level 1 every number equals the v0.2 economy, so the intro pacing above is unchanged. The one-time upgrades still apply on top (soil and copper ×1.5, terminal ×2 checkout, roomy shelves double the base 6).

The chain is min(herbs, potions, customers) × price, so the bottleneck moves as you level. An analytic payback-greedy simulation, starting after the one-time upgrades and assuming constant play, reaches all stations at Lv 10 in about 10 min, Lv 25 in about 17 min, Lv 50 in about 2.2 h and Lv 75 in about 20 h. Lv 100 is deliberately far off, which leaves room for prestige. The offline cap stays at two hours.

Saves are now version 2. A version 1 save migrates on load with every station at level 1.
