# Little Heroes Growth Island — development plan

Written 22 July 2026. Living document; revise as reality intervenes.

---

## The constraint that shapes this plan

**No one has run this game since the icon and juice work landed.** I build it
without an engine — I can read code and check it statically, but I cannot see a
button overlap its label or a particle system fail to fire.

That has already cost one debug cycle: a parser error in a file the boot screen
never touches blanked the entire game, and every static check I had at the time
passed. The checker is much stronger now, but the lesson stands.

So this plan is ordered by **risk reduction first, features second**. The
fastest route to a game you can put in front of your son is not more levels —
it is making the ~3,500 lines that already exist provably work.

---

## Phase 0 — Prove what exists (you, 6 minutes)

**Status: blocked on you.**

Press F5 and walk README §14's test order. Nothing below matters until this
happens; every feature added on top of an unverified base multiplies the
debugging if something foundational is wrong.

Highest-suspicion item: `UiKit.icon_button()` positions its icon by fraction of
button size and pushes the label down with a content margin. If that maths is
off, **every button on Home and the map is wrong at once**, because they all
share that one function. One screenshot settles it.

---

## Phase 1 — Make verification cheap (done this session)

A smoke test that boots every scene and every level headlessly and reports
errors, run with one command in about thirty seconds:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/smoke_test.gd
```

This catches parser errors, missing methods, null crashes on scene entry, and
controls that overflow the 1280×720 viewport. It does not catch "this looks
ugly" or "this is confusing to a child" — those need your eyes and his hands.

**Why this is Phase 1 and not Phase 5:** it converts every future change from
"hope it works" to "checked in thirty seconds", which compounds across
everything after it.

---

## Phase 2 — Complete the level set (done this session)

`animal_rescue` was the last unbuilt template. With it: **14 of 14 levels
playable**, four templates, four worlds.

| Template | Levels | Skill |
|---|---|---|
| `traffic_crossing` | 3 | impulse control, road safety |
| `item_sorting` | 5 | classification, counting, danger recognition |
| `collect_energy` | 3 | attention, colour matching |
| `animal_rescue` | 3 | sequencing, planning |

---

## Phase 3 — The real content pass (needs you)

Code cannot do these. In order of impact on whether your son plays twice:

1. **Fonts** — 10 minutes, largest single visual jump. See `ASSETS.md` §1.
2. **Voice lines** — he cannot read; the voice *is* the instruction. Your voice
   beats any stock clip, and recording them with him is a better evening than
   anything in this file.
3. **His drawings as the hero** — the `CharacterSkin` seam exists precisely for
   this. Scan at ~128×192 transparent PNG.
4. **Sound effects** — Kenney's CC0 packs; every hook is already wired.

---

## Phase 4 — Playtest and cut (needs him)

Put it in front of him and watch without helping. Record only:

- which level he asks to replay
- where he goes quiet or looks at you for help
- what he tries that the game does not support

Then **delete or rework whatever he does not return to.** Fourteen levels is
already more than a spare-time project can polish well; expect to keep eight.

The one metric that matters: *does he ask to play it again tomorrow?*

---

## Phase 5 — Depth, only after Phase 4

Do not start these before the playtest tells you which direction is worth it.

- **Hero House** — spend coins on furniture. Currently a disabled button, which
  is honest. This is the strongest candidate for "reason to come back".
- **Child profiles** — only if a sibling starts playing.
- **More levels per template** — pure JSON, cheap, but only for templates he
  actually likes.
- **Story cutscenes between worlds** — expensive; skip unless he asks.

---

## Phase 6 — Release

1. macOS/Windows build for family
2. Android APK for the tablet (project is already landscape, touch, GL
   Compatibility)
3. Web build only if you want to share a link; Godot's web export is the
   fiddliest target and there is no audience for it yet
4. iOS last, needs a paid Apple account

**Before any build leaves the house:** replace any licensed character likeness
with the original light hero. The skin system makes this a one-file change —
that is why it was built that way from the first commit.

---

## Standing principles

Encoded in code, not just written here:

- Finishing always earns at least one star; mistakes take 3 → 2 → 1, never 0
- Stars never decrease on a worse replay
- No fail state — a wrong tap is a calm voice and a retry
- Nothing important is conveyed by words alone; every meaning has a picture
- Reward motion is generous, correction motion is minimal
- All motion can be switched off (Parent Center → Reduce motion)
- Touch targets ≥ 220×120
- No ads, no payments, no loot boxes, no network, no strangers
- Daily limit is advisory and never locks a child out mid-level

---

## What I will not do without asking

- Add a fifth minigame template before the first four are verified
- Replace the drawn icons with downloaded art (your call on licences)
- Add any network, account, or analytics feature — the local-only promise is
  the most valuable property this project has
