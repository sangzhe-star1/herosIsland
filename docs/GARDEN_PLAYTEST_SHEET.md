# 星光农场试玩记录

一轮只记录真实发生的事，不按“功能都找到”来引导孩子。开始前不要讲解访客、集市日、小狗技巧或设施倒计时；先让孩子从自己熟悉的入口开始玩，观察他自然看见什么、在哪里停下来、是否请求帮助、之后有没有主动回来。

## 本轮信息

- 日期与时长：
- 游戏版本 / Git 提交：
- 设备与屏幕方向：
- 孩子从哪个页面开始：
- 是否使用日常存档：是 / 否
- 观察者：

## 设施等待

每个设施记录开始操作、产物可领取的时刻，以及等待期间孩子实际做了什么。秒数是对照值，不要告诉孩子。

| 设施 | 对照时间 | 开始时刻 | 实际完成时刻 | 等待时做了什么 | 主动回来收取？ | 原话 / 求助 |
|---|---:|---|---|---|---|---|
| 鸡舍 | 120 秒 | | | | | |
| 风车 | 90 秒 | | | | | |
| 牛棚 | 150 秒 | | | | | |
| 蜂箱 | 90 秒 | | | | | |

## 自己发现的事

- 来访朋友：从进入农场到第一次注意到访客用了多久？他怎么理解访客想要什么？是否自己打开好友农场或交付菜肴？
- 集市日：他是否注意到提前公告？能否在没有讲解时说出哪种作物更值钱、什么时候卖？
- 雨云：他是否主动把云拖到需要照料的地块？第一次成功前试了几次？
- 小狗与种地：在同一段自由游戏里，他主动扔棍子、照料作物、查看设施各做了几次？哪件事之后他还继续玩？

## 结束时

- 他主动重复最多的动作：
- 停下来或看向大人的时刻：
- 他试了但游戏不支持的动作：
- 他问了什么，或用自己的话讲了什么：
- 明天还想不想继续玩？记录他的主动表达，不要追问：

## 旧存档迁移（有 iPad 备份时）

先在设备上保留原档的独立副本，把副本导出到 Mac；不要把审计产生的规范化副本直接覆盖回设备。按 [真实存档审计说明](SAVE_MIGRATION_AUDIT.md) 运行：

```bash
python3 tests/audit_garden_save.py --save /absolute/path/to/save_game.json
```

- 报告目录：
- `basic_checks_passed`：是 / 否
- `human_review_required`：是 / 否
- `lost_farm_keys`：
- `changed_farm_keys`：
- XP、星星币、地块、仓库与篮子核对：
- 设备上打开原档是否成功：
- 设备上主要进度是否仍在：

先核实报告中的变化与原档内容，再在设备上用保留的原档副本验证。若发现任何进度缺失，立即停止写回并保留两份文件供进一步分析。

## 本机预检（2026-10-10）

- Godot 4.7.1 的 iOS 工程导出成功，Xcode `generic/platform=iOS` arm64 Debug 编译成功（未签名）；这只确认导出与编译链路，不代表已在真机运行。当前导出的工程保存在本机忽略目录 `build/ios-preflight/HeroesIsland.xcodeproj`。
- 首轮预检发现 `item_sorting.gd` 把金色反馈颜色传给 `Juice.burst` 时触发参数错误；现已支持可选颜色并重导，未再出现脚本解析错误。`FeedbackProbe` 的 34 项检查通过。
- 本机没有连接实体 iPad。iPad 模拟器安装失败：当前安装的 Godot 模拟器模板库实际只有 x86_64，而本机的 iPad 模拟器要求 arm64；已编译的 x86_64 app 被 iPadOS 拒绝安装。
- 因此计时、自然发现和旧存档项目仍待实体 iPad 验证；完成后填写本表，不要把模拟器预检当作试玩结果。

## 复验更新（2026-10-10）

- 在当前 `main` 的 `efa0945` 上重新导出到忽略目录 `build/ios-current/HeroesIsland.xcodeproj`。Xcode `generic/platform=iOS` 的未签名 Debug 构建通过，app 二进制确认为 arm64。真机列表仍只有 MacBook Pro，没有连接 iPad。
- 用这次导出工程复测 `generic/platform=iOS Simulator`：仍因 Godot `libgodot.a` 只有 x86_64 而无法链接 arm64；XCFramework 清单虽列出 arm64 simulator，库的实际切片不含它，最终报 `_main` 未定义。设备版可编译，模拟器和真机运行尚未验证。
- 额外对本机 Godot 用户目录里的现有 Mac 存档做了隔离审计：源存档 `save_version=4`、38 个农场字段和 6 块地；8/8 项基础保留检查通过、`lost_farm_keys` 为空，原文件 SHA-256 前后相同。审计报告将 8 个结算相关字段标为需人工复核；这不是 iPad 备份，不能替代真实设备旧档验证。

## 模拟器模板修复与运行边界（2026-10-10）

- 复核了 Godot 4.7.1 的 XCFramework：`Info.plist` 声明 `arm64 x86_64`，但官方模拟器库实际只有 x86_64。这与 Godot 的 [4.7.1 模拟器切片问题](https://github.com/godotengine/godot/issues/122379)一致。
- 在被忽略的 `build/ios-current/` 中检出 Godot `4.7.1-stable`（源码提交 `a13da4f`），运行 `scons platform=ios target=template_debug arch=arm64 ios_simulator=yes` 编出 arm64 静态库；用 `lipo -create` 与原 x86_64 库合成临时通用切片。`lipo -archs` 确认为 `x86_64 arm64`。没有把 Godot 源码、生成库或修改后的模板加入项目。
- 核心复现命令（从仓库根目录运行；完整源码、SCons 虚拟环境和中间输出都留在被忽略的 `build/`）：

  ```bash
  cd build/ios-current/godot-4.7.1-src
  ../scons-venv/bin/scons -j8 platform=ios target=template_debug arch=arm64 ios_simulator=yes
  cd ../../..
  xcrun lipo -create \
    build/ios-current/SimulatorX86DerivedData/Build/Products/Debug-iphonesimulator/libgodot.a \
    build/ios-current/godot-4.7.1-src/bin/libgodot.ios.template_debug.arm64.simulator.a \
    -output build/ios-current/SimulatorMerged/libgodot.a
  cp build/ios-current/SimulatorMerged/libgodot.a \
    build/ios-current/HeroesIsland.xcframework/ios-arm64_x86_64-simulator/libgodot.a
  lipo -archs build/ios-current/HeroesIsland.xcframework/ios-arm64_x86_64-simulator/libgodot.a
  ```

- 合并后的模拟器工程由 Xcode 编译成功；普通 app 和唯一 QA bundle `com.family.heroesisland.qafarm` 都成功安装并启动在 iPad Pro 13-inch (M5) / iOS 26.5 Simulator。QA bundle 使用独立 `user://` 容器，未接触正式 app 存档。
- **触控探针未通过，也未判失败。** 全量 904 项探针运行超过 11 分钟，只写出 `harvest_feedback_1280_720.png` 与 `friend_door_1280_720.png`，没有最终断言标记；后续 `--market-sale-only` 运行超过 6 分钟仍停在灰屏和农场初始化，专用存档没有离开启动状态。采样显示主线程反复耗在 iPad 高分辨率的 GLES 软件栅格化；停止这两次测试以免继续占用机器。模拟器启动画面有上下留黑，不能替代横屏实体设备观察。
- 因此只确认了导出、链接、安装和启动；**没有确认**模拟器触控探针完整通过、孩子的计时/自然发现体验或真实 iPad 旧档迁移。iPad 备份尚未导出；收到备份后仍按上面的只读源文件审计流程执行，再由人工核对报告。
- 同一 `main` 提交上的桌面隔离回归：`./tests/run_smoke.sh` 为 30 passed、0 skipped；`python3 tools_check.py` 为 0 errors、208 warnings；文档改动通过 `git diff --check`。
