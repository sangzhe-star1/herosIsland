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

## Where the two of them stand, written against the 1280x720 the art was drawn
## at. Nothing reads these directly any more -- everything goes through
## _hero_pos and _monster_pos, which are the same two places on the screen the
## child is actually holding. On a 4:3 tablet that screen is 1280x960 and the
## ground line has moved down with it, so a hero left at a hard 620 stands in
## mid-air with a hundred and fifty pixels of daylight under his boots.
const GROUND_Y := 620.0
const HERO_POS := Vector2(250, 620)
const MONSTER_POS := Vector2(690, GROUND_Y)   # clear of the skill pad, bottom right
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
const MONSTER_STAND := 290.0
## The tallest a boss may be drawn, horns and all. The health bar sits at
## y=84 and the ground at y=620, so anything past this is standing in the HUD.
const MONSTER_CEILING := 440.0


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
var _threats: Array = []          # goo and roar nodes in flight
var _taught_swat := false         # the "tap the goo" line, shown once

## --- holding the beam ---
var _charging := false
var _charge_started := 0.0
var _charge_ring: Line2D
## Charged enough to interrupt. Not 1.0: a finger lifts a frame early, and a
## child must never lose the whole thing to that.
const CHARGED_AT := 0.8

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
const OPENING := 2.6
## What a hit is worth while the monster is wide open. The reward for reading
## it right has to be big enough to feel, or a child goes back to mashing.
const OPENING_BONUS := 2

var _armored := false
var _opens_on: Array = []
var _open_until := 0.0
var _guard_left := 0            # blocks still owed before it can be opened
var _weak_spot: Control
var _enraged := false

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
	var armor: Dictionary = config.get("armor", {})
	_armored = not armor.is_empty()
	_opens_on = armor.get("opens_on", ["dodge", "block", "interrupt"])
	_guard_left = int(armor.get("blocks_first", 0))

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

	build_world(_play_area, 0.0)

	# The play area is in the tree now, so it can be asked how big the screen
	# really is. Everything placed after this line is placed on THAT screen.
	_hero_pos = Fit.at(_play_area, HERO_POS)
	_monster_pos = Fit.at(_play_area, MONSTER_POS)

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
	var ring := Node2D.new()
	frame.add_child(ring)
	var mid := Vector2(size * 0.5, size * 0.5)
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


func _build_meter() -> void:
	var holder := Control.new()
	# Centred, and one GAP below the instruction instead of two pixels into it.
	holder.position = Vector2((Fit.view(_play_area).x - HP_W) * 0.5,
		MARGIN + 56.0 + GAP)
	holder.size = Vector2(HP_W, HP_H)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(holder)

	# Whose health this is. Without the face it is just a bar, and the child
	# has two of them on screen.
	#
	# THIS monster's face, not a generic one: the whole point of giving every
	# boss its own drawing is undone if the bar above it still shows the same
	# purple stand-in on all six islands. Same album entry as the creature and
	# the album card, so all three can never drift apart.
	_hp_face = _monster_head(52.0)
	if _hp_face == null:
		_hp_face = UiKit.picture("monster", 52.0)
	if _hp_face != null:
		_hp_face.position = Vector2(-58, -10)
		_hp_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(_hp_face)

	var track := Node2D.new()
	holder.add_child(track)
	Shapes.fill(track, Shapes.rounded_rect(Vector2(-4, -4),
		Vector2(HP_W + 8.0, HP_H + 8.0), (HP_H + 8.0) * 0.5),
		Color(0.06, 0.09, 0.18, 0.85), 0.0)

	_hp_fill = Control.new()
	_hp_fill.position = Vector2.ZERO
	_hp_fill.size = Vector2(HP_W, HP_H)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.clip_contents = true
	holder.add_child(_hp_fill)
	var paint := Node2D.new()
	_hp_fill.add_child(paint)
	Shapes.lit(paint, Shapes.rounded_rect(Vector2.ZERO, Vector2(HP_W, HP_H),
		HP_H * 0.5), Color(0.96, 0.55, 0.42), 1.0)
	Shapes.fill(paint, Shapes.rounded_rect(Vector2(10, 6),
		Vector2(HP_W - 20.0, HP_H * 0.30), HP_H * 0.15),
		Color(1.0, 0.86, 0.72, 0.55), 0.0)


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
	pad_style.bg_color = Color(0.06, 0.09, 0.20, 0.42)
	# A capsule: the radius IS half the height, so it cannot drift out of the
	# family the way four separately-written corner numbers can.
	pad_style.set_corner_radius_all(int(pad_size.y * 0.5))
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
	style.bg_color = Color(0.09, 0.15, 0.30, 0.94)
	style.set_corner_radius_all(int(size / 2.0))
	style.shadow_color = Color(0.0, 0.04, 0.12, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 6)
	button.add_theme_stylebox_override("panel", style)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var icon: Control = UiKit.picture(icon_name, size * 0.58)
	if icon != null:
		icon.position = Vector2(size * 0.21, size * 0.21)
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
		size * 0.5 - 3.0, 30)
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
	for i in range(LIGHT_PIPS):
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
			_light_left = LIGHT_PIPS
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

	if _goo_interval > 0.0:
		_goo_timer -= delta
		if _goo_timer <= 0.0:
			_goo_timer = _goo_interval * randf_range(0.85, 1.3)
			_begin_telegraph("goo")
			return
	if _roar_interval > 0.0:
		_roar_timer -= delta
		if _roar_timer <= 0.0:
			_roar_timer = _roar_interval * randf_range(0.9, 1.3)
			_begin_telegraph("roar")


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
	_land_hit(1)
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
	return true


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
func _land_hit(amount: int, charges: bool = true) -> void:
	# Armoured and not yet opened: the shot lands and does nothing. It has to
	# LOOK like it did nothing on purpose -- a clink, a spark off the shell, the
	# monster unbothered -- because a hit that silently fails to count is the
	# same bug report as a button that does nothing.
	if is_armored_now():
		_clink()
		if charges:
			# The special move still fills. Whacking away at a shell is not
			# wasted, it is just slow, and a child who cannot yet read the tell
			# still gets somewhere by trying.
			_ult_charge = mini(_ult_charge + 1, _ult_needed)
			if ult_ready():
				UiKit.breathe(_ult_button, 0.06, 0.6)
		return
	if wide_open():
		amount *= OPENING_BONUS
	_monster.call("flinch")
	if charges:
		_ult_charge = mini(_ult_charge + amount, _ult_needed)
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
		# at all -- 举盾挡住三次攻击, straight off blaze_claw's card.
		_guard_left -= 1
		_clink()
		return
	if not _opens_on.has(why):
		return
	_open_until = _clock + OPENING
	AudioManager.play_sfx("res://assets/audio/power_on.ogg")
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


# --- the monster fights back --------------------------------------------

# --- the wind-up --------------------------------------------------------

## Announce it, then do it. See the note on TELEGRAPH.
func _begin_telegraph(kind: String) -> void:
	if _telegraph_left > 0.0 or _won or _finished:
		return
	_telegraph_kind = kind
	_telegraph_left = TELEGRAPH
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
	if kind == "goo":
		_monster_attack_goo()
	elif kind == "roar":
		_monster_attack_roar()


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


# --- the attacks themselves ---------------------------------------------

func _monster_attack_goo() -> void:
	_monster.call("puff_up")
	if not _taught_swat:
		_taught_swat = true
		_instruction.text = I18n.t("duel.swat")
		var back := get_tree().create_timer(3.0)
		back.timeout.connect(func():
			if is_instance_valid(_instruction) and not _won and not _finished:
				_instruction.text = I18n.t("duel.instruction")
		)
	# The goo is a BUTTON now: it can be swatted out of the air. Until the
	# light bar could actually run out, ignoring goo was free and the shield
	# was a curiosity; now that it ends the level, a child needs a defence
	# more discoverable than a skill on a cooldown. Tapping the thing flying
	# at you is the most discoverable defence there is.
	var goo := Button.new()
	var goo_size := Vector2(96, 96)
	goo.custom_minimum_size = goo_size
	goo.size = goo_size
	goo.pivot_offset = goo_size / 2.0
	goo.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.78, 0.42, 0.95)
	style.set_corner_radius_all(int(goo_size.x / 2.0))
	style.border_width_bottom = 5
	style.border_color = Color(0.40, 0.62, 0.30)
	for state in ["normal", "hover", "pressed", "disabled"]:
		goo.add_theme_stylebox_override(state, style)
	# Press, not release. A Button fires on RELEASE by default, so the finger
	# had to go down AND come up on the same 96px target -- while that target
	# is 2.4 seconds into a parabola. It slides out from under him and the swat
	# misses. The three skill keys beside it have always fired on press (they
	# read raw gui_input); the one thing on this screen that MOVES was the one
	# thing wired to release.
	goo.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	goo.pressed.connect(_swat_goo.bind(goo))
	# And it has to say it can be hit. The only teaching is one line of text,
	# once, for three seconds (_taught_swat) -- which a child who cannot read
	# never receives at all. A thing that pulses is a thing you touch.
	UiKit.breathe(goo, 0.05, 0.7)
	var from: Vector2 = _monster.position + Vector2(-40, -240 * _monster.scale.x)
	goo.position = from - goo_size / 2.0
	_play_area.add_child(goo)
	_threats.append(goo)

	var to := _hero_pos + Vector2(0, -50)
	var t := create_tween()
	t.tween_method(_goo_step.bind(goo, from, to), 0.0, 1.0, 2.4)
	t.tween_callback(func(): _threat_arrives(goo))


## Swatted: it bursts where it is and nothing is lost. No score -- defending
## is its own reward, and scoring it would inflate the level's target.
func _swat_goo(goo: Control) -> void:
	if not is_instance_valid(goo) or _won:
		return
	_threats.erase(goo)
	Juice.burst(_play_area, goo.position + goo.size / 2.0, 12)
	AudioManager.play_sfx("res://assets/audio/correct.ogg")
	goo.queue_free()


func _goo_step(k: float, goo: Control, from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(goo):
		return
	var x: float = lerpf(from.x, to.x, k)
	var y: float = lerpf(from.y, to.y, k) - sin(k * PI) * 170.0
	goo.position = Vector2(x, y) - goo.size / 2.0


func _monster_attack_roar() -> void:
	_monster.call("puff_up")
	AudioManager.play_sfx("res://assets/audio/try_again.ogg")
	var ring := TextureRect.new()
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(RING_ART):
		ring.texture = load(RING_ART)
	elif ResourceLoader.exists(SMOKE_ART):
		ring.texture = load(SMOKE_ART)
	ring.size = Vector2(170, 170)
	ring.position = _monster.position + Vector2(-140, -260)
	ring.modulate = Color(0.8, 0.55, 0.95, 0.8)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_area.add_child(ring)
	_threats.append(ring)
	var t := create_tween()
	t.tween_property(ring, "position:x", _hero_pos.x - 85.0, 2.6)
	t.tween_callback(func(): _threat_arrives(ring))


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
		result.clean_run = _light_left >= LIGHT_PIPS
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
