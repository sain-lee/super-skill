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

`/plugin` 是 Claude Code 的**交互式内建命令，Claude 无法代跑**，必须让用户在 Claude Code 输入框里亲自输入。流程：

1. （若用社区 marketplace）注册 marketplace：
   `/plugin marketplace add <owner>/<marketplace-repo>`
2. 安装插件：
   `/plugin install <plugin-name>@<marketplace-name>`
3. 一般无需重启；插件 skills 在相应任务时自动激活。

Claude 的职责：查清该插件 README 里的**确切命令**和 marketplace 标识，逐条贴给用户让其输入，并在装好后协助验证。

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
- `/plugin` 系列命令 Claude 跑不了，永远让用户亲自输入。
- 安装位置选用户级还是项目级，先问清用户意图。

---

## 已安装清单

### superpowers — obra/superpowers

- **来源**：https://github.com/obra/superpowers （作者 Jesse Vincent / obra）
- **是什么**：一套 agentic 软件开发方法论 skills 合集（头脑风暴、规划、TDD、系统化调试、子 agent 代码评审、写新 skill 等），安装后在开发任务中自动引导工作流。
- **形式**：Plugin（marketplace）
- **安装命令**（用户在 Claude Code 输入框亲自输入，二选一）：
  - 官方 marketplace（推荐）：
    `/plugin install superpowers@claude-plugins-official`
  - 社区 marketplace（备选，两步）：
    `/plugin marketplace add obra/superpowers-marketplace`
    `/plugin install superpowers@superpowers-marketplace`
- **重启**：无需。
- **验证**：装好后开始一个开发任务，superpowers 会自动引导（如先做方案细化再写代码）；也可 `/plugin` 查看已启用列表。
- **安装日期**：2026-05-17（记录创建；以用户实际执行 `/plugin install` 为准）
