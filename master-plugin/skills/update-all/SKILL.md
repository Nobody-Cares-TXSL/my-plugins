---
name: update-all
description: 一键更新所有已启用 Claude Code 插件、opencli、agent-reach、notebooklm、opencode 并同步 Obsidian 文档；也可传组件名只更新单个组件
argument-hint: [plugins|opencode|commands|opencli|agent-reach|notebooklm]
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

## 全量流程（无参数）

### 任务追踪

开始前，用 TaskCreate 创建以下 9 个任务，按顺序逐步 TaskUpdate 为 in_progress → completed：

1. **版本快照（更新前）** — snapshot.sh before，保存 UPDATE_BEFORE
2. **Claude Code 插件** — update-plugins.sh
3. **opencode CLI** — update-opencode.sh（curl 二进制更新）
4. **opencode commands** — update-opencode-commands.sh
5. **opencli** — update-opencli.sh（含 nvm 加载）
6. **agent-reach** — update-agent-reach.sh
7. **notebooklm** — update-notebooklm.sh（pipx upgrade + skill install）
8. **版本快照（更新后）+ 对比** — snapshot.sh after，输出变更摘要
9. **更新 Obsidian 文档** — README.md + Superpowers_Gstack_README.md

完成后输出 reload 提示。

### 脚本

所有脚本位于 `scripts/` 目录：
- `snapshot.sh` — 版本快照
- `update-plugins.sh` — Claude Code 插件
- `update-opencli.sh` — opencli CLI + skills
- `update-agent-reach.sh` — agent-reach CLI + skill
- `update-notebooklm.sh` — notebooklm CLI + skill
- `update-opencode.sh` — opencode CLI 二进制更新
- `update-opencode-commands.sh` — opencode.jsonc commands 同步（中文描述映射见 `commands-desc.txt`）

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

#### opencli CLI + Skills

```bash
bash {skillDir}/scripts/update-opencli.sh
```

> 脚本内部已包含 nvm 加载逻辑，无需手动 source。

#### agent-reach

```bash
bash {skillDir}/scripts/update-agent-reach.sh
```

#### notebooklm

```bash
bash {skillDir}/scripts/update-notebooklm.sh
```

#### 版本快照（更新后）

```bash
bash {skillDir}/scripts/snapshot.sh after
```

**对比两次快照**，输出变更摘要（使用 `⬆️` 标记升级、`✅` 标记无变化）。检测 [opencli 生态] 组是否有新/移除的 skill（独立 skill 由各自来源管理，不计入 opencli 变更）。

### 文档更新

基于变更摘要，更新以下两个文档。**所有工具都更新文档**，无变更的至少更新日期。

#### 文档 A: `~/Project/obsidian/04 调研/工具栈/README.md`

- **信息获取章节**: last30days 通道状态、opencli 版本号 + 站点数/命令数 + skill 列表、agent-reach 版本号 + 通道数 + Tier 状态
- **全局技能表**: opencli 和 agent-reach 的 skill 描述
- **插件表**: 各插件的技能列表

版本检测命令：
- opencli 站点/命令数: `opencli list 2>&1 | grep "built-in commands"`（输出格式如 `1050 built-in commands across 162 sites, 13 external CLIs`；勿用 `tail -1`，node warning 会挤掉统计行）
- agent-reach 通道数: `agent-reach doctor 2>&1 | grep "状态："`
- 注意：本文档无独立"最后更新"字段，版本信息内嵌在标题（如 `#### opencli v1.8.7`）与表格中

#### 文档 B: `~/Project/obsidian/04 调研/工具栈/Superpowers_Gstack_README.md`

- 最后更新日期（L5 的 `> 最后更新：YYYY-MM-DD，...` 行）
- Superpowers 版本号（从 `installed_plugins.json` 读取）
- 新增 skill 补充到对应分组

#### 文档原则

- 只修改版本/状态字段，不重构结构
- 先 Read 文件再 Edit，保持格式一致
- 无变更的工具至少更新日期
- 不要写 `### v1.xx 主要更新` 版本更新日志段落

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
