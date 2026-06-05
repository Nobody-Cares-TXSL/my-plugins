# 图片

## 问题

硬编码 width/height 导致变形。不同图片尺寸不同，统一写死必然出错。

## 技巧：读 PNG 元数据等比缩放

PNG 尺寸存在文件头固定偏移处：

```javascript
function imageSize(buf) {
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}
```

按目标宽度等比缩放：

```javascript
function insertFigure(buf, caption, widthMm = 140) {
  const sz = imageSize(buf);
  const w = Math.round(widthMm / 25.4 * 96);          // mm → px (96 DPI)
  const h = Math.round(w * (sz.height / sz.width));    // 等比
  return [
    new Paragraph({
      children: [new ImageRun({ data: buf, transformation: { width: w, height: h }, type: "png" })],
      alignment: AlignmentType.CENTER,
    }),
    new Paragraph({ children: [r(caption, { font: FONT_HEI, size: 21 })], alignment: AlignmentType.CENTER }),
  ];
}
```

要点：`type: "png"` 不能省，否则渲染失败。

## 图片来源

如果图片是外部生成的（如截图、实验结果），建议统一放到一个目录（如 `image_out/`），脚本中用绝对路径引用：

```javascript
const IMAGES = resolve(import.meta.dirname, "..", "image_out");
const buf = readFileSync(join(IMAGES, "result.png"));
```

## 图注

图注用黑体/五号，居中，紧跟图片后面。让 `insertFigure` 返回数组 `[图片段落, 图注段落]`，在 children 中一起展开插入，防止被其他内容隔开。
