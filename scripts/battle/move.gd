extends RefCounted
## 英雄的一招搓招。抽象在这里，实现在 moves/ 下面，一个文件一招。
##
##
## 和怪兽那边同一个形状，理由也同一个
##
## 5C 把怪兽的五个 elif 换成了"一招一个文件"，而英雄这边当时还留着一份
## `const MOVES := [...]` 和一段 `match move:` —— 同一个毛病的另一半。加第三招
## 要改四处：那份数组、那段 match、招式表卡片上手画的箭头，还有招式表的宽度。
## 现在改零处。
##
##
## 子类要实现的
##
##   id() -> String                  搓招的名字，默认取文件名
##   gesture() -> Dictionary         {kind, params}，喂给 harvest 那套识别器
##   card_stroke() -> Array          卡片上画的那一笔，见下
##   perform(arena) -> void          真的打出去
##
## 可以覆写的
##
##   card_icon() -> String           笔画旁边那个小图标，说明打出去是什么
##
##
## card_stroke 是什么
##
## 一串 -1..1 的点，就是这一招要画的形状本身：上划是一条竖线，画圈是一个圈。
## 卡片按自己的尺寸把它放大画出来 —— 所以**卡片上显示的就是手指要走的路**，
## 不是一个近似的示意图，也不是谁手画上去的箭头。加一招，卡片自己会长出一行。
##
## 六岁不识字，这张卡是他唯一的说明书。


func id() -> String:
	return get_script().resource_path.get_file().get_basename()


## 手势：{kind: "drag"/"twist"/"sweep"/..., params: {...}}。
## kind 和 params 直接交给 scripts/harvest/gesture.gd —— 战斗里的手感和他每天
## 拔萝卜是同一套识别器，不重写。
func gesture() -> Dictionary:
	return {}


## 卡片上那一笔，-1..1 的点。
func card_stroke() -> Array:
	return []


func card_icon() -> String:
	return "spark"


func perform(_arena) -> void:
	push_warning("move.gd: %s 没有实现 perform()" % id())
