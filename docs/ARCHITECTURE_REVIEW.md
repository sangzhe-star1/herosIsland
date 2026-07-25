# Architecture review — the rendering layer

Written 25 July 2026, after reading every file, running the game, and
screenshotting all seventeen screens.

---

## 1. The finding, in one paragraph

The project has a good **logic** architecture and no **rendering** architecture
at all. Levels are data, templates are code, the save/audio/scene/reward seams
are clean, and one file per minigame genuinely serves many levels — that part
of the design bet has paid off. But there was no equivalent decision about what
the game *looks* like. Each screen independently chose its own scenery, mostly
by naming a PNG, and the PNG always won. The result was five incompatible
visual languages on screen at once, which is what "a collection of pasted
cutout assets" actually means in code.

---

## 2. What the screenshots showed

Seventeen screens, rendered before any changes:

| Screen | What it was drawn from |
|---|---|
| Boot, Home, Result, Hero House | a **photograph** of a real night skyline |
| Hero City levels (5) | the same photograph, plus a photo cut-out of a real broadcast tower on a black rectangle |
| Monster Arena (2) | the same photograph, with a **cartoon owl** pasted on it |
| Piglet Town, Memory (4) | a **flat pastel vector** daytime village, bunting and all |
| Rescue Forest (3) | a flat pastel forest, different palette again |
| Traffic Crossing | **grey and green rectangles** — no scenery whatsoever |
| World Map | the photograph again, with a decorative dot-to-dot line **baked into the image** that had no relationship to any level |
| Parent Center | unstyled engine default |
| Every icon, badge, panel and card | imported **navy discs and nine-patches** from an asset bundle |
| Heroes | photoreal **render cut-outs** of two licensed characters |

Five styles is generous — counting the drawn `IconLibrary` primitives, which
were being overridden by the navy badge PNGs and so almost never appeared, it
was six.

Three further problems followed from the same root cause:

- **No shared ground.** `collect_energy` put its horizon at y=620,
  `monster_battle` at 620, `traffic_crossing` had none, and every screen picked
  its own hero scale (`1.15`, `1.3`, `1.5`, `2.0`). Characters stood at
  different heights and different sizes from screen to screen.
- **No shared light.** Nothing agreed on where the sun was, and nothing cast a
  contact shadow. A cut-out with no contact shadow is the single most reliable
  tell that a figure was pasted onto a background.
- **Nothing could change.** The energy tower's "repair" was a texture swap
  between two PNGs; the lamp the child had to colour-match was a `Panel`
  floated on top of the photograph. A picture cannot be an instruction.

---

## 3. The root cause

There were two doors into the renderer and both led outside:

```gdscript
UiKit.background(self, colour, "res://assets/backgrounds/home.png")  # shell screens
UiKit.scene_art(_play_area, config)   # levels, via a "background_art" key in JSON
```

Both said the same thing: *if a PNG exists, use it; otherwise fall back to
something drawn.* Repeated in fourteen places, that rule guarantees the
imported art always wins and the drawn code is dead. It also puts art direction
in `data/levels.json`, where twenty-six levels each named a file, so "make the
game look like one place" was a twenty-six-row edit with no single owner.

The fix is not better pictures. It is **one renderer, with no second path.**

---

## 4. What was built

Five new files under `scripts/world/`, and every screen rewired through them.

### `shapes.gd` — the drawing language
One outline colour, one weight rule (proportional to a shape's size), one light
direction (`LIGHT_DIR`), one rounding convention, one contact shadow, one glow,
one star. Every drawn thing in the game — background hills, hero armour,
sorting shapes, icons, map coastline — goes through it. **Cohesion is not an
art problem, it is a constructor problem:** a prop written six months from now
cannot come out in a different style because there is no other way to draw one.

### `world_style.gd` — five worlds, one day
Each world is the same island at a different hour: Piglet Town late morning,
Safety Bureau noon, Rescue Forest golden afternoon, Hero City dusk, Monster
Arena night. Same shapes, same ground line, same light rule — only the light
changes. That gives each world its own feel without ever leaving the style,
which was the whole failure mode being replaced. A level may nudge its world
(`weather`, `calm`, `damaged`); it may not name a picture.

### `stage.gd` — the world renderer
Sky gradient → sun/moon → stars → high cloud → three parallax horizon bands →
horizon haze → ground plane → ground detail → props on the ground line → low
cloud → airborne motes → optional calm veil → foreground fringe. All polygons,
no textures, seeded per level so a child replaying a level returns to the same
place. It publishes `ground_y()` and `place()`, so **every actor in the game
now stands on one floor.**

`calm` is the piece that makes one world serve every template: a sorting grid
over a busy meadow is harder to look at than it is pretty, so reading-heavy
templates ask for a warm veil that quiets the scenery without changing worlds.

### `hero_art.gd` — the heroes
Jointed parts in the same shape language, with poses (idle, cheer, beam, hurt,
walk) and real transitions between them. A skin is now a *design* — proportions,
crest shape, chest pattern, four colours — so Tiga-like, Zero-like and the
original light hero are three `.tres` files, not two photographs and a
placeholder. The photo cut-outs are kept in `resources/skins/photo/` as opt-in.

This buys four things a PNG cannot: poses, scene lighting, runtime recolouring
(the chest core **is** the instruction in the colour-matching levels), and a
build that can leave the house.

### `energy_tower.gd`, `island_map.gd` — landmarks
The tower is an object with `set_light_color()` and `repair()`, so "Repair the
Energy Tower" tells its story by *changing* rather than by swapping images. The
map is one island generated from the level data, with a path that runs through
the actual marker positions — adding a level in JSON extends the path and grows
the coastline.

---

## 5. The other finding: this project could not see itself

`PLAN.md` opens with it: *"I build it without an engine — I can read code and
check it statically, but I cannot see a button overlap its label."* That is the
most expensive constraint in the repository, and it is fixable in half an hour.

`tests/shots.sh` renders all seventeen screens to PNG in about twenty seconds,
headless, on a machine with no GPU. During this pass it caught, in order:

1. props drawing **on top of buttons** (scenery had positive `z_index`),
2. the splash screen coming out **solid navy** (a failsafe rectangle sat in
   front of the world, because scenery draws behind everything),
3. five map signposts **720 pixels tall** (a `PanelContainer` on a plain
   `Control` grows to its parent, and the parent was the whole island),
4. heroes rendering at the **wrong size** (`set_height()` was called before
   `_ready()` built the figure, so it was silently discarded),
5. buildings standing **on the sea**.

Every one of those passed `tools_check.py` and the smoke test. None of them
would have been found by reading code.

**Recommendation: run `tests/shots.sh` the way you run `run_smoke.sh`.** It is
the difference between a project that ships what it intended and one that ships
what it typed.

One thing it cannot catch, and the one that actually bit on first run: **a
stale class cache**. Godot resolves global class names from
`.godot/global_script_class_cache.cfg`, which only the editor rewrites. Adding
a `class_name` and then launching without opening the editor first makes every
script that references it fail to *parse*, so the game boots to a blank
window with no error on screen. `run_smoke.sh` refreshes the cache before
testing and `tools_check.py` warns when it detects the condition — run either
one after pulling changes that add a class.

---

## 6. What was deliberately not changed

- **Level logic.** Not one gameplay rule was touched. All 36 levels still boot
  clean (`0 failures`), and `tools_check.py` reports `0 errors, 0 warnings`.
- **The data-driven design.** Still one file per template, still JSON per level.
  The rewrite removed a key (`background_art`) rather than adding any.
- **The child-facing rules** in README §11 — one star minimum, no fail state,
  no flashing, reduce-motion, ≥220×120 touch targets. The new map markers are
  148px discs, which is larger in area than the rectangular minimum, and every
  new animation checks `Juice.motion_enabled()`.
- **The audio pipeline.** Untouched.

## 7. What is still worth doing

Ordered by how much it would change a six-year-old's experience:

1. **Voice lines.** Unchanged from PLAN.md §3 and still the highest-value hour
   in the project. He cannot read; the voice is the instruction.
2. **Sorting bins and number tiles** are still flat rounded rectangles. They
   are gameplay objects sitting in a drawn world; drawn crates and wooden
   number blocks would finish the job.
3. **A shared `Creature` class** for the arena monsters and the rescue
   animals, the way `HeroArt` is shared by the three heroes. `monster.gd` is
   now on `Shapes` and has a proper face rig; the rescue animals are not.
4. **Playtest and cut** — PLAN.md Phase 4, unchanged and still the only phase
   that can tell you which levels deserve more polish.
