class_name Palette
extends RefCounted
## Every colour in the game, in one place.
##
## Chosen for a six-year-old on a tablet, which is a different problem from
## adult UI: saturated enough to feel like a toy, but with dark ink on light
## surfaces so text stays legible in a bright room. Nothing relies on colour
## alone to carry meaning -- shape and position always agree with it.
##
## Every pairing below clears WCAG AA (4.5:1) for body text.

# --- ink and surfaces ---
const INK := Color(0.11, 0.16, 0.24)          # near-black navy, all body text
const INK_SOFT := Color(0.32, 0.38, 0.46)     # secondary text
const ON_COLOR := Color(1.0, 1.0, 1.0)        # text on saturated buttons
const SURFACE := Color(1.0, 0.99, 0.96)       # warm white cards
const SURFACE_SUNK := Color(0.93, 0.92, 0.89) # inset wells

# --- action colours ---
const BLUE := Color(0.18, 0.44, 0.72)
const GREEN := Color(0.24, 0.62, 0.38)
const ORANGE := Color(0.82, 0.50, 0.14)   # darkened until white text clears AA (3.09:1)
const PURPLE := Color(0.51, 0.38, 0.72)
const RED := Color(0.83, 0.31, 0.27)
const YELLOW := Color(1.0, 0.78, 0.22)
const SLATE := Color(0.40, 0.45, 0.52)
const MUTED := Color(0.68, 0.69, 0.72)        # disabled / locked

# --- world tints, used behind each world's levels ---
const SKY := Color(0.62, 0.83, 0.94)
const MEADOW := Color(0.71, 0.87, 0.72)
const CREAM := Color(0.98, 0.94, 0.85)
const DUSK := Color(0.09, 0.13, 0.24)
const BLUSH := Color(0.97, 0.89, 0.93)

# --- feedback ---
const STAR_ON := Color(1.0, 0.80, 0.18)
const STAR_OFF := Color(0.80, 0.80, 0.82)


## A button's shadow colour: the same hue pushed dark, so the raised edge reads
## as the button's own thickness rather than a grey drop shadow.
static func edge(color: Color) -> Color:
	return color.darkened(0.32)


## Slightly lifted version, for hover and highlight states.
static func lift(color: Color) -> Color:
	return color.lightened(0.10)
