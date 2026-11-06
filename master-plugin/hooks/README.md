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
| `prompt-optimize.js` | 输入框上方「优化草稿」按钮：主动校准并回填草稿，不自动发送，支持安全还原 |

加新 mod：在 `register.js` 加一行 import 和一次调用，`hooks.json` 不用改。

## prompts：本地提示词库

`/prompts [关键词]` 打开侧边面板，搜索、预览本地 Markdown 提示词并填入输入框。

- **目录**：读 `plugin.json` 的 `userConfig.promptsDirectory`，默认 `~/.claude/prompts`，支持 `~/` 开头或绝对路径
- **扫描**：递归读取目录下的 `.md`，跳过符号链接与空文件，并跳过 `CLAUDE.md` / `AGENTS.md` / `README.md`（按文件名不区分大小写，任意层级生效）；名称取首个 `# ` 标题，没有则用文件名
- **嵌套目录**：支持任意层级普通子文件夹。无关键词时只展示当前层提示词与直接子目录，点击目录逐层深入、可返回上一级；有关键词时跨所有层级搜索名称、相对路径及全文，无需先进入子目录
- **预览**：显示文件开头 frontmatter（YAML）
- **填入**：`插入光标处` / `追加到末尾` / `替换输入内容` 填提示词全文；`插入文件路径` 把该文件的绝对路径插到光标处。填入后面板保持打开，可继续选择
- **降级**：终端和 Desktop 之外（如 `claude -p`、VS Code 聊天面板）不绘制界面，改为返回提示词列表文本

状态（提示词、当前文件夹、搜索词等）只存在模块级变量里，重载即重置；不保存用户数据。

## prompt-optimize：三档任务意图重构（不自动发送）

用户在 Claude Code Terminal / Desktop 输入框上方选择「low优化草稿」「medium优化草稿」或「high优化草稿」，插件读取草稿并调用**当前会话模型**，按所选推理强度重构任务，再只把优化结果回填输入框。**不再把原始描述追加到提示词末尾**；原稿仅保存在模块内存中，用于切换档位重新比较或点击「还原上次优化」。Enter 始终正常发送。

- **模型**：始终使用 `await $.session.model()`，不强制切换 Haiku 或其他模型。
- **推理档位**：low=`effort: 'low'`（8.5 秒超时）；medium=`effort: 'medium'`（14 秒超时）；high=`effort: 'high'`（22 秒超时）。三档均使用 `maxTokens: 850`。高档位给予更长时间，仍可能因 API 取消、网络或代理问题失败。
- **横向比较**：若输入框仍是上一次优化结果，切换档位时会重新以最初草稿作为模型输入，而不是在上一次改写上继续改写。成功后更新当前结果；「还原上次优化」恢复最初草稿。若用户手动编辑当前草稿，原还原快照失效，避免覆盖新编辑。
- **任务质量**：识别真实目标、动作授权、明确约束、待验证前提与必要的执行方式；分析类请求不能升级为直接修改。保留路径、@引用、URL、版本、数字和否定条件，模型遗漏时不回填。输出保持精炼，简单任务不套长模板。
- **状态反馈**：按钮旁显示当前档位的运行状态、对应超时、完成结果或失败原因。模型 `aborted`、HTTP 499、429、权限错误及网络连接错误分别提示；499 可能与客户端取消、超时或网络中断有关，不直接归咎于服务端。
- **数据保护**：优化期间草稿发生变化时取消回填；模型失败、输出格式错误或遗漏路径／引用／数字时保留当前输入。优化结果不含原文副本，不会自动发送。
- **限制**：草稿长度 6～6000 字符；每次点击只调用一次模型，不自动重试或切换模型。复杂任务的 high 档位可能更慢；8.5／14／22 秒是各档请求上限，不是实际耗时保证。
- **测试**：`claude plugin test .`、`claude plugin validate .`。测试覆盖三个按钮、当前会话模型、effort 与超时映射、跨档位从原稿重算、原稿还原、无原文追加、硬约束、499/aborted 和不自动发送。

## html-link：点击 html 路径用浏览器打开

会话记录（助手回复）里出现 `.html` / `.htm` 路径时，在该消息下方追加一行可点链接，点击交给系统默认浏览器打开。

- **识别**：裸路径、行内代码、markdown 链接目标、以及裸写的 `file://` 绝对路径；`~/` 与相对路径按该消息首次绘制时的 cwd 解析（`cd` 之后旧消息不漂移）
- **不识别**：代码围栏内的路径；`http(s)://` 等带协议的 URL；`.xhtml`
- **去重**：按文件名，同一条消息里 `file:///…/a.html` 与 `a.html` 只保留一条
- **只显示存在的**：`$.fs.stat` 确认 `kind === 'file'` 才显示。已确认的路径记在模块级 Set 里，**每个文件每会话只查一次**，流式输出的反复重绘不产生额外 IO。文件写完前不显示，写完后自然出现
- **中文**：以 ASCII 开头的 token（`23-张截图.html`）整段当路径，不切分；以中文开头的（`见index.html`）先试中文之后的部分，再兜底整段。`见中文文件.html` 无法区分「见」是正文还是文件名，属纯文本的固有限制，与 mdview 一致
- **打开**：Linux 先查 `xdg-settings get default-web-browser`（http(s) 归属，**不是**易被桌面「设为默认」改走的 `text/html` 文件关联），解析其 desktop 文件 `Exec=` 后用浏览器直开 `file://` URL；查不到才回退 `xdg-open`/`open`。Windows `cmd /c start`。直接传参数数组，不经 shell，每次尝试 5 秒超时
- **反馈**：成功/失败都用 toast 告知
- **只是追加**：`await next(e)` 保留引擎与其它 mod 的绘制，再追加一行 `⎿  a.html ↗`——**不替换正文**；最多 20 个，同一文件的 `#a` 与 `#b` 只算一个
- **点击时**：再 stat 一次，文件已被删则 toast 提示
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
