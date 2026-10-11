# 菜园与丰收页双画幅回归 — 2026-10-11

本组验收覆盖菜园主画面、市场面板和 `harvest_02`，每页均检查 16:9（1280×720）与 4:3（1024×768）；丰收页另覆盖低动态模式。当前截图与草莓株身接入前的提交 `3b1954ae7a7d354adaf7056ea8b83df71484d191` 使用相同夹具对照。

| 页面 | 16:9 | 4:3 |
| --- | --- | --- |
| 菜园 | [当前](garden_16x9.png) · [基线](baseline_garden_16x9.png) | [当前](garden_4x3.png) · [基线](baseline_garden_4x3.png) |
| 市场 | [当前](market_16x9.png) · [基线](baseline_market_16x9.png) | [当前](market_4x3.png) · [基线](baseline_market_4x3.png) |
| 丰收普通态 | [当前](harvest_normal_16x9.png) · [基线](baseline_harvest_normal_16x9.png) | [当前](harvest_normal_4x3.png) · [基线](baseline_harvest_normal_4x3.png) |
| 丰收低动态 | [当前](harvest_low_motion_16x9.png) · [基线](baseline_harvest_low_motion_16x9.png) | [当前](harvest_low_motion_4x3.png) · [基线](baseline_harvest_low_motion_4x3.png) |

本轮共渲染 16 张图，全部使用 `tests/qa_run.py` 的独立项目副本和唯一 `user://`，逐个串行启动；运行均退出 0，菜园/市场由 `FarmShot` 在保存前检查非空画面，丰收截图由 `screenshot_tool` 的 `CONTENT PASSED` 门禁确认。具体命令日志、尺寸与 SHA-256 记录在 [`results.json`](results.json) 和 [`baseline_results.json`](baseline_results.json)。没有读取或写入正式玩家存档。

目视复核结论：

- 菜园在两个比例下保持顶栏、底部工具坞、作物栏和任务条的固定层级；4:3 增高视口露出更多世界，未遮住工具和任务入口。
- 市场面板在两个比例下均完整留出关闭入口、仓库作物、待出售数量和结算按钮；4:3 下背景扩展没有挤压交互区。
- 对照基线后，菜园与市场的主要层级和操作区保持稳定。丰收页新增的草莓叶冠株身落在果实下方，篮子、订单计数和触控提示区域仍可见，没有遮挡 HUD 或篮口。
- 低动态画面仍保留订单计数、目标和篮区可见；本组不以静态截图代替复杂手势回归，相关手势和低动态提示仍由 `HarvestTouchProbe` 覆盖。
- 丰收页整体仍能看出不同 3D 作物与背景的表达差异；这组截图只通过布局回归，不代表风格试片、儿童辨识或目标 iPad 性能已验收。作物摆位含随机差异，基线用于目视比较层级和遮挡，不作为逐像素差分。

## 结果

P4-3 的双比例截图和低动态布局回归通过，可以标记完成。P4-1 风格统一、P4-2 目标设备与小尺寸辨识、P4-4 儿童观察/模拟任务、P4-5 中文展示字试片保持开放。
