extends Node
## The one place on the island that reads a clock.
##
## Until this existed, `Time.` was called from wherever it was needed -- nine
## sites, no agreement between them, and nothing that could be pointed at a
## pretend clock. That was survivable while the only thing time did was count
## today's play minutes. It stops being survivable the moment something GROWS
## while the game is closed: "the carrot is ready tomorrow morning" cannot be
## tested by waiting until tomorrow morning.
##
## Two clocks live here and they are not interchangeable:
##
##   now_unix()  WALL time. Survives a restart, so it is the only one that can
##               answer "how long was the game closed". It can also be dragged
##               backwards by a child who finds the date picker in Settings,
##               which is why elapsed_since() is the clamped one below.
##   ticks_ms()  MONOTONIC time since this process started. Cannot be tampered
##               with, resets to zero every launch, and -- the thing that
##               caused a real bug -- keeps counting while iOS holds the app
##               suspended in the background.
##
## Everything reads through here so that a probe can set both and step time
## forward on purpose. See tests/clock_probe.gd.

## The most growth any single absence is allowed to be worth.
##
## Eight hours covers "he went to bed and came back after breakfast", which is
## the real case this is for. It also means that setting the tablet's date
## forward a year buys exactly the same as one night's sleep -- so there is
## nothing to discover, and nothing to be clever about.
const MAX_OFFLINE_SECONDS := 8 * 60 * 60

## How far backwards the wall clock may drift before it counts as the date
## being changed rather than the usual second or two of NTP correction.
const ROLLBACK_GRACE_SECONDS := 60

var _test_unix: int = -1
var _test_ticks: int = -1


func _ready() -> void:
	print("[autoload] GameClock ok")


# --- wall time ---

func now_unix() -> int:
	if _test_unix >= 0:
		return _test_unix
	return int(Time.get_unix_time_from_system())


## Today, as "YYYY-MM-DD". Local date on a real device, because a child's day
## is a local thing -- an evening in Shanghai is not the same day in UTC.
func now_date() -> String:
	if _test_unix >= 0:
		return Time.get_date_string_from_unix_time(_test_unix)
	return Time.get_date_string_from_system()


func now_datetime() -> Dictionary:
	if _test_unix >= 0:
		return Time.get_datetime_dict_from_unix_time(_test_unix)
	return Time.get_datetime_dict_from_system()


## The calendar dictionary of any unix time (weekday 0 = Sunday), for a caller
## asking about another moment than now; same fields as now_datetime().
func datetime_at(unix_time: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(unix_time)


## The date of a calendar dictionary as a whole-day count, so consecutive
## dates are consecutive numbers whatever the hour. The dictionary is read as
## if it were UTC on purpose: this counts the date the child sees.
func day_index_of(dt: Dictionary) -> int:
	return int(floor(float(Time.get_unix_time_from_datetime_dict(dt)) / 86400.0))


func now_datetime_string() -> String:
	if _test_unix >= 0:
		return Time.get_datetime_string_from_unix_time(_test_unix)
	return Time.get_datetime_string_from_system()


# --- monotonic time ---

func ticks_ms() -> int:
	if _test_ticks >= 0:
		return _test_ticks
	return Time.get_ticks_msec()


# --- the one piece of arithmetic worth centralising ---

## Seconds between `stamp` and now, with both ends made safe.
##
## Never negative: a clock dragged backwards must not un-grow anything, so an
## absence that reads as negative is worth nothing rather than worth going
## backwards. Never more than MAX_OFFLINE_SECONDS: a clock dragged forwards
## buys one night's sleep and no more.
##
## `stamp` of 0 means "no stamp yet" and is worth nothing, not fifty-six years.
func elapsed_since(stamp: int) -> int:
	if stamp <= 0:
		return 0
	var raw := now_unix() - stamp
	if raw < 0:
		return 0
	return mini(raw, MAX_OFFLINE_SECONDS)


## True when the wall clock has moved backwards past the point of being an NTP
## nudge. The caller decides what to do about it -- growth re-anchors to now,
## so a changed date costs the child nothing and gains him nothing.
func went_backwards(stamp: int) -> bool:
	return stamp > 0 and now_unix() < stamp - ROLLBACK_GRACE_SECONDS


func is_new_day(stamp: int) -> bool:
	if stamp <= 0:
		return true
	return Time.get_date_string_from_unix_time(stamp) != now_date()


# --- for probes only ---

## Point both clocks somewhere. A probe that wants to watch a carrot grow
## overnight sets this instead of waiting until tomorrow.
func set_test_now(unix_seconds: int, ticks_milliseconds: int = -1) -> void:
	_test_unix = unix_seconds
	_test_ticks = ticks_milliseconds


func advance_test(seconds: int) -> void:
	if _test_unix < 0:
		_test_unix = int(Time.get_unix_time_from_system())
	if _test_ticks < 0:
		_test_ticks = Time.get_ticks_msec()
	_test_unix += seconds
	_test_ticks += seconds * 1000


func clear_test_now() -> void:
	_test_unix = -1
	_test_ticks = -1


func under_test() -> bool:
	return _test_unix >= 0 or _test_ticks >= 0
