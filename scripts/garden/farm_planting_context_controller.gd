extends RefCounted
## Resolve the lesson timing and daily-care blessing for one planting.
##
## The caller supplies live lesson context and one random roll. Injecting the
## roll makes the rare-crop boundary reproducible in probes; this controller
## owns the probability and the rule that the teaching carrot is never gold.

const Dailies := preload("res://scripts/garden/farm_daily_manager.gd")

const GOLDEN_PLANT_CHANCE := 0.04


static func golden_chance(dailies: Dictionary) -> float:
	return GOLDEN_PLANT_CHANCE * 2.0 if Dailies.all_done(dailies) \
		else GOLDEN_PLANT_CHANCE


static func resolve(dailies: Dictionary, lesson_running: bool,
		plot_index: int, lesson_target_index: int, crop_id: String,
		lesson_crop_id: String, lesson_growth_seconds: int,
		golden_roll: float) -> Dictionary:
	var lesson_seed := lesson_running and plot_index == lesson_target_index \
		and crop_id == lesson_crop_id
	var golden := not lesson_running and golden_roll >= 0.0 \
		and golden_roll < golden_chance(dailies)
	return {
		"growth_override_seconds": lesson_growth_seconds if lesson_seed else 0,
		"golden": golden,
	}
