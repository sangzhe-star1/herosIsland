# 草莓株身候选

这是用于 3D 试片的独立草莓 rosette 株身，不属于 Godot runtime。模型保留地面原点和名为 `FruitSlot | strawberry GLB center` 的子节点；红色果实在评审图中复用已有 `strawberry_readability/rendered/strawberry.glb`，株身 GLB 本身不包含可采果实。`HarvestTarget`、篮子、订单与触控语义仍由现有游戏组件独占。

构型为六组低矮莓叶、短叶柄和一条前伸果梗。目标不是用叶片或透明面伪造连续菜床；床体还需在 pilot 中单独评审。

`rendered/strawberry_plant_review.blend` 是可编辑造型源；生成器从这份场景重新导出 body-only GLB 与固定视角预览：

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b \
  --python assets/harvest_3d/source/strawberry_plant_candidate/build_strawberry_plant.py \
  -- --out assets/harvest_3d/source/strawberry_plant_candidate/rendered
```

`rendered/strawberry_plant_preview.png` 是固定角度的单株造型检查，`rendered/strawberry_plant_body.glb` 是仅含被动株身与果槽节点的三维候选。此输出尚未导入 Godot；必须与实际篮子及 pilot 相机同场，再评审遮挡、尺度、接地和 16:9/4:3 构图后才能决定是否晋升。

Blender 5.2.2 LTS 输出包含 5 个 mesh primitive、约 10.9k 三角形和 5 种纯色材质；没有图像纹理，也没有可采莓果。固定角度预览只用于检查叶冠/果槽是否能组成一株，不是交互验收。当前造型的叶片仍偏莲座感，需在与原地形同场后再判断它是否适合页面。
