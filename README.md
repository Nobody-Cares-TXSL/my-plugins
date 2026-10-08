# My Plugins

个人插件集合(兼容Claude 和 Codex)。

## 仓库结构

```
.
├── .claude-plugin/marketplace.json   # Claude Code 市场清单（owner + 插件列表）
├── .agents/plugins/marketplace.json  # Codex 市场清单（repo 市场）
└── master-plugin/                     # 唯一的子插件
    ├── .claude-plugin/plugin.json    # 插件清单
    ├── .codex-plugin/plugin.json     # Codex 插件清单
    └── skills/                         # 目录型 skills
        ├── explain/SKILL.md            #   代码解释（Claude Code CLI / Codex）
        ├── push/SKILL.md               #   约定式提交 + 推送（Claude Code CLI / Codex）
        ├── deep-read/SKILL.md          #   智能阅读助手
        ├── update-all/SKILL.md         #   工具链一键更新
        │   ├── commands-desc.txt       #     opencode 命令中文描述映射
        │   └── scripts/*.sh            #     各组件更新脚本
        ├── auto_answer/SKILL.md        #   基于 opencli browser 的自动答题
        ├── write-docx/SKILL.md         #   docx.js 中文 Word 生成最佳实践
        │   └── references/              #     字体/行距/表格/图片/公式/封面等专题
        └── update-my-plugins/SKILL.md  #   优化技能 → 同步文档 → 提交推送 → 更新本地
```

## 安装

```
/plugin marketplace add Nobody-Cares-TXSL/my-plugins
/plugin install master-plugin
```

## 包含的插件

### master-plugin

个人工具集，包含：

| 组件 | 类型 | 说明 |
|------|------|------|
| `explain` | skill | 解释选中的代码，包含库函数简要说明，兼容 Claude Code CLI 和 Codex |
| `push` | skill | 按约定式提交规范创建提交并推送，兼容 Claude Code CLI 和 Codex |
| `deep-read` | skill | 智能阅读助手，压缩文本的同时辅助理解 |
| `update-all` | skill | 一键更新所有 Claude Code 插件、opencli、agent-reach、notebooklm、opencode 并同步 Obsidian 文档 |
| `auto_answer` | skill | 基于 opencli browser 的自动答题，绑定浏览器标签页读取题目并一次性作答 |
| `write-docx` | skill | docx.js 生成中文 Word 文档的最佳实践，含字体、行距、表格、图片、公式、页眉页脚等格式指南与踩坑速查 |
| `update-my-plugins` | skill | 优化 my-plugins 中的技能，同步仓库文档，推送更新到 GitHub，然后更新本地插件 |
