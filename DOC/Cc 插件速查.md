# Claude Code 插件速查

一个插件 = **一个目录 + 一个清单**。目录里放 skills / agents / hooks / MCP 服务器等组件，`.claude-plugin/plugin.json` 给插件命名。Claude Code 把整个目录作为单元加载，所以能共享给团队、装进多个项目、发布到市场。

## 何时该用插件

| 情况 | 选择 |
|------|------|
| 只服务一个项目，或只服务你自己 | 保持独立配置（`.claude/` + `~/.claude/`） |
| 想共享给团队成员 / 装进多个项目 / 发布版本化发布 | 做成插件 |

移入插件后有两处变化：文件挪到插件根目录下（`skills/`、`agents/`、`hooks/hooks.json`、`.mcp.json`），组件获得插件名前缀（`/my-plugin:hello`）。前缀让两个插件各自提供 `hello` 而不冲突。

## 目录结构

```
my-plugin/                        # 插件根目录（= 传给 --plugin-dir 的目录）
├── .claude-plugin/
│   └── plugin.json               # 清单。只有它放 .claude-plugin/ 内
├── skills/<name>/SKILL.md        # 技能，每个一个目录
├── commands/<name>.md            # 旧格式（见下）
├── agents/<name>.md              # 子代理，支持子文件夹 → 冒号分隔
├── hooks/hooks.json              # hook 配置
├── monitors/monitors.json        # 会话后台监控命令
├── .mcp.json                     # MCP 服务器
├── .lsp.json                     # LSP 服务器
├── bin/<executable>              # 裸命令，启用后进 PATH
├── settings.json                 # 默认设置（仅 2 个键生效）
├── themes/<slug>.json            # 颜色主题
├── output-styles/<name>.md       # 输出样式
├── workflows/<name>.js           # 多子代理编排脚本
└── evals/                        # 测试套件
```

> 组件放进 `.claude-plugin/` 内**不会加载**。
> 插件根是插件自己的目录，**不是** `~/.claude/` 本身（`~/.claude/.mcp.json` 不加载）。
> 只有 `plugin.json` 是必需的，没有任何组件也是合法插件。

## 组件一览

| 组件 | 保存位置 | 用户看到 / 调用 | 清单键 |
|------|---------|----------------|--------|
| Skill | `skills/<name>/SKILL.md` | `/my-plugin:name`，Claude 也可自动匹配描述触发 | `skills`（追加，不替换扫描） |
| Command | `commands/<file>.md` | `/my-plugin:<file>` | `commands` |
| Agent | `agents/<name>.md` | `@agent-my-plugin:name` | `agents`（替换扫描） |
| Hook | `hooks/hooks.json` | 无 UI，事件触发 | `hooks`（与文件并存） |
| MCP 服务器 | `.mcp.json` | `/mcp` 中 `plugin:my-plugin:<server>` | `mcpServers` |
| LSP 服务器 | `.lsp.json` | 编辑器诊断 / 代码导航 | `lspServers` |
| 可执行文件 | `bin/<name>` | Bash 工具中作裸命令 | — |
| 默认设置 | `settings.json` | 启用即生效 | `settings` |
| 主题 | `themes/<slug>.json` | `/theme` | `experimental.themes` |
| 输出样式 | `output-styles/<name>.md` | `/output-style` | `outputStyles` |
| Monitor | `monitors/monitors.json` | 输出作通知到达 Claude | `experimental.monitors` |
| Workflow | `workflows/<name>.js` | `/my-plugin:<name>` | — |
| Channel | MCP 服务器 + `channels` 条目 | 外部系统向会话发消息 | `channels` |

**Commands 是旧格式**：新组件写成 skills——调用方式相同，还能带支持文件。已有 `commands/` 的保留不动。

**Skill 命名**：`/<plugin>:<目录名>`；frontmatter 里的 `name` 替换最后一段，插件前缀不变。插件根目录单个 `SKILL.md` 也是一个 skill，但要显式设 `name`。

**插件不会加载插件根目录的 `CLAUDE.md`**，`claude plugin validate` 会警告。想给人看说明就写成 skill。

## plugin.json 清单

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Review, formatting, and database tools for this team"
}
```

| 要点 | 说明 |
|------|------|
| `name` | 唯一必需字段 |
| `version` | 用户的缓存键。**不改它，用户就收不到更新** |
| `description` | `/plugin` 中显示的文案 |
| `userConfig` | 向用户索取的配置值，见下 |

### userConfig（要求用户提供配置）

**为什么需要**：插件要调用某个团队的 API，就得知道**地址**和**令牌**——这些每个用户都不同，不能写死在插件里。`userConfig` 让插件声明"我需要哪些值"，由 Claude Code 弹表单收集、存起来，插件运行时直接读。

```json
{
  "userConfig": {
    "api_url":   { "type": "string", "title": "API URL", "description": "Base URL" },
    "api_token": { "type": "string", "title": "API token", "description": "Team token", "sensitive": true }
  }
}
```

| 要点 | 说明 |
|------|------|
| 插件的声明 | `title` 是表单标签，`description` 显示在下方 |
| `"sensitive": true` | 加在令牌/密码上：输入框显示为遮蔽，值存**安全存储**（非 `settings.json`）；普通值直接存 `settings.json` |
| 插件怎么读值 | 代码里写 `${user_config.<key>}`，即上面声明的 key 名 |
| 对话框何时弹 | `/plugin` 中安装 / `/plugin install` / 在 Installed 标签启用；随时 `/plugin configure <plugin>@<marketplace>` 补填 |
| **不会弹**的情况 | `--plugin-dir` 加载和 `claude plugin install`（命令行弹不了表单）——shell 里只能 `--config KEY=VALUE`，或事后 `claude plugin configure --values-stdin` |
| 例外 | Monitor 命令拿不到 `${user_config.*}`，引用它的 monitor 不启动 |

### settings.json 只有两个键生效

插件可以带 `settings.json` 改变会话行为，但**只有 `agent` 和 `subagentStatusLine` 生效，其余键被静默丢弃**——写了别的设置以为生效，其实被扔掉了。

同一个键在多处设置时的优先级（**用户永远压过插件**）：

```
用户自己的 ~/.claude/settings.json     ← 最高
  ↑ 插件的 settings.json           ← 存在且含支持键时，压过清单内联 settings
  ↑ 清单内联的 settings 字段        ← 最低
```

## 路径变量

插件装到哪、用户机器什么样，写插件时都不知道，所以路径用变量代替：

| 变量 | 大白话 |
|------|------|
| `${CLAUDE_PLUGIN_ROOT}` | “插件现在装在哪儿”。**每次更新路径都会变** → **别往里存东西**，会丢 |
| `${CLAUDE_PLUGIN_DATA}` | “插件可以安心存东西的地方”：`~/.claude/plugins/data/<id>/`，首次引用时创建。**更新不丢**，装 `node_modules`、venv、缓存都放这儿 |
| `${CLAUDE_PROJECT_DIR}` | 当前项目根目录 |

`<id>` 是把插件名安全化：`@` 等不能进文件夹名的字符替换为 `-`（`my-plugin@my-marketplace` → `my-plugin-my-marketplace`），你不用管。

这三个变量在 skill / 命令 / agent 内容、hook 和 monitor 命令、MCP / LSP 配置里**都会自动替换**，并导出给这些进程。

> **Hook 引号规则**：不加 `args` 时命令经 **shell** 执行，路径里有空格会被拆成两个词 → **必须用双引号包住**。
> 改用 `args` 数组时**不走 shell**，每个元素独立传参，**不需要引号**。
> 记法：**走 shell（只有 command）→ 加引号；走 args → 不加**。

## 开发工作流

### 三种加载方式

| 方式 | 作用范围 | 命令 |
|------|---------|------|
| `--plugin-dir` | 单会话，可重复传，可传 `.zip` 或包含多个插件的插件文件夹 | `claude --plugin-dir ./my-plugin` |
| `claude plugin init <name>` | 每会话自动加载，写入 `~/.claude/skills/<name>/` | `claude plugin init my-tool --with skills` |
| `--plugin-url` | 单会话，从 URL 取 `.zip` | `claude --plugin-url https://…/p.zip` |

`--plugin-dir` 也可用环境变量 `CLAUDE_CODE_PLUGIN_DIRS` 代替（绝对路径列表，v2.1.280+）。改文件后用 `/reload-plugins` 生效。

**插件文件夹的加载规则**（需要 v2.1.265+）：传一个文件夹时，若它没有 `.claude-plugin/` 且顶层无插件组件，Claude Code 就把它当作插件文件夹——其下**每个带 `.claude-plugin/plugin.json` 的直接子文件夹**各作为一个插件加载，其余内容静默跳过（含没有清单的子文件夹）。若文件夹旁边有 `.claude-plugin/marketplace.json`（v2.1.281+），**只要该 `.claude-plugin/` 内不含 `plugin.json`**，插件仍照常加载。

> `--plugin-dir` 传**市场根目录**不会加载 `plugins/` 下的插件，也不报错——要指向单个插件的文件夹。

### 调试四步循环

1. `claude plugin validate <path>` — 校验清单和各组件 frontmatter，通过退出 0（`--strict` 警告也失败）
2. `/reload-plugins` — 应用磁盘改动，打印 `Reloaded:` 计数
3. `/plugin` — **Installed** 标签列出插件（选中插件后详情里显示找到的组件），**Errors** 标签说明什么没加载及原因
4. `claude plugin list` — 打印仅会话和技能目录插件，带 `Status: ✔ loaded` 或错误。**要包含你正在开发的插件，先给它传 `--plugin-dir`**：`claude --plugin-dir ./my-plugin plugin list`

MCP 看 `/mcp`（健康即"已连接"）；hook 触发它匹配的事件后读调试日志（`PostToolUse` 退出 0 时不显示任何东西）。

### 从 `.claude/` 迁移

| 组件 | 迁移后是否冲突 |
|------|--------------|
| Skills / Agents | 不冲突（有 `my-plugin:` 前缀，`/deploy` 与 `/my-plugin:deploy` 并存） |
| Hooks | **冲突**：无前缀，两处同时存在会每次触发跑两次 |

确认插件可用后再删 `.claude/` 下的原文件，并从设置文件中移除 `hooks` 对象。

## 依赖

在 `plugin.json` 的 `dependencies` 数组声明。条目是裸名字符串，或对象：

```json
{
  "name": "deploy-kit",
  "version": "3.1.0",
  "dependencies": [
    "audit-logger",
    { "name": "secrets-vault", "version": "~2.1.0", "marketplace": "other-mkt" }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `name` | 依赖插件名，默认在**同一市场**查找（除非设 `marketplace`） |
| `version` | semver 范围（`~2.1.0` / `^2.0` / `>=1.4` / `=2.1.0`）。不写则跟随市场最新版 |
| `marketplace` | 跨市场解析，需根市场允许列表放行 |

**约束针对 git 标签解析**：标签格式 `<plugin-name>--v<version>`，用 `claude plugin tag --push` 创建（会校验、要求工作树干净、拒绝已存在标签）。装到满足范围的最高标签处。`.claude-plugin/marketplace.json` 中相对路径引用的插件，标签由市场仓库创建。

**跨市场**：默认拒绝安装来自其他市场的依赖，除非用户已自行装过。要放行，在**根市场**的 `marketplace.json` 加 `"allowCrossMarketplaceDependenciesOn": ["目标市场"]`。

**捆绑包模式**：发布一个只有 `name` + `dependencies` 的插件，团队一个 `claude plugin install` 装齐整套。

**本地联调**：`claude --plugin-dir ./my-dependency --plugin-dir ./my-plugin`，本地副本满足依赖，无需发布。本地副本无需 `version`（约束不针对本地副本检查）。

**解析失败时**：有自身仓库的插件安装直接失败（`Dependency "…" has no git tag satisfying…`）；由相对路径引用的插件改用市场当前副本，**若该副本落在范围之外**则依赖保持禁用，`claude plugin list` 显示 `Requires "…" ~2.1.0, installed 3.0.0`（范围内则正常加载）。

## 发布

| 路线 | 谁可安装 | 需要什么 | 自动更新 |
|------|---------|---------|---------|
| 无市场 | 你发文件夹 / `.zip` 的人 | 插件目录 | 无 |
| 自己的市场 | 能克隆仓库的人 | 带 `.claude-plugin/marketplace.json` 的 git 仓库 | 默认关 |
| Anthropic 目录 | claude.ai / Cowork 用户 | GitHub 仓库 + 付费 claude.ai 计划 | 是 |

### 自己的市场

```json
{
  "name": "your-marketplace",
  "owner": { "name": "Your Name" },
  "plugins": [ { "name": "deploy-helper", "source": "./" } ]
}
```

条目 `name` 必须与 `plugin.json` 的 `name` 一致。推送前 `claude plugin validate .`。

用户端两条命令：
```
claude plugin marketplace add your-org/your-marketplace
claude plugin install deploy-helper@your-marketplace
```
（会话内一步：`/plugin install deploy-helper --marketplace your-org/your-marketplace`）

### 更新、重命名、删除

- **发新版**：bump `plugin.json` 的 `version` 并 push。用户 `claude plugin update` 或开启自动更新后收到
- **改 `name` = 破坏性**：老用户会丢失插件。用市场文件的 `renames` 映射迁移，只改展示名用 `displayName`

## 测试 evals

`claude plugin eval` 用隔离的非交互会话跑测试用例并打分。默认每个用例**每个臂**跑 3 次（`runs`，1–50），分数 = 通过的评分器比例。一次套件约 `cases × runs` 次代理运行，加上无插件基线的同等数量。**每次运行都是真实的模型调用，会计费。**

**默认值链**：`--model` 依次取 用例 `model` → 环境变量 `ANTHROPIC_MODEL` → Claude Code 默认；`--judge-model` 默认用后台任务模型。CI 里两个都固定，否则模型发布会被误判成插件回归。

```bash
claude plugin eval init          # 交互式生成用例和评分器
claude plugin eval init --bare first-case   # 空白模板（CI 用）
claude plugin eval .             # 从插件根跑全套
claude plugin eval . --allow-tools Write Edit "Bash(npm test *)"
```

### 套件结构

```
evals/
├── <case>/                    # 一个目录 = 一个用例
│   ├── prompt.md              # frontmatter: 运行字段；正文: 提示词
│   ├── case.yaml              # 可选：context.* 字段
│   ├── graders/<name>.md      # 每个文件一个评分器（至少一个，否则加载失败）
│   └── mocks/                 # 仅该用例的 mock
├── mocks/<server>/<tool>.md   # 套件级 MCP mock
└── results/<timestamp>/       # 每次运行写入；加入 .gitignore
```

### 评分器类型

| 类型 | 关键选项 | 通过条件 | 计费 |
|------|---------|---------|------|
| `regex` | `pattern` `flags` `match` `target` | 目标中匹配到 JS 正则（`match: not_contains`=要求缺失，`count:N`=恰好 N 次） | 免费 |
| `tool_used` | `tool` `input_match` `min` `max` | 工具调用次数在 `min`（默认 1）和 `max` 之间 | 免费 |
| `tool_order` | `before` `after` | `before` 的首次调用早于 `after` 的首次调用 | 免费 |
| `file_exists` | `path` `exists` | 匹配 glob 的**新建**文件存在 / 不存在 | 免费 |
| `llm` | `criteria` `focus` | 评判模型三次投票中两次 PASS 评分标准 | 调模型 |
| `baseline` | `baseline_file` `criteria` | 评判认为运行至少与参考记录一样好 | 调模型 |

**评分器能看到什么**（`target` / `focus` 取值）：`last_message`（默认，最终回复）、`trace`（整个会话 JSON，每行一条，引号转义为 `\"`；**`llm` 评判只看前 12 条和最后 12 条**）、`files`（新建路径列表，**非内容**）、`{ source: file, path: … }`（某文件内容，评分生成文件用这个）、`mock_calls`。

### 针对无插件基线评分（Δ）

**为什么需要**：光有高分说明不了插件有用——Claude 不装插件也可能做对。所以要跑两遍对比：一遍加载插件（with-arm，报 `WITH`），一遍不加载（without-arm，报 `W/OUT`）。两者之差 `Δ = WITH − W/OUT` 才是插件的实际贡献；若两边都满分，说明插件不是通过的原因。

以下评分器**不计入**两臂运行的分数（在 without-arm 中永远不可能通过，计入会夸大 Δ）：所有 `tool_used: Skill`、`target: mock_calls` 的 `regex`、`focus: mock_calls` 的 `llm`（且相关 mock 服务器都由本插件声明）、任何标 `arm: with-only` 的。运行中报告为 `scored: false`。反之 `arm: both` 强制两臂都评分——这正是「不得调用 skill」检查（`min: 0` `max: 0`）需要的。**例外**：若用例中每个评分器都被排除，它们改为正常评分（否则无可评分内容）。

以下情况只跑 with 臂（无 `Δ`）：传 `--ablation none`（单臂，成本减半）；用例用 `context.history_file` 且 target 是路径（要强制带上 without-arm 对比，传 **`--ablation with-without`**）；没为用例找到插件。

### CI

```bash
claude plugin eval . \
  --trust-plugin --json results.json --threshold 0.8 \
  --model claude-sonnet-5 --judge-model claude-haiku-4-5 \
  --no-publish --max-cost-usd 20
```

| 退出码 | 含义 |
|--------|------|
| 0 | 每个用例均达 `--threshold` |
| 1 | 有用例低于阈值 / 用例文件加载失败 / 无用例 / 无法启动 / **选项无效** / 目录不受信任且未加 `--trust-plugin` |
| 2 | 部分运行：达到 `--max-cost-usd` 上限，或凭据被拒（结果带 `partial: true`） |
| 130 / 143 | 被中断 / 被终止 |

> `target` 放 `--tag`、`--allow-tools`、`--json` **之前**，否则会被读成它们的值。
> `--threshold` 默认 1.0，任何不完美都会让命令退出 1。**`Δ`（with 减 without）只被报告，不影响退出码**；HTML 报告写入/发布的问题也不影响。

### 稳定评分的习惯

- 长输出（生成的文件）用 `regex` 评文件内容，`llm` 留给短输出并写具体 PASS/FAIL 条件
- 每个用例配两个评分器：一个评**结果**（最终消息 / 生成的文件），一个评**步骤**（`tool_used` / `tool_order`）证明是插件产生的结果
- `tool_used: Skill` 通过但 `Δ` 为负 → 先怀疑评判模型，用 `--judge-model sonnet` 重跑并收紧评分标准
- 快速套件只用免费评分器，不需要 Δ 时用 `--ablation none` 把成本减半

### 运行环境

- **`prompt.md` 的 `env` 键必须是 `EVAL_[A-Z0-9_]*`**，其他键会让运行失败。子会话只继承一份白名单：`PATH` 和区域设置、代理/证书、模型提供商变量、多数 `ANTHROPIC_*` 和 `CLAUDE_CODE_*`、`EVAL_*`。要传工具链配置，导出成 `EVAL_*` 变量
- 运行**不加载**任何个人/项目内容（用户设置、hooks、`CLAUDE.md`、其他插件、memory），也不读工作区里的 `.claude/` / `.mcp.json`；`add_dirs` 只给只读。案例所需的一切得由插件自身或 `scaffold_script` 提供
- `scaffold_script` 只在传 `--scaffold` 时运行，环境极小、限时 120 秒，非零退出即该次运行得 0（`scaffold failed`）。它作为你在代理沙箱**外**运行，只对自己/组织编写的套件开启

## 成本

```bash
claude plugin details formatter
```

`claude plugin details` 要求插件**已加载**：已安装、在 skills 目录中，或同一命令里用 `--plugin-dir` 传入（`claude --plugin-dir ./formatter plugin details formatter`）。

- **Always-on**：插件的 skill / agent / command 的**名称 + description** 加进每个启用插件的会话，无论是否使用。这是每个用户每轮都在付的数字
- **On-invoke**：只在组件运行时加载的正文
- Commands 与 skills 一起计数。Hooks 显示为 `harness-only — no model context cost`，MCP 服务器显示为 `tool schemas resolved at runtime; not counted`，LSP 服务器**有独立统计行**（通常为 0）；MCP 工具的实际成本用 `/context` 的 `MCP tools` 类看

**降低 always-on**：缩短 description、把大插件拆成按需安装的小插件。但 description 也是 Claude 匹配请求的依据，**修剪后用 `tool_used: Skill` 评分器验证触发没坏**。

**是否仍被使用**（告诉用户）：`/plugin` 的 Not used recently（14 天且 10 会话未用）、`/skill-doctor`（列从未调用的 skill）、`/doctor`（建议禁用未用插件）、`/usage`（使用份额）。**Not used recently 永不出现**在：`--plugin-dir` 或 skills 目录加载的插件、托管设置的插件、含主题/输出样式/monitor/workflow 的插件（这些无跟踪调用）。官方市场插件在安装前的 `/plugin` 详情里显示 Context cost。

## 常见坑

### 清单与路径

| 症状 | 原因 / 修法 |
|------|------------|
| Errors 标签 `<component> path not found` | 清单里路径指向不存在的东西 → 修路径或建目录，`/reload-plugins` |
| 插件加载但 skills 缺失 | `skills/` 误放在 `.claude-plugin/` 内，或清单 `skills` 条目指向文件而非含 `SKILL.md` 的目录 |
| `--plugin-dir` 指到市场根 | 不读 `marketplace.json`，`plugins/` 下不加载且**无错误** → 指向单个插件的文件夹 |
| `userConfig` 对话框不出现 | `--plugin-dir` 和 `claude plugin install` 都不弹 → 会话中 `/plugin configure <name>` |

### Hooks

- 插件的 hooks 在**会话加载插件时**就注册，不等某个 skill/命令被使用。想限制何时运行就缩小 `matcher`
- `PostToolUse` 退出 0 时记录里什么都不显示 → 用调试日志或脚本产生的副作用确认它跑了
- 匹配插件自己的 MCP 工具必须写全名 `mcp__plugin_<plugin>_<server>__<tool>`，只写服务器名的匹配器**永不触发**
- 每个 hook 进程的环境里有 `CLAUDE_PLUGIN_ROOT`、`CLAUDE_PLUGIN_DATA`，以及每个 userConfig 值的 `CLAUDE_PLUGIN_OPTION_<KEY>`

### MCP / LSP / bin

- 本地 stdio MCP 服务器在 Claude Code 和桌面端 Cowork 可用，**在 claude.ai 上不可用** → 要覆盖 claude.ai 用户得用 `https://` 远程服务器
- `claude plugin validate` 会检查 `.mcp.json`，把加载时会被丢弃的服务器条目报为错误（v2.1.281+）
- LSP 日志发 **stderr**，stdout 只读协议消息（头 ≤64 KiB，体 ≤32 MiB），违规会算崩溃
- `claude plugin validate` **不检查** `.lsp.json`；**任何一条目无效时整个文件在加载时被跳过**，`/plugin` Errors 标签显示 `Invalid LSP server config for ".lsp.json"`
- LSP 扩展名冲突时先注册的赢，另一个被忽略（Errors 标签给警告）
- 顶层 `bin/` 目录会让 claude.ai 和 Cowork **拒绝安装**该插件；插件 `bin/` 位于用户自己的 `PATH` 之后，不能遮蔽 `git`、`ls` 等系统命令

### evals

- 所有内容都 0 分但你生成了正确文件 → 评分器 `target: files` 只给路径列表，改用 `{ source: file, path: … }`
- `file_exists` 只算**运行期间新建**的文件，脚手架创建或仅被编辑的文件对它不可见
- `trace` 是每行 JSON，引号转义成 `\"`；正则用 JS 语法，大小写不敏感写 `flags: i` 而非 `(?i)`
- 基线臂报 `Agent type '<plugin>:<agent>' not found` 是**预期**的（基线不加载插件）；传 `--ablation none` 跳过基线
- git < 2.31 会直接拒绝运行；`Bash` 授权需 OS 级沙箱（Linux 装 `bubblewrap` + `socat`，Windows 用 WSL2）
- 达到用量/速率限制时后续运行以错误结束并按生成内容评分（常为 0），套件仍完成且**不标 partial** → 检查 `NOTES` 列或 `cases[].arms.with[].error`，限制重置后重跑
