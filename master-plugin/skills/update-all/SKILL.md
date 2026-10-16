---
name: update-all
description: 一键更新所有已启用 Claude Code 插件、npm/pipx 包、opencli、agent-reach、notebooklm、opencode 并同步 Obsidian 文档；也可传组件名只更新单个组件
argument-hint: [plugins|opencode|commands|opencli|agent-reach|notebooklm|npm|pipx]
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

# update-all — 工具链更新

更新 Claude Code 工具链。无参数时全量更新并同步文档；传组件名时只更新该组件。

## 参数解析

`$ARGUMENTS` 的第一个词为组件名（可选）：

- **无参数** → 全量流程（更新全部组件 + 快照对比 + 同步 Obsidian 文档）
- **合法组件名** → 单组件流程（只跑该组件脚本，跳过快照与文档）
- **未知组件名 / 多余参数** → 输出下方组件清单并终止，不回退全量

| 组件名 | 脚本 | 更新内容 |
|--------|------|---------|
| `plugins` | `update-plugins.sh` | 已启用 Claude Code 插件 |
| `opencode` | `update-opencode.sh` | opencode CLI 二进制 |
| `commands` | `update-opencode-commands.sh` | opencode.jsonc 命令同步 |
| `opencli` | `update-opencli.sh` | opencli CLI + skills 生态 |
| `agent-reach` | `update-agent-reach.sh` | agent-reach CLI + skill |
| `notebooklm` | `update-notebooklm.sh` | notebooklm CLI + skill |
| `npm` | `update-npm.sh` | npm 全局包 |
| `pipx` | `update-pipx.sh` | pipx 安装的 CLI |
| `hard` | `check-hard-updates.sh` | 散装二进制（只检查，需手动安装） |

## 全量流程（无参数）

### 任务追踪

开始前，用 TaskCreate 创建以下 12 个任务，按顺序逐步 TaskUpdate 为 in_progress → completed：

1. **版本快照（更新前）** — snapshot.sh before，保存 UPDATE_BEFORE
2. **Claude Code 插件** — update-plugins.sh
3. **opencode CLI** — update-opencode.sh（curl 二进制更新）
4. **opencode commands** — update-opencode-commands.sh
5. **npm 全局包** — update-npm.sh（须在 opencli 之前）
6. **pipx 包** — update-pipx.sh（须在 agent-reach/notebooklm 之前）
7. **opencli** — update-opencli.sh（含 nvm 加载；npm 全量已跑过，此处为 no-op）
8. **agent-reach** — update-agent-reach.sh（pipx 全量已跑过，此处为 no-op）
9. **notebooklm** — update-notebooklm.sh（同上）
10. **散装二进制检查** — check-hard-updates.sh（只读扫描 + 查最新版 + AskUserQuestion 让用户选 + 下载到 ~/下载，**由用户手动安装**）
11. **版本快照（更新后）+ 对比** — snapshot.sh after，输出变更摘要
12. **更新 Obsidian 文档** — README.md

完成后输出 reload 提示。

### 脚本

所有脚本位于 `scripts/` 目录：
- `snapshot.sh` — 版本快照
- `update-plugins.sh` — Claude Code 插件
- `update-opencli.sh` — opencli CLI + skills
- `update-agent-reach.sh` — agent-reach CLI + skill
- `update-notebooklm.sh` — notebooklm CLI + skill
- `update-npm.sh` — npm 全局包
- `update-pipx.sh` — pipx 安装的 CLI
- `update-opencode.sh` — opencode CLI 二进制更新
- `update-opencode-commands.sh` — opencode.jsonc commands 同步（中文描述映射见 `commands-desc.txt`）
- `check-hard-updates.sh` — 发现散装二进制（apt/npm/pipx 管不到的），只读检查 + 通用下载器；**不自动安装**

### 执行命令

#### 版本快照（更新前）

```bash
export http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890
bash {skillDir}/scripts/snapshot.sh before
```

#### Claude Code 插件

```bash
bash {skillDir}/scripts/update-plugins.sh
```

#### opencode CLI

```bash
bash {skillDir}/scripts/update-opencode.sh
```

#### opencode commands 同步

```bash
bash {skillDir}/scripts/update-opencode-commands.sh
```

#### npm 全局包

```bash
bash {skillDir}/scripts/update-npm.sh
```

#### pipx 包

```bash
bash {skillDir}/scripts/update-pipx.sh
```

#### opencli CLI + Skills

```bash
bash {skillDir}/scripts/update-opencli.sh
```

> 脚本内部已包含 nvm 加载逻辑，无需手动 source。npm 全量已在前一步跑过，此处的 `npm update -g @jackwener/opencli` 通常为 no-op。

#### agent-reach

```bash
bash {skillDir}/scripts/update-agent-reach.sh
```

> pipx 全量已跑过，此处的 `pipx upgrade agent-reach` 通常为 no-op。

#### notebooklm

```bash
bash {skillDir}/scripts/update-notebooklm.sh
```

> 同上，`pipx upgrade notebooklm-py` 通常为 no-op。

#### 散装二进制检查

```bash
bash {skillDir}/scripts/check-hard-updates.sh
```

列出候选后，对每个查上游最新版，用 AskUserQuestion 让用户勾选要更新的，再逐个下载：

```bash
bash {skillDir}/scripts/check-hard-updates.sh --download <url>
```

> **不自动安装**——下载到 `~/下载` 后由用户手动执行安装命令（多数需 sudo）。

#### 版本快照（更新后）

```bash
bash {skillDir}/scripts/snapshot.sh after
```

**对比两次快照**，输出变更摘要（使用 `⬆️` 标记升级、`✅` 标记无变化、`⚠️` 标记跨大版本升级）。检测 [opencli 生态] 组是否有新/移除的 skill（独立 skill 由各自来源管理，不计入 opencli 变更）。

两次快照同时落盘在 `$TMPDIR/update-all-snapshot-{before,after}.txt`（TMPDIR 为空时为 `~/.cache/tmp/`），上下文丢失时可直接读文件对比。

### 文档更新

基于变更摘要，更新以下文档。**所有工具都更新文档**，无变更的至少更新日期。

#### `~/Project/obsidian/04 调研/工具栈/README.md`

- **信息获取章节**: last30days 通道状态、opencli 版本号 + 站点数/命令数 + skill 列表、agent-reach 版本号 + 通道数 + Tier 状态
- **全局技能表**: opencli 和 agent-reach 的 skill 描述
- **插件表**: 各插件的技能列表

版本检测命令：
- opencli 站点/命令数: `opencli list 2>&1 | grep "built-in commands"`（输出格式如 `1050 built-in commands across 162 sites, 13 external CLIs`；勿用 `tail -1`，node warning 会挤掉统计行）
- agent-reach 通道数: `agent-reach doctor 2>&1 | grep "状态："`
- 注意：本文档无独立"最后更新"字段，版本信息内嵌在标题（如 `#### opencli v1.8.7`）与表格中

#### 文档原则

- 只修改版本/状态字段，不重构结构
- 先 Read 文件再 Edit，保持格式一致
- 无变更的工具至少更新日期
- 不要写 `### v1.xx 主要更新` 版本更新日志段落
- **改完自检**：复核关键版本号与统计数字已同步，避免漏改

## 散装二进制（apt/npm/pipx 管不到的）

这些软件只能手动换二进制（如 fd、lazygit、yazi、starship、rtk、anki、px0）。流程：

1. **发现**：`bash {skillDir}/scripts/check-hard-updates.sh`（只读，列出候选 + 当前版本 + 属主 + 更新方式）
2. **查最新版**：对每个候选查上游最新版（GitHub releases）
3. **让用户选**：用 AskUserQuestion 列出可更新项，用户勾选
4. **下载**：`bash {skillDir}/scripts/check-hard-updates.sh --download <url>`（下载到 `~/下载`，**不安装**）
5. **用户手动安装**：脚本给出安装命令，由用户执行（多数需 sudo）

> `自更新` 标记的软件（uv/magpie/rustup 等）应走自带命令，不用手动换二进制。

### 完成提示

```
全部更新完成！运行 /reload-plugins 使新版本生效。
```

## 单组件流程（传组件名）

只执行参数解析表中该组件对应的脚本，命令写法同上（`bash {skillDir}/scripts/<脚本>`）。

- **不做**版本快照（`snapshot.sh before/after`）、**不做**变更摘要对比
- **不做** Obsidian 文档更新
- 完成后输出：`<组件名> 更新完成。`
- 若组件为 `plugins`，追加提示：`运行 /reload-plugins 使新版本生效。`

## 关键路径

| 组件 | 配置/数据路径 | 源仓库 |
|------|-------------|--------|
| 已启用插件列表 | `~/.claude/settings.json` → `enabledPlugins` | — |
| 插件安装信息 | `~/.claude/plugins/installed_plugins.json` | — |
| opencli skills（生态） | `~/.agents/skills/`（通用 agent skills 目录，opencli 生态占其中一部分）+ `~/.claude/skills/` (symlinks) | `jackwener/opencli` |
| agent-reach skill | `~/.claude/skills/agent-reach/` | `Panniantong/Agent-Reach` → `agent_reach/skill/` |
| opencli CLI | 全局 npm | `@jackwener/opencli` |
| opencode CLI | `~/.opencode/bin/opencode` | `opencode upgrade --method curl` |
| agent-reach CLI | pipx venv | `agent-reach` PyPI |
| notebooklm CLI + skill | pipx venv + `~/.claude/skills/notebooklm/` | `teng-lin/notebooklm-py` PyPI |
| npm 全局包 | `~/.nvm/versions/node/*/lib/node_modules` | `npm update -g` |
| pipx CLI | `~/.local/share/pipx/venvs/` | `pipx upgrade-all` |
