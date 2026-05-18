# douyin-ingest 运行操作参考

抖音 web 端 DOM 类名混淆且频繁变；本文件只描述**运行时如何发现**稳定特征、三级提取的具体动作、反爬礼仪、账本结构。**绝不在 SKILL.md 或这里硬编码哈希类名/固定选择器。**

## 1. 运行时发现

### 1.1 登录态判定

导航到抖音个人页后 `extract` 页面的 markdown/html，按**文案特征**而非固定选择器找登录标志：

- **已登录**信号：出现头像、「我的」入口、用户昵称、「收藏」/「喜欢」等个人页 tab。
- **未登录**信号：出现明显的「登录」按钮/「立即登录」「扫码登录」字样。

判定逻辑是"在 extract 出的文本里找这些特征词"，不是匹配某个 class。判不准就视为未登录，停下让用户人工确认。

### 1.2 收藏列表枚举

在「我的-收藏」tab 下：

1. 用 `data-e2e` 等语义属性辅助定位「收藏」tab 与视频卡片（语义属性比哈希类名稳定）。
2. 反复 `scroll`（payload 方向 `"down"`），**每次滚动后短暂 `await`** 让懒加载内容进来，再 `extract` html。
3. 对每次 `extract` 的 html 用正则 `/video/\d+` 收集视频链接，并就近取可见标题文本。
4. 直到某次 `extract` 不再产生新的 `/video/\d+` 链接为止 → 列表加载完毕。
5. **绝不写死哈希类名**；定位一律靠 `/video/\d+` 正则 + `data-e2e` 等语义属性。

### 1.3 抖音 AI 文稿入口发现

打开单个视频页后 `extract`，按**可见文案候选词**搜索可点击元素：「文稿」「视频文稿」「AI」「总结」「智能总结」「文案」。找到则 `click` 展开，再 `extract` 该面板文本拿全文。

抖音 AI 文稿入口的形态/位置在 web 端不确定且会变 → **必须运行时按候选词发现，不可硬编码入口位置**。

## 2. 三级降级提取（细节）

对每条新视频依次尝试，**取到可用内容即停**。每级都要尽量抓 **作者名 / 发布日期 / 正文**。

### Tier 1 — AI 文稿/总结全文

- 动作：`navigate` 到视频 url → `extract` → 按 §1.3 候选词找入口 → `click` → `await` → `extract` 面板文本。
- 捕获：文稿全文（正文）、页面上的作者名、发布日期。
- **校验**：若拿回的文稿异常短或为空（明显不是完整文稿）→ 视为 Tier 1 失败，降到 Tier 2。

### Tier 2 — 元信息兜底

- 动作：`extract` 视频页，取 标题 + 作者 + 简介 + 可见字幕/置顶评论。
- 捕获：标题、作者名、发布日期、简介/字幕/置顶评论作为正文替代。
- 若这些信息合起来足以判断财经相关性与博主观点 → 用 Tier 2 内容继续。

### Tier 3 — 放弃，标记人工

- 触发：Tier 1、Tier 2 都拿不到足以判断内容的信息。
- 动作：账本记 `status: "needs-manual"`，**不写入知识库**。
- **硬规则**：Tier 3 绝不编造、绝不用幻觉补全内容来"凑"一条整合。宁可标 `needs-manual` 让用户人工处理。

## 3. 反爬礼仪

- 用**有头**的真实 `douyin` profile（已持久化登录态），不开无头、不伪造。
- **类人节奏**：滚动分批进行，每步之间留间隔，不瞬时狂滚到底；逐条视频之间也留间隔。
- 出现**验证码 / 风控拦截页 / 异常重定向**（如跳到登录页或安全验证页）→ **立即停止本轮**，把已处理视频的账本行写好，报告交回用户。
- **不绕风控、不逆向抖音接口、不破签名**。失败即停并如实报告，不硬刚。

## 4. 账本结构

路径：`skills/douyin-ingest/state/ingested.jsonl`（相对仓库根，append-only，一行一视频）。

每行 JSON 结构：

```json
{"id":"<douyin video id>","url":"https://www.douyin.com/video/<id>","title":"...","blogger":"恩哥-拿着别动","video_date":"YYYY-MM-DD","ingested_at":"YYYY-MM-DD","status":"integrated","target_file":"references/storage.md"}
```

字段与规则：

- `id`：抖音 videoId，**去重键**。
- `url`：`https://www.douyin.com/video/<id>`。
- `title`：视频标题。
- `blogger`：作者名（匹配 `investment-views` 已知博主清单；未知博主按 V3.0 待收录处理，仍如实记原作者名）。
- `video_date`：视频发布日期 `YYYY-MM-DD`。
- `ingested_at`：本次处理日期 `YYYY-MM-DD`。
- `status`：枚举，三选一 —— `integrated`（已按 Type D 落档）/ `skipped-not-finance`（非财经，跳过）/ `needs-manual`（内容不足，需人工）。
- `target_file`：`status` 为 `integrated` 时填写 `investment-views` 中实际落档的 reference 路径（如 `references/storage.md`）；其余两种状态填 `null`。
- **每条视频处理完立即追加一行**（单条 checkpoint，运行中断后凭账本去重续跑）。
- 去重：下次运行读全部行的 `id` 构成已处理集合，跳过其中任何已存在的 `id`。
