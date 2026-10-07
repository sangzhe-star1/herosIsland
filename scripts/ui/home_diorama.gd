extends Node3D
## 3D Toy Diorama Island Home Screen (北欧绘本治愈风 / 任天堂式 3D 微缩玩具沙盘大厅)
## Features:
## - 3D Diorama Island with low-saturation warm Nordic / Morandi toy palette
## - Smooth touch/drag horizontal interactive rotation with gentle spring return
## - Diegetic UI buttons anchored to 3D landmarks via unproject_position
## - Active hero papercraft/billboard standing in center plaza with breathing tween & responsive tricks
## - Dynamic notification badges: "🧺 可收获" for ripe garden crops, "⭐ 新装扮" for new wardrobe items
## - Authentic game navigation: World Map (with daily limit break dialog), Hero House, Garden, Rewards, Monster Battles
## - Fully responsive top HUD adapting to 16:9 widescreen and 4:3 iPad tablet
## - Safe parent door access with hold-to-enter progress bar and hint

const Farm := preload("res://scripts/garden/farm_save.gd")
const Growth := preload("res://scripts/garden/offline_growth.gd")
const Shop := preload("res://scripts/shop/shop_manager.gd")

const GLB_PATH := "res://assets/scenes_3d/home_diorama.glb"
const PARENT_HOLD_SECONDS := 3.0

var _camera: Camera3D
var _diorama: Node3D
var _ui_layer: CanvasLayer
var _hud_root: Control
var _labels: Array[Dictionary] = []
var _time: float = 0.0

var _hero_sprite: Sprite3D
var _hero_holder: Node3D
var _trick_count: int = 0
var _windmill_blades: Node3D
var _windmill_speed: float = 1.0

var _is_dragging: bool = false
var _target_yaw: float = 0.0
var _current_yaw: float = 0.0

# Parent door hold tracking
var _hold_time: float = 0.0
var _holding: bool = false
var _hint_flash: int = 0
var _parent_pill: Button
var _parent_fill: Panel
var _parent_hint: Label

# Precise local 3D landmark positions on the diorama model
const LOCAL_LOCATIONS := {
	"adventure": Vector3(3.9, 2.7, -1.7),  # Toy Airship & Launch Pier
	"house": Vector3(-3.5, 2.9, -1.6),      # Hero's Cozy Cottage
	"garden": Vector3(3.4, 1.5, 1.8),       # Starlight Veggie Garden
	"reward": Vector3(-3.4, 2.3, 1.8),      # Golden Treasure Chest
	"monster": Vector3(0.0, 2.6, -3.0),     # Chubby Purple Monster Dais
}

# Refined Morandi / Nordic Picture-Book Palette for UI Badges (低饱和度、柔和温润)
const NORDIC_PALETTE := {
	"adventure": Color(0.32, 0.58, 0.38), # 柔和森林草甸绿 (Warm Forest Sage)
	"house": Color(0.50, 0.42, 0.60),     # 温润丁香灰紫 (Muted Lavender Plum)
	"garden": Color(0.76, 0.40, 0.30),    # 陶土暖珊瑚橘 (Terracotta Coral)
	"reward": Color(0.80, 0.58, 0.24),    # 温暖蜂蜜琥珀金 (Honey Amber Gold)
	"monster": Color(0.42, 0.46, 0.65),   # 柔和雾霾蓝紫 (Soft Periwinkle Slate)
}

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_load_diorama()
	_setup_hero()
	_setup_hud()
	_setup_landmark_buttons()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	# Soothing powder morning sky blue (低饱和柔和晨曦蓝)
	env.background_color = Color(0.62, 0.73, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.58, 0.65)
	env.ambient_light_energy = 0.20 # Keep low so shadows have depth and colors stay warm & calm
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.96, 0.90) # Warm morning sunlight
	sun.light_energy = 0.85
	sun.light_specular = 0.08 # Soft matte highlights on clay and wood
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = Color(0.68, 0.78, 0.88)
	fill.light_energy = 0.20
	fill.rotation_degrees = Vector3(30, -145, 0)
	add_child(fill)

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "MainCamera"
	_camera.position = Vector3(0.0, 9.8, 12.5)
	_camera.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	_camera.fov = 38.0
	add_child(_camera)

func _load_diorama() -> void:
	if ResourceLoader.exists(GLB_PATH):
		var scene: PackedScene = load(GLB_PATH)
		_diorama = scene.instantiate()
		_diorama.name = "DioramaIsland"
		add_child(_diorama)
		_start_idle_animations()

func _start_idle_animations() -> void:
	# Windmill blades reference
	_windmill_blades = _diorama.find_child("Windmill_Blades", true, false) as Node3D

	# Floating Star gentle bobbing
	var star := _diorama.find_child("Floating_Star", true, false)
	if star != null and star is Node3D:
		var orig_y: float = star.position.y
		var tw := create_tween().set_loops()
		tw.tween_property(star, "position:y", orig_y + 0.25, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(star, "position:y", orig_y, 1.2).set_trans(Tween.TRANS_SINE)

	# Adventure Airship gentle floating
	var airship := _diorama.find_child("Adventure_Airship", true, false)
	if airship != null and airship is Node3D:
		var orig_ay: float = airship.position.y
		var tw_a := create_tween().set_loops()
		tw_a.tween_property(airship, "position:y", orig_ay + 0.18, 1.6).set_trans(Tween.TRANS_SINE)
		tw_a.tween_property(airship, "position:y", orig_ay, 1.6).set_trans(Tween.TRANS_SINE)

	# Chubby Toy Monster breathing
	var monster := _diorama.find_child("Toy_Monster", true, false)
	if monster != null and monster is Node3D:
		var tw_m := create_tween().set_loops()
		tw_m.tween_property(monster, "scale", Vector3(1.08, 0.95, 0.95), 1.4).set_trans(Tween.TRANS_SINE)
		tw_m.tween_property(monster, "scale", Vector3(1.02, 1.04, 0.90), 1.4).set_trans(Tween.TRANS_SINE)

	# Starlight Garden sweet carrots gentle breathing wobble
	for ci in range(5):
		var carrot := _diorama.find_child("Carrot_%d" % ci, true, false)
		if carrot != null and carrot is Node3D:
			var tw_c := create_tween().set_loops()
			tw_c.tween_interval(ci * 0.18)
			tw_c.tween_property(carrot, "scale", Vector3(1.08, 1.08, 0.94), 0.9).set_trans(Tween.TRANS_SINE)
			tw_c.tween_property(carrot, "scale", Vector3(0.96, 0.96, 1.04), 0.9).set_trans(Tween.TRANS_SINE)

func _setup_hero() -> void:
	# Place the active Hero on the Center Plaza of the Diorama
	var char_id := str(SaveManager.data.get("profile", {}).get("character_id", "tiga"))
	var tex_path := "res://assets/characters/%s/hero_idle.png" % char_id
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/characters/tiga/hero_idle.png"
	
	if ResourceLoader.exists(tex_path):
		_hero_holder = Node3D.new()
		_hero_holder.name = "HeroHolder"
		_hero_holder.position = Vector3(0.0, 1.35, 0.1)
		
		_hero_sprite = Sprite3D.new()
		_hero_sprite.name = "HeroSprite"
		_hero_sprite.texture = load(tex_path)
		_hero_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_hero_sprite.pixel_size = 0.0072
		_hero_sprite.shaded = false
		_hero_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
		_hero_holder.add_child(_hero_sprite)
		
		if _diorama != null:
			_diorama.add_child(_hero_holder)
		else:
			add_child(_hero_holder)

		# Idle breathing tween
		var tw := create_tween().set_loops()
		tw.tween_property(_hero_sprite, "scale", Vector3(1.05, 0.95, 1.0), 0.75).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_hero_sprite, "scale", Vector3(0.96, 1.04, 1.0), 0.75).set_trans(Tween.TRANS_SINE)

		# Periodic cheerful hop
		var hop_timer := Timer.new()
		hop_timer.wait_time = 8.5
		hop_timer.autostart = true
		add_child(hop_timer)
		hop_timer.timeout.connect(func():
			if not Juice.motion_enabled() or not is_instance_valid(_hero_holder):
				return
			var hop_tw := create_tween()
			hop_tw.tween_property(_hero_holder, "position:y", 1.70, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			hop_tw.tween_property(_hero_holder, "position:y", 1.35, 0.26).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		)

func _setup_hud() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "HUD"
	add_child(_ui_layer)

	_hud_root = Control.new()
	_hud_root.name = "HudRoot"
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_hud_root)

	# 1. Top Title Plaque (Warm Nordic parchment)
	var banner := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.98, 0.97, 0.94, 0.95)
	b_style.set_corner_radius_all(UiKit.RADIUS_CARD)
	b_style.border_width_left = 2
	b_style.border_width_top = 2
	b_style.border_width_right = 2
	b_style.border_width_bottom = 4
	b_style.border_color = Color(0.86, 0.82, 0.76)
	b_style.shadow_color = Color(0.10, 0.14, 0.20, 0.12)
	b_style.shadow_size = 6
	b_style.content_margin_left = 22
	b_style.content_margin_right = 22
	b_style.content_margin_top = 8
	b_style.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", b_style)
	banner.position = Vector2(28, 24)

	var b_label := Label.new()
	b_label.text = "🚩 小英雄探险岛"
	b_label.add_theme_font_size_override("font_size", UiKit.TYPE_TITLE)
	b_label.add_theme_color_override("font_color", Palette.INK)
	banner.add_child(b_label)
	_hud_root.add_child(banner)

	# 2. Top-Right Treasure Bar (Responsive Anchor to Top-Right)
	var treasure := Button.new()
	treasure.focus_mode = Control.FOCUS_NONE
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.18, 0.22, 0.28, 0.92)
	t_style.set_corner_radius_all(UiKit.RADIUS_CARD)
	t_style.border_width_left = 2
	t_style.border_width_top = 2
	t_style.border_width_right = 2
	t_style.border_width_bottom = 3
	t_style.border_color = Color(0.88, 0.74, 0.38, 0.8)
	t_style.shadow_color = Color(0.10, 0.14, 0.20, 0.15)
	t_style.shadow_size = 6
	t_style.content_margin_left = 18
	t_style.content_margin_right = 18
	t_style.content_margin_top = 8
	t_style.content_margin_bottom = 8
	for state in ["normal", "hover", "pressed"]:
		treasure.add_theme_stylebox_override(state, t_style)
	
	treasure.anchor_left = 1.0
	treasure.anchor_right = 1.0
	treasure.offset_left = -270
	treasure.offset_right = -28
	treasure.offset_top = 24
	treasure.offset_bottom = 68
	treasure.pressed.connect(func():
		AudioManager.play_sfx("res://assets/audio/pop.ogg")
		Juice.pop(treasure, 0.06)
		SceneManager.goto_scene("res://scenes/reward/RewardCenter.tscn"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Rank
	var shield_icon := UiKit.picture("shield", 28)
	if shield_icon != null: row.add_child(shield_icon)
	var rank_lbl := Label.new()
	rank_lbl.text = "%d" % SaveManager.hero_level()
	rank_lbl.add_theme_font_size_override("font_size", 20)
	rank_lbl.add_theme_color_override("font_color", Palette.ON_COLOR)
	row.add_child(rank_lbl)

	# Stars
	var star_icon := UiKit.picture("star", 28)
	if star_icon != null: row.add_child(star_icon)
	var star_lbl := Label.new()
	star_lbl.text = "%d" % SaveManager.total_stars()
	star_lbl.add_theme_font_size_override("font_size", 20)
	star_lbl.add_theme_color_override("font_color", Palette.ON_COLOR)
	row.add_child(star_lbl)

	# Coins
	var coin_icon := UiKit.picture("coin", 28)
	if coin_icon != null: row.add_child(coin_icon)
	var coin_lbl := Label.new()
	coin_lbl.text = "%d" % int(SaveManager.data["rewards"]["coins"])
	coin_lbl.add_theme_font_size_override("font_size", 20)
	coin_lbl.add_theme_color_override("font_color", Palette.ON_COLOR)
	row.add_child(coin_lbl)

	treasure.add_child(row)
	_hud_root.add_child(treasure)

	# 3. Bottom-Left Parent Door (Hold for 3 seconds)
	_setup_parent_door()

func _setup_parent_door() -> void:
	_parent_pill = Button.new()
	_parent_pill.focus_mode = Control.FOCUS_NONE
	_parent_pill.clip_contents = true
	_parent_pill.anchor_top = 1.0
	_parent_pill.anchor_bottom = 1.0
	_parent_pill.offset_left = 28
	_parent_pill.offset_bottom = -24
	_parent_pill.offset_top = -72
	_parent_pill.offset_right = 168
	
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.18, 0.24, 0.32, 0.70)
	p_style.set_corner_radius_all(UiKit.RADIUS_CARD)
	p_style.border_width_bottom = 3
	p_style.border_color = Color(0.28, 0.34, 0.44)
	for state in ["normal", "hover", "pressed"]:
		_parent_pill.add_theme_stylebox_override(state, p_style)

	_parent_pill.button_down.connect(_begin_hold)
	_parent_pill.button_up.connect(_cancel_hold)
	_hud_root.add_child(_parent_pill)

	_parent_fill = Panel.new()
	_parent_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.42, 0.65, 0.85, 0.80)
	fill_style.set_corner_radius_all(UiKit.RADIUS_CARD)
	_parent_fill.add_theme_stylebox_override("panel", fill_style)
	_parent_fill.size = Vector2(0, 48)
	_parent_pill.add_child(_parent_fill)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	_parent_pill.add_child(hbox)

	var gear := UiKit.picture("gear", 26)
	if gear != null:
		hbox.add_child(gear)

	_parent_hint = Label.new()
	_parent_hint.text = "🔒 家长中心"
	_parent_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parent_hint.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
	_parent_hint.add_theme_color_override("font_color", Palette.ON_COLOR)
	hbox.add_child(_parent_hint)

func _begin_hold() -> void:
	_holding = true
	_hold_time = 0.0
	_parent_fill.size.x = 0.0

func _cancel_hold() -> void:
	var early: bool = _holding and _hold_time >= 0.12 and _hold_time < PARENT_HOLD_SECONDS
	_reset_hold()
	if early and is_instance_valid(_parent_hint):
		_hint_flash += 1
		var token: int = _hint_flash
		_parent_hint.text = "长按3秒进入"
		get_tree().create_timer(2.0).timeout.connect(func():
			if _hint_flash == token and not _holding and is_instance_valid(_parent_hint):
				_parent_hint.text = "🔒 家长中心"
		)

func _reset_hold() -> void:
	_holding = false
	_hold_time = 0.0
	if is_instance_valid(_parent_fill):
		_parent_fill.size.x = 0.0
	if is_instance_valid(_parent_hint):
		_parent_hint.text = "🔒 家长中心"

func _setup_landmark_buttons() -> void:
	var items: Array[Dictionary] = [
		{
			"id": "adventure",
			"name": "🚀 去冒险",
			"color": NORDIC_PALETTE["adventure"],
			"scale": 1.25,
			"badge": "",
			"target": func(): _on_play()
		},
		{
			"id": "house",
			"name": "🏡 英雄小屋",
			"color": NORDIC_PALETTE["house"],
			"scale": 1.05,
			"badge": "⭐ 新装扮" if _house_has_something_new() else "",
			"target": func(): SceneManager.goto_scene("res://scenes/shop/HeroHouseScreen.tscn")
		},
		{
			"id": "garden",
			"name": "🥕 星光菜园",
			"color": NORDIC_PALETTE["garden"],
			"scale": 1.05,
			"badge": "🧺 可收获" if _garden_has_something_ripe() else "",
			"target": func(): _on_garden()
		},
		{
			"id": "reward",
			"name": "🎁 我的奖励",
			"color": NORDIC_PALETTE["reward"],
			"scale": 1.05,
			"badge": "",
			"target": func(): SceneManager.goto_scene("res://scenes/reward/RewardCenter.tscn")
		},
		{
			"id": "monster",
			"name": "👾 光之战士",
			"color": NORDIC_PALETTE["monster"],
			"scale": 1.05,
			"badge": "",
			"target": func(): _on_battle()
		},
	]

	for item in items:
		var btn := Button.new()
		btn.text = item["name"]
		btn.focus_mode = Control.FOCUS_NONE
		var btn_w: float = 148.0 * item["scale"]
		var btn_h: float = 54.0 * item["scale"]
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
		btn.add_theme_font_size_override("font_size", int(22 * item["scale"]))
		btn.add_theme_color_override("font_color", Palette.ON_COLOR)
		
		var col: Color = item["color"]
		var style := StyleBoxFlat.new()
		style.bg_color = col
		style.set_corner_radius_all(int(27 * item["scale"]))
		style.border_width_bottom = int(5 * item["scale"])
		style.border_color = Color(col.r * 0.75, col.g * 0.75, col.b * 0.75) # Subtle darker border
		style.shadow_color = Color(0.08, 0.12, 0.18, 0.22)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 3)
		style.content_margin_left = 18
		style.content_margin_right = 18
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		
		# Attach cute badge if applicable
		var badge_text: String = item["badge"]
		if badge_text != "":
			var badge := PanelContainer.new()
			var badge_style := StyleBoxFlat.new()
			badge_style.bg_color = Color(0.92, 0.35, 0.25) # Vibrant coral badge
			badge_style.set_corner_radius_all(UiKit.RADIUS_INNER)
			badge_style.border_width_left = 2
			badge_style.border_width_top = 2
			badge_style.border_width_right = 2
			badge_style.border_width_bottom = 2
			badge_style.border_color = Color.WHITE
			badge_style.content_margin_left = 10
			badge_style.content_margin_right = 10
			badge_style.content_margin_top = 3
			badge_style.content_margin_bottom = 3
			badge.add_theme_stylebox_override("panel", badge_style)
			badge.position = Vector2(btn_w - 32, -14)
			
			var badge_lbl := Label.new()
			badge_lbl.text = badge_text
			badge_lbl.add_theme_font_size_override("font_size", UiKit.TYPE_CAPTION)
			badge_lbl.add_theme_color_override("font_color", Color.WHITE)
			badge.add_child(badge_lbl)
			btn.add_child(badge)
			
			# Gentle bounce on badge
			var btw := badge.create_tween().set_loops()
			btw.tween_property(badge, "position:y", -18.0, 0.6).set_trans(Tween.TRANS_SINE)
			btw.tween_property(badge, "position:y", -14.0, 0.6).set_trans(Tween.TRANS_SINE)

		var target: Callable = item["target"]
		var item_id: String = item["id"]
		btn.pressed.connect(func():
			AudioManager.play_sfx("res://assets/audio/pop.ogg")
			_hero_answers(item_id)
			Juice.pop(btn, 0.08)
			target.call())

		_ui_layer.add_child(btn)
		_labels.append({
			"btn": btn,
			"pos_local": LOCAL_LOCATIONS[item_id],
			"phase": randf() * TAU
		})

# Navigation actions matching game rules
func _on_play() -> void:
	if GameManager.daily_limit_reached():
		_show_break_message()
		return
	SceneManager.goto_world_map()

func _on_garden() -> void:
	for level in GameData.levels:
		if bool(level.get("room", false)) and str(level.get("game_type", "")) == "garden":
			GameManager.start_level(str(level.get("id", "")))
			return

func _on_battle() -> void:
	var levels: Array = GameData.get_levels_for_mode("battle")
	if levels.is_empty():
		return
	var next: Dictionary = levels[levels.size() - 1]
	for level in levels:
		if int(SaveManager.get_level_progress(str(level.get("id", ""))).get("stars", 0)) <= 0:
			next = level
			break
	GameManager.start_level(str(next.get("id", "")))

func _garden_has_something_ripe() -> bool:
	var raw: Variant = SaveManager.data.get("farm", null)
	if not (raw is Dictionary):
		return false
	var settled: Dictionary = Growth.settle(raw as Dictionary, GameClock.now_unix())
	var plots: Array = settled.get("plots", [])
	for i in range(plots.size()):
		if Farm.is_ready(Farm.normalise_plot(plots[i], i)):
			return true
	return false

func _house_has_something_new() -> bool:
	var shop: Dictionary = SaveManager.data.get("shop", {})
	for owned in shop.get("owned", []):
		if Shop.is_new(str(owned)):
			return true
	return false

func _hero_answers(landmark_id: String) -> void:
	if not Juice.motion_enabled() or not is_instance_valid(_hero_holder):
		return
	var tw := create_tween()
	match landmark_id:
		"adventure":
			tw.tween_property(_hero_holder, "position:y", 1.85, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(_hero_holder, "position:y", 1.35, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"house":
			tw.tween_property(_hero_holder, "rotation_degrees:y", 25.0, 0.15)
			tw.tween_property(_hero_holder, "rotation_degrees:y", 0.0, 0.2)
		"garden":
			tw.tween_property(_hero_holder, "rotation_degrees:y", -25.0, 0.15)
			tw.tween_property(_hero_holder, "rotation_degrees:y", 0.0, 0.2)
		_:
			tw.tween_property(_hero_holder, "position:y", 1.6, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(_hero_holder, "position:y", 1.35, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _show_break_message() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.08, 0.16, 0.0)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_layer.add_child(scrim)
	
	var fade := scrim.create_tween()
	fade.tween_property(scrim, "color:a", 0.55, 0.25)

	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(holder)

	var card := UiKit.card()
	card.custom_minimum_size = Vector2(760, 0)
	holder.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)

	var moon: Control = UiKit.picture("moon", 108)
	if moon != null:
		var moon_row := CenterContainer.new()
		moon_row.add_child(moon)
		column.add_child(moon_row)

	column.add_child(UiKit.title(I18n.t("limit.title"), UiKit.TYPE_TITLE))

	var body := UiKit.title(I18n.t("limit.body"), UiKit.TYPE_BODY, Palette.INK_SOFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(680, 0)
	column.add_child(body)

	var button_row := CenterContainer.new()
	var ok := UiKit.big_button(I18n.t("common.continue"), Palette.GREEN)
	ok.pressed.connect(func():
		scrim.queue_free()
		SceneManager.goto_world_map()
	)
	button_row.add_child(ok)
	column.add_child(button_row)
	UiKit.breathe(ok, 0.03, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			if not event.pressed:
				# Tapped on the diorama / hero
				_windmill_speed = 4.5
				if is_instance_valid(_hero_holder):
					_hero_answers("adventure")
					AudioManager.play_sfx("res://assets/audio/star.ogg")
	elif event is InputEventScreenTouch:
		_is_dragging = event.pressed
		if not event.pressed:
			_windmill_speed = 4.5
			if is_instance_valid(_hero_holder):
				_hero_answers("adventure")
				AudioManager.play_sfx("res://assets/audio/star.ogg")
	elif event is InputEventMouseMotion and _is_dragging:
		_target_yaw += event.relative.x * 0.005
	elif event is InputEventScreenDrag:
		_target_yaw += event.relative.x * 0.005

func _process(delta: float) -> void:
	# Continuous Windmill Rotation with tap surge & easing
	if is_instance_valid(_windmill_blades):
		_windmill_speed = lerpf(_windmill_speed, 1.0, delta * 1.6)
		_windmill_blades.rotate_object_local(Vector3(0, 0, 1), delta * 1.5 * _windmill_speed)

	# Parent Door Hold Update
	if _holding:
		_hold_time += delta
		if is_instance_valid(_parent_fill) and is_instance_valid(_parent_pill):
			_parent_fill.size.x = _parent_pill.size.x * clampf(_hold_time / PARENT_HOLD_SECONDS, 0.0, 1.0)
		if is_instance_valid(_parent_hint):
			var rem: int = maxi(int(ceil(PARENT_HOLD_SECONDS - _hold_time)), 1)
			_parent_hint.text = "🔒 家长中心 (%ds)" % rem
		if _hold_time >= PARENT_HOLD_SECONDS:
			_reset_hold()
			SceneManager.goto_scene("res://scenes/parent/ParentCenter.tscn")

	if _camera == null:
		return
	_time += delta
	
	if not _is_dragging:
		_target_yaw = lerp(_target_yaw, sin(_time * 0.5) * 0.04, delta * 2.0)
	_current_yaw = lerp(_current_yaw, _target_yaw, delta * 10.0)
	
	if _diorama != null:
		_diorama.rotation.y = _current_yaw

	# Project 3D landmarks to 2D screen positions
	for item in _labels:
		var btn: Button = item["btn"]
		var local_pos: Vector3 = item["pos_local"]
		var bob: float = sin(_time * 2.5 + item["phase"]) * 0.12
		var world_pos: Vector3 = _diorama.to_global(local_pos + Vector3(0, bob, 0)) if _diorama != null else local_pos
		
		var cam_to_obj := (world_pos - _camera.global_position).normalized()
		var forward := -_camera.global_transform.basis.z
		if cam_to_obj.dot(forward) <= 0.0:
			btn.visible = false
		else:
			btn.visible = true
			var screen_pos: Vector2 = _camera.unproject_position(world_pos)
			btn.position = screen_pos - btn.size * 0.5
