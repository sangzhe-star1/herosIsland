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

## 2. Open and run

1. Launch Godot → **Import** → select this folder's `project.godot` → **Import & Edit**.
2. First import takes a minute while assets are scanned.
3. Press **F5** (or the ▶ button).

You should get: splash → tap → home → Adventure → Growth Island map →
**Cross the Road Safely** → result screen with stars → back to the map, with
progress saved.

---

## 3. What is built

**Working end to end (the vertical slice):**

| Piece | Where |
|---|---|
| Boot / Home / World Map / Result / Rewards / Parent Center | `scenes/`, `scripts/ui/` |
| Traffic-crossing minigame | `scripts/minigames/traffic_crossing.gd` |
| Save, audio, scene flow, rewards, growth stats | `scripts/core/`, `scripts/reward/` |
| Level config, 2 languages | `data/` |

**Playable levels right now: 3 of 14** — all three traffic-crossing levels.
They are three different levels built from *one* template with no extra code,
which is the whole point of the data-driven design:

- `safety_traffic_01` — one lane, slow cars, red/green only
- `safety_traffic_02` — two lanes, faster, cars that run a late green
- `safety_traffic_03` — rain, tighter gaps

The other 11 levels appear on the map as "Coming Soon" until their template
exists. Three templates remain: `collect_energy`, `item_sorting`, `animal_rescue`.

> The plan called for 12 levels; there are 14. The two extras are traffic
> variants, added so there is more than one playable level on day one.

---

## 4. Adding a level (no code)

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

## 5. Swapping the character art

Level code never names a character. It only reads a `CharacterSkin`
(`resources/skins/light_hero.tres`). Today that skin has no textures, so
`SkinnedCharacter` draws a placeholder hero from primitives — body, crest, and a
glowing chest core that levels can recolor.

To use real art: open the `.tres` in Godot, drop a texture into `idle_texture`.
Nothing in `scripts/minigames/` changes.

This is the seam that lets your son's drawings become the hero: scan at roughly
**128×192 px, transparent PNG**, drop into `assets/characters/`, assign to the
skin.

---

## 6. Chinese text

English is the default and works out of the box. Chinese strings are complete,
but Godot's built-in font has no CJK glyphs — **Chinese will render as empty
boxes until you add a font.**

1. Download Noto Sans SC from <https://fonts.google.com/noto/specimen/Noto+Sans+SC>
2. Save as `assets/fonts/NotoSansSC-Regular.ttf` (exact name)

`UiKit.theme()` picks it up automatically. Switch language in Parent Center.

---

## 7. Voice and sound

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

## 8. Exporting

Godot → **Project → Export**, add a preset, then install the export templates
when prompted (Editor → Manage Export Templates).

Order recommended in the plan: **desktop → Android → web → iOS**. Android needs
the SDK and a debug keystore; the project is already set to landscape,
touch-enabled, and the GL Compatibility renderer, which is the right target for
older tablets.

---

## 9. Design rules encoded in the code

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

## 10. Known caveats

- **This code has not been run in the Godot editor.** It was validated
  statically (`tools_check.py`: 0 errors) but the first launch may surface small
  runtime issues — a container margin, a null on a first-run save. Fix as they
  appear; the structure is sound.
- Placeholder art throughout. It is meant to be replaced.
- `Hero House` on the home screen is deliberately disabled until there is
  furniture to put in it.

## 11. On character likenesses

Ultraman, Peppa Pig and PAW Patrol are owned properties, and there are no
open-source asset libraries for them — anything labelled that way is fan art,
which cannot be licensed to you. This project ships an **original light hero**
instead: the transformation, the crest, the glowing chest core that changes
color are tropes, not protected expression, and they are yours to release.

Because of the skin system, if you do use licensed art in a private family
build, it lives in one `.tres` file and swapping it out later is a two-minute
job — not a rewrite.
