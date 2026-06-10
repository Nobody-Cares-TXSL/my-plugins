---
name: write-docx
description: docx.js 生成中文 Word 文档的最佳实践。字体、行距、表格、图片、公式、页眉页脚等常见问题的解决模式。
argument-hint: [无参数]
---

# Write-Docx — docx.js 中文 Word 生成最佳实践

**运行方式**：`npm install docx` → `node generate.mjs`

## 架构概览

采用 **Markdown 数据源 + ESM 脚本** 分离架构：

```
paper.md (内容) ──parsePaper()──▶ elements[] ──buildChildren()──▶ docx.js 对象 ──▶ paper.docx
```

- **内容层**（`paper.md`）：论文标题、摘要、正文、公式、图表、引用、参考文献
- **格式层**（`generate.mjs`）：字体字号、行距缩进、页眉页脚、封面布局、三线表样式
- **分离收益**：改论文内容只需编辑 Markdown，改排版规范只需改脚本常量

详细架构设计见 [[references/architecture]]。

## 使用方式

**先读** [[references/boilerplate.mjs.txt]] — 获取完整代码骨架和所有工厂函数，再按需查阅以下专题：

| 任务涉及 | 文件 | 获取什么 |
|----------|------|----------|
| 字体显示异常 | [[references/fonts]] | 三字段字体对象 `{ ascii, eastAsia, hAnsi }` 原理 |
| 页面/段落细节 | [[references/page-paragraph]] | 单位转换、行距原理、奇偶页眉、页码控制 |
| 表格 | [[references/tables]] | 三线表边框哲学、行列控制要点 |
| 图片 | [[references/images]] | PNG 头原理、等比缩放、type 必填 |
| 公式 | [[references/equations]] | 渲染管线（KaTeX+Chrome+ImageMagick）、bmatrix 修复、行内公式 |
| 封面/目录 | [[references/cover-toc]] | 封面对齐策略、手动目录构建原理、SimpleField 陷阱 |
| 整体架构 | [[references/architecture]] | Markdown→docx 解析架构、元素映射、内容与格式分离 |
| 遇到 bug | [[references/pitfalls]] | 29 条症状→原因→修复速查 |

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
- [ ] 标题加 `heading: "Heading1/2/3"` 属性 + `BookmarkStart/End`（供目录引用）
- [ ] 目录用手动构建（Bookmark + SimpleField PAGEREF + dot leader），不要用 TableOfContents
- [ ] SimpleField 直接传字符串，不要传 `{ instruction: "..." }` 对象
- [ ] Document 加 `features: { updateFields: true }`
- [ ] 内容用 Markdown，格式用脚本（不要在脚本中硬编码论文内容）
