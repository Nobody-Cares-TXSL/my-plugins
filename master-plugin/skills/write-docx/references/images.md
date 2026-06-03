# 图片插入

## 问题

硬编码 width/height 导致图片变形或显示不全。不同图片原始尺寸不同，统一写死一个尺寸必然出错。

## 方案：读 PNG 元数据等比缩放

### 读取 PNG 尺寸

PNG 文件的宽度存储在 offset 16（4 bytes，big-endian），高度在 offset 20：

```javascript
function imageSize(buf) {
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20),
  };
}
```

### 按目标毫米宽度等比缩放

```javascript
function insertFigure(pngName, caption, widthMm = 140) {
  const buf = loadPng(pngName);
  const sz = imageSize(buf);
  const w = Math.round(widthMm / 25.4 * 96);           // mm → px (96 DPI)
  const h = Math.round(w * (sz.height / sz.width));     // 等比缩放
  return [
    new Paragraph({
      children: [new ImageRun({
        data: buf,
        transformation: { width: w, height: h },
        type: "png",  // 必须指定
      })],
      alignment: AlignmentType.CENTER,
      spacing: { before: 120, after: 60 },
    }),
    figCap(caption),
  ];
}
```

### 图注

```javascript
function figCap(text) {
  return new Paragraph({
    children: [new TextRun({ text, font: FONT_HEI, size: 21 })],
    alignment: AlignmentType.CENTER,
    spacing: { line: 20 * 20, lineRule: "exact" },
  });
}
```

## 关键细节

| 要点 | 说明 |
|------|------|
| `type: "png"` | ImageRun 必须指定图片类型，省略会导致渲染失败 |
| 96 DPI | `widthMm / 25.4 * 96` 将毫米转为像素（屏幕 DPI） |
| 返回数组 | `insertFigure` 返回 `[图片段落, 图注段落]`，展开插入 |

## 加载图片

```javascript
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import { existsSync, readFileSync } from "fs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIGURES = resolve(__dirname, "figures");

function loadPng(name) {
  const p = resolve(FIGURES, name);
  if (!existsSync(p)) throw new Error(`图片不存在: ${p}`);
  return readFileSync(p);
}
```

## 用法

```javascript
// 在正文 children 数组中展开插入
contentChildren.push(
  bodyPara("图3-1展示了数据集样本..."),
  ...insertFigure("samples.png", "图3-1 数据集样本展示", 145),
);
```

`widthMm = 145` 表示图片在 Word 中显示为 14.5cm 宽，高度按原始比例自动计算。
