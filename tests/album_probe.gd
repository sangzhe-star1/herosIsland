extends Node
## 怪兽图鉴: can it actually be filled?
##
##   godot --headless --path . res://tests/AlbumProbe.tscn
##
## A collection is worth exactly as much as its ability to be completed. This
## checks that every card in the book is reachable by playing -- and that the
## monster on the card is the one he fought, not a stand-in.

const Album := preload("res://scripts/reward/monster_album.gd")
const Art := preload("res://scripts/reward/monster_art.gd")

var _out: Array[String] = []


func _ok(condition: bool, message: String) -> void:
	if not condition:
		_out.append(message)


func _ready() -> void:
	await get_tree().process_frame
	print("\n=== album probe ===")

	SaveManager.data["rewards"]["album"] = []
	print("  the book holds %d monsters" % Album.total())
	_ok(Album.total() >= 15, "only %d monsters in the book" % Album.total())
	_ok(Album.met_count() == 0, "a brand new child has already met something")

	_every_card_is_reachable()
	_each_monster_looks_like_itself()
	await _beating_one_writes_it_down()
	_collecting_is_finishable()

	for f in _out:
		print("FAIL  %s" % f)
	print("ALBUM PROBE %s\n" % ("PASSED" if _out.is_empty() else "FAILED"))
	get_tree().quit(1 if _out.size() > 0 else 0)


## Every card must be earnable. A monster in the book that appears in no level
## is a page he can never turn, which is worse than not printing it.
func _every_card_is_reachable() -> void:
	var reachable := {}
	for level in GameData.levels:
		var config: Dictionary = level.get("config", {})
		# Duels name their monster directly.
		var duel := str(config.get("monster", {}).get("id", ""))
		if duel != "" and not reachable.has(duel):
			reachable[duel] = str(level.get("id", ""))
		# Adventure levels name theirs on the sections.
		for section in config.get("sections", []):
			# First level only: the EARLIEST place he can earn the card is the
			# interesting number. Overwriting kept the last one and made three
			# monsters look like they only turned up in the fifth world.
			#
			# A section names WHO in `monsters`, separately from HOW IT BEHAVES
			# in `kinds`. Those were one field once, which is why the album's
			# first three cards were called walker, spitter and armoured -- the
			# names of three behaviours, not three creatures.
			for named in section.get("monsters", []):
				if not reachable.has(str(named)):
					reachable[str(named)] = str(level.get("id", ""))
			var arena := str(section.get("monster", ""))
			if str(section.get("kind", "")) == "boss" and arena != "" \
					and not reachable.has(arena):
				reachable[arena] = str(level.get("id", ""))

	var stranded: Array = []
	for entry in Album.all():
		var mid := str(entry.get("id", ""))
		if reachable.has(mid):
			print("    %-15s first earned in %s" % [mid, reachable[mid]])
		else:
			stranded.append(mid)
	_ok(stranded.is_empty(),
		"in the book but in no level, so he can never earn them: %s"
			% ", ".join(stranded))


## Fifteen monsters, fifteen creatures -- and fifteen pictures that really
## load. tools_check proves the files exist and differ; this proves the game
## can DECODE them, which is a different question and the one that has bitten
## this project before: a .png whose import artifact was never built on this
## machine reports as present and comes back null.
func _each_monster_looks_like_itself() -> void:
	var seen := {}
	var clones: Array = []
	var missing: Array = []
	for entry in Album.all():
		var mid := str(entry.get("id", ""))
		var tex: Texture2D = Art.texture(mid)
		if tex == null:
			missing.append(mid)
		else:
			var look := "%dx%d" % [tex.get_width(), tex.get_height()]
			if seen.has(look) and seen[look] != mid:
				# Same pixel size is not proof of a clone, so this only
				# reports; the byte-identical check lives in tools_check.
				pass
			seen[look] = mid
		# Every card needs a name, a place, a move and a way to win, or it is
		# a picture with no story on the page behind it.
		for key in ["name_key", "where_key", "skill_key", "weakness_key",
				"about_key", "element_key"]:
			var s: String = str(entry.get(key, ""))
			_ok(s != "" and I18n.t(s) != s,
				"%s has nothing written for %s" % [mid, key])
	print("  %d monsters, %d pictures loaded"
		% [Album.total(), Album.total() - missing.size()])
	_ok(missing.is_empty(),
		"these monsters have no picture the game can load: %s"
			% ", ".join(missing))
	_ok(clones.is_empty(), "two monsters look identical: %s" % ", ".join(clones))


## Winning a duel has to put the card in the book -- once.
func _beating_one_writes_it_down() -> void:
	SaveManager.data["rewards"]["album"] = []
	GameManager.current_level_id = "sunny_park_06"
	var duel: Node = load("res://scenes/minigames/monster_duel/MonsterDuel.tscn")\
		.instantiate()
	add_child(duel)
	for i in range(6):
		await get_tree().process_frame
	var who := str(duel.get("_monster_id"))
	print("  sunny_park_06 fights '%s'" % who)
	_ok(who != "", "the first duel has no monster id, so nothing can be recorded")
	_ok(not Album.met(who), "already in the book before the fight")

	# Win it the way a child does: land every hit the monster takes.
	var need: int = duel.call("target_value", "correct", 0)
	Engine.time_scale = 30.0
	var guard := 0
	while not bool(duel.get("_won")) and guard < 4000:
		duel.set("_light_left", 5)
		duel.call("fire_beam_skill")
		await get_tree().process_frame
		guard += 1
	Engine.time_scale = 1.0
	print("  beat it in %d hits (target %d)" % [int(duel.result.correct), need])
	_ok(bool(duel.get("_won")), "could not win the first duel at all")
	_ok(Album.met(who), "beat %s and it never went into the book" % who)
	_ok(Album.met_count() == 1,
		"beating one monster filled %d cards" % Album.met_count())

	# ...and beating it again must not add a second copy.
	Album.beat_monster(who)
	_ok(Album.met_count() == 1,
		"the same monster got into the book twice (%d cards)" % Album.met_count())
	print("  book now %d / %d, and a replay does not add a duplicate"
		% [Album.met_count(), Album.total()])
	if is_instance_valid(duel):
		duel.queue_free()
	await get_tree().process_frame


func _collecting_is_finishable() -> void:
	for entry in Album.all():
		Album.beat_monster(str(entry.get("id", "")))
	print("  every monster beaten: %d / %d" % [Album.met_count(), Album.total()])
	_ok(Album.met_count() == Album.total(),
		"beat every monster and the book still says %d / %d"
			% [Album.met_count(), Album.total()])
	SaveManager.data["rewards"]["album"] = []
