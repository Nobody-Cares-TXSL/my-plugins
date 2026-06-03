# 中文字体设置

## 问题

只写 `font: "宋体"` 时，中文内容会用默认字体（小明体或 Calibri），**不生效**。

## 原因

docx.js 的 font 字段区分三种字符域，只传字符串时默认所有域都用该字体，但 Word 实际渲染中文时优先读 `eastAsia` 字段。

## 方案

```javascript
const FONT_SONG = { ascii: "Times New Roman", eastAsia: "宋体", hAnsi: "Times New Roman" };
const FONT_HEI  = { ascii: "Times New Roman", eastAsia: "黑体", hAnsi: "Times New Roman" };
// FONT_SONG 同时用作默认字体和 Document styles.default，无需单独定义 FONT_TNR
```

| 字段 | 作用 | 典型值 |
|------|------|--------|
| ascii | 英文/数字 | Times New Roman |
| eastAsia | 中日韩字符 | 宋体 / 黑体 |
| hAnsi | 西欧扩展字符 | Times New Roman |

## 规则

**凡是包含中文的 TextRun，必须用三字段字体对象。**

```javascript
// ❌ 中文会显示为默认字体
new TextRun({ text: "第一章 绪论", font: "黑体", size: 32, bold: true })

// ✅ 正确
new TextRun({ text: "第一章 绪论", font: FONT_HEI, size: 32, bold: true })
```

## 封装函数

```javascript
function r(text, { font = FONT_SONG, size = 24, bold = false } = {}) {
  return new TextRun({ text, font, size, bold });
}
```

调用时通过参数切换字体：

```javascript
r("正文内容")                                        // 默认宋体
r("一级标题", { font: FONT_HEI, size: 32, bold: true })  // 黑体
```

## 高校模板常见字体规范

| 位置 | 中文字体 | 英文字体 | 字号 |
|------|---------|---------|------|
| 正文 | 宋体 | Times New Roman | 小四 (12pt = 24 half-pt) |
| 一级标题 | 黑体 | Times New Roman | 三号 (16pt = 32) |
| 二级标题 | 黑体 | Times New Roman | 小三 (15pt ≈ 28) |
| 图注 | 黑体 | Times New Roman | 五号 (10.5pt ≈ 21) |
| 表格内容 | 宋体 | Times New Roman | 五号 |
