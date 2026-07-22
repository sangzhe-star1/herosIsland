extends Node
## Headless smoke test. Run it with tests/run_smoke.sh.
##
## Exists because this project is written without a running engine, and static
## checking cannot catch a scene that crashes on entry. A parser error in a file
## the boot screen never touches once blanked the whole game while every static
## check passed; this is the answer to that class of problem.
##
## What it proves: every scene and every level instantiates and survives a few
## frames, the data files agree with each other, the icons all draw, and the
## scoring and save rules behave.
##
## What it cannot prove: that any of it looks good, or that a six-year-old can
## understand it. Those need eyes and hands.

const FRAMES_PER_SCENE := 6
const VIEWPORT := Vector2(1280.0, 720.0)

var _failures: Array[String] = []
var _warnings: Array[String] = []
var _checks := 0


func _ready() -> void:
	print("\n=== Little Heroes Growth Island :: smoke test ===\n")

	_check_data()
	_check_icons()
	_check_scoring()
	_check_save_rules()
	await _check_scenes()

	print("\n--- summary ---")
	print("checks run: %d" % _checks)
	for w in _warnings:
		print("WARN  %s" % w)
	for f in _failures:
		print("FAIL  %s" % f)
	print("%d failures, %d warnings" % [_failures.size(), _warnings.size()])

	if _failures.is_empty():
		print("\nSMOKE TEST PASSED\n")
	else:
		print("\nSMOKE TEST FAILED\n")
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _ok(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _warn(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_warnings.append(description)


# --- data ---------------------------------------------------------------

func _check_data() -> void:
	print("[data]")
	_ok(GameData.worlds.size() > 0, "GameData loaded no worlds")
	_ok(GameData.levels.size() > 0, "GameData loaded no levels")
	_ok(I18n.available_locales().size() >= 2, "fewer than two locales loaded")

	for level in GameData.levels:
		var id: String = str(level.get("id", ""))
		_ok(id != "", "a level has no id")
		_ok(GameData.get_world(str(level.get("world", ""))).size() > 0,
			"%s points at a world that does not exist" % id)
		var scene: String = GameData.get_minigame_scene(str(level.get("game_type", "")))
		_ok(scene != "", "%s has game_type with no scene mapping" % id)
		_ok(ResourceLoader.exists(scene), "%s scene missing: %s" % [id, scene])

		# Every displayed string must resolve, or the child sees a raw key.
		var name_key: String = str(level.get("name_key", ""))
		_ok(I18n.t(name_key) != name_key, "%s name_key does not resolve: %s" % [id, name_key])

	print("  %d worlds, %d levels" % [GameData.worlds.size(), GameData.levels.size()])


# --- icons --------------------------------------------------------------

func _check_icons() -> void:
	print("[icons]")
	var names := [
		"teddy", "ball", "blocks", "picture_book", "comic", "socks", "tshirt",
		"hat", "knife", "matches", "scissors", "medicine", "socket", "crayon",
		"pillow", "bandage", "plaster", "berries", "fish", "carrot", "blanket",
		"scarf", "check", "warning",
		"flag", "house", "gear", "star", "car", "spark", "sort", "paw",
	]
	for icon_name in names:
		var icon: Control = IconLibrary.build(icon_name, 96.0)
		_ok(icon != null, "icon '%s' did not draw" % icon_name)
		if icon != null:
			_ok(icon.get_child_count() > 0, "icon '%s' drew nothing" % icon_name)
			icon.queue_free()

	# Nothing referenced by a level may be missing an icon.
	for level in GameData.levels:
		var config: Dictionary = level.get("config", {})
		for item in config.get("items", []):
			var key: String = str(item.get("text_key", ""))
			if key.begins_with("item."):
				_warn(IconLibrary.has(key.substr(5)),
					"%s uses item '%s' with no icon" % [level.get("id"), key.substr(5)])
		for bin in config.get("bins", []):
			var icon_name2: String = str(bin.get("icon", ""))
			if icon_name2 != "":
				_ok(IconLibrary.has(icon_name2),
					"%s bin icon '%s' does not exist" % [level.get("id"), icon_name2])
	print("  %d icons drawn" % names.size())


# --- scoring rules ------------------------------------------------------

func _check_scoring() -> void:
	print("[scoring]")
	# The promises made in the README, asserted rather than trusted.
	var clean := LevelResult.new("smoke")
	clean.correct = 5
	_ok(clean.stars() == 3, "a clean run should earn 3 stars")

	var slip := LevelResult.new("smoke")
	slip.correct = 5
	slip.mistakes = 2
	_ok(slip.stars() == 2, "two mistakes should earn 2 stars")

	var messy := LevelResult.new("smoke")
	messy.correct = 5
	messy.mistakes = 9
	_ok(messy.stars() == 1, "finishing always earns at least 1 star")

	var left := LevelResult.new("smoke")
	left.quit_early = true
	_ok(left.stars() == 0, "leaving early should earn 0 stars")

	_ok(is_equal_approx(clean.accuracy(), 1.0), "clean run accuracy should be 1.0")
	print("  star rules hold")


# --- save rules ---------------------------------------------------------

func _check_save_rules() -> void:
	print("[save]")
	const KEY := "__smoke_test_level__"
	var before: Dictionary = SaveManager.data["levels"].duplicate(true)

	SaveManager.record_level_result(KEY, 3, 1.0)
	_ok(SaveManager.get_level_progress(KEY).get("stars", 0) == 3, "3 stars did not record")

	# The rule that matters: a worse replay must never take stars away.
	SaveManager.record_level_result(KEY, 1, 0.4)
	_ok(SaveManager.get_level_progress(KEY).get("stars", 0) == 3,
		"a worse replay lowered the star count")
	_ok(int(SaveManager.get_level_progress(KEY).get("attempts", 0)) == 2,
		"attempts did not increment")

	SaveManager.data["levels"] = before
	SaveManager.save_game()
	print("  stars never decrease")


# --- scenes -------------------------------------------------------------

func _check_scenes() -> void:
	print("[scenes]")
	var screens := [
		"res://scenes/boot/Boot.tscn",
		"res://scenes/home/Home.tscn",
		"res://scenes/map/WorldMap.tscn",
		"res://scenes/reward/RewardCenter.tscn",
		"res://scenes/parent/ParentCenter.tscn",
		"res://scenes/ui/ResultScreen.tscn",
	]
	for path in screens:
		await _try_scene(path, path.get_file())

	# Each level, with GameManager primed the way the real game primes it.
	for level in GameData.levels:
		var id: String = str(level.get("id", ""))
		var scene: String = GameData.get_minigame_scene(str(level.get("game_type", "")))
		if scene == "" or not ResourceLoader.exists(scene):
			continue
		GameManager.current_level_id = id
		await _try_scene(scene, id)


func _try_scene(path: String, label: String) -> void:
	_checks += 1
	if not ResourceLoader.exists(path):
		_failures.append("%s: scene file missing" % label)
		return

	var packed: PackedScene = load(path)
	if packed == null:
		_failures.append("%s: scene failed to load" % label)
		return

	var instance: Node = packed.instantiate()
	if instance == null:
		_failures.append("%s: scene failed to instantiate" % label)
		return

	add_child(instance)
	for i in range(FRAMES_PER_SCENE):
		await get_tree().process_frame

	if not is_instance_valid(instance):
		_failures.append("%s: freed itself during the first frames" % label)
		return

	_check_bounds(instance, label)
	print("  ok  %s" % label)

	remove_child(instance)
	instance.queue_free()
	await get_tree().process_frame


## Controls spilling outside the viewport. Reported as warnings rather than
## failures: some overflow is legitimate (scroll content), but a button off the
## edge of the screen is invisible to a child and worth surfacing.
func _check_bounds(node: Node, label: String) -> void:
	if node is Control:
		var control := node as Control
		if control.visible and control.size.x > 1.0 and control.size.y > 1.0:
			var rect := control.get_global_rect()
			var off_left: bool = rect.position.x < -2.0
			var off_top: bool = rect.position.y < -2.0
			var off_right: bool = rect.end.x > VIEWPORT.x + 2.0
			var off_bottom: bool = rect.end.y > VIEWPORT.y + 2.0
			if off_left or off_top or off_right or off_bottom:
				_warnings.append("%s: %s sits outside the screen (%s)"
					% [label, control.name, rect])
	for child in node.get_children():
		_check_bounds(child, label)
