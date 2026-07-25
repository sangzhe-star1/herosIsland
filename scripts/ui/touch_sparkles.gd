extends CanvasLayer
## A tiny sparkle wherever the child taps empty space, game-wide.
##
## Buttons, cards, orbs and pads all answer touches themselves; this catches
## the taps that would otherwise fall on nothing -- and at six, a tap that
## does NOTHING is the screen being broken. Unhandled input only, so it
## never competes with real controls; reduce-motion turns it off entirely.

func _ready() -> void:
	layer = 90
	print("[autoload] TouchSparkles ok")


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = UiKit.is_press(event)
	if not pressed or not Juice.motion_enabled():
		return

	var at: Vector2 = event.position
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.amount = 7
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 140.0
	particles.gravity = Vector2(0, 240.0)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.94, 0.6, 0.9)
	if ResourceLoader.exists("res://assets/effects/sparkle.png"):
		particles.texture = load("res://assets/effects/sparkle.png")
		particles.scale_amount_min = 0.04
		particles.scale_amount_max = 0.09
	add_child(particles)
	particles.emitting = true

	var timer := get_tree().create_timer(0.9)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)
