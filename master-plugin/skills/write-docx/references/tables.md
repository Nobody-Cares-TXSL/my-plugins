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

## 要点

- `tableHeader: true` 标记第一行，跨页时自动重复表头
- `verticalAlign: VerticalAlign.CENTER` 使内容垂直居中
- 表格标题单独用 `new Paragraph` 居中放在表格上方，不属于 Table 对象
