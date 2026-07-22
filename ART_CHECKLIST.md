# Complete art checklist

Every image slot in the game, with the exact filename and size to produce.

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
