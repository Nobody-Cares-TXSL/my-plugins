# Claude Code Mods 速查

**Mod = 一个插件，其代码注册事件处理程序**。Claude Code 在事件发生时（工具调用、提交提示词、界面绘制）调用这些处理程序，处理程序可以**观察**、**改写**或**接管**该事件。Mod 在 Claude Code **进程内**运行（不是外部脚本），所以能绘制界面、改写工具调用——这是设置 hook、skill、MCP 服务器做不到的。

## Mod vs 设置 hook vs Skill vs MCP

| | Mod | 设置 hook | Skill | MCP 服务器 |
|---|---|---|---|---|
| 是什么 | 插件里、被 Claude Code 在自己进程中调用的**函数** | 生命周期事件上运行的 shell/HTTP/提示词 | `SKILL.md` 指令 | 提供工具的外部进程 |
| 能改什么 | 工具调用、提示词、命令、轮次、界面绘制 | 调用是否继续、参数与结果、上下文 | Claude 知道什么 | Claude 有哪些工具 |
| 能画界面 | **是** | 否 | 否 | 否 |
| 写什么 | JavaScript / TypeScript | 脚本 + `settings.json` | Markdown | 任意语言 |

## 目录结构

```
first-mod/
├── .claude-plugin/plugin.json      # 清单（mod 不添加必需字段）
├── hooks/
│   ├── hooks.json              # { "modules": ["./register.js"] }
│   └── register.js             # hooks 模块：导出 register(on, options)
└── types/index.d.ts            # 用 $.state 或新增命名空间时必需
```

**文件规则**：hook 模块后缀 `.js` `.mjs` `.cjs` `.jsx` `.ts` `.mts` `.cts` `.tsx`，必须是 **ES 模块**（用 `import`，不用 `require`）。测试文件以 `.test.ts` / `.test.tsx` 结尾。

## 版本要求

| 场景 | 最低版本 |
|------|---------|
| 终端使用 mod | v2.1.287 |
| Desktop 应用（自带副本） | v2.1.286 |
| `isDeferred` 字段 | v2.1.293 |
| `prompt.mention` 事件 | v2.1.290 |
| `ui.fault` 事件 | v2.1.289 |

早期访问期的 `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` 已被忽略，**应删除**（设 `0` 也不会关闭 mod）。

## 最小示例

```javascript
let calls = 0

export function register(on) {
  on('tool.call', async ($, e, next) => {   // 观察到工具调用
    calls += 1
    $.ui.invalidate('ui.render')            // 请求重绘
    return next(e)                          // 放行，工具照常运行
  })

  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    return next({ ...e, props: { ...e.props, suffix: ' · tool calls: ' + calls } })
  })
}
```

## hook 三参数

`register(on, options)` 的 **`options`** 含清单 `userConfig` 字段的值（已填入默认值）。以下是每个 hook 收到的三个参数：

| 参数 | 说明 |
|------|------|
| `$` | **mods API**（`$.ui`、`$.fs`……）。必须完整写出 `$.命名空间.方法`；可传给**同一文件顶层声明的函数**（验证输出会显示 `$.store.get (via loadNotes)`），但不能解构、赋给变量，或传给方法 / hook 内定义的函数 / 导入的函数 |
| `e` | 事件数据，**深度冻结**的纯数据。改它要传副本给 `next` |
| `next(e)` | 下一个处理程序（中间件链）。解析为该事件的结果 |

**`next` 的附加属性**：

| 属性 | 用途 |
|------|------|
| `next.signal` | `AbortSignal`，事件被放弃时中止（传给长耗时操作） |
| `next.origin` | 谁触发的：`{ plugin, tier }`；Claude Code 自身为 `{ plugin: 'engine', tier: 'core' }` |
| `next.budget` | 时间限制：`.ms` 总量，`.remainingMs` 剩余 |
| `next.to(e, tier)` | 跳到后面的层级（`append`/`builtin`/`core`），仅 `prepend`/`append` 插件可调用 |
| `next.error` / `next.called` | 仅在 `.catch` 中可用 |

## 处理事件的三种方式

```javascript
// 1. 观察：不改变，返回 next(e)
on('tool.call', async ($, e, next) => { $.ui.log('tool: ' + e.tool); return next(e) })

// 2. 改写：传事件副本给 next
on('prompt.submit', async ($, e, next) => next({ ...e, text: e.text.trim() }))

// 3. 接管：不调用 next，直接返回结果（短路整条链）
on('tool.call', { tool: 'Bash' }, async () => ({ deny: '本项目禁用 Bash。' }))
```

**观察后置**：`const r = await next(e)` → 做事 → `return r`（在工具运行后执行）。

## 匹配器（matcher）

`on` 的第二参数，按字段过滤。字段可以是值、数组或正则：

```javascript
on('tool.call', { tool: 'Bash' }, hook)                    // 单值
on('tool.call', { tool: ['Edit', 'Write'] }, hook)         // 任一匹配
on('tool.call', { tool: /^mcp__github__/ }, hook)          // 正则
on('classic.*', hook)                                       // 通配符
on('*', hook)                                               // 除遥测外全部
```

> 同一事件**无 matcher 只能注册一次**——重复注册会加载失败：`on("session.start") is registered twice without a matcher`。

## 事件分组

| 组 | 事件 |
|----|------|
| **工具** | `tool.call`、`tool.check`、`tool.describe` |
| **提示词** | `prompt.submit`、`prompt.fill`、`prompt.suggest`、`prompt.edit`、`prompt.compose`、`prompt.section`、`prompt.context`、`prompt.attachment`、`prompt.mention`、`skill.prompt`、`attribution.text` |
| **命令/配置** | `command.run`、`command.describe`、`config.set`、`config.describe` |
| **轮次** | `turn.start`、`turn.step`、`turn.complete` |
| **会话** | `session.start`、`session.end`、`session.compact`、`session.receive`、`session.send`、`session.append`、`session.attach`、`session.detach`、`session.measure` |
| **子代理** | `agent.offer`、`agent.spawn` |
| **界面** | `ui.render`、`ui.resolve`、`ui.press`、`ui.input`、`ui.select`、`ui.focus`、`ui.scroll`、`ui.close`、`ui.message`、`ui.fault` |
| **其他 mod** | `plugin.register`、`engine.create` |
| **遥测** | `telemetry.log`、`telemetry.mark`（须加 `{ to: 'collector' }` 过滤） |

> **异步生成器事件**：`turn.step` 和 `process.spawn` 上的 hook 必须写成异步生成器（`async function*` + `yield* next(e)`），其余事件用普通异步函数。
| **设置 hook** | 每个设置 hook 事件都有 `classic.<名称>` 形式，如 `classic.Stop` |

### 关键事件速查

| 事件 | 触发时机 | 可返回 |
|------|---------|--------|
| `tool.call` | 工具即将运行 | `next(e)` / `{ deny: reason }` / `{ result }` |
| `tool.check` | 权限规则和 hook 决定之后 | `{ decision: 'allow'\|'ask'\|'deny', reason? }` |
| `prompt.submit` | 提示词提交时 | `next({...e, text})` / `next({...e, context})` / `{ drop: reason }` |
| `turn.step` | 请求即将发往模型（**异步生成器**） | `yield* next(e)` / `next({...e, model})` |
| `turn.complete` | 轮次结束 | `{ text }`（回答下方显示一行） |
| `session.start` | 每个 mod 一次，首个提示词之前；**重载后再次触发**；`/clear` 后**不触发** | `next(e)` |
| `session.end` | 会话结束或 `/clear`/`/resume`/`/branch` | `next(e)` |
| `ui.render` | 某渲染位置即将绘制 | 元素树 / `next(e)` |
| `plugin.register` | hook 模块即将加载 | `{ refuse: reason }` |
| `process.spawn` | `$.process.spawn` 启动流式命令（**异步生成器**） | `yield* next(e)` |

## mods API 命名空间

| 命名空间 | 主要方法 |
|---------|---------|
| `$.plugin` | `name`、`root` |
| `$.ui` | `resolve`、`invalidate`、`open`、`close`、`focus`、`toast`、`status`、`log`、`ask`、`blit` |
| `$.command` | `register`、`run`、`list` |
| `$.tool` | `register`、`call`、`check`、`list` |
| `$.agent` | `register`、`spawn`、`list` |
| `$.model` | `complete`、`fork`、`classify` |
| `$.prompt` | `submit`、`read`、`fill`、`suggest`、`compose` |
| `$.turn` | `abort` |
| `$.session` | `messages`、`cwd`、`model`、`usage`、`send`、`compact` |
| `$.fs` | `read`、`write`、`list`、`exists`、`stat` |
| `$.process` | `run`、`spawn` |

> **`$.process.spawn` 被链中较早的 mod 拒绝时**，命令已产生的副作用**不会撤销**，调用以两种消息之一结尾：
> `$.process.spawn started, and a plugin withheld its result:`（输出未读完，命令仍在运行则会被停止）
> `$.process.spawn ran, and a plugin withheld its result:`（输出已读完，命令已退出）
| `$.http` | `fetch` |
| `$.store` | `get`、`set`、`delete`、`keys`（跨会话共享） |
| `$.state` | `get`、`set` + 辅助 `atom`、`read`、`update`、`derive` |
| `$.clock` | `now`、`sleep`、`after`、`every` |
| `$.env` / `$.settings` / `$.config` | 环境变量 / 设置 / 配置 |
| `$.mcp` | `call`、`connect` |
| `$.audio` | `play`、`speak` |
| `$.telemetry` | `log`、`mark` |

**每个 API 调用本身也是事件**（`fs.read`、`model.complete`……），链中较早的 mod 可拦截它——这是组织限制 mod 权限的方式。

## 添加命令

```javascript
on('session.start', async ($, e, next) => {
  await $.command.register({ name: 'standup', description: '总结今天的变更', argumentHint: '[days]' })
  return next(e)
})

on('command.run', { command: 'standup' }, async ($, e) => {
  return { text: '最近 ' + (e.args || '1') + ' 天的总结：...' }
})
```

- 返回 `{}` 则不打印任何内容（如仅打开窗格的命令）
- 加 `immediate: true` 让命令在 Claude 工作时也能运行
- 名字被占用会**抛异常**，导致整个 `session.start` hook 被跳过 → 放在该 hook 最后注册，或用 `try/catch`

## 添加工具

```javascript
on('session.start', async ($, e, next) => {
  await $.tool.register({
    name: 'ticket',
    description: '按 id 查询工单',
    inputSchema: { type: 'object', properties: { id: { type: 'string' } }, required: ['id'] },
  })
  return next(e)
})

on('tool.call', { tool: 'mcp__my-mod__ticket' }, async ($, e) => {
  const r = await $.http.fetch('https://tickets.example.com/api/' + encodeURIComponent(e.id))
  return { result: r.ok ? r.text : '查询失败：' + r.status }
})
```

**完整工具名** = `mcp__` + 插件名 + `__` + 注册名。

## 界面绘制

![Claude Code 终端会话地图：mod 可添加的位置——右侧窗格、右上角 toast、记录中的日志行、输入框上方的条带、输入框下方的状态栏；可重绘的部分——消息、工具调用行、加载指示器。输入框属于 Claude Code 自己。](https://mintcdn.com/claude-code/dgiVO_Od1X1faduV/images/mods-screen-map.svg?w=2500&fit=max&auto=format&n=dgiVO_Od1X1faduV&q=85&s=973c9ae9ae792ccbe3e712a804a564a2)

上图是终端布局总览。**实线框**是 mod 可新增的位置，**虚线框**是 mod 可重绘的位置，**无色框**是 Claude Code 自己的。

### 渲染位置（`ui.render` 的 `e.component`）

| 位置 | 在哪里 | 应用 |
|------|-------|------|
| `Pane` | 侧边栏窗格 / 输入框上方 | 终端、Desktop |
| `AbovePrompt` | 输入框上方的条带 | 终端、Desktop |
| `UserMessage`、`AssistantMessage` | 会话记录中的消息 | 终端、Desktop |
| `ToolUse`、`ToolResult`、`ToolGroup` | 工具调用行 | 终端、Desktop |
| `CommandOutput` | 命令打印的行 | 终端、Desktop |
| `AskUserQuestion` | 提问对话框 | 终端、Desktop |
| `Spinner` | 加载动画 | 终端、Desktop |
| `ToolProgress`、`TurnDuration` | 工具进度 / 轮次耗时 | 终端 |
| `InfoNotice`、`SessionMode`、`PromptHint` | 状态栏 / 模式标签 / 提示行 | 终端 |

**权限提示不是渲染位置**，mod 无法更改。

### 三种改法

```javascript
// 改细节：保留 Claude 的绘制，改 props
return next({ ...e, props: { ...e.props, suffix: ' · ' + calls } })

// 替换：返回自己的树，不调 next
const { Text } = $.ui.resolve(e)
return Text({ children: ['替换内容'] })

// 保持不变
return next(e)
```

对 Claude 自己绘制的位置，`next(e)` 返回引用 `{ type: 'engine', ref }`，可原样返回或用 `Box` 包裹。

### 打开窗格

```javascript
await $.ui.open({ id: 'hello-tabs', title: 'Hello tabs', focus: true })
await $.ui.close({ id: 'hello-tabs' })
```

| 字段 | 作用 |
|------|------|
| `title` | 多个窗格时的标签 |
| `focus` / `closeOnEscape` / `holdToasts` | **只接受 `true`**，不用就省略（传 `false` 会抛错） |
| `rows` / `columns` | 请求的高度 / 宽度 |

返回 `{ isPlaced: true }`；等待更宽终端时为 `false`，附带 `reason`。

**放置规则**：用户操作打开的窗格任意宽度都显示；mod 自行打开的需要 ≥144 列，用户手动开过一次后降到 110 列。

### 元素

| 元素 | 用途 | 位置 |
|------|------|------|
| `Box` | flex 容器（`flexDirection`、`gap`、`padding`、`borderStyle`、`width`） | 到处 |
| `Text` | 样式化文本（`color`、`bold`、`italic`、`dimColor`、`wrap`） | 到处 |
| `Button` | 控件，`onPress` | 到处 |
| `Link` / `Code` / `Markdown` | 链接 / 代码块 / 格式化文本 | 到处 |
| `Input` / `Select` | 文本字段 / 下拉 | 终端、Desktop |
| `Svg` | SVG 文档 | **仅 Desktop** |
| `Client` | 由第二个文件绘制的区域（动画、指针输入） | 终端、Desktop |
| `Raster` / `Image` | 彩色单元格网格 / 图片 | **仅终端** |

`Markdown` 内容走 **`text` 属性**（不是 `children`）。

### 各元素效果图

以下截图来自官方图库，可用于按外观挑选元素（均为浅色主题；深色把文件名中的 `light` 换成 `dark`）。

**Text** — 九种样式各一行（`bold` / `italic` / `underline` / `strikethrough` / `dimColor` / `inverse` / `color` / `backgroundColor`）：

![九行文本，每行以其样式命名：plain、bold、italic、underline、strikethrough、灰色的 dimColor、inverse、红色的 color、蓝底的 backgroundColor](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-text-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=fb5e711db31896bf184d20514dc3d330)

**Box** — 行内排列（`columnGap: 4`）+ 圆角边框（`borderStyle: 'round'`，边框延展至窗格宽度）：

![一行三个间隔四列的词，然后是围绕一行文本的圆角边框](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-box-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=b9e28b6e36bc4ae3597ed59eaf3b6ed7)

**Button** — 默认带方括号、`plain: true` 带快捷键 `n`、`dimColor: true` 灰色三种：

![三个按钮：带方括号的 Save、显示 n: Next 的 plain 按钮、灰色 Skip](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-button-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=88c3ebc62a99611996f32fa17006f9a5)

获得焦点的按钮以**反色**绘制：

![同样的三个按钮，第二个 n: Next 反色显示](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-button-plain-focused-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=d24999e36bdd80d262b3c65ecb0a4c4c)

**Input** — 未聚焦显示标签 + 占位文本；聚焦后标签变粗体、出现光标、`⏎` 后显示 `submitLabel`；键入后替换占位文本：

![标签 Title 加灰色占位文本](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-input-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=5da5f933427ef0829d67b90e84808981)
![标签变粗体、光标出现、回车符后跟 save](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-input-focused-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=4da5193cb6aa9464414d44541351757d)
![已键入 Rel，后跟回车符和 save](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-input-typed-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=8c24351da29d887d31965e8ba7197c7d)

**Select** — 收起显示当前值；展开列出选项（当前项反色）；选中后收起：

![标签 Format、当前值 Markdown、向下箭头](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-select-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=b1f1c966982ceabc142d96936bf91392)
![展开的选项列表，第二个 HTML 反色](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-select-moved-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=7ec9f2169557720379d06599534f7e07)
![再次收起，当前值 HTML](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-select-picked-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=2a40095eaf1bfcdc0cde9d902d4cb7b3)

**Code** — 带行号、语法着色（颜色随用户主题）：

![两行带行号、语法着色的 JavaScript 代码](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-code-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=b65a1adf5167fed4c54e13b1a35f95b4)

以 **diff 形式**使用 `Code`（`format: 'diff'`）——删除行红底、添加行绿底，变化的词用更深底纹：

![四行 diff，删除行红底、添加行绿底，均带行号](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-diff-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=fca587f7e3a2b2727a30861e55282fa3)

**Markdown** — 标题加粗不显示 `#`，行内代码着色不显示反引号，引用斜体带左侧竖线：

![标题 Release notes、含粗体词和代码词的句子、两项列表、带竖线的引用](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-markdown-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=7ea71c7ed1aef39ad494754ff2bf2f9f)

**Link** — 标签后跟灰色 URL；能否点击取决于终端：

![标签 Claude Code docs 后跟灰色 URL](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-link-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=c6fe5d8d02a0caeaaebd1527ce0769f5)

**Raster** — 彩色单元格网格（此处为 3×2 热力图）；颜色会被近似到较小调色板。

窗格中的实际效果：

![终端窗格中的 3×2 彩色网格：顶行绿绿红，底行绿绿琥珀](https://mintcdn.com/claude-code/dgiVO_Od1X1faduV/images/mods-heat-map.svg?w=2500&fit=max&auto=format&n=dgiVO_Od1X1faduV&q=85&s=21ed0218a88259260905232ba0d97f15)

![两行三列的彩色方块网格：绿、琥珀、红；绿、绿、琥珀](https://mintcdn.com/claude-code/EXkwf0kKMewZsyod/images/mods-el-raster-light.png?w=2500&fit=max&auto=format&n=EXkwf0kKMewZsyod&q=85&s=ad1c9996c6bfc9df5280c45f482cdd62)

### Box 边框样式

`'single'` `'double'` `'round'` `'bold'` `'singleDouble'` `'doubleSingle'` `'classic'` `'arrow'` `'dashed'` `'quote'`

其他名称（如 `'rounded'`）**不画边框**。

## 重绘

| 触发 | 说明 |
|------|------|
| Claude Code 自动 | prop 变化或终端宽度变化时 |
| `$.ui.invalidate('ui.render')` | 你的数据变化后主动请求 |
| `$.clock.every(ms, fn)` | 按计时器重绘 |
| 写 `$.state` | **自动重绘**（无需 invalidate） |

重绘有频率上限（见下表），超出的调用会被**合并**。

## 状态保持

| 存哪里 | 持续到 | 用于 |
|--------|-------|------|
| 模块级变量 | 模块重载（开发时每次保存） | 可丢失的值 |
| `$.state` | 会话结束，或 `/clear`/`/resume`/`/branch` | 绘制依赖、需跨重载存活 |
| `$.store` | mod 删除或长期无读写（存于 `~/.claude/plugins/store/`） | 设置、历史记录 |

`$.state` 是**响应式**：读取它的 `ui.render` 会订阅，写入即重绘。声明方式：

```typescript
// types/index.d.ts
declare module 'claude-code' {
  interface PluginState {
    'hello-tabs': { tab: 'one' | 'two'; count: number }
  }
}
```
```json
// plugin.json 需指向该文件
{ "types": "./types/index.d.ts" }
```
```javascript
import { atom, read, update } from 'claude-code'
const count = atom({ plugin: 'hello-tabs', key: 'count' }, 0)
const n = await read($, count)                        // 在 ui.render 中读
onPress: () => update($, count, (v) => v + 1)         // 在回调中写
```

**规则**：`plugin`/`key` 写字面字符串；用 `const`（`let` 会验证失败）；必须在类型文件声明；`ui.render` 只能读不能写。

**`/clear` 后重新加载**：`/clear`/`/resume`/`/branch` 会把 `$.state` 重置为默认值，且 **`session.start` 不会再次触发**。需在 `classic.SessionStart` 中重新复制，用 `source` 限定：

```javascript
on('classic.SessionStart', { source: ['clear', 'resume', 'fork'] }, async ($, e, next) => {
  await loadCount($)
  return next(e)
})
```

**多会话共享 `$.store`**：`get` 后 `set` **不是原子的**，会竞争。对策：每个项目用自己的键；写入前重新读取。多会话更改的数据**建议放 `$.store`**（`$.fs.write` 原地覆盖，非原子）。

## 与其他 mod 共存

### 执行顺序

1. 内置守卫 `sec-default@builtin` + 组织 `prependPlugins` 中的 mod
2. 用户安装的 mod
3. 组织 `appendPlugins` 中的 mod
4. 其他内置 mod

**第一个 mod 最外层**：先看到事件、后看到结果，决定后续 mod 是否运行。同一模块内按 `on` 调用顺序。

### 设置 hook 在链中的位置

- **托管设置的 `PreToolUse`**：在第一个 mod 的 `tool.call` **之前**，其阻止是最终决定
- **其他设置文件/插件的 `PreToolUse`**：在最后一个 mod 调用 `next` 后（作为 Claude Code 自身行为的一部分）

### hook 失败

| 情况 | 结果 |
|------|------|
| 调 `next` **之前**失败 | 跳过它，下一个处理程序代替运行 |
| `next` 解析**之后**失败 | 该结果成立，没有东西重复运行 |

**失败关闭**（fail-closed）用 `.catch`：

```javascript
on('tool.call', { tool: 'Bash' }, guard).catch(async ($, e, next) => {
  return { deny: '守卫失败，命令未运行：' + next.error.kind }  // kind: 'throw' | 'timeout'
})
```

`.catch` 处理程序的时间限制更短（1 秒）。

## 限制

| 限制 | 值 |
|------|-----|
| hook 执行时间（不含 `next` 和 API 调用内耗时） | 10 秒；`prompt.edit` 为 **50 毫秒** |
| `.catch` 处理程序 | 1 秒 |
| 所有 `session.end` hook 合计 | 1.5 秒（从设置中的 `SessionEnd` hook 完成时开始计） |
| `$.process.run` 超时 | 默认 30 秒，最长 10 分钟 |
| `$.model.complete` `maxTokens` | 默认 1024，最多 64,000 |
| `$.fs.read` / `write` | 单文件 4 MiB |
| 单棵树文本 | 只画前 100,000 字符 |
| `$.store` | JSON 总计 4 MiB |
| `$.session.messages()` | 最新 4,096 条 |
| `$.ui.invalidate` 重绘 | 每秒 10 次；终端中可见窗格/展开区/提示行 30 次 |
| `$.ui.toast` | 显示 4 秒 |
| 命令/工具/子代理/窗格名称 | 字母数字 `_` `-`，最多 64 字符 |
| 单个 `claude plugin test` 测试 | 5 秒 |

## 命令与工具

| 命令 | 作用 |
|------|------|
| `/plugin` | 标签页下方显示 `1 mod active · first-mod`；在**已安装**→**内置**下可见内置 mod |
| `claude plugin validate <dir>` | 报告错误、处理的事件、发出的 API 调用（`--strict`、`--json`） |
| `claude plugin test [dir]` | 运行 `.test.ts` / `.test.tsx`，有失败则退出码 1 |
| `claude --plugin-dir <dir>` | 单会话加载，保存时**热重载** |
| `/reload-plugins` | 手动重载 |

### `claude plugin validate` 输出解读

```
❯ ./register.js hooks: session.start, tool.call, command.run{command=tally}, ui.render{component=Spinner}
  ❯ ./register.js calls: $.command.register, $.ui.invalidate
```

- `hooks:` — 处理的事件，大括号内是 matcher
- `calls:` — 调用的 API 方法
- 另有 `env reads:` / `env writes:` / `state reads:` / `state writes:`
- `gating hook without .catch: tool.call` — 可拒绝操作的 hook 缺少错误处理

**静态分析规则**（违反会验证失败）：

- 完整写出 `$.命名空间.方法`；**可传给同一文件顶层声明的函数**；不能解构、赋给变量、用计算名索引（`const ui = $.ui` → 失败）
- 例外：`$.state` 的 `read` / `update` 是可接收 `$` 的导入函数
- 事件名必须字符串字面量（用变量或循环 → 失败）
- `register` 内不能重复声明 `on`
- 只能从插件目录内相对导入；唯一的裸导入是 `claude-code`
- 用 `import` 声明，不用动态 `import()`

## 打包与发布

Mod 就是插件，用 `/plugin install <name>@<marketplace>` 安装。**`claude plugin validate` 会拒绝以 `claude-` 开头的插件名**（像是 Anthropic 自己的）。

对已在运行的会话，安装/更新后需 `/reload-plugins`。

## 打开或关闭 mod

| 范围 | 做法 |
|------|------|
| 单个 mod | `/plugin` → **已安装** 标签禁用或卸载 |
| 单次会话全部 | `claude --safe-mode`（也会禁用其他自定义） |
| 所有会话 | `settings.json` 设 `"disableAllHooks": true`（组织管理的内容继续运行） |

`disableAllHooks` 和 `allowManagedModsOnly` **只停 mod，保留插件其余部分**——skill、命令、Agent、MCP 服务器照常加载。

**内置 mod 不受这些开关影响**。

## Mod 在哪里运行

| 运行环境 | hook 是否运行 | 绘制是否出现 |
|---------|-------------|------------|
| 终端 `claude`（含编辑器集成终端、JetBrains） | 是 | 是 |
| Desktop 代码选项卡 | 是 | 是（仅限终端的元素除外） |
| Desktop 的 WSL 会话 | 否 | 否 |
| VS Code 扩展聊天面板 | 是 | **否** |
| `claude -p` 和 Agent SDK | 是 | **否** |
| 云会话 | 是（限可上云的插件） | 否 |

会绘制内容的 mod 应检查 `e.surface`，在无法绘制处回退为文本。

## 安全

Mod **使用你的权限运行，不在沙箱中**。加载后可以：

- 以你身份读写文件、启动进程、发网络请求
- 读取环境变量和设置文件（**包括 API 密钥**）
- 看到每个提示词和工具调用
- 改写提示词/工具调用、代你提交提示词
- 不经询问批准工具调用
- 消耗你的用量

**安装前先看它做什么**（不运行代码）：

```bash
claude plugin validate ./some-mod    # 看 hooks: 和 calls: 行
```

沙箱**不隔离 mod**——沙箱只隔离 Claude 运行的 Bash 命令，mod 启动的进程在沙箱外。

## 常见坑

| 症状 | 原因 / 修法 |
|------|------------|
| 验证失败 `$.ui is used as a value` | 把 `$` 或命名空间赋给了变量 / 解构了 |
| 验证失败 `the event name passed to on() is not a string literal` | 事件名用了变量或循环 |
| 验证失败 `"on" is declared again (shadowed)` | `register` 内重复声明了 `on` |
| 验证失败 `hello-tabs.count is not declared` | `$.state` 的值没在类型文件声明 |
| 验证失败 `takes a source the scan can read` | `atom` 结果用了 `let` 而非 `const` |
| 命令注册抛异常 | 名字被内置命令占用 → 放在 `session.start` 最后注册，或 `try/catch` |
| `on("session.start") is registered twice without a matcher` | 同一事件无 matcher 注册了两次 → 合并为一个 hook |
| 遥测 hook 验证不通过 | 缺 `{ to: 'collector' }` 过滤 |
| 绘制不显示 | 树用了不支持的元素/prop → 查会话记录中 `ui.render (Pane) refused: ...` 行 |
| `AskUserQuestion` 树被忽略 | 树必须**恰好包含一次** `next` 的引用 |
| `/clear` 后显示默认值 | `session.start` 不再触发 → 用 `classic.SessionStart` + `source` 过滤重新加载 |
| 多会话计数丢失 | `$.store` 的 `get`→`set` 非原子 → 写入前重新读取 |
| 窗格在窄终端不出现 | mod 自行打开需 ≥144 列（用户开过则 110） |
| 静态绘制不更新 | 数据变了没调 `$.ui.invalidate('ui.render')` |
