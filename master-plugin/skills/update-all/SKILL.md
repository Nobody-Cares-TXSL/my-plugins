---
name: update-all
description: 一键更新所有已启用 Claude Code 插件、npm/pipx/uv tool 包、opencli、agent-reach、notebooklm、opencode 并同步 Obsidian 文档；也可传组件名只更新单个组件
argument-hint: [plugins|opencode|opencli|agent-reach|notebooklm|npm|pipx|uv]
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
| `opencli` | `update-opencli.sh` | opencli CLI + skills 生态 |
| `agent-reach` | `update-agent-reach.sh` | agent-reach CLI + skill |
| `notebooklm` | `update-notebooklm.sh` | notebooklm CLI + skill |
| `npm` | `update-npm.sh` | npm 全局包 |
| `pipx` | `update-pipx.sh` | pipx 安装的 CLI |
| `uv` | `uv tool upgrade --all` | uv tool 安装的 CLI（harlequin、laya、paper-search-mcp 等） |
| `hard` | `check-hard-updates.sh` | 散装二进制（只检查，需手动安装） |

## 全量流程（无参数）

### 任务追踪

开始前，若当前环境注册了 `TaskCreate`/`TaskUpdate`，就创建以下 12 个任务并逐步更新为 in_progress → completed；未注册则顺序执行，每步结束向用户简报进度。两种方式结果等价，不要因缺工具跳过步骤：

1. **版本快照（更新前）** — snapshot.sh before，保存 UPDATE_BEFORE
2. **Claude Code 插件** — update-plugins.sh
3. **opencode CLI** — update-opencode.sh（curl 二进制更新）
4. **npm 全局包** — update-npm.sh（须在 opencli 之前）
5. **pipx 包** — update-pipx.sh（须在 agent-reach/notebooklm 之前）
6. **uv tool 包** — `uv tool upgrade --all`（与 pipx 并列的独立渠道，互不覆盖）
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
- （uv tool 无独立脚本，直接 `uv tool upgrade --all`）
- `update-opencode.sh` — opencode CLI 二进制更新
- `check-hard-updates.sh` — 发现散装二进制（apt/npm/pipx 管不到的），只读检查 + 通用下载器；**不自动安装**

### 执行命令

#### 版本快照（更新前）

```bash
export http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890
bash ${CLAUDE_SKILL_DIR}/scripts/snapshot.sh before
```

#### Claude Code 插件

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-plugins.sh
```

#### opencode CLI

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-opencode.sh
```

#### npm 全局包

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-npm.sh
```

> 脚本先跑 `npm outdated -g`（~14s），无更新则跳过 `npm update -g`。后者会重算整棵依赖树，实测**空跑 5 分钟、有更新时 11 分钟**（本次实测 `changed 1172 packages in 11m`）——这是全流程最大的单点耗时，别改回去。
> **预期超过前台 600s 超时**，用 `run_in_background: true` 执行，或设 `timeout: 600000` 后等其转后台；转后台不等于失败。

#### pipx 包

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-pipx.sh
```

#### uv tool 包

```bash
export http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890
uv tool upgrade --all
```

> 与 pipx 是两个独立渠道：`uv tool list` 里的 harlequin、laya、paper-search-mcp 等不归 pipx 管，pipx 升级不到它们。这两个渠道都不要遍历 `~/.local/share/uv/tools/*/bin/`——那里混着每个工具的全部依赖可执行文件（python、tqdm、typer 等），会淹没有效信息。

#### opencli CLI + Skills

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-opencli.sh
```

> 脚本内部已包含 nvm 加载逻辑，无需手动 source。npm 全量已在前一步跑过，此处的 `npm update -g @jackwener/opencli` 通常为 no-op。

#### agent-reach

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-agent-reach.sh
```

> pipx 全量已跑过，此处的 `pipx upgrade agent-reach` 通常为 no-op。

#### notebooklm

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-notebooklm.sh
```

> 同上，`pipx upgrade notebooklm-py` 通常为 no-op。

#### 散装二进制检查

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/check-hard-updates.sh
```

列出候选后，对每个查上游最新版，用 AskUserQuestion 让用户勾选要更新的，再逐个下载：

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/check-hard-updates.sh --download <url>
```

> **不自动安装**——下载到 `~/下载` 后由用户手动执行安装命令（多数需 sudo）。

#### 版本快照（更新后）

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/snapshot.sh after
```

**对比两次快照**，输出变更摘要（使用 `⬆️` 标记升级、`✅` 标记无变化、`⚠️` 标记跨大版本升级）。检测 [opencli 生态] 组是否有新/移除的 skill（独立 skill 由各自来源管理，不计入 opencli 变更）。

两次快照同时落盘在 `$TMPDIR/update-all-snapshot-{before,after}.txt`（TMPDIR 为空时为 `~/.cache/tmp/`），上下文丢失时可直接读文件对比。

### 文档更新

基于变更摘要，更新以下文档。**只改版本/状态字段**；无变更的工具不改动，在简报里说明「已实测核对，无需改动」即可——该文档无独立日期字段，不存在「至少更新日期」这回事。

#### `~/Project/obsidian/04 调研/工具栈/README.md`

- **信息获取章节**: last30days 通道状态、opencli 版本号 + 站点数/命令数 + skill 列表、agent-reach 版本号 + 通道数 + 级别（level: default/optional/experimental）分布
- **全局技能表**: opencli 和 agent-reach 的 skill 描述
- **插件表**: 各插件的技能列表

版本检测命令：
- opencli 站点数: `opencli --help 2>&1 | grep -oE 'Site adapters \([0-9]+\)'`（v2.0+ 起；1.x 无此行，退回 `opencli list | grep "built-in commands"`）
- opencli 命令数: `opencli list --limit 1 -f json 2>&1 | grep -oE '"total":[0-9]+'`（取 `total` 字段；勿数数组长度——`list` 默认只返回 25 条）
- agent-reach 通道数: `agent-reach doctor 2>&1 | grep -oE '"status": *"[^"]+"' | sort | uniq -c`（默认输出 JSON；`--text` 为人类可读表，无"状态："字段）
- 注意：本文档无独立"最后更新"字段，版本信息内嵌在标题（如 `#### opencli v2.0.2`）与表格中

#### 文档原则

- 只修改版本/状态字段，不重构结构
- 先 Read 文件再 Edit，保持格式一致
- 无变更的工具至少更新日期
- 不要写 `### v1.xx 主要更新` 版本更新日志段落
- **改完自检**：复核关键版本号与统计数字已同步，避免漏改

## 散装二进制（apt/npm/pipx 管不到的）

这些软件只能手动换二进制（如 fd、lazygit、yazi、starship、rtk、anki、px0）。流程：

1. **发现**：`bash ${CLAUDE_SKILL_DIR}/scripts/check-hard-updates.sh`（只读，列出候选 + 当前版本 + 属主 + 更新方式 + **上游/查新版**）
2. **查最新版**：按「上游/查新版」列执行，**并行查**——串行 8 个请求约 9 秒，并行约 3 秒：
   - `owner/repo` → `gh release view --repo <owner/repo> --json tagName -q .tagName`
   - `self: <cmd>` → 直接跑该命令（如 `uv self update --dry-run`、`magpie update check`、`rustup check`），**不要**用 `gh release` 查
   ```bash
   for r in <owner/repo>...; do
     env gh release view --repo "$r" --json tagName -q .tagName 2>/dev/null | sed "s|^|$r |" &
   done; wait
   ```
   > 表里显示 `-` 的，先 `gh search repos <name>` 定位仓库，**不要猜仓库名**（猜错会得到空结果，白跑一轮）。
   > 用 `gh` 而非 `curl api.github.com`：匿名 API 会 403 限流（实测 `API rate limit exceeded`）。
3. **让用户选**：用 AskUserQuestion 列出可更新项，用户勾选
4. **下载**：`bash ${CLAUDE_SKILL_DIR}/scripts/check-hard-updates.sh --download <url> <目标路径>`（下载到 `~/下载`，**不安装**；目标路径用于按属主生成准确的安装命令）
5. **用户手动安装**：脚本给出安装命令，由用户执行（目录不可写时自动带 sudo）

> 更新方式有五类，**按脚本输出的「更新方式」列照做，不要按路径猜**：
>
> | 更新方式 | 命令 | 说明 |
> |---|---|---|
> | `自更新` | 脚本最后一列给出的命令（`uv self update`、`rustup check` 等） | 走工具自带机制 |
> | `uv tool` | `uv tool upgrade <名>` | 与 pipx 独立 |
> | `cargo 更新` | `cargo install <名> --locked` | 来源是 **crates.io**，升级安全 |
> | `本地源码` | 在该包的源码目录执行 `cargo install --force --path .` | 来源是 **本地 `--path`**，见下方警告 |
> | `手动下载` | 下 release 包后手动装 | 无包管理器 |
>
> **`本地源码` 是危险项，不能当 `cargo 更新` 处理。** 这类包不在 crates.io 上，或虽同名但源码已被本地修改。若误用 `cargo install <名>`，cargo 会去 crates.io 装回同名上游版本，等于把本地改动全部覆盖掉——典型如 `tmux-expose`：本地是二开版 0.1.0，crates.io 上的同名上游是 0.8.0，装回会丢失全部二次开发功能。
>
> 脚本用 `~/.cargo/.crates.toml` 判定来源，判据是安装记录里的 `registry+https://...` 还是 `path+file:///...`，不靠路径前缀猜。遇到 `本地源码`，最后一列已给出源码目录，直接在该目录执行 `cargo install --force --path .`。

### 有意不检查的类型

`check-hard-updates.sh` 只列 ELF 二进制。以下**没有出现在结果里是正常的**，不代表漏扫：

| 类型 | 例子 | 为什么不列 | 实际怎么维护 |
|---|---|---|---|
| shell / python 本机脚本 | `md-read-hd`、`tmux-suspend-ueberzug`、`mimeapps-guard.sh`、`check-hard-updates` | 不是 ELF，且无上游可查 | 手工改，随仓库/文档同步 |
| uv tool 命令 | `harlequin`、`hsql`、`laya` | 是 `~/.local/bin` 下的符号链接 | 已在结果中单列，走 `uv tool upgrade` |
| 软链兼容层 | `fd`→`fdfind`、`magick`→`convert` | 符号链接，指向 APT 管理的真实程序 | 随 APT 更新 |
| rustup 组件 | `cargo`、`rustc`、`rustfmt`、`clippy` | 都是指向 `rustup` 的符号链接 | `rustup update` |
| 备份/下载残留 | `*.bak*`、`*.new`、`*.old` | 不是已安装软件 | — |

> 看到某个工具"没被列出"时，先查上表。若它确实是有上游的 ELF 却没出现，多半是 `SCAN_DIRS` 没覆盖它的目录，或它是符号链接。

### 与终端环境文档的职责边界

`04 调研/工具栈/终端环境/`（14 份文档）记录的是另一组工具：Yazi、tmux、Starship、lazygit、Alacritty、ueberzugpp 等。它们的关系是：

- 这些工具的版本**会**出现在 `check-hard-updates.sh` 结果里，可照常更新。
- 但它们**不在** `snapshot.sh` 采集范围内，所以不会进变更摘要。
- 本技能**不自动修改**终端环境文档。更新了 Yazi / tmux / Alacritty 之类之后，需要按该目录的 `CLAUDE.md` 规则手工同步，或明确告知用户「终端环境文档未更新」。

### 完成提示

```
全部更新完成！运行 /reload-plugins 使新版本生效。
```

## 单组件流程（传组件名）

只执行参数解析表中该组件对应的脚本，命令写法同上（`bash ${CLAUDE_SKILL_DIR}/scripts/<脚本>`）。

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
| agent-reach skill | `~/.agents/skills/agent-reach/`（权威）；`~/.claude/skills/agent-reach` 为符号链接 | `Panniantong/Agent-Reach` → `agent_reach/skill/` |
| opencli CLI | 全局 npm | `@jackwener/opencli` |
| opencode CLI | `~/.opencode/bin/opencode` | `opencode upgrade --method curl` |
| agent-reach CLI | pipx venv | `agent-reach` PyPI |
| notebooklm CLI + skill | pipx venv + `~/.claude/skills/notebooklm/` | `teng-lin/notebooklm-py` PyPI |
| npm 全局包 | `~/.nvm/versions/node/*/lib/node_modules` | `npm update -g` |
| pipx CLI | `~/.local/share/pipx/venvs/` | `pipx upgrade-all` |
| uv tool CLI | `~/.local/share/uv/tools/`（命令软链在 `~/.local/bin/`） | `uv tool upgrade --all` |
| cargo 安装来源 | `~/.cargo/.crates.toml` | 判定 `registry+`（crates.io）还是 `path+`（本地源码） |
