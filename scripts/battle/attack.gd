extends RefCounted
## 一记攻击。抽象在这里，实现在 attacks/ 下面，一个文件一招。
##
##
## 为什么是类，不是 if/elif
##
## 5B 加完三招之后，对决模板里长出了这样一段：
##
##     if kind == "goo":    ...
##     elif kind == "roar":  ...
##     elif kind == "rush":  ...
##     elif kind == "breath": ...
##     elif kind == "summon": ...
##
## 五个分支，五个 `_monster_attack_*`，全都住在同一个 1900 行的文件里。第六招
## 要改三处：分支、方法、还有那份没人记得的心智清单。这正是这个项目在别处已经
## 吃过一次的亏 —— 首页把卡片数写死成 3，第五张就掉出了屏幕；tablet_probe 自己
## 也写死了 3，于是它一边亮绿一边在量错的那张卡。
##
## 所以：一招 = 一个文件。放进 attacks/ 就存在，关卡数据里写上 id 就会用。
## 模板不认识任何一招的名字，attack_book 也没有一张手写的清单可以忘记更新
## —— 它扫目录。battle_feel_probe 有一条断言在 grep 模板，只要有人写下
## `if kind == "rush"`，它就红。
##
##
## 子类要实现的
##
##   id() -> String              数据里写的那个名字，和文件名一致
##   fire(arena) -> void         真的打出去
##
## 可以覆写的
##
##   answered_by() -> Array      这招能被哪几种答法应对，纯声明，给探针和
##                               将来的教学界面读；不参与结算
##   telegraph_scale() -> float  起手窗口的倍数。更疼的招给更宽的窗口 ——
##                               变强的是怪兽，变难的从来不是孩子的手
##
##
## arena 是什么
##
## 传进去的是对决本身，但子类**只许**调下面这些 `arena_` 开头的方法。前缀是
## 契约的可见形式：在模板那边它们聚成一节，在这边它们是白名单。攻击伸手去摸
## `_light_left` 这种内部状态，是下一个人改不动这个文件的开始。
##
##   arena_play_area() -> Control      往哪儿挂节点
##   arena_monster() -> Node2D         怪兽本体（可能为 null）
##   arena_monster_at() -> Vector2     它站在哪
##   arena_hero_at() -> Vector2        英雄站在哪
##   arena_alive() -> bool             这一场还在打吗
##   arena_volley() -> int             这一关一次最多几个飞行物
##   arena_add_threat(node)            登记一个飞行物（能被拍的）
##   arena_swat(node)                  它被拍掉了
##   arena_arrives(node)               它飞到英雄跟前了
##   arena_contact_hero()              一记攻击真的碰到英雄
##   arena_teach_once(flag, key)       第一次遇到这招时说一句，只说一次
##   arena_after(seconds) -> SceneTreeTimer
##   arena_tween() -> Tween


## 数据里写的名字。默认取文件名，所以一个文件一招、文件名即 id，不用两处对齐。
func id() -> String:
	return get_script().resource_path.get_file().get_basename()


## 这招能被哪几种答法应对。声明用，不参与结算 —— 结算走 arena_contact_hero，
## 五招共用同一套（挡了弹开算一下，没挡掉一格光），不引入第四种结果。
func answered_by() -> Array:
	return ["block", "dodge", "interrupt"]


## 起手窗口的倍数。1.0 是默认的那 0.9 秒。
func telegraph_scale() -> float:
	return 1.0


## 这一招是不是"基本招"——一关什么都没配的时候，怪兽默认会的那一招。
##
## 角色由招式自己声明，而不是模板里写一个名字：模板一旦写下默认招的名字，
## 就又多了一处要跟着改的地方。有且只该有一招回答 true。
func is_basic() -> bool:
	return false


## 这一招是不是"慢招"——走第二个、更慢的计时器那一路。同样是角色不是名字。
func is_heavy() -> bool:
	return false


## 打出去。子类必须实现 —— 基类这里故意什么都不做而不是报错：一个还没写完的
## 招应该是"这一次它没出手"，不是把整场战斗炸掉。
func fire(_arena) -> void:
	push_warning("attack.gd: %s 没有实现 fire()" % id())
