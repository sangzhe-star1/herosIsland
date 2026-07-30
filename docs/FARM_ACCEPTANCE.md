# 星光菜园 · 首期验收对账

十七条验收标准，逐条指到证明它的那句断言上。**不是"应该没问题"，是"哪个探针的
哪一行会在它坏掉的时候变红"。**

跑法：

```
GODOT=/path/to/godot ./tests/run_smoke.sh     # 23 个检查点，约 10~12 分钟
python3 tools_check.py                        # 0 errors
```

---

| # | 验收标准 | 探针 | 断言 |
|---|---|---|---|
| 1 | 新存档可以正常进入菜园 | `smoke_test.gd` + `garden_touch_probe.gd` | smoke 把 `levels.json` 里**每一关**都实例化跑 6 帧（含 `star_garden`）；触摸探针每轮都从一份全新存档打开菜园 |
| 2 | 旧存档升级后不丢主线、衣服、图鉴 | `garden_probe.gd` | `_an_old_save_grows_a_garden()`：一份有 359 经验、214 星星币、2 徽章、3 张图鉴卡、3 件衣服、`worn` 记着哪个英雄穿了什么、两关成绩（含隐藏宝石）而**没有 farm 字段**的老档，走真实 JSON 往返后逐项断言"一样没动"，然后菜园出现 |
| 3 | 可以在 4 块土地上独立种植 | `garden_probe.gd` | `_a_new_child_finds_four_empty_plots()` 断言四块地四个不同 id；`_the_four_plots_do_not_share_a_clock()` 四块地不同作物不同时间种下，同一刻结算后进度依次递减，清掉一块不动其余三块 |
| 4 | 同一块地不能重复播种 | `garden_touch_probe.gd` | `_one_bed_takes_one_crop()`：拖第二颗种子到已种的地，作物不变、`planted_at` 不重置。**机制是"已种的地不注册投放点"**，孩子连高亮圈都看不见 |
| 5 | 作物成长阶段正确 | `garden_probe.gd` | `_a_carrot_goes_through_five_stages()`：逐阶段验证，**差一秒不进阶、到点就进阶**，最后一阶段走完变成可收获 |
| 6 | 退出重进后状态恢复 | `garden_probe.gd` + `garden_touch_probe.gd` | `_it_survives_being_closed()`；触摸探针交付订单后 `load_game()` 再查 `delivered` |
| 7 | 玩主线期间作物继续成长 | `garden_probe.gd` | `_it_grows_while_he_is_playing_a_level()`：菜园**根本不在场景树里**，只推进时钟，回来阶段已经前进——因为生长是从时间戳算出来的，不是有东西在跑 |
| 8 | 系统时间倒退不会让进度异常 | `garden_probe.gd` + `clock_probe.gd` | `_a_clock_dragged_backwards_does_not_break_it()`：往回拨一周不倒退、不出负数、`clock_high_water` 记住最高点，从新时间继续长；`clock_probe` 另外验 `elapsed_since()` 永不为负 |
| 9 | 系统时间前进不会无限领奖 | `garden_probe.gd` + `clock_probe.gd` | `_a_clock_dragged_forwards_ripens_once()`：往前拨一年只换来"渴着等"，浇水后成熟一次，再拨两千天纹丝不动；`clock_probe` 验一次缺席最多值 `MAX_OFFLINE_SECONDS`（8 小时） |
| 10 | 收获数量正确进入仓库 | `garden_touch_probe.gd` | `_tapping_a_ripe_bed_fills_the_barn()`：收一次进仓库的数量**精确等于**作物的 yield，地块回到空的翻好土，**再点一次不再给** |
| 11 | 订单不能重复领奖 | `garden_probe.gd` + `garden_touch_probe.gd` | `_an_order_pays_once()`：连领四次只付一次、`delivered` 里只写一条、存盘重开后仍不付；触摸侧按卡片、再按、以及**绕过按钮直接调交付**都验 |
| 12 | 星星币正确增加 | `garden_probe.gd` | 同上：余额精确等于 `before + price`，多按几次不动。菜园全程**没有一处直接写 `rewards.coins`**（静态规则 5e 强制） |
| 13 | 关卡星章不会变化 | `garden_probe.gd` | `_the_garden_cannot_touch_his_score()`：种→长→收→交付走完整轮，`total_stars()`、关卡条数、徽章数**一个都没动**，只有能花的那个数变了 |
| 14 | 作物不会永久死亡 | `garden_probe.gd` | `_a_crop_never_dies()`：两周不管，断言**没有"死亡"这个状态**，最坏是"渴着，一点没少地停在原地"，浇一次水照样收得到 |
| 15 | 触摸拖动和自动吸附正常 | `garden_touch_probe.gd` | `_dragging_a_seed_lands_in_the_bed_he_aimed_at()`：真实 `InputEventScreenTouch`／`ScreenDrag`，**故意偏离中心 40px 松手**，落进瞄准的那块地、其余三块没接到。**两种视口各跑一遍**（1280×720 与 iPad 的 1280×960，坐标按窗口像素换算） |
| 16 | 菜园能正常返回 | `garden_touch_probe.gd` | `_there_is_a_way_out()`：返回键存在、够大（拇指）、在屏内、**接了东西**。⚠️ 见下方偏差说明 |
| 17 | 现有 30 关完整回归通过 | `map_probe.gd` + `smoke_test.gd` | `map_probe` 把**每个世界的每一关**实例化跑 10 个物理帧并断言不死；`smoke_test` 另外加载 7 个固定屏 + 每一关；`run_smoke.sh` 全套 23 个检查点结尾 `All good.` |

---

## 第 16 条的偏差已按原文收回（2026-07-29 Zane 拍板）

首期为了和其余关卡一致，菜园曾返回世界地图并在此记为偏差。现按验收原文落地：
**菜园的返回键通向英雄基地（hero_studio）**。去哪个房间写在数据里
（`levels.json` 的 `star_garden.config.exit_room`），代码不点任何房间的名；
没配或配错时安静退回世界地图，孩子永远出得去。`garden_touch_probe` 盯着
这条数据：必须存在、必须是真房间、场景必须真的在。

代价也写明：这是全游戏唯一一处"从地图进、不回地图"的门，孩子从地图进菜园、
出来站在基地门口。设计上读作"回家"；如果实测发现他迷路，改回来是删一行数据。

## 两条首期明确不做的，确认还没做

- **除草**在阶段 4 补上了（确定性长草，第 2 阶段长一次，拔了不再长）
- NPC 拜访、悄悄摘一颗、加工小屋、大量食谱、菜园扩建、16 种作物、复杂装饰、
  真实网络玩家、排行榜——**都没做**，按首期约定

## 还欠一句配音

`star_garden_intro.wav`：「翻翻土，把种子放进去，别忘了浇水。」

词已经写进 `docs/VOICE_SCRIPT.md`，`voice_check` 每次跑都会打印
`WAITING TO BE RECORDED`——它区分"没人写过词"（失败）和"写好了等着录"（提示），
所以这一句不挡任何东西，等最后一起录。
