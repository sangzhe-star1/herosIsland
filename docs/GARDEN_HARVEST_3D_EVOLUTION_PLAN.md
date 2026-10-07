# 菜园与丰收的 3D 化演进计划

> 状态：同源草地、番茄分件、厚藤篮和土盖已接正式2.5D页面；草莓宽肩尖底/真实表面种子、果园短枝提示也已采用。最新 `clean-ground-formal` 隔离快照使用当前 `harvest_action.gd` SHA `9a1cb6…`，记录1698项触控、448项三订单检查/68次送篮、19张截图（14张页面图通过内容门禁、85个小图格逐格可见），39项输入哈希全部匹配。中部大块空草地仍影响构图审美，当前美术不算最终通过；设备性能、儿童识别与完整29项smoke仍开放，未引入 Three.js 或整页 runtime 3D。
> 更新：2026-10-03。
> 关联：[菜园与丰收视觉/体验升级任务计划](GARDEN_HARVEST_VISUAL_UPGRADE_PLAN.md)。
> 面向：5–8 岁儿童、横屏平板优先；保持 Android、iOS 与 Web 的可运行性。

## 0. 结论先行

这不是「把一张 3D 背景贴进来」的计划，而是把游戏逐步变成一座**玩具感的立体农场**。

主路线定为：**3D 制作管线 → 2.5D 运行时呈现 → 受控 runtime 3D 试片 → 只有通过门槛才考虑全 3D 世界**。

这样选择有三个原因：

1. 当前“贴图味”来自视觉语言断裂，而不是少了多边形。水粉大背景、深描边作物、程序化泥土没有共享光向、材质和尺度；直接换成 3D 背景只会把前景衬得更像剪贴画。
2. 菜园与丰收已经有可靠的二维玩法骨架：`FarmWorld` / `FarmCamera` 管镜头与触控，`PlotView` 管地块状态，`HarvestTarget` / `HarvestBasket` 管手势、目标和归类。重写它们既昂贵又会增加儿童操作风险。
3. 项目目前固定使用 Godot 4.7 的 GL Compatibility，并面向低端平板和 Web。Godot 将该渲染器定位为 2D 和基础 3D 的广兼容选项；复杂全 3D 效果需要额外的设备、画质与回归成本。[官方渲染器说明](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

**本计划的承诺：**先让孩子看到的“土、菜垄、篮子、仓库”像来自同一套立体玩具，再决定是否需要真正可移动的 3D 农场。任何阶段都不复制订单、手势、存档、命中或相机系统。

## 1. 要解决什么，不解决什么

### 要解决

- 让作物、泥土、篮子、建筑和环境共享同一个左上暖光、脚下短阴影和比例关系。
- 用几何轮廓、局部遮挡、接地阴影和低模材质建立深度，而不是靠一张完整场景图“假装有空间”。
- 让可交互作物仍是最清楚的焦点；背景的丰富度不能抢走“现在该点什么”。
- 让 3D 资产能被多个页面复用：同一只篮子、同一块菜垄、同一座仓库应有一个视觉来源。
- 保持 16:9、4:3、低动态模式、触摸和鼠标路径的行为不变。

### 不解决 / 当前不做

- 不把 `FarmWorld`、`HarvestAction`、`FarmCamera`、`PlotView`、`HarvestTarget`、`HarvestBasket` 改成第二套 3D 玩法系统。
- 不在第一轮做自由绕农场行走、RayCast 点选、3D 物理、昼夜循环、PBR 写实、SSAO、SSR 或全屏后处理。
- 不把 AI 生成的整张风景图作为运行时主背景，也不恢复旧的 `background_art` 路径；`Stage` 的统一程序化场景原则仍然成立。
- 不为了 3D 缩小触控热区、增加阅读文字，或让装饰吞掉地块/设施点击。
- 不在未经验证前全局切换到 Mobile / Forward+ 渲染器。

## 2. 本次候选图的处置

图 1 已经在用户明确要求“直接配置”后作为丰收挑战的**过渡性固定底景**导入；图 2 仍只作为美术参考。这个例外不改变本计划的主张：整张背景不能替代同源、可组合的环境和前景资产，也不能进入会平移缩放的菜园世界。

| 候选 | 技术审计 | 可借鉴的内容 | 不能直接使用的原因 | 本计划中的状态 |
| --- | --- | --- | --- | --- |
| 图 1：蓝天、远山、草原 | `1672×941`、8-bit sRGB、RGB、无 alpha，约 16:9 | 顶部 HUD 留白、低对比远山、地平线高度 | 4:3 的 `expand` 会裁掉两侧；它是静态墙纸，不含近中远遮挡、接地影或可随镜头变化的层，不能单独解决粗描边作物的贴图感 | 已限于 `HarvestAction` 的无输入底景；不用于可平移/缩放的 `FarmWorld`，也不承担订单、手势或命中 |
| 图 2：草地与边缘植被 | `1733×907`、8-bit sRGB、RGB、无 alpha；比例与 `FarmWorld` 的 `2200×1150` 仅差约 0.12% | 草地色板、边缘装饰密度、中央交互留白 | 不透明整图会同现有路径、围栏、树和安全区重复；以当前尺寸放到世界并在 1.25 倍镜头下会变软；没有局部遮挡和交互层次，仍是一张矩形底图 | 菜园**地表色板/密度参考** |

图 1 的当前授权范围、校验值和使用限制已记录在 `docs/ASSET_ATTRIBUTION.md`。以后若要真正导入用户生成、外购或外部 3D 素材，先在该台账记录来源、生成工具或作者、使用许可、原始文件、导出文件、页面用途和压缩规格。没有可追溯来源的素材只可作参考，不进入发布包。

## 3. 目标美术语言：少年英雄的玩具农场

不是水粉插画农场，也不是写实模拟经营农场。目标是能让孩子一眼理解、又有“摸得到”的立体感的**低模玩具农场**。

| 规则 | 具体约束 |
| --- | --- |
| 视角 | 固定 3/4 俯视；所有 3D 源资产以同一正交镜头导出。不要每个物体各自选一个透视角。 |
| 光线 | 左上方暖色主光；右下方只留很短的蓝灰/紫灰接地影。阴影说明“站在哪里”，不制造恐怖或真实硬阴影。 |
| 材质 | 圆润低模、哑光玩具塑料/黏土感、3–4 级色阶和极浅 AO；禁止照片纹理、金属高光、噪点很重的水粉和纯黑描边。 |
| 轮廓 | 远景无深描边，环境只有弱轮廓，可互动目标最清晰。深蓝绿只用于可点物的重要外缘，不能出现在每块草地上。 |
| 深度 | 通过前后遮挡、草缘盖住土边、菜垄高度、脚下阴影和微小尺寸变化表达；不靠巨大棕色地块或模糊背景。 |
| 动效 | 作物轻摆、篮子收纳轻压、草地极慢摆动、收获时少量土屑/光点。所有动效遵从 `Juice.motion_enabled()`，低动态模式保留静态结果。 |
| 儿童可读性 | 一个页面一个高对比主动作；装饰不能伪装成按钮；48 / 72 / 96px 目标尺寸下，作物、篮子和状态必须仍能区分。 |

## 4. 现有架构与不可破坏的边界

项目并非没有渲染基础，而是已经有一套应被延续的 2D 世界语言：

- `Stage` 负责天空、远中近景、地面、道具、前景的统一生成，并借由 `Shapes` 统一光向和接地阴影。它不能被按页面贴入一张背景图的做法绕开。
- `FarmWorld` 是菜园唯一会随镜头平移、缩放的世界；`FarmCamera` 是唯一的逻辑镜头，拥有 `centre`、`zoom`、`window`、`world_to_screen()` 和 `screen_to_world()`。
- `FarmWorldArt` 只画被动环境；`PlotView` 仍拥有地块的状态呈现与真实交互位置；建筑/地块的命中仍回到 `FarmWorld`。
- `HarvestAction` 的 `_field` 是唯一承接收菜手势的舞台；`HarvestTarget` 和 `HarvestBasket` 是唯一的目标/篮子业务组件。
- HUD 继续是 `Control` / `UiKit` / `HeroTaskRibbon` 的二维界面，永远不跟着 3D 相机移动。

因此，新视觉的层次应是：

```text
数据、订单、存档、手势识别（保持原样）
                 │
                 ├── FarmWorld / PlotView ── 现有地块与设施热区
                 └── HarvestAction / Target / Basket ── 现有采摘与归类热区
                                      │
                                只传递“展示状态”
                                      │
                   2.5D 预渲染精灵 或 Toy3DPreview（无业务、无输入）
                                      │
                     FarmWorldArt / Harvest 被动视觉层（在热区之下）
                                      │
                         现有 2D HUD、教程手、文字与反馈（在最上）
```

### 唯一允许新增的视觉能力

若预渲染试片通过、且 runtime 3D 也需要落地，可以新增一个可复用的 `Toy3DPreview`。它必须满足：

1. 只封装 `SubViewport`、`World3D`、固定 `Camera3D`、灯光和视觉模型；不持有订单、作物、存档、手势或命中规则。
2. 输出一张纹理给既有 `Sprite2D` / `TextureRect`，由页面现有节点决定位置、显示与销毁。
3. 禁止接收输入；点击仍由 `FarmWorld` 或 `HarvestAction` 的二维热区处理。
4. Phase 3 的首个单物体试片可以只放在一个页面，以验证输入、锚点和性能边界；只有第二个**通过视觉审核**的资产出现后，才把该桥接层提升为菜园与丰收共同复用的正式视觉能力。没有通过审核的原语试片不得留在页面里，更不能形成“第二套场景系统”。

Godot 官方明确把“在 2D 游戏中渲染 3D 物体”列为 `SubViewport` 的适用场景；其纹理可以回填到 2D 节点。该能力适合局部展示，不等于需要把整页迁为 3D。[Godot Viewports](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html)

## 5. 路线决策矩阵

| 路线 | 画面上得到什么 | 对现有玩法的风险 | 首轮成本 | 本计划的定位 |
| --- | --- | --- | --- | --- |
| 继续生成完整 2D 背景图 | 细节增加，但视觉语法仍可能冲突 | 低 | 低 | 不再作为主路线 |
| **离线 3D 制作 → 正交预渲染精灵** | 低模立体质感、统一光源，运行时仍像可靠 2D | 很低 | 中 | **主路线 / 第一试片** |
| **局部 runtime 3D `SubViewport`** | 仓库、篮子、菜垄可有真实微动和受光变化 | 中低 | 中 | 第二试片，必须有回退 |
| 3D 地表 + 2D 作物/UI | 局部深度，但容易再次混搭 | 中 | 高 | 仅在局部试片通过后扩大 |
| 完整 runtime 3D 菜园/丰收 | 自由相机、真实遮挡、昼夜等产品能力 | 很高 | 很高 | 远期立项，非本轮承诺 |

### 关键判断

第一轮“往 3D 走”的最佳方式是**用 3D 统一资产生产**，不是先把触摸农场变成需要射线投射的 3D 游戏。孩子看到的是立体农场；代码仍保留最稳定、最易测的二维互动。

## 6. 分阶段实施计划

### Phase 0：风格合同、基线和资产规范

**目标：**先统一“什么算同一种 3D 玩具资产”，避免一批低模资产又变成另一种拼贴。

| 工作项 | 产物 | 复用与边界 | 验收 |
| --- | --- | --- | --- |
| 固定风格合同 | [`TOY_FARM_3D_STYLE.md`](TOY_FARM_3D_STYLE.md) | 只描述镜头、光向、轮廓、色板、材质与像素尺寸；不创建第二个主题系统 | 任意两位素材制作者按文档能导出同角度、同光向的篮子 |
| 建立截图基线 | 丰收普通态、手持态；菜园 16:9 / 4:3 全景、聚焦地块 | 复用现有截图探针；不使用正式 `user://` | 后续每一轮可并排比较，而不是凭印象判断 |
| 选择首批物体 | 一只篮子、一组菜垄、一座仓库/订单板外壳 | 都是静态或低频视觉物；不先替换 14 种作物和复杂手势对象 | 每项都能映射到既有 `HarvestBasket` 或 `FarmWorld` / `FarmWorldArt` |
| 确立来源台账 | `ASSET_ATTRIBUTION.md` 条目模板 | 只记录实际要导入的资产；参考图不入包 | 资产来源、许可、原始文件与导出尺寸可追溯 |

**退出条件：**风格合同已写明，待同屏 3D 小套件通过美术评审后确认；首批资产不包含完整背景、不包含交互规则；未写入任何玩法代码。

### Phase 1：3D 制作、2D 运行的垂直切片（首选）

**目标：**先验证“低模玩具感”本身是否消除贴图味，而不是先验证复杂的 3D 工程。

#### 1.1 首批资产范围

| 页面 | 首批对象 | 为什么先做它 | 暂不做 |
| --- | --- | --- | --- |
| 丰收挑战 | 一只分类篮子 + 一段三条菜垄的土/草边 | 篮子是高频视觉锚点；菜垄能直接替代中央大棕色贴片 | 作物手势、订单逻辑、目标解析、整张背景 |
| 每日菜园 | 一座仓库或订单板外壳 + 一块地块草缘 | 建筑是稳定地标，最适合作为“立体玩具”试片 | 所有设施一次替换、地图相机、种植/收获状态机 |

#### 1.2 3D 源资产与导出规范

- 源文件建议使用可编辑的低模格式；导出的运行时图片应带透明背景，单独保存，不烘焙天空、草原或页面 UI。
- 所有物体使用同一个正交 3/4 镜头和同一个地面基准点。图片的 pivot 必须落在物体真正接地的位置，而不是图像中心。
- 一张物体图只包含一个可替换对象或一个有限的地表模块；禁止把树、路、花、天和建筑烘成不可拆分的大场景。
- 光照在导出时统一：左上暖光、右下软阴影、哑光表面。不要依赖黑色描边去补轮廓。
- 对象应以目标最大显示尺寸的至少两倍导出后再缩放。若未来确实尝试整张菜园底材，在 1.25 倍镜头下，宽度至少需要覆盖约 `2750px`；先用 `3072×1606` 级别样图和真实设备显存测试，不能把当前 `1733px` 候选直接上线。

#### 1.3 集成方式

- 丰收：只扩展 `HarvestAction` 已有的被动土壤绘制层和 `HarvestBasket` 的视觉外壳；`takes()`、`in_reach()`、`accept()`、订单和手势节点保持唯一来源。
- 菜园：只在 `FarmWorld._draw_ground()` / `FarmWorldArt` 的被动层放置预渲染视觉，继续由 `FarmWorld` 处理地块、设施、平移和缩放；`PlotView` 仍绘制状态和作物。
- 2.5D 精灵必须位于真实目标热区之下，并完全透传输入。它只会让同一个对象“看起来更立体”，不会创建另一个可点对象。

**退出条件：**首批四类对象在一张丰收截图和一张菜园截图中读为同一材质语言；相应鼠标/触控、订单、收纳、地块状态和存档回归全部通过。若效果仍像贴图，先回到风格合同和资产重做，**不扩大数量**。

### Phase 2：可复用的 2.5D 资产包与状态映射

**目标：**让通过 Phase 1 的 3D 资产覆盖更多状态，而不产生视觉状态和真实状态两套真相。

| 模块 | 正确做法 | 禁止做法 |
| --- | --- | --- |
| 篮子 | 在 `HarvestBasket` 已有 `waiting()`、`accept()`、样本标签和接地影的展示点上替换/补强视觉；业务方法仍不动 | 新建 `Basket3D` 并在里面重新判断该收哪种菜 |
| 菜垄 | 根据 `_draw_bed()` 已有位置布局视觉地表；作物仍由现有 `HarvestTarget` 放置并接收手势 | 重新随机生成一批 3D 作物坐标，导致视觉与可点中心不一致 |
| 建筑 | 从 `FarmLayout.facility()` 的既有位置和 id 获得锚点；仍由 `FarmWorld` 发出 `facility_pressed` | 给 3D 房屋单独加点击、订单页或库存状态 |
| 地块 | 继续让 `PlotView` 从既有 Farm/Growth 状态画成熟、缺水、金色等反馈 | 把成长时间或“可收获”判断塞进视觉资产 |
| 作物 | 先保持现有交互精灵；后续若重做，必须以同一 3D 源资产导出所有成熟度/手势需要的图 | 一部分水粉 PNG、一部分低模、一部分矢量同时出现在同一菜畦 |

此阶段的资产包应按“可组合”拆分，而非按“某张页面”拆分：

```text
3D 源资产
├── ground/       草缘、土壤、菜垄、路径（可拼接、无烘焙背景）
├── props/        篮子、仓库、订单板、围栏、旗帜
├── crops/        每种作物的成熟度、手势外观、阴影参考
├── shadows/      必要时的短接地 AO，不含大面积环境阴影
└── exports/      正交预渲染 PNG / atlas 与导出清单
```

**退出条件：**同一资产至少有两处复用或明确只属于一个稳定地标；没有添加第二份订单、存档、手势、相机或输入事件；每次增量可单独回退。

### Phase 3：runtime 3D 可行性试片（有回退）

**目标：**只验证一个真正运行时的 3D 物体是否能在目标设备上提供“值得保留”的增益。

首选试片为**菜园仓库**，次选为**丰收菜垄**。仓库位置稳定、已有设施 id 和二维命中，最能隔离 3D 风险。篮子可以先走预渲染路线；它在手持和收纳时变动频繁，过早接 runtime 3D 只会增加同步成本。

#### 3.1 试片场景结构

```text
现有 FarmWorld / HarvestAction（仍拥有所有玩法）
└── Toy3DPreview（纯展示宿主，候选新增）
    ├── SubViewport（透明、不接收输入，可按需要只更新一次）
    │   └── World3D
    │       ├── Camera3D（固定正交 3/4 视角）
    │       ├── DirectionalLight3D（唯一主光）
    │       └── Low-poly MeshInstance3D（一个仓库或一段菜垄）
    └── 既有 Sprite2D / TextureRect（显示 ViewportTexture，放在视觉层）
```

在菜园中，显示 `ViewportTexture` 的 `Sprite2D` 应作为既有仓库/设施视觉节点的子节点，随 `FarmWorld` 的现有平移和缩放一起移动；它不是新的页面或相机。设施视觉在世界刷新时本来就可以重建，因此 3D 预览也必须是可重建、无业务状态的节点。

#### 3.2 技术约束

1. **固定正交镜头先行。**Godot 的 `Camera3D` 支持正交投影，物体不会因远近改变屏幕尺寸；这更适合对齐儿童触控点和现有 2D 画面。[Camera3D 文档](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)
2. **输入永远留在 2D。**使用独立 `SubViewport` 输出纹理，不使用会转发 GUI 输入的 `SubViewportContainer`；viewport 禁用 GUI 输入和 3D 物理拾取，显示 `Control` 设置 `mouse_filter = IGNORE`。仓库点击继续走 `FarmWorld`，篮子落点继续走 `HarvestBasket.in_reach()`。试片必须断言“视觉层出现后，原点击结果完全相同”。
3. **相机只有一个逻辑来源。**`FarmCamera.centre`、`zoom`、`window` 继续是唯一可测试的镜头状态。若 runtime 视觉需要跟随菜园移动，只能由一个无状态投影适配器读取它；适配器不得自行解释手势、夹紧或边界。
4. **先用单物体纹理回填。**第一版把 3D 输出当作现有世界节点中的一个视觉物体，随 `FarmWorld` 的已有 `position` / `scale` 移动。不要先渲染完整 3D 世界并尝试同步两台相机。
5. **渲染保持朴素。**在 Compatibility 下只使用一盏方向光、少量哑光材质、烘焙 AO 或顶点色；不依赖实时全局阴影、体积雾、屏幕空间效果、Decal 或高级后处理。Godot 的 Compatibility 特性集对这些高级能力有限。[官方特性对照](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
6. **首帧也要验证。**模型/材质首次出现不能卡住孩子的点击；试片须在实际设备上检查材质编译和首次打开页面的卡顿，必要时预热一次后再显示。[Godot 管线编译说明](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)
7. **必须可关闭。**3D 试片需有一个明确的回退开关或可以整体移除的独立视觉节点；关闭后不能改变任何可见逻辑、数据或点击结果。

#### 3.3 试片验收

- 在 16:9、4:3、默认镜头、最大镜头、平移后和回家镜头下，3D 视觉锚点都与原设施/地块中心一致。
- 手指点在 3D 仓库、视觉边缘、草地、底栏和缩放按钮上，仍得到与试片前一致的事件；装饰没有吞掉输入。
- 在目标 Android 平板和 iPad（若可用）上与 2D 基线对照：没有持续掉帧、输入延迟、首次显示长卡顿、明显显存压力或发热异常。
- 3D 拿掉后，截图和探针仍可回到原有 2D 表现；这证明它不是业务依赖。

**失败处理：**任一项不通过，就删除/停用 runtime 试片，继续使用 Phase 1–2 的预渲染 2.5D 路线。失败不是倒退，而是避免把不可控渲染成本扩散到全项目。

#### 3.4 试片记录（2026-10-01）

- [x] 做过透明 `SubViewport`、独立 `World3D`、固定正交镜头和一盏无阴影方向光的单仓库试片；它从未持有输入、碰撞、订单、存档或相机业务。
- [x] 在隔离存档的 16:9、4:3 运行中验证过原有命中、触控和回归路径，证明这类视觉节点可删除而不影响玩法。
- [x] 视觉评审结论：通用低模原语与现有深描边作物、程序化环境不共享材质、边缘或比例语言；它让页面出现“一个 3D 模型贴在 2D 页面上”，没有改善贴图感。因此仓库试片、专属探针断言和 `Toy3DPreview` 已全部从产品代码撤回。
- [x] 尝试过用运行时基础几何制作收菜菜垄；截图读成硬质木条/模型，和松土语义冲突。该分支同样不保留。
- [ ] 若重新尝试 3D，下一件资产必须先拥有同一正交镜头、左上暖光、圆润哑光材质和透明导出的真实源资产；先与篮子/菜垄做同屏审核，审核通过后才接入既有 2D 玩法壳。

#### 3.5 真实低模源资产隔离复核（2026-10-01）

- [x] 在**隔离项目与隔离存档**中，用 Quaternius 的 CC0 `Ultimate Crops Pack` 真实 OBJ 作过单株与小菜畦复核：番茄、胡萝卜、南瓜、生菜和草丛的轮廓、受光和遮挡比现有深描边 PNG 更接近“从泥土里长出来”。来源页标明该包有 102 个模型、5 个生长阶段及 CC0 授权；这是候选源，不是已导入项目资产。[官方源包](https://quaternius.com/packs/ultimatecrops.html) / [作者在 OpenGameArt 的 CC0 镜像](https://opengameart.org/content/lowpoly-crops-pack)
- [x] 同时复核了 CC0 低模自然物候选，确认树、灌木、石头可以来自同一作者的自然物包；但当前收菜需要的篮子、菜垄/草缘和首批作物还没有以**同一镜头、同一材质、同一导出规格**成为一套完成资产，不能把单个模型当作产品答案。[CC0 自然物候选](https://opengameart.org/content/lowpoly-nature-pack)
- [x] 做过“实时透明 3D 作物叠在水粉参考背景上”的反例。它能证明模型体积，但没有同源地面、接地 AO、篮子和相机基准，画面仍然像模型漂在背景前。因此该反例只作为阻断证据，**不进入主项目，也不作为截图优化的交付物**。
- [x] 随后在隔离 QA 中完成过“同源低模小场景”复核：地面、远景丘陵、树、菜畦和作物都通过同一个正交相机与光源渲染，浮空菜畦和水粉/低模混搭随之消失，16:9 与 4:3 均能完整容纳菜畦。结论同样不是“可上线”：原始低模包、代码色块和简化远景的密度/材质仍停留在技术验证级，不能直接替换产品页，也不保留 runtime 节点。
- [x] 本轮产品侧只落下可回归的二维结构修复：收菜页将用户授权的草原图限制为固定、无输入的底景；巨型棕色田地改为随目标显隐的局部根部土丘；篮子列复用 `FarmWorldArt` 的低位分类角而非竖直货架；订单 HUD 继续使用 `UiKit`，但压缩为留白充足的横向轨道。没有新增订单、手势、篮子命中、存档或相机系统。
- [x] 追加收菜限定的轻量调色 pass：`HarvestTarget` 原有 `TextureRect` 保持唯一作物节点，暖橄榄墨线、较低饱和度和更清楚的接触影减轻前景跳脱；原图轮廓、alpha、成熟 tint/wash、触控热区与菜园显示均保持各自现有路径。16:9 与 4:3 均已复核；这只是过渡性的融合处理，不代替同源资产制作。
- [ ] 重新打开 3D 门槛前，先在**隔离试片**交付同源的四件小套件：`篮子 + 三条菜垄/草缘 + 1 种成熟作物 + 接地阴影`。它们必须以固定正交 3/4、左上暖光、透明 alpha、接地 pivot 导出；把同一套切片放到 16:9、4:3、手持态截图里审稿。任何一处像漂浮贴图，就回到资产制作，不接 runtime 3D。

- [x] `docs/ASSET_ATTRIBUTION.md` 已登记用户提供的草原背景和仅限收菜页的用途；若后续引入 CC0 低模或其烘焙导出，再补作者/来源页、许可证、下载日期、原始 OBJ/Blend 路径、导出文件哈希和页面用途。目前没有第三方 3D 二进制写入主项目。

#### 3.6 程序化环境与同屏资产再试片（2026-10-01）

- [x] 用现有 Quaternius 作物模型在隔离 QA 副本重做了完整 3D 收菜小场景；测试同时加入了程序化地形、柔土菜垄和篮子几何，并使用 Godot 4.7 / GL Compatibility 实际渲染截图。
- [x] 该轮仍未通过：地形显得空、亮度/色板难控制，远景退化成几条不自然的几何脊线，菜垄和篮子仍像程序拼装物；真实作物虽有体积，也没有让页面成为一个可信、统一的玩具农场。此试片只保留为阻断记录，不并入产品或发布素材。
- [x] 项目内已新增 [`TOY_FARM_3D_STYLE.md`](TOY_FARM_3D_STYLE.md)，明确拒绝继续靠圆盘地块、球体山、圆柱篮子堆场景；后续必须先获得同源、可编辑、同镜头校色的 3D 资产小套件。
- [x] 复核了 3DAssets.dev 的 `Cozy Farm and Homestead` 套件说明：该页列出 66 个共用色板模型、16 种作物，标注 CC0，并宣称 glTF 可导入 Godot；但提供的一体式 GLB 在 Godot 4.7 实际导入时因 `KHR_mesh_quantization` 扩展不受支持而失败。素材同时标注 66/66 文件使用 AI 生成；即使将来转换成功，也仍需完整人工美术评审，不作为当前接入候选。[套件说明](https://3dassets.dev/packs/cozy-farm-and-homestead)
- [ ] 其他外部候选包尚未选定。Quaternius 作物与自然物包均标 CC0，但分属不同包；Godot Asset Store 的 Cozy Farm 页面标 CC0，同时将当前版本标注为不稳定且暂无评价，不能仅凭许可证视为质量过关。[Quaternius Ultimate Crops](https://quaternius.com/packs/ultimatecrops.html)、[Godot Asset Store Cozy Farm](https://store.godotengine.org/asset/styloo/farm/)
- [ ] 下一步不再调色掩盖几何缺陷；只在有实际同源资产（篮子、菜垄、作物至少三件）的情况下继续 2.5D 同屏审核。若拿不到合适素材，先停在风格规范，不把原语试片接到主界面。

#### 3.7 当前原型复核与下一份素材输入（2026-10-01）

- [x] 重新看过隔离原型 `heroes-island-harvest-3d-v8.png`：天空与远景呈带状切片，地面成为大块无层次的绿板，菜垄/篮子过小且像独立模型摆件，和作物、空间比例没有形成一个可玩的农场。这张图只用于记录失败点，不是产品页面截图，也不作为美术基线。
- [x] 决定不再通过继续加树、花、碎石或调整色值来掩饰结构问题；也不引入 Three.js。Godot 现有渲染栈可以承载合格的局部 3D，但当前缺的是同源模型和明确的景深构图。
- [ ] 下一轮仍请求一份**可编辑的 3D 垂直切片**用于同屏审核：单独几何/材质的 GLB（优先），包含菜垄、成熟作物、草缘与篮子，物件节点可拆分；不含完整风景、天空或烘焙背景。整张场景的渲染 PNG 只作美术参考；单个对象的透明 PNG 可以作为受限 2.5D 视觉层，但必须一一映射现有对象并保持玩法状态由当前 2D 节点控制。
- [ ] 收到 GLB 后，先在隔离场景用 Godot 的同一正交镜头和左上暖光渲染，再与现有交互层对位；只验证构图、接地、前后关系和视觉一致性。通过前不把该 GLB 接入产品页或新增 runtime 3D；当前 2D 命中、状态和收菜逻辑继续由 `HarvestTarget` / `HarvestBasket` 负责。

#### 3.8 逐作物透明渲染图接入（2026-10-01）

- [x] 使用共享 Blender 场景生成 17 种丰收作物/杂物图和 2 种道具图，单张 `512×512` RGBA，统一 3/4 正交相机与 `(256, 467)` 地面锚点；项目内源档和构建脚本保存在 `assets/harvest_3d/source/`，运行时 PNG 单独放在 `crops/` 与 `props/`。
- [x] `HarvestVisualArt` 只按作物/道具 ID 解析贴图，并把地面锚点映射到既有显示位置；`HarvestTarget` 缺图时退回原图标。收菜手势、成熟状态、篮子命中、订单和存档仍由原组件负责。
- [x] 隔离 QA 副本的 16:9 与 4:3 普通态、真实触控后的手持态截图均通过布局复核：脚点落在草垄上，订单和成熟提示未遮挡，两只篮子与目标提示仍可分辨。
- [x] 19/19 作物/道具贴图覆盖探针通过；90px 联系表检查确认全部剪影可辨。缩小后的 held cue 在双比例截图中仍能表明作物已拿起，且没有盖住手势触点或篮子样本。
- [x] 17 种作物/杂物的 alpha 裁切徽标与 2 种道具剪影已按 48、72、96px 复核；19 项主要轮廓在 48px 下仍可区分，籽粒、麦芒等细节在 72px 以下变弱。归档联系表：[`contact_sheet_small_sizes.png`](../assets/harvest_3d/source/contact_sheet_small_sizes.png)。
- [x] 隔离存档下 `HarvestTouchProbe` 在 1280×720 与 1024×768（expand 后 1280×960 视口）共 442 项通过；新增鼠标拖取番茄并入篮一次的真实输入回归，未改变玩法输入、命中或归类实现。
- [ ] 完整实际页面里的 48–72px 工具、奖励和状态图标可读性，目标平板性能与首次显示卡顿仍待单独验收；此受限 2.5D pass 不代表菜园 GLB 或完整 runtime 3D 小套件验收通过。

#### 3.9 GLB v3 的 Godot Compatibility 实渲染（2026-10-01）

- [x] 将隔离 GLB v3 放入 Godot 4.7.1 GL Compatibility 渲染器实际出图；正交相机按模型包围盒适配 16:9（1280×720）与 4:3（1024×768），床、作物和篮子均完整入镜。
- [x] 双比例均确认 GLB 网格和基础材质可导入、可显示；本试片不含游戏输入层，不能作为交互验收。
- [ ] 视觉仍未通过：叶色偏亮、番茄高光明显，厚木床沿与编织篮抢过植株，和现有柔和草原页不统一；v3 保持在隔离目录，没有进入产品代码。
- [ ] 下一版改用项目现有 Blender 作物、篮子、草土资产，补连续菜床并继续以 Godot Compatibility 双比例截图评审；通过后才做实际页面对位与触控回归。

#### 3.10 同源环境 v4 的 Godot 双比例实渲染（2026-10-01）

- [x] 从隔离的 v4 Blender 场景导出临时 GLB，包含可见远景、连续菜床、项目现有胡萝卜/篮子模型和源正交相机；Godot 4.7.1 GL Compatibility 成功导入 106 个网格和相机。
- [x] Godot 渲染器下完成 16:9（1280×720）与 4:3（1024×768）截图；4:3 按比例增大正交可视高度后，菜床和篮子都留在画面内。
- [ ] 视觉仍未通过：环境在 Godot 中成为硬色带，草地/作物偏亮，动态阴影偏硬；AgX 能缓和颜色但未修复托盘感、整齐重复的作物构图或大片背景色块。关闭动态阴影后又显得过平。
- [ ] 该 GLB 和渲染器仅存在于 `/private/tmp` 隔离试片；没有做游戏交互对位。下一版仍须先通过 Godot 兼容渲染器的视觉评审，再接入现有 2D 交互壳。

#### 3.11 v4 低床沿修订的 Godot 复核（2026-10-01）

- [x] 将 11:55:28 保存的 Blender 源场景复制到隔离快照，再导出 GLB；Godot 4.7.1 GL Compatibility 成功导入 102 个网格，并渲染 16:9（1280×720）与 4:3（1024×768）。本轮截图对应固定源快照，避免建模会话写文件时导出读到混合版本。
- [x] 新几何移除了硬质高架床沿；16:9 与 4:3 的篮子均完整入镜，草土菜床比高床沿版本更接近长在地里。
- [ ] 视觉仍未通过：16:9 中地面是大块平绿底并带明显重复纹理，菜床读成硬边大土盘，胡萝卜偏亮且排列重复；4:3 虽出现天空/地面分层，但地平线成为数条硬色带，主体仍偏小、留白较多。截图位于 `/private/tmp/heroes-island-toy-farm-v4-latest-godot/godot_render_16x9.png` 与 `/private/tmp/heroes-island-toy-farm-v4-latest-godot/godot_render_4x3.png`。隔离源快照为 `/private/tmp/heroes-island-toy-farm-v4-latest-source_snapshot.blend`，GLB 与渲染 harness 位于 `/private/tmp/heroes-island-toy-farm-v4-latest-godot/`；均未接入产品页或对齐游戏交互。
- [ ] 下一轮依实际 Godot 图继续修自然地平与地面层次、作物疏密和 4:3 独立镜头；每次改动后固定源快照、重新导出 GLB 并做双比例 Compatibility 复核，过关前不进入页面集成。

#### 3.12 v4 独立 4:3 镜头与环境修订的 Godot 复核（2026-10-01）

- [x] 对 12:01:41 保存的新版场景建立只读快照 `/private/tmp/heroes-island-toy-farm-v4-1201-source.blend`，从该快照导出隔离 GLB；Godot 4.7.1 GL Compatibility 成功导入并渲染 126 个网格。16:9 用 `Harvest Camera 4x3` 的 3.825 正交尺寸，4:3 用 5.1；输出分别为 1280×720、1024×768。
- [x] 4:3 改为独立正交相机后，菜床和篮子比 3.11 更大，且均完整入镜。
- [ ] 视觉仍未通过：两个比例都出现远离菜床的大片扁平叶片，菜床仍像浮在地面的硬边土盘，胡萝卜间距和造型高度重复、颜色偏亮，阴影偏硬；16:9 仍只有平绿地面，4:3 顶部有明显白色水平线和硬色带。截图位于 `/private/tmp/heroes-island-toy-farm-v4-1201-godot/godot_render_16x9.png` 与 `/private/tmp/heroes-island-toy-farm-v4-1201-godot/godot_render_4x3.png`。该版本只在 `/private/tmp/heroes-island-toy-farm-v4-1201-godot/`，未接入产品页或对齐游戏交互。
- [ ] 下一版先移除或正确扎根漂浮叶片，重做自然连续的地面/地平过渡并削弱土盘轮廓；再调作物疏密与亮度。导出后仍需用同一固定快照流程做双比例 Godot 复核。

#### 3.13 v4 地平与草簇修订的 Godot 复核（2026-10-01）

- [x] 对 12:07:03 保存的场景固定快照 `/private/tmp/heroes-island-toy-farm-v4-1207-source.blend` 并单独导出 GLB；Godot 4.7.1 GL Compatibility 成功导入 150 个网格并完成 16:9、4:3 实渲。截图：`/private/tmp/heroes-island-toy-farm-v4-1207-godot/godot_render_16x9.png`、`/private/tmp/heroes-island-toy-farm-v4-1207-godot/godot_render_4x3.png`。
- [x] 这一版移除了离开菜床的大块扁平叶片；菜床和篮子在两个比例中完整入镜。
- [ ] 视觉仍未通过：两种比例的远景都由白/浅灰与多层绿组成明显硬横条，16:9 的白色带横穿画面；取样点 `(640, 180)` 的 RGBA 正好等于 Godot 试片设置的背景清除色 `#E9E6DF`，说明该处镜头能透过背景几何的空隙看到清除色。边缘草簇被画幅裁切。土垄依旧读成浮在地面的大土盘，胡萝卜重复且偏亮，阴影生硬。当前依然只是隔离试片，没有接入产品页或游戏交互。
- [ ] 下一轮先让不透明背景几何完整覆盖相机画幅、消除露出清除色的缝隙，并统一地面、地平、天空的过渡；删除或重新摆放会被画面切边的草簇，再评估菜床形状、作物重复度和光照。必须以新快照的 Godot 双比例图复核。

#### 3.14 v4 连续草地的 Godot 材质诊断（2026-10-01）

- [x] 对 12:11:58 快照 `/private/tmp/heroes-island-toy-farm-v4-1211-source.blend` 完成 GLB 导入和双比例实渲：148 个网格，截图在 `/private/tmp/heroes-island-toy-farm-v4-1211-godot/godot_render_16x9.png`、`godot_render_4x3.png`。
- [x] Blender 预览里的绿地在 Godot 中变成大面积浅米色，且没有地平线。检查导出的 GLB 可见草地网格包含 `COLOR_0`，但 Godot 导入的 `StandardMaterial3D` 将 `vertex_color_use_as_albedo` 设为 `false`、`albedo_color` 设为白色；因此顶点色没有参与表面颜色。这解释了 Godot 里草地颜色丢失，不能把 Blender 预览当作最终效果。
- [ ] 视觉仍未通过：背景顶点色被忽略，画面读成浅色棚拍底；菜床仍为硬边大土盘，胡萝卜重复且偏亮，阴影生硬，边缘草簇仍被裁切。下一版应把地面颜色做成 GLB/Godot 明确支持的材质底色或在导入后启用顶点色，并调整连续地形与相机，使远近地面/地平有清楚层次；之后再按双比例实际截图验收。

#### 3.15 v4 连续地形颜色修订的 Godot 复核（2026-10-01）

- [x] 对 12:16:13 保存的源场景快照 `/private/tmp/heroes-island-toy-farm-v4-1216-source.blend` 导出 GLB；Godot 4.7.1 GL Compatibility 成功导入 124 个网格并完成双比例实渲。截图：`/private/tmp/heroes-island-toy-farm-v4-1216-godot/godot_render_16x9.png`、`godot_render_4x3.png`。
- [x] 通过临时 Godot 脚本直接检查导入场景，确认地面材质仍是白色 `albedo_color` 且 `vertex_color_use_as_albedo = false`；上轮发现的 `COLOR_0` 丢失问题在此版本仍存在。
- [ ] 视觉仍未通过：两种画幅都读成大面积浅米色的棚拍底，没有可辨地平线；四角的草/树簇继续被边界切断。大土盘、亮且重复的胡萝卜和硬阴影仍明显。下一版需先修正导出材质颜色并把环境完整收进镜头，再做同样的双比例 Godot 实渲。

#### 3.16 v4 作物与草地再修订的 Godot 复核（2026-10-01）

- [x] 对 12:22:31 场景快照 `/private/tmp/heroes-island-toy-farm-v4-1222-source.blend` 导出 GLB；Godot 4.7.1 GL Compatibility 导入 128 个网格，16:9 / 4:3 实图见 `/private/tmp/heroes-island-toy-farm-v4-1222-godot/godot_render_16x9.png`、`godot_render_4x3.png`。
- [x] 新场景减掉了旧的宽大叶片；改后菜床里的目标只剩绿色叶冠，橙色根部不再可见，已难以识别为胡萝卜。
- [ ] 视觉仍未通过：导入材质检查仍为白色 albedo 且忽略 `COLOR_0`，所以背景继续变为浅米色空底，没有自然地平；菜床目标缺少可识别的蔬菜根部，床体仍是裸露的大块土盘，裁边草簇和硬阴影也仍可见。下一版先保证根部与叶冠同框、修正 GLB 可见的草地颜色并完整收进相机画幅，再做比例和光照调整。

#### 3.17 v4 顶点色强制启用的隔离对照（2026-10-01）

- [x] 在 12:22 快照的临时 Godot 渲染副本中，只对 `Environment | continuous rolling meadow` 的材质副本打开 `vertex_color_use_as_albedo`，没有改 GLB 或项目资源；双比例截图在 `/private/tmp/heroes-island-toy-farm-v4-1222-vcol-godot/godot_render_16x9_vertexcolor.png`、`godot_render_4x3_vertexcolor.png`。
- [x] 颜色通道确实生效，浅米色变成深绿；这确认上一轮的颜色丢失诊断，也表明当前顶点色本身在该光照下过暗。
- [ ] 视觉仍未通过：强制启用后依旧是一整块没有地平的单一绿色背景，说明只打开顶点色不足以完成场景；还需提亮调色并重做地形/天空的相机覆盖和过渡。此对照仅用于查因，不能记为正式修复或验收通过。

#### 3.18 v4 根部回归与地面材质复核（2026-10-01）

- [x] 对 12:29:15 保存的快照 `/private/tmp/heroes-island-toy-farm-v4-1229-source.blend` 导出 GLB；Godot 4.7.1 GL Compatibility 成功导入 165 个网格，完成 16:9、4:3 实渲：`/private/tmp/heroes-island-toy-farm-v4-1229-godot/godot_render_16x9.png`、`godot_render_4x3.png`。
- [x] 菜床中的橙色根部重新可见，恢复了叶冠与根部同株的结构。
- [ ] 视觉仍未通过：根部在 Godot 实图中成为圆钝土包，轮廓不足以让儿童辨认为胡萝卜；Blender 源几何复核显示根部顶端约在 `z=0.457–0.495m`，土面约在 `z=0.297m`，仅约 18% 的根部高度露出，因此可见部分像圆包。导入的地面材质仍是白 albedo、`vertex_color_use_as_albedo=false`，所以背景继续为浅米色且无地平；菜床仍像大块硬边土盘，边缘草簇被裁切、阴影偏硬。下一版需增加能识别的锥形根部露土比例、让草地材质颜色真正进 Godot，并把环境摆进双比例画幅。

建议生成词（供 3D 模型生成器使用）：

> 生成一份可用于儿童农场游戏的原创 3D 玩具农场垂直切片，交付可编辑几何和材质的 `.glb` / `.gltf`，不是一张渲染图。固定 3/4 俯视构图，圆润、精致、可触摸的哑光黏土/玩具塑料质感，明亮但不过饱和，主光来自左上，阴影短而柔和。画面只包含一块完整的小菜垄、一种成熟蔬菜植株（优先番茄或胡萝卜）、自然包住泥土边缘的草皮和一只开口清晰的小藤编收获篮；菜叶扎根于土中，篮子稳稳接地，各对象比例协调、互相有遮挡关系，整体像同一套桌面玩具模型。菜垄应是有真实侧壁与草缘起伏的长方形/圆角长方形，不要平圆盘；篮子要看得见篮口和内部，不要细线笼子。使用干净、有限的暖绿、叶绿、泥土棕、藤编浅金色块，低多边形但轮廓饱满，避免写实、照片纹理、粗黑描边、强镜面高光和夸张阴影。请尽可能把菜垄、植株、草缘、篮子导出为独立且有名称的节点，底部接地点靠近各自原点；模型以米为单位，整体宽约 3 米。不要天空、地面大平面、远山、围栏、人物、动物、UI、文字、Logo、水印、边框、相机后期或烘焙背景。另附一张同镜头预览图供审美评审；预览图不替代模型文件。

如果使用的工具只能生成 2D 图片，这个提示词不适用：不要再生成一张整屏草地背景；应把生成图视为造型参考，等拿到真实模型文件后再进入 Godot 试片。

#### 3.19 同源菜畦候选 v6 复核（2026-10-01）

- [x] 对隔离候选 `3d1da80d477bda4fc4b94a4a16ad65c31f4ae5ef9b4fa1182abc38e056b14397` 做 Godot 实渲复核；同哈希副本位于 `/private/tmp/heroes-island-toy-farm-v4/harvest_same_source.glb` 与 `/private/tmp/heroes-island-toy-farm-v6-godot/harvest_same_source.glb`。审核图为 `/private/tmp/heroes-island-toy-farm-v6-godot/godot_render_16x9_final.png`、`godot_render_4x3_final.png`。
- [x] 远丘轮廓与较浅、收小后的土床比上一版清楚；仍有大面积均匀绿地、偏厚的托盘式土床边缘、重复且偏圆的胡萝卜轮廓，4:3 右侧留白也偏紧。结论：保留在隔离试片，不接产品页。

#### 3.20 同源菜畦候选 v7 复核（2026-10-01）

- [x] 对隔离候选 `cb0950fed2696e8180ac22913a1bce72be4e297afed2ee943eaa1ec69fe1c971` 做 Godot 双比例实渲；审核 harness 显式覆写连续草地材质并启用顶点色，截图为 `/private/tmp/heroes-island-toy-farm-v7-godot/godot_render_16x9.png`、`godot_render_4x3.png`。
- [x] 新增的浅色弧形丘陵占据画面顶部约四分之一；4:3 天空被挤成一条边缘。绿地仍单色，土床仍有厚托盘感，胡萝卜轮廓重复。结论：此版仍留在隔离试片，丘陵比 v6 更抢主体，不接产品页。
- [x] 对相同 GLB 做了只改审核 harness 的隐藏丘体 A/B（`/private/tmp/heroes-island-toy-farm-v8-nohills/`，哈希未变；截图为 `godot_render_16x9.png`、`godot_render_4x3.png`）。天空恢复但地平线成为笔直硬线，绿地仍缺少层次；这是构图诊断，不是新的源资产版本或接入验收。
- [ ] 下一版缩低丘线、保留足够天空和地平线，增加克制的地面色阶，优先解决草缘接地及作物轮廓差异；完成后使用新哈希重跑 Godot 双比例审核。

#### 3.21 同源菜畦候选 v9 的 Godot 双比例复核（2026-10-01）

- [x] 对源文件 `/private/tmp/heroes-island-toy-farm-v9/harvest_same_source.glb`（SHA-256 `e1f2d7824695cc78a17287359cd8fb3d5e1851e7f9eaf44edcc2dae43982f288`）在 Godot Compatibility 副本完成实渲；显式启用顶点色的图为 `/private/tmp/heroes-island-toy-farm-v10-godot/godot_render_16x9.png`、`godot_render_4x3.png`。
- [x] 16:9 画幅隐藏了大丘体，但根部埋得过深；4:3 的天空和外沿留白较 v7 改善，仍有主导上半部的大弧丘，根部也更外露、像圆包。两台画幅专用相机没有给出一致的构图。菜床厚边和单色草地仍在，候选不接入产品页。
- [x] v10 的审核 harness 对 `continuous rolling meadow` 显式设置 `vertex_color_use_as_albedo = true`；随后 v11 移除材质覆写，真实默认导入图 `/private/tmp/heroes-island-toy-farm-v11-default-godot/godot_render_16x9_default.png`（SHA-256 `b50200e36466d06fc2d1089247f49a52b7815e6e6aee69b097073013568248c6`）、`godot_render_4x3_default.png`（SHA-256 `7cb56c47eaa7bab6ab3bd39f550677067ff6d3200c7e45ab1246053450c572e0`）又变成大面积米白地面，确认 GLB 默认材质仍未使用地面顶点色。
- [ ] 统一两种宽高比下的地平与根部露出，改善草缘接地和地面层次，并单独复核默认材质；之后再用新哈希做双比例 Godot 渲染。

#### 3.22 同源菜畦候选 v12 的默认材质 Godot 复核（2026-10-01）

- [x] 源文件 `/private/tmp/heroes-island-toy-farm-v12/harvest_same_source.glb`（SHA-256 `26c7a780518238fc579e094a66e5da45fae8b8764cff3f2e07b246786248e1d1`）由我复制到干净的 Godot 4.7.1 Compatibility 副本；源与副本哈希完全一致。该版本为草地导出嵌入式 PNG `baseColorTexture`，不依赖 `COLOR_0` 或审核时材质覆写。
- [x] 默认材质双比例实渲成功：16:9 `/private/tmp/heroes-island-toy-farm-v12-26c7-default-verify/godot_16x9_no_override.png`（SHA-256 `93dda9c86ff1079fa3801189d9c83035fed3cbfb281574c9191614cb0f7ef17f`），4:3 `/private/tmp/heroes-island-toy-farm-v12-26c7-default-verify/godot_4x3_no_override.png`（SHA-256 `e9e949dceabe35a8afab43fc6bf7c2cf1fbf6f9795f631089cbd729fab7e453b`）。Godot 日志分别确认选中 `Harvest Camera 16x9` 与 `Harvest Camera 4x3`。
- [x] v12 修复了 v11 默认材质下地面发白的问题，双比例都正确呈现绿色地面；菜畦边缘较前版低，但整体仍偏厚且像孤立土盘。两画幅仍以均匀绿地和硬直地平线占据大部分画面，篮子离菜畦较远、关系较弱。结论：材质技术门槛通过，整体构图仍不接产品页。
- [x] 发现 `/private/tmp/heroes-island-toy-farm-v12-no-override-audit/` 当时仍装载 v11 哈希 `e1f2d7824695cc78a17287359cd8fb3d5e1851e7f9eaf44edcc2dae43982f288`，其 `*_default.png` 截图早于 v12 导出，不能作为 v12 的验证结果；本节仅记录哈希匹配的干净副本截图。
- [ ] 下一版优先缩减无内容的绿地与硬直地平线，给草地加入克制的远近层次，继续削薄菜畦侧缘并强化菜畦、作物与篮子的空间联系；有新源哈希后再以默认材质重跑双比例 Godot 实渲。

#### 3.23 同源菜畦候选 v13 的默认材质 Godot 复核（2026-10-01）

- [x] 源 GLB `/private/tmp/heroes-island-toy-farm-v13/harvest_same_source.glb`（SHA-256 `29412f6c300a054efb9c6a861b780d29298b9520dc46500b90dbc2863b5a027f`）复制到干净 Godot 4.7.1 Compatibility 副本，源与副本哈希一致；16:9、4:3 均用 GLB 内对应相机及默认材质完成实渲。
- [x] 截图：16:9 `/private/tmp/heroes-island-toy-farm-v13-29412-default-verify/godot_16x9_no_override.png`（SHA-256 `af89d5b48709c8b15d48e45ac0b5368ed4a4762d701ab2937a9d00a5acd1c2b2`）；4:3 `/private/tmp/heroes-island-toy-farm-v13-29412-default-verify/godot_4x3_no_override.png`（SHA-256 `9e99475a69b7b092823cbbad5fb0ec5d9553cbad8e5870707bdbd0c10857ffaf`）。默认材质仍能呈现绿色地面。
- [x] v13 复用了草缘土块，但 Godot 图中草缘变成宽而亮的厚托盘边；脚本新增的低丘没有形成可见天际轮廓，两种画幅仍看到硬直地平和大块均匀绿地。菜株只有叶冠，胡萝卜根完全埋住；篮子继续与菜床脱节。结论：本版不接产品页。
- [ ] 下一版收窄并压低草缘，明确让远丘进入两种画幅的剪影区域，给每株增加少量可辨的锥形胡萝卜根露土，并让篮子与菜床产生更强的空间联系；之后仍按默认材质重新做双比例 Godot 实渲。

#### 3.24 同源菜畦候选 v14 的默认材质 Godot 复核（2026-10-01）

- [x] 源 GLB `/private/tmp/heroes-island-toy-farm-v14/harvest_same_source.glb`（SHA-256 `d0c10be7728864d62a0f4c7f70253808df3b43ff2ed22c467db137c78e7b5540`）导入干净 Godot 4.7.1 Compatibility 副本，源与副本哈希一致；两种比例均使用默认材质实渲。
- [x] 截图：16:9 `/private/tmp/heroes-island-toy-farm-v14-d0c10-default-verify/godot_16x9_no_override.png`（SHA-256 `8183ded01238bfa5a3b949b0d30322f065bfd7e8e91387d3456d97c27577afbe`）；4:3 `/private/tmp/heroes-island-toy-farm-v14-d0c10-default-verify/godot_4x3_no_override.png`（SHA-256 `e765a0d28fdd259607eff5910295031916f3fb7f6acc3af08c74bb9a1f1fb64a`）。默认地面材质保持绿色。
- [x] v14 去掉了 v13 宽亮的绿色草环，画面更克制；但土床侧壁仍偏厚，散置草叶在边缘像漂浮贴片；菜株只有叶冠，没有可辨胡萝卜根。两画幅的远地平仅轻微起伏，大面积绿地仍空，篮子和菜床关系偏弱。结论：本版不接产品页。
- [ ] 若继续做独立场景，先把床缘植被确实扎进床土、把床体降到接近地面，并露出一段带锥度的胡萝卜根；完成后以默认材质做新的双比例实渲。正式页面仍以已复核的水粉草地背景和独立 2.5D 目标/篮子为当前方案。

#### 3.25 同源菜畦候选 v15 的默认材质 Godot 复核（2026-10-01）

- [x] 源 GLB `/private/tmp/heroes-island-toy-farm-v15/harvest_same_source.glb`（SHA-256 `ff5b6877775a346c290577b15faaef5dae0b70fa3f13d880b74cb16c89bca7d0`）导入干净 Godot 4.7.1 Compatibility 副本；源与副本哈希一致，双比例使用默认材质实渲。
- [x] 截图：16:9 `/private/tmp/heroes-island-toy-farm-v15-ff5b-default-verify/godot_16x9_no_override.png`（SHA-256 `3a2c97caedd240496cf56086714c4c833e4d4c575b4b8b9700ae766b5c7b65d6`）；4:3 `/private/tmp/heroes-island-toy-farm-v15-ff5b-default-verify/godot_4x3_no_override.png`（SHA-256 `0b9f67bef6bb1e9b49696613c4daddb3afa6f47e59f8d2c8546d1ed737511e09`）。默认地面材质正常。
- [x] v15 将菜株根与叶冠重新连接，并把篮子移近菜畦，主体比 v14 更集中；但两种比例中的根只露出宽肩，尖身仍埋住，三株读成橙色圆包；床外沿仍形成一圈绿垫。结论：不接产品页。
- [ ] 下一版先统一 16:9 / 4:3 的安全构图，并压低床缘绿垫；v16 预览中的根部识别已有改善，仍待默认材质 Godot 双比例实渲确认。

#### 3.26 同源菜畦候选 v16 初步检查（2026-10-01，待相机修订）

- [ ] 源 GLB `/private/tmp/heroes-island-toy-farm-v16/harvest_same_source.glb`（SHA-256 `8a904537ef9cbce2d878a7bd2cb93fd038226cc796355d9ff4a9fb22d07437e4`）及 Blender 预览 `/private/tmp/heroes-island-toy-farm-v16/harvest_same_source_16x9.png`、`harvest_same_source_4x3.png` 已落盘；目前只作预览检查，尚未完成 Godot 默认导入实渲。
- [ ] 两种预览都能看到根与叶冠相连，胡萝卜辨识比 v15 有改善，篮子也靠近菜床；绿色草缘仍像独立垫片。资产会话复核了比例差异：16:9 裁掉天际线，4:3 保留天际线但主体偏小，当前相机版本不通过。
- [ ] 生成脚本已把三个植株的 `root_sink` 调到 `0.40–0.48`，但装配段仍调用放大后的 `soil_grass_patch`；文件中已有的 `continuous_bed()` 与 `reuse_grass_tuft_border()` 没有接入装配，因此草垫轮廓问题仍在。需要结合源根模型的实际形状继续调整，而非只移动根部。
- [ ] 当前共享机仍有另一个 Godot `FarmShot` 实例运行（PID 73674）；按串行要求暂缓独立审核进程。待该实例退出后复制并核对同哈希 GLB，以 Godot Compatibility 默认材质完成 16:9 / 4:3 实渲，再更新验收结论；此候选尚未通过，也不接入产品页。

#### 3.27 同源菜畦候选 v17 的 Blender 预览初审（2026-10-01）

- [x] 当前快照 GLB `/private/tmp/heroes-island-toy-farm-v17/harvest_same_source.glb` SHA-256 为 `6113a092fa50d5e6e5e9b378a2f8992725992407cca7fe562ba4272e8604b6a6`；16:9 预览 `/private/tmp/heroes-island-toy-farm-v17/harvest_same_source_16x9.png` SHA-256 `e311edbc9b771e71dc459645633dd73e0b7a92a2c44a77b2e9c12fe36e80fe94`，4:3 预览 `/private/tmp/heroes-island-toy-farm-v17/harvest_same_source_4x3.png` SHA-256 `f95996fe72088380f6b511068f6da471995f04efb5cc8d3c12cfc571d89df5c9`。生成脚本语法检查通过。
- [x] 两张 Blender 预览中，菜株与叶冠相连，篮子也靠近主体；但菜床依然读成孤立的宽大土垫，16:9 的土床下缘和主体被画幅裁切，4:3 中上半部留有大面积空天。露出的胡萝卜根仍是宽短圆包，未形成清楚的尖锥轮廓；土面上的散点像石子。
- [x] 同哈希 GLB 的只读 glTF 审计：53 个 mesh、12 个材质、2 个正交相机和 1 张嵌入式地面纹理。地面变化色位于 `COLOR_1`，`COLOR_0` 全白；默认材质名为 soft contact shadow 的阴影却导出为不透明黑色因子。名为 `Harvest Camera 16x9` 的节点引用的相机定义比例实际为 4:3；4:3 投影下左侧草簇略微越界。这些是 Godot 默认导入的待核项，不是已确认的 Godot 渲染结果。
- [ ] 当前截图仅为 Blender 预览，不代表 Godot 默认材质和导入结果；v17 不接入产品页。下一轮先让地面/菜床的空间连续关系与两种画幅取景成立，再修根形和散点。Godot 实渲仍按串行流程等待现有 `FarmShot` 实例退出。

#### 3.28 用户参考图对照与番茄资产检查（2026-10-01）

- [x] 用户提供的主要 3D 参考是丰盛的番茄藤、支撑木桩、多个红果、厚实自然的草缘土床和有编织体积的篮子；不是空旷远景或裸露的简化土块。关键输入图仍在原会话附件路径 `/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/codex-clipboard-52f8a64e-1f65-4e00-8242-b73a71a4e5ce.png` 与 `/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/codex-clipboard-3e7ee3d0-953f-4229-8758-f13a739bdb0d.png`。
- [x] 源脚本 `assets/harvest_3d/source/build_pack.py` 中的 `make_tomato()` 只生成单果、萼片与短梗；`make_soil_grass_patch()` 是椭圆土盘、薄草唇、8 根短草和 4 个土块。它们能复用材质与局部部件，不能单独代表参考图中的整株番茄或丰盛菜垄。
- [ ] 下一份透明模块试片要展示真实的完整番茄枝叶/支撑关系、成熟果实、成型草缘土垄和开口编织篮，并采用可拆分的 3D 节点。先以用户参考图对照两种画幅，再导入 Godot Compatibility 默认材质。
- [ ] 透明套件预览只是中间门槛。完整目标仍要求把通过的 3D 视觉接入实际收菜页面，并用现有 `HarvestTarget` / `HarvestBasket` 状态和命中锚点驱动；完成证据必须包括实际页面 16:9、4:3、拿起/分拣状态截图和鼠标、触摸路径回归，不能以 Blender 预览或一张静态导出图代替。

#### 3.29 模块番茄菜床候选 v18 预览（2026-10-01）

- [x] 同一资产快照 GLB `/private/tmp/heroes-island-toy-farm-v18/modular_tomato_kit.glb` SHA-256 `e07fbf012afcc6e8b8337dde07942868c6bd9125e8ea2b8771c8df875d9eeb30`；16:9 Blender 图 `/private/tmp/heroes-island-toy-farm-v18/modular_tomato_kit_16x9.png` SHA-256 `a6e8d527d9e1424bcaa83150d59ba48a7abeeecb043cb4472757276b3eb714ce`，4:3 图 `/private/tmp/heroes-island-toy-farm-v18/modular_tomato_kit_4x3.png` SHA-256 `62fe70cc2e8bc66c06906d77b9cf87c145a63e14b24ca87be6184a322a6b8e27`。
- [x] 相较 v17，v18 使用了完整 Quaternius Tomato_4 网格，菜株不再是胡萝卜圆包；篮口与提手保持可读。但藤果比篮中同源番茄明显暗，三株枝叶仍稀疏且枝干偏直，菜床仍像大椭圆绿盘与平浅土心，构图里主体比例偏小、空白过多。结论：仍不接产品页，且尚未做 Godot 默认导入实渲。
- [x] v20 已统一藤果红色材质、把厚椭圆绿盘改成自然叶簇草缘并修正篮子 safe framing；叶枝层次仍需后续调整，Godot Compatibility 默认材质验证尚未完成。

#### 3.30 番茄菜床候选 v19 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-v19/tomato_bed_kit.glb` SHA-256 `e2e674d65730ba3bb362f9dcc0d8ee283822647ca1d65af4a54d089b2df41d75`；16:9 预览 `/private/tmp/heroes-island-toy-farm-v19/tomato_bed_16x9.png` SHA-256 `5a4fa6668a5781b2e5a36d3457b9cfa0246ecbdc287e295ba42f97861ccb58c2`，4:3 预览 `/private/tmp/heroes-island-toy-farm-v19/tomato_bed_4x3.png` SHA-256 `b8dec0297b568edd58df1dcefd3c9d40b1148774ce6ffb6be957d3eefb1143a7`。
- [x] 自定义矩形土床、材质调亮和支撑边已改善 v18 的椭圆外形；但用户参考没有显著木框，v19 的高木轨与角柱把画面变成花箱。篮子底部在 16:9、4:3 都被裁，4:3 床两端也被裁切；番茄藤仍显稀疏，土面散点像小石子。
- [x] GLB 审计确认 v19 的藤果仍有红暗问题：只将材质 `Red` 调亮，OBJ 重复导入的 `Red.001`、`Red.002` 保留深棕色因子；所以仅左株果实变亮，中/右株仍暗。结论：v19 不接产品页，也未完成 Godot 默认导入验证。
- [x] v20 已修复重复材质、双画幅裁切和主导画面的木框。仍需以用户原图对比丰盛枝叶、果实可读性与篮子接地，并通过 Godot Compatibility 默认导入检查。

#### 3.31 番茄菜床候选 v20 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-v20/tomato_bed_kit.glb` SHA-256 `1d88eb19c13100319daf289d287e4f541d6ade057e5e6fb663bebb8d1a83cbef`；16:9 预览 `/private/tmp/heroes-island-toy-farm-v20/tomato_bed_16x9.png` SHA-256 `35b8d34b599bf8d2000a1753652134b3eb34c752951d26c918f13e4b64714718`，4:3 预览 `/private/tmp/heroes-island-toy-farm-v20/tomato_bed_4x3.png` SHA-256 `b9c6fc4e55ddda9a6d3b89ce86661e9601113cb81af972b05321b14ebe141f60`。
- [x] 双画幅中篮子与菜床都完整入镜；藤果材质已统一为亮红色；圆顶土面和自然叶簇草缘取代 v19 主导画面的高木框，方向明显改善。
- [x] 造型仍需细化：三株枝叶连成高度接近的水平藤架，果实排布过于整齐。GLB 结构审计为 443 个节点、305 个 mesh 资源、306 个 primitive、16 种材质，无贴图/相机；443 个节点全部平铺，没有任何父子层级。过多独立叶片、枝段与果实会增加重复实例的运行开销，也不便按株组织可采目标。
- [x] v21 已打散部分藤蔓/果簇，并把枝叶草缘合并成少量静态网格，同时保留每颗可采果实的独立稳定节点和每株根节点；下一轮继续修正叶片、主茎和床侧造型。

#### 3.32 番茄菜床候选 v21 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-v21/tomato_bed_kit.glb` SHA-256 `3ec1f2c756d16802e9f9d77f3b843908899be65eef8c0de8e16969eb7848c8e6`；16:9 预览 `/private/tmp/heroes-island-toy-farm-v21/tomato_bed_16x9.png` SHA-256 `7e3902b4789b57c7bd4f66b6e094626192391fe6c283c4fbb3a519b1ef03da56`，4:3 预览 `/private/tmp/heroes-island-toy-farm-v21/tomato_bed_4x3.png` SHA-256 `21d7e8d28ba51ace4f5137f1cacc336cca4d8518af5937b6a2d27d7b4c94cdc6`。
- [x] 两个画幅的菜床、植株与篮子均完整入镜。GLB 从 v20 的 305 meshes / 306 primitives 降至 7 meshes / 25 primitives；保留床、篮和三株根节点，三株各有 4 个独立命名的 `HarvestTarget` 番茄节点并共用一个果实 mesh，便于后续逐果映射。
- [x] 造型尚未通过：叶片仍大而重复，主茎偏粗直，菜床侧壁仍像硬边托盘。GLB 为 24 nodes、14 种 PBR 材质、0 贴图、0 相机，文件约 3.47 MB；静态网格合并改善 draw-call 规模，但还需控制源几何与资源尺寸。
- [x] v22 已进一步打散叶簇与果实位置、保留 12 个独立可采节点和低 primitive 数；造型与预览材质仍需校准，详见 §3.33。Godot Compatibility 默认材质实渲及收菜页状态/触控映射仍未完成。

#### 3.33 番茄菜床候选 v22 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-v22/tomato_bed_kit.glb` SHA-256 `140146e4e23f16cbe309d9eeaa4b8d5e82f69fa4cd341716bbc7d8b658bd5eba`；16:9 预览 `/private/tmp/heroes-island-toy-farm-v22/tomato_bed_16x9.png` SHA-256 `0b40b52b021bf7542dc88834fd3ffe6e920d275b4e6b8e9d274988c64f271d9a`，4:3 预览 `/private/tmp/heroes-island-toy-farm-v22/tomato_bed_4x3.png` SHA-256 `98b40f360239b4132077f275cfb60489340260069d0949f403ad71425e6b1841`。菜床和篮子均完整入镜。
- [x] GLB 保留 v21 结构：24 nodes、6 meshes、23 primitives、15 种材质；12 个带 mesh 且有父节点的 `HarvestTarget`，0 贴图、0 相机。几何为 126,891 vertices / 223,441 triangles / 5,642,040 bytes；相较 v21 的 84,135 / 144,532 / 3,465,932 增长约一半，后续需纳入平板性能预算。其中编织篮网格占 99,600 triangles / 54,805 vertices（约占总 tris 45%），菜床占 58,734，三株各约 21,548；降低篮子曲线 bevel/resolution 可在保住交互与植株轮廓时优先减面。
- [x] 番茄 GLB BaseColor 与 v21 相同 `[0.83, 0.075, 0.035, 1]`，但 roughness 从 `0.72` 降至 `0.46`。Blender 预览呈粉白，生成脚本还把既有 area lights 设为 `850`、追加 `520/260` 两盏 area light、World strength `0.48`；因此粉白更可能由补光/高光造成，而非 GLB 红色底因子变化。此判断仍需后续 Godot 默认材质实渲验证。
- [x] 视觉仍未通过：番茄叶片较大且重复、主茎偏直、支架可见；土面密集浅色小圆点像石子，床侧仍有托盘感。v22 只是 Blender 候选，不接产品页，也没有 Godot Compatibility 默认导入或实际页面截图。
- [ ] 下一版先把审图灯光与 roughness 调回哑光基线，减少土面麻点、细化叶簇和枝干、继续弱化床侧；保留 12 个目标节点与分组，并控制几何增长。随后按 GLB 哈希完成 Godot 默认材质验证和现有收菜交互映射。

#### 3.34 并行低模番茄床候选（2026-10-01）

- [x] 在独立临时目录 `/private/tmp/heroes-island-toy-farm-parallel-glb-20261001/` 生成可编辑 Blender 源、GLB 与 16:9 / 4:3 预览；GLB SHA-256 `ed185b13f8ce8d4bca8200bc3ca2256572f2227c88f478d0112bf35d11ec61ed`。该候选与主线 v23 并行，只供比较，不覆盖资产任务的脚本或输出。
- [x] 结构预算达到规格：41,852 triangles、12 个静态 material primitives、9 种纯色 PBR 材质；`Root` 下含 `GardenBed`、`Basket`、`Plant01`–`Plant03`。12 个独立 `HarvestTarget Tomato P01/P02/P03 F01–F04` 各 357 triangles，pivot 在果实中心；无 camera、texture/image 或地面平面。
- [ ] Blender 预览显示草缘和篮筐编织已成形、两种画幅主体完整；叶片仍显统一，土面中央留白较多，视觉 gate 未通过。尚未导入 Godot、连接现有交互或接入正式页面；等待 v23 预览后并排比较，再决定是否保留可复用造型。

#### 3.35 v23 / v24 与并行低模候选对照（2026-10-01）

- [x] v23 GLB `/private/tmp/heroes-island-toy-farm-v23/tomato_bed_kit.glb` SHA-256 `0a8adc36aef7ae268201be228d06e8aaa1d862f43d7ab8dc4056e3d1625e6476`，95,007 tris；v24 GLB `/private/tmp/heroes-island-toy-farm-v24/tomato_bed_kit.glb` SHA-256 `8966551edae78460d499fc0f47783bf6a9bef036234a0a8d701e591f0c5699d0`，124,765 tris（比 v23 增长 31%）。二者均为 24 nodes / 6 meshes / 22 primitives / 14 材质 / 12 个独立可采目标，0 贴图与 0 相机；每颗目标果 407 tris。
- [x] v24 双画幅完整，果实颜色清楚，叶簇比 v23 更密；但植株仍排成连续一线，叶片宽尖且重复，遮挡部分果实。土床平而硬，外缘仍有深色接缝和托盘感，篮子以重复横带为主。
- [x] v24 分项面数：篮筐 19,944 tris、床体 21,950、每株 27,488、目标果 407。体量比 60k 目标高一倍以上，不能以结构节点达标代替性能预算。
- [x] 与 v23 相比，独立低模候选（§3.34）有更柔和的圆顶床、厚编织篮和错落枝果；它的 41,852 tris 与 12 个静态 material primitives 达到对应数量约束。但其中央土面留白、叶缘碎尖，同样没有通过视觉 gate。两份都还是 Blender 候选，没有 Godot 导入或交互验收。
- [ ] 下一版优先修补床体接缝、弱化托盘轮廓、放开果实周围遮挡，并把静态三角面压回预算；通过实际双画幅审看后再确定采用哪份枝叶/篮体造型。已有 Godot 实例仍在执行长时间 QA，暂未启动第二实例。

#### 3.36 番茄菜床候选 v25 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-v25/tomato_bed_kit.glb` SHA-256 `f65e2ac55597ac482d21af3e07204a93015a02d34f70b60101d08b6bfe0b171b`；24 nodes、6 meshes、74 primitives、14 材质、12 个唯一目标果，各 407 tris，无贴图/相机。16:9 与 4:3 主体均完整入镜。
- [x] v25 总量 136,296 tris，比 v24 的 124,765 再增加约 9%；不含 12 个 HarvestTarget 节点，静态部分仍有 26 个 material primitives。篮筐主网格在 v23–v25 都维持 19,944 tris；每株从 v24 的 27,488 增至 29,568，床体 21,950。当前篮子横带不是主要减面来源，枝叶静态网格优先优化。
- [x] 视觉上植株虽更密，但叶簇堆成连续厚墙，遮住果实；土面仍读成平盘，深色床缘还在，篮带重复感未解决。该版没有通过造型 gate 或 60k 面数预算，也未导入 Godot。
- [ ] 下一轮停止增加叶片数量；以共享低面数叶簇压低静态网格，同时为果实留出视窗、用连续浅起伏弱化土面平盘感，并修复床体接缝。通过结构与两种画幅门槛后再考虑 Godot 导入；在现有长时间 QA 进程结束前不启动另一实例。

#### 3.37 并行圆叶低模候选 v26 复核（2026-10-01）

- [x] 整合任务生成 `/private/tmp/heroes-island-toy-farm-parallel-v26/tomato_harvest_editable.glb`，SHA-256 `2eeb347401ce805300d06d9c7502751f2dc4cb8ce5d5c200a68032bca3bff110`；16:9 预览 SHA `0d207fc462d6b696b30fb1388da11c7f0bc05003a1ed1e11d03b2fb061c74134`，4:3 预览 SHA `94b6723d1a8fc8e4ea796e75727b66900e3095bb70776cc9b088fa7bf7a9bee0`。两比例主体完整。
- [x] 结构预算：38,828 tris、12 个静态 material primitives、9 种材质；Root 下为 GardenBed / Basket / Plant01–03，12 个唯一 `HarvestTarget Tomato P01/P02/P03 F01–F04` 各 357 tris，无贴图/相机。相较首个并行候选 41,852 tris，圆叶改形后又减少约 7%。
- [x] 圆润低面叶形已弱化此前宽尖、碎叶的刺状感；土床与编织篮的接触比 v23–v25 柔和。视觉仍未通过最终 gate：前景土面偏空，中心与右侧有果实被叶片遮挡，床侧仍有浅托盘感。这是目前最符合性能结构预算的完整植株候选，尚未 Godot 导入或互动验收。
- [ ] 下一步保持圆叶和预算，打散果簇遮挡、适度填实前景土床，并弱化床侧；现存 Godot 长时间 QA 进程结束后，再优先对本候选做隔离导入与现有 HarvestTarget / Basket 映射。

#### 3.38 并行圆叶低模候选 v27 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-parallel-v27/tomato_harvest_editable.glb` SHA-256 `b01539344515db6c8e41a15bb768942d5a99d613c4cba29461bfcaeb62483ee3`；16:9 SHA `cb4d99db449ae4832cdfc6291b432e280376e6255ae3106b49cb688198870fef`，4:3 SHA `bff2366e89180270a924c4fbb2ab05e2e64b71e587901e92dafbc3357afe420f`。两个画幅主体完整。
- [x] GLB 为 35,544 tris / 12 静态 material primitives / 9 材质；12 个唯一 `HarvestTarget Tomato P01/P02/P03 F01–F04` 各 357 tris，0 贴图/相机。相比 parallel-v26（38,828 tris）继续减面约 8%。
- [x] v27 圆叶间距和果实可读性优于 v26；仍有前景土面留白、缺少浅起伏、叶缘锯齿弱等问题。尚未导入 Godot；缩到页面实际尺寸时必须再看单果像素大小，并确认多个近邻目标的触控范围不会重叠。
- [ ] 保持 v27 的静态预算，先微调床面和目标间距，再以双画幅与小尺寸截图决定是否进入隔离 Godot 导入映射。现有长时间 QA 进程释放前不并行启动 Godot。

#### 3.39 主线番茄菜床候选 v26 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-v26/tomato_bed_kit.glb` SHA-256 `6542f54bd151454477265b24dac341ddf5e548d27e3e4ee12ba5720fd9e2d15a`；16:9 SHA `c8f89e783f41e30dedbe74bded42af642b80614d391d93370051dd89d735f32b`，4:3 SHA `2e4f6905a3b0a7952af96db0f1f71e2288b90d4fa1810efe50ec22dfe7f5210a`。两个比例都完整入镜；12 个独立目标果各 401 tris。
- [x] 几何为 50,316 tris，达到 ≤60k；但仍有 14 材质和 74 总 primitives。排除 HarvestTarget 后仍有 26 个静态 primitives（篮内两颗装饰果亦计入），未达到 ≤12 材质和 <15 静态 primitives。
- [x] 前移果实后可读性比 v25 好，菜床连续、接缝少；主要阻断是土壤在预览里呈浅灰白。GLB 的 `Garden soil | deep cocoa` 未导出 `baseColorFactor`，床面含 `COLOR_0` 且 RGB 均值约 0.675，解释了土色丢失；v25 曾正确导出深棕 `[0.20, 0.095, 0.036]`。该材质错误未修复前不通过视觉 gate。
- [x] v28 已恢复暖棕床土顶点色，把模型压到 35,544 tris / 12 静态 primitives / 9 材质；导出色均值与 Blender 预览一致，详见 §3.41。后续还需补土面纹理并复核遮果，Godot 验证仍待现存长时间 QA 进程结束。

#### 3.40 并行圆叶低模候选 v28 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-parallel-v28/tomato_harvest_editable.glb` SHA-256 `12f80a1104c91bc97b4e0776f7696682270ba8e2dcf88e05ac12cb1b100666d3`；16:9 SHA `80f7056f76aee693ab88f4578ecb2fcc2a08ca9576cd0c79f622d6eddc576fe4`，4:3 SHA `af28929a0117a7caa9d54e6e42971b7ac5b2d497f673e01583717c7d64cd6099`。两比例均完整入镜。
- [x] 结构为 39,590 tris / 12 个静态 material primitives / 9 材质，12 个唯一 HarvestTarget 各 357 tris，无贴图/相机；床 10,944 tris、单株 2,776–3,352、篮 15,218。低于 60k 总面数预算。
- [x] v28 加厚了外围草缘与植株根部，保留 v27 较清晰的果实窗口；当前是预算内更适合进入隔离导入评估的候选。视觉仍有大片平土面，个别叶片挡住果实，尚未通过最终美术 gate。
- [ ] 保持该结构规模，补少量连续土面起伏并只调整遮挡果实的几片叶；随后以实际页面尺寸审查单果屏幕像素和近邻目标触控范围。现存 Godot 实例释放前不启动新实例，且本候选尚未导入或映射现有交互。


#### 3.41 主线番茄菜床候选 v28 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-v28/tomato_harvest_editable.glb` SHA-256 `524b619de3a4747abe9e03918b7c9aaa87e7538e04624101b6cdfba999c0140d`；16:9 SHA `2883c9fceaf3c7fcf847686c2f02f2ba04838b72ed7e6ad4e49547189eb9812e`，4:3 SHA `94f829d800eb4faa007437888e3311500f2caeef0be0ad90f48736685225eebb`。两个比例完整入镜。
- [x] 已恢复暖土色：虽未写 `baseColorFactor`，但 GLB 床面 `COLOR_0` RGB 均值约 `(0.285, 0.142, 0.065)`，预览呈暖棕，不再是 v26 的灰白。结构为 35,544 tris / 12 静态 material primitives / 9 材质 / 12 个 357-tri harvest targets，无贴图/相机。
- [x] 相较 v26 有明显预算改善，主要果实仍可辨；前景土面纹理仍过平，部分叶片压住果实，尚未通过最终美术 gate。后续主线正在为床面加低对比细节。
- [ ] 保持该预算与暖土色，接纳低对比连续地表起伏并只微调遮挡叶片；再按小尺寸检查可点目标，之后才进入隔离 Godot 导入。

#### 3.42 并行低模候选 v29 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-parallel-v29/tomato_harvest_editable.glb` SHA-256 `ed8dbe8ae9d5774f309ef6cab191e47395dff5ef8bc13236a895ee31cd7e98ad`；16:9 SHA `ad341a6b4b80d1d18fadb3ddb64b54c2483b2f156bb4e5b134292d20e7341b61`，4:3 SHA `33162caa9ed7d7d268af31ff7dd5bd3181c9c24795baecde266b4c834a3f97c7`。
- [x] 35,078 tris / 12 静态 primitives / 9 材质 / 12 个 357-tri targets，无贴图/相机；双比例完整，果实窗口比 parallel-v28 更清楚。
- [x] 叶片布局较稀疏、枝干感更直，前景土仍大片空白。未 Godot 导入，当前作为开窗/减面参考，不作已通过资产。

#### 3.43 主线番茄菜床候选 v30 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-v30/tomato_harvest_editable.glb` SHA-256 `bf76a04744b876511c69d8017921d76a9d82e1d99ce3acd8ac36a0638c23a5fc`；16:9 SHA `fb831d698037bf4b75deede922d97fb37710550805321bb4a9d7588d7c5487ac`，4:3 SHA `4eb4ac6568b61d5aaca2822735658dc842bf17469f8428944ffbc151148504ef`。35,544 tris / 12 静态 primitives / 9 材质 / 12 个 357-tri targets。
- [x] v30 把 v29 的规则菱格纹理压掉，两比例主体完整；但土面预览明显比 v28 暗，仍读成大块平盘。模型新增 1 张 512×512、约 54 KB soil albedo texture，违反初始候选的“纯色 PBR、无贴图”约束；尚未 Godot 验证。
- [ ] 若纯色预算保持，改用低对比床面 `COLOR_0` 变化表达细节；若保留 albedo map，则先恢复到 v28 的可读土色并核对目标渲染路径，再复核地表是否需要轻微几何起伏。

#### 3.44 主线番茄菜床候选 v31 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-v31/tomato_harvest_editable.glb` SHA-256 `dc5c5ad192cdece30f82e6a1c4d569efd275fce2b0afa1011a3dbe4a0e14c3c9`；16:9 SHA `c7d31e07fb0da927e8f25a6ccae05c11a5c88f4daeb231d01dc22e68e4ab7d7a`，4:3 SHA `63a1c2c28d1be261e1a621615e4aa06dbf4fb74ff0d8703144fe1a4b71f2a286`。双画幅均完整，输出分别为 1280×720、960×720。
- [x] 结构为 37,904 tris / 12 材质 / 1 张内嵌贴图 / 15 个静态材质 primitive；12 个唯一 `HarvestTarget Tomato P01/P02/P03 F01–F04` 各 357 tris（目标合计48 primitives），无相机。总面数和静态 primitive 数达标，但内嵌 soil albedo 仍违反无贴图约束。
- [x] 比 v30 增加低矮、稀疏土粒，暖土色和圆叶冠较自然，是当前更好的整床外观基线；仍有大片平土、个别叶片压果，薄草缘和独立篮子也与现有动态页面布局不匹配。背景仍为灰白棚拍底图；未导入 Godot、未通过最终美术 gate。
- [ ] 保持12个目标锚点和当前静态预算，尝试移除贴图并以顶点色/纯 PBR 表达土色；优化几处挡果叶片和低矮床缘。下一步优先拆出可适配动态 `HarvestTarget` 布局的植株/地表部件，而非接入固定整床。

#### 3.45 并行番茄菜床候选 v31 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-parallel-v31/tomato_harvest_editable.glb` SHA-256 `da621a4fbf5dc7c7c516c1f282527028d1c8d548f021606b4cf69fdac8a8cd50`；16:9 SHA `04e37175772a57e6b45c03c2a94bc58d50ba7b0a98aef476bb1fc53622824d70`，4:3 SHA `f5a0161718c377b775cea2e7988c516ac0913acf1edcb5f04ab2caa75d2bb294`。双画幅均完整，输出分别为 1280×720、960×720。
- [x] 结构为 41,252 tris / 9 材质 / 1 张内嵌贴图 / 12 个静态材质 primitive；12 个唯一目标各 357 tris（目标合计48 primitives），无相机。几何、静态 primitive 均在预算内，贴图约束未过。
- [x] 土床外围更厚、果实较清楚，但大块浅绿叶缘形成规律粗环，三根直立支柱显眼，呈现规则花盆/支架感；土粒偏暗。视觉审查不通过，未导入 Godot。
- [ ] 保留当前静态预算与可见果实窗口，移除或弱化支柱，打散叶缘尺寸和间距；把连续床缘收低并做自然过渡。无贴图版本完成前仍只作临时候选。

#### 3.46 并行番茄菜床候选 v33 复核（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-toy-farm-parallel-v33/tomato_harvest_editable.glb` SHA-256 `909ee909c93f50cf6af66bc4fec2ba9adb26dba50e96756a1e2af9df3b3eb3b4`；16:9 SHA `15f8fd396f9321d06e67c65f8fe91dc2f0ce2bc99b23d72eb701c7434eec6644`，4:3 SHA `9cf4964dd6b8dad7f1e0ad684e621d159631801926ce91aaf30b6671b2e64fd3`。两比例完整入镜。
- [x] 结构为 49,244 tris / 9 材质 / 1 张内嵌贴图 / 12 个静态材质 primitive；12 个独立目标各357 tris（48目标 primitives），无相机。保持静态预算，面数低于60k但余量约10.8k；无贴图约束仍未通过。
- [x] v33 比 v32 的叶缘大小和间距更不规则、土粒与床缘层次有改善；仍像连续叶块环，三根支柱明显。尚未接入动态页面，也未导入 Godot，不能视为通过。
- [ ] 后续避免继续增加整床几何；移除立杆、只修正必要遮果叶片，同时尝试拆出能复用于动态 `HarvestTarget` 的土丘/植株部件。

#### 3.47 连续土行离线原型 v1 复核（2026-10-01）

- [x] Blender 输出 `/private/tmp/heroes-island-soft-furrow-v1/soft_furrow.png`（2048×256，SHA-256 `a7f4d18828c6c89db915c1173a950b9b9ce6a9ba2d7a46fa2cd53f9faba05f75`）；作物叠图 `/private/tmp/heroes-island-soft-furrow-v1/soft_furrow_with_crops.png`（1280×420，SHA-256 `5ca5daa6bc35c5af8d026b216ebe0621bbed1e56e2263cf41678c24680d36433`）。
- [x] 相机轴修正后土行与屏幕水平对齐，番茄、胡萝卜、莴苣、南瓜和小麦根部大致接触土面；这是离线构图检查，不代表真实页面接入或 Godot 验收。
- [x] 视觉 gate 未通过：土行过窄且长边近乎笔直，长向平行色带读成木板/托盘；暖土与草地反差偏强，边缘少量草叶像散落在垄外。暂不接入项目。
- [ ] 下一版需放宽并柔化不对称侧缘和端头，减弱长向规则条带与土色对比，让草缘贴合土行；再按真实草地、篮子和动态行布局做离线组合审查。

#### 3.48 连续土行 v2 独立叠图复核（2026-10-01）

- [x] 从更新中的生成脚本复制出独立审查版 `/private/tmp/heroes-island-soft-furrow-review-v2/build_soft_furrow_review.py`，与资产线源脚本只有输出目录不同；没有覆盖资产线文件。候选 PNG SHA-256 `47ba2797a88143ac84d89963b04349149d047f45b4fb31939992610bbaf54de0`，作物叠图 `/private/tmp/heroes-island-soft-furrow-review-v2/soft_furrow_with_crops.png` SHA-256 `59ac1ff2d2202e49d57dfbcf342bc0f371571a753f4160b7bf5505b6bc886757`。
- [x] 相较 v1，不规则侧缘更柔和，平行条带和垄外散草已消失；番茄、胡萝卜、莴苣、南瓜和小麦的根部大致落在土行上。
- [x] 视觉 gate 仍未通过：表面过于均匀，整体仍像一条棕色长带/下划线；土面立体起伏和低频色差不足，草地反差偏强。此图为临时审查叠图，不是正式资产导出或 Godot 页面截图。
- [ ] 下一版保留不规则边缘，增加克制的宽幅冠部明暗和低频色差、降低土色对比，再检查根点尺度、真实草地与相邻篮子；避免细碎石点和重复纹理。

#### 3.49 连续土行 v2 贴地边缘复核（2026-10-01）

- [x] 独立脚本 `/private/tmp/heroes-island-soft-furrow-edge-review-v2/build_edge_review.py` 与资产线生成器相同，只有输出目录不同；原图 `/private/tmp/heroes-island-soft-furrow-edge-review-v2/soft_furrow.png` SHA-256 `879e688c4da648dd3abf42e2677f0b53d6310fef73149297186c924d9cd3e587`，作物叠图 SHA-256 `230786ee1d174c5bd6c3ee02560eb38ddf121623253f692ea477f3d39e51cf4c`。
- [x] 修正侧缘高度后，土行更贴地，土粒露出表面，根部落点总体成立；轮廓仍保留自然的宽窄变化。
- [x] 视觉 gate 仍未通过：低频明暗不足使土面像均匀棕色横带，画面注意力被横线吸走，土色与草地反差仍偏强。该候选为离线复核，不是正式资产导出或 Godot 页面截图。
- [ ] 保留当前贴地边缘；增加克制的宽幅冠部明暗和低频土色变化，稍降土色对比，并用动态目标长行/短行及篮子旁的实际组合检视。

#### 3.50 共享浅土面 v1 全页离线组合复核（2026-10-01）

- [x] 新候选 `/private/tmp/heroes-island-soil-plot-v1/soil_plot.png`（2048×640，SHA-256 `1433460f8db74f66eb911a4d706099c4b5a87ee8ecc591cd141d850197de2172`）为低矮、不封闭的共享种植面；复用现有草地、两行各五株作物和篮子，独立组合图 `/private/tmp/heroes-island-soil-plot-v1/soil_plot_page_mock_16x9.png`（1280×720，SHA-256 `7aec8a9f5212580326e73075e9fdc4a02386ff20ac6df04d9670865fe712d87f`）。
- [x] 相比窄土带，共享土面能把两行作物读成同一块种植地；不过当前轮廓像规则棕色胶囊岛，颜色整片偏实，上排根点靠近远侧边缘，双行 16:9 之外的动态适配尚未验证。
- [x] 视觉/布局 gate 未通过：这是一张离线构图 mock，不是 Godot 页面截图，也不能证明单行、短行、4:3 或篮子留白可用；没有导入项目或改动交互。
- [ ] 继续探索可按当前所有目标 bounds 缩放的低对比不对称浅土面；先保证各行根点有边界余量，再验证单行、短行、双行的 16:9/4:3 和篮子安全区，避免固定胶囊托盘感。

#### 3.51 共享浅土面 v1 扩大覆盖组合复核（2026-10-01）

- [x] 对同一 PNG 手工改为 985×424px、centerX=590、画面 ground center=517，得到 `/private/tmp/heroes-island-soil-plot-review-fitted/soil_plot_page_mock_fitted_16x9.png`（1280×720，SHA-256 `6f8ef69450f96cd2ee45314ce469ab77b4ba6f7e0964cdc4987e540ef028f622`）；两行作物根部都落进土面，说明共享地表形状有继续试的价值。
- [x] 此尺寸仅为手动构图：相对 1280×720 下 `_bed()` 的 x=172..968、宽 796px，土面约延伸至 x=97.5..1082.5，超出可玩床并进入篮子安全区；轮廓也仍像规整、平滑的棕色胶囊岛。因此不构成动态布局通过。
- [ ] 按实际 `_plan_positions()` spots 得出共享 bounds，以 `_bed()` 和篮子安全区共同 clamp；调整形状为更低对比、不对称的柔和土面，并检查短行/单行和 4:3，不能直接采用手调放大的尺寸。

#### 3.52 Blender 共享浅土面 v2 与 3D 路线复核（2026-10-01）

- [x] 使用本机 Blender 5.2.2 生成可编辑土面源文件 [`soil_plot.blend`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.blend) 与 GLB [`soil_plot.glb`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.glb)；预渲染 RGBA [`soil_plot.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.png) 为 2048×896。GLB SHA-256：`e282e741fd83b882234c19870325ffea69c73c29689c8d0b087ed636f8f7fc4a`。
- [x] 将同一块共享土面放在用户已授权的草原底景、现有番茄/胡萝卜/生菜/南瓜/小麦 PNG 与收菜篮子旁做离线 16:9 尺寸复核：[`soil_plot_page_mock_16x9.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot_page_mock_16x9.png)，SHA-256：`b35c7eb6ca01163966b5b87f763e03656d208c3b2d5a8102eca74433ddbc42a2`。这不是 Godot 页面截图。
- [x] 视觉 gate 未通过：较宽土面能覆盖两排作物根部，但在现有水粉草地上仍像单独铺放的棕色平台；它没有消除前后景材质/光照的断裂。因此不复制 PNG 到 `assets/`，不改 `HarvestAction`，不接入正式页面。
- [ ] 下一轮暂停扩大或调色这类独立土垫；待当前 QA Godot 实例退出后，在隔离副本做一次**真正的 Godot 3D 接地试片**：让可拆的 3D 土面与既有 `HarvestTarget` / `HarvestBasket` 屏幕锚点共用正交相机和光照，2D 节点仍唯一拥有状态、手势和命中。只比较 16:9、4:3、拿起态以及篮子安全区；若仍像拼贴则不进产品页，回到同源完整地表/模型输入，而不是改用 Three.js 或烘焙整页背景。

#### 3.53 soil_plot.glb 静态导出审计（2026-10-01）

- [x] GLB `/private/tmp/heroes-island-soil-plot-v1/soil_plot.glb`（SHA-256 `e282e741fd83b882234c19870325ffea69c73c29689c8d0b087ed636f8f7fc4a`）共 17,282 triangles、12 nodes/meshes/primitives、无纹理。主体网格 15,600 tris，10 个独立 clod 各 168 tris，阴影面 2 tris。
- [x] 主土材质只有 roughness，没有 `baseColorFactor`；网格属性无 `COLOR_0`，GLB 也无纹理，因此 Blender 的程序化 Noise/ColorRamp 外观没有序列化到 PBR BaseColor。默认 glTF 土色外观很可能变白，须以实际 Godot 导入确认。
- [x] 阴影材质导出为 `alphaMode=OPAQUE`、`baseColorFactor=[0,0,0,1]`，仅附 warm `emissiveFactor`；Blender 透明渐变没有作为透明纹理/alpha 写入 GLB，存在出现不透明阴影片的风险。
- [x] 前一版的材质/阴影导出问题已在 §3.54 静态修复并核对；此项仅记录旧版导出结论，Godot 导入/光照验证仍待完成。

#### 3.54 soil_plot.glb 顶点色修复与布局联系图复核（2026-10-01）

- [x] 新导出 [`soil_plot.glb`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.glb) SHA-256 `96a921b372f4334d42f385b62dc42720c9f684b5045b7580e974489f76e25b0a`，1 个共享网格、2 个 primitive，主土面与 clod 均包含 `COLOR_0`；主土面为 8003 个 VEC3 float 顶点色，范围约 `(0.2295,0.1485,0.0900)` 至 `(0.2558,0.1655,0.1003)`。GLB 不含透明阴影网格、图像或纹理；clod 使用显式 PBR BaseColor。§3.53 记录的是前一导出版本，当前静态颜色/黑色阴影板阻塞已解除，但尚未做 Godot 导入验证，也需在实际场景提供光照/接地阴影。
- [x] 用 Blender 的 `import_scene.gltf` 将 GLB 重新导入并在绿色地面与补充灯光下渲染：[`soil_plot_glb_roundtrip.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot_glb_roundtrip.png)，SHA-256 `f88064e72785c7edaa1bdba4ffc87e816987f0fea300b11353c2e592911bea5b`。颜色正确呈现，没有白色土面或黑色阴影片，证明 GLB roundtrip 的材质数据可读；这仍是 Blender 验证而非 Godot 导入。造型仍像宽、硬边的土面平板，GLB 也没有独立接地阴影，此视觉 gate 未通过。
- [x] 更新后的共享土面布局图覆盖正式关卡样本 5/8/10/12/14/18 个目标以及 16:9、4:3：[`16:9`](/private/tmp/heroes-island-soil-plot-runtime-audit/soil_plot_formal_16x9.png)（SHA-256 `9826ce5231efe6cf7b483d2a30a6af4c23295aa4a7e468d97d57e2d673d77965`）、[`4:3`](/private/tmp/heroes-island-soil-plot-runtime-audit/soil_plot_formal_4x3.png)（SHA-256 `fa7a75673a364c9f69878a5c06e6474aac4407bc704f8f3682717a55864f82f7`）。读取实时关卡/作物 JSON 并复现 `_bed()`、网格容量、间距、抖动范围与 clamp，但用 deterministic stand-in RNG 代替项目 String hash/PCG；是假设首次尝试、普通难度下的离线合成，不是 Godot 输出或精确位置序列。
- [x] 复核蓝框语义后更正布局判断：`_bed()` 是目标中心可放置区域，源码以 `CROP_HALF=62px` 向内缩，作物图像边缘可延伸到 `_bed().grow(CROP_HALF)`。联系图里可见土面超出蓝色中心框，但 16:9 最大高度 266px 小于 176+124=300px；4:3 最大 386px 小于 296+124=420px，因此现有证据不能证明土面越出作物视觉床区，不应简单 clamp 到蓝框。仍要确认实际 PCG 点位下根部边缘余量。12/18 目标与篮子可见 alpha 的横向重叠分别为 16:9 约6px、4:3 约24px；正式代码土层 z=-5、篮子站 z=-4，可能是合理的前后遮挡，但须看真实页面合成再判定。
- [x] 扩展边界叠图 [`16:9`](/private/tmp/heroes-island-soil-plot-runtime-audit/soil_plot_bounds_16x9.png)（SHA-256 `6874ddbc3e0e8e8d36d977204c351bf60892481fba5da19a9f5c17dba59d5f02`）与 [`4:3`](/private/tmp/heroes-island-soil-plot-runtime-audit/soil_plot_bounds_4x3.png)（SHA-256 `29349278644c76be3338b8fac081b8d8e4726a81c813bc2df7ff90c0aac6b618`）将蓝色 `_bed()` 中心框、绿色 `_bed().grow(CROP_HALF+14)` 地表/篮站边界与洋红色 alpha=0.5 边界并列。所有样本土面都在扩展边界内；拥挤版最小下缘余量约 13–14px。因此纵向尺寸适配通过这项静态边界检查，仍待实际 PCG 与 Godot 页面复核。12/18 目标的篮子 alpha 重叠 6/24px 是唯一明确的横向相交；土层 z=-5 低于篮子站 z=-4，已建议集成会话微调篮位约 26px，再确认两种比例中的篮子轮廓、最右根点余量和触控区均不受影响。
- [x] §3.54 当时的 2048×896 RGBA [`soil_plot.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.png) SHA-256 `ec474d68afec0f7a9250f6a882ac014cc5b718784948fadfd5f53fd952a6e2a4` 仍像宽大的棕色胶囊土台，视觉 gate 未通过；该图现由 §3.55 新版取代。

#### 3.55 GLB 顶点 Alpha 与柔边 roundtrip 复核（2026-10-01）

- [x] 更新导出 [`soil_plot.glb`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.glb) SHA-256 `7cdd7bcfd81a8c137e9b593ae5877527de80bd0bf27a48054b4a450a70ea7cd0`。主土 primitive 的 `COLOR_0` 为 13,019 个 normalized uint16 `VEC4`，RGB 约 `(0.167,0.073,0.031)` 至 `(0.198,0.087,0.037)`，alpha 范围 `0.0002–1.0`；主材质 `alphaMode=BLEND`。Clods 为 1,150 个不透明 `VEC4`，并使用显式 PBR 土色。无贴图、无额外阴影平面。
- [x] Blender `import_scene.gltf` roundtrip 渲染 [`soil_plot_glb_roundtrip.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot_glb_roundtrip.png)，SHA-256 `8fa110aeae1b3d2701ff068551bab8330cda72ffb1fdb4d26f40a2146d57f910`：土色保留，顶点 alpha 的柔边正常工作，矩形硬边已消失；仍是偏宽的软边土岛，没在作物/篮子上下文验证，也不是 Godot 导入。
- [x] 新版 2048×896 RGBA [`soil_plot.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.png) SHA-256 `b39a5fe07bfe5ae3874d0b495dc90160d1c7fd6f01c4e00e872373b263c3cbe3` 已重做 Blender 输出。按 alpha 重新拟合后的组合图现为 [`16:9`](/private/tmp/heroes-island-soil-plot-runtime-audit/soil_plot_latest_16x9.png)（SHA-256 `346ba0b9a19599bd96d14d5337d4833c1eee7b88c3c331795ca1f92dd76f18f2`）与 [`4:3`](/private/tmp/heroes-island-soil-plot-runtime-audit/soil_plot_latest_4x3.png)（SHA-256 `69a3d52dbe37b58bba71f7b78fe785a7fd1ef25148f77717af9be4ca5b43f315`）；使用新版 alpha 可见范围比例 0.8193×0.5748 与重心偏移 0.0647。两图仍采用近似 PCG 点位，不是 Godot 实页；新版柔边土面已覆盖作物根点，但看起来仍是一块较宽的共享棕色地面。旧版 expanded-bound 图里的 alpha 边界数字不能直接套用新版，需补新版边界对照。12/18 目标的篮子 overlap 仍待约26px篮位调整后复核；Godot PID 73674 仍运行，页面导入待串行 QA 窗口。

#### 3.56 三条浅种植垄与新版 Alpha 导出（2026-10-01）

- [x] 新一轮源文件生成于23:36：[`soil_plot.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.png) SHA-256 `d2402d0a5a83ebf1fe74e123d232037c87bac844b3abf3ccdcb1fe22c5c26dba`；[`soil_plot.glb`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.glb) SHA-256 `559f0f55ffa7849a2417a3a5fe93cce7fb3ec656ac209318a4415c0c2abe57ea`。GLB 主土 primitive 仍为 13,019 个 normalized uint16 `VEC4` 顶点色、`BLEND`；clod primitive 扩至 4,140 个顶点色记录，无纹理或独立阴影片。
- [x] PNG 的 alpha≥0.02 bounds 为 `(185,245)–(1862,761)`，占源图 `0.8193×0.5770`，加权 alpha 重心纵向偏移 `0.0627`。23:13 布局图基于前一版 `(0.8193×0.5748)`；当前 QA 副本贴图仍停留在22:05旧文件（SHA-256 `406089e782ebe00231a2433bf774dd1d1974e3f23a791f00e280e3d40c2a84ea`），`_draw_bed()` 也仍使用 `.808/.444/.059` 常量。已通知集成会话同步新版贴图并按本版 alpha 重新拟合，旧截图不可作为当前版本验证。
- [x] Blender GLB roundtrip [`soil_plot_glb_roundtrip.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot_glb_roundtrip.png)，SHA-256 `876241b9a8ebcd1d534e10c37888b9a3358c0d24ae0ec325b14ae38e79ccae54` 显示土色和柔边有效、clod 比前版明显；三条浅垄在整块地面比例下仍较弱，画面仍像宽大的棕色土面。此为 Blender 导入渲染，没有作物/篮子，也不是 Godot 验收；等新版组合图和造型评审后再决定是否继续调整。

#### 3.57 圆角木框共享菜床候选（2026-10-02）

> 历史实验记录，不是当前接入建议。10/02 后续同屏比较仍读成托盘或棕色地毯，停止继续调木框、土色与柔边。当前下一项见第 11 节；原 QA 实例 73674 已由串行验证会话正常关闭，不再依据下文的旧 PID 状态安排运行。

- [x] 00:05 更新可编辑源文件、PNG 与 GLB：[`soil_plot.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.png)（2048×896，SHA-256 `3ac5221bf67a894d1e4f451ce63cf67298697dae655e5b8137ae4593c49c0e83`），[`soil_plot.glb`](/private/tmp/heroes-island-soil-plot-v1/soil_plot.glb)（SHA-256 `2d5ece069f37537f35eab67132e5504312bef512e169e9eef3f9519ad0f164b4`）。Blender 单位立方体缩放已更正，四边木框闭合，土面轮廓改为填入框内的圆角长方形。
- [x] 当前 GLB 静态检查为 1 node / 1 mesh / 3 material primitives，共 32,124 triangles：土面 26,988、木框 96、土块 5,040；三个 primitive 均带 `COLOR_0 VEC4`，主土材质使用 `BLEND`，无纹理。GLB 不含接触阴影平面，需由实际场景光照提供落地感。
- [x] 当前 PNG 的 alpha≥0.02 bounds 为 `(185,217)–(1862,750)`，占画布 `0.8193×0.5960`，加权 alpha 重心纵向偏移 `+0.0485`；QA 副本原 `.808/.444/.059` 参数不适用。
- [x] 离线 16:9 页图 [`soil_plot_page_mock_16x9.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot_page_mock_16x9.png)（1280×720，SHA-256 `81f3a0acb1f3f98e19b79b0e2adf2e7f92c5c7fdf1b4a3232a1854ab1da1fb3e）显示闭合木框比前版更容易读成一张完整菜床；土面主体仍较平，浅垄缩小后不突出。它是静态构图而非 Godot 页面，也未证明动态短行或篮子安全区适配。
- [x] Blender `import_scene.gltf` roundtrip [`soil_plot_glb_roundtrip.png`](/private/tmp/heroes-island-soil-plot-v1/soil_plot_glb_roundtrip.png)（1280×720，SHA-256 `d92937cbcdfd3231f80e22da27072142f579080c0669357147356527bac23a4f）保留了木框和土色，证明该 GLB 可在 Blender 回读；浅垄仍不明显，绿色地面上能看到边缘的半透明过渡。这不是 Godot 导入或实际作物/篮子页面。
- [x] 补齐按新版 bounds 构成的 16:9/4:3 目标联系表 [`16:9`](/private/tmp/heroes-island-soil-plot-runtime-audit/soil_plot_0005_16x9.png)（SHA-256 `3de72f6dedc70971cf11f09983e0c8c69819d94686bdd91fe48ba7ea4f4a51f2）与 [`4:3`](/private/tmp/heroes-island-soil-plot-runtime-audit/soil_plot_0005_4x3.png)（SHA-256 `7aeb3c71fd89cf40c6186cc92cc833863943f5e74c5a14aeb73c9ee9876c7093`），覆盖5/8/10/12/14/18目标的短行和拥挤行。它们是离线近似点位，不是 Godot 页面截图；4:3 的12/18目标土面与篮子可见轮廓仍约重叠24px，拥挤行根部与木框接触余量也要以真实 PCG 点位复核。
- [x] 在 180px 显示尺寸下，以 source ground pivot `y=467` 为中心检查 `y=455..<480`、alpha≥0.02 的25px接触带：番茄/胡萝卜/生菜/南瓜/西瓜/小麦横向宽约47/40/53/106/91/46px，最宽单侧按像素栅格保守取55px（另一轮取整约53px）。因此 `_bed().grow(CROP_HALF=62)` 已覆盖根部，额外14px给柔边余量。端点根部碰框是菜床被夹在 `_bed()` 目标中心范围的构图问题，不是需要包住完整叶冠；整株叶冠 bounds 不可当作根宽。测量脚本 [`measure_crop_pivot_slice.swift`](/private/tmp/heroes-island-soil-plot-review-20261002/measure_crop_pivot_slice.swift)。
- [x] 并行集成候选副本 `/private/tmp/heroes-island-harvest-shared-bed-qa-20261002-candidate` 已按根区边界 `_bed().grow(76)` 扩床，并独立反推三篮 alpha 安全区；18目标整组左移68px（16:9）、62px（4:3）后，静态联系图 [`16:9`](/private/tmp/heroes-island-soil-plot-v1/soil_plot_candidate_18_16x9.png)（SHA-256 `acd3da9e6e3834df1a4f68bb6e27b49e71fc028a83530679fbdec8e28401955b）与 [`4:3`](/private/tmp/heroes-island-soil-plot-v1/soil_plot_candidate_18_4x3.png)（SHA-256 `4251d06442d0d8833822dd91b6db3f2e130209648a625f1ea6062b49d7947687）都避开篮站轮廓，解决旧图的约24px静态重叠。4:3拥挤关仍排成三行且贴近屏幕下缘；点位用近似 RNG，尚非 Godot/真实 seed 验证，也不代表正式工作树已改。
- [x] 同源场景二次构图 [`16:9`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_preview_16x9.png)（1600×900，SHA-256 `016d2faca25dd4a33c9a8e0b0f9a55351ca03699d4d26aabacfa96ddf8ef129a）与 [`4:3`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_preview_4x3.png)（1200×900，SHA-256 `c2d01ec77b5da2f29f604f53c2495e0ef50abaa9d9823e0203345fb9a08e099b）修正了菜床/作物行轴、篮子朝向与山丘地平线；篮把手恢复弧形。现有作物/篮子 Blender collection 被直接复用，未重造模型。编辑场景 [`unified_3d_harvest_preview.blend`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_preview.blend) 可单独打开审阅。它们是离线 Blender 图，不含正式 UI，也不是 Godot 页面或触控验证。
- [x] 10/02 继续校正全场取景：相机沿菜床横轴偏移约0.65场景单位，让床与篮一起构图，而不是单独挪动篮子。更新预览 [`16:9`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_preview_16x9.png)（1600×900，SHA-256 `742d500e61b2685435bd3604f45d4abfbd3e1adf614df864c796989243aa1ee1`）与 [`4:3`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_preview_4x3.png)（1200×900，SHA-256 `a9a08444475a172721447f98e78446a5610c43d3cce198628e6347ef0b48e288`）后，篮子均完整入镜，床左缘/篮子右缘约保留5%–8%画幅安全区。
- [x] 在同一离线场景改用 Blender Standard 显示变换并回调环境强度/草地色，远山网格细分从72段提高到144段并启用平滑法线，草地增加低幅程序噪声；相较 AgX 版更有儿童向色彩与地形层次，但近景绿地仍大面积平、远山仍像简化色带，需在真实页面尺度下继续判断。
- [x] 18目标静态拥挤预览已随同相机和色彩更新：[`16:9`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_18_16x9.png)（SHA-256 `c2bc612bbad91e40685227ea506b35507550eeca5ab202f9a9aa40710656bf62`）、[`4:3`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_18_4x3.png)（SHA-256 `f5f01b7755a64628b55a0317c6e210dbdb28ecc54849beec58a58471d2ad5d3c`）。两种比例篮子安全边距改善，但西瓜藤横向过宽、小麦过高、部分作物模型接地/比例不齐，说明现有原始模型不能不经裁定直接塞满拥挤关；该图不是运行时动态布局。
- [ ] Blender 美术 gate 仍未通过：10株图的作物间距较松，床体仍像展示台；18株压力图暴露西瓜藤横向过宽、小麦过高及部分模型根部/比例不齐。最新 16:9 / 4:3 预览的床和篮子均留出约5%–8%边距，但画面仍缺少完整 UI、订单、采摘动画与真实命中框，不能据此确认 Godot 材质导入或页面可读性。
- [x] 木框 A/B 轻量化候选 [`16:9`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_preview_slimframe_16x9.png)（SHA-256 `232a72e85ec4dd405591714159406553f6544044be723471e4b96d4c5ae1ea62`）、[`4:3`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_preview_slimframe_4x3.png)（SHA-256 `12e15e88c0867450e6e5f68453eb03e87178084239e45e93a6af933603f9454b`）仅缩薄原有独立木框，没有改镜头/作物/篮子。木框略轻，但画面仍读成托盘；另一会话的无框比较 [`16:9`](/private/tmp/harvest-style-composite-20261002/no_frame_16x9.png)、[`4:3`](/private/tmp/harvest-style-composite-20261002/no_frame_4x3.png) 则显示裸土变成漂浮棕色贴片。两种极端都不能作为最终样式。
- [x] 更低边沿 A/B 候选 [`16:9`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_preview_lowrim_16x9.png)（SHA-256 `960b5fddc84c707261dcb83eb84861a739985be1223cc14e8415b470c79a9e45`）、[`4:3`](/private/tmp/heroes-island-soil-plot-v1/unified_3d_harvest_preview_lowrim_4x3.png)（SHA-256 `e8cbf9663232cdbb023f4b64f640cff38f02a90dc2449ed574c7186beef729d5`）把木沿压低并缩窄，床/篮和作物布局保持不变。前沿托盘感下降，但棕色种植面仍是一块独立的抬高平台，尚未与草地融合；它只是造型对照，不导入项目。
- [x] 集成线另做精确18目标点位的静态根影尺度图：[`16:9`](/private/tmp/harvest-style-composite-20261002/root_mounds_sized_18_16x9.png)、[`4:3`](/private/tmp/harvest-style-composite-20261002/root_mounds_sized_18_4x3.png)，基于透明 PNG 根部接触带估计作物足迹，接触影随宽瓜/窄根菜变化并整体降淡25%。4:3三行接地感略有改善，但差异细微、仍有轻微悬浮印象；它是 AppKit 静态合成，不是 Godot 随机点位/触控验证。可作为低矮共享地表方案的接地参考，不能直接视作已通过实现。
- [ ] 下一轮造型方向改为“低矮、融入草地的共享土带/浅土丘 + 按作物根部足迹变化的柔和接触影”，避免继续在厚木托盘与无框棕色贴片间二选一。现有 `HarvestTarget` 与篮子/命中区不动；地表只呈现被动视觉并在采摘后保留。优先复用当前作物/篮子资产，接地与边界通过真实动态 spots、16:9/4:3 和拥挤数量共同验证。
- [ ] Godot 页面集成 gate 仍未通过：隔离候选 `/private/tmp/heroes-island-harvest-shared-bed-qa-20261002-candidate` 已同步当前 `soil_plot.png`（SHA-256 `3ac5221bf67a894d1e4f451ce63cf67298697dae655e5b8137ae4593c49c0e83`）与 alpha 参数 `.8193/.5960/.0485`；密集时仅把作物贴图从90px缩至72px，`HarvestTarget.radius` 保持原命中容差。其布局/构图仍是候选，尚未用真实 seed、HUD、拿起/投放与 Godot 页面截图验收。旧副本 `/private/tmp/heroes-island-harvest-shared-bed-qa-20261001` 仍是旧 PNG（SHA-256 `406089e782ebe00231a2433bf774dd1d1974e3f23a791f00e280e3d40c2a84ea`）和 `.808/.444/.059` 参数，不作本轮验证依据。当前 Godot PID 73674 仍运行；释放串行窗口后，在隔离副本复核16:9/4:3、真实目标点、篮站边界、视觉接地及收菜/分拣状态，交互继续由现有 `HarvestTarget` / `HarvestBasket` 持有。

#### 3.58 可拆整株与同源空间冻结（2026-10-02）

- [x] 源输入、构造脚本、可编辑 Blender、五份真实 GLB、透明分件和双比例审图保存到 `assets/harvest_3d/source/whole_plant/`；上级 `.gdignore` 继续隔离运行资源。
- [x] 当前整场 GLB `123cfab7a4150110e8af29ca208b46dda6a8250d4870e46f3fb791620f64718c`：49,094 tris / 9材质 / 11静态 material primitives / 12独立目标，0图片、纹理、相机、灯光。复用原粗藤篮和曲面叶；叶端在厚化前焊接/三角化，退化、反向和非有限法线计数为0。
- [x] 补修单件归零导出后的父basis恢复。前一 `b779…` 的首果挂点偏移，因此被取代，正常法线并不代表位置正确。新的默认 GLB 回读逐个核对12果的父级、局部位置和源比例；另有5个正/反例与19项共用只读审计测试。
- [x] 同源连续草地、缓坡和短草另存 `environment_rendered/`，同屏用冻结GLB，不改植株/篮网格；源哈希、网格内容哈希及世界变换复核（最大误差0）。背景和环境GLB不带示例三株固定土印，透明分件没有烘焙接地影。
- [x] 同场采用 Standard / 曝光-0.20，Sun主光与两Area补光；精确参数、实测挂点和单果中心写入清单。普通单件基准69.23077px/m，株身art_size102.115385，密集81.692308；实际背景跨度18.488889，与放大审图分开，不抄用旧比例。
- [x] 集成会话按这份冻结profile重渲17种已有单件与挖土盖，首轮20张真实双比例图暴露深橄榄空场、土盖遮露弱、手持贴株顶和采空回调引用已释放对象。不能以1526项触控通过或截图成功保存覆盖这些失败。
- [x] 回调寿命独立34项真实回归与采空双比例复验干净；当前正式控制新快照1536项触控通过，严格QA runner拒绝运行期 `ERROR:`。这些结果不追溯更改首轮失败日志。
- [x] 同一环境生成器完成连续侧坡/淡远坡、自然绿低频层次和边缘短草修订，独立保存 `environment_refined/`；不覆盖旧4fac摄影基线。新旧 `render_profile`、`runtime_reference`、`png_contract` 严格相等，三分件RGBA逐像素相同（文件哈希因PNG元数据不同而不同）。
- [x] 修订环境GLB `b0ab2a87738360bf01d84aeb2651ee3e48176bc816a3413bfc1d72bfa55d3e92`：15,776tris、2网格/2材质、0纹理/目标/相机/灯光，默认回读退化、反向角法线和非有限/零法线为0。旧环境13项薄侧壁异常保留为历史失败，不混用报告。
- [x] 新隔离候选20张实际图覆盖普通、三订单、埋土/真实挖开、持货、金色低动态、干扰及采空后；地面重复横条已移除，采摘后空株保留。随后持货避邻株也有新双比例截图，仍由原目标/教程组件承载，没有第二套输入。
- [x] 正式树隔离快照产生30张双比例实际图，完整触控1584项及规则日志通过，无运行/退出错误，关键运行文件逐项与正式树相同。原三张catalog空灰屏不计通过，截图夹具补等实际绘制帧与逐格非空断言，新48/72/96图51格复验通过，详见收菜运行证据。
- [ ] 技术接入和本轮局部构图改善不等于最终美术、设备或儿童体验通过；中央空场与小标签身份可读性继续开放。

### Phase 4：通过试片后的受控扩展

**目标：**只把已证明有价值的 3D 手法扩展到静态环境和少数高价值物体。

扩展顺序：

1. 仓库、订单板、井、围栏等稳定地标。
2. 丰收页的菜垄、土层、草缘和篮子外壳。
3. 菜园的被动环境层和可扩建区域的展示壳。
4. 最后才是作物；每种作物必须连同所有成熟状态、手势提示、低动态状态和小尺寸可读性一起完成，不能只替换一张“成熟菜”图。

每扩展一个对象，必须同时回答：它复用了哪个组件？它的真实状态从哪来？热区由谁拥有？关闭 3D 后是否仍能运行？若答案不是现有组件，先停下补设计，不扩量。

### Phase 5：是否立项“完整 runtime 3D 农场”

全 3D 不是默认下一步，只在以下条件**全部成立**时另立项目：

- 产品目标真的需要自由环绕、进入建筑、昼夜/季节变化等 2.5D 无法表达的能力；不是仅仅为了让截图更好看。
- 试片证明目标 Android、iPad 和 Web 路径都有可接受性能，且能接受不同渲染器下的画质差异。
- 已有完整的低模资产生产、导出、授权和版本管理流程，而非零散生成图。
- 已验证二维 `FarmCamera` 到三维平面的投影映射：每块地、每个设施、每个手指落点在平移/缩放/双尺寸下都可量化地对齐。
- 团队愿意承担一次产品级回归：渲染器、相机、触摸投射、遮挡、HUD、低动态、存档、所有菜园/丰收探针和目标设备测试。

未满足这些条件时，继续优化 3D 制作的 2.5D 呈现就是正确的长期路线；儿童并不需要自由相机才能感受到“立体、可玩的农场”。

## 7. 素材生产检查表

每个准备导入的 3D / 2.5D 素材须通过以下检查：

| 检查项 | 合格标准 |
| --- | --- |
| 风格 | 与风格合同的镜头、左上光、短阴影、色板一致；不是照片、水粉风景或像素风混搭。 |
| 拆分 | 对象、地表模块和环境层可分开组合；没有把整个页面烘成一张图。 |
| 锚点 | 真正接地点为 pivot；在 48 / 72 / 96px 下不会漂浮或压住文字。 |
| 透明与边缘 | 物体预渲染使用干净 alpha；没有黑/黄绿毛边、白边、半透明方框或烘焙天空。 |
| 状态 | 所有可见状态来自既有业务状态；无状态只能做被动装饰。 |
| 性能 | 导出尺寸符合最大缩放需求；贴图数量、材质数量和 viewport 更新频率经过真机检查。 |
| 授权 | 来源、许可、生成提示或原始资产、再加工和导出路径已记录。 |

## 8. 验证与质量门槛

视觉变更也必须按收菜 Skill 的安全流程验证：探针用隔离 `user://`，串行运行 Godot，绝不能触碰正式儿童存档。

### 自动/半自动回归

- `python3 tools_check.py`
- `GardenProbe.tscn`
- `GardenTouchProbe.tscn`
- `FarmWorldProbe.tscn`
- `HarvestProbe.tscn`
- `HarvestTouchProbe.tscn`
- 每个新增纯展示适配器的独立锚点/输入透传断言

### 必看截图

| 页面 | 必看状态 |
| --- | --- |
| 菜园 | 16:9 默认镜头、4:3 默认镜头、最大缩放、平移后、任务旗/成熟/缺水等状态共存 |
| 丰收 | 16:9 普通态、4:3 普通态、真实拿起作物后的分拣态、正确入篮、低动态模式 |
| 3D 试片 | 3D 开/关的同构对照、锚点叠加图、点击区域可视化图、目标设备截图/录屏 |

### 儿童体验验收

让 5–8 岁孩子或观察者完成“找到成熟菜 → 收起 → 放进篮子 / 仓库 → 回到任务”，记录：

1. 是否在三秒内知道先点哪里；
2. 是否把环境物误认为可点目标；
3. 是否因阴影、遮挡或透视误判作物/篮子的接触位置；
4. 是否在 4:3 或低动态模式下仍看懂物品去了哪里。

若 3D 让上述任何一项变差，即使截图更漂亮，也不通过。

## 9. 风险、对策与停止线

| 风险 | 早期信号 | 对策 / 停止线 |
| --- | --- | --- |
| 2D 与 3D 又变成两种风格 | 3D 模型太写实、作物像图标、阴影方向不一致 | 回到风格合同，先统一资产源；不增加更多物体 |
| 3D 视觉与热区漂移 | 放大/平移后物体中心与点击中心不重合 | 仅允许视觉读取现有 `FarmCamera`；未通过锚点探针不能上生产页 |
| `SubViewport` 吞输入 | 点仓库/篮子后无响应或触发两个事件 | viewport/display 设为无输入，保留原 2D 命中；作为阻断级缺陷处理 |
| 低端平板性能下降 | 首帧卡顿、掉帧、发热、内存暴涨 | 先预渲染、降低 viewport 更新频率或停用 runtime 3D；不切换全局渲染器来掩盖问题 |
| 画面变丰富但孩子更迷失 | 背景细节比作物亮，误点装饰 | 降低环境对比度，保留唯一主焦点，减少而不是增加装饰 |
| 资产授权不清 | 只有成图、没有来源/许可 | 不导入；先补来源记录或重新制作 |

## 10. 推荐执行顺序

```text
Phase 0 风格合同与截图基线
    ↓
Phase 1 离线 3D → 2.5D 垂直切片（篮子 / 菜垄 / 仓库）
    ↓ 视觉、触控、双尺寸全部通过
Phase 2 资产包与既有状态映射
    ↓ 真机性能和风格收益明确
Phase 3 一个可删除的 runtime 3D SubViewport 试片
    ↓ 只有通过全部门槛
Phase 4 静态环境与高价值物体的受控扩展
    ↓ 产品需求、设备能力、投影映射都成熟时再评审
Phase 5 完整 runtime 3D 农场（独立立项）
```

## 11. 当前下一项建议

### 11.1 已确认的当前问题

共享土面、木框减薄、降低边沿、无框柔边和水粉底景合成都没有消除贴图感，不再在这条支线上继续微调。当前真正需要补的是用户参考中的造型关系：红果挂在完整枝叶上、木支架属于植株、篮口与编织有厚度、所有物体使用一致的相机和光照。单颗果实与细线篮并不能靠换背景变成完整农场。

丰收集成会话已经完成布局、动效互斥与礼篮标识等正式修复，并持续验证整株被动层候选；双比例真实截图、检查数和源文件 SHA 由 [运行证据](HARVEST_RUNTIME_QA_20261002.md) 维护。这说明交互与拥挤布局可验证，不表示美术通过。实际 `harvest_08` 首屏只显示当前订单的 3 个胡萝卜、4 个草莓及石头；离线 18 株或本轮三株同屏图不能代替该关的真实运行截图。

### 11.2 已交付的源资产：可拆整株与藤编篮

只做这一种作物和一个篮子，不扩作物数量、不改经济、不引入 Three.js、不切换全局渲染器。

1. 已复用既有 v28 无贴图模型、v33 曲面叶函数及粗藤篮，修整厚叶、萼片和原篮提手。支架属于对应植株，篮子不拥有木桩或装饰果。
2. 已保存 `Plant01–03` 静态株身与12个独立目标，另导出无果株身、单果和空篮。采一次仍是一个已有收获单位；四果整株只作造型图，不能替换 `crop_texture`。
3. PNG 保留512画布及原点 `(256,467)`；清单记录实测果心挂点、单果中心、相机跨度和已烘入图内的1.13源比例。不能只核pivot，更不能拿整株叶冠宽度当根幅。
4. 源模型预算与实际回读见§3.58及 [源资产说明](../assets/harvest_3d/source/whole_plant/README.md)。primitive不是实测draw call，GLB可回读也不代表Godot、目标设备性能或儿童识别通过。
5. 同源空间和同rig透明分件另见 [环境接入契约](../assets/harvest_3d/source/whole_plant/ENVIRONMENT_REVIEW.md)。`rendered/` 中性AgX图不能混用；`environment_rendered/` 是冻结Standard摄影基线，`environment_refined/` 只修同rig连续环境，不更换分件光照或锚点。

### 11.3 接入与停止线

| 内容 | 复用 / 所有权 | 本轮边界 |
| --- | --- | --- |
| 果实采摘、拿起、入篮 | `HarvestTarget` / `HarvestAction` | 一个已有目标对应一个可收获单位；不另建 3D 拾取或订单状态 |
| 枝叶、支架与采摘后的空株 | 场景被动外观 | 不命中、不结算；采摘果实后株身保留 |
| 篮子规则与提示 | `HarvestBasket` | 只替换外壳；沿用现有接受规则、示例标签与低动态反馈 |
| 预渲染锚点与图标 | `HarvestVisualArt` | 接地使用原契约；订单徽标仍表示单颗果实，不能换成整株 |

先在隔离副本验证普通态、手持态、采空后、正确/错误分拣和低动态；只有同屏美术与交互都通过，才接正式页面。若同源模型仍不能在目标尺寸下明确表达采摘，就返回造型或连接点整理，不新增玩法绕开问题。

Godot 按实际会话窗口所有权串行运行，应用名与 `user://` 必须隔离，不根据历史 PID 猜测空闲。整株模型和缩图验证可用 Blender 后台完成，无需占用 Godot 窗口。当前仍处于资产验证阶段，尚未批准整页 runtime 3D 迁移。

### 11.4 当前下一项：同源构图与小标签身份可读性

集成会话已复用原 `harvest_sprite_pack.blend` 和已有长根胡萝卜/挖土盖，按冻结环境 rig 重渲单件；本线程维护整株源包、同源环境生成器与契约，集成会话负责唯一运行实现和正式树接入。两边不重复造株、篮、输入层或环境。

正式树接入已经完成，新的隔离快照实际覆盖16:9/4:3当前订单、手持、采空后和低动态，普通/密集显示尺寸按清单统一。触控探针包含正确/错误分拣、教程跟随、土豆挖开与采空回调寿命；不因此宣布全部玩法、设备或美术过关。下一轮继续沿同一profile整理构图和标签，不再等待已经结束的测试，不重跑旧灰屏作为通过证据。

10/03 小标签修订已完成：复用同源草莓8圈果体、7片莓叶、14颗原种子和冻结rig，扩大上肩、整理柔尖，把原来埋在果肉中的种子移到真实曲面；同一PNG继续供订单、场内作物和篮标使用。源包见 `assets/harvest_3d/source/strawberry_readability/`，GLB5844三角形、22网格、4材质，无纹理，默认回读异常0。24/32px原尺寸、普通/手持双比例经主会话及独立审图确认更容易与圆番茄区分；不将此称为儿童识别通过。

同时把果园旧192px深描边横木板缩为按成熟/未熟果实alpha定位的60–82px短枝，无新输入节点。较早组合快照 `heroes-qa-harvest-readable-final-vfsy2myx` 记录1706项真实触控、原规则通过，五尺寸85格实际可见、14页含普通/手持/低动态及果园摇动持货双比例。更新的 `heroes-qa-harvest-root-connected-v1-hc2l3s6u` 基于05:16源码，`touch.log` 为1698项、`completion.log` 为448项三订单检查；双比例截图内容门禁通过。两份快照的触控数属于各自输入与覆盖范围，不互相替代，SHA详见运行台账。

复看 `root-connected-v1` 截图后，连续局部带在4:3太淡，在16:9仍显成一段波浪色带，没有解决接地感。05:22源码已在实际 `HarvestMeadowBackdrop` 存在时停画整行带，只留单株接触影。其 `harvest-no-overlay-final-_0zdx63n` 截图-only复拍已被完整回归快照 `harvest-clean-ground-formal-cbh297xi` 取代；后者的 `harvest_action.gd` SHA 与当前树同为 `9a1cb6ced0cd546eaf86389deda9a99ca6e8fb777b2b8d9e20871d36f8a7c500`，39个记录输入哈希全部匹配。隔离快照22项运行均退出0：触控1698项、三单448项检查/68次送篮、果园回归通过；19张PNG中14张游戏页图逐张通过内容门禁，5档目录图逐格有可见内容。人工复看仍见中上部空场很大，持货路径横穿空场；这些结果确认当前互动回归和截图有效，不代表构图美术已完成。同源Godot 3D地表只作隔离候选对比，不接入正式页面或命中层。中央草场偏空仍开放。`tomato` 原数据仍是 `vegetable`，指向胡萝卜样本的蔬菜篮符合唯一解析器；不能因标签形似而改分拣规则。后续继续同源构图、轮廓与可读性整理，不新增类别或玩法。

若仍像贴图或缺少空间层级，只回到同一环境的构图/低频层次调整，不开新素材路线、不加玩法、不全局切换渲染器。整页美术过关后，才按Phase3既定边界评估可移除的Godot SubViewport试片。

### 11.5 Godot 同源 3D 地表全幅底层试片（2026-10-03，未通过美术门）

- 在 `tests/Harvest3DGroundPilot.tscn` 中加载正式源包已有的 `environment_refined/passive_environment.glb`，用 Godot 4.7.1 `GLTFDocument` 运行时读取，依照冻结环境相机设置正交投影；透明 `SubViewport` 放在真实 `HarvestAction` 的背景与作物之间。订单 HUD、`HarvestTarget`、`HarvestBasket`、gesture/path 及命中对象仍为正式 2D 节点，本轮没有改生产页面。
- 试片读取了地面网格的7345个原始顶点色。Godot 的首个生成材质未显示这些颜色，调试版因而白屏；仅在临时预览材质打开 `vertex_color_use_as_albedo` 后才恢复实际草绿色。没有改冻结GLB或运行素材。v3 的 16:9/4:3 普通及真实草莓持货四图分别在 `heroes-qa-harvest-3d-ground-pilot-16x9-v3-ajfdr58e`、`...4x3-5_jow0l_`、`...16x9-held-pwhxp1gs`、`...4x3-held-u_8ghb0i`；四份 `QASession` 日志均退出0、图像有内容且无Godot错误。图像留在 `/private/tmp/heroes-harvest-3d-pilot.DOX9WU/`。
- v3 的地面仍是大面积空草场，色调过绿过暗，远处边缘比原水粉场景硬；目标根部继续依赖原有小椭圆接触影。16:9 草地空处的抽样中位色约从当前正式背景 `(153,182,132)` 变为 `(115,168,61)`，偏色明显。v4 的透明羽化试图软化交界，却生成宽蓝色光带、深绿草地，仍未收住中央空场。v4 截图：`ground-16x9-normal-v4.png`。这条“全幅 3D 地面 + 2D 作物叠放”路线判定**未通过视觉验收，不接入正式页面**；不要再靠全屏材质调色或羽化反复修同一缺陷。
- 下一轮不再做“整幅3D地面、2D作物贴上去”，也不调更多环境色。只在隔离场景把同profile环境 GLB 与已有同源植株/果实/篮子模型放进同一正交视图，再用现有 `HarvestTarget` 的屏幕锚点定位可见模型；状态、手势、命中、订单及 `HarvestBasket` 仍由正式2D组件拥有。先取模型素材已有的代表作物做普通/持货、16:9/4:3对照，验证根部连续、轮廓仍能被儿童理解且不遮挡触控目标；如需给每一种作物新造模型或需要第二套命中/排序系统才能成立，就停止该路线并保留当前2.5D。

### 11.6 Godot 实页目标叠加与菜床映射试片（2026-10-03，未通过美术门）

- 新隔离探针 `tests/Harvest3DIntegratedPilot.tscn` 复用真实 `HarvestAction`、14 个 `HarvestTarget` 和两个 `HarvestBasket`，仅把目标、番茄株身与篮子的显示内容替换成已有 GLB；点按区域、订单、成熟态和篮子规则仍归原2D组件。没有改生产页面或全局渲染器。
- `whole_plant_scene.glb` 能由 Godot 4.7.1 导入，并从场景中只保留其独立 `GardenBed` 网格，避免把固定12颗番茄误当作动态目标。5+5+4测试排布下 16:9/4:3 普通态截图分别为 [`raised-bed-5x3-16x9.png`](/private/tmp/heroes-harvest-3d-integrated-20261003/raised-bed-5x3-16x9.png)、[`raised-bed-5x3-4x3.png`](/private/tmp/heroes-harvest-3d-integrated-20261003/raised-bed-5x3-4x3.png)；Godot退出0，截图有效，日志无运行错误。这只证明运行时导入与图像生成成功，不是视觉验收。
- 固定菜床不符合当前屏幕空间目标排布：斜向椭圆土面与果实行轴不同，部分作物在床缘外、部分被床面压住；视觉读成草地上放了一块大土盘。隔离版再把目标投影到床面后，[`raised-bed-mapped-16x9.png`](/private/tmp/heroes-harvest-3d-integrated-20261003/raised-bed-mapped-16x9.png) 中仍有果实只露出叶顶/果顶、番茄根部和屏幕热区错位、局部阴影过重。映射本身因此也判失败，不以调缩放/高度掩盖坐标和遮挡问题。
- **结论：**弃用固定整块床体与现有自由目标网格的拼接，不接入丰收正式页；不继续微调该床模型。源GLB保留为造型参考。现有 Godot 内的3D模型层只适合继续做非交互、可删的局部试片。若要追求真正完整的3D农场，需另立“统一三维槽位 + 投影同步二维热区”的工作，先解决作物种类、成熟态、层级、4:3/16:9、安全热区，再讨论 Three.js 或更换引擎；本项目当前不需要为这张页另加 Three.js。
- 本轮接续方向限定为两选一：其一，继续用现有 Godot GLB/正交相机展示局部3D对象，保留二维舞台并把3D模型锚点/短接地影作为一个整体评审；其二，若必须使用整块3D菜床，则先在纯原型中把目标点位设计成菜床上的真实种植槽，再让二维热区从同一投影坐标生成。二者必须与现有组件复用；若需要第二份采摘状态或另一套输入/篮子规则，立即停止。

### 11.7 同屏单株 GLB + 局部接触阴影候选（2026-10-03，候选交互验证通过；整页视觉仍未通过）

- 首张 `shadow-catcher-tomato-16x9.png` 不能作为视觉结论：当时 pilot 只替换一株番茄的株身，却把其他目标果实也全部替换为 GLB，产生了脱离株身的果实；该截图判定为**测试夹具无效**，不用于否定资产。修正后的 local receiver 模式只替换一个成熟番茄的株身与对应果实，其他作物、菜畦、篮子和水粉底图保持现状。
- 新增测试专用 `tests/harvest_shadow_receiver.gdshader`，以局部透明平面接收现有 3D 植株阴影；不是全幅地面，也没有加入正式页面。 Godot 4.7.1 GL Compatibility 在隔离 `user://` 的 `tests/qa_run.py` 副本中实际渲染，16:9（1280×720）与4:3（960×720）均退出0、截图有内容，日志无脚本/渲染错误。屏幕映射现通过目标节点的全局画布变换应用局部 anchor，普通态两比例的株根投影 x=705.5、果实锚点 x=710.4，偏差约5px且稳定；原先 16:9 偏差由 pilot 把局部偏移直接加到全局画布点造成，已在测试层修正。
- 普通态可见截图：[`shadow-catcher-tomato-fixed-16x9.png`](/private/tmp/heroes-harvest-3d-integrated-20261003/shadow-catcher-tomato-fixed-16x9.png)、[`shadow-catcher-tomato-fixed-4x3.png`](/private/tmp/heroes-harvest-3d-integrated-20261003/shadow-catcher-tomato-fixed-4x3.png)。审阅结论是**通过进入持货态验证**：单株主体和果实属于同一可读目标，接收面没有矩形边或跨株色带；不过根影仍是较简单的小椭圆，尚不足以证明整页去贴纸感。
- 真实手势严格断言拿起的节点就是 `_single_tomato_target`，而非只断言“手里有某个目标”。测试层按持货后的实际 GLB 锚点放置果实，局部阴影则留在原生长点；透明的 2D 原株身只提供路线障碍几何，GLB 仍是 pilot 中唯一可见株身。不新增命中/状态系统。
- 该试片仍未接入正式页面，也未替换全作物资产。局部接收阴影没有矩形边或跨株色带，但根影仍是较简单的小椭圆；候选图通过只说明可继续做局部对象验证，不能证明整页去贴纸感。
- `shadow_to_opacity` 的用法与能力边界按 [Godot 4.7 空间着色器文档](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)核对；兼容渲染器是否有良好画面仍以本项目实图为准，不以文档特性说明代替视觉通过。

### 11.8 安全网格 + 持货指引锚点迭代（2026-10-03，双比例回归通过）

- 目标总数不再横向挤成一条带：16:9 下 5–12 个目标优先 2 行、14/18 个目标 3 行；4:3 下 5/6 个目标 2 行、8–12 个 3 行、14/18 个 4 行。各行居中并均衡分配，点位仍带确定性轻微抖动，中心距不得低于 92px。屏幕安全带上缘取 `max(34%屏高, HUD底边204 + 最大触控半径 + 24px)`，下缘到 81% 屏高；篮列和原始触控半径不改。
- 截图均来自正式 `HarvestAction.tscn`，用隔离 QA 项目生成：[`harvest02-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/harvest02-16x9.png)、[`harvest02-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/harvest02-4x3.png)、[`harvest01-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/harvest01-16x9.png)、[`harvest01-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/harvest01-4x3.png)。18目标多订单关卡第一单的对照图为 [`harvest08-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/harvest08-16x9.png)、[`harvest08-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/harvest08-4x3.png)。独立复核结论：HUD、篮列和安全通道没有明显碰撞；小订单 5 株呈 3+2 分布，正常；多订单的未来目标隐藏后会留下空位，这是固定点位跨订单复用的现状，本轮不动态搬动剩余植株/根影。
- 真实持货截图 [`held-route-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/held-route-16x9.png)、[`held-route-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/held-route-4x3.png) 来自正式 `HarvestAction`。`TutorialDirector.follow_look_target()` 增加默认零偏移的可复用锚点；HarvestAction 用果实实际 alpha bounds 中心同时规划路线和跟随光圈，并按持货后的落点预先避开植株。修复前的缺陷是路线在抬升开始前按逻辑根点计算，而可见 trace 首点随后跟着果实移动，导致线穿过株叶。现篮口终点只影响教学路线，`_basket_for()`、真实篮子中心和命中半径未变。
- 同一新锚点后的隔离 GLB 持货候选 [`pilot-held-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-held-16x9.png)、[`pilot-held-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-held-4x3.png) 均正常渲染（单株身、单果实、一个局部阴影接收器）。该画面仍使用测试里的鲜绿 3D 草地，和正式 UI/2D作物语言不统一，番茄也偏小，所以只验证锚点与局部交互，不晋升正式页面。
- `HarvestProbe` 双比例网格纯逻辑断言通过；`HarvestTouchProbe` 在 1280×720 与 1024×768 窗口（4:3 对应 1280×960 画布）均通过，1713 条拇指动作问题；所有正式页面截图均 `CONTENT PASSED`；`tools_check.py` 0 errors、204 warnings；`git diff --check` 干净。Godot 4.7.1 Compatibility 与 `tests/qa_run.py` 隔离用户数据验证，未关闭用户拥有的 Godot 进程。
- **当前判断：**布局与操作反馈这轮通过；整体绿底仍是刻意保持的连续水彩草地，而非新增整幅贴图。多订单页的空位可在后续有订单换阶段动效时再评估；单株 GLB 仍只留在隔离 pilot 中，正式页面继续复用现有 2D目标、菜篮、手势和订单组件。后续 3D 方向继续按下面的候选门槛推进，不把当前局部通过当作整页完成。
- `shadow_to_opacity` 的用法与能力边界按 [Godot 4.7 空间着色器文档](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)核对；兼容渲染器是否有良好画面仍以本项目实图为准，不以文档特性说明代替视觉通过。

### 11.9 持货果实避障收敛 + 3D候选门槛复查（2026-10-03）

- 原持货避障用 `held_art_radius()` 扩成正方形碰撞范围，并允许横向移动到 ±128px；对有透明画布的3D渲染果实，这会把轻微 alpha 边界接触当成很大的实体冲突。现在统一按实际纹理 alpha bounds 预测 `HarvestTarget.HELD_SCALE` 后的可见外框，与植株、其他作物、篮子外框计算重叠；横移以 16px 递增、由 48px 上限生成候选，并为位移付出与果实尺寸相关的代价。`HarvestTarget` 仍是唯一持货状态和触控目标，篮子解析与触控半径不变。
- 触控探针新增真实番茄持货记录：打印 held-fruit 与 rooted-plant alpha bounds，并从 HarvestAction 脚本常量读取上限做断言。双窗口形状 1280×720、1024×768（逻辑视口 1280×720、1280×960）通过，共 1715 项拇指动作检查；本次选中的两颗番茄都无需横移（x=0）。`tools_check.py` 0 errors/204 warnings，`git diff --check` 通过。
- 更新后的隔离 3D held 候选截图：[`pilot-held-r6-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-held-r6-16x9.png)、[`pilot-held-r6-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-held-r6-4x3.png)。3D 果实与手持提示锚点贴合且运行无错误，但候选地表仍显荧绿、单果相对株身偏小；这项只通过“投影/交互锚点”检查，**视觉仍未过门，不接入正式页**。
- 后续 3D 迭代不是再叠一张 GLB 到现有 2D 草地：先为审核过的可运行模型建立正常 Godot import/runtime 路径，再验证屏幕舞台的 3D 地形、槽位、株身与采摘果实同场景融合；所有目标仍以既有 `HarvestTarget` 做 hit/state 代理、篮子仍用 `HarvestBasket` 做唯一解析。需覆盖全作物与成熟态，并在 16:9/4:3 实页持货截图、触控回归和视觉对照均通过后，才把 3D presenter 挂入正式页面。

### 11.10 可运行作物目录 + 双比例真实投篮试片（2026-10-03，交互通过；整页视觉未通过）

- 将同源候选模型通过 Godot 标准 `PackedScene` / `ResourceLoader` 导入路径加载，而非把 Blender 预览或单张渲染图误当 runtime 成果。番茄和草莓模型只作为隔离 pilot 的可见层；订单、成熟态、hit-test、手势与正确篮子仍完全由现有 `HarvestAction`、`HarvestTarget`、`HarvestBasket` 驱动。为保留其余目标在手持路径规划中的障碍边界，原 2D 作物纹理层保持 `visible=true`，仅调为透明；不能把目标节点隐藏来“清理”画面，否则路线规划会丢失这些代理的可见 bounds。
- 被采摘目标释放后，pilot 先对原始 Variant 引用做 `is_instance_valid()`，再进行 `Node2D` 类型转换；释放的 3D fruit presenter 会清理，不再让旧目标引用产生每帧 `Trying to cast a freed object`。旧 QA 快照即使打印过投篮成功，也因脚本错误门禁而作废；只采纳使用唯一新运行名重跑的结果。
- runtime 导入 field 在原有阴影接收行为下出现长黑色条纹。试片仅对连续地表网格使用局部 `shadows_disabled` shader render mode，保留原有明暗与光照而不接收投影；条纹在 Godot 4.7.1 Compatibility 实际截图中消失。该 shader 仍位于 tests，不改全局渲染器，也未被批准用于正式场景；语义参考 [Godot 4.7 空间着色器文档](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)。
- 两比例均通过隔离 `tests/qa_run.py` 对原生触摸事件的真实分发：持起草莓，再投向正确的水果篮。16:9（窗口实测 1364×768）和 4:3（1024×768）日志均为 `delivery=true basket=fruit picked={"strawberry": 1}`、`content=true save=OK`，run/import exit 0 且无脚本错误。投篮后订单从 `0/4` 到 `1/4`，篮上已有成功标记；这证明复用的目标、手势、篮子解析和订单回调仍连通，不代表儿童可用性或整页美术通过。
- 截图证据：普通态 [`pilot-runtime-catalog-r14-shadow-disabled-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-catalog-r14-shadow-disabled-16x9.png)、[`pilot-runtime-catalog-r14-shadow-disabled-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-catalog-r14-shadow-disabled-4x3.png)；持货态 [`pilot-runtime-catalog-r14-held-proxies-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-catalog-r14-held-proxies-16x9.png)、[`pilot-runtime-catalog-r14-held-proxies-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-catalog-r14-held-proxies-4x3.png)；真实投篮完成态 [`pilot-runtime-catalog-r14-held-delivery-16x9-fixed.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-catalog-r14-held-delivery-16x9-fixed.png)、[`pilot-runtime-catalog-r14-held-delivery-4x3-fixed.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-catalog-r14-held-delivery-4x3-fixed.png)。
- **视觉结论：不晋升。** 双比例图仍是单一低细节绿地上稀疏摆放 3D 果实/篮子，背景空间空旷，和订单 HUD 及部分 2D 株身的表达语言不一致；局部果实可读性、投影锚点和入篮反馈虽可用，整体仍像分层贴图试片。不得以本轮“真实投篮成功”替代美术验收，不扩大到所有作物，也不挂到正式页面。
- 下一步只推进同场景的局部舞台整合：继续复用已有环境、株身、果实和篮子资产，先做一屏密度与尺度的对照，让可交互目标在视觉上表现为同一块连续、有种植槽节奏的场景；先补齐双比例普通/持货/实际入篮截图，再评审是否解决空场与 2D/3D 断层。若需要为不同作物临时拼出第二套状态或命中，或只能靠加大量装饰填空，则停止 runtime 3D 路线并回到统一风格的 2.5D 资产呈现。

### 11.11 单 World 地形锚点 + 真触控跟随（2026-10-03，交互双比例通过；美术不晋升）

- 仅修改隔离探针 `tests/harvest_3d_integrated_pilot.gd` 和候选场地 shader；正式 `HarvestAction`、`HarvestTarget`、`HarvestBasket`、原有 hit proxy、篮子解析和 HUD 均未替换。环境、作物/株身、篮子试片共用一个 `World3D`、`SubViewport` 与正交相机；19 次屏幕射线三角相交全部命中同一连续草地网格（`misses=0`），不再把斜坡作物压在固定 `y=0` 平面。空闲模型缓存地形点；采摘后则沿相机屏幕平面跟随既有 2D target 位移，避免 3D 果实在拿起/送篮时重新贴回地面。此为 presenter 原型，不增加第二套状态、手势或命中。
- 阴影 A/B：R20 开启地面接收后虽有真实动态投影，但硬黑长影与篮筐格栅影反而强调悬浮，因此拒绝。R21/R22 只在测试候选启用柔化、低不透明度的地面接收材质，关闭场地自身及篮子投影，并提高直射角度；接地关系有所改善，但仍不是可晋级的美术方案。`tests/harvest_field_grade.gdshader`（原 `shadows_disabled`）供既有试片保留；新 `tests/harvest_field_receive.gdshader` 仅由试片的 `PILOT_RECEIVE_FIELD_SHADOWS=1` 分支选用。
- 番茄挂点 A/B：旧 `TOMATO_SLOT_HEIGHT=1.42` 与按地形屏幕点追加的 source-pixel `ground_offset` 叠高，截图中果实高于枝叶。候选改为可由环境变量覆写；同 rig 16:9 对照取 `PILOT_TOMATO_SLOT_HEIGHT=0.55` 后，三颗动态果实均回到对应藤尖附近。不要将这个试片值视为所有作物/正式运行材质的通用高度；应按源模型的 pivot 与 `HarvestVisualArt` 槽位逐类映射。
- 隔离运行使用 Godot 4.7.1 GL Compatibility、正常窗口渲染和独立 `user://`；各次 import/run 均退出0，截图 `content=true save=OK`，未匹配脚本或解析错误。相同视觉参数已覆盖：16:9 普通 [`pilot-runtime-shared-ground-r22-tomato-anchor-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-shared-ground-r22-tomato-anchor-16x9.png)、持货 [`pilot-runtime-shared-ground-r23-held-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-shared-ground-r23-held-16x9.png)、真实入篮 [`pilot-runtime-shared-ground-r23-delivery-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-shared-ground-r23-delivery-16x9.png)；4:3 普通 [`pilot-runtime-shared-ground-r23-normal-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-shared-ground-r23-normal-4x3.png)、持货 [`pilot-runtime-shared-ground-r23-held-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-shared-ground-r23-held-4x3.png)、真实入篮 [`pilot-runtime-shared-ground-r23-delivery-4x3.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-shared-ground-r23-delivery-4x3.png)。两比例原生触摸结果均为 `delivery=true basket=fruit picked={"strawberry":1}`；HUD 从 `0/4` 到 `1/4`，篮上的正确反馈出现。持货图中的果实与原 Halo/教学路线同步，证明屏幕映射和篮子事务连通，不证明儿童可用性或整页 3D 美术过关。
- `tools_check.py` 最终为 `0 errors, 204 warnings`，warning 数与仓库既有项目警告相同；`git diff --check` 通过。试片中几处已有土壤候选数组显式标注 `Vector3`，修复了静态检查推断报错，不改变渲染或玩法。
- **视觉结论：继续不晋升。** 番茄连接关系比前版自然，接地阴影也比硬黑影克制；但背景仍是大面积空绿坡，14个目标稀疏散落，草莓仍是没有株体的单颗果实，顶部订单 UI 与物件渲染语言分离，4:3 空场尤明显。不能靠给每颗果实铺一个椭圆 `soil_grass_patch` 来伪造菜垄：会重现独立贴片。当前没有已审核的草莓株身 GLB（`plants/` 只有 `tomato.json`），也没有与此自由目标排布匹配的连续种植床。
- 后续只沿两件事验证：① 用实际果实槽位/alpha bounds 让所有模型与原 2D 代理锚点逐作物对齐，并保留原代理用于路线边界；② 在已存在同源模型基础上做一个连续、能容纳现有自由目标网格的种植行舞台，不复用固定整床，也不重复绘制椭圆土块。若找不到能满足目标屏幕点位的连续床资产，或草莓必须另造株体/状态系统才能理解，就停在当前 2.5D/局部3D候选；不要挂正式页面，不切 Three.js，也不改变输入和订单。

### 11.12 地形锚定连续行 A/B（2026-10-03，几何命中通过；美术否决）

- 在 `tests/harvest_3d_integrated_pilot.gd` 中首次实际启用原先未调用的连续行候选，并用共享场景地形射线取得根部锚点。r24 首跑因测试脚本内层循环缩进错误未加载；修正后以唯一 run name 重跑，r24b 正常渲染。该修复仅在隔离 pilot，不影响正式场景。
- r24b [`pilot-runtime-shared-ground-r24b-terrain-soil-rows-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-shared-ground-r24b-terrain-soil-rows-16x9.png) 中，三行都贴合地形采样（33 hits / 0 misses），但线条仍读成很窄的弯曲车辙，未支撑草莓根部或形成菜畦节奏。
- r25 将同一批根点压到平均屏幕行高，让行带顺地形而不随单株高低蛇形，并将半宽约加倍、轻微抬高中心。隔离 Godot 4.7.1 QA 成功退出；`content=true save=OK`、三行、47 hits / 0 misses、无脚本错误。截图 [`pilot-runtime-shared-ground-r25-wide-level-rows-16x9.png`](/private/tmp/heroes-harvest-layout-20261003/pilot-runtime-shared-ground-r25-wide-level-rows-16x9.png) 仍呈棋盘状半透明带/平面叠片感，明显没有形成真实床面，也没有改善大面积空场。4:3 未扩测，因为 16:9 美术门已失败。
- **结论：**否决连续透明土行 overlay 路线；不再调宽度、颜色或透明度，不接正式页。保持土行代码在 test-only pilot 作为被否决的对照，不挪入 production。根因尚未确认；截图中的周期性明暗可能涉及透明面与地面深度/三角插值，但这只是待证假设，不作为事实。
- 下一步回到可拆的真正场景对象：先只验证一个草莓株身（低矮叶冠、单个可视果槽，单果继续复用现有 GLB）与连续床体同处一个正交 3D 场景，原 `HarvestTarget` 仍独占交互/状态，现有篮子和 HUD 不变。仓库当前没有已审核的草莓株身模型，也没有与自由目标网格匹配的床体；若不能复用源资产生成一个局部原型，就向用户提供明确的生成素材提示词，而不拿透明几何线条继续伪装床面。只有 16:9 单行普通/持货通过，再考虑双比例和真实投篮；否则停止 runtime 3D 页面路线，保留已验证的 2.5D/局部 3D 资产，不改生产页。

### 11.13 土床网格否决后，改为现有地形的程序化土色试片（2026-10-03，双比例覆盖与真实入篮通过；仍是候选）

- r2/r3/r4 独立土床 GLB 能覆盖一部分根点，但 4:3 会露点或被地形遮住；r4 最大 padding 后仍显成大平台。将 1,153 个土床顶点逐点贴到真实坡面虽达到可见根点 14/14，却把远坡起伏带成巨大、扭曲的棕灰地毯，**否决“整块 bed mesh 变形贴地”路线**。相关失败图：[`pilot-runtime-strawberry-bed-r4-maxpad-4x3.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-bed-r4-maxpad-4x3.png)、[`pilot-runtime-strawberry-bed-r5-conform-maxpad-4x3.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-bed-r5-conform-maxpad-4x3.png)。对应候选留在 source-only 目录，不进入 runtime 资产或正式页面。
- 当前最有希望的候选不再加几何床板，而是在隔离 pilot 复用既有 `harvest_field_grade.gdshader`，按 14 个真实 `HarvestTarget` 根点映射一个统一、低对比、低频不规则的 soil mask；shader 使用原地形顶点色与 world position，植株继续落在原连续 3D 坡面。mask 内使用浅暖棕色和克制噪声，避免恢复 r1 深色贴花或 r2 黄绿色阴影感。试片开关为 `PILOT_FIELD_SOIL_PLOT=1`，默认关闭，不影响其它截图探针。
- r3 的 16:9（1280×720）与 4:3（960×720）普通截图分别为 [`pilot-runtime-strawberry-soilplot-r3-16x9.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r3-16x9.png)、[`pilot-runtime-strawberry-soilplot-r3-4x3.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r3-4x3.png)。两个比例均为 14/14 根点处于土色 mask 内；材质不改变 terrain mesh，不再有床边遮挡或悬空根点。严格根点门禁下的成功入篮图为 [`pilot-runtime-strawberry-soilplot-r3-delivery-strict-16x9.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r3-delivery-strict-16x9.png)、[`pilot-runtime-strawberry-soilplot-r3-delivery-strict-4x3.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r3-delivery-strict-4x3.png)：均 `roots inside=14/14`、34 terrain ray hits/0 misses；既有 `HarvestTarget` 拿起草莓，`HarvestBasket` 正确入篮，日志 `delivery=true basket=fruit picked={"strawberry":1}`，HUD 0/4→1/4，株身留场、单果消失。两次 import/run 退出码均为0，无脚本/解析错误。
- **判断：**这是当前最稳的“双比例根点覆盖 + 交互”结构，视觉只晋级到**候选**，不等于页面签收：仍有一整块较大的土色域、作物间距偏疏，HUD/3D 美术语言未统一；4:3 画面仍显空。订单、成熟态、手势、route bounds、篮子 hit-test 与存档全由原 2D 系统拥有，本轮只替换试片显示材质，不把 GLB、shader 或第二套状态接到正式页面。
- 下一步先冻结 r3 颜色和边缘，不做大幅度继续调色；以当前双比例普通/持货/入篮截图为基线，只允许小步尝试减少空白土域或加入极轻的耕作层次，并要求严格 14/14 mask 覆盖、真实投篮和 `tools_check.py` 回归。正式页仍使用 `HarvestVisualArt.crop_texture()` 的 PNG；接入前必须另行打通按作物/成熟态的 presenter 映射、持货半径/alpha bounds、采后残株与正式页面的 UI 配合，不得把本试片描述为 3D 页面已完成。

### 11.14 减少共享地形土色域的留白 A/B（2026-10-03，覆盖与投篮通过；美术仍不晋级）

- 以 r3 当前参数作同代码基线，仅将 `PILOT_SOIL_PLOT_PADDING_X/Y` 从 `76/56` 降至 `60/48`。两组均保留 `PILOT_CROP_CATALOG=1`、同一株身 GLB、plant tint、body height、番茄挂点与相机；严格根点门禁常开，避免把作物资源/灯光的变化误记成土域改善。
- 更激进的 `54/40` 在 16:9 只覆盖 `13/14` 根点，按门禁拒绝，没有作为截图或候选。`60/48` 的四份隔离 Godot 4.7.1 截图均 `content=true save=OK`、34 次地形射线命中 / 0 漏点，14/14 根点在 shader mask 内；真实采摘投篮日志均为 `delivery=true basket=fruit picked={ "strawberry": 1 }`：
  - 16:9 普通/入篮：[`soilplot-r4-clean-16x9.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r4-clean-16x9.png)、[`soilplot-r4-clean-delivery-16x9.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r4-clean-delivery-16x9.png)
  - 4:3 普通/入篮：[`soilplot-r4-clean-4x3.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r4-clean-4x3.png)、[`soilplot-r4-clean-delivery-4x3.png`](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r4-clean-delivery-4x3.png)
- 与当前代码同源重拍的 `76/56` 基线比较，`60/48` 的土色范围仅小幅收紧（16:9 bounds `10.24×14.18m → 9.78×13.66m`；4:3 `8.18×17.85m → 7.72×17.33m`）。人工复看确认边缘略收，根点没有贴边，但中央仍是一整片近乎均匀的棕色地形；这是可复现的微改进，不足以解决空场或“土色块像贴片”的核心问题。
- **结论：**保留 `60/48` 作为隔离对照参数，不改变 shader 默认值、不改正式 `HarvestAction`，也不把土色 mask 晋升到产品页。下一步若继续，仅在同一 pilot 上验证非常轻的耕作层次是否能打散单色土域；必须沿用相同模型配置、双比例 `14/14` 根点门禁和真实入篮回归。若条纹读成车辙/棋盘或变化仍不明显，则停止该 mask 微调，回到同源完整场景资产，而非继续扩大 overlay。

### 11.15 浅耕纹理 A/B：视觉门失败，停止 shader 微调（2026-10-03）

- 依照 §11.14 的限制，在隔离 pilot 的 `60/48` 土域内尝试低幅度方向性纹理（强度 `0.18`）；作物 GLB、成熟态、相机、背景、篮子位置及其他参数均与 r4 相同，不接入正式页面。
- 一份隔离快照串行完成 16:9/4:3 普通态与真实投篮态四次 Godot 4.7.1 运行，全部退出码 0：`content=true`、`save=OK`，`14/14` 根点处于土色 mask 内，地面射线 `34 hits / 0 misses`；投篮日志为 `delivery=true`、`basket=fruit`、`picked={"strawberry":1}`，两比例 HUD 均由 `0/4` 变为 `1/4`。
- 同源对照图：普通态 [r5 16:9](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r5-tillage-16x9.png)、[r5 4:3](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r5-tillage-4x3.png)；入篮态 [r5 16:9](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r5-tillage-delivery-16x9.png)、[r5 4:3](/tmp/heroes-harvest-layout-20261003/pilot-runtime-strawberry-soilplot-r5-tillage-delivery-4x3.png)。
- **美术判断：不通过。**与 r4 同源截图目视几乎没有可辨差别，土域仍是一整块棕色平面；增加方向噪声没有改善贴图感，继续增强容易变成条纹/车辙，收益不值得。
- **处理：**移除本轮 shader tillage uniform 与 pilot 参数，恢复纯地表色域 mask；保留 r5 证据图和日志作为否决记录。`60/48` 依旧仅是隔离实验参数，不晋级产品页。
- **下一轮方向：**停止调 mask 颜色、边缘和噪声，转为验证完整 3D 构图：适度收紧相机空场、放大并分层作物/篮子，或研究沿实际坡面生成窄而低的实体垄。实体地形必须能在多行/短行下保持根点余量、篮子安全区和接地阴影；不再尝试整块贴片/大床面变形。先做单个代表关卡与 16:9/4:3 失败可回退原景，再决定是否推进。

### 11.16 相机取景与果实倍率 A/B（2026-10-03，技术通过；只保留轻微倍率候选）

- **相机失败档：**同一共享场景下比较默认 width 18.488889 与 4:3 width 16.5、target_x 0.48。普通态及 zoom 入篮态都为 content=true、save=OK，14/14 根点在 mask 内、34 地面射线命中 / 0 漏点；入篮正确更新为 1/4。图：默认 [16:9](/tmp/heroes-harvest-layout-20261003/pilot-soilplot-camera-16x9-default.png)、[4:3](/tmp/heroes-harvest-layout-20261003/pilot-soilplot-camera-4x3-default.png)，收紧视野 [4:3 普通](/tmp/heroes-harvest-layout-20261003/pilot-soilplot-camera-4x3-zoom.png)、[4:3 入篮](/tmp/heroes-harvest-layout-20261003/pilot-soilplot-camera-4x3-zoom-delivery.png)。目视收益不足，地平线更高、背景土域更显眼；代码中模型按原二维锚点重新 fit 到目标像素高度，缩窄相机无法真正放大果实/篮子，因此已撤回相机 override。
- **1.20 倍果实档：**用现有 PILOT_FRUIT_SCALE 和 PILOT_TOMATO_FRUIT_SCALE，仅改变果实模型倍率；草莓株体 GLB、body height factor 1.50、灯光、相机、地形和土域参数保持一致。16:9/4:3 普通态与 1.20 入篮态六次隔离运行均通过 14/14 根点覆盖、34/34 地面射线、content/save 和真实送篮。目视果实更醒目，但草莓红果略压过叶冠，不选为首选。图：[16:9 基线](/tmp/heroes-harvest-layout-20261003/pilot-fruit-scale-baseline_16x9.png)、[16:9 1.20](/tmp/heroes-harvest-layout-20261003/pilot-fruit-scale-fruit120_16x9.png)、[4:3 基线](/tmp/heroes-harvest-layout-20261003/pilot-fruit-scale-baseline_4x3.png)、[4:3 1.20](/tmp/heroes-harvest-layout-20261003/pilot-fruit-scale-fruit120_4x3.png)、[1.20 入篮 4:3](/tmp/heroes-harvest-layout-20261003/pilot-fruit-scale-fruit120_delivery_4x3.png)。
- **1.10 倍平衡档：**相同单因素参数下补拍 16:9/4:3 普通态与入篮态四张图，全部同样通过；草莓和番茄仍更容易辨认，且果实与叶冠比例比 1.20 自然。图：[16:9](/tmp/heroes-harvest-layout-20261003/pilot-fruit-scale-110-16x9.png)、[4:3](/tmp/heroes-harvest-layout-20261003/pilot-fruit-scale-110-4x3.png)、[16:9 入篮](/tmp/heroes-harvest-layout-20261003/pilot-fruit-scale-110-delivery-16x9.png)、[4:3 入篮](/tmp/heroes-harvest-layout-20261003/pilot-fruit-scale-110-delivery-4x3.png)。
- **判断：**只把 1.10 记为隔离 pilot 的较平衡视觉候选；尚未更改 pilot 默认倍率或正式 HarvestTarget/HarvestVisualArt。较大的空绿坡、宽棕色 mask 与 2D HUD/3D 模型语言分离仍是整页否决项，倍率调整不能算页面升级或 3D 上线。
- 下一步与并行线协调：另一会话正在评估把现有草莓 rosette 株体复用为正式被动 plant PNG/布局元数据；本线暂不重复生成草莓株体。并行审计发现新株体 GLB 的果心投影与正式草莓 PNG 的果实中心相差明显，直接叠图可能造成果实悬空；因此本节 1.10 倍仅适用于 source-only r4 plant GLB + 当前 VisualArt 锚点的 pilot 组合，不能迁移为正式倍率。待对齐单果/叶冠锚点并完成普通/持货/入篮两比例截图后，再决定是否能在现有 HarvestVisualArt/HarvestTarget 视觉锚点内实现低风险渐进式替换。

### 11.17 土域开关与既有接地原型复核（2026-10-04，功能通过；全部美术否决）

- 沿用 11.16 相同的 source-only 草莓株体、1.10 倍果实、相机与场景，只切换 `PILOT_FIELD_SOIL_PLOT`。soil-on 的 16:9/4:3 均为 `content=true save=OK`、14/14 根点在 mask 内、34 次地面采样 0 漏点；soil-off 普通态双比例及实际入篮双比例也均 `content=true save=OK`、地面射线 0 漏点，送篮结果 `delivery=true basket=fruit picked={ "strawberry": 1 }`。off 日志为 19 次地面射线；on 的 34 次包含构建 mask 的额外根点采样，次数不同不代表地面覆盖退化。
- mask 对照图：开启 [16:9](/tmp/heroes-harvest-layout-20261003/soil-on-normal-16x9.png)、[4:3](/tmp/heroes-harvest-layout-20261003/soil-on-normal-4x3.png)；关闭 [16:9](/tmp/heroes-harvest-layout-20261003/soil-off-normal-16x9.png)、[4:3](/tmp/heroes-harvest-layout-20261003/soil-off-normal-4x3.png)，另有 off 实际入篮 [16:9](/tmp/heroes-harvest-layout-20261003/soil-off-delivery-16x9.png)、[4:3](/tmp/heroes-harvest-layout-20261003/soil-off-delivery-4x3.png)。目视：off 让地形更连续、更清爽，但作物根部显得浮在草坡；on 有接地感，棕色仍铺成一整片显眼的大贴片。二元开关两边都不能晋级。
- 复核 pilot 已有的三个局部候选，各拍 16:9/4:3 并通过 `content/save` 与地面 `misses=0`：14 个小土丘形成深色椭圆贴纸（[16:9](/tmp/heroes-harvest-layout-20261003/soil-mounds-16x9.png)、[4:3](/tmp/heroes-harvest-layout-20261003/soil-mounds-4x3.png)）；地表顶点染色形成 3/4 条极淡行带，视觉上难以辨认（[16:9](/tmp/heroes-harvest-layout-20261003/soil-vertex-rows-16x9.png)、[4:3](/tmp/heroes-harvest-layout-20261003/soil-vertex-rows-4x3.png)）；连续几何行垄形成 3/4 条直线棕条，读作地面栅条/车辙（[16:9](/tmp/heroes-harvest-layout-20261003/soil-geometry-rows-16x9.png)、[4:3](/tmp/heroes-harvest-layout-20261003/soil-geometry-rows-4x3.png)）。已有木框槽另有 3 行/4 行两比例对照并通过渲染及地面检查，但横木条穿过或切到作物，读作托盘/花箱而非连续菜地（[16:9](/tmp/heroes-harvest-layout-20261003/wood-beds-16x9.png)、[4:3](/tmp/heroes-harvest-layout-20261003/wood-beds-4x3.png)）。所有截图只来自隔离 QA 副本，没有改变 pilot 默认、正式页面、作物数据或用户存档。
- **决策：**停止调色、改透明度、加椭圆、直线行垄或木框参数；这些都只是地表贴片/装饰条，没有形成连贯的种植场景。下一次接地迭代必须是与现有连续坡地统一的低矮地形造型/美术资产，按真实 HarvestTarget 根点贴坡并留出草地间隙，避免遮挡命中点与篮子安全区；再以两个画幅普通态及真实入篮态复验。root-following 起伏土脊已在 §11.18 双比例验收并按美术门否决；不再平行制作同类屏幕空间土线，草莓株体与果实锚点未对齐前也不迁移被动果实候选。

### 11.18 根点跟随起伏土脊 A/B（2026-10-04，技术通过；美术否决）

- 并行线在独立 `QASession` 快照中，以真实目标根点作为起伏峰值、行间作为低谷，并将网格顶点按屏幕位置采样到共享场地表面。第一次运行仅因临时脚本 `Array.front/back()` 的 Variant 推断被警告门禁阻止；在隔离副本显式声明 `float` 后重跑成功，未改共享 pilot 或正式代码。
- 16:9/4:3 普通态与真实采摘态共四次 Godot 4.7.1 运行，全部 `content=true save=OK`。16:9 为 3 行、1712 地面射线命中/0 漏点；4:3 为 4 行、1685/0。两比例的触控采摘均 `delivery=true basket=fruit picked={ "strawberry": 1 }`，订单从 0/4 到 1/4。
- 四图：[16:9 普通](/tmp/heroes-harvest-root-ridges-20261004/root-follow-ridge-normal-16x9.png)、[4:3 普通](/tmp/heroes-harvest-root-ridges-20261004/root-follow-ridge-normal-4x3.png)、[16:9 入篮](/tmp/heroes-harvest-root-ridges-20261004/root-follow-ridge-delivery-16x9.png)、[4:3 入篮](/tmp/heroes-harvest-root-ridges-20261004/root-follow-ridge-delivery-4x3.png)。
- **美术结论：不晋级。**独立复看两比例仍只读成每行作物下方的细直棕线，峰谷高差在游戏实际屏幕尺寸中不可辨；根点命中与交互通过不能替代美术通过。不得把临时几何复制进共享 pilot 或正式页面。
- **阶段性收束：**mask、软土丘、顶点染色、透明土垄、木框和顺坡起伏垄均未解决“作物融入场景而非贴在坡面上”。暂停同一屏幕空间地表线条的程序化变体。下一轮转为整体场景资产/构图：让地形、作物、篮子和 UI 共享一个明确的微缩农场舞台与尺度层级；仍由现有 `HarvestTarget` 独占交互。若新舞台资产不能在 16:9/4:3 普通与真实入篮中同时保留根点清晰、作物间隙、篮子触达空间和一致画风，则继续留在隔离试片，不接正式页。

### 11.19 四行布局阶段目标均衡 A/B（2026-10-04，轻量行代价已采纳）

- **改动范围：**在 ownership swap 的既有成本中加入共显目标同行惩罚，仅对 A/B 验证过的 `harvest_08` 四行网格生效。成本按订单阶段的可见目标掩码计算；不把已采后仍保留的 passive body/root 当成目标。网格点、seed/RNG、THUMB_APART、触控半径、手势、篮区位置与投放规则均不变。`harvest_08` 在 4:3 形成四行、16:9 保持三行；其他可能形成四行的关卡（例如 `harvest_02` Brave）不受此改动影响，需单独做 A/B 和双比例验收后再纳入。
- **4:3 行计数（含石头）：**第一单从基线 [1,2,2,3] 改为 [2,2,2,2]；第二单从 [2,0,3,1] 改为 [2,1,2,1]；第三单从 [2,2,1,0] 改为 [1,1,2,1]。分配器只交换目标与固定槽位的归属；同一批槽位坐标完全保留，最近目标中心间距仍为 94.1px，种植边界及篮子障碍框不变。隔离日志记录的两组交换分别是首单 carrot ↔ 第三单 grape、第二单 wheat ↔ 第三单 grape。
- **16:9：**基线与候选 18 个目标的 owner/slot 映射逐项一致，阶段计数维持 [1,3,4]、[2,3,1]、[3,2,0]，最近目标中心间距维持 93.3px。候选截图：[普通态](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-ab-final-5o55b3he/qa_shots/candidate_normal_16x9_o0.png)、[持货态](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-ab-final-5o55b3he/qa_shots/candidate_held_16x9_o0.png)。
- **4:3 截图：**基线与候选普通态 [对照](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-ab-final-5o55b3he/qa_shots/baseline_normal_4x3_o0.png)、[候选普通态](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-ab-final-5o55b3he/qa_shots/candidate_normal_4x3_o0.png)；[候选持货态](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-ab-final-5o55b3he/qa_shots/candidate_held_4x3_o0.png)、[第二单](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-ab-final-5o55b3he/qa_shots/candidate_normal_4x3_o1.png)、[第三单](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-ab-final-5o55b3he/qa_shots/candidate_normal_4x3_o2.png)。目视复核未见作物被订单卡遮挡、目标互压或挤入篮区；首排目标与卡片仍有清晰间隔。4:3 的行分布更均匀，但草坡留白仍在，不能算整体场景美术完成。
- content/save 截图门禁通过，隔离 HarvestTouchProbe 的 1771 项检查通过；QA 锁已释放。前两次隔离补丁运行分别因临时 harness 补丁作用域/缩进错误而失败，错误截图为空白且未改共享源码；这是 harness 调试记录，不是产品回归。
- **收窄范围后的最终集成复验：**fresh `QASession` 的 [HarvestProbe](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-final-dzd2u31o/qa_logs/harvest_rules.log) 与 [HarvestTouchProbe](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-final-dzd2u31o/qa_logs/harvest_touch.log) 均通过，后者为 1779 项检查。该快照上的 h08 普通态已拍 16:9/4:3 三个订单阶段；代表图：[16:9 首单](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-final-dzd2u31o/qa_shots/h08_normal_16x9_o0.png)、[4:3 首单](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-final-dzd2u31o/qa_shots/h08_normal_4x3_o0.png)、[4:3 第二单](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-final-dzd2u31o/qa_shots/h08_normal_4x3_o1.png)、[4:3 第三单](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-final-dzd2u31o/qa_shots/h08_normal_4x3_o2.png)；[16:9 持货](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-final-dzd2u31o/qa_shots/h08_held_16x9.png)、[4:3 持货](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-final-dzd2u31o/qa_shots/h08_held_4x3.png) 与 [4:3 低动态](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-row-balance-final-dzd2u31o/qa_shots/h08_low_motion_4x3.png) 截图均通过内容/保存门禁；目视未见目标压住 HUD、彼此挤叠或侵入篮区。
- 实际触控送篮截图来自 `HarvestEmptyShot` 的 **harvest_07**，验证的是番茄送篮后株体仍留在田里的通用交互结果，不作为 h08 行布局证据：[16:9](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-delivery-final-0r8x5wby/qa_shots/harvest_07_delivery_16x9.png)、[4:3](/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-delivery-final-0r8x5wby/qa_shots/harvest_07_delivery_4x3.png)。两张独立快照的送篮 fixture 均显示 `HARVEST EMPTY SHOT PASSED`；16:9 帧中能看到篮子，4:3 帧中没有篮子，只能作逻辑/内容 smoke，不能作为 4:3 篮区可视性证据。篮区视觉检查只依据 h08 自己的普通态与持货态截图。
- **决定：**采纳轻量行代价作为构图修正；保留现有 ownership swap 上限及全部触控/几何规则。它只改善多阶段目标的纵向分布，不替代连续场景资产，也不解决全页空坡和 2D HUD/作物风格分离。
