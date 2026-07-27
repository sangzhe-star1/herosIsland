extends Node
## The clock, and the one bug it was built to kill.
##
## Everything here is about a clock nobody can watch: the app is in a bag, the
## tablet's date has been changed by a curious six-year-old, or the thing being
## measured takes until tomorrow morning. None of that can be checked by
## playing, which is why it needs a probe that can move time on purpose.

var _failures: Array[String] = []


func _ok(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _ready() -> void:
	print("\n=== clock probe ===")
	await get_tree().process_frame

	_a_pretend_clock_can_be_pointed_anywhere()
	_time_dragged_backwards_is_worth_nothing()
	_time_dragged_forwards_is_worth_one_night()
	_three_hours_in_a_bag_is_not_three_hours_of_play()

	for failure in _failures:
		print("FAIL  %s" % failure)
	print("CLOCK PROBE %s\n" % ("PASSED" if _failures.is_empty() else "FAILED"))
	get_tree().quit(1 if _failures.size() > 0 else 0)


## Without this nothing else in this file is possible, so it is checked first.
func _a_pretend_clock_can_be_pointed_anywhere() -> void:
	var real := GameClock.now_unix()
	_ok(not GameClock.under_test(), "the clock starts real")

	GameClock.set_test_now(1_700_000_000, 0)
	_ok(GameClock.under_test(), "the clock knows it is being pretended at")
	_ok(GameClock.now_unix() == 1_700_000_000, "a pretend clock reads what it was told")
	_ok(GameClock.ticks_ms() == 0, "...and so does the monotonic side")

	GameClock.advance_test(3600)
	_ok(GameClock.now_unix() == 1_700_003_600, "an hour forward is an hour forward")
	_ok(GameClock.ticks_ms() == 3_600_000, "...on both clocks, in step")

	GameClock.clear_test_now()
	_ok(not GameClock.under_test(), "and it can be handed back")
	_ok(absi(GameClock.now_unix() - real) < 60, "the real clock is still the real clock")


## A tablet's date is two taps away in Settings, and a child who finds it will
## drag it. Backwards must never un-grow anything, and must never leave the
## garden frozen either.
func _time_dragged_backwards_is_worth_nothing() -> void:
	GameClock.set_test_now(1_700_000_000, 0)
	var planted := GameClock.now_unix()

	# Half an hour passes honestly.
	GameClock.advance_test(1800)
	_ok(GameClock.elapsed_since(planted) == 1800, "half an hour reads as half an hour")

	# Now the date goes back a week.
	GameClock.advance_test(-7 * 24 * 60 * 60)
	_ok(GameClock.elapsed_since(planted) == 0,
		"a clock dragged backwards is worth nothing, never a negative")
	_ok(GameClock.went_backwards(planted),
		"...and the game can tell that is what happened, so it can re-anchor")

	# A second or two of NTP correction is not the date being changed.
	GameClock.set_test_now(planted - 5, 0)
	_ok(not GameClock.went_backwards(planted),
		"a few seconds of clock correction is not a child in the Settings app")

	GameClock.clear_test_now()


## Forwards is the one worth being strict about: it is the only direction that
## could hand out something for nothing.
func _time_dragged_forwards_is_worth_one_night() -> void:
	GameClock.set_test_now(1_700_000_000, 0)
	var planted := GameClock.now_unix()

	GameClock.advance_test(365 * 24 * 60 * 60)
	_ok(GameClock.elapsed_since(planted) == GameClock.MAX_OFFLINE_SECONDS,
		"setting the date forward a year buys exactly one night, no more")

	# And one night really is worth one night.
	GameClock.set_test_now(planted + 8 * 60 * 60, 0)
	_ok(GameClock.elapsed_since(planted) == GameClock.MAX_OFFLINE_SECONDS,
		"a full night is worth the full night")
	GameClock.set_test_now(planted + 60 * 60, 0)
	_ok(GameClock.elapsed_since(planted) == 3600, "an hour away is worth an hour")

	# A stamp of zero means "never started", not "started in 1970".
	_ok(GameClock.elapsed_since(0) == 0,
		"an unset timestamp is worth nothing, not fifty-six years")

	_ok(GameClock.is_new_day(0), "with no stamp at all, it is a new day")
	GameClock.set_test_now(1_700_000_000, 0)
	_ok(not GameClock.is_new_day(1_700_000_000), "the same moment is the same day")

	GameClock.clear_test_now()


## The regression this whole file exists for.
##
## Time.get_ticks_msec() does not stop while iOS holds the app suspended, and
## GameManager banked (now - session start) on the next flush without ever
## noticing that the app had come back. Twenty minutes of play plus three hours
## on the sofa was recorded as three hours and twenty minutes -- past the
## thirty-minute daily limit, so the next time he asked to play he was told he
## was finished for the day.
func _three_hours_in_a_bag_is_not_three_hours_of_play() -> void:
	var real_save: Dictionary = SaveManager.data.duplicate(true)
	SaveManager.data = SaveManager._default_data()

	# 08:00 on a Tuesday. A morning start on purpose: today's play time is kept
	# under a date key, so a test that began at ten at night would cross
	# midnight halfway through and measure the calendar instead of the bug.
	const TUESDAY_MORNING := 1_699_948_800
	GameClock.set_test_now(TUESDAY_MORNING, 0)
	GameManager._notification(NOTIFICATION_APPLICATION_RESUMED)   # start of session

	# Twenty minutes of actual play.
	GameClock.advance_test(20 * 60)
	GameManager._notification(NOTIFICATION_APPLICATION_PAUSED)
	var after_play := SaveManager.playtime_today()
	_ok(absf(after_play - 1200.0) < 2.0,
		"twenty minutes of play is banked as twenty minutes")

	# Into the bag for three hours. The monotonic clock keeps running.
	GameClock.advance_test(3 * 60 * 60)
	GameManager._notification(NOTIFICATION_APPLICATION_RESUMED)
	GameManager.flush_playtime()
	var after_bag := SaveManager.playtime_today()
	_ok(absf(after_bag - after_play) < 2.0,
		"three hours in a bag adds nothing to today's play time")
	_ok(not GameManager.daily_limit_reached(),
		"...so he is not locked out of a game he played once this morning")

	# And real play after coming back still counts.
	GameClock.advance_test(5 * 60)
	GameManager.flush_playtime()
	_ok(absf(SaveManager.playtime_today() - (after_bag + 300.0)) < 2.0,
		"five more minutes after coming back is five more minutes")

	# Tomorrow is a fresh allowance. This falls out of keeping play time under a
	# date key rather than a counter, and it is worth pinning: a child who used
	# up Tuesday should not wake up on Wednesday already finished.
	var tuesday_total := SaveManager.playtime_today()
	GameClock.advance_test(24 * 60 * 60)
	_ok(SaveManager.playtime_today() == 0.0,
		"the next day starts at zero, however long yesterday was")
	_ok(tuesday_total > 0.0, "...and yesterday really had something in it")
	GameClock.set_test_now(TUESDAY_MORNING + 3 * 60 * 60, 0)
	_ok(absf(SaveManager.playtime_today() - tuesday_total) < 2.0,
		"and yesterday's total is still there, not overwritten")

	GameClock.clear_test_now()
	SaveManager.data = real_save
	SaveManager.save_game()
