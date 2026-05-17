# super-skill

我的个人 [Claude Code](https://claude.com/claude-code) Skill 集合。

每个 skill 是 `skills/` 下的一个独立目录，核心是一个 `SKILL.md`：开头的 YAML frontmatter 声明 `name` 和 `description`，正文写给 Claude 看的操作指令。

## 目录结构

```
super-skill/
├── README.md
├── .gitignore
└── skills/
    └── <skill-name>/
        ├── SKILL.md          # 必需：frontmatter + 指令正文
        └── (可选) 脚本/模板/参考文件
```

## SKILL.md 写法

```markdown
---
name: my-skill
description: 一句话说明「何时」该用这个 skill —— Claude 靠这句话决定要不要触发它
---

# My Skill

给 Claude 的步骤化指令：要做什么、怎么做、注意什么。
可以引用同目录下的脚本或模板文件。
```

要点：

- `name`：kebab-case，和目录名一致。
- `description`：描述**触发场景**而非功能罗列，写清楚「用户说什么 / 遇到什么情况」时该用它。
- 正文：精炼、可执行的步骤。需要附带脚本、模板、示例时放在同目录并在正文里引用。

## 安装 / 使用

把某个 skill 目录放到 Claude Code 能识别的 skills 路径下（如项目级 `.claude/skills/` 或用户级 `~/.claude/skills/`），然后在 Claude Code 里用 `/<skill-name>` 调用。

## 新增一个 skill

```bash
mkdir -p skills/<skill-name>
$EDITOR skills/<skill-name>/SKILL.md
```

参考 `skills/example-skill/` 作为模板起点。
