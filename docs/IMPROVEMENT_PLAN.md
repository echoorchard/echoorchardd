# Echo Orchard — Improvement Plan (ship pass)

Date: 2026-11-12. Supersedes the "pending" phases 10–11 in
`IMPLEMENTATION_PLAN.md`.

## 1. Audit (baseline)

**What the game is:** a rhythm-timing harvest game. Trees pulse on a BPM; an
echo ring expands each beat and you tap when it crosses the golden ripe band.
Perfect = 2 fruit, good = 1, a miss or decoy tap bruises fruit (−1 of 3 lives).
Fill the basket to the row quota to win; 1–3 stars.

**Baseline:** Flutter 3.47.9 · `flutter analyze` clean · 13 tests pass ·
~3,800 lines in `lib/`.

| Area | Finding |
|------|---------|
| Naming | App label, title, docs and `echo_orchard` package agree. applicationId `com.echoorchard.echo_orchard`: no trademark problem, keep it. |
| Content | 20 rows / 4 seasons. Decoy and wind both arrive in the same season, so a season doesn't introduce exactly one rule. |
| Mechanics | Decoy = a tiny ash twig beside the canopy: hard to see, not rhythmic. Dead end: when every fruit is picked below quota, the row never ends. |
| Art | 100% code-drawn shapes; no images. Reads flat. |
| Sound | Only `SystemSound.click`/`alert`: inaudible on many Android devices. |
| Retention | None: no daily, endless mode, achievements, stats or shop. |
| Hub | Static "Grove Gate" menu; doesn't change as you progress. |
| UI slop | Emoji season labels, stock Material icons (`eco`, `star`), ~30 ad-hoc colours. |
| Publisher | `hello@echoorchard.app` invented in `constants.dart`; no credits; no privacy policy doc. |
| Release | No launcher icon, store kit, privacy policy, `tool/`. Workflow uses unpinned Flutter and v4 actions (Node-20 deprecation). |
| Secrets | Keystore + base64 sit in project root; both git-ignored. Not a git repo yet. |

## 2. Improved concept

**Echo Orchard: answer the pulse.** Walk one hillside orchard from spring
blossom to a harvest-moon night. Each season adds one rule to the same tap:

| # | Season | New rule | Rows | Tutorials | Finale |
|---|--------|----------|------|-----------|--------|
| 1 | Spring Bloom | **One pulse**: tap on the ripe band | 9 | 1–2 | *First Basket* |
| 2 | Summer Sun | **Many tempos**: 2–3 trees on different BPMs | 12 | 10–11 | *Midsummer Chorus* |
| 3 | Autumn Gold | **Rest beats**: some beats wither; let them pass | 11 | 22–24 | *Leaf-Fall Waltz* |
| 4 | Winter Quiet | **Wind gusts**: a gust pushes the ripe moment early or late | 10 | 33 | *First Frost* |
| 5 | Harvest Moon | **Fading echo**: the ring fades, so you keep the beat from memory | 8 | 43–44 | *Moonlit Basket* |

**Why 50 rows in 5 seasons:** a row lasts 30–90 s, so 50 rows is ~2 hours of
fresh content before the daily row and Long Row take over. Seasons are uneven
on purpose: Summer and Autumn are the longest because polyrhythm and rest beats
have the most combinations; Winter is shorter (one tutorial, since wind is a
modifier the player can already read); Harvest Moon is a short, steep finale
that mixes every rule. Tutorials and finales are hand-made; the middle rows of
each season come from a deterministic generator (`lib/data/row_generator.dart`)
tuned along a difficulty curve, then frozen into tests.

**Rule fixes:** decoy twigs are replaced by rest beats (rhythmic, readable
by shape and colour). A row also ends ("The branches are bare") when every
fruit is picked before the quota is reached.

## 3. How it plays

1. The Orchard Path (hub): a tall hillside you climb, one season per band of
   art. Every cleared row plants a sapling by its post; locked seasons sit
   under mist.
2. Tap a post → row card (rule reminder, best stars) → Harvest Row.
3. Harvest Row: the trees stand on the season's illustration. Tap on the band.
   HUD: three leaves (lives) at the top left, the basket at the bottom showing
   the quota.
4. Basket Crowned: stars pop in one by one, then seeds are counted up. Season
   Rests: a dusk wash and a quick retry.

## 4. Retention (all offline, all earned)

- **Daily Row**: date-seeded generated row using the unlocked rules. First
  clear each day: +15 seeds + 1 dewdrop. Streak counter + 5-week calendar.
- **Long Row**: endless; fruit regrows and the tempo rises every 8 harvests;
  3 lives; best score kept.
- **20 achievements** (local), each +10 seeds.
- **Journal**: stats (fruit harvested, perfects, best streak, rows cleared,
  stars, days played, Long Row best) + the achievement list.
- **Market Stall**: cosmetics at fixed seed prices: basket weaves and orchard
  keepsakes (lantern, beehive, scarecrow, windmill, swing, birdhouse) that
  appear on the hub hillside.
- **Dewdrops** (hint): shield one bruise in a row. Earned only (daily +
  achievements), never sold. Restart is always free.

## 5. Play readiness checklist

- [ ] One name everywhere; remove emoji + stock icons; drawn icon set
- [ ] 50 rows, each proven winnable by a simulated player (tests)
- [ ] Chapter art 1080×1920 ×5, splash art, tree/fruit/basket/keepsake sprites, logo
- [ ] Synth SFX (tick, harvest, perfect, bruise, win, lose, unlock, buy, menu, wind) + ambient loop
- [ ] Settings: sound, music, vibration, reduce motion, eyes-only, gentle wind; reset progress (confirm)
- [ ] Credits (Fraunces OFL) + Privacy Policy screen
- [ ] Launcher icon (flutter_launcher_icons), Android toolchain = Flutter 3.47.9 template, no permissions
- [ ] Store kit: icon-512, feature graphic, ≥5 screenshots, STORE_LISTING.md
- [ ] docs/PRIVACY_POLICY.md; compliance 14×NO; .gitignore scrub
- [ ] Workflow pinned to 3.47.9, checkout@v5 / setup-java@v5 / upload-artifact@v7
- [ ] git init with a non-personal identity; push once the GitHub account is known

## 6. Roadmap

| Phase | Work |
|-------|------|
| A | Design language, palette consolidation, drawn icons |
| B | Engine: rest beats, fading echo, bare-branch end, dynamic tempo, simulator |
| C | 50 rows + generator + validity tests |
| D | Art + SFX scripts (in parallel) and asset wiring (audioplayers) |
| E | Hub path, daily, Long Row, achievements, journal, market, settings, credits |
| F | Web preview, critique → polish |
| G | Icon, toolchain, store kit, privacy, compliance, CI, git |

## Publisher

MUMMY FAITHIA BUSINESS VENTURE (developer Comfort Bukunmi Bello), Ilesha,
Osun State, Nigeria · echobelogame.com.ng. Used only in the website privacy policy and the store listing, never in the app.
The GitHub account and repo are still pending, so the push is deferred.
