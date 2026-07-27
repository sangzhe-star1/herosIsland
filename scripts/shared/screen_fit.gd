extends RefCounted
## One rule for "the screen is taller than the drawing was made for".
##
##     const Fit := preload("res://scripts/shared/screen_fit.gd")
##     hero.position = Fit.at(self, Vector2(250, 620))
##
##
## WHY THIS EXISTS
##
## The island is drawn against 1280x720 and stretches with aspect="expand".
## Expand does not scale the extra space away -- it HANDS IT OVER. A 4:3 tablet
## gives the game a 1280x960 viewport: 240 real pixels of height that no
## hard-coded y knows about. This project has now shipped that bug twice, and
## the audit called the remaining hard-coded numbers "the candidate list for
## the next one".
##
## What it looks like on an iPad is not a crash. It is worse than a crash,
## because nobody reports it: the whole game sits in the top three quarters of
## the screen, the skill buttons a thumb reaches for float in the middle of
## nowhere, and the bottom quarter is a flat band of grass with nothing in it.
##
##
## THE RULE
##
## `Stage` now draws the world against the real viewport (see stage.gd), so the
## horizon and the ground plane move down on a taller screen. Anything standing
## in that world has to move with it, and moving with it means the SAME
## fraction of the screen, not the same number of pixels:
##
##     at(node, p)  ->  p * (real viewport / 1280x720)
##
## For chrome that belongs against an edge rather than in the world -- a tray
## along the bottom, a pad in the corner -- `bottom()` and `right()` keep the
## gap to that edge instead.
##
## Both are exactly the identity on a 1280x720 screen. That is not a nice
## property, it is the whole safety argument: 30 levels' worth of layout is
## changed by these calls and NONE of it can move on the size the game was
## designed and eyeballed at.

const DESIGN := Vector2(1280.0, 720.0)


## The screen the child is actually holding, never smaller than the design.
## A node that is not in the tree yet cannot ask, and gets the design size --
## which is the same answer it would have got before this file existed.
static func view(node: CanvasItem) -> Vector2:
	if node == null or not node.is_inside_tree():
		return DESIGN
	var size := node.get_viewport_rect().size
	return Vector2(maxf(DESIGN.x, size.x), maxf(DESIGN.y, size.y))


## A design-space point, moved to the same place on the real screen.
static func at(node: CanvasItem, design_pos: Vector2) -> Vector2:
	var v := view(node)
	return Vector2(design_pos.x * v.x / DESIGN.x, design_pos.y * v.y / DESIGN.y)


static func y(node: CanvasItem, design_y: float) -> float:
	return design_y * view(node).y / DESIGN.y


static func x(node: CanvasItem, design_x: float) -> float:
	return design_x * view(node).x / DESIGN.x


## Keep the distance to the bottom edge, for things that belong ON the edge.
## A tray 60 px above the bottom stays 60 px above the bottom.
static func bottom(node: CanvasItem, design_y: float) -> float:
	return view(node).y - (DESIGN.y - design_y)


static func right(node: CanvasItem, design_x: float) -> float:
	return view(node).x - (DESIGN.x - design_x)


## Both edges at once, for a corner.
static func corner(node: CanvasItem, design_pos: Vector2) -> Vector2:
	return Vector2(right(node, design_pos.x), bottom(node, design_pos.y))
