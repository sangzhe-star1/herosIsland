extends RefCounted
## 英雄搓招册：扫目录，不是手写清单。见 script_book.gd 和 attack_book.gd ——
## 三个文件是同一条道理的三次应用，扫描本身只有一份。
const Books := preload("res://scripts/battle/script_book.gd")

const DIR := "res://scripts/battle/moves"

static var _book: Dictionary = {}
static var _scanned := false


static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	_book = Books.scan(DIR)


static func get_move(id: String):
	_scan()
	return _book.get(id)


static func ids() -> Array:
	_scan()
	var out: Array = _book.keys()
	out.sort()
	return out


## 交给 stroke_reader 的那张表：[{name, kind, params}]。
##
## 顺序是稳定的（按 id 排序），因为识别器是"第一个答应的赢"—— 一个会随目录
## 顺序变的优先级，是那种今天对明天错的 bug。
static func gesture_table() -> Array:
	_scan()
	var out: Array = []
	for id in ids():
		var move = _book[id]
		var g: Dictionary = move.gesture()
		if g.is_empty():
			continue
		out.append({"name": id, "kind": str(g.get("kind", "")),
			"params": g.get("params", {})})
	return out


static func files_on_disk() -> int:
	return Books.count(DIR)
