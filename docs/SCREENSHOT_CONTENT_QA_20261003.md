# 截图内容防误通过（2026-10-03）

## 问题与范围

丰收会话发现目录夹具输出“通过”，实际PNG是灰屏。它已独立修复 `HarvestCatalogShot` 的等待时机与逐格检查。本轮检查菜园/奖励夹具：`FarmShot`、`RewardsPreview`、`IconScaleShot` 和 `BadgeScaleShot` 都仅依赖节点、尺寸、PNG保存结果；原历史图已目视，但这些断言无法拒绝之后出现的空图。

## 代码改动

扩展现有 `tests/probe_lifecycle.gd`，保持 `finish(probe, exit_code)` 签名与音频收尾原样。新函数仅由显式截图入口调用，不进入产品帧循环：

- `image_has_content()`：整页稀疏采样，至少8个与实际背景有差异的可见像素（alpha大于0.05）；拒绝均匀清屏、缺失或未分配图像。
- `image_region()`：把视口逻辑矩形换算成真实PNG像素，向外取整并裁到图片内；包含4:3的1280×960→1024×768映射以及独立SubViewport的1:1映射。
- `contrasting_pixels()`：逐像素检查指定区域，与本张图的背景比较，到达8像素即停止；返回值有上限，不是完整覆盖率或识别分数。

矩阵额外检查每个图形区域，排除旁边标题。Icon每次84区域；Badge的248个整勋章图形区和124个内图区，共372区域，写入manifest。完整勋章仅查缩放后的168×132视觉区，隐藏caption不算内容。菜园、任务板、溢出及真实奖励页另查整张图是否有内容。失败的可读PNG仍保存；Icon与FarmShot新增明确拒绝headless，纯Image规则探针允许headless。

本轮保持既有出帧与瞬态截图时机：没有给飞行/持货截图额外等待。它只收紧截图成功判定，不声称解决此前两次等待绘制信号超时的根因。

## 复验入口与实际结果

`ScreenshotContentProbe.tscn` 用人工创建的Image检查7/8像素边界、ROI外有图但内为空、透明彩色像素、裁剪与坐标映射，共21项纯规则。

串行隔离脚本 `/private/tmp/heroes-screenshot-content-qa-TMjc2B/run.py` 已完成Python语法检查，执行交给当前持有Godot的美术会话。它用 `QASession` 创建唯一应用和存档目录，运行：

1. 纯Image规则。
2. Icon双比例、Badge完整矩阵。
3. 真实奖励成长页、七种子溢出、每日任务板各双比例。
4. 四个只在副本修改的故障：隐藏一个glyph、透明一块48px勋章、将捕获Image填灰、headless Icon。要求真实exit 1、FAILED与对应错误描述，并保存失败图片；每次后恢复副本输入。

美术会话已串行执行完脚本，副本 `/private/var/folders/rb/q_d47yds3195hn023328yl_00000gn/T/heroes-qa-screenshot-content-iqx77ql0`。成功组10次运行，全部exit 0、无脚本/引擎错误或退出残留：

| 范围 | 实际检查与图片 | 场景耗时 |
| --- | --- | --- |
| 纯Image规则 | 21项 | 1.257秒 |
| Icon双比例 | 各187项，含每次84图形区域；10PNG | 1.841–1.867秒 |
| 真实成长区双比例 | 各156项；2PNG | 3.300–3.322秒 |
| 七种子溢出双比例 | 各52项；12PNG | 6.568–6.587秒 |
| 每日板双比例 | 各17项；2PNG | 5.410–5.416秒 |
| 完整Badge矩阵 | 372图形区域；24PNG，manifest失败列表为空 | 3.119秒 |

成功图片共50张。原尺寸目视本轮Icon地块徽记、溢出收尾、成长区的双比例图，以及4:3每日板和首张勋章矩阵；内容正常，没有新增空图或布局变化。本轮没有重新逐张审查全部图案身份与小尺寸辨识，原图案限制仍保留。

四个故障均实测exit 1，且无额外脚本/解析错误，源输入随后恢复：

- 隐藏一个glyph：只报告 `rewards:HUD money:48:0` 空白；其他图和标题仍绘出，保留5PNG。
- 透明一块勋章：只报告 `road_guardian:earned:medal:48.0` 空白；保留24PNG，已对照首张正常/失败原图。
- 纯灰Image：5个整页、84个图形区均失败，PNG写入仍成功，保留5PNG。
- headless Icon：开始即FAILED，0PNG。

独立只读复核还用像素差验证故障范围：隐藏glyph只改变 `rewards.png` 的(360,149)–(396,183)区域，其余4页与正常基线逐点一致；透明medal只改变 `badges_medal_01.png` 的(334,194)–(386,246)，其余23页相同。5张灰图实体均只有一种颜色，日志对应5个整页和84格失败。成功50图、故障34图的数量与尺寸均核对。

`qa_logs/screenshot_content_summary.json` 保留逐次结果和输入hash；原摘要四个故障用 `expected_failure=true` 记录，未包含exit字段。另从执行会话的真实控制台取回4条 `exit=1` 原文存为 `qa_logs/fault_exit_codes.txt`，没有回填或改写原摘要。QA脚本也严格匹配 `Godot exited with 1;` 后才写成功摘要。当前静态0 errors、204 warnings，日志 `/private/tmp/heroes-screenshot-content-static-20261003.log`，工作区 `git diff --check` 通过。

## 本轮输入 SHA-256

上述副本的6份GDScript与当前工作区逐字节相同：

- `tests/probe_lifecycle.gd`: `f9687a4c81fa62dada435f2e62aef6cd87a88e7409f3f7bc51939de3759d2529`
- `tests/farm_shot.gd`: `51f488a9341645180f0011292dab69b74667abcabed7bbfa705703c421c57da2`
- `tests/rewards_preview.gd`: `2fc95e80ef75962dadf634879e2d9dbbcd6f55ecc3ae76b15c05476d7f66444c`
- `tests/icon_scale_shot.gd`: `352a0483c726450b46c2fde316537bfc7332ec6f2345f1931892fa2308de18bf`
- `tests/badge_scale_shot.gd`: `24a63a5f3cf9de0aeb35b896679faa79fdaad1f39425c209cd8c4b8a9dbd594d`
- `tests/screenshot_content_probe.gd`: `c8890761cdb0a4976842ce90294f097fa334ae44bceb5e1a0e27bb89744d4b1b`

## 证据限制

至少8像素仅证明区域有内容，不证明图案身份、完整性、字可读或儿童能辨认。整页非均匀也不能证明某个控件可见；矩阵逐格检查、真实页面遮挡断言和目视仍各自需要。勋章图形区非空不能单独证明金底上的内图可识别。
