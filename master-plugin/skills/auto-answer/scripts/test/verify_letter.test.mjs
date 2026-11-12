// verify_letter.test.mjs — verify 输出字段回归测试
// 核心用例：雨课堂系平台的 input.value 与可见标号错位。
// verify 若把 value 当主字段输出，读报告的人会误判选了哪一项
// （实测：可见 "C 动态模型" 的 value 是 "B"，读 value 会当成选了 B）。
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import assert from 'node:assert/strict';
import { makeEl, makeDoc, buildScript } from './dom_stub.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const read = name => readFileSync(join(here, '..', 'js', name), 'utf8');

let passed = 0;
const test = (name, fn) => {
  try { fn(); passed++; console.log('  ok  ' + name); }
  catch (e) { console.error('  FAIL ' + name + '\n       ' + e.message); process.exitCode = 1; }
};

// 造一道已选中的单选题：可见标号 vis，input.value 是错位的 val
function q(vis, val, checked) {
  const inp = makeEl({ tag: 'input', attrs: { value: val }, value: val, checked });
  const label = makeEl({
    tag: 'label', classes: ['el-radio'],
    attrs: { 'aria-checked': checked ? 'true' : 'false' },
    children: [inp, makeEl({ tag: 'span', classes: ['el-radio__label'], text: vis })],
  });
  return makeEl({
    tag: 'div', classes: ['subject-item'],
    children: [makeEl({ tag: 'h4', text: '题目' }), makeEl({ tag: 'div', children: [label] })],
  });
}

function run(doc) {
  const win = { document: doc };
  const js = buildScript(read, 'verify.js');
  return JSON.parse(new Function('window', 'document', js)(win, doc));
}

test('letter 取可见标号，rawValue 保留错位的 input.value', () => {
  const out = run(makeDoc([q('A 过程内聚', 'D', true)]));
  const c = out.report[0].checked[0];
  assert.equal(c.letter, 'A', 'letter 应是可见标号');
  assert.equal(c.rawValue, 'D', 'rawValue 应是原始 value');
});

test('标号与 value 错位时，letter 不会被 value 污染', () => {
  const out = run(makeDoc([q('C 用户界面', 'A', true)]));
  assert.equal(out.report[0].checked[0].letter, 'C');
});

test('未选中的题进入 unanswered', () => {
  const out = run(makeDoc([q('A 甲', 'A', false), q('B 乙', 'B', true)]));
  assert.deepEqual(out.unanswered, [1]);
});

test('无可见标号时 letter 为空字符串（判断题）', () => {
  const out = run(makeDoc([q('√', 'true', true)]));
  assert.equal(out.report[0].checked[0].letter, '');
});

console.log(`\n${passed} passed`);
