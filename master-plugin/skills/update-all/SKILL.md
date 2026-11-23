---
name: update-all
description: 一键更新所有已启用 Claude Code 插件、npm/pipx/uv tool 包、agent-reach、notebooklm、npx skills 管理的 agent skills、opencode、omp、pi 并同步 Obsidian 文档；也可传组件名只更新单个组件
argument-hint: [plugins|opencode|omp|pi|agent-reach|notebooklm|skills|npm|pipx|uv]
allowed-tools: Bash Read Edit Write
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
| `omp` | `update-omp.sh` | omp（`@oh-my-pi/pi-coding-agent`，bun 全局，自更新） |
| `pi` | `update-pi.sh` | pi coding agent（自更新） |
| `agent-reach` | `update-agent-reach.sh` | agent-reach CLI + skill |
| `notebooklm` | `update-notebooklm.sh` | notebooklm CLI + skill |
| `skills` | `update-agent-skills.sh` | `npx skills` 管理的 `~/.agents/skills` 技能 |
| `npm` | `update-npm.sh` | npm 全局包 |
| `pipx` | `update-pipx.sh` | pipx 安装的 CLI |
| `uv` | `uv tool upgrade --all` | uv tool 安装的 CLI（harlequin、laya、paper-search-mcp 等） |
| `hard` | `check-hard-updates.sh` | 散装二进制（只检查，需手动安装） |

## 全量流程（无参数）

### 任务追踪

开始前，若当前环境注册了 `TaskCreate`/`TaskUpdate`，就创建以下任务并逐步更新为 in_progress → completed；未注册则顺序执行，每步结束向用户简报进度。两种方式结果等价，不要因缺工具跳过步骤：

1. **版本快照（更新前）** — snapshot.sh before，保存 UPDATE_BEFORE
2. **Claude Code 插件** — update-plugins.sh
3. **opencode CLI** — update-opencode.sh（curl 二进制更新）
4. **omp** — update-omp.sh（bun 全局包，`omp update`）
5. **pi** — update-pi.sh（`pi update`，自更新；与 omp 互不依赖，可并行）
6. **npm 全局包** — update-npm.sh
7. **pipx 包** — update-pipx.sh（须在 agent-reach/notebooklm 之前）
8. **uv tool 包** — `uv tool upgrade --all`（与 pipx 并列的独立渠道，互不覆盖）
9. **agent-reach** — update-agent-reach.sh（pipx 已由前面的 pipx 步骤覆盖；此处重点是 `update --sync-only` 刷新 skill）
10. **notebooklm** — update-notebooklm.sh（同上，重点是 `notebooklm skill install`）
11. **npx skills 管理的技能** — update-agent-skills.sh（`~/.agents/skills`）
12. **散装二进制检查** — check-hard-updates.sh（只读扫描 + 查最新版 + AskUserQuestion 让用户选 + 下载到 ~/下载，**由用户手动安装**）
13. **版本快照（更新后）+ 对比** — snapshot.sh after，输出变更摘要
14. **更新 Obsidian 文档** — README.md

完成后输出 reload 提示。

### 脚本

所有脚本位于 `scripts/` 目录：
- `snapshot.sh` — 版本快照
- `update-plugins.sh` — Claude Code 插件
- `update-agent-reach.sh` — agent-reach CLI + skill
- `update-notebooklm.sh` — notebooklm CLI + skill
- `update-agent-skills.sh` — `npx skills` 管理的 `~/.agents/skills` 技能
- `update-npm.sh` — npm 全局包
- `update-pipx.sh` — pipx 安装的 CLI
- （uv tool 无独立脚本，直接 `uv tool upgrade --all`）
- `update-opencode.sh` — opencode CLI 二进制更新
- `update-omp.sh` — omp（bun 全局包 `@oh-my-pi/pi-coding-agent`）
- `update-pi.sh` — pi coding agent
- `check-hard-updates.sh` — 发现散装二进制（apt/npm/pipx 管不到的），只读检查 + 通用下载器；**不自动安装**

### 环境注意事项（Claude Code Bash tool）

- **nvm 管理的命令必须用 `env` 调用**：`~/.zshrc` 把 node/npm/npx/mcporter/xreach/codex/codebuddy/agent-reach 包成懒加载函数；Bash tool 的 shell 快照里函数定义残缺，直接调用会报 `command not found: _nvm_lazy_run`。用 `env <cmd>` 直接 exec PATH 中的二进制即可。
- 若 PATH 中没有 nvm 的 node，先补 `export PATH="$(ls -d "$HOME"/.nvm/versions/node/*/bin | sort -V | tail -1):$PATH"`，再用 `env <cmd>`。
- 脚本内部是 bash，不加载 zsh 函数，不受此影响；此规则只针对 Bash tool 里直接手敲的命令（尤其是下方「文档更新」里的版本检测命令）。

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

#### omp

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-omp.sh
```

> omp 由 bun 全局安装（`@oh-my-pi/pi-coding-agent`），走自带 `omp update`；`--check` 只查不装。脚本已把 `~/.bun/bin` 补进 PATH。

#### pi

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-pi.sh
```

> `pi update` 默认只更新 pi 自身；`--all` 会连带更新已装扩展。本技能只做 self 更新，避免计划外改动扩展。

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

#### agent-reach

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-agent-reach.sh
```

> **注意 `pipx upgrade` 不是 no-op**：实测即使已是最新也要 7.6 秒（每次都重新解析 spec 并重拉 GitHub zip）。全量流程中 `pipx upgrade-all`（步骤 7）已覆盖同一包，此处可跳过 pipx 部分，只跑 `agent-reach update --sync-only`；单组件模式下才需要 `pipx upgrade`。
> skill 由 `agent-reach update --sync-only` 刷新（走上游 `manage.sync()` → `place_skill()`）：它会渲染 `{{VERSION}}` 与 `{{CHANNEL_TABLE}}` 并为各 agent 建链接。**不要**手工 `git clone` + `cp` 上游 `agent_reach/skill`——拿到的是未渲染模板，版本号会是字面量 `"{{VERSION}}"`。
> 不加 `--sync-only` 的 `agent-reach update` 会走 `manage.update()`，本机 `install_method` 为 `other` 时会触发 pipx→uv 迁移，属计划外变更。

#### notebooklm

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-notebooklm.sh
```

> 同上，`pipx upgrade notebooklm-py` 不是 no-op（实测已最新也要 1.7-9.6 秒）。全量流程中可跳过 pipx 部分，只跑 `notebooklm skill install`。

#### npx skills 管理的技能

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-agent-skills.sh
```

> 管理 `~/.agents/skills` 下由 `npx skills` 安装的技能（清单见 `~/.agents/.skill-lock.json`），来源包括 `mattpocock/skills`、`affaan-m/ECC`、`github/awesome-copilot` 等。
> 脚本显式传 `-g`：当前目录是 `$HOME` 时，`~/.agents/skills` 会被 npx 的 `hasProjectSkills()` 误判成 project skills。
> 只处理 lock 中登记过的技能；`~/.agents/skills` 里的手写技能（agent-reach、notebooklm、orca-*、orchestration）不在 lock 中，不会被触碰。
> 脚本用 `npx -y skills@latest`，不依赖全局安装；`~/.agents/.skill-lock.json` 不存在时直接跳过（退出 0），不中断全量流程。
> **并发从源头限制**：上游默认 4 路并发 clone（`DEFAULT_FETCH_CONCURRENCY`），走代理时并发握手易被掐断，报 `gnutls_handshake() failed`。脚本设 `SKILLS_CLONE_CONCURRENCY=2`（上游 `fetchConcurrency()` 读取，未写入 `--help`）；首轮失败时降为单路整轮重跑一次。update 是幂等的，已最新的技能会被跳过，无需解析输出定位具体哪一项。

#### 散装二进制检查

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/check-hard-updates.sh
```

列出候选后，对每个查上游最新版，用 AskUserQuestion 让用户勾选要更新的，再逐个下载：

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/check-hard-updates.sh --download <url>
```

> **不自动安装**——下载到 `~/下载` 后由用户手动执行安装命令（多数需 sudo）。
> 下载完成后脚本会以当前用户身份执行一次 `--version` 做冒烟测试（不安装、不 sudo；仅对可信来源的 release 使用）。若提示「无法运行」，多为 glibc/ABI 不兼容（实测 resvg 0.50.0 需 GLIBC_2.43，本机 2.39），改用源码编译：`cargo install <包名> --locked --version <版本>`。

#### 版本快照（更新后）

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/snapshot.sh after
```

**对比两次快照**，输出变更摘要（使用 `⬆️` 标记升级、`✅` 标记无变化、`⚠️` 标记跨大版本升级）。

两次快照同时落盘在 `$TMPDIR/update-all-snapshot-{before,after}.txt`（TMPDIR 为空时为 `~/.cache/tmp/`），上下文丢失时可直接读文件对比。

### 文档更新

基于变更摘要，更新以下文档。**只改版本/状态字段**；无变更的工具不改动，在简报里说明「已实测核对，无需改动」即可——该文档无独立日期字段，不存在「至少更新日期」这回事。

#### `~/Project/obsidian/04 调研/工具栈/README.md`

- **信息获取章节**: last30days 通道状态、agent-reach 版本号 + 通道数 + 级别（level: default/optional/experimental）分布
- **全局技能表**: agent-reach 的 skill 描述
- **插件表**: 各插件的技能列表

版本检测命令：
- agent-reach 通道数: `env agent-reach doctor 2>&1 | grep -oE '"status": *"[^"]+"' | sort | uniq -c`（默认输出 JSON；`--text` 为人类可读表，无"状态："字段）
- 注意：本文档无独立"最后更新"字段，版本信息内嵌在标题与表格中

#### 文档原则

- 只修改版本/状态字段，不重构结构
- 先 Read 文件再 Edit，保持格式一致
- 无变更的工具至少更新日期
- 不要写 `### v1.xx 主要更新` 版本更新日志段落
- **改完自检**：复核关键版本号与统计数字已同步，避免漏改

## 散装二进制（apt/npm/pipx 管不到的）

只读检查 + 通用下载器，**不自动安装**。完整流程（发现 / 查最新版 / 让用户选 / 下载 / 手动安装）、五类更新方式（含 `本地源码` 危险项），以及"有意不检查的类型"清单，见 [references/hard-binaries.md](references/hard-binaries.md)。

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
| npx skills 管理的技能 | `~/.agents/skills/`（清单：`~/.agents/.skill-lock.json`） | `mattpocock/skills`、`affaan-m/ECC`、`github/awesome-copilot` 等 |
| agent-reach skill | `~/.agents/skills/agent-reach/`（权威）；`~/.claude/skills/agent-reach` 为符号链接 | `Panniantong/Agent-Reach` → `agent_reach/skill/` |
| opencode CLI | `~/.opencode/bin/opencode` | `opencode upgrade --method curl` |
| omp CLI | `~/.bun/bin/omp` → bun 全局 `@oh-my-pi/pi-coding-agent` | `omp update` |
| pi CLI | `~/.pi/agent/bin/pi`（`~/.local/bin/pi` 为符号链接） | `pi update` |
| agent-reach CLI | pipx venv | `agent-reach` PyPI |
| notebooklm CLI + skill | pipx venv + `~/.claude/skills/notebooklm/` | `teng-lin/notebooklm-py` PyPI |
| npm 全局包 | `~/.nvm/versions/node/*/lib/node_modules` | `npm update -g` |
| pipx CLI | `~/.local/share/pipx/venvs/` | `pipx upgrade-all` |
| uv tool CLI | `~/.local/share/uv/tools/`（命令软链在 `~/.local/bin/`） | `uv tool upgrade --all` |
| cargo 安装来源 | `~/.cargo/.crates.toml` | 判定 `registry+`（crates.io）还是 `path+`（本地源码） |
