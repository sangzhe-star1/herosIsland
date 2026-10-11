# 草莓 2.5D 株身接入验收 — 2026-10-11

Blender 5.2.2 将 source-only r5 草莓 rosette 渲成透明 512×512 株身图，并通过现有 `HarvestVisualArt.plant_layout()` / `HarvestTarget` 接入正式 `harvest_02`。果实继续使用已有草莓图；`HarvestTarget` 仍独占触控、成熟、采摘与送篮状态，株身只是采后留在地面的被动图层。

| 画幅 | 普通态 | 真实触控持货态 |
| --- | --- | --- |
| 16:9（1280×720） | [查看](normal-16x9.png) | [查看](held-16x9.png) |
| 4:3（1024×768） | [查看](normal-4x3.png) | [查看](held-4x3.png) |

四次独立 `tests/qa_run.py` 均在 Godot 4.7.1 Compatibility renderer 下完成 import 和 run（exit 0）。每张普通态均确认关卡实例化 9 株可见的 Blender 株身；两张持货态通过正式触控手势摘取草莓，确认果实进入手持状态且原株身仍在田里。运行使用 QA runner 建立的独立项目和 `user://`，没有读取或写入正式存档。

另以完整 `HarvestTouchProbe` 覆盖收菜手势与订单路径，两种画幅合计 2,317 项通过。被动叶冠计入实际画面占位后，`harvest_08` 的宽屏订单行归属更新为 `[3,1,4]`、`[1,4,1]`、`[2,3,0]`；全探针确认目标间距与触控布局仍满足门槛。手持截图探针还验证避让株身的横移保持在现有 `HELD_SHIFT_LIMIT` 内。

运行时规格在 [`../../assets/harvest_3d/plants/strawberry.json`](../../assets/harvest_3d/plants/strawberry.json)。株身图保留共享地面锚点 `[256, 467]`；从 GLB 投影得出的草莓果槽为 `[227.645, 455.784]`。株身放大后把 `fruit_ortho` 定为 0.864，单独控制果实与叶冠比例，避免两者同比放大。候选渲染和哈希清单在 [`../../assets/harvest_3d/source/strawberry_plant_bed_candidate/rendered_2d/`](../../assets/harvest_3d/source/strawberry_plant_bed_candidate/rendered_2d/)，复现脚本为同目录的 `render_strawberry_body.py`。Blender 使用固定 20261011 seed、CPU 单线程、48 samples，并清掉 PNG 中随运行时间变化的元数据；连续两次生成得到相同的 SHA-256：`0adf8359231c2ebe6991c53c8639149f7b3959b5372a5dd4552e741b12064d75`。

复跑普通态时设置 `SHOT_WINDOW=1280x720` 或 `1024x768`、`SHOT_PATH=/tmp/strawberry.png`；再运行：

```sh
python3 tests/qa_run.py --name strawberry-plant-shot --timeout 240 \
  --expect 'HARVEST PLANT SHOT PASSED state= plants=' -- \
  --rendering-driver opengl3 res://tests/HarvestPlantShot.tscn
```

持货态再加 `SHOT_PLANT_STATE=held`，成功标记改为 `HARVEST PLANT SHOT PASSED state=held plants=`。

验收范围限于株身在真实页面的显示、双画幅适配与实际采摘后留株；没有声称儿童辨识度、iPad 性能或整页美术评审通过。
