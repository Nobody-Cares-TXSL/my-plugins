---
name: update-my-plugins
description: 优化 my-plugins 中的技能并推送更新到 GitHub，然后更新本地插件
argument-hint: <技能名> <优化说明>
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - AskUserQuestion
  - Skill
---

# update-my-plugins — 技能优化与发布

优化 my-plugins 中的 skill/command，提交推送后更新本地插件。

## 参数解析

`$ARGUMENTS` 格式：`<技能名> <优化说明>`

- 第一个参数：技能名（`skills/` 或 `commands/` 下的名称，如 `deep-read`、`push`）
- 第二个参数：对优化的描述（剩余所有文字）

若参数不完整或无法区分，用 AskUserQuestion 向用户确认。

## 执行流程

### 1. 定位技能文件

在 `/home/duan/plugins/` 仓库中查找对应的技能文件：

- 先查 `skills/<技能名>/SKILL.md`（skill）
- 再查 `commands/<技能名>.md`（command）
- 都找不到则报错并终止

### 2. 阅读并优化

1. 读取技能文件完整内容
2. 根据用户的优化说明，对技能进行修改
3. 修改遵循现有风格和格式
4. 如有附属文件（如 scripts/、commands-desc.txt 等），一并检查是否需要同步修改

### 3. 更新版本号

读取 `.claude-plugin/plugin.json`，将 `version` 字段的 PATCH 版本号 +1（如 `1.0.1` → `1.0.2`），写回文件。必须 bump 版本号，否则 Claude Code CLI 因缓存键不变而无法检测到更新。

### 4. 提交推送

调用 `/push` 命令进行提交推送：

推送成功后继续下一步。

### 5. 更新本地插件

```bash
claude plugin update master-plugin 2>&1
```

如果更新失败（如已是最新版本），忽略错误继续。

## 完成

输出简要总结：修改了什么、提交 hash、插件更新状态。
