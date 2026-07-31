extends RefCounted
## 扫一个目录，把里面每个脚本实例化成一本册子。
##
##     const Books := preload("res://scripts/battle/script_book.gd")
##     var book: Dictionary = Books.scan("res://scripts/battle/attacks")
##
## 怪兽的招式册和英雄的招式册要做的是同一件事：目录即清单。写第二遍就会有第二
## 种行为 —— 而这里最容易写错的恰恰是导出后的那几种后缀，错了的表现是"注册表
## 在编辑器里满员、在真机上空掉"，没人会报上来，怪兽只是安静地不出手。
##
## 所以扫描只有这一份。attack_book 和 move_book 都只是它上面的一层薄壳，
## 各自加自己的角色查询。


## id -> 实例。id 取自脚本自己的 id()，默认是文件名。
##
## 招式是无状态的（状态全在 arena 那边），所以一个实例反复用是安全的，也省掉
## 每次出手一次 new。
static func scan(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("script_book: 打不开 %s" % dir_path)
		return out
	for file in dir.get_files():
		var name := _source_name(file)
		if name == "":
			continue
		var script: Script = load("%s/%s" % [dir_path, name])
		if script == null:
			push_warning("script_book: %s 载不进来" % name)
			continue
		var made = script.new()
		var id: String = str(made.id())
		if id != "":
			out[id] = made
	return out


## 目录里有几个脚本。给探针比对用：册子里的数目对不上目录里的文件数，就是
## 有东西没被扫进来。
static func count(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var n := 0
	for file in dir.get_files():
		if _source_name(file) != "":
			n += 1
	return n


## 一个文件名还原成它的源码名，不是脚本就返回空字符串。
##
## 导出时一个 .gd 可能变成 .gdc（二进制化）或者跟着一个 .remap。三种都要认，
## 而且都要还原成 load() 认得的那个路径。
static func _source_name(file: String) -> String:
	var name := file
	for suffix in [".remap", ".gdc"]:
		if name.ends_with(suffix):
			name = name.trim_suffix(suffix)
			if not name.ends_with(".gd"):
				name += ".gd"
	return name if name.ends_with(".gd") else ""
