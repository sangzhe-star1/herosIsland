# Changelog

## 收尾：把十七条验收逐条指到断言上 — 27 July 2026

星光菜园的阶段 5。没有新玩法，全是把已经做完的东西**证明**给你看，外加两件审计时
记下来、当时没有 Godot 不敢动的欠账。

**十七条验收，逐条对账。** `docs/FARM_ACCEPTANCE.md`：每一条都指到具体探针的具体
断言上——不是"应该没问题"，是"它坏掉的时候哪一行会变红"。写的过程中发现第 16 条
有一处偏差：原文是"返回英雄基地"，实际做的是返回世界地图。**这是入口方案定下来
之后的连锁**——菜园是世界地图上和英雄基地并列的房间，出来回世界地图和其余 34 关
是同一条路；改成回英雄基地是一行的事，但会让它成为全游戏独一份的行为。写清楚了，
你定。

**七个孤儿文案键清掉了。** `house.choose`、`house.set_on`、`house.slot_{hat,face,
suit,back,colour}` 是旧衣柜的槽位词，旧英雄小屋移出仓库之后就没人引用了。警告
193 → 186，正好那七条。清之前确认过没有 `I18n.t("house.slot_" + slot)` 这类动态
拼接，清完跑了英雄小屋和商店两个探针，没有任何界面变成裸 key。

**`RestDirector.new_session()` 终于有人调了。** 它写好几个月，注释里明明白白写着
"游戏启动时调用"，而全项目**零调用**。`levels_this_session` 存在 settings 里跨启动
只增不清——这不是"休息提示来得太勤"，而是**三关一次的节奏从几周前某个任意点算起，
而不是从他坐下来那一刻**。一个在他今早第一关之后、或者要到第五关才出现的休息提示，
已经不再意味着"你玩了一阵子了"。

**那条新断言第一版也是假的。** 它搜整个 `boot.gd` 找 `RestDirector.new_session()`
——而解释这行为什么存在的注释就在它正上方，所以**把调用删掉，断言靠自己的脚注
照样通过**。改成只看非注释行。这和阶段 3 那条"代码里不许写房间 id"踩的是同一个坑。

**README 里的数字改准了。** 它写着 `0 errors, 0 warnings` 和 `355 checks / 36
levels`，早就不是了。现在是 `0 errors, 186 warnings`、22 个检查点、35 条关卡记录。

完整回归：`tools_check.py` **0 errors / 186 warnings**；`run_smoke.sh` **22 个检查点
全绿 + All good.**，0 脚本错误；`next_level_id` 走完全部 35 条关卡记录 0 坏链。
故意破坏：`new_session()` 不清零、把 boot 里那行删掉（注释留着）——都报错。


## 有人来要东西了 — 27 July 2026

星光菜园的阶段 4：仓库、三个 NPC 订单、星星币，还有首期承诺的第五个动作——除草。
**首期垂直切片到此闭环**：种下去、长出来、收进仓库、交给需要它的人、换成星星币。

**仓库和背包是两个，故意的。** `farm.warehouse` 是从地里出来的东西，`inventory` 是
其它一切。订单要三根胡萝卜，不能拿种子抵；而且仓库是孩子**看得见在变多**的那个东西。
两个都不是 `rewards.items`——那是战斗药水，三个模板直接读它，合在一起意味着菜园的
一个 bug 能清空他的回血药。

**`take()` 是唯一的出口，不够就一个都不动。** 和 `Coins.spend()` 同一个形状、同一个
理由：另一种写法是仓库能变成负数，而**负数根胡萝卜没法跟六岁孩子解释**。订单是
全付或不付——差一根就掏空他所有能掏的，是两种坏结果里更坏的那个。

**除草是确定性的，不是随机的。** 每种作物长到第 2 阶段必长一次草，拔掉就不再长。
写成固定阶段而不是概率：随机意味着两个孩子的同一座菜园活儿不一样，「为什么我的
有草他的没有」不是这个游戏想引出的问题——那也是商店被明令禁止爬的那道梯子的第一级。
**草不影响生长**，它是一件事，不是一笔罚款。

**顺着"再弄坏一次"挖出一个真 bug。** 交付的第一版是**先掏仓库、再问这单领没领过**
——所以一个已经交付的订单如果被再次触发，会**拿走三根胡萝卜然后一分不给**。UI 上
按钮已经禁用，够不到，但"够不到"是今天这块屏幕的性质，不是规则的性质。现在先问
再掏，探针绕过按钮直接调交付来证明它。

**还挖出三段删了也没事的代码。** 交付里的 `save_game()`（`Coins.earn` 内部已经写盘）、
`_deliver` 里对 `delivered` 数组的重新赋值（数组是引用）——这两处留着当文档，但
**探针补了"关掉再打开还算数"这条**，让写盘这件事真的被测到。第三段是删掉的。

**一个解析错误让整套挂死了。** `var x := data["levels"].size()` 是 Variant 推断，
GDScript 直接拒绝解析——而**我给 GardenProbe 的那条命令忘了加 `timeout`**，于是探针
既不运行、不打印、也不退出，整套跑到被手动杀掉为止。两件事都修了：静态规则 3b 补了
"在裸下标/裸 `.get()` 上调方法"这两种写法（现在它能抓到那一行），三个菜园/时钟探针
都加上了 `timeout 240`。

检查与测试：`tools_check.py` 0 errors / 193 warnings（新增规则 5r：订单必须能被填满、
必须给钱、图标必须画得出）；`run_smoke.sh` 22 个检查点全绿 + All good.。故意破坏：
`grant` 不看一次性 key、仓库允许透支、交付顺序调回先掏后问——都报错。


## 菜园可以走进去了 — 27 July 2026

星光菜园的阶段 3。**这是第一个孩子能看见的阶段**：世界地图上多了一个星光菜园，
点进去是四块地，能翻土、拖种子、浇水、收获，收下来的东西进仓库。

**点一块地 = 做它当下唯一该做的事。** 别的种田游戏给你一个工具架，要求先选锄头
才能锄地——那是每个动作多一个决定，而它造成的失败（拿铲子去浇水，什么都没发生，
不知道为什么）正好是六岁孩子没法自己排查的那种。所以一块地任何时刻只有一件事要
做，用图画说出来，点它就做那件事：草地翻土、渴了浇水、熟了收。**没有点错这回事，
因为没有东西可选。** 播种是唯一的例外，而且是故意的：从种子架把种子拖进土里，是
唯一"选哪一个"真的重要的动作，拖这个动作让它像把东西放进地里，而不是从菜单里挑。

**一块地只种一样，靠的不是拦截而是不给目标。** 已经种了东西的地**根本不注册投放
点**，孩子连高亮的圈都看不见，而不是松手之后才被拒绝。我原本还写了一个"已经种了
就返回"的守卫，删掉之后触摸探针照样全绿——够不到的死代码，删了。

**地块间距是从吸附半径算出来的，不是看着定的。** 第一版横向 260 竖向 200 是估的，
而 `DragField.SNAP` 是 118——**竖向 200 小于两倍吸附半径，瞄准上面那块地的种子会
吸到下面那块**。触摸探针一跑就抓到了。现在写成 `DragField.SNAP * 2 + 26`，以后调
吸附半径，地块会跟着挪，而不是悄悄坏掉。

**九个新图标，画完都看过一遍。** soil / seed / sprout / watering_can / weed /
basket，加上四种作物各自的 corn / strawberry / tomato（番茄之前借用的是药水瓶，
一个装着爱心的瓶子）。第一版里 `soil` 像个木箱、`basket` 的提手像把锤子、
`watering_can` 的把手是飘着的——都是渲染出来看了才发现的，改完再看一遍。

**世界地图上多了一个不该被算进去的分母。** 菜园作为房间加进阳光公园之后，那个世界
的星章显示成了 `5 / 27`——里面含着菜园永远拿不到的 3 颗星，**这个世界会永远填不
满**。现在房间的星章分子分母都跳过，显示 `5 / 21`，而且房间的标记下面不再画三颗
空星——一行永远填不满的空星，孩子读到的是"这里还有我没做到的事"。已经存进档里的
星星一颗没动，商店解锁读的 `total_stars()` 照旧。

**配音检查学会区分"忘了"和"等着录"。** 菜园没有配音，而这条检查要求每一关都有
录音。它的注释写着"变哑的关卡是回归，不是待办"——但新加一个房间确实产生了一条真
待办。所以它现在分两种：**没人写过词 = 失败**（关卡被忘了），**词写在
`docs/VOICE_SCRIPT.md` 里但还没录 = 每次跑都大声提示**。菜园的那句词已经写好了：
「翻翻土，把种子放进去，别忘了浇水。」等你录。

首期还没有的：仓库界面、NPC 订单、收获换星星币（都在阶段 4），以及除草——地里还
不会长草。

检查与测试：`tools_check.py` 0 errors / 193 warnings；`run_smoke.sh` **22 个检查点
全绿 + All good.**（新增 Garden Touch），0 脚本错误。新探针在 **1280×720 与
iPad 的 1280×960 两种视口下各跑一遍**，用真实的 `InputEventScreenTouch` 推事件并
按窗口像素换算坐标。故意破坏：把间距缩回 200、给每块地都注册投放点、收获不清空
地块——都报错。


## 没人看着的时候，地里发生了什么 — 27 July 2026

星光菜园的阶段 2。仍然没有界面。这一阶段全部是关于**没人能坐着等完的时间**——
一夜、一个被拨回去的日期、一个跳过去的年份——所以生长写成了纯函数：给它任意
一个秒数，读它的答案，不用真的等到明天早上。

**生长是算出来的，不是数出来的。** 没有任何计时器在跑。地块只记"什么时候种的"
和"结算到哪儿了"，生长是进门时算出来的差。这就是"打主线关的时候胡萝卜还在长"
为什么成立而菜园一帧都没加载过——**没有东西在跑，因为从来就没有东西在跑**。

**两条不让步的规则。** 作物永不死亡：水没了生长就**等**，不烂、不需要重种。
离开两周回来，最坏的状态是"渴着，一点没少地停在你离开的地方"——因为会离开两周的
那个孩子只有六岁，而且不是他决定要离开的。熟了就是天花板：可收获之后不管时钟
再走多远都停住，**把日期往前拨换不来第二次收获，因为根本没有第二次可以到达**。

**上一条改了 CHANGELOG 里的一句话。** 阶段 1 写的"睡一觉起来全部成熟"是错的——
探针一跑就发现胡萝卜的口渴时间（15 分钟）比它长完全程（30 分钟）短，不浇水永远
长不完。这**不是 bug，正是"等待帮助"该有的样子**，错的是那句描述和当时的断言。
四种作物的口渴时间统一调成总时长的三分之二，于是每一种都**正好需要浇一次水**：
不浇水，它长到第 3 阶段停下来等你；浇一次，走完全程还剩半罐。浇水这件事因此是
有意义的，而不是一个装饰。

**再弄坏一次，弄出了两段什么都没做的代码。** `settle()` 里那个"时钟往回拨"的特判
和 `advance()` 里"熟了就提前返回"的守卫，删掉之后探针照样全绿——因为往回拨已经被
`GameClock.elapsed_since()` 挡住了，而熟了之后循环边界本来就不会再推进阶段。
往回拨那段**删了**：一条规则，一个地方，clock_probe 是它的测试。熟了那段**留下并
补了真正的断言**：熟的时候用受控步长让土里还剩水，再放一个月，水位一动不动——
"他留下时是可以收的，回来时就还是可以收的，连土都没干"。第一版这条断言是用跳一年
的方式把它催熟的，那样水在路上就已经流干了，于是规则被删掉它照样通过。

**四块地四个独立的钟。** 同一时刻结算，胡萝卜比玉米靠前、玉米比草莓靠前、草莓比
番茄靠前，清掉一块地不动其他三块——地块是四个独立的字典，不是同一个字典的四个引用。

检查与测试：`tools_check.py` 0 errors / 193 warnings；`run_smoke.sh` 20 个检查点
全绿 + All good.，0 脚本错误。故意破坏：拿掉缺水暂停（浇水变装饰）、拿掉 8 小时
上限（一年真的算一年）、拿掉熟了封顶——都报错；另外两次没报错的，就是上面那两段
被删掉和被补上断言的代码。


## 菜园先在存档里长出来 — 27 July 2026

星光菜园的阶段 1。还是没有界面，只有一个问题：一份已经装着几个月游戏历史的存档，
能不能在不惊动其中任何一样东西的前提下长出一个菜园。

**「常驻房间」从四处字符串比较变成一个字段。** 英雄基地要被"这个世界通关了吗"和
"全岛还剩多少"跳过，否则打完的世界永远停在 5/6、后面的商品永远不开。这个跳过原本
是四个文件里四句 `id == "hero_studio"`。一个房间时没事，菜园是第二个，四处两元素
判断正是一条规则悄悄漏掉其中一个的方式。现在关卡自己说 `"room": true`，静态规则
盯着两件事：**代码里再写出房间 id 就报错**（注释里写不算，那是在解释规则而不是依赖它），
以及**房间不许发奖励**——发了它就成了一个不会失败的关卡。

**四块地写进新档的默认值，不是进门时才变出来。** 一个"走进去才存在"的菜园，会让
其他每一处代码都要先判断它在不在。

**顺手修了新档不 settle 的洞。** `load_game()` 的全新档分支从来不调
`_settle_after_load()`，于是任何在结算里发放的东西都要等到**第二次启动**——孩子
第一次打开游戏会看到四块空地和一个没有种子的架子。这个洞在菜园之前就在，只是之前
没有东西踩上去。**探针是走真正的 `load_game()` 那条路验的**，第一版探针自己手动
调了结算，结果把这个洞完美地测过去了——重新弄坏才发现，改成走真实路径后立刻抓到。

**`plots` 是数组，迁移永远够不到里面。** `_migrate` 只补两层，而地块的字段在第三层
且在数组里。与其为每个新字段写一次迁移，不如**每次读地块都过一遍 `normalise_plot()`**：
缺字段补默认、类型不对换默认，将来给地块加字段成本是这里一行、迁移零行。探针拿
一份真实的烂数据验过：缺字段的、类型错的、根本不是字典的、以及干脆少一块地，
四种都修回来了。

**又一次撞上 int/float。** `planted_at` 存成整数、从 JSON 读回来是浮点，类型校验
如果严格比就会把每块地都"拔"回没种过。`same_shape` 因此从私有改成公开——同一条
规则抄第二份就是让它有第二个地方可以走样。

**探针抓到了一个真的顺序错误。** `_migrate` 先填默认值再推导 `save_version`，于是
**每一份老档都会被标成"今天早上写的"**——那正好毁掉版本字段存在的全部意义。推导
挪到填充之前。这条是 save probe 在套件里报出来的，不是看出来的。

**四种作物，五个阶段，真实时间。** 胡萝卜半小时（当天就能收到，第一次成功不用等），
玉米两小时，草莓四小时，番茄八小时——正好等于 `GameClock.MAX_OFFLINE_SECONDS`，
所以睡一觉起来全部成熟，而把日期往前拨一年买到的和睡一觉一样多。`tools_check` 新增
规则 5q：阶段时长为零的作物、没有产量的作物、`IconLibrary` 画不出的图标，全部报错。

检查与测试：`tools_check.py` 0 errors / 193 warnings（与阶段 0 逐类一致）；
`run_smoke.sh` **20 个检查点全绿 + All good.**（新增 Garden）。五次故意破坏五次报错：
迁移不看一次性标志、地块列表不补齐、`normalise_plot` 不校验类型、新档不 settle、
版本推导挪回填充之后。实机截图 16:9 与 iPad 4:3 两档都看过，世界地图与英雄基地正常。


## 地基：一个时钟，一个钱包，一份读得懂的存档 — 27 July 2026

星光菜园的阶段 0。没有一行菜园代码，改的全是菜园会踩上去的那几块地板。

**三小时装在包里，被算成了三小时的游戏时间。** `Time.get_ticks_msec()` 在 iOS
把应用挂起期间照常走，而 `GameManager` 只处理"进后台"、从不处理"回前台"，于是
"玩了二十分钟 + 在沙发上放了三小时"被记成三小时二十分钟——超过三十分钟的每日
上限，孩子下次来玩就被告知今天玩够了。**探针里真的把这一天走了一遍**：20 分钟
→ 装包 3 小时 → 回来，今天的时长仍然是 20 分钟，而且回来之后再玩 5 分钟照样算。

**新的 `GameClock`，全岛唯一一个读时钟的地方。** 以前 `Time.` 在九个地方各读各的，
没有任何一处能被指向一个假时钟——这意味着"胡萝卜明天早上熟"这种事只能靠等到明天
早上来验。现在墙上时间和单调时间分开（前者能被孩子在设置里拨，后者不能但会在后台
继续走），`elapsed_since()` 一次把两头都封死：**往回拨不产生负进度**，
**往前拨一年买到的和睡一觉完全一样多**（上限 8 小时）。`tools_check.py` 加了规则
5o，`game_clock.gd` 之外再出现 `Time.get_*` 直接报错。

**导入一次备份，全部关卡的隐藏宝石都能再拿一遍。** `_merge_progress()` 整条重写
关卡记录时漏掉了 `found_hidden`——而那正是"隐藏宝石的 5 星星币只发一次"的闩。
家长在家长中心导一次备份，这个闩在**每一关**上都被打开。补上了，探针盯住。

**存档字段类型不对会在 autoload 阶段直接把游戏带走。** `_migrate()` 只问
`has(key)` 不问类型，所以一份 `rewards` 变成了数组的存档能一路走到
`data["rewards"]["coins"]`，然后是一个灰窗口，什么都不说。现在类型不对就换成默认值
并留一条警告。**这里差点写出一个更糟的 bug**：JSON 只有一种数字类型，`xp` 存成
整数读回来是浮点——严格比类型会把孩子的经验每次开机清零一次。所以 int 和 float
算同一种形状，探针专门盯着 359 点经验存盘再读回来还是 359。

**星星币的两个后门堵上了。** `SaveManager.add_coins()` 和 `spend_coins()` 是
`currency_manager.gd` 之外的第二条路：前者忘了发 `progress_changed`，所以打完一关
右上角的币数还是旧的；而且因为它们是函数调用不是字典写入，那条"钱只能从一个文件
进出"的静态规则**根本看不见它们**。两个函数删掉，两个调用方改走 `Coins`，规则补上
函数调用的匹配——现在连在 `save_manager.gd` 里重新定义一遍都会报错。顺带堵掉
`platformer.gd` 里那个休眠的刷币口（每次通关全额重发沿途金币，没有任何"上次拿了
多少"的对比，现在 0 关用这个模板，加一关就活过来）。

**测试体系自己有三处是坏的。** `run_smoke.sh` 里 Tap / Difficulty / Upgrade 三个
probe 的脚本错误检查读的是**已经被 `rm` 掉的文件**——grep 对不存在的文件回答"没
匹配"，于是这三个 probe 中途报错也照样算通过。而且那三行写在 `if` 外面，在没有
xvfb 的 headless Linux 上 `set -u` 会直接让整个脚本崩掉，看起来像测试失败。现在
检查挪进 `if` 里、挪到 `rm` 前面，并且给 `no_script_errors` 加了守卫：**文件不在
就是检查没跑，直接报 HARNESS BUG**，而不是当成"没有错误"。

**`NextProbe` 写好几个月，从来没接进套件。** 它管的是结算页那个大绿按钮——链路
指向自己就是孩子出不去的死循环。接进去之前先修了两件事：它没有 PASSED 标记，
以及它往存档里塞 34 关通关记录却从不还原（会把后面每个 probe 都交到一个已经
通关的游戏上）。顺手补了两条断言：最后一关之后没有下一关，不存在的关卡不会
凭空造出一个目的地。

**截图工具拍不出 iPad 的形状。** 它在设 `window.size` 的同时也设了
`content_scale_size`，那等于关掉 `aspect=expand`，拿回来一个规规整整的
1024×768——而真实的 iPad 拿到的是 **1280×960**，高出 240 像素，正是这个项目
两次上线事故的所在地。现在 `SHOT_WINDOW=1024x768` 能拍真实形状，并且会把
"要的窗口"和"真实视口"两个数字都打出来，它们不一致才是对的。

检查与测试：`tools_check.py` 0 errors / 193 warnings（与改动前逐类一致，没有新增）；
`run_smoke.sh` 19 个检查点全绿 + `All good.`（比改动前多两个：新写的 Clock，和
终于接上的 Next）。每一条修复都**故意重新弄坏一次**，确认检查真的会响：拆掉
RESUMED 处理、拆掉负数保护、拆掉 8 小时上限、去掉 `found_hidden`、去掉类型校验、
把 int/float 容忍改成严格相等、重新调用 `add_coins`、重新定义 `add_coins`、让界面
直接读 `Time`、把 `rm` 挪回检查前面——十次破坏，十次报错，还原后十次恢复绿色。


## 英雄小屋 变成了换装屋 — 26 July 2026

98 张素材接进来了，旧的配置页没了。

**两套衣柜合成一套。** 英雄小屋用 `rewards.outfits` + `profile.outfit`，槽位叫
hat/face/suit/back/colour；星光礼物屋用 `data.shop`，槽位叫
head/body/back/hands/feet，规则全写好了但**没有任何 UI 在调**。`back` 是唯一
撞名的槽位，装的还是不同的东西。现在一套：`data.shop` 的结构胜出，旧的 17 件
按 id 对照表迁过去。**探针造一个旧存档跑迁移，四件进四件出，一件不丢，而且跑
两次不会翻倍**——上周怪兽换 id 就是这个坑。

**每个英雄记住自己的衣服。** `profile.outfit` 以前是全局的：给迪迦戴上王冠，
切到赛罗，赛罗也戴着。对孩子来说那是"只有一个人换了皮肤"。现在
`data.shop.worn` 按角色分，五个英雄可以打扮成五个完全不同的样子。买是共享的
——衣服属于孩子，不属于某一个英雄。

**衣服挂在骨头上。** `hero_art.gd` 的节点树本来就在跟着姿势动，所以把 PNG 精灵
挂进 `_head`/`_torso`/`_leg_front`，衣服自动跟着走路、跳跃、转圈、欢呼——
**动画代码一行没写**。这是全案最大的技术风险，动手前先做了一次性验证，四个姿势
都对了才开始写正式代码。验证过程挖出两件事：成对的鞋和手套必须从中线切开（不切
就是一只脚四只靴子），素材是按图标比例画的（直接挂上去帽子比人还大）——都不用
重画，每件三个数字，在 `data/character_slots.json`。

**帽子不再削掉头冠。** 迪迦的鳍从救援头盔顶上露出来，看着像故意设计的。
而且写了 `tools/fit_head_pieces.py`：把眼睛的位置投影进每张帽子图里读 alpha，
**挡住眼睛就自动往上抬**。17 顶里 4 顶被抬了（太空头盔抬了 18 个单位，恐龙兜帽
12 个）——这类问题眼睛看得见，但看 17 遍看不准。

**92 件商品，98 张素材一张不剩。** 一开始能买 31 件，**60 件是玩出来的**
（打通世界 20、累计通关 14、三星关卡 10、徽章 6、世界星章 5、打赢 Boss 5），
1 件是第一次进来免费送的星星披风。12 套主题，从公园探险 ⭐93 到城堡勇者 ⭐236，
正对着关卡顺序。

**试穿永远免费。** `preview_outfit()` 一个字节都不碰存档。探针连试 30 件，
星星币和拥有列表纹丝不动——而且它还检查"预览真的把帽子挂上去了"，否则整个测试
测的是空气。

**六种状态，全部画出来。** 未解锁是**真实剪影加图形化的解锁条件**（三颗星、
世界图标、徽章、旗子加数字），不是问号；穿戴中是整圈金框加勾；不兼容显示
「换个英雄试试」。状态不缓存，每次重新问——留一张过期的查找表是这个月栽过
四次的坑。

**小狗有出路了。** bluey 用另一套渲染器，永远穿不了任何衣服，但以前商品照样
卖给它。现在选中它，衣柜整片换成一张卡片「小狗不用穿衣服，它有毛！不过它可以有
玩具伙伴 →」，一按就跳到伙伴分类。伙伴站在旁边而不是穿在身上，所以小狗完全可以有。

**买东西要按两次，五秒内能反悔。** 点卡片先免费试穿，试完才问「喜欢吗？」；
确认卡只有三个数字（现在有 / 要花 / 还剩）；买完礼物盒六帧开箱，然后「放回去」
停留五秒，全额退款。星星不够时没有红色、没有叉，一句温和的话加三个大按钮
（去闯关 / 放进愿望盒 / 继续看看）。

**新 `HeroHouseProbe`，跑你列的 17 条**：试穿不扣费、买了扣对、重复购买被拦、
未解锁买不了、撤销全额退、一槽一件、跨槽不打架、小狗穿不上、每个英雄各自的衣服、
魔法搭配 200 次没出现过没买的东西、撤销 5 步逐步正确、保存的搭配退出重进还在、
两种分辨率下角色占展示区 68-72% 且没有东西出界。

**顺手修的两件**：`Shapes.lit` 的高光按形状**尺度**偏移，画在 540px 长条上就是
54px 的位移，高光飘到条子上面变成第二根柱子——长条要用 `fill`。还有探针的顺序
依赖：商店探针单独跑过、在套件里挂，因为前一个探针在磁盘存档里留下了"当前角色是
小狗"。两个探针都改成显式设置自己需要的状态，并且**故意把存档写成小狗验证过修好了**。


## 十五只画出来的怪兽 — 26 July 2026

第二版素材包接进来了。图鉴、决斗、冒险关里的小怪，现在是同一张画。

**第一版一张都用不了，问题不在画。** 15 张 512×512 的成品卡，边框和名牌烤进
图里，背景是蓝灰渐变加发光——自动抠图 15 张失败 10 张，剩下 5 张带毛边。所以
先写了 `docs/MONSTER_ART_PROMPTS.md`（五条硬要求：纯绿平背景、无边框无文字、
全身站姿脚在下缘、1024 见方、15 只统一比例）和 `tools/check_monster_art.py`
（逐张验收，说清哪张差在哪）。第二版 15 张全过。

**抠图不是"留最大连通块"。** 第一版脚本那么干，缩略图看着完美——放大才发现
两腿之间、腋下那些封闭的绿色被"填洞"填成了怪兽的一部分。绿幕上看不见，贴到
游戏的天空上就是腋下一扇绿窗。`tools/cut_monsters.py` 是真正的色度键：绿就是
背景，封不封闭都一样，边缘按色度算半透明，再把渗进边缘的绿抽掉。15 张残留绿点
全部为 0。8.6 MB 压到 1.4 MB。

**一张图，三个地方用。** `scripts/reward/monster_art.gd` 是唯一加载点，决斗里
的 Boss、冒险关里巡逻的小怪、图鉴里的卡片都从这里取——这就是图鉴的意义。它也
顶住了这个项目栽过一次的 .import 陷阱：`load()` 返回 null 时直接读磁盘上的 PNG。

**「是谁」和「怎么打」分开了。** 冒险关的小怪以前只有 `kinds`，值是
walker / spitter / armoured——那是三种**行为**。它同时被当成图鉴 id 用，所以
图鉴前三张卡的名字就是三个行为的名字。现在 `kinds` 管行为，`monsters` 管是谁。

**世界分布从 1/2/3/4/5 改成 3/3/3/3/3。** 素材包里阳光公园只有一只，孩子头六关
只能收到一张卡；天空基地挤了五只。每个世界现在是"两只小的 + 一只 Boss"，难度
也一路往上排。

**图鉴卡可以点开了。** 素材包给了每只的属性、技能、弱点和一句话介绍，126 px 的
卡放不下——点一下开一页大的：画像、属性·产地、会用的招、怎么赢、一段介绍。

**Boss 的大小阶梯修好了。** 高度以前是"怪兽自己的高 × 关卡的 scale"，各自有了
高度以后就乱了；现在 scale 只表示"比别人大多少"，像素在一处算。六场决斗
304 → 334 → 319 → 354 → 389 → 440 px，最后一战最大。

**旧存档不会丢卡。** 十只手绘怪兽的 id 全部作废了，而 id 对不上就是卡片凭空
消失——孩子不知道游戏被重做了，他只知道自己打赢的那只不见了。`save_manager`
里有一张改名表，按"同一个世界、同一个位置"把旧卡换成新卡。

**探针和静态检查跟上了**：`AlbumProbe` 现在验 15 只、每只都能在不同关卡first
拿到、15 张图真的能解码（不是"文件在不在"）、每张卡的名字/产地/技能/弱点/介绍
都有文案。`tools_check.py` 新增：每只怪兽必须有图、每张图必须有主人、两张图不
能字节相同、关卡不能打图鉴里没有的怪兽；手绘那套"长得不一样""耳朵形状没人用"
的规则只在还有手绘怪兽时才生效。


## 怪兽图鉴 — 26 July 2026

He beats a monster; the monster goes in the book. Ten of them, and the book
tells him which ones are still out there.

**The six bosses were one creature.** The monster builder takes colours,
horns, spikes, eye count, proportions and a tail. Every duel level passed it
`{"scale": 1.15}` and nothing else -- so every boss on the island was the same
purple monster at six different sizes. The kaiju designer was written months
ago; nobody had ever filled in the form. `data/monsters.json` is that form,
filled in ten times, and it is now the ONE source for what a monster looks
like: the creature in the fight, the card in the book and the little face on
the health bar are all built from the same entry and cannot drift apart.

**The album was unfillable.** There was already a shelf of four silhouettes,
filled by the adventure levels. The duels recorded nothing at all -- so the
six fights a child actually tells you about left no trace. And the shelf drew
every card with the same generic monster icon in four tints, so the thing he
beat and the card he collected were two different drawings and only one of
them was his. Cards now draw the real creature.

**Three small monsters lived five worlds from home.** `walker`, `spitter` and
`armoured` were only ever fought in `dark_castle_04`, at the far end of the
game. They have their own islands now: sunny_park_05, night_city_04,
monster_valley_04.

**Ten creatures, one outline.** Every monster wore the same two big round
ears, which is the largest shape on the head -- ten colours of one animal.
Ears come from the data now (round / pointed / small / long / fin / none),
all six shapes in use, and horns and spikes were moved outside the body
silhouette where they can actually be seen. That is what makes the grey
not-yet-met cards readable as ten different promises rather than ten smudges.

**The final boss did not fit on the screen.** A level's `scale` used to
multiply the monster's own height, which was safe while every monster was 300
px tall and stopped being safe the moment they each got a size: 1.4 x 370 put
660 px of creature on a 720 px screen, head off the top, health bar across
its eyes. `scale` now means *how big compared to the others* and the pixels
are worked out in one place, capped so only the last boss touches the ceiling.

**Album cards had their captions on the hillside.** The names sat below the
card, which on the bottom row meant pale blue text over green scenery. The
card is one white panel now and the writing lives inside it.

**New `AlbumProbe`, in the smoke suite**, asking the only question that
matters about a collection: can every card actually be earned by playing?
(All ten, each first reachable in a different level.) Plus: ten distinct
looks, beating the same monster twice does not hand out the card twice, and
the whole book is finishable. `DuelLengthProbe` now also measures whether
each boss fits on the screen -- a screenshot only catches the duel somebody
happens to look at, and there are six. `tools_check.py` gained three rules:
no card the game never awards, no monster drawn exactly like another, and no
ear shape the builder can draw that nobody wears.


## The island speaks — 26 July 2026

Forty-four recorded lines arrived and the game uses them.

**Every level says what it wants**, the three hint steps are spoken, praise
lands every fourth right answer, "try again" once per level on the first slip,
and the rest suggestion says the same sentence it shows on screen. Nothing
needed wiring per level -- the lookup is by filename, which is what the last
round built it for.

**Voice is sparse on purpose.** A line on every correct answer stops being
encouragement and becomes a running commentary a child tunes out -- and at two
seconds a line it would fall behind the game on any fast level. Once every
four right answers is about one warm word a minute, which is how an adult
sitting beside a child actually behaves. "Try again" is spoken on the first
mistake only; after that the child knows what the sound means and being told
again is nagging.

**27 MB of WAV became 2.8 MB of OGG.** Mono, 24 kHz, quality 1 -- more than
speech needs and a tenth of the size. On a tablet build that matters more than
it does on a desktop, and nobody can hear the difference on a sentence.

**New `VoiceCheck`, in the smoke suite.** Every level finds a line, every
shared line is present, and asking for one really loads a stream into the
player -- because "the files are in the folder" and "a child hears them" are
two different claims, and this project has been caught by that gap before. The
voice player got a name so the test can look inside it.

Three levels are still silent: the bonus levels arrived after the script was
written. They are allowed to be quiet, and their three lines are now at the
end of `docs/VOICE_SCRIPT.md` for whenever somebody feels like it.

## The grey window — 26 July 2026

Reported as "公园里的光球页面空白": the level opened to a flat grey rectangle
with nothing in it. Every level using one of the new templates did the same.

**Cause, and it is the same trap wearing a new hat.** `variant_picker.gd`
declared `class_name VariantPicker` and then used that name twice inside
itself -- once as a return type, once as `VariantPicker.new()`. Global class
names live in `.godot/global_script_class_cache.cfg`, which only the editor
rebuilds, so on a machine that has not rescanned the name does not exist
**including inside the file that declares it**. The script failed to COMPILE,
every template that preloads it failed with it, and the scene came up empty.

The previous fix taught every file to reach for its neighbours by path. This
one was reaching for ITSELF by name, which felt safe and was not.

**Fix**: the return type is gone and the constructor goes through
`load("res://scripts/shared/variant_picker.gd")`. Verified by rebuilding a
class cache with exactly the eleven newest names removed -- three compile
errors and a grey screen before, a clean park with its orbs after.

**And the check that missed it now catches it.** The class-cache rule had an
explicit `if name == own_name: continue`, on the reasoning that a file may
obviously name its own class. It may -- on the declaration line, and nowhere
else. It now ignores that line and errors on any other use, naming the file,
the class and both ways out. Confirmed by putting the trap back and watching
it fail.

## Voice that just works, and the games you asked for come back — 26 July 2026

**Recordings now play themselves.** Drop a file named after a level into
`assets/audio/voice/level/` and that level speaks -- no JSON edit, no code, no
rebuild of anything. `sunny_park_01_intro.wav` and it says its line;
`hint_2.wav` and the second hint step is spoken. `.wav`, `.ogg` and `.mp3` are
all looked for, because a phone hands you whichever it feels like and a parent
should not have to convert anything. A level with no recording is silent and
perfectly fine, which is the state the game ships in.

That closes the loop on `docs/VOICE_SCRIPT.md`: read the 44 lines into a
phone, copy the folder in, done.

**Three games come back as bonus levels.** Keepy Uppy, the Light Range and
Dance Time were asked for by name in earlier rounds and had been left on disk
with nothing pointing at them. They sit beside the curriculum rather than in
it: always unlocked, never required, and deliberately outside the variety
ratio -- counting them would let somebody "fix" a platformer-heavy island by
adding bonus puzzles, which fixes the number and not the problem. They keep
the older count-the-slips star rule too, because on an arcade treat "how well
did you do" genuinely is the question.

Twelve templates now have a level pointing at them.

**All five lesson films rendered.** 17 seconds each, the island's own music
underneath, no buttons in shot.

## The lesson at the end of the episode — 26 July 2026

Finishing a world now earns a little lesson: the thing cartoons for this age
do at the end of an episode, where the story stops and somebody says one small
useful thing. Bluey does it, Ultraman does it, and they do it because five
minutes of story is when a six-year-old is most willing to be told something.

**Five lessons, one per world**, aimed at a child about to start school:
put things back where they live; stop at red and hold a hand; look before you
run; ask for something to be said again; notice when somebody needs help.

Each is three beats -- what happens, what you do, why that is good -- drawn
with the same `Shapes` calls as the rest of the island, so it is visibly the
same world rather than a slideshow bolted on. It plays itself, has a "watch
again" button, and is skippable from the first frame, because a lesson you
cannot leave is a lecture.

**And it films.** `tools/make_film.sh <world>` renders the real scene frame by
frame and encodes an MP4 with the island's own music underneath -- the lesson
without the game around it, for a phone in a waiting room or a grandparent who
will never install anything.

The film's own bug, caught by watching it: a software renderer manages nowhere
near thirty frames a second, so the scene ran on wall-clock while the capture
ran on render rate and the whole lesson finished a third of the way into the
video. The capture now drives time -- it measures how long each frame really
took and scales the engine's clock so that interval equals exactly 1/30 s of
scene time. Self-correcting, so a slow frame simply gets a slower clock.

**Voice: still no.** No speech engine is reachable from here -- the package
archive is blocked and none of piper, espeak or coqui will install. The 44-line
script in `docs/VOICE_SCRIPT.md` is ready to read into a phone, and a parent's
own voice was always going to beat anything synthetic for this particular
listener.

## The last few things the brief asked for — 26 July 2026

Five platforms, a game that suggests a break, adaptation in both directions,
and a collection that grows by playing.

**Windows and Web export presets** are in. Five platforms now: macOS, iOS,
Android, Windows, Web.

**The island suggests a rest.** Every three levels the result screen adds one
soft line -- "today's mission is done, shall we have a rest?" -- with nothing
to press and the "next level" button still the biggest thing on screen. It
counts LEVELS, not minutes, because a child who played one long level has not
had a long sitting. Why it is the game's job: a six-year-old has no idea how
long they have been playing, and a game that never mentions it is quietly
relying on a parent to be the one who says stop. That makes the parent the
villain and the game the friend. This puts the game on the parent's side.

**Adaptation goes up as well as down.** Three levels finished without a single
hint and the next one hides one more thing and waits longer before helping.
The brief is careful about what "harder" may mean for a six-year-old and rules
out the two things games normally reach for -- more speed, more enemies --
because neither is a new idea, just the same one turned up until it stops
being fun. Doing well here buys a child MORE GAME, never less mercy. One level
that needed help puts the streak back to zero.

**The monster album.** Every monster met gets a page; the ones not yet met are
dark silhouettes with a question mark. The silhouette is the whole point at
six: a child can SEE that there are four and they have two, without counting
or reading. It is the only thing in this game that says "there is more", and
it says it without a shop, a timer or a locked box.

**Island completion**, as a ring that closes beside the star count on the map.
Not a percentage -- a shape. "How far am I" is the one question a child asks
about a game with more than one screen.

**`docs/VOICE_SCRIPT.md`**: 44 lines to record, one per level plus the
encouragements and the rest lines, with the filenames the game expects and a
note on how to say them. Twenty minutes with a phone.

Caught on the way through: the map's completion ring hung off the bottom of
its card and dropped a house icon on top of the star; and a `const` lost in an
earlier edit left `observation_search` referring to an undeclared `Props`,
which the smoke test caught as a parse error before it reached anyone.

## Nine games, not one — 25 July 2026

The island stopped being a side-scroller with variations and became what the
brief asked for: a collection of games that happen to share a map, a hero and
a reward wall.

**Nine templates, one core idea each.** Six of them are new:
`observation_search` (look for things), `matching_sorting` (drag them where
they go), `build_repair` (make it, then watch it run), `puzzle_mechanism`
(turn things until the light gets through), `memory_rhythm` (do it back), and
`creative_play` (a room with no rules at all). `roleplay_rescue` merges the
old rescue and traffic levels; `monster_duel` and `platform_adventure` stay,
with side-scrolling now capped at a fifth of the island.

**The mix, measured rather than intended:** side-scrolling 6, battles 6,
sorting 4, puzzles 4, building 3, memory 3, looking 2, helping 2 -- thirty
levels, no template twice running, every world offering at least four kinds
of play. `tools_check.py` now fails on all three of those rules, and the
check was verified by deliberately breaking it: turning World 1 into five
platformers produced exactly the three errors it should have.

**Four shared pieces everything is built on:**
- `ThumbStick` -- the left hand is a stick now. A quarter of the screen is
  the touch area, the ring appears wherever the thumb lands, and it springs
  home when released. Two arrow buttons asked a small hand to aim; a stick
  asks it to lean, which is what it does anyway.
- `DragField` -- one drag for the whole island. Lift and grow, every target
  glows, the nearest one glows harder, snap from 118 px, and a wrong drop
  floats home. Sorting and building feel identical because they are.
- `HintDirector` -- one failure says it again, two shows a finger, three does
  the hard part and **leaves the last step for the child**. That last clause
  is the whole design: a game that solves the puzzle has taken it away.
- `TutorialDirector` -- the five to eight seconds before every level. Show
  the goal, show the action once, hand over control, in that order, wordless.
- `VariantPicker` -- replays differ, from hand-written lists only. It picks;
  it never generates, so it cannot produce a level nobody can finish.

**Audio, generated.** `tools/make_audio.py` synthesises 22 sound effects, 8
tuned notes and 7 pieces of music from one file -- so the drag sound and the
drop sound were made by the same hand, in the same room, on the same
pentatonic scale that nothing can sound sour on. The game had 8 effects and
one track; it has 37 files now. Voice is still the one gap: no speech engine
was reachable, and a parent's own voice is better than any of them anyway.

**The right hand got smaller and livelier.** Skill buttons 112 → 88 px, icons
60 → 46, laid on an arc a thumb sweeps. They breathe while ready, ripple when
pressed, and flash their rim the moment a cooldown ends -- so a child can
watch the monster instead of watching a wedge shrink.

**`MapProbe` now enters all thirty-one levels** the way a child does, through
the map's own calls, on a save from before the rebuild. Nine templates, every
one of them building and scoring by objectives.

## Audited against the spec, and four things it was missing — 25 July 2026

Checked the rebuilt island against the ten-point brief rather than against
memory. Six of the ten were already right; four were not, and three of those
are now fixed.

**The boss slammed without saying where.** Phase one raised its arms and
flashed, then picked its landing spot at the moment of impact. The child saw
that something was coming but not where, so dodging was guessing -- and a
guess you lose a heart for is indistinguishable from unfairness. It now marks
the ground for the whole wind-up with the same growing shadow the falling
rocks use, so a child who learned level two already knows to step off it. The
mark is chosen when the wind-up starts and never re-aimed, because a warning
that moves is worse than none. Measured: 1.77 s of warning.

**The double jump existed and nothing granted it.** `double_jump_unlocked`
had been sitting in the hero controller since Phase A, read once, never set.
The chest at the end of 岩石怪的挑战 now gives it, `SaveManager` keeps it in a
new `skills` list, and the hero reads it back on every level. Unlocking is
idempotent, so replaying for a third star gets the treasure and not the
lecture. A skill that has to be re-earned every time the tablet sleeps is a
tease, not a reward.

**Two falls got help, but not the kind the spec asked for.** The island
already slowed down and pointed at the gate. It now also loops a translucent
finger on the actual BUTTON -- attack, shield, lightning or jump, whichever
is the answer to where the child is stuck. Pointing at the thing in the world
is half an answer: "get past that gate" is no use to someone who has not yet
worked out that the round yellow circle is how you jump.

**Still outstanding:** Windows and Web export presets (the file can only be
edited with Godot closed, and it is open), and voice-over on the new levels,
which needs recordings.

## The bug that made every level error — 25 July 2026

The father picked a level in 怪兽擂台 and got an error. So did every other
level, on his machine, and none of them on mine.

**Cause.** `adventure.gd` referred to its five new classes -- `HeroController`,
`SkillBar`, `AdventureProps`, `AdventureEnemies`, `PuzzleCard` -- by class
name. Godot keeps global class names in `.godot/global_script_class_cache.cfg`
and only rebuilds it when the EDITOR rescans. On a machine whose editor had
not been reopened since those classes were written, all five were unknown, and
an unknown identifier is not a runtime problem in GDScript -- it is a PARSE
error. The whole template failed to compile, so *every* level errored the
instant it was picked. Nothing in the game pointed at the cache file.

**Fix.** The template now loads all five by path:
`const HeroCtl := preload("res://scripts/adventure/hero_controller.gd")`.
`preload` resolves at compile time and never consults the cache. Reproduced
by rebuilding a cache with exactly those five entries removed -- five parse
errors before, a clean 怪兽擂台 after.

**So it cannot happen again.** `tools_check.py` used to WARN that the cache
was stale. It now ERRORS, naming the file, the class and the fix, whenever a
shipping script refers by name to a class the cache does not have. A warning
was the wrong volume for a condition that breaks every screen in the game.

**And so the door gets opened.** New `MapProbe` walks in the way a child does:
build the map, check every world's first level is unlocked, and enter it
through the same calls the marker makes. Every previous test reached levels the
way a programmer does, with the id already set -- the map was the one path
nobody walked. It also plays a save from before the rebuild, full of level ids
that no longer exist, which is the state every existing player is in.

## Phase D: the whole island rebuilt — 25 July 2026

The 54 old levels are gone. In their place, **thirty adventure levels across
five worlds**, all one template, every one of them a side-scrolling run made
of beats.

- 阳光公园 · 快乐小猪镇 · 安全局 · 动物救援森林 · 怪兽擂台, six levels each.
- A level's whole definition is now an ORDER OF BEATS. No x positions, no
  lengths: the template plans the beats, grows ground to fit them, and derives
  the level's length from what they need. Adding a level is nine lines of JSON.
- **Every level has at least three different kinds of thing to do**, which is
  the rule the old island broke worst: adventure_valley was five platformers
  in a row and hero_city was six collect levels out of eight.
- **The old teaching survives as cards.** `count` is Piglet Town's counting
  (asked in dots, never digits); `sort_safe` is the Safety Bureau's spot-the-
  danger; `same_as` is Memory Match without the memory; `color_match` is the
  energy-tower colour levels. They pop up mid-level and hand the child back to
  the path fifteen seconds later.
- **Every badge the island ever had is earnable again** -- one per level,
  matched to what the level is about.

Testing changed shape to match. `AdventureProbe` now checks the LAWS of all
thirty levels -- buildable, everything inside the real jump arc, plates far
enough apart, gates that hold -- and walks three of them end to end, chosen to
cover a gentle level, a hazard level and a fighting level.

Two things caught by looking at it:
- The map's second row of levels hung its names and stars off the bottom of a
  720 px screen. Rows now sit where a marker column actually fits.
- The page dots were drawn under the island's clouds, so with five worlds the
  map looked like it had three.

**The twelve old templates are still on disk and still work** -- nothing points
a level at them any more. Light Defense, Keepy Uppy, Monster Duel, Dance Mode
and the rest are one `"game_type"` line in levels.json away from coming back as
bonus levels. Their two probes (battle, duel) are parked in the same spirit.

## Phase C: monsters that telegraph, and a giant to beat — 25 July 2026

Third stage of the rebuild. Level 3, 岩石怪的挑战, and everything that fights.

- **Monsters that wind up first, always.** A ring closes in on the monster for
  the whole telegraph before it lunges or spits; nothing it does during the
  wind-up can touch you. Three kinds, each teaching one idea: the walker
  teaches the attack button, the spitter teaches the shield, the armoured one
  teaches that hitting harder is sometimes the wrong idea (its glowing spot is
  only open from above).
- **The shield is real now.** It was a light show; it is a 2.2-second window
  that eats hits, follows the hero, and expires. The lightning skill became a
  real beam that reaches across the screen -- and it is the only thing that
  breaks the giant's shell.
- **The rock giant**: three phases, three hits each, nine countable pips on
  its bar. Phase one slams the ground behind a shadow; phase two throws three
  announced stones; phase three shells itself and must be opened with the
  beam. Beaten, it sits down and waves -- nothing on this island dies.
  Walking past it is impossible, so the fight is the door.
- **Rescue**: a caged friend freed with the interact key, who then trots along
  behind you forever. Nothing to protect, nothing to lose. The reward for
  being kind is company.
- **Two falls and the island leans in** (spec §5): longer warnings, slower
  monsters, a shorter boss fight, and a hand pointing at whatever is in the
  way. No menu, no question -- a child who has just lost twice should not be
  ASKED whether they would like it easier.
- **The result screen shows the three doors**: finished / found the secret /
  kept your hearts, as pictures. Undone ones are dim, never crossed out.
  "Two stars" is a grade; a dim gem beside a bright chest is an invitation.

Bugs the probe caught before any child could:
- The armoured monster was literally unhittable. The swing lands 80 px above
  the hero's feet and a monster's origin is at its own feet, so a hit from
  above measured 217 px away from a 176 px circle. Swings now use a forgiving
  capsule around the monster's middle.
- A beaten monster's node is freed by its own farewell tween, and the loop
  assigned it to a typed variable before checking validity -- which is an
  error in itself, so the guard never ran.
- The cage's interact key floated exactly where the hero's face was.

## Phase B: things that warn, and questions asked in place — 25 July 2026

Second stage of the 54-level rebuild. Level 2, 落石小径 (Rockfall Path), and
the five beat kinds it needed.

- **Hazards that warn first, always.** A falling rock grows a shadow on the
  ground where it will land, and the SIZE of the shadow is the countdown; a
  fire vent blushes red before the column comes up. Difficulty may shorten
  the fuse and may never remove it -- the probe measures a real rockfall with
  a stopwatch (1.72 s from shadow to impact) rather than trusting the config.
- **A crate you push with your body**, not with a button, solid from the side
  and ridable from on top. It exists to reach a shelf exactly one jump above
  its own roof, with the hidden gem on it -- both numbers derived from the
  jump arc rather than chosen.
- **Step-in-order plates**, wearing one, two, three DOTS (never digits).
  Wrong order relights the row and costs nothing: not a heart, not an orb,
  not the gate.
- **PuzzleCard**: a picture-question asked without leaving the level. The
  world dims, the card flips up, fifteen seconds later the child is back on
  the path. This is how the twelve old minigames come back -- Phase B ships
  the colour-match card from the old collect_energy levels.
- **A hand that points.** Push at a shut gate for two seconds and the game
  points at whatever opens it -- plate, next dot-plate, or question post.

Bugs the probe caught before any child could:
- Sequence plates could be built 50 px apart, closer than the hero is wide,
  so one step hit all three and the "sequence" solved itself. Plates now sit
  at a fixed 200 px and the count shrinks rather than the spacing.
- Zone beats were placed by hunting for a wide enough ground segment, and the
  only one long enough was the opening meadow -- so the crate, the plates and
  their gates all slid back to the first screen and two thirds of the level
  was an empty walk. Terrain is now GROWN around beats planned in advance,
  and the level's length is derived from what its beats need.
- The crate never moved: contact zeroes the hero's velocity, and the push
  read velocity. It now reads the buttons (`HeroController.wish_dir()`).
- SceneTreeTimers outliving the nodes they were meant to tidy, in six places
  including every particle puff and every stumble. All now tweens owned by
  the node, so leaving a level takes its countdowns with it.
- The card's dimmer was invisible: `set_anchors_preset` keeps the current
  rect, so a Control born at zero size stays there.

## The adventure template -- Phase A of the big rebuild — 25 July 2026

The first stage of rebuilding all 54 levels into one side-scrolling adventure
("儿童版冒险岛"), as planned in `docs/ADVENTURE_PLAN.md`.

- **`platform_adventure`**, a new level template: one long strip of seeded
  terrain with the level's beats laid along it from JSON -- collect, spring,
  hidden gem, checkpoint, floor plate + gate, treasure chest. At least three
  kinds per level, enforced.
- **`HeroController`**: walking, jumping, climbing, attacking, being hurt,
  with every forgiveness a six-year-old needs baked in -- coyote time, jump
  buffer, ledge magnet, auto-aim, a mercy flicker after every hit.
- **`SkillBar`**: the fixed hands of the genre. Move pad bottom-left; jump,
  attack and two cooldown-ring skills bottom-right; a contextual interact key
  that exists only when something is in reach.
- **Three independent stars** (`LevelResult.objective_scoring`): reached the
  chest / found the gem / kept your hearts. Undone tiles on the task strip
  are dim, not crossed out -- "still out there", never "you failed".
- **World 1: 阳光公园 (Sunny Park)** and its first level, 公园散步.
- **AdventureProbe**, in the smoke suite: walks the whole level with the two
  buttons a child has, measures every gap against the real jump arc, proves a
  shut gate is a wall and that the plate is what opens it.

Bugs the probe and the beat camera caught before any child could:
- Pickups compared world coordinates with global ones, so collection drifted
  by exactly the camera scroll -- nothing past the first screen could ever be
  picked up.
- `Juice.idle_bob` on a prop root tweened every orb back to world origin;
  props now bob an inner node (`AdventureProps._bobber`).
- The chest stood under the jump button on the final screen; it now stands at
  dead centre of the fully-scrolled camera, and the level ends with plain
  walking toward it.
- Hand-written beat x-positions drifted with terrain overshoot and piled
  three beats into one 190 px stretch; beats are now an ORDER, spread evenly
  over whatever ground the seed produced.
- Orbs hung above the real jump arc; heights now derive from jump physics.

## Mac packaging — 25 July 2026

`tools/build_mac.command`: double-click to export, unzip, de-quarantine and
reveal `Little Heroes Growth Island.app` (universal, ad-hoc signed, family
build). Ships with a pre-configured macOS export preset and a proper app
icon — the chibi hero on the island's morning sky, rendered by
`tests/IconShot.tscn` into a full .icns. DEPLOYMENT.md gained the macOS
section.


## Trail beauty pass, and switchable maps — 25 July 2026

- **Set dressing along every trail**, coloured from the world's own palette:
  flowers, bushes and pines in the green worlds; in the city the slabs ARE
  rooftops now — window grids on their faces, lamps and roof vents on top.
  Floating ledges grow hanging roots. All of it small, sparse, and behind
  the action.
- **The finish line is a landmark**: a tall pole with a waving star pennant,
  a gold cap, stones at its foot, and a glow visible from half a screen away.
- **Switchable maps via one config knob**: `"weather"` in any level's config
  re-lights the whole world with no art — and `snow` now whitens the ground
  and the distant ranges, so a snowy level is a different PLACE, not just
  falling flakes. New level: Snowy Trail (雪山小道), Adventure Valley's
  fourth stage.
- Smoke test: 43 levels, 397 checks.


## The trails spread across the island — 25 July 2026

- **Bounce mushrooms**: land on the cap and launch twice a jump's height,
  with a cap-squash and sparks. No danger — they are the way up to the
  highest coins, a discovery rather than a decoration. (`"springs": n` in a
  level's config; challenges grow one per two ranks.)
- **Two new adventure stages in the old worlds**: Rooftop Run (Hero City at
  dusk, stone slabs, lit windows sliding past) and Forest Dash (golden
  afternoon). The platform slabs now take their colours from the world, so
  one template serves a green valley, a night rooftop and an autumn forest
  with zero per-level art.
- **Trail coins are kept coins**: everything collected on a run goes into
  the pouch on top of the level reward.
- Pad buttons made near-opaque — translucent rounded styleboxes show their
  corner seams as diagonal lines.
- Smoke test now covers 42 levels (391 checks).


## Adventure Valley: the platform trails — 25 July 2026

A sixth world and a seventh template: **`platformer`**, the side-scrolling
adventure run — run, jump, collect the coins, reach the flag, with the camera
following the hero and the alpine horizon parallaxing behind (new
`Stage.parallax()`). Four levels in **Adventure Valley** (crisp alpine
morning, tall pale crags), including a Challenge that grows a longer trail
each time it is beaten. Terrain is generated from the level's seed — replays
return to the same valley — and each level is a handful of JSON knobs
(`length`, `gap_max`, `coins`, `moving`).

The house rules bind the genre, not the other way round: falling into a gap
floats the hero back to the last safe ledge — one mistake, no lives, no lost
coins, no fail state. Nothing is an enemy; the hazards are geometry. A ledge
always floats over any gap too wide to walk. Controls are three chunky pad
buttons in the thumb corners (left/right and jump, with coyote time and a
jump buffer sized for small hands) plus arrow keys/space on desktop.

Three new badges (Valley Explorer, Cloud Jumper, Mountain Hero), the island
grew a sixth region with a snow-capped peak, and the smoke test now covers
40 levels.

**Drop-in characters.** `GameData` now registers a playable character from
nothing but two PNGs: put `hero_idle.png` (transparent, ~256×384, feet at the
bottom edge) and optionally `hero_cheer.png` into
`assets/characters/bluey/`, restart, and Bluey appears in the Hero House.
No .tres, no JSON edit. Licensed characters stay in this house, same rule as
the photo skins — see README §13.


## The tap-ratchet bug, and the chibi hero — 25 July 2026

**The bug.** `Juice.pop` read a node's *current* scale as its base, so a tap
landing while the previous pop was still in flight adopted the inflated size
as the new normal. Ten fast taps grew the Tap-to-Cross button without limit,
until it had swallowed a quarter of the screen and the hero behind it. Fixed
at the root: the base scale is remembered once in metadata, every pop returns
to it, and a new pop kills the one in flight — which fixes every button in the
game at once. The same disease existed in `Juice.nudge` (rapid wrong-answers
walked a node sideways) and in the hero's own jump (each landing "returned" to
the stretched launch scale, growing him five percent per hop): both now return
to a remembered rest state. `celebrate()` refuses to run mid-jump, and the
crossing ignores taps until the landing hop finishes.

**The hero, third pass: chibi.** The second pass fixed the marionette
problems but kept heroic 4.5-head proportions — still an adult in armour. The
research on what small children actually find likeable is unambiguous: the
baby schema. The figure is now ~2.2 heads tall — the head is nearly half of
it — with enormous LOW-SET eyes (below the head's midline; this is the
single biggest lever), blush cheeks, a tiny mouth, stub limbs with mitten
hands, and boots nearly as big as the legs. The hero identity survives in the
crest, the chest core, the colours and the poses. Raised-arm poses (CHEER,
JUMP) now angle up-and-out, because the head is wider than the shoulders.
The hero and the monsters finally look like they come from the same game.


## The hero learns to move — 25 July 2026

Second pass on the character: redesigned figure, and a real motion vocabulary.
Full character sheet: `docs/CHARACTER_DESIGN.md`.

**The figure.** Joints now hide under overlapping segments instead of sitting
between them as rivets; the torso is one silhouette with a waist instead of
stacked boxes; the shoulder caps are domes the arm slides out from under; the
eyes are large tilted glowing almonds with catchlights; boots and gauntlets
have real shapes (shaft, trim band, sole); each suit carries exactly one chest
pattern. The marionette look is gone.

**The motion.** Poses added: JUMP (asymmetric, mid-leap) and TUCK (rolled into
a ball), plus a crouch. New verbs on SkinnedCharacter, used by every screen so
the physics is shared: `jump()` (crouch → spring → hang → land with dust and a
settle bounce), `hop()`, `roll()` (one full tumble around the body's centre,
speed lines trailing), `entrance()` (drops from the sky, lands with a
shockwave), `victory()` (leap, then cheer at the top of the bounce). New Juice
primitives: `dust`, `shockwave`, `speed_lines` — all drawn, all silent under
reduce-motion.

**Where it fires.** The boot screen's hero now ARRIVES — drops out of the sky
and lands in front of the title. Wins on the result screen are a leap.
Tapping the home-screen hero cycles three tricks (hop, cheer, tumble). The
traffic-crossing hero finally *walks* the crossing (the rig had a walk cycle;
the hero glided) and hops on the safe kerb. Both arena templates open with the
entrance, and the duel's special move starts with a leap into the brace.
`Juice.idle_bob` no longer runs on drawn heroes — it fought the rig's own
breathing and the new position tweens.

**New harness:** `tests/MotionPreview.tscn` captures a five-frame filmstrip
(mid-fall, landing dust, mid-roll, mid-leap, settled), because motion cannot
be judged from a single still.


## The reward wall becomes readable — 25 July 2026

The badge shelf was a grid of grey slabs reading "?" until earned and a line of
Chinese afterwards. A child who cannot read learned nothing from either state:
not what they had won, and not what was left to win. That breaks the rule the
whole game is built on -- *nothing important is carried by words alone* -- and
it was breaking it on the one screen whose entire job is to make a child feel
they have collected something.

- **Every badge is a medal now**: ribbon, scalloped rim, and its own picture in
  the middle. Twenty-two badges, twenty-two pictures, assigned in
  `data/rewards.json` rather than in code.
- **A locked badge shows its own picture in silhouette behind a padlock**, so
  the wall reads as a display of things to go and get instead of a row of
  question marks. Same reasoning as drawing the empty stars: seeing what is
  still out there is the point of showing it at all.
- **The heading counts**: "7 / 22". A six-year-old cannot read "Badges" but can
  absolutely read the gap between two numbers, and that gap is the reason to
  come back.
- **An earned badge is worth touching** -- it pops, sparkles and chimes.
- **The growth bars grew pictures too**: courage, wisdom, kindness, focus and
  safety were five unreadable words next to five identical bars.
- Eight new drawn icons: eye, umbrella, magnifier, compass, leaf, music, medal,
  traffic light. Safety uses the traffic light because the bare tick is drawn
  near-white and vanished against a cream card -- found by looking at the
  render, which is the whole argument for `tests/shots.sh`.
- `tests/rewards_preview.gd` renders the page with progress already made,
  because on a fresh save every badge is locked and the earned state is never
  seen.


## First-play fixes — 25 July 2026

Four things found by actually playing it.

- **The daily-limit message was an engine dialog.** Godot's `AcceptDialog` is
  an OS window with the default grey theme, so the one moment the game asks a
  six-year-old to stop playing was also the one moment it looked like a system
  error. It is now a card built from the game's own parts, with a drawn moon.
- **There was no way to reach the next level.** The result screen offered
  "Play Again" and "Back to Map" and nothing else, so continuing meant going
  back to the map and finding the next one. `GameManager.next_level_id()` now
  walks the level list — same world first, then onward — and the result screen
  leads with a breathing **Next Level** button. Verified across all 36 levels
  by `tests/next_probe.gd`.
- **The duel's skill buttons did not answer a tap.** A press that fired
  produced almost nothing visible; a press refused because the skill was
  cooling produced *nothing at all*, which is indistinguishable from a broken
  game. Now: every tap answers. A firing skill flashes an expanding ring, pops,
  braces the hero and flares the chest light; a refused one rocks the button
  and clicks. Cooldown is a drawn wedge that sweeps away, and a skill coming
  back online pops and flashes. The three buttons moved onto a control pad in
  the corner, clear of the monster.
- **The duel had no stakes.** The monster's attacks did nothing at all if they
  landed. The hero now has a three-pip **light bar**: an unblocked hit costs a
  pip and counts as a mistake, which is what makes the shield worth pressing.
  It cannot end the level — emptying it makes the hero stumble and the light
  returns on its own. The cost of being hit is stars, and stars never go below
  one.
- **The monsters were not appealing.** A purple ball with triangle spikes and
  two white discs is a monster shape without being a character. Rebuilt on
  `Shapes` with the things that actually make a creature likeable: eyelids that
  blink and carry mood, eyebrows, cheeks, a belly, rounded paws with claws,
  ears that wiggle, a visible tail, curved horns instead of triangles, and
  highlights in the eyes.
- Hero and monster are now sized against each other (`set_height`), so a duel
  looks like two giants rather than a child facing a kaiju.


## The rendering architecture pass — 25 July 2026

**The game draws its own world now. No background images, no imported UI art,
no character photographs.**

The full reasoning is in `docs/ARCHITECTURE_REVIEW.md`. In short: the project
had a good logic architecture and no rendering architecture. Each screen chose
its own scenery, mostly by naming a PNG, and the PNG always won — so the game
showed a photographic night skyline, a flat pastel village, a cartoon owl, a
set of imported navy badge discs, two licensed render cut-outs and a screen of
bare grey rectangles, all at the same time.

### New — `scripts/world/`

- **`shapes.gd`** — the drawing language. One outline colour, one weight rule,
  one light direction, one rounding convention, one contact shadow, one glow,
  one star. Everything drawn in the game goes through it, which is what makes
  a 24px berry and a 400px building look like the same hand drew them.
- **`world_style.gd`** — the five worlds as five hours of one day: Piglet Town
  late morning, Safety Bureau noon, Rescue Forest golden afternoon, Hero City
  dusk, Monster Arena night. Same shapes, only the light changes.
- **`stage.gd`** — the layered parallax renderer: sky, sun or moon, stars,
  cloud, three horizon bands, haze, ground, props, motes, weather, fringe.
  All polygons, seeded per level so a replay returns to the same place.
  Publishes `ground_y()`, so every actor in the game stands on one floor.
- **`hero_art.gd`** — jointed heroes with five poses and real transitions. A
  skin is now a design (proportions, crest, chest pattern, four colours), not
  a pair of pictures.
- **`island_map.gd`** — Growth Island as one island, generated from the level
  data, with a path that runs through the actual markers.
- **`energy_tower.gd`** — the Hero City landmark, as an object that can be
  broken, recoloured and repaired.

### Changed

- Every screen and every level template now gets its scenery from
  `build_world()` or `UiKit.world_background()`. There is no third path.
- **The world map is a map.** It was a scrolling list of navy cards over a
  photograph, with a dot-to-dot line baked into the image that had nothing to
  do with any level. It is now one island with the levels standing on it, and
  it opens scrolled to whichever level is next.
- **The heroes are drawn.** `tiga` and `zero` are original designs in the
  game's own style; the licensed render cut-outs moved to
  `resources/skins/photo/`, unreferenced and opt-in.
- **Hero House** presents all three heroes the same way — the live drawn
  figure, breathing — instead of two photographic spotlight cards and one
  drawn placeholder.
- **Icons are drawn by default.** A bare name always draws; artwork has to be
  asked for by path. The previous rule was the reverse, so the imported navy
  badge discs silently replaced the whole `IconLibrary`. Thirteen icons added
  (lock, coin, heart, shield, lightning, orb, rock, sound on/off, retry,
  pause, chest, star_empty) and the set now goes through `Shapes`.
- **Parent Center is styled.** It was the one screen still on engine defaults.
- **The energy tower repairs itself** instead of swapping between two PNGs,
  and its lamp is a real light the level recolours.
- **Traffic Crossing has a world.** It was grey and green rectangles; it now
  has a town on the far kerb, a horizon raised to match the camera, and a
  drawn crossing.
- **Text over the world is outlined** through `UiKit.on_art()`.
- Characters are sized with `set_height(pixels)` rather than a scale factor.
- `background_art` removed from 26 levels and from `UiKit`. Art direction is
  no longer a per-level data field.

### New — `tests/shots.sh`

Renders all seventeen screens to PNG in about twenty seconds, headless, on a
machine with no GPU. `PLAN.md` opens by naming "I cannot see the output" as
the project's most expensive constraint; this removes it. During this pass it
caught scenery drawing on top of buttons, a splash screen coming out solid
navy, signposts 720 pixels tall, heroes at the wrong size, and buildings
standing on the sea — every one of which passed `tools_check.py` and the smoke
test.

### Verified

```
python3 tools_check.py   ->  0 errors, 0 warnings
./tests/run_smoke.sh     ->  355 checks, 0 failures (all 36 levels boot)
./tests/shots.sh         ->  17 screens rendered and reviewed
```

No gameplay rule was changed.


## 2026-07-24 (arena upgrade) — Real 1v1 duels with a skill wheel

- **Template #8, `monster_duel`** — the Honor-of-Kings loop, filed smooth
  for six: a skill wheel in the thumb corner with BEAM (basic attack, short
  cooldown sweep), SHIELD (a light bubble; attacks that hit it bounce back
  and COUNT), and a chargeable ULT picked before battle when the level
  offers a choice — Meteor Barrage (six raking beams) or Light Burst (a
  gold ring that clears every threat and stuns). The ult charges from
  landed hits and never from its own.
- **The monster finally fights back**: goo lobs and, in later duels,
  roaring rings that cross the arena. Blocked = bounced back for a hit;
  unblocked = a wobble and a briefly resting beam button. No hero health,
  nothing ever lost, no mistake recorded — and every duel still ends with
  the monster waving goodbye.
- **A duel ladder across four environments**: Rocky on the city rooftop,
  Blobbi in town, Spikelor in the forest, and the Champion Duel in the
  burning city (36 levels total; Arena Champion badge). Challenge scaling
  hooks are in (busier opponent, higher goal, never a faster hand).
- **Fourth probe in the suite**: drives the skill wheel like thumbs —
  cooldown gates, ult economy (including the it-must-not-self-charge rule
  the probe caught being broken), shield reflection, harmless unshielded
  hits, and a clean 3-star finish.
- Suite: 355 checks + battle, progression and duel probes, all green;
  arena and ult picker verified by rendered screenshot.


## 2026-07-24 (later still) — The Light Song, tap sparkles, and a sticker wall

- **New template #7, `light_echo` — the Light Song**: big candy-coloured
  pads sing a short pentatonic melody (the island theme's own notes, five
  freshly synthesized plucks), then the child taps the song back. Listen,
  hold it, reproduce it — a whole new kind of interaction, and the gentlest
  one: the game waits forever, and a wrong note just replays the song. The
  hero's chest light turns the colour of every note. Two levels (Light Song
  in Piglet Town, Tower Light Song in Hero City; 32 total) and
  challenge-ready scaling (longer songs, never faster ones).
- **Tap-anywhere sparkles**: a new autoload answers taps that land on
  nothing with a tiny golden sparkle, game-wide — at six, a tap that does
  nothing is a broken screen. Unhandled input only (never competes with
  real controls), off under reduce-motion.
- **The sticker wall**: stickers bought in My Rewards now appear along the
  bottom of the Hero House like a bedroom door; each one bounces, sparkles
  and sings a random island note when tapped. Purely for joy — no score,
  no goal, no way to be wrong.
- Suite: 331 checks + both probes, all green; Light Song verified by
  rendered screenshot.


## 2026-07-24 (continued) — Challenge gating fix, progression probe, honest docs

- **Fixed a real challenge bug**: `LevelResult.met_target()` read the
  original target from GameData, so a rank-scaled challenge SHOWED the
  bigger goal but completed at the base one. Results now carry a
  `target_override` wired to the live level data; completion is measured
  against what the label promises.
- **New progression probe** in the suite (`tests/ProgressionProbe.tscn`):
  XP maths (45 per clean run, replays pay in full, 120/rank boundaries),
  improvement-only coins (a same-star replay pays zero), the sticker
  economy (no overdrafts, no duplicates), and challenge scaling — including
  the exact regression above, plus proof that scaling never leaks into
  GameData. Snapshots and restores the save, so it is safe on a machine
  with a real child's save. `run_smoke.sh` runs it after the battle probe.
- Docs told the truth again: README (30 levels, six templates, five
  endless; art status), ART_CHECKLIST and ASSETS status blurbs updated to
  what actually ships versus what is still genuinely open (monster
  paintings, richer art, family voice recordings).


## 2026-07-24 (late night) — Music, voice pipeline, and the ever-growing level system

- **The island has music**: an original 26-second pentatonic lullaby loop
  (`assets/audio/music/island_theme.ogg`, composed and synthesized in-repo),
  playing softly from app start across every screen, ducking under voice
  lines. The Parent Center music slider controls or silences it.
- **Voice, one double-click away**: the sandbox cannot reach any usable TTS,
  so `tools/make_voice.command` generates all 8 Chinese lines on the family
  Mac using its built-in Tingting voice (no internet, no installs) straight
  into `assets/audio/voice/level/`; the audio loader now accepts .wav where
  call sites say .ogg. Three levels gained spoken intros
  (`voice_intro` on Hero City 1, Arena 1, Memory Toys).
- **Hero level**: every finished level pays experience (replays included —
  effort always counts, unlike coins which pay improvement only). The hero
  rank sits first in the home treasure chip (shield badge), the result
  screen shows a quiet +XP spark line, and rank-ups get a breathing gold
  "Level up!" banner. 120 XP per rank, rising forever.
- **Challenge levels — the level system that expands itself**: each world
  ends in a gold-star Challenge card that unlocks after its last hand-made
  level. Beating a challenge raises its rank permanently; every rank makes
  it a little bigger — denser skies, more sparks and duds, an extra memory
  pair, longer trails, busier traffic — always MORE TO DO, never faster
  reactions (the no-speed rule holds; spark lifetimes and car speeds never
  shrink). Rank shows on the map card and pays bonus XP. 30 levels total,
  five of which never run out.
- Suite: 319 checks + battle probe, all green.


## 2026-07-24 (night) — Every plan phase executed

- **Phase 1 juice**: sorting bins wear counter chips that pop as they fill;
  rescue stones turn green with a tick and a dotted path draws itself
  between them, the goal breathes; map islands drift in staggered and the
  frontier level of each world breathes; result-screen coins fly one by one
  into the treasure chip as it counts up; the boot title pops in and the
  hero's chest light flares hello.
- **Phase 2 art**: all 22 item icons generated in the badge style (sorting
  levels are now fully pictorial), and three painted scenes — town, forest,
  room — behind every sorting, rescue and memory level via the new shared
  `background_art` hook (`UiKit.scene_art`).
- **Phase 3 audio**: the game makes sound. Eight synthesized chime SFX ship
  in `assets/audio/` (correct, try_again, star, coin, level_complete,
  orb_collect, power_up, beam) — soft triads and sweeps, mixed quiet.
  Voice lines remain for the family to record (script in DESIGN_PLAN.md).
- **Phase 4 play**: the **Sticker Book** opens in My Rewards — twelve
  stickers bought with coins (first thing coins are FOR), owned ones glow;
  new **memory_match** template with Memory Toys and Forest Memory levels
  (25 levels, 6 templates); the three arena monsters **parade** on the map
  header once all are befriended. Rhythm-tap was consciously dropped:
  timing pressure conflicts with the no-speed rule, memory took its slot.
- SaveManager grows spend_coins/add_sticker (coins only ever leave through
  the sticker book); suite grows to 289 checks, all green.


## 2026-07-24 (evening) — Fonts, home hub polish, BabyBus-pass plan

- **Real fonts ship at last**: `assets/fonts/NotoSansSC.otf` (Noto Sans CJK
  SC Medium, OFL) — Chinese renders identically on desktop and mobile, no
  more engine-default look. Drop `Baloo2-SemiBold.ttf` beside it any time
  for the rounded Latin; the chain picks it up automatically.
- **Home hub**: treasure chip top-right (stars + coins, tap = My Rewards),
  hero waves by himself every ~9s (motion-gated), soft radial spotlight.
- **Every button** now bounces on release via `UiKit.big_button`.
- **My Rewards** restyled as white rounded cards on the soft page (treasure,
  badges, growth) with the bundle's progress-bar art — the BabyBus
  catalogue look.
- **Traffic fix**: the Tap-to-Cross button sat exactly on top of the waiting
  hero, hiding all but his head; moved to the bottom-right thumb corner and
  the hero enlarged.
- Dropped the now-unused `common.locked` string (padlock badges replaced it).
- **docs/DESIGN_PLAN.md**: the full BabyBus-quality iteration plan — next
  coding pass, exact art slots to fill (items, three world backgrounds,
  monster paintings), the voice-recording script table, and future play
  ideas (sticker book, memory match, rhythm tap).

## 2026-07-24 (later) — Shell restyle after first on-device screenshots

- **Fixed the giant overlapping stars** on the world map (and every other
  oversized badge): `TextureRect` clamps `size` until `expand_mode` is set,
  so icons silently rendered at their native 128px. All picture/star/effect
  construction now sets expand mode first; hit bursts, collect flashes,
  power rings and battle meters were all quietly affected.
- **World map restyled** on the BabyBus/Toca/Khan-Kids patterns: white
  outlined titles over the painted scene, the bundle's navy panel and level
  cards, a per-world progress bar (bundle frame/fill art), padlock badges
  instead of "(locked)" text, and playable cards rendered clearly brighter
  than locked ones so pressability reads by glow alone.
- **Home screen**: the chosen hero stands in a soft radial spotlight, the
  Adventure button breathes slowly (the screen's single pulsing action),
  bigger badges, readable parent hint.
- **Hero House cards fixed** (names now sit in the card art's name bar; the
  gold star pins to the chosen card's corner) — PanelContainer tramples
  anchors, so card content moved into a plain Control wrapper.
- **Battle sparks** got a glowing disc backing so tap targets read as
  things, not wisps; dud sparks stay square and dull.
- New `tests/Screenshot.tscn` renders any scene to PNG under Xvfb, so
  screens can be eyeballed (and were: home, map, Hero House, battle, and
  the repair level, all verified rendered) without a person at the keyboard.
- Design rationale and the reference sources are in `docs/DESIGN_NOTES.md`
  ("The shell restyle").

## 2026-07-24 — The Ultraman build: asset bundle, Hero House, juice pass, Monster Arena

One working session, three rounds. Levels went from 14 to 23, worlds from
4 to 5, templates from 4 to 5. Everything below is verified by the headless
suite: 277 smoke checks plus the battle interaction probe, 0 failures.

### Characters and the Hero House

- Integrated `ultraman_tiga_zero_complete_game_bundle.zip`: **Tiga and Zero**
  are real, selectable heroes (`resources/skins/tiga.tres`, `zero.tres`),
  alongside the original drawn Light Hero. Default character is Tiga.
- **Hero House is open** (was a "coming soon" button): a character-select room
  using the bundle's painted spotlight cards. Tap a card to become that hero
  everywhere — levels, home screen, result screen. The chosen card wears a
  gold star; the others dim but never disappear.
- `SkinnedCharacter` learned textures properly: sprites fit the placeholder's
  exact footprint (no level layout changed), `celebrate()` swaps to the cheer
  pose, and the **tintable chest light** is drawn over the sprite at each
  skin's measured chest position — the colour-matching mechanic survives real
  art. New `core_position()` exposes the light as the beam muzzle for battles.

### Visuals and game feel

- Hero City is fully textured: painted skyline (`city.png`, storm levels use
  `city_damaged.png`), painted energy tower with the level's colour lamp
  seated on its lamp orb, neutral orbs tinted at runtime, rock hazards.
- **Repair the Energy Tower now tells its story in state**: the level opens on
  the broken tower and swaps to the shining repaired one at the win, held on
  screen so the child sees what the work was for.
- Point-of-touch feedback everywhere: collect flash under the finger, a
  colour-tinted power-up ring pulsing from the tower lamp when the target
  changes, sparkle-textured confetti, painted star badges in every star row,
  the chosen hero standing on the home screen (tap = celebration), the hero
  cheering beside the result stars, coin icon on coin lines, chest in the
  Reward Center.
- Full icon-badge set wired (star, coin, heart, warning, house, spark, …) plus
  **six icons generated in the same badge style** where the bundle had none:
  check, flag, gear, car, sort, paw — navigation, bins and the map are now
  consistently textured. Texture filtering switched to linear for the painted
  art.
- The principles behind all of this are documented in `docs/DESIGN_NOTES.md`
  (game-feel "juice" adapted for age six, children's touch-target research).

### Monster Arena — the new battle world

- New `monster_battle` template: sparks appear on a city-threatening monster;
  every tap fires the hero's **light beam from the chest light to the tapped
  point on the same frame** — no cooldowns, every tap answered. A spark meter
  fills (never depletes); at the target the monster gives up, waves bye-bye,
  and hops off home. Startled, never hurt; the child cannot be harmed and
  nothing is timed.
- Three procedurally drawn monsters with distinct silhouettes — Rocky (orange,
  one horn), Blobbi (green, three googly eyes), Spikelor (purple boss, spikes)
  — parameterised from `levels.json`, each with a drop-in art slot at
  `assets/characters/monsters/<id>.png`.
- Difficulty grows by adding things to do: dud sparks (grey, square, dull —
  shape AND brightness differ, colour-blind safe) as the only mistake source,
  and slow poppable goo lobs that splat harmlessly. Bundle's `energy_beam`,
  `hit_burst` and `smoke` effects wired.

### New levels (9)

- Hero City: **Meteor Shower** (storm dodge-and-collect), **Rainbow Charge**
  (4-colour tower matching).
- Piglet Town: **Toys or Clothes?** (category sorting).
- Safety Bureau: **Danger Detective** (10-item danger sort), **Night
  Crossing** (3-lane, rain).
- Rescue Forest: **The Long Trail** (6-step trail, 4 hazards).
- Monster Arena: **Wake the Rock Monster**, **Goo Trouble**, **The Big
  Spiky**. Six new badges, all strings in English and Chinese.

### Fixes

- Collect Energy's hero was parented to the scene root and therefore drawn
  *behind* the CanvasLayer background — invisible since the template was
  written. Gameplay actors now live inside the play area.
- The traffic levels' "Safe crossings" counter no longer runs 18 px off the
  right edge (right-aligned in a fixed box; was the suite's one standing
  warning).
- `celebrate()` no longer assumes scale 1.0 (pre-existing fix kept from the
  original tree).

### Tests

- Smoke test covers Hero House, the monster icon, and all 23 levels.
- New `tests/BattleProbe.tscn`: drives the battle input handler the way a
  finger would — dud taps must nudge without scoring, 12 hits must fill the
  meter, win the level, and land a 2-star result in `GameManager` —
  `run_smoke.sh` runs it automatically after the scene sweep.

### For any build that leaves the house

Tiga and Zero are recognisable licensed characters; this build is for the
household only. Remove their two entries from `data/characters.json` (the
game falls back to the original Light Hero cleanly) before sharing a build
anywhere public. `docs/DEPLOYMENT.md` covers installing on the family's own
iOS/Android devices without any store.
