# hooks — Claude Code Mod

master-plugin 的 mod 目录。

**Mod** 是插件内注册事件处理函数的代码，运行在 Claude Code 进程内，能绘制界面、改写提示词与工具调用——设置 hook、skill、MCP 服务器都做不到这些。API 速查见 [DOC/cc_mods.md](../../DOC/cc_mods.md)。

## 文件

| 文件 | 作用 |
|------|------|
| `hooks.json` | 入口声明，`modules` 列出要加载的 hook 模块（**每插件只能一个**） |
| `register.js` | 启动入口：import 各 mod 并依次调用它们的 `register` |
| `prompts.js` | `prompts` 命令与 Prompt Library 面板 |
| `html-link.js` | 会话记录里 `.html` 路径的可点链接与浏览器打开；路径解析等纯函数也在本文件内 |

加新 mod：在 `register.js` 加一行 import 和一次调用，`hooks.json` 不用改。

## prompts：本地提示词库

`/prompts [关键词]` 打开侧边面板，搜索、预览本地 Markdown 提示词并填入输入框。

- **目录**：读 `plugin.json` 的 `userConfig.promptsDirectory`，默认 `~/.claude/prompts`，支持 `~/` 开头或绝对路径
- **扫描**：递归读取目录下的 `.md`，跳过符号链接与空文件；名称取首个 `# ` 标题，没有则用文件名
- **浏览**：无关键词时按文件夹逐层浏览；有关键词时在名称、文件名、全文里搜索
- **预览**：显示文件开头 frontmatter（YAML）
- **填入**：`插入光标处` / `追加到末尾` / `替换输入内容`，填入后面板保持打开，可继续选择
- **降级**：终端和 Desktop 之外（如 `claude -p`、VS Code 聊天面板）不绘制界面，改为返回提示词列表文本

状态（提示词、当前文件夹、搜索词等）只存在模块级变量里，重载即重置；不保存用户数据。

## html-link：点击 html 路径用浏览器打开

会话记录（助手回复）里出现 `.html` / `.htm` 路径时，在该消息下方追加一行可点链接，点击交给系统默认浏览器打开。

- **识别**：裸路径、行内代码、markdown 链接目标里的本地 `.html` / `.htm` 文件；`~/` 与相对路径（按该消息首次绘制时的 cwd 解析，`cd` 之后旧消息不漂移）
- **不识别**：代码围栏内的路径；`http(s)://` 等带协议的 URL；**裸写的 `file://…`**（被 URL 分支消费，只有包在行内代码或 markdown 链接目标里才认）；`.xhtml`
- **中文紧邻**：`见index.html` 取 `index.html`（转折处优先）。但 `见中文文件.html` 无法区分「见」是正文还是文件名的一部分，会整体当作文件名——纯文本的固有限制，与 mdview 一致
- **打开**：Linux `xdg-open`，失败回退 `open`；Windows `cmd /c start`。直接传参数数组，不经 shell，每次尝试 5 秒超时
- **反馈**：成功/失败都用 toast 告知；**渲染期不 stat**，文件不存在时点击才提示
- **只是追加**：`await next(e)` 保留引擎与其它 mod 的绘制，再追加一行 `⎿  a.html ↗`——**不替换正文**；最多 20 个，同一文件的 `#a` 与 `#b` 只算一个
- **与 mdview 共存**：`.md` 的点击显示仍归 mdview，本模块只认 html

### 链顺序限制

本模块靠 `await next(e)` 拿到内层（引擎 + mdview）的结果再追加，所以**必须排在 `mdview` 之前**。现状符合（`settings.json` 的 `enabledPlugins` 里 `master-plugin` 在第 4、`mdview` 在第 6）。

顺序若反转，失效窗口是**同一条消息里同时含 `.md` 和 `.html`**——此时 mdview 会替换整棵树且不调 `next`，本模块的 hook 根本不执行，html 链接不出现（只含 html 的消息不受影响，因为 mdview 的门禁不命中、会放行）。

验证：发一条同时含 `a.md` 与 `b.html` 的回复，看到 `⎿ b.html ↗` 即为外层。

## 验证

```bash
claude plugin validate ./master-plugin   # 看 hooks: 与 calls: 行是否与预期一致
claude --plugin-dir ./master-plugin      # 单会话加载，保存文件即热重载
```

`master-plugin/tsconfig.json` 继承 `.claude-plugin/types/tsconfig.json`，供编辑器和类型检查使用（`include` 已覆盖 `hooks/`）。
