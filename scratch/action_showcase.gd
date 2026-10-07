extends Node2D

const OUT_DIR := "/Users/xhzhou/.gemini/antigravity/brain/2a762f9a-01f0-43fc-b355-5a304be9bd77"

const PuppyArt := preload("res://scripts/world/puppy_art.gd")
const MonsterClass := preload("res://scripts/battle/monster.gd")

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	# 1. Render Hero Combat Action Suite
	await _render_hero_combat_suite()
	# 2. Render Hero Emotes & Life Suite
	await _render_hero_emotes_suite()
	# 3. Render Puppy Actions Suite
	await _render_puppy_suite()
	# 4. Render Boss Battle Actions Suite
	await _render_boss_suite()

	print("ALL ACTION SHOWCASE SCREENSHOTS GENERATED SUCCESSFULLY!")
	get_tree().quit(0)


func _create_card_background(title: String, subtitle: String) -> Control:
	var root := Control.new()
	root.size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.12, 0.14, 0.20)
	root.add_child(bg)

	# Grid decoration lines
	for x in range(0, 1280, 80):
		var line := Line2D.new()
		line.points = [Vector2(x, 0), Vector2(x, 720)]
		line.width = 1.0
		line.default_color = Color(1, 1, 1, 0.04)
		root.add_child(line)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.position = Vector2(40, 28)
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	root.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.position = Vector2(40, 74)
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	root.add_child(sub_lbl)

	return root


func _save_screenshot(filename: String) -> void:
	RenderingServer.force_draw(false)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT_DIR, filename]
	var err := img.save_png(path)
	print("Saved action showcase: ", filename, " err=", error_string(err))


func _render_hero_combat_suite() -> void:
	var canvas := _create_card_background("小英雄战斗动作体系 (Hero Combat Actions)", "直拳连击 · 凌空飞踢 · 英雄砸地 · 能量格挡 · 龙卷终结")
	add_child(canvas)

	var actions = [
		{"pose": HeroArt.Pose.PUNCH, "name": "连击段1：直拳前冲", "x": 160.0, "fx": "punch"},
		{"pose": HeroArt.Pose.KICK, "name": "连击段2：强力侧踢", "x": 420.0, "fx": "kick"},
		{"pose": HeroArt.Pose.SLAM, "name": "高空重击：英雄砸地", "x": 680.0, "fx": "slam"},
		{"pose": HeroArt.Pose.BLOCK, "name": "守护姿态：护甲格挡", "x": 920.0, "fx": "block"},
		{"pose": HeroArt.Pose.DASH, "name": "风速俯冲：低空冲刺", "x": 1130.0, "fx": "dash"},
	]

	var skin := CharacterSkin.new()
	skin.id = "hero"

	for act in actions:
		var col_x: float = act["x"]
		var ground_y := 520.0

		var shadow := Shapes.ground_shadow(canvas, Vector2(col_x, ground_y), 90.0, 0.4)

		var hero := HeroArt.new(skin)
		hero.set_height(190.0)
		hero.position = Vector2(col_x, ground_y)
		canvas.add_child(hero)
		hero.set_pose(act["pose"], false)

		# Visual FX per action
		match act["fx"]:
			"punch":
				Juice.speed_lines(canvas, Vector2(col_x + 30, ground_y - 70), Vector2(1, 0), Color(1.0, 0.85, 0.4, 0.8), 4)
				Juice.impact_sparks(canvas, Vector2(col_x + 75, ground_y - 70), Color(1.0, 0.9, 0.4), 8)
			"kick":
				Juice.speed_lines(canvas, Vector2(col_x + 40, ground_y - 85), Vector2(1, 0), Color(1.0, 0.6, 0.3, 0.8), 4)
				Juice.shockwave(canvas, Vector2(col_x + 75, ground_y - 85), 50.0, Color(1.0, 0.8, 0.3))
			"slam":
				Juice.dust(canvas, Vector2(col_x, ground_y), 8, 1.2)
				Juice.shockwave(canvas, Vector2(col_x, ground_y), 95.0, Color(1.0, 0.85, 0.4))
			"block":
				var rim := Line2D.new()
				rim.points = Shapes.circle_points(Vector2(col_x, ground_y - 70), 65.0, 24)
				rim.closed = true
				rim.width = 4.0
				rim.default_color = Color(0.4, 0.85, 1.0, 0.8)
				canvas.add_child(rim)
			"dash":
				Juice.speed_lines(canvas, Vector2(col_x - 40, ground_y - 50), Vector2(1, 0), Color(0.7, 0.9, 1.0, 0.8), 5)

		var lbl := Label.new()
		lbl.text = act["name"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(180, 36)
		lbl.position = Vector2(col_x - 90, ground_y + 36)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		canvas.add_child(lbl)

	await get_tree().create_timer(0.25).timeout
	_save_screenshot("showcase_hero_combat_actions.png")
	remove_child(canvas)
	canvas.queue_free()
	await get_tree().process_frame


func _render_hero_emotes_suite() -> void:
	var canvas := _create_card_background("小英雄生动日常与待机动作 (Hero Emotes & Life)", "胜利V手势 · 强壮健美 · 热情招手 · 伸展懒腰 · 侦查眺望 · 欢乐掘地")
	add_child(canvas)

	var emotes = [
		{"pose": HeroArt.Pose.PEACE, "name": "胜利手势 (Peace)", "x": 130.0},
		{"pose": HeroArt.Pose.FLEX, "name": "超级强壮 (Flex)", "x": 340.0},
		{"pose": HeroArt.Pose.WAVE, "name": "友好招手 (Wave)", "x": 550.0},
		{"pose": HeroArt.Pose.STRETCH, "name": "惬意伸展 (Stretch)", "x": 750.0},
		{"pose": HeroArt.Pose.LOOK_AROUND, "name": "侦查眺望 (Scout)", "x": 950.0},
		{"pose": HeroArt.Pose.DIG, "name": "快乐掘地 (Dig)", "x": 1150.0},
	]

	var skin := CharacterSkin.new()
	skin.id = "hero"

	for emo in emotes:
		var col_x: float = emo["x"]
		var ground_y := 520.0

		var shadow := Shapes.ground_shadow(canvas, Vector2(col_x, ground_y), 85.0, 0.38)

		var hero := HeroArt.new(skin)
		hero.set_height(190.0)
		hero.position = Vector2(col_x, ground_y)
		canvas.add_child(hero)
		hero.set_pose(emo["pose"], false)

		var lbl := Label.new()
		lbl.text = emo["name"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(170, 36)
		lbl.position = Vector2(col_x - 85, ground_y + 36)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		canvas.add_child(lbl)

	await get_tree().create_timer(0.25).timeout
	_save_screenshot("showcase_hero_emotes.png")
	remove_child(canvas)
	canvas.queue_free()
	await get_tree().process_frame


func _render_puppy_suite() -> void:
	var canvas := _create_card_background("萌犬伴侣丰富动作体系 (Puppy Companion Actions)", "经典扑击 · 撒欢俯冲 · 欢呼跳跃 · 刨土探索 · 歪头好奇 · 警惕守护")
	add_child(canvas)

	var puppy_poses = [
		{"pose": HeroArt.Pose.STRETCH, "name": "经典嬉戏式 (Play Bow)", "x": 140.0},
		{"pose": HeroArt.Pose.PEACE, "name": "快乐举爪 (High Five)", "x": 360.0},
		{"pose": HeroArt.Pose.DIG, "name": "欢快刨土 (Digging)", "x": 580.0},
		{"pose": HeroArt.Pose.DASH, "name": "小狗冲刺 (Sprint)", "x": 790.0},
		{"pose": HeroArt.Pose.LOOK_AROUND, "name": "歪头好奇 (Curious)", "x": 980.0},
		{"pose": HeroArt.Pose.BLOCK, "name": "警惕守护 (Guard)", "x": 1160.0},
	]

	for pp in puppy_poses:
		var col_x: float = pp["x"]
		var ground_y := 520.0

		var shadow := Shapes.ground_shadow(canvas, Vector2(col_x, ground_y), 80.0, 0.35)

		var pup := PuppyArt.new()
		pup.set_height(160.0)
		pup.position = Vector2(col_x, ground_y)
		canvas.add_child(pup)
		pup.set_pose(pp["pose"], false)

		var lbl := Label.new()
		lbl.text = pp["name"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(170, 36)
		lbl.position = Vector2(col_x - 85, ground_y + 36)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
		canvas.add_child(lbl)

	await get_tree().create_timer(0.25).timeout
	_save_screenshot("showcase_puppy_actions.png")
	remove_child(canvas)
	canvas.queue_free()
	await get_tree().process_frame


func _render_boss_suite() -> void:
	var canvas := _create_card_background("怪兽与首领战斗招式库 (Boss Battle Animation Repertoire)", "震天怒吼前摇 · 迅猛爪击突进 · 大地践踏震波 · 眩晕星环破防")
	add_child(canvas)

	var monster_cases = [
		{"name": "蓄力怒吼 (Roar Telegraph)", "x": 180.0, "state": "roar"},
		{"name": "迅猛爪击 (Claw Swipe)", "x": 500.0, "state": "claw"},
		{"name": "重踏震波 (Ground Stomp)", "x": 800.0, "state": "stomp"},
		{"name": "眩晕破防 (Dizzy Stun)", "x": 1100.0, "state": "stun"},
	]

	for mc in monster_cases:
		var col_x: float = mc["x"]
		var ground_y := 530.0

		var shadow := Shapes.ground_shadow(canvas, Vector2(col_x, ground_y), 140.0, 0.45)

		var mon := MonsterClass.new()
		mon.position = Vector2(col_x, ground_y)
		mon.scale = Vector2(0.85, 0.85)
		canvas.add_child(mon)
		var mcfg: Dictionary = {
			"id": "boss_dragon",
			"height": 260,
			"horns": 2,
		}
		mon.build(mcfg)

		match mc["state"]:
			"roar":
				mon.roar(10.0)
				Juice.shockwave(canvas, Vector2(col_x - 50.0, ground_y - 110.0), 90.0, Color(1.0, 0.85, 0.35))
			"claw":
				mon.claw_swipe(10.0)
				Juice.speed_lines(canvas, Vector2(col_x - 40.0, ground_y - 100.0), Vector2(-1, 0), Color(1.0, 0.45, 0.25, 0.9), 4)
				Juice.impact_sparks(canvas, Vector2(col_x - 50.0, ground_y - 100.0), Color(1.0, 0.5, 0.2), 8)
			"stomp":
				mon.ground_stomp(10.0)
				Juice.dust(canvas, Vector2(col_x, ground_y), 8, 1.1)
				Juice.shockwave(canvas, Vector2(col_x, ground_y - 10.0), 110.0, Color(0.95, 0.75, 0.45))
			"stun":
				mon.dizzy_stun(10.0)

		var lbl := Label.new()
		lbl.text = mc["name"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(220, 36)
		lbl.position = Vector2(col_x - 110, ground_y + 42)
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
		canvas.add_child(lbl)

	await get_tree().create_timer(0.35).timeout
	_save_screenshot("showcase_boss_actions.png")
	remove_child(canvas)
	canvas.queue_free()
	await get_tree().process_frame
