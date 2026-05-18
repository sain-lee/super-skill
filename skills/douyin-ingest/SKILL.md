---
name: douyin-ingest
description: 当用户要从抖音收藏夹批量采集新的财经/股票视频并整合进投资知识库时使用。触发语：『扫一下抖音收藏』『扫收藏夹』『更新抖音收藏到投资库』『把抖音新收藏的财经视频整理进来』『同步抖音收藏』『ingest 抖音』等采集动作。本 skill 负责：用 Playwright MCP 驱动已登录的 Chrome（douyin profile）打开抖音『我的-收藏』、枚举新增收藏视频、经『问问AI』逐字稿三级降级提取内容、过滤出财经/股票相关项、按 investment-views 的 Type D 流程落档、用 JSONL 账本去重幂等。不要在用户只是查询投资观点（如『光模块还能拿吗』『恩哥怎么看存储』『HBM 周期到顶了吗』）时触发——查询是 investment-views 的职责；本 skill 只在用户要『去抖音取新视频』这一采集动作时触发。
---

# douyin-ingest

## 何时使用

用户要把抖音「我的-收藏」里**新收藏的财经/股票视频取回来并整合进投资知识库**这一**采集动作**时调用。典型说法："扫一下抖音收藏""扫收藏夹""更新抖音收藏到投资库""把抖音新收藏的财经视频整理进来""同步抖音收藏""ingest 抖音"。

分工：本 skill = **去抖音取新视频 + 结构化 + 路由**；`investment-views` = **知识查询 + Type D 整合规则的唯一来源**。用户只是查观点（"光模块还能拿吗""恩哥怎么看存储"）时不要触发本 skill，那是 `investment-views` 的职责。

## 前置：驱动与登录态

1. **主驱动 = Playwright MCP**（`mcp__playwright__browser_*`），不是 superpowers-chrome——抖音「问问AI」是跨域 iframe，只有 Playwright 的 frame API/snapshot 读得到。详见 `references/operations.md` §0。**首次环境准备（装 Node≥18 / 注册 Playwright MCP / profile / 登录 / 重启）见 `SETUP.md`。**
2. Playwright 已配 `--user-data-dir` 指向 `douyin` profile，复用持久登录态。用前先杀掉占用该 profile 的 superpowers-chrome Chrome（profile 锁，见 §0）。装/改 MCP 后须新开 claude 会话。
3. `browser_navigate` 个人页，`browser_evaluate` 判登录（昵称「八百标兵奔北坡」/个人页标题=已登录；"扫码登录"=未登录），运行时发现、不写死选择器。
4. **未登录** → 停下，提示用户在有头窗口扫码，登录后随 profile 持久化、后续免登。**绝不自动化登录。**
5. **滑块风控**：首次自动化导航常弹滑块（与驱动无关）。**绝不程序化破解**——停下提示用户在可见窗口手动拖过，确认后继续。属设计内的偶发人工兜底。

## 步骤 1 · 枚举收藏

1. `browser_navigate` 个人页，点「收藏」tab（按可见文本"收藏"定位，不写哈希类名）。
2. 类人节奏渐进滚动 + 等待，`browser_evaluate` 用正则 `/video/(\d+)/` 从视频链接收集每条 `{videoId}`，直到不再产生新 id。
3. 列表锚文本含播放量噪声，标题以视频页为准。细节见 `references/operations.md` §1.2。

## 步骤 2 · 去重

1. 读 `skills/douyin-ingest/state/ingested.jsonl`，按每行 `id` 构建已处理集合。
2. 过滤出未在集合中的新 `videoId`，只对新增项继续。
3. 若无新增 → 直接跳到「步骤 6 · 账本 + 报告」输出报告并结束。

## 步骤 3 · 提取视频内容（三级降级）

每条按顺序尝试，**取到即停**（详细动作见 `references/operations.md` §1.3、§2）：

1. **问问AI 逐字稿（首选）**：`browser_navigate` 到 modal URL `https://www.douyin.com/user/self?modal_id={id}&showTab=favorite_collection`（不是 `/video/{id}`）→ 点右侧竖栏**最上方**「问问 AI」图标（hover 验 tooltip）→ 跨域 iframe `so-landing.douyin.com` → `browser_snapshot` 读 iframe。问问AI 按账号持久化历史，已有则直接复用；没有就 `browser_type` 发提示词「把这个视频的语音内容逐字转成文字，输出完整的原始口语原文，不要总结、不要概括、不要分点、不要改写，只要逐字稿全文。」等输出完再 snapshot 取**逐字稿原文**。
2. 取不到 → 标题 + 作者 + 简介 + 可见字幕/置顶评论。
3. 仍不足以判断 → 状态标 `needs-manual`，**不写入知识库**（不得用幻觉填充）。

每条同时抓取：**作者名、发布日期**。逐字稿即博主原话，交 Claude 按 Type D 结构化，不让问问AI 替你总结。

## 步骤 4 · 财经相关性过滤

1. 用 `investment-views` 的 **5 大重点关注领域 + 覆盖话题** 判定该视频是否财经/股票相关。
2. 不相关 → 账本记 `skipped-not-finance`，**不整合**。
3. **不硬套非覆盖话题**：比亚迪、白酒、医药、债券、ETF 配置等命中即按不相关跳过，不要用 AI 产业链思路冒充。

## 步骤 5 · 整合（复用 investment-views Type D）

相关视频的整合**完全复用 `investment-views`**，本 skill 不复制其规则：

1. 加载 `investment-views` skill，**严格按其 SKILL.md 的 Type D 流程执行**；路由表与整合规则唯一来源是它，本 skill 只引用不复制。
2. **两种入档模式（折中政策，见 `operations.md` §2.6）**：
   - **逐字原话**（直播/口播型）→ 按 Type D 结构化为 核心观点/数据参考/投资逻辑/风险点，入「博主原话」区，标 `@博主`、时间戳。
   - **问问AI 结构化总结**（财报/研报/框架型，重试仍总结）→ 作为 **『⚠️ 问问AI 摘要（非博主原话）』独立小节**入 Type D 路由到的对应专题档，小节内显著标注"问问AI 生成·非博主原话 + 视频链接 + 时点"，**与博主原话区物理分开、绝不混标**。
3. 作者匹配 `investment-views` **已知博主清单**；未知按 V3.0 待收录。
4. 更新 §7 跨视频对比表、版本号/最后更新日期、「待补充 V3.0」 —— 全部以 `investment-views` Type D 为准。
5. **铁律**：原话区只放原话；AI 摘要单列并标来源，读者永远分得清博主说的 vs AI 概括的。

## 步骤 6 · 账本 + 报告

1. **账本**：每条视频处理完**立即**向 `skills/douyin-ingest/state/ingested.jsonl` 追加一行 JSONL（单条 checkpoint，中断后凭账本可续跑）。`status ∈ {integrated, skipped-not-finance, needs-manual}`。完整行结构与字段规则见 `references/operations.md`。
2. **报告**：结束时输出汇总——扫描数 / 整合数（分别落到哪个档）/ 跳过数（非财经）/ 需人工数（`needs-manual`）。

## 注意事项

- **Playwright MCP 为主驱动**：问问AI 是跨域 iframe，只有 Playwright 的 snapshot/frame API 读得到；superpowers-chrome 读不到。注意 profile 锁、装/改 MCP 须新开会话。
- **打开视频用 modal URL**：`user/self?modal_id={id}&showTab=favorite_collection`，**不要用** `/video/{id}`（会弹回个人页）。
- **问问AI 持久化历史**：同一视频再进，上次的提问+逐字稿原样在，直接复用，省一次问答。
- **运行时发现，不硬编码**：抖音类名哈希且频繁变（问问AI 图标类名实测会变），按位置/tooltip/语义运行时定位。
- **提取不确定就降级标记，绝不编造**：内容不足标 `needs-manual` 且不写知识库，不得用幻觉污染用户笔记。
- **账本幂等、可续跑**：`id` 为去重键，单条 checkpoint，重复运行只处理新增。
- **整合规则单一来源**：Type D 路由与整合规则只在 `investment-views`，本 skill 引用不复制。
- **滑块风控人工兜底，不绕**：风控与驱动无关；首次自动化导航常弹滑块 → 停下让用户在有头窗口手动拖过再继续，**绝不程序化破解/绕风控/逆向接口**；其它风控失败即停、写好已完成账本、如实报告。
- **收藏量大可分次跑完**：逐条 checkpoint 支持分多次运行直到全部处理完。
