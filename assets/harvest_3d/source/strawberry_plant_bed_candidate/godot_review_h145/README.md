# 草莓株身 H1.45 隔离呈现评审

这是 r5 草莓 GLB 的 Godot 呈现参数 A/B，不是新模型，也不是正式页面验收。GLB 的几何和哈希保持不变；只把 pilot 株身高度倍率从 1.20 调到 1.45，并将叶片材质乘色调为 R/G/B = 0.82/0.90/0.78。偏蓝暗绿的旧档会让低矮 rosette 不易辨认；更亮的 1.05/1.10/0.70 档又过于荧绿，因此保留两者之间的温和档。

## 真实关卡截图

以下画面来自 `harvest_02` 的 `Harvest3DIntegratedPilot`。两种比例都使用 14 个既有 `HarvestTarget`、两只真实篮子；3D 只负责替换草莓的可见株身。普通态、持货态和实际送篮态均通过 `qa_run.py` 隔离项目的 content/save 门禁。

| 状态 | 16:9 | 4:3 |
| --- | --- | --- |
| 普通态 | [1280×720](normal-16x9.png) | [1024×768](normal-4x3.png) |
| 持货态 | [1280×720](held-16x9.png) | [1024×768](held-4x3.png) |
| 送篮后 | [1280×720](delivery-16x9.png) | [1024×768](delivery-4x3.png) |

两个比例的持货运行都从真实草莓目标拿起果实；送篮记录为 `delivery=true basket=fruit picked={ "strawberry": 1 }`，且篮中订单从 0/4 变为 1/4。采后株身仍留在地面，现有 2D 命中区域、篮子解析与订单结算未改。

## 判断与边界

放大后的叶冠在 16:9 和 4:3 都更醒目，饱和度也比偏蓝档自然；行距中仍可分辨相邻株身。这个小步改善了作物株身的识别，不解决当前隔离页面的大块空地、其余作物的 2D/3D 混搭、iPad 性能或儿童实玩问题。株身仍是 source-only 美术候选，不能据此替换正式 Harvest 页面。

## 复跑

```sh
SHOT_WINDOW=1280x720 \
SHOT_PATH=/tmp/strawberry-h145.png \
PILOT_STRAWBERRY_PLANT=1 \
PILOT_STRAWBERRY_BODY_GLB=res://assets/harvest_3d/source/strawberry_plant_bed_candidate/rendered_r5/strawberry_plant.glb \
python3 tests/qa_run.py --name strawberry-h145 \
  --timeout 240 --expect "3D integrated pilot image=" -- \
  --rendering-driver opengl3 res://tests/Harvest3DIntegratedPilot.tscn
```

持货截图附加 `PILOT_HELD=1`；真实送篮附加 `PILOT_HELD=1 PILOT_DELIVER=1`。改成 `SHOT_WINDOW=1024x768` 可复核 4:3。
