# Visual & engagement plan — the BabyBus-quality pass

The reference: BabyBus's catalogue and apps — candy-bright saturated scenes,
white rounded cards on soft pages, one adorable character anchoring every
screen, voice narrating everything, collectibles always visible, every tap
answered with bounce and sparkle. This plan maps that standard onto this
game, screen by screen and level by level, split into what is DONE, what I
can do NEXT with no new material, and what needs ART or VOICE from you
(exact filenames given — everything drops in with zero code changes).

## Phase 0 — shipped in this pass

- Real fonts at last: Noto Sans SC Medium ships in `assets/fonts/` (Chinese
  now renders identically on Mac/iPad/Android instead of relying on system
  fallback; Medium weight reads friendlier than the engine default). Drop
  `Baloo2-SemiBold.ttf` beside it any time for the rounded "toy" Latin —
  the chain in `UiKit` picks it up automatically.
- Home hub: treasure chip (stars + coins, always visible, tap = My Rewards),
  hero waves on his own every few seconds, spotlight glow, breathing
  Adventure button.
- Every button in the game bounces on release (plus the existing squash).
- My Rewards restyled as white cards on a soft page (treasure / badges /
  growth), with the bundle's progress-bar art for growth.
- Traffic: the Tap-to-Cross button no longer hides the hero (moved to the
  thumb corner); hero enlarged.
- Removed the last unused string; suite stays at 277 checks + battle probe.

## Phase 1 — next coding pass (no material needed)

1. **Sorting levels**: item cards fly to the bin on a correct drop (tween
   arc), bins wiggle when fed, bin fill-count pips. Item card enters with a
   soft bounce instead of appearing.
2. **Rescue trail**: number the paw-stones visually (1-2-3 dots are subtle);
   draw a dotted path between stones; the goal paw pulses; a little
   "footprint" trail appears behind each correct tap.
3. **Map**: world panels enter with a 60ms stagger (slide+fade, motion-gated);
   the next playable level's card gets a gentle shine sweep.
4. **Result screen**: coins fly one by one from the star row into a corner
   chip (same treasure chip as home) — the BabyBus collect-the-reward beat.
5. **Boot**: title gets a pop-in and the hero beams (power_up flare) once.

## Phase 2 — needs ART from your generator (exact slots)

Highest impact first. PNG, transparent unless noted; drop in and done.

| What | Path | Size | Note |
|---|---|---|---|
| 22 item icons | `assets/icons/teddy.png` … (list in ART_CHECKLIST §2) | 128×128 | Replaces drawn icons in all sorting levels — biggest remaining visual gap |
| Piglet Town bg | `assets/backgrounds/town.png` | 1920×1080 | Bright daytime, BabyBus palette; centre quiet |
| Safety street bg | `assets/backgrounds/street.png` | 1920×1080 | Same |
| Rescue forest bg | `assets/backgrounds/forest.png` | 1920×1080 | Same |
| Monster paintings | `assets/characters/monsters/rocky.png`, `blobbi.png`, `spikelor.png` | ~512×640, feet at bottom | Replaces the drawn kaiju, keeps all animations |
| Hero walk/extra poses | `assets/characters/tiga/hero_cheer.png` exists; a `hero_fly.png` pose | 256×384 | For a future flying bonus level |
| Daytime home/menu | overwrite `assets/backgrounds/home.png` | 1920×1080 | Only if you want the bright BabyBus mood instead of night-hero mood |

When the three world backgrounds land, tell me — wiring each is one JSON
line per level, and I'll do the pass and re-verify.

## Phase 3 — needs VOICE (the single biggest BabyBus ingredient)

BabyBus narrates everything because its players cannot read. All hooks are
wired and silent. Record on a phone (quiet room, one line per file), any
format — I'll convert to .ogg and place them. Suggested script, Chinese
first (your son's language), calm and warm:

| File (under `assets/audio/voice/level/`) | Line |
|---|---|
| `well_done.ogg` | 「太棒了！」 |
| `try_again.ogg` | 「没关系，再试一次！」 |
| `car_coming.ogg` | 「小心，有车来了！」 |
| `wrong_light.ogg` | 「红灯要等一等哦。」 |
| `safety_traffic_01_intro.ogg` | 「绿灯亮了才能过马路。准备好了吗？」 |
| `hero_city_intro.ogg` | 「和奥特曼一起收集光之能量吧！」 |

Plus the short SFX set (`assets/audio/`): correct, try_again, star, coin,
level_complete, orb_collect, power_up, beam — free CC0 packs listed in
ASSETS.md §5, or I can point at exact files next pass.

## Phase 4 — new play, once the above lands

- **Sticker book**: spend coins on stickers (reward_chest is already in);
  a page per world. This is PLAN.md's "reason to come back", BabyBus-style.
- **Boss parade**: after all three arena monsters are befriended, they
  appear waving on the map's arena panel.
- **New templates** (each = one script + JSON): memory-match with the item
  icons; a gentle rhythm-tap level using the beam on falling sparks.

## The rules that don't move (from docs/DESIGN_NOTES.md)

Whatever gets added: 2cm targets, tap-first, no time pressure, mistakes
cost a nudge and nothing else, one pulsing thing per screen, no flashing,
reduce-motion honoured everywhere, and words never carry meaning alone.
