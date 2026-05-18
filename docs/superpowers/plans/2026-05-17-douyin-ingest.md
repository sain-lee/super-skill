# douyin-ingest Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. REQUIRED AUTHORING SUB-SKILL: Use superpowers:writing-skills when writing/verifying SKILL.md.

**Goal:** Build a `douyin-ingest` skill that scans the user's Douyin 收藏夹, extracts new finance/stock video content, and integrates it into the `investment-views` knowledge base via its existing Type D flow.

**Architecture:** The deliverable is a markdown procedure skill (`SKILL.md` + one references file + a JSONL state ledger), not executable code. It drives Chrome through the `superpowers-chrome:browsing` MCP tool using a dedicated logged-in headed profile, discovers DOM at runtime instead of hardcoding selectors, extracts content via a 3-tier degradation ladder, and hands integration off to `investment-views` Type D (single source of truth — never duplicated here).

**Verification model (read this — there is no pytest):** A skill has no unit tests. "Tests" in this plan mean: (a) structural/placeholder checks on the markdown, (b) trigger-description evaluation (does the `description` fire on the right phrases and stay quiet on `investment-views` queries), (c) a one-time human-in-loop smoke run against real Douyin (needs the user's login). Each task states its concrete pass criteria.

**Tech Stack:** Markdown skill; `superpowers-chrome:browsing` (`mcp__chrome__use_browser`); `superpowers:writing-skills` for authoring/verification; `investment-views` skill for integration; JSONL ledger.

**Spec:** `docs/superpowers/specs/2026-05-17-douyin-ingest-design.md`

---

## File Structure

All paths relative to repo root `/Users/lisai/code/super-skill`.

- Create: `skills/douyin-ingest/SKILL.md` — when-to-use + the 7-unit procedure at readable depth + pointers to references. Kept lean (frontmatter `description` always loads).
- Create: `skills/douyin-ingest/references/operations.md` — runtime DOM discovery, 3-tier extraction ladder, anti-bot etiquette, login flow detail, ledger JSONL schema. Detail lives here so SKILL.md stays focused.
- Create: `skills/douyin-ingest/state/ingested.jsonl` — append-only dedup ledger, seeded empty, tracked in git.
- Read-only reference (do NOT modify in this plan): `skills/investment-views/SKILL.md` — its Type D flow is the integration contract.

Decomposition rationale: SKILL.md = the procedure the agent follows; operations.md = volatile/defensive detail that would bloat SKILL.md; state/ = data that changes every run. Integration rules are NOT a file here — they are referenced from `investment-views` to keep one source of truth.

---

### Task 1: Scaffold skill dir + frontmatter & trigger description

**Files:**
- Create: `skills/douyin-ingest/SKILL.md`
- Create: `skills/douyin-ingest/state/ingested.jsonl` (empty)

- [ ] **Step 1: Define acceptance — trigger / non-trigger phrase set**

Write this list into the plan tracking (used in Task 5 too). The `description` MUST cause invocation on:
- "扫一下抖音收藏" / "扫收藏夹"
- "更新抖音收藏到投资库"
- "把抖音新收藏的财经视频整理进来"
- "同步抖音收藏" / "ingest 抖音"

The `description` MUST NOT cause this skill to fire on pure knowledge queries (those belong to `investment-views`):
- "光模块还能拿吗"
- "恩哥怎么看存储"
- "HBM 周期到顶了吗"

- [ ] **Step 2: Create the empty ledger**

```bash
mkdir -p skills/douyin-ingest/state skills/douyin-ingest/references
: > skills/douyin-ingest/state/ingested.jsonl
```

- [ ] **Step 3: Write SKILL.md frontmatter + section skeleton**

Create `skills/douyin-ingest/SKILL.md` with exactly this frontmatter, then empty `##` headings for the 7 units (filled in Task 2):

```markdown
---
name: douyin-ingest
description: 当用户要从抖音收藏夹批量采集新的财经/股票视频并整合进投资知识库时使用。触发语：『扫一下抖音收藏』『扫收藏夹』『更新抖音收藏到投资库』『把抖音新收藏的财经视频整理进来』『同步抖音收藏』『ingest 抖音』等采集动作。本 skill 负责：用 superpowers-chrome 控制专用已登录的有头 Chrome profile 打开抖音『我的-收藏』、枚举新增收藏视频、三级降级提取视频内容、过滤出财经/股票相关项、按 investment-views 的 Type D 流程落档、用 JSONL 账本去重幂等。不要在用户只是查询投资观点（如『光模块还能拿吗』『恩哥怎么看存储』『HBM 周期到顶了吗』）时触发——查询是 investment-views 的职责；本 skill 只在用户要『去抖音取新视频』这一采集动作时触发。
---

# douyin-ingest

## 何时使用

## 前置：登录态保障

## 步骤 1 · 枚举收藏

## 步骤 2 · 去重

## 步骤 3 · 提取视频内容（三级降级）

## 步骤 4 · 财经相关性过滤

## 步骤 5 · 整合（复用 investment-views Type D）

## 步骤 6 · 账本 + 报告

## 注意事项
```

- [ ] **Step 4: Verify — frontmatter valid & collision-checked**

Run:
```bash
head -3 skills/douyin-ingest/SKILL.md
grep -c "不要在用户只是查询投资观点" skills/douyin-ingest/SKILL.md
test -f skills/douyin-ingest/state/ingested.jsonl && echo "ledger ok"
```
Expected: frontmatter present; grep returns `1` (explicit anti-collision clause exists); `ledger ok`.
Manually confirm the `description` contains every positive trigger phrase from Step 1 and the explicit "不要…investment-views 的职责" exclusion.

- [ ] **Step 5: Commit**

```bash
git add skills/douyin-ingest/SKILL.md skills/douyin-ingest/state/ingested.jsonl
git commit -m "feat(douyin-ingest): scaffold skill dir, frontmatter, empty ledger"
```

---

### Task 2: Write the 7-unit procedure body in SKILL.md

**Files:**
- Modify: `skills/douyin-ingest/SKILL.md` (fill the skeleton from Task 1)

- [ ] **Step 1: Write "何时使用" + "前置：登录态保障"**

Fill these two sections. Required content:
- 何时使用: restate the采集动作触发条件; one line clarifying division of labor vs `investment-views` (this skill = 去取新视频; investment-views = 查询/整合规则).
- 前置：登录态保障:
  - Use `superpowers-chrome:browsing`. Profile name `douyin`, **headed mode** (set profile, then `show_browser`).
  - Navigate to Douyin personal page; detect logged-in vs logged-out by extracting page and checking for a logged-in marker (discover at runtime — see `references/operations.md`).
  - If logged out: STOP and tell the user to scan the QR in the visible window; wait; re-check. Never automate login.
  - State that login persists in the `douyin` profile (one-time).
  - Pointer: "DOM 发现与异常处理细节见 `references/operations.md`".

- [ ] **Step 2: Write "步骤 1 · 枚举收藏" + "步骤 2 · 去重"**

- 枚举收藏: navigate to 我的-收藏; progressive human-paced scroll until the list stops growing; `extract` page; collect `{videoId, url, title}` by matching `/video/\d+` links + stable `data-e2e` attrs — **do not hardcode hashed class names**; defer pattern detail to operations.md.
- 去重: read `skills/douyin-ingest/state/ingested.jsonl`, build the set of seen `id`; filter the enumerated list to new ids only; if none new → jump straight to 步骤 6 报告 and end.

- [ ] **Step 3: Write "步骤 3 · 提取视频内容（三级降级）"**

State the exact 3-tier ladder (full detail in operations.md, but the ladder itself must be in SKILL.md):
1. 找抖音「视频文稿 / AI 总结 / 智能总结 / 文案」入口，展开取全文。
2. 取不到 → 标题 + 作者 + 简介 + 可见字幕/置顶评论。
3. 仍不足以判断 → 状态标 `needs-manual`，**不写入知识库**（不得用幻觉填充）。
Also capture per video: 作者名、发布日期。

- [ ] **Step 4: Write "步骤 4 · 财经相关性过滤"**

Judge finance/stock relevance using `investment-views` 的 5 大重点领域 + 覆盖话题. Not relevant → ledger `skipped-not-finance`, do not integrate. Explicitly: 不硬套非覆盖话题（比亚迪/白酒/医药/债券/ETF 配置）.

- [ ] **Step 5: Write "步骤 5 · 整合（复用 investment-views Type D）"**

This section MUST NOT restate Type D rules. It must say, in effect:
- 加载 `investment-views` skill 并严格按其 SKILL.md 的 Type D 执行。
- 结构化为 核心观点 / 数据参考 / 投资逻辑 / 风险点。
- 作者匹配已知博主清单；未知博主按 V3.0 待收录处理。
- 落档路由、保留博主原话、时间戳（视频发布日 +「2026-05 收录」）、更新 §7 表 / 版本号 / 最后更新日期 / 待补充 V3.0 清单 —— 全部以 investment-views Type D 为准。
- 一句话强调：路由表与整合规则的唯一来源是 investment-views，本 skill 不复制。

- [ ] **Step 6: Write "步骤 6 · 账本 + 报告" + "注意事项"**

- 账本: every processed video → append one JSONL line immediately (single-video checkpoint, resumable). Schema lives in operations.md; SKILL.md references the path `skills/douyin-ingest/state/ingested.jsonl` and the `status ∈ {integrated, skipped-not-finance, needs-manual}` enum.
- 报告: end with summary — 扫描数 / 整合数（落哪个档）/ 跳过数 / 需人工数.
- 注意事项 (bullet list, must include): 有头专用 profile；运行时发现选择器不硬编码；提取不确定就降级标记绝不编造；账本幂等可续跑；整合规则单一来源；反爬失败即停报告不硬刚不绕风控；收藏量大可分次跑完。

- [ ] **Step 7: Verify — structural & placeholder & no-duplication checks**

Run:
```bash
grep -nE "TBD|TODO|待补充实现|FIXME|XXX" skills/douyin-ingest/SKILL.md || echo "no placeholders"
for s in "何时使用" "登录态保障" "枚举收藏" "去重" "三级降级" "财经相关性过滤" "Type D" "账本" "注意事项"; do grep -q "$s" skills/douyin-ingest/SKILL.md && echo "OK: $s" || echo "MISSING: $s"; done
grep -nE "核心观点 */ *数据参考|路由优先级|blogger_views.md|storage.md" skills/douyin-ingest/SKILL.md && echo "WARN: possible Type D duplication — must reference investment-views instead" || echo "no Type D duplication"
```
Expected: `no placeholders`; every `OK:` line present, no `MISSING:`; `no Type D duplication` (step 5 should point to investment-views, not mirror its routing table).

- [ ] **Step 8: Commit**

```bash
git add skills/douyin-ingest/SKILL.md
git commit -m "feat(douyin-ingest): write 7-unit procedure body"
```

---

### Task 3: Write references/operations.md

**Files:**
- Create: `skills/douyin-ingest/references/operations.md`

- [ ] **Step 1: Write the runtime-discovery section**

Content:
- 登录态判定：导航个人页后 `extract` markdown/html，找登录标志（头像/「我的」入口/未登录则有「登录」按钮）；判定逻辑描述为"找文案特征"而非固定选择器。
- 收藏列表枚举：在「我的-收藏」tab 下渐进 `scroll` (payload "down")，每次滚动后 `await` 短暂、`extract` html，用正则 `/video/\d+` 收集链接与其可见标题；用 `data-e2e` 等语义属性辅助定位 tab/卡片；滚到 `extract` 不再新增链接为止；明确"绝不写死哈希类名"。
- 抖音 AI 文稿入口发现：打开视频页后 `extract`，按可见文案候选词搜索可点击元素——"文稿"/"视频文稿"/"AI"/"总结"/"智能总结"/"文案"；找到则 `click` 展开再 `extract` 该面板文本。入口形态/位置不确定且会变 → 必须运行时发现，不可硬编码。

- [ ] **Step 2: Write the 3-tier extraction ladder (detail)**

Spell out each tier's exact actions, what to capture (作者/发布日期/正文), and the hard rule: tier 3 → `needs-manual`, 不写知识库, 不编造. Include guidance: if AI 文稿 returns suspiciously short/empty, treat as tier-1 failure and fall to tier 2.

- [ ] **Step 3: Write anti-bot etiquette section**

Rules: 有头真实 `douyin` profile；类人节奏（滚动分批 + 每步间隔，不要瞬时狂滚）；单条之间留间隔；若出现验证码/风控页/异常重定向 → 立即停止该轮，写已完成部分的账本，报告并交回用户，**不尝试绕过风控、不逆向接口**.

- [ ] **Step 4: Write the ledger schema section**

Document the exact JSONL line and the path `skills/douyin-ingest/state/ingested.jsonl`:

```json
{"id":"<douyin video id>","url":"https://www.douyin.com/video/<id>","title":"...","blogger":"恩哥-拿着别动","video_date":"YYYY-MM-DD","ingested_at":"YYYY-MM-DD","status":"integrated","target_file":"references/storage.md"}
```
Rules: one line per video; `status ∈ {integrated, skipped-not-finance, needs-manual}`; `target_file` = the investment-views reference path when `integrated`, else `null`; append immediately after each video (checkpoint); dedup key = `id`.

- [ ] **Step 5: Verify — every spec risk/principle is covered**

Run:
```bash
for s in "运行时发现" "三级" "needs-manual" "类人" "风控" "ingested.jsonl" "status" "去重"; do grep -q "$s" skills/douyin-ingest/references/operations.md && echo "OK: $s" || echo "MISSING: $s"; done
grep -nE "TBD|TODO|FIXME" skills/douyin-ingest/references/operations.md || echo "no placeholders"
```
Expected: all `OK:`, `no placeholders`.

- [ ] **Step 6: Commit**

```bash
git add skills/douyin-ingest/references/operations.md
git commit -m "feat(douyin-ingest): add operations reference (discovery, ladder, anti-bot, ledger)"
```

---

### Task 4: Cross-file path & schema consistency check

**Files:**
- Modify (only if mismatch found): `skills/douyin-ingest/SKILL.md`, `skills/douyin-ingest/references/operations.md`

- [ ] **Step 1: Verify path & enum consistency across SKILL.md, operations.md, spec**

Run:
```bash
grep -rn "ingested.jsonl" skills/douyin-ingest docs/superpowers/specs/2026-05-17-douyin-ingest-design.md
grep -rn "skipped-not-finance\|needs-manual\|integrated" skills/douyin-ingest
```
Expected: the ledger path string is identical (`skills/douyin-ingest/state/ingested.jsonl`) everywhere it appears; the three status values are spelled identically in SKILL.md and operations.md. Fix any drift inline (e.g. a `clearLayers` vs `clearFullLayers` style mismatch).

- [ ] **Step 2: Commit (only if a fix was needed)**

```bash
git add -A skills/douyin-ingest
git commit -m "fix(douyin-ingest): align ledger path and status enum across files"
```
If nothing changed, skip this commit.

---

### Task 5: Trigger-description evaluation

**Files:**
- Modify (if mis-trigger found): `skills/douyin-ingest/SKILL.md` frontmatter `description`

- [ ] **Step 1: Author/verify with writing-skills**

Invoke `superpowers:writing-skills` and follow its description/verification guidance for this skill. Use it to sanity-check the `description` against the phrase set from Task 1 Step 1.

- [ ] **Step 2: Positive-trigger reasoning check**

For each positive phrase ("扫一下抖音收藏", "更新抖音收藏到投资库", "把抖音新收藏的财经视频整理进来", "同步抖音收藏", "ingest 抖音"): confirm the `description` wording would plausibly select THIS skill. If any phrase is weakly covered, add it explicitly to the `description`.

- [ ] **Step 3: Negative / collision check vs investment-views**

For each query phrase ("光模块还能拿吗", "恩哥怎么看存储", "HBM 周期到顶了吗"): confirm the `description`'s explicit exclusion clause keeps THIS skill from firing and routes to `investment-views`. Read `skills/investment-views/SKILL.md` frontmatter and confirm no overlapping trigger wording. Tighten the exclusion clause if there's any ambiguity.

- [ ] **Step 4: Verify**

Run:
```bash
diff <(grep -o "扫一下抖音收藏\|更新抖音收藏\|把抖音新收藏\|同步抖音收藏\|ingest 抖音" skills/douyin-ingest/SKILL.md | sort -u) <(printf '%s\n' "扫一下抖音收藏" "更新抖音收藏" "把抖音新收藏" "同步抖音收藏" "ingest 抖音" | sort -u) && echo "all positive phrases present"
grep -q "investment-views 的职责\|查询是 investment-views" skills/douyin-ingest/SKILL.md && echo "exclusion clause present"
```
Expected: `all positive phrases present`; `exclusion clause present`.

- [ ] **Step 5: Commit (only if description changed)**

```bash
git add skills/douyin-ingest/SKILL.md
git commit -m "fix(douyin-ingest): tighten trigger description and investment-views collision guard"
```

---

### Task 6: End-to-end smoke run (human-in-loop checkpoint)

**Files:**
- Modify (only to fix defects found): files under `skills/douyin-ingest/`
- Side effects: appends to `skills/douyin-ingest/state/ingested.jsonl`; may update `skills/investment-views/references/*` and `SKILL.md` per Type D

- [ ] **Step 1: Cold-start login flow**

Invoke the `douyin-ingest` skill. Confirm it: switches to `douyin` profile + headed, navigates Douyin, detects logged-out, and STOPS asking the user to scan the QR. User logs in. Confirm it resumes and detects logged-in. Pass: login persisted in `douyin` profile, no automated-login attempt.

- [ ] **Step 2: Enumerate + extract a small batch**

Let it enumerate 收藏 and process the first few new videos. Pass criteria (spec §9):
- finance video → structured per Type D and written to the correct `investment-views` reference file; §7 table / version / date / V3.0 list updated.
- non-finance video → `skipped-not-finance` in ledger, no KB write.
- under-extracted video → `needs-manual` in ledger, no KB write, no fabricated content.

- [ ] **Step 3: Idempotency check**

Run the skill a second time. Pass: already-processed videoIds are NOT re-written; only genuinely new favorites are processed; ledger has no duplicate `id` for the same `status`.

- [ ] **Step 4: Anti-bot behavior check**

Confirm scrolling/pacing was human-like and that if any risk/captcha page had appeared the skill would have stopped + reported (verify the operations.md rule is actually followed, not just documented).

- [ ] **Step 5: Fix any defects found, then commit**

```bash
git add -A skills/douyin-ingest skills/investment-views
git commit -m "feat(douyin-ingest): pass end-to-end smoke; fixes from real Douyin run"
```
Commit the smoke-run KB updates and ledger together (auditable, consistent with how investment-views is curated in this repo).

- [ ] **Step 6: Final commit of plan completion**

```bash
git add docs/superpowers/plans/2026-05-17-douyin-ingest.md
git commit -m "docs(douyin-ingest): mark implementation plan complete"
```

---

## Self-Review

**Spec coverage:** Spec §5.1→Task 2 Step 1; §5.2→Task 2 Step 2 + Task 3 Step 1; §5.3→Task 2 Step 2; §5.4→Task 2 Step 3 + Task 3 Step 2; §5.5→Task 2 Step 4; §5.6→Task 2 Step 5 (references investment-views Type D, not duplicated); §5.7→Task 2 Step 6 + Task 3 Step 4; §6 data/state→Task 1 Step 2 + Task 3 Step 4 + Task 4; §7 principles→Task 2 Step 6 注意事项; §8 risks→Task 3 Steps 1-3 + Task 6 Step 4; §9 acceptance→Task 6 Steps 1-3. Triggering (spec §3)→Task 1 Step 1 + Task 5. No spec section left without a task.

**Placeholder scan:** No "TBD/TODO/implement later". Markdown content steps give the exact frontmatter, exact ledger schema, exact ladder, and exact verification commands. Prose sections give concrete required-content checklists rather than pre-writing every sentence — intentional, since authoring the prose IS the execution step (writing-skills sub-skill).

**Type consistency:** Ledger path `skills/douyin-ingest/state/ingested.jsonl` and status enum `{integrated, skipped-not-finance, needs-manual}` are spelled identically in Task 1, 2, 3, 4; Task 4 exists specifically to enforce this. Profile name `douyin` and the 3-tier ladder wording are consistent across Tasks 2, 3, 6.
