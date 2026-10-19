---
name: auto_answer
description: 基于 opencli browser 的自动答题技能。绑定浏览器标签页，读取题目，完成选择题、判断题、填空题的作答。
argument-hint: [会话名，默认 auto]
allowed-tools:
  - Bash
  - Read
---

# auto_answer — 自动答题

通过 opencli browser 操作浏览器，读取在线考试/练习题目并自动作答。
所有浏览器交互都走 `scripts/aa.sh`，**不要手写内联 JS**（长内联 JS 的引号/换行转义极易出错）。

## 前置检查

```bash
scripts/aa.sh doctor
```

确保 `[OK] Extension: connected`。未连接则 `opencli daemon restart` 后重试；仍失败则提示用户安装扩展。

> `aa.sh` 会自动把 NVM 的 node bin 目录补进 PATH，无需手动 export。

## 执行流程

### Step 1: 绑定标签页

会话名走环境变量 `AA_SESSION`（默认 `auto`）：

```bash
export AA_SESSION=auto
scripts/aa.sh bind
```

确认绑定的 URL 包含 `exam`/`quiz`/`test` 关键词。若绑到空白页，提示用户在浏览器中打开答题页后重试。

> 多标签时 `open` 与 `bind` 可能不是同一个标签。用 `opencli browser $AA_SESSION tab list` 取 `page` id，再 `export AA_TAB=<page id>` 精确指定。

### Step 2: 处理弹窗

```bash
scripts/aa.sh hide-dialogs
```

若页面有"开始"按钮且考试尚未开始计时，提示用户手动点击"开始"（部分平台需要手机验证码等二次确认）。

### Step 3: 读取全部题目

```bash
scripts/aa.sh read-questions
```

输出 JSON：`{ root, total, items[] }`，每题含 `q`（题号）、`type`（`single`/`multi`/`judge`/`fill`）、`title`、`options[]`、`fillCount`、`ctx`。

`type` 判定顺序：有填空 input → `fill`；有 checkbox → `multi`；选项 value 是 `true`/`false` → `judge`；否则 `single`。

> 题目可能在同源 iframe 内（`root` 字段会指出位置），脚本已自动探测。若 `total` 为 0，检查页面是否已交卷或需先点"开始"。

### Step 4: 分析答案

逐题分析后写两个 JSON 文件：

```json
// choice.json —— 单选/多选/判断题
{
  "choice": { "4": ["A", "C", "D"], "5": ["D"] },
  "judge":  { "2": "false", "3": "true" }
}

// fill.json —— 填空题（题号 → 该题各空答案，按空位顺序）
{ "fill": { "1": ["-1", "mid"], "11": ["O(nlog n)", "O(n)"] } }
```

- `choice` 的值可以是**选项标号**（`"A"`）或**选项文本**（按包含匹配）
- `judge` 的值是 `"true"`/`"false"`
- 填空答案若含 `"` 或 `\`，JSON 序列化会正确处理，无需手动转义

### Step 5: 作答

```bash
scripts/aa.sh answer-choice choice.json
scripts/aa.sh answer-fill   fill.json
```

**两者必须分开执行**，不要合并——填空题有独立的串行写入逻辑（见下）。

#### 填空题为什么必须逐空串行

平台（实测雨课堂）的填空题组件在每次 `input` 事件后异步重渲染，用组件内部保存的值 patch DOM。若在同一题内连续写多个空，**先写的空会被回滚**（回滚成上一次已保存的值，而非清空）。

`answer_fill.js` 已内置正确策略，无需你处理：
- 逐空串行，每空之间 `sleep(700)` 等重渲染结束
- 写后**重新 `querySelectorAll`** 取存活节点再验证，通过后才写下一个空
- 用原生 setter 绕过 Vue 属性代理
- 失败重试最多 3 次，逐空记日志

### Step 6: 验证

```bash
scripts/aa.sh verify
```

输出 `{ total, unanswered[], partialFills[], report[] }`。
- `unanswered` 非空 → 选择题有遗漏
- `partialFills` 非空 → 填空题有空位未填

补答：修改 JSON 后重跑 Step 5 对应命令（脚本幂等，已选中的不会重复点击）。

## 关键技术规则

脚本已内置以下防护，了解即可：

| 规则 | 原因 |
|------|------|
| 不用 `click <ref>` | 页面重渲染后 refs 全部过期 |
| 用 `label.dispatchEvent(MouseEvent)` 而非 `radio.click()` | 对 `tabindex=-1` 的隐藏 input 无效 |
| 按**可见标号**匹配选项，不信 `input.value` | 雨课堂的可见标号与 value 错位（反自动化） |
| 判断题按 `input.value` 的 `true`/`false` 匹配 | 判断题选项无文字，仅有 √/× 图标 |
| 题号用 `.subject-item` 过滤后顺序推导 | 填空题没有 h4，且导航面板也是 `.subject-item` |
| 填空题逐空串行 + 原生 setter | 批量写会被重渲染回滚；Vue 代理拦截直接赋值 |

### 逃生口

临时脚本（如主观题、特殊页面）用：

```bash
scripts/aa.sh eval /path/to/tmp.js    # 执行 JS 文件
scripts/aa.sh raw 'location.href'      # 直接透传 JS 字符串（短表达式）
```

`eval` 会先拼上 `js/_common.js`（提供 `window.__aa`：`pickRoot`/`items`/`qType`/`visText`/`clickFull`/`queryAll`），可复用这些工具。

### 弹窗与开始按钮

考试页面常见弹窗：考试须知、开始确认、交卷确认。统一用 `hide-dialogs` 隐藏（`[role=dialog]` 的 `display: none`）。

需要点击"开始"才能进入答题时，用文本匹配：
```javascript
// 经 aa.sh eval 或 raw 执行
document.querySelectorAll('button, span').forEach(el => {
  if (el.textContent.trim() === '开始') el.click();
});
```

## 注意事项

- 本技能提供答题框架，实际答案需要 Claude 根据题目内容分析得出
- 对于专业性强的题目（如微机原理、医学等），Claude 可能给出错误答案
- 用户应在答题完成后检查一遍，尤其是专业课
- 填空题答案可能有多种正确表述，平台可能不接受同义词
- **题目可能是图片**（PPT 背景图）：DOM 里无文字时，从 `.pptimg[data-background]` 取图片 URL 下载后视觉识别
- **不可逆页面要停下确认**：页面若提示"仅一次提交机会"，填完后必须停下等用户确认，不要自动交卷
