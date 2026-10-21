# hooks — Claude Code Mod

master-plugin 的 mod 目录。

**Mod** 是插件内注册事件处理函数的代码，运行在 Claude Code 进程内，能绘制界面、改写提示词与工具调用——设置 hook、skill、MCP 服务器都做不到这些。API 速查见 [DOC/cc_mods.md](../../DOC/cc_mods.md)。

## 文件

| 文件 | 作用 |
|------|------|
| `hooks.json` | 入口声明，`modules` 列出要加载的 hook 模块 |
| `prompts.js` | `prompts` 命令与 Prompt Library 面板 |

## prompts：本地提示词库

`/prompts [关键词]` 打开侧边面板，搜索、预览本地 Markdown 提示词并填入输入框。

- **目录**：读 `plugin.json` 的 `userConfig.promptsDirectory`，默认 `~/.claude/prompts`，支持 `~/` 开头或绝对路径
- **扫描**：递归读取目录下的 `.md`，跳过符号链接与空文件；名称取首个 `# ` 标题，没有则用文件名
- **浏览**：无关键词时按文件夹逐层浏览；有关键词时在名称、文件名、全文里搜索
- **预览**：显示文件开头 frontmatter（YAML）
- **填入**：`插入光标处` / `追加到末尾` / `替换输入内容`，填入后面板保持打开，可继续选择
- **降级**：终端和 Desktop 之外（如 `claude -p`、VS Code 聊天面板）不绘制界面，改为返回提示词列表文本

状态（提示词、当前文件夹、搜索词等）只存在模块级变量里，重载即重置；不保存用户数据。

## 验证

```bash
claude plugin validate ./master-plugin   # 看 hooks: 与 calls: 行是否与预期一致
claude --plugin-dir ./master-plugin      # 单会话加载，保存文件即热重载
```

`master-plugin/tsconfig.json` 继承 `.claude-plugin/types/tsconfig.json`，供编辑器和类型检查使用（`include` 已覆盖 `hooks/`）。
