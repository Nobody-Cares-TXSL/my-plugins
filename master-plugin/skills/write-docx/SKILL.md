---
name: write-docx
description: 使用 docx.js 生成中文 Word 文档时加载。覆盖字体、行距、表格、图片、公式、页眉页脚、封面、目录等常见问题。触发词：docx、Word、docx.js、生成文档、论文格式、三线表、公式渲染。
argument-hint: [topic]
compatibility: "Requires Node.js with docx and katex packages. Optional: Google Chrome (equation rendering), ImageMagick (crop whitespace)."
---

# Write-Docx — docx.js 中文 Word 生成最佳实践

## 概述

基于 **Markdown 数据源 + ESM 脚本** 分离架构：`paper.md` → `parsePaper()` → `elements[]` → `buildChildren()` → docx.js 对象 → `paper.docx`。

内容改 Markdown，格式改脚本常量，互不干扰。详细架构见 [[references/architecture.md]]。

首次使用先读 [[references/quickstart.md]] 了解项目初始化与工作流。

## 使用方式

**先读** [[references/boilerplate.mjs.txt]] — 获取完整代码骨架和所有工厂函数，再按需查阅以下专题：

| 任务涉及 | 文件 | 获取什么 |
|----------|------|----------|
| 字体显示异常 | [[references/fonts.md]] | 三字段字体对象 `{ ascii, eastAsia, hAnsi }` 原理 |
| 页面/段落细节 | [[references/page-paragraph.md]] | 单位转换、行距原理、奇偶页眉、页码控制 |
| 表格 | [[references/tables.md]] | 三线表边框哲学、行列控制要点 |
| 图片 | [[references/images.md]] | PNG 头原理、等比缩放、type 必填 |
| 公式 | [[references/equations.md]] | 渲染管线（KaTeX+Chrome+ImageMagick）、bmatrix 修复、行内公式 |
| 封面/目录 | [[references/cover-toc.md]] | 封面对齐策略、手动目录构建原理、SimpleField 陷阱 |
| 整体架构 | [[references/architecture.md]] | Markdown→docx 解析架构、元素映射、内容与格式分离 |
| 遇到 bug | [[references/pitfalls.md]] | 31 条症状→原因→修复速查 |
| 项目初始化 | [[references/quickstart.md]] | 初始化、目录结构、运行命令、修改流程 |

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
- [ ] 正文段落用 `parseInline(text)` 处理内联格式（`**bold**`、`` `code` ``、`$eq$`、`[N]`下标），不要只传裸字符串
- [ ] 列表项（`- ` 开头）解析为带左缩进段落，不要当普通文本保留前缀
- [ ] 中文文件名输出用 `resolve(import.meta.dirname, "文件名.docx")`，不要用 `new URL().pathname`
