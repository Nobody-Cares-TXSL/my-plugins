# 图片

> 完整代码见 `boilerplate.mjs.txt`，本文件只记录原理和要点。

## PNG 元数据读取原理

PNG 尺寸存在文件头的固定偏移处：宽度在偏移 16（4 字节 BE uint32），高度在偏移 20。所以 `buf.readUInt32BE(16)` / `buf.readUInt32BE(20)` 可以零依赖获取原始像素尺寸。

## 等比缩放

```javascript
const w = Math.round(widthMm / 25.4 * 96);       // mm → px (96 DPI)
const h = Math.round(w * (srcHeight / srcWidth));  // 等比
```

25.4 mm = 1 inch，96 DPI 是 Word 默认渲染分辨率。用目标宽度算出像素宽度，再按原始宽高比算高度。

## type 字段不能省

`ImageRun` 的 `type: "png"` 必须显式指定，否则 docx.js 渲染失败（图片不显示）。

## 图片来源管理

外部图片（截图、实验结果等）建议统一放一个目录：

```javascript
const IMAGES = resolve(import.meta.dirname, "..", "image_out");
const buf = readFileSync(join(IMAGES, "result.png"));
```

## 图注紧跟图片

`insertFigure` 返回数组 `[图片段落, 图注段落]`，在 children 中展开插入：

```javascript
children: [
  ...前文内容,
  ...insertFigure(buf, "图 1-1 xxx"),  // 展开为 [图片, 图注]
  ...后文内容,
]
```

这样图片和图注不会被其他内容隔开。图注用黑体五号（`size: 21`），居中。
