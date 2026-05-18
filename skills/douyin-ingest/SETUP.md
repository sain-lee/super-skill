# douyin-ingest 环境准备（一次性，机器级）

本文件把跑通 `douyin-ingest` 的**前置环境**固化进仓库，避免散落在机器本地记忆里。流程逻辑见 `SKILL.md`，运行时细节见 `references/operations.md`。下列命令已在 macOS（darwin x86_64）上实测通过（2026-05-18）。

> 为什么需要这些：`douyin-ingest` 的内容提取依赖抖音「问问AI」，它是**跨域 iframe**，必须用 **Playwright MCP**（frame API 才读得到）。superpowers-chrome 的 `use_browser` 读不到该 iframe。

## 1. Node ≥ 18（Playwright MCP 要求）

系统 Node 可能过旧（本机原为 v12，跑不了 MCP server）。**用户级**装 Node 20，不动系统 Node：

```bash
# darwin x64 示例；其它平台改 https://nodejs.org/dist 对应包名
V=v20.18.1; F=node-$V-darwin-x64.tar.gz
mkdir -p ~/.local/opt
curl -fsSL -o /tmp/$F "https://nodejs.org/dist/$V/$F"
tar -xzf /tmp/$F -C ~/.local/opt
# 让它在 PATH 最前（本机 ~/.zshrc 已有 export PATH="$HOME/.local/bin:$PATH"）
mkdir -p ~/.local/bin
for b in node npm npx; do ln -sf ~/.local/opt/node-$V-darwin-x64/bin/$b ~/.local/bin/$b; done
node -v   # 应为 v20.x
```

回退：`rm ~/.local/bin/{node,npm,npx}`（系统 Node 原样保留）。

## 2. 安装并注册 Playwright MCP

```bash
npm i -g @playwright/mcp@latest          # 用上面的 Node20 npm
NODE=$(command -v node)                    # 绝对路径，避免 MCP 启动时 PATH 歧义
CLI="$(npm root -g)/@playwright/mcp/cli.js"
PROFILE="$HOME/Library/Caches/superpowers/browser-profiles/douyin"   # 复用抖音登录态的 Chrome profile

claude mcp add playwright --scope user -- \
  "$NODE" "$CLI" --browser chrome --user-data-dir "$PROFILE"
```

`--browser chrome` 用系统已装 Google Chrome，不下载 Chromium。`--user-data-dir` 复用持久登录态。

验证：`claude mcp list` 应看到 `playwright … ✓ Connected`。

## 3. 重启 Claude 会话（必须）

MCP server 在**会话启动时 spawn**。注册后必须**新开 `claude` 会话**（`claude --resume` 也算新进程，会重新拉起 MCP）后 `mcp__playwright__browser_*` 工具才可用。

## 4. profile 锁

同一 `--user-data-dir` 不能两个 Chrome 同占。用 Playwright 前先关掉占用 douyin profile 的 superpowers-chrome Chrome：

```bash
pkill -f 'browser-profiles/douyin' 2>/dev/null; true
```

`douyin-ingest` 全流程以 Playwright 为唯一驱动。

## 5. 首次登录（一次性人工）

首次用该 profile 时抖音未登录。skill 会停在登录态判定，让你在**有头窗口**扫码登录。登录态持久化在 `--user-data-dir`，之后免登。**绝不自动化登录。**

## 6. 滑块风控（设计内人工兜底）

抖音对自动化导航偶发滑块拼图验证（"请完成下列验证后继续"），**与驱动无关**。skill 遇到即停、提示你在可见窗口手动拖过，再继续。**绝不程序化破解 / 绕风控 / 逆向接口。**

## 7. 验收自检

- `node -v` = v20.x
- `claude mcp list` 含 `playwright … ✓ Connected`
- 新会话里存在 `mcp__playwright__browser_navigate` 等工具
- 说「扫一下抖音收藏」能触发 `douyin-ingest` 并起 Chrome（首次需扫码/拖滑块）

## 本机实测值（worked example）

| 项 | 值 |
|---|---|
| Node | `~/.local/opt/node-v20.18.1-darwin-x64/bin/node`（v20.18.1, darwin x64） |
| Playwright MCP | `@playwright/mcp` v0.0.75，cli 在该 Node 的全局 `lib/node_modules/@playwright/mcp/cli.js` |
| MCP 注册 | user scope，写入 `~/.claude.json`，name=`playwright` |
| Chrome profile | `~/Library/Caches/superpowers/browser-profiles/douyin` |
| 账号 | 八百标兵奔北坡（登录态已持久在该 profile） |

不同平台/架构需改 Node 包名与路径；MCP 注册命令结构不变。
