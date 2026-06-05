# 公式

## 问题

docx.js 没有内置 LaTeX 渲染能力。

## 方案：预渲染为 PNG 插入

将公式渲染管线与 docx 生成解耦：先批量渲染所有公式为 PNG，再在生成 docx 时作为 ImageRun 插入。

### 渲染管线

```
LaTeX → KaTeX 渲染为 HTML → Chrome --headless --screenshot → ImageMagick trim → PNG
```

为什么用 Chrome 命令行而非 puppeteer 的 `page.screenshot()`：puppeteer 的截图 API 会导致**水平方向压缩**（右半部分被挤在一起），调整 deviceScaleFactor/viewport 都无法修复。Chrome 原生 `--headless --screenshot` 输出正确。

```javascript
import { execSync } from "node:child_process";
import { writeFileSync } from "node:fs";

// 生成 HTML 并截图
const html = buildKatexHtml(tex, displayMode);
writeFileSync("/tmp/eq.html", html);
execSync(
  `google-chrome --headless --disable-gpu --screenshot="${outPng}" --window-size=1280,400 /tmp/eq.html`,
  { stdio: "pipe" }
);

// 裁白边
execSync(
  `convert "${outPng}" -trim +repage -bordercolor white -border 16x16 "${outPng}"`,
  { stdio: "pipe" }
);
```

依赖：`katex`（npm）、`google-chrome`（系统）、`convert`（ImageMagick）。

### KaTeX HTML 模板要点

```javascript
const html = `<!DOCTYPE html><html><head><meta charset="UTF-8">
<style>${katexCss}
body { margin:0; padding:40px; background:white; text-align:center; }
.katex { font-size:1.3em; }
</style></head><body>
<div class="${display ? "katex-display" : "katex"}" id="eq"></div>
<script>${katexJs}
katex.render(${JSON.stringify(tex)}, document.getElementById("eq"),
  { displayMode: ${display}, throwOnError: false });
</script></body></html>`;
```

`JSON.stringify(tex)` 防止 LaTeX 中的反斜杠/引号被注入 HTML。`throwOnError: false` 防止渲染失败中断。

### ImageMagick trim

Chrome 截取整个视口（1280×400），公式只占中间一小块。`-trim +repage` 裁掉白边，`-border 16x16` 加四周 padding 防贴边。

## bmatrix 方括号自动扩展

KaTeX 的 `\begin{bmatrix}` 对小矩阵不自动扩展方括号。替换为 `\left[...\right]` + `\vphantom` 使方括号扩展到足够高度：

```javascript
function fixBmatrix(tex) {
  return tex.replace(
    /\\begin\{bmatrix\}([\s\S]*?)\\end\{bmatrix\}/g,
    (_, content) => {
      const cols = content.split("\\\\")[0].split("&").length;
      const colSpec = "c".repeat(cols);
      return `\\left[\\vphantom{\\frac{0}{0}}\\begin{array}{${colSpec}}${content}\\end{array}\\right]`;
    }
  );
}
```

注意：必须在模板字符串中用 `${colSpec}` 插值，不能用 `' + 'c'.repeat(cols) + '`（这是字面文本）。

## 在 Word 中插入

### 显示公式：居中 + 右对齐序号

用无边框两列表格实现：

```javascript
function equationPara(pngBuf, w, h, eqNum) {
  const NONE_B = { style: BorderStyle.NONE, size: 0, color: "FFFFFF" };
  const borders = { top: NONE_B, bottom: NONE_B, left: NONE_B, right: NONE_B };
  return new Table({
    rows: [new TableRow({
      children: [
        new TableCell({
          children: [new Paragraph({
            children: [new ImageRun({ data: pngBuf, transformation: { width: w, height: h }, type: "png" })],
            alignment: AlignmentType.CENTER,
          })],
          width: { size: 5800, type: WidthType.DXA }, borders,
          verticalAlign: VerticalAlign.CENTER,
        }),
        new TableCell({
          children: [new Paragraph({
            children: [new TextRun({ text: `(${eqNum})` })],
            alignment: AlignmentType.RIGHT,
          })],
          width: { size: 1200, type: WidthType.DXA }, borders,
          verticalAlign: VerticalAlign.CENTER,
        }),
      ],
    })],
    width: { size: 7000, type: WidthType.DXA },
  });
}
```

### 行内公式

复杂行内公式用预渲染图片，简单变量用 TextRun 斜体+下标近似：

```javascript
// 复杂：预渲染图片（高度与正文行高匹配）
const targetH = 20; // px
const w = Math.round(sz.width * targetH / sz.height);
runs.push(new ImageRun({ data: buf, transformation: { width: w, height: targetH }, type: "png" }));

// 简单：TextRun（如 $S_\eta$）
function simpleInlineMath(tex) {
  const m = tex.match(/^([A-Za-z])_\\?(\w+)$/);
  if (m) return [
    r(m[1], { italics: true }),
    r(m[2], { italics: true, subScript: true }),
  ];
  return [r(tex, { italics: true })];
}
```

### 公式序号提取

Markdown 中的 `$$... \quad (1-1)$$` 提取序号：

```javascript
const m = tex.match(/\\quad\s*\((\d+-\d+)\)\s*$/);
const eqNum = m ? m[1] : null;  // "1-1"
```
