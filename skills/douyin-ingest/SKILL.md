---
name: douyin-ingest
description: 当用户要从抖音收藏夹批量采集新的财经/股票视频并整合进投资知识库时使用。触发语：『扫一下抖音收藏』『扫收藏夹』『更新抖音收藏到投资库』『把抖音新收藏的财经视频整理进来』『同步抖音收藏』『ingest 抖音』等采集动作。本 skill 负责：用 superpowers-chrome 控制专用已登录的有头 Chrome profile 打开抖音『我的-收藏』、枚举新增收藏视频、三级降级提取视频内容、过滤出财经/股票相关项、按 investment-views 的 Type D 流程落档、用 JSONL 账本去重幂等。不要在用户只是查询投资观点（如『光模块还能拿吗』『恩哥怎么看存储』『HBM 周期到顶了吗』）时触发——查询是 investment-views 的职责；本 skill 只在用户要『去抖音取新视频』这一采集动作时触发。
---

# douyin-ingest

## 何时使用

用户要把抖音「我的-收藏」里**新收藏的财经/股票视频取回来并整合进投资知识库**这一**采集动作**时调用。典型说法："扫一下抖音收藏""扫收藏夹""更新抖音收藏到投资库""把抖音新收藏的财经视频整理进来""同步抖音收藏""ingest 抖音"。

分工：本 skill = **去抖音取新视频 + 结构化 + 路由**；`investment-views` = **知识查询 + Type D 整合规则的唯一来源**。用户只是查观点（"光模块还能拿吗""恩哥怎么看存储"）时不要触发本 skill，那是 `investment-views` 的职责。

## 前置：登录态保障

1. 用 `superpowers-chrome:browsing`（`use_browser` MCP）。专用 profile 名 `douyin`，**有头模式**（反爬更低、可人工扫码）。`set_profile`/`show_browser` 会重启 Chrome 且有先后约束，**严格按 `references/operations.md` §0 的一次性建会话顺序操作**，不要自己压缩成一步。
2. 导航到抖音个人主页，`extract` 页面，按**登录标志**（如头像 / 「我的」入口；未登录时出现「登录」按钮）判断登录态。具体登录标志在运行时发现，**不写死选择器**。
3. **未登录** → 立即停止，提示用户在弹出的可见窗口里扫码登录，等待用户确认后重新 `extract` 复检。**绝不自动化登录流程。**
4. 登录态随 `douyin` profile 持久化，是一次性人工动作，后续运行免登。
5. DOM 发现与异常处理细节见 `references/operations.md`。

## 步骤 1 · 枚举收藏

1. 导航到「我的-收藏」tab。
2. 类人节奏渐进滚动加载（分批 + 间隔，不瞬时狂滚），直到列表不再增长。
3. `extract` 页面，用正则匹配 `/video/\d+` 链接 + 稳定的 `data-e2e` 等语义属性，收集每条 `{videoId, url, title}`。**不写死哈希类名**（抖音类名混淆且频繁变）。
4. 选择器/滚动模式等易变细节见 `references/operations.md`。

## 步骤 2 · 去重

1. 读 `skills/douyin-ingest/state/ingested.jsonl`，按每行 `id` 构建已处理集合。
2. 过滤出未在集合中的新 `videoId`，只对新增项继续。
3. 若无新增 → 直接跳到「步骤 6 · 账本 + 报告」输出报告并结束。

## 步骤 3 · 提取视频内容（三级降级）

对每条新视频打开视频页，按顺序尝试，**取到即停**：

1. 找抖音「视频文稿 / AI 总结 / 智能总结 / 文案」入口，展开取全文。
2. 取不到 → 标题 + 作者 + 简介 + 可见字幕/置顶评论。
3. 仍不足以判断 → 状态标 `needs-manual`，**不写入知识库**（不得用幻觉填充）。

每条同时抓取：**作者名、发布日期**。各级具体 `use_browser` 动作见 `references/operations.md`。

## 步骤 4 · 财经相关性过滤

1. 用 `investment-views` 的 **5 大重点关注领域 + 覆盖话题** 判定该视频是否财经/股票相关。
2. 不相关 → 账本记 `skipped-not-finance`，**不整合**。
3. **不硬套非覆盖话题**：比亚迪、白酒、医药、债券、ETF 配置等命中即按不相关跳过，不要用 AI 产业链思路冒充。

## 步骤 5 · 整合（复用 investment-views Type D）

相关视频的整合**完全复用 `investment-views`**，本 skill 不复制其规则：

1. 加载 `investment-views` skill，**严格按其 SKILL.md 的 Type D 流程执行**。
2. 把视频内容结构化为：核心观点 / 数据参考 / 投资逻辑 / 风险点。
3. 作者匹配 `investment-views` 的**已知博主清单**；未知博主按 **V3.0 待收录**处理。
4. 落档路由、保留博主原话、时间戳（视频发布日 +「2026-05 收录」）、更新 §7 跨视频对比表、文档版本号/最后更新日期、「待补充 V3.0」清单 —— **全部以 `investment-views` 的 Type D 为准**。
5. **路由表与整合规则的唯一来源是 `investment-views`，本 skill 只引用、不复制、不镜像**（哪条内容写进哪个 reference 档由 `investment-views` 决定，本 skill 不在此重述其路由表）。

## 步骤 6 · 账本 + 报告

1. **账本**：每条视频处理完**立即**向 `skills/douyin-ingest/state/ingested.jsonl` 追加一行 JSONL（单条 checkpoint，中断后凭账本可续跑）。`status ∈ {integrated, skipped-not-finance, needs-manual}`。完整行结构与字段规则见 `references/operations.md`。
2. **报告**：结束时输出汇总——扫描数 / 整合数（分别落到哪个档）/ 跳过数（非财经）/ 需人工数（`needs-manual`）。

## 注意事项

- **有头专用 profile**：固定用有头的 `douyin` profile，登录态持久化，绝不自动化登录。
- **运行时发现选择器，不硬编码**：抖音 DOM 类名混淆且频繁变，全部按稳定语义特征运行时定位。
- **提取不确定就降级标记，绝不编造**：内容不足判断时标 `needs-manual` 且不写知识库，不得用幻觉污染用户笔记。
- **账本幂等、可续跑**：`id` 为去重键，单条 checkpoint，重复运行只处理新增。
- **整合规则单一来源**：Type D 路由与整合规则只在 `investment-views`，本 skill 引用不复制。
- **反爬失败即停、报告交回**：遇验证码/风控页/异常重定向立即停止该轮、写已完成账本、报告交回用户，**不硬刚、不绕风控、不逆向接口**。
- **收藏量大可分次跑完**：逐条 checkpoint 支持分多次运行直到全部处理完。
