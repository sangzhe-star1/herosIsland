# Little Heroes Growth Island

A level-based learning game for a six-year-old. Godot 4 + GDScript, data-driven
levels, local save only. No ads, no payments, no loot boxes, no network calls,
no strangers.

---

## 1. Install Godot

Download **Godot 4.7 (Standard, not .NET)** from <https://godotengine.org/download>.
It is a single executable with no installer and no dependencies.

- **macOS** — unzip, drag `Godot.app` to Applications. First launch: right-click → Open.
- **Windows** — unzip, run `Godot_v4.7-stable_win64.exe`.

**Pin this version.** Godot 4.x minor releases occasionally change API details.
Finish the first release before upgrading.

## 2. Verify it works

Run the smoke suite to check scene startup, data consistency, progression and
touch behavior. It copies the current project into a temporary directory with
its own save directory, imports that copy and runs 29 probes serially:

```bash
./tests/run_smoke.sh
```

Eight probes need a window. On Linux without a display, install/use xvfb to
include them; otherwise the summary explicitly reports skipped probes. A full
run requires `Suite finished: 29 passed, 0 skipped`. Allow several minutes for
the suite. See [QA runner usage](docs/QA_RUNNER.md) for individual probes,
timeouts, screenshot output and saved logs.

**If it says "Could not find Godot":** you launched Godot straight from the
download, so macOS is running it from a randomised read-only path (App
Translocation). Fix it once:

```bash
mv ~/Downloads/Godot.app /Applications/
```

That also clears the translocation, which can cause odd behaviour in the editor
itself. Or point at it directly with
`GODOT=/path/to/Godot.app/Contents/MacOS/Godot ./tests/run_smoke.sh`.

It exists because this project was written without a running engine. A parser
error in a file the boot screen never touches once blanked the whole game while
every static check passed — actual engine startup catches that class of fault.

**If it reports `Identifier "X" not declared in the current scope`:** that is
Godot's class cache being stale, not a code bug. The editor rewrites the cache
when it scans; headless runs read it as-is, so a `class_name` added since the
editor last opened the project is invisible to them. `run_smoke.sh` now
refreshes the cache before testing, and `tools_check.py` warns when it detects
the condition. Opening the project in the editor once also fixes it.

Also run the static checker after editing any data file:

```bash
python3 tools_check.py
```

And **look at the game** after any visual change:

```bash
./tests/shots.sh              # every screen -> /tmp/heroes-shots/*.png
```

Twenty seconds, no keyboard, works headless. This project spent months unable
to see its own output, which is the most expensive thing in its history — see
`docs/ARCHITECTURE_REVIEW.md` §5 for the list of bugs this caught that every
static check passed.

## 3. Open and run

1. Launch Godot → **Import** → select this folder's `project.godot` → **Import & Edit**.
2. First import takes a minute while assets are scanned.
3. Press **F5** (or the ▶ button).

You should get: splash → tap → home → Adventure → Growth Island map →
**Cross the Road Safely** → result screen with stars → back to the map, with
progress saved.

---

## 4. What is built

**Working end to end (the vertical slice):**

| Piece | Where |
|---|---|
| Boot / Home / World Map / Result / Rewards / Parent Center | `scenes/`, `scripts/ui/` |
| Traffic-crossing minigame | `scripts/minigames/traffic_crossing.gd` |
| Save, audio, scene flow, rewards, growth stats | `scripts/core/`, `scripts/reward/` |
| Level config, 2 languages | `data/` |

**All 30 levels are playable**, from six templates — including the Monster
Arena's beam battles (`monster_battle`: the monster ends up tired and happy,
never hurt) and pair-finding (`memory_match`). Five of the thirty are
**Challenge levels** that grow one rank bigger every time they are beaten,
so the game never runs out (CHANGELOG.md and `docs/DESIGN_PLAN.md` tell that
story):

| Template | Levels | Mechanic |
|---|---|---|
| `traffic_crossing` | 3 | wait for green, check for cars, cross |
| `item_sorting` | 5 | drag or tap an item into the right bin |
| `collect_energy` | 3 | tap the right falling things, ignore the rest |
| `animal_rescue` | 3 | follow a trail in order, route around hazards |

Each template is one file. Every level built on it differs only by its `config`
block in `data/levels.json` — no new code per level. That is the whole design
bet, and it is now proven three times over.

See `PLAN.md` for the long-term roadmap.

> The plan called for 12 levels; there are 14. The two extras are traffic
> variants, added so there was more than one playable level on day one.

---

## 5. Adding a level (no code)

Add an entry to `data/levels.json`:

```json
{
  "id": "safety_traffic_04",
  "world": "safety",
  "name_key": "level.safety_traffic_04",
  "game_type": "traffic_crossing",
  "difficulty": 3,
  "requires": "safety_traffic_03",
  "config": { "car_speed": 240.0, "car_gap_min": 1.2, "lanes": 2 },
  "target": { "correct_crossings": 5 },
  "reward": { "coins": 25, "badge": "road_guardian" }
}
```

Then add `level.safety_traffic_04` to both locales in `data/strings.json`.
It shows up on the map on the next run. Nothing else to touch.

`config` keys for `traffic_crossing`: `car_speed`, `car_gap_min`, `car_gap_max`,
`green_seconds`, `red_seconds`, `lanes`, `late_cars`, `rain`.

Run `python3 tools_check.py` to validate — it checks every resource path,
every translation key, level/badge/world references, and autoload ordering.

---

## 6. The heroes, and how to make another one

> Full art notes: `ART_CHECKLIST.md`. The reasoning: `docs/ARCHITECTURE_REVIEW.md` §4.

Level code never names a character. It only reads a `CharacterSkin`, and a
skin is a **design**, not a pair of pictures:

```
build_width    76        # one number resizes the whole figure
crest_kind     fin | twin | horns      # the silhouette from across the room
chest_pattern  blade | chevron | bands
body_color / accent_color / trim_color / eye_color / core_color
```

`HeroArt` draws that: jointed limbs, five poses, a chest core the game
recolours mid-level, breathing while it waits. Three heroes ship — `light_hero`,
`tiga`, `zero` — and a fourth is a new `.tres` in `resources/skins/`, no code.

A skin **may** carry pictures instead (`prefer_texture = true`). That is the
seam for a scan of your son's own drawing — roughly 128×192 px, transparent
PNG. It is opt-in rather than the default because a picture cannot be posed,
cannot be lit to match a scene, and cannot have its chest light recoloured,
which the colour-matching levels depend on.

## 7. Fonts and Chinese text

**See `ASSETS.md` for the full art and font shopping list.** Short version: two
font files are the biggest single visual improvement available, and take about
ten minutes.

| File | Path |
|---|---|
| [Baloo 2 SemiBold](https://fonts.google.com/specimen/Baloo+2) | `assets/fonts/Baloo2-SemiBold.ttf` |
| [Noto Sans SC Regular](https://fonts.google.com/noto/specimen/Noto+Sans+SC) | `assets/fonts/NotoSansSC-Regular.ttf` |

`UiKit.theme()` chains them, so Baloo 2 renders Latin text and Noto fills in
every Chinese glyph automatically. English works with neither font installed;
**Chinese renders as empty boxes until Noto is present**. Switch language in
Parent Center.

---

## 8. Voice and sound

Every `AudioManager.play_voice()` / `play_sfx()` call silently no-ops when the
file is absent, so the game is fully playable with zero audio today. Drop in
`.ogg` files to turn each one on:

```
assets/audio/correct.ogg, try_again.ogg, star.ogg, level_complete.ogg
assets/audio/voice/level/well_done.ogg, wrong_light.ogg, car_coming.ogg
assets/audio/voice/level/safety_traffic_01_intro.ogg
```

A six-year-old may not read fluently — **voice is the real instruction channel**,
and recording your own (or your son's) is the highest-value hour you can spend
on this project.

---

## 9. Exporting

Godot → **Project → Export**, add a preset, then install the export templates
when prompted (Editor → Manage Export Templates).

Order recommended in the plan: **desktop → Android → web → iOS**. Android needs
the SDK and a debug keystore; the project is already set to landscape,
touch-enabled, and the GL Compatibility renderer, which is the right target for
older tablets.

---

## 10. Visual design

**The game draws its own world.** There are no background images, no imported
UI art and no character photographs in the running game. Every pixel of scenery
is generated from `scripts/world/`, which buys four things a picture cannot:
the world can be lit per world, generated per level, animated, and recoloured
at runtime — and the last of those matters, because in the colour-matching
levels the hero's chest light and the tower's lamp **are** the instruction.

`docs/ARCHITECTURE_REVIEW.md` is the full reasoning. The short version:

| File | What it owns |
|---|---|
| `scripts/world/shapes.gd` | the drawing language: one outline, one weight rule, one light direction, one shadow, one glow |
| `scripts/world/world_style.gd` | five worlds as five hours of one day |
| `scripts/world/stage.gd` | the layered parallax renderer every screen puts behind itself |
| `scripts/world/hero_art.gd` | the heroes, jointed and posable |
| `scripts/world/island_map.gd` | Growth Island, generated from `data/levels.json` |
| `scripts/world/energy_tower.gd` | the landmark that breaks and gets repaired |

There are exactly two ways scenery reaches the screen, and no third:

```gdscript
build_world(_play_area, calm)                        # inside any level template
UiKit.world_background(self, world_id, seed, calm)   # on a shell screen
```

A level may nudge its own world through its `config` — `weather`, `calm`,
`damaged` — but it cannot name a picture. That door is what let the game end up
with a photographic night city, a flat pastel village and a grey rectangle on
screen at the same time.

**Every world is the same island at a different hour.** Piglet Town is late
morning, the Safety Bureau is flat noon, Rescue Forest is golden afternoon,
Hero City is dusk when the windows light up, Monster Arena is night. Same
shapes, same ground line, same sun direction — only the light changes. That is
what gives each world its own feeling without any of them leaving the style.

**Everything stands on one floor.** `Stage.ground_y()` is the ground line for
the whole game, and characters are sized with `set_height(pixels)` rather than
a scale factor, so a hero is the same size in the forest as in the city.

Colours live in `scripts/ui/palette.gd` and nowhere else. Every text pairing is
verified against WCAG AA (4.5:1 body, 3:1 for large button text). Text over the
world goes through `UiKit.on_art()`, which outlines it — a white instruction
that is legible over a dusk skyline is invisible over a midday cloud.

Buttons are drawn as physically raised slabs: a thick bottom edge in a darker
shade of the button's own colour, which shrinks on press while the label slides
down, so the button visibly squashes. For a child who cannot read, that motion
is what confirms a tap landed. The map's level markers are round rather than
slabs, but use the same physics — a child who has learned one button has
learned all of them.

Icons are drawn from primitives in `scripts/ui/icon_library.gd`, forty-five of
them, all through `Shapes`. A bare icon name is always drawn; artwork has to be
asked for by full path. (The previous rule was the reverse, which quietly meant
the whole game rendered a set of imported navy badge discs instead of its own
icons.)

Celebration lives in `scripts/ui/juice.gd`, under two rules: reward motion is
generous and correction motion is not (confetti for right, a small nudge for
wrong — never a buzz, screen shake or red flash), and all of it can be switched
off from Parent Center. Every animation in `scripts/world/` checks
`Juice.motion_enabled()` too, including the drifting clouds and the hero's
breathing.

## 11. Design rules encoded in the code

These are enforced in `level_result.gd`, `level_manager.gd` and `ui_kit.gd`, not
just written down:

- **Finishing always earns at least one star.** Mistakes take 3 → 2 → 1, never 0.
- **Stars never go down.** A worse replay cannot erase what was earned.
- **No fail state.** A wrong tap = calm voice + step back + try again.
- **Coins pay only the improvement**, so replaying is fun but not a farm.
- **Touch targets ≥ 220×120 px.** Small fingers miss small buttons.
- **No flashing.** Pulses are slow and low-contrast.
- **Parent gate**: 3-second hold, then arithmetic. Hard for a child, trivial for you.
- **Daily limit is advisory** — it suggests a break, it never locks a child out mid-level.

---

## 12. Known caveats

- **Nothing here has been played by a child yet.** All 36 levels boot clean and
  every screen has been rendered and looked at, but `tests/shots.sh` cannot
  tell you whether a level is fun.
- **`scripts/battle/monster.gd` is the last thing not on the house style.**
  The creatures are drawn from primitives already and they read fine, but they
  use their own outline and shading conventions rather than `Shapes`, so they
  are close to the style rather than in it. See the review's §7.
- **Sorting bins and number tiles are still flat rounded rectangles** — the
  gameplay objects that have not been drawn as world objects yet.
- **`assets/backgrounds/`, `assets/icons/`, `assets/ui/` and
  `assets/characters/` are no longer loaded by the running game.** They are
  left in place because the licensed hero art is still reachable through
  `resources/skins/photo/`, and because deleting a folder is your call, not
  mine. Nothing breaks if you remove the rest.

## 13. On character likenesses

Ultraman, Peppa Pig and PAW Patrol are owned properties, and there are no
open-source asset libraries for them — anything labelled that way is fan art,
which cannot be licensed to you.

This project now ships **original drawn heroes**. The transformation, the
crest, the glowing chest core that changes colour are genre tropes, not
protected expression, and they are yours to release. `tiga` and `zero` are
original designs in the game's own style that borrow the *vocabulary* a child
recognises — a fin crest, twin blades, red-and-silver, blue-and-silver — and
copy no particular character's expression.

The licensed photographic render cut-outs from the asset bundle are still in
`resources/skins/photo/`, unreferenced. To use them in a private family build,
point `data/characters.json` at `photo/tiga_photo.tres` instead of `tiga.tres`.
**Do not do that for a build that leaves the house.** Nothing else has to
change either way, which is the entire point of the skin seam.

**Drop-in characters** are the two-PNG version of the same seam: save a
transparent `hero_idle.png` (~256×384, feet at the bottom edge, and
`hero_cheer.png` if you have one) into `assets/characters/bluey/`, restart,
and Bluey appears in the Hero House as a playable character. The same rule
applies: a favourite licensed character is for this household's build only.
The id list lives in `GameData.DROPIN_CHARACTERS`; add an id there and a
folder for it to add another.

## 14. Where things stand

Historical checks after the rendering rewrite:

```
python3 tools_check.py     ->  0 errors, 186 warnings   (warnings are old debt)
./tests/run_smoke.sh       ->  22 checkpoints (historical suite)
./tests/shots.sh           ->  21 screens rendered and looked at
```

The current smoke manifest has 29 probes and reports passed/skipped counts.
The isolated runner has passed its unit checks and a current-source 1094-check
GardenTouchProbe run with two garden screenshots; the full 29-probe suite has
not been rerun in this iteration. See [garden runtime evidence](docs/GARDEN_RUNTIME_QA_20261002.md).

What has never happened: **a child has played it.** That is Phase 4 in
`PLAN.md` and it is still the only thing that can tell you which levels are
worth more work. Put it in front of him, watch without helping, and note which
level he asks to replay.

### Git housekeeping

If a sandbox left lock files behind, git may refuse to run until they are gone:

```bash
rm -f .git/index.lock .git/HEAD.lock
rm -f .git/objects/*/tmp_obj_*
git status
```
