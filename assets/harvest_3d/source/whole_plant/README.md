# 整株番茄 3D 候选

这里保存Blender源模型与审图，Blend/GLB未作为Godot运行模型导入。10/03 已从同profile源包采用背景和透明分件，正式页面仍由既有2D组件驱动；运行输入及QA见上级 `RUNTIME_INTEGRATION_20261003.json`。所有原始输入在 `inputs/`，不需要旧临时 vXX 目录。

默认产物在 `rendered/`；其中 GLB 是真实可旋转网格，不是图片平面。源码目录受上级 `.gdignore` 保护，不会被 Godot 自动打包为运行素材。审图脚本需要 Pillow；GLB 只读检查和单元测试仅依赖 Python 标准库。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python build_whole_plant.py -- --out rendered --validator ../validation/audit_glb.py
python3 review_exports.py --root rendered --out rendered
python3 ../validation/audit_glb.py rendered/whole_plant_scene.glb --check-whole-plant
```

构造脚本用 AST 只载入 `inputs/curved_leaf_source.py` 的 `curved_leaf_mesh` 和 `inputs/plant_builder_source.py` 的 `Builder`。两个历史 generator 不能直接执行，否则其旧输出路径会产生额外文件。`tomato_seed.blend` 来自主线 v28 无贴图模型；篮体和编织沿复用原几何，提手环仅修正原顶点参照方向。木支架归每株静态网格，篮子不拥有木桩或装饰果。

整株四果图仅用于造型评审。运行候选是 `plant001_body.glb` / `plant001_body_512.png` + `tomato_fruit.glb` / `tomato_fruit_512.png` 分件；番茄一次点击只采一个果实，不能把四果整株用作现有 `crop_texture`。PNG 均为 512×512，地面投影为 `(256,467)`；单果 PNG 抬到 `.232m` 以使果底落在该线，GLB 保留果实中心 pivot。株身无果图会保留真实果梗。

`manifest.json` 记录材质、实例化面数、12目标层级、果实投影挂点、单株 yaw 和画布跨度。`validation/glb_audit.json` 是复用项目唯一 validator 产出的数据，没有第二套统计实现。

构造时清理原模型重合端点、零面积面并重算法线，薄叶/萼片保留锐边，篮子仍使用圆润的平滑编织法线；不会把所有部件无差别变成硬切面。`topology_cleanup` 记录每个对象的修改数量。透明图没有烘焙接触影，运行侧须复用既有 `Shapes.ground_shadow`；不可套用旧 sprite pack 的“图内自带阴影”假设。

叶尖修复必须在 `Solidify` **之前**焊接重合端点、删除退化面并三角化曲面，不能只在挤出后重算法线。原候选的 1,110 个反向三角形来自厚叶/萼片局部翻折；保持篮子平滑后，最新 GLB 默认回读的退化三角形、反向三角形、非有限位置/法线与零法线计数均为 0。实际报告及单果隐藏图在 `rendered/validation/`，它们仍不是 Godot 导入或游戏性能验收。

当前冻结 `whole_plant_scene.glb` SHA-256 为 `123cfab7a4150110e8af29ca208b46dda6a8250d4870e46f3fb791620f64718c`：49,094 tris、9 材质、11 个静态材质 primitive、12 个独立目标、0 图像/纹理/相机/灯光。`source_generator` 和 `source_dependencies` 记录构建脚本、输入和 Blender 版本。Cycles PNG 另有本次输出哈希，不承诺跨设备逐像素相同。

单件归零导出后必须恢复原 `matrix_basis` 和 `matrix_parent_inverse`，并更新依赖图，再导出整场。前一 `b779…` 虽没有法线异常，首果的局部挂点仍因父级切换发生偏移，已被取代。当前 `--pose-contract rendered/manifest.json` 回读额外核对全部12果的父级、局部挂点和世界比例，不能只检查节点数和接地 pivot。

`small_scale_review.png` 的 48/72/96 是透明画布宽。`runtime_art_size_review.png` 对应真实 `art_size=72/90`、透明画布 `144/180px`，同时对照现有番茄和空篮。它们是离线缩图，不证明触控或实际页面布局。

[同源草地空间](ENVIRONMENT_REVIEW.md) 将这份 GLB 直接放进连续草地/缓坡/短草的单一渲染场景，并另外输出同 rig 的透明分件。`environment_rendered/` 是已交接的 Standard/Sun 摄影基线，`environment_refined/` 是保持该 rig、锚点和显示尺度严格相等的连续地形修订；上面的 `rendered/` 是 AgX 中性源模型审图，不能混搭到运行页。实际尺寸基准与挂点以对应清单为准，仍须通过隔离页面评审，不能把源模型回读视为整页美术通过。
