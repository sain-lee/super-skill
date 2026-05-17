---
name: example-skill
description: 模板示例，演示一个 skill 的标准写法。复制本目录作为新 skill 的起点，然后替换 name、description 和正文。实际使用中可删除本 skill。
---

# Example Skill

> 这是一个占位模板。把它复制成你自己的 skill 后，删掉这段引用说明。

## 何时使用

说明触发条件 —— 用户说了什么、出现了什么情况时，Claude 应该调用这个 skill。
（这部分的精简版要同步写进上面 frontmatter 的 `description`，因为 Claude 主要靠 `description` 决定是否触发。）

## 步骤

1. 第一步该做什么。
2. 第二步该做什么。
3. 完成后如何确认结果。

## 注意事项

- 列出边界条件、不该做的事、需要向用户确认的点。
- 如需脚本或模板，放在本目录下并在此引用，例如 `scripts/run.sh`。
