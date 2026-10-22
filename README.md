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
    ├── hooks/                          # Claude Code Mod
    │   ├── hooks.json                 #   Mod 入口声明（只指向 register.js）
    │   ├── register.js                #   启动入口：import 各 mod 并调用
    │   ├── prompts.js                 #   Prompt Library 面板
    │   ├── html-link.js               #   会话里的 .html 路径可点，点击开浏览器
    │   ├── net-link.js                #   会话里的 http(s) 链接可点，点击开浏览器
    │   └── README.md                  #   mod 说明
    └── skills/                         # 目录型 skills
        ├── explain/SKILL.md            #   代码解释（Claude Code CLI / Codex）
        ├── push/SKILL.md               #   约定式提交 + 推送（Claude Code CLI / Codex）
        ├── deep-read/SKILL.md          #   智能阅读助手
        ├── update-all/SKILL.md         #   工具链一键更新
        │   ├── commands-desc.txt       #     opencode 命令中文描述映射
        │   └── scripts/*.sh            #     各组件更新脚本
        ├── auto_answer/SKILL.md        #   基于 opencli browser 的自动答题
        │   └── scripts/                 #     aa.sh 单入口 + js/*.js 浏览器脚本
        ├── write-docx/SKILL.md         #   docx.js 中文 Word 生成最佳实践
        │   └── references/              #     字体/行距/表格/图片/公式/封面等专题
        ├── update-my-plugins/SKILL.md  #   优化技能 → 同步文档 → 提交推送 → 更新本地
        ├── distill-session/SKILL.md    #   复盘会话摩擦 → 归类 → 七维度定位 → 生成优化清单
        └── sync-statusline/SKILL.md    #   同步状态栏的斜杠命令速查行
            └── scripts/                 #     扫描脚本 + 中文说明映射表
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
| `prompts` | Claude Code mod | `/prompts [关键词]` 浏览文件夹、搜索提示词、预览 frontmatter，并将全文填入输入框，手动发送 |
| `net-link` | Claude Code mod | 会话记录里的 `http(s)` 链接追加为可点行，单击用系统浏览器打开；覆盖回复、用户消息、命令输出、工具结果 |
| `explain` | skill | 解释选中的代码，包含库函数简要说明，兼容 Claude Code CLI 和 Codex |
| `push` | skill | 按约定式提交规范创建提交并推送，兼容 Claude Code CLI 和 Codex |
| `deep-read` | skill | 智能阅读助手，压缩文本的同时辅助理解 |
| `update-all` | skill | 一键更新所有 Claude Code 插件、npm/pipx 包、opencli、agent-reach、notebooklm、opencode 并同步 Obsidian 文档；开发工具链（npm/pnpm/corepack）锁定大版本；传组件名可只更新单个组件 |
| `auto_answer` | skill | 基于 opencli browser 的自动答题，绑定浏览器标签页读取题目并一次性作答 |
| `write-docx` | skill | docx.js 生成中文 Word 文档的最佳实践，含字体、行距、表格、图片、公式、页眉页脚等格式指南与踩坑速查 |
| `update-my-plugins` | skill | 优化 my-plugins 中的技能，同步仓库文档，推送更新到 GitHub，然后更新本地插件，兼容 Claude Code CLI 和 Codex |
| `distill-session` | skill | 复盘当前会话中调用插件的摩擦，归类为插件/模型/环境问题，生成插件优化清单并逐条确认修复，兼容 Claude Code CLI 和 Codex |
| `sync-statusline` | skill | 同步 `~/.claude/statusline.zsh` 的斜杠命令速查行：命令名自动扫描（已启用的 mod 与插件技能），中文说明人工维护（`scripts/labels.txt` 映射表），保证状态栏与实际可用命令一致 |
