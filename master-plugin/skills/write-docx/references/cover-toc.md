# 封面与文档结构

## 封面信息对齐

### 技巧：用 Table + 固定行高

普通段落无法精确控制标签和值的水平对齐。Table + HeightRule.EXACT 是最佳方案：

```javascript
new Table({
  rows: [
    ["学       院：", "计算机学院"],
    ["专 业 班 级：", "计算机2308班"],
  ].map(([label, value]) =>
    new TableRow({
      children: [
        new TableCell({
          children: [new Paragraph({ children: [r(label, { size: 28, bold: true })], alignment: AlignmentType.CENTER })],
          width: { size: 2345, type: WidthType.DXA },  // 固定宽
          verticalAlign: VerticalAlign.CENTER,
        }),
        new TableCell({
          children: [new Paragraph({ children: [r(value, { size: 28, bold: true })], alignment: AlignmentType.CENTER })],
          width: { size: 3394, type: WidthType.DXA },
          verticalAlign: VerticalAlign.CENTER,
        }),
      ],
      height: { value: 452, rule: HeightRule.EXACT },
    })
  ),
  width: { size: 5739, type: WidthType.DXA },
});
```

标签用空格填充到等宽（如 `"学       院："`），配合固定列宽，实现标签右对齐、值左对齐的效果。`HeightRule.EXACT` 防止内容撑开行高导致上下不对齐。

### 封面校徽

内置校徽资源：`references/assets/school.png`（陕西科技大学镐京学院）。

```javascript
// 前置：import { readFileSync } from "node:fs"; import { join } from "node:path";
const logoBuf = readFileSync(join(import.meta.dirname, "references/assets/school.png"));
const { width: srcW, height: srcH } = imageSize(logoBuf);

new Paragraph({
  children: [new ImageRun({ data: logoBuf, transformation: { width: srcW, height: srcH }, type: "png" })],
  alignment: AlignmentType.CENTER,
  spacing: { before: 600, after: 200 },
});
```

如需缩放，将 `srcW/srcH` 替换为等比计算值。用原始像素尺寸时直接传入即可。
```

**注意**：不要靠文件名判断图片内容，必须确认图片本身是校徽。

## 多 section 文档结构

### 技巧：每章独立 section

当不同章节需要不同的页眉/页码起始值时，必须拆分为独立 section：

```javascript
const doc = new Document({
  styles: { default: { document: { run: { font: FONT_SONG, size: 24 } } } },
  sections: [
    { properties: { page: PAGE }, children: coverChildren },          // 封面
    { properties: { page: PAGE }, children: abstractChildren },       // 摘要
    ...chapters.map((ch, i) => ({
      properties: {
        page: { ...PAGE, ...(i === 0 ? { pageNumbers: { start: 1 } } : {}) },
        oddAndEvenHeaders: true,
      },
      headers: { default: makeHeader(paperTitle), even: makeHeader(ch.title) },
      footers: { default: makeFooter() },
      children: ch.children,
    })),
  ],
});
```

每个 section 有独立的 page 属性、headers、footers、children。封面/摘要的 section 不挂 footer = 不显示页码；第一章的 section 设 `pageNumbers.start: 1` = 从此开始编页码。

## 手动目录页

### 为什么不用 TableOfContents

docx.js 的 `TableOfContents` 生成的是 TOC 域代码，需要 Word 打开后"更新域"才能显示内容。在 WPS/LibreOffice 中经常不显示。改用手动构建目录，确保兼容性。

### 技巧：Bookmark + SimpleField(PAGEREF) + dot leader

分三步：

**1. 章标题加 Bookmark 锚点**

```javascript
function chapterTitle(text, bookmark) {
  return new Paragraph({
    heading: "Heading1",
    children: [
      ...(bookmark ? [new BookmarkStart(bookmark), new BookmarkEnd(bookmark)] : []),
      r(text, { font: FONT_HEI, size: 32, bold: true }),
    ],
    spacing: { before: 800, after: 400, ...LINE }, alignment: AlignmentType.CENTER,
  });
}
```

**2. 目录条目用 SimpleField 引用页码**

⚠️ `SimpleField` **必须直接传字符串**，传 `{ instruction: "..." }` 对象会输出 `[object Object]`：

```javascript
// ✅ 正确
new SimpleField(` PAGEREF ch_0 \\h `)

// ❌ 错误 — 输出 [object Object]
new SimpleField({ instruction: ` PAGEREF ch_0 \\h ` })
```

**3. dot leader 连接标题和页码**

```javascript
const TOC_TAB = { type: TabStopType.RIGHT, position: convertMillimetersToTwip(150), leader: "dot" };

new Paragraph({
  children: [
    r("1 引言", { bold: true }),
    r("\t"),
    new SimpleField(` PAGEREF ch_0 \\h `),
  ],
  spacing: LINE, tabStops: [TOC_TAB],
});
```

**4. Document 加 updateFields**

```javascript
const doc = new Document({
  features: { updateFields: true },  // Word 打开时自动更新域
  styles: {
    default: { ... },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", run: { font: FONT_HEI, size: 32, bold: true } },
      { id: "Heading2", name: "Heading 2", run: { font: FONT_HEI, size: 28, bold: true } },
    ],
  },
  sections: [
    { children: coverChildren },
    { children: tocChildren },     // 手动目录页
    { children: abstractChildren },
    ...docSections,
  ],
});
```
