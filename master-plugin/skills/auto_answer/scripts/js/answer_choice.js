(() => {
  const AA = window.__aa;
  const ANSWERS = __ANSWERS__;          // { choice: {...}, judge: {...} }
  const ROOT = AA.pickRoot().doc;
  const items = AA.items(ROOT);

  const click = el => el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
  const log = [];

  // 按可见标号匹配。雨课堂的 input.value 与可见标号错位，不能信 value
  const matchByLetter = (l, letter) => {
    const t = AA.visText(l);
    if (t === letter) return true;
    if (new RegExp('^' + letter + '[\\s.、,，:：)）]').test(t)) return true;
    const inp = l.querySelector('input');           // 无可见标号时退回 value
    return !!inp && inp.value === letter;
  };
  // 也可直接给选项文本，按包含匹配
  const matchByText = (l, text) => AA.visText(l).includes(text);

  // ===== 单选 / 多选 =====
  Object.keys(ANSWERS.choice || {}).forEach(qk => {
    const item = items[+qk - 1];
    if (!item) { log.push('Q' + qk + ' ITEM-MISSING'); return; }
    const labels = Array.from(item.querySelectorAll('label.el-radio, label.el-checkbox'));
    (ANSWERS.choice[qk] || []).forEach(ans => {
      const isLetter = /^[A-Za-z]$/.test(ans);
      const target = labels.find(l => isLetter ? matchByLetter(l, ans.toUpperCase()) : matchByText(l, ans));
      if (target) { click(target); log.push('Q' + qk + ' ' + ans + ' OK'); }
      else log.push('Q' + qk + ' ' + ans + ' MISS');
    });
  });

  // ===== 判断题：按 input.value 的 true/false 匹配 =====
  Object.keys(ANSWERS.judge || {}).forEach(qk => {
    const item = items[+qk - 1];
    if (!item) { log.push('Q' + qk + ' ITEM-MISSING'); return; }
    const want = String(ANSWERS.judge[qk]);
    const labels = Array.from(item.querySelectorAll('label.el-radio, label.el-checkbox'));
    const target = labels.find(l => {
      const inp = l.querySelector('input');
      return !!inp && inp.value === want;
    });
    if (target) { click(target); log.push('Q' + qk + ' judge=' + want + ' OK'); }
    else log.push('Q' + qk + ' judge=' + want + ' MISS');
  });

  return JSON.stringify({ log }, null, 1);
})()
