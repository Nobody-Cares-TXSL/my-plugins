# 页面与段落格式

## A4 页面设置（毫米级精度）

```javascript
import { convertMillimetersToTwip } from "docx";

const PAGE_PROPS = {
  size: { width: convertMillimetersToTwip(210), height: convertMillimetersToTwip(297) },
  margin: {
    top: convertMillimetersToTwip(28),     // 2.8cm
    bottom: convertMillimetersToTwip(22),   // 2.2cm
    left: convertMillimetersToTwip(28),     // 2.8cm
    right: convertMillimetersToTwip(22),    // 2.2cm
  },
};
```

docx.js 的尺寸单位是 twip (1/20 point)。`convertMillimetersToTwip()` 是官方提供的转换函数。

## 固定行距

```javascript
// ❌ 错误：只设 line，是"最小行距"，实际行距会浮动
{ line: 400 }

// ✅ 正确：20pt 固定行距 (20 * 20 = 400 twips)
{ line: 20 * 20, lineRule: "exact" }
```

**`lineRule: "exact"` 不可省略。** 没有它，Word 会将 `line` 值视为最小行距，实际行距由内容撑开。

高校模板一般要求 20 磅（20pt）固定行距。

## 首行缩进

```javascript
const FIRST_INDENT = { firstLine: convertMillimetersToTwip(9.6) };
// 9.6mm = 约两个汉字宽度
```

## 正文段落

```javascript
function bodyPara(text) {
  return new Paragraph({
    children: [r(text)],
    spacing: { line: 20 * 20, lineRule: "exact" },
    indent: { firstLine: convertMillimetersToTwip(9.6) },
    alignment: AlignmentType.JUSTIFIED,
  });
}
```

三个要素缺一不可：固定行距 + 首行缩进 + 两端对齐。

## 标题段落

```javascript
function h1(text) {
  return new Paragraph({
    children: [r(text, { font: FONT_HEI, size: 32, bold: true })],
    spacing: { before: 18 * 20, after: 9 * 20, line: 20 * 20, lineRule: "exact" },
    // 标题不缩进
  });
}

function h2(text) {
  return new Paragraph({
    children: [r(text, { font: FONT_HEI, size: 28, bold: true })],
    spacing: {
      before: 36 * 20,   // 36pt
      after: 36 * 20,    // 36pt
      line: 20 * 20,
      lineRule: "exact",
    },
  });
}
```

标题段落不加 indent，before/after 控制与前后内容的间距。

## 空行

```javascript
function emptyLine(count = 1) {
  return Array.from({ length: count }, () =>
    new Paragraph({ children: [], spacing: { line: 317.5, lineRule: "exact" } })
  );
}
```

用于封面等需要大片留白的场景。317.5 twips ≈ 0.55cm，比固定 20pt 行距稍松。

## 目录条目

```javascript
function tocLine(title) {
  return new Paragraph({
    children: [r(title, { font: FONT_SONG, size: 24 })],
    alignment: AlignmentType.DISTRIBUTE,  // 均匀分布
    spacing: { before: 127, after: 127, line: 20 * 20, lineRule: "exact" },
  });
}
```
