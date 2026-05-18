# douyin-ingest 运行操作参考

抖音 web 端 DOM 类名混淆且频繁变；本文件描述**运行时如何发现**稳定特征、内容提取的具体动作、反爬礼仪、账本结构。**绝不硬编码哈希类名/固定选择器。** 本文件的流程已于 2026-05-18 用真实账号端到端验证过（见各节"实测"标注）。

## 0. 驱动选择（先读）

**主驱动 = Playwright MCP（`mcp__playwright__browser_*`）。** 原因：抖音「问问AI」内容面板是**跨域 iframe**（`so-landing.douyin.com` 嵌在 `www.douyin.com`），`superpowers-chrome` 的 `use_browser` 只在顶层 frame 跑 eval，**读不到该 iframe**；而 Playwright 的 accessibility snapshot / frame API 对跨域 OOPIF iframe 原生透明，能读到问问AI 的逐字稿全文。**实测：superpowers-chrome 无法完成提取；Playwright 一次 `browser_snapshot` 即拿到完整逐字稿。**

- Playwright MCP 已用户级注册（`@playwright/mcp`，绝对 Node20 路径），配 `--browser chrome --user-data-dir /Users/lisai/Library/Caches/superpowers/browser-profiles/douyin`（复用抖音登录态）。详见记忆 `playwright-mcp-for-douyin`。
- **profile 锁**：同一 user-data-dir 不能两个 Chrome 同占。用 Playwright 前必须先杀掉占用 `douyin` profile 的 superpowers-chrome Chrome（`pkill -f 'browser-profiles/douyin'`）。**douyin-ingest 全流程以 Playwright 为唯一驱动。**
- 装新 MCP 后**必须新开 claude 会话**才加载（`--resume` 也算新进程，会重新 spawn MCP）。
- 常用 action：`browser_navigate`、`browser_snapshot`（含跨域 iframe，**抓内容首选**）、`browser_click`、`browser_type`、`browser_evaluate`（仅顶层 frame）、`browser_take_screenshot`、`browser_wait_for`。

## 1. 运行时发现

### 1.1 登录态判定
- 登录态持久在 `douyin` user-data-dir 里，Playwright 复用，正常免登。
- 判定：`browser_evaluate` 取 `document.title` / body 文本，**出现用户昵称「八百标兵奔北坡」或个人页标题**=已登录；出现「扫码登录/手机号登录」=未登录。判不准就视为未登录。
- **未登录** → 头有界面，停下让用户在可见窗口扫码，登录后持久化，后续免登。绝不自动化登录。

### 1.2 收藏列表枚举（实测有效）
1. `browser_navigate` 到个人页，点「收藏」tab（Semi-UI `.semi-tabs-tab`，按可见文本"收藏"定位，不写哈希类名）。
2. 渐进 `scroll` / 等待，`browser_evaluate` 用正则 `/video/(\d+)/` 从 `a[href*="/video/"]` 收集 `{id}`，标题以视频页为准（列表锚文本含播放量噪声，仅作粗标题）。
3. 直到不再产生新 id。

### 1.3 打开收藏视频 + 问问AI（实测路径，关键）
1. **打开视频只能用 modal URL**：`https://www.douyin.com/user/self?modal_id={videoId}&showTab=favorite_collection`。**不要用 `https://www.douyin.com/video/{id}`**——实测它会弹回个人页，不稳定。
2. 等播放器出现（`browser_snapshot` 里有 `video` / 右侧动作竖栏）。
3. **问问AI 按钮 = 模态右侧动作竖栏「最上方」那个图标**，无文字、类名哈希（实测曾为 `CLMjb9Fi`，会变）。运行时定位法：在右栏顶部小图标格（约 44×44、含 `<svg>`、y 最小、在头像/点赞之上）上 `browser_hover`，确认 tooltip 文案为 **"问问 AI"** 后再点。`browser_evaluate` 给该格打一个临时属性再 `browser_click` 该属性最稳（避免点到外层竖栏容器）。
4. 点开后出现跨域 iframe `so-landing.douyin.com/search_ai_mobile/pc?...&aweme_id={videoId}...`。**直接单独打开该 iframe URL 是白屏**，必须在 douyin 页面内嵌态下用。

## 2. 内容提取（三级降级）

每条尽量抓 **作者名 / 发布日期 / 正文**，取到可用即停。

### Tier 1 — 问问AI 逐字稿（首选，实测可全自动）
1. 按 §1.3 打开 modal + 点开问问AI iframe。
2. `browser_snapshot`：Playwright 会把跨域 iframe 内容一并抓出。**先看 iframe 里是否已有历史**——实测问问AI **按账号持久化会话历史**，同一视频再次进入，之前的提问 + 逐字稿会原样在（带"以上为历史记录"），可直接复用，省一次问答。
3. 若无历史：在 iframe 输入框（accessibility 名类似"问AI、找答案"）`browser_type` 填提示词并提交：

   > 把这个视频的语音内容逐字转成文字，输出完整的原始口语原文，不要总结、不要概括、不要分点、不要改写，只要逐字稿全文。

4. `browser_wait_for` 等输出完（流式），再 `browser_snapshot` 读出 iframe 里那段**逐字稿正文**（assistant 气泡的长文本节点）。问问AI 还会附章节摘要（如"光模块与指数的关系/银行出货的判断/市场风险与应对策略"）与"内容由AI生成"——摘要可作辅助，**正文以逐字稿为准**。
5. **逐字稿即博主原话**：交给 Claude 按 Type D 结构化，**不要让问问AI 替你总结**（提示词已要求只出原文）。校验：明显过短/空 → 视为 Tier 1 失败，降 Tier 2。

### Tier 2 — 元信息兜底
- 取 标题 + 作者 + 发布日期 + 视频可见字幕/简介/置顶评论（`browser_snapshot`）。足以判断财经性与观点即用。

### Tier 3 — 放弃，标记人工
- Tier 1、2 都不足 → 账本 `status:"needs-manual"`，**不写知识库**。
- **硬规则**：绝不编造、绝不用幻觉补全。宁可 `needs-manual` 让用户人工。

## 3. 反爬礼仪（实测：风控与驱动无关）

- **滑块风控**：实测**首次自动化导航**抖音常弹滑块拼图验证（"请完成下列验证后继续"），换 Playwright/CDP 都一样——风控与驱动无关。**绝不程序化破解/绕过滑块**（违规且属绕风控）。有头窗口下→**停下，提示用户在可见窗口手动拖滑块**，用户确认过了再继续。这是设计内的"偶发人工兜底"，不是每条都要人工。
- **验证码中间页**：`navigate` 瞬间 DOM 标题可能是"验证码中间页"。它**有时几秒自动消解**（等一下重新 `browser_snapshot`/截图判断），有时是上面那种需人工拖的硬滑块——**别只凭 navigate 当下的标题下结论**。
- **类人节奏**：处理完一条（含写账本）再开下一条；不并发多 tab；不狂滚。
- **不绕风控、不逆向接口、不破签名**；遇风控失败即停、写好已完成账本、如实报告。

## 4. 账本结构

路径：`skills/douyin-ingest/state/ingested.jsonl`（相对仓库根，append-only，一行一视频）。

```json
{"id":"<douyin video id>","url":"https://www.douyin.com/video/<id>","title":"...","blogger":"恩哥-拿着别动（李一恩）","video_date":"YYYY-MM-DD","ingested_at":"YYYY-MM-DD","status":"integrated","target_file":"references/blogger_views.md"}
```

- `id`：抖音 videoId，**去重键**。
- `url`、`title`、`blogger`（匹配 `investment-views` 已知博主清单；未知博主按 V3.0 待收录、仍记原名）。
- `video_date`：视频/直播日期；`ingested_at`：本次处理日期。
- `status`：`integrated`（已按 Type D 落档）/ `skipped-not-finance` / `needs-manual`。
- `target_file`：`integrated` 时填实际落档的 reference 路径，否则 `null`。
- **每条处理完立即追加一行**（单条 checkpoint，中断凭账本续跑）。
- 去重：下次运行读全部 `id` 构成已处理集合，跳过已存在的。
