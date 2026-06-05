# 表格

## 问题

docx.js 默认无边框。手动给每个 cell 加四边框太密。高校常用"三线表"（顶线+表头底线+底线）。

## 技巧：按行分配边框预设

三线表本质是给不同行分配不同的 top/bottom 边框，左右始终为空。

```javascript
const THICK = { style: BorderStyle.SINGLE, size: 12, color: "000000" };
const THIN  = { style: BorderStyle.SINGLE, size: 6,  color: "000000" };
const NONE  = { style: BorderStyle.NONE,   size: 0,  color: "FFFFFF" };

// 三种边框组合——只控制 top 和 bottom
const hB = { top: THICK, bottom: THIN,  left: NONE, right: NONE }; // 表头
const bB = { top: NONE,  bottom: NONE,  left: NONE, right: NONE }; // 中间行
const lB = { top: NONE,  bottom: THICK, left: NONE, right: NONE }; // 末行
```

BorderStyle.SINGLE 的 `size` 单位是 1/8 pt。根据学校规范调整：
- 粗线（顶/底）：size 12 = 1.5pt，或 size 8 = 1pt
- 细线（表头底）：size 6 = 0.75pt

## 行高控制

```javascript
new TableRow({
  children: [...],
  height: { value: convertMillimetersToTwip(10), rule: HeightRule.EXACT },
})
```

`HeightRule.EXACT` 固定行高，`HeightRule.AT_LEAST` 最小行高。表格常用 EXACT 防止内容撑开。

## 列宽

```javascript
// 百分比——自适应页面宽度
width: { size: 100, type: WidthType.PERCENTAGE }

// 固定——适合封面信息表等精确布局
width: { size: 2345, type: WidthType.DXA }  // 2345 DXA ≈ 4.15cm
```

1 inch = 1440 DXA。用百分比更灵活，用 DXA 更精确。不要混用。

## 完整模式

```javascript
function makeTable(headers, rows) {
  function cell(text, borders = bB) {
    return new TableCell({
      children: [new Paragraph({
        children: [r(text, { size: 21 })],
        alignment: AlignmentType.CENTER,
      })],
      verticalAlign: VerticalAlign.CENTER,
      borders,
    });
  }
  return new Table({
    rows: [
      new TableRow({ children: headers.map(h => cell(h, hB)), tableHeader: true }),
      ...rows.map((row, i) => new TableRow({
        children: row.map(c => cell(c, i === rows.length - 1 ? lB : bB)),
      })),
    ],
    width: { size: 100, type: WidthType.PERCENTAGE },
  });
}
```

关键：`tableHeader: true` 标记第一行，`verticalAlign: VerticalAlign.CENTER` 使内容垂直居中。表格标题单独用 `new Paragraph` 居中放在表格上方。
