# 草莓小尺寸识别修订

本目录不是新美术系统：继续复用 `catalog_profile_candidate` 的既有草莓果体、莓叶、种子、相机/灯光与导出辅助函数。运行页面仍使用 `HarvestVisualArt.crop_badge()` 与 `HarvestTarget`，没有改变水果/蔬菜分类、订单、手势或触控热区。

## 改动与来源

- 原8圈果体扩大上肩、延长柔尖，使轮廓与圆番茄不同；莓叶仍是原7片，沿用整株生成器的叶端焊接、三角化、厚化修复。
- 原种子的中上两排埋在果肉内部。本轮复用14颗原种子网格，按真实果皮半径与切线定位，固定正交镜头下能够看见。没有绘制种子贴图。
- 果体粗糙度改为0.80。接地影仍由现有运行组件负责；候选场景彻底移除原 `Shadow | strawberry` 阴影片，PNG/GLB不含它。
- 冻结输入 `catalog_profile_editable.blend` SHA `e28bda1c3520552c8a00fcde7ec7da55ce6f9deb0cda76627c10afdcab363ee9`，冻结profile SHA `4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512`。两文件未写回。
- 显示设置、World、灯光数据/节点逐值不变；灯光矩阵允许1e-6数值误差，实测最大5.96e-8，导出相机矩阵与catalog相同。不是为草莓另挑相机或补光。

## 冻结输出

`rendered/` 保留生成时的候选manifest，后续正式采用记录单独追加，不回写历史候选状态。

| 文件 | SHA-256 |
| --- | --- |
| `strawberry.png` | `9c965bd5d7cf69cb3d1d21d376dc3d7fd6e0454ecdc8e3190f1004a7f3a8a04a` |
| `strawberry.glb` | `eb33862a529ba8d182d7d76363931f3173453175da2d02dfd1db9205ace29ae7` |
| `strawberry_readable.blend` | `b35febff108aa2b9f910943bc5953c1d3f3e1ba6e20246edd3111a5a278aa97c` |

512×512透明PNG，正交跨度2.60m，接地锚 `(256,467)`，不做单件自动缩放。GLB默认重新导入得到22网格、4材质、5844三角形，无图像纹理；退化三角形、反向角法线、非有限位置/法线和零法线均为0。回读图只用于几何检查，不能代替Godot页面截图。

## 验证与复用

候选隔离快照：`/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-strawberry-candidate-_3s2yca7`。原规则通过；24/32/48/72/96五档×17格均实际可见；两关双比例普通/手持及低动态共10张页面已目视，独立审图也未发现新的身份混淆或遮挡拒绝项。正式草莓PNG已采用，最终组合回归记录见主运行台账及QA文档。

复现生成（输出到新的临时目录，不覆盖冻结包）：

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b \
  --python assets/harvest_3d/source/strawberry_readability/build_strawberry.py \
  -- --out /private/tmp/新的草莓输出目录
```

`verify_runtime.py` 只通过既有 `QASession` 创建独立应用名/存档的QA副本；`--candidate 路径` 仅替换副本PNG，默认复验正式素材，可选触控及果园同屏检查。需Python/Pillow运行环境，不访问正式存档。

边界：本轮证明小图更容易与番茄区分，不等于5–8岁儿童识别验收。种子安排服务于固定镜头，不宣称任意旋转视角的模型已经完成；整页仍是3D制作、2.5D运行，场景构图与目标设备性能仍待收敛。
