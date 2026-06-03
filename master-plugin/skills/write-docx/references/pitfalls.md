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
