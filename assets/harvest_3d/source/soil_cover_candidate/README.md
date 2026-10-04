# 松土盖同源候选

浅土前坡让真实薯体与薯眼半露。没有圆土块假眼、描边、照片纹理或烘焙接触影。
源模型1024三角形、1网格/1材质、2节点；现有Target、命中半径、sweep判定和uncover透明度/缩放负责交互。

已从本目录builder在Blender5.2.2重新导出，GLB文件与实际审图输入逐字节相同（573f96e7…）。相同4fac冻结摄影及灯光来自相邻catalog_profile_candidate/inputs/frozen_render_profile.blend。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python build_soil_cover.py -- --out /tmp/soil-new-geometry
/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python render_frozen_profile.py -- --input-glb /tmp/soil-new-geometry/soil_cover.glb --out /tmp/soil-new-render
python3 audit_geometry.py --out /tmp/soil-new-geometry
```

输出目录必须为空。PNG地面原点(256,467)，运行时地面(0,42)，实际alpha宽度为crop_size×1.30（117/93.6px）。
review_old_vs_revision_90_72.png是离线叠图；真实soil/dig双比例图来自provenance所指QA。正式接入后的证据以HARVEST_RUNTIME_QA文档为准。
