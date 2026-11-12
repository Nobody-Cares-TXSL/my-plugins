---
name: auto-answer
description: 基于 opencli browser 的自动答题技能。绑定浏览器标签页，读取题目，完成选择题、判断题、填空题的作答。
argument-hint: [会话名，默认 auto]
allowed-tools: Bash Read
---

# auto-answer — 自动答题

通过 opencli browser 操作浏览器，读取在线考试/练习题目并自动作答。
所有浏览器交互都走 `${CLAUDE_SKILL_DIR}/scripts/aa.sh`，**不要手写内联 JS**（长内联 JS 的引号/换行转义极易出错）。

## 前置检查

```bash
${CLAUDE_SKILL_DIR}/scripts/aa.sh doctor
```

输出是 JSON，看 `data.extensionConnected` 为 `true`。未连接则 `opencli daemon restart` 后重试；仍失败则提示用户安装扩展。

> 输出里若提示扩展版本过旧（`does not report command journal support`），不影响答题，但 `opencli browser chrome call` 这类原生标签管理接口会超时，别用它。

> `aa.sh` 会自动把 NVM 的 node bin 目录补进 PATH，无需手动 export。

## 执行流程

### Step 1: 绑定标签页

**`bind` 绑的是"当前聚焦"的 Chrome 标签**（`bind --help` 原文：Bind the *current* Chrome tab），不是会话自己的标签。浏览器里随便哪个标签在前台，就会绑到那个上面去。所以优先用**自己创建**的标签：

```bash
export AA_SESSION=auto
# 1) 建一个会话自有的标签，记下返回的 page id
opencli browser --session "$AA_SESSION" tab new 'https://changjiang.yuketang.cn/v2/web/index'
# 2) 用 AA_TAB 精确指定，后续所有命令都带 --tab
export AA_TAB=<上一步返回的 page id>
```

拿到 `AA_TAB` 后，`aa.sh` 会自动给 `eval` 加 `--tab`，不用再 `bind`。

只有当目标标签**确实是当前前台页**时，`bind` 才可靠：

```bash
${CLAUDE_SKILL_DIR}/scripts/aa.sh bind
```

绑完确认 URL 含 `exam`/`quiz`/`test`。绑到空白页或别的不相干站点，就是被前台标签抢走了，改用上面的 `tab new` 路径。

> 命令写法是 `opencli browser --session <名> ...`，会话名走 `--session` 选项，**不能**写成 `opencli browser <名> ...`（会被当成子命令，报 `unknown command`）。

### Step 2: 处理弹窗

```bash
${CLAUDE_SKILL_DIR}/scripts/aa.sh hide-dialogs
```

若页面有"开始"按钮且考试尚未开始计时，提示用户手动点击"开始"（部分平台需要手机验证码等二次确认）。

### Step 3: 读取全部题目

```bash
${CLAUDE_SKILL_DIR}/scripts/aa.sh read-questions
```

输出 JSON：`{ root, total, items[] }`，每题含 `q`（题号）、`type`（`single`/`multi`/`judge`/`fill`）、`title`、`options[]`、`fillCount`、`ctx`。

`type` 判定顺序：有填空 input → `fill`；有 checkbox → `multi`；选项 value 是 `true`/`false` → `judge`；否则 `single`。

> 题目可能在同源 iframe 内（`root` 字段会指出位置），脚本已自动探测。
>
> `total` 为 0 时按这个顺序排查，**别急着认定结构不匹配**：
> 1. **页面还没渲染完** —— 最常见。新考试系统是 SPA，路由切换后题目异步挂载；`read-questions` 已内置最多 15s 轮询守卫，若仍为 0 再往下查。
> 2. 需要先点"开始"进入答题（见下节）。
> 3. 已交卷 / 只读回顾态。
> 4. DOM 结构确实不同 —— 用 `aa.sh eval` 跑一段探测脚本，看题目的实际 class。改 `_common.js` 的 `items()` 时注意嵌套：新考试系统是 `.subject-item` 包裹 `.exercise-item`，两者都带 h4，合并选择器会让每题计两次。

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
${CLAUDE_SKILL_DIR}/scripts/aa.sh answer-choice choice.json
${CLAUDE_SKILL_DIR}/scripts/aa.sh answer-fill   fill.json
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
${CLAUDE_SKILL_DIR}/scripts/aa.sh verify
```

输出 `{ total, unanswered[], partialFills[], report[] }`。
- `unanswered` 非空 → 选择题有遗漏
- `partialFills` 非空 → 填空题有空位未填

`report[].checked[]` 每项含 `letter` / `label` / `rawValue`：
- **看 `letter` 或 `label`，别看 `rawValue`**。雨课堂系平台的 `input.value` 与可见标号错位，`rawValue` 只用于排查。
- 判断题无可见标号，`letter` 为空，看 `rawValue` 的 `true`/`false`。

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
${CLAUDE_SKILL_DIR}/scripts/aa.sh eval /path/to/tmp.js    # 执行 JS 文件
${CLAUDE_SKILL_DIR}/scripts/aa.sh raw 'location.href'      # 直接透传 JS 字符串（短表达式）
```

`eval` 会先拼上 `js/_common.js`（提供 `window.__aa`：`pickRoot`/`items`/`qType`/`visText`/`clickFull`/`queryAll`），可复用这些工具。

### 标签页可见性与租约

两个容易卡住的约束：

- **CDP 真实点击要求标签可见**。`opencli browser click <css>` 是走 CDP 的原生输入，标签在后台时直接报 `Native input requires a visible browser page`，输入不会派发。此时切到该标签（或在带 `--window foreground` 的会话里操作）再点。
- **会话绑在用户自有标签上时，不能 `tab new`/`tab select`/`tab close`**，会报 `bound_tab_mutation_blocked`。租约保护：用户标签只能读不能改。要管理标签就换成会话自有的 `tab new` 创建的标签。

> `label.dispatchEvent(new MouseEvent('click'))` 不受可见性限制，所以 `answer-choice`/`answer-fill` 用合成事件，在后台标签也能跑；只有需要真实点击（如"开始答题"）时才受上面的约束。

### 弹窗与开始按钮

考试页面常见弹窗：考试须知、开始确认、交卷确认。统一用 `hide-dialogs` 隐藏（`[role=dialog]` 的 `display: none`）。

需要点击"开始"才能进入答题时，用文本匹配：
```javascript
// 经 aa.sh eval 或 raw 执行
document.querySelectorAll('button, span').forEach(el => {
  if (el.textContent.trim() === '开始') el.click();
});
```

#### 新考试系统（changjiang-exam.yuketang.cn）的进入路径

课程页的"开始答题"在 Vue 里是 `jumpToExam()`，内部走 `window.open` 开新标签，**会被弹窗拦截器吞掉**，点多少次页面都没反应。正确做法是拿路由 href 直接导航：

```javascript
// 1) 在课程考试封面页执行，取 exam-trans 路由
function vueOf(el) { let c = el; while (c) { if (c.__vue__) return c.__vue__; c = c.parentElement; } return null; }
let v = vueOf(document.querySelector('.btn-quiz'));
while (v && !(v.$router && v.$options.methods && v.$options.methods.jumpToExam)) v = v.$parent;
const href = v.$router.resolve({
  name: 'exam-trans',
  params: { cid: v.classroomid, eid: v.examid },
  query: Object.assign({}, v.$route.query, { status: 0, isFrom: 2 })
}).href;   // 形如 /v2/web/trans/<cid>/<eid>?...
```
```bash
# 2) 拼上站点根域名导航过去，会落到 /start/<eid>，点"开始"后进入 /exam/<eid>
opencli browser --session "$AA_SESSION" open "https://changjiang.yuketang.cn$href" --tab "$AA_TAB"
```

进去后 DOM 是 `.subject-item` **包裹** `.exercise-item` 的嵌套结构，两者都带 h4、都指向同一道题。`items()` 只取外层 `.subject-item`，**不要**把两个选择器合并（会每题计两次，30 题变 60）。选项标号与 `input.value` 同样错位。

> 该页题目有时被第三方答题插件注入 `(✓)` 正确答案（纯文本节点，不是 DOM 元素，`<script src>` 查不到）。可作参考，但**必须逐题用自己的知识复核**；判断题通常没有标记。

### iframe 内的考试页（主观题 / 手写题）

部分考试（如雨课堂主观题）整页渲染在同源 iframe 里（`src` 形如 `/v/quiz/quiz_result/<id>/`），主文档只有导航栏。此时：

- **按钮点击**（继续答题 / 作答 / 去交卷 / 交卷 / 确认）必须在 `iframe.contentDocument` 内查找：
  ```javascript
  const d = document.querySelector('iframe').contentDocument;
  const b = [...d.querySelectorAll('button,span,div,a')]
    .find(e => e.textContent.trim() === '作答');
  b.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
  ```
- **题目内容**：主观题题目通常是 PPT 图片，从 `iframe.contentWindow.quizData.Slides[].Shapes[].URL` 取图片地址下载后识别。
- **附件上传**：`opencli upload` 不穿透 iframe，用专用子命令：
  ```bash
  ${CLAUDE_SKILL_DIR}/scripts/aa.sh upload-attachment /path/to/answer.jpg
  ```
  脚本自动 base64 分块注入（绕过 argv 长度上限），优先选 iframe 内的 `input[type=file]`，触发 `change` 后页面显示文件名即成功。
- **标签页丢失**：会话标签可能被其他操作切成 `about:blank`，关键步骤前用 `${CLAUDE_SKILL_DIR}/scripts/aa.sh ensure` 自动重绑（`read-questions`/`answer-*`/`verify`/`upload-attachment` 已内置该守卫）。

## 注意事项

- 本技能提供答题框架，实际答案需要 Claude 根据题目内容分析得出
- 对于专业性强的题目（如微机原理、医学等），Claude 可能给出错误答案
- 用户应在答题完成后检查一遍，尤其是专业课
- 填空题答案可能有多种正确表述，平台可能不接受同义词
- **题目可能是图片**（PPT 背景图）：DOM 里无文字时，从 `.pptimg[data-background]` 取图片 URL 下载后视觉识别
- **不可逆页面要停下确认**：页面若提示"仅一次提交机会"，填完后必须停下等用户确认，不要自动交卷
