---
name: update-my-plugins
description: 优化 my-plugins 中的技能或 hooks mod 并推送更新到 GitHub，然后更新本地插件
argument-hint: <目标> <优化说明>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - AskUserQuestion
  - Skill
---

# update-my-plugins — 技能/mod 优化与发布

优化 my-plugins 中的 skill 或 hooks mod，提交推送后更新本地插件。

## 工作仓库

**所有改动都在 `/home/duan/plugins` 里做。**

`/home/duan/.claude/plugins/marketplaces/my-plugins` 是 `claude plugin` 从 GitHub 克隆的只读市场副本（`known_marketplaces.json` 的 `installLocation` 指向它），内容和真仓库几乎一致，改在这里既不进提交，也会被下次拉取覆盖。

开始改动前先核对，不一致就停下问用户：

```bash
git -C /home/duan/plugins remote get-url origin   # 应为 Nobody-Cares-TXSL/my-plugins
git -C /home/duan/plugins status --short          # 记下开工前的已有改动
```

## 输入与工具

- Claude Code CLI：从 `$ARGUMENTS` 读取目标与优化说明；使用 Read、Edit、Write、Bash；用 AskUserQuestion 确认；调用 `push` 技能时写 `/master-plugin:push`；用 `claude plugin update master-plugin@my-plugins` 更新本地插件。
- Codex：从用户消息读取目标与优化说明，不依赖 `$ARGUMENTS` 自动展开；使用当前环境提供的读写、命令执行工具；确认使用支持审批的工具或直接在对话中询问，没有回复就等待，不将默认选项或超时视为同意；调用 `push` 技能时写 `$push`；用 `codex plugin add master-plugin@my-plugins` 重新安装以刷新本地缓存（Codex 无 update 子命令，本地市场靠重装更新）。

## 参数解析

`$ARGUMENTS` 格式：`<目标> <优化说明>`

- 第一个参数：目标名，可以是 `skills/` 下的技能名（如 `deep-read`、`push`），或 `hooks/` 下的 mod 名（如 `prompts`、`html-link`）
- 第二个参数：对优化的描述（剩余所有文字）

若参数不完整或无法区分，用 AskUserQuestion 向用户确认。

## 执行流程

### 1. 定位目标文件

在 `/home/duan/plugins/master-plugin/` 下按类型查找，先技能后 mod：

- 技能：`skills/<目标>/SKILL.md`
- mod：`hooks/<目标>.js`（入口声明在 `hooks/hooks.json`，注册在 `hooks/register.js`）
- 两者都找不到则报错并终止

### 2. 阅读并优化

1. 读取目标文件完整内容
2. 根据用户的优化说明，对文件进行修改
3. 修改遵循现有风格和格式
4. 如有附属文件，一并检查是否需要同步修改：
   - 技能：`scripts/`、`commands-desc.txt` 等
   - mod：同目录的 `hooks/README.md`（mod 的行为说明只写在这里，不在仓库根 README）

### 3. 同步仓库文档

检查本次优化是否影响文档，如有则同步更新：

- **README.md**（仓库根）：检查组件表中的描述是否需要更新（如 description 变更、新增/删除附属文件）
- **CLAUDE.md**（仓库根）：检查目录树和说明注释是否需要更新（如新增脚本、references 文件等）
- **组件自带文档**：`hooks/README.md`（mod 的完整行为说明）、`skills/<名>/` 内的附属说明

读取相关文档，按需修改。若本次优化不涉及文档变更，跳过此步。

### 4. 更新版本号

读取 `/home/duan/plugins/master-plugin/.claude-plugin/plugin.json` **和** `.codex-plugin/plugin.json`，将两者的 `version` 字段 PATCH 版本号 +1（如 `1.0.1` → `1.0.2`），写回文件。**两个清单必须同步 bump**，否则两个 agent 看到的版本号不一致；Claude Code CLI 还会因缓存键不变而检测不到更新。

### 5. 提交推送

调用 `push` 技能进行提交推送（Claude Code CLI 使用 `/master-plugin:push`，Codex 使用 `$push`）：

推送成功后继续下一步。

### 6. 更新本地插件

**Claude Code CLI**：

```bash
claude plugin update master-plugin@my-plugins 2>&1
```

**Codex**（无 update 子命令，本地市场靠重装刷新缓存）：

```bash
codex plugin add master-plugin@my-plugins 2>&1
```

更新失败（如已是最新版本）时忽略错误继续。

### 7. 验证落地

确认改动真的进了已安装副本，而不是只留在工作仓库：

```bash
ls ~/.claude/plugins/cache/my-plugins/master-plugin/        # 应出现新版本号目录
```

抽查新版本目录里的目标文件是否含本次改动。mod 改动生效还需 `/reload-plugins`，不必重启会话。

## 完成

输出简要总结：修改了什么、提交 hash、插件更新状态。
