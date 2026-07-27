# 丰收行动 · 第三阶段设计（实施前）

**没有写实现代码。** 这份文档是你要的八项输出，外加三处我认为提示词需要改的地方
和理由。等你确认后再动 3.1。

---

## 零、先说素材包：18 张会被现有抠图工具毁掉

素材包是 64 张 1024×1024、纯 #00FF00 底的扁平卡通 PNG，风格和岛上现有美术是一路的。
README 说"方便沿用现有抠图流程"——**沿用不了**。

`tools/cut_monsters.py` 是为**照片式绿幕**写的：它判断背景的方法是"绿色比红蓝都
高"。奥特曼和怪兽身上没有纯绿，所以那条规则一直好用。**蔬菜身上全是绿的。**

跑一遍全部 64 张，量"画出来的东西还剩多少"：

| 保留比例 | 作物 |
|---|---|
| 0.16 – 0.28 | 卷心菜、甜椒、黄瓜、菠菜、西兰花、生菜、豌豆、芹菜、西瓜、罗勒、薄荷 |
| 0.57 – 0.74 | 水稻、猕猴桃、芦笋、玉米、云朵玉米、花椰菜、小白菜 |

西兰花抠完只剩一圈黑线，花全没了。**18/64。**

### 修法，已经验证

这批图不是绿幕拍出来的，是程序画出来的：底色是**精确的 #00FF00 平板**，占画面
77–83%，而作物自己的绿离它很远。量一下西兰花的颜色距离分布：

```
距离 #00FF00   0–4  : 846579 px   ← 底板
              4–120 :   1919 px   ← 抗锯齿边缘
            120–∞   : 200078 px   ← 画的东西
```

**120 到 240 之间是空的。** 两堆之间有一条谁都不在的裂缝，所以按"到 #00FF00 的距离"
切，而不是按"绿是不是最大"切，就完全分得开。

`tools/key_plate.py`（新，已写好并跑过全部 64 张）：距离 <12 全透明，>120 全不透明，
中间线性过渡当抗锯齿，只在半透明的那一圈做去绿。**64 张保留比例全部 ≥ 0.9**，
西兰花、卷心菜、生菜、西瓜、黄瓜、豌豆在 54px 下都还认得出来。

`cut_monsters.py` **不动**——怪兽那批照片式素材还得靠它，两种底两种切法，各归各的。

### 尺寸

1024² 存 64 张，游戏里最大画到 118px。建议导入时统一压到 **256²**（约 6% 的显存），
`assets/crops/<id>.png`。原图留在 zip 里，不进仓库。

---

## 一、当前可复用的菜园系统

提示词里点名的十二个模块，实际存在的名字：

| 提示词写的 | 项目里的 | 状态 |
|---|---|---|
| FarmManager | `scripts/garden/farm_save.gd` + `garden_screen.gd` | 可用 |
| FarmPlot | `farm_save.gd` 的 `PLOT` + 状态机 | 可用 |
| CropGrowthManager | `scripts/garden/offline_growth.gd` | 可用，纯函数 |
| InventoryManager | `scripts/garden/inventory_manager.gd` | 可用，两个独立库 |
| RewardManager | `scripts/reward/reward_manager.gd` | 可用，`grant()` / `record()` 幂等 |
| CurrencyManager | `scripts/shop/currency_manager.gd` | 可用，星章与星星币分离 |
| SaveMigrationManager | `save_manager.gd` 的 `_migrate()` | 可用，save_version 3 |
| GameClock | `scripts/core/game_clock.gd` | 可用，autoload |
| AdaptiveHintManager | `scripts/shared/hint_director.gd` | 可用，三级 |
| TutorialDirector | `scripts/shared/tutorial_director.gd` | 可用 |
| AudioManager | autoload | 可用 |
| Juice | `scripts/ui/juice.gd` | 可用 |

**还有四个提示词没提但这一期离不开的：**

- `LevelManager` —— 30 关的基类。管进出、结算、`LevelResult`、三星、`quit_level()`。
- `DragField` —— 拖拽 + 吸附，`SNAP := 118.0`。菜园播种就是它。
- `VariantPicker` —— 按关卡 id 播种的确定性随机。同一关重玩，东西在同一个地方。
- `difficulty()` / `harder()` / `harder_i()` —— **温和/普通/勇敢已经存在**，家长中心
  里设，30 关全部在用。

---

## 二、我建议改的三处，和理由

### 2.1 丰收行动应该是第 10 个玩法模板，不是菜园的子系统

提示词 §14 要 `scripts/farm/harvest/` 下十个新脚本、`scenes/farm/harvest/` 下五个新
场景。但提示词自己在同一节说"已有同类脚本时必须扩展，禁止重复创建平行系统"——
**已有的同类系统就是 `LevelManager`。**

丰收行动的定义是"2～4 分钟的小关卡、有三星、结算发星星币、不影响真实仓库"。这就是
这个游戏里"一关"的定义，一字不差。做成模板，白拿：

- 进出、暂停、返回、返回目标 —— `LevelManager` 已有并被 map_probe 每关验过
- 三星 —— `LevelResult.stars()`，结算屏已有
- 发奖幂等 —— `RewardManager.grant_for_level()`，含首次通关奖励
- 关卡解锁、地图入口、星章统计 —— `levels.json` 加 8 条就有
- 30 关回归 —— map_probe 会自动把这 8 关也实例化跑一遍

做成 `scripts/farm/harvest/harvest_manager.gd` 自己一套的话，上面每一样都要重写一遍，
而且新写的那份不在任何现有探针的视野里。

**建议：** `scripts/minigames/harvest_action.gd extends LevelManager`，
`data/levels.json` 加 8 关，`game_type: "harvest_action"`。
菜园里那个"丰收挑战"按钮 = `GameManager.start_level("harvest_01_carrot")`。

### 2.2 `harvest_difficulty_profiles.json` 会变成第二套难度系统

素材包里那份 profiles（gentle/normal/brave，含 `snap_radius`、`unripe_ratio`、
`hint_after_errors`）和项目里已有的 `difficulty()` + `harder()` 是同一件事的两种写法。
两套难度必然漂：家长在家长中心调成"温和"，丰收关却读 json 里的另一份。

**建议：** 参数留在 json 里（它们是好的默认值），但**读取走 `harder()`**——
json 存"普通档的值 + 每档的倍率"，实际值由现有的 `difficulty()` 算出来。一套开关。

### 2.3 19 种手势其实是 5 个识别器

`harvest_asset_catalog.json` 里 56 种作物用了 19 个 `harvest_gesture` 名字。按**手指
实际怎么动**分，只有五类：

| 识别器 | 覆盖的手势名 | 参数 |
|---|---|---|
| **点** | tap_collect, tap_pair, tap_cluster, tap_bundle, tap_seeds, memory_pick, match_color | 命中半径 |
| **定向拖** | pull_up, swipe_down, open_pod, roll_to_basket, pull_timing | 方向、最短距离、角度容差 |
| **旋转** | twist | 累计角度、方向不限 |
| **划线** | cut_stem, cut_cluster, swipe_cut, charge_then_cut | 线段、吸附半径 |
| **来回** | dig_search, shake_tree | 换向次数、每次最短行程 |

十九个 `match` 分支会长成十九个各自演化的 bug；五个识别器 + 一张参数表不会。作物数据
照样写 19 个名字（对策划友好），**映射到五个识别器**在一个地方做。

---

## 三、收获手势架构

```
harvest_screen (extends LevelManager)
  └── GestureField (Control, MOUSE_FILTER_STOP, 接 _gui_input)
        ├── 收到 InputEventScreenTouch / ScreenDrag / MouseButton / MouseMotion
        ├── 归一成 (id, 起点, 当前点, 轨迹)
        └── 交给命中目标的识别器
HarvestTarget (Node2D)
  ├── crop_id, maturity, gesture, tags
  ├── 命中区 = 圆，半径 = touch_tolerance × 难度倍率
  └── succeeded → 飞入篮子 / refused → 摇头
```

**三条不动的规则：**

1. **一个目标只能被收一次。** 收成功立刻从可命中集合里摘掉，飞行动画期间不可再命中。
   （和菜园收获同一条规则，同一个理由。）
2. **未成熟不是失败。** 点了摇头、出声、不扣时间、不扣星、不计错误上限。它只喂
   `HintDirector.missed()`，那是**提示**的计数器，不是惩罚的计数器。
3. **虚拟库存。** 关卡里摘到的东西进 `LevelResult`，不进 `InventoryManager`。
   结算时一次性发放，事务 id `harvest_<level_id>_<run_id>`。

**触摸和鼠标：** `_gui_input` 同时处理两族事件（触摸事件不会自动变成鼠标事件，这个
坑这个项目踩过一次，`MOUSE_FILTER_STOP` 的全屏 Control 吃掉 `ScreenTouch`）。
两种视口（1280×720 和 iPad 的 1280×960）都要跑，`tablet_probe` 已有这条路。

---

## 四、8 关详细流程

每关只加 1～2 个维度。第 8 关之前，孩子见过的手势不超过 5 个。

| # | 关卡 | 作物 | 手势（新） | 目标 | 新加的维度 |
|---|---|---|---|---|---|
| 1 | 拔出胡萝卜 | 胡萝卜 | **pull_up** | 5 | 手势本身 |
| 2 | 草莓红了吗 | 草莓 | tap_collect（已会） | 6 熟 + 3 生 | **成熟度判断** |
| 3 | 玉米剥一剥 | 玉米 | **swipe_down** ×2（先剥叶再摘） | 4 | **两步动作** |
| 4 | 土豆在哪里 | 土豆 | **dig_search** | 6，混 2 块石头 | **干扰物** |
| 5 | 果园摇一摇 | 苹果（红/青） | **shake_tree** | 8，两色分篮 | **分类** |
| 6 | 豌豆数一数 | 豌豆 | **open_pod** | 3 个盒子按数量 | **计数** |
| 7 | 多作物订单 | 番茄+胡萝卜+南瓜 | **roll_to_basket**（南瓜） | 3+2+1 | **订单组合 + 工具** |
| 8 | 丰收庆典 | 6 种 | 全部已教 | 3 张连续订单 | **顺序 + 检查点** |

**每关的完整节拍：**

```
进场（世界地图 → 关卡）
 → 语音一句 + 目标图标（不读字）
 → [第一次玩这个手势] TutorialDirector 演示一遍
 → 自由收获，HintDirector 在旁边看着
 → 达成主订单 → 第一颗星，立刻存
 → 达成全部主订单 → 第二颗星
 → 结算屏（现有的 ResultScreen）：三星 + 星星币 + 可选目标
```

第 8 关三个检查点：每完成一张订单立刻 `SaveManager.save_game()`，中途退出从最近
检查点回来，**已经交付的订单不重收也不重发**。

**难点在第 6 关。** "把豆粒按数量放进 3 个盒子"是这一期唯一一个需要孩子**读数字**的
地方。六岁孩子会数到 10 但不一定认得阿拉伯数字。建议盒子上画**点阵**（⚫⚫⚫）而不是
"3"，数字小小地跟在旁边——和游戏其它地方"图先文后"一致。

---

## 五、难度参数表

现有 `harder()` 的形状：`值 × 倍率^(档位-1)`。所以只写普通档的值和每档倍率。

| 参数 | 普通档 | 每档倍率 | 温和 | 勇敢 |
|---|---|---|---|---|
| 吸附半径 px | 78 | ×0.77 | 101 | 60 |
| 未成熟占比 | 0.22 | ×1.45 | 0.15 | 0.32 |
| 提示前的错误次数 | 2 | +1 | 1 | 3 |
| 角度容差（定向拖） | 35° | ×0.8 | 44° | 28° |
| 旋转所需角度 | 90° | ×1.15 | 78° | 104° |
| 来回次数（挖/摇） | 3 | +1 | 2 | 4 |
| 订单例外条数 | 0 | +1 | 0 | 1 |
| 可选计时 | 关 | — | 关 | 开 |
| 检查点数量 | 按关卡 | **不变** | 同 | 同 |

**勇敢档不减检查点、不加损失。** 难度只从"要想的事情更多"来，不从"错了更惨"来。

温和档的 101px 吸附略大于 `DragField.SNAP`(118) 的一半——两个目标的最小间距因此是
202px，比菜园的 236px 松，第 5 关一棵树上挂 8 个苹果时会紧。**这是一条要在 3.1 就
量出来的数**，不是等到第 5 关再发现。

---

## 六、数据结构

### `data/harvest_crops.json`（首期 14 种，不是 56 种）

```json
{
  "id": "carrot",
  "name_key": "crop.carrot",
  "asset": "res://assets/crops/carrot.png",
  "category": "root_vegetables",
  "harvest_gesture": "pull_up",
  "recogniser": "drag",
  "gesture_params": { "direction": [0, -1], "distance": 90, "angle": 35 },
  "maturity_visuals": {
    "unripe":       { "scale": 0.62, "tint": [0.55, 0.78, 0.42], "halo": "none" },
    "almost_ready": { "scale": 0.82, "tint": [0.85, 0.80, 0.45], "halo": "none" },
    "ready":        { "scale": 1.0,  "tint": [1, 1, 1],          "halo": "soft" },
    "golden":       { "scale": 1.05, "tint": [1.0, 0.92, 0.55],  "halo": "star" }
  },
  "harvest_count": 1,
  "tool_required": "",
  "touch_tolerance": 78,
  "difficulty": 1,
  "tags": ["orange", "root", "vegetable"],
  "special_rule": "",
  "voice_intro": "crop_carrot_intro"
}
```

首期 14 种：胡萝卜、草莓、玉米、土豆、苹果、豌豆、番茄、南瓜、西兰花、葡萄、橙子、
小麦、生菜、黄金胡萝卜。**素材包里 56 种全部保留在 `harvest_asset_catalog.json` 里
备用**，只是这一期不接。

### `data/harvest_orders.json`

```json
{
  "id": "harvest_07_mixed",
  "level_id": "harvest_07",
  "requirements": [ {"crop_id": "tomato", "count": 3},
                    {"crop_id": "carrot", "count": 2},
                    {"crop_id": "pumpkin", "count": 1} ],
  "allowed_maturity": ["ready", "golden"],
  "basket_rules": [ {"basket": "veg", "accepts_tags": ["vegetable"]} ],
  "exception_rules": [ {"tag": "golden", "basket": "gift", "beats": "basket_rules"} ],
  "optional_objectives": ["no_hints", "zero_unripe_taps", "find_golden_crop"],
  "reward": { "coins": 20 },
  "time_limit_optional": 180,
  "checkpoint_count": 2,
  "completion_transaction_key": "harvest_order_07_mixed"
}
```

`exception_rules.beats` 是 §六.5 那条"例外优先于普通分类"——写成数据里的一个字段，
而不是代码里的一个 if。

### 存档新增（`farm` 下）

```
harvest_runs        : { level_id -> {best_stars, runs, golden_found} }
harvest_checkpoint  : { level_id, order_index, collected, run_id }   ← 只存一份
paid_harvest_runs   : [ transaction_id ]     ← 有界，同 paid_harvests
```

`harvest_checkpoint` 只保留**当前那一关**的一份。退出重进不在这一关就丢掉——
一个孩子不会同时中途卡在三关里。

**不新增：** 库存（用 `InventoryManager`）、货币（用 `CurrencyManager`）、
星章（用 `levels`）、难度（用 `settings.difficulty`）。

---

## 七、文件清单

**新增**

```
tools/key_plate.py                       抠图（平板底），已写好验过
assets/crops/*.png                       14 张，256²，keyed
scripts/minigames/harvest_action.gd      关卡本体，extends LevelManager
scripts/harvest/gesture_field.gd         输入归一 + 五个识别器
scripts/harvest/harvest_target.gd        一个可收目标
scripts/harvest/maturity.gd              四档成熟度 → 五个视觉通道
scripts/harvest/basket.gd                篮子与分类规则
scripts/harvest/harvest_order.gd         订单、例外、检查点
scripts/harvest/interference.gd          干扰（3.5 才做）
data/harvest_crops.json
data/harvest_orders.json
tests/harvest_probe.gd                   纯逻辑：识别器、成熟度、订单、幂等
tests/harvest_touch_probe.gd             真实触摸，两种视口
```

**修改**

```
data/levels.json          + 8 关，game_type: harvest_action
data/strings.json         + 关卡名、语音 key
scripts/core/game_data.gd + harvest_crops / harvest_orders 载入
scripts/ui/icon_library.gd  可能补 2～3 个图标（手推车、采摘剪）
scripts/garden/garden_screen.gd  + 一个"丰收挑战"按钮
tests/run_smoke.sh        + 两个探针
tools_check.py            + harvest 数据规则
docs/HARVEST_ACCEPTANCE.md
```

**不建**：`scripts/farm/harvest/` 下的十个文件、`scenes/farm/harvest/` 下的五个
场景、`harvest_difficulty_profiles.json`、`harvest_interference.json`、
`harvest_tutorials.json`（理由见第二节；干扰和教学的配置并进 orders / crops）。

---

## 八、美术、动画、音效、语音缺口

**美术** —— 素材包解决了作物本体。**缺的是"同一个作物的四种成熟度"**：包里每种作物
只有一张图。方案是**程序化派生**（`maturity_visuals` 里的 scale + tint + halo），
不需要新画 4×14 张。代价是"未成熟"看起来是"小一点、绿一点的成品"而不是真正的幼果。
**六岁孩子够用，但值得你先看一眼再定。**

还缺：土块/泥土飞溅、豆荚打开的两态、树干摇动、手推车、切线高亮、篮子接住的反馈。
这些都能用现有 `Shapes` / `Juice` 画。

**动画** —— 全部可用现有 tween + `Juice.burst/shockwave/pop`。没有骨骼动画需求。

**音效** —— 现有可复用：`water.ogg`、`drag_snap.ogg`、`drag_back.ogg`、`star.ogg`、
`coin.ogg`、`correct.ogg`。**缺 6 个**：拔出（噗）、挖土（沙沙）、剪断（咔）、
摇树（叶响）、豆荚开、手推车滚。`tools/make_audio.py` 能生成。

**语音** —— 缺 12 句左右，全部走现有 `docs/VOICE_SCRIPT.md` + `voice_check` 流程：
每种手势一句教学、"再等一等，它还没长大"、"放进红篮子"、"带星星的放礼物篮"、
"还差几个呢"、订单完成、庆典完成。**占位路径先接上，缺音频不报错不卡流程**——
这条已经是项目的既有规矩。

---

## 九、测试计划

提示词 §17 的 20 条，映射到两个新探针 + 现有回归：

| 条 | 落在哪 |
|---|---|
| 1 手势在鼠标和触摸下都行 | `harvest_touch_probe`，两族事件各推一遍 |
| 2 容差角度和距离有效 | `harvest_probe`：容差内成功、容差外失败**且不惩罚** |
| 3 未成熟不能被误收 | `harvest_probe` + touch |
| 4 点未成熟不扣奖励 | `harvest_probe`：点 5 次生果，星和币不动 |
| 5 目标不重复计数 | touch：同一个目标连点，只算一次 |
| 6 进正确篮子 | `harvest_probe` |
| 7 订单数量正确 | `harvest_probe` |
| 8 例外优先于普通分类 | `harvest_probe`：`beats` 字段的专项 |
| 9 切换篮子不丢物品 | touch |
| 10 大作物用手推车 | touch |
| 11/12 检查点保存与恢复 | `harvest_probe`：存→重载→断言进度 |
| 13 普通菜园收获不重复发奖 | **已有**，`garden_touch_probe` |
| 14 挑战不改真实库存 | `harvest_probe`：跑完一关，`InventoryManager` 一动不动 |
| 15 结算只发一次 | `harvest_probe`：重开结算三次，币只涨一次 |
| 16 三档生效 | `harvest_probe`：三档各跑一遍，断言参数确实不同 |
| 17 提示不会卡住 | touch：三级提示走完仍可继续 |
| 18 目标始终可完成 | `harvest_probe`：每关断言"可收的量 ≥ 订单要求" |
| 19 低分辨率不遮挡 | **已有** `tablet_probe`，加这 8 关 |
| 20 菜园和 30 关回归 | **已有** map_probe / smoke / garden 全套 |

**每条新断言都要被故意打破一次**，这是这个项目的规矩，二期十三轮破坏里有四轮打出来
的是断言自己的洞，不是代码的洞。

---

## 十、工作量与我的建议

提示词 §16 分了 3.1～3.6 六个小阶段。按二期的实际速度（一个完整闭环 ≈ 一个长会话），
诚实估计：

| 阶段 | 内容 | 估计 |
|---|---|---|
| 3.0 | 抠图 + 导入 14 张 + 数据文件骨架 | 短 |
| 3.1 | 五个识别器里的三个（点/定向拖/旋转）+ 第 1 关 | 一个会话 |
| 3.2 | 成熟度四档 + 未成熟保护 + 两个篮子 + 第 2 关 | 一个会话 |
| 3.3 | 订单、例外、检查点 + 第 3、7 关 | 一个会话 |
| 3.4 | 划线 + 来回两个识别器 + 第 4、5、6 关 | 一个会话 |
| 3.5 | 干扰机制 | 一个会话 |
| 3.6 | 第 8 关庆典 + 三星结算 + 挑战模式入口 | 一个会话 |

**六个会话，不是一个。** 提示词把 19 种手势、8 种订单、7 种干扰、5 个难度级、8 个
关卡、5 个数据文件、10 个脚本、5 个场景放进了"第三阶段"，这比一二期加起来还大。

**我的建议还是那句：先让孩子玩几天二期的菜园。** 星光菜园刚刚才有了教学和收获闭环，
他还一次都没在真机上种过一根胡萝卜。丰收行动是给"已经会种菜、开始觉得种菜不够"的
孩子准备的——先看看他是不是真的到了那一步，比先把它做完更有价值。

如果要开工，从 **3.0 + 3.1** 开始：抠图、导入、三个识别器、第一关"拔出胡萝卜"。
一关能玩通，比六个系统半成品有用。
