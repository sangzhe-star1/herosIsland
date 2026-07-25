# Changelog

## Audited against the spec, and four things it was missing — 25 July 2026

Checked the rebuilt island against the ten-point brief rather than against
memory. Six of the ten were already right; four were not, and three of those
are now fixed.

**The boss slammed without saying where.** Phase one raised its arms and
flashed, then picked its landing spot at the moment of impact. The child saw
that something was coming but not where, so dodging was guessing -- and a
guess you lose a heart for is indistinguishable from unfairness. It now marks
the ground for the whole wind-up with the same growing shadow the falling
rocks use, so a child who learned level two already knows to step off it. The
mark is chosen when the wind-up starts and never re-aimed, because a warning
that moves is worse than none. Measured: 1.77 s of warning.

**The double jump existed and nothing granted it.** `double_jump_unlocked`
had been sitting in the hero controller since Phase A, read once, never set.
The chest at the end of 岩石怪的挑战 now gives it, `SaveManager` keeps it in a
new `skills` list, and the hero reads it back on every level. Unlocking is
idempotent, so replaying for a third star gets the treasure and not the
lecture. A skill that has to be re-earned every time the tablet sleeps is a
tease, not a reward.

**Two falls got help, but not the kind the spec asked for.** The island
already slowed down and pointed at the gate. It now also loops a translucent
finger on the actual BUTTON -- attack, shield, lightning or jump, whichever
is the answer to where the child is stuck. Pointing at the thing in the world
is half an answer: "get past that gate" is no use to someone who has not yet
worked out that the round yellow circle is how you jump.

**Still outstanding:** Windows and Web export presets (the file can only be
edited with Godot closed, and it is open), and voice-over on the new levels,
which needs recordings.

## The bug that made every level error — 25 July 2026

The father picked a level in 怪兽擂台 and got an error. So did every other
level, on his machine, and none of them on mine.

**Cause.** `adventure.gd` referred to its five new classes -- `HeroController`,
`SkillBar`, `AdventureProps`, `AdventureEnemies`, `PuzzleCard` -- by class
name. Godot keeps global class names in `.godot/global_script_class_cache.cfg`
and only rebuilds it when the EDITOR rescans. On a machine whose editor had
not been reopened since those classes were written, all five were unknown, and
an unknown identifier is not a runtime problem in GDScript -- it is a PARSE
error. The whole template failed to compile, so *every* level errored the
instant it was picked. Nothing in the game pointed at the cache file.

**Fix.** The template now loads all five by path:
`const HeroCtl := preload("res://scripts/adventure/hero_controller.gd")`.
`preload` resolves at compile time and never consults the cache. Reproduced
by rebuilding a cache with exactly those five entries removed -- five parse
errors before, a clean 怪兽擂台 after.

**So it cannot happen again.** `tools_check.py` used to WARN that the cache
was stale. It now ERRORS, naming the file, the class and the fix, whenever a
shipping script refers by name to a class the cache does not have. A warning
was the wrong volume for a condition that breaks every screen in the game.

**And so the door gets opened.** New `MapProbe` walks in the way a child does:
build the map, check every world's first level is unlocked, and enter it
through the same calls the marker makes. Every previous test reached levels the
way a programmer does, with the id already set -- the map was the one path
nobody walked. It also plays a save from before the rebuild, full of level ids
that no longer exist, which is the state every existing player is in.

## Phase D: the whole island rebuilt — 25 July 2026

The 54 old levels are gone. In their place, **thirty adventure levels across
five worlds**, all one template, every one of them a side-scrolling run made
of beats.

- 阳光公园 · 快乐小猪镇 · 安全局 · 动物救援森林 · 怪兽擂台, six levels each.
- A level's whole definition is now an ORDER OF BEATS. No x positions, no
  lengths: the template plans the beats, grows ground to fit them, and derives
  the level's length from what they need. Adding a level is nine lines of JSON.
- **Every level has at least three different kinds of thing to do**, which is
  the rule the old island broke worst: adventure_valley was five platformers
  in a row and hero_city was six collect levels out of eight.
- **The old teaching survives as cards.** `count` is Piglet Town's counting
  (asked in dots, never digits); `sort_safe` is the Safety Bureau's spot-the-
  danger; `same_as` is Memory Match without the memory; `color_match` is the
  energy-tower colour levels. They pop up mid-level and hand the child back to
  the path fifteen seconds later.
- **Every badge the island ever had is earnable again** -- one per level,
  matched to what the level is about.

Testing changed shape to match. `AdventureProbe` now checks the LAWS of all
thirty levels -- buildable, everything inside the real jump arc, plates far
enough apart, gates that hold -- and walks three of them end to end, chosen to
cover a gentle level, a hazard level and a fighting level.

Two things caught by looking at it:
- The map's second row of levels hung its names and stars off the bottom of a
  720 px screen. Rows now sit where a marker column actually fits.
- The page dots were drawn under the island's clouds, so with five worlds the
  map looked like it had three.

**The twelve old templates are still on disk and still work** -- nothing points
a level at them any more. Light Defense, Keepy Uppy, Monster Duel, Dance Mode
and the rest are one `"game_type"` line in levels.json away from coming back as
bonus levels. Their two probes (battle, duel) are parked in the same spirit.

## Phase C: monsters that telegraph, and a giant to beat — 25 July 2026

Third stage of the rebuild. Level 3, 岩石怪的挑战, and everything that fights.

- **Monsters that wind up first, always.** A ring closes in on the monster for
  the whole telegraph before it lunges or spits; nothing it does during the
  wind-up can touch you. Three kinds, each teaching one idea: the walker
  teaches the attack button, the spitter teaches the shield, the armoured one
  teaches that hitting harder is sometimes the wrong idea (its glowing spot is
  only open from above).
- **The shield is real now.** It was a light show; it is a 2.2-second window
  that eats hits, follows the hero, and expires. The lightning skill became a
  real beam that reaches across the screen -- and it is the only thing that
  breaks the giant's shell.
- **The rock giant**: three phases, three hits each, nine countable pips on
  its bar. Phase one slams the ground behind a shadow; phase two throws three
  announced stones; phase three shells itself and must be opened with the
  beam. Beaten, it sits down and waves -- nothing on this island dies.
  Walking past it is impossible, so the fight is the door.
- **Rescue**: a caged friend freed with the interact key, who then trots along
  behind you forever. Nothing to protect, nothing to lose. The reward for
  being kind is company.
- **Two falls and the island leans in** (spec §5): longer warnings, slower
  monsters, a shorter boss fight, and a hand pointing at whatever is in the
  way. No menu, no question -- a child who has just lost twice should not be
  ASKED whether they would like it easier.
- **The result screen shows the three doors**: finished / found the secret /
  kept your hearts, as pictures. Undone ones are dim, never crossed out.
  "Two stars" is a grade; a dim gem beside a bright chest is an invitation.

Bugs the probe caught before any child could:
- The armoured monster was literally unhittable. The swing lands 80 px above
  the hero's feet and a monster's origin is at its own feet, so a hit from
  above measured 217 px away from a 176 px circle. Swings now use a forgiving
  capsule around the monster's middle.
- A beaten monster's node is freed by its own farewell tween, and the loop
  assigned it to a typed variable before checking validity -- which is an
  error in itself, so the guard never ran.
- The cage's interact key floated exactly where the hero's face was.

## Phase B: things that warn, and questions asked in place — 25 July 2026

Second stage of the 54-level rebuild. Level 2, 落石小径 (Rockfall Path), and
the five beat kinds it needed.

- **Hazards that warn first, always.** A falling rock grows a shadow on the
  ground where it will land, and the SIZE of the shadow is the countdown; a
  fire vent blushes red before the column comes up. Difficulty may shorten
  the fuse and may never remove it -- the probe measures a real rockfall with
  a stopwatch (1.72 s from shadow to impact) rather than trusting the config.
- **A crate you push with your body**, not with a button, solid from the side
  and ridable from on top. It exists to reach a shelf exactly one jump above
  its own roof, with the hidden gem on it -- both numbers derived from the
  jump arc rather than chosen.
- **Step-in-order plates**, wearing one, two, three DOTS (never digits).
  Wrong order relights the row and costs nothing: not a heart, not an orb,
  not the gate.
- **PuzzleCard**: a picture-question asked without leaving the level. The
  world dims, the card flips up, fifteen seconds later the child is back on
  the path. This is how the twelve old minigames come back -- Phase B ships
  the colour-match card from the old collect_energy levels.
- **A hand that points.** Push at a shut gate for two seconds and the game
  points at whatever opens it -- plate, next dot-plate, or question post.

Bugs the probe caught before any child could:
- Sequence plates could be built 50 px apart, closer than the hero is wide,
  so one step hit all three and the "sequence" solved itself. Plates now sit
  at a fixed 200 px and the count shrinks rather than the spacing.
- Zone beats were placed by hunting for a wide enough ground segment, and the
  only one long enough was the opening meadow -- so the crate, the plates and
  their gates all slid back to the first screen and two thirds of the level
  was an empty walk. Terrain is now GROWN around beats planned in advance,
  and the level's length is derived from what its beats need.
- The crate never moved: contact zeroes the hero's velocity, and the push
  read velocity. It now reads the buttons (`HeroController.wish_dir()`).
- SceneTreeTimers outliving the nodes they were meant to tidy, in six places
  including every particle puff and every stumble. All now tweens owned by
  the node, so leaving a level takes its countdowns with it.
- The card's dimmer was invisible: `set_anchors_preset` keeps the current
  rect, so a Control born at zero size stays there.

## The adventure template -- Phase A of the big rebuild — 25 July 2026

The first stage of rebuilding all 54 levels into one side-scrolling adventure
("儿童版冒险岛"), as planned in `docs/ADVENTURE_PLAN.md`.

- **`platform_adventure`**, a new level template: one long strip of seeded
  terrain with the level's beats laid along it from JSON -- collect, spring,
  hidden gem, checkpoint, floor plate + gate, treasure chest. At least three
  kinds per level, enforced.
- **`HeroController`**: walking, jumping, climbing, attacking, being hurt,
  with every forgiveness a six-year-old needs baked in -- coyote time, jump
  buffer, ledge magnet, auto-aim, a mercy flicker after every hit.
- **`SkillBar`**: the fixed hands of the genre. Move pad bottom-left; jump,
  attack and two cooldown-ring skills bottom-right; a contextual interact key
  that exists only when something is in reach.
- **Three independent stars** (`LevelResult.objective_scoring`): reached the
  chest / found the gem / kept your hearts. Undone tiles on the task strip
  are dim, not crossed out -- "still out there", never "you failed".
- **World 1: 阳光公园 (Sunny Park)** and its first level, 公园散步.
- **AdventureProbe**, in the smoke suite: walks the whole level with the two
  buttons a child has, measures every gap against the real jump arc, proves a
  shut gate is a wall and that the plate is what opens it.

Bugs the probe and the beat camera caught before any child could:
- Pickups compared world coordinates with global ones, so collection drifted
  by exactly the camera scroll -- nothing past the first screen could ever be
  picked up.
- `Juice.idle_bob` on a prop root tweened every orb back to world origin;
  props now bob an inner node (`AdventureProps._bobber`).
- The chest stood under the jump button on the final screen; it now stands at
  dead centre of the fully-scrolled camera, and the level ends with plain
  walking toward it.
- Hand-written beat x-positions drifted with terrain overshoot and piled
  three beats into one 190 px stretch; beats are now an ORDER, spread evenly
  over whatever ground the seed produced.
- Orbs hung above the real jump arc; heights now derive from jump physics.

## Mac packaging — 25 July 2026

`tools/build_mac.command`: double-click to export, unzip, de-quarantine and
reveal `Little Heroes Growth Island.app` (universal, ad-hoc signed, family
build). Ships with a pre-configured macOS export preset and a proper app
icon — the chibi hero on the island's morning sky, rendered by
`tests/IconShot.tscn` into a full .icns. DEPLOYMENT.md gained the macOS
section.


## Trail beauty pass, and switchable maps — 25 July 2026

- **Set dressing along every trail**, coloured from the world's own palette:
  flowers, bushes and pines in the green worlds; in the city the slabs ARE
  rooftops now — window grids on their faces, lamps and roof vents on top.
  Floating ledges grow hanging roots. All of it small, sparse, and behind
  the action.
- **The finish line is a landmark**: a tall pole with a waving star pennant,
  a gold cap, stones at its foot, and a glow visible from half a screen away.
- **Switchable maps via one config knob**: `"weather"` in any level's config
  re-lights the whole world with no art — and `snow` now whitens the ground
  and the distant ranges, so a snowy level is a different PLACE, not just
  falling flakes. New level: Snowy Trail (雪山小道), Adventure Valley's
  fourth stage.
- Smoke test: 43 levels, 397 checks.


## The trails spread across the island — 25 July 2026

- **Bounce mushrooms**: land on the cap and launch twice a jump's height,
  with a cap-squash and sparks. No danger — they are the way up to the
  highest coins, a discovery rather than a decoration. (`"springs": n` in a
  level's config; challenges grow one per two ranks.)
- **Two new adventure stages in the old worlds**: Rooftop Run (Hero City at
  dusk, stone slabs, lit windows sliding past) and Forest Dash (golden
  afternoon). The platform slabs now take their colours from the world, so
  one template serves a green valley, a night rooftop and an autumn forest
  with zero per-level art.
- **Trail coins are kept coins**: everything collected on a run goes into
  the pouch on top of the level reward.
- Pad buttons made near-opaque — translucent rounded styleboxes show their
  corner seams as diagonal lines.
- Smoke test now covers 42 levels (391 checks).


## Adventure Valley: the platform trails — 25 July 2026

A sixth world and a seventh template: **`platformer`**, the side-scrolling
adventure run — run, jump, collect the coins, reach the flag, with the camera
following the hero and the alpine horizon parallaxing behind (new
`Stage.parallax()`). Four levels in **Adventure Valley** (crisp alpine
morning, tall pale crags), including a Challenge that grows a longer trail
each time it is beaten. Terrain is generated from the level's seed — replays
return to the same valley — and each level is a handful of JSON knobs
(`length`, `gap_max`, `coins`, `moving`).

The house rules bind the genre, not the other way round: falling into a gap
floats the hero back to the last safe ledge — one mistake, no lives, no lost
coins, no fail state. Nothing is an enemy; the hazards are geometry. A ledge
always floats over any gap too wide to walk. Controls are three chunky pad
buttons in the thumb corners (left/right and jump, with coyote time and a
jump buffer sized for small hands) plus arrow keys/space on desktop.

Three new badges (Valley Explorer, Cloud Jumper, Mountain Hero), the island
grew a sixth region with a snow-capped peak, and the smoke test now covers
40 levels.

**Drop-in characters.** `GameData` now registers a playable character from
nothing but two PNGs: put `hero_idle.png` (transparent, ~256×384, feet at the
bottom edge) and optionally `hero_cheer.png` into
`assets/characters/bluey/`, restart, and Bluey appears in the Hero House.
No .tres, no JSON edit. Licensed characters stay in this house, same rule as
the photo skins — see README §13.


## The tap-ratchet bug, and the chibi hero — 25 July 2026

**The bug.** `Juice.pop` read a node's *current* scale as its base, so a tap
landing while the previous pop was still in flight adopted the inflated size
as the new normal. Ten fast taps grew the Tap-to-Cross button without limit,
until it had swallowed a quarter of the screen and the hero behind it. Fixed
at the root: the base scale is remembered once in metadata, every pop returns
to it, and a new pop kills the one in flight — which fixes every button in the
game at once. The same disease existed in `Juice.nudge` (rapid wrong-answers
walked a node sideways) and in the hero's own jump (each landing "returned" to
the stretched launch scale, growing him five percent per hop): both now return
to a remembered rest state. `celebrate()` refuses to run mid-jump, and the
crossing ignores taps until the landing hop finishes.

**The hero, third pass: chibi.** The second pass fixed the marionette
problems but kept heroic 4.5-head proportions — still an adult in armour. The
research on what small children actually find likeable is unambiguous: the
baby schema. The figure is now ~2.2 heads tall — the head is nearly half of
it — with enormous LOW-SET eyes (below the head's midline; this is the
single biggest lever), blush cheeks, a tiny mouth, stub limbs with mitten
hands, and boots nearly as big as the legs. The hero identity survives in the
crest, the chest core, the colours and the poses. Raised-arm poses (CHEER,
JUMP) now angle up-and-out, because the head is wider than the shoulders.
The hero and the monsters finally look like they come from the same game.


## The hero learns to move — 25 July 2026

Second pass on the character: redesigned figure, and a real motion vocabulary.
Full character sheet: `docs/CHARACTER_DESIGN.md`.

**The figure.** Joints now hide under overlapping segments instead of sitting
between them as rivets; the torso is one silhouette with a waist instead of
stacked boxes; the shoulder caps are domes the arm slides out from under; the
eyes are large tilted glowing almonds with catchlights; boots and gauntlets
have real shapes (shaft, trim band, sole); each suit carries exactly one chest
pattern. The marionette look is gone.

**The motion.** Poses added: JUMP (asymmetric, mid-leap) and TUCK (rolled into
a ball), plus a crouch. New verbs on SkinnedCharacter, used by every screen so
the physics is shared: `jump()` (crouch → spring → hang → land with dust and a
settle bounce), `hop()`, `roll()` (one full tumble around the body's centre,
speed lines trailing), `entrance()` (drops from the sky, lands with a
shockwave), `victory()` (leap, then cheer at the top of the bounce). New Juice
primitives: `dust`, `shockwave`, `speed_lines` — all drawn, all silent under
reduce-motion.

**Where it fires.** The boot screen's hero now ARRIVES — drops out of the sky
and lands in front of the title. Wins on the result screen are a leap.
Tapping the home-screen hero cycles three tricks (hop, cheer, tumble). The
traffic-crossing hero finally *walks* the crossing (the rig had a walk cycle;
the hero glided) and hops on the safe kerb. Both arena templates open with the
entrance, and the duel's special move starts with a leap into the brace.
`Juice.idle_bob` no longer runs on drawn heroes — it fought the rig's own
breathing and the new position tweens.

**New harness:** `tests/MotionPreview.tscn` captures a five-frame filmstrip
(mid-fall, landing dust, mid-roll, mid-leap, settled), because motion cannot
be judged from a single still.


## The reward wall becomes readable — 25 July 2026

The badge shelf was a grid of grey slabs reading "?" until earned and a line of
Chinese afterwards. A child who cannot read learned nothing from either state:
not what they had won, and not what was left to win. That breaks the rule the
whole game is built on -- *nothing important is carried by words alone* -- and
it was breaking it on the one screen whose entire job is to make a child feel
they have collected something.

- **Every badge is a medal now**: ribbon, scalloped rim, and its own picture in
  the middle. Twenty-two badges, twenty-two pictures, assigned in
  `data/rewards.json` rather than in code.
- **A locked badge shows its own picture in silhouette behind a padlock**, so
  the wall reads as a display of things to go and get instead of a row of
  question marks. Same reasoning as drawing the empty stars: seeing what is
  still out there is the point of showing it at all.
- **The heading counts**: "7 / 22". A six-year-old cannot read "Badges" but can
  absolutely read the gap between two numbers, and that gap is the reason to
  come back.
- **An earned badge is worth touching** -- it pops, sparkles and chimes.
- **The growth bars grew pictures too**: courage, wisdom, kindness, focus and
  safety were five unreadable words next to five identical bars.
- Eight new drawn icons: eye, umbrella, magnifier, compass, leaf, music, medal,
  traffic light. Safety uses the traffic light because the bare tick is drawn
  near-white and vanished against a cream card -- found by looking at the
  render, which is the whole argument for `tests/shots.sh`.
- `tests/rewards_preview.gd` renders the page with progress already made,
  because on a fresh save every badge is locked and the earned state is never
  seen.


## First-play fixes — 25 July 2026

Four things found by actually playing it.

- **The daily-limit message was an engine dialog.** Godot's `AcceptDialog` is
  an OS window with the default grey theme, so the one moment the game asks a
  six-year-old to stop playing was also the one moment it looked like a system
  error. It is now a card built from the game's own parts, with a drawn moon.
- **There was no way to reach the next level.** The result screen offered
  "Play Again" and "Back to Map" and nothing else, so continuing meant going
  back to the map and finding the next one. `GameManager.next_level_id()` now
  walks the level list — same world first, then onward — and the result screen
  leads with a breathing **Next Level** button. Verified across all 36 levels
  by `tests/next_probe.gd`.
- **The duel's skill buttons did not answer a tap.** A press that fired
  produced almost nothing visible; a press refused because the skill was
  cooling produced *nothing at all*, which is indistinguishable from a broken
  game. Now: every tap answers. A firing skill flashes an expanding ring, pops,
  braces the hero and flares the chest light; a refused one rocks the button
  and clicks. Cooldown is a drawn wedge that sweeps away, and a skill coming
  back online pops and flashes. The three buttons moved onto a control pad in
  the corner, clear of the monster.
- **The duel had no stakes.** The monster's attacks did nothing at all if they
  landed. The hero now has a three-pip **light bar**: an unblocked hit costs a
  pip and counts as a mistake, which is what makes the shield worth pressing.
  It cannot end the level — emptying it makes the hero stumble and the light
  returns on its own. The cost of being hit is stars, and stars never go below
  one.
- **The monsters were not appealing.** A purple ball with triangle spikes and
  two white discs is a monster shape without being a character. Rebuilt on
  `Shapes` with the things that actually make a creature likeable: eyelids that
  blink and carry mood, eyebrows, cheeks, a belly, rounded paws with claws,
  ears that wiggle, a visible tail, curved horns instead of triangles, and
  highlights in the eyes.
- Hero and monster are now sized against each other (`set_height`), so a duel
  looks like two giants rather than a child facing a kaiju.


## The rendering architecture pass — 25 July 2026

**The game draws its own world now. No background images, no imported UI art,
no character photographs.**

The full reasoning is in `docs/ARCHITECTURE_REVIEW.md`. In short: the project
had a good logic architecture and no rendering architecture. Each screen chose
its own scenery, mostly by naming a PNG, and the PNG always won — so the game
showed a photographic night skyline, a flat pastel village, a cartoon owl, a
set of imported navy badge discs, two licensed render cut-outs and a screen of
bare grey rectangles, all at the same time.

### New — `scripts/world/`

- **`shapes.gd`** — the drawing language. One outline colour, one weight rule,
  one light direction, one rounding convention, one contact shadow, one glow,
  one star. Everything drawn in the game goes through it, which is what makes
  a 24px berry and a 400px building look like the same hand drew them.
- **`world_style.gd`** — the five worlds as five hours of one day: Piglet Town
  late morning, Safety Bureau noon, Rescue Forest golden afternoon, Hero City
  dusk, Monster Arena night. Same shapes, only the light changes.
- **`stage.gd`** — the layered parallax renderer: sky, sun or moon, stars,
  cloud, three horizon bands, haze, ground, props, motes, weather, fringe.
  All polygons, seeded per level so a replay returns to the same place.
  Publishes `ground_y()`, so every actor in the game stands on one floor.
- **`hero_art.gd`** — jointed heroes with five poses and real transitions. A
  skin is now a design (proportions, crest, chest pattern, four colours), not
  a pair of pictures.
- **`island_map.gd`** — Growth Island as one island, generated from the level
  data, with a path that runs through the actual markers.
- **`energy_tower.gd`** — the Hero City landmark, as an object that can be
  broken, recoloured and repaired.

### Changed

- Every screen and every level template now gets its scenery from
  `build_world()` or `UiKit.world_background()`. There is no third path.
- **The world map is a map.** It was a scrolling list of navy cards over a
  photograph, with a dot-to-dot line baked into the image that had nothing to
  do with any level. It is now one island with the levels standing on it, and
  it opens scrolled to whichever level is next.
- **The heroes are drawn.** `tiga` and `zero` are original designs in the
  game's own style; the licensed render cut-outs moved to
  `resources/skins/photo/`, unreferenced and opt-in.
- **Hero House** presents all three heroes the same way — the live drawn
  figure, breathing — instead of two photographic spotlight cards and one
  drawn placeholder.
- **Icons are drawn by default.** A bare name always draws; artwork has to be
  asked for by path. The previous rule was the reverse, so the imported navy
  badge discs silently replaced the whole `IconLibrary`. Thirteen icons added
  (lock, coin, heart, shield, lightning, orb, rock, sound on/off, retry,
  pause, chest, star_empty) and the set now goes through `Shapes`.
- **Parent Center is styled.** It was the one screen still on engine defaults.
- **The energy tower repairs itself** instead of swapping between two PNGs,
  and its lamp is a real light the level recolours.
- **Traffic Crossing has a world.** It was grey and green rectangles; it now
  has a town on the far kerb, a horizon raised to match the camera, and a
  drawn crossing.
- **Text over the world is outlined** through `UiKit.on_art()`.
- Characters are sized with `set_height(pixels)` rather than a scale factor.
- `background_art` removed from 26 levels and from `UiKit`. Art direction is
  no longer a per-level data field.

### New — `tests/shots.sh`

Renders all seventeen screens to PNG in about twenty seconds, headless, on a
machine with no GPU. `PLAN.md` opens by naming "I cannot see the output" as
the project's most expensive constraint; this removes it. During this pass it
caught scenery drawing on top of buttons, a splash screen coming out solid
navy, signposts 720 pixels tall, heroes at the wrong size, and buildings
standing on the sea — every one of which passed `tools_check.py` and the smoke
test.

### Verified

```
python3 tools_check.py   ->  0 errors, 0 warnings
./tests/run_smoke.sh     ->  355 checks, 0 failures (all 36 levels boot)
./tests/shots.sh         ->  17 screens rendered and reviewed
```

No gameplay rule was changed.


## 2026-07-24 (arena upgrade) — Real 1v1 duels with a skill wheel

- **Template #8, `monster_duel`** — the Honor-of-Kings loop, filed smooth
  for six: a skill wheel in the thumb corner with BEAM (basic attack, short
  cooldown sweep), SHIELD (a light bubble; attacks that hit it bounce back
  and COUNT), and a chargeable ULT picked before battle when the level
  offers a choice — Meteor Barrage (six raking beams) or Light Burst (a
  gold ring that clears every threat and stuns). The ult charges from
  landed hits and never from its own.
- **The monster finally fights back**: goo lobs and, in later duels,
  roaring rings that cross the arena. Blocked = bounced back for a hit;
  unblocked = a wobble and a briefly resting beam button. No hero health,
  nothing ever lost, no mistake recorded — and every duel still ends with
  the monster waving goodbye.
- **A duel ladder across four environments**: Rocky on the city rooftop,
  Blobbi in town, Spikelor in the forest, and the Champion Duel in the
  burning city (36 levels total; Arena Champion badge). Challenge scaling
  hooks are in (busier opponent, higher goal, never a faster hand).
- **Fourth probe in the suite**: drives the skill wheel like thumbs —
  cooldown gates, ult economy (including the it-must-not-self-charge rule
  the probe caught being broken), shield reflection, harmless unshielded
  hits, and a clean 3-star finish.
- Suite: 355 checks + battle, progression and duel probes, all green;
  arena and ult picker verified by rendered screenshot.


## 2026-07-24 (later still) — The Light Song, tap sparkles, and a sticker wall

- **New template #7, `light_echo` — the Light Song**: big candy-coloured
  pads sing a short pentatonic melody (the island theme's own notes, five
  freshly synthesized plucks), then the child taps the song back. Listen,
  hold it, reproduce it — a whole new kind of interaction, and the gentlest
  one: the game waits forever, and a wrong note just replays the song. The
  hero's chest light turns the colour of every note. Two levels (Light Song
  in Piglet Town, Tower Light Song in Hero City; 32 total) and
  challenge-ready scaling (longer songs, never faster ones).
- **Tap-anywhere sparkles**: a new autoload answers taps that land on
  nothing with a tiny golden sparkle, game-wide — at six, a tap that does
  nothing is a broken screen. Unhandled input only (never competes with
  real controls), off under reduce-motion.
- **The sticker wall**: stickers bought in My Rewards now appear along the
  bottom of the Hero House like a bedroom door; each one bounces, sparkles
  and sings a random island note when tapped. Purely for joy — no score,
  no goal, no way to be wrong.
- Suite: 331 checks + both probes, all green; Light Song verified by
  rendered screenshot.


## 2026-07-24 (continued) — Challenge gating fix, progression probe, honest docs

- **Fixed a real challenge bug**: `LevelResult.met_target()` read the
  original target from GameData, so a rank-scaled challenge SHOWED the
  bigger goal but completed at the base one. Results now carry a
  `target_override` wired to the live level data; completion is measured
  against what the label promises.
- **New progression probe** in the suite (`tests/ProgressionProbe.tscn`):
  XP maths (45 per clean run, replays pay in full, 120/rank boundaries),
  improvement-only coins (a same-star replay pays zero), the sticker
  economy (no overdrafts, no duplicates), and challenge scaling — including
  the exact regression above, plus proof that scaling never leaks into
  GameData. Snapshots and restores the save, so it is safe on a machine
  with a real child's save. `run_smoke.sh` runs it after the battle probe.
- Docs told the truth again: README (30 levels, six templates, five
  endless; art status), ART_CHECKLIST and ASSETS status blurbs updated to
  what actually ships versus what is still genuinely open (monster
  paintings, richer art, family voice recordings).


## 2026-07-24 (late night) — Music, voice pipeline, and the ever-growing level system

- **The island has music**: an original 26-second pentatonic lullaby loop
  (`assets/audio/music/island_theme.ogg`, composed and synthesized in-repo),
  playing softly from app start across every screen, ducking under voice
  lines. The Parent Center music slider controls or silences it.
- **Voice, one double-click away**: the sandbox cannot reach any usable TTS,
  so `tools/make_voice.command` generates all 8 Chinese lines on the family
  Mac using its built-in Tingting voice (no internet, no installs) straight
  into `assets/audio/voice/level/`; the audio loader now accepts .wav where
  call sites say .ogg. Three levels gained spoken intros
  (`voice_intro` on Hero City 1, Arena 1, Memory Toys).
- **Hero level**: every finished level pays experience (replays included —
  effort always counts, unlike coins which pay improvement only). The hero
  rank sits first in the home treasure chip (shield badge), the result
  screen shows a quiet +XP spark line, and rank-ups get a breathing gold
  "Level up!" banner. 120 XP per rank, rising forever.
- **Challenge levels — the level system that expands itself**: each world
  ends in a gold-star Challenge card that unlocks after its last hand-made
  level. Beating a challenge raises its rank permanently; every rank makes
  it a little bigger — denser skies, more sparks and duds, an extra memory
  pair, longer trails, busier traffic — always MORE TO DO, never faster
  reactions (the no-speed rule holds; spark lifetimes and car speeds never
  shrink). Rank shows on the map card and pays bonus XP. 30 levels total,
  five of which never run out.
- Suite: 319 checks + battle probe, all green.


## 2026-07-24 (night) — Every plan phase executed

- **Phase 1 juice**: sorting bins wear counter chips that pop as they fill;
  rescue stones turn green with a tick and a dotted path draws itself
  between them, the goal breathes; map islands drift in staggered and the
  frontier level of each world breathes; result-screen coins fly one by one
  into the treasure chip as it counts up; the boot title pops in and the
  hero's chest light flares hello.
- **Phase 2 art**: all 22 item icons generated in the badge style (sorting
  levels are now fully pictorial), and three painted scenes — town, forest,
  room — behind every sorting, rescue and memory level via the new shared
  `background_art` hook (`UiKit.scene_art`).
- **Phase 3 audio**: the game makes sound. Eight synthesized chime SFX ship
  in `assets/audio/` (correct, try_again, star, coin, level_complete,
  orb_collect, power_up, beam) — soft triads and sweeps, mixed quiet.
  Voice lines remain for the family to record (script in DESIGN_PLAN.md).
- **Phase 4 play**: the **Sticker Book** opens in My Rewards — twelve
  stickers bought with coins (first thing coins are FOR), owned ones glow;
  new **memory_match** template with Memory Toys and Forest Memory levels
  (25 levels, 6 templates); the three arena monsters **parade** on the map
  header once all are befriended. Rhythm-tap was consciously dropped:
  timing pressure conflicts with the no-speed rule, memory took its slot.
- SaveManager grows spend_coins/add_sticker (coins only ever leave through
  the sticker book); suite grows to 289 checks, all green.


## 2026-07-24 (evening) — Fonts, home hub polish, BabyBus-pass plan

- **Real fonts ship at last**: `assets/fonts/NotoSansSC.otf` (Noto Sans CJK
  SC Medium, OFL) — Chinese renders identically on desktop and mobile, no
  more engine-default look. Drop `Baloo2-SemiBold.ttf` beside it any time
  for the rounded Latin; the chain picks it up automatically.
- **Home hub**: treasure chip top-right (stars + coins, tap = My Rewards),
  hero waves by himself every ~9s (motion-gated), soft radial spotlight.
- **Every button** now bounces on release via `UiKit.big_button`.
- **My Rewards** restyled as white rounded cards on the soft page (treasure,
  badges, growth) with the bundle's progress-bar art — the BabyBus
  catalogue look.
- **Traffic fix**: the Tap-to-Cross button sat exactly on top of the waiting
  hero, hiding all but his head; moved to the bottom-right thumb corner and
  the hero enlarged.
- Dropped the now-unused `common.locked` string (padlock badges replaced it).
- **docs/DESIGN_PLAN.md**: the full BabyBus-quality iteration plan — next
  coding pass, exact art slots to fill (items, three world backgrounds,
  monster paintings), the voice-recording script table, and future play
  ideas (sticker book, memory match, rhythm tap).

## 2026-07-24 (later) — Shell restyle after first on-device screenshots

- **Fixed the giant overlapping stars** on the world map (and every other
  oversized badge): `TextureRect` clamps `size` until `expand_mode` is set,
  so icons silently rendered at their native 128px. All picture/star/effect
  construction now sets expand mode first; hit bursts, collect flashes,
  power rings and battle meters were all quietly affected.
- **World map restyled** on the BabyBus/Toca/Khan-Kids patterns: white
  outlined titles over the painted scene, the bundle's navy panel and level
  cards, a per-world progress bar (bundle frame/fill art), padlock badges
  instead of "(locked)" text, and playable cards rendered clearly brighter
  than locked ones so pressability reads by glow alone.
- **Home screen**: the chosen hero stands in a soft radial spotlight, the
  Adventure button breathes slowly (the screen's single pulsing action),
  bigger badges, readable parent hint.
- **Hero House cards fixed** (names now sit in the card art's name bar; the
  gold star pins to the chosen card's corner) — PanelContainer tramples
  anchors, so card content moved into a plain Control wrapper.
- **Battle sparks** got a glowing disc backing so tap targets read as
  things, not wisps; dud sparks stay square and dull.
- New `tests/Screenshot.tscn` renders any scene to PNG under Xvfb, so
  screens can be eyeballed (and were: home, map, Hero House, battle, and
  the repair level, all verified rendered) without a person at the keyboard.
- Design rationale and the reference sources are in `docs/DESIGN_NOTES.md`
  ("The shell restyle").

## 2026-07-24 — The Ultraman build: asset bundle, Hero House, juice pass, Monster Arena

One working session, three rounds. Levels went from 14 to 23, worlds from
4 to 5, templates from 4 to 5. Everything below is verified by the headless
suite: 277 smoke checks plus the battle interaction probe, 0 failures.

### Characters and the Hero House

- Integrated `ultraman_tiga_zero_complete_game_bundle.zip`: **Tiga and Zero**
  are real, selectable heroes (`resources/skins/tiga.tres`, `zero.tres`),
  alongside the original drawn Light Hero. Default character is Tiga.
- **Hero House is open** (was a "coming soon" button): a character-select room
  using the bundle's painted spotlight cards. Tap a card to become that hero
  everywhere — levels, home screen, result screen. The chosen card wears a
  gold star; the others dim but never disappear.
- `SkinnedCharacter` learned textures properly: sprites fit the placeholder's
  exact footprint (no level layout changed), `celebrate()` swaps to the cheer
  pose, and the **tintable chest light** is drawn over the sprite at each
  skin's measured chest position — the colour-matching mechanic survives real
  art. New `core_position()` exposes the light as the beam muzzle for battles.

### Visuals and game feel

- Hero City is fully textured: painted skyline (`city.png`, storm levels use
  `city_damaged.png`), painted energy tower with the level's colour lamp
  seated on its lamp orb, neutral orbs tinted at runtime, rock hazards.
- **Repair the Energy Tower now tells its story in state**: the level opens on
  the broken tower and swaps to the shining repaired one at the win, held on
  screen so the child sees what the work was for.
- Point-of-touch feedback everywhere: collect flash under the finger, a
  colour-tinted power-up ring pulsing from the tower lamp when the target
  changes, sparkle-textured confetti, painted star badges in every star row,
  the chosen hero standing on the home screen (tap = celebration), the hero
  cheering beside the result stars, coin icon on coin lines, chest in the
  Reward Center.
- Full icon-badge set wired (star, coin, heart, warning, house, spark, …) plus
  **six icons generated in the same badge style** where the bundle had none:
  check, flag, gear, car, sort, paw — navigation, bins and the map are now
  consistently textured. Texture filtering switched to linear for the painted
  art.
- The principles behind all of this are documented in `docs/DESIGN_NOTES.md`
  (game-feel "juice" adapted for age six, children's touch-target research).

### Monster Arena — the new battle world

- New `monster_battle` template: sparks appear on a city-threatening monster;
  every tap fires the hero's **light beam from the chest light to the tapped
  point on the same frame** — no cooldowns, every tap answered. A spark meter
  fills (never depletes); at the target the monster gives up, waves bye-bye,
  and hops off home. Startled, never hurt; the child cannot be harmed and
  nothing is timed.
- Three procedurally drawn monsters with distinct silhouettes — Rocky (orange,
  one horn), Blobbi (green, three googly eyes), Spikelor (purple boss, spikes)
  — parameterised from `levels.json`, each with a drop-in art slot at
  `assets/characters/monsters/<id>.png`.
- Difficulty grows by adding things to do: dud sparks (grey, square, dull —
  shape AND brightness differ, colour-blind safe) as the only mistake source,
  and slow poppable goo lobs that splat harmlessly. Bundle's `energy_beam`,
  `hit_burst` and `smoke` effects wired.

### New levels (9)

- Hero City: **Meteor Shower** (storm dodge-and-collect), **Rainbow Charge**
  (4-colour tower matching).
- Piglet Town: **Toys or Clothes?** (category sorting).
- Safety Bureau: **Danger Detective** (10-item danger sort), **Night
  Crossing** (3-lane, rain).
- Rescue Forest: **The Long Trail** (6-step trail, 4 hazards).
- Monster Arena: **Wake the Rock Monster**, **Goo Trouble**, **The Big
  Spiky**. Six new badges, all strings in English and Chinese.

### Fixes

- Collect Energy's hero was parented to the scene root and therefore drawn
  *behind* the CanvasLayer background — invisible since the template was
  written. Gameplay actors now live inside the play area.
- The traffic levels' "Safe crossings" counter no longer runs 18 px off the
  right edge (right-aligned in a fixed box; was the suite's one standing
  warning).
- `celebrate()` no longer assumes scale 1.0 (pre-existing fix kept from the
  original tree).

### Tests

- Smoke test covers Hero House, the monster icon, and all 23 levels.
- New `tests/BattleProbe.tscn`: drives the battle input handler the way a
  finger would — dud taps must nudge without scoring, 12 hits must fill the
  meter, win the level, and land a 2-star result in `GameManager` —
  `run_smoke.sh` runs it automatically after the scene sweep.

### For any build that leaves the house

Tiga and Zero are recognisable licensed characters; this build is for the
household only. Remove their two entries from `data/characters.json` (the
game falls back to the original Light Hero cleanly) before sharing a build
anywhere public. `docs/DEPLOYMENT.md` covers installing on the family's own
iOS/Android devices without any store.
