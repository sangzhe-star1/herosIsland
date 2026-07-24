# Changelog

## 2026-07-24 (evening) — Fonts, home hub polish, BabyBus-pass plan

- **Real fonts ship at last**: `assets/fonts/NotoSansSC.otf` (Noto Sans CJK
  SC Medium, OFL) — Chinese renders identically on desktop and mobile, no
  more engine-default look. Drop `Baloo2-SemiBold.ttf` beside it any time
  for the rounded Latin; the chain picks it up automatically.
- **Home hub**: treasure chip top-right (stars + coins, tap = My Rewards),
  hero waves by himself every ~9s (motion-gated), soft radial spotlight.
- **Every button** now bounces on release via `UiKit.big_button`.
- **My Rewards** restyled as white rounded cards on the soft page (treasure,
  badges, growth) with the bundle's progress-bar art — the BabyBus
  catalogue look.
- **Traffic fix**: the Tap-to-Cross button sat exactly on top of the waiting
  hero, hiding all but his head; moved to the bottom-right thumb corner and
  the hero enlarged.
- Dropped the now-unused `common.locked` string (padlock badges replaced it).
- **docs/DESIGN_PLAN.md**: the full BabyBus-quality iteration plan — next
  coding pass, exact art slots to fill (items, three world backgrounds,
  monster paintings), the voice-recording script table, and future play
  ideas (sticker book, memory match, rhythm tap).

## 2026-07-24 (later) — Shell restyle after first on-device screenshots

- **Fixed the giant overlapping stars** on the world map (and every other
  oversized badge): `TextureRect` clamps `size` until `expand_mode` is set,
  so icons silently rendered at their native 128px. All picture/star/effect
  construction now sets expand mode first; hit bursts, collect flashes,
  power rings and battle meters were all quietly affected.
- **World map restyled** on the BabyBus/Toca/Khan-Kids patterns: white
  outlined titles over the painted scene, the bundle's navy panel and level
  cards, a per-world progress bar (bundle frame/fill art), padlock badges
  instead of "(locked)" text, and playable cards rendered clearly brighter
  than locked ones so pressability reads by glow alone.
- **Home screen**: the chosen hero stands in a soft radial spotlight, the
  Adventure button breathes slowly (the screen's single pulsing action),
  bigger badges, readable parent hint.
- **Hero House cards fixed** (names now sit in the card art's name bar; the
  gold star pins to the chosen card's corner) — PanelContainer tramples
  anchors, so card content moved into a plain Control wrapper.
- **Battle sparks** got a glowing disc backing so tap targets read as
  things, not wisps; dud sparks stay square and dull.
- New `tests/Screenshot.tscn` renders any scene to PNG under Xvfb, so
  screens can be eyeballed (and were: home, map, Hero House, battle, and
  the repair level, all verified rendered) without a person at the keyboard.
- Design rationale and the reference sources are in `docs/DESIGN_NOTES.md`
  ("The shell restyle").

## 2026-07-24 — The Ultraman build: asset bundle, Hero House, juice pass, Monster Arena

One working session, three rounds. Levels went from 14 to 23, worlds from
4 to 5, templates from 4 to 5. Everything below is verified by the headless
suite: 277 smoke checks plus the battle interaction probe, 0 failures.

### Characters and the Hero House

- Integrated `ultraman_tiga_zero_complete_game_bundle.zip`: **Tiga and Zero**
  are real, selectable heroes (`resources/skins/tiga.tres`, `zero.tres`),
  alongside the original drawn Light Hero. Default character is Tiga.
- **Hero House is open** (was a "coming soon" button): a character-select room
  using the bundle's painted spotlight cards. Tap a card to become that hero
  everywhere — levels, home screen, result screen. The chosen card wears a
  gold star; the others dim but never disappear.
- `SkinnedCharacter` learned textures properly: sprites fit the placeholder's
  exact footprint (no level layout changed), `celebrate()` swaps to the cheer
  pose, and the **tintable chest light** is drawn over the sprite at each
  skin's measured chest position — the colour-matching mechanic survives real
  art. New `core_position()` exposes the light as the beam muzzle for battles.

### Visuals and game feel

- Hero City is fully textured: painted skyline (`city.png`, storm levels use
  `city_damaged.png`), painted energy tower with the level's colour lamp
  seated on its lamp orb, neutral orbs tinted at runtime, rock hazards.
- **Repair the Energy Tower now tells its story in state**: the level opens on
  the broken tower and swaps to the shining repaired one at the win, held on
  screen so the child sees what the work was for.
- Point-of-touch feedback everywhere: collect flash under the finger, a
  colour-tinted power-up ring pulsing from the tower lamp when the target
  changes, sparkle-textured confetti, painted star badges in every star row,
  the chosen hero standing on the home screen (tap = celebration), the hero
  cheering beside the result stars, coin icon on coin lines, chest in the
  Reward Center.
- Full icon-badge set wired (star, coin, heart, warning, house, spark, …) plus
  **six icons generated in the same badge style** where the bundle had none:
  check, flag, gear, car, sort, paw — navigation, bins and the map are now
  consistently textured. Texture filtering switched to linear for the painted
  art.
- The principles behind all of this are documented in `docs/DESIGN_NOTES.md`
  (game-feel "juice" adapted for age six, children's touch-target research).

### Monster Arena — the new battle world

- New `monster_battle` template: sparks appear on a city-threatening monster;
  every tap fires the hero's **light beam from the chest light to the tapped
  point on the same frame** — no cooldowns, every tap answered. A spark meter
  fills (never depletes); at the target the monster gives up, waves bye-bye,
  and hops off home. Startled, never hurt; the child cannot be harmed and
  nothing is timed.
- Three procedurally drawn monsters with distinct silhouettes — Rocky (orange,
  one horn), Blobbi (green, three googly eyes), Spikelor (purple boss, spikes)
  — parameterised from `levels.json`, each with a drop-in art slot at
  `assets/characters/monsters/<id>.png`.
- Difficulty grows by adding things to do: dud sparks (grey, square, dull —
  shape AND brightness differ, colour-blind safe) as the only mistake source,
  and slow poppable goo lobs that splat harmlessly. Bundle's `energy_beam`,
  `hit_burst` and `smoke` effects wired.

### New levels (9)

- Hero City: **Meteor Shower** (storm dodge-and-collect), **Rainbow Charge**
  (4-colour tower matching).
- Piglet Town: **Toys or Clothes?** (category sorting).
- Safety Bureau: **Danger Detective** (10-item danger sort), **Night
  Crossing** (3-lane, rain).
- Rescue Forest: **The Long Trail** (6-step trail, 4 hazards).
- Monster Arena: **Wake the Rock Monster**, **Goo Trouble**, **The Big
  Spiky**. Six new badges, all strings in English and Chinese.

### Fixes

- Collect Energy's hero was parented to the scene root and therefore drawn
  *behind* the CanvasLayer background — invisible since the template was
  written. Gameplay actors now live inside the play area.
- The traffic levels' "Safe crossings" counter no longer runs 18 px off the
  right edge (right-aligned in a fixed box; was the suite's one standing
  warning).
- `celebrate()` no longer assumes scale 1.0 (pre-existing fix kept from the
  original tree).

### Tests

- Smoke test covers Hero House, the monster icon, and all 23 levels.
- New `tests/BattleProbe.tscn`: drives the battle input handler the way a
  finger would — dud taps must nudge without scoring, 12 hits must fill the
  meter, win the level, and land a 2-star result in `GameManager` —
  `run_smoke.sh` runs it automatically after the scene sweep.

### For any build that leaves the house

Tiga and Zero are recognisable licensed characters; this build is for the
household only. Remove their two entries from `data/characters.json` (the
game falls back to the original Light Hero cleanly) before sharing a build
anywhere public. `docs/DEPLOYMENT.md` covers installing on the family's own
iOS/Android devices without any store.
