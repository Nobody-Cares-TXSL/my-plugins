# Codex 插件速查

一个 Codex 插件 = **一个目录 + 一个清单**：打包 skills、MCP 服务器、应用集成（Apps）等，成为一个可安装、可分发的工作流单元，装进 Codex 和 ChatGPT 重复使用。发布一次到通用插件目录（Universal Plugin Directory），ChatGPT 和 Codex 两个产品都能发现它。

## 何时该用插件

| 情况 | 选择 |
|------|------|
| 只在当前仓库试验一个工作流 / 行为很个人化 / 还在迭代 | 先写本地 skill（`codex exec --skill` 直接加载） |
| 跨项目、跨仓库复用 / 打包 skills + MCP + App 多项能力 / 给团队稳定版本 / 准备发布 | 做成插件 |

**四层生态**（并列的四类，非层级递进）：Skill（可复用工作流的编写格式）· Plugin（打包分发单元）· App（GitHub/Slack 等外部服务的权限层）· MCP Server（扩展工具面或共享上下文的服务端层）。插件的核心价值是能同时捆绑 skill、app、MCP 这三类东西。

## 目录结构

```
my-plugin/                        # 插件根目录
├── plugin.json                   # portable manifest（新包推荐，声明 Agent Plugins schema）
├── .codex-plugin/
│   └── plugin.json               # compatibility manifest（仍被支持；plugin-creator 生成的就是它）
├── skills/<name>/SKILL.md        # 技能，portable 包自动从根 skills/ 发现
├── mcp.json                      # 捆绑的 MCP 服务器（portable 格式，每个服务器要声明 transport type）
├── .mcp.json                     # MCP 服务器（compatibility fallback）
├── .app.json                     # 已注册 MCP 服务器的映射（apps）
├── hooks/hooks.json              # 生命周期 hooks（仅手动安装的 Codex desktop 插件）
├── scripts/                      # 辅助脚本（hook/skill 通过路径引用）
└── assets/                       # icon.png、logo.png、screenshots
```

> **清单与组件位置**：portable 部分永远放插件根（`plugin.json`、`mcp.json`、`skills/`、`assets/`）；加了 Codex overlay 时 `.codex-plugin/` 里只留 `plugin.json`，它引用的 hooks、`.app.json` 等资源仍在插件根。旧包可以在 `.codex-plugin/plugin.json` 里直接声明 `hooks` 或 `extensions.com.openai.onboardingSkill`。
> 根清单的 `extensions.com.openai` 是对象时**整体替换**（不合并）`.codex-plugin/plugin.json` overlay；inline 对象缺失时才回落到 overlay。
> 不要把 `.mcp.json` 简单改名为 `mcp.json`——portable 格式还要给每个服务器声明 transport `type`。

### 用 @plugin-creator 脚手架

最快路径是内置的 `@plugin-creator` skill（ChatGPT Work 模式用 `@plugin-creator`，Codex CLI 用 `$plugin-creator`）。它生成 `.codex-plugin/plugin.json` 这个 compatibility manifest，并能顺带生成本地市场条目用于测试；已有插件文件夹也可以让它接进市场。

请求全部可选组件时，它创建：

```
my-plugin/
├── .codex-plugin/plugin.json    # 唯一总是创建的文件
├── .mcp.json                    # 起始为空 mcpServers 对象
├── .app.json                    # 起始为空 apps 对象
├── skills/                      # 清单声明 skills: "./skills/"
├── hooks/                       # 空目录，不生成 hook 配置或脚本
├── scripts/
└── assets/
```

> 脚手架用的是 **Codex compatibility layout**，不是 portable Agent Plugins layout。要写 portable 包就照上面的目录结构手动建根 `plugin.json` + `mcp.json`，别只重命名 `.mcp.json`。
> 请求 hooks 只会建一个空 `hooks/` 目录——`hooks/hooks.json` 和脚本要自己加。

## plugin.json 清单

最小 portable 清单（`name` 是插件标识和组件命名空间，kebab-case）：

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "my-first-plugin",
  "version": "1.0.0",
  "description": "Reusable greeting workflow"
}
```

完整版可加：`author{name,email,url}`、`homepage`、`repository`、`license`、`keywords`。

portable 包会自动从根 `skills/` 发现技能，**不需要** `skills` 字段；compatibility manifest 则要 `"skills": "./skills/"` 显式声明。

### extensions.com.openai（OpenAI 特定设置）

放在根 `plugin.json`，涵盖展示、已注册 MCP 服务器映射（apps）、生命周期 hooks：

| 字段 | 说明 |
|------|------|
| `apps` | 指向 `./.app.json`（ChatGPT 注册的 MCP 服务器 ID 映射） |
| `hooks` | 路径 / 路径数组 / inline hooks 对象（见下） |
| `onboardingSkill` | `./skills/setup/SKILL.md`，安装后引导用户运行 setup；相对根，必须指向包内 skill |
| `interface.displayName` / `shortDescription` / `longDescription` / `developerName` / `category` | 安装界面的展示文案 |
| `interface.capabilities` | 如 `["Read", "Write"]` |
| `interface.websiteURL` / `privacyPolicyURL` / `termsOfServiceURL` | 绝对 HTTPS URL |
| `interface.defaultPrompt` | 启动建议（最多 3 条，每条 ≤128 字符） |
| `interface.brandColor` | `#RRGGBB` |
| `interface.composerIcon` / `logo` / `screenshots` | 图片路径，放 `./assets/` |

## 组件一览

| 组件 | 声明方式 | 说明 |
|------|---------|------|
| Skill | `skills/<name>/SKILL.md` | frontmatter（`name` + `description`）+ 自然语言指令；指令越具体执行越稳定。渐进式加载：元数据常驻 → 正文触发时 → 资源按需 |
| MCP 服务器 | 根 `mcp.json`（portable）/ `.mcp.json`（兼容） | `mcpServers` 下的命名条目；远程 HTTP 用 `"type": "streamable-http"` |
| App 集成 | `.app.json` + 清单 `apps` 字段 | 连接 ChatGPT 里已注册的 MCP 服务器（`plugin_asdk_app...` ID） |
| Hooks | `hooks/hooks.json` | Codex desktop 手动安装的插件；含 hooks 的插件**不能进公共目录** |
| Assets | `assets/` | 图标、logo、截图，供安装界面展示 |

### MCP 服务器（portable 格式）

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  "mcpServers": {
    "docs": { "type": "streamable-http", "url": "https://example.com/mcp" }
  }
}
```

公共提交以**远程 HTTPS 端点**为主（走 **With MCP** 入口提交）。本地运行的 MCP 服务器要发布，得先部署到公网 HTTPS；如果做不到，联系你的 OpenAI 对接人寻求本地 MCP 支持。

用户可在 Codex 配置里按插件粒度调 MCP 策略，不用改插件：

```toml
[plugins."my-plugin".mcp_servers.docs]
enabled = true
default_tools_approval_mode = "prompt"
enabled_tools = ["search"]

[plugins."my-plugin".mcp_servers.docs.tools.search]
approval_mode = "approve"
```

### Onboarding skill（安装后引导用户）

给用户一个装完就能跑的 setup 工作流：把技能放在 `skills/setup/SKILL.md`，在清单里声明：

```json
{
  "extensions": {
    "com.openai": { "onboardingSkill": "./skills/setup/SKILL.md" }
  }
}
```

- 用户运行 setup 时，**在新对话里调用该 skill**；若是在当前对话中途安装的，则复用当前对话
- `onboardingSkill` 路径相对插件根，且必须指向**包内**的 skill
- 兼容格式下把同一字段写在 `.codex-plugin/plugin.json`，路径仍从插件根解析
- 测试时两种情形都要跑：全新对话 + 在已有对话中安装

### Hooks

- Codex 默认发现 `hooks/hooks.json`；要覆盖，在 `extensions.com.openai.hooks` 定义——**显式值替换默认发现，不叠加**
- hook 路径以 `./` 开头、相对插件根、不得越出根
- hook 命令的环境变量：`PLUGIN_ROOT`（安装根）、`PLUGIN_DATA`（可写数据目录），并有兼容别名 `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PLUGIN_DATA`
- **安装 ≠ 信任**：插件 hooks 是非托管 hooks，用户 review 并信任当前定义之前 Codex 跳过它们
- hook 脚本必须在执行环境里真实存在——web 上安装不会部署脚本（企业可用 MDM 下发）

## 本地市场（marketplace）

市场 = 一份 JSON 插件目录清单，不是"官方商店"。ChatGPT desktop 从三处读取：

| 市场 | 路径 | 用途 |
|------|------|------|
| Repo 市场 | `$REPO_ROOT/.agents/plugins/marketplace.json` | 随仓库分发，团队共享 |
| Personal 市场 | `~/.agents/plugins/marketplace.json` | 个人跨项目复用 |
| 兼容市场 | `$REPO_ROOT/.claude-plugin/marketplace.json` | 旧格式 |

示例（每个条目**必须带** `policy.installation`、`policy.authentication`、`category`）：

```json
{
  "name": "local-repo",
  "interface": { "displayName": "Local Example Plugins" },
  "plugins": [
    {
      "name": "my-plugin",
      "source": { "source": "local", "path": "./plugins/my-plugin" },
      "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL" },
      "category": "Productivity"
    }
  ]
}
```

- `source.path` **相对市场根**解析（不是相对 `.agents/plugins/`），以 `./` 开头、留在根内；local 条目也可写纯字符串路径
- `policy.installation`：`AVAILABLE` / `INSTALLED_BY_DEFAULT` / `NOT_AVAILABLE`
- `policy.authentication`：`ON_INSTALL` / `ON_USE`

### 插件来源类型

| source | 关键字段 | 说明 |
|--------|---------|------|
| `local` | `path` | 仓库/本地目录 |
| `url` 或 `git-subdir` | `url`、`path`、`ref`/`sha` | Git 仓库根 / 子目录 |
| `npm` | `package`（必需）、`version`、`registry` | 下载**不运行**生命周期脚本；需装 npm CLI；registry 必须 HTTPS 且无凭据/查询/片段 |

> 某个条目的 source 解析失败时，Codex **跳过该插件**，不让整个市场失败。
> npm 源的 `version` 接受版本、发行标签、范围，但不接受路径/URL 选择器。

### 市场 CLI（Codex）

```bash
codex plugin marketplace add owner/repo                 # GitHub 简写
codex plugin marketplace add owner/repo --ref main      # 固定 ref
codex plugin marketplace add https://github.com/example/plugins.git --sparse .agents/plugins
codex plugin marketplace add ./local-marketplace-root   # 本地目录
codex plugin marketplace list                           # 列出 + 解析到的根路径
codex plugin marketplace upgrade [name]                 # 刷新
codex plugin marketplace remove <name>
```

CLI 里的 `/plugins` 可浏览市场插件：方向键浏览、Enter 详情、Space 切换启用、Esc 退出。

**`marketplace add` 的合法来源形态**：GitHub 简写（`owner/repo` 或 `owner/repo@ref`）、HTTP/HTTPS Git URL、**SSH Git URL**、本地市场根目录。`--ref` 固定 Git ref；`--sparse PATH` 对 Git 市场做 sparse checkout，**只对 Git 来源有效且可重复**。
`marketplace list` 打印 Codex 正在考虑的每个市场及其解析出的根路径，包括本地默认市场和配置好的市场快照。

**安装与缓存**：安装后插件进 `~/.codex/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME/$VERSION/`（本地插件 `$VERSION` = `local`），ChatGPT 从缓存副本加载而非直接从市场条目。改了插件文件后，更新市场指向的目录并**重启 ChatGPT desktop** 才生效。

## 启用 / 禁用

用户级选择存 `~/.codex/config.toml`；项目级用仓库的 `.codex/config.toml` 控制：

```toml
[plugins."my-plugin@local-repo"]
enabled = false   # 禁用但不卸载
```

- 键格式：`"<plugin名>@<市场名>"`
- 项目设置只对**受信任项目**加载；项目 > 用户 > 云托管 > 系统默认
- 市场刷新时即使 `enabled = false` 也会安装/刷新插件文件；已连接服务仍需认证
- 这套设置只管本地市场插件；通过 **Admin > Plugins** 导入的插件用 workspace 管理的启用状态

## 发布

| 路线 | 谁可安装 | 需要什么 | 自动更新 |
|------|---------|---------|---------|
| 无市场 | 你发目录/`.zip` 的人 | 插件文件夹 | 无，对方加载你发的副本 |
| 自己的市场（repo/personal） | 能访问仓库的人 | `.agents/plugins/marketplace.json` | 市场刷新/`upgrade` |
| ChatGPT workspace | 指定 workspace 角色 | workspace admin 在 ChatGPT Plugins → Personal → 三点菜单 → Publish | 随 workspace |
| 公共目录 | ChatGPT + Codex 所有用户 | 插件提交门户审核（含 MCP 服务器时走 With MCP） | 推送新版本后 |

- **workspace 发布**不出通用目录，留在组织边界内。管理员可用 `features.plugin_sharing = false`（requirements.toml）禁用
- **公共提交**前：`interface` 字段补全（displayName / category / privacyPolicyURL 等）、替换所有 `[TODO: ...]` 占位符、含本地 MCP 的先部署到公网 HTTPS；MCP 服务器作为连接器提交时走 **With MCP** 入口
- 发布相关字段要求和导入行为以官方 submission 文档为准

### 在 ChatGPT 注册 MCP 服务器（`.app.json` / `apps` 字段的前提）

带 MCP 服务器的插件要本地测试，得先在 ChatGPT 里注册这个连接：

1. 打开 `chatgpt.com/plugins`，点加号 → **Add custom MCP server**
2. 填 MCP 服务器 URL 和连接信息，阅读风险提示并选 **I understand and want to continue**
3. 选 **Create as a plugin**，从浏览器 URL 复制技术 ID（以 `plugin_asdk_app` 开头）
4. 把这个 ID 交给 `@plugin-creator`（Work 模式）或 `$plugin-creator`（Codex），让它把 MCP wiring 写进插件

生成后：`.app.json` 的映射要指向正确的 `plugin_asdk_app...` ID，`.codex-plugin/plugin.json` 的 `apps` 字段要指向 `./.app.json`。

### 本地安装与测试循环

```
1. 插件目录拷到 $REPO_ROOT/plugins/my-plugin
2. 写 $REPO_ROOT/.agents/plugins/marketplace.json，source.path 指向 ./plugins/my-plugin
3. 重启 ChatGPT desktop，在 Plugins Directory 的本地源里安装，然后在新对话里测试
```

改了插件后，更新市场条目指向的目录并重启 ChatGPT desktop。CLI 里用 `codex plugin marketplace add ./local-marketplace-root` 接入本地市场，用 `codex plugin marketplace list` 确认解析到的根路径。

## 常见坑

| 症状 | 原因 / 修法 |
|------|------------|
| 用 plugin-creator 后直接改 `.mcp.json` 文件名当 `mcp.json` | portable MCP 格式多了 transport `type` 声明，照抄会失效 |
| `extensions.com.openai` 写了但 overlay 还在生效 | inline 对象**替换而非合并** overlay；两个都写时以 inline 为准 |
| 改了插件没生效 | 安装的是**缓存副本**——更新市场指向的目录并重启 ChatGPT desktop |
| `source.path` 解析不到 | 它相对**市场根**解析，不是相对 `.agents/plugins/` 文件夹；必须 `./` 开头 |
| 整个市场消失 | 排查单个条目——source 解析失败只跳过该插件，但 JSON 语法错误会让整份清单读不了 |
| hooks 不跑 | ①插件还没被用户信任（安装≠信任）②脚本没在执行环境里（web 安装不部署脚本）③`extensions.com.openai.hooks` 定义后默认的 `hooks/hooks.json` 不再被读取 |
| 含 hooks 的插件无法提交公共目录 | hooks 插件不符合公共目录资格（官方未给修法；实务上可考虑把 hooks 移出公共版本） |
| 项目 config.toml 不生效 | Codex 只为**受信任项目**加载项目设置 |
| 测试插件影响个人市场配置 | 用 repo 市场（`<repo>/.agents/plugins/marketplace.json`）注册开发中的插件，别动 `~/.agents/` 下的个人配置 |
| 找不到 `codex plugin install/list/enable/disable/package/add` | 这些子命令**不存在**。安装和测试本地插件用 **ChatGPT desktop app**（或 CLI 的 `/plugins` 浏览器）；项目级启停靠 `.codex/config.toml` 的 `[plugins."x@y"] enabled=`；市场管理用 `codex plugin marketplace …` |

## 与 Claude Code 插件的对照（同名概念，不同实现）

| 概念 | Codex | Claude Code |
|------|-------|---------|
| 清单位置 | 根 `plugin.json`（portable）或 `.codex-plugin/plugin.json` | `.claude-plugin/plugin.json` |
| 市场 | `.agents/plugins/marketplace.json`（或 `.claude-plugin/` 兼容） | `.claude-plugin/marketplace.json` |
| Hook 环境变量 | `PLUGIN_ROOT` / `PLUGIN_DATA` | `CLAUDE_PLUGIN_ROOT` / `CLAUDE_PLUGIN_DATA`（Codex hooks 也有兼容别名） |
| Hooks 信任 | 安装后需用户 review 信任 | 加载即注册 |
| 公共目录 | ChatGPT + Codex 共享通用目录，走提交门户 | Anthropic 目录（claude.ai/directory），走开发者门户 |
| 官方脚手架 | `@plugin-creator` / `$plugin-creator` | `claude plugin init` / `plugin-dev` 插件 |
