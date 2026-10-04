# Harvest sprite pack

> **Rebuilding or adding a sprite: use [pipeline/](pipeline/README.md).** One
> studio (the frozen profile that rendered what ships), one recipe per asset,
> one command that renders, audits and draws the contact sheet. It reproduces
> every PNG in `../crops/` to within one pixel. `build_pack.py` below is the
> original one-file pack the pipeline's models were moved out of, kept as
> history; its own rig (softbox, AgX) is not what the game shows.

This Blender render source covers the 17 IDs in `data/harvest_crops.json` (including `stone` and `bug`), plus two optional environment sprites: an empty basket and a small soil/grass patch.

## Files

- `rendered/sprites/<id>.png` — default build output: 512 × 512 RGBA sprites, with soft contact shadows composited into alpha. Set `HARVEST_SPRITE_PACK_OUT` to choose another output directory.
- `contact_sheet.png` — all 19 assets at review size.
- `contact_sheet_90px.png` — same set shown at the 90 × 90 runtime target size.
- `contact_sheet_small_sizes.png` — visible silhouettes at 48, 72 and 96 px; the crop art is cropped to the alpha bounds used by the order and basket badges.
- `harvest_sprite_pack.blend` — editable Blender scene. Each asset is in its own `ASSET | <id>` collection; the shared camera, softbox and shadow catcher are in `STUDIO | shared render rig`.
- `build_pack.py` — rebuilds every PNG and the Blender source with Blender 5.2+; output defaults to `source/rendered/`, not a machine-specific temporary path.
- `manifest.json` — checked-in reference manifest with IDs, filenames, dimensions and ground-pivot pixel coordinates.

## Ground pivot and limits

All models use the same world-space ground origin `(0, 0, 0)`. It projects to pixel `(256, 467)` in each 512 × 512 sprite: 211 px below the texture center, or about 37 px below center when displayed at 90 × 90. Use that point as the sprite's ground anchor; the visible contact footprint can extend a little around it, especially on wide items such as the pumpkin and watermelon.

The shadows are deliberately soft and short, but they are included in the PNG alpha. If the game adds a separate contact shadow, reduce or remove one of the two. Wide ground footprints (especially the empty basket and soil patch) reach close to the bottom edge by design; avoid auto-trimming them before applying the pivot. The render is a fixed 3/4 view with no held-state variants or animation. The smallest crown, seed and awn details lose definition below about 72 px; the main crop silhouettes remain distinct at 48 px in `contact_sheet_small_sizes.png`.

## 整株 3D 候选（2026-10-02）

新增的 [whole_plant/](whole_plant/README.md) 保存完整番茄株、独立单果、无果株身和修复提手的粗藤编篮，包括可编辑 Blender 源、真实 GLB、透明分件及双比例造型图。Blender 与 GLB 留在源目录；同一冻结渲染配置生成的背景、透明株身、单果和篮子 PNG 衍生图已于 2026-10-03 接入正式运行页面。运行采用这些烘焙图层与既有 2D 交互，不在 Godot 中实例化 GLB。几何来自现有项目模型和构造函数，没有引入新的运行引擎、订单或采摘系统。

整株分件与上面的旧 sprite pack 不同：透明图**没有烘焙接地阴影**，应在页面复用 `Shapes.ground_shadow`，不能依据旧包假定其自带阴影。采摘只移动单果，空株/支架留在原地；订单徽标继续显示果实，不显示四果整株。完整契约见候选 `rendered/manifest.json`。

[validation/](validation/README.md) 提供共用 GLB 预算、层级、颜色检查和内存单元测试；Blender 回读工具仅用于资产验证，不代表 Godot 导入、实际触控或目标平板性能通过。

## Godot runtime use

This `source/` directory is source-only and contains an empty `.gdignore`, so Godot does not import or package its Blender project, build script, manifest or contact sheets. The game uses copied PNGs from the sibling `../crops/` and `../props/` directories through the harvest visual adapter. The v2 farm GLB is a separate prototype and is not part of this sprite pack.
