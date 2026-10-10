# 小狗 3D 农场角色

小狗的程序化 Blender 模型原本只用于 `assets/harvest_3d/props/dog.png`。本次用项目冻结摄影棚将同一模型导出为 GLB，让小狗能站进 3D 好友农场。

- `exports/harvest_studio.blend`：可编辑 Blender 场景。
- `exports/sprites/dog.glb`：无纹理 glTF 2.0 模型，使用游戏内环境光和阴影。
- `exports/sprites/dog.png`：同一源模型重新渲染的对照图。
- `exports/manifest.json`、`exports/contact_sheet.png`：摄影棚契约与资产审计。
- 运行时副本：`assets/harvest_3d/runtime/friends/dog.glb`。

模型脚本和配方分别为 `assets/harvest_3d/source/pipeline/models/dog.py` 与 `assets/harvest_3d/source/pipeline/recipes/dog.json`。资产为项目内程序化制作，不引用外部模型或纹理。

重建命令：

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python-exit-code 1 \
  -P assets/harvest_3d/source/pipeline/build.py -- \
  --only dog \
  --out assets/harvest_3d/source/farm_friends_20261004/dog/exports \
  --glb --blend \
  --audit-python /Users/xhzhou/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
```
