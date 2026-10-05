# Blender 农场视觉首轮交付

基线 `claude/stoic-bell-a41pfu` / `25ecd52`，本地 Blender 5.2.2 LTS 生成。
完整计划、命令、游戏内对照与验收记录：
[BLENDER_FARM_POLISH_PLAN.md](../../../../docs/BLENDER_FARM_POLISH_PLAN.md)。

## 直接打开

- `review/farm_polish_review.blend`：可编辑的摆台场景；仓库、菜畦、小熊入口并排，附原有胡萝卜与篮子，F12 可重新渲染。对应 `farm_polish_review.png`。
- `exports/harvest_studio.blend`：实际精灵批量导出的源场景，每个资产一个 Collection，位置重叠以共享精灵机位；单独查看时需隐藏其他资产 Collection。
- `exports/sprites/`：三份 512×512 透明 PNG 与 GLB。
- `exports/manifest.json`：导出规格、安装路径、阴影策略和菜畦表面像素锚点；`contact_sheet.png` 是小尺寸审查图。

游戏已使用 `../../props/` 下更新后的三个 PNG。运行方式仍为 Blender 渲染的 2.5D，展示场景不是游戏背景。上层 `.gdignore` 让 Godot 跳过这些源文件。

## 可继续编辑的生成源

- `../pipeline/models/soil_grass_patch.py`：薄土层、起伏土面、碎土与稀疏草缘；土壤 Noise/Bump 材质本地程序生成。
- `../pipeline/models/building_warehouse.py`：屋顶瓦片、梁柱、嵌入门窗、木箱。
- `../pipeline/models/building_bear_door.py`：草丘、石拱、木门、门槛和草缘。
- `../pipeline/recipes/`：对应 JSON 配方。
- `../pipeline/build_polish_review.py`：重建摆台场景。

没有下载外部素材。本轮新增几何与材质均保存在生成代码和 `.blend` 中；摆台的胡萝卜与篮子复用项目资产。

## 使用 GLB

GLB 用于几何复用，渲染用接触阴影 helper 不导出，由目标 3D 引擎提供光照和阴影。土壤程序化 Noise/Bump 未烘焙为 GLB 法线纹理，完整外观以 `.blend` 与正式 PNG 为准。GLB 不是已经接入 Godot 的运行时 3D 场景。

## 重建目录约定

精灵构建的 `--out` 指向本目录的 `exports/`；摆台生成的 `--out` 指向 `review/`。两者分开，避免把 1600×900 的展示图误当 512×512 精灵送入审计。
