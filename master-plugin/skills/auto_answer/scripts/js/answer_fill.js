(() => new Promise(resolve => {
  const AA = window.__aa;
  const FILLS = (__ANSWERS__.fill) || {};   // 题号 -> 该题各空答案（按空位顺序）
  const ROOT = AA.pickRoot().doc;
  const items = AA.items(ROOT);

  // 原生 setter 绕过 Vue 属性代理，否则框架不感知变更
  const setVal = (el, v) => {
    const desc = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
    if (desc && desc.set) desc.set.call(el, v); else el.value = v;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  };
  const sleep = ms => new Promise(r => setTimeout(r, ms));

  // 展开成待写的空位队列：每题逐空
  const jobs = [];
  Object.keys(FILLS).forEach(k => {
    (FILLS[k] || []).forEach((want, idx) => jobs.push({ q: +k, idx, want }));
  });

  (async () => {
    const log = [];
    for (const job of jobs) {
      let ok = false;
      for (let attempt = 1; attempt <= 3 && !ok; attempt++) {
        const item = items[job.q - 1];
        if (!item) { log.push('Q' + job.q + ' blank' + job.idx + ' ITEM-MISSING'); break; }
        // 每次重新查询，取当前存活的节点
        const inp = item.querySelectorAll('input[placeholder=输入答案]')[job.idx];
        if (!inp) { log.push('Q' + job.q + ' blank' + job.idx + ' INPUT-MISSING'); break; }

        inp.focus();
        setVal(inp, job.want);
        await sleep(700);                       // 等这次写入触发的重渲染结束

        const fresh = item.querySelectorAll('input[placeholder=输入答案]')[job.idx];
        if (fresh && fresh.value === job.want) { ok = true; log.push('Q' + job.q + ' blank' + job.idx + ' OK'); }
      }
      if (!ok) log.push('Q' + job.q + ' blank' + job.idx + ' FAILED want=' + JSON.stringify(job.want));
    }
    await sleep(2500);                          // 最终稳定后快照
    const final = {};
    Object.keys(FILLS).forEach(k => {
      const item = items[+k - 1];
      final['Q' + k] = item ? Array.from(item.querySelectorAll('input[placeholder=输入答案]')).map(x => x.value) : null;
    });
    resolve(JSON.stringify({ log, final }, null, 1));
  })();
}))()
