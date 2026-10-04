# 丰收页面运行证据（2026-10-02）

本轮已接入布局、采摘动效互斥、固定输入锚、计时器和金色礼篮标识。10/03 后续已把同源环境、分件番茄、厚编织篮及松土盖接入正式树；正式快照规则/1584项触控和30张页面图已复核。本文保留各历史失败与旧快照边界；整体美术、目标设备及儿童识别仍未最终验收。

## 运行隔离

- QA 项目：`/private/tmp/heroes-harvest-runtime-20261002-no8_7pnv`。
- 应用名和自定义存档目录均为 `heroes-harvest-runtime-20261002-no8_7pnv`。
- 运行时确认的 `user://`：`/Users/xhzhou/Library/Application Support/heroes-harvest-runtime-20261002-no8_7pnv/`。
- 所有 Godot QA 实例串行运行，日志写入 QA 的 `qa_logs/`；单次截图上限20秒，探针上限45秒。旧空白 QA 实例73674已关闭；另一路径的空闲项目管理器66328随后也已正常退出。进程检测已覆盖 AppTranslocation 路径。

## 接入内容

- 三篮关在最终安全矩形内规划目标，保留92px最低中心间距。
- 密集排列的图片尺寸系数为0.8；触控半径和手势参数保持来自作物数据。
- 根部接地影按透明贴图地面附近的实际根幅生成，宽度48–86px，随目标显隐和采摘更新。
- 未接入此前未通过审美检查的整床土垫。
- 每个目标保留自身 sway/lift/bob/refuse Tween；快速送篮会取消未结束的 lift 及延迟 bob，避免两个动效同时写位置。
- 拒绝摇动只作用于目标下的 `HarvestTargetVisual` 显示节点，作物、土盖、手势提示和持货标记一起摇动；命中原点、半径、拿起和送篮路径保持稳定。重复拒绝及切换低动态效果都会复位显示偏移。
- 勇敢模式计时器位于右上 HUD，不再被订单夹遮住。
- 金色礼篮保留原样本标签，并增加透传输入的星标。

## 验证结果

- Godot 4.7.1，截图使用 OpenGL Compatibility / Apple M5 Pro。
- `HarvestProbe` 通过；`HarvestTouchProbe` 首轮1395项通过；独立控制候选在新快照 `/private/tmp/heroes-harvest-controls-20261002-0nwrxiaj` 以当前正式素材运行，1440项通过（24.8秒）。其中原有442项仍执行。
- 16:9窗口1280×720 → 游戏视口1280×720；4:3窗口1024×768 → 游戏视口1280×960。
- 新断言覆盖所有关卡的最终种植边界、触控半径、接地影显隐、三篮净空，以及作物中心和相邻中点本侧的命中。
- 正式树接入后 `tools_check.py`：0 errors、204 warnings；`git diff --check`通过。
- 控制快照 `HarvestProbe` 仍通过（0.5秒），1440项新断言包含即时/延后送篮动效互斥、计时器层级、金色礼篮样本和星标，以及丰收庆典18个总目标。
- 控制快照的5个源文件与正式接入文件逐项SHA一致。
- Godot正常退出时仍记录 ObjectDB/resource cleanup 警告；本次控制触控探针为16个ObjectDB/8个resource，规则探针为4/2。并行音频对照已证明 stop三player、清空stream并等待混音退出可消除告警，运行期没有随64次切换积累；现已接共用 `tests/probe_lifecycle.gd`，同一控制快照复跑1440项（26.3秒）及规则探针（1.3秒），两个日志均无ObjectDB/resource或脚本错误。产品AudioManager没有为此改动。
- 固定输入锚补丁在同一控制快照通过1486项（31.0秒）。新增真实输入覆盖重复未成熟拒绝、未完成挖土时土盖摇动、拿起尚未结束时投错篮、持货 bob 期间重复投错篮，以及随后正确送篮只结算一次。日志 `qa_logs/controls-refuse-pivot.log` 无 ObjectDB/resource 或脚本错误；目标和触控探针两文件与正式树 SHA 一致。

## 真实截图

路径均位于 `/private/tmp/heroes-harvest-runtime-20261002-no8_7pnv/qa_shots/`：

| 状态 | 16:9 | 4:3 |
| --- | --- | --- |
| 丰收庆典首单 | `final_18_16x9.png` | `final_18_4x3.png` |
| 丰收庆典订单2 | `order2-16x9.png` | `order2-4x3.png` |
| 丰收庆典订单3 | `order3-16x9.png` | `order3-4x3.png` |
| 成熟度辨认 | `decoys-16x9.png` | `decoys-4x3.png` |
| 多手势页面 | `gestures-16x9.png` | `gestures-4x3.png` |
| 真实输入拿起后的分拣 | `held_16x9.png` | `held-4x3.png` |

`18`指关卡种植总数。首单实际只显示当前订单的3个胡萝卜、4个草莓及石头；离线18株同屏合成不作为真实首屏证据。持货截图由 InputEventScreenTouch/Drag 完成采摘，并确认 `_in_hand != null`。


### 当前正式控制修复截图

快照 `/private/tmp/heroes-harvest-controls-20261002-0nwrxiaj/qa_shots/`：

| 状态 | 16:9 | 4:3 |
| --- | --- | --- |
| 勇敢模式金色目标 | `controls-golden-ready-16x9.png` | `controls-golden-ready-4x3.png` |
| 真实输入金色持货/低动态 | `controls-golden-held-16x9.png` | `controls-golden-held-4x3.png` |
| 固定输入锚后的土豆土盖 | `pivot-soil-cover-16x9.png` | `pivot-soil-cover-4x3.png` |
| 固定输入锚后的金色目标 | `pivot-golden-16x9.png` | `pivot-golden-4x3.png` |

土豆土盖截图暴露了尚未解决的美术问题：156×104px 深棕描边圆角覆盖层像卡片，相邻覆盖层交叠。它仍按现有挖土进度变淡与缩小，但不能作为最终造型验收；小松土丘的同源模型正在制作，仅作为被动显示候选。

### 整株候选（未接正式页面）

候选快照仍为 `/private/tmp/heroes-harvest-runtime-20261002-no8_7pnv`。分件探针1448项通过（28.9秒）：fruit Target是唯一输入对象，采摘/送篮后 passive body 和根影在field原位保留，未来订单同时隐藏果实和株身。重复1.13源缩放和缺失`visual_plant`元数据读取已修。

`plant-final-order2-*`、`plant-final-normal-*`、`plant-final-held-*` 和 `golden-star-held-*` 均为双比例真实PNG。`slots-order2-*`、`slots-order3-*`、`slots-held-*` 为随后6张真实复核图。候选在规划前为passive根影下收8px种植下界，篮子安全边界仍从实际 `_bed()` 推导；最多4次置换原slots，按相同订单可见部分、持续株身、实际PNG范围与固定篮组评分。1458项复跑通过（31.1秒）且日志无退出或脚本错误；119次布局初始化在M5Pro headless上median16.18ms、max45.77ms，未作为设备性能证明。真实双比例中原番茄/小麦穿插已消除，4:3根影下缘余量约30px。低模前景与水粉底景的材质落差也仍未通过整页美术验收。这批图只证明分件和输入链可运行。

同一冻结素材候选接入固定输入锚后通过1504项（36.4秒），日志 `qa_logs/plant-refuse-pivot.log` 无退出或脚本错误。主资产对话后续产出的新模型法线、同源空间及新渲染 profile 未覆盖这次快照；必须放入下一份新快照，在真实订单和持货状态重新验收整页。

## 当前正式验证输入 SHA-256

下面 SHA 为固定输入锚验证时的历史输入；后续回调寿命及持货引导修复须按新快照重新记录，不能套用旧通过结果。

- `scripts/minigames/harvest_action.gd`: `1f9c14696f34166e8e5c83122364674fe61525c820652b5d4d4dd82959ce546c`
- `scripts/harvest/harvest_target.gd`: `fc9455f9829bfcd6d20393c8ca5896d731551d95c1f82ba5610ea4ddddfdb677`
- `scripts/harvest/harvest_basket.gd`: `95d7136c0d42d4b899d4f1a35360d0a526594e47a309fe0e7e7b64a983070799`
- `scripts/harvest/harvest_visual_art.gd`: `b358e553891e6bce111ea1ce84ba7d5d33f3517df2b1649b44dd9a0f35fcb2ac`
- `scripts/ui/juice.gd`: `9b2aaefa3154e4d627e9a2dbd59707e700accec1cafc56af76cd362feb1749be`
- `tests/harvest_touch_probe.gd`: `7b009adbc051f22bef7145fc3075722682626ea248addb56df279215200821ef`
- `tests/harvest_probe.gd`: `7df92e2e36aec1ddfd795aa289a2200b75e361715bc07bf4c634eeba90b05b80`
- `tests/probe_lifecycle.gd`: `d180f17731080253507a7c62ca3eaef5faebeaf08aa3b361c1af6c0e1e17e934`

## 同源渲染实际页面复核

新独立快照为 `/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-unified-art-gu8i3d7h`。17种单件和松土盖按冻结 `4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512` Blend 的实际相机、Sun及两个Area灯、World和Standard显示设置重渲。正常作物基准69.23077px/m，株身102.115385、密集81.692308；土盖使用实际alpha宽度拟合117/93.6px，无额外脚本或输入。

- 20张真实双比例图包括普通、三订单、埋土、真实挖开、真实持货、金色低动态、成熟度干扰和采空后株身。
- 新土盖真实拖动断言覆盖1/3挖开时透明度/缩放、未采摘/未持货、松手复原，以及完整挖开一次送篮。完整触控探针1526项通过（38.0秒），规则探针通过（1.3秒），两探针日志干净。
- 本轮整页仍未通过：草地与天空过平、土盖与薯体识别弱、普通持货仍贴株顶且早期分篮引导圈停在旧位置。独立审图与主模型会话确认这些问题，不能以触控探针通过替代美术验收。
- 采空低动态图虽成功保存、断言通过，两份日志各有2次 `Lambda capture at index 0 was freed`。该条路径记为失败，保留原快照日志。

### 连续送篮回调寿命复验

错误来自低动态篮口勾号被下一次送篮替换后，旧SceneTreeTimer仍捕获已释放Node。正式树及候选改为勾号自身拥有Tween，只绑定整数实例ID；替换或离页会结束其寿命。顾客低动态爱心也改为自身Tween，避免订单刷新后遗留相同引用。

独立复验快照 `/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-receipt-3mu34ncq`：34项真实双比例回归通过（5.9秒），覆盖连续三次实际送篮、旧勾号释放、最后勾号过期与未结束时离页；随后双比例真实采空截图通过（3.0/2.9秒）。三份日志扫描 `ERROR:`、脚本错误、ObjectDB及资源退出告警均为零。该复验只冻结旧持货反馈和旧候选美术，用于确认勾号回调修复；完整新控制与美术仍需下一份快照。

### 当前正式控制的完整新快照

`/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-final-controls-cymjmk1g` 使用严格运行错误检查的新runner `f49e0364a2a449e4923a9b262434f329785abe18e2feea234153f97bc2347327`，不再允许 `PASSED` 覆盖运行期 `ERROR:`。

- 完整触控1536项通过（36.4秒），规则探针通过（1.3秒），所有日志无运行错误、脚本错误或退出残留。
- 新正常动态的分拣引导从LOOK开始显示同一个 `MotionTrace`，小环按目标实际alpha边界设置，LOOK跟随目标的实际拿起位置；ACT沿原路线移动。其他页面默认教程表现保持原配置。
- 真实输入断言覆盖第一拍的路线、拿起过程中及弹起完成后环和线起点随held移动、正确目的篮、送篮清理引导、连续低动态勾号的替换/到期及离页。
- 正式素材中的普通作物保持46px拿起高度；株身候选才按body/fruit透明边界计算额外净空。候选美术输入不在这次正式控制通过范围内。
- 本次完整SHA清单位于 `qa_logs/INPUT_SHA256.json`。action `7a41afb605d8cf47403f0fd79e223d4cdca7c81ba777222fb408391050a8b5a6`；Target `8bfcf2d10506f07d332a0e0c1f2285620e850d3a23152990ddc7e92d7cbe66e5`；Basket `ff10dfdc86574de7f4f183d686ea44f353e82273979ce5c7b22c8b9ac58519b3`；Tutorial `210478703b9ad1e1dd7a9bda1eb4aae8c0c2ef1b57b3dd43a3630fbe51cbe8c4`；触控探针 `2ce1ff3beaa5d333507b8b7b6c6a70f396315947648a84b91ea870344fbf33b2`。

## 正式同源接入与接手复核（2026-10-03）

集成会话已完成正式接入和新的隔离运行，但在汇总前因外部服务错误终止。主资产会话先核对进程清单（原Godot/QA进程均已结束）、正式快照文件及日志，再接手文档与截图测试收尾，没有重新启动整套验证。

- 正式快照：`/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-formal-art-6ykzg4kx`。应用名及独立存档目录由同名 `QASession` 生成；没有在正式存档上运行探针。
- `touch.log` 记录1584项真实触控断言和 `HARVEST TOUCH PROBE PASSED`；`rules.log` 记录 `HARVEST PROBE PASSED`。36份日志复核无 `ERROR:`、脚本错误、已释放lambda、ObjectDB或资源退出告警。
- 30张实际页面图为15场景×双比例：普通、三订单、埋土、真实挖开、真实持货、金色低动态、成熟度干扰、采空后，以及玉米、果园、豌豆/虫子、后两关。目视普通/订单、持货与挖开图显示同源草地、分件空株和藤篮，地面重复横条已移除；持货避开原株和邻株，分篮仍使用原唯一解析器。
- 核对当前树与该快照的Action、Target、Basket、VisualArt、Tutorial、两探针、QA runner和背景文件：逐项字节相同。25项既有运行素材哈希匹配。当前输入SHA与证据路径补入 `assets/harvest_3d/source/RUNTIME_INTEGRATION_20261003.json`，不套用旧控制快照的SHA。

### 修正空灰屏尺寸图的假通过

正式快照里的 `catalog-48/72/96.png` 都是空灰屏，虽然保存成功并打印通过，**这三图不计入小尺寸视觉验收**。原因是刚添加Control/Sprite后马上 `force_draw`，尚未等实际Canvas绘制帧；旧断言只检查资源存在和PNG保存结果。

`tests/HarvestCatalogShot.gd` 现在等待真实 `frame_post_draw`，逐个裁取17个badge范围，与背景比较可见像素，任何空格都会报错而不是打印通过。只改审图场景，不改产品视觉/玩法。

新的独立快照 `/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-catalog-visible-lx952xsc`：导入退出0，48/72/96三次均退出0且通过；51个素材格实际有内容，48px最少309个对比像素，三图已目视，日志无运行或退出错误。旧灰屏保留为失败证据，不覆盖。以上仅证明导入、渲染与小尺寸可复查，不证明5–8岁儿童能可靠识别全部标签。

仍开放：中央场景偏空、小尺寸草莓篮标像圆番茄、目标Android/iPad/Web性能与儿童识别、完整29项smoke。当前是3D制作/2.5D运行，不是整页实时3D迁移。

## 果园短枝与完整订单补验（2026-10-03）

正式30图中的果园暴露了旧192×18px深描边木板相互重叠的问题。现已在原 `HarvestTarget._draw_affordance()` 内替换为60–82px宽、6px厚的浅暖短枝，按实际作物透明边界顶端定位并用短茎相接。成熟/未熟图缩放后各自拟合。显示由现有 `HarvestTargetVisual` 持有，节点均为无脚本Polygon2D；sweep阈值、半径、关卡数量与篮子解析保持来自原规则。

`HarvestTouchProbe` 新增两比例果园检查：逐株测实际枝宽与果顶距离、被动节点类型，再经真实InputEventScreenTouch/Drag摇下一只成熟苹果，使用现有 `_destination_for()` 送篮一次。当前补丁静态检查0 errors/204 warnings，文件diff检查通过；运行与最新双比例审图结果待统一隔离QA后记录。

本轮静态输入：Target `b6b561a389cd61be602c6eea300b8302b9410a5d927f7df4d12cbe18383517b8`；触控探针 `b7efac3d2f8a5a4e629c2f28ed09cde24ca8b3d7d7228cfb2f2b4122d496c5a0`。它们已不同于旧1584项快照，不能套用旧通过结果。

另安排独立 `HarvestCompletionProbe` 复用真实触控夹具，补丰收庆典三订单的采摘、分篮、下一单、最终结果与存档闭环。原1584项已检查全部10关的布局与规则，但h08真实重载路径只完成首单，采空夹具仅清空h07番茄组；这些旧证据不记作完整关卡通关。

## 10/03 根部连接与构图迭代（仍未通过最终美术门）

- 按两种画幅的实际页面，将可种植区顶边从视口高度的 `0.50` 上移至 `0.43`，减少 HUD 与作物带间距。扩大的菜园高度同时拉大三篮可触达半径；首个候选在 `harvest_07/08` 的 4:3 真实触控检查中发现礼篮中心距 150px、小于两侧半径和 155px，属于有效的误触风险，不放宽测试。把下方礼篮中心从土区 `0.84` 改为 `0.88` 后，后一候选两比例触控恢复通过；半径公式、目标输入/篮子解析器未改。
- 对照了横贯全场的绿色带、仅限作物群的浅带、加深浅带三种同一根部方案。真实画面中全宽版本读成平行草坪条纹，局部版本要么太淡、要么出现半透明波浪色块；均未接纳。正式背景存在时关闭此叠层，只保留既有按根宽生成的接触影；只有退回程序化 Stage（没有 meadow 纹理）时才保留 row cue fallback。
- 历史截图-only快照：`/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-no-overlay-final-_0zdx63n`；`harvest_action.gd` SHA-256 `9a1cb6ced0cd546eaf86389deda9a99ca6e8fb777b2b8d9e20871d36f8a7c500`，`screenshot_tool.gd` SHA-256 `57c75ac18198c190be5976895c1317a482caf58ac602c913e09ccb34b6cd010e`。规则、5档目录图和 harvest_02/08 两比例普通/持货/低动态共16次运行均退出0，15张图经过PNG变化量检查；普通截图由新的截图内容门禁报告 `CONTENT PASSED`。它没有运行触控、果园或三单完成探针，现已由下方完整快照替代。4:3礼篮站位与画面可见范围复核通过。
- 静态 `tools_check.py`：61/61关卡可玩、0 errors/204 warnings；`git diff --check`通过。三种色带候选均未接纳；视觉仍见中部草地偏空。下一步按本计划§3.52，只在独立 QA 副本做真正的 Godot 3D 地表/SubViewport 对照；不替换正式背景、不改变二维命中对象，不把试片直接接入产品页。

## 10/03 Clean-ground 当前完整回归

完整隔离快照 `/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-harvest-clean-ground-formal-cbh297xi` 与当前正式树一致，`harvest_action.gd` SHA-256 为 `9a1cb6ced0cd546eaf86389deda9a99ca6e8fb777b2b8d9e20871d36f8a7c500`。汇总列出的39项输入 SHA 均与当前工作区一致。

- 22/22 项运行退出码均为0，日志无 `ERROR:`、脚本错误、ObjectDB、Lambda capture 或资源退出告警；规则探针通过。
- `HarvestTouchProbe` 记录1698项触控并通过。三单完成探针覆盖4种画幅/动态组合、12次订单推进、68次真实送篮及448项检查，均通过。
- 共19张图：14张页面截图涵盖 harvest_02/08、果园、普通、真实持货和低动态的16:9/4:3状态，逐张有 `CONTENT PASSED`；5档目录图每档17个格子都通过像素可见性检查，共85格。
- 自动检查汇总为“自动检查通过；仍需人工读图，不等于儿童识别验收”。人工复看仍见中上部空场大，当前只验证了无色带的干净底景与现有根部接触影，没有通过最终构图美术门。同源3D地表仍是隔离候选，不代表已集成或已验证设备性能。
