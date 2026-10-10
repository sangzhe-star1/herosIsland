extends Node
## Read a supplied save only after copying it into this isolated QA project's
## user:// directory. The source path is never opened for writing.

const EXPECTED_MARKER := "SAVE MIGRATION AUDIT COMPLETED"


func _ready() -> void:
	call_deferred("_run_audit")


func _run_audit() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var input_path := str(options.get("input_save", ""))
	var output_dir := str(options.get("output_dir", ""))
	if input_path.is_empty() or output_dir.is_empty():
		_fail("Pass --input-save and --output-dir after the scene path.")
		return
	if not input_path.is_absolute_path() or not FileAccess.file_exists(input_path):
		_fail("The input save must be an existing absolute file path.")
		return
	if not output_dir.is_absolute_path():
		_fail("The report directory must be an absolute path.")
		return

	var source := FileAccess.open(input_path, FileAccess.READ)
	if source == null:
		_fail("The input save could not be opened for reading.")
		return
	var source_text := source.get_as_text()
	source.close()
	var source_variant: Variant = JSON.parse_string(source_text)
	if not source_variant is Dictionary:
		_fail("The input file is not a JSON save object.")
		return
	var source_save: Dictionary = source_variant.duplicate(true)

	var report_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if report_error != OK:
		_fail("The report directory could not be created.")
		return
	var isolated_save_path := ProjectSettings.globalize_path(SaveManager.SAVE_PATH)
	for relative_path in [SaveManager.SAVE_PATH, SaveManager.SAVE_BACKUP,
			SaveManager.SAVE_TMP]:
		var absolute_path := ProjectSettings.globalize_path(relative_path)
		if FileAccess.file_exists(relative_path):
			DirAccess.remove_absolute(absolute_path)
	var copy_error := DirAccess.copy_absolute(input_path, isolated_save_path)
	if copy_error != OK:
		_fail("The source save could not be copied into isolated user:// storage.")
		return

	# Run the real startup path, including schema migration and offline farm
	# settlement. All writes stay under this QA snapshot's unique user folder.
	SaveManager.load_game()
	SaveManager.save_game()
	SaveManager.load_game()
	SaveManager.save_game()
	var normalized_text := FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var normalized_variant: Variant = JSON.parse_string(normalized_text)
	if not normalized_variant is Dictionary:
		_fail("The migrated save could not be read back from isolated disk storage.")
		return
	var normalized_save: Dictionary = normalized_variant
	var live_save: Dictionary = SaveManager.data
	var report := _build_report(source_save, normalized_save, live_save, input_path)
	if not _write_json(output_dir.path_join("migration_report.json"), report):
		_fail("The migration report could not be written.")
		return
	if not _write_json(output_dir.path_join("normalized_save.json"), normalized_save):
		_fail("The normalized save copy could not be written.")
		return
	print("SAVE MIGRATION AUDIT COMPLETED")
	print("Report: %s" % output_dir.path_join("migration_report.json"))
	print("Normalized copy: %s" % output_dir.path_join("normalized_save.json"))
	print("Source save remains read-only; all game writes used isolated user://.")
	get_tree().quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var result := {}
	var index := 0
	while index < args.size():
		if index + 1 < args.size() and args[index] in ["--input-save", "--output-dir"]:
			var key := "input_save" if args[index] == "--input-save" else "output_dir"
			result[key] = args[index + 1]
			index += 2
		else:
			index += 1
	return result


func _build_report(source: Dictionary, normalized: Dictionary, live: Dictionary,
		input_path: String) -> Dictionary:
	var source_farm: Dictionary = source.get("farm", {}) \
		if source.get("farm") is Dictionary else {}
	var source_farm_shape_ok := not source.has("farm") \
		or source.get("farm") is Dictionary
	var final_farm: Dictionary = normalized.get("farm", {}) \
		if normalized.get("farm") is Dictionary else {}
	var source_profile: Dictionary = source.get("profile", {}) \
		if source.get("profile") is Dictionary else {}
	var source_profile_shape_ok := not source.has("profile") \
		or source.get("profile") is Dictionary
	var final_profile: Dictionary = normalized.get("profile", {}) \
		if normalized.get("profile") is Dictionary else {}
	var source_rewards: Dictionary = source.get("rewards", {}) \
		if source.get("rewards") is Dictionary else {}
	var source_rewards_shape_ok := not source.has("rewards") \
		or source.get("rewards") is Dictionary
	var final_rewards: Dictionary = normalized.get("rewards", {}) \
		if normalized.get("rewards") is Dictionary else {}
	var lost_farm_keys: Array[String] = []
	var added_farm_keys: Array[String] = []
	var changed_farm_keys: Array[String] = []
	for key in source_farm.keys():
		if key == "harvest_checkpoint":
			if normalized.has("harvest_checkpoint"):
				continue # Known legacy key moved to its current top-level owner.
		if not final_farm.has(key):
			lost_farm_keys.append(str(key))
		elif not _same_json_value(source_farm[key], final_farm[key]):
			changed_farm_keys.append(str(key))
	for key in final_farm.keys():
		if not source_farm.has(key):
			added_farm_keys.append(str(key))
	var source_coins_value: Variant = source_rewards.get("coins", 0)
	var source_spent_value: Variant = source_rewards.get("spent_stars", 0)
	var coin_fields_shape_ok := source_rewards_shape_ok \
		and (not source_rewards.has("coins") or _is_number(source_coins_value)) \
		and (not source_rewards.has("spent_stars") or _is_number(source_spent_value))
	var source_coins := int(source_coins_value) if _is_number(source_coins_value) else 0
	var expected_refund := maxi(0, int(source_spent_value)) \
		if _is_number(source_spent_value) else 0
	var normalized_coins_value: Variant = final_rewards.get("coins", 0)
	var normalized_coins := int(normalized_coins_value) \
		if _is_number(normalized_coins_value) else 0
	var live_farm: Dictionary = live.get("farm", {}) \
		if live.get("farm") is Dictionary else {}
	var checks := {
		"normalized_main_save_exists": not normalized.is_empty(),
		"profile_xp_not_lost": source_profile_shape_ok
			and (not source_profile.has("xp") or _is_number(source_profile.get("xp")))
			and _is_number(final_profile.get("xp", 0))
			and _is_number(source_profile.get("xp", 0))
			and float(final_profile.get("xp", 0)) >= float(source_profile.get("xp", 0)),
		"coins_preserved_or_old_star_refund_applied": coin_fields_shape_ok
			and _is_number(normalized_coins_value)
			and normalized_coins == source_coins + expected_refund,
		"level_records_preserved": _same_json_value(source.get("levels", {}), normalized.get("levels", {})),
		"shared_version_is_current": int(normalized.get("version", 0)) == SaveManager.SAVE_VERSION,
		"farm_version_is_current": int(normalized.get("save_version", 0)) == SaveManager.FARM_SAVE_VERSION,
		"disk_and_live_farm_match": _same_json_value(final_farm, live_farm),
		"source_farm_is_object_or_missing": source_farm_shape_ok,
	}
	return {
		"audit_format": 1,
		"source_file": input_path.get_file(),
		"source_bytes": FileAccess.get_file_as_bytes(input_path).size(),
		"source_version": source.get("version", null),
		"source_save_version": source.get("save_version", null),
		"normalized_version": normalized.get("version", null),
		"normalized_save_version": normalized.get("save_version", null),
		"loaded_at_unix": GameClock.now_unix(),
		"profile_xp_before": source_profile.get("xp", null),
		"profile_xp_after": final_profile.get("xp", null),
		"coins_before": source_coins,
		"coins_after": normalized_coins,
		"old_spent_stars_refund_expected": expected_refund,
		"farm_before": _farm_summary(source_farm),
		"farm_after": _farm_summary(final_farm),
		"lost_farm_keys": lost_farm_keys,
		"added_farm_keys": added_farm_keys,
		"changed_farm_keys": changed_farm_keys,
		"human_review_required": not source_farm_shape_ok \
			or not lost_farm_keys.is_empty() or not changed_farm_keys.is_empty(),
		"checks": checks,
		"basic_checks_passed": _all_checks_passed(checks),
	}


func _farm_summary(farm: Dictionary) -> Dictionary:
	var plots: Array[Dictionary] = []
	var raw_plots: Variant = farm.get("plots", [])
	if raw_plots is Array:
		for index in range(raw_plots.size()):
			var raw_plot: Variant = raw_plots[index]
			if not raw_plot is Dictionary:
				plots.append({"index": index, "valid": false})
				continue
			var plot: Dictionary = raw_plot
			plots.append({
				"index": index,
				"state": plot.get("state", null),
				"crop_id": plot.get("crop_id", null),
				"plant_cycle_id": plot.get("plant_cycle_id", null),
				"growth_stage": plot.get("growth_stage", null),
				"growth_progress": plot.get("growth_progress", null),
				"water_level": plot.get("water_level", null),
				"golden": plot.get("golden", null),
			})
	return {
		"farm_level": farm.get("farm_level", null),
		"farm_xp": farm.get("farm_xp", null),
		"plot_count": farm.get("plot_count", null),
		"plot_array_valid": raw_plots is Array,
		"plots": plots,
		"warehouse": farm.get("warehouse", {}),
		"harvest_basket": farm.get("harvest_basket", {}),
		"unlocked_crops": farm.get("unlocked_crops", []),
	}


func _same_json_value(actual: Variant, expected: Variant) -> bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size():
			return false
		for key in expected.keys():
			if not actual.has(key) or not _same_json_value(actual[key], expected[key]):
				return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_json_value(actual[index], expected[index]):
				return false
		return true
	if typeof(actual) in [TYPE_INT, TYPE_FLOAT] \
			and typeof(expected) in [TYPE_INT, TYPE_FLOAT]:
		return is_equal_approx(float(actual), float(expected))
	return actual == expected


func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


func _all_checks_passed(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true


func _write_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return true


func _fail(reason: String) -> void:
	push_error("SAVE MIGRATION AUDIT FAILED: %s" % reason)
	get_tree().quit(1)
