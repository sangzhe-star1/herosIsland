# Design notes: game feel and interaction, for a six-year-old

The principles this project builds against, distilled from the game-feel
("juice") literature and research on young children's interaction design, and
the places in the code where each one lives. When adding anything new, check
it against this page.

## Interaction rules (from children's UX research)

**Touch targets ≥ 2×2 cm.** Children this age need targets about four times
the adult minimum, tapped rather than dragged, and forgivingly placed. On a
1280-wide tablet viewport that is roughly 120 px. `UiKit.TOUCH_MIN` is
220×120; icons render at ~110 px; nothing interactive is smaller.
(NN/g, "Design for Kids Based on Their Stage of Physical Development".)

**Tap first; drag optional.** Precise dragging demands motor control a
pre-reader may not have. `item_sorting` accepts tap-item-then-tap-bin as a
full alternative to dragging. Never gate progress on a gesture finer than a
tap.

**Never demand speed.** Tasks requiring quick reactions to visual stimuli
frustrate this age group. Nothing in the game punishes slowness: orbs that
fall away cost nothing, traffic waits for the child, and difficulty rises as
*more to do*, not *less time to do it*.

**Pictures carry meaning; words ride along.** Every destination and item
shows an image; the word is beneath it, learned by association. The saved
hero appearing on the home screen — not just in levels — is part of this:
state the child controls should be *visible*, not remembered.

## Game-feel rules (from the juice literature)

The juice canon (squash-and-stretch, tweens on everything, particles, flashes,
screen shake, hit-stop) is written for adult reflex games. This project takes
its **accent** techniques and refuses its **assault** techniques:

- **Answer every touch at the point of touch.** Collect flash appears where
  the finger is; bursts spawn at the tapped thing; buttons visibly squash
  (`UiKit._raised`). Feedback elsewhere on screen might as well not exist.
- **Reward asymmetry** (`Juice`): a correct act earns confetti, a cheer pose,
  a count-up; a mistake earns a small nudge and nothing else. The asymmetry
  is the pedagogy.
- **One accent at a time, pointing at the instruction.** The power-up ring on
  the tower fires exactly when the target colour changes, because that is the
  moment the child must look up. Juice that doesn't direct attention is noise.
- **No screen shake, no flashing, no hit-stop.** Fast flicker is a seizure
  risk and overstimulating; shake reads as something *breaking*. All motion is
  slow, low-contrast, and switchable off (`reduce_motion` honours everything;
  pose swaps still happen because a still change is calm feedback).
- **Tell stories with state, not text.** The repair level opens on the broken
  tower and ends on the shining repaired one. The before/after IS the reward.

## Combat for a six-year-old (the Monster Arena rules)

Battles are the most requested fantasy and the easiest place to accidentally
build stress. The arena keeps the drama and removes the threat:

- **The child can act, but cannot be harmed.** The hero has no health; goo is
  slow, poppable, and splats harmlessly. There is nothing to dodge — only
  things to DO. Difficulty adds more to do, never less time to do it.
- **Every tap answered on the same frame, at the tapped point.** Beam, burst,
  flinch and meter all fire from the tap with no cooldown. Responsiveness IS
  the game feel; a dropped tap teaches a six-year-old that tapping is
  unreliable.
- **The monster is startled, never wounded.** Squash, blink, step back — no
  damage states, no distress. Winning makes it happy: it waves and hops off
  home. The exit animation is deliberately held so the child watches the
  story resolve. Excitement without anything upsetting to a six-year-old.
- **Progress only fills.** The meter is a row of sparks that light up; no
  depleting health bar on either side of the fight.
- **Telegraphs, not surprises.** The monster puffs up before it throws; the
  duds are dull, square and grey where sparks are bright, round and gold —
  shape AND brightness, so colour-blindness never decides the fight.

## The shell restyle (what the reference apps taught us)

Studying BabyBus (宝宝巴士), Toca Boca and Khan Academy Kids yielded five
conventions the shell screens now follow:

- **Brightness is the affordance.** Pressable things are the brightest
  things; locked cards sink visibly darker. A pre-reader picks the playable
  level by glow, not by reading.
- **A padlock badge, never the word "locked."** Same for every state: show
  a thing, not a term.
- **The character is the warmest pixel on screen.** The chosen hero stands
  in a soft radial spotlight on the home screen; the eye lands there first,
  exactly as BabyBus leads with its panda.
- **One pulsing primary action per screen.** The Adventure button breathes
  slowly; nothing else on the screen moves at rest. A screen where
  everything pulses is a screen where nothing does.
- **Chrome comes from one family.** Level cards, panels and progress bars
  all use the bundle's navy spotlight art, matching the icon badges — the
  same visual language from home screen to battle meter.

Voice guidance is the one BabyBus signature still missing, and the hooks are
already wired (`assets/audio/voice/`): recorded lines would do more for a
pre-reader than any further visual work.

## A Godot trap this file exists to remember

`TextureRect` clamps `size` to the texture's own size until `expand_mode`
is set — so set `expand_mode` (and `stretch_mode`) FIRST, then `size`.
Getting this backwards once rendered every 128px badge at 128px regardless
of the size asked for, which is why the world map's stars were briefly
enormous. Likewise `PanelContainer` re-lays-out its direct children:
free-positioned content (name bars, corner badges) must live inside a plain
`Control` wrapper.

## Sources

- NN/g — Design for Kids and Physical Development:
  https://www.nngroup.com/articles/children-ux-physical-development/
- GameAnalytics — "Squeezing more juice out of your game design":
  https://www.gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design
- The Design Lab — "Making Gameplay Irresistibly Satisfying Using Game Juice":
  https://thedesignlab.blog/2025/01/06/making-gameplay-irresistibly-satisfying-using-game-juice/
- GameJuice technique library: https://gamejuice.co.uk/browse
- UX for children overviews: https://www.aufaitux.com/blog/ui-ux-designing-for-children/,
  https://www.ungrammary.com/post/designing-for-kids-ux-design-tips-for-children-apps
- Toca Boca's design process: https://motionographer.com/2016/04/27/the-design-process-behind-toca-bocas-infectious-apps/
- Ramotion, UX design for kids: https://www.ramotion.com/blog/ux-design-for-kids/
- BabyBus reference apps (store pages, for style study): https://apps.apple.com/us/app/baby-panda-world-babybus/id1264951751
