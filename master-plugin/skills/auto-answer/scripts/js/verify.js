(() => {
  const AA = window.__aa;
  const ROOT = AA.pickRoot().doc;
  const items = AA.items(ROOT);

  const report = items.map((item, i) => {
    const labels = Array.from(item.querySelectorAll('label.el-radio, label.el-checkbox'));
    const isChecked = l => {
      if (l.getAttribute('aria-checked') === 'true') return true;
      const inp = l.querySelector('input');
      return !!inp && inp.checked;
    };
    const checked = labels.filter(isChecked).map(l => {
      const inp = l.querySelector('input');
      return { value: inp ? inp.value : '', label: AA.visText(l).slice(0, 40) };
    });
    const fills = Array.from(item.querySelectorAll('input[placeholder=输入答案]')).map(x => x.value);
    const type = AA.qType(item);
    return { q: i + 1, type, checked, fills, emptyFills: fills.filter(v => !String(v).trim()).length };
  });

  return JSON.stringify({
    total: report.length,
    unanswered: report.filter(r => r.type !== 'fill' && r.checked.length === 0).map(r => r.q),
    partialFills: report.filter(r => r.type === 'fill' && r.emptyFills > 0).map(r => r.q),
    report
  }, null, 1);
})()
