# My Claude Code Plugins

个人 Claude Code 插件集合。

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
| `explain` | command | 解释选中的代码，包含库函数简要说明 |
| `push` | command | 按约定式提交规范创建提交并推送 |
| `deep-read` | skill | 智能阅读助手，压缩文本的同时辅助理解 |
| `update-all` | skill | 一键更新所有 Claude Code 插件、opencli、agent-reach、notebooklm、gstack 并同步 Obsidian 文档 |
| `auto_answer` | skill | 基于 opencli browser 的自动答题，绑定浏览器标签页读取题目并一次性作答 |
| `write-docx` | skill | docx.js 生成中文 Word 文档的最佳实践，含字体、行距、表格、图片、公式、页眉页脚等格式指南与踩坑速查 |
| `update-my-plugins` | skill | 优化 my-plugins 中的技能，同步仓库文档，推送更新到 GitHub，然后更新本地插件 |
