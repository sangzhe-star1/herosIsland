# Character design — the hero

Second design pass, 25 July 2026. This is the character sheet: what the hero
is made of, how it moves, and where each motion fires. Change the figure in
`scripts/world/hero_art.gd`, the motion in `scripts/skin/skinned_character.gd`
and `scripts/ui/juice.gd`, then run `./tests/shots.sh` and the two previews at
the bottom of this page and *look*.

---

## 0. The companion

The puppy (or bee, or dragon) in the `pal` slot hangs off `SkinnedCharacter`,
not off the dressing-room stage — so every screen that puts a hero on it gets
the companion for free, and there is one place where "does he come along?" is
answered. He is scenery: no collision, no input, `z_index -1` so he never
covers what the child is trying to tap, and `show_pal = false` on the 100 px
card portraits and the row of faces, where a hero and a puppy in that space
shows neither.

He trails. The offset flips to whichever side the hero is *not* walking
towards and lerps across, which reads as following without a single line of
path-finding. The travel signal is `position.x` plus the mover's
`position.x` — deliberately NOT `global_position`, because the adventure
levels have no camera and scroll by sliding the whole world sideways, so a
companion reading global x thinks the hero is standing still. The minigames do
the opposite and move the figure itself. Adding the two covers both.

---

## 1. The figure

**Proportions: chibi, ~2.2 heads.** The second pass used heroic
four-and-a-half-head proportions and still read as an adult in armour. The
third pass follows the baby schema — the cross-culturally studied set of
features (large head, large LOW-SET eyes, round cheeks, small mouth, short
thick limbs) that reads as likeable to small children — and standard chibi
practice, which lands at two to three heads with half the figure being head.
Feet at y = 0, everything drawn upward, written at `build_width = 76`:

```
      crest             -252 … -300  (varies by crest_kind)
      helmet crown      -228
      head centre       -174     rx 50, ry 54 — nearly half the figure
      eye line          -166     BELOW the head midline; low-set is the lever
      chin              -118     overlaps the collar; a chibi has no neck
      shoulders         -108     arms attach at ±28
      chest core         -86     the tintable light; levels recolour it
      belt               -60 … -49
      hips               -46     legs attach at ±13
      boot top           -20
      sole                 0
```

One geometric consequence of the huge head: the head (±50) is wider than the
shoulders (±28), so raised arms must angle **up and out** or the fists land on
the face. CHEER and JUMP both do.

**The rules the drawing follows** (all learned by rendering it large and
looking, all violated by the first pass):

1. **No visible joints, no elbow detail.** Joint circles are suit-coloured
   and sit under overlapping segments; at chibi scale even a bend line is
   noise. Hands are mittens — the friendliest hand there is.
2. **One torso silhouette**, collar to crotch, with a real waist. Separate
   chest and hip boxes never stop showing their seam.
3. **Armour is worn, not stuck on.** The shoulder caps are domes drawn last,
   over the arm joints, so a raised arm slides out from under them. Sized to
   guard the shoulder — oversized caps crowd the chin and swallow the neck.
4. **Eyes are the identity.** Large tilted almonds (outer corners lifted),
   glowing, with a white catchlight — nearly half the face-width each.
   Trapezoid eyes read as tired; drooping corners read as sad.
5. **One accent idea per suit.** The chest carries a single pattern
   (`blade` | `chevron` | `bands`), the belt is one trim line, and that is
   all. Three overlapping accent shapes read as patches.
6. **Everything goes through `Shapes`** — same ink, same weight rule, same
   light direction as every tree, monster and icon in the game.

**What a skin controls** (`CharacterSkin`, one `.tres` per hero):

| Field | What it changes |
|---|---|
| `build_width` | the whole figure's bulk, one number |
| `crest_kind` | ten shapes — `fin` (dorsal blade) / `twin` (paired sweeps) / `horns` (broad side blades) / `tiara` (gold band, three points, a gem) / `ears` (cat ears, sat on the skull so a hat still fits) / `star_crest` (a star on a short stalk) / `antenna` (two lit beads, the only crest that uses `core_color`) / `ponytail` (fringe plus a tail beside the head) / `bun` (hair dome and a tie) / `unicorn` (one spiral horn, the tallest of the set) — the silhouette from across the room |
| `chest_pattern` | `blade` / `chevron` / `bands` / `star` / `heart` / `ring`. The last three are drawn AROUND the chest core rather than on the upper chest: the chin covers the torso above −108, the core plate and its halo own the middle, and the arms cover past x 20. Two earlier cuts of these three rendered invisible for exactly that reason. |
| `lashes` | three strokes off each eye's outer rim, warmer blush, rosier mouth — the feminine read at chibi scale; the eyes stay as big as everyone's |
| `body_color` | the suit |
| `accent_color` | sweeps, caps, gauntlets, boots, crest |
| `trim_color` | collar, belt, boot bands — the thin bright line the family shares |
| `eye_color` | the lamps |
| `core_color` | the chest light — gameplay recolours this |

Ships with fourteen faces. Five from the first pass: `light_hero`
(twin / bands / red-gold), `tiga`-like (fin / chevron / crimson-purple),
`zero`-like (horns / blade / blue-red), and two heroines added by request from
the playtester's father -- `grigio`-like (twin / chevron / rose-silver, lashes)
and `yullian`-like (tiara / bands / red-gold, lashes). `bluey` is drawn by the
puppy renderer instead and is never dressed.

Eight originals were added when the six new crests went in, each one a
different outline so a row of thumbnails has no two alike:

| id | 名字 | crest / pattern | build | reads as |
|---|---|---|---|---|
| `ember` | 小火苗 | star_crest / star | 74 | warm orange, the cheerful one |
| `tide` | 浪花 | fin / ring | 76 | deep blue, the calm one |
| `sprout` | 小芽 | ears / heart | 68 | green cat ears, the small one |
| `luna` | 月亮 | bun / ring | 68 | violet, lashes, the quiet one |
| `coco` | 可可 | ponytail / heart | 70 | brown hair, lashes, the friendly one |
| `bolt` | 闪电 | antenna / bands | 78 | yellow and navy, the fast one |
| `rainbow` | 小彩虹 | unicorn / star | 68 | pink, lashes, the tallest crest |
| `pebble` | 小石头 | horns / chevron | 86 | stone and ochre, the heavy one |

Four of the eight -- `tide` (60), `luna` (70), `rainbow` (80), `pebble` (60) --
are bought with 星星币 through the ordinary try-on-then-decide flow. The rest
are free from the first minute. A fifteenth hero is a new `.tres`, a line in
`characters.json`, a `who_` row in `shop_items.json` and two names in
`strings.json` -- and `tools_check.py` rule 5n fails until all four exist.

---

## 2. The rig

```
HeroArt (feet at origin)
└─ _spin        origin at body centre (y −96) — rolls rotate this
   └─ _root     origin back at the feet — poses, breathing, walk bob
      ├─ back leg / back arm     (suit darkened 0.16 — turned from the light)
      ├─ torso (core, belt, patterns)
      ├─ front leg
      ├─ head (mask, eyes, crest)
      ├─ front arm
      └─ shoulder caps
```

Each limb is two segments (`Fore` / `Shin`) hung off a root; a **pose is a
dictionary of joint angles** and switching poses is a 0.22 s `TRANS_BACK`
tween, so the hero *moves* between stances instead of cutting:

| Pose | Reads as | Used by |
|---|---|---|
| `IDLE` | at ease — arms slightly out, soft elbows, one foot forward | everywhere |
| `WALK` | legs and arms swing per-frame | traffic crossing |
| `CHEER` | both arms up | wins, taps |
| `BEAM` | crossed-forearm brace, hands at the core | beam levels, duels |
| `HURT` | a stumble, never a collapse | unblocked hits |
| `JUMP` | arms flung up-back, legs bent *unevenly* — the asymmetry is what makes it a leap and not a levitation | jump / entrance |
| `TUCK` | knees to chest, chin down | rolls |
| `crouch()` | the loaded spring | the beat before every jump |

---

## 3. The motion verbs (`SkinnedCharacter`)

Levels never animate joints. They call verbs, so every screen gets the same
physics — the same anticipation beat, the same landing weight — and all of it
degrades to stillness under Parent Center's reduce-motion switch.

| Verb | What happens | Where it fires |
|---|---|---|
| `jump(height, dur)` | crouch 0.09 s → stretch + launch (`QUAD` out) → `JUMP` pose in the air → fall (`QUAD` in) → land: dust, squash 0.88, settle bounce | result screen, home taps, duel ult wind-up |
| `hop()` | `jump(42, 0.42)` | the safe kerb in traffic crossing |
| `roll(distance, dur)` | `TUCK`, one full spin around the body centre, a shallow arc, speed lines trailing, dust on exit | home taps (the third trick) |
| `entrance(from_h)` | drops from the sky in `JUMP` pose, lands with dust + **shockwave ring** + squash, chest light flares | boot screen, both arena templates |
| `victory()` | `jump(72)` then `CHEER` at the top of the bounce-back | result screen |

Squash-and-stretch scales the *node*, whose origin is at the feet — so the
figure compresses into the ground, not around its own middle. The crouch
before the leap is not decoration: **a jump with no anticipation reads as
levitation.** The `_moving` flag keeps verbs from stacking.

## 4. The effects (`Juice`)

Three new primitives, drawn through `Shapes` like everything else:

- `dust(parent, at, amount)` — soft warm-grey puffs that drift out and fade,
  ~0.5 s. The cheapest possible "that landing had weight".
- `shockwave(parent, at, radius, color)` — one expanding, fading ground-plane
  ellipse. Reserved for arrivals and big landings (≥130 px) so it stays
  special.
- `speed_lines(parent, at, direction, color)` — three tapered streaks
  trailing a fast mover; the drawn version of motion blur.

All three no-op under reduce-motion, and none of them flashes — the rules
from the rest of the game apply to the new toys too.

---

## 5. Verifying a change

```bash
SHOT_BIG=1 SHOT_SKIN=tiga SHOT_PATH=/tmp/hero.png \
  xvfb-run -a godot --path . res://tests/HeroPreview.tscn   # 6 poses, large
SHOT_DIR=/tmp/motion \
  xvfb-run -a godot --path . res://tests/MotionPreview.tscn # 5-frame filmstrip
./tests/shots.sh                                            # every screen
```

The filmstrip exists because motion cannot be judged from one still: it
captures mid-fall, the landing dust, mid-roll, mid-leap, and the settle.
