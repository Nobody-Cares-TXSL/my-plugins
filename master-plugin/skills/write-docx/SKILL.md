---
name: write-docx
description: docx.js 生成中文 Word 文档的最佳实践。字体、行距、表格、图片、公式、页眉页脚等常见问题的解决模式。
argument-hint: [无参数]
---

# Write-Docx — docx.js 中文 Word 生成最佳实践

**运行方式**：`npm install docx` → `node generate.mjs`

## 使用方式

1. **先读** [[references/boilerplate.mjs.txt]] — 获取完整代码骨架和所有工厂函数
2. **按需加载**以下专题（根据用户任务选择相关文件）：

| 任务涉及 | 文件 | 获取什么 |
|----------|------|----------|
| 字体显示异常 | [[references/fonts]] | 三字段字体对象 `{ ascii, eastAsia, hAnsi }` 原理 |
| 页面/段落细节 | [[references/page-paragraph]] | 单位转换、行距原理、奇偶页眉、页码控制 |
| 表格 | [[references/tables]] | 三线表边框哲学、行列控制要点 |
| 图片 | [[references/images]] | PNG 头原理、等比缩放、type 必填 |
| 公式 | [[references/equations]] | 渲染管线（KaTeX+Chrome+ImageMagick）、bmatrix 修复、行内公式 |
| 封面/目录 | [[references/cover-toc]] | 封面对齐策略、手动目录构建原理、SimpleField 陷阱 |
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
