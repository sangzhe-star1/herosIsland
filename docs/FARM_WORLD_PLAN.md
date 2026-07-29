# 星光菜园 → 星光农场 · 审计与空间化改造方案

> 状态：**只是方案，一行代码都还没动。** 等你确认后从阶段 1 开始。
> 配套线框图：`docs/FARM_WORLD_WIREFRAME.svg`
> 上一轮的审计和首期方案在 `docs/FARM_PLAN.md`，验收对账在 `docs/FARM_ACCEPTANCE.md`，本文只写**这次改造**新增的部分。

---

## 0. 一句话结论

**数据层几乎不用动，表现层要重写。**

生长、离线、水位、杂草、订单、幂等、存档修复这一整套已经是纯函数 + 状态机 + 事务号，
质量足够撑起 QQ 农场那套循环。真正缺的是三件东西，而且都在表现层：

1. **一个能平移缩放的世界**（这个项目至今没有一个 `Camera2D`，全部是 Control + 视口尺寸）
2. **一个笔刷式的连续作业系统**（现在一次点击 = 一块地）
3. **一条钱的出口**（现在只有订单能换钱，出售、买种子、扩地全没有）

下面十四节，前面是审计，后面是你要的 13 项设计。

---

## 0.1 开工前必须你拍板的六件事

| # | 事情 | 我的建议 | 为什么要问你 |
|---|---|---|---|
| **A** | **工具栏和"点一下就做对事"冲突** | 保留"点 = 做对的事"，工具栏是**附加**的批量笔刷，第一个按钮是常亮的「手」 | 这条是你上次拍板的第 4 条（"交互都是一下，只有播种要拖"），理由写在 `garden_screen.gd:4-19`：**给六岁孩子一个工具栏，就制造了"拿着铲子浇水，没反应，不知道为什么"这种他调不出来的失败**。硬加工具栏会把这条推翻，我不想默默推翻它 |
| **B** | **目录叫 `scripts/farm/` 还是继续 `scripts/garden/`** | 继续 `scripts/garden/` | `tools_check.py` 有一条规则的作用域写死是 `scripts/garden/*.gd`（禁止出现 `Time.get_*`，必须走 GameClock）。**新建 `scripts/farm/` 会让新代码静悄悄逃出这条检查** |
| **C** | **首页要不要加第五个大按钮** | 加，同时保留世界地图上的房间入口 | 你截图指的是首页。但上次拍板第 3 条是"入口走世界地图常驻房间"。两个入口都指向 `GameManager.start_level("star_garden")`，不冲突，只是首页 2×2 要变 2×3，两种屏形都得重新截图 |
| **D** | **「悄悄摘一颗」多久能摘一次** | **等小熊自己的作物长好**（真实时间，和你的地一个算法），不要"每天一次" | "每天一次 + 午夜刷新" = 连续登录奖励的变体，是你自己定的儿童红线里明令禁止的那一类。用生长时间做门槛，错过了不损失任何东西 |
| **E** | **`crops.json` 里的 `harvest_gesture` 现在是死数据** | 菜园批量收菜用"滑过即收"，per-crop 手势只在丰收行动和「悄悄摘一颗」里有意义 | 四种作物各写了 `pull_up`/`swipe_down`/`tap_each`，**菜园代码一次都没读过**。要么接上（和"连续滑动收菜"冲突），要么明确标成丰收专用。我建议后者 |
| **F** | **你列的 `data/farm_visit_log.json`** | 拆成两个：`data/farm_visit_texts.json`（模板句，只读）+ 存档里的 `farm.visit_log`（真实记录） | `data/` 是随版本发布的只读游戏数据，`GameData` 在 `_ready()` 里加载。**访客记录写进 `data/` 的话，下次更新会把孩子的记录整个覆盖掉。** 同理 `data/farm_dog.json` 只能放小狗的配置，不能放小狗的状态 |

---

# 一、审计结果

按你列的 10 项，逐条。

## 1.1 `farm_screen.tscn` 场景树 —— 没有这个文件

真实入口链是：

```
data/levels.json  →  {"id": "star_garden", "world": "sunny_park",
                      "game_type": "garden", "room": true, "config": {}}
GameData.get_minigame_scene("garden")  →  "res://scenes/garden/Garden.tscn"
Garden.tscn（全文 6 行，一个 Node2D 挂脚本）
scripts/garden/garden_screen.gd（1164 行，extends LevelManager）
```

**场景树几乎不存在**：`Garden.tscn` 只有一个根节点，屏幕上的每一个像素都是 `_rebuild()`
在运行时 `new()` 出来的。这对改造是**好事** —— 没有 `.tscn` 里硬编码的坐标要迁移。

`_rebuild()` 的做法是**整屏重建**（`garden_screen.gd:150`）：先把所有 Control / DragField
`queue_free()`，再画顶栏 → 地块 → 订单板 → 种子架 → 仓库。理由写在 `:22-27`：四块地不值得
做 diff，而重建是唯一能保证"浇完水还挂着口渴徽章"不发生的做法。

**空间化之后这条要改。** 世界里有 6~8 块地 + 9 个设施 + 一只会跑的狗，整屏重建会
把狗的位置、相机位置、正在进行的笔刷全部抹掉。方案见 §5.4。

## 1.2 四块土地节点和数据绑定

没有"节点"，只有一个循环：

```gdscript
func _plot_beds(view):            # :243
    _field = DragField.new()
    for i in range(plots.size()):
        _one_bed(plots[i], i, _bed_centre(i))
```

`_one_bed()` 现场造一个 `Button` + 作物图 + 进度环 + 徽章，`bed.pressed` 连到
`_tap_plot(index)`。绑定靠 **index**，不靠 plot_id。

`_bed_centre(index)`（`:590`）**每次都从视口量**，绝不用硬编码的 720 ——
注释说这个坑在这里翻过两次（`aspect=expand` 下 4:3 平板拿到的是 1280×960 视口）。

`BED_GAP := DragField.SNAP * 2.0 + 26.0`（`:49`）= **262**，是算出来的不是看着定的。
低于这个数，两块地会抢同一次投放。**这个数在缩放世界里会出事，见 §4.3。**

## 1.3 土地状态机

`scripts/garden/farm_save.gd:43-60`，**一个词，六个状态**：

```
EMPTY → TILLED → SEEDED → GROWING ⇄ NEEDS_CARE → READY →（收获）→ TILLED
```

`HARVESTING` **故意不落盘**（`:50-55`）：它只活在动画期间，写进存档的话，动画中途关平板
会让那块地永远卡死。它现在存在 `garden_screen._harvesting` 这个内存字典里。

你要的 11 个状态和它的对应关系：

| 你列的 | 现有 | 怎么办 |
|---|---|---|
| EMPTY / TILLED / SEEDED / READY | 同名 | 直接用 |
| SPROUT / GROWING | `GROWING` + `growth_stage` 0..4 | **不要加新状态**。`growth_stage` 已经能区分，加 `SPROUT` 就是加第七个会互相矛盾的字段（`farm_save.gd:32-42` 把三个 bool 合并成一个词就是为了避免这个） |
| NEEDS_WATER / HAS_WEED | `NEEDS_CARE` + `care_event ∈ {"", "thirsty", "weeds"}` | 用现有的两级表示 |
| HAS_BUG | **没有** | 新增 `care_event = "bug"`，走同一条 `Growth.wants()` 通道 |
| GOLDEN_READY | **没有** | 新增 `plot.golden: bool`（见 §6.3），**不新增状态词** |
| HARVESTED | 内存里的 `_harvesting` | 保持内存，不落盘 |

**结论：状态机只加一个 `care_event` 取值 `"bug"`，加一个 bool。表现层的 11 种画法映射到
"状态 + 3 个字段"，映射函数是纯的、可以被探针问数字。**

## 1.4 作物数据与成长阶段

`data/crops.json`，4 种作物，字段：

```
id / name_key / icon / growth_seconds / growth_stages(=5) / stage_seconds[4]
growth_assets[5] / care_event_types[] / care_event_stage / thirst_seconds
harvest_amount / harvest_gesture / tutorial_growth_override / unlock_condition
```

| 作物 | 总时长 | 照料事件 | 产量 | 手势 |
|---|---|---|---|---|
| carrot | 30 分 | thirsty @1200s | 3 | pull_up |
| corn | 2 小时 | weeds @stage2 | 2 | swipe_down |
| strawberry | 4 小时 | thirsty @9600s | 4 | tap_each |
| tomato | 8 小时 | weeds @stage2 | 3 | tap_each |

三条已定的设计（`farm_decisions.md` + `offline_growth.gd` 注释）：

- **每种作物一辈子只有一种活**（`care_event_types` 单元素）。两件活压在一块地上，
  六岁孩子必然漏掉一件。**你要的"每次进入最多出现一个主要事件"，这条规则已经强制了。**
- `thirst_seconds` **恰好在全程 2/3 处**，所以每株正好需要浇一次水。教学胡萝卜的
  6 秒 override 是**整条缩放**（`Growth.crop_for()`），不是换个总数，就是为了保住这个比例。
- **长草是确定性的**，不是随机。理由写在 `offline_growth.gd:55-62`："为什么我的地长草他的没长"是这个
  游戏不想引出的问题，**也是商店那条禁止踏上的阶梯的第一级**。加小虫时必须遵守同一条。

**`harvest_gesture` 是死数据** —— 菜园从头到尾没读过它，收获就是点一下。见开放问题 E。

## 1.5 离线成长

`scripts/garden/offline_growth.gd`，**全部是静态纯函数，不碰存档、不碰时钟、不碰场景**。

```gdscript
Growth.advance(plot, crop, seconds) -> plot     # 全部算术在这里
Growth.settle(farm, now) -> farm                # 唯一伸手到外面的
Growth.fraction_done(plot, crop) -> float
Growth.water(plot) / Growth.weed(plot) / Growth.crop_for(plot, crop)
Growth.wants(crop, kind) / Growth.weeds_stage(crop)
```

两条不可谈判的规则（`:29-40`）：**作物永不死亡**（没水就等）、**熟了是天花板**（时钟往前
拨一年也只能收一次）。

时钟：`GameClock.MAX_OFFLINE_SECONDS = 8 小时`；`elapsed_since()` 永不为负；
倒拨时锚点搬到 now，生长原地继续、这趟旅行一分不发。

**这一整块改造中一行都不用动。** 新农场只是多几块地走同一个 `settle()`。

## 1.6 仓库 / 订单 / 奖励接口

**`InventoryManager`（110 行，全 static）**

```gdscript
Barn.count/has/contents/total/put/take/can_pay/pay(..., which := "warehouse")
```

两个仓：`"warehouse"` → `farm.warehouse`（地里出来的）；其他 → `data.inventory`（种子/工具）。
两者都**不是** `rewards.items`（那是战斗药水，三个 minigame 直读）。

**两个必须知道的缺口：**

1. **没有任何容量概念。** `put()` 只要 `amount > 0` 就无条件成功。你要的 40 格是新东西。
   好消息：`put()` 已经**返回实际入库量**，签名天生留好了"部分入库"的位置。
2. **这个文件里没有一处 `save_game()`。** 落盘完全靠调用方。批量收菜必须自己节流，
   不能每收一颗存一次盘。

**奖励**：`RewardManager.grant(source, coins, once_key, already_paid) -> int`
和 `RewardManager.record(source, once_key, already_paid) -> bool`。
**幂等的 append 发生在 return 之前**，所以后面 await 一个动画也漏不进第二次按压。
`already_paid` 是调用方的数组 —— 只有调用方知道往哪儿持久化。

**钱**：只有 `rewards.coins` 一个能花的数。`CurrencyManager.earn/spend/refund/can_afford/short_by`，
`spend()` 不够就返 false 且什么都不改。`SaveManager.add_coins()` 已删除，静态规则强制
菜园不许直接写 `rewards.coins`。

**现成的事务号样板只有一个，就是菜园自己的**：
`"farm_harvest_<plot_id>_<plant_cycle_id>"`，`plant_cycle_id` 每次下种 +1、跨收获不重置，
配 `Farm.remember_paid()` + `PAID_LEDGER_KEPT = 64` 的**有界 ledger**。
出售和买种子照抄这个形状（§7.4）。

## 1.7 触摸拖动与自动吸附

`scripts/shared/drag_field.gd`：

```
GRAB := 84.0     拇指会盖住目标，落点常在旁边
SNAP := 118.0    松手后吸进最近的槽
LIFT := 1.18     握住时抬起放大，越过拇指可见
HOME := 0.28     放错平滑浮回原位 —— 不掉、不消失、不红闪
```

`add_item / add_slot / items / slots / held / complete / place_for_them`，
信号 `picked_up / dropped(item, slot, correct) / solved`。
握着时**所有可放处发光，最近的更亮**。

**`SNAP` 是屏幕空间常量。世界一旦能缩放，它就变成一个会漂的数 —— 这是这次改造最容易
悄悄坏掉的地方，见 §4.3。**

手势识别器另有一套：`scripts/harvest/gesture.gd`，
`Gesture.satisfied(kind, params, track, centre)`，**纯函数，五种识别器**
（tap / drag / twist / line / sweep）覆盖 19 个手势名。「悄悄摘一颗」直接用它。

## 1.8 存档里的 plot_id 与布局

`plot_id = "plot_%d" % (index + 1)`，从 1 开始。**布局完全不在存档里** —— 位置是
`_bed_centre(index)` 每帧算的。所以**新布局不需要迁移任何位置数据**，只需要保证
plot_1..plot_4 还是那四块地。

`Farm.normalise_farm()` 的这一行是免费的迁移：

```gdscript
var wanted: int = maxi(int(farm["plot_count"]), PLOT_COUNT)
```

`PLOT_COUNT` 从 4 改成 6：老档 `plot_count = 4` → `wanted = 6` → 前四块从磁盘原样读回，
第 5、6 块 `fresh_plot()` 出来是 EMPTY。**扩地到 8 也一样，把 `plot_count` 写成 8 即可，
`maxi` 保证它永不缩水。不需要新机制。**

## 1.9 可复用的素材

| 有什么 | 在哪 | 备注 |
|---|---|---|
| **作物图（真 PNG）** | `assets/crops/` | carrot corn strawberry tomato **potato lettuce** apple orange grape pumpkin watermelon broccoli peas wheat golden_carrot bug stone —— **你要卖的土豆和生菜的图已经有了** |
| 图标（代码画的，约 100 个） | `scripts/ui/icon_library.gd` | 已有 `soil seed sprout watering_can weed basket carrot corn strawberry tomato paw leaf rock chest coin star_coin gear lock check heart shelf sofa lamp` |
| 缺的图标 | — | 小虫、小狗、水井、市场箱、订单板、围栏、牌坊、扇子、手套、锄头 —— 约 10 个，代码画，估 260 行 |
| 音效 | `assets/audio/` | 33 个，已有 `water drag_pick drag_snap drag_back coin star correct machine door rustle pop sparkle found footstep whoosh` —— 农场基本够用 |
| 语音 | `docs/VOICE_SCRIPT.md` | 权威清单。新农场约需 **18 句新词**，按你的老规矩：**先写词、后录音，`AudioManager.say()` 缺文件静默失败不挡路** |
| 角色 | `scripts/world/puppy_art.gd`（12KB） | **小狗已经有画法了**，别重画 |
| 手势 | `scripts/harvest/gesture.gd` | 见上 |
| 提示三级 | `scripts/shared/hint_director.gd` | `Hints.new(); watch(nudge, show, do_hard_part)`；家长档 API：`HintDirector.doing_well() / extra_things(base) / idle_wait()` |
| 休息提议 | `scripts/shared/rest_director.gd` | 一次拜访只提一次、必须在好事之后、无倒计时无惩罚 |
| 屏形适配 | `scripts/shared/screen_fit.gd` | `Fit.at/x/y/bottom/right/corner/view`，1280×720 上是恒等变换 |

## 1.10 测试基线

`tests/run_smoke.sh` 现在 **25 个检查点**（`FARM_ACCEPTANCE.md` 写的 23 已过期），
菜园直接相关的 4 个：

| 检查点 | 文件 | 断言 | 要窗口 |
|---|---|---|---|
| Garden touch probe | `garden_touch_probe.gd` | 10 小节 × 65 个 `_ok(` × **2 种屏形**（1280×720 / 1024×768） | 是 |
| Garden probe | `garden_probe.gd` | 19 小节，134 个 `_ok(` 调用点（循环内实际更多） | 否 |
| Harvest touch probe | `harvest_touch_probe.gd` | 172 条，**带 `_asked` 计数、<60 自己判失败** | 是 |
| Harvest probe | `harvest_probe.gd` | 纯逻辑 | 否 |

**顺序是硬约束**：Garden probe 必须在 Save probe 之前（它会 `rm` 存档走真实首次启动路径）；
Save probe 必须最后（它故意留下一个全新空档）。

**三个会被这次改造直接打红的地方**（不是 bug，是探针在做它该做的事）：

1. `garden_touch_probe._find_back_button()` 靠 `child is Button and child.text == "<"` 找返回键
2. `garden_touch_probe._seed_tile(index)` 硬编码复刻了种子架布局 `x = 90 + index * 130`
3. `garden_probe._a_new_child_finds_four_empty_plots()` 断言 4 块地、`plot_count == 4`

**一个真实缺口**：两个菜园探针**都没有"提问数不足就判失败"的自检计数器**。
`harvest_touch_probe` 有（`_asked < 60` 自己红）。大改造正是"绿灯但什么都没测"最容易发生的时候，
**阶段 1 就把两个菜园探针也加上 `_asked`**。

## 1.11 审计里挖出的三个既有问题（顺手修）

| 问题 | 位置 | 后果 |
|---|---|---|
| `farm_visitors` / `farm_unlocks` 在 `_default_data()` 建了空 dict，**`_merge_farm()` 完全没合并它们** | `save_manager.gd:135-136` vs `:1158-1234` | 二期真用起来后，从家长中心导入备份会**静默清空访客记录和解锁状态** |
| `InventoryManager._store()` 的 warehouse 分支写 `SaveManager.data.get("farm", {})` | `inventory_manager.gd:31` | `farm` 缺失时改动写进临时字典**静默丢失**。现在不触发（`farm` 永远存在），但改造别破坏这个前提 |
| `GameData.get_order()` 是线性扫描，没建索引 | `game_data.gd:182-186` | 现在 3 张订单无所谓；订单变多时记得建索引 |

---

# 二、迁移方案

## 2.1 存档改动一览

`FARM_SAVE_VERSION: 3 → 4`。

```gdscript
# farm 里新增（都在 default_farm() 里给默认值）
"farm_xp": 0,                    # 农场经验，和玩家主等级完全无关
"warehouse_cap": 40,             # 仓库格数，升级后 60
"harvest_basket": {},            # 仓库满了的临时篮，crop_id -> count，绝不丢
"paid_sales": [],                # 出售事务号 ledger（有界 64，同 paid_harvests）
"sale_receipt_id": 0,            # 只涨不减的收据号
"shop_receipt_id": 0,            # 买种子的收据号
"visit_log": [],                 # 访客记录，最多 10 条
"dog": {"scarf": "", "found_seeds": []},
"npc": {"bear": {"friendship": 0, "last_share_cycle": 0, "help_owed": false}},

# plot 里新增（PLOT 常量加两行，normalise_plot 自动兜底，不用写迁移）
"golden": false,                 # 金色成熟
"pest_stage": 0,                 # 小虫出现在哪一阶段，0 = 这一茬没有虫
```

`farm_level` / `plot_count` / `unlocked_crops` / `npc_friendship` / `decorations` /
`completed_missions` **已经存在**，直接用，不新建平行字段。

## 2.2 迁移六步（都在 `_settle_after_load()` 里，跟在现有四个迁移后面）

1. `Farm.PLOT_COUNT: 4 → 6`。`normalise_farm()` 的 `maxi()` 自动把老档补到 6 块，
   **前四块原样，后两块 EMPTY**。不需要写一行迁移代码。
2. `save_version < 4` 时：`warehouse_cap = 40`；`farm_xp = 0`；
   `harvest_basket = {}`；三个 ledger / 收据号清零。
3. `unlocked_crops` 保持原样。**新的土豆、生菜不预解锁** —— 它们是种子商店的第一批商品，
   买了才有。这是"钱有地方花"的第一环。
4. **`_merge_farm()` 同步加规则**：`visit_log` 取并集后按时间截最近 10 条；
   `paid_sales` 取并集；`warehouse_cap` 取大值；`farm_xp` 取大值；`npc.*.friendship` 取大值；
   顺手把漏掉的 `farm_visitors` / `farm_unlocks` 补上。
5. 写 `data["save_version"] = FARM_SAVE_VERSION`（照抄 `_open_the_farm():384`）。
6. **`_settle_after_load()` 必须返回 `bool changed`** —— 不返回的话结算只在内存里，
   每次启动重跑一遍（退款那次就是这么错的）。

## 2.3 迁移的三条硬保证（每条对应一个断言）

| 保证 | 断言放在哪 |
|---|---|
| 老档四块地的 state / crop_id / plant_cycle_id / planted_at 一个字节没变 | `garden_probe._an_old_save_keeps_its_four_beds()`（新） |
| 新的第 5、6 块一定是 EMPTY，绝不"继承"任何东西 | 同上 |
| 迁移跑三次结果逐字节相同 | 扩展现有的 `_opening_the_garden_twice_changes_nothing()` |

---

# 三、新场景线框图

见 `docs/FARM_WORLD_WIREFRAME.svg`（两块：A 世界俯视、B 屏幕分层）。

**屏幕分三层，只有中间那层会动：**

```
┌──────────────────────────────────────────────┐  84px  顶栏（固定）
│ ←返回      星光农场      农场 Lv1 ▮▮▯▯   🪙298 │
├──────────────────────────────────────────────┤
│                                              │
│          世 界 窗 口  （可平移 / 可缩放）        │  504px
│                                     ＋  −     │
│                                              │
├──────────────────────────────────────────────┤
│  手  锄头  种子  水壶  手套  小扇  篮子          │  132px  工具栏（固定）
└──────────────────────────────────────────────┘
```

**为什么不用 `Camera2D`：** 这个项目至今一个 `Camera2D` 都没有，全部是
`UiKit.play_area()` + `get_viewport_rect().size` 的屏幕空间布局。Godot 里 `Camera2D`
会连同层 Control 一起搬走，要把工具栏钉住就得引入 `CanvasLayer`，而 `DragField`、
`UiKit`、两个探针的坐标换算全部按视口写的。

**改成：`FarmWorld` 是一个自己管 `position` 和 `scale` 的 `Node2D` 容器**，
顶栏和工具栏是它的兄弟节点，留在屏幕空间。世界↔屏幕换算收在一个纯函数里：

```gdscript
func world_to_screen(p: Vector2) -> Vector2:   # 探针可以直接问它数字
    return (p - _cam_centre) * _zoom + _window_centre
```

这和 `garden_touch_probe._glass()` 是同一个套路 —— **拖歪了和拖坏了长得一模一样，
所以换算必须是能被单独问数字的纯函数。**

---

# 四、6 块土地布局

## 4.1 坐标（世界设计单位，世界 2200 × 1150）

| | 列 1 | 列 2 | 列 3 | 扩建列 |
|---|---|---|---|---|
| **行 1（y = 420）** | plot_1 (470) | plot_2 (830) | plot_3 (1190) | plot_7 (1550) |
| **行 2（y = 780）** | plot_4 (470) | plot_5 (830) | plot_6 (1190) | plot_8 (1550) |

地块尺寸 220 × 150。**中心间距 X = Y = 360。**

设施：种子商店 (200,250)、水井 (830,165)、仓库 (200,700)、小狗窝 (330,990)、
农场入口 (830,1060)、市场出售箱 (1950,380)、订单板 (1950,750)、
装饰区 (1550,1025)、果树区(Lv3) (1950,135)、加工区/温室(Lv4/5) (1950,1005)。

## 4.2 缩放三档，最小档必须看得见全部六块地

```
ZOOM_STEPS := [0.8, 1.0, 1.25]      默认 1.0
```

最小档 0.8 时，504px 高的世界窗口对应 **1600 × 630 世界单位**。
六块地的外接框是 **940 × 510**（含地块本身）。**整块装得下，还剩余量。**

**这条是硬性的：孩子把画面拖没了、找不到自己的地，就等于游戏坏了。**
所以 (1) 相机范围硬钳制在世界矩形内；(2) 双击草地回默认视角；
(3) 最小缩放一定看得见全部土地；(4) 小狗会跑向该干活的地方，跟着它就行。

## 4.3 ⚠️ 间距是算出来的，而且缩放会毁掉它

**这个项目已经四次遇到"两个能点的东西离太近"**（菜园地块、丰收目标、篮子、作物摆放）。
空间农场引入了第五次，而且这次多一个乘数：

```
屏幕间距 = 世界间距 × 缩放
```

`DragField.SNAP = 118` 是**屏幕空间**的。所以：

```
世界间距 ≥ (DragField.SNAP * 2 + 26) / MIN_ZOOM = 262 / 0.8 = 327.5
取 360，余量 32.5
```

**必须写成这个算式，不能写 360。** 以后调 `SNAP` 或调 `MIN_ZOOM`，间距跟着动，
而不是悄悄失效。设施之间用较松的一条：`世界间距 ≥ THUMB_APART / MIN_ZOOM = 92 / 0.8 = 115`，
并且和丰收篮子一样**取最近的那个，不是范围内的第一个**。

新增探针断言：**在每一档缩放下**，任意两块地的屏幕间距 > `SNAP*2`；
任意两个设施的屏幕间距 > `THUMB_APART`。

## 4.4 土地表现（11 种状态怎么一眼看懂）

| 状态 | 画面 | 不用文字 |
|---|---|---|
| EMPTY | 草皮，浅绿，边上一圈没翻过的土坷垃 | 锄头徽章 |
| TILLED | 深褐、有犁沟、**干土偏浅** | 种子徽章（虚线投放圈） |
| SEEDED | 犁沟中间一个小土包 | 无 |
| SPROUT（stage 0-1） | 两片子叶 | 无 |
| GROWING（stage 2-3） | 逐渐长大，`size = 56 + 62 × done` | 无 |
| NEEDS_WATER | **土色变浅、叶子微垂**，水滴徽章慢慢眨 | 水壶徽章 |
| HAS_WEED | **杂草真的长在作物旁边**，不是徽章代替 | 手套徽章 |
| HAS_BUG | **小虫在叶子附近来回爬**（正弦轨迹，2 秒一个来回） | 小扇徽章 |
| READY | 成熟作物**轻微摆动**（`Juice.idle_bob` 已有） | 篮子徽章 |
| GOLDEN_READY | 同上 + **柔和星光**（`Juice` 的粒子，低密度） | 金篮徽章 |
| HARVESTED | 0.45 秒不可点，作物飞向篮子 | — |

**湿土 / 干土靠颜色差**：`Color(0.45,0.32,0.22)` 湿 → `Color(0.58,0.45,0.33)` 干，
两者明度差 ≥ 0.12（红绿色盲也能看出深浅）。

**圆形进度环只在点击土地后显示 3 秒**（你要的），平时不占画面。
但 **成熟和缺水必须常驻可见** —— 那不是进度，那是"这里有活干"。

---

# 五、连续工具交互设计

## 5.1 七个工具，第一个永远是「手」

```
[手] [锄头] [种子] [水壶] [手套] [小扇] [篮子]
 ↑ 默认选中，永远可用
```

- **「手」= 今天的行为**：点一块地，做它当下唯一该做的那件事。**没有错的点法。**
- 其余六个是**批量笔刷**：选中后，在土地上按下并拖动，划过的地依次做这一件事。
- **没活可干的工具变灰、点不动。** 全场没有渴的地，水壶就是灰的 —— 孩子不可能
  "选了水壶然后什么都不发生"。
- **一个工具把活干完后自动回到「手」**，同时小狗跑向下一件该做的事。

这样既满足你要的连续操作，又不推翻 `garden_screen.gd:4-19` 那条
"六岁孩子调不出'拿着铲子浇水没反应'"。

## 5.2 拖动的归属：一次按下只属于一个人

```
按下点在土地 / 设施上  ┬ 选中了具体工具 → 连续作业笔刷（画面不动）
                      └ 选中的是「手」  → 平移画面
按下点在草地上        → 平移画面（任何工具下都是）
```

**双击草地 = 回默认视角**（缩放 1.0，中心对准六块地）。
**捏合缩放**做，但 **＋/− 两个大按钮是主路** —— 六岁的两指捏合不可靠。

## 5.3 一笔之内绝不重复作用同一块地

```gdscript
var _stroke_done := {}          # plot_id -> true，按下时清空，松手时清空

func _brush_over(plot_id):
    if plot_id in _stroke_done: return          # ① 这一笔已经碰过
    if not _tool_has_work_here(plot_id): return # ② 这块地不需要这个活
    _stroke_done[plot_id] = true
    _do_the_job(plot_id)
```

**两道闸，缺一不可**：① 挡"来回蹭同一块地"；② 挡"划过已浇过的地又浇一次"。
探针要分别验：来回划一块地 → 恰好一次；划过 6 块地其中 3 块渴 → 恰好 3 次。

## 5.4 整屏重建要换成"只重画变了的地块"

现在 `_rebuild()` 是核弹级的（`:150`）。空间化后必须收窄：

- **世界节点常驻**，`_rebuild()` 只在进场和扩地时跑
- 每块地一个持久的 `PlotView` 节点，`refresh(plot)` 只改自己那点东西
- **`_queue_rebuild()` 的"手里拿着东西时绝不重建"这条保留**（`:186-199`，
  它抹掉过孩子正在拖的胡萝卜），并且**扩一条：笔刷进行中也绝不重建**

## 5.5 家长三档怎么作用在笔刷上

| 档 | 吸附半径 | 提示 | 事件 |
|---|---|---|---|
| 温和 | `min(地块间距/2, SNAP*1.4)` —— **上限是算出来的，不能让两块地互抢** | 一次做错就出 | 虫和草绝不同时出现（现有 `care_event_types` 单元素已强制） |
| 普通 | `SNAP` | 现有 `HintDirector.IDLE = 11s` | 同上 |
| 勇敢 | `SNAP * 0.85` | `HintDirector.idle_wait()` = ×1.45 | 多一块地要管 + 一个分类/顺序任务；**产量一点不减** |

读法：`SaveManager.get_setting("difficulty", 1)`（0 温和 / 1 普通 / 2 勇敢）。

---

# 六、批量收菜设计

## 6.1 流程

1. 点篮子工具 → 所有成熟的地**同时轻轻跳一下**（告诉他有几块）
2. 在成熟的地上按下拖动 → 每划过一块，作物**从地里升起来 → 飞向屏幕角落的篮子**
3. 飞行途中屏幕中央显示 **连收数字**（1 → 2 → 3…），字号随数字变大
4. 松手 → 数字停住 → **所有作物一起进仓库**，篮子鼓一下，`AudioManager.say("praise_1")`

## 6.2 每个 plant_cycle 只发奖一次 —— 直接用现成的

批量收菜**不发明新机制**，每块地都走现有的 `_harvest(plot)`：

```gdscript
key := "farm_harvest_%s_%d" % [plot_id, plant_cycle_id]
if not RewardManager.record("garden:harvest:%s" % crop_id, key, paid): return
Farm.remember_paid(farm, key)
```

`plant_cycle_id` 每次下种 +1、**跨收获不重置**，所以历史上不可能重复。
`PAID_LEDGER_KEPT = 64` 对 8 块地绰绰有余。

**落盘一次，不是八次**：整笔结束后 `SaveManager.save_game()` 一次。
（`InventoryManager` 自己不存盘，正好。）

## 6.3 金色成熟

- **确定性，不是概率。** 规则：一块地**连续三次**在成熟后 24 小时内被收走 →
  第四次金色。写在 `plot.golden`，收获时清零计数。
- 金色 = 产量 ×2 + 一颗友情星。**不是抽奖**，是"照顾得好"的结果，孩子能自己发现规律。
- 这条必须由探针钉死：**没有任何 `randf()` 参与作物产出。**

---

# 七、种子商店与市场经济设计

## 7.1 首批六种种子

| 种子 | 价格 | 成长 | 产量 | 卖价/个 | 解锁 |
|---|---:|---:|---:|---:|---|
| 胡萝卜 | 5 | 30 分 | 3 | 4 | 一开始就有 |
| 玉米 | 8 | 2 小时 | 2 | 9 | 一开始就有 |
| 草莓 | 12 | 4 小时 | 4 | 8 | 一开始就有 |
| 番茄 | 16 | 8 小时 | 3 | 14 | 一开始就有 |
| **土豆** | 10 | 3 小时 | 5 | 6 | 农场 Lv1（商店买） |
| **生菜** | 6 | 1 小时 | 3 | 4 | 农场 Lv1（商店买） |

**土豆和生菜的图 `assets/crops/potato.png` / `lettuce.png` 已经在盘上了**（丰收行动在用）。
它们要加进 `data/crops.json`（成长曲线、`care_event_types` 单元素、`thirst_seconds` 在 2/3 处）。

**卖价 × 产量 > 种子价，但差得不多**（胡萝卜：5 → 12，赚 7）。订单奖励是它的 2~3 倍，
这样"交订单比直接卖划算"是孩子自己算得出来的，不需要谁教。

## 7.2 商店界面：先试 → 看清三个数字 → 确认

红线要求原样照搬英雄小屋那一套：

```
[种子图]  名字   我有 ×3
          🪙 5      ⏱ 30分      🧺 3个
                    [ 买一包 ]
```

**三个数字必须同时可见**（价格 / 成长时间 / 收获数量）。
**一次点击绝不直接扣费** —— 点「买」出确认卡，确认后才扣。
**买完 5 秒内可以全额放回去**（`Coins.refund()` 已有）。
**只用星星币。没有真实货币、没有广告、没有随机包、没有限时折扣、没有红点。**

## 7.3 市场出售箱

1. 走到箱子前点一下 → 仓库抽屉从下面滑出来
2. **把作物拖进箱子**（`DragField`，一次一叠，长按加速）
3. 箱子上方实时显示 **🪙 累计**
4. 点「卖掉」→ 货物装箱动画 → 金币飞向顶栏的钱包 → 数字跳上去

## 7.4 出售 / 购买绝不重复结算

照抄 `plant_cycle_id` 的形状：

```gdscript
# 出售
farm["sale_receipt_id"] += 1                       # 先涨号，再付钱
var key := "farm_sale_%d" % farm["sale_receipt_id"]
if not Barn.pay(basket): return                    # 先扣货，扣不动就整笔不做
Coins.earn(total, "farm:market")
Farm.remember_paid_sale(farm, key)                 # 有界 64，同 paid_harvests
SaveManager.save_game()

# 买种子（顺序反过来：先扣钱，扣不动整笔不做）
if not Coins.spend(price): return "poor"
Barn.put(seed_id, count, "inventory")
```

`Coins.spend()` **不够就返 false 且什么都不改**，忘了检查也不会透支。
**扣货/扣钱在 await 之前，动画在之后** —— `_deliver()` 的注释（`:738-743`）
写了原因："六岁孩子会按两次"。

---

# 八、仓库容量方案

## 8.1 40 格，一件一格

`farm.warehouse_cap = 40`。**占用 = `Barn.total()`**（现有函数，走 `contents()` 求和）。
一颗胡萝卜一格，不做堆叠规则 —— 孩子看得见的是"篮子里有多少东西"。

## 8.2 `InventoryManager` 的最小改动

```gdscript
static func room_left(which := WAREHOUSE) -> int:
    return maxi(0, cap(which) - total(which))

static func put(item_id, amount, which := WAREHOUSE) -> int:
    var room := room_left(which)               # ← 新增
    var stored := mini(amount, room)           # ← 新增
    ...
    return stored                              # 签名没变，本来就返回实际入库量
```

**签名一行没改** —— `put()` 本来就返回实际入库量，只是以前永远等于 `amount`。
调用方（`_harvest`、批量收菜）拿返回值和请求量比，差额进临时篮。

## 8.3 满了会怎样：什么都不丢

```
收获 5 颗，仓库还剩 2 格
 → 2 颗进仓库
 → 3 颗进 farm.harvest_basket（临时收获篮，画在仓库门口，鼓鼓囊囊）
 → 小狗跑到仓库门口叫两声
 → 顶栏出现三个图标按钮：[交订单] [去市场] [升级仓库]
```

**临时篮不会溢出、不会过期、不会被清空。** 腾出空间后一点就全部收进去。
**绝不出现"仓库满了，本次收获作废"。**

## 8.4 首次升级 40 → 60

需要三样，都是孩子能自己攒的：

- 🪙 **60 星星币**
- ✅ **完成 3 张订单**（现有 `farm_orders.delivered` 直接数）
- 🪵 **提交 3 块木板** —— 木板从丰收行动的关卡奖励掉（`levels.json` 的 `reward` 加一项），
  **不是随机掉落，是打完那一关必给**

**不能用付费扩容，不能用广告扩容，不能限时打折。**

---

# 九、小熊 NPC 农场设计

## 9.1 它是什么

`data/npc_farms.json` 里的一份**静态描述**，加上存档里 `farm.npc.bear` 的一点状态。
**不连真实玩家，没有联网，没有排行榜，没有真实损失。**

```
scenes/garden/visitor_farms/BearFarm.tscn
scripts/garden/npc_farm_manager.gd
data/npc_farms.json
```

## 9.2 小熊农场里有什么

| | |
|---|---|
| 6 块地 | 4 块种胡萝卜和草莓（长势各不相同），1 块**缺水**，1 块**带分享星星、已成熟的草莓** |
| 水井 | 1 口，孩子帮忙浇水时从这儿打水 |
| 小熊 | 会挥手、会指方向、会鞠躬。**永远不生气、不追、不拒绝** |
| 回家的门 | 屏幕左上角，和自己农场的返回键同一个位置、同一个样子 |

**小熊农场的状态由游戏生成，是确定性的**：给定 `farm.npc.bear.last_share_cycle`
和当前时间，长成什么样是算出来的，不是随机的。**同一个孩子今天和明天看到的
小熊农场，会因为时间流逝而不同，但绝不会因为运气而不同。**

## 9.3 进出

- 入口：自己农场的**农场入口牌坊**旁边出现小熊头像（第一次收获后出现）
- 也可以从访客记录牌点小熊的名字进去
- 返回：左上角同款返回键 → 回到自己的农场，**相机停在牌坊前**（不是默认视角，
  这样他知道自己是从哪儿回来的）

---

# 十、悄悄摘一颗流程

## 10.1 七步

```
1. 进小熊农场         小熊挥手 · 语音「欢迎来我家！」
2. 找到分享作物       那颗草莓头上有一颗慢慢转的星星，别的都没有
3. 用对的收获手势     草莓是 tap_each → Gesture.satisfied("tap", ...)
                     手势不对：草莓摇一摇，不消失、不惩罚、可以再试
4. 作物进访客奖励篮   飞进屏幕右下角一个和自己仓库不一样的小篮子
5. 小熊指向缺水的地   语音「那块地渴了，你能帮帮它吗？」+ 手指动画
6. 孩子帮忙浇水       从水井拖水壶过去，或者选水壶点那块地
7. 小熊挥手道谢       友情星 +1，掉一颗种子（小熊自己种的那种）
```

## 10.2 七条规则怎么落地

| 你的规则 | 实现 | 断言 |
|---|---|---|
| 只有带分享星星的能摘 | 只有 `share: true` 的地注册收获热区 | 对其他 5 块地做手势 → 什么都不发生、不报错 |
| 每次访问最多一颗 | `_picked_this_visit` 内存标志 + `bear.last_share_cycle` 落盘 | 摘完再摘 → 星星已经没了，热区已注销 |
| 小熊不损失真实产量 | **小熊农场根本没有仓库、没有产量账本**，它是一张画 | 摘完后小熊那块地照样按时间长下一茬 |
| 摘完必须帮浇一块地 | `bear.help_owed = true` 落盘 | 摘了就走 → **草莓照样归他，友情星等回来再给**。绝不追回、绝不惩罚 |
| 完成后得友情星 | `RewardManager.record("bear:friend:%d" % cycle, ...)` | 连点四次只发一次 |
| 访问状态立即保存 | 摘的那一刻 `save_game()`，浇完再 `save_game()` | 中途杀进程重开 → 状态在 |
| 同一轮不能重复 | `last_share_cycle` 对比小熊当前的种植轮次 | 见下 |

## 10.3 ⚠️ "同一轮"怎么定义（开放问题 D）

**不要用"每天一次 + 午夜刷新"** —— 那是连续登录奖励的变体，是你自己的红线明令禁止的。

**建议**：小熊那块分享地和你的地跑**同一套 `Growth.advance()`**。摘走之后它变回
`TILLED`，小熊"重新种上"，按草莓的 4 小时长回来。所以：

- 门槛是**生长时间**，不是日历
- **错过一天不损失任何东西**，草莓熟着一直等
- 孩子能自己理解："它还没长好，我明天再来"

---

# 十一、小狗和访客记录设计

## 11.1 小狗

`scripts/world/puppy_art.gd`（12KB）**已经有小狗的画法了，直接用，别重画。**

| 它做什么 | 触发 | 不做什么 |
|---|---|---|
| 跑向成熟的地，坐下摇尾巴 | 有 READY 的地 | **不弹红点、不倒计时、不催** |
| 对着有虫的叶子小声叫 | `care_event == "bug"` | 不咬、不吓人 |
| 小熊来访时摇尾巴迎接 | 有未读访客记录 | **绝不对访客吠、绝不驱赶** |
| 找到藏起来的种子 | **确定性**：每升一级，农场里固定藏一颗，位置由 `farm_level` 决定 | **不是随机掉落，不是开箱** |
| 蹲在访客记录牌旁边 | 有未读记录 | — |

**没有饥饿、没有受伤、没有生病、没有离开惩罚。** 它不是养成对象，是一个提示器和一个陪伴。

**它不会挡路**：小狗节点 `mouse_filter = IGNORE`，永远不吃点击；
它的位置计算永远绕开地块中心 `THUMB_APART` 以外。探针要验这两条。

## 11.2 访客记录牌

立在自己农场入口牌坊旁边，一块小木牌。点开是一列卡片，**最多 10 条，最新在上**：

```
🐻  小熊来过
    帮你浇了 2 块地
    摘走了 1 颗分享草莓
    留下 1 颗友情星
```

**规则：**

- **访客不会让自己的库存减少一件。** 访客摘走的是"分享作物"——
  一颗**额外生成**的、专门标了星星的作物，不是从他仓库里拿的。
  探针要验：一次访问前后 `Barn.total()` **完全相等**。
- **一个字的负面表达都没有。** 没有"偷"、没有"损失"、没有"被拿走"。
  措辞表放 `data/farm_visit_texts.json`，`tools_check.py` 加一条规则：
  **这个文件里出现"偷/抢/丢/损失/被拿"任何一个词就报 error。**
- 记录写在 `farm.visit_log`（存档，不是 `data/`），超过 10 条丢最旧的。
- **不是通知，不催**：小狗蹲在牌子边就是全部提示，没有数字角标。

---

# 十二、修改文件清单

## 12.1 新建（14 个）

> 目录用 `scripts/garden/` 而不是 `scripts/farm/`（见开放问题 B）。
> 如果你更想要 `farm/`，我会同步把 `tools_check.py` 那条作用域规则从
> `scripts/garden/` 改成 `scripts/(garden|farm)/`，**不能忘**。

| 文件 | 估行 | 干什么 |
|---|---:|---|
| `scripts/garden/farm_world_controller.gd` | 520 | 世界节点、地块视图池、状态→表现映射 |
| `scripts/garden/farm_camera_controller.gd` | 240 | 平移/缩放/钳制/双击回中/`world_to_screen()` |
| `scripts/garden/farm_tool_controller.gd` | 280 | 七个工具、选中态、灰掉规则、自动回「手」 |
| `scripts/garden/continuous_action_controller.gd` | 260 | 笔刷、一笔一块、两道闸 |
| `scripts/garden/seed_shop_manager.gd` | 220 | 目录、价格、买、5 秒退 |
| `scripts/garden/farm_market_manager.gd` | 200 | 出售、收据号、有界 ledger |
| `scripts/garden/farm_level_manager.gd` | 180 | `farm_xp` / `farm_level` / 升级门槛 |
| `scripts/garden/farm_expansion_manager.gd` | 200 | 扩地、`plot_count` 增长、扩地动画 |
| `scripts/garden/farm_dog_controller.gd` | 240 | 小狗行为（复用 `puppy_art.gd` 画法） |
| `scripts/garden/npc_farm_manager.gd` | 260 | 小熊农场的确定性生成 |
| `scripts/garden/friendly_harvest_manager.gd` | 220 | 悄悄摘一颗 + 帮浇水 + 友情星 |
| `scripts/garden/farm_visit_log_manager.gd` | 140 | 访客记录读写、截 10 条 |
| `scripts/garden/plot_view.gd` | 300 | 一块地的持久节点，`refresh(plot)` |
| `scripts/garden/farm_layout.gd` | 120 | **布局常量与间距算式，纯数据，探针直接问它** |

场景（5 个）：
`scenes/garden/FarmToolBar.tscn`、`SeedShop.tscn`、`FarmMarketBox.tscn`、
`FarmVisitLog.tscn`、`visitor_farms/BearFarm.tscn`

> **不新建 `farm_world.tscn`。** `Garden.tscn` 就是农场的场景，它已经是入口
> （`levels.json` → `GameData.get_minigame_scene("garden")`）。再建一个平行入口，
> 正是你说的"平行实现"。`garden_screen.gd` 改成薄壳，挂 `farm_world_controller.gd`。

## 12.2 数据文件（7 新建 + 2 扩展）

| 文件 | 新建/扩展 | 内容 |
|---|---|---|
| `data/crops.json` | **扩展** | 加 potato、lettuce（图已在盘上） |
| `data/garden_orders.json` | **扩展** | 订单从 3 张加到 6 张 |
| `data/farm_world_layout.json` | 新建 | 地块和设施的世界坐标、缩放档位 |
| `data/farm_seed_shop.json` | 新建 | 六种种子的价格/解锁 |
| `data/farm_market_prices.json` | 新建 | 每种作物的卖价 |
| `data/farm_levels.json` | 新建 | 五级农场等级、每级解锁什么 |
| `data/farm_expansions.json` | 新建 | 扩地的门槛和动画参数 |
| `data/npc_farms.json` | 新建 | 小熊农场的地块和作物 |
| `data/farm_friend_actions.json` | 新建 | 可以帮小熊做的事 |
| `data/farm_dog.json` | 新建 | 小狗**配置**（速度、蹲点偏移、装饰列表）。**状态在存档里** |
| `data/farm_visit_texts.json` | 新建 | 访客记录的措辞模板（替代你列的 `farm_visit_log.json`） |

**每加一个 json 要改 5 处 `game_data.gd`**：变量声明、`_load_json()`、索引（如需）、
**"空即报错"表（`:79-83`）**、`get_xxx()` 访问器。第 4 处漏了就是静默半安装 ——
怪兽图鉴那次就是这么整个功能不存在的。

## 12.3 修改（14 处）

| 文件 | 改什么 | 不改的后果 |
|---|---|---|
| `scripts/garden/garden_screen.gd` | 改成薄壳，表现层搬走 | — |
| `scripts/garden/farm_save.gd` | `PLOT_COUNT 4→6`、PLOT 加 2 字段、farm 加 9 字段、`remember_paid_sale()` | — |
| `scripts/garden/inventory_manager.gd` | `cap()` / `room_left()` / `put()` 限量 | 仓库容量做不出来 |
| `scripts/core/save_manager.gd` | `FARM_SAVE_VERSION 3→4`；`_default_data()`；**`_merge_farm()` 加全部新 key**；`_settle_after_load()` 迁移 | **导入备份时静默清空** |
| `scripts/core/game_data.gd` | 7 个新 json 的 5 处 | 静默半安装 |
| `scripts/ui/home.gd` | 加第五个大按钮「星光菜园」→ `GameManager.start_level("star_garden")`，2×2 改 2×3 | 你截图要的入口没有 |
| `scripts/ui/world_map.gd` | 房间 marker 图标不变，无需改 | — |
| `data/levels.json` | `star_garden` 的 `config` 里加世界布局引用 | — |
| `data/strings.json` | 新文案键约 40 个 | `I18n.t()` 会显示裸 key |
| `docs/VOICE_SCRIPT.md` | 加约 18 句新词 | `voice_check` 报"没写词"（失败） |
| `tools_check.py` | 加 6 条新规则（见 §14.4） | 新代码逃出检查 |
| `tests/garden_probe.gd` | 4 块地 → 6 块地；加迁移小节；**加 `_asked` 计数** | 绿灯但什么都没测 |
| `tests/garden_touch_probe.gd` | 返回键找法、种子架布局、地块数；**加 `_asked` 计数** | 直接打红 |
| `tests/run_smoke.sh` | 加 `FarmWorldProbe`（带 `timeout`） | 一个解析错误挂死整套 |

---

# 十三、分阶段开发计划

**每个阶段：跑 `tools_check.py` 0 errors + 全套 `run_smoke.sh` 全绿 + 两种屏形实机截图
+ 至少一次"再弄坏一次"的证明。同步到你机器上，等你确认，我不提交。**

### 阶段 0 · 地基与迁移（**不出画面**，约 1 天）

- `FARM_SAVE_VERSION → 4`，9 个 farm 字段 + 2 个 plot 字段
- `PLOT_COUNT 4 → 6`，老档迁移
- `_merge_farm()` 补全（含顺手修 `farm_visitors` / `farm_unlocks`）
- `InventoryManager` 容量 + 临时篮
- **两个菜园探针加 `_asked` 自检计数器**
- **交付**：老档迁移前后的逐字段对账表 + 三次迁移逐字节相同的证明

> 上一轮就是这么开始的（阶段 0 `72b9877`），事后证明是对的：
> UI 一旦画出来，改存档格式的代价会翻倍。

### 阶段 1 · 空间农场场景（约 2 天）

- `farm_layout.gd` 间距算式 + `data/farm_world_layout.json`
- 世界节点、6 块地的 `PlotView`、9 个设施的占位
- 相机：拖动、缩放三档、钳制、双击回中、`world_to_screen()`
- 11 种土地表现
- **交付**：三档缩放各两种屏形共 6 张截图 + 间距断言表 + 老档进去后前四块地原样的截图

### 阶段 2 · 工具栏与连续作业（约 2 天）

- 七个工具、灰掉规则、自动回「手」
- 笔刷：连续翻土 / 播种 / 浇水 / 拔草 / 赶虫 / 收菜
- 批量收菜的连收数字和飞行动画
- **交付**：真实 `InputEventScreenDrag` 推出来的连续作业录屏帧 + "来回蹭一块地只做一次"的断言

### 阶段 3 · 种子商店、市场、仓库容量（约 2 天）

- 商店（三个数字 + 确认 + 5 秒退）、市场箱、仓库满的临时篮、40→60 升级
- crops.json 加 potato / lettuce
- **交付**：买卖各连点 5 次余额只变一次的断言 + 仓库满时一颗不丢的截图

### 阶段 4 · 小狗、小熊农场、悄悄摘一颗、访客记录（约 3 天）

- 小狗（复用 `puppy_art.gd`）、小熊农场、七步摘取流程、帮浇水、友情星、访客记录牌
- **交付**：完整走一遍七步的截图序列 + "小熊产量一颗没少"的断言

### 阶段 5 · 等级、扩地、动画、整体回归（约 2 天）

- `farm_xp` / 五级 / 扩地动画（移石头、修围栏、土地展开、角色和小狗欢呼）
- 首期完整故事链（你的第十七节）从头到尾跑通
- 全套回归 + 30 关 + 英雄小屋 + 怪兽图鉴
- **交付**：故事链 12 张连续截图 + 25(+1) 个检查点全绿

---

# 十四、测试计划

## 14.1 你列的 22 条，逐条指到断言

| # | 要验的 | 探针 | 断言（新写的标 🆕） |
|---|---|---|---|
| 1 | 旧 4 块地正确迁移 | `garden_probe` | 🆕`_an_old_save_keeps_its_four_beds()` 逐字段对比 |
| 2 | 新增土地不覆盖旧状态 | `garden_probe` | 同上：plot_5/6 必须 EMPTY 且 `plant_cycle_id == 0` |
| 3 | 相机触摸和鼠标拖动 | 🆕`farm_world_probe` | 真 `InputEventScreenDrag` + `InputEventMouseButton`，两种屏形 |
| 4 | 连续工具不重复作用 | 🆕`farm_world_probe` | 来回划一块地 → 恰好 1 次；划 6 块其中 3 块渴 → 恰好 3 次 |
| 5 | 连续收菜不重复发奖 | `garden_touch_probe` | 扩展 `_a_harvest_is_paid_for_once()`：批量路径也走一遍 |
| 6 | 仓库满时不丢 | `garden_probe` | 🆕`_a_full_barn_never_loses_anything()`：收 5 剩 2 格 → 2+3，总数守恒 |
| 7 | 出售不重复给钱 | 🆕`farm_market_probe` | 连点 5 次卖 → 余额只涨一次；绕过按钮直调也不涨 |
| 8 | 买种子不重复扣费 | 🆕`farm_market_probe` | 同上；余额不够时**一分不扣** |
| 9 | 农场等级保存 | `garden_probe` | 存盘重开后 `farm_level` / `farm_xp` 不变 |
| 10 | 扩地状态保存 | `garden_probe` | `plot_count` 只涨不缩（`maxi` 保证），重开后第 7、8 块还在 |
| 11 | NPC 农场可进可返 | 🆕`bear_farm_probe` | 进入 → 返回 → 自己农场状态完全没变 |
| 12 | 同次访问只能摘一颗 | 🆕`bear_farm_probe` | 摘第二次：热区已注销、状态不变 |
| 13 | NPC 不真实损失 | 🆕`bear_farm_probe` | 摘前摘后小熊那 6 块地的 JSON 逐字节相同 |
| 14 | 采摘后必须完成帮助 | 🆕`bear_farm_probe` | 摘完就走 → 草莓归他、`help_owed == true`、友情星**没发**；回来浇完 → 发 |
| 15 | 友情星只发一次 | 🆕`bear_farm_probe` | `RewardManager.record()` 连领 4 次只 1 次 |
| 16 | 访客记录正确 | 🆕`bear_farm_probe` | 一次访问前后 `Barn.total()` **完全相等**；记录条数 ≤ 10，最新在上 |
| 17 | 小狗不卡住角色或土地 | 🆕`farm_world_probe` | 小狗节点 `mouse_filter == IGNORE`；小狗中心到任一地块中心 > `THUMB_APART` |
| 18 | 三个家长档生效 | 🆕`farm_world_probe` | 三档下吸附半径不同，且**温和档也 ≤ 地块间距/2** |
| 19 | 现有种植/离线/订单回归 | `garden_probe` | 19 个小节全部保留 |
| 20 | 30 关回归 | `map_probe` + `smoke_test` | 每个世界每一关实例化跑 10 物理帧 |
| 21 | 英雄小屋回归 | `hero_house_probe` | 现有 |
| 22 | 怪兽图鉴回归 | `album_probe` | 现有 |

## 14.2 三层检查各管什么（这次要补的是第三层）

| 层 | 抓什么 | 抓不到什么 |
|---|---|---|
| `tools_check.py` 静态 | 数据一致性、禁用写法 | 运行时的一切 |
| `*_probe.gd` 纯逻辑 | 算术、状态机、幂等 | **手指推不推得动** |
| `*_touch_probe.gd` 真输入 | 真的 `InputEventScreenDrag` 走完整条输入管线 | 好不好看 |
| 实机截图 + 自己看 | 看不看得见 | — |

**丰收行动那次的教训不能再犯**：四关用手指玩不了，三层检查全绿，
因为**没有任何东西推过一个真的 `InputEventScreenDrag`**。
空间农场的平移、缩放、笔刷**全部是拖动**，所以 `farm_world_probe` 必须是触摸探针，
不能是纯逻辑探针。

## 14.3 每个探针都要有 `_asked` 计数器

照抄 `harvest_touch_probe.gd`：`_ok()` 同时累加 `_asked`，`_ready()` 末尾断言
`_asked >= 基线`。**半个探针是"找一个这种地再问它"，找不到就静悄悄跳过一堆问题然后印 PASSED。**

## 14.4 `tools_check.py` 新增 6 条规则

| # | 规则 | 为什么 |
|---|---|---|
| 1 | `farm_world_layout.json` 里任意两块地的世界间距 ≥ `(SNAP*2+26)/MIN_ZOOM` | 第五次"两个能点的东西离太近" |
| 2 | `scripts/garden/*.gd` 里禁止 `randf/randi/rand_range`（除装饰粒子） | 长草是确定性的，虫和金色也必须是 |
| 3 | `farm_visit_texts.json` 出现"偷/抢/丢/损失/被拿"任一 → error | 不使用负面"被偷"文字 |
| 4 | `farm_seed_shop.json` 每件商品必须同时有 price / grow_seconds / yield | 三个数字必须同时可见 |
| 5 | 农场代码里禁止直接写 `rewards.coins`（现有规则 5e 扩作用域） | 钱只有一个出口 |
| 6 | `crops.json` 每种作物 `care_event_types` 必须**恰好 1 个元素** | 两件活压一块地，六岁必漏 |

**写这些规则时一定要跳过注释行。** 这个坑踩过两次（房间 id 那条、
`RestDirector.new_session()` 那条）——**解释规则的注释本身就含那个字符串，
于是删掉代码检查照样通过**。

## 14.5 每条新规则都要"再弄坏一次"

加完检查后，把刚做好的地方重新弄坏，跑一次，确认**真的报红**，再恢复。
计划弄坏这 8 处：

1. 笔刷去掉 `_stroke_done` → 重复浇水断言必须红
2. 地块间距从算式改成写死 360 → tools_check 规则 1 必须红（改 MIN_ZOOM 后）
3. `put()` 去掉限量 → 仓库满断言必须红
4. 出售去掉收据号 → 重复给钱断言必须红
5. 小熊摘取去掉 `last_share_cycle` → 重复采摘断言必须红
6. 访客记录措辞里塞一个"偷" → tools_check 规则 3 必须红
7. 小狗 `mouse_filter` 改成 STOP → 卡住断言必须红
8. 迁移时把 plot_5 的 state 抄成 plot_1 的 → 迁移断言必须红

---

# 十五、红线自检

| 红线 | 这个方案怎么守 |
|---|---|
| 只用星星币 | 商店、市场、扩地全部 `rewards.coins`，**没有第二种货币** |
| 无真实货币、无广告 | 全文没有 |
| 无抽卡/随机宝箱/概率商品 | **金色成熟是"连续三次及时收"，隐藏种子按等级固定藏，长草长虫按阶段固定出**。规则 2 静态强制 |
| 无连续登录奖励 | 「悄悄摘一颗」的门槛是**生长时间**不是日历（开放问题 D） |
| 无限时消失、无错过焦虑 | 作物永不死亡、熟了冻住、临时篮不过期、帮助任务一直等着 |
| 无一次点击直接扣费 | 买种子必须"先看三个数字 → 确认"，5 秒内可全额退 |
| 无红点催促进店 | 小狗蹲着就是全部提示，没有数字角标 |
| 图标是主角，文字是注脚 | 七个工具全是图标；三个数字用 🪙⏱🧺 三个图标打头；访客记录是图 + 数字 |
| 无负面/报复/排行榜 | 访客记录措辞表 + tools_check 规则 3；小熊永不生气；没有任何比较 |

---

# 十六、等你回话的清单

1. **§0.1 的 A~F 六件事**（工具栏与"点一下"的关系是最要紧的一条）
2. 阶段划分和顺序接受吗？我建议**先做阶段 0（存档迁移，不出画面）**
3. 首页那个新按钮叫什么？「星光菜园」还是改叫「我的农场」？
4. 六种种子的价格/卖价（§7.1 那张表）你想调吗
5. 仓库首次升级的门槛（60 币 + 3 张订单 + 3 块木板）合适吗
6. 约 18 句新语音的词，我按老规矩先写进 `VOICE_SCRIPT.md`，等你全部做完一起录 —— 对吧？

**确认后我从阶段 0 开始，做完一个阶段给你截图和测试结果，等你确认再进下一个，全程不提交代码。**
