class_name WorldStyle
extends RefCounted
## What one place in Growth Island looks like.
##
## The whole island is drawn with the same shapes, the same outline, the same
## ground line and the same light rule (Shapes.LIGHT_DIR). The only thing that
## changes from world to world is **the hour of the day** and the silhouette on
## the horizon. That is deliberate: it gives each world its own feeling without
## ever leaving the style, which is exactly the failure mode this replaces --
## a photographic night city next to a flat pastel village next to grey boxes.
##
## Piglet Town is late morning. Safety Bureau is bright noon. Rescue Forest is
## golden afternoon. Hero City is dusk, when the lights come on. Monster Arena
## is night. A child moving through the map is moving through a single day.

## Where the ground meets the sky, as a fraction of screen height. Shared by
## every world so a hero standing in the forest and a hero standing in the city
## stand at the same height on the screen, and no level has to guess.
const HORIZON := 0.86

var id := "island"

## Where the ground meets the sky in THIS world, as a fraction of screen
## height. Defaults to the shared HORIZON so every side-on level puts its
## actors at the same height; the crossing levels raise it, because there the
## camera looks down the road rather than along it.
var horizon := HORIZON
## How far down the ground props may stand, as a fraction of the ground area.
## Small values keep them near the far edge, out of the play space.
var prop_band := 0.55

# --- sky ---
var sky_top := Color(0.34, 0.62, 0.88)
var sky_bottom := Color(0.78, 0.90, 0.97)
## Warm band right above the horizon. This is most of what "time of day" means.
var haze := Color(1.0, 0.94, 0.82, 0.55)

# --- the sun or moon ---
var light_at := Vector2(0.20, 0.22)     # fraction of the screen
var light_radius := 62.0
var light_color := Color(1.0, 0.96, 0.80)
var light_glow := 0.34
var star_density := 0.0                 # 0 = daylight, 1 = deep night

# --- the horizon ---
## "hills" | "skyline" | "forest" | "crags" | "rooftops" | "sea"
var horizon_kind := "hills"
## How tall the horizon stands. A skyline towers; a hedgerow does not.
var band_scale := 1.0
## Far to near. Three bands is enough for depth and cheap enough for a tablet.
var band_colors: Array[Color] = [
	Color(0.62, 0.78, 0.72), Color(0.48, 0.70, 0.60), Color(0.36, 0.60, 0.48),
]

# --- the ground ---
var ground_top := Color(0.52, 0.76, 0.48)
var ground_bottom := Color(0.36, 0.62, 0.36)
var ground_kind := "grass"              # "grass" | "road" | "plaza" | "sand" | "arena"

# --- what lives here ---
## Props scattered on the ground line, drawn by Stage. Kept small: a world is
## recognisable from three or four repeated shapes, not from twenty.
var props: Array[String] = ["tree", "bush", "flower"]
var prop_density := 1.0

# --- the air ---
var mote_kind := "pollen"               # "none"|"pollen"|"fireflies"|"embers"|"snow"|"rain"|"sparks"
var mote_color := Color(1.0, 0.95, 0.72, 0.75)

## Pulled toward white/ink to keep gameplay readable on busy worlds. Applied by
## Stage as a full-width veil above the scenery and below the play field, so a
## sorting level and a battle level can share a world and still both read.
var calm := 0.0

## Cloud cover, 0 to 1.
var clouds := 0.55


## The five worlds, plus the island seen from above on the map. Everything the
## game draws comes from one of these -- there is no other source of scenery.
static func for_world(world_id: String) -> WorldStyle:
	var s := WorldStyle.new()
	s.id = world_id
	match world_id:

		# Late morning over a friendly valley. The gentlest screen in the game,
		# because this is where the youngest levels live.
		"piglet_town":
			s.sky_top = Color(0.36, 0.66, 0.92)
			s.sky_bottom = Color(0.80, 0.92, 0.99)
			s.haze = Color(1.0, 0.97, 0.86, 0.50)
			s.light_at = Vector2(0.78, 0.16)
			s.light_radius = 58.0
			s.light_color = Color(1.0, 0.95, 0.72)
			s.light_glow = 0.30
			s.horizon_kind = "hills"
			s.band_colors = [
				Color(0.66, 0.83, 0.78), Color(0.53, 0.76, 0.60), Color(0.40, 0.67, 0.46),
			]
			s.ground_top = Color(0.56, 0.80, 0.46)
			s.ground_bottom = Color(0.38, 0.65, 0.35)
			s.props = ["cottage", "tree", "bush", "flower", "fence"]
			s.clouds = 0.7
			s.mote_kind = "pollen"
			s.mote_color = Color(1.0, 0.97, 0.78, 0.7)

		# Flat noon light, low contrast, nothing dramatic. A level about
		# crossing a road should not have a sunset competing with the traffic
		# light -- here the scenery deliberately gets out of the way.
		"safety":
			s.sky_top = Color(0.44, 0.72, 0.93)
			s.sky_bottom = Color(0.85, 0.94, 0.99)
			s.haze = Color(1.0, 1.0, 0.94, 0.42)
			s.light_at = Vector2(0.50, 0.10)
			s.light_radius = 52.0
			s.light_color = Color(1.0, 0.99, 0.86)
			s.light_glow = 0.22
			s.horizon_kind = "rooftops"
			s.band_scale = 1.3
			s.band_colors = [
				Color(0.72, 0.82, 0.88), Color(0.62, 0.74, 0.82), Color(0.52, 0.66, 0.75),
			]
			s.ground_top = Color(0.60, 0.80, 0.52)
			s.ground_bottom = Color(0.44, 0.68, 0.40)
			s.ground_kind = "road"
			s.props = ["shop", "lamp", "tree", "bush"]
			s.clouds = 0.45
			s.mote_kind = "none"

		# Four o'clock in autumn. Long warm light through a deep treeline --
		# the world where the kindness levels live, and the one that should
		# feel like the safest place on the island.
		"rescue_forest":
			s.sky_top = Color(0.44, 0.60, 0.82)
			s.sky_bottom = Color(1.0, 0.83, 0.60)
			s.haze = Color(1.0, 0.78, 0.50, 0.66)
			s.light_at = Vector2(0.24, 0.60)
			s.light_radius = 92.0
			s.light_color = Color(1.0, 0.87, 0.58)
			s.light_glow = 0.46
			s.horizon_kind = "forest"
			s.band_scale = 1.4
			s.band_colors = [
				Color(0.52, 0.60, 0.62), Color(0.36, 0.51, 0.46), Color(0.22, 0.38, 0.32),
			]
			s.ground_top = Color(0.46, 0.62, 0.36)
			s.ground_bottom = Color(0.26, 0.42, 0.26)
			s.props = ["pine", "tree", "bush", "flower", "rock", "log"]
			s.prop_density = 1.5
			s.clouds = 0.3
			s.mote_kind = "fireflies"
			s.mote_color = Color(1.0, 0.92, 0.55, 0.85)

		# Dusk, the moment the windows light up. Keeps the drama the hero
		# levels were reaching for with the photograph, but drawn, so the hero
		# is standing in the city instead of on top of it.
		"hero_city":
			s.sky_top = Color(0.16, 0.20, 0.44)
			s.sky_bottom = Color(0.92, 0.56, 0.44)
			s.haze = Color(1.0, 0.66, 0.42, 0.62)
			s.light_at = Vector2(0.63, 0.44)
			s.light_radius = 72.0
			s.light_color = Color(1.0, 0.78, 0.48)
			s.light_glow = 0.50
			s.star_density = 0.25
			s.horizon_kind = "skyline"
			s.band_scale = 2.1
			s.band_colors = [
				Color(0.30, 0.30, 0.50), Color(0.21, 0.22, 0.40), Color(0.13, 0.15, 0.30),
			]
			s.ground_top = Color(0.24, 0.25, 0.40)
			s.ground_bottom = Color(0.14, 0.16, 0.28)
			s.ground_kind = "plaza"
			s.props = ["lamp", "block", "antenna"]
			s.clouds = 0.35
			s.mote_kind = "sparks"
			s.mote_color = Color(1.0, 0.86, 0.55, 0.8)

		# Night, but a friendly night -- a big moon, a lot of stars, and no
		# black anywhere. The monsters here end up tired and happy, so the
		# arena is lit like a fairground after closing, not like a horror film.
		"monster_arena":
			s.sky_top = Color(0.08, 0.10, 0.26)
			s.sky_bottom = Color(0.30, 0.24, 0.50)
			s.haze = Color(0.68, 0.52, 0.92, 0.45)
			s.light_at = Vector2(0.80, 0.20)
			s.light_radius = 66.0
			s.light_color = Color(0.96, 0.96, 0.86)
			s.light_glow = 0.40
			s.star_density = 1.0
			s.horizon_kind = "crags"
			s.band_scale = 1.9
			s.band_colors = [
				Color(0.22, 0.20, 0.42), Color(0.16, 0.15, 0.34), Color(0.11, 0.11, 0.26),
			]
			s.ground_top = Color(0.28, 0.22, 0.44)
			s.ground_bottom = Color(0.15, 0.12, 0.28)
			s.ground_kind = "arena"
			s.props = ["banner", "crag", "brazier"]
			s.clouds = 0.25
			s.mote_kind = "embers"
			s.mote_color = Color(1.0, 0.72, 0.46, 0.8)

		# Crisp alpine morning: thin air, high peaks, long views. The world
		# where the platform trails live -- the one world whose horizon the
		# camera actually travels past, so the peaks are tall and pale.
		"adventure_valley":
			s.sky_top = Color(0.36, 0.64, 0.92)
			s.sky_bottom = Color(0.82, 0.92, 0.99)
			s.haze = Color(0.94, 0.97, 1.0, 0.5)
			s.light_at = Vector2(0.22, 0.13)
			s.light_radius = 56.0
			s.light_color = Color(1.0, 0.98, 0.86)
			s.light_glow = 0.28
			s.horizon_kind = "crags"
			s.band_scale = 2.3
			s.band_colors = [
				Color(0.74, 0.82, 0.92), Color(0.62, 0.73, 0.87), Color(0.50, 0.64, 0.80),
			]
			s.ground_top = Color(0.52, 0.76, 0.46)
			s.ground_bottom = Color(0.34, 0.58, 0.34)
			s.props = ["pine", "rock", "tree"]
			s.prop_density = 1.2
			s.clouds = 0.6
			s.mote_kind = "pollen"
			s.mote_color = Color(1.0, 1.0, 1.0, 0.6)

		# The island seen from the air, for the map and the shell screens.
		# Same palette family as Piglet Town so arriving on the map feels like
		# looking down at the place you were just standing in.
		"island", _:
			s.sky_top = Color(0.24, 0.56, 0.80)
			s.sky_bottom = Color(0.50, 0.78, 0.90)
			s.haze = Color(0.86, 0.95, 1.0, 0.40)
			s.light_at = Vector2(0.84, 0.14)
			s.light_radius = 54.0
			s.horizon_kind = "sea"
			s.band_colors = [
				Color(0.40, 0.68, 0.84), Color(0.31, 0.60, 0.80), Color(0.24, 0.52, 0.74),
			]
			s.ground_top = Color(0.32, 0.63, 0.82)
			s.ground_bottom = Color(0.20, 0.48, 0.70)
			s.ground_kind = "sand"
			s.props = []
			s.clouds = 0.5
			s.mote_kind = "none"
	return s


## A level may nudge its own world without leaving it: "night" for a storm
## level in Hero City, "calm" so a sorting grid reads cleanly over the scenery.
## What a level may NOT do is name a picture -- that is the door this closes.
func apply_config(config: Dictionary) -> WorldStyle:
	calm = clampf(float(config.get("calm", calm)), 0.0, 1.0)
	if config.has("weather"):
		match str(config["weather"]):
			"rain":
				mote_kind = "rain"
				mote_color = Color(0.80, 0.88, 1.0, 0.55)
				clouds = 1.0
				sky_top = sky_top.lerp(Color(0.32, 0.36, 0.46), 0.55)
				sky_bottom = sky_bottom.lerp(Color(0.60, 0.64, 0.70), 0.55)
				haze = Color(0.72, 0.76, 0.82, 0.5)
				light_glow *= 0.4
			"snow":
				# Snow is a MAP change, not just weather: the ground and the
				# distant bands whiten, so a snowy level reads as a different
				# place on the same island. This is the "switch the map" knob:
				# any level may set "weather" in its config and get a new look
				# for the same world, with no art.
				mote_kind = "snow"
				mote_color = Color(1.0, 1.0, 1.0, 0.85)
				clouds = 0.9
				ground_top = ground_top.lerp(Color(0.93, 0.95, 1.0), 0.55)
				ground_bottom = ground_bottom.lerp(Color(0.72, 0.78, 0.88), 0.40)
				for i in range(band_colors.size()):
					band_colors[i] = band_colors[i].lerp(Color(0.92, 0.95, 1.0), 0.35)
				haze = Color(0.94, 0.96, 1.0, 0.55)
			"storm":
				mote_kind = "rain"
				clouds = 1.0
				star_density = 0.0
				sky_top = sky_top.lerp(Color(0.16, 0.16, 0.26), 0.6)
				sky_bottom = sky_bottom.lerp(Color(0.38, 0.34, 0.42), 0.6)
			"clear":
				clouds = 0.15
	if bool(config.get("damaged", false)):
		# The "city under attack" levels. Smoke and a bruised sky, still drawn
		# in the same palette -- damage is a lighting change, not a new art set.
		haze = Color(0.86, 0.44, 0.34, 0.55)
		mote_kind = "embers"
		clouds = 0.8
	return self


## Silhouettes read as distance when they lose contrast against the sky. One
## rule, applied to every band in every world, is why the horizon always sits
## behind the action instead of competing with it.
func band_color(index: int) -> Color:
	var c: Color = band_colors[clampi(index, 0, band_colors.size() - 1)]
	if calm <= 0.0:
		return c
	return c.lerp(sky_bottom, calm * 0.45)
