# 页面布局与段落

## 单位转换

docx.js 用 twip（1/20 point）。从现实单位换算：

```javascript
import { convertMillimetersToTwip } from "docx";
// mm → twip
convertMillimetersToTwip(25.4)  // 1 inch = 1440 twips
```

也可以算：`1mm ≈ 56.7 twip`，`1cm ≈ 567 twip`。用官方函数更清晰。

## 页面设置

```javascript
const PAGE = {
  size: { width: convertMillimetersToTwip(210), height: convertMillimetersToTwip(297) }, // A4
  margin: {
    top: convertMillimetersToTwip(XX), bottom: convertMillimetersToTwip(XX),
    left: convertMillimetersToTwip(XX), right: convertMillimetersToTwip(XX),
    header: convertMillimetersToTwip(XX),   // 页眉距边界
    footer: convertMillimetersToTwip(XX),   // 页脚距边界
  },
};
```

`margin.header/footer` 控制页眉页脚区域的大小，不设则用默认值。

## 固定行距

```javascript
// 必须同时设 line 和 lineRule
{ line: 20 * 20, lineRule: "exact" }  // 20pt 固定行距
```

`line` 单位是 twip。`lineRule: "exact"` 使行距固定，否则 Word 将其视为最小行距，内容会撑开。

多数高校论文要求固定 20pt。标题的 before/after 间距也用 twip：`before: 800` = 40pt。

## 首行缩进

```javascript
const INDENT = { firstLine: convertMillimetersToTwip(8.47) }; // ≈2字符
```

正文段落加 indent，标题不加。

## 标题层级

标题通过 `font`、`size`、`bold`、`spacing.before/after`、`alignment` 区分。没有 docx.js 原生的"标题样式"概念，全部靠 Paragraph 属性控制。

```javascript
function chapterTitle(text) {  // 章标题：大字号、居中
  return new Paragraph({
    children: [r(text, { font: FONT_HEI, size: 32, bold: true })],
    spacing: { before: 800, after: 400, ...LINE },
    alignment: AlignmentType.CENTER,
  });
}
function sectionTitle(text) {   // 节标题：中等字号、左对齐
  return new Paragraph({
    children: [r(text, { font: FONT_HEI, size: 28, bold: true })],
    spacing: { before: 200, after: 200, ...LINE },
    alignment: AlignmentType.JUSTIFIED,
  });
}
```

## 正文段落

三个属性缺一不可：固定行距 + 首行缩进 + 两端对齐。

```javascript
function bodyPara(children) {
  return new Paragraph({
    children: Array.isArray(children) ? children : [children],
    spacing: LINE,
    indent: INDENT,
    alignment: AlignmentType.JUSTIFIED,
  });
}
```

`children` 接受 TextRun 数组，方便混合普通文字、粗体、行内图片等。

## 页眉页脚

```javascript
import { Header, Footer, PageNumber } from "docx";

// 页眉
new Header({
  children: [new Paragraph({
    children: [r("论文题目", { size: 18 })],
    alignment: AlignmentType.CENTER,
  })],
});

// 页脚（居中页码）
new Footer({
  children: [new Paragraph({
    children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT_SONG, size: 18 })],
    alignment: AlignmentType.CENTER,
  })],
});
```

在 section 中挂载：`headers: { default: Header(...) }`, `footers: { default: Footer() }`。

## 奇偶页不同页眉

很多高校要求单数页=论文题目，双数页=章标题。实现方式：

1. 每个 section 设 `oddAndEvenHeaders: true`
2. `headers: { default: Header("论文题目"), even: Header("当前章标题") }`
3. 每章作为独立 section，各自的 `even` header 不同

```javascript
{
  properties: {
    page: PAGE,
    oddAndEvenHeaders: true,
  },
  headers: {
    default: makeHeader("论文题目"),
    even: makeHeader(ch.title),
  },
  children: [...],
}
```

## 页码控制

正文从第一章开始编页码：在该 section 的 page 配置中加 `pageNumbers: { start: 1 }`。封面/摘要的 section 不设此项，它们不会显示页码（如果 footer 只加在有页码的 section 上）。
