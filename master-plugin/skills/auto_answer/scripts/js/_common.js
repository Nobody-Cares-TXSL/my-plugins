// _common.js — auto_answer 公共工具（由 lib.sh 的 build_js 拼在主脚本之前）
// 用 window.__aa 包装：多次 eval 共享页面上下文，重复赋值幂等，且不泄漏顶层变量
window.__aa = (() => {
  const norm = s => String(s || '').replace(/\s+/g, ' ').trim();

  // 主文档 + 所有同源 iframe（跨域 iframe 的 contentDocument 为 null，自动跳过）
  const allDocs = () => {
    const out = [{ expr: 'document', doc: document }];
    Array.from(document.querySelectorAll('iframe')).forEach((f, i) => {
      let d = null;
      try { d = f.contentDocument; } catch (e) { d = null; }
      if (d) out.push({ expr: "document.querySelectorAll('iframe')[" + i + "].contentDocument", doc: d });
    });
    return out;
  };

  // 探测承载题目的根：取题目元素最多的那个 document
  const pickRoot = () => {
    const cands = allDocs();
    let best = cands[0], bestScore = -1;
    cands.forEach(c => {
      const n = c.doc.querySelectorAll('.subject-item, label.el-radio, label.el-checkbox, input[placeholder=输入答案]').length;
      if (n > bestScore) { bestScore = n; best = c; }
    });
    return best;
  };

  // 真正的题目项：有 h4，或有填空输入框（排除导航面板等）
  const items = root => Array.from(root.querySelectorAll('.subject-item')).filter(it =>
    it.querySelector('h4') || it.querySelector('input[placeholder=输入答案]'));

  // 题型判定：先看控件类型（checkbox=多选），再看 value 特征（判断题）
  // 顺序不能反：多选的 value 也可能是 true/false
  const qType = item => {
    if (item.querySelector('input[placeholder=输入答案]')) return 'fill';
    if (item.querySelector('label.el-checkbox')) return 'multi';
    const hasBoolValue = Array.from(item.querySelectorAll('label input')).some(inp =>
      inp.value === 'true' || inp.value === 'false');
    return hasBoolValue ? 'judge' : 'single';
  };

  // 选项可见文本（Element UI 的 label 文本在 .el-radio__label / .el-checkbox__label 里）
  const visText = l => {
    const tEl = l.querySelector('.el-radio__label, .el-checkbox__label');
    return norm(tEl ? tEl.textContent : l.textContent);
  };

  const fire = (doc, el, type) => el.dispatchEvent(new MouseEvent(type, {
    bubbles: true, cancelable: true, view: doc.defaultView, button: 0
  }));

  // 完整鼠标事件序列（部分按钮只认 mousedown+mouseup+click）
  const clickFull = (doc, el) => ['mousedown', 'mouseup', 'click'].forEach(t => fire(doc, el, t));

  // 在主文档与所有同源 iframe 里找符合条件的第一批元素
  const queryAll = sel => {
    const out = [];
    allDocs().forEach(c => c.doc.querySelectorAll(sel).forEach(el => out.push({ doc: c.doc, el })));
    return out;
  };

  return { norm, allDocs, pickRoot, items, qType, visText, fire, clickFull, queryAll };
})();
