---
name: write-docx
description: docx.js 生成中文 Word 文档的最佳实践。字体、行距、表格、图片、公式、页眉页脚等常见问题的解决模式。
argument-hint: [无参数]
---

# Write-Docx — docx.js 中文 Word 生成最佳实践

**运行方式**：`npm install docx` → `node generate.mjs`

## 专题索引

| 问题 | 文件 | 核心技巧 |
|------|------|----------|
| 中文显示为默认字体 | [[references/fonts]] | 三字段字体对象 `{ ascii, eastAsia, hAnsi }` |
| 行距不对、页边距计算 | [[references/page-paragraph]] | mm→twip 转换、`lineRule: "exact"`、首行缩进 |
| 表格无边框/边框太密 | [[references/tables]] | 按行分配 top/bottom 边框，size 单位 1/8pt |
| 图片变形/不显示 | [[references/images]] | 读 PNG 头等比缩放，必须指定 type |
| LaTeX 公式无法渲染 | [[references/equations]] | KaTeX+Chrome 截图预渲染为 PNG，无边框表格实现公式序号 |
| 封面信息对不齐 | [[references/cover-toc]] | Table + HeightRule.EXACT + 固定列宽；内置校徽 `references/assets/school.png` |
| 每章不同页眉/页码 | [[references/cover-toc]] | 每章独立 section，`oddAndEvenHeaders: true` |
| 完整模式参考 | [[references/boilerplate.mjs.txt]] | 所有常用模式的极简骨架 |
| 高频踩坑 | [[references/pitfalls]] | 25 个症状→原因→修复速查 |

## 检查清单

- [ ] 中文 TextRun 用三字段字体对象（不是字符串）
- [ ] 行距配 `lineRule: "exact"`（不只是 `line`）
- [ ] 正文有首行缩进，标题没有
- [ ] 表格手动设 borders（按行分配 top/bottom）
- [ ] 图片用 PNG 元数据等比缩放 + `type: "png"`
- [ ] 公式预渲染为 PNG（KaTeX + Chrome `--headless --screenshot`，不要用 puppeteer 截图 API）
- [ ] 显示公式用无边框表格实现居中+序号右对齐（百分比宽度，不要用固定 DXA）
- [ ] Document 构造设 `styles.default`
- [ ] 章节拆分时 ch 元素要进 `els`（否则正文无章标题）
- [ ] 引用标记 `[N]` 用 `subScript: true` 渲染为下标
