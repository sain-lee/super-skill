---
name: install-open-source-skill
description: 当用户想安装某个开源的 Claude Code skill 或 plugin（例如 superpowers），或想把第三方 skill 引入自己环境时使用。负责判断分发形式（plugin marketplace / 散装 skill 文件）、给出对应安装步骤、验证是否生效，并把已安装项追加到本文件末尾的「已安装清单」。
---

# 安装开源 Claude Code Skill / Plugin

帮用户把开源的 Claude Code skill 或 plugin 装进环境，并把安装记录沉淀下来。

## 步骤

### 1. 判断分发形式

先确认目标是哪种形式（看仓库 README）：

- **Plugin（插件）**：仓库带 `plugin.json` / `.claude-plugin/` / hooks / marketplace 配置，README 让你用 `/plugin` 命令安装。**这类必须走 plugin 路径**，散装复制会丢 hooks，功能不全。
- **散装 skill 文件**：仓库就是一堆 `SKILL.md`（或 `skills/<name>/SKILL.md`），没有 plugin 结构。这类可直接放进 skills 目录。

拿不准时优先按 README 写的官方方式来。

### 2a. Plugin 形式 → marketplace 安装

有两条路，**优先用 CLI（Claude 能直接代跑，无需用户手动）**：

**A. `claude plugin` CLI（推荐，非交互，Claude 可代跑）**

```bash
claude plugin marketplace list                       # 看已注册 marketplace
claude plugin marketplace add <owner>/<repo>          # 需要时再注册社区 marketplace
claude plugin install <plugin>@<marketplace>          # 安装（默认 scope: user）
claude plugin list                                    # 验证：状态应为 enabled
claude plugin details <plugin>                        # 看 skills/hooks 清单与 token 成本
```

`install -s/--scope` 可选 `user`（全局，默认）/ `project` / `local`。`anthropics/claude-plugins-official` 通常已预注册，名为 `claude-plugins-official`。

**B. `/plugin` 交互 TUI（用户在输入框亲自输入，Claude 跑不了这个）**

```
/plugin marketplace add <owner>/<repo>
/plugin install <plugin>@<marketplace>
```

两种等价；能用 CLI 就用 CLI。装完一般无需重启，但**带 SessionStart hook 的插件要新开会话**才完整生效。
Claude 的职责：查清该插件 README 里的**确切命令**和 marketplace 标识，能代跑就代跑，跑完验证。

### 2b. 散装 skill 形式 → 放进 skills 目录

1. `git clone <repo-url>` 到临时位置（或 `/tmp`）。
2. 把每个 skill 目录复制到目标 skills 路径：
   - 用户级（全局可用）：`~/.claude/skills/<skill-name>/`
   - 项目级（仅该项目）：`<project>/.claude/skills/<skill-name>/`
3. 确认每个 skill 是 `<skill-name>/SKILL.md` 结构、frontmatter 含 `name` 和 `description`。
4. 清理临时 clone。

### 3. 验证

- Plugin：跑 `/plugin`（或对应管理命令）确认已列出并启用；按 README 说明触发一次看是否生效。
- 散装 skill：在 Claude Code 里 `/<skill-name>` 能被识别即成功。

### 4. 记录

每成功安装一个，**追加一条**到下面的「已安装清单」：来源仓库、形式、确切命令、验证方式、安装日期。保持清单是当前环境的真实快照。

## 注意事项

- 第三方代码会进入你的 agent 流程：装前快速扫一眼仓库，确认来源可信、star/活跃度正常，留意它注入的 hooks/指令。
- 能用 `claude plugin` CLI 就代跑；只有交互式 `/plugin` TUI 需要用户亲自输入。
- 安装位置选用户级（默认）还是项目级，拿不准先问用户。
- 带 SessionStart hook 的插件：装好后提醒用户**新开会话**才完整生效。
- **枚举 marketplace 里有哪些插件，必须以权威清单为准**：注册后读本地
  `~/.claude/plugins/marketplaces/<name>/.claude-plugin/marketplace.json`，
  或直连 `raw.githubusercontent.com/.../marketplace.json` 解析。**不要拿
  WebFetch / README 摘要当完整列表**——它是小模型生成的有损概括，会漏项、会给错数量
  （本 skill 初版就因此把 10 个插件误报成 4 个）。报数量/清单前先核对权威源。

---

## 已安装清单

环境快照，最后更新 2026-05-17。全部 scope=user，`claude plugin list` 均 ✔ enabled。

### marketplaces

- `claude-plugins-official` — GitHub `anthropics/claude-plugins-official`（预注册，官方）
- `superpowers-marketplace` — GitHub `obra/superpowers-marketplace`（社区，本次 `claude plugin marketplace add obra/superpowers-marketplace` 注册；权威清单 = 该仓库 `.claude-plugin/marketplace.json`，共 **10 个插件**）

### 已装插件（8）

| 插件@marketplace | 版本 | 组成 | 备注 |
|---|---|---|---|
| superpowers@claude-plugins-official | 5.1.0 | 14 skills + 1 SessionStart hook（常驻 ~723 tok） | 核心方法论库；hook 需新开会话生效 |
| elements-of-style@superpowers-marketplace | 1.0.0 | 1 skill（writing-clearly-and-concisely） | Strunk 写作规则 |
| superpowers-developing-for-claude-code@superpowers-marketplace | 0.3.1 | 2 skills（developing-claude-code-plugins / working-with-claude-code） | 开发插件/skill/MCP 的资源+官方文档 |
| private-journal-mcp@superpowers-marketplace | 1.2.0 | MCP server（Node/TS 包） | ⚠️ 插件壳已装，MCP 本体是 npm 包，可能需 `npm install`+构建才真正可用；`details` 显示 MCP 0 |
| double-shot-latte@superpowers-marketplace | 1.2.0 | 1 Stop hook | 自动判断是否继续，消除“要不要继续”打断 |
| episodic-memory@superpowers-marketplace | 1.4.1 | 1 skill + 1 SessionStart hook + 1 MCP server（episodic-memory） | 跨会话语义记忆；hook 需新开会话生效 |
| superpowers-chrome@superpowers-marketplace | 2.1.0 | 1 skill（browsing，17 CLI 命令 / MCP 模式） | BETA，轻度测试；需本机 Chrome |
| claude-session-driver@superpowers-marketplace | 2.0.1 | 1 skill + 5 hooks（PreToolUse/SessionStart/Stop/UserPromptSubmit/SessionEnd） | 经 tmux 操控其它 Claude 会话；需 tmux；hook 多，新开会话生效 |

安装方式统一为 CLI 代跑：`claude plugin install <plugin>@<marketplace>`（scope user）。

### 未装 / 跳过（superpowers-marketplace 剩余 2）

- `superpowers-lab` — 实验性杂项（tmux 自动化 / MCP 发现 / Slack 等）。用户本次未选；需要再装。
- `superpowers-dev` — DEV 分支，**装前必须先卸载其它 superpowers 版本**，与已装 `superpowers` 冲突，**不装**。

### 通用验证 / 生效提醒

- 验证：`claude plugin list`（状态 enabled）+ `claude plugin details <plugin>`（组件清单）。
- 多个插件带 SessionStart/Stop/PreToolUse 等 hook：**需新开 Claude Code 会话**这些 hook 才真正挂上。
- `private-journal-mcp` / `episodic-memory` 的 MCP server 首次使用前可能需各自的运行依赖（Node 等），用到时再按其 README 启用。
