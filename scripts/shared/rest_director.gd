class_name RestDirector
extends RefCounted
## Suggesting a break, the way a person would.
##
## The brief asks for it in so many words: after two or three levels the game
## should say *"the hero has finished today's job -- shall we have a rest?"*
## and that is the entire feature. Not a lock, not a countdown, not a locked
## door with a timer on it. An invitation from a game that likes the child.
##
## Why it matters more than it looks: a six-year-old has no idea how long they
## have been playing, and the honest thing for a game aimed at one to do is
## notice on their behalf. A game that never mentions it is quietly relying on
## a parent to be the one who says stop, which makes the parent the villain
## and the game the friend. This puts the game on the parent's side.
##
## Three rules, all of them deliberate:
##   * it never blocks. "Keep playing" is always right there and never smaller
##     than the other button
##   * it counts LEVELS FINISHED, not minutes. A child who played one long
##     level has not had a long session; three quick ones is a session
##   * it says something different each time, so it does not become wallpaper

## Levels between suggestions. Three is about eight minutes at these lengths --
## roughly the span a six-year-old plays before they would benefit from
## standing up, and not so often that it nags.
const EVERY := 3

## What it says. Rotated rather than random, so the same one never lands twice
## running; all of them are the voice of the game being pleased, never tired.
const LINES := [
	"rest.done_today",
	"rest.stretch",
	"rest.come_back",
	"rest.well_played",
]


## Called once per finished level. Returns true when this is a good moment to
## offer a break.
static func should_offer() -> bool:
	var done: int = int(SaveManager.get_setting("levels_this_session", 0)) + 1
	SaveManager.set_setting("levels_this_session", done)
	return done > 0 and done % EVERY == 0


## Which line to use, so the wording moves on each time.
static func line() -> String:
	var shown: int = int(SaveManager.get_setting("rest_line", 0))
	SaveManager.set_setting("rest_line", (shown + 1) % LINES.size())
	return LINES[shown % LINES.size()]


## A new sitting. Called when the game boots, so closing the app and coming
## back tomorrow starts the count again rather than nagging on level one.
static func new_session() -> void:
	SaveManager.set_setting("levels_this_session", 0)


## How many levels into this sitting the child is -- for the message, which
## reads better when it knows.
static func so_far() -> int:
	return int(SaveManager.get_setting("levels_this_session", 0))
