> **Superseded, 25 July 2026.** Every slot in this checklist has been filled by
> drawn art generated at runtime, and the game no longer loads image files. Do
> not work through it. The equivalent document now is `docs/ARCHITECTURE_REVIEW.md`
> (why) plus `scripts/world/` (how) — and the way to change how something looks
> is to edit the code that draws it, then run `./tests/shots.sh` and look.
>
> Kept for the record of what the pipeline used to be.

# Complete art checklist

Every image slot in the game, with the exact filename and size to produce.

> **Status — July 2026:** the `ultraman_tiga_zero_complete_game_bundle` has been
> integrated. Filled from it: both hero skins (Tiga and Zero, chosen in the Hero
> House; the original drawn Light Hero remains available), the home and map
> backgrounds (`menu_bg` and `level_select_bg` from the bundle), the Hero City
> set (`city.png`, `tower.png` + broken/repaired states, `city_damaged.png`,
> `orb.png`, `rock.png`), the result-screen `victory.png`, the full icon-badge
> set (star, coin, heart, warning, house, spark and friends), the character
> select cards, the reward chest, and the `sparkle.png` / `collect_flash.png` /
> `power_up.png` effects. Six icons the bundle lacked — `check`, `flag`,
> `gear`, `car`, `sort`, `paw` — were generated in the same badge style
> (`assets/icons/`), so navigation and bins are fully textured and consistent.
> **Later that day:** the 22 item icons were generated in the same badge style
> (drop richer versions on the same filenames any time), painted town / forest
> / room scenes now sit behind the sorting, rescue and memory levels, eight
> synthesized SFX and an original music loop live in `assets/audio/`, and
> `tools/make_voice.command` generates the Chinese voice lines on the Mac.
> Still genuinely open: monster paintings (`assets/characters/monsters/`),
> a `street.png` for the traffic world if ever wanted, richer backgrounds,
> and real family voice recordings to replace the synthetic ones.
> Interaction principles behind the wiring: `docs/DESIGN_NOTES.md`.
>
> **Monster Arena:** the three battle monsters (`rocky`, `blobbi`, `spikelor`)
> are drawn procedurally. To replace one with real art, drop a PNG at
> `assets/characters/monsters/<id>.png` — transparent background, feet at the
> bottom edge, roughly 512 × 640 — and it takes over automatically, keeping
> every animation (flinch, puff, happy exit). Battle sound hooks, silent until
> the files exist: `assets/audio/beam.ogg` (each shot) plus the shared
> `correct/try_again/level_complete` set.
>
> **Licence note:** the Tiga and Zero skins depict recognisable Tsuburaya
> characters. They are for this household's own tablet only — a build that
> leaves the house must ship with `light_hero` (or other original art) as the
> only skins. `data/characters.json` is the single place to remove them.

**Format for everything: PNG, RGBA with real transparency, no baked background.**
Not JPG — it has no alpha channel and will give you white boxes behind every
icon.

**How it works:** drop a file at the listed path and it appears. No code change,
no data change. Anything you have not supplied keeps its drawn placeholder, so
you can do this ten files at a time and the game stays playable throughout.

---

## Before you start: the Ultraman question

You asked for assets "resembling Ultraman Tiga". There are two different things
there, and the difference matters a lot.

**Copying Tiga** — using screenshots, ripped sprites, official art, or a close
likeness. Fine on your own machine for your own child. It cannot be shared,
uploaded, put on any store, or sent to another parent. Tsuburaya Productions
enforces this actively, including against small fan projects.

**Evoking Tiga** — original art that uses the tropes: silver-and-red giant,
crest fin on the head, a round chest light that changes colour, a beam pose,
fighting a monster. Tropes are not protected. This you own outright and can
release.

Practically, for a commissioned artist or an image generator, the instruction
that gets you 90% of the feeling with none of the risk is roughly:

> A friendly giant hero for young children. Silver body with red accent stripes,
> a smooth featureless helmet-like head with large glowing oval eyes, a fin
> crest along the top of the head, and a round glowing light in the centre of
> the chest. Simple, rounded, cartoon proportions. Full body, front-facing,
> standing. Transparent background.

Note it never names Tiga, and it produces something your son will read as "the
light hero" instantly. **My recommendation: do this once, properly, and it
becomes yours.** The chest light is already wired as a game mechanic — it
changes colour in the Repair the Energy Tower level and tells him which orbs to
collect.

Either way, the skin system means swapping later is one file.

---

## 1. The hero — highest priority

`resources/skins/light_hero.tres` fields, set in the Godot inspector.

| What | Path to save to | Size | Notes |
|---|---|---|---|
| Standing pose | `assets/characters/hero_idle.png` | 256 × 384 | Full body, front-facing, feet at the bottom edge |
| Portrait (optional) | `assets/characters/hero_portrait.png` | 256 × 256 | Head and shoulders, for menus |
| Walk cycle (optional) | `assets/characters/hero_walk_1..4.png` | 256 × 384 | 4 frames; skip for now, the game does not need it |

**Important:** draw the chest light in a **neutral white or pale grey**, not
coloured. The game tints it at runtime — that is how the colour-matching level
works. A pre-coloured red light cannot be recoloured convincingly.

After adding: open `light_hero.tres` in Godot, drag `hero_idle.png` into the
`Idle Texture` field. That is the whole integration.

---

## 2. Item icons — 22 files

All **128 × 128**, transparent, centred with a small margin. Save to
`assets/icons/`.

Then in `data/levels.json`, change each item's `"text_key"` line to add an
`"icon"` field, e.g. `"icon": "res://assets/icons/teddy.png"`. Tell me when the
files are in and I will do that edit in one pass.

**Toys and home** (Tidy Up the Room, Spot the Danger)
```
teddy.png          ball.png           blocks.png
picture_book.png   comic.png          socks.png
tshirt.png         hat.png            pillow.png
crayon.png
```

**Dangerous things** (Spot the Danger)
```
knife.png          matches.png        scissors.png
medicine.png       socket.png
```

**Rescue supplies** (Choose Rescue Tools)
```
bandage.png        plaster.png        berries.png
fish.png           carrot.png         blanket.png
scarf.png
```

---

## 3. Bin and status icons — 2 files

**128 × 128**, transparent, `assets/icons/`.

```
check.png       green tick — the "safe" bin
warning.png     hazard triangle — the "dangerous" bin, and rescue hazards
```

---

## 4. Navigation icons — 8 files

**128 × 128**, transparent, `assets/icons/`. These are what let your son
navigate without reading, so clarity beats detail — they are seen at ~110px.

```
flag.png     Adventure button        house.png    Hero House button
star.png     Rewards button          gear.png     Parents button
car.png      road-safety levels      sort.png     sorting levels
spark.png    collecting levels       paw.png      rescue levels
```

**Good Ultraman-flavoured substitutions**, if you want the theme to carry
through: `spark` as the chest-light glow, `star` as a beam-pose sparkle,
`flag` as a hero emblem.

---

## 5. Backgrounds — 6 files

**1920 × 1080** (downscaled cleanly to the 1280 × 720 viewport), PNG or JPG —
these are the only files where JPG is fine, since they have no transparency.

| Path | Where it appears |
|---|---|
| `assets/backgrounds/home.png` | Home screen — already wired |
| `assets/backgrounds/map.png` | Growth Island map — already wired |
| `assets/backgrounds/city.png` | Light Energy Hero City levels |
| `assets/backgrounds/town.png` | Happy Piglet Town levels |
| `assets/backgrounds/street.png` | Safety Bureau levels |
| `assets/backgrounds/forest.png` | Animal Rescue Forest levels |

The four level backgrounds need one line each added to `data/levels.json`. Ask
and I will wire them.

**Keep the middle of the frame quiet.** Gameplay sits on top; a busy centre
makes the items hard to see. Detail belongs at the edges.

---

## 6. Audio — optional, high impact

`.ogg` or `.wav`. Every hook is already wired and silently does nothing while
the file is missing.

```
assets/audio/correct.ogg        assets/audio/try_again.ogg
assets/audio/star.ogg           assets/audio/coin.ogg
assets/audio/level_complete.ogg
assets/audio/voice/level/well_done.ogg
assets/audio/voice/level/wrong_light.ogg
assets/audio/voice/level/car_coming.ogg
assets/audio/voice/level/safety_traffic_01_intro.ogg
```

**Record the voice lines yourself.** He cannot read, so the voice *is* the
instruction — and a recording of you or him beats any stock clip. A phone
recording converted to `.ogg` is fine.

---

## 7. Light Energy Hero City — the hero-themed scenes

These three levels are the ones with the strongest character identity, so they
benefit most from real art. Everything below is currently drawn in code and
works; each file simply replaces a drawn version.

| What | Path | Size | Notes |
|---|---|---|---|
| City skyline | `assets/backgrounds/city.png` | 1920 × 1080 | Night city, lit windows. **Keep the upper two-thirds quiet** — orbs fall through it |
| Energy orb | `assets/icons/orb.png` | 128 × 128 | Neutral **white or pale**, tinted at runtime to 4 colours. A pre-coloured orb cannot be recoloured |
| Hazard rock | `assets/icons/rock.png` | 128 × 128 | Must differ from the orb in **shape as well as colour** — a colour-blind child has to tell them apart |
| Energy tower | `assets/backgrounds/tower.png` | 400 × 700 | Lamp area left blank; the game draws the coloured lamp on top |
| Hero, standing | `assets/characters/hero_idle.png` | 256 × 384 | Chest light **neutral white** |
| Hero, arms raised | `assets/characters/hero_cheer.png` | 256 × 384 | Optional; used on a correct collect |

### The two rules that will bite you if ignored

**Neutral, not coloured, for anything the game tints.** The hero's chest light,
the orbs, and the tower lamp are all recoloured at runtime — that recolouring
*is* the gameplay in Repair the Energy Tower. Paint them red and the level stops
working.

**Hazards differ by shape, not just colour.** Roughly 1 boy in 12 has some
red-green colour deficiency. The drawn version uses a dark square against a
glowing circle for exactly this reason.

### Audio for this world

```
assets/audio/orb_collect.ogg     bright chime, very short
assets/audio/power_up.ogg        rising tone, for the colour change
assets/audio/voice/level/hero_city_intro.ogg
```

The power-up sound is the one worth getting right: it fires when the tower
changes colour, which is the moment the child needs to look up.

---

## Summary

| Group | Files | Size | Priority |
|---|---|---|---|
| Hero | 1–2 | 256 × 384 | **Do this first** |
| Item icons | 22 | 128 × 128 | High — most visible |
| Bin icons | 2 | 128 × 128 | High |
| Navigation icons | 8 | 128 × 128 | Medium |
| Backgrounds | 6 | 1920 × 1080 | Medium |
| Audio | 9 | — | High for voice |

**38 images and 9 sounds for a complete art pass.** You do not need all of them
to start — the hero alone will change how the game feels more than the other 37
combined.

---

## Two things to avoid

**Do not put licensed art in a build you share.** Not with other parents, not on
itch.io, not in a group chat. Your own tablet is your own business; the moment it
leaves the house it is distribution.

**Do not mix art styles.** Eight beautiful icons and fourteen placeholders looks
worse than twenty-two consistent placeholders. Do a whole group at a time —
that is why the checklist is grouped this way.
