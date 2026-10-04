# 收菜 GLB 只读审计

`audit_glb.py` 使用 Python 标准库，直接读取 GLB；不启动 Blender 或 Godot，也不修改输入文件。

```sh
python3 audit_glb.py candidate.glb
python3 audit_glb.py --json candidate.glb
python3 audit_glb.py --check-whole-plant candidate.glb
python3 -m unittest discover -s . -p 'test_audit_glb.py' -v
```

统计区分 GLB 中每个 mesh 定义累计一次的 `unique_mesh_triangles`，与默认场景实际引用 mesh 后的 `instanced_scene_triangles`。共享 mesh 节省文件和内存，仍会在每个实例位置绘制；完整资产的 60k 面数限制检查后者。静态 primitive 统计排除 `HarvestTarget` 节点及其子树，不能把这个值当作真实运行时 draw calls。

默认命令只输出事实，不把整株规则应用到独立植株、土面或篮子。可选 `--check-whole-plant` 检查完整三株套件：

- 默认场景唯一根节点 `Root`，直接拥有 `GardenBed`、`Basket`、`Plant01`、`Plant02`、`Plant03`。
- 三株合计 12 个独立、唯一的 `HarvestTarget <作物名> P01–P03 F01–F04`；目标为对应植株的直接子节点，并各自拥有 mesh。
- 场景实例 ≤60,000 tris、材质 ≤12、静态 material primitives ≤12。
- image、texture、camera、light 均为 0。

退出码：0 为只读审计成功或完整套件检查通过；1 为可选套件检查失败；2 为无法解析或结构损坏。JSON 输出在启用套件检查时包含 `whole_plant_check.passed/errors`。

测试使用内存 GLB fixture，覆盖共享 mesh/实例、默认场景、重复节点名和目标名、层级与目标父子关系、材质/贴图/顶点色统计、预算边界，以及可选 CLI 退出码。不依赖 Blender、Godot 或项目存档。

COLOR_0 的统计只证明 GLB 有顶点色。Godot 实际导入仍需确认 active material 的 `vertex_color_use_as_albedo` 与 surface 的 `Mesh.ARRAY_COLOR`；不在这里覆写材质。脚本不验证美术、镜头、命中位置或玩家交互，也不能代替真实页面 16:9、4:3 和拿起/分拣状态截图。

`review_glb_roundtrip.py` 用 Blender 默认 glTF importer 回读真实 GLB，不沿用生成器的网格或材质对象。可用 `--expect-sha256` 锁定输入，输出全景、单果隐藏、独立篮图与数值法线报告；不修改输入 GLB、不运行 Godot、不重新导出模型。边界边或退化三角形需结合实际造型判断，不能把数值报告直接当美术或完整拓扑验收。

整株回读另加 `--pose-contract ../whole_plant/rendered/manifest.json`：契约必须匹配输入 GLB 哈希，逐个检查12果的直接父级、局部挂点与世界源比例（误差 `<1e-5`）。它针对“单件归零导出后，首果的父矩阵恢复错位”这一真实回归，不会把正常法线计数当作挂点正确的证明。

`verify_roundtrip_pose_fixtures.py` 在 Blender 中执行5个正/反例：正确挂点、父级切换偏移、错误比例、错误篮子所有权和错版契约。运行命令为 `Blender -b --python verify_roundtrip_pose_fixtures.py`，需看到 `ROUNDTRIP POSE FIXTURES PASSED`，不能只看 Blender 进程退出码；Blender 有时在 Python 异常后仍返回0。
