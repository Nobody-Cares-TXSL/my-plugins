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

```javascript
// 前置：import { readFileSync } from "node:fs"; import { join } from "node:path";
const logoBuf = readFileSync(join(import.meta.dirname, "school_logo.jpg"));
const { width: srcW, height: srcH } = imageSize(logoBuf);
const logoW = Math.round(30 / 25.4 * 96);       // 3cm → px
const logoH = Math.round(logoW * (srcH / srcW)); // 等比

new Paragraph({
  children: [new ImageRun({ data: logoBuf, transformation: { width: logoW, height: logoH }, type: "jpg" })],
  alignment: AlignmentType.CENTER,
  spacing: { before: 600, after: 200 },
});
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
