# Blender 农场立体视觉优化

日期：2026-10-04。基线：`claude/stoic-bell-a41pfu` / `25ecd52`。

## 目标

用本地 Blender 5.2.2 LTS 改善真实游戏里的体积、接地和建筑辨识，生成资产并接入项目供用户复验。继续使用当前正交摄影棚与 2.5D 运行方式；操作、作物成长、订单、存档、镜头和触控归属保持既有组件。缺少的模型与材质可自行制作，随生成代码和配方保存，不引入外部来源不明素材。

## 当前画面判断

- 菜畦像厚绿圆盘，泥面平滑且缺少土层结构；作物根部与泥面的高度关系不明确。
- 仓库主要由墙块和整块屋顶组成，门窗缺少凹进与边框，近看模型体积仍显单薄。
- 小熊入口是草丘与木圆片，缺少清楚的门洞、门框和可站立的门槛。
- 素材管线能重建，但本地 Blender 的审图解释器需要显式选择；草地平铺纹理需要与接地精灵分开验收。

## 本轮交付范围

1. **菜畦**：有低矮土层侧面、圆角土面、克制的耕作起伏与零散草缘，减少绿色托盘感；校准菜畦与现有作物根点。模型与材质走现有配方。
2. **仓库**：有厚度的屋顶、结构梁柱、嵌入式门窗、清楚的双门斜撑及少量木箱细节；保持既有设施热区与画面占用。
3. **小熊入口**：草丘包住立体木门、门框与踏步，缩图仍能认作入口；不新增可点装饰。
4. **管线**：支持显式指定 Pillow 审计解释器；为平铺草地声明独立规格与审计，仍严格检查普通精灵的透明边、接地基准和裁切。
5. **源资产与证据**：保留 Python 模型、JSON 配方、可编辑 `.blend`、GLB、透明 PNG、导出 manifest 与双比例页面对比。

## 执行与验收

- [x] 确认分支、保留用户本地 QA 文档补充、检查本地 Blender。
- [x] 保存本计划并明确第一轮资产范围。
- [x] 建模：菜畦、仓库、小熊入口。
- [x] 用冻结摄影棚在本地 Blender 渲染，保持 512×512 与 `(256,467)` 基准；输出可编辑源文件。
- [x] 审查单资产与小尺寸对照，不把 Blender 大图当游戏页验收。
- [x] 将合格 PNG 接入既有资源路径，复拍菜园 16:9 / 4:3；菜畦资源仅由 PlotView 使用，本轮不影响丰收页作物布局。
- [x] 隔离存档、串行执行相关 Godot 探针；保留日志及候选迭代记录。
- [x] 运行素材审计、管线自检、静态检查和差异格式检查。
- [x] 更新本文件，列出采用项、未通过项、生成命令与用户复验步骤。

## 视觉通过条件

- 菜根有明确落点，菜畦侧面表达厚度而不形成悬浮托盘；泥土细节不盖过作物。
- 仓库屋顶、门窗和小熊门洞在实际显示尺寸下具有清楚的前后关系。
- 三种资产与原作物共享机位和光向，轮廓圆润，草地不因新素材出现深色孤岛。
- 装饰不遮住订单、工具、作物状态图标，不扩大或移动热区。
- 16:9 与 4:3 页面都能显示核心对象；低动态和触控路径不退化。

## 已知基线问题

上轮独立复跑：丰收触控 1779 项、菜园 1230 项、农场 736 项通过；菜园/农场曾在首轮 16:9 输入阶段失败，原因未定位。运行器纯 Python 单测仍有旧白名单及 29/30 项断言不一致，本轮不借美术工作改写其判定。四句鸡舍/风车语音尚缺音频，留作独立内容任务。

## 本轮结果

第一轮三资产已实现并接入，等待用户美术复验。当前主观判断：仓库的屋顶、门窗前后关系有明显提升；菜畦改善了接地，但缩小时仍偏规则薄板；小熊入口的石拱与门槛更清楚，全景中仍会被既有前围栏遮挡一部分。没有把这些局部改善记作整个农场美术完成。

### 实际采用

- 菜畦采用低土层与连续土面，放弃第一版过厚、像饼状底座的候选。正式表面高度为 `0.10`；小范围耕作起伏和 Noise/Bump 材质均来自 Blender。
- 菜畦配方声明 `planting_surface`，构建时通过冻结机位计算像素坐标 `(255.9056,422.9964)`，与 PNG 一起保存到 sidecar。PlotView 把此点与现有作物根点对齐；不依靠手估偏移。缺失 sidecar 时保留旧放置方式。
- 干旱状态最后一笔裂纹原来会落到新土面之外，已移回土面；整条加笔宽边界共 261 次 alpha 采样都在不透明土面内，并补拍最终画面。
- 仓库加入三排宽瓦、屋脊、结构木梁、凹进门窗、门斜撑及木箱细节；小熊入口采用有开口的草丘、石拱、内嵌木门与踏步，去掉候选中过宽的棕色底盘。
- 补全显式 `--audit-python`、草地平铺纹理契约、锚点投影/sidecar 审计；草地专用规则只匹配 `props/grass_tile.png`，普通精灵的裁切/接地检查不放宽。

### 交付入口

| 文件 | 用途 |
| --- | --- |
| [Blender 摆台源文件](../assets/harvest_3d/source/blender_polish_20261004/review/farm_polish_review.blend) | 直接打开看三个模型，可编辑并 F12 重渲染 |
| [摆台效果图](../assets/harvest_3d/source/blender_polish_20261004/review/farm_polish_review.png) | 模型观察图；与游戏内验收分开 |
| [精灵摄影棚](../assets/harvest_3d/source/blender_polish_20261004/exports/harvest_studio.blend) | 每资产一个 Collection，同原点叠放，需单独显示查看 |
| [导出 manifest](../assets/harvest_3d/source/blender_polish_20261004/exports/manifest.json) | 三种 PNG/GLB、机位参数与菜畦锚点 |
| [素材说明](../assets/harvest_3d/source/blender_polish_20261004/README.md) | 源码、配方、导出物及 GLB 使用范围 |

GLB 不携带摄影棚程序化阴影片，避免透明节点转换失败形成黑色矩形；由目标引擎提供实际阴影。土壤 Noise/Bump 未烘焙成法线贴图，完整当前外观保留在 `.blend` 和正式 PNG 中。上层 `.gdignore` 使这些源资产不参与 Godot 运行时导入。

### 游戏内对照与验证

| 比例 / 镜头 | 改动前 | 接入后 |
| --- | --- | --- |
| 16:9 普通 | [before](qa/blender_farm_polish_20261004/before_16x9_normal.png) | [after](qa/blender_farm_polish_20261004/after_16x9_normal.png) |
| 16:9 全景 | [before](qa/blender_farm_polish_20261004/before_16x9_out.png) | [after](qa/blender_farm_polish_20261004/after_16x9_out.png) |
| 4:3 普通 | [before](qa/blender_farm_polish_20261004/before_4x3_normal.png) | [after](qa/blender_farm_polish_20261004/after_4x3_normal.png) |
| 4:3 全景 | [before](qa/blender_farm_polish_20261004/before_4x3_out.png) | [after](qa/blender_farm_polish_20261004/after_4x3_out.png) |

这些 `after_*` 为三资产接入版本，拍于最后一笔干裂修正之前；最终低动态与入口聚焦证据另列，避免混淆时序。初次集成 [结果](qa/blender_farm_polish_20261004/integrated_qa.json)：GardenTouchProbe **1238** 项、FarmWorldProbe **736** 项均首跑通过，所有运行使用复制项目、独立应用名与 `user://`，串行执行。没有使用真实存档，也没有把此前分支的 30 项 smoke 记录当作本轮全量复跑结果。

最后裂纹修正后的四张证据：[16:9 低动态](qa/blender_farm_polish_20261004/after_16x9_reduce_motion.png)、[4:3 低动态](qa/blender_farm_polish_20261004/after_4x3_reduce_motion.png)、[16:9 小熊入口聚焦](qa/blender_farm_polish_20261004/after_16x9_bear_door.png)、[4:3 小熊入口聚焦](qa/blender_farm_polish_20261004/after_4x3_bear_door.png)。[截图记录](qa/blender_farm_polish_20261004/additional_shots_results.json) 包含实际开关、分辨率和 PNG 哈希；两比例裂纹均位于土面，未发现新增严重裁切、浮空或 UI 遮挡。静态截图验证低动态设置与画面，不能单独证明所有动画行为。一次早于裂纹修正的补拍快照已被替代，其路径和原因保留在 JSON 中。

同一最终快照再次运行 [GardenTouchProbe](qa/blender_farm_polish_20261004/final_garden_touch.log) **1238 项 / 49.56 秒**与 [FarmWorldProbe](qa/blender_farm_polish_20261004/final_farm_world.log) **736 项 / 17.50 秒**，两者退出码 0 且出现 PASSED；[最终结果](qa/blender_farm_polish_20261004/final_qa.json) 记录该版 PlotView 的 SHA-256。FarmWorld 退出仍打印 12 个 ObjectDB 实例与 6 个资源未释放的通知；现有运行器将这类已知退出通知列入白名单，本轮没有修改白名单或宣称资源泄漏已修复。

- [管线自检](qa/blender_farm_polish_20261004/pipeline_validation.log)：69 配方 / 63 模型 / 96 色板；17 个契约测试通过；已安装 17 作物 + 53 道具 + 1 纹理，0 失败。
- [本轮导出审计](qa/blender_farm_polish_20261004/export_audit.log)：3 个精灵，0 失败；土面侧边最低实色行为 504，属于其声明的深占地范围，未裁切。
- [GLB 导出复核](qa/blender_farm_polish_20261004/glb_validation.log)：三文件无外链、无程序化阴影辅助面；小熊入口 18,273 三角、仓库 18,733 三角保持不变，菜畦仅减少阴影片的 2 个三角到 11,228；6 种 helper 识别验证通过，受保护的 59 个 PNG/`.blend` 哈希未变。
- [静态检查](qa/blender_farm_polish_20261004/static_check.log)：0 errors、203 warnings，与基线相同；`git diff --check` 通过。
- 冻结摄影棚 SHA-256 保持 `4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512`。三张安装 PNG 与导出 PNG 字节一致；sidecar/manifest 的菜畦锚点一致。
- 既有 QA 文档的两行本地补充保留，原 diff SHA-256 为 `c906321cc7cbc7be6002e59d1ac295c8fb214203e26f82f81eb92b2aeb359195`，整理后仍一致。

### 迭代中发现的问题

1. 第一版菜畦过厚，被目视淘汰；后续降低土层并收敛边缘。
2. 一次土壤节点查找因 Blender 中文界面下 `Principled BSDF` 名称不同而报错，改用节点类型识别后重渲染。最终构建带 `--python-exit-code 1`，防止 Python 出错但进程显示成功。
3. 小熊入口第一版的土裙过宽，收窄到草丘轮廓；展示场景初版篮子父子层级重复缩放，已改为只缩放根对象。
4. 原有纯 Python QA 运行器测试的旧白名单和 29/30 manifest 数量问题仍未处理；本轮素材契约测试及 Godot 功能探针通过不代表该已知基线问题已解决。

## 复现命令

以下命令从 `/opt/heroesIsland` 执行；`AUDIT_PY` 需指向装有 Pillow 的 Python。导出图与展示图分目录，避免审计把展示图当精灵。

```bash
cd /opt/heroesIsland
P=assets/harvest_3d/source/pipeline
OUT=assets/harvest_3d/source/blender_polish_20261004
AUDIT_PY=/Users/xhzhou/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3

/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python-exit-code 1 \
  -P "$P/build.py" -- \
  --only soil_grass_patch,building_warehouse,building_bear_door \
  --out "$OUT/exports" --glb --blend --install --audit-python "$AUDIT_PY"

/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python-exit-code 1 \
  -P "$P/build_polish_review.py" -- --out "$OUT/review"

"$AUDIT_PY" "$P/test_pipeline.py"
"$AUDIT_PY" "$P/audit.py" "$OUT/exports"
python3 tools_check.py
git diff --check
```

功能复验要先关闭正在运行的 Godot，然后使用隔离运行器。它会先导入复制项目中的新图，再运行探针，不要直接在真实项目上跑会清理存档的测试场景。

```bash
python3 tests/qa_run.py --name blender-polish-garden \
  --expect "GARDEN TOUCH PROBE PASSED" -- \
  --rendering-driver opengl3 res://tests/GardenTouchProbe.tscn
python3 tests/qa_run.py --name blender-polish-world \
  --expect "FARM WORLD PROBE PASSED" -- \
  --rendering-driver opengl3 res://tests/FarmWorldProbe.tscn

SHOT_WHAT=garden SHOT_WIN=1024x768 SHOT_REDUCE_MOTION=1 \
  SHOT_PATH=/tmp/farm-polish-low-motion.png \
  python3 tests/qa_run.py --name blender-polish-low-motion -- \
  --rendering-driver opengl3 res://tests/FarmShot.tscn
```

普通模式省略 `SHOT_REDUCE_MOTION`；全景加 `SHOT_ZOOM=out`；入口聚焦加 `SHOT_FOCUS_FACILITY=bear_door`；16:9 用 `SHOT_WIN=1280x720`。

## 用户复验重点

1. 在 Godot 打开项目，等导入完成，进入星光菜园；观察仓库门窗、菜根落点、缺水裂纹及小熊门洞。
2. 普通与最远缩放各看一次，切换 16:9 / 4:3、低动态；确认作物状态、订单和底部工具仍易读。
3. 点地、种植、浇水、收菜，检查新土面仍把点击交给原作物热区；仓库与小熊入口能正常进入。
4. Blender 打开 `review/farm_polish_review.blend` 细看模型和材质；优先评价“土面是否仍像板”“石拱是否过亮”“新仓库是否与周边建筑一致”。下一轮按这些实际画面反馈扩展资产，当前不额外改镜头或布局。
