# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

个人 Claude Code 插件集合，通过 GitHub 市场分发。仓库同时也是市场根目录（`.claude-plugin/marketplace.json`），包含一个子插件 `master-plugin`，采用 `git-subdir` 源类型。

## 仓库结构

```
.
├── .claude-plugin/marketplace.json   # 市场清单（owner + 插件列表）
└── master-plugin/                     # 唯一的子插件
    ├── .claude-plugin/plugin.json    # 插件清单
    ├── commands/                      # 平面 Markdown skills（旧风格）
    │   ├── explain.md                 #   代码解释（含库函数说明）
    │   └── push.md                    #   约定式提交 + 推送
    └── skills/                         # 目录型 skills
        ├── deep-read/SKILL.md          #   智能阅读助手
        ├── update-all/SKILL.md         #   工具链一键更新
        │   ├── commands-desc.txt       #     opencode 命令中文描述映射
        │   └── scripts/*.sh            #     各组件更新脚本
        ├── auto_answer/SKILL.md        #   基于 opencli browser 的自动答题
        └── update-my-plugins/SKILL.md  #   优化技能 → 提交推送 → 更新本地
```

## 常用命令

```bash
# 本地测试插件（无需安装）
claude --plugin-dir ./master-plugin

# 验证插件
claude plugin validate ./master-plugin

# 安装/更新
/plugin marketplace add Nobody-Cares-TXSL/my-plugins
/plugin install master-plugin
claude plugin update master-plugin

# 重新加载（修改 skill/command 后）
/reload-plugins
```

## 开发约定

- 每次git推送后都读取 `.claude-plugin/plugin.json`，将 `version` 字段的 PATCH 版本号 +1（如 `1.0.1` → `1.0.2`），写回文件。必须 bump 版本号，否则 Claude Code CLI 因缓存键不变而无法检测到更新。
- 新组件放 `skills/<name>/SKILL.md`（目录型），不用 `commands/`
- SKILL.md frontmatter：`description` 必填，`allowed-tools` 按需声明
- push command 依赖约定式提交规范（Conventional Commits），需用户两次确认（commit + push）
- update-all 的 shell 脚本位于 `skills/update-all/scripts/`，使用 `set -euo pipefail`
- update-my-plugins 会调用 push command，再执行 `claude plugin update master-plugin`
- 所有需要网络的脚本设置 `http_proxy/https_proxy=http://127.0.0.1:7890`

## 外部工具链路径（update-all 维护）

| 组件 | 路径 | 更新方式 |
|------|------|---------|
| Claude Code 插件 | `~/.claude/settings.json` → `enabledPlugins` | `claude plugin update` |
| 插件安装信息 | `~/.claude/plugins/installed_plugins.json` | — |
| gstack | `~/.claude/skills/gstack/` | `git pull` |
| opencli skills | `~/.agents/skills/` + `~/.claude/skills/`（符号链接） | `git clone --depth 1` + 同步 |
| agent-reach skill | `~/.claude/skills/agent-reach/` | pipx upgrade + skill install |
| notebooklm | pipx venv + `~/.claude/skills/notebooklm/` | pipx upgrade + skill install |
