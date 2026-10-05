# 兔兔朋友与农场工具源资产

2026-10-04，本地 Blender 5.2.2 LTS，以项目冻结正交摄影棚生成。完整任务与关卡计划见 [FARM_FRIENDS_AND_LEVELS_PLAN.md](../../../../docs/FARM_FRIENDS_AND_LEVELS_PLAN.md)。

- `exports/harvest_studio.blend`：可编辑兔兔模型、青色围裙、挎篮、胡萝卜和举手姿势；材质在本地程序生成。
- `exports/sprites/rabbit.png`：512×512 RGBA，已安装到 `../../props/rabbit.png`。
- `exports/sprites/rabbit.glb`：真实模型几何，不含摄影棚相机、灯光或程序化阴影辅助片；目标引擎提供光照。
- `exports/manifest.json` 与 `exports/contact_sheet.png`：导出契约、小尺寸审查。
- 生成源码 `../pipeline/models/rabbit.py`，配方 `../pipeline/recipes/rabbit.json`。

游戏地图仍使用渲染PNG；呼吸、招呼及爱心由既有 FarmSceneryLife 表现。订单和关卡头像调用共享 prop_badge，按透明边界适配，未另画一套头像。

```bash
cd /opt/heroesIsland
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python-exit-code 1 \
  -P assets/harvest_3d/source/pipeline/build.py -- --only rabbit \
  --out assets/harvest_3d/source/farm_friends_20261004/exports \
  --glb --blend --install \
  --audit-python /Users/xhzhou/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
```

上层 `.gdignore` 使源件不进入 Godot 游戏导入。构建日志及GLB结构验证存放于 `docs/qa/farm_friends_20261004/`。


## 物品栏工具

- `tools/exports/harvest_studio.blend`：木柄小铲和青绿洒水壶的可编辑源场景。
- `tools/exports/sprites/tool_trowel.{png,glb}`、`tool_watering_can.{png,glb}`：512px透明渲染与真实几何；PNG已安装至游戏 props。
- `../pipeline/models/tool_trowel.py`、`tool_watering_can.py` 及对应 recipes：同一冻结摄影棚、同一材质调色板；无裁切或悬空审计豁免。
- 工具槽使用 `Art.prop_badge()` 按可见轮廓适配44px，已审查44/48px实际显示尺寸；没有单独替换触控按钮。

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python-exit-code 1 \
  -P assets/harvest_3d/source/pipeline/build.py -- \
  --only tool_trowel,tool_watering_can \
  --out assets/harvest_3d/source/farm_friends_20261004/tools/exports \
  --glb --blend --install \
  --audit-python /Users/xhzhou/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
```
