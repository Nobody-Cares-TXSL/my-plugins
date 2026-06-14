---
name: update-all
description: 一键更新所有已启用 Claude Code 插件、opencli、agent-reach、notebooklm、gstack、opencode 并同步 Obsidian 文档
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

# update-all — 工具链一键更新

一键更新所有 Claude Code 工具链并同步文档。

## 任务追踪

开始前，用 TaskCreate 创建以下 11 个任务，按顺序逐步 TaskUpdate 为 in_progress → completed：

1. **版本快照（更新前）** — snapshot.sh before，保存 UPDATE_BEFORE
2. **Claude Code 插件** — update-plugins.sh
3. **gstack** — git pull
4. **opencode CLI** — update-opencode.sh（curl 二进制更新）
5. **gstack→opencode 符号链接** — update-gstack-opencode.sh
6. **opencode commands** — update-opencode-commands.sh
7. **opencli** — update-opencli.sh（含 nvm 加载）
8. **agent-reach** — update-agent-reach.sh
9. **notebooklm** — pipx upgrade + skill install
10. **版本快照（更新后）+ 对比** — snapshot.sh after，输出变更摘要
11. **更新 Obsidian 文档** — README.md + Superpowers_Gstack_README.md

完成后输出 reload 提示。

## 脚本

所有脚本位于 `scripts/` 目录：
- `snapshot.sh` — 版本快照
- `update-plugins.sh` — Claude Code 插件
- `update-opencli.sh` — opencli CLI + skills
- `update-agent-reach.sh` — agent-reach CLI + skill
- `update-opencode.sh` — opencode CLI 二进制更新
- `update-gstack-opencode.sh` — gstack→opencode 符号链接
- `update-opencode-commands.sh` — opencode.jsonc commands 同步（中文描述映射见 `commands-desc.txt`）

## 执行命令

### 版本快照（更新前）

```bash
export http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890
bash {skillDir}/scripts/snapshot.sh before
```

### Claude Code 插件

```bash
bash {skillDir}/scripts/update-plugins.sh
```

### gstack

```bash
cd ~/.claude/skills/gstack && git pull origin main 2>&1
```

### opencode CLI

```bash
bash {skillDir}/scripts/update-opencode.sh
```

### gstack→opencode 符号链接同步

```bash
bash {skillDir}/scripts/update-gstack-opencode.sh
```

### opencode commands 同步

```bash
bash {skillDir}/scripts/update-opencode-commands.sh
```

### opencli CLI + Skills

```bash
bash {skillDir}/scripts/update-opencli.sh
```

> 脚本内部已包含 nvm 加载逻辑，无需手动 source。

### agent-reach

```bash
bash {skillDir}/scripts/update-agent-reach.sh
```

### notebooklm

```bash
pipx upgrade notebooklm-py 2>&1 && notebooklm skill install 2>&1
```

### 版本快照（更新后）

```bash
bash {skillDir}/scripts/snapshot.sh after
```

**对比两次快照**，输出变更摘要（使用 `⬆️` 标记升级、`✅` 标记无变化）。检测 [opencli 生态] 组是否有新/移除的 skill（独立 skill 由各自来源管理，不计入 opencli 变更）。

## 文档更新

基于变更摘要，更新以下两个文档。**所有工具都更新文档**，无变更的至少更新日期。

### 文档 A: `~/Project/obsidian/04 调研/工具栈/README.md`

- **信息获取章节**: last30days 通道状态、opencli 版本号 + 站点数/命令数 + skill 列表、agent-reach 版本号 + 通道数 + Tier 状态
- **全局技能表**: opencli 和 agent-reach 的 skill 描述
- **插件表**: 各插件的技能列表

版本检测命令：
- opencli 站点/命令数: `opencli list 2>&1 | grep "built-in commands"`（输出格式如 `1050 built-in commands across 162 sites, 13 external CLIs`；勿用 `tail -1`，node warning 会挤掉统计行）
- agent-reach 通道数: `agent-reach doctor 2>&1 | grep "状态："`

### 文档 B: `~/Project/obsidian/04 调研/工具栈/Superpowers_Gstack_README.md`

- 最后更新日期
- Superpowers 版本号（从 `installed_plugins.json` 读取）
- gstack 版本号和命令数（`cat ~/.claude/skills/gstack/VERSION`、`ls ~/.claude/skills/gstack/*/SKILL.md | wc -l`）
- 新增 skill 补充到对应分组

### 文档原则

- 只修改版本/状态字段，不重构结构
- 先 Read 文件再 Edit，保持格式一致
- 无变更的工具至少更新日期
- 不要写 `### v1.xx 主要更新` 版本更新日志段落

## 完成提示

```
全部更新完成！运行 /reload-plugins 使新版本生效。
```

## 关键路径

| 组件 | 配置/数据路径 | 源仓库 |
|------|-------------|--------|
| 已启用插件列表 | `~/.claude/settings.json` → `enabledPlugins` | — |
| 插件安装信息 | `~/.claude/plugins/installed_plugins.json` | — |
| gstack | `~/.claude/skills/gstack/` | `garrytan/gstack` |
| gstack (opencode) | `~/.config/opencode/skills/<name>/SKILL.md` → gstack 仓库 | 符号链接，由 `update-gstack-opencode.sh` 维护 |
| opencli skills（生态） | `~/.agents/skills/`（通用 agent skills 目录，opencli 生态占其中一部分）+ `~/.claude/skills/` (symlinks) | `jackwener/opencli` |
| agent-reach skill | `~/.claude/skills/agent-reach/` | `Panniantong/Agent-Reach` → `agent_reach/skill/` |
| opencli CLI | 全局 npm | `@jackwener/opencli` |
| opencode CLI | `~/.opencode/bin/opencode` | `opencode upgrade --method curl` |
| agent-reach CLI | pipx venv | `agent-reach` PyPI |
| notebooklm CLI + skill | pipx venv + `~/.claude/skills/notebooklm/` | `teng-lin/notebooklm-py` PyPI |
