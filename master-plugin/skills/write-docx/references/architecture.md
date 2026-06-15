# Markdown → docx 架构

## 核心思路

**Markdown 作数据源，ESM 脚本解析生成 docx。** 内容改 md，格式改脚本，互不干扰。

```
paper.md ──parsePaper()──▶ [{type, text, ...}] ──buildChildren()──▶ docx.js 对象 ──Packer.toBuffer()──▶ paper.docx
```

优势：论文内容变更只需编辑 Markdown 文件，重新运行脚本即可。格式规范变更只改脚本。内容和排版彻底解耦。

## 解析器设计

### 逐行状态机

`parsePaper(md)` 将 Markdown 拆为结构化元素数组：

```javascript
function parsePaper(md) {
  const lines = md.split(/\n/);
  const elements = [];
  let inTable = false, tHeaders = [], tRows = [], tCaption = null;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line === '') { /* 关闭表格 */ continue; }
    if (line === '---') continue;

    // 标题
    if (line.startsWith('#### ')) { elements.push({ type: 'sub', text: line.slice(5) }); continue; }
    if (line.startsWith('### '))  { elements.push({ type: 'sec', text: line.slice(4) }); continue; }
    if (line.startsWith('## '))   { elements.push({ type: 'ch',  text: line.slice(3) }); continue; }
    if (line.startsWith('# '))    { elements.push({ type: 'title', text: line.slice(2) }); continue; }

    // 图片（下一行作为图注）
    const imgM = line.match(/^!\[([^\]]*)\]\(([^)]+)\)$/);
    if (imgM) { /* ... */ continue; }

    // 表格行
    if (line.startsWith('|')) {
      // 收集表头 → 检测下一行是否为 |---|---| 分隔行（用正则判断，无分隔行则不跳过）
      // ⚠️ 不能无条件跳过表头下一行：无分隔行的表格会丢失第一条数据
      /* 收集 headers/rows */ continue;
    }

    // 显示公式 $$...$$
    if (line.startsWith('$$') && line.endsWith('$$')) { /* ... */ continue; }

    // 列表项（- 或 * 开头）
    if (/^[-*]\s+/.test(line)) { elements.push({ type: 'list', text: line.replace(/^[-*]\s+/, '') }); continue; }

    // 普通段落
    elements.push({ type: 'p', text: line });
  }
  return elements;
}
```

关键：表格用状态机（`inTable` 标记），图片自动取下一行作图注，`---` 分隔符忽略。

⚠️ **表格分隔行必须智能检测**：表头后下一行用正则 `/^\|[\s:|-]*-{2,}[\s:|-]*\|?\s*$/` 判断，匹配才跳过。markdown 表格可省略 `|---|---|` 分隔行，若无条件跳过表头下一行，会把第一条数据行误当 separator 吞掉（实测 STM32、第一项器件等行丢失）。

### 元素类型表

| type | 来源 | 渲染为 |
|------|------|--------|
| `title` | `# ` | 提取论文标题（不直接渲染） |
| `ch` | `## ` | `chapterTitle()` — 黑体三号居中 |
| `sec` | `### ` | `sectionTitle()` — 黑体四号 |
| `sub` | `#### ` | `subTitle()` — 黑体小四 |
| `p` | 普通行 | `bodyPara(parseInline(text))` |
| `eq` | `$$...$$` | `equationPara(pngName, eqNum)` |
| `img` | `![alt](path)` | `insertFigure(fname, caption)` |
| `table` | `\|...\|` | `makeTable(headers, rows, caption)` |
| `list` | `- ` 或 `* ` 开头 | 带左缩进的段落：`bodyPara(parseInline(text), indent=false)` + `indent: { left, hanging }` |

### 内联解析

`parseInline(text)` 处理段落内的混合格式，用 while + 正则逐步匹配：

```javascript
function parseInline(text) {
  const runs = [];
  let rest = text;
  while (rest.length > 0) {
    let m;
    if ((m = rest.match(/^\[(\d+)\]/)))        // [1] 引用下标
      runs.push(r(m[0], { subScript: true }));
    else if ((m = rest.match(/^\*\*(.+?)\*\*/)))  // **bold**
      runs.push(r(m[1], { bold: true }));
    else if ((m = rest.match(/^`([^`]+)`/)))      // `code`
      runs.push(r(m[1], { italics: true }));
    else if ((m = rest.match(/^\$([^$]+)\$/)))    // $inline eq$
      runs.push(...handleInlineEq(m[1]));
    else if ((m = rest.match(/^(.*?)(?=\*\*|`|\$|\[\d+\])/s)))
      runs.push(r(m[1]));                          // 普通文字（到下一个标记为止）
    else { runs.push(r(rest)); rest = ''; }         // 剩余全部
    rest = rest.slice(m[0].length);
  }
  return runs;
}
```

注意 fallback 正则必须包含所有标记类型作为前瞻，否则 `[1]` 等标记会被当普通文字吃掉。

## 章节拆分

按 `## ` 标题将 elements 拆分为 chapters 数组，每章对应一个独立 section：

```javascript
const chapters = [];
let curCh = null;
for (const el of elements) {
  if (el.type === 'ch') {
    if (curCh) chapters.push(curCh);
    curCh = { title: el.text, els: [el] };  // ⚠️ ch 元素也进 els
    continue;
  }
  if (curCh) curCh.els.push(el);
}
if (curCh) chapters.push(curCh);
```

⚠️ **ch 元素必须加入 `els`**，否则 `buildChildren` 的 `case 'ch'` 永远不会触发，正文无章标题。

## 公式预渲染分离

LaTeX → PNG 的渲染管线与 docx 生成完全解耦：

1. `render_equations.mjs` — 批量渲染所有公式为 PNG（独立运行一次）
2. `generate.mjs` — 通过映射表引用 PNG 文件名

```javascript
const DISPLAY_EQS = {
  '1-1': 'eq_1-1.png', '1-2': 'eq_1-2.png', ...
};
const INLINE_EQS = new Map([
  ['g(x,y) = f(x,y) - \\nabla^2 f(x,y)', 'eq_inline_1.png'],
  ...
]);
```

好处：改论文内容不需要重新渲染公式，改公式不需要重新跑整个生成流程。

## 职责分工

| 改什么 | 改哪里 |
|--------|--------|
| 论文标题、摘要、正文、引用 | 只改 `paper.md` |
| 公式内容 | 改 `paper.md` + 重跑 `render_equations.mjs` |
| 图片/实验结果 | 替换 `image_out/` 下的 PNG |
| 字体、字号、行距、页边距 | 改 `generate.mjs` 常量 |
| 页眉页脚、封面布局 | 改 `generate.mjs` 对应函数 |
