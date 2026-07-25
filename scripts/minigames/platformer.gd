extends LevelManager
## The adventure template: a side-scrolling platform run.
##
## What MapleStory-likes actually give a child, reduced to what a six-year-old
## can hold: run, jump, collect the shinies, reach the flag. The level is a
## strip several screens wide; the camera follows the hero; the horizon
## parallaxes behind them.
##
## The house rules still bind, and they shape the design more than the genre
## does:
##   * No fail state. Falling into a gap floats the hero gently back to the
##     last ledge they stood on. It costs one mistake (stars 3 -> 2 -> 1,
##     never 0) and nothing else -- no lives, no restart, no losing the coins
##     already collected.
##   * Nothing is an enemy. The hazards are geometry: gaps and heights.
##   * Reaching the flag IS finishing. Coins are joy, not a toll.
##
## Terrain is generated from the level's seed, so replays return to the same
## valley, and a level entry in data/levels.json is a handful of knobs:
##   { "length": 2600, "gap_max": 120, "seg_min": 220, "coins": 8,
##     "moving": false }
## Challenge ranks stretch the trail and add coins -- never faster reflexes.

const GRAVITY := 1500.0
const MOVE_SPEED := 265.0
const JUMP_VELOCITY := -640.0
## Forgiveness, tuned for small hands: a jump pressed slightly after leaving
## a ledge (coyote) or slightly before landing (buffer) still works.
const COYOTE := 0.14
const JUMP_BUFFER := 0.16
const CAMERA_LEAD := 520.0

var _length := 2600.0
var _coins_total := 8
var _moving_platforms := false

var _world: Node2D
var _stage: Stage
var _hero: SkinnedCharacter
var _platforms: Array = []        # [{rect: Rect2, node: Node2D|null}]
var _coins: Array = []            # [{node, x, y, taken}]
var _flag_x := 0.0
var _ground_y := 0.0

var _velocity := Vector2.ZERO
var _grounded := false
var _stand_on := -1               # index into _platforms while grounded
var _coyote_left := 0.0
var _buffer_left := 0.0
var _was_space := false
var _dir_left := false
var _dir_right := false
var _last_safe := Vector2.ZERO
var _coins_got := 0
var _reached := false

var _instruction: Label
var _coin_label: Label
var _hud: Control


func setup_level() -> void:
	var config: Dictionary = level_data.get("config", {})
	_length = maxf(float(config.get("length", 2600.0)), 1400.0)
	_coins_total = int(config.get("coins", 8))
	_moving_platforms = bool(config.get("moving", false))
	var gap_max := clampf(float(config.get("gap_max", 120.0)), 60.0, 210.0)
	var seg_min := maxf(float(config.get("seg_min", 220.0)), 170.0)

	# Challenge scaling: a longer trail with more to find. The gaps grow a
	# little; the hero never has to be faster, only keep going.
	var rank := challenge_rank()
	if rank > 0:
		_length += 380.0 * float(rank)
		_coins_total += 2 * rank
		gap_max = clampf(gap_max + 6.0 * float(rank), 60.0, 230.0)

	_stage = build_world(self)
	_ground_y = _stage.ground_y()

	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_build_terrain(gap_max, seg_min)
	_add_springs(int(config.get("springs", 0)) + rank / 2)
	_build_coins()
	_build_flag()
	_build_hero()
	_build_hud()


# --- building the valley -------------------------------------------------

## Ground segments with gaps, and a floating ledge over every gap wide
## enough to need one. Seeded on the level id: the same trail every visit.
func _build_terrain(gap_max: float, seg_min: float) -> void:
	var rng := Shapes.rng_for(str(level_data.get("id", "trail")))
	var x := -200.0
	# The starting meadow is always solid and always generous.
	_add_ground(x, 560.0)
	x += 560.0
	while x < _length - 420.0:
		var gap: float = rng.randf_range(70.0, gap_max)
		var width: float = rng.randf_range(seg_min, seg_min + 240.0)
		# A ledge floats over every real gap, offering the easy route; wide
		# gaps in the floor are ALWAYS crossable the short way via the ledge.
		if gap > 95.0:
			var ledge_w: float = maxf(gap + 90.0, 170.0)
			var ledge_x: float = x + gap * 0.5 - ledge_w * 0.5
			var ledge_y: float = _ground_y - rng.randf_range(96.0, 132.0)
			_add_ledge(ledge_x, ledge_y, ledge_w, rng)
		x += gap
		_add_ground(x, width)
		# Bonus ledges above the trail, for the climbers.
		if rng.randf() < 0.55:
			_add_ledge(x + width * rng.randf_range(0.1, 0.45),
				_ground_y - rng.randf_range(120.0, 175.0),
				rng.randf_range(150.0, 210.0), rng)
		x += width
	# The final meadow holds the flag.
	_add_ground(x, 460.0)
	_flag_x = x + 300.0
	_length = x + 460.0


func _add_ground(x: float, width: float) -> void:
	var holder := Node2D.new()
	_world.add_child(holder)
	# Body below, bright lip on top -- and both colours come from the WORLD,
	# so this same template runs a green valley by day and a stone rooftop
	# trail at dusk without a line of per-level art.
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, _ground_y),
		Vector2(width, 190.0), 10.0), _slab_color(), 0.0)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, _ground_y - 4.0),
		Vector2(width, 22.0), 8.0), _stage.style.ground_top, 0.0)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, _ground_y - 4.0),
		Vector2(width, 7.0), 3.0), _stage.style.ground_top.lightened(0.20), 0.0)
	var rng := Shapes.rng_for("decor%f" % x)
	if _stage.style.ground_kind != "plaza":
		# Grass tufts so the lip is not a bare stripe.
		for i in range(int(width / 90.0)):
			var tx: float = x + rng.randf_range(14.0, width - 14.0)
			Shapes.fill(holder, PackedVector2Array([
				Vector2(tx - 7.0, _ground_y - 2.0),
				Vector2(tx + rng.randf_range(-4.0, 4.0), _ground_y - 16.0),
				Vector2(tx + 7.0, _ground_y - 2.0),
			]), _stage.style.ground_top.lightened(0.10), 0.0)
	_decorate_ground(holder, x, width, rng)
	_platforms.append({"rect": Rect2(x, _ground_y, width, 190.0), "node": null})


func _add_ledge(x: float, y: float, width: float, rng: RandomNumberGenerator) -> void:
	var holder := Node2D.new()
	_world.add_child(holder)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, y), Vector2(width, 30.0), 12.0),
		_slab_color(), 0.9)
	Shapes.fill(holder, Shapes.rounded_rect(Vector2(x, y - 3.0),
		Vector2(width, 15.0), 7.0), _stage.style.ground_top.lightened(0.06), 0.0)
	# Little roots and grass hang under a floating ledge -- the cheap line
	# that says "torn out of a hillside" instead of "UI element in the sky".
	if _stage.style.ground_kind != "plaza":
		for k in range(maxi(int(width / 110.0), 1)):
			var vx: float = x + rng.randf_range(18.0, width - 18.0)
			Shapes.fill(holder, Shapes.taper(Vector2(vx, y + 26.0),
				Vector2(vx + rng.randf_range(-5.0, 5.0), y + 26.0 + rng.randf_range(12.0, 28.0)),
				5.0, 1.8), _slab_color().lightened(0.08), 0.0)
	var entry := {"rect": Rect2(x, y, width, 30.0), "node": null}
	# In the windier levels some ledges drift up and down, slowly. Vertical
	# only, two-second period: a moving target, never a moving trap.
	if _moving_platforms and rng.randf() < 0.4:
		entry["node"] = holder
		entry["base_y"] = y
		holder.position = Vector2.ZERO
		if Juice.motion_enabled():
			var t := holder.create_tween().set_loops()
			var drift: float = rng.randf_range(44.0, 64.0)
			var period: float = rng.randf_range(2.0, 2.6)
			t.tween_property(holder, "position:y", -drift, period)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(holder, "position:y", 0.0, period)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_platforms.append(entry)


## Coins strung along the trail: over ledges and mid-segment, always where
## walking or one small jump reaches them.
func _build_coins() -> void:
	var rng := Shapes.rng_for(str(level_data.get("id", "coins")) + ":coins")
	var spots: Array = []
	for entry in _platforms:
		if entry.get("spring", false):
			continue
		var rect: Rect2 = entry["rect"]
		if rect.position.x < 200.0 or rect.position.x > _flag_x - 160.0:
			continue
		spots.append(Vector2(rect.position.x + rect.size.x * 0.5,
			rect.position.y - 86.0))
		if rect.size.x > 300.0:
			spots.append(Vector2(rect.position.x + rect.size.x * 0.22,
				rect.position.y - 74.0))
	spots.sort_custom(func(a, b): return a.x < b.x)
	while spots.size() > _coins_total:
		spots.remove_at(rng.randi() % spots.size())
	_coins_total = spots.size()
	for spot in spots:
		var coin: Control = UiKit.picture("coin", 54)
		if coin == null:
			continue
		coin.position = spot - Vector2(27, 27)
		_world.add_child(coin)
		if Juice.motion_enabled():
			var t := coin.create_tween().set_loops()
			t.tween_property(coin, "position:y", coin.position.y - 9.0, 0.9)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(coin, "position:y", coin.position.y, 0.9)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_coins.append({"node": coin, "x": spot.x, "y": spot.y, "taken": false})


## The finish line is a landmark, not an icon: a tall pole, a pennant that
## waves, a gold cap, and a few stones at the foot. Visible from half a
## screen away, which is the point of a goal.
func _build_flag() -> void:
	var flag := Node2D.new()
	flag.position = Vector2(_flag_x, _ground_y)
	_world.add_child(flag)
	var rng := Shapes.rng_for(str(level_data.get("id", "flag")) + ":flag")
	Shapes.ground_shadow(flag, Vector2.ZERO, 130.0, 0.22)
	for offs in [Vector2(-36, -5), Vector2(30, -7), Vector2(8, -3)]:
		Shapes.lit(flag, Shapes.blob(offs as Vector2, Vector2(rng.randf_range(12.0, 19.0), 9.0),
			rng, 0.2, 3, 12), Color(0.62, 0.63, 0.70), 0.8)
	Shapes.glow(flag, Vector2(0, -120.0), 130.0, Color(1.0, 0.92, 0.55), 5, 0.26)
	Shapes.fill(flag, Shapes.taper(Vector2(0, 0), Vector2(0, -176.0), 9.0, 5.5),
		Color(0.52, 0.42, 0.30), 0.9)
	Shapes.lit(flag, Shapes.circle_points(Vector2(0, -180.0), 7.5, 12),
		Color(1.0, 0.84, 0.30), 0.8)
	var pennant := Node2D.new()
	pennant.position = Vector2(2.0, -172.0)
	flag.add_child(pennant)
	Shapes.lit(pennant, PackedVector2Array([
		Vector2(2, 0), Vector2(92, 16), Vector2(68, 32), Vector2(92, 48), Vector2(2, 62),
	]), Color(0.90, 0.34, 0.36), 1.0)
	Shapes.fill(pennant, Shapes.star_points(Vector2(34, 30), 13.0, 0.45, 5),
		Color(1.0, 0.92, 0.55), 0.0)
	if Juice.motion_enabled():
		var t := pennant.create_tween().set_loops()
		t.tween_property(pennant, "rotation_degrees", 4.0, 1.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(pennant, "rotation_degrees", -3.0, 1.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_hero() -> void:
	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = Vector2(150.0, _ground_y)
	_world.add_child(_hero)
	_hero.set_height(150.0)
	_last_safe = _hero.position


func _slab_color() -> Color:
	return _stage.style.ground_bottom.darkened(0.22)


## Set dressing along the trail: flowers, bushes and pines in the green
## worlds; lit windows, lamps and roof vents in the city, where the slabs ARE
## rooftops. Small, sparse, behind the action, and coloured from the world's
## own palette -- the difference between a runway and a place. Placement
## avoids the middle band of each segment, which is where the mushrooms go.
func _decorate_ground(holder: Node2D, x: float, width: float,
		rng: RandomNumberGenerator) -> void:
	if _stage.style.ground_kind == "plaza":
		# Window grid on the slab face: the run is across the tops of
		# buildings, so the buildings get to say so.
		var wy: float = _ground_y + 30.0
		while wy < _ground_y + 140.0:
			var wx: float = x + 26.0
			while wx < x + width - 42.0:
				if rng.randf() < 0.55:
					var lit: bool = rng.randf() < 0.62
					Shapes.fill(holder, Shapes.rounded_rect(Vector2(wx, wy),
						Vector2(18.0, 24.0), 4.0),
						Color(1.0, 0.86, 0.52, rng.randf_range(0.5, 0.9)) if lit
							else Color(0.0, 0.02, 0.10, 0.28), 0.0)
				wx += 52.0
			wy += 54.0
	var count := int(width / 250.0)
	for i in range(count):
		var fx: float = x + width * (rng.randf_range(0.05, 0.44) if rng.randf() < 0.5
			else rng.randf_range(0.80, 0.94))
		var d := Node2D.new()
		d.position = Vector2(fx, _ground_y)
		holder.add_child(d)
		if _stage.style.ground_kind == "plaza":
			if rng.randf() < 0.6:
				_decor_lamp(d)
			else:
				_decor_vent(d, rng)
		else:
			var roll: float = rng.randf()
			if roll < 0.42:
				_decor_flower(d, rng)
			elif roll < 0.72:
				_decor_bush(d, rng)
			else:
				_decor_pine(d, rng)


func _decor_flower(d: Node2D, rng: RandomNumberGenerator) -> void:
	var h: float = rng.randf_range(20.0, 32.0)
	Shapes.fill(d, Shapes.taper(Vector2.ZERO, Vector2(rng.randf_range(-4.0, 4.0), -h),
		3.6, 2.2), _stage.style.ground_top.darkened(0.10), 0.0)
	var petal: Color = [Color(0.98, 0.62, 0.70), Color(1.0, 0.84, 0.36),
		Color(0.80, 0.72, 0.98)][rng.randi() % 3]
	for k in range(5):
		var a: float = TAU * float(k) / 5.0
		Shapes.fill(d, Shapes.circle_points(Vector2(0, -h) + Vector2(cos(a), sin(a)) * h * 0.16,
			h * 0.13, 8), petal, 0.0)
	Shapes.fill(d, Shapes.circle_points(Vector2(0, -h), h * 0.10, 8),
		Color(1.0, 0.94, 0.62), 0.0)


func _decor_bush(d: Node2D, rng: RandomNumberGenerator) -> void:
	var r: float = rng.randf_range(16.0, 26.0)
	var leaf: Color = _stage.style.ground_top.darkened(0.08)
	Shapes.lit(d, Shapes.blob(Vector2(-r * 0.4, -r * 0.5), Vector2(r, r * 0.8), rng, 0.16, 3, 14),
		leaf, 0.8)
	Shapes.lit(d, Shapes.blob(Vector2(r * 0.4, -r * 0.45), Vector2(r * 0.8, r * 0.7), rng, 0.16, 3, 14),
		leaf.lightened(0.08), 0.8)


func _decor_pine(d: Node2D, rng: RandomNumberGenerator) -> void:
	var h: float = rng.randf_range(46.0, 72.0)
	Shapes.fill(d, Shapes.taper(Vector2.ZERO, Vector2(0, -h * 0.4), h * 0.10, h * 0.07),
		Color(0.46, 0.33, 0.24), 0.8)
	var leaf: Color = _stage.style.ground_top.darkened(0.16)
	for k in range(2):
		var t: float = float(k) * 0.5
		var w: float = h * lerpf(0.36, 0.22, t)
		Shapes.lit(d, PackedVector2Array([
			Vector2(-w, -h * (0.32 + t * 0.3)), Vector2(0, -h * (0.66 + t * 0.34)),
			Vector2(w, -h * (0.32 + t * 0.3)),
		]), leaf.lightened(t * 0.08), 0.8)


func _decor_lamp(d: Node2D) -> void:
	Shapes.fill(d, Shapes.taper(Vector2.ZERO, Vector2(0, -52.0), 7.0, 4.5),
		Color(0.30, 0.32, 0.42), 0.8)
	Shapes.glow(d, Vector2(0, -58.0), 46.0, Color(1.0, 0.86, 0.52), 4, 0.32)
	Shapes.fill(d, Shapes.circle_points(Vector2(0, -58.0), 6.5, 10),
		Color(1.0, 0.93, 0.70), 0.0)


func _decor_vent(d: Node2D, rng: RandomNumberGenerator) -> void:
	Shapes.lit(d, Shapes.rounded_rect(Vector2(-16.0, -15.0), Vector2(32.0, 15.0), 5.0),
		Color(0.34, 0.37, 0.48), 0.8)
	if rng.randf() < 0.6:
		Shapes.fill(d, Shapes.rounded_rect(Vector2(-10.0, -11.0), Vector2(20.0, 4.0), 2.0),
			Color(1.0, 0.86, 0.52, 0.7), 0.0)


## Bounce mushrooms: land on the cap and get launched high -- pure joy, no
## danger, and the way up to the highest coins. Placed on wide ground
## segments away from the start and the flag.
func _add_springs(count: int) -> void:
	if count <= 0:
		return
	var rng := Shapes.rng_for(str(level_data.get("id", "trail")) + ":springs")
	var candidates: Array = []
	for entry in _platforms:
		if entry.get("spring", false) or entry["node"] != null:
			continue
		var rect: Rect2 = entry["rect"]
		if rect.size.y < 100.0:
			continue                      # ground segments only, not ledges
		if rect.position.x < 700.0 or rect.position.x > _flag_x - 500.0:
			continue
		if rect.size.x < 280.0:
			continue
		candidates.append(rect)
	while candidates.size() > count:
		candidates.remove_at(rng.randi() % candidates.size())
	for rect in candidates:
		var sx: float = rect.position.x + rect.size.x * rng.randf_range(0.55, 0.75)
		var holder := Node2D.new()
		holder.position = Vector2(sx, _ground_y)
		_world.add_child(holder)
		# A big friendly mushroom: cream stem, red cap, white spots.
		Shapes.fill(holder, Shapes.taper(Vector2(0, 0), Vector2(0, -26.0), 30.0, 22.0),
			Color(0.97, 0.93, 0.82), 0.9)
		var cap := Node2D.new()
		cap.position = Vector2(0, -26.0)
		holder.add_child(cap)
		var dome := PackedVector2Array()
		for i in range(13):
			var a: float = PI + PI * float(i) / 12.0
			dome.append(Vector2(cos(a) * 44.0, sin(a) * 30.0))
		dome.append(Vector2(38.0, 4.0))
		dome.append(Vector2(-38.0, 4.0))
		Shapes.lit(cap, dome, Color(0.90, 0.34, 0.36), 1.0)
		for spot in [Vector2(-18, -14), Vector2(10, -20), Vector2(24, -8)]:
			Shapes.fill(cap, Shapes.circle_points(spot as Vector2, 6.0, 10),
				Color(1, 1, 1, 0.92), 0.0)
		Shapes.ground_shadow(holder, Vector2.ZERO, 90.0, 0.18)
		_platforms.append({
			"rect": Rect2(sx - 40.0, _ground_y - 54.0, 80.0, 54.0),
			"node": null, "spring": true, "cap": cap,
		})


# --- HUD and controls ------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = UiKit.theme()
	layer.add_child(_hud)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(24, 24)
	_hud.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t("platformer.instruction")
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.position = Vector2(240, 34)
	_instruction.size = Vector2(800, 52)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_instruction)

	# The coin pouch, top right.
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.26, 0.82)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	chip.add_theme_stylebox_override("panel", style)
	chip.position = Vector2(1080, 26)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var coin_icon: Control = UiKit.picture("coin", 38)
	if coin_icon != null:
		row.add_child(coin_icon)
	_coin_label = Label.new()
	_coin_label.text = "0 / %d" % _coins_total
	_coin_label.add_theme_font_size_override("font_size", 30)
	_coin_label.add_theme_color_override("font_color", Palette.ON_COLOR)
	row.add_child(_coin_label)
	chip.add_child(row)
	_hud.add_child(chip)

	# The control pad. Left and right under the left thumb, jump under the
	# right -- the same corners the duel put its skills in, so hands that
	# learned one screen already know the other.
	_pad_button(Vector2(36, 556), 128.0, "left")
	_pad_button(Vector2(196, 556), 128.0, "right")
	_pad_button(Vector2(1104, 544), 148.0, "jump")


func _pad_button(at: Vector2, size: float, kind: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.position = at
	b.focus_mode = Control.FOCUS_NONE
	var face := Color(0.09, 0.15, 0.30, 0.92)
	var ring := Color(1.0, 0.86, 0.40) if kind == "jump" else Color(0.55, 0.75, 0.95)
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.set_corner_radius_all(int(size / 2.0))
	style.border_width_bottom = 6
	style.border_width_top = 5
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_color = ring
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, style if state != "pressed" else _pressed_style(style))
	b.pivot_offset = Vector2(size, size) / 2.0
	_hud.add_child(b)

	# Drawn arrows: symbols a pre-reader owns already.
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var c := Vector2(size, size) / 2.0
	var r: float = size * 0.22
	match kind:
		"left":
			Shapes.fill(icon, PackedVector2Array([
				c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r * 1.1, 0),
			]), Color(0.92, 0.96, 1.0), 0.0)
		"right":
			Shapes.fill(icon, PackedVector2Array([
				c + Vector2(-r, -r), c + Vector2(-r, r), c + Vector2(r * 1.1, 0),
			]), Color(0.92, 0.96, 1.0), 0.0)
		"jump":
			Shapes.fill(icon, PackedVector2Array([
				c + Vector2(-r * 1.1, 0.0), c + Vector2(0, -r * 1.2), c + Vector2(r * 1.1, 0.0),
			]), Color(1.0, 0.94, 0.6), 0.0)
			Shapes.fill(icon, Shapes.rounded_rect(c + Vector2(-r * 0.34, r * 0.05),
				Vector2(r * 0.68, r * 0.95), r * 0.2), Color(1.0, 0.94, 0.6), 0.0)

	match kind:
		"left":
			b.button_down.connect(func(): _dir_left = true)
			b.button_up.connect(func(): _dir_left = false)
		"right":
			b.button_down.connect(func(): _dir_right = true)
			b.button_up.connect(func(): _dir_right = false)
		"jump":
			b.button_down.connect(func():
				_buffer_left = JUMP_BUFFER
				Juice.pop(b, 0.10)
			)


func _pressed_style(base: StyleBoxFlat) -> StyleBoxFlat:
	var s: StyleBoxFlat = base.duplicate()
	s.bg_color = Color(base.bg_color.r, base.bg_color.g, base.bg_color.b, 0.9)
	return s


# --- the run ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _finished or _hero == null or not is_instance_valid(_hero):
		return

	# Keyboard for the desktop build; the buttons for the tablet.
	var left: bool = _dir_left or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var right: bool = _dir_right or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	var space: bool = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP)
	if space and not _was_space:
		_buffer_left = JUMP_BUFFER
	_was_space = space

	var dir: float = (1.0 if right else 0.0) - (1.0 if left else 0.0)
	_velocity.x = dir * MOVE_SPEED
	_velocity.y += GRAVITY * delta

	_buffer_left = maxf(_buffer_left - delta, 0.0)
	_coyote_left = maxf(_coyote_left - delta, 0.0)
	if _buffer_left > 0.0 and (_grounded or _coyote_left > 0.0):
		_buffer_left = 0.0
		_coyote_left = 0.0
		_grounded = false
		_stand_on = -1
		_velocity.y = JUMP_VELOCITY
		_hero.set_pose(HeroArt.Pose.JUMP)

	var prev_y: float = _hero.position.y
	_hero.position.x = clampf(_hero.position.x + _velocity.x * delta, 60.0, _length - 60.0)
	_hero.position.y += _velocity.y * delta

	# Standing on a drifting ledge: ride it.
	if _grounded and _stand_on >= 0:
		var top: float = _platform_top(_stand_on)
		if _on_platform_x(_stand_on):
			_hero.position.y = top
		else:
			_grounded = false
			_stand_on = -1
			_coyote_left = COYOTE

	# Landing: only while falling, only onto a top crossed this frame.
	if _velocity.y > 0.0:
		for i in range(_platforms.size()):
			var top2: float = _platform_top(i)
			if prev_y <= top2 + 1.0 and _hero.position.y >= top2 and _on_platform_x(i):
				if _platforms[i].get("spring", false):
					_bounce(i, top2)
					break
				_hero.position.y = top2
				_velocity.y = 0.0
				if not _grounded:
					Juice.dust(_world, _hero.position, 4, 0.7)
					_hero.set_pose(HeroArt.Pose.IDLE)
				_grounded = true
				_stand_on = i
				var rect: Rect2 = _platforms[i]["rect"]
				_last_safe = Vector2(
					clampf(_hero.position.x, rect.position.x + 40.0,
						rect.position.x + rect.size.x - 40.0), top2)
				break

	# Walking animation follows what the feet are doing.
	if _grounded:
		_hero.walk(absf(dir) > 0.1)

	_collect_coins()
	_check_flag()
	_check_fall()
	_scroll_camera()


## The mushroom launch: much higher than a jump, with a squash on the cap
## and sparks off the hero. The extra height is the only way to the highest
## coins, which is what makes the mushroom a discovery rather than a decoration.
func _bounce(i: int, top: float) -> void:
	_hero.position.y = top
	_velocity.y = -980.0
	_grounded = false
	_stand_on = -1
	_hero.set_pose(HeroArt.Pose.JUMP)
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")
	Juice.dust(_world, Vector2(_hero.position.x, _ground_y), 5, 0.8)
	var cap: Variant = _platforms[i].get("cap")
	if cap is Node2D and is_instance_valid(cap) and Juice.motion_enabled():
		var t := (cap as Node2D).create_tween()
		t.tween_property(cap, "scale", Vector2(1.25, 0.55), 0.10)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(cap, "scale", Vector2.ONE, 0.22)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _platform_top(i: int) -> float:
	var entry: Dictionary = _platforms[i]
	var rect: Rect2 = entry["rect"]
	var node: Variant = entry["node"]
	if node != null and is_instance_valid(node):
		return float(entry["base_y"]) + (node as Node2D).position.y
	return rect.position.y


func _on_platform_x(i: int) -> bool:
	var rect: Rect2 = _platforms[i]["rect"]
	return _hero.position.x >= rect.position.x - 16.0 \
		and _hero.position.x <= rect.position.x + rect.size.x + 16.0


func _collect_coins() -> void:
	for coin in _coins:
		if coin["taken"]:
			continue
		if absf(_hero.position.x - float(coin["x"])) < 52.0 \
				and absf((_hero.position.y - 60.0) - float(coin["y"])) < 78.0:
			coin["taken"] = true
			_coins_got += 1
			_coin_label.text = "%d / %d" % [_coins_got, _coins_total]
			var node: Control = coin["node"]
			if is_instance_valid(node):
				Juice.burst(_world, node.position + Vector2(27, 27), 10)
				node.queue_free()
			AudioManager.play_sfx("res://assets/audio/coin.ogg")


func _check_flag() -> void:
	if _reached:
		return
	if absf(_hero.position.x - _flag_x) < 64.0 and _grounded:
		_reached = true
		_hero.walk(false)
		_hero.victory()
		AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
		# The coins picked up on the trail go straight into the pouch, on top
		# of the level reward. A collected coin that vanished at the flag
		# would be a broken promise at any age.
		if _coins_got > 0:
			SaveManager.add_coins(_coins_got)
		# Every coin found earns one extra confetti moment before the result.
		if _coins_got >= _coins_total and _coins_total > 0:
			Juice.burst(_world, _hero.position + Vector2(0, -120), 26)
		score_correct()


## Falling is the level's only mistake, and it is a soft one: float back up
## to the last safe ledge, lose a star's worth of accuracy, keep every coin.
func _check_fall() -> void:
	if _hero.position.y < _ground_y + 240.0:
		return
	score_mistake()
	_velocity = Vector2.ZERO
	_grounded = true
	_stand_on = -1
	_hero.position = _last_safe
	_hero.set_pose(HeroArt.Pose.IDLE)
	_hero.stumble()
	Juice.dust(_world, _hero.position, 6)
	_instruction.text = I18n.t("platformer.fell")
	var timer := get_tree().create_timer(2.2)
	timer.timeout.connect(func():
		if is_instance_valid(_instruction) and not _finished:
			_instruction.text = I18n.t("platformer.instruction")
	)


## The camera: the world slides, the horizon slides slower. This is where the
## valley stops being a screen and starts being a place that continues.
func _scroll_camera() -> void:
	var scroll: float = clampf(_hero.position.x - CAMERA_LEAD, 0.0, _length - 1280.0)
	_world.position.x = -scroll
	if _stage != null and is_instance_valid(_stage):
		_stage.parallax(scroll)
