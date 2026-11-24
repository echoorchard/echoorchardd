# Ripe Rhythm: Design Language

One hillside orchard, painted in morning light, climbed from spring blossom
to a harvest-moon night. The look is a **storybook gouache** world (soft
layered hills, visible brush texture, warm rim light) carrying a quiet
**paper-and-ink** interface. The art moves; the interface stays still and
lets it.

---

## 1. Palette: five interface colours, each with one job

| Token | Hex | Job | Never |
|-------|-----|-----|-------|
| `cream` Dawn Cream | `#FFF6E8` | Paper: every interface surface, sheet and text on dark art | tinted grey stand-ins |
| `ink` Bark Ink | `#2C2416` | Text, drawn icon strokes, the shadow colour | pure black |
| `leaf` Leaf Deep | `#3D6B4F` | Action & structure: primary buttons, the path, the current row, toggles on | decoration |
| `gold` Ripe Gold | `#E8A838` | **The beat / "now"**: ripe band, perfect, stars, seeds | backgrounds, borders "to pop" |
| `dusk` Dusk Plum | `#5E4B6E` | Rest & failure: bruise, rest beats, locked mist, Season Rests | anger red |

Derived (not new colours): secondary text = `ink` @ 72%; disabled = `ink` @ 38%;
scrim = `ink` @ 55%; sheet shadow = `ink` @ 16%.

**Contrast:** `ink` on `cream` 14.9:1; `cream` on `leaf` 6.0:1; `ink` on `gold`
7.9:1. Text placed directly on art always sits on a `cream` sheet or carries
an `ink` @ 40% text shadow.

### World colours (art only, never UI chrome)

Used only inside the illustrations and sprites generated in `tool/`:

| Season | Sky | Light | Hills | Signature |
|--------|-----|-------|-------|-----------|
| Spring Bloom | `#FCE7C8`→`#F6D2C4` | `#FFF0B8` | `#A9D0A0` `#82B884` `#5E9A66` | blossom `#F3B6C6` |
| Summer Sun | `#FFE9A8`→`#BFE3D0` | `#FFF6D0` | `#9CCB7E` `#6FAE5C` `#4E8A4A` | meadow flowers `#F7D46A` |
| Autumn Gold | `#F7C98B`→`#E9A46A` | `#FFE0A3` | `#C9A15A` `#B07A3E` `#8A5A30` | falling leaves `#D9733A` |
| Winter Quiet | `#E6EEF5`→`#C9D8E6` | `#FFFFFF` | `#DDE6EE` `#B9C9D8` `#93A9BF` | snow + bare bark |
| Harvest Moon | `#2C2A4A`→`#4B3F6B` | moon `#FFE6B0` | `#3B4A5E` `#2E3C4E` `#22303F` | lanterns `#E8A838` |

Fruit: apple `#C8463D`, pear `#C9B33F`, plum `#7A4E8C`, moon-peach `#F2B38A`.

**Gradients allowed only where they are the world:** sky, light falloff, moon
glow, water. No gradient on any button, text, chip or panel.

---

## 2. Type: Fraunces only

Bundled `assets/fonts/Fraunces-{Regular,SemiBold,Bold}.ttf` (SIL OFL 1.1).

| Role | Weight | Size | Height | Use |
|------|--------|------|--------|-----|
| Title | 700 | 40 | 1.05 | Splash wordmark, Basket Crowned |
| Heading | 600 | 26 | 1.15 | Screen and season names |
| Label | 600 | 17 | 1.2 | Buttons, row names, HUD numbers (tabular) |
| Body | 400 | 15 | 1.45 | Lesson, privacy, descriptions |
| Small | 400 | 13 | 1.35 | Captions, stat labels |

Tracking: −0.5 on Title, 0 elsewhere. Numerals in HUD/stats use
`FontFeature.tabularFigures()`. Max line measure ~60 characters.

---

## 3. Space

4dp base. `s1` 4 · `s2` 8 · `s3` 12 · `s4` 16 · `s5` 24 · `s6` 32 · `s7` 48 · `s8` 64.
Screen gutter 24 (20 under 360dp width). More space above a heading than
below it. Touch targets ≥48×48.

---

## 4. Surfaces & components

- **Paper sheet**: `cream`, radius 20 (top-only for bottom sheets), one soft shadow
  `ink`@16% y+6 blur 20. No border. Never nested: a sheet holds rows
  separated by space or a hairline `ink`@10%, never by inner cards.
- **Stake button (primary)**: `leaf` fill, `cream` label, radius 14, height 56,
  pressed = scale 0.96 + darker fill. One per screen.
- **Quiet button (secondary)**: no fill; `ink` label with a drawn leaf glyph;
  48dp target.
- **Icon set**: drawn in `lib/widgets/orchard_icons.dart`, 2dp `ink` stroke,
  round caps, 24dp box: basket, leaf, star, seed, dewdrop, calendar,
  lantern-book (journal), market awning, windmill (settings), pause-canopy,
  back-branch, lock, restart. No Material icons and no emoji anywhere.
- **Stars**: drawn five-point with rounded joins; earned = `gold` fill + `ink`
  stroke, empty = `ink` stroke only (shape difference, not colour alone).

---

## 5. Screens: one composition each

| Screen | Composition |
|--------|-------------|
| Splash | Full-bleed dawn painting; wordmark lower third; mist drifts; fades to the path |
| Orchard Path (hub) | Tall vertical hillside, spring at the bottom and moon at the top. A winding `leaf` path with numbered stakes. Cleared stakes grow saplings; the next stake breathes `gold`; locked seasons sit under `dusk` mist. A thin top strip holds seeds and dewdrops; a bottom **shelf** of four drawn icons (Daily, Long Row, Market, Journal) is left-aligned in an asymmetric row, with the settings windmill on its own at the right. |
| Harvest Row | Season art full-bleed, trees on the ground line, nothing else mid-screen. Leaves (lives) top-left, pause canopy top-right, basket + quota bottom-centre. |
| Pause | `ink`@55% scrim; a cream sheet rises with resume (stake), restart, lesson, leave |
| Basket Crowned | Golden-hour wash over the row art; stars pop 1→3; seeds count up; next row (stake) |
| Season Rests | `dusk` wash; one gentle line; retry (stake), back to the path (quiet) |
| Journal | Paper page: stats as a two-column ledger, achievements as a list with drawn seals |
| Market Stall | Awning header; keepsakes in a 2-column grid with a sprite, name and seed price |
| Wind & Hush | Bottom sheet of toggle rows |

---

## 6. Motion

| Moment | Duration | Curve |
|--------|----------|-------|
| Echo ring | one beat | linear |
| Tap squash (tree) | 180ms | 1→0.92→1.05→1 |
| Fruit to basket | 450–650ms | easeInCubic arc |
| Screen transition | 300ms | easeOutCubic fade + 2% scale |
| Star pop | 260ms each, 180ms stagger | easeOutBack |
| Seed count-up | 600ms | easeOutCubic |
| Lose shake | 300ms, 8px | damped sine |
| Hub next-row breathe | 2400ms loop | easeInOut |
| Ambient (clouds, petals, snow, fireflies) | continuous | linear |

**Reduce Motion** (setting, or `MediaQuery.disableAnimations`): ambient
particles off, screen transitions become plain fades, shake off, stars
appear without overshoot. The echo ring is gameplay and stays.

---

## 7. Sound & haptics

Synthesised in `tool/make_sfx.py` (no third-party audio): wood-block tick,
harvest pluck, perfect chime, soft bruise thud, rest-beat hush, gust whoosh,
star pops, win phrase, lose sigh, unlock bell, buy coin, menu tap, plus a quiet
ambient loop (pad + birds). Visual events always lead; sound, music and
vibration each have their own toggle.

---

## 8. Words

Use the orchard's own words: rows, seasons, basket, quota, ripe band, echo
ring, bruised, seeds, dewdrops, keepsakes. Never "Play", "Settings", "Game
Over", "Level Select", "Shop", "Coins".
