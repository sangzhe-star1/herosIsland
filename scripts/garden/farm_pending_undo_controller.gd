extends RefCounted
## Own the single short-lived undo receipt currently offered by the garden.
##
## `FarmUndoController` contains the refund rules. This object owns receipt
## lifetime so a drawing panel never has to clear saved interaction state.

const UndoRules := preload("res://scripts/garden/farm_undo_controller.gd")

var _pending: Dictionary = {}


func offer(kind: String, id: String, now_ms: int) -> Dictionary:
	set_pending(UndoRules.offer(kind, id, now_ms))
	return current()


func set_pending(receipt: Dictionary) -> void:
	_pending = receipt.duplicate(true)


func current() -> Dictionary:
	return _pending.duplicate(true)


func is_open(now_ms: int) -> bool:
	return UndoRules.is_open(_pending, now_ms)


## Expire a receipt before the view reads it. The final deadline millisecond
## stays open according to the shared undo rule.
func expire(now_ms: int) -> bool:
	if _pending.is_empty() or UndoRules.is_open(_pending, now_ms):
		return false
	_pending = {}
	return true


## Consume before settlement so a synchronous repeat cannot present the same
## purchase a second time, even when the object could no longer be returned.
func consume(now_ms: int) -> Dictionary:
	var receipt := current()
	_pending = {}
	return UndoRules.settle(receipt, now_ms)
