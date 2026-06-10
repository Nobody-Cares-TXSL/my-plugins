# 快速上手：项目初始化与工作流

## 1. 初始化

```bash
mkdir wordgen && cd wordgen
npm init -y && npm install docx katex
# 系统依赖：google-chrome（公式渲染）、convert/ImageMagick（裁白边）

# 检查环境
node -e "require('docx'); console.log('docx ✓')"   # docx 已安装
google-chrome --version                                 # Chrome 已安装
convert --version                                      # ImageMagick 已安装
```

## 2. 目录结构

```
wordgen/
├── generate.mjs          # 主脚本：解析 paper.md → 生成 paper.docx
├── render_equations.mjs  # 公式渲染：LaTeX → KaTeX+Chrome → PNG
├── paper.md             # 论文内容（Markdown 格式）
└── image_out/
    ├── result_exp1.png  # 实验结果图片
    ├── result_exp2.png
    └── equations/        # 预渲染的公式 PNG
        ├── eq_1-1.png
        └── eq_inline_1.png
```

## 3. 运行生成

```bash
# 渲染公式（LaTeX 有变化时才需要重跑）
node render_equations.mjs

# 生成 Word 文档（paper.md 或脚本格式有变化时重跑）
node generate.mjs
```

## 4. 修改论文

- **改内容** → 编辑 `paper.md`，重跑 `node generate.mjs`
- **改格式**（字体、行距、页眉等）→ 编辑 `generate.mjs` 常量，重跑
- **改公式** → 编辑 `paper.md` 中的 LaTeX，重跑 `render_equations.mjs` + `node generate.mjs`
- **换图片** → 替换 `image_out/` 下的文件，重跑 `node generate.mjs`
