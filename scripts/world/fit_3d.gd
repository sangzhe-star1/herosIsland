extends RefCounted
## Size a level's 3D backdrop to the real viewport without moving anything.
##
## The six 3D-backed templates were built at 1280x720 and hard-coded that size
## into their SubViewportContainer. On a 4:3 iPad the game's viewport is
## 1280x960 (aspect=expand), so the bottom 240 px showed the grey clear colour,
## and in observation_search a findable item sat on that grey band.
##
## Simply growing the container is not enough: a perspective camera would then
## re-centre its picture and every 3D crate, slot and table would slide away
## from the 2D hit areas laid over it. So for a taller screen the camera becomes
## an off-axis frustum with the same scale and the same top edge: the top 720
## rows are pixel-for-pixel what 16:9 shows, and the extra height simply shows
## more of the floor below. Screen-to-world rays (project_ray_*) stay valid.

const DESIGN := Vector2(1280.0, 720.0)


## `design_fov` is the vertical field of view the scene was framed with at 16:9.
static func fill(container: SubViewportContainer, viewport: SubViewport,
		camera: Camera3D, design_fov: float, view_size: Vector2) -> void:
	var size := Vector2(maxf(view_size.x, 1.0), maxf(view_size.y, 1.0))
	container.custom_minimum_size = size
	container.size = size
	viewport.size = Vector2i(size.round())
	if camera == null:
		return
	if is_equal_approx(size.y * DESIGN.x, DESIGN.y * size.x):
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = design_fov
		return
	frame(camera, design_fov, size)


## The off-axis frustum, separately so a probe can check the arithmetic.
static func frame(camera: Camera3D, design_fov: float, size: Vector2) -> void:
	# World units per screen pixel on the near plane, from the 16:9 framing:
	# 720 design rows span the design fov. The same scale holds for any size,
	# so a wider screen shows more at the sides and a taller one more below.
	var half_design := camera.near * tan(deg_to_rad(design_fov) * 0.5)
	var per_px := 2.0 * half_design / DESIGN.y
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = per_px * size.y
	# Keep the top edge where 16:9 put it; extra rows extend downward.
	camera.frustum_offset = Vector2(0.0, half_design - per_px * size.y * 0.5)
