// answer_choice.test.mjs — 多选幂等回归测试
// 核心用例：重复执行 answer-choice 时，已选中的多选项不能被再次点击（点击是切换语义，
// 再点一次会把用户/上一轮的答案取消掉）。
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { makeEl, makeDoc, wireToggle, buildScript } from './dom_stub.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const read = name => readFileSync(join(here, '..', 'js', name), 'utf8');

let passed = 0;
const test = (name, fn) => {
  try { fn(); passed++; console.log('  ok  ' + name); }
  catch (e) { console.error('  FAIL ' + name + '\n       ' + e.message); process.exitCode = 1; }
};
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

// 造一个带 n 个多选项的题目项；initial 指定初始选中项（模拟上一轮已答）
function makeMultiItem(labels, initial = []) {
  const opts = labels.map((vis, i) => {
    const inp = makeEl({ tag: 'input', attrs: { value: String(i) }, value: String(i) });
    const label = makeEl({
      tag: 'label',
      classes: ['el-checkbox'],
      attrs: { 'aria-checked': 'false' },
      children: [
        inp,
        makeEl({ tag: 'span', classes: ['el-checkbox__label'], text: vis }),
      ],
    });
    wireToggle(label);
    return { label, inp };
  });
  initial.forEach(i => {
    opts[i].inp.checked = true;
    opts[i].label.setAttribute('aria-checked', 'true');
  });
  const item = makeEl({
    tag: 'div',
    classes: ['subject-item'],
    children: [
      makeEl({ tag: 'h4', text: '多选题' }),
      ...opts.map(o => o.label),
    ],
  });
  return { item, opts };
}

// 在给定 DOM 下执行 answer_choice.js，返回 { log, opts }
function runChoice(labels, answers, initial = []) {
  const { item, opts } = makeMultiItem(labels, initial);
  const doc = makeDoc([item]);
  const win = { document: doc };
  const js = buildScript(read, 'answer_choice.js', answers);
  const out = new Function('window', 'document', 'MouseEvent', 'Event', js)(
    win, doc, class { constructor(t) { this.type = t; } }, class { constructor(t) { this.type = t; } },
  );
  return { log: JSON.parse(out).log, opts };
}

const LABELS = ['A 甲', 'B 乙', 'C 丙'];

test('首次执行：选中 A、C 会各自点击一次', () => {
  const { log, opts } = runChoice(LABELS, { choice: { 1: ['A', 'C'] } });
  assert(opts[0].inp.checked && opts[2].inp.checked, 'A/C 应被选中');
  assert(log.filter(l => l.endsWith('OK')).length === 2, '应有两条 OK，实际: ' + log.join(','));
});

test('重复执行：已选中的 A、C 不再点击，答案保持不变', () => {
  const { log, opts } = runChoice(LABELS, { choice: { 1: ['A', 'C'] } }, [0, 2]);
  assert(opts[0].inp.checked && opts[2].inp.checked, 'A/C 应仍处于选中状态（不能被取消）');
  assert(log.filter(l => l.endsWith('ALREADY')).length === 2, '应记录两条 ALREADY，实际: ' + log.join(','));
  assert(log.filter(l => l.endsWith('OK')).length === 0, '不应有任何点击');
});

test('补答：已选 A，再答 A、B 时只点 B', () => {
  const { log, opts } = runChoice(LABELS, { choice: { 1: ['A', 'B'] } }, [0]);
  assert(opts[0].inp.checked && opts[1].inp.checked, 'A/B 都应选中');
  assert(log.includes('Q1 A ALREADY'), 'A 应记为 ALREADY');
  assert(log.includes('Q1 B OK'), 'B 应记为 OK');
});

test('单选重复点击不会误判：aria-checked 已 true 时跳过', () => {
  const inp = makeEl({ tag: 'input', attrs: { value: '0' }, value: '0' });
  const label = makeEl({
    tag: 'label',
    classes: ['el-radio'],
    attrs: { 'aria-checked': 'true' },
    children: [inp, makeEl({ tag: 'span', classes: ['el-radio__label'], text: 'A 甲' })],
  });
  wireToggle(label);
  inp.checked = true;
  const item = makeEl({ tag: 'div', classes: ['subject-item'], children: [makeEl({ tag: 'h4' }), label] });
  const doc = makeDoc([item]);
  const js = buildScript(read, 'answer_choice.js', { choice: { 1: ['A'] } });
  const out = new Function('window', 'document', 'MouseEvent', 'Event', js)(
    { document: doc }, doc, class { constructor(t) { this.type = t; } }, class { constructor(t) { this.type = t; } },
  );
  const log = JSON.parse(out).log;
  assert(inp.checked, '单选应保持选中');
  assert(log.includes('Q1 A ALREADY'), '应跳过已选中的单选项，实际: ' + log.join(','));
});

test('未匹配的选项仍记 MISS，不点击任何东西', () => {
  const { log, opts } = runChoice(LABELS, { choice: { 1: ['Z'] } });
  assert(log.includes('Q1 Z MISS'), '应记 MISS');
  assert(!opts.some(o => o.inp.checked), '不应选中任何项');
});

console.log('\n' + passed + ' passed');
