# 小狗 3D 农场角色

小狗的程序化 Blender 模型原本只用于 `assets/harvest_3d/props/dog.png`。本次用项目冻结摄影棚将同一模型导出为 GLB，让小狗能站进 3D 好友农场。

2026-10-10 将游戏内毛色重调为蜂蜜金和暖奶油色，并降低农场环境光与直射光，解决高光下小狗融成浅黄色的问题。几何仍由同一 Blender 脚本生成；没有加入外部模型或纹理。

- `exports/harvest_studio.blend`：可编辑 Blender 场景。
- `exports/sprites/dog.glb`：无纹理 glTF 2.0 模型，使用游戏内环境光和阴影。
- `exports/sprites/dog.png`：同一源模型重新渲染的对照图。
- `exports/manifest.json`、`exports/contact_sheet.png`：摄影棚契约与资产审计。
- 运行时副本：`assets/harvest_3d/runtime/friends/dog.glb`。
- 游戏内验证截图：`docs/qa/friend_farms_20261010/puppy_16x9.png` 与 `puppy_4x3.png`。

模型脚本和配方分别为 `assets/harvest_3d/source/pipeline/models/dog.py` 与 `assets/harvest_3d/source/pipeline/recipes/dog.json`。资产为项目内程序化制作，不引用外部模型或纹理。

重建命令：

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python-exit-code 1 \
  -P assets/harvest_3d/source/pipeline/build.py -- \
  --only dog \
  --out assets/harvest_3d/source/farm_friends_20261004/dog/exports \
  --glb --blend --install \
  --audit-python /Users/xhzhou/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
```
