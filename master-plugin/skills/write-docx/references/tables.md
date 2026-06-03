# 表格格式

## 问题

docx.js 默认表格无边框。手动给每个单元格加四边边框又太密。高校模板通常要求"三线表"（表头上底线 + 末行底线）。

## 方案：三线表

```javascript
import { BorderStyle } from "docx";

function makeTable(headers, rows) {
  const thin = { style: BorderStyle.SINGLE, size: 1, color: "000000" };
  const none = { style: BorderStyle.NONE, size: 0, color: "FFFFFF" };

  // 三种边框预设
  const hB = { top: thin, bottom: thin, left: none, right: none };  // 表头
  const bB = { top: none, bottom: none, left: none, right: none };  // 中间行
  const lB = { top: none, bottom: thin, left: none, right: none };  // 末行

  function cell(text, borders = bB) {
    return new TableCell({
      children: [new Paragraph({
        children: [new TextRun({ text, font: FONT_SONG, size: 21 })],
        alignment: AlignmentType.CENTER,
        spacing: { before: 40, after: 40 },
      })],
      verticalAlign: VerticalAlign.CENTER,
      borders,
    });
  }

  return new Table({
    rows: [
      new TableRow({
        children: headers.map(h => cell(h, hB)),
        tableHeader: true,
      }),
      ...rows.map((row, i) =>
        new TableRow({
          children: row.map(c => cell(c, i === rows.length - 1 ? lB : bB)),
        })
      ),
    ],
    width: { size: 100, type: WidthType.PERCENTAGE },
  });
}
```

## 边框策略说明

```
表头行：  ─────────────── (top thin + bottom thin)
第1行：  （无线）
第2行：  （无线）
末行：    ─────────────── (bottom thin)
```

| 边框预设 | 位置 | top | bottom | left | right |
|----------|------|-----|--------|------|-------|
| hB | 表头 | thin | thin | none | none |
| bB | 中间行 | none | none | none | none |
| lB | 末行 | none | thin | none | none |

## 列宽

### 百分比宽度（推荐）

表格宽度自适应页面，各列按比例分配：

```javascript
width: { size: 100, type: WidthType.PERCENTAGE }
```

单元格不设 width，Word 自动按内容分配。

### 固定宽度（适合封面信息表）

```javascript
new TableCell({
  width: { size: 2345, type: WidthType.DXA },
  // ...
})
```

DXA 单位：1 inch = 1440 DXA。2345 DXA ≈ 4.15cm。

## 表格标题

表格上方用段落居中显示标题：

```javascript
new Paragraph({
  children: [new TextRun({ text: "表3-1 训练超参数配置", font: FONT_HEI, size: 21 })],
  alignment: AlignmentType.CENTER,
  spacing: { line: 20 * 20, lineRule: "exact" },
});
```

## 用法

```javascript
makeTable(
  ["超参数", "值", "说明"],
  [
    ["优化器", "SGD", "小批量随机梯度下降"],
    ["学习率", "0.001", "余弦退火起点"],
    ["训练轮次", "5", "完整遍历次数"],
  ],
);
```
