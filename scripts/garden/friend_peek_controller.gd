extends RefCounted
## 一二三木头人 on a friend's farm: the friend turns its back, then turns round
## to look, on a fixed beat. While its back is turned, a child holding the
## quiet bed fills a little ring; while it is looking, the ring simply waits.
##
## This is the playable half of 偷菜 with the half that hurts left out. The
## friend loses nothing (its produce is arithmetic, the crop is conjured), being
## seen costs nothing (the ring pauses, it never empties), and there is no luck
## anywhere: the beat is the same every time, so a child who watches learns
## when to go. The turn is always announced first -- the friend wiggles before
## it turns round -- so a careful player is never surprised.
##
## Deliberately NOT a class_name, loaded through preload like the other
## garden controllers.

const AWAY := "away"          # back turned: picking fills the ring
const TURNING := "turning"    # the wiggle before it looks: still safe
const LOOKING := "looking"    # facing him: the ring waits

## One beat, in seconds. AWAY + TURNING is longer than HOLD, so a child who
## starts as the friend turns away always finishes inside one window.
const AWAY_SECONDS := 3.0
const TURNING_SECONDS := 0.8
const LOOKING_SECONDS := 1.6
const HOLD_SECONDS := 1.4

var elapsed := 0.0
var progress := 0.0      # 0..1, never decreases within a visit
var done := false


static func beat() -> float:
	return AWAY_SECONDS + TURNING_SECONDS + LOOKING_SECONDS


static func phase_at(time: float) -> String:
	var t := fposmod(time, beat())
	if t < AWAY_SECONDS:
		return AWAY
	if t < AWAY_SECONDS + TURNING_SECONDS:
		return TURNING
	return LOOKING


func phase() -> String:
	return phase_at(elapsed)


## Advance the beat by `delta`. Returns "done" on the frame the ring fills,
## "frozen" on frames he is holding while the friend looks, else "".
func step(delta: float, holding: bool) -> String:
	elapsed += maxf(delta, 0.0)
	if done or not holding:
		return ""
	if phase() == LOOKING:
		return "frozen"
	progress = minf(1.0, progress + maxf(delta, 0.0) / HOLD_SECONDS)
	if progress >= 1.0:
		done = true
		return "done"
	return ""
