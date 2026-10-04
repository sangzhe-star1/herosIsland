# 连续草莓床候选

这里保存一个独立的草莓 rosette 与连续土床候选，和 body-only 候选分开。生成脚本写入自己的 `rendered/`，包含单株 `strawberry_plant.glb` 与独立 `strawberry_bed.glb`，不会改正式页面、既有果实资源或 [body-only 候选](../strawberry_plant_candidate/README.md)。株身只有空的 `FruitSlot | strawberry GLB center`；评审图里的红色圆体只是果槽标记，不在 GLB 中，也不拥有 `HarvestTarget` 状态。

生成与预览：

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b \
  --python assets/harvest_3d/source/strawberry_plant_bed_candidate/build_plant_bed.py \
  -- --out assets/harvest_3d/source/strawberry_plant_bed_candidate/rendered \
  --bed-width 8.8 --bed-depth 4.4
```

默认土床为 8.8×4.4m 的圆角浅丘，由连续闭合土面和稀疏边缘草簇组成；3D 评审图把 15 株草莓按五列三排放在真实床面射线采样点上。当前 plant GLB 约 4.0k 三角形，bed GLB 约 4.0k；边缘草簇使用 16 组低面数草叶，没有逐株椭圆垫或透明带。带 marker 的预览可检查单果槽是否落在叶冠前沿。

这只是 Blender 固定机位候选。宽度和深度可由实际 `HarvestTarget` 根点 bounds 传入，但本次用了 8.8×4.4m 默认估值；Godot 中仍须按实际地面射线命中的根点范围、坡面和篮子净空放置或缩放，再以真实相机截图确认。没有接入 pilot 或正式页面。

## r3：低土丘与缓坡边缘

r3 保留独立株身和果槽，把床面最高点降到地面上方约 0.155m，底缘埋入 0.035m；外圈缓慢抬升，不再使用深色厚侧壁或颜色分带。土色变化只用低对比 GLTF 材质，外缘为 12 组贴边的短叶簇。床宽深仍为 8.8×4.4m，单株及整床均单独导出。它是给主线 Godot pilot 做真实相机验收的候选，尚未通过游戏内视觉验收。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b \
  --python assets/harvest_3d/source/strawberry_plant_bed_candidate/build_plant_bed_r3.py \
  -- --out assets/harvest_3d/source/strawberry_plant_bed_candidate/rendered_r3 \
  --bed-width 8.8 --bed-depth 4.4
```

- [r3 15 株预览](rendered_r3/strawberry_plant_bed_review.png)
- [r3 果槽标记预览](rendered_r3/strawberry_plant_bed_with_slot_review.png)
- [r3 导出清单](rendered_r3/manifest.json)

床体 GLB SHA-256：`3b5174dafc14dfd6f4a992f784aad285b9b90d32be5d7109653571c0f6540d4c`。实际坡面拟合、果实高度、16:9 与 4:3 画面、收菜和投篮流程仍须由隔离 Godot pilot 验证；正式页面没有改动。

## r4：无底裙的超浅土面

r4 是针对 r3 游戏内仍显厚板和露出边缘的后续对照：土面从地面高度起步，最高约 0.09m，使用单面开放网格，不导出封闭底面或侧裙；另加极低幅起伏、低对比嵌入式 loam 纹理和 8 组短边缘叶。纹理平铺坐标覆盖整片土面，图像会嵌入 GLB。它降低坡面错位时露出厚边的机会，但需要游戏内评估，不视为美术通过。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b \
  --python assets/harvest_3d/source/strawberry_plant_bed_candidate/build_plant_bed_r4.py \
  -- --out assets/harvest_3d/source/strawberry_plant_bed_candidate/rendered_r4 \
  --bed-width 8.8 --bed-depth 4.4
```

- [r4 15 株预览](rendered_r4/strawberry_plant_bed_review.png)
- [r4 果槽标记预览](rendered_r4/strawberry_plant_bed_with_slot_review.png)
- [r4 独立 loam 纹理](rendered_r4/strawberry_loam_texture.png)
- [r4 导出清单](rendered_r4/manifest.json)

床体 GLB SHA-256：`79f1e82dd32ec9a24f685d3b17d8fb7eb0e600b520d4e02c33cb210771f532f9`。它仍是隔离资源候选；Godot 的真实相机截图与 14 个根点命中数据决定是否继续保留此方案。

## r5：草地色软化床沿

r5 基于 r4，仅把纹理外缘从低对比土色渐变到 Blender 预览草地色，减少土床的清晰贴片边线。床体仍是 9cm 开口浅面，目标是视觉对照；Godot 里的田地使用独立着色器，边缘色是否匹配仍需实图判断。

- [r5 15 株预览](rendered_r5/strawberry_plant_bed_review.png)
- [r5 果槽标记预览](rendered_r5/strawberry_plant_bed_with_slot_review.png)
- [r5 loam 纹理](rendered_r5/strawberry_loam_texture.png)
- [r5 导出清单](rendered_r5/manifest.json)

床体 GLB SHA-256：`543b734f3ebc3405eae293955c1d7437a5f3322bb13a28c48935ef93bc1e9949`。它同样尚未通过 Godot 的 root/front-of-ground 命中和美术验收。
