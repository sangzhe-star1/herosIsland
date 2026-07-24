# Changelog

## 2026-07-24 (later still) — The Light Song, tap sparkles, and a sticker wall

- **New template #7, `light_echo` — the Light Song**: big candy-coloured
  pads sing a short pentatonic melody (the island theme's own notes, five
  freshly synthesized plucks), then the child taps the song back. Listen,
  hold it, reproduce it — a whole new kind of interaction, and the gentlest
  one: the game waits forever, and a wrong note just replays the song. The
  hero's chest light turns the colour of every note. Two levels (Light Song
  in Piglet Town, Tower Light Song in Hero City; 32 total) and
  challenge-ready scaling (longer songs, never faster ones).
- **Tap-anywhere sparkles**: a new autoload answers taps that land on
  nothing with a tiny golden sparkle, game-wide — at six, a tap that does
  nothing is a broken screen. Unhandled input only (never competes with
  real controls), off under reduce-motion.
- **The sticker wall**: stickers bought in My Rewards now appear along the
  bottom of the Hero House like a bedroom door; each one bounces, sparkles
  and sings a random island note when tapped. Purely for joy — no score,
  no goal, no way to be wrong.
- Suite: 331 checks + both probes, all green; Light Song verified by
  rendered screenshot.


## 2026-07-24 (continued) — Challenge gating fix, progression probe, honest docs

- **Fixed a real challenge bug**: `LevelResult.met_target()` read the
  original target from GameData, so a rank-scaled challenge SHOWED the
  bigger goal but completed at the base one. Results now carry a
  `target_override` wired to the live level data; completion is measured
  against what the label promises.
- **New progression probe** in the suite (`tests/ProgressionProbe.tscn`):
  XP maths (45 per clean run, replays pay in full, 120/rank boundaries),
  improvement-only coins (a same-star replay pays zero), the sticker
  economy (no overdrafts, no duplicates), and challenge scaling — including
  the exact regression above, plus proof that scaling never leaks into
  GameData. Snapshots and restores the save, so it is safe on a machine
  with a real child's save. `run_smoke.sh` runs it after the battle probe.
- Docs told the truth again: README (30 levels, six templates, five
  endless; art status), ART_CHECKLIST and ASSETS status blurbs updated to
  what actually ships versus what is still genuinely open (monster
  paintings, richer art, family voice recordings).


## 2026-07-24 (late night) — Music, voice pipeline, and the ever-growing level system

- **The island has music**: an original 26-second pentatonic lullaby loop
  (`assets/audio/music/island_theme.ogg`, composed and synthesized in-repo),
  playing softly from app start across every screen, ducking under voice
  lines. The Parent Center music slider controls or silences it.
- **Voice, one double-click away**: the sandbox cannot reach any usable TTS,
  so `tools/make_voice.command` generates all 8 Chinese lines on the family
  Mac using its built-in Tingting voice (no internet, no installs) straight
  into `assets/audio/voice/level/`; the audio loader now accepts .wav where
  call sites say .ogg. Three levels gained spoken intros
  (`voice_intro` on Hero City 1, Arena 1, Memory Toys).
- **Hero level**: every finished level pays experience (replays included —
  effort always counts, unlike coins which pay improvement only). The hero
  rank sits first in the home treasure chip (shield badge), the result
  screen shows a quiet +XP spark line, and rank-ups get a breathing gold
  "Level up!" banner. 120 XP per rank, rising forever.
- **Challenge levels — the level system that expands itself**: each world
  ends in a gold-star Challenge card that unlocks after its last hand-made
  level. Beating a challenge raises its rank permanently; every rank makes
  it a little bigger — denser skies, more sparks and duds, an extra memory
  pair, longer trails, busier traffic — always MORE TO DO, never faster
  reactions (the no-speed rule holds; spark lifetimes and car speeds never
  shrink). Rank shows on the map card and pays bonus XP. 30 levels total,
  five of which never run out.
- Suite: 319 checks + battle probe, all green.


## 2026-07-24 (night) — Every plan phase executed

- **Phase 1 juice**: sorting bins wear counter chips that pop as they fill;
  rescue stones turn green with a tick and a dotted path draws itself
  between them, the goal breathes; map islands drift in staggered and the
  frontier level of each world breathes; result-screen coins fly one by one
  into the treasure chip as it counts up; the boot title pops in and the
  hero's chest light flares hello.
- **Phase 2 art**: all 22 item icons generated in the badge style (sorting
  levels are now fully pictorial), and three painted scenes — town, forest,
  room — behind every sorting, rescue and memory level via the new shared
  `background_art` hook (`UiKit.scene_art`).
- **Phase 3 audio**: the game makes sound. Eight synthesized chime SFX ship
  in `assets/audio/` (correct, try_again, star, coin, level_complete,
  orb_collect, power_up, beam) — soft triads and sweeps, mixed quiet.
  Voice lines remain for the family to record (script in DESIGN_PLAN.md).
- **Phase 4 play**: the **Sticker Book** opens in My Rewards — twelve
  stickers bought with coins (first thing coins are FOR), owned ones glow;
  new **memory_match** template with Memory Toys and Forest Memory levels
  (25 levels, 6 templates); the three arena monsters **parade** on the map
  header once all are befriended. Rhythm-tap was consciously dropped:
  timing pressure conflicts with the no-speed rule, memory took its slot.
- SaveManager grows spend_coins/add_sticker (coins only ever leave through
  the sticker book); suite grows to 289 checks, all green.


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
