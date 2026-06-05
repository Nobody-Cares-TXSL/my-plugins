# 踩坑速查表

| # | 症状 | 原因 | 修复 |
|---|------|------|------|
| 1 | 中文显示为默认字体 | font 只写了字符串 `"宋体"` | 用 `{ ascii, eastAsia, hAnsi }` 三字段对象 |
| 2 | 行距忽大忽小 | 只设了 `line`，缺 lineRule | 加 `lineRule: "exact"` |
| 3 | 正文没有首行缩进 | 段落没设 indent | 加 `indent: { firstLine: ... }` |
| 4 | 表格完全无边框 | docx.js 默认无边框 | 手动设 borders（三线表方案） |
| 5 | 表格边框太密 | 给每个 cell 加了四边框 | 只给表头加上下线、末行加底线 |
| 6 | 图片变形 | 硬编码 width/height | 读 PNG 元数据等比缩放 |
| 7 | 图片不显示 | ImageRun 缺少 type | 加 `type: "png"` |
| 8 | `split("\\n")` 返回空数组 | JS 字符串 `"\\n"` 是两个字符 `\` + `n`，不是换行符 | 用 `split(/\n+/)` 正则按真实换行分割 |
| 9 | 数字显示 `81.58666666666667%` | 浮点数未格式化 | 所有数字用 `.toFixed(2)` 或 `.toFixed(4)` |
| 10 | 封面信息上下对不齐 | 用普通段落拼凑 | 用 Table + 固定宽 TableCell + HeightRule.EXACT |
| 11 | 图注没紧跟图片 | 图片和图注分开插入，中间被其他内容隔开 | `insertFigure` 返回数组，展开一起插入 |
| 12 | 全局默认字体不生效 | Document 构造时没设 styles | 设 `styles: { default: { document: { run: { font: ... } } } }` |
| 13 | 标题也缩进了 | bodyPara 的 indent 用在了标题上 | 标题段落不加 indent |
| 14 | 表格内容左对齐 | cell 段落缺 alignment | Paragraph 加 `alignment: AlignmentType.CENTER` |
| 15 | 页面尺寸不对 | 用了硬编码 twip 值 | 用 `convertMillimetersToTwip()` 转换 |
| 16 | puppeteer 截图公式被水平压缩 | `page.screenshot()` API 有渲染 bug，deviceScaleFactor 无效 | 用 Chrome 原生 `--headless --screenshot` 命令行截图 |
| 17 | 模板字符串中 JS 表达式没被求值 | 反引号内写了 `' + expr + '`，这是字面文本 | 用 `${expr}` 模板插值 |
| 18 | 图片路径被重复拼接 | `loadPng(join(EQ_DIR, name))` 但 loadPng 内部又 `join(IMAGES, name)` | loadPng 只接受文件名，或直接用 `readFileSync(join(EQ_DIR, name))` |
| 19 | 正则匹配 LaTeX `\\` 失败 | JS 正则中 `\\\\` 匹配一个 `\`，不是 `\\`。要匹配两个反斜杠需要 `/\\\\/g` | 用 Node 脚本打印验证：`console.log(/\\\\/g.test("\\\\"))` |
| 20 | Chrome 截图大量空白 | 截取整个视口但公式只占一小块 | ImageMagick `convert -trim +repage -bordercolor white -border 16x16` |
| 21 | bmatrix 小矩阵方括号太小 | KaTeX 的 `\begin{bmatrix}` 不自动扩展方括号 | 用 `\left[\vphantom{\frac{0}{0}}\begin{array}{cc}...\end{array}\right]`，自动检测列数 |
