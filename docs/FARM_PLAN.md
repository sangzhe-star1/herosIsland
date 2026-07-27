# 星光菜园 · 接入前审计与基础改造规划

> 本文只是**审计与计划**。没有写任何菜园代码，没有改动任何现有文件，没有提交。
> 审计日期 2026-07-27，代码基线 `6e6f3e0`（34 条关卡 / 109 个 `.gd` / 34594 行 GDScript）。
> 所有结论都带 `文件:行号`，可以逐条复核。

---

## 0. 一句话结论

**菜园可以安全接入，但不能"直接接"。** 现有系统在四个地方是干净的（发奖有唯一入口、货币有单一实现、存档有原子写入和双代回退、模板结算有现成信号），在三个地方是空白的（**没有任何统一时间管理**、没有库存系统、没有可注入的关卡宿主），在**五个地方埋着会咬人的坑**——其中一个（`creative_play` 的存档 key 写死为 `"base"`）如果照直复用，**会在孩子第一次进菜园时抹掉他在英雄基地摆了很久的东西**。

首期垂直切片的真正工作量不在"种菜"，在**先把时间这一层从零建起来**，并且把它建成可注入假时钟的形状——否则你列的 17 条验收标准里有 4 条（#5 #7 #8 #9）根本没法写测试。

---

# 一、当前项目审计结果

## 1. 存档入口、格式、路径

| 项 | 结论 | 佐证 |
|---|---|---|
| 唯一写盘函数 | `save_game()` | `scripts/core/save_manager.gd:419` |
| 路径 | `user://save_game.json` | `save_manager.gd:7` |
| 备份 | `user://save_game.bak`（上一代）、`user://save_game.tmp`（写入中转） | `save_manager.gd:10, 17` |
| 格式 | **JSON，tab 缩进**，不是 ConfigFile 不是二进制 | `save_manager.gd:427` |
| 写入协议 | 写 tmp → 现有档轮转为 bak → tmp 原子 rename 就位 | `save_manager.gd:419-433` |
| 家长导出 | `user://heroes_island_progress_<日期>.json`，再尽力复制到 Downloads/Documents | `save_manager.gd:784, 801-833` |

**写盘入口唯一，写内存入口不唯一。** `SaveManager.data` 是 public，五个文件直接改字典再自己调 `save_game()`：`shop_manager.gd:208/234/417/503/530`、`currency_manager.gd:56/67`、`wishlist_manager.gd:59/70`、`preset_manager.gd:152`。这个模式本身没坏，但它意味着**没有任何地方能拦截"存档被改了"这件事**——菜园的节流保存必须自己实现，不能指望框架。

## 2. save_version 与旧存档迁移

**版本号存在，但是装饰品。**

```gdscript
save_manager.gd:18    const SAVE_VERSION := 1
save_manager.gd:222   loaded["version"] = SAVE_VERSION      # 只写，从不读
```

全项目**没有任何 `if version < N` 的分支**。所有迁移的幂等性靠一次性标志位或数据自身形态，不靠版本号。

已有四个迁移，全部挂在 `_settle_after_load()`（`save_manager.gd:233-239`）：

| # | 函数 | 位置 | 幂等靠什么 |
|---|---|---|---|
| 1 | `_refund_spent_stars()` | `:603-610` | `spent_stars > 0` 判断 + 做完置 0 |
| 2 | `_rename_old_monsters()` | `:393-416` | id 是否已在 `GameData.monsters` 里（自幂等） |
| 3 | `_move_wardrobe_in()` | `:276-324` | 标志位 `shop.wardrobe_moved` |
| 4 | `_split_wardrobes()` | `:334-365` | 标志位 `shop.wardrobe_split` |

**默认值合并逻辑在 `_migrate()`（`save_manager.gd:213-223`），它只补两层：**

```gdscript
for key in base.keys():
    if not loaded.has(key):
        loaded[key] = base[key]                      # 第一层
    elif base[key] is Dictionary and loaded[key] is Dictionary:
        for sub in base[key].keys():
            if not loaded[key].has(sub):
                loaded[key][sub] = base[key][sub]    # 第二层，到此为止
```

| 新增字段深度 | 老档能否自动补全 |
|---|---|
| 顶层（`farm`） | ✅ |
| 二层（`farm.plot_count`） | ✅ |
| **三层及以下（`farm.plots[0].water_level`）** | ❌ **补不到** |
| **数组里的元素**（`plots` 是数组） | ❌ **永远补不到** |

这是本次规划里**最硬的一条约束**，直接决定第三节的存档设计。

还有一个已经存在的敞口：`_migrate` 只看 `has(key)` 不看类型。老档里如果 `"rewards"` 是 `[]` 或 `null`，`_migrate` 不会修，随后 `data["rewards"]["coins"]` 在 autoload 阶段直接崩。全文件有大量硬下标（`:498 :536 :563 :724 :750 :762 :772 :919`）。

## 3. 星章 / 经验 / 金币 / 星星币在哪里维护

游戏里一共 **7 种数值**：

| # | 名称 | 存档字段 | 维护者 | 谁能增 | 谁能减 | 性质 |
|---|---|---|---|---|---|---|
| 1 | **关卡星章** | `levels[id].stars` | `save_manager.gd:482-493` | `record_level_result()`，`maxi()` 单调 | **无人可减** | **永久成绩** |
| 2 | **星星币** | `rewards.coins` | `shop/currency_manager.gd` | `Coins.earn()` | `Coins.spend()` | **可消费货币** |
| 3 | 经验 xp | `profile.xp` | `save_manager.gd:554` | `add_xp()`，只加非负 | 无 | 永久成绩 |
| 4 | 徽章 | `rewards.badges[]` | `save_manager.gd:765` | `add_badge()` 幂等 | 无 | 永久成绩 |
| 5 | 世界星章 | **不存盘，实时求和** | `shop_manager.gd:134-138` | 派生 | — | 派生视图 |
| 6 | 成长属性 | `growth.{courage,...}` | `save_manager.gd:773` | `add_growth()` | 无 | 永久成绩 |
| 7 | 战斗道具 | `rewards.items{id:count}` | `save_manager.gd:615-634` | `add_item()` | `use_item()` | 可消耗库存 |

**"星章不能消费"已经是既成事实**：`spend_stars()` 在 `save_manager.gd:591-594` 被改成 `push_error` 硬报错并返回 false；老档的 `rewards.spent_stars` 由迁移 #1 一次性等额退成星星币。`tools_check.py:486-489` 还有一条静态规则禁止任何人再调用它。

**但星星币的"单一入口"是有洞的**——`SaveManager` 上留着两个平行后门，且都有生产代码在用：

| 后门 | 位置 | 谁在用 | 危害 |
|---|---|---|---|
| `add_coins()` | `save_manager.gd:535-538` | `minigames/platformer.gd:1241` | **不 emit `progress_changed`**，币章 UI 显示过期数字 |
| `spend_coins()` | `save_manager.gd:740-746` | `ui/reward_center.gd:565` | 与 `Coins.spend()` 重复的第二份实现 |

`tools_check.py:472-494` 的规则 5e 只匹配**直接写字典**（`data["rewards"]["coins"] =`），**函数调用完全不触发**，而且把 `save_manager.gd` 整个文件豁免了。所以这两个后门在静态检查里是隐形的。

## 4. 奖励是否有统一发放接口

**有，而且是真正的单一入口。** `RewardManager` 是 autoload（`project.godot:26`），`grant_for_level()` 全项目**只有一个调用点**：

```
模板 complete_level()                level_manager.gd:191-199
  └─ emit level_completed(result)     :197   ← 已存在的挂点，当前无人监听
  └─ await 1.2s
  └─ GameManager.finish_level(result) :199
       ├─ RewardManager.grant_for_level(result)   game_manager.gd:52  ← 唯一发奖口
       ├─ SaveManager.bump_challenge_rank()       :56
       ├─ flush_playtime()                        :57
       └─ SceneManager.goto_scene(ResultScreen)   :59  ← 硬编码
```

`ResultScreen` 是**纯展示层**，只读 `RewardManager.last_*`，不发奖（`result_screen.gd:68/81/90/101`）。所以在结算页退出不会丢奖励。

发奖顺序有一条关键不变量，注释写在 `reward_manager.gd:32-35`：**必须先读 `previous` 和算 bonus，再 `record_level_result()`**，否则每一项首次奖励都在和自己比，永远付不出来。

**奖励来源共 11 条**，6 条走 RewardManager，5 条不走：

不走的 5 条里有一个休眠的刷币口：`minigames/platformer.gd:1236-1241` 每次通关全额重发沿途金币，没有任何 `previous` 对比，也不走 `Coins.earn()`。当前 `levels.json` 里 **0 关**用 `platformer`，所以是死代码——但 `game_data.gd:164` 仍映射着场景，任何人加一关 `"game_type": "platformer"` 就立刻激活它，且 tools_check 和 shop_probe 都不会报警。

## 5. 英雄小屋购买与库存怎么保存

全部在 `data.shop`（`save_manager.gd:153-174`）：

```jsonc
"owned":  [],       // 一维 id 列表 —— 衣服属于孩子，不属于某个英雄
"worn":   {},       // character_id -> {slot: item_id} —— 每个英雄一套
"presets": ["","",""],   // 三套搭配，值是 JSON.stringify 的字符串
"wishlist": [],     // 最多 5 件
"seen_new": [], "bundles_done": [], "free_gift_taken": false
```

**购买是"先扣钱后给货"，且不原子**（`shop_manager.gd:171-185`）：`Coins.spend()` 内部已经 `save_game()` 写过一次盘，`_grant()` 再写第二次。两次之间崩溃 = 钱扣了货没到。`save_game()` 本身原子，但**跨两次 save 的业务事务不原子**。

撤销购买（5 秒全额退，`shop_manager.gd:214-236`）：先从 `owned` 移除 → **遍历所有角色**把该件从 `worn` 各槽清空 → `Coins.refund()` → 保存。顺序是刻意的（先脱后退钱），`undo()` 第二次调用直接 return false，幂等。

⚠️ `undo()` **不校验这件东西是不是花钱买的**。`grant_free()` 白送的也在 `owned` 里，将来若有 UI 对免费物调 `Shop.undo()`，会按标价白送一笔币。当前不可达，但是未设防的不变量。

## 6. 怪兽图鉴解锁怎么保存

`rewards.album`，一维字符串数组（`save_manager.gd:80`）。唯一写入口 `record_meeting()`（`:651-661`）**天然去重**——已有就返回 false，所以"重复击败不重复入册"是结构性保证，不是判断出来的。

两个触发点：`minigames/monster_duel.gd:1009`、`adventure/adventure.gd:771-774`。

历史迁移在 `save_manager.gd:379-416`：10 个旧怪兽 id 全部作废，靠 `MONSTER_RENAMES` 表按"同一个世界、同一个位置"换成新卡，没有继任者的**显式丢弃**。三个安全设计值得菜园照抄：

1. `if known.is_empty(): return false` —— **目录没加载成功就绝不动存档**（`:400-401`）
2. 重建新数组而不是原地改，顺带去重
3. 靠 autoload 顺序（`GameData` 排在 `SaveManager` 前）保证目录一定先就绪

## 7. 世界地图和英雄基地怎么注册新入口

⚠️ **先纠正一个术语错位**，这会影响你对工作量的判断：

| 你说的 | 实际是什么 | 位置 |
|---|---|---|
| **英雄基地** | 一条**关卡**，`id = hero_studio`，`game_type = creative_play` | `data/levels.json:972-987` |
| **英雄小屋** | 换装商店屏 | `scripts/shop/hero_house_screen.gd`（955 行） |
| **我的奖励** | 图鉴 + 徽章 + 贴纸 + 成长条，同一个 ScrollContainer 里的卡片 | `scripts/ui/reward_center.gd` |

**这个项目没有"房间注册表"这种抽象。** 常驻房间 = 一条特殊关卡 + **散落在 4 个文件里的 `if id == "hero_studio"` 豁免**：

| 豁免 | 位置 | 作用 |
|---|---|---|
| ① | `result_screen.gd:294-298` | 世界通关判定跳过它 |
| ② | `shop_manager.gd:125-129` | 商店解锁条件的世界通关判定跳过它 |
| ③ | `save_manager.gd:671-680` | 全岛完成度分母跳过它 |
| ④ | `tools_check.py:334` | 玩法多样性统计跳过它 |

**加菜园作为第二个常驻房间，会让这 4 处各自变成两元素判断。** 建议先在 `levels.json` 引入 `"room": true` 字段，把 4 处统一改成读字段——这是 20 行的重构，但它是加房间之前该做的事，不是之后。

首页（`scripts/ui/home.gd`）现在 4 个按钮，`grid.columns = 2`（`:27`）。**加第 5 个按钮必须同时改列数**，否则最后一行只剩一个按钮靠左，视觉断裂。首页按钮**没有任何解锁机制**，四个按钮永远可见——要做"通关世界 1 才解锁菜园"得自己写。

世界地图的 `game_type → 图标` 映射表在 `world_map.gd:423-442`，`tools_check.py:410-425` 强制每个 `game_type` 都得有图标，漏了直接报 error。

## 8. 九种模板哪些可以复用于菜园

**先说结构性判断：模板是"关卡专用"，不是"可嵌入组件"。**

| 证据 | 位置 |
|---|---|
| 配置从**全局单例**读，没有注入口 | `level_manager.gd:24` — `GameManager.current_level_data()` |
| 完成时**硬调**全局结算 | `level_manager.gd:199` |
| 结算又**硬跳**结果页 | `game_manager.gd:59` |
| 退出**硬跳**世界地图 | `level_manager.gd:209` |

**但有两条好消息：**

1. `signal level_completed(result)` **已经存在，且发射时机正确**——在 `await 1.2s` 和 `finish_level()` **之前**（`level_manager.gd:12, 197`）。外面已经能拿到结果，只是当前没人监听。
2. **模板作为子节点 `instantiate()` 已被两个探针证明可行**：`tests/touch_probe.gd:73-76`（5 个模板）、`tests/studio_probe.gd:56-60`（两种视口各跑一遍）。

**要让菜园内嵌小游戏并自己发奖，只需要在 `level_manager.gd` 抽三个 seam，约 10 行，不动任何一个模板文件**（详见第四节）。

复用可行性逐条：

| 菜园玩法 | 目标模板 | 可复用度 | 需要什么 |
|---|---|---|---|
| 灌溉管道／阳光镜面 | `puzzle_mechanism` | 🟢 **零改造** | `pipes`/`mirrors` 本来就是内置两种（`:49, 106-120, 175-199`），写 config 就能玩 |
| 作物分拣／送食物 | `matching_sorting` | 🟢 **零改造** | `bins` + `items` 全数据驱动（`:78-145`） |
| 订单装箱（每箱 N 个） | `matching_sorting` | 🟢 **1 行** | `DragField.add_slot()` 已支持 `capacity`（`drag_field.gd:61-67`），只是 `matching_sorting.gd:95` 没传 |
| 照顾小鸟／病株 | `roleplay_rescue` | 🔴→🟢 **6 行即可全数据化** | `const CASES` 7 条写死（`:26-41`），改 `:70` 读 `config.cases` + `_trouble_icon()` 读字段。**投入产出比最高的一处重构** |
| 摆放土地／围栏／稻草人 | `creative_play` | 🟡 **3 个 config 字段** | ⚠️ **见下方 P0 陷阱** |
| 找杂草／害虫／缺水地 | `observation_search` | 🟡 **2 字段 + 图标** | `config.icon` 是单个字符串（`:63`），要改成 `targets: [{icon,count}]`；`const SPOTS` 12 个写死屏幕坐标（`:33-37`）要参数化，否则东西不会落在菜地格子上 |
| 番茄支架／围栏／水井／温室 | `build_repair` | 🔴 **必须改代码** | `BLUEPRINTS` 只有 bridge/tower/robot/ship（`:41-63`），每加一种造型要动 3 处：常量表 + `_draw_part()` match + `_run_the_machine()` match |
| 配送作物／找稀有种子 | `platform_adventure` | 🟡 **成本最高** | "找种子"用现成的 `gem`/`collect` 节拍；"配送"没有对应节拍需新增。2291 行 + 虚拟摇盘 + 物理循环，嵌入成本远高于其他模板 |

### ⚠️ P0 陷阱：`creative_play` 的存档 key 写死为 `"base"`

```gdscript
creative_play.gd:120    SaveManager.get_creation("base")
creative_play.gd:152    SaveManager.set_creation("base", out)
creative_play.gd:153    SaveManager.set_setting("base_light", _light)
```

**菜园如果复用 `creative_play` 而不加 `creation_key` 配置，孩子在英雄基地摆的东西会在他第一次进菜园后消失。** 这是本次审计里唯一一个会造成**用户数据丢失**的复用陷阱。

## 9. 拖放 / 吸附 / 手势教学 / 提示 / 语音 / 成功反馈是否已公共化

| 能力 | 公共化程度 | 位置 |
|---|---|---|
| **拖放 + 自动吸附** | 🟢 **有，且是核心资产** | `shared/drag_field.gd`（306 行）。`GRAB=84`（抓取半径比物体大，因为拇指会盖住目标）、`SNAP=118`（松手落附近就"咔哒"归位）、拖动时物体抬到手指**上方 34px** 避免遮挡、拿起瞬间所有可用槽位呼吸发光、最近的那个 alpha 拉满 |
| **三级提示** | 🟢 **有，且自适应** | `shared/hint_director.gd`（142 行）。11 秒空闲或**第一次做错**就升级；连续 3 关无提示则空闲阈值 ×1.45（`clean_streak`）；三个 Callable 注入，任意界面可复用 |
| **手势教学** | 🟡 **有，但每次都演** | `shared/tutorial_director.gd`（120 行）。`add_step(看哪, 点哪)`，距离 > 30px 自动演成拖动否则演成点击。**存档里没有任何"教学已看过"字段**；`skip()` 定义了但**无调用点** |
| **重玩变化** | 🟢 有 | `shared/variant_picker.gd`。种子 = `level_id#通关次数`，保证首次通关全球一致（可测）、重玩不同、中途退出续玩不变 |
| **语音** | 🟢 有统一入口 | `AudioManager.say(name)`（`audio_manager.gd:104`），按 `.ogg/.wav/.mp3` 顺序试。缺文件**静默失败，是设计意图**。权威清单是 `docs/VOICE_SCRIPT.md`（63 句），`tools_check.py:751-765` 会对没登记的 id 报警告 |
| **成功反馈** | 🟢 有 | `ui/juice.gd`（270 行）：`burst` 纸屑 / `pop` 挤压回弹 / `nudge` 轻晃（唯一的失败反馈）/ `dust` / `shockwave` / `no_sign`。铁律：**奖励动效大方，纠正动效吝啬**；全部可关（`reduce_motion`）；**没有屏幕震动，也不会有** |
| **结算页** | 🟢 公共一份 | `ui/result_screen.gd`（340 行）服务所有模板 |
| **星星飞入** | 🔴 **不公共**，三份手写 | `result_screen.gd:328`（星星弹出）、`:187`（金币飞 chip，79 行）、`observation_search.gd:227`（物件飞 HUD） |
| **长按** | 🔴 **零基础设施** | 全项目唯一长按是家长门（`home.gd:203-235`，`button_down` + `_process` 累加 + ProgressBar），是私有实现不可复用 |
| **园艺图标** | 🔴 **一个都没有** | `icon_library.gd` 98 个 id 里没有 seed/sprout/flower/watering_can/soil/pot。最接近的只有 `leaf`、`carrot`、`berries` |

⚠️ `creative_play.gd:219-241` 和 `hero_house_screen.gd` **各自重写了一套一模一样的拖放状态机**，没走 DragField。菜园别成为第三份。

## 10. 是否存在统一时间管理

**没有。这是最大的空白。**

全项目 `Time.` 只有 9 处裸调，**没有 GameClock、没有 TimeService、没有任何封装**：

| 位置 | 调用 | 用途 |
|---|---|---|
| `game_manager.gd:16, 27` | `get_ticks_msec()` | 会话计时（重启归零） |
| `save_manager.gd:41` | `get_unix_time_from_system()` | `profile.created_at` —— **写了但全项目零读者** |
| `save_manager.gd:802, 807` | 日期字典/字符串 | 备份文件名与 `exported_at` |
| `save_manager.gd:918, 924` | `get_date_string_from_system()` | `playtime` 的日期 key |
| `tests/lesson_film.gd:59,62` | `get_ticks_usec()` | 录屏工具 |

**依赖真实时间的功能只有一个**：每日游玩时长上限（`game_manager.gd:115-119` → `save_manager.gd:923`）。用本机本地日期，改设备时钟即可绕过；`playtime` 字典**只增不清**，玩一年就是 365 个 key 常驻内存并参与每次全量写盘。

**没有任何"到期时间 / 冷却结束时刻"式的持久化时间戳**，而且这是刻意的：`tools_check.py:499-508` 有一条规则，扫到商店数据里出现 `expires` / `limited_time` / `countdown` 直接构建失败。

> 📌 **这意味着菜园会引入这个代码库里的第一个真正的持久化时钟依赖。** 在动手之前值得确认一次策划口径：菜园是"真实时间生长"还是"通关次数推进"？后者和现有的 `challenges` rank、`levels_this_session` 完全同构，风险约等于零；前者要新开一整套不变量。本文按**真实时间**规划，因为"关掉游戏胡萝卜还在长"正是菜园的情感核心。

**顺带发现一个现有 bug**：`game_manager.gd:19-31` 只处理 `NOTIFICATION_APPLICATION_PAUSED`，**不处理 RESUMED**。`get_ticks_msec()` 在 iOS 挂起期间照常走，所以**后台放 3 小时再回来，下一次 flush 会把这 3 小时全记进"今日游玩时长"，直接误触每日上限**。GameClock 必须一并修掉。

## 11. 退出重进后如何恢复状态

autoload 顺序即 `_ready()` 顺序（`project.godot:20-29`）：

```
GameData → SaveManager(_ready 里 load_game) → I18n → AudioManager
         → RewardManager → GameManager → SceneManager → TouchSparkles
```

两个硬依赖：**GameData 必须在 SaveManager 前**（迁移要读目录）、**SaveManager 必须在 I18n 前**（I18n 从存档读 locale）。

**恢复策略是"写穿"**：每个 mutation 立刻 `save_game()`（全项目 20+ 处）。这依赖一条不变量——**任何攒着不写的状态，退出就丢**。

损坏回退链（`load_game()`，`save_manager.gd:108-125`）：主档 → `.bak` → 两代都坏则**静默重开新档**（只 `push_warning`，UI 上没有任何提示）。家长导出的第三份备份**不参与自动回退**。

⚠️ **`_settle_after_load()` 不跑在全新档上**（`:122-125` 走另一分支）。新档要到**第二次启动**才会跑一轮迁移。菜园的初始化逻辑如果放进迁移，新玩家第一次进去会看到空地。

## 12. 当前测试脚本覆盖哪些内容

- **`tests/run_smoke.sh`**（427 行）串起 **19 个独立 Godot 进程**。失败判定两层：`no_script_errors()`（`:102-112`，grep `SCRIPT ERROR|Parse Error`，因为 Godot 把脚本错误打到 stdout 但**退出码仍是 0**）+ 每个 probe 的 `XXX PROBE PASSED` 标记。
- **`tests/smoke_test.gd`**（270 行）：数据完整性、图标可构建、计分规则、**重玩变差不得扣星**、7 个固定屏 + **每一关**都实例化跑 6 帧、越界检查。
- **18 个 probe**，重点几个：`save_probe`（**撕裂档从 backup 恢复**）、`shop_probe`（456 行，**买东西永远不能动关卡星章**、5 个奖励源只付一次）、`hero_house_probe`（733 行，**试穿必须免费**、老档迁移不丢付费物、**两种屏形**）、`album_probe`（**每张卡都能靠玩拿到**，从 levels.json 反查）、`map_probe`（植入重构前老存档、**每个世界每一关**都实例化）、`studio_probe`（**iPad 4:3 拖拽**，带窗口像素→视口坐标换算）。
- **`tools_check.py`**（1017 行，28 条规则，61 个 error 检查点）。

### 测试体系自身的三个缺陷（菜园动手前建议先修）

1. **三处 `no_script_errors` 在读已删除的文件**：`run_smoke.sh:167`（Tap）、`:191`（Difficulty）、`:213`（Upgrade）——`rm -f` 排在检查之前，grep 对不存在的文件返回非 0，函数静默通过。**这三个 probe 的脚本错误检查完全失效。**
2. **无 xvfb 的 headless Linux 上整个脚本会崩**：`:9` 有 `set -u`，而 `TAP_OUT` 只在 `:149` 条件成立时才赋值，`:167` 却在 `if` 块外面 → `unbound variable`，且退出码非 0，看起来像测试失败实际是环境问题。
3. **`NextProbe` 从未接入** `run_smoke.sh`（`BattleProbe`/`DuelProbe` 是有意封存，有注释；`NextProbe` 是纯遗漏）。

### 193 条警告的构成

| 类型 | 数量 | 性质 |
|---|---:|---|
| `strings.json` 定义了但没被引用 | **173** | i18n 预写文案 / 已下线模板的遗留 key（**占 89.6%**） |
| **写死接近 720 的 y 坐标** | **11** | **4:3 适配债，下一个 iPad bug 的候选名单** |
| tab 后混空格 | 8 | `roleplay_rescue.gd:28-40` 占 7 条 |
| 拿不到的徽章 | 1 | |

> `README.md:350` 和 `CHANGELOG.md:887` 都还写着 `0 errors, 0 warnings`，与现状不符，文档已过时。

---

# 二、可以复用的系统

**不需要新建、直接用**：

| 需求 | 用什么 | 位置 |
|---|---|---|
| 拖种子到土地 + 自动吸附 | `DragField` | `shared/drag_field.gd` |
| 卡住了给三级提示 | `HintDirector.watch(nudge, show, do_it)` | `shared/hint_director.gd:39` |
| 第一次进来演一遍怎么玩 | `TutorialDirector.add_step()` | `shared/tutorial_director.gd:35` |
| 每次进来不一样 | `VariantPicker.for_level()` | `shared/variant_picker.gd:117` |
| 收获的庆祝 | `Juice.burst/pop/shockwave/dust` | `ui/juice.gd` |
| 做错了的轻提示 | `Juice.nudge`（**不要用红色、不要用叉**） | `ui/juice.gd:113` |
| 发星星币 | `Coins.earn(amount, reason)` | `shop/currency_manager.gd:52` |
| 关卡结算页 | `ResultScreen` 公共一份 | `ui/result_screen.gd` |
| 休息提示 | `RestDirector.should_offer()`，已自动挂在结算页 | `shared/rest_director.gd:40` |
| UI 外壳 | `UiKit.world_background / play_area / big_button / back_button / picture` | `ui/ui_kit.gd` |
| 触摸/鼠标统一判定 | `UiKit.is_press() / is_release()` | `ui/ui_kit.gd:581` |
| **浇水音效** | `res://assets/audio/water.ogg` **已存在且在用** | `build_repair.gd:280` |
| 图鉴式"只解锁一次" | `record_meeting()` 的集合去重模式 | `save_manager.gd:651` |
| 存档原子写入 + 双代回退 | `save_game()` / `load_game()` | `save_manager.gd:419, 108` |

**存在但必须参数化**（改动都很小，但不改就会出问题）：

| 项 | 现状 | 要改成什么 | 不改的后果 |
|---|---|---|---|
| `DragField` 吸附阈值 | `SNAP = 118` 是 `const`（`:31`） | per-slot 参数或实例变量 | **地块中心间距若小于 118px，会吸到隔壁地块** |
| `DragField` 音效 | 拿起写死 `coin.ogg`（`:150`）、吸附写死 `correct.ogg`（`:235`） | 可注入 | 种子拿起来"叮"一声像捡到钱 |
| `DragField` 一次性语义 | `item["placed"]` 是布尔，**没有取出/移除 API** | 新增 `release(slot)` | 收获后地块无法重新播种 |
| `TutorialDirector` | 每次进关都演，存档无字段 | 加 `settings.tutorial_seen_<id>`，并把 `skip()` 真正接上 | 孩子第 20 次进菜园还要看一遍演示 |
| `HintDirector` 语音 | 写死 `hint_%d`（`:77`） | 可配前缀 | 菜园说不了"先浇水再种" |
| `RestDirector.new_session()` | **定义在 `:55` 但全项目零调用**，`levels_this_session` 跨启动累加 | 在 `boot.gd` 或 `GameManager._ready()` 补一行 | 休息提示的计数永远不清零 |

---

# 三、必须先补齐的基础模块

你列了 8 个模块。对照代码，**其中 3 个已经存在**（不要重复造），**3 个是升级现有的**，**只有 2 个是真正的新建**——外加 1 个你没列但必须有的。

| 你列的模块 | 判定 | 现状与动作 |
|---|---|---|
| **CurrencyManager** | ✅ **已存在，只需收口** | `shop/currency_manager.gd` 80 行纯静态，`earn/spend/refund/can_afford/short_by` 齐全，防透支干净。**动作**：删掉 `SaveManager.add_coins()`（`:535-538`）和 `spend_coins()`（`:740-746`）两个后门，把仅有的两个调用方（`platformer.gd:1241`、`reward_center.gd:565`）改走 `Coins`；`tools_check.py:480-494` 补两条正则抓函数调用，并把 `save_manager.gd` 从豁免名单里拿掉 |
| **RewardManager** | 🟡 **已存在，需加一个通用口** | autoload 单一入口，但签名死绑 `LevelResult`，只处理"打完一关"。**动作**：新增 `grant(source: String, payload: Dictionary) -> Dictionary`，菜园订单走它；`grant_for_level()` 内部改成调用它，保证只有一条发币路径 |
| **AdaptiveHintManager** | 🟡 **已存在（HintDirector），只需参数化** | 已经自适应（`clean_streak` 连续 3 关无提示则放宽 1.45 倍）。**动作**：语音 id 前缀可配 |
| **InteractionTutorialManager** | 🟡 **已存在（TutorialDirector），缺"看过"记忆** | **动作**：加存档字段 + 接上 `skip()` |
| **SaveMigrationManager** | 🟠 **雏形存在，必须升级** | `_migrate()` + `_settle_after_load()` 是雏形，但①只补两层②不看版本号③不看类型④不跑在新档上。**动作**：见第五节 |
| **InventoryManager** | 🔴 **新建** | 最接近的雏形是 `save_manager.gd:615-634` 的 `add_item/use_item/item_count`（`use_item` 自带"没有就返回 false"的原子扣减，这个模式直接抄）。**但不要复用 `rewards.items` 本身**——那是战斗药水，被 `item_shop.gd` 和 3 个 minigame 直接引用 |
| **GameClock** | 🔴 **新建，且是首期最关键的一块** | 全项目零基础。见下 |
| **OfflineProgressCalculator** | 🔴 **新建** | 建议做成**无状态纯函数模块**（`extends RefCounted`，全 static），输入 `(plot, elapsed_seconds, crop_def)` 输出新 plot 状态。纯函数才好测，17 条验收里有 4 条靠它 |
| **HoldGesture**（你没列，但必须有） | 🔴 **新建** | "长按浇水"零基础设施。需要处理 ScreenTouch/MouseButton、抖动容差（手指微动不算取消）、可视进度环。**必须走 `gui_input`**（`tools_check.py:665-687` 规则 3a3 会抓），且 `UiKit.is_press()` 不给坐标，要顺手把 `_press_position()` 提到 UiKit（现在有 **6 份几乎相同的副本**：`observation_search.gd:211`、`puzzle_mechanism.gd:223`、`light_defense.gd:685`、`memory_rhythm.gd:220`、`roleplay_rescue.gd:209`、`world_map.gd:313`） |

## GameClock 必须提供的接口与必须一并修的东西

```gdscript
# autoload，排在 SaveManager 之后
now_unix() -> int          # 唯一的真实时间读取点
now_date() -> String        # 唯一的日期字符串来源
ticks_ms() -> int
elapsed_since(stamp: int) -> int    # 已钳制：不为负，不超过 MAX_OFFLINE
is_new_day(last_stamp) -> bool
# 测试注入
set_test_now(t: int)        # 仅 probe 使用
```

必须一并迁移/修复：

| 现有用法 | 位置 | GameClock 要解决什么 |
|---|---|---|
| 后台挂起把 3 小时算进游玩时长 | `game_manager.gd:19-31` | **补 `NOTIFICATION_APPLICATION_RESUMED`**，resume 时重置会话起点 |
| `playtime` 日期 key | `save_manager.gd:918, 924` | 统一日期源；顺手加旧日期裁剪（现在只增不清） |
| `daily_limit_reached()` | `game_manager.gd:115` | 走同一个日期源 |
| Android 返回键 | 全项目零匹配 | `NOTIFICATION_WM_GO_BACK_REQUEST` 未处理 |
| `RestDirector.new_session()` | `rest_director.gd:55` | 由"距上次活动超过 N 分钟 = 新会话"驱动，并在 `boot.gd` 接上 |

> **给 tools_check 加一条规则**：`scripts/garden/*.gd` 里除 GameClock 外禁止直接出现 `Time.get_*`。没有单一入口就无法注入假时钟，#5 #7 #8 #9 四条验收全部不可测。`get_ticks_msec()` 尤其致命——它是**会话相对**的，重启归零，直接违反 #6。

---

# 四、现有玩法复用方案

## 4.1 三个 seam：让模板可嵌入（约 10 行，只改 `level_manager.gd`）

```gdscript
# ① :24 — 配置可注入
var injected_level_data: Dictionary = {}
var embedded := false

func _ready() -> void:
    level_data = injected_level_data if not injected_level_data.is_empty() \
        else GameManager.current_level_data().duplicate(true)

# ② :191-199 — 完成时的去向可托管
func complete_level() -> void:
    ...
    level_completed.emit(result)          # 已有，:197
    await get_tree().create_timer(1.2).timeout
    if embedded:
        return                            # 奖励与去向交给宿主
    GameManager.finish_level(result)

# ③ :202-209 — 退出的去向可托管
func quit_level() -> void:
    ...
    if embedded:
        level_completed.emit(result)
        return
    SceneManager.goto_world_map()
```

菜园用法（照抄 `touch_probe.gd:73-76` 的写法）：`instantiate()` → 设 `injected_level_data` 和 `embedded = true` → `add_child()` → 连 `level_completed` → 自己发奖、自己 `queue_free()`。

**三个必须同时处理的全局副作用**：

1. `build_world()`（`level_manager.gd:95`）会画一整屏背景，**嵌进菜园会盖住菜园**——需要一个"跳过背景"的开关，或宿主 `hide()` 掉 Stage
2. `HintDirector.record_run()` 会写全局 `clean_streak`（`hint_director.gd:111-114`）
3. `VariantPicker.for_level()` 用关卡 id 当种子（`variant_picker.gd:117`）——嵌入时需要给一个稳定的伪 id

## 4.2 每个菜园活动接哪个模板

| 菜园活动 | 模板 | config 长什么样 | 改造 |
|---|---|---|---|
| 找杂草／害虫／成熟果实／缺水地 | `observation_search` | `{targets: [{icon:"weed", count:4}], spots: [...菜地格子坐标], bonus: "ladybug"}` | 2 字段 + 新图标 |
| 作物分拣 | `matching_sorting` | `{bins: [{key:"carrot", icon:"carrot"}], items: [...]}` | 0 |
| 订单装箱 | `matching_sorting` | 同上 + 每个 bin 的 `capacity` | 1 行 |
| 给怪兽送食物 | `matching_sorting` | bins 换成怪兽头像 | 0 |
| 番茄支架／围栏／水井／温室 | `build_repair` | `{machine: "trellis"}` | **每种造型 3 处**；建议先把 `config.blueprint` 做成可整份覆盖 `BLUEPRINTS[_kind]`（改 `:74-77` 四行），让槽位坐标数据驱动 |
| 灌溉管道／阳光镜面 | `puzzle_mechanism` | `{puzzle: "pipes", steps: 4}` | **0** |
| 照顾受伤小鸟／生病植物 | `roleplay_rescue` | `{cases: [{who:"bird", trouble_icon:"bandage", right:"bandage", wrong:[...]}]}` | **6 行**，改完这个模板就全数据驱动了 |
| 配送作物／寻找稀有种子 | `platform_adventure` | 种子用现成 `gem`/`collect` 节拍；配送需新增 `deliver` 节拍 | 中等，建议放到二期 |
| 摆放土地／家具／围栏／稻草人 | `creative_play` | `{stickers: [...], creation_key: "garden", backdrop: "farm"}` | **3 字段，`creation_key` 是 P0** |

## 4.3 提示 / 奖励 / 结算绝不复制

你的要求"不要为每一个菜园小游戏重新复制一套独立的提示、奖励和结算代码"，在架构上这样落地：

| 关注点 | 唯一归属 | 菜园怎么用 |
|---|---|---|
| 提示 | `HintDirector` | 每个嵌入活动传自己的三个 Callable，**不新建提示逻辑** |
| 发币 | `Coins.earn()`（经 `RewardManager.grant()`） | 菜园任何地方**不得**出现 `data["rewards"]["coins"]`，静态规则 5e 会拦 |
| 入库 | `InventoryManager` | 收获、订单奖励、种子购买，**一个入口** |
| 结算 | 菜园自己的轻量结算条（不跳 ResultScreen） | 嵌入活动结束 → `level_completed` → 菜园把 `result` 翻译成"这次除掉了 4 棵杂草" → `RewardManager.grant("garden:weeding", {...})` |
| 教学 | `TutorialDirector` | 每个活动一组 `add_step()`，**看过一次就不再演** |

---

# 五、推荐存档结构与旧存档迁移

## 5.1 一个必须先做的决定：`currencies` 建议不要新增

你列的字段里有 `currencies`。**我的建议是不加这个顶层字段，菜园收益直接进 `rewards.coins`**，理由三条：

1. `tools_check.py:486-494` 的"星星币只能从一个地方进出"这条静态不变量，只覆盖 `rewards.coins`。新开一个货币容器等于在检查器视野外再造一套钱。
2. `_merge_progress()`（`save_manager.gd:877-912`）是**逐字段手写**的 best-of 合并。新字段不加进去，家长跨设备导入备份时会**静默丢失**。coins 已经在里面了。
3. `docs/DESIGN_NOTES.md:132` 已经明确写了"三种货币，一种都不能互换"是刻意的上限——第四种要向孩子解释。

如果你坚持要 `currencies`，那它应该是**视图而非存储**：`currencies.coins` 只读代理到 `rewards.coins`，将来真需要第二种货币时再落盘。本文按"不新增"规划，你说一声我改。

## 5.2 推荐结构

```jsonc
{
  "save_version": 2,          // ← 新增。第一次真正被读的版本号
  "version": 1,               // ← 保留原字段不动，避免任何旧代码路径受影响

  "farm": {
    "farm_level": 1,
    "plot_count": 4,
    "plots": [ /* 见 5.3 */ ],
    "warehouse": {},            // crop_id -> 数量
    "unlocked_crops": ["carrot", "corn", "strawberry", "tomato"],
    "unlocked_recipes": [],
    "decorations": [],
    "completed_missions": [],
    "npc_friendship": {},       // npc_id -> 好感度整数
    "last_seen_at": 0,          // 上次离开菜园的 GameClock 时间戳
    "clock_high_water": 0       // 见过的最大时间戳，防倒拨用
  },

  "inventory": {},              // item_id -> 数量（种子、工具、材料）
  "farm_orders": {
    "active": [],               // [{order_id, npc_id, wants:{crop:n}, reward_coins, issued_at}]
    "delivered": []             // 已交付的 order_id 列表 —— 防重复领奖的唯一依据
  },
  "farm_visitors": {},          // 二期，首期建空 dict 占位
  "farm_unlocks": {}            // feature_id -> bool
}
```

## 5.3 每块土地

```jsonc
{
  "plot_id": "plot_1",
  "crop_id": "",              // "" = 空地
  "tilled": false,            // ← 你的首期含"松土"，需要这个字段
  "planted_at": 0,
  "last_updated_at": 0,       // 上次结算到哪个时刻
  "growth_stage": 0,          // 0..4，共 5 个阶段
  "growth_progress": 0.0,     // 当前阶段内 0.0..1.0
  "water_level": 1.0,         // 0.0..1.0
  "care_event": "",           // "" | "thirsty" | "weeds" | "pests"
  "care_completed": false,
  "ready_to_harvest": false
}
```

## 5.4 ⚠️ 两层合并的硬约束，以及怎么绕过去

`_migrate()` 只补两层，**而 `plots` 是数组——数组元素永远补不到**。所以：

**必须做两件事，缺一不可：**

1. **把 `_migrate()` 升级成 schema 驱动的深合并**，同时补上类型校验：
   ```gdscript
   # 新增：类型不对就整个换成默认值。这一行同时修掉现有全部字段的同类风险
   elif typeof(loaded[key]) != typeof(base[key]):
       loaded[key] = base[key]
   ```
2. **每块地在读取时过一遍 `_plot_defaults()` 规范化**，不依赖 migrate：
   ```gdscript
   static func normalise(raw: Dictionary) -> Dictionary:
       var p := PLOT_DEFAULT.duplicate(true)
       for k in p.keys():
           if raw.has(k) and typeof(raw[k]) == typeof(p[k]):
               p[k] = raw[k]
       return p
   ```
   **所有读 plot 的路径都走它。** 这样将来给 plot 加字段（比如二期的 `greenhouse`），老档自动拿到默认值，不需要写新的迁移。

> 顺带建议给 tools_check 加一条 warning：`_default_data()["farm"]` 的字典嵌套不得超过两层——这条规则的存在本身就是在提醒未来的自己为什么要有 `normalise()`。

## 5.5 迁移方案

```gdscript
# _settle_after_load() 里追加，紧跟现有四个迁移之后
changed = _open_the_farm() or changed
```

```gdscript
func _open_the_farm() -> bool:
    # 目录没加载成功就绝不动存档 —— 抄 _move_wardrobe_in():289-291
    if GameData.crops.is_empty():
        return false
    var farm: Dictionary = data.get("farm", {})
    if bool(farm.get("opened", false)):
        return false                       # 一次性标志位，抄 wardrobe_moved
    # 只给当前角色开，不复制给所有人 —— 抄 _split_wardrobes 的教训
    ...
    farm["opened"] = true
    data["save_version"] = 2
    return true
```

**四条从历史事故里抄来的纪律：**

| 纪律 | 出处 |
|---|---|
| 目录空就 return false，什么都不动 | `save_manager.gd:289-291, 400-401` |
| 一次性标志位，不靠版本号 | `wardrobe_moved` / `wardrobe_split` |
| **不要把一份数据复制给所有角色** | `save_manager.gd:300-306` 的事后剖析——第一版给 14 个英雄穿了同一套衣服，补救花了第二个迁移函数 |
| 换 id 必须配改名表，无继任者显式决定丢弃还是保留 | `MONSTER_RENAMES:379` / `OUTFIT_RENAMES:256` |

**新档要单独处理**：`_settle_after_load()` 不跑在全新档上（`:122-125`），所以 `_default_data()` 里必须直接带一个开好的 4 块空地，不能指望迁移。

## 5.6 非法时间处理

| 情况 | 处理 | 理由 |
|---|---|---|
| `now < last_updated_at`（时钟倒拨） | `elapsed = 0`，**不推进也不倒退**；若倒拨超过 60 秒宽限，把 `last_updated_at` 重锚到 `now` | 不产生负进度（你的第 6 条）；重锚是为了**不因为一次倒拨永久卡死** |
| `now` 大幅前进 | `elapsed = min(elapsed, MAX_OFFLINE)`，建议 **8 小时** | 你的第 7 条。8 小时够覆盖"睡一觉起来" |
| 连续多次前进刷奖 | **结构性防御，不靠钳制**：成熟即封顶（`ready_to_harvest = true` 后不再变化），收获是**消耗型**（清空地块），订单靠 `delivered[]` 去重 | 时间跳多远，最多也只是"全部成熟一次" |
| 时区变化 | 所有时间戳一律 unix 秒（UTC），只有 `playtime` 用本地日期 | 现有 `playtime` 已经是本地日期，不动它 |

## 5.7 作物永不枯死

```
water_level 随时间衰减 → 触底为 0 → 生长暂停，care_event = "thirsty"
                                    ↑ 这是终点，没有"死亡"这个状态
```

**离线期间最多进入两种状态**：`ready_to_harvest`（可以收获）或 `care_event != ""`（等待帮助）。这两个都是可恢复的。**`crops.json` 里不允许出现任何 `dies_after` 之类的字段**，建议加进 tools_check 的赌博词表同款检查。

## 5.8 保存时机（菜园必须自己节流）

现有系统是"每个 mutation 立刻全量写盘"，一关结算就写 5~7 次。菜园的生长是连续的，**绝不能每帧或每秒 `save_game()`**。

| 时机 | 写盘 |
|---|---|
| 松土 / 播种 / 浇水 / 除草 / 收获 | ✅ 立即 |
| 订单交付、领奖 | ✅ 立即（**在任何 `await` 之前先写 `delivered[]`**） |
| 离开菜园场景 | ✅ 立即 |
| `NOTIFICATION_APPLICATION_PAUSED` / `WM_CLOSE_REQUEST` | ✅ 立即 |
| 生长 tick / 每帧刷新 | ❌ **绝不** |

生长不需要存盘，因为它是**从时间戳算出来的**，不是累加出来的。这也顺带解决了你的第 12 条验收（玩主线时继续成长）——不是"后台在跑"，是"回来的时候算一次"。

---

# 六、首期菜园页面线框

见随附的 `FARM_WIREFRAME.svg`（1280×720 与 1280×960 两档并排）。要点：

```
┌────────────────────────────────────────────────────────────┐
│ [←]  星光菜园                              🪙 128  🌟 42    │  ← 顶栏 96px
├────────────────────────────────────────────────────────────┤
│                                                             │
│      ┌─────────┐  ┌─────────┐                              │
│      │ plot_1  │  │ plot_2  │      ☁                       │
│      │  🥕 ●●○ │  │  空地   │                              │
│      └─────────┘  └─────────┘                              │  ← 2×2 地块
│      ┌─────────┐  ┌─────────┐                              │    中心间距
│      │ plot_3  │  │ plot_4  │   [NPC 订单板]               │    ≥ 260px
│      │  💧缺水 │  │  ✓可收  │    🐻 想要 3 根胡萝卜         │    (远大于
│      └─────────┘  └─────────┘        🪙 12                  │     SNAP=118)
│                                                             │
├────────────────────────────────────────────────────────────┤
│  🪏松土   🌱种子架: 🥕 🌽 🍓 🍅    💧浇水   ✋除草   🧺仓库  │  ← 工具架 168px
└────────────────────────────────────────────────────────────┘
```

**六个必须遵守的约束**（全部来自现有代码或历史事故）：

1. **地块中心间距 ≥ 260px** —— `DragField.SNAP = 118`，间距小于 236 就会吸到隔壁地块
2. **一切坐标从 `get_viewport_rect().size` 量起**，绝不写死 720 —— 这个 bug 在这个项目**上线过两次**，`tools_check.py:689-729` 有专门规则
3. **播放区用 `UiKit.play_area(self, true)` + `gui_input`**，绝不用 `_unhandled_input` —— 全屏 `MOUSE_FILTER_STOP` 会吃掉 `InputEventScreenTouch`，**鼠标能用、iPad 不能用**（`tools_check.py:665-687`）
4. **图标是主角，文字是注脚** —— 六岁孩子不识字。地块状态用图形表达（进度环、水滴、感叹号），不用文字
5. **顶栏币数用现成的财宝角标样式**，收获时金币飞过去（照 `result_screen.gd:187` 的 `_fly_coins_to_chip`）
6. **返回按钮 `UiKit.back_button()`**，回英雄基地不回世界地图

---

# 七、首期核心循环

```
                     ┌──────────────────┐
                     │  进入菜园         │
                     │  GameClock.now()  │
                     │  结算离线成长 ×1  │  ← 一次，不是每帧
                     └────────┬─────────┘
                              ▼
   ┌──────────────────────────────────────────────┐
   │  看四块地：空地 / 生长中 / 缺水 / 可收获       │
   └───┬──────────┬──────────┬──────────┬─────────┘
       ▼          ▼          ▼          ▼
   ┌───────┐  ┌───────┐  ┌───────┐  ┌────────┐
   │ 松土  │→ │ 播种  │  │ 浇水  │  │ 收获   │
   │ 点一下 │  │ 拖种子│  │ 长按  │  │ 点一下 │
   │       │  │ +吸附 │  │ +进度环│  │ +飞入 │
   └───────┘  └───────┘  └───────┘  └───┬────┘
                                          ▼
                                    ┌──────────┐
                                    │ 进仓库   │
                                    │warehouse │
                                    └────┬─────┘
                                         ▼
                                 ┌───────────────┐
                                 │ NPC 订单板     │
                                 │ 凑够 → 交付    │
                                 └───────┬───────┘
                                         ▼
                                 ┌───────────────┐
                                 │ Coins.earn()  │
                                 │ delivered[] ✓ │  ← 写在 await 之前
                                 └───────┬───────┘
                                         ▼
                                 ┌───────────────┐
                                 │ 三关一次       │
                                 │ 休息提示       │
                                 └───────────────┘
```

**五个成长阶段**：种子 → 发芽 → 长叶 → 结果 → 成熟。每阶段时长从 `crops.json` 读，首期建议 4 种作物差异化：胡萝卜最快（适合第一次上手，孩子当天就能收），番茄最慢。

**离线成长只在两个时刻结算**：进入菜园时、从后台恢复时。**不在 `_process` 里跑。**

---

# 八、新增和修改文件清单

## 8.1 新建（15 个）

| 文件 | 行数估计 | 说明 |
|---|---:|---|
| `scripts/core/game_clock.gd` | ~120 | **autoload**，排在 SaveManager 之后。唯一的 `Time.*` 读取点，带 `set_test_now()` |
| `scripts/garden/offline_growth.gd` | ~150 | 无状态纯函数：`(plot, elapsed, crop_def) -> plot`。17 条验收里 4 条靠它 |
| `scripts/garden/garden_manager.gd` | ~300 | 菜园状态机：松土/播种/浇水/除草/收获，全部返回 bool |
| `scripts/garden/garden_screen.gd` | ~450 | 主界面 |
| `scripts/garden/plot_view.gd` | ~200 | 单块地的渲染与交互 |
| `scripts/garden/order_board.gd` | ~180 | NPC 订单板 |
| `scripts/garden/inventory_manager.gd` | ~120 | 统一库存，抄 `use_item()` 的原子扣减模式 |
| `scripts/shared/hold_gesture.gd` | ~140 | 长按（浇水），带抖动容差与进度环 |
| `scenes/garden/Garden.tscn` | — | |
| `data/crops.json` | — | 4 种作物 × 5 阶段 |
| `data/garden_orders.json` | — | 3 个 NPC 订单模板 |
| `tests/garden_probe.gd` + `.tscn` | ~400 | 主力探针，14 个检查 |
| `tests/garden_touch_probe.gd` + `.tscn` | ~180 | 两种屏形的拖拽吸附 |
| `docs/FARM_PLAN.md` | — | 本文 |

## 8.2 修改（21 处）

### 必改 · 基础层

| 文件 | 改什么 | 优先级 |
|---|---|---|
| `scripts/core/save_manager.gd:35-105` | `_default_data()` 加 `save_version` / `farm` / `inventory` / `farm_orders` / `farm_visitors` / `farm_unlocks` | P0 |
| `scripts/core/save_manager.gd:213-223` | `_migrate()` 加**类型校验**（一行修掉全部现有字段的同类风险） | P0 |
| `scripts/core/save_manager.gd:233-239` | `_settle_after_load()` 追加 `_open_the_farm()` | P0 |
| `scripts/core/save_manager.gd:877-912` | `_merge_progress()` 加菜园字段；**顺手补上现有的 bug**：重写 `levels[id]` 时丢了 `found_hidden`（`:881-887`），导致家长导入一次备份，隐藏宝石的 5 币奖励可以再拿一遍 | P0 |
| `scripts/core/save_manager.gd:535-538, 740-746` | **删掉 `add_coins()` / `spend_coins()` 两个后门** | P1 |
| `scripts/minigames/platformer.gd:1241` | 改走 `Coins.earn()`（顺带堵住那个休眠的刷币口） | P1 |
| `scripts/ui/reward_center.gd:565` | 改走 `Coins.spend()` | P1 |
| `scripts/core/game_manager.gd:19-21` | 补 `NOTIFICATION_APPLICATION_RESUMED` 与 `WM_GO_BACK_REQUEST` | P1 |
| `scripts/reward/reward_manager.gd` | 新增通用 `grant(source, payload)` | P1 |
| `project.godot` | 注册 `GameClock` autoload | P0 |

### 必改 · 复用层

| 文件 | 改什么 | 优先级 |
|---|---|---|
| `scripts/level/level_manager.gd:24, 191-209` | 三个 seam：`injected_level_data` / `embedded` | P1（二期用，首期可延后） |
| `scripts/shared/drag_field.gd:29-33, 150, 235` | SNAP 阈值可配、音效可注入、新增 `release(slot)` | P0 |
| `scripts/shared/tutorial_director.gd` | "看过一次"记忆 + 接上 `skip()` | P1 |
| `scripts/ui/icon_library.gd:40-73` + `_draw()` | 新增园艺图标：`seed` `sprout` `watering_can` `weed` `soil` `basket` `fence` `scarecrow` | P0 |
| `scripts/ui/home.gd:27, 45` | 加菜园入口 + **改 `grid.columns`** | P0 |
| `scripts/core/game_data.gd:26-38` | 加载 `crops.json` / `garden_orders.json`（**不加就是 error**，规则 5j） | P0 |
| `data/strings.json` | `garden.*` 文案，**en + zh 两份都要**（缺一报 error） | P0 |

### 必改 · 检查与测试

| 文件 | 改什么 | 优先级 |
|---|---|---|
| `tools_check.py:702-703` | 3a4 扫描目录加 `scripts/garden/*.gd`——**不加则菜园的写死 720 完全不被检出**，而菜园正是网格布局，是 4:3 最容易出事的形态 | P0 |
| `tools_check.py:271-274` | 规则 4 的 namespace 白名单加 `garden`——不加会双向出错：刷假警告 + **漏掉真正的缺 key error** | P0 |
| `tools_check.py` | 新增 5o~5t 六条规则（见第十节） | P1 |
| `tests/run_smoke.sh:167, 191, 213` | **修掉三处 `no_script_errors` 读已删文件**，以及 `set -u` 崩溃 | P0 |
| `tests/run_smoke.sh` | 挂 GardenProbe（**排在 AlbumProbe 之后、SaveProbe 之前**） | P0 |
| `tests/smoke_test.gd:184-192` | `screens` 数组加菜园场景 | P0 |

## 8.3 建议顺手做（不做也能上，但会越拖越贵）

| 事项 | 位置 | 理由 |
|---|---|---|
| `levels.json` 引入 `"room": true`，把 4 处 `hero_studio` 字符串豁免统一改成读字段 | `result_screen.gd:296`、`shop_manager.gd:127`、`save_manager.gd:674`、`tools_check.py:334` | 菜园是第二个常驻房间，不做就变成 4 处两元素判断 |
| `_press_position()` 提到 `UiKit` | 现有 6 份副本 | 长按手势要用第 7 份 |
| `RestDirector.new_session()` 接上 | `rest_director.gd:55` | 定义了从未被调用，计数永远不清零 |
| 清掉 `profile.outfit` / `wear_outfit()` 等僵尸 API | `save_manager.gd:47, 731` | `wear_outfit()` 仍会往已迁移的存档写脏数据，而 `wardrobe_split` 已 true 永不再清理。**一颗仍在膛内的子弹** |

---

# 九、分阶段开发计划

**一个阶段一次交付，跑完整套检查 + 实机截图，你看过再进下一阶段。** 首期不实现：NPC 拜访、悄悄摘一颗、加工小屋、大量食谱、菜园扩建、16 种作物、复杂装饰、真实网络玩家、排行榜。

### 阶段 0 · 地基（不出菜园，但后面每一步都靠它）

- `GameClock` autoload + `set_test_now()`
- `_migrate()` 类型校验 + `save_version`
- 修 `run_smoke.sh` 三处失效检查 + `set -u` 崩溃
- `tools_check.py` 两处扫描范围（`scripts/garden/`、`garden` namespace）
- 收口货币后门（删两个函数，改两个调用方，补两条静态规则）
- 修 `_merge_progress` 丢 `found_hidden` 的 bug
- 补 `NOTIFICATION_APPLICATION_RESUMED`
- **交付**：`tools_check` 0 errors、全套 probe 全绿、**并且证明后台挂起 3 小时不再误算游玩时长**（这是阶段 0 唯一的"看得见"的成果）

### 阶段 1 · 存档结构与迁移（仍然没有 UI）

- `_default_data()` 六个新字段、`_open_the_farm()` 迁移、`plot.normalise()`
- `data/crops.json` 4 种作物、`game_data.gd` 加载
- `tests/garden_probe.gd` 的**前 3 个检查**：老档升级不丢主线/衣服/图鉴、新档拿到 4 块空地、跑两次不翻倍
- **交付**：探针输出 + **故意把存档写成"没有 farm 字段的老档"跑一次证明迁移生效**

### 阶段 2 · 生长与离线（仍然没有 UI）

- `offline_growth.gd` 纯函数 + 5 阶段推进
- 时间倒退、时间前进、上限钳制、永不枯死
- `garden_probe` 的时间四检查（#5 #7 #8 #9）
- **交付**：注入假时钟的探针输出，逐条对应你的验收标准

### 阶段 3 · 菜园主界面与四块地

- `Garden.tscn` + `garden_screen.gd` + `plot_view.gd`
- 松土、播种（拖拽吸附）、浇水（长按）、除草、收获
- `hold_gesture.gd`、园艺图标、`DragField` 参数化
- 首页入口 + 改列数 + 返回英雄基地
- **交付**：1280×720 与 1280×960 **两档实机截图**各 4~6 张 + `garden_touch_probe` 全绿

### 阶段 4 · 仓库与 3 个 NPC 订单

- `inventory_manager.gd`、订单板、`RewardManager.grant()` 通用口
- 订单去重（`delivered[]`）、星星币入账
- **交付**：截图 + 探针（**订单不能重复领奖**、**星星币精确增加**、**关卡星章一字不差**）

### 阶段 5 · 收尾与完整回归

- 自然休息提示接入
- 全套 18+2 个 probe + `tools_check` + 30 关完整回归
- **交付**：完整测试输出 + 全套截图，等你确认后才提交

---

# 十、回归测试计划

## 10.1 你的 17 条验收标准 vs 现有体系

| # | 验收标准 | 现状 | 怎么补 |
|---|---|---|---|
| 1 | 新存档可以正常进入菜园 | 🟡 加一行 | `smoke_test.gd:184-192` 的 `screens` 数组加菜园场景，自动获得实例化+存活+越界检查 |
| 2 | 旧存档升级不丢主线/衣服/图鉴 | 🟡 有范式无实例 | 新写 `_an_old_save_grows_a_garden()`，范式抄 `hero_house_probe.gd:79`、`map_probe.gd:41` |
| 3 | 4 块地独立种植 | ❌ | 新写 |
| 4 | 同一块地不能重复播种 | ❌ | 新写，断言第二次 `plant()` 返回 false 且**不扣种子** |
| 5 | 作物成长阶段正确 | ❌ | 新写，注入时钟逐阶段验证，**边界前一秒不得进阶** |
| 6 | 退出重进后状态恢复 | 🟡 有范式 | 抄 `shop_probe.gd:436-444`（save→load 往返） |
| 7 | 玩主线期间作物继续成长 | ❌ | 新写：播种后**不把菜园加进场景树**，推进时钟，再实例化，断言阶段已推进 |
| 8 | 时间倒退不会异常 | ❌ | 新写 |
| 9 | 时间前进不会无限领奖 | ❌ **最关键** | 新写：前进 10 天收获 N，再前进 10 天不重新播种必须拿到 0 |
| 10 | 收获数量正确进入仓库 | ❌ | 新写 |
| 11 | 订单不能重复领奖 | 🟡 有范式 | 抄 `shop_probe.gd:183` `_bonuses_pay_once` 与 `album_probe.gd:148-150` |
| 12 | 星星币正确增加 | 🟡 规则已在 | 静态侧 `tools_check.py:490-494` 已强制走 CurrencyManager |
| 13 | **关卡星章不会变化** | ✅ **已被三重保护** | `shop_probe.gd:60`、`unlock_probe.gd:77-86` 的 `_fingerprint()`、`tools_check.py:486-489`。菜园版直接抄 `_fingerprint()` |
| 14 | 作物不会永久死亡 | ❌ | 新写：成熟后再推 30 天仍可收获 |
| 15 | 触摸拖动和自动吸附正常 | 🟡 范式完备 | 抄 `studio_probe.gd:129-162` 的 `_glass()` 窗口像素→视口坐标换算，**两种屏形各跑一遍** |
| 16 | 菜园能正常返回英雄基地 | ❌ | 新写（现有体系**没有任何 probe 按过返回按钮**） |
| 17 | 现有 30 关完整回归通过 | ✅ **已覆盖** | `map_probe.gd:74-130` + `smoke_test.gd:196-204` |

**合计：完全覆盖 2 条，有范式可低成本补齐 6 条，完全空白 9 条。**

## 10.2 `tests/garden_probe.gd` 的 14 个检查

```
_a_new_child_finds_four_empty_plots()          #1 #3
_planting_twice_in_one_plot_is_refused()       #4   ← 失败不得扣种子
_the_four_plots_do_not_share_state()           #3
_stages_advance_on_the_clock()                 #5   ← 边界前一秒不得进阶
_it_survives_being_closed()                    #6
_it_grows_while_he_is_playing_a_level()        #7
_a_clock_set_backwards_does_not_break_it()     #8
_a_clock_set_forward_pays_once()               #9   ← 先写这条
_harvest_lands_in_the_barn()                   #10
_an_order_pays_once()                          #11
_the_garden_pays_coins_through_currency()      #12
_the_garden_cannot_touch_stars()               #13  ← 和 #9 一起先写
_a_crop_never_dies()                           #14
_an_old_save_grows_a_garden()                  #2
```

**收尾必须**：`duplicate(true)` 全量快照 + 还原 + `save_game()`（抄 `progression_probe.gd:20, 26-27`，这是全项目唯一做对的），并显式复位 `character_id`（`hero_house_probe.gd:51-52` 的教训——存档跨进程存活，一个 probe 留下的状态会让下一个失败）。

**挂载位置**（照正确写法，先检查后删文件）：

```bash
GARDEN_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/GardenProbe.tscn 2>&1 | tee "$GARDEN_OUT"
if ! grep -q "GARDEN PROBE PASSED" "$GARDEN_OUT"; then rm -f "$GARDEN_OUT"; exit 1; fi
no_script_errors "$GARDEN_OUT" "Garden Probe"     # ← 在 rm 之前
rm -f "$GARDEN_OUT"
```

## 10.3 tools_check 新增规则

| id | 抓什么 | 级别 | 为什么 |
|---|---|---|---|
| **5o** | `scripts/garden/*.gd` 里除 GameClock 外禁止 `Time.get_*` | error | 没有单一入口就无法注入假时钟，4 条验收不可测 |
| **5p** | 菜园目录禁止 `record_level_result` / `data["levels"]` / `add_badge` / `bump_challenge_rank` | error | #13 的静态版 |
| **5q** | `crops.json`：id 唯一、`stages ≥ 2`、每阶段 `duration > 0`、`yield > 0`、`name_key` 可解析 | error | `duration = 0` 会让阶段判定除零或瞬间成熟 |
| **5r** | `garden_orders.json` 只引用存在的作物，`reward > 0` | error | 与图鉴的"每张卡都能赚到"同构——领不了的订单是永远灰着的承诺 |
| **5s** | `_default_data()` 必须含 `farm` key | error | #2 的静态保险 |
| **5t** | `_default_data()["farm"]` 嵌套不得超两层 | warn | 直接对应 `_migrate()` 的实现限制 |

## 10.4 30 关回归

现有 `map_probe.gd:74-130` 已经会把**每个世界的每一关**实例化并跑 10 个物理帧。菜园改动如果碰了 `level_manager.gd`（三个 seam）或 `drag_field.gd`（吸附参数），**这条回归是唯一能证明没弄坏的东西**，每个阶段都必须跑。

---

# 十一、风险清单

按"会不会造成不可逆损害"排序。

## P0 · 会造成用户数据丢失

| # | 风险 | 触发条件 | 防御 |
|---|---|---|---|
| 1 | **菜园布局覆盖英雄基地布局** | 复用 `creative_play` 而不加 `creation_key` 配置——存档 key 写死为 `"base"`（`creative_play.gd:120, 152`） | 阶段 3 之前先加 `config.creation_key`；`garden_probe` 断言摆完菜园后 `get_creation("base")` 一字不差 |
| 2 | **迁移把一份数据复制给所有角色** | 菜园若有"每个英雄一块地"维度，照直写 `for each character: farm[c] = 初始数据` | 只给 `profile.character_id` 建，其余惰性创建。这是 `save_manager.gd:300-306` 已经栽过一次的跟头，补救花了第二个迁移函数 |
| 3 | **老档类型损坏在 autoload 阶段崩溃** | `_migrate` 只看 `has(key)` 不看类型，老档里 `"farm"` 是 `[]` 或 `null` | 阶段 0 就加类型校验（一行），同时修掉现有全部字段 |
| 4 | **家长导入备份丢菜园** | `_merge_progress()` 是逐字段手写，新字段不加进去就静默丢失 | 阶段 1 加进去；`save_probe` 加断言 |

## P1 · 会造成不可逆的经济损害

| # | 风险 | 触发条件 | 防御 |
|---|---|---|---|
| 5 | **改系统时间无限刷币** | 收获或订单是"累加型"而非"消耗型" | 结构性防御：成熟即封顶、收获清空地块、订单靠 `delivered[]` 去重。**先写 `_a_clock_set_forward_pays_once()` 这条测试，再写功能** |
| 6 | **订单连点两次发两次币** | 交付流程里有 `await`（动画、语音），而 `delivered[]` 写在 await 之后 | **在任何 await 之前先写 `delivered[]` 并 `save_game()`** |
| 7 | **关卡星章被误改** | 菜园数据挂到 `levels` 下 —— `record_level_result()` 是**整条字典整体覆写**（`:485-491`），任何不在字面量里的新字段重玩一次就被抹掉；而 `total_stars()` 是遍历求和不校验 key 来源，塞伪条目会虚高星数进而错误解锁世界和商店 | 菜园数据一律建在 `levels` 之外的顶层；`_fingerprint()` 断言 |
| 8 | **休眠刷币口被激活** | 任何人加一关 `"game_type": "platformer"`，`platformer.gd:1241` 每次通关全额重发沿途金币，tools_check 和 shop_probe 都不会报警 | 阶段 0 改走 `Coins.earn()` 顺手堵掉 |

## P2 · 会造成"孩子用不了但大人看不出来"

| # | 风险 | 触发条件 | 防御 |
|---|---|---|---|
| 9 | **iPad 上拖不动** | 用 `_unhandled_input` 而非 `gui_input`——全屏 `MOUSE_FILTER_STOP` 吃掉 `InputEventScreenTouch`，**鼠标能用、iPad 不能用**，是最难在开发机上发现的一类 bug | `tools_check.py:665-687` 规则 3a3 会抓，前提是**扫描目录加上 `scripts/garden/`** |
| 10 | **4:3 上东西飘在屏幕四分之一处** | 写死接近 720 的 y 坐标。这个 bug 在这个项目**上线过两次**，现在还有 11 处存量 | 同上，规则 3a4；`garden_touch_probe` 两种屏形各跑一遍 |
| 11 | **种子吸到隔壁地块** | 地块中心间距 < 236px（`SNAP = 118` × 2） | 线框已按 ≥ 260px 设计；probe 断言吸附到**正确**地块中心 |
| 12 | **菜园整个不存在** | `crops.json` 同步了，加载它的 `game_data.gd` 那一行留在另一台机器上——**这个事故发生过**（怪兽图鉴），症状是"我看不到" | 规则 5j 自动覆盖（`data/*.json` 必须在 `game_data.gd` 里出现）。**另外：本轮已经发生过两次"文件只在沙箱里"的事故，同步后必须逐个 `wc -c` 核对** |
| 13 | **播种音效是静音的** | `play_sfx()` 打不存在的文件不报错 | 规则 5l 自动覆盖（error 级）；浇水音效 `water.ogg` 已存在可直接用 |
| 14 | **孩子第 20 次进菜园还要看演示** | `TutorialDirector` 每次都演，存档无"看过"字段 | 阶段 3 加字段 |

## P3 · 工程债

| # | 风险 | 说明 |
|---|---|---|
| 15 | **存档写放大** | 现在一关结算写 5~7 次全量 `JSON.stringify` + 两次 rename；`playtime` 永不清理；`shop.owned` 已 92 件。菜园必须自己节流，框架不会帮你 |
| 16 | **probe 顺序耦合** | 现在靠 `run_smoke.sh` 的执行顺序而不是隔离来避免污染。GardenProbe 必须排在 AlbumProbe 之后、SaveProbe 之前（SaveProbe 故意以空档收尾） |
| 17 | **`hero_studio` 豁免散落 4 处** | 加第二个常驻房间会变成 4 处两元素判断。建议先做 `"room": true` 重构 |
| 18 | **`wear_outfit()` 仍能写脏数据** | 旧 API 还活着，而 `wardrobe_split` 标志位已 true 永不再清理。菜园别制造第二个这样的僵尸——要接管旧字段就一次性删干净，或改成 `push_error` 硬报错 |

---

# 等你确认的六件事

1. **菜园是"真实时间生长"还是"通关次数推进"？** 本文按真实时间规划。选后者的话，阶段 0 和阶段 2 几乎可以砍掉，风险降到接近零，但"关掉游戏胡萝卜还在长"这件事就没有了。
2. **`currencies` 顶层字段要不要加？** 我建议不加，星星币仍走 `rewards.coins`（理由见 5.1）。
3. **菜园入口放首页还是世界地图？** 首页最省事但要改列数且没有解锁机制；走世界地图则免费获得解锁链，但要做 `"room": true` 重构。
4. **离线上限定 8 小时可以吗？** 够覆盖"睡一觉起来"，又不至于一次拨表全部成熟。
5. **首期要不要嵌入小游戏？** 本文把 `level_manager` 三个 seam 排在 P1、二期用。首期只做松土/播种/浇水/除草/收获五个原生交互，不嵌任何模板——这样阶段 3 的风险面小很多。
6. **阶段 0 的"顺手修"要不要一起做？** 那些 bug（后台挂起误算时长、`_merge_progress` 丢 `found_hidden`、三处失效的脚本错误检查、休眠刷币口）都不是菜园引入的，但菜园会踩在它们上面。我建议一起修，代价约半个阶段。

**在你确认之前，我不会写任何菜园代码，也不会提交。**
