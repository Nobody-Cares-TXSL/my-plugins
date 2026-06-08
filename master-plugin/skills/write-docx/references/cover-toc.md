# 封面与目录

> 完整代码见 `boilerplate.mjs.txt`（`makeCoverTable`、`buildTOC`、`chapterTitle` 等），本文件只记录设计决策和要点。

## 封面信息对齐

### 为什么用 Table 而不是普通段落

普通段落无法精确控制"标签"和"值"的水平对齐。Table + `HeightRule.EXACT` + 固定列宽是最佳方案：

- 标签列固定宽（DXA），值列固定宽，实现标签右对齐、值左对齐
- `HeightRule.EXACT` 防止内容撑开行高导致上下不对齐
- 标签用空格填充到等宽（如 `"学       院："`），配合固定列宽实现对齐效果

## 封面校徽

内置校徽资源：`references/assets/school.png`（陕西科技大学镐京学院）。

使用时注意：**不要靠文件名判断图片内容，必须确认图片本身是校徽**。

## 多 section 文档结构

每章需要不同的页眉（奇偶页不同）和不同的页码起始值，因此必须拆分为独立 section：

- 封面/摘要的 section 不挂 footer = 不显示页码
- 第一章的 section 设 `pageNumbers: { start: 1 }` = 从此开始编页码
- 每个 section 有独立的 `properties.page`、`headers`、`footers`、`children`

## 手动目录

### 为什么不用 TableOfContents

docx.js 的 `TableOfContents` 生成的是 TOC 域代码，需要 Word 打开后"更新域"才能显示内容。在 WPS/LibreOffice 中经常不显示。手动构建目录确保跨软件兼容性。

### 手动目录构建三要素

1. **BookmarkStart/End 锚点**：章/节标题加 bookmark，供目录引用
2. **SimpleField(PAGEREF)**：目录条目引用页码。⚠️ **必须直接传字符串**，传 `{ instruction: "..." }` 对象会输出 `[object Object]`
3. **dot leader tab stop**：`{ type: TabStopType.RIGHT, position: convertMillimetersToTwip(150), leader: "dot" }` 连接标题和页码

### Document 加 updateFields

```javascript
const doc = new Document({
  features: { updateFields: true },  // Word 打开时自动更新域
  ...
});
```

没有此项，PAGEREF 域不会自动解析为页码。
