# 公式

> 完整代码见 `boilerplate.mjs.txt`（`equationPara` 函数），本文件只记录渲染管线和独有知识。

## 问题

docx.js 没有内置 LaTeX 渲染能力。公式必须预渲染为 PNG 再插入。

## 渲染管线

```
LaTeX → KaTeX 渲染为 HTML → Chrome --headless --screenshot → ImageMagick trim → PNG
```

### 为什么不用 puppeteer 截图 API

puppeteer 的 `page.screenshot()` 会导致**水平方向压缩**（右半部分被挤在一起），调整 `deviceScaleFactor`/`viewport` 都无法修复。Chrome 原生 `--headless --screenshot` 命令行输出正确。

### 执行命令

```javascript
import { execSync } from "node:child_process";
import { writeFileSync } from "node:fs";

const html = buildKatexHtml(tex, displayMode);
writeFileSync("/tmp/eq.html", html);
execSync(
  `google-chrome --headless --disable-gpu --screenshot="${outPng}" --window-size=1280,400 /tmp/eq.html`,
  { stdio: "pipe" }
);

// 裁白边 + 加 padding
execSync(
  `convert "${outPng}" -trim +repage -bordercolor white -border 16x16 "${outPng}"`,
  { stdio: "pipe" }
);
```

依赖：`katex`（npm）、`google-chrome`（系统）、`convert`（ImageMagick）。

### KaTeX HTML 模板要点

`JSON.stringify(tex)` 防止 LaTeX 中的反斜杠/引号被注入 HTML。`throwOnError: false` 防止渲染失败中断。

### ImageMagick trim

Chrome 截取整个视口（1280×400），公式只占中间一小块。`-trim +repage` 裁掉白边，`-border 16x16` 加四周 padding 防贴边。

## bmatrix 方括号自动扩展

KaTeX 的 `\begin{bmatrix}` 对小矩阵不自动扩展方括号。替换为 `\left[...\right]` + `\vphantom`：

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

注意：模板字符串中必须用 `${colSpec}` 插值，不能用 `' + 'c'.repeat(cols) + '`（这是字面文本）。

## 行内公式

复杂行内公式用预渲染图片（高度与正文行高匹配），简单变量用 TextRun 斜体+下标近似：

```javascript
// 复杂：预渲染图片
const targetH = 20; // px
const w = Math.round(sz.width * targetH / sz.height);
runs.push(new ImageRun({ data: buf, transformation: { width: w, height: targetH }, type: "png" }));

// 简单：TextRun（如 $S_\eta$）
function simpleInlineMath(tex) {
  const m = tex.match(/^([A-Za-z])_\\?(\w+)$/);
  if (m) return [r(m[1], { italics: true }), r(m[2], { italics: true, subScript: true })];
  return [r(tex, { italics: true })];
}
```

## 公式序号提取

Markdown 中的 `$$... \quad (1-1)$$` 提取序号：

```javascript
const m = tex.match(/\\quad\s*\((\d+-\d+)\)\s*$/);
const eqNum = m ? m[1] : null;  // "1-1"
```
