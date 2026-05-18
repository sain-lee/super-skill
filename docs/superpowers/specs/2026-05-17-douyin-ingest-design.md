# douyin-ingest 设计 spec

- 日期：2026-05-17
- 状态：已通过 brainstorming 评审，待写实现计划
- 仓库：`/Users/lisai/code/super-skill`，skill 落点 `skills/douyin-ingest/`

## 1. 目标

用户在抖音「我的-收藏」里持续收藏财经/股票视频。本 skill 自动：登录抖音 → 枚举收藏 → 取出每条视频内容 → 过滤出财经/股票相关的 → 按 `investment-views` 的 Type D 流程整合进知识库。重复运行只处理新增收藏（幂等）。

## 2. 非目标（YAGNI）

- 不做单条链接/分享口令的手工输入模式（用户已明确选「扫收藏夹」批量模式）。
- 不逆向抖音接口、不破签名风控。
- 不在本 skill 内重写整合规则；整合规则单一来源 = `investment-views` SKILL.md 的 Type D。
- 不覆盖非财经话题（比亚迪、白酒、医药、债券、ETF 配置等），命中即跳过。

## 3. 定位与边界

- **采集型动作 skill**：职责是"取 + 结构化 + 路由"。
- 与 `investment-views`（知识查询 + Type D 整合规则）职责分离，互不重复。
- 触发语：用户说"扫一下抖音收藏""更新抖音收藏到投资库""把抖音新收藏的财经视频整理进来""ingest 抖音"等。

## 4. 方案选型

- 方案 A（硬编码抖音 CSS 选择器）：抖音类名哈希混淆且频繁变，几周失效，否决。
- **方案 B（采纳）**：`superpowers-chrome` 控制专用、已登录、有头 Chrome profile；运行时 `extract` 后按稳定特征定位；内容提取三级降级；JSONL 账本去重。抗 DOM 漂移、抗反爬、可断点续跑、绝不编造。
- 方案 C（逆向抖音收藏接口）：违反 ToS、易封号，否决。

## 5. 架构：七个单元（各单一职责）

### 5.1 登录态保障
- 用 `superpowers-chrome:browsing`，专用 profile 名 `douyin`，**有头模式**（反爬更低、可扫码登录）。
- 检测登录态：导航到抖音个人页，判断是否已登录。
- 未登录 → 暂停，引导用户在弹出的有头浏览器扫码登录；登录态随 `douyin` profile 持久化，后续免登。
- 登录是一次性人工动作，skill 不尝试自动化登录。

### 5.2 枚举收藏
- 导航到「我的-收藏」页。
- 渐进滚动加载（类人节奏，分批 + 间隔），直到列表不再增长。
- 运行时 `extract` 页面，按稳定特征定位视频：`/video/\d+` 链接 + `data-e2e` 等属性，**不写死哈希类名**。
- 产出 `{videoId, url, title}` 列表。

### 5.3 去重
- 读 `state/ingested.jsonl`，取已处理 videoId 集合。
- 过滤出未处理的新 videoId；无新增则直接报告并结束。

### 5.4 内容提取（三级降级）
对每条新视频打开视频页，按顺序尝试：
1. 找抖音「视频文稿 / AI 总结 / 智能总结 / 文案」入口，展开取全文。
2. 取不到 → 取 标题 + 作者 + 简介 + 可见字幕/置顶评论。
3. 仍不足以判断内容 → 状态标 `needs-manual`，**不写入知识库**（不用幻觉污染用户笔记）。

同时抓取：作者名、发布日期。

### 5.5 财经相关性过滤
- 按 `investment-views` 的 5 大重点领域 + 覆盖话题判定是否财经/股票相关。
- 不相关 → 账本记 `skipped-not-finance`，不整合。

### 5.6 整合（复用 investment-views Type D）
对相关视频：
- 加载 `investment-views` skill，严格走其 Type D 流程。
- 结构化为：核心观点 / 数据参考 / 投资逻辑 / 风险点。
- 作者匹配已知博主清单（恩哥-拿着别动/李一恩、口罩哥、真深挖者也、黄小勋、全哥、奶爸美股、超级鲨鱼辣椒、说真的渣渣张等）；未知博主按 V3.0 待收录处理。
- 按 `investment-views` 路由逻辑写进正确 reference 档（blogger_views / storage / chip / power / li_yien / zhenshenwa / gao_jingqi）。
- **保留博主原话**，带时间戳（视频发布日 +「2026-05 收录」）。
- 更新 §7 跨视频对比表、文档版本号/最后更新日期、「待补充 V3.0」清单。

### 5.7 账本 + 报告
- 每条处理完立即追加一行 JSONL：`{id, url, title, blogger, date, status, target_file}`；`status ∈ {integrated, skipped-not-finance, needs-manual}`。
- 单条 checkpoint，运行中断可凭账本续跑。
- 结束输出汇总：扫描数 / 整合数（落哪个档）/ 跳过数 / 需人工数。

## 6. 数据与状态

- `skills/douyin-ingest/state/ingested.jsonl`（路径相对仓库根）：append-only，一行一视频，键为抖音 videoId。随知识库更新一起提交（与 `investment-views` 同仓库、可审计、CLI/桌面共用）。
- 不存任何凭证；登录态只在 `douyin` Chrome profile 内。

## 7. 关键原则

- 有头专用 profile；运行时发现选择器而非硬编码。
- 提取不确定就降级标记，绝不编造。
- 账本幂等、可续跑、单条 checkpoint。
- 整合规则单一来源（investment-views Type D），本 skill 不复制规则。

## 8. 已知风险与对策（写进 skill 注意事项）

- 抖音 AI 文稿入口在 web 端形态/位置不确定且可能变 → 运行时发现 + 三级降级。
- 反爬可能拦截 → 有头真实 profile + 类人滚动/间隔 + 失败即停并报告，不硬刚、不绕风控。
- 收藏量大 → 逐条 checkpoint，支持分次跑完。

## 9. 验收标准

- 首次运行：能引导扫码登录并持久化。
- 二次运行：仅处理新增收藏，已处理的不重复写入。
- 财经视频 → 按 Type D 正确落档并更新 §7/版本/V3.0。
- 非财经视频 → 跳过并在账本记录。
- 内容取不全的视频 → 标 `needs-manual` 且不写知识库。
- 结束有清晰汇总报告。
