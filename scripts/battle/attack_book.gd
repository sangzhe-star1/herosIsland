extends RefCounted
## 招式册：扫目录，不是手写清单。
##
##     const Book := preload("res://scripts/battle/attack_book.gd")
##     var attack = Book.get_attack("rush")     # 没有就返回 null
##     Book.ids()                               # 全部认识的招
##
##
## 为什么扫目录
##
## 一份手写的 `const ATTACKS := {"goo": ..., "roar": ...}` 是第二处要记得改的
## 地方，而这个项目已经被"第二处"咬过：首页把卡片数写死成 3，第五张卡掉出了
## 屏幕；tablet_probe 自己也写死了 3，于是它一边亮绿一边在量错的那张卡。
##
## 扫目录之后，"加一招"是且只是"往 attacks/ 里放一个文件"。没有清单可以忘记
## 更新，也没有第二处可以和第一处说不一样的话。
##
##
## 导出包里也得扫得到
##
## 导出时 .gd 可能被打成 .gdc（二进制化）或者跟着一个 .remap。三种后缀都认，
## 而且 battle_feel_probe 有一条断言盯着"册子里的招数 == 目录里的文件数"——
## 一个在编辑器里满员、在真机上空掉的注册表，是那种没人会报上来的坏：怪兽
## 只是安静地不出手了。
const Books := preload("res://scripts/battle/script_book.gd")

const DIR := "res://scripts/battle/attacks"

## id -> attack 实例。第一次问的时候建好，之后一直用同一批 —— 攻击是无状态的
## （所有状态都在 arena 那边），所以一个实例反复用是安全的，也省掉每次出手的
## 一次 new。
static var _book: Dictionary = {}
static var _scanned := false


static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	_book = Books.scan(DIR)


## 一招，没有就 null —— 而不是随便给一招。数据里写错一个名字，结果应该是
## "这一关的怪兽不会那一招"（一眼看得见），不是"它换了一招"（永远查不出来）。
static func get_attack(id: String):
	_scan()
	return _book.get(id)


## 按角色找一招。角色写在招式自己身上（is_basic / is_heavy），所以模板里
## 一个招式名字都不用出现 —— 那正是 5C 想买到的东西。找不到返回空字符串。
static func role(which: String) -> String:
	_scan()
	for id in _book.keys():
		var attack = _book[id]
		if which == "basic" and bool(attack.is_basic()):
			return str(id)
		if which == "heavy" and bool(attack.is_heavy()):
			return str(id)
	return ""


static func ids() -> Array:
	_scan()
	var out: Array = _book.keys()
	out.sort()
	return out


## 目录里到底有几个脚本。给探针比对用 —— 见 script_book.gd 文件头。
static func files_on_disk() -> int:
	return Books.count(DIR)
