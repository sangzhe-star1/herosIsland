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
