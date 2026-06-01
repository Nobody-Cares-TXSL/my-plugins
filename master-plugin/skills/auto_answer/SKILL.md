---
name: auto_answer
description: 基于 opencli browser 的自动答题技能。绑定浏览器标签页，读取题目，一次性完成选择题、判断题、填空题的作答。
argument-hint: [会话名，默认 auto]
allowed-tools:
  - Bash
  - Read
---

# auto_answer — 自动答题

通过 opencli browser 操作浏览器，读取在线考试/练习题目并自动作答。

## 前置检查

```bash
opencli doctor
```

确保 `[OK] Extension: connected`。未连接则提示用户安装扩展。

## 执行流程

### Step 1: 绑定标签页

`$ARGUMENTS` 第一个参数为会话名，默认 `auto`。

```bash
opencli browser $SESSION unbind 2>/dev/null; opencli browser $SESSION bind
```

确认绑定的 URL 包含 `exam` 或 `quiz` 或 `test` 关键词。若绑定到空白页，提示用户在浏览器中打开答题页面后重试。

### Step 2: 处理弹窗

检测并关闭可能存在的对话框（考试须知、开始确认等）：

```bash
opencli browser $SESSION eval "(() => {
  document.querySelectorAll('[role=dialog]').forEach(d => d.style.display = 'none');
  return 'dialogs hidden';
})()"
```

若页面有"开始"按钮且考试尚未开始计时，提示用户手动点击"开始"（部分平台需要手机验证码等二次确认）。

### Step 3: 读取全部题目

循环执行 `state` + `scroll`，直到页面底部（`page_scroll` 向下滚动量为 0）：

```bash
opencli browser $SESSION state 2>&1
opencli browser $SESSION scroll down --amount 1500
```

从 state 输出中提取所有题目。题目结构：

- **单选题/多选题/判断题**：有 `<h4>` 包含题目文本，`<label>` 包含选项
- **填空题**：`<span>` 包含前后文，`<input placeholder=输入答案>` 为填空位置

### Step 4: 分析答案

逐题分析，输出答案清单：

| 题型 | 答案格式 |
|------|---------|
| 单选题 | 选项文本（如 `传输速度快,适合近距离`） |
| 多选题 | 选项文本数组（如 `['分类', '回归']`） |
| 判断题 | `true` 或 `false` |
| 填空题 | 填入的文本（如 `片选`） |

### Step 5: 一次性作答（核心）

**绝对禁止用 `click <ref>`** — 页面重渲染后 refs 全部过期。

用单次 `eval` 完成所有答题操作：

```javascript
opencli browser $SESSION eval "(() => {
  const results = {};

  // ===== 单选题 / 判断题 =====
  // 用答案文本匹配 label，不用 ref 索引
  const radioAnswers = {
    // 题号: 答案文本（或 true/false）
    1: '选项文本',
    4: '8 个',
    // ...
  };

  const allLabels = document.querySelectorAll('label');
  allLabels.forEach(label => {
    const radio = label.querySelector('input[type=radio]');
    if (!radio || radio.checked) return;
    const text = label.textContent;
    for (const [qnum, ans] of Object.entries(radioAnswers)) {
      if (typeof ans === 'string' && text.includes(ans)) {
        label.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
        break;
      }
    }
  });
  results.radio = 'done';

  // ===== 多选题 =====
  // 多选答案按题号分组
  const checkAnswers = {
    16: ['无监督学习', '强化学习', '监督学习'],
    17: ['分类', '回归'],
    // ...
  };

  for (const [qnum, answers] of Object.entries(checkAnswers)) {
    allLabels.forEach(label => {
      const checkbox = label.querySelector('input[type=checkbox]');
      if (!checkbox || checkbox.checked) return;
      const text = label.textContent;
      for (const ans of answers) {
        if (text.includes(ans)) {
          label.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}));
          break;
        }
      }
    });
  }
  results.checkbox = 'done';

  // ===== 填空题 =====
  const fillAnswers = ['答案1', '答案2', '答案3'];
  const textInputs = document.querySelectorAll('input[type=text][placeholder=输入答案]');
  textInputs.forEach((inp, i) => {
    if (i < fillAnswers.length) {
      inp.focus();
      inp.value = fillAnswers[i];
      inp.dispatchEvent(new Event('input', {bubbles: true}));
      inp.dispatchEvent(new Event('change', {bubbles: true}));
    }
  });
  results.fill = 'done';

  return JSON.stringify(results);
})()"
```

### Step 6: 验证

```bash
opencli browser $SESSION eval "(() => {
  const radioChecked = document.querySelectorAll('label[aria-checked=true]').length;
  const textInputs = document.querySelectorAll('input[type=text][placeholder=输入答案]');
  const filled = Array.from(textInputs).filter(i => i.value.trim() !== '').length;
  return JSON.stringify({
    radioChecked,
    textFilled: filled,
    totalTextInputs: textInputs.length
  });
})()"
```

对比预期数量。若有遗漏，用 `eval` 补答。

## 关键技术规则

### 禁止事项

| 禁止 | 原因 |
|------|------|
| `click <ref>` | 页面重渲染导致 refs 全部过期 |
| `radio.click()` | 对 `tabindex=-1` 的隐藏 input 无效 |
| `input[checked]` 检测状态 | Vue/React 响应式状态不反映到 DOM 属性 |
| h4 索引映射题号 | 填空题没有 h4，索引不连续 |

### 正确做法

| 操作 | 方法 |
|------|------|
| 点击选项 | `label.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true}))` |
| 匹配答案 | 用答案文本匹配 `label.textContent`，不用 ref 或索引 |
| 检测选中 | `label[aria-checked=true]` 或 `radio.checked` |
| 填写填空 | `input.focus()` → 设 `value` → `dispatchEvent('input')` + `dispatchEvent('change')` |
| 验证填空 | 检查 `input.value` |

### 弹窗处理

考试页面常有以下弹窗：
- **考试须知**：`[role=dialog][aria-label=考试须知]`
- **开始确认**：含"开始"/"暂不开始"按钮
- **交卷确认**：含"交卷"/"继续作答"按钮

统一处理：`document.querySelectorAll('[role=dialog]').forEach(d => d.style.display = 'none')`

若需要点击"开始"才能进入答题，用文本匹配：
```javascript
document.querySelectorAll('button, span').forEach(el => {
  if (el.textContent.trim() === '开始') el.click();
});
```

## 注意事项

- 本技能提供答题框架，实际答案需要 Claude 根据题目内容分析得出
- 对于专业性强的题目（如微机原理、医学等），Claude 可能给出错误答案
- 用户应在答题完成后检查一遍，尤其是专业课
- 填空题答案可能有多种正确表述，平台可能不接受同义词
