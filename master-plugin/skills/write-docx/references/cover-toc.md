# 封面与文档结构

## 封面：表格化排版

封面信息（姓名、学号等）用 Table 排列，比普通段落更整齐。

```javascript
const coverChildren = [
  ...emptyLine(6),
  new Paragraph({
    children: [r("《人工智能》课程设计", { font: FONT_HEI, size: 84, bold: true })],
    alignment: AlignmentType.CENTER,
    spacing: { line: 635, lineRule: "exact" },
  }),
  ...emptyLine(2),
  new Paragraph({
    children: [
      r("题目：", { font: FONT_HEI, size: 32, bold: true }),
      r("你的标题", { font: FONT_HEI, size: 32, bold: true }),
    ],
    spacing: { line: 400, lineRule: "exact" },
  }),
  ...emptyLine(2),
  // 学生信息表格
  new Table({
    rows: [
      ["学 生 姓 名 ：", "张三"],
      ["学       号 ：", "XXXXXXXXXX"],
      ["学       院 ：", "计算机学院"],
      ["专 业 班 级 ：", "计算机230X班"],
    ].map(([label, value]) =>
      new TableRow({
        children: [
          new TableCell({
            children: [new Paragraph({
              children: [r(label, { font: FONT_SONG, size: 28, bold: true })],
              alignment: AlignmentType.CENTER,
            })],
            width: { size: 2345, type: WidthType.DXA },
            verticalAlign: VerticalAlign.CENTER,
          }),
          new TableCell({
            children: [new Paragraph({
              children: [r(value, { font: FONT_SONG, size: 28, bold: true })],
              alignment: AlignmentType.CENTER,
            })],
            width: { size: 3394, type: WidthType.DXA },
            verticalAlign: VerticalAlign.CENTER,
          }),
        ],
        height: { value: 452, rule: HeightRule.EXACT },
      })
    ),
    width: { size: 5739, type: WidthType.DXA },
  }),
  ...emptyLine(2),
  new Paragraph({
    children: [r("二〇二六年六月", { font: FONT_SONG, size: 32 })],
    indent: { firstLine: convertMillimetersToTwip(49) },
  }),
];
```

### 关键要点

| 要素 | 说明 |
|------|------|
| `HeightRule.EXACT` | 行高固定，防止内容撑开行高 |
| 固定列宽 | 左列 2345 DXA (≈4.15cm)，右列 3394 DXA (≈6.0cm) |
| 表格居中 | 整个 Table 包在一个没有 border 的无框表格中 |
| 标签空格对齐 | "学       号 ：" 用空格填充到固定宽度 |

## 目录

```javascript
const tocChildren = [
  new Paragraph({
    children: [r("目 录", { font: FONT_HEI, size: 32 })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 18 * 20, after: 9 * 20, line: 20 * 20, lineRule: "exact" },
  }),
  ...[
    "1 绪论",
    "  1.1 研究背景",
    "  1.2 数据集介绍",
    "2 技术原理",
    "  2.1 模型架构",
    "3 实验结果",
    "  3.1 训练分析",
    "  3.2 混淆矩阵分析",
    "4 总结",
  ].map(t => tocLine(t)),
];
```

`tocLine` 使用 `AlignmentType.DISTRIBUTE` 均匀分布。此处为手动目录，不含页码——如需自动目录需使用 docx.js 的 `TableOfContents` 组件。

## 文档组装

```javascript
const doc = new Document({
  styles: {
    default: {
      document: { run: { font: FONT_TNR, size: 24 } },
    },
  },
  sections: [
    { properties: { page: PAGE_PROPS }, children: coverChildren },
    { properties: { page: PAGE_PROPS }, children: tocChildren },
    { properties: { page: PAGE_PROPS }, children: contentChildren },
  ],
});

const buffer = await Packer.toBuffer(doc);
writeFileSync("output.docx", buffer);
```

### sections 数组

每个 section 是一个独立的页面区域，可以有各自的 PAGE_PROPS。

- 第一个 section：封面
- 第二个 section：目录（可选）
- 第三个 section：正文

各 section 独立控制页码、页眉页脚、页面方向等。
