extends LevelManager
## Duel template: a proper one-on-one, hero versus monster, with a skill
## wheel in the thumb corner the way the big arena games do it -- and every
## one of their sharp edges filed off for a six-year-old.
##
## Three skills, all pictures:
##   BEAM   the basic attack. Tap, beam fires, monster flinches, meter +1.
##          A short cooldown sweeps the button -- pacing, not pressure: the
##          game never moves on without you.
##   SHIELD a light bubble for a few seconds. An attack that hits the bubble
##          bounces straight back at the monster (meter +1) -- blocking is
##          an ATTACK here, which is what makes the duel feel clever.
##   ULT    the special move, chosen before the battle when the level offers
##          a choice. It charges from landed beams (the classic ult economy);
##          when the ring is full the button glows. Barrage rains six beams;
##          Burst sweeps the arena clear and stuns.
##
## The monster fights back -- lobbing goo, and in later duels roaring rings
## across the arena -- but the house rules hold absolutely: an unblocked hit
## wobbles the hero and briefly delays the beam button. Nothing is ever
## lost, there is no hero health bar, misses are not mistakes, and the duel
## ends the way every battle here ends: the monster tired, happy, waving.

## Reached by preload, never by class name: an unknown class name is a parse
## error on a machine whose editor has not rescanned, and that takes the whole
## game grey rather than one screen.
const Album := preload("res://scripts/reward/monster_album.gd")
const Fit := preload("res://scripts/shared/screen_fit.gd")
const Stroke := preload("res://scripts/shared/stroke_reader.gd")
## 招式册。模板不认识任何一招的名字 —— 它只会问册子。见 attack_book.gd。
const Book := preload("res://scripts/battle/attack_book.gd")
## 英雄的搓招册。和怪兽那本同一个形状 —— 模板不认识任何一招的名字。
const Moves := preload("res://scripts/battle/move_book.gd")

## Where the two of them stand, written against the 1280x720 the art was drawn
## at. Nothing reads these directly any more -- everything goes through
## _hero_pos and _monster_pos, which are the same two places on the screen the
## child is actually holding. On a 4:3 tablet that screen is 1280x960 and the
## ground line has moved down with it, so a hero left at a hard 620 stands in
## mid-air with a hundred and fifty pixels of daylight under his boots.
const GROUND_Y := 520.0
const HERO_POS := Vector2(270, 520)
const MONSTER_POS := Vector2(976, 520)
## How many unblocked hits the hero can take before the light bar empties.
const LIGHT_PIPS := 3

## How tall a boss stands on screen at "scale": 1.0, and the most it may ever
## be. The level's `scale` used to multiply the monster's own height directly,
## which was harmless while every monster in the game was 300 px tall and
## stopped being harmless the moment they each got their own size: the final
## boss is 370 and its level asks for 1.4, so it came out 660 px of creature
## on a 720 px screen with its head off the top and the health bar drawn
## across its face.
##
## So `scale` now means what a level author thinks it means -- how big this
## one is COMPARED TO the others -- and the pixels are worked out here.
## Deliberately low enough that only the LAST boss on the island touches the
## ceiling. At 300 the top three all clamped to the same pixel height, which
## quietly threw away the one thing the numbers were for: the final monster
## has to be the biggest thing he has ever seen.
const MONSTER_STAND := 245.0
## The tallest a boss may be drawn, horns and all. The health bar sits at
## y=84 and the ground at y=520, so anything past 375 is standing in the HUD (y < 140).
const MONSTER_CEILING := 375.0


func _fit_monster(tall: float, want: float) -> float:
	var target: float = minf(MONSTER_STAND * want, MONSTER_CEILING)
	return target / maxf(tall, 1.0)

const BEAM_ART := "res://assets/effects/energy_beam.png"
const HIT_ART := "res://assets/effects/hit_burst.png"
const SMOKE_ART := "res://assets/effects/smoke.png"
const RING_ART := "res://assets/effects/power_up.png"

var _beam_cooldown := 1.2
var _shield_cooldown := 6.0
var _shield_duration := 2.8
var _ult_needed := 6
var _goo_interval := 0.0
var _roar_interval := 0.0
var _ult_type := "barrage"

var _started := false
var _won := false
var _beam_ready_at := 0.0
var _used_ult := false
var _shield_ready_at := 0.0
var _shield_until := 0.0
var _ult_charge := 0
var _clock := 0.0
var _goo_timer := 0.0
var _roar_timer := 0.0

## HERO_POS and MONSTER_POS, put on the screen this child is holding. Filled in
## once, in _build_scene, before either of them is added to the tree.
var _hero_pos := HERO_POS
var _monster_pos := MONSTER_POS

var _play_area: Control
var _instruction: Label
var _hero: SkinnedCharacter
var _monster: Node2D
var _shield_bubble: Control
var _hp_fill: Control          # the monster's health, drawn as a draining bar
var _hp_face: Control
var _monster_id := ""
var _met_new_monster := false
var _skill_pad: Control       # the rounded plate the three of them sit on
var _beam_button: Control
var _shield_button: Control
var _ult_button: Control
## name -> {button, pie, radius, colour, ready}. One place holds the state of
## every skill, so "is this pressable right now" is asked and answered the same
## way for all three.
var _skills: Dictionary = {}
var _light_pips: Array[Control] = []
## Which skill currently wears the accent ring. "" until the wheel is built.
var _accent_on := ""
var _light_left := LIGHT_PIPS
## 这一关有几格光。LIGHT_PIPS 只是默认值了。
var _light_max := LIGHT_PIPS
## 一次飞几颗泥球。会玩的孩子拍一颗是反射，拍三颗是决定先拍哪一颗。
var _goo_volley := 1
var _threats: Array = []          # goo and roar nodes in flight

## --- holding the beam ---
var _charging := false
var _charge_started := 0.0
var _charge_ring: Line2D
## Charged enough to interrupt. Not 1.0: a finger lifts a frame early, and a
## child must never lose the whole thing to that.
const CHARGED_AT := 0.8

## --- 搓招 ---
##
## 三个按钮是保底路径，手势是进阶层。不搓也能打完整关，搓了快得多、好看得多 ——
## 和这个项目一贯的做法一致：点也能玩，按住更好，搓招最好。一个六岁孩子在学会
## 搓招之前不该被挡在门外，所以这里没有任何一件事是只有搓招才做得到的。
##
## 两招，都用菜园那套识别器（scripts/harvest/gesture.gd），因为战斗里的手感必须
## 和他每天拔萝卜是同一套：
##
##   ↑ 上划  升龙光拳  一下顶上去 = 一次打断 + 一次命中
##   → 前划  光波      推出去 = 一次命中 + 路上的泥球一起带走
##
## 两招都走同一个 _beam_ready_at，所以它们是光线的**替代**而不是白送的输出：
## 快在一个动作顶两个动作，不快在打得更多。
## 招式表从册子来，不再是这里的一份常量。
##
## 原来这是一个写死的数组，加第三招要改四处：数组、_perform 里的 match、
## 招式表卡片上手画的箭头、还有卡片的高度。5C 在怪兽那边治过同一个毛病，
## 英雄这边当时留了一半。现在也没了 —— 加一招是且只是往 moves/ 放一个文件。
static func gesture_table() -> Array:
	return Moves.gesture_table()

var _stroke                     # Stroke.new(MOVES)
var _move_card: Control         # the card of moves, so a missed stroke can point at it
var _stroke_far := 0.0          # how far the current stroke has got from where it began
var _stroke_from := Vector2.ZERO
## 一笔至少要离起点这么远才算"试着搓了一招"；比每一招要求的距离都短得多。
const STROKE_TRY := 30.0
var _stroke_field: Control
var _trail: Line2D

## --- 护甲与破绽 ---
##
## 让写好的弱点在战斗里成真.
##
## Every one of the fifteen monsters in monsters.json already carries a
## weakness_key, and every one of them names a real tactic -- "跳跃躲开后攻击
## 背部", "火焰熄灭时攻击", "使用护盾挡住震动". All fifteen were written,
## translated, and printed in the album as a sentence the FIGHT never kept:
## whatever the card said, the answer on screen was the same button forty-four
## times. That is the "太少、不够丰富" the playtester's father reported, and the
## design for fixing it has been sitting in the data the whole time.
##
## The mechanic, kept to ONE new idea rather than fifteen (the boss-design
## literature is unanimous that variety should come from re-parameterising an
## attack, not from bolting on new systems):
##
##   an armoured monster does not take damage from an ordinary beam. The shot
##   lands, it clinks, the monster is unbothered. What opens it is the thing
##   its card names -- dodging the wind-up, blocking it, or interrupting with a
##   full charge -- and for a few seconds after that it is wide open and every
##   hit counts double.
##
## So the loop stops being "press beam" and becomes "watch, answer, punish",
## and the album turns into a hint book: read the card, know the fight.
## `armor.opens_on` is a list, so one monster is opened by dodging and another
## only by blocking, from data, with no branch in here naming a monster.
const OPENING := 1.8
## What a hit is worth while the monster is wide open. The reward for reading
## it right has to be big enough to feel, or a child goes back to mashing.
const OPENING_BONUS := 2
## 每种答法值多少个窗口。见 _open_up。
const OPENING_SCALE := {"block": 1.25, "dodge": 1.0, "interrupt": 0.6}

var _armored := false
var _opens_on: Array = []
var _open_until := 0.0
var _guard_left := 0            # blocks still owed before it can be opened
var _weak_spot: Control
var _enraged := false

## --- 怪兽的招式表 ---
##
## 5B. 怪兽原来只有两招：扔泥球、吼一声，而且写死在两个计时器里。现在每一关
## 从数据带一张招式表（config.attacks），计时器到点从表里随机抽一招。新招一共
## 三个，每一个都对应一个**已有的**答法 —— 不引入新答法，是因为丰富度该来自
## "同样的三个答案，问法不一样"，而不是让孩子学第四个动作：
##
##   rush    冲撞，横穿场地      答法：躲（或万能的挡）
##   breath  吐息，一道持续的光  答法：挡（或躲开起手）
##   summon  召两只小怪          答法：拍 —— 拍的是源头，不是飞过来的东西
##
## 没配 attacks 的关卡得到那一招声明自己是基本招的，行为和 5B 之前逐帧
## 一致 —— 岛上那六场
## boss 战走的就是这条默认路，它们的时长基准线因此一个字都不用重画。
var _attacks: Array = []
## 发怒之后欠一记大的（硬直）。record 在 _check_phase，兑现在 _process ——
## 因为发怒可能发生在一次起手进行中，而两个预警叠在一起孩子一个都答不了。
var _heavy_owed := false
## 走第二条更慢计时器的那一招。角色由招式自己声明，数据可以盖掉。
var _heavy_kind := ""

## --- the wind-up ---
##
## The monster used to attack out of nowhere. The roar in particular could not
## be answered at all -- it is drawn with mouse_filter IGNORE, and the shield
## it needs rests 4.5 to 5.5 seconds while lasting 2.8, so across the last three
## duels roughly half the time there was nothing in the child's hands that
## could do anything about it.
##
## Now every attack is announced. The monster swells (puff_up, which was
## written for exactly this and never called for it), a warning ring rises, and
## for TELEGRAPH seconds there are three answers, none of which needs reading:
##
##   挡  press the shield -- it bounces back and scores, as it always did
##   躲  press the dodge mark that appears on the ground -- the hero rolls
##   打断 let go of a full charge -- the attack never happens
const TELEGRAPH := 0.9
## 发怒之后那记大的，窗口拉多宽。更疼的对价是更多的反应时间。
const HEAVY_SPAN := 1.7
var _telegraph_left := 0.0
var _telegraph_kind := ""
var _dodge_mark: Button
var _dodged := false


func setup_level() -> void:
	# Three doors, like every other template on the island, so the result
	# screen can say WHICH one is still shut rather than handing out a grade:
	#   1  the monster gave up            2  you used your special move
	#   3  you finished with every light
	result.objective_scoring = true
	var config: Dictionary = level_data.get("config", {})
	_beam_cooldown = float(config.get("beam_cooldown", 1.2))
	_shield_cooldown = float(config.get("shield_cooldown", 6.0))
	_ult_needed = int(config.get("ult_needed", 6))
	_goo_interval = float(config.get("goo_interval", 5.0))
	_roar_interval = float(config.get("roar_interval", 0.0))
	_ult_type = str(config.get("ult", "barrage"))
	# 每关自己的手感，不再是三个写死的常量。
	#
	# 难度以前只能变"程度"——同一场仗，数字大一点。这三个让它能变"种类"：
	# 一场只有两格光的仗要小心，一场护盾只撑 1.8 秒的仗要掐时机，一场一次
	# 飞三颗泥球的仗要一直动手。同样的三个答案，问法不一样。
	_light_max = clampi(int(config.get("lights", LIGHT_PIPS)), 1, 5)
	_light_left = _light_max
	_shield_duration = clampf(float(config.get("shield_duration", 2.8)), 1.0, 5.0)
	_goo_volley = clampi(int(config.get("goo_volley", 1)), 1, 3)
	var armor: Dictionary = config.get("armor", {})
	_armored = not armor.is_empty()
	_opens_on = armor.get("opens_on", ["dodge", "block", "interrupt"])
	_guard_left = int(armor.get("blocks_first", 0))
	# 招式表从数据来；数据没说，就问册子要那一招声明了自己是"基本招"的。
	# 模板里一个招式名字都不出现 —— 见 attack_book.role()。
	_attacks = config.get("attacks", [])
	if _attacks.is_empty():
		var basic := Book.role("basic")
		_attacks = [basic] if basic != "" else []
	# 第二条更慢的计时器那一路，同样按角色要，同样可以被数据盖掉。
	_heavy_kind = str(config.get("attack_heavy", Book.role("heavy")))

	# Difficulty: goo comes sooner, the beam rests longer, and the ult costs
	# more to charge -- the shield and the swat matter more at every step.
	_goo_interval = maxf(harder(_goo_interval, 0.82), 2.2)
	if _roar_interval > 0.0:
		_roar_interval = maxf(harder(_roar_interval, 0.85), 4.0)
	_beam_cooldown = clampf(harder(_beam_cooldown, 1.14), 0.6, 2.4)
	_ult_needed = maxi(harder_i(_ult_needed, 1), 3)

	# Challenge scaling: a busier opponent and a higher goal, never a faster
	# hand required of the child.
	var rank := challenge_rank()
	if rank > 0:
		if _goo_interval > 0.0:
			_goo_interval = maxf(_goo_interval - 0.25 * rank, 2.6)
		if _roar_interval > 0.0:
			_roar_interval = maxf(_roar_interval - 0.3 * rank, 5.0)
		bump_target("correct", mini(rank, 10))

	_goo_timer = _goo_interval
	_roar_timer = _roar_interval * 1.4
	_build_scene(config)

	var choices: Array = config.get("ult_choices", [])
	if choices.size() >= 2:
		_build_ult_picker(choices)
	else:
		_started = true


# --- construction -------------------------------------------------------

func _build_scene(config: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_play_area = Control.new()
	_play_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.theme = UiKit.theme()
	layer.add_child(_play_area)

	_build_3d_arena()

	# 搓招层，铺在最底下。所有按钮都在它之后 add_child，所以按钮照常吃自己的
	# 点击 —— 手势只接管"空地上划的那一笔"。
	_stroke = Stroke.new(Moves.gesture_table())
	_stroke_field = Control.new()
	_stroke_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stroke_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_stroke_field.gui_input.connect(_on_stroke_input)
	_play_area.add_child(_stroke_field)
	_trail = Line2D.new()
	_trail.width = 12.0
	_trail.default_color = Color(1.0, 0.93, 0.55, 0.75)
	_trail.antialiased = true
	_trail.z_index = 8
	_play_area.add_child(_trail)

	# The play area is in the tree now, so it can be asked how big the screen
	# really is. Everything placed after this line is placed on THAT screen.
	_hero_pos = Fit.at(_play_area, HERO_POS)
	_monster_pos = Fit.at(_play_area, MONSTER_POS)

	# Deep ambient contact shadow on the stone dais to eliminate cutout floating
	var monster_shadow := Shapes.ground_shadow(_play_area, _monster_pos, 280.0, 0.42)
	monster_shadow.name = "MonsterDaisShadow"

	_monster = preload("res://scripts/battle/monster.gd").new()
	_monster.position = _monster_pos
	_play_area.add_child(_monster)
	# From the album, so the monster he fights and the card he collects are one
	# drawing. Before this every duel passed only a scale, and all six bosses on
	# the island were the same purple creature at six different sizes.
	var monster_id := str(config.get("monster", {}).get("id", ""))
	_monster_id = monster_id
	var entry: Dictionary = Album.get_monster(monster_id)
	if monster_id != "" and not entry.is_empty():
		_monster.build(entry)
	else:
		entry = config.get("monster", {})
		_monster.build(entry)
	_monster.scale = Vector2.ONE * _fit_monster(
		float(entry.get("height", 300.0)),
		float(config.get("monster", {}).get("scale", 1.15)))

	var hero_shadow := Shapes.ground_shadow(_play_area, _hero_pos, 160.0, 0.40)
	hero_shadow.name = "HeroDaisShadow"

	_hero = SkinnedCharacter.new()
	_hero.skin = GameData.current_skin()
	_hero.position = _hero_pos
	_play_area.add_child(_hero)
	_hero.set_height(330.0)
	_hero.entrance(340.0, 0.15)

	var back := UiKit.back_button(func(): quit_level())
	back.position = Vector2(MARGIN, MARGIN)
	_play_area.add_child(back)

	_instruction = Label.new()
	_instruction.text = I18n.t(str(config.get("instruction_key", "duel.instruction")))
	_instruction.add_theme_font_size_override("font_size", 36)
	_instruction.add_theme_color_override("font_color", Palette.ON_COLOR)
	UiKit.on_art(_instruction)
	_instruction.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.16, 0.75))
	_instruction.add_theme_constant_override("outline_size", 8)
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Centred against the screen he is holding, and sitting on the same top
	# margin as the back button rather than 6 px above it.
	var band_w: float = 600.0
	_instruction.position = Vector2(
		(Fit.view(_play_area).x - band_w) * 0.5, MARGIN)
	_instruction.size = Vector2(band_w, 56)
	_instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(_instruction)

	_build_meter()
	_build_light_bar()
	_build_skill_wheel()
	_build_move_card()


# --- 一个节奏 ------------------------------------------------------------
#
# Every gap, inset and corner on this screen comes from these four numbers or
# a whole multiple of them. Written down once, referenced everywhere: numbers
# scattered through a layout do not stay aligned, and this screen had already
# collected three button sizes, two near-identical golds and four different
# vertical positions in the thumb corner alone.

## The rhythm. Every distance here is GAP or a multiple of it.
const GAP := 12.0
## The safe edge, shared by everything that touches one.
const MARGIN := 24.0
## Children's touch target, and the ONE size all three skills are drawn at.
## Well over the 60 px floor because this is the thing he presses forty times.
const SKILL := 108.0
## The one accent. Whatever is most worth pressing right now wears it, and
## nothing else on the screen is allowed to.
const ACCENT := Color(1.0, 0.84, 0.36)

const DESIGN_W := 1280.0
const DESIGN_H := 720.0

const HP_W := 560.0
const HP_H := 34.0
const HP_AT := Vector2(360.0, 84.0)


## The monster's health, as a bar that drains.
##
## It was a row of sparks that filled, one spark per hit, and the moment the
## final fight needed fifty-five hits that stopped working: twelve sparks over
## fifty-five hits means a spark every FIVE beams, so a child fires, watches
## the beam land, and sees nothing change. Four times in a row. His father
## reported it exactly that way -- "命中很多次，都没有星星".
##
## A bar has no such floor. Every single hit takes 1/55th off it, which is ten
## pixels of a 560 px bar, animated, next to a monster's face that is watching
## the bar go down. The rule underneath is the one this whole game runs on:
## every action a child takes has to visibly do something, immediately.
## A small round portrait of the monster being fought -- the same creature,
## built the same way, cropped to its head. Returns null if this level fights
## something the album has never heard of, so the caller can fall back.
func _monster_head(size: float) -> Control:
	var entry: Dictionary = Album.get_monster(_monster_id)
	if entry.is_empty():
		return null
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(size, size)
	frame.size = Vector2(size, size)
	frame.clip_contents = true
	var disc := Node2D.new()
	frame.add_child(disc)
	Shapes.fill(disc, Shapes.circle_points(Vector2(size * 0.5, size * 0.5),
		size * 0.5, 24), Color(0.06, 0.09, 0.18, 0.9), 0.0)
	var beast: Node2D = preload("res://scripts/battle/monster.gd").new()
	frame.add_child(beast)
	beast.build(entry)
	var tall: float = maxf(float(entry.get("height", 300.0)), 1.0)
	# The head is roughly the top half of the drawing, so fit THAT, not the
	# whole creature -- a whole monster shrunk into 52 px is a smudge.
	var fit: float = (size * 0.92) / (tall * 0.58)
	beast.scale = Vector2(fit, fit)
	beast.position = Vector2(size * 0.5, size * 0.5 + tall * 0.70 * fit)

	# clip_contents crops to a RECTANGLE, so the head came out as a square
	# stamp with the monster's shoulders showing in the corners. A thick ring
	# painted on top cuts a round window in it, in the same dark as the health
	# track behind, so the portrait and the bar read as one piece of HUD.
	#
	# It has to reach past the corner (0.707 x size) to cover it, which is the
	# whole reason the outer radius looks too big.
	# 3D Gold medallion rim around boss portrait
	var ring := Node2D.new()
	frame.add_child(ring)
	var mid := Vector2(size * 0.5, size * 0.5)
	Shapes.fill(ring, Shapes.circle_points(mid, size * 0.50, 30), Color(0.96, 0.78, 0.28, 0.35), 0.0)
	var band := PackedVector2Array()
	var outer := Shapes.circle_points(mid, size * 0.80, 28)
	var inner := Shapes.circle_points(mid, size * 0.44, 28)
	band.append_array(outer)
	band.append(outer[0])
	for i in range(inner.size() - 1, -1, -1):
		band.append(inner[i])
	band.append(inner[inner.size() - 1])
	Shapes.fill(ring, band, Color(0.06, 0.09, 0.18, 0.85), 0.0)
	return frame


var _arena_3d_cam: Camera3D
var _arena_3d_vp: SubViewport
var _arena_3d_world: Node3D
var _hero_3d_actor: Node3D
var _boss_3d_actor: Node3D

func _build_3d_arena() -> void:
	var vp_container := SubViewportContainer.new()
	vp_container.name = "Arena3DContainer"
	vp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(vp_container)

	_arena_3d_vp = SubViewport.new()
	_arena_3d_vp.name = "Arena3DViewport"
	_arena_3d_vp.own_world_3d = true
	_arena_3d_vp.transparent_bg = false
	_arena_3d_vp.handle_input_locally = false
	_arena_3d_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(_arena_3d_vp)

	var world_root := Node3D.new()
	world_root.name = "ArenaWorld"
	_arena_3d_vp.add_child(world_root)
	_arena_3d_world = world_root

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.54, 0.86)
	sky_mat.sky_horizon_color = Color(0.78, 0.86, 0.94)
	sky_mat.ground_bottom_color = Color(0.38, 0.35, 0.30)
	sky_mat.ground_horizon_color = Color(0.72, 0.68, 0.62)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	sun.rotation_degrees = Vector3(-36.0, 32.0, 0.0)
	world_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.55, 0.70, 0.90)
	fill.light_energy = 0.22
	fill.rotation_degrees = Vector3(25.0, -145.0, 0.0)
	world_root.add_child(fill)

	_arena_3d_cam = Camera3D.new()
	_arena_3d_cam.name = "ArenaCamera"
	_arena_3d_cam.position = Vector3(0.0, 3.8, 9.6)
	_arena_3d_cam.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	_arena_3d_cam.fov = 44.0
	world_root.add_child(_arena_3d_cam)

	var glb_path := "res://assets/scenes_3d/duel_arena.glb"
	if ResourceLoader.exists(glb_path):
		var arena_packed: PackedScene = load(glb_path)
		var arena_inst := arena_packed.instantiate()
		arena_inst.name = "DuelArenaMesh"
		world_root.add_child(arena_inst)

	# Keep dais uncluttered for illustrated hero & boss sprites,
	# while retaining 3D combat energy beams, crystal shields, and arena lighting.
	# _spawn_3d_combatants()


func _spawn_3d_combatants() -> void:
	if _arena_3d_world == null:
		return

	var hero_node := Node3D.new()
	hero_node.name = "Hero3DActor"
	hero_node.position = Vector3(-4.55, 0.72, 0.6)
	hero_node.rotation_degrees.y = 80.0

	var h_body := MeshInstance3D.new()
	var h_bm := CapsuleMesh.new()
	h_bm.radius = 0.38
	h_bm.height = 1.35
	h_body.mesh = h_bm
	h_body.position = Vector3(0.0, 0.85, 0.0)
	var h_bmat := StandardMaterial3D.new()
	h_bmat.albedo_color = Color(0.28, 0.58, 0.95)
	h_bmat.roughness = 0.35
	h_bmat.metallic = 0.5
	h_body.set_surface_override_material(0, h_bmat)
	hero_node.add_child(h_body)

	var h_head := MeshInstance3D.new()
	var h_hm := SphereMesh.new()
	h_hm.radius = 0.42
	h_hm.height = 0.84
	h_head.mesh = h_hm
	h_head.position = Vector3(0.0, 1.70, 0.0)
	var h_hmat := StandardMaterial3D.new()
	h_hmat.albedo_color = Color(0.98, 0.88, 0.38)
	h_hmat.roughness = 0.3
	h_hmat.metallic = 0.6
	h_head.set_surface_override_material(0, h_hmat)
	hero_node.add_child(h_head)

	var h_cape := MeshInstance3D.new()
	var h_cm := BoxMesh.new()
	h_cm.size = Vector3(0.65, 1.05, 0.1)
	h_cape.mesh = h_cm
	h_cape.position = Vector3(-0.1, 1.0, -0.32)
	h_cape.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	var h_cmat := StandardMaterial3D.new()
	h_cmat.albedo_color = Color(0.92, 0.30, 0.28)
	h_cape.set_surface_override_material(0, h_cmat)
	hero_node.add_child(h_cape)

	var h_core := MeshInstance3D.new()
	var h_crm := SphereMesh.new()
	h_crm.radius = 0.15
	h_crm.height = 0.30
	h_core.mesh = h_crm
	h_core.position = Vector3(0.0, 1.0, 0.36)
	var h_crmat := StandardMaterial3D.new()
	h_crmat.albedo_color = Color(0.4, 0.9, 1.0)
	h_crmat.emission_enabled = true
	h_crmat.emission = Color(0.4, 0.9, 1.0)
	h_crmat.emission_energy_multiplier = 3.5
	h_core.set_surface_override_material(0, h_crmat)
	hero_node.add_child(h_core)

	_arena_3d_world.add_child(hero_node)
	_hero_3d_actor = hero_node

	var boss_node := Node3D.new()
	boss_node.name = "Boss3DActor"
	boss_node.position = Vector3(4.15, 0.72, 0.6)
	boss_node.rotation_degrees.y = -80.0

	var b_scale := 1.45
	var b_body := MeshInstance3D.new()
	var b_bm := CapsuleMesh.new()
	b_bm.radius = 0.55 * b_scale
	b_bm.height = 1.65 * b_scale
	b_body.mesh = b_bm
	b_body.position = Vector3(0.0, 1.15 * b_scale, 0.0)
	var b_bmat := StandardMaterial3D.new()
	b_bmat.albedo_color = Color(0.35, 0.22, 0.32)
	b_bmat.roughness = 0.65
	b_body.set_surface_override_material(0, b_bmat)
	boss_node.add_child(b_body)

	for hx in [-0.45 * b_scale, 0.45 * b_scale]:
		var horn := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.02
		hm.bottom_radius = 0.15 * b_scale
		hm.height = 0.65 * b_scale
		horn.mesh = hm
		horn.position = Vector3(hx, 2.3 * b_scale, 0.1)
		horn.rotation_degrees = Vector3(15.0, 0.0, -25.0 if hx < 0 else 25.0)
		var hrmat := StandardMaterial3D.new()
		hrmat.albedo_color = Color(0.92, 0.45, 0.25)
		hrmat.roughness = 0.4
		horn.set_surface_override_material(0, hrmat)
		boss_node.add_child(horn)

	for ex in [-0.22 * b_scale, 0.22 * b_scale]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.10 * b_scale
		em.height = 0.20 * b_scale
		eye.mesh = em
		eye.position = Vector3(ex, 1.85 * b_scale, 0.52 * b_scale)
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(1.0, 0.28, 0.18)
		emat.emission_enabled = true
		emat.emission = Color(1.0, 0.28, 0.18)
		emat.emission_energy_multiplier = 4.0
		eye.set_surface_override_material(0, emat)
		boss_node.add_child(eye)

	_arena_3d_world.add_child(boss_node)
	_boss_3d_actor = boss_node


func _fire_3d_beam(fat: float = 1.0) -> void:
	if _arena_3d_world == null:
		return
	var beam_root := Node3D.new()
	var from_p := Vector3(-4.55, 1.45, 0.6)
	var to_p := Vector3(4.15, 1.65, 0.6)
	var diff := to_p - from_p
	var dist := diff.length()
	beam_root.position = (from_p + to_p) * 0.5

	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16 * fat
	cm.bottom_radius = 0.16 * fat
	cm.height = dist
	cyl.mesh = cm
	cyl.rotation_degrees.z = 90.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.65)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.88, 0.35)
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.95
	cyl.set_surface_override_material(0, mat)
	beam_root.add_child(cyl)
	_arena_3d_world.add_child(beam_root)

	var flash := OmniLight3D.new()
	flash.position = to_p
	flash.light_color = Color(1.0, 0.85, 0.45)
	flash.light_energy = 4.5 * fat
	flash.omni_range = 6.0
	_arena_3d_world.add_child(flash)

	if _boss_3d_actor != null and is_instance_valid(_boss_3d_actor):
		var btw := _boss_3d_actor.create_tween()
		btw.tween_property(_boss_3d_actor, "position:x", 4.15 + 0.35, 0.08)
		btw.tween_property(_boss_3d_actor, "position:x", 4.15, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var tw := beam_root.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22 if Juice.motion_enabled() else 0.06)
	tw.tween_callback(beam_root.queue_free)

	var ftw := flash.create_tween()
	ftw.tween_property(flash, "light_energy", 0.0, 0.24)
	ftw.tween_callback(flash.queue_free)


func _raise_3d_shield(duration: float) -> void:
	if _arena_3d_world == null:
		return
	var shield := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.15
	sm.height = 2.30
	sm.is_hemisphere = true
	shield.mesh = sm
	shield.position = Vector3(-4.55, 0.72, 0.6)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.35, 0.85, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.85, 1.0)
	mat.emission_energy_multiplier = 2.2
	shield.set_surface_override_material(0, mat)
	_arena_3d_world.add_child(shield)

	var tw := shield.create_tween()
	tw.tween_property(shield, "scale", Vector3(1.12, 1.12, 1.12), 0.15)
	tw.tween_interval(duration)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(shield.queue_free)


func _build_meter() -> void:
	var holder := Control.new()
	# Centred, and one GAP below the instruction instead of two pixels into it.
	holder.position = Vector2((Fit.view(_play_area).x - HP_W) * 0.5,
		MARGIN + 56.0 + GAP)
	holder.size = Vector2(HP_W, HP_H)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(holder)

	_hp_face = _monster_head(54.0)
	if _hp_face == null:
		_hp_face = UiKit.picture("monster", 54.0)
	if _hp_face != null:
		_hp_face.position = Vector2(-60, -11)
		_hp_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(_hp_face)

	# 3D Ornate Boss HP Frame
	var bg_frame := Node2D.new()
	holder.add_child(bg_frame)
	# Drop shadow
	Shapes.fill(bg_frame, Shapes.rounded_rect(Vector2(-6, -2),
		Vector2(HP_W + 12.0, HP_H + 12.0), (HP_H + 12.0) * 0.5),
		Color(0.0, 0.04, 0.12, 0.40), 0.0)
	# Outer 3D Bronze/Gold Rim
	Shapes.fill(bg_frame, Shapes.rounded_rect(Vector2(-6, -6),
		Vector2(HP_W + 12.0, HP_H + 12.0), (HP_H + 12.0) * 0.5),
		Color(0.82, 0.66, 0.28), 0.0)
	# Top golden highlight edge
	Shapes.fill(bg_frame, Shapes.rounded_rect(Vector2(-4, -5),
		Vector2(HP_W + 8.0, 4.0), 2.0),
		Color(1.0, 0.88, 0.45, 0.8), 0.0)
	# Recessed dark well
	Shapes.fill(bg_frame, Shapes.rounded_rect(Vector2(-2, -2),
		Vector2(HP_W + 4.0, HP_H + 4.0), (HP_H + 4.0) * 0.5),
		Color(0.08, 0.10, 0.18, 0.95), 0.0)

	_hp_fill = Control.new()
	_hp_fill.position = Vector2.ZERO
	_hp_fill.size = Vector2(HP_W, HP_H)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.clip_contents = true
	holder.add_child(_hp_fill)
	var paint := Node2D.new()
	_hp_fill.add_child(paint)
	# 3D Ruby/Amber health bar
	Shapes.fill(paint, Shapes.rounded_rect(Vector2.ZERO, Vector2(HP_W, HP_H),
		HP_H * 0.5), Color(0.96, 0.42, 0.32), 0.0)
	# Top specular gloss streak
	Shapes.fill(paint, Shapes.rounded_rect(Vector2(12, 3),
		Vector2(HP_W - 24.0, HP_H * 0.36), HP_H * 0.18),
		Color(1.0, 0.90, 0.80, 0.65), 0.0)
	# Bottom rich shade
	Shapes.fill(paint, Shapes.rounded_rect(Vector2(12, HP_H * 0.62),
		Vector2(HP_W - 24.0, HP_H * 0.28), HP_H * 0.14),
		Color(0.72, 0.18, 0.15, 0.55), 0.0)


## Called after every landed hit. `clip_contents` on the fill means shrinking
## its width slides the drawing out of view from the right, so the bar empties
## the way a bar should rather than squashing its own rounded end.
func _update_meter() -> void:
	if not is_instance_valid(_hp_fill):
		return
	var need: int = maxi(target_value("correct", 8), 1)
	var left: float = clampf(1.0 - float(result.correct) / float(need), 0.0, 1.0)
	var want := Vector2(HP_W * left, HP_H)
	if not Juice.motion_enabled():
		_hp_fill.size = want
		return
	# Animated, because the movement IS the feedback. Short enough that a
	# second hit landing on top of it just retargets.
	var t := _hp_fill.create_tween()
	t.tween_property(_hp_fill, "size", want, 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_hp_face):
		Juice.pop(_hp_face, 0.18)


## The thumb corner: ult, shield, beam -- beam biggest and rightmost, exactly
## where a landscape tablet's right thumb already rests.
##
## Three things were wrong with the first version and all three are fixed here:
## the buttons sat on top of the monster with nothing to separate UI from
## world; a tap that landed produced almost no visible reaction; and a tap that
## was refused because the skill was cooling produced *none at all*, so a child
## could not tell a dead button from a broken game. Every tap now answers.
## The corner is measured from the corner, not from 1280x720. These four are
## the only things on this screen that do NOT scale with it: a thumb rests
## where the bezel is, so the pad keeps its gap to the right and bottom edges
## whatever shape the tablet turns out to be. Left as design numbers they sat
## in the middle of an iPad with the child's thumb under empty grass.
func _build_skill_wheel() -> void:
	# One capsule holding three, rather than three discs scattered near each
	# other. Related controls that live in one container read as one control
	# with three parts, and the container is what makes the thumb corner look
	# deliberate instead of occupied.
	#
	# Everything below is derived from GAP and SKILL. Nothing here is a number
	# somebody typed while looking at a mock-up, which is what produced the
	# three sizes and three border colours this replaced: 124/108/100 px with
	# gold, blue and a SECOND, slightly different gold. Three accents is no
	# accent, and two golds a shade apart read as a mistake rather than a rank.
	var inner := GAP * 2.0
	var pad_size := Vector2(SKILL * 3.0 + GAP * 2.0 + inner * 2.0, SKILL + inner * 2.0)
	_skill_pad = Panel.new()
	var pad := _skill_pad
	pad.position = Fit.corner(_play_area,
		Vector2(DESIGN_W - MARGIN - pad_size.x, DESIGN_H - MARGIN - pad_size.y))
	pad.size = pad_size
	var pad_style := StyleBoxFlat.new()
	pad_style.bg_color = Color(0.06, 0.10, 0.22, 0.65)
	pad_style.set_corner_radius_all(int(pad_size.y * 0.5))
	pad_style.border_width_top = 2
	pad_style.border_width_left = 1
	pad_style.border_width_right = 1
	pad_style.border_width_bottom = 1
	pad_style.border_color = Color(0.42, 0.58, 0.82, 0.45)
	pad_style.shadow_color = Color(0.0, 0.03, 0.10, 0.50)
	pad_style.shadow_size = 14
	pad_style.shadow_offset = Vector2(0, 6)
	pad.add_theme_stylebox_override("panel", pad_style)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(pad)

	# Left to right: ult, shield, beam. Beam stays rightmost and therefore
	# closest to where a landscape thumb already rests -- that was right the
	# first time, and it is the only thing about the old arrangement that was.
	var row_y: float = pad.position.y + inner
	var slot_x: float = pad.position.x + inner
	_ult_button = _skill_button("ult", Vector2(slot_x, row_y), SKILL, "star")
	_ult_button.gui_input.connect(_on_ult_input)

	slot_x += SKILL + GAP
	_shield_button = _skill_button("shield", Vector2(slot_x, row_y), SKILL, "shield")
	_shield_button.gui_input.connect(_on_shield_input)

	slot_x += SKILL + GAP
	_beam_button = _skill_button("beam", Vector2(slot_x, row_y), SKILL, "spark")
	_beam_button.gui_input.connect(_on_beam_input)
	_refresh_accent()

	_set_skill_ready("ult", false)
	_set_skill_ready("shield", true)
	_set_skill_ready("beam", true)


## One skill, drawn the same as the other two.
##
## No colour argument any more. Every button is the same dark disc with the
## same soft drop shadow, and exactly one of them wears the accent ring at a
## time -- see _refresh_accent. Shadow OR border, never both: the old version
## had a 6-7 px coloured border AND a shadow on all three, which is the
## double-edge that makes a control look pasted on.
func _skill_button(key: String, at: Vector2, size: float,
		icon_name: String) -> Control:
	var button := Panel.new()
	button.size = Vector2(size, size)
	button.position = at
	button.pivot_offset = button.size / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.35, 0.96)
	style.set_corner_radius_all(int(size / 2.0))
	style.border_width_top = 4
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_bottom = 6
	style.border_color = Color(0.32, 0.46, 0.74, 0.85)
	style.shadow_color = Color(0.0, 0.04, 0.14, 0.55)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	button.add_theme_stylebox_override("panel", style)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	# Top gloss reflection highlight
	var gloss := Node2D.new()
	button.add_child(gloss)
	Shapes.fill(gloss, Shapes.rounded_rect(Vector2(size * 0.18, size * 0.08),
		Vector2(size * 0.64, size * 0.28), size * 0.14),
		Color(1.0, 1.0, 1.0, 0.22), 0.0)

	var icon: Control = UiKit.picture(icon_name, size * 0.62)
	if icon != null:
		icon.position = Vector2(size * 0.19, size * 0.19)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)

	# The cooldown wedge, drawn rather than a nine-patch texture: a dark pie
	# that sweeps away as the skill comes back. A child reads "the dark is
	# shrinking, it is nearly ready" without being told.
	var pie := Polygon2D.new()
	pie.color = Color(0.02, 0.05, 0.12, 0.62)
	pie.position = Vector2(size / 2.0, size / 2.0)
	pie.antialiased = true
	button.add_child(pie)

	# The accent ring, built for every button but shown on only one. Kept as a
	# node rather than a border on the style so that moving the accent is one
	# property change instead of rebuilding three stylebox objects every frame.
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2(size * 0.5, size * 0.5),
		size * 0.5 - 2.0, 32)
	ring.closed = true
	ring.width = 6.0
	ring.default_color = ACCENT
	ring.antialiased = true
	ring.visible = false
	button.add_child(ring)

	_play_area.add_child(button)
	_skills[key] = {
		"button": button, "pie": pie, "radius": size * 0.5, "colour": ACCENT,
		"ready": true, "ring": ring,
	}
	return button


## Exactly one accent on the screen, on the thing most worth pressing now.
##
## The rule is a ladder, not a mood: a full special move outranks everything,
## otherwise the beam. The other two are still perfectly pressable -- they are
## simply not shouting, which is what lets the one that IS shouting mean
## something. A child who cannot read has to be able to find "the button" in
## the half second before he gives up and presses whatever is biggest.
func _refresh_accent() -> void:
	var want: String = "ult" if ult_ready() else "beam"
	if want == _accent_on:
		return
	_accent_on = want
	for key in _skills.keys():
		var skill: Dictionary = _skills[key]
		var ring = skill.get("ring")
		if ring != null and is_instance_valid(ring):
			ring.visible = key == want


## The dark wedge over a cooling skill. `fraction` is how much is left.
func _set_skill_cooldown(key: String, fraction: float) -> void:
	var skill: Dictionary = _skills.get(key, {})
	if skill.is_empty():
		return
	var pie: Polygon2D = skill["pie"]
	if not is_instance_valid(pie):
		return
	var left: float = clampf(fraction, 0.0, 1.0)
	if left <= 0.001:
		pie.polygon = PackedVector2Array()
		return
	var radius: float = float(skill["radius"])
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := maxi(int(28.0 * left), 2)
	for i in range(steps + 1):
		var a: float = -PI * 0.5 + TAU * left * float(i) / float(steps)
		points.append(Vector2(cos(a), sin(a)) * radius)
	pie.polygon = points


## The charge, drawn as an arc closing around the beam button.
##
## A separate ring rather than the cooldown wedge, because they mean opposite
## things and sharing one shape would make "filling up" and "running out" look
## identical. It grows clockwise from the top and turns white at CHARGED_AT --
## the colour change is the "now it will interrupt" signal, and it is a
## SECOND channel on top of the size, so it survives being colour-blind.
func _tick_charge() -> void:
	if not _charging:
		return
	var skill: Dictionary = _skills.get("beam", {})
	if skill.is_empty() or not is_instance_valid(skill["button"] as Control):
		return
	var button: Control = skill["button"]
	var k: float = charge_fraction()
	if _charge_ring == null or not is_instance_valid(_charge_ring):
		_charge_ring = Line2D.new()
		_charge_ring.width = 11.0
		_charge_ring.antialiased = true
		_charge_ring.z_index = 4
		_charge_ring.position = button.position + button.size / 2.0
		_play_area.add_child(_charge_ring)
	var radius: float = float(skill["radius"]) + 12.0
	var points := PackedVector2Array()
	var steps: int = maxi(int(30.0 * k), 2)
	for i in range(steps + 1):
		var a: float = -PI * 0.5 + TAU * k * float(i) / float(steps)
		points.append(Vector2(cos(a), sin(a)) * radius)
	_charge_ring.points = points
	_charge_ring.default_color = Color(1.0, 0.99, 0.92) if k >= CHARGED_AT \
		else Color(1.0, 0.86, 0.40)
	# The hero says it too, on his own body, for the child who is looking at
	# the fight rather than at his thumb.
	if k >= CHARGED_AT and _hero != null and is_instance_valid(_hero):
		_hero.set_core_color(Color(1.0, 0.99, 0.92))


func _clear_charge_ring() -> void:
	if _charge_ring != null and is_instance_valid(_charge_ring):
		_charge_ring.queue_free()
	_charge_ring = null
	if _hero != null and is_instance_valid(_hero) and _hero.skin != null:
		_hero.set_core_color(_hero.skin.core_color)


## Ready or not, said in brightness rather than only in a wedge -- brightness
## is the part a six-year-old reads from across the table.
func _set_skill_ready(key: String, ready: bool) -> void:
	var skill: Dictionary = _skills.get(key, {})
	if skill.is_empty() or bool(skill["ready"]) == ready:
		return
	skill["ready"] = ready
	var button: Control = skill["button"]
	if not is_instance_valid(button):
		return
	button.modulate = Color(1, 1, 1, 1) if ready else Color(0.62, 0.66, 0.76, 0.85)
	if ready:
		# Coming back online is worth a small celebration: it is an invitation
		# to press again.
		Juice.pop(button, 0.14)
		_flash_ring(key)


## A ring that expands and fades off a button. This is the "yes, that landed"
## signal -- the single thing most missing from the first version.
func _flash_ring(key: String) -> void:
	var skill: Dictionary = _skills.get(key, {})
	if skill.is_empty() or not Juice.motion_enabled():
		return
	var button: Control = skill["button"]
	if not is_instance_valid(button):
		return
	var radius: float = float(skill["radius"])
	var holder := Node2D.new()
	holder.position = button.position + button.size / 2.0
	holder.z_index = 3
	_play_area.add_child(holder)
	var line := Line2D.new()
	line.points = Shapes.circle_points(Vector2.ZERO, radius, 28)
	line.closed = true
	line.width = 8.0
	line.default_color = skill["colour"]
	line.antialiased = true
	holder.add_child(line)
	var t := create_tween().set_parallel(true)
	t.tween_property(holder, "scale", Vector2(2.1, 2.1), 0.38)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(holder, "modulate:a", 0.0, 0.38)
	t.chain().tween_callback(holder.queue_free)


## A refused tap. Small, quiet and immediate: the button rocks and dims for a
## beat. Never a buzz or a red flash -- the rule everywhere else in the game.
##
## Two things were wrong with the old version. `Juice.nudge` returns without
## doing anything when "reduce motion" is on, so on that setting a refused
## press was a sound and nothing else -- and the sound is the part a child in a
## noisy room does not get either. And 7 px is below what anyone sees; the
## helper's own default is 14.
##
## So: the button dims for a beat whether or not motion is allowed, and the
## hero's chest light answers too. Something on screen changes, always.
func _refuse(key: String) -> void:
	var skill: Dictionary = _skills.get(key, {})
	if skill.is_empty():
		return
	var button: Control = skill["button"]
	if not is_instance_valid(button):
		return
	Juice.nudge(button, 14.0)
	if _hero != null and is_instance_valid(_hero):
		_hero.pulse_core(1)
	var was: Color = button.modulate
	button.modulate = Color(0.55, 0.58, 0.66, 0.9)
	var back := get_tree().create_timer(0.16)
	back.timeout.connect(func():
		if is_instance_valid(button):
			button.modulate = was)
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")


## The hero's light. Three pips: every hit that gets through costs one and
## counts as a mistake, which is what makes shielding matter -- before this the
## monster's attacks had no consequence at all and the duel had no stakes.
##
## It cannot run out in a way that ends the game. Emptying it makes the hero
## stumble, then the light comes back on its own. There is no losing here; the
## cost of being hit is stars, and stars never go below one.
func _build_light_bar() -> void:
	var row := HBoxContainer.new()
	# Beside the back button, on the same rhythm and centred against its height
	# rather than floating ten pixels above its middle.
	row.position = Vector2(MARGIN + 112.0 + GAP, MARGIN + (96.0 - 46.0) * 0.5)
	row.add_theme_constant_override("separation", int(GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(row)
	for i in range(_light_max):
		var pip := Control.new()
		pip.custom_minimum_size = Vector2(46, 46)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glow := Shapes.glow(pip, Vector2(23, 23), 42.0, Color(0.45, 0.92, 1.0), 4, 0.5)
		glow.name = "Glow"
		Shapes.lit(pip, Shapes.circle_points(Vector2(23, 23), 16.0, 20),
			Color(0.45, 0.92, 1.0), 1.0)
		row.add_child(pip)
		_light_pips.append(pip)


func _refresh_light_bar() -> void:
	for i in range(_light_pips.size()):
		var pip: Control = _light_pips[i]
		if not is_instance_valid(pip):
			continue
		var lit: bool = i < _light_left
		pip.modulate = Color(1, 1, 1, 1) if lit else Color(0.35, 0.40, 0.52, 0.55)


## A hit got through. Costs a pip and a star's worth of accuracy; never the
## level.
func _lose_light() -> void:
	if _won:
		return
	score_mistake()
	_light_left = maxi(_light_left - 1, 0)
	_refresh_light_bar()
	_hero.stumble()
	if _light_left > 0:
		return
	_out_of_light()


## The light bar is empty, so the duel STOPS. It used to quietly refill
## itself after a beat, which meant a child could stand there taking hits
## forever and the bar meant nothing -- exactly what his father reported.
##
## Now: everything pauses, and he chooses. Spend a Heart Potion from the
## Star Shop and fight on with a full bar, or finish here and take the
## level's reward. Finishing is a real ending, not a loss: the result is
## reported the normal way and still earns its star.
func _out_of_light() -> void:
	if _won or _finished:
		return
	_hero.stumble()
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	get_tree().paused = true
	UiKit.light_out_card(_play_area, SaveManager.item_count("heart_potion"),
		func():
			get_tree().paused = false
			if not SaveManager.use_item("heart_potion"):
				return
			_light_left = _light_max
			_refresh_light_bar()
			_hero.power_up()
			Juice.burst(_play_area, _hero.position + Vector2(0, -160.0), 18)
			AudioManager.play_sfx("res://assets/audio/power_up.ogg"),
		func():
			get_tree().paused = false
			complete_level())


## Pre-battle choice of special move -- two big picture cards, no timer.
func _build_ult_picker(choices: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.12, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_area.add_child(dim)

	var title := UiKit.title_on_art(I18n.t("duel.pick_ult"), 46)
	title.position = Vector2(340, 140)
	title.size = Vector2(600, 60)
	dim.add_child(title)

	var icons := {"barrage": "star", "burst": "lightning"}
	var offsets := [Vector2(400, 250), Vector2(710, 250)]
	for i in range(2):
		var kind := str(choices[i])
		var card := Panel.new()
		card.size = Vector2(190, 220)
		card.position = offsets[i]
		card.pivot_offset = card.size / 2.0
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.PURPLE
		style.set_corner_radius_all(22)
		style.border_width_bottom = 8
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_color = Palette.edge(Palette.PURPLE)
		style.shadow_color = Color(0.0, 0.05, 0.15, 0.28)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 6)
		card.add_theme_stylebox_override("panel", style)
		var icon: Control = UiKit.picture(str(icons.get(kind, "star")), 110)
		if icon != null:
			icon.position = Vector2(40, 26)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(icon)
		# Whole literal keys inside I18n.t calls, so tools_check can verify
		# both statically.
		var ult_name := I18n.t("duel.ult_burst") if kind == "burst" else I18n.t("duel.ult_barrage")
		var name_label := UiKit.title(ult_name, 26, Palette.ON_COLOR)
		name_label.position = Vector2(0, 160)
		name_label.size = Vector2(190, 40)
		card.add_child(name_label)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event: InputEvent):
			if UiKit.is_press(event) and not _started:
				_ult_type = kind
				_started = true
				Juice.pop(card, 0.2)
				AudioManager.play_sfx("res://assets/audio/correct.ogg")
				dim.queue_free()
		)
		dim.add_child(card)
		UiKit.breathe(card, 0.03, 1.0 + 0.15 * float(i))


# --- loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_clock += delta
	var beam_left: float = clampf((_beam_ready_at - _clock) / _beam_cooldown, 0.0, 1.0)
	var shield_left: float = clampf((_shield_ready_at - _clock) / _shield_cooldown, 0.0, 1.0)
	_set_skill_cooldown("beam", beam_left)
	_set_skill_cooldown("shield", shield_left)
	_set_skill_ready("beam", beam_left <= 0.0)
	_set_skill_ready("shield", shield_left <= 0.0)
	_set_skill_cooldown("ult", 1.0 - float(_ult_charge) / float(maxi(_ult_needed, 1)))
	_set_skill_ready("ult", ult_ready())
	_refresh_accent()
	if _shield_bubble != null and is_instance_valid(_shield_bubble) and _clock > _shield_until:
		_shield_bubble.queue_free()
		_shield_bubble = null

	if not _started or _won:
		return
	_tick_charge()
	if _weak_spot != null and not wide_open():
		_clear_weak_spot()
		if not _won:
			_instruction.text = I18n.t("duel.instruction")

	# The wind-up runs its own clock. Nothing else is scheduled while it does:
	# two attacks announced at once is two warnings a six-year-old has to tell
	# apart, and he will answer neither.
	if _telegraph_left > 0.0:
		_telegraph_left -= delta
		if _telegraph_left <= 0.0:
			_fire_telegraphed()
		return

	# 欠着的硬直先还：发怒那一刻如果正有一次起手在跑，两个预警会叠在一起，
	# 所以那里只记账，这里兑现。
	if _heavy_owed and _telegraph_left <= 0.0:
		_heavy_owed = false
		_begin_telegraph(str(_attacks[0]), TELEGRAPH * HEAVY_SPAN)
		return

	if _goo_interval > 0.0:
		_goo_timer -= delta
		if _goo_timer <= 0.0:
			_goo_timer = _goo_interval * randf_range(0.85, 1.3)
			_begin_telegraph(_pick_attack())
			return
	if _roar_interval > 0.0:
		_roar_timer -= delta
		if _roar_timer <= 0.0:
			_roar_timer = _roar_interval * randf_range(0.9, 1.3)
			if _heavy_kind != "":
				_begin_telegraph(_heavy_kind)


## 招式表：卡片上画的就是手指要走的路。
##
## 六岁不识字，这张卡是他唯一的说明书 —— 所以它不能是文字，也不该是谁手画上去
## 的示意箭头。每一行的那一笔直接来自招式自己的 card_stroke()，也就是识别器
## 认的那个形状本身。加一招，卡片自己长出一行；改一招的手势，卡片跟着变。
##
## 贴在左边中间，离拇指区远：它是拿来看的不是拿来按的。mouse_filter 是 IGNORE，
## 所以它永远不会把一笔画吃掉 —— 一张挡住输入的说明书是最坏的一种说明书。
func _build_move_card() -> void:
	var moves: Array = Moves.ids()
	if moves.is_empty():
		return
	var row_h := 88.0
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(MARGIN, MARGIN + 72.0 + GAP)
	card.size = Vector2(82, row_h * float(moves.size()) + 16.0)
	_play_area.add_child(card)
	_move_card = card

	var plate := Panel.new()
	plate.size = card.size
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.12, 0.22, 0.60)
	p_style.set_corner_radius_all(22)
	p_style.border_width_top = 1
	p_style.border_width_left = 1
	p_style.border_width_right = 1
	p_style.border_width_bottom = 1
	p_style.border_color = Color(0.40, 0.55, 0.78, 0.40)
	plate.add_theme_stylebox_override("panel", p_style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(plate)

	for i in range(moves.size()):
		var move = Moves.get_move(str(moves[i]))
		if move == null:
			continue
		var mid := Vector2(card.size.x * 0.5, 8.0 + row_h * (float(i) + 0.5))
		_draw_card_stroke(card, mid + Vector2(0, -12.0), move.card_stroke())
		var icon: Control = UiKit.picture(str(move.card_icon()), 24.0)
		if icon != null:
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.position = mid + Vector2(-12.0, 14.0)
			card.add_child(icon)


## 一笔画。-1..1 的点放大到 22 像素半径，从细到粗 —— 粗的那头是终点，
## 所以"往哪个方向走"不用箭头也说得清；圈和折线本来也画不了箭头。
func _draw_card_stroke(card: Control, mid: Vector2, stroke: Array) -> void:
	if stroke.size() < 2:
		return
	var reach := 22.0
	var line := Line2D.new()
	var pts := PackedVector2Array()
	for p in stroke:
		pts.append(mid + (p as Vector2) * reach)
	line.points = pts
	line.width = 5.0
	line.default_color = Color(1.0, 0.93, 0.55)
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	# 终点上一个圆点：一笔从哪儿收尾，比一个箭头尖更好画也更好认。
	card.add_child(line)
	var tip := Node2D.new()
	card.add_child(tip)
	Shapes.fill(tip, Shapes.circle_points(pts[pts.size() - 1], 7.0, 14),
		Color(1.0, 0.97, 0.78), 0.0)


# --- 搓招 -----------------------------------------------------------------

func _on_stroke_input(event: InputEvent) -> void:
	if not _started or _won or _finished:
		return
	var was_drawing: bool = _stroke.drawing()
	var at := _event_at(event)
	_stroke.feed(event, at)
	_paint_trail()
	if not was_drawing and _stroke.drawing():
		_stroke_from = at
		_stroke_far = 0.0
	elif was_drawing:
		_stroke_far = maxf(_stroke_far, at.distance_to(_stroke_from))
	var move: String = _stroke.take()
	if move != "":
		_perform(move)
	elif was_drawing and not _stroke.drawing() and _stroke_far >= STROKE_TRY:
		_missed_stroke()


## 一笔划完了，招式册里没有这一招。不能没声音：他划了、抬手了、什么都没发生，
## 和"这游戏坏了"是同一件事 —— 减少动效开着的时候连轨迹都不画，就更是。
## 一声轻响，招式表晃一下（说"照这个划"），不碰任何识别阈值。STROKE_TRY 只是
## 把"按按钮时手指滑了一下"排除掉，比每一招要求的距离都短得多。
func _missed_stroke() -> void:
	AudioManager.play_sfx("res://assets/audio/pop.ogg")
	if _move_card != null and is_instance_valid(_move_card):
		Juice.nudge(_move_card, 6.0)


## 事件落在战斗坐标系的哪里。gui_input 给的是相对控件的位置，而这个控件是
## 满屏的，所以两者相同 —— 写出来是因为下一个把它挪进容器的人会踩到。
func _event_at(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	return Vector2.ZERO


## 手指画到哪儿就画到哪儿。看见自己的那一笔，是"我搓出来的"和"游戏替我决定了"
## 之间的全部区别 —— 而且划歪了也看得见，这是他自己能学会的唯一途径。
func _paint_trail() -> void:
	if _trail == null or not is_instance_valid(_trail):
		return
	if not Juice.motion_enabled():
		return
	_trail.points = _stroke.trail()


## 一招打出去。
##
## 两招都吃 _beam_ready_at，所以搓招是光线的替代而不是外挂：一个动作顶两个
## 动作，而不是多一份输出。冷却中搓招走 _refuse，和按钮完全一样 —— 同一个
## 限制，同一个回答。
func _perform(move: String) -> void:
	if _clock < _beam_ready_at:
		_refuse("beam")
		return
	var made = Moves.get_move(move)
	if made == null:
		push_warning("monster_duel: 搓招册里没有 %s" % move)
		return
	# 搓招和光线共用一个冷却：它是替代，不是外挂。一个动作顶两个动作，
	# 而不是多一份输出。
	_beam_ready_at = _clock + _beam_cooldown
	_hero.brace()
	_hero.power_up()
	made.perform(self)
	_flash_ring("beam")


# --- skills -------------------------------------------------------------

func _tap(event: InputEvent) -> bool:
	return UiKit.is_press(event)


## Hold to charge, let go to fire.
##
## 把等待变成动作. The beam used to be tap-then-wait: one press, then 1.3 to 1.7
## seconds of watching a grey wedge sweep. Over the last duel that is roughly
## forty-four presses of one button with dead air between every pair of them,
## and the dead air is most of the level.
##
## Now the wait IS the press. Holding builds a charge; letting go fires. The
## DAMAGE is identical either way -- deliberately, because a child who taps
## must never end up behind -- and what charging buys is reach: a full charge
## cancels whatever the monster is winding up, brings down the goo already in
## the air, and fills the special-move ring twice as fast.
##
## The cost is paid the same either way too: firing sets the remaining cooldown
## to `beam_cooldown - held`, so a tap waits exactly as long as it always did
## and a full hold has already served its sentence. That equality is what keeps
## duel_length_probe honest -- fire_beam_skill(), the tap path and the thing
## that probe presses, is the same fight it was measuring before.
func _on_beam_input(event: InputEvent) -> void:
	if UiKit.is_press(event):
		_begin_charge()
	elif UiKit.is_release(event):
		_release_charge()


func _begin_charge() -> void:
	if not _started or _won or _charging:
		return
	_charging = true
	_charge_started = _clock
	AudioManager.play_sfx("res://assets/audio/charge.ogg")
	_hero.set_pose(HeroArt.Pose.BEAM)
	_hero.pulse_core(1)


## How far along the charge is, 0 to 1. Full takes exactly one cooldown, so the
## charge ring and the button's own wedge always tell the same story.
func charge_fraction() -> float:
	if not _charging:
		return 0.0
	return clampf((_clock - _charge_started) / maxf(_beam_cooldown, 0.05), 0.0, 1.0)


func _release_charge() -> void:
	if not _charging:
		return
	var held: float = _clock - _charge_started
	var full: bool = charge_fraction() >= CHARGED_AT
	_charging = false
	_clear_charge_ring()
	if _hero != null and is_instance_valid(_hero):
		_hero.set_pose(HeroArt.Pose.IDLE)
	if not fire_beam_skill(full):
		return
	# The hold counts AGAINST the cooldown rather than adding to it.
	_beam_ready_at = _clock + maxf(_beam_cooldown - held, 0.2)


## Everything a full charge reaches that a tap does not. No extra damage here
## on purpose -- see the note on _on_beam_input.
func _charged_extras(target: Vector2) -> void:
	Juice.shockwave(_play_area, target, 190.0, Color(1.0, 0.94, 0.72))
	AudioManager.play_sfx("res://assets/audio/ultimate.ogg")
	# Whatever it was winding up, it is not doing it now.
	if _telegraph_left > 0.0:
		_cancel_telegraph()
		_open_up("interrupt")
		_monster.call("flinch")
	# And anything already in the air comes down with it.
	for threat in _threats.duplicate():
		if threat is Button and is_instance_valid(threat):
			_swat_goo(threat)
	# The special move fills twice as fast for a charged hit. A reward for
	# holding, never a requirement.
	_ult_charge = mini(_ult_charge + 1, _ult_needed)


func _on_shield_input(event: InputEvent) -> void:
	if _tap(event):
		activate_shield()


func _on_ult_input(event: InputEvent) -> void:
	if _tap(event):
		fire_ult()


func fire_beam_skill(charged: bool = false) -> bool:
	if not _started or _won:
		return false
	if _clock < _beam_ready_at:
		_refuse("beam")
		return false
	_beam_ready_at = _clock + _beam_cooldown
	# The hero visibly does something: braces, the chest light flares, and the
	# button flashes a ring. Before this, a tap produced a thin beam somewhere
	# off to the right and nothing else.
	_hero.brace()
	_hero.power_up()
	_flash_ring("beam")
	var target: Vector2 = _monster.position + Vector2(randf_range(-40, 40), -190.0 * _monster.scale.x + randf_range(-40, 40))
	_draw_beam(_hero.core_position(), target, 2.0 if charged else 1.0)
	_impact(target)
	_land_hit(1, true, charged)
	AudioManager.play_sfx("res://assets/audio/beam.ogg")
	Juice.pop(_beam_button, 0.16)
	if charged:
		_charged_extras(target)
	return true


func activate_shield() -> bool:
	if not _started or _won:
		return false
	if _clock < _shield_ready_at:
		_refuse("shield")
		return false
	_shield_ready_at = _clock + _shield_cooldown
	_shield_until = _clock + _shield_duration
	Juice.pop(_shield_button, 0.16)
	_flash_ring("shield")
	AudioManager.play_sfx("res://assets/audio/power_up.ogg")

	_raise_bubble()
	if _hero != null and is_instance_valid(_hero) and _hero.has_method("block"):
		_hero.block(_shield_duration)
	return true


## 那个泡泡本身。抽出来是因为现在有两个东西会立起它：护罩键，和画圈那一招 ——
## 两份画法就是两种"我被保护着"的样子，而这是屏幕上最不该有歧义的一件事。
func _raise_bubble() -> void:
	if _shield_bubble != null and is_instance_valid(_shield_bubble):
		return
	# A drawn bubble: a filled dome with a bright rim, so "I am protected right
	# now" is unmistakable at a glance.
	_shield_bubble = Control.new()
	_shield_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_bubble.position = _hero_pos - Vector2(0, 60)
	_play_area.add_child(_shield_bubble)
	Shapes.fill(_shield_bubble, Shapes.circle_points(Vector2.ZERO, 145.0, 32),
		Color(0.55, 0.86, 1.0, 0.22), 0.0)
	var rim := Line2D.new()
	rim.points = Shapes.circle_points(Vector2.ZERO, 145.0, 32)
	rim.closed = true
	rim.width = 7.0
	rim.default_color = Color(0.72, 0.94, 1.0, 0.9)
	rim.antialiased = true
	_shield_bubble.add_child(rim)
	if Juice.motion_enabled():
		var t := _shield_bubble.create_tween().set_loops()
		t.tween_property(_shield_bubble, "modulate:a", 0.4, 0.5)
		t.tween_property(_shield_bubble, "modulate:a", 0.65, 0.5)
	_raise_3d_shield(_shield_duration)


func shield_active() -> bool:
	return _clock < _shield_until


func ult_ready() -> bool:
	return _ult_charge >= _ult_needed


func fire_ult() -> bool:
	if not _started or _won:
		return false
	if not ult_ready():
		_refuse("ult")
		return false
	_ult_charge = 0
	_used_ult = true
	_set_skill_cooldown("ult", 1.0)
	_flash_ring("ult")
	# The special move begins with a leap and lands in the brace -- wind-up,
	# then delivery.
	_hero.jump(64.0, 0.45)
	get_tree().create_timer(0.55).timeout.connect(func():
		if is_inside_tree() and is_instance_valid(_hero):
			_hero.brace()
	)
	AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
	if _ult_type == "burst":
		_ult_burst()
	else:
		_ult_barrage()
	return true


## Six quick beams raking the monster. Loud, bright, three meter cells.
func _ult_barrage() -> void:
	for i in range(6):
		var target: Vector2 = _monster.position + Vector2(randf_range(-90, 90), -randf_range(60, 320) * _monster.scale.x)
		var delay := 0.09 * float(i)
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_inside_tree() or _monster == null or not is_instance_valid(_monster):
				return
			_draw_beam(_hero.core_position(), target)
			_impact(target)
			AudioManager.play_sfx("res://assets/audio/beam.ogg")
		)
	_monster.call("flinch")
	get_tree().create_timer(0.65).timeout.connect(func():
		if is_inside_tree():
			_land_hit(3, false)
	)


## A great gold ring sweeping the arena: every threat pops, the monster is
## dazzled, three meter cells.
func _ult_burst() -> void:
	var ring := TextureRect.new()
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(RING_ART):
		ring.texture = load(RING_ART)
	ring.size = Vector2(220, 220)
	ring.position = _hero_pos - Vector2(110, 170)
	ring.pivot_offset = ring.size / 2.0
	ring.modulate = Color(1.0, 0.85, 0.4, 0.85)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(7.0, 7.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.55)
	t.chain().tween_callback(ring.queue_free)

	for threat in _threats.duplicate():
		if is_instance_valid(threat):
			Juice.burst(_play_area, threat.position + threat.size / 2.0, 10)
			threat.queue_free()
	_threats.clear()
	_land_hit(3, false)


## charges=false for the ult's own hits: a special move must not pay for
## the next special move, or the button never stops glowing.
func _land_hit(amount: int, charges: bool = true, charged: bool = false) -> void:
	# Armoured and not yet opened: the shot lands and does nothing. It has to
	# LOOK like it did nothing on purpose -- a clink, a spark off the shell, the
	# monster unbothered -- because a hit that silently fails to count is the
	# same bug report as a button that does nothing.
	if is_armored_now():
		# 三种结果，都看得出来:
		#   点一下   -> 叮，0     壳挡住了
		#   按住蓄满 -> 1         磨得动，但慢
		#   破绽期   -> 2         正路
		#
		# The middle rung is what stops this being a pass/fail gate. Measured
		# without it, the two ends broke in opposite directions: a monster
		# opened by interrupting (free, always available) died in 37 seconds,
		# and one opened only by blocking -- behind a 5 second shield cooldown
		# -- took 210. A child who has not yet read the tell has to still be
		# moving forward, or the fight is a wall; a child who HAS read it has
		# to be moving much faster, or reading it was pointless.
		if charged:
			_monster.call("flinch")
			if charges:
				_ult_charge = mini(_ult_charge + 1, _ult_needed)
			score_correct()
			_update_meter()
			_check_phase()
			return
		_clink()
		if charges:
			# The special move still fills. Whacking away at a shell is not
			# wasted, it is just slow, and a child who cannot yet read the tell
			# still gets somewhere by trying.
			_ult_charge = mini(_ult_charge + 1, _ult_needed)
			if ult_ready():
				UiKit.breathe(_ult_button, 0.06, 0.6)
		return
	# 破绽期的双倍是给「读懂了它，抓住那扇窗」的奖励，不是给「刚好这一秒放了
	# 大招」的。必杀本身已经是 3 点，再乘 2 就是 6，而它每八次命中就能放一次
	# ——量下来最后一只怪兽 78 点血 41 秒结束，大半是这么没的。
	# ult 走的是 charges=false 那条路，所以这一行只影响真正用手打出去的那一下。
	# 破绽期的双倍付在伤害上，不付在必杀条上。
	#
	# 原来这两样一起翻倍：读懂了它，这一下既算两下伤害、又给必杀条充两格。
	# 两个奖励叠在一起复利，最后一只怪兽 89 点血还是被压到四十来秒，而大半
	# 是必杀吞掉的。
	#
	# 查了一圈现成的做法，守望先锋的经济写得最明白：伤害打在"已经被削弱的
	# 那一层"上只给一半充能，而且必杀自己造成的伤害完全不充能——一记大招
	# 绝不许喂自己。同一条道理：破绽是奖励，不是复利。
	#
	# 但方向不是"把必杀调贵"。同一批资料里另一句同样要紧：一次用得不那么好的
	# 大招，也远好过一次永远没用出来的大招。屏幕上最好看的东西，六岁孩子必须
	# 常常见到——所以价钱不动，只掐掉复利。
	var meter: int = amount
	if wide_open() and charges:
		amount *= OPENING_BONUS
	_monster.call("flinch")
	Juice.impact_sparks(_play_area, arena_monster_at(), Color(1.0, 0.88, 0.35), 10)
	if charged:
		Juice.hit_stop(get_tree(), 0.06)
		Juice.screen_shake(_play_area, 10.0, 0.18)
	if charges:
		_ult_charge = mini(_ult_charge + meter, _ult_needed)
		if ult_ready():
			UiKit.breathe(_ult_button, 0.06, 0.6)
	for i in range(amount):
		score_correct()
	_update_meter()
	_check_phase()


## Armoured right now: it has armour, and the opening is not running.
func is_armored_now() -> bool:
	return _armored and not wide_open()


func wide_open() -> bool:
	return _clock < _open_until


## The shot that bounced. Deliberately NOT the try_again sound -- the child did
## nothing wrong, the monster is just wearing a shell.
func _clink() -> void:
	AudioManager.play_sfx("res://assets/audio/machine.ogg")
	var at: Vector2 = _monster.position + Vector2(-40, -190.0 * _monster.scale.x)
	Juice.burst(_play_area, at, 5)
	if Juice.motion_enabled():
		Juice.nudge(_monster, 8.0)


## The monster is open. Everything that can say so, says so at once: it drops
## its guard, a bright spot appears on it, the sound rises, and the beam does
## double until the window closes.
func _open_up(why: String) -> void:
	if not _armored or wide_open():
		return
	if _guard_left > 0:
		# Some monsters have to be blocked a few times before the shell cracks
		# at all -- 举盾挡住三次攻击, straight off that monster's own card.
		# (Not named here: battle_feel_probe greps this file for every album id,
		# so that nobody can ever write `if _monster_id == ...` -- and a comment
		# is not worth an exception hole in that check.)
		_guard_left -= 1
		_clink()
		return
	if not _opens_on.has(why):
		return
	# 越难的答法，窗口越大。
	#
	# 三种答法的代价差得很远，而奖励原来是一样的：挡要付一次 5 秒的护盾冷却，
	# 躲要在 0.9 秒里点中一个标记，而打断——孩子本来就一直握着光线键，所以每
	# 一次起手都自动是一次破绽，等于不要钱。量出来的结果正是这样：只能打断的
	# 那几只，血最厚却打得最快。
	_open_until = _clock + OPENING * float(OPENING_SCALE.get(why, 1.0))
	AudioManager.play_sfx("res://assets/audio/power_on.ogg")
	if _monster.has_method("dizzy_stun"):
		_monster.call("dizzy_stun", 1.8)
	else:
		_monster.call("flinch")
	Juice.shockwave(_play_area, _monster.position + Vector2(0, -60.0), 150.0,
		Color(1.0, 0.92, 0.6))
	_show_weak_spot()
	_instruction.text = I18n.t("duel.now")


## A bright ring on the monster while it is open, so "hit it NOW" is a picture
## and not a word. Removed by the same clock that closes the window.
func _show_weak_spot() -> void:
	_clear_weak_spot()
	var mark := Control.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.position = _monster.position + Vector2(0, -200.0 * _monster.scale.x)
	mark.z_index = 6
	_play_area.add_child(mark)
	var ring := Line2D.new()
	ring.points = Shapes.circle_points(Vector2.ZERO, 78.0, 30)
	ring.closed = true
	ring.width = 9.0
	ring.default_color = Color(1.0, 0.92, 0.45)
	ring.antialiased = true
	mark.add_child(ring)
	_weak_spot = mark
	if Juice.motion_enabled():
		var t := mark.create_tween().set_loops()
		t.tween_property(mark, "scale", Vector2(1.12, 1.12), 0.35)
		t.tween_property(mark, "scale", Vector2.ONE, 0.35)


func _clear_weak_spot() -> void:
	if _weak_spot != null and is_instance_valid(_weak_spot):
		_weak_spot.queue_free()
	_weak_spot = null


## Half health: it gets cross. One escalation, not four -- the boss-design
## reading is consistent that a second phase is what makes a fight feel like it
## has an arc, and that more than a couple stops being legible.
func _check_phase() -> void:
	if _enraged or _won:
		return
	var need: int = maxi(target_value("correct", 8), 1)
	if float(result.correct) / float(need) < 0.5:
		return
	_enraged = true
	_monster.call("puff_up")
	AudioManager.play_sfx("res://assets/audio/monster_roar.ogg")
	Juice.shockwave(_play_area, _monster.position + Vector2(0, -60.0), 220.0,
		Color(1.0, 0.7, 0.5))
	# Busier, never faster-fingered: the same answers, asked more often.
	if _goo_interval > 0.0:
		_goo_interval = maxf(_goo_interval * 0.75, 2.0)
	if _roar_interval > 0.0:
		_roar_interval = maxf(_roar_interval * 0.75, 4.0)
	# 硬直：发怒之后憋一记大的，预警窗口拉长 1.7 倍。只发生在带真招式表的
	# 关（列表长度 > 1）—— 岛上那六场走默认的单招表，永远见不到它，
	# 它们的时长基准线因此原封不动。
	if _attacks.size() > 1:
		_heavy_owed = true


# --- the monster fights back --------------------------------------------

# --- the wind-up --------------------------------------------------------

## Announce it, then do it. See the note on TELEGRAPH.
func _begin_telegraph(kind: String, span: float = 0.0) -> void:
	if _telegraph_left > 0.0 or _won or _finished:
		return
	_telegraph_kind = kind
	# 窗口有多宽，问那一招自己 —— 两只一起来的召唤要看清有几只在哪儿，所以
	# 它声明了 1.3 倍。更疼的招给更宽的窗口：变强的是怪兽，变难的从来不是
	# 孩子的手。硬直那一记由调用方直接给 span，压过招式自己的声明。
	if span > 0.0:
		_telegraph_left = span
	else:
		var attack = Book.get_attack(kind)
		var scale: float = float(attack.telegraph_scale()) if attack != null else 1.0
		_telegraph_left = TELEGRAPH * scale
	_dodged = false
	_monster.call("puff_up")
	AudioManager.play_sfx("res://assets/audio/warn.ogg")
	_show_dodge_mark()


func _cancel_telegraph() -> void:
	_telegraph_left = 0.0
	_telegraph_kind = ""
	_clear_dodge_mark()


func _fire_telegraphed() -> void:
	var kind := _telegraph_kind
	_telegraph_left = 0.0
	_telegraph_kind = ""
	_clear_dodge_mark()
	if _won or _finished:
		return
	# Dodged: it happens, it just misses. The monster still gets its moment --
	# an attack that is deleted rather than evaded reads as a bug.
	if _dodged:
		AudioManager.play_sfx("res://assets/audio/whoosh.ogg")
		return
	# 一招一个文件，模板只负责问册子。这里曾经是五个 elif 和五个
	# `_monster_attack_*`，第六招要改三处。现在改零处 —— 见 attack_book.gd。
	var attack = Book.get_attack(kind)
	if attack == null:
		# 数据里写错一个名字，结果是"这一次它没出手"，一眼看得见；
		# 而不是悄悄换成另一招，那种错永远查不出来。
		push_warning("monster_duel: 招式册里没有 %s" % kind)
		return
	attack.fire(self)


func _pick_attack() -> String:
	return str(_attacks[randi() % _attacks.size()])


## Where to jump to, drawn on the ground where his thumb already is.
##
## A mark rather than "anywhere on the floor": a whole tappable half-screen
## competes with the beam button he may be holding at that exact moment, and a
## six-year-old told to "move" moves nowhere. One circle, breathing, 120 px.
func _show_dodge_mark() -> void:
	_clear_dodge_mark()
	var size := Vector2(120, 120)
	var mark := Button.new()
	mark.custom_minimum_size = size
	mark.size = size
	mark.pivot_offset = size / 2.0
	mark.focus_mode = Control.FOCUS_NONE
	mark.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.86, 1.0, 0.34)
	style.border_color = Color(0.82, 0.96, 1.0, 0.95)
	style.set_border_width_all(6)
	style.set_corner_radius_all(int(size.x / 2.0))
	for state in ["normal", "hover", "pressed", "disabled"]:
		mark.add_theme_stylebox_override(state, style)
	# Behind the hero and to his left -- away from the monster, which is the
	# direction "get out of the way" means without anyone saying it.
	mark.position = _hero_pos + Vector2(-150.0, -70.0) - size / 2.0
	mark.pressed.connect(_dodge)
	_play_area.add_child(mark)
	_dodge_mark = mark
	UiKit.breathe(mark, 0.06, 0.5)


func _clear_dodge_mark() -> void:
	if _dodge_mark != null and is_instance_valid(_dodge_mark):
		_dodge_mark.queue_free()
	_dodge_mark = null


func _dodge() -> void:
	if _dodged or _telegraph_left <= 0.0:
		return
	_dodged = true
	_clear_dodge_mark()
	_open_up("dodge")
	_hero.roll(150.0, 0.45)
	Juice.dust(_play_area, _hero_pos, 8)
	Juice.speed_lines(_play_area, _hero_pos + Vector2(0, -90),
		Vector2.LEFT, Color(1, 1, 1, 0.55), 3)
	AudioManager.play_sfx("res://assets/audio/whoosh.ogg")


## 一记攻击真的碰到英雄。挡着：弹开、算他一下、能开壳的开壳。没挡：软软的
## 一声、掉一格光、光线键多歇 0.7 秒。和泥球到站的结算刻意同一套 —— 三种
## 新招不引入第四种结果。
func _contact_hero() -> void:
	if _won or _finished:
		return
	if shield_active():
		_open_up("block")
		AudioManager.play_sfx("res://assets/audio/correct.ogg")
		_impact(_hero_pos + Vector2(20, -120))
		_land_hit(1)
		return
	_splat(_hero_pos + Vector2(0, -90))
	_beam_ready_at = maxf(_beam_ready_at, _clock) + 0.7
	_lose_light()


# --- arena：招式唯一许可的接口 -------------------------------------------
#
# 每一招都住在 scripts/battle/attacks/ 下面，拿到的是这个对决本身，但只许调
# 下面这一节。前缀 arena_ 是契约的可见形式：在这边它们聚成一节，在 attack.gd
# 那边它们是一张白名单。一记攻击伸手去摸 _light_left 这种内部状态，是下一个人
# 改不动这两个文件的开始。
#
# 每一个都短得像转发，而这正是它们值钱的地方 —— 内部怎么改，招式不用跟着改。

func arena_play_area() -> Control:
	return _play_area


func arena_monster() -> Node2D:
	return _monster


func arena_monster_at() -> Vector2:
	return _monster_pos


func arena_hero_at() -> Vector2:
	return _hero_pos


## 这一场还在打吗。招式的延时回调全都要先问一句 —— 一个在结算画面上飞出来的
## 泥球，是这类定时器最典型的漏网。
func arena_alive() -> bool:
	return is_inside_tree() and not _won and not _finished


func arena_volley() -> int:
	return _goo_volley


func arena_add_threat(node: Control) -> void:
	_threats.append(node)


func arena_swat(node: Control) -> void:
	_swat_goo(node)


func arena_arrives(node: Control) -> void:
	_threat_arrives(node)


func arena_contact_hero() -> void:
	_contact_hero()


## --- 搓招用到的几个 ---

func arena_hero() -> SkinnedCharacter:
	return _hero


## 这一招该打在哪儿。怪兽身上那个高度，所有搓招共用一个准星。
func arena_aim() -> Vector2:
	if _monster == null or not is_instance_valid(_monster):
		return _hero_pos
	return _monster.position + Vector2(0, -190.0 * _monster.scale.x)


func arena_beam(to: Vector2, fat: float = 1.0) -> void:
	_draw_beam(_hero.core_position(), to, fat)


func arena_impact(at: Vector2) -> void:
	_impact(at)


func arena_land(amount: int, charged: bool = false) -> void:
	_land_hit(amount, true, charged)


## 正在起手就打断它，顺便按"打断"这条路开壳。没在起手就什么都不做 ——
## 招式不需要自己判断时机对不对。
func arena_interrupt() -> void:
	if _telegraph_left <= 0.0:
		return
	_cancel_telegraph()
	_open_up("interrupt")


## 把已经开着的破绽再撑开一截。没开就不动 —— 撑开一扇不存在的窗没有意义，
## 而"顺手把壳打开"是打断该做的事，不是这里。
func arena_stretch_opening(seconds: float) -> void:
	if wide_open():
		_open_until += seconds


## 场上飞的东西一次收拾干净。
func arena_sweep_threats() -> void:
	for threat in _threats.duplicate():
		if threat is Button and is_instance_valid(threat):
			_swat_goo(threat)


## 一小段护罩，不吃护罩键自己的冷却 —— 它是应急，不是替代。
func arena_shelter(seconds: float) -> void:
	_shield_until = maxf(_shield_until, _clock + seconds)
	if _shield_bubble == null or not is_instance_valid(_shield_bubble):
		_raise_bubble()


func arena_after(seconds: float) -> SceneTreeTimer:
	return get_tree().create_timer(seconds)


func arena_tween() -> Tween:
	return create_tween()


## 第一次遇到这招时说一句，只说一次，三秒后还原。
##
## flag 由招式自己给（"swat" / "minions"），旗子存在这边 —— 招式是无状态的
## 单例，一场打完换下一场，教学该重新算，而招式自己记不住"这是新的一场"。
var _taught: Dictionary = {}

func arena_teach_once(flag: String, key: String) -> void:
	if bool(_taught.get(flag, false)):
		return
	_taught[flag] = true
	if _instruction == null or not is_instance_valid(_instruction):
		return
	_instruction.text = I18n.t(key)
	var back := get_tree().create_timer(3.0)
	back.timeout.connect(func():
		if is_instance_valid(_instruction) and not _won and not _finished:
			_instruction.text = I18n.t("duel.instruction"))


# --- the attacks themselves ---------------------------------------------

## Swatted: it bursts where it is and nothing is lost. No score -- defending
## is its own reward, and scoring it would inflate the level's target.
func _swat_goo(goo: Control) -> void:
	if not is_instance_valid(goo) or _won:
		return
	_threats.erase(goo)
	Juice.burst(_play_area, goo.position + goo.size / 2.0, 12)
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	goo.queue_free()


## A threat reaches the hero. Shield up: it bounces back and COUNTS (+1).
## Shield down: a soft poof, a wobble, and the beam button rests a moment
## longer. Nothing is lost either way -- the difference is only how clever
## the child got to feel.
func _threat_arrives(threat: Control) -> void:
	_threats.erase(threat)
	if not is_instance_valid(threat):
		return
	if shield_active():
		_open_up("block")
		AudioManager.play_sfx("res://assets/audio/correct.ogg")
		var back_to: Vector2 = _monster.position + Vector2(0, -190 * _monster.scale.x)
		var t := create_tween()
		t.tween_property(threat, "position", back_to - threat.size / 2.0, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(func():
			if is_instance_valid(threat):
				_impact(threat.position + threat.size / 2.0)
				threat.queue_free()
			_land_hit(1)
		)
		return

	_splat(threat.position + threat.size / 2.0)
	threat.queue_free()
	_beam_ready_at = maxf(_beam_ready_at, _clock) + 0.7
	_lose_light()


# --- shared effects -----------------------------------------------------

## `fat` is how much of a charge went into it: 1.0 for a tap, 2.0 for a full
## hold. The beam is the only place the difference is visible mid-flight, and
## it has to be visible -- holding a button for a second and getting back the
## same thin line teaches that holding does nothing.
func _draw_beam(from: Vector2, to: Vector2, fat: float = 1.0) -> void:
	var span := to - from
	if ResourceLoader.exists(BEAM_ART):
		var beam := Sprite2D.new()
		beam.texture = load(BEAM_ART)
		beam.position = from + span / 2.0
		beam.rotation = span.angle()
		beam.scale = Vector2(span.length() / 1024.0, 0.34 * fat)
		beam.modulate = Color(1.0, 0.88, 0.45) if fat <= 1.0 \
			else Color(1.0, 0.96, 0.72)
		_play_area.add_child(beam)
		var t := create_tween()
		t.tween_property(beam, "modulate:a", 0.0, 0.22 if Juice.motion_enabled() else 0.05)
		t.tween_callback(beam.queue_free)
	_fire_3d_beam(fat)


func _impact(at: Vector2) -> void:
	Juice.burst(_play_area, at, 12)
	if not ResourceLoader.exists(HIT_ART):
		return
	var burst := TextureRect.new()
	burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	burst.texture = load(HIT_ART)
	burst.size = Vector2(150, 150)
	burst.position = at - burst.size / 2.0
	burst.pivot_offset = burst.size / 2.0
	burst.scale = Vector2(0.5, 0.5)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(burst)
	var t := create_tween().set_parallel(true)
	t.tween_property(burst, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(burst, "modulate:a", 0.0, 0.22)
	t.chain().tween_callback(burst.queue_free)


func _splat(at: Vector2) -> void:
	if not ResourceLoader.exists(SMOKE_ART):
		return
	var poof := TextureRect.new()
	poof.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poof.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poof.texture = load(SMOKE_ART)
	poof.size = Vector2(120, 120)
	poof.position = at - poof.size / 2.0
	poof.pivot_offset = poof.size / 2.0
	poof.modulate = Color(0.7, 0.85, 0.6, 0.8)
	poof.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(poof)
	var t := create_tween().set_parallel(true)
	t.tween_property(poof, "scale", Vector2(1.4, 1.4), 0.5)
	t.tween_property(poof, "modulate:a", 0.0, 0.5)
	t.chain().tween_callback(poof.queue_free)


# --- winning ------------------------------------------------------------

func complete_level() -> void:
	if not _finished:
		_won = true
		result.reached_goal = true
		result.found_hidden = _used_ult
		result.clean_run = _light_left >= _light_max
		_instruction.text = I18n.t("battle.bye")
		# Into the 图鉴. Beaten, not merely met -- a card he won is worth more
		# than one he was handed for turning up.
		_met_new_monster = Album.beat_monster(_monster_id)
		_hero.celebrate()
		Juice.burst(_play_area, _monster.position + Vector2(0, -160), 30)
		AudioManager.play_sfx("res://assets/audio/level_complete.ogg")
		_monster.call("leave_happy")
		await get_tree().create_timer(1.0).timeout
	await super.complete_level()


func on_correct() -> void:
	_update_meter()


func _debug_level_data() -> Dictionary:
	return {
		"id": "monster_arena_04",
		"world": "monster_valley",
		"game_type": "monster_duel",
		"difficulty": 1,
		"target": {"correct": 8},
		"reward": {"stars": 3, "coins": 30, "badge": ""},
		"config": {
			"beam_cooldown": 1.2,
			"shield_cooldown": 4.5,
			"ult_needed": 3,
			"goo_interval": 5.0,
			"instruction_key": "duel.instruction",
			"monster": {
				"id": "sand_fist",
				"scale": 1.0,
			},
		},
	}
