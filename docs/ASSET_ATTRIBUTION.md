# 运行时素材来源台账

这份台账记录已进入运行时目录的素材来源，并区分外部/用户提供素材与项目内部生成素材。参考图、隔离试片和未进入 `assets/` 的候选模型不在此列。

| 运行时文件 | 来源与授权范围 | 原始文件 / 校验 | 用途与限制 | 记录日期 |
| --- | --- | --- | --- | --- |
| `assets/backgrounds/harvest_meadow.png` | 项目内部 Blender 连续地形、顶点色和已有叶形生成；未引用第三方模型、照片或纹理。已替换此前用户水粉底景。 | 源包 `assets/harvest_3d/source/whole_plant/environment_refined/`，构建脚本 `build_environment_review.py`；当前运行PNG SHA-256 `f4a91d72ce9bdd606e7d450bba9677a84d0b61948582757ed19f87f0eefe5c4b`；环境GLB SHA `b0ab2a87738360bf01d84aeb2651ee3e48176bc816a3413bfc1d72bfa55d3e92`。 | 仅作 `HarvestAction` 无输入的2.5D底景；不用于可平移/缩放的 `FarmWorld`，不承担点击、订单、手势或存档。源GLB没有迁移成整页runtime 3D。 | 2026-10-03 |
| `assets/harvest_3d/crops/*.png`, `assets/harvest_3d/props/*.png`, `assets/harvest_3d/plants/*` | 项目内部 Blender 模型与已有生成器复用；17种单件重新使用同源冻结相机/灯光/Standard profile，厚藤篮、番茄分件和土盖采用对应内部源包；未引用第三方模型或纹理。 | 源目录 `catalog_profile_candidate/`、`soil_cover_candidate/`、`whole_plant/`；冻结profile Blend SHA `4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512`。运行文件逐项哈希、元数据与正式QA输入见 `assets/harvest_3d/source/RUNTIME_INTEGRATION_20261003.json`；512画布接地锚 `(256,467)`。 | 只替换外观；`HarvestTarget`、手势、篮子命中和订单仍是唯一逻辑来源。果实移动而被动空株留原位；源目录 `.gdignore` 阻止导入Blend/GLB。 | 2026-10-03 |
| `assets/harvest_3d/crops/strawberry.png`（小图识别修订） | 复用上一行内部草莓8圈果体、7片莓叶与原种子网格；扩大上肩、整理柔尖及真实表面种子，移除旧阴影片。不含外部素材。 | 可编辑源/GLB/PNG与生成、回读报告见 `source/strawberry_readability/`；PNG SHA `9c965bd5d7cf69cb3d1d21d376dc3d7fd6e0454ecdc8e3190f1004a7f3a8a04a`，GLB SHA `eb33862a529ba8d182d7d76363931f3173453175da2d02dfd1db9205ace29ae7`。相同冻结profile与接地契约，旧catalog保持不改。 | 订单、作物与篮标仍共用同一PNG/徽标组件；不改分类或手势。不表示儿童识别或自由旋转视角通过。 | 2026-10-03 |

## 未导入的 3D 候选

Quaternius `Ultimate Crops Pack`、`LowPoly Nature Pack` 等 CC0 候选只在隔离
视觉试片中检查，当前没有 OBJ、FBX、GLB 或导出 PNG 写入主项目；是否导入
由 `GARDEN_HARVEST_3D_EVOLUTION_PLAN.md` 的小套件审核门槛决定。决定导入时，
再为每个实际文件补充作者、来源页、许可证、下载日期、原始路径、导出路径和
哈希，不能把这段候选说明当作已引入素材的授权记录。

2026-10-02 项目内部的 `assets/harvest_3d/source/whole_plant/` 保存可拆整株、藤编篮和同源环境的源模型/真实GLB/审图。几何复用既有项目生成器和网格，没有引入第三方模型或纹理；用户图片只作造型参考，未投到图片平面上，也不是自动精确三维重建。10/03 已采用其中同profile的背景和透明分件；Blend/GLB仍受 `.gdignore` 隔离，仅在上述PNG运行图层使用，不声称已接实时3D。

## 历史替换记录

10/01 用户授权的水粉底景原附件 `codex-clipboard-04f9b827-0990-4745-9fd8-4a033a7198c8.png` 为1672×941 PNG，SHA `6487d43358df9699c16ac7d7347a9b05f9ac9b9078317d6e30cf807fef7fea42`。其生成工具及通用再分发许可未提供，仅按用户授权用于本项目；当前相同运行路径已经改为内部同源渲染，不能再将该旧SHA当作当前背景。旧19张单件与道具渲染也保留为历史源包，不作为本轮Standard profile的输入证明。
