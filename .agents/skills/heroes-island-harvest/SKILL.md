---
name: heroes-island-harvest
description: 迭代《小英雄成长岛》的丰收挑战与菜园收菜界面（Godot 4.7）。当修改订单、作物交互、篮子、收菜反馈或对应的触控/UI 测试时使用。
metadata:
  short-description: 英雄岛收菜迭代
---

# 英雄岛收菜迭代

在不新建平行系统的前提下，让学龄前儿童也能顺畅理解收菜流程。项目以数据驱动：关卡内容放在 `data/`，可复用行为放在现有的收菜/菜园组件中，页面只负责编排状态与事件。

## 先判断工作路由

- 丰收挑战（`game_type: "harvest_action"`）：阅读 `scripts/minigames/harvest_action.gd`、`scripts/harvest/`、`data/levels.json`、`data/harvest_crops.json`，以及两个收菜探针。
- 每日菜园：阅读 `scripts/garden/garden_screen.gd`、`plot_view.gd`、`offline_growth.gd`、`farm_save.gd` 与菜园探针。
- 同时改动挑战和菜园时，必须保持两套经济系统独立：丰收挑战只计算关卡成绩，绝不把作物写入仓库；每日菜园使用种植周期的事务账本。

## 先复用，再新增

按以下顺序优先复用现有部分：

1. 使用 `UiKit`、`Juice`、`ScreenFit` 和既有主题完成 HUD 布局与反馈。
2. 使用 `HarvestTarget`、`HarvestBasket`、`Gesture`、`Maturity`、`TutorialDirector`、`HintDirector` 表达挑战中的交互语法。
3. 使用 `PlotView` 与菜园世界的增量刷新路径呈现每日菜园。
4. 只有现有组件确实无法承载行为时才新增组件，并在改动说明中写明为什么不能扩展现有组件。

不要新建第二套目标、篮子、手势识别、教程手势、作物飞行动画或订单 HUD 风格。叶子组件只上报事件；订单状态由页面级控制器统一拥有并连接这些事件。

## 丰收挑战不变量

- 必须只有一个“当前订单可用”的判定。目标显隐、命中测试、教程、提示和三级帮助都必须使用它。未来订单的作物不能被消耗，除非数量已被可靠地带入该订单。
- 必须只有一个“目标篮子”解析器。先应用例外规则，再调用 `HarvestBasket.takes()`；玩家校验与所有引导指针必须共用它。
- 田地中的目标保持可自由定位的 `Node2D`；HUD、订单进度和页面装饰保持在既有 UI 层的 `Control` 节点中。
- 多订单页面要清楚表示当前订单，并且不依赖文字也能区分已完成和未来订单。不要把延后出现的作物伪装成未成熟作物。
- 反馈应简短、不阻塞：复用 `Juice`/`TutorialDirector`，尊重低动态效果设置，纠错反馈不能带有惩罚感。

## 每日菜园不变量

- 作物生长只能从对应地块的时间戳开始累计，不能计算种植前的时间。
- 收获动画必须在地块重置前取得作物和数量；点击收获与刷动收获要传达同一种结果。
- `SaveManager.settle_farm()` 后，界面应通过状态变化事件或显式的恢复刷新更新，不能继续显示过期快照。

## 验证要求

- 每一项行为改动都要配套纯规则测试；涉及触控/UI 时，还要补场景探针，并覆盖现有探针覆盖的鼠标和触摸路径。
- 在 16:9 与 4:3 下渲染改动页面，检查真实截图，包括拿起作物后的分拣状态。
- 绝不能对正式 `user://` 运行会删除存档的探针。当前多个探针会删除 `SaveManager.SAVE_PATH` 及其备份：必须使用应用名和存档根目录都不同的临时项目，截图写入临时目录，并串行运行 Godot 实例。
- 收尾时运行范围最小的相关探针与 `python3 tools_check.py`；只有全量烟测已启用存档隔离时才运行它。

## 外部设计输入

本 Skill 借鉴 [`awesome-gamedev-agent-skills`](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) 的“小而可组合”路由方式：Godot UI 使用 `Control` 布局并做响应式验证，游戏手感和存档各自独立处理。不会把该仓库整套 Skill 拷入项目；以上项目规则才是这里的唯一准则。
