(() => {
  const AA = window.__aa;
  const b = AA.pickRoot();
  const ROOT = b.doc;
  const items = AA.items(ROOT);

  const out = items.map((item, i) => {
    const h4 = item.querySelector('h4');
    const title = h4 ? AA.norm(h4.textContent) : '';
    const opts = Array.from(item.querySelectorAll('label.el-radio, label.el-checkbox')).map(l => {
      const inp = l.querySelector('input');
      return { value: inp ? inp.value : '', label: AA.visText(l) };
    });
    const fills = item.querySelectorAll('input[placeholder=输入答案]').length;
    const kind = AA.qType(item);

    // 填空题上下文：把每个空位替换为【空N】，便于看清前后文
    let ctx = '';
    if (fills) {
      const doc = item.ownerDocument;
      const clone = item.cloneNode(true);
      let n = 0;
      clone.querySelectorAll('input[placeholder=输入答案]').forEach(x => {
        n++;
        const s = doc.createElement('span');
        s.textContent = '【空' + n + '】';
        x.parentNode.replaceChild(s, x);
      });
      clone.querySelectorAll('label input').forEach(x => x.remove());
      ctx = AA.norm(clone.textContent).slice(0, 500);
    }

    return { q: i + 1, type: kind, title, options: opts, fillCount: fills, ctx };
  });

  return JSON.stringify({ root: b.expr, total: out.length, items: out }, null, 1);
})()
