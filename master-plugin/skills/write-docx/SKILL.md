---
name: write-docx
description: 基于 docx.js 生成中文 Word 文档的格式指南与踩坑速查。字体、表格、行距、图片、文档结构等全部经验。
argument-hint: [无参数]
---

# Write-Docx — docx.js 中文 Word 生成指南

使用 docx.js (npm) 生成 .docx 文件时，中文格式有一系列隐藏陷阱。

**运行方式**：`npm install docx` → `node generate.mjs`

## 专题索引

| 专题 | 文件 | 内容 |
|------|------|------|
| 中文字体 | [[references/fonts]] | eastAsia 字体对象、FONT_SONG/FONT_HEI/FONT_TNR 预设 |
| 页面与段落 | [[references/page-paragraph]] | A4 精度、固定行距、首行缩进、工具函数 |
| 表格 | [[references/tables]] | 三线表边框、列宽、VerticalAlign |
| 图片 | [[references/images]] | PNG 元数据读取、等比缩放、图注 |
| 封面与文档结构 | [[references/cover-toc]] | 封面表格排版、目录条目、多 section 组装 |
| 完整脚手架 | [[references/boilerplate.mjs.txt]] | 可直接复用的 .mjs 模板代码 |
| 踩坑速查表 | [[references/pitfalls]] | 15 个高频问题 + 原因 + 修复 |

## 快速检查清单

生成 Word 前逐项确认：

- [ ] 所有含中文的 TextRun 使用 `{ ascii, eastAsia, hAnsi }` 字体对象
- [ ] 行距包含 `lineRule: "exact"`
- [ ] 正文段落有 `indent: FIRST_INDENT`
- [ ] 表格手动设置 borders（三线表方案）
- [ ] 图片用 PNG 元数据等比缩放，不硬编码宽高
- [ ] 浮点数全部 `.toFixed()` 格式化
- [ ] 封面使用 Table + 固定宽 TableCell 排版
- [ ] Document 构造时设置 `styles.default`
