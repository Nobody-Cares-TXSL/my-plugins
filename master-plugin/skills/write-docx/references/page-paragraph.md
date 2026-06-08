# 页面布局与段落

> 完整代码见 `boilerplate.mjs.txt`，本文件只记录原理和要点。

## 单位转换

docx.js 内部用 twip（1/20 point）。三个常用换算：

| 现实单位 | 换算 | 示例 |
|----------|------|------|
| mm → twip | `convertMillimetersToTwip(mm)` | `convertMillimetersToTwip(25.4)` = 1440 |
| pt → half-pt（size 字段） | `pt × 2` | 三号 16pt = `size: 32`，小四 12pt = `size: 24`，五号 10.5pt ≈ `size: 21` |
| pt → twip（line 字段） | `pt × 20` | 20pt 行距 = `line: 400` |

优先用 `convertMillimetersToTwip()`，不要手写硬编码 twip 值。

## 页面设置

```javascript
const PAGE = {
  size: { width: convertMillimetersToTwip(210), height: convertMillimetersToTwip(297) }, // A4
  margin: {
    top: convertMillimetersToTwip(XX), bottom: convertMillimetersToTwip(XX),
    left: convertMillimetersToTwip(XX), right: convertMillimetersToTwip(XX),
    header: convertMillimetersToTwip(XX),   // 页眉距边界（不是页眉字体大小）
    footer: convertMillimetersToTwip(XX),   // 页脚距边界
  },
};
```

`margin.header/footer` 控制页眉页脚区域的大小，不设则用默认值。

## 固定行距

```javascript
{ line: 20 * 20, lineRule: "exact" }  // 20pt 固定行距
```

**必须同时设 `line` 和 `lineRule`**。缺 `lineRule` 时 Word 将其视为最小行距，内容会撑开行高。多数高校论文要求固定 20pt。标题的 `before/after` 间距单位也是 twip：`before: 800` = 40pt。

## 首行缩进

```javascript
const INDENT = { firstLine: convertMillimetersToTwip(8.47) }; // ≈2字符
```

正文段落加 `indent`，标题不加。

## 奇偶页不同页眉

高校常见要求：单数页=论文题目，双数页=章标题。

1. 每个 section 设 `oddAndEvenHeaders: true`
2. `headers: { default: Header("论文题目"), even: Header("当前章标题") }`
3. 每章作为独立 section，各自的 `even` header 不同

## 页码控制

正文从第一章开始编页码：在该 section 的 page 配置中加 `pageNumbers: { start: 1 }`。封面/摘要的 section 不设此项且不挂 footer = 不显示页码。
