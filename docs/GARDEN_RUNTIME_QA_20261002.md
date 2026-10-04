# 菜园运行与节点寿命证据（2026-10-02）

## 本轮修复

`GardenScreen` 的挑战预览先创建星星，再用下一关作物覆盖变量。旧星星从未挂到父节点，也未释放；每次重建遗失一个 Control、两个 Polygon2D 和一个 Line2D。现先解析图片引用，再只调用一次既有 `UiKit.picture()`，作物与通关星星的显示规则保持一致。

触控探针新增两种预览各连续重建八次的检查：保留唯一图片、元数据正确、孤立节点数不增长。探针要求调试引擎提供真实寿命计数，避免发布构建返回零造成漏检。

## 隔离与运行

- QA 项目：`/private/tmp/heroes-garden-continuation-qa-20261002-oz9ovtra`。
- 应用名及自定义存档目录均为 `heroes-garden-continuation-qa-20261002-oz9ovtra`，探针删除的是独立存档。
- Godot 4.7.1；OpenGL Compatibility / Apple M5 Pro；音频使用 Dummy 驱动。
- 所有实例串行运行，检查包含 AppTranslocation 在内的 Godot 可执行路径；运行器只在超时时终止自己启动的进程组。
- 日志位于 QA 的 `qa_logs/`，截图位于 `qa_shots/`；本轮所有运行正常退出，无超时终止。

## 修复前后同一寿命诊断

隔离夹具 `tests/GardenLifetimeDiagnostic.tscn` 连续三次进出菜园，每次三轮打开、关闭订单、商店、市场、仓库、拜访、配方和厨房，共129次重建。关闭后等待删除队列及20秒菜园计时器结束，才记录最终结果。旧脚本保存为 `qa_logs/garden_screen_before_lifetime.gd.txt`。

| 指标 | 修复前 | 修复后 |
| --- | ---: | ---: |
| 第一轮进出后孤立节点 | 172 | 0 |
| 三轮进出后孤立节点 | 516 | 0 |
| 关闭后树内节点 | 16 | 16 |
| 关闭后运行中 Tween | 0 | 0 |
| 关闭后菜园恢复回调 | 0 | 0 |
| 退出 CanvasItem RID 告警数量 | 516 | 无告警 |
| 退出 GLES mesh RID 告警数量 | 258 | 无告警 |
| 退出 ObjectDB 告警数量 | 649 | 4 |
| 退出资源告警数量 | 2 | 2 |

两次运行均25.0秒、exit 0。证据：`lifetime_before.log`、`lifetime_after.log`。每次重建增加4个孤立节点，与129×4=516及此前完整触控日志944/472的绘图残留吻合。

## 完整触控与截图

- `GardenTouchProbe` 实际询问1094项，全部通过，39.4秒、exit 0；日志 `garden_touch_lifetime_fixed.log`。
- 窗口1280×720 → 游戏视口1280×720；窗口1024×768 → 游戏视口1280×960。
- 覆盖原有市场持货、收据滚动、快速减到零、拒绝出售、回填配方、应用恢复、教程与经济等检查，以及新增预览寿命检查。
- `garden_lifetime_16x9.png` 与 `garden_lifetime_4x3.png` 均实际生成并目视复核；预览、顶部按钮、工具与种子行布局正常。两个截图运行各4.4秒、exit 0。
- 完整触控与两次截图均不再报告 CanvasItem 或 mesh 残留。
- `tools_check.py`：0 errors、204 warnings；`git diff --check`通过。

## 音频退出对照与探针收尾

上面的历史日志在退出时仍留下 Ogg 播放对象。随后在同一隔离项目中用 `AudioExitDiagnostic.tscn` 单独对照：每个驱动四批、每批16次切换音乐/音效/语音，共64次，最后再启动音效和语音。输出静音，实际音频服务继续工作；日志直接记录 `AudioServer` 返回的驱动名。

| 实际驱动 / 退出方式 | 四批对象 / 资源 / 节点 | 退出 ObjectDB / 资源告警 | 耗时 / 退出码 |
| --- | --- | --- | --- |
| Dummy / 直接退出 | 每批1534 / 29 / 16 | 14 / 6 | 6.1秒 / 0 |
| Dummy / 停止、清空流、等待混音 | 每批1534 / 29 / 16 | 无告警 | 7.1秒 / 0 |
| CoreAudio / 直接退出 | 每批1535 / 29 / 16 | 14 / 6 | 6.6秒 / 0 |
| CoreAudio / 停止、清空流、等待混音 | 每批1535 / 29 / 16 | 无告警 | 7.7秒 / 0 |

四次检查均通过，孤立节点始终为0。清理后三条通道均不播放且不持有流，资源数降至23；等待期间混音时间确实推进（Dummy 5.903413→6.958133，CoreAudio 6.427494→7.440830）。日志为原QA目录下 `qa_logs/audio_{dummy,coreaudio}_{direct,drained}.log`。结果支持本次退出告警来自音频收尾时机，且这64次切换没有资源增长；此对照不代替目标设备长时间运行验收。

`tests/probe_lifecycle.gd` 现提供共用的 `finish(probe, exit_code)`：停止现有三条 `AudioManager` 通道、清空流、等待1秒及两帧后退出。`GardenTouchProbe` 和 `FarmShot` 已采用；产品 `AudioManager` 未修改，断言和截图在收尾前完成。

## 新 QA 入口实际复验

`tests/qa_run.py` 在当前源码副本中导入和运行，应用名与自定义存档目录均采用新副本的唯一名称。使用说明见 [QA运行器](QA_RUNNER.md)。

- 触控副本：`/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-garden-lifecycle-7ivhh0rr`；导入3.2秒，1094项全部通过，运行40.2秒，均exit 0。
- 截图副本：`/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-garden-shots-dbckhx7a`；导入3.1秒，两次截图各5.3秒，均exit 0。
- 真实PNG为 `qa_shots/garden_16x9.png`（1280×720）和 `garden_4x3.png`（1024×768）。已目视复核顶部按钮、挑战预览、工具和种子行，未遮挡操作区域。
- 上述两组全部日志均无脚本/解析错误、ObjectDB、资源、CanvasItem或mesh残留告警。
- 运行器13项单元检查通过（3.573秒，不启动Godot）。原29场景的完整smoke范围和顺序已保留为清单；本轮没有运行全部29场景，不能据此宣布完整smoke通过。

## 尚未完成

整株素材、奖励和状态图标的完整小尺寸检查、目标平板性能与首帧验收继续由当前改造计划推进。

随后的小尺寸图标修复已独立复验当前菜园1094项（37.1秒）及市场/日常状态/普通菜园六张双比例页面图；其中一次先前连续运行的截图出帧超时仍未定位。范围与日志见 [P4图标尺寸证据](P4_ICON_QA_20261002.md)。

## 节点寿命修复时的输入 SHA-256

- `scripts/garden/garden_screen.gd`: `6b7192d99ce80da5fa579f99e8eb28e3a3d210e4183b3a0001b7a7ad81e975bd`
- `scripts/shared/drag_field.gd`: `03e6ab7f918bcd9d362266f77b26faf1b38d42a1e7ba8dda5a0591230e790fd2`
- `tests/garden_touch_probe.gd`: `20eebf1513e93141ab369e4134d7f473161f6132b1dd285b55d81e6fff748fa9`

## 新入口实际复验的输入 SHA-256

- `scripts/core/audio_manager.gd`: `e68773f6d99e42e6bd49a08dea89abca53442dc79f3dc80ede76c4038f7cd5ba`
- `tests/qa_run.py`: `fbd3b93db0c69df7d37f2cf6a4d3e8b3f6d40cd856b2d8f2df145b3a1a6940e4`
- `tests/probe_lifecycle.gd`: `d180f17731080253507a7c62ca3eaef5faebeaf08aa3b361c1af6c0e1e17e934`
- `tests/garden_touch_probe.gd`: `76c8ee9c06ab7e6fb62842dcad0e7c627423b5f7bb86287a9cbe9d2cf80b05f3`
- `tests/farm_shot.gd`: `9b307d0b43d5c5ef943efc25681d96902fc562d3cc3101d531812055c8b28db1`

## 后续：收纳目的地可见性

真实部分/全满仓截图发现一个此前数量与坐标检查遗漏的问题：装饰入口完全遮住了溢出篮，飞行仍然落到正确坐标。现将入口移到工具行右端，紧凑主任务条按入口边界留12px间距，保留原篮口与收纳规则。触控探针对部分、全满仓各增加一次入口/篮子不相交检查，双比例从1094项增为1098项。

- 成功副本：`/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-overflow-visible-om9_awhx`。
- 导入3.1秒，完整菜园触控1098项通过、40.1秒、exit 0。
- 普通/七种子页各双比例，4次真实触摸收菜截图夹具各36项通过、6.5–6.6秒，生成24张PNG；日志无脚本/解析或退出残留告警。
- 四张六阶段联系表和关键原尺寸图已复核篮口、入口、任务条、翻页箭头和真实仓库数量。该批仅覆盖胡萝卜部分入库、草莓全溢出；低动态、更多作物和设备性能仍待验证。

失败运行、布局修复、图片路径及对应三份输入hash见 [奖励与溢出目的地记录](P4_BADGE_QA_20261002.md)。

随后独立复核发现最低检查数仍是旧1094，已同步1098；收纳夹具增加入口/任务条存在与七种子/箭头检查。新副本 `heroes-qa-overflow-guarded-c873qh3l` 导入3.0秒，菜园1098项通过39.935秒，普通双比例各40项、七种子双比例各46项，共172项，24原始PNG、无运行错误或退出残留。产品菜园hash与上一批相同；该副本仍使用旧QA运行器，错误检查另由调用脚本执行，不能据此宣布后续运行器增强已通过真实引擎验收。

共用QA运行器随后将行首 `ERROR:` 纳入所有场景的默认失败条件，防止引擎错误被 `PASSED` 掩盖；15项纯Python检查通过，未额外启动Godot。契约、输入hash与测试范围见 [QA运行器](QA_RUNNER.md)。
