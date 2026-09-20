# 表格

> 完整代码见 `boilerplate.mjs.txt`，本文件只记录原理和要点。

## 三线表

docx.js 默认无边框。高校常用"三线表"：顶线 + 表头底线 + 末行底线，左右始终为空。

核心思路是给不同行分配不同的 top/bottom 边框预设：

| 预设 | top | bottom | 用途 |
|------|-----|--------|------|
| `hB`（表头） | THICK | THIN | 第一行 |
| `bB`（中间行） | NONE | NONE | 中间数据行 |
| `lB`（末行） | NONE | THICK | 最后一行 |

## 边框 size 单位

`BorderStyle.SINGLE` 的 `size` 单位是 **1/8 pt**。根据学校规范调整：
- 粗线（顶/底）：`size: 12` = 1.5pt，或 `size: 8` = 1pt
- 细线（表头底）：`size: 6` = 0.75pt

## 行高控制

```javascript
new TableRow({
  children: [...],
  height: { value: convertMillimetersToTwip(10), rule: HeightRule.EXACT },
})
```

- `HeightRule.EXACT`：固定行高，内容超出会被裁切
- `HeightRule.AT_LEAST`：最小行高，内容多时自动撑开

表格常用 EXACT 防止内容撑开导致行高不一致。

## 列宽

```javascript
// 百分比——自适应页面宽度
width: { size: 100, type: WidthType.PERCENTAGE }

// 固定——适合封面信息表等精确布局
width: { size: 2345, type: WidthType.DXA }  // 2345 DXA ≈ 4.15cm
```

1 inch = 1440 DXA。百分比更灵活，DXA 更精确。**不要在同一个表格内混用**。

### columnWidths 是列宽的唯一来源

`Table({ columnWidths: [...] })` 是 docx.js 生成 `<w:tblGrid><w:gridCol>` 的**唯一**入口。不传时每个 `gridCol` 写成 `w="100"`（≈1.76 mm），Word/LibreOffice 以这个网格为准划分列宽，于是：

- 每个 `TableCell.width` 单独设的 DXA 值会被压塌——列宽不生效、中文在词中间折行
- 只补 `layout: TableLayoutType.FIXED` 不解决问题，反而让渲染端更严格地信任错误的网格

精确布局（封面信息表、标签-值表单）三件套一起写，且三者自洽：

```javascript
new Table({
  rows: [...],                                     // cell 的 width 与 columnWidths 逐项一致
  columnWidths: [1750, 4550],                       // ← 缺这一行，tblGrid 退化成 gridCol 100
  width: { size: 6300, type: WidthType.DXA },       // = ΣcolumnWidths
  layout: TableLayoutType.FIXED,
})
```

内容自适应的三线数据表可以省略 `columnWidths`（列宽交给渲染端按内容分配）。有疑问时直接查 XML（只读）：

```bash
unzip -p out.docx word/document.xml | grep -o '<w:gridCol[^/]*/>'
```

出现一串 `w:w="100"` 就是漏了 `columnWidths`。

## 要点

- `tableHeader: true` 标记第一行，跨页时自动重复表头
- `verticalAlign: VerticalAlign.CENTER` 使内容垂直居中
- 表格标题单独用 `new Paragraph` 居中放在表格上方，不属于 Table 对象
