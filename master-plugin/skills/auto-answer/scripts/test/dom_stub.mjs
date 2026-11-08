// dom_stub.mjs — 极简 DOM 桩，只实现 auto-answer 页面脚本用到的接口
// 目的是让 answer_choice.js / upload_file.js 能在 Node 里跑起来做回归测试，
// 不引入 jsdom（插件仓库不装 node_modules）。
//
// 支持的 selector：标签名、.class、[attr]、[attr=value]、逗号并列。
// 不支持：层级选择器（"a b"）、伪类、兄弟/子代组合符——当前脚本都没用到。

export function matches(node, sel) {
  const m = sel.match(/^([a-zA-Z0-9]*)((?:[.#][\w-]+|\[[^\]]+\])*)$/);
  if (!m) return false;
  const [, tag, rest] = m;
  if (tag && node.tagName !== tag) return false;
  for (const t of rest.match(/[.#][\w-]+|\[[^\]]+\]/g) || []) {
    if (t.startsWith('.')) {
      if (!node.classes.includes(t.slice(1))) return false;
    } else if (t.startsWith('#')) {
      if (node.attrs.id !== t.slice(1)) return false;
    } else {
      const inner = t.slice(1, -1);
      const eq = inner.indexOf('=');
      if (eq === -1) {
        if (!(inner in node.attrs)) return false;
      } else {
        const k = inner.slice(0, eq);
        let v = inner.slice(eq + 1);
        if (/^(["']).*\1$/.test(v)) v = v.slice(1, -1);
        if (String(node.attrs[k]) !== v) return false;
      }
    }
  }
  return true;
}

function queryAll(root, sel) {
  const parts = sel.split(',').map(s => s.trim()).filter(Boolean);
  const out = [];
  const walk = n => {
    for (const c of n.children || []) {
      if (parts.some(p => matches(c, p))) out.push(c);
      walk(c);
    }
  };
  walk(root);
  return out;
}

export function makeEl({
  tag = 'div', classes = [], attrs = {}, children = [], text = '', checked = false, value = '',
} = {}) {
  const node = {
    tagName: tag,
    classes,
    attrs,
    children,
    checked,
    value,
    textContent: text,
    files: [],
    events: [],
    getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; },
    setAttribute(k, v) { this.attrs[k] = v; },
    querySelectorAll(sel) { return queryAll(this, sel); },
    querySelector(sel) { return queryAll(this, sel)[0] || null; },
    dispatchEvent(e) {
      this.events.push(e.type);
      if (typeof this.onEvent === 'function') this.onEvent(e);
      return true;
    },
  };
  return node;
}

export function makeDoc(children = []) {
  const doc = {
    defaultView: {},
    children,
    querySelectorAll(sel) { return queryAll(doc, sel); },
    querySelector(sel) { return queryAll(doc, sel)[0] || null; },
  };
  return doc;
}

// Element UI 的 checkbox/radio：点 label 会切换内部 input，并同步 aria-checked
export function wireToggle(label) {
  label.onEvent = () => {
    const inp = label.querySelector('input');
    if (!inp) return;
    inp.checked = !inp.checked;
    label.setAttribute('aria-checked', inp.checked ? 'true' : 'false');
  };
}

// 拼 _common.js + _match.js + 主脚本，替换 __ANSWERS__（与 lib.sh 的 build_js 一致）
// _common/_match 是完整语句，主脚本是末尾无分号的 IIFE 表达式；
// 只在主脚本前加 return 才能取到它的返回值
export function buildScript(read, mainFile, answers) {
  const prelude = read('_common.js') + read('_match.js');
  let main = read(mainFile);
  if (answers !== undefined) main = main.replace('__ANSWERS__', JSON.stringify(answers));
  return prelude + '\nreturn (' + main + '\n);';
}
