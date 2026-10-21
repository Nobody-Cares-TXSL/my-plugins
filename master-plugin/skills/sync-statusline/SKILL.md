---
name: sync-statusline
description: 同步 ~/.claude/statusline.zsh 的斜杠命令速查行。装/卸 mod、增删本插件技能后，状态栏第 2、3 行的命令列表会过期，用此技能重新生成。触发词：同步状态栏、statusline 命令、状态栏命令过期。
argument-hint: [无参数]
allowed-tools:
  - Bash
  - Read
  - Edit
---

# sync-statusline — 状态栏命令同步

重新生成 `~/.claude/statusline.zsh` 第 2、3 行的斜杠命令速查。

## 三行结构

| 行 | 内容 | 本技能是否管 |
| --- | --- | --- |
| 1 | 模型 \| 上下文 \| 目录 | ❌（引擎的 stdin JSON） |
| 2 | 外部 mod 的斜杠命令 ｜ 本插件 mod 的斜杠命令 | ✅ `# >>> sync-statusline: mods >>>` 标记之间 |
| 3 | 本插件技能的斜杠命令 | ✅ `# >>> sync-statusline: plugin >>>` 标记之间 |

第 2 行内部用 ` | ` 分成两半：左边是外部 mod，右边是本插件自己的 mod。

## 核心设计：分工

| 项 | 谁管 | 为什么 |
| --- | --- | --- |
| **命令名** | 脚本自动扫描 | 变更机械；源码里就有 |
| **显示文本** | 人工维护 `scripts/labels.txt` | 源码里的 `description` 是**写给模型读的英文长句**，不适合放状态栏，需润色成简短中文 |
| **显示顺序** | `labels.txt` 的行序 | 顺带解决排序 |
| **显示哪些** | `labels.txt` 即**白名单** | 未列出的命令**不显示**（想显示就补一行） |

> 白名单语义很重要：想隐藏某命令（如 `/push`、`/update-all`）只需**不写它**，不必改脚本。

## 命令名怎么扫

- **mod**（第 2 行）：读 `~/.claude/settings.json` 的 `enabledPlugins`（值为 `true` 才算启用），扫 `~/.claude/plugins/cache/*/*/*/`，凡 `hooks/hooks.json` 含 `modules` 键的才是 mod，再从 module 源码正则提取 `command.register({ name: '...' })` 的 name（支持跨行写法）。
- **本插件技能**（第 3 行）：扫 `skills/*/` 目录名。

## labels.txt 格式

```
# --- mods ---
files	/files [目录|文件]:项目文件浏览器
md	/md <路径>:md 阅读器

# --- ownmods ---
prompts	/prompts [关键词]:提示词库

# --- plugin ---
explain	/explain:解释选中代码
```

- 每行：`命令名<TAB>显示文本`（**制表符分隔，不是空格**）
- 分节标记决定命令归到哪一行：
  - `# --- mods ---` → 第 2 行前半（外部 mod）
  - `# --- ownmods ---` → 第 2 行后半（本插件 mod），与前半用 ` | ` 分隔
  - `# --- plugin ---` → 第 3 行（本插件技能）
- 行序 = 状态栏里的顺序
- `#` 开头为注释

## 执行

```bash
bash scripts/sync-statusline.sh --dry-run   # 先看结果，不写入
bash scripts/sync-statusline.sh             # 写入
```

脚本幂等：重复运行结果一致。写入前检查四个哨兵注释都在，缺任何一个就报错退出（不会静默改错位置）。

## 加新命令

1. 在 `labels.txt` 的对应分节里补一行 `命令名<TAB>显示文本`（想让它显示才要补）
2. 跑脚本

## 注意

- **不要手改** statusline.zsh 哨兵注释之间的行——会被下次运行覆盖
- 改 `labels.txt` 后**必须重跑脚本**，否则状态栏不更新
- 脚本只读插件源码，不执行任何 mod 代码
