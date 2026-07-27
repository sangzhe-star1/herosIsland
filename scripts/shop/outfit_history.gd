extends RefCounted
## The last few things he changed, so 撤销 can walk back.
##
##     const History := preload("res://scripts/shop/outfit_history.gd")
##
## Five steps, in memory only. Deliberately NOT in the save: an undo stack that
## survives a restart would let a child undo something he did last Tuesday and
## has long since forgotten, which is not undo, it is a surprise. Within one
## visit it is exactly what a mis-tap needs.
##
## Each step is a whole outfit, not a diff. Outfits are seven short strings;
## storing the difference would save nothing and get the ordering wrong the
## first time a preset changed four slots at once.

const DEPTH := 5

var _steps: Array = []


## Call BEFORE changing anything, with what the hero is wearing right now.
func remember(outfit: Dictionary) -> void:
	_steps.append(outfit.duplicate(true))
	while _steps.size() > DEPTH:
		_steps.pop_front()


## The outfit to go back to, or an empty dictionary when there is nothing to
## undo. Pops, so pressing undo five times walks back five steps.
func back() -> Dictionary:
	if _steps.is_empty():
		return {}
	return _steps.pop_back()


func can_undo() -> bool:
	return not _steps.is_empty()


func depth() -> int:
	return _steps.size()


func clear() -> void:
	_steps.clear()
