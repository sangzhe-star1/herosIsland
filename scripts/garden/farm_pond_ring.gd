extends Node2D
## Visual timing ring and water ripples for pond fishing.
##
## Deliberately NOT a class_name, loaded through:
##     const PondRing := preload("res://scripts/garden/farm_pond_ring.gd")

const PondManager := preload("res://scripts/garden/farm_pond_manager.gd")

var active := false
var progress := 0.0  # 0.0 to 1.0


func _draw() -> void:
	if not active:
		return
	var center := PondManager.POND_CENTER
	# Water ripple expanding
	var r1 := 10.0 + progress * 32.0
	var a1 := clampf((1.0 - progress) * 0.7, 0.0, 0.7)
	draw_arc(center, r1, 0, TAU, 32, Color(0.65, 0.88, 1.0, a1), 2.5)

	# Secondary trailing ripple
	if progress > 0.25:
		var r2 := 8.0 + (progress - 0.25) * 26.0
		var a2 := clampf((1.0 - (progress - 0.25)) * 0.5, 0.0, 0.5)
		draw_arc(center, r2, 0, TAU, 28, Color(0.65, 0.88, 1.0, a2), 2.0)

	# Contracting timing ring
	var ring_r := lerpf(46.0, 10.0, clampf(progress, 0.0, 1.0))
	var is_sweet := progress >= 0.7 and progress <= 1.0
	var col := Color(1.0, 0.88, 0.28, 0.95) if is_sweet else Color(0.4, 0.75, 1.0, 0.8)
	draw_arc(center, ring_r, 0, TAU, 36, col, 3.5)

	# Target center dot
	draw_circle(center, 4.0, Color(1.0, 1.0, 1.0, 0.9))
