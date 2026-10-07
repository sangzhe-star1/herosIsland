extends Node2D
## Visual marked dig spot on the farm where the dog digs up a daily seed.
##
## Deliberately NOT a class_name, loaded through:
##     const DigSpot := preload("res://scripts/garden/farm_dog_dig_spot.gd")

const DogManager := preload("res://scripts/garden/farm_dog_manager.gd")

var dug_today := false
var _t := 0.0


func _ready() -> void:
	position = DogManager.DIG_SPOT_POSITION
	z_index = 0


func _draw() -> void:
	var pos := Vector2.ZERO
	if dug_today:
		# A quiet, smooth earth patch (already dug today)
		draw_circle(pos, 26.0, Color(0.55, 0.44, 0.30, 0.45))
		draw_circle(pos, 20.0, Color(0.48, 0.38, 0.25, 0.55))
	else:
		# Marked dig spot: fresh mound of soft soil with cute golden paw sparkles
		draw_circle(pos, 30.0, Color(0.46, 0.33, 0.21, 0.6))
		draw_circle(pos, 24.0, Color(0.58, 0.43, 0.28, 0.88))
		# Small soil clumps
		draw_circle(pos + Vector2(-11.0, -3.0), 6.5, Color(0.50, 0.36, 0.22, 0.95))
		draw_circle(pos + Vector2(9.0, 5.0), 6.0, Color(0.50, 0.36, 0.22, 0.95))
		draw_circle(pos + Vector2(2.0, -9.0), 7.5, Color(0.52, 0.38, 0.24, 0.95))
		# Golden paw print / sparkle
		var pulse := 0.8 + 0.2 * sin(_t * 4.0)
		var sparkle_col := Color(1.0, 0.92, 0.45, pulse)
		draw_circle(pos + Vector2(0.0, 2.0), 5.5, sparkle_col)
		draw_circle(pos + Vector2(-5.5, -4.0), 2.8, sparkle_col)
		draw_circle(pos + Vector2(0.0, -6.5), 2.8, sparkle_col)
		draw_circle(pos + Vector2(5.5, -4.0), 2.8, sparkle_col)


func _process(delta: float) -> void:
	if not dug_today and Juice.motion_enabled():
		_t += delta
		queue_redraw()
