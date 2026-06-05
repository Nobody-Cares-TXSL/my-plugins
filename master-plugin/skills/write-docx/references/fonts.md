# 中文字体

## 问题

`font: "宋体"` 对中文不生效，Word 中中文仍显示为默认字体。

## 原因

docx.js 的 font 字段区分三个字符域。Word 渲染中文时读 `eastAsia` 字段，只传字符串时所有域都用该值，但 Word 对 CJK 字符的字体查找走的是另一条路径，可能被覆盖。

## 技巧：三字段字体对象

```javascript
const FONT_SONG = { ascii: "Times New Roman", eastAsia: "宋体", hAnsi: "Times New Roman" };
const FONT_HEI  = { ascii: "Times New Roman", eastAsia: "黑体", hAnsi: "Times New Roman" };
```

封装后通过参数切换：

```javascript
function r(text, { font = FONT_SONG, size = 24, bold = false } = {}) {
  return new TextRun({ text, font, size, bold });
}
r("正文");                          // 宋体
r("标题", { font: FONT_HEI, size: 32, bold: true }); // 黑体
```

字号换算：`pt × 2 = half-pt`。如三号 16pt = size: 32，小四 12pt = size: 24，五号 10.5pt ≈ size: 21。

## 要点

- **凡是含中文的 TextRun，必须用三字段对象。** 这是 docx.js + Word 的必坑。
- `ascii` / `hAnsi` 一般设为英文字体（Times New Roman），`eastAsia` 设中文字体。
- Document 的 `styles.default.document.run.font` 也要设三字段对象，否则全局默认字体对中文不生效。
