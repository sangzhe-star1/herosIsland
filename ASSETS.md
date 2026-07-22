# Art and font shopping list

> **Replacing the artwork?** See `ART_CHECKLIST.md` for the complete list of
> every image slot with exact filenames and pixel sizes. This file covers the
> free/CC0 route; that one covers supplying your own.

Everything here is free and licensed for commercial release. The game runs
without any of it — each file is picked up automatically once it exists at the
exact path given, with no code changes.

Do the fonts first. They are ten minutes of work and the single largest jump in
how finished the game looks.

---

## 1. Fonts (do these first)

| File | Where to get it | Path it must go to |
|---|---|---|
| Baloo 2 SemiBold | [Google Fonts](https://fonts.google.com/specimen/Baloo+2) | `assets/fonts/Baloo2-SemiBold.ttf` |
| Noto Sans SC Regular | [Google Fonts](https://fonts.google.com/noto/specimen/Noto+Sans+SC) | `assets/fonts/NotoSansSC-Regular.ttf` |

Both are SIL Open Font License — free to ship in a commercial game.

Download gives you a zip with many weights; you only need the two files above,
renamed exactly as shown. `UiKit.theme()` chains them, so Baloo 2 draws the
Latin text and Noto fills in every Chinese glyph automatically. Restart Godot
after adding them so the import runs.

**Why Baloo 2:** rounded terminals and heavy weight read as "toy" rather than
"document" at a glance. Fredoka or Nunito are equally good if you prefer them —
just keep the filename constant in `UiKit.FONT_DISPLAY` in step with whatever
you choose.

---

## 2. UI art

| Pack | License | Notes |
|---|---|---|
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | CC0 | Buttons, panels, sliders, checkboxes |
| [Kenney UI Pack RPG Expansion](https://kenney.nl/assets/ui-pack-rpg-expansion) | CC0 | Wooden/parchment panels, good for the map |
| [Kenney Game Icons](https://kenney.nl/assets/game-icons) | CC0 | Star, heart, gear, arrows |

Drop into `assets/ui/`. CC0 means no attribution required, though Kenney
appreciates a credit line.

---

## 3. Backgrounds

Save as PNG at 1280×720 or larger. These paths are already wired:

| Path | Used by |
|---|---|
| `assets/backgrounds/home.png` | Home screen |
| `assets/backgrounds/map.png` | Growth Island map |

Sources: [Kenney Background Elements](https://kenney.nl/assets/background-elements),
[OpenGameArt](https://opengameart.org/) filtered to **CC0**.

> Check the license filter on OpenGameArt every time. It mixes CC0, CC-BY and
> GPL assets on the same page, and CC-BY needs attribution while GPL would force
> you to license the whole game under GPL.

---

## 4. Item icons — already handled, but replaceable

This was the worst problem in the game: three sorting levels rendered their
items as **words**, so a child who cannot read could not play them.

**Fixed without art.** `scripts/ui/icon_library.gd` draws all 22 items — teddy,
knife, matches, socket, carrot, scarf and the rest — plus check and warning
marks for the safe/dangerous bins, all from primitives. Cards now show the
picture with the word beneath it, so the image carries the meaning and the word
is learned by association.

Replace them with real artwork whenever you like; the drawn icons are meant to
be outgrown, not kept. Add an `"icon"` field to the item in `data/levels.json`
pointing at a texture, and add a texture branch to `_render_label()` in
`item_sorting.gd` — a few lines. Ask and I'll wire it.

Good sources if you do: [Kenney Game Icons](https://kenney.nl/assets/game-icons)
(CC0), [game-icons.net](https://game-icons.net/) (CC-BY 3.0, needs a credit line).

---

## 5. Audio

All optional; every call silently no-ops when the file is missing.

```
assets/audio/correct.ogg          assets/audio/try_again.ogg
assets/audio/star.ogg             assets/audio/level_complete.ogg
assets/audio/coin.ogg
assets/audio/voice/level/well_done.ogg
assets/audio/voice/level/wrong_light.ogg
assets/audio/voice/level/car_coming.ogg
assets/audio/voice/level/safety_traffic_01_intro.ogg
```

Sources: [Kenney Audio](https://kenney.nl/assets?q=audio) (CC0),
[freesound.org](https://freesound.org/) (check each file's licence).

**Record the voice lines yourself.** Your voice, or your son's, will beat any
stock clip — and since he cannot read, the voice line *is* the instruction. A
phone recording converted to `.ogg` is fine.

---

## Licence summary

| Licence | Attribution? | Safe to ship? |
|---|---|---|
| CC0 | No | Yes |
| SIL OFL (fonts) | No | Yes |
| CC-BY | Yes, credit the author | Yes |
| CC-BY-SA | Yes, and share-alike | Avoid |
| GPL | Forces GPL on your game | Avoid |

Keep a `CREDITS.md` as you add CC-BY assets — reconstructing attributions later
is miserable.
