# Godot QA 运行器

`tests/qa_run.py` 用当前工作区副本运行探针，适用于 macOS / Linux、Python 3 和项目指定的 Godot 4.7。`tests/run_smoke.sh` 已使用同一入口。

## 单个探针

在项目根目录运行：

```bash
python3 -B tests/qa_run.py --name garden --timeout 90 \
  --expect "GARDEN TOUCH PROBE PASSED" \
  -- --rendering-driver opengl3 res://tests/GardenTouchProbe.tscn
```

`--` 前是运行器参数，后面是 Godot 参数。默认查找应用目录或 PATH 中的 Godot；也可设置 `GODOT` 或 `--godot /path/to/Godot`。`--project` 可指定源码目录，默认本仓库；`--name` 只用于副本名称；`--audio-driver` 默认 `Dummy`。

单场景默认墙钟上限120秒，导入也默认120秒；`--timeout` 同时覆盖两者。成功要求退出码0、没有脚本/解析或引擎 `ERROR:`，以及出现指定 `--expect` 标记；指定 `PASSED` 时，对应的 `FAILED` 标记也会导致失败。导入与场景使用同一错误检查，打印 `PASSED` 后出现运行期或退出期 `ERROR:` 仍会失败，原日志保留。不指定 `--expect` 时只检查进程和错误，不能据此判断行为断言通过。普通 `WARNING:` 不自动判失败，独立的ObjectDB等泄漏警告仍须复核日志。

### 丰收跨关卡触控覆盖

```bash
python3 -B tests/qa_run.py --name harvest-coverage --timeout 300 \
  --expect "HARVEST COVERAGE PROBE PASSED" \
  -- --rendering-driver opengl3 res://tests/HarvestCoverageProbe.tscn
```

该探针以真实触摸事件覆盖 h02 未成熟拒采、h03 单篮收单、h06 豆荚计数与瓢虫障碍、h09 谷物/水果双篮及错篮反馈、h10 两阶段订单与金胡萝卜特例，并在 1280×720 与 1024×768 各跑一轮。它会清理 `SaveManager` 存档，因此必须通过 `qa_run.py` 的隔离项目运行。目前探针不在默认 `smoke_suite.json` 中；资产或交互改动后可显式运行这一 focused 验收。

## 完整 smoke

```bash
./tests/run_smoke.sh
```

`tests/smoke_suite.json` 保留原29场景的顺序、成功标记和运行参数。全部场景串行共享一份副本和独立存档；`GardenProbe` 保持靠后，`SaveProbe` 最后运行，以保留原有存档重置约定。

清单默认每项240秒，`FarmWorldProbe` 400秒，`HarvestTouchProbe`、`TabletProbe`、`HomeProbe` 300秒。传入 `--timeout` 会覆盖每项上限及导入上限，未传入时导入仍为120秒。

其中8项需要窗口。无 `DISPLAY` 的 Linux 使用 `xvfb-run` 和软件 OpenGL；若没有 xvfb，会明确跳过这些项目。最终输出 `Suite finished: N passed, M skipped`；有跳过时仍可能exit 0，**完整29项验收要求29 passed、0 skipped**。本轮只实际运行菜园相关探针和截图，完整29场景尚未复跑。

## 截图和多次运行

`QASession` 允许一份快照内顺序执行多次探针。截图场景需要调用者明确设置输出路径；创建 `qa_shots/` 不会自动指定 `SHOT_PATH`。

```python
from pathlib import Path
import sys

sys.path.insert(0, str(Path("tests").resolve()))
from qa_run import QASession, find_godot

with QASession(Path.cwd(), find_godot(), name="garden-shots") as qa:
    qa.import_project()
    for window, label in [("1280x720", "16x9"), ("1024x768", "4x3")]:
        qa.run_godot(
            ["--rendering-driver", "opengl3", "res://tests/FarmShot.tscn"],
            label="garden_" + label, timeout=20, expect="farm_shot -> OK",
            env={"SHOT_WHAT": "garden", "SHOT_WIN": window,
                 "SHOT_PATH": str(qa.qa_root / "qa_shots" / (label + ".png"))},
        )
```

`run_godot()` 的日志标签只能含字母、数字、`-`、`_`；`timeout` 覆盖本次运行，`env` 覆盖继承的环境变量。

`FarmShot` 的 `SHOT_WHAT=daily_board` 打开真实每日任务板并检查三种领取状态，成功标记为 `DAILY BOARD SHOT PASSED`。完整徽章矩阵用 `BadgeScaleShot.tscn`（绝对 `SHOT_DIR`）；真实奖励页滚动截图用 `RewardsPreview.tscn`（`SHOT_WIN`、`SHOT_BADGE_ROW`、绝对 `SHOT_PATH`）。矩阵的固定像素页不能代替奖励页双比例检查，具体输入、标记和实际结果见 [徽章与任务板记录](P4_BADGE_QA_20261002.md)。

`RewardsPreview` 还支持 `SHOT_ALL_BADGES_EARNED=1` 检查全部已获名称，以及 `SHOT_SECTION=stickers|growth` 定位真实贴纸/成长区；不要同时选择section和badge row。`FarmShot` 的 `SHOT_WHAT=overflow` 用真实触摸收菜并输出部分入库/全满溢出的飞行、收尾和仓库图，设置绝对 `SHOT_DIR`，成功标记 `OVERFLOW SHOT PASSED`；`SHOT_FULL_RACK=1` 增加七种子页和翻页箭头的布局输入。这些模式只在独立QA项目运行。

## 副本、日志和并行协作

- 副本包含未提交、未跟踪文件；保留 `.gdignore`，排除 `.git`、`.godot`、`__pycache__`、`tmp`、`build`、`_to_delete`。符号链接内容复制到副本，导入不会沿链接写回源码。
- 仅副本的 `[application]` 应用名、`use_custom_user_dir` 和 `custom_user_dir_name` 被替换；三者由唯一副本名称确定，原项目设置和正式存档不变。
- 独立 `user://` 存档仍在系统的应用数据目录中，目录名与副本名称相同，并不存放在QA项目内。删除项目副本不会自动删除对应QA存档。
- 控制台打印 `QA project:`、启动PID、日志路径、耗时和退出码。副本、`qa_logs/` 和 `qa_shots/` 保留供复查，需由调用者按需要清理；系统临时目录不保证永久保存。
- `/tmp/heroes-island-godot-qa.lock` 覆盖副本、导入与整次运行。入口拒绝已有Godot进程，识别含AppTranslocation在内的可执行路径。仍须在会话间明确交接运行窗口；锁不能阻止手工或旧脚本在检查后启动引擎。
- 超时或CLI中断只停止本入口启动的进程组，先TERM、最多等3秒再KILL。禁止覆盖项目路径、主资源包或远程项目等绕过副本的参数。

## 探针音频收尾

已经完成断言或截图、准备退出的探针可复用：

```gdscript
const ProbeLifecycle := preload("res://tests/probe_lifecycle.gd")

# 在最终结果记录之后：
await ProbeLifecycle.finish(self, 0 if failures.is_empty() else 1)
```

助手停止现有音乐、音效、语音播放器，清空流，等1秒和两帧后退出。当前菜园触控和截图入口已实际验证；播放器字段改名、新增通道或场景收尾期间再次发声时，需要相应维护。音频对照及实际日志见 [菜园运行证据](GARDEN_RUNTIME_QA_20261002.md)。

## 运行器单元检查

```bash
python3 -B -m unittest discover -s tests -p test_qa_run.py -v
```

这些检查使用临时文件和普通Python子进程，不启动Godot；覆盖隔离、标记/错误判定、锁、超时清理和smoke清单约定。它们不能替代真实引擎运行。

### 2026-10-02：运行期错误不能被通过标记掩盖

并行丰收QA的连续采空低动态截图日志含已释放对象回调的引擎错误，但旧场景判定只查脚本/解析错误和成功标记。现在 `check_result()` 对导入和全部场景共用行首 `ERROR:` 规则，退出0、出现 `PASSED` 或未指定expect均不能掩盖运行期/退出期引擎错误；完整stdout与stderr日志不变。资源和RID退出行若是 `ERROR:` 也会失败，单独的 `WARNING:` 仍需人工复核。

15项纯Python单元检查通过（3.698秒），新增真实Python子进程输出 `PASSED` 后在stderr写missing texture、resources still in use和RID leak三种错误，检查退出0仍失败、错误码为1、完整日志保留；正常进度、`ERROR_COUNT=0`、普通WARNING和成功标记仍通过。原missing marker、锁、隔离、超时及抗TERM子进程清理检查保持通过。没有为该运行器改动启动Godot，不把单元结果或旧runner的1098项引擎日志算作新runner的真实引擎验收。

- `tests/qa_run.py` SHA-256：`f49e0364a2a449e4923a9b262434f329785abe18e2feea234153f97bc2347327`
- `tests/test_qa_run.py` SHA-256：`1188f80fbe77a3dd77562b4e7035ab97513abe92c071010fe93296c95686ed7c`

已经导入旧模块的Python进程不会自动获得新判定；下一次QA应重新启动Python入口。

### 2026-10-03：截图非空内容检查

PNG保存成功不保证画面已绘出。`ProbeLifecycle` 现为显式截图入口提供整页非均匀检查、逻辑视口到PNG的区域换算、逐格至少8个对比像素检查；`finish()` 兼容原调用，产品帧循环不使用这些函数。Icon检查每次84格，Badge检查372格；菜园、每日板、溢出和真实奖励页检查整图。失败图片保留，Icon/FarmShot拒绝headless。

纯规则入口：`res://tests/ScreenshotContentProbe.tscn`，可使用headless，成功标记 `SCREENSHOT CONTENT PROBE PASSED`。本轮实际规则21项、正常双比例与目录50PNG通过；隐藏图标、透明勋章、纯灰图、headless四故障均正确拒绝。非空不能证明图案身份、完整性或儿童识别，仍需目视；具体日志、输入hash和证据范围见 [截图内容记录](SCREENSHOT_CONTENT_QA_20261003.md)。
