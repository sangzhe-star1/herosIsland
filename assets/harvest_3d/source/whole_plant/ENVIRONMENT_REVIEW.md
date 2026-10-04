# 同源草地空间试片

这是 Blender 离线候选，不是已经上线的游戏场景。没有引入 Three.js、第二套目标、订单、地块或射线拾取。

## 使用已有模型

`build_environment_review.py` 默认导入 `rendered/whole_plant_scene.glb`，同时核对冻结 SHA。植株、独立果实和藤编篮的网格、法线及材质槽保持不变；示例平棕菜床只隐藏。脚本检查网格内容哈希、源文件哈希和全部导入对象的变换，允许的变换浮点误差不超过 `1e-6`，实际值写入清单。

环境只新增连续缓坡草地和少量短草。短草复用已有 `Builder.leaflet` 与 `prepare_leaf_surface`，不重造另一套叶形。没有照片、程序噪声纹理、球山、独立阴影片或整床厚土台。当前生成器默认写入独立 `environment_refined/`，不覆盖已交接的 `environment_rendered/` 冻结摄影基线。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python build_environment_review.py -- --out environment_refined
python3 ../validation/audit_glb.py environment_refined/passive_environment.glb
```

审图脚本需要 Pillow，且会更新对应 manifest，冻结包交接后不要原地再运行它。所有输入和生成脚本保存在项目内，不需要旧临时版本目录；输出仍受上级 `.gdignore` 保护，未成为 Godot 运行资源。Blender 命令须同时核对退出码、`ENVIRONMENT_MANIFEST` 标记与实际清单，不能只看它是否退出。

## 输出区别

| 文件 | 用途 | 限制 |
| --- | --- | --- |
| `same_source_space_16x9.png` / `same_source_space_4x3.png` | 同一场景中评审完整植株、篮子、草地与短接触影 | 放大的离线示例，无订单 HUD、无触控行为，不代表真实首单 |
| `environment_only_16x9.png` / `environment_only_4x3.png` | 清除示例根点土色印记后的被动背景候选 | 使用 `art_size90` 的实际米/像素基准；需真实 slots、4:3裁切、篮区净空检查 |
| `plant001_body_512.png` / `tomato_fruit_512.png` / `basket_512.png` | 与该环境同 rig 的透明分件 | 不能与旧 AgX PNG 混搭；仍由现有组件决定位置和状态 |
| `passive_environment.glb` | 真正可编辑/旋转的独立环境网格 | 不含作物、目标、灯光、相机或固定根点印记；顶点色须实际导入检查 |
| `same_source_space.blend` | 可编辑示例场景 | 保存模型与环境，没有游戏规则 |
| `manifest.json` / `alpha_review.json` / 缩图 | 相机、灯光、profile、挂点、源缩放、哈希、面数和画布验证 | 不证明实机帧率、输入行为或美术已通过 |

## 接入契约

- 示例三株的浅土透色只用于完整离线构图。背景 PNG 和环境 GLB **不保留这些固定印记**，否则真实随机布局会出现无作物的假地块。
- `render_profile` 给出精确相机、灯光和 World 参数。当前采用统一 Standard 显示变换、曝光 `-0.20`；相机可见蓝天与环境补光分开，不能为了蓝天把作物照成荧光色。
- PNG 延续 `512×512`、接地基准 `(256,467)`。单果图内已包含 `1.13` 源比例，不重复放大；当前 `png_contract` 另记录实测各果心投影、单果中心和各物件跨度，不能只抄接地 pivot。
- 透明分件没有烘焙接地影，继续复用既有 `Shapes.ground_shadow`。普通单件作物统一基准为 `art_size90`、180px画布、相机跨度2.60，即69.23077px/m；株身跨度2.95，对应 `art_size102.115385`，密集时81.692308。背景跨度为 `1280 * 2.60 / 180 = 18.488889`，不会以放大审图的跨度拼实际页面；密集关缩放仍属于既有组件，不创建新的三维命中尺度。
- `HarvestTarget` 仍只拥有可采的单果；空株属于 field 的被动层，采摘后保留。篮子继续使用 `HarvestBasket` 的原规则和示例标签。

## 当前评审边界

去掉水粉底景与旧平棕床后，同屏材质与接地关系更一致，但低缓坡和稀疏草簇还不能保证真实订单下画面饱满、边缘不抢目标。先用同 profile 的全部既有单件进入新的隔离 QA，检查 16:9 / 4:3 普通态、真实手持态、采空后与低动态；未通过整页评审前不替换正式素材，不进入整页 runtime 3D 迁移。

### 连续地形修订（2026-10-03）

首轮真实20张页面截图确认旧背景深橄榄草地和单一硬地平线仍像测试场；操作区内的小草还容易被误认成可收作物。修订仅在同一生成器调整连续地形、低频顶点色和草簇位置：侧面中坡露出较淡远坡，中央与右下篮区仍平坦、安静，短草移到极边缘。没有添加新树、房屋或玩法。

`frozen_contract_review` 强制新包的 `render_profile`、`runtime_reference`、`png_contract` 与旧基线清单逐字段严格相等。基线 manifest SHA 为 `c337ad2ad59c922bfda3340f9b6422c2d4b99337883088140ef0c39e5487343e`。这证明没有换摄影路线，不证明画面已通过。

修订环境 GLB SHA 为 `b0ab2a87738360bf01d84aeb2651ee3e48176bc816a3413bfc1d72bfa55d3e92`，15,776 tris、2网格/2材质、0纹理/目标/相机/灯光。短草在厚化后也固定薄侧壁三角曲面，默认回读的退化面、反向角法线、非有限位置/法线与零法线计数均为0；旧冻结环境的13项侧壁异常不被追溯改写成通过。真实 Godot 页面、采空回调与手持反馈继续由收菜集成会话单线验证，源文件成功不代替运行验收。
