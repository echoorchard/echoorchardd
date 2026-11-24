# Echo Orchard: Game Design Document

> v2 (ship pass, 12 Nov 2026). The original 20-row blueprint is archived in
> `archive-v1-blueprint/`.

## One-line pitch

Tap each tree on its own heartbeat to harvest ripe fruit, season by season,
up one painted hillside.

## Core loop

1. **Choose a row** on the Orchard Path (hub).
2. **Watch the pulse.** Every tree has a tempo (BPM). An echo ring grows from
   its canopy each beat; the golden ripe band sits at 75% of the ring's travel.
3. **Tap on the band.** Within ±perfect/2 ms = **perfect** (2 fruit); within
   ±good/2 ms = **good** (1 fruit); anything else, or a rest beat, **bruises**
   fruit (−1 leaf).
4. **Fill the basket** to the row's quota before losing all three leaves, or
   before the branches go bare.
5. **Earn stars and seeds**, unlock the next row, and climb the hill.

Missing a beat (not tapping) costs nothing; only wrong taps bruise.

## Rules

| Rule | Detail |
|------|--------|
| Count-in | Two beats before the first band; taps then are ignored |
| Perfect streak | Every 3rd perfect in a row adds +1 fruit |
| Leaf regrowth | 10 clean harvests in a row regrow one lost leaf (max 3) |
| Dewdrops | Carried into a row by choice; each absorbs one bruise |
| Bare branches | The row ends if every fruit is picked before the quota |
| Stars | 1 = cleared · 2 = cleared with ≥2 leaves · 3 = ≥2 leaves and ≥60% perfect |

## Seasons (chapters): one new rule each

| Season | Rows | Rule | Tutorials | Finale |
|--------|------|------|-----------|--------|
| Spring Bloom | 1–9 | One pulse | First Pulse, Two for One | First Basket |
| Summer Sun | 10–21 | Many tempos (2–3 trees, musical ratios) | Two Trees, Quick and Slow | Midsummer Chorus |
| Autumn Gold | 22–32 | Rest beats (pattern like `xx-`; tapping one bruises) | A Rest Beat, Tap and Wait, Two Waltzes | Leaf-Fall Waltz |
| Winter Quiet | 33–42 | Wind gusts (shift the ripe moment ±80–150 ms for 2.5 beats) | First Gust | First Frost |
| Harvest Moon | 43–50 | Fading echo (ring visible N beats, ghosted M beats) | Fading Echo, Moon Memory | Moonlit Basket |

Tutorial and finale rows are hand-made in `lib/data/rows.dart`. The rows
between come from the deterministic `RowGenerator` along each season's curve
(tempo up, windows tighter, more trees), reaching 85% of the curve so the
finale is always the peak. Rows are sized from a target duration (about 20–45 s
for a steady player).

**Proven by tests** (`test/levels_test.dart`): a simulated perfect player
3-stars every row, a steady player who only lands "good" taps clears every row,
a player who ignores rest beats fails every Autumn row, durations stay within
15–75 s, difficulty ramps inside each season, and finale windows tighten
season over season.

## Modes

- **Story rows**: the 50 rows above.
- **Daily Row**: generated from the date (`DailyRow.forDate`) using only the
  seasons reached; the first clear each day gives 15 seeds + 1 dewdrop. Streak
  and a 5-week calendar.
- **Long Row**: endless; two trees, fruit regrows, and the tempo rises 4 BPM
  every 8 harvests (cap 132). Score = basket; the best is kept.

## Economy (earned only)

| Source | Seeds |
|--------|-------|
| First clear of a row | 10 |
| Each new star | 5 |
| Daily Row (first clear per day) | 15 + 1 dewdrop |
| Each seal (achievement) | 10 (daily/streak seals also give a dewdrop) |
| Long Row | 1 per 10 points |

Market Stall (fixed prices): Rush 120, Birch 160, Cedar 220, Moonweave 300
baskets; Birdhouse 80, Beehive 100, Rope Swing 140, Scarecrow 180, Windmill
220, Moon Lantern 260 keepsakes, which appear on the hub hillside. No real
money anywhere.

## Seals (20)

First Fruit · First Basket · Midsummer Chorus · Leaf-Fall Waltz · First Frost
· Moonlit Basket · Starry Rows (30★) · Constellation (100★) · Golden Season
· Clear Note (all-perfect row) · Unbruised (flawless finale) · In the Pocket
(12 perfect streak) · Heartbeat (30) · Full Larder (500 fruit) · Orchard
Keeper (3,000) · Morning Round · Seven Dawns · Long Row (60) · Endless
Orchard (200) · Well-Kept Hill (all keepsakes).

## Screens

| Screen | Purpose |
|--------|---------|
| Splash ("Dawn over the grove") | Painting, wordmark, one echo ring |
| Orchard Path (hub) | Tall hillside, 50 stakes on a winding trail, saplings on cleared rows, mist over locked seasons, keepsakes; shelf: Daily, Long Row, Market, Journal + next row |
| Row sheet | Rules in this row, quota, tempo, carry a dewdrop, begin |
| Harvest Row | The game; leaves + pause on top, basket count at the bottom; lesson card on tutorials |
| Beneath the Canopy (pause) | Back to the row, start over, Wind & Hush, leave |
| Basket Crowned | Stars pop, seeds count up, seals, next row |
| The Season Rests | Gentle reason, carry dewdrops, try again |
| How to harvest | Five pages with live practice rings using the real judge |
| Orchard Journal | Ledger of stats + 20 seals |
| Market Stall | Baskets and keepsakes |
| Daily Row | Today's row, streak, calendar |
| Wind & Hush (settings) | Sounds, ambient bed, pulse tick, vibration, eyes-only, gentle wind, reduce motion, reset (confirmed) |
| Privacy Policy | No data collected, no account needed, saves stay on the device, how to delete them; support via the Play listing (no contact details in the app). Font licence (OFL) is registered with `LicenseRegistry`, not shown as a screen |

## Audio & haptics

All synthesised by `tool/make_sfx.py`: tick, rest, harvest, perfect, bonus,
bruise, gust, star, win, lose, unlock, buy, menu, plus day/night ambient loops.
Haptics on harvest/bruise/win (toggle). Eyes-only mode removes rhythm sounds
and brightens bands.

## Persistence

`shared_preferences` only, on device: unlocked row, stars, seeds, dewdrops,
owned items, equipped basket, seals, stats, daily dates, play dates, Long
Row best, settings. "Reset the orchard" clears progress and keeps settings.

## Technical map

| Layer | Files |
|-------|-------|
| Pure rules | `lib/game/rhythm/{pulse_clock,beat_judge,wind_gust,harvest_simulator}.dart`, `lib/game/harvest_session.dart` |
| Content | `lib/data/{row_definition,rows,row_generator,daily,achievements,market}.dart` |
| Saves & rewards | `lib/data/{progress_repository,progression_service}.dart` |
| Flame | `lib/game/harvest_game.dart`, `lib/game/components/*` |
| UI | `lib/screens/*`, `lib/widgets/*`, `lib/theme/*` |
| Audio | `lib/audio/orchard_audio.dart`, `lib/game/feedback/orchard_feedback.dart` |
