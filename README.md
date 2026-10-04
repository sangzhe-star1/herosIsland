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

You should get: splash → tap → home with five cards → **去冒险 / Adventure** →
Growth Island map → the first Sunny Park level → result screen with stars →
back to the map, with progress saved.

---

## 4. What is built

**Five doors on the home screen**, in reading order, which is importance order:

| Card | Where it goes | Code |
|---|---|---|
| 去冒险 · Adventure | Growth Island map, 34 levels across five worlds | `scripts/ui/world_map.gd`, `scripts/world/island_map.gd` |
| 我的奖励 · My Rewards | badges, stars, the monster album | `scripts/reward/`, `scenes/reward/` |
| 英雄小屋 · Hero House | dress-up room, furniture, the star-coin shop | `scripts/shop/`, `scripts/skin/` |
| 星光菜园 · Star Garden | the farm (care gestures, daily jobs, the bear, the kitchen), plus the ten 丰收行动 harvest levels | `scripts/garden/`, `scripts/harvest/` |
| 光之战士 · Light Warrior | fifteen monster duels in a row, one door, always the next unbeaten one | `scripts/battle/`, `scripts/minigames/monster_duel.gd` |

Behind them: boot, result screen, parent center, save, audio, scene flow,
rewards and growth stats in `scripts/core/`, `scripts/ui/` and `scripts/reward/`.

**61 levels, all data**, in `data/levels.json`. A level's `mode` decides which
door it sits behind; a level with no `mode` is a pin on the island map.

| `mode` | Levels | Lives behind |
|---|---|---|
| *(none)* | 34 | the island map, 5 worlds of 6 to 8 levels |
| `battle` | 15 | 光之战士; every one is a Challenge level that grows a rank each time it is beaten |
| `harvest` | 10 | the Star Garden |
| `standalone` | 1 | the Star Garden itself |
| `deco` | 1 | the garden's decoration room |

The five worlds, in order: 阳光公园 Sunny Park, 夜光城市 Night City,
怪兽山谷 Monster Valley, 天空基地 Sky Base, 黑暗城堡 Dark Castle.

**Fourteen templates are in use.** Each template is one file in
`scripts/minigames/` (the garden lives in `scripts/garden/`), and every level
built on it differs only by its `config` block. No new code per level. That is
the whole design bet.

| Template | Levels | What the child does |
|---|---|---|
| `monster_duel` | 21 | beam, shield and dodge a monster until it is tired and happy, never hurt; later monsters are opened by the move their album card names |
| `harvest_action` | 10 | pull, dig, shake and sort crops with drawn gestures; the crops are 2.5D renders from `assets/harvest_3d/` |
| `platform_adventure` | 6 | run and jump through a side-scrolling level |
| `build_repair` | 4 | put a broken thing back together in order |
| `puzzle_mechanism` | 4 | work out how a machine opens |
| `matching_sorting` | 3 | drag each thing into the bin it belongs in |
| `memory_rhythm` | 3 | play back a sequence of lights or sounds |
| `observation_search` | 2 | find the hidden things in a scene |
| `roleplay_rescue` | 2 | someone is in trouble; pick the thing that helps |
| `creative_play` | 2 | free decoration with no wrong answer |
| `keepy_uppy` | 1 | keep a balloon off the ground |
| `light_defense` | 1 | a stream of monsters walks in; tap anywhere to blast, and pick an upgrade between waves |
| `light_echo` | 1 | the light pads sing a short song and he taps it back |
| `garden` | 1 | the Star Garden farm; its beds grow the same 2.5D crop renders the harvest levels use |

**Seven more templates are in the code but no level uses them:**
`traffic_crossing`, `item_sorting`, `collect_energy`, `animal_rescue`,
`memory_match`, `monster_battle`, `monster_expedition`. They are from the
first version of the game. `tests/difficulty_probe.gd` prints them on every run
and fails if the list grows. Giving them levels again or deleting them is an
open decision; see `PLAN.md`.

See `PLAN.md` for the roadmap and `CHANGELOG.md` for how each piece got here.

---

## 5. Adding a level (no code)

Add an entry to the list in `data/levels.json`:

```json
{
  "id": "sunny_park_07",
  "world": "sunny_park",
  "name_key": "level.sunny_park_07",
  "game_type": "matching_sorting",
  "difficulty": 2,
  "requires": "sunny_park_06",
  "target": {},
  "reward": { "coins": 26, "badge": "super_sorter" },
  "config": {
    "count": 10,
    "instruction_key": "sorting.instruction",
    "bins": [
      { "key": "toy",    "icon": "teddy",   "colour": "#5fb0e8" },
      { "key": "danger", "icon": "warning", "colour": "#e2703c" }
    ]
  }
}
```

Then add `level.sunny_park_07` to both locales in `data/strings.json`.
It shows up on the map on the next run. Nothing else to touch.

A level that should **not** be on the map gets a `mode` (see §4), and must say
where its back button goes, or `tools_check.py` refuses it:

| Field | Points at | Used by |
|---|---|---|
| `config.exit_room` | another level | harvest levels → the garden, decoration room → the garden |
| `config.exit_to` | a screen that is not a level (`"home"`) | the garden, the battles |
| neither | the world map | the 34 island levels |

The rule is that he leaves by the door he came in through.

Run `python3 tools_check.py` to validate. It checks every resource path,
every translation key, level/badge/world references, exits, and autoload
ordering.

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
recolours mid-level, breathing while it waits. Fourteen characters are listed in
`data/characters.json`, ten of them unlocked from the start, and another one is
a new `.tres` in `resources/skins/` plus one entry there, no code.

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
| [Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC) | `assets/fonts/NotoSansSC.otf` — **already in the repo** |

`UiKit.theme()` chains them, so Baloo 2 renders Latin text and Noto fills in
every Chinese glyph automatically. Noto ships with the project, so Chinese
renders out of the box. Baloo 2 is still optional; without it Noto draws the
Latin text as well. Switch language in Parent Center.

---

## 8. Voice and sound

Every `AudioManager.play_voice()` / `play_sfx()` call silently no-ops when the
file is absent, so a missing line never breaks a level.

The sound effects and music are generated, not downloaded:
`python3 tools/make_audio.py` writes every file under `assets/audio/` from one
set of primitives, so they all sound like they came from one room. The voice
lines under `assets/audio/voice/level/` are generated on a Mac by
`tools/make_voice.command`, using the Chinese system voice. The script for
every line is `docs/VOICE_SCRIPT.md`, and `tests/VoiceCheck.tscn` checks that
every level finds a line that actually loads.

A six-year-old may not read fluently — **voice is the real instruction
channel**. Replacing a synthetic line with your own voice is the same file
name in the same folder, and it is still the highest-value hour you can spend
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

**Every world is the same island at a different hour.** Sunny Park is nine in
the morning by the sea, Sky Base is a low sun above the clouds, Monster Valley
is last light in a green valley, Night City is half past nine from a rooftop,
and Dark Castle is a big moon and braziers — night-time, never frightening.
Same shapes, same ground line, same sun direction — only the light changes.
That is what gives each world its own feeling without any of them leaving the
style. The per-world settings are in `scripts/world/world_style.gd`.

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

- **Real play has started, and it drives the work.** Since late July the
  changes come from watching him play: getting lost behind the garden's exit,
  finding the monster fights too easy. `CHANGELOG.md` records each of those
  reports and what changed. `tests/shots.sh` still cannot tell you whether a
  level is fun.
- **Seven templates have no levels.** See §4. They still pass the smoke test
  and still collect lint warnings, which is most of the "hard-coded 1280" debt
  that `tools_check.py` reports.
- **`scripts/battle/monster.gd` is the last thing not on the house style.**
  The creatures are drawn from primitives already and they read fine, but they
  use their own outline and shading conventions rather than `Shapes`, so they
  are close to the style rather than in it. See the review's §7.
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

Verified on 4 October 2026, on this branch rebased onto the 3D-art commit:

```
python3 tools_check.py     ->  0 errors, 203 warnings   (warnings are old debt)
./tests/run_smoke.sh       ->  Suite finished: 30 passed, 0 skipped
```

The suite copies the project to a temporary directory with its own save,
imports it, then runs 30 probes in order (`tests/smoke_suite.json`). On Linux
without a display it needs `xvfb-run` for the eight windowed probes. Two
engine notices at exit, "resources still in use" and "RID allocations
leaked", are not failures and the runner ignores them; anything else that
says `ERROR:` still fails the run.

The warnings are almost all translation keys nothing uses yet and screen edges
hard-coded as 1280 or 720 in the unused templates. Do not let the count grow.

The work follows the playtest loop in `PLAN.md` Phase 4: watch him play, write
down what he says, fix the thing, keep a check that proves it stays fixed.
`CHANGELOG.md` is the record of that loop, one section per round.

### Git housekeeping

If a sandbox left lock files behind, git may refuse to run until they are gone:

```bash
rm -f .git/index.lock .git/HEAD.lock
rm -f .git/objects/*/tmp_obj_*
git status
```
