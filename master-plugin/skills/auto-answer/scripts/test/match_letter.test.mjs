// match_letter.test.mjs — _match.js 回归测试
// 核心用例：雨课堂的可见标号与 input.value 错位时，必须按可见标号匹配
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, '..', 'js', '_match.js'), 'utf8');

const win = {};
new Function('window', src)(win);
const { matchByLetter } = win.__aa;

let passed = 0;
const test = (name, fn) => {
  try { fn(); passed++; console.log('  ok  ' + name); }
  catch (e) { console.error('  FAIL ' + name + '\n       ' + e.message); process.exitCode = 1; }
};

// 平台错位场景：可见标号 A/B/C/D 对应的 input.value 是打乱的
const opts = [
  { vis: 'A 顺序组合', value: 'B' },
  { vis: 'B 允许适当交叉以节省篇幅', value: 'D' },
  { vis: 'C 完整嵌套', value: 'C' },
  { vis: 'D 只用三种基本控制结构', value: 'A' },
];

test('选 B 命中第 2 个选项，而不是 value 恰好为 B 的第 1 个', () => {
  const hits = opts.filter(o => matchByLetter(o.vis, 'B') === true);
  assert.equal(hits.length, 1);
  assert.equal(hits[0].vis, 'B 允许适当交叉以节省篇幅');
});

test('选 C 命中第 3 个选项', () => {
  const hits = opts.filter(o => matchByLetter(o.vis, 'C') === true);
  assert.equal(hits.length, 1);
  assert.equal(hits[0].vis, 'C 完整嵌套');
});

test('无可见标号返回 null（调用方退回 value）', () => {
  assert.equal(matchByLetter('', 'A'), null);
  assert.equal(matchByLetter('随便一段没有标号的文本', 'A'), null);
});

test('精确标号与带分隔符的前缀都命中', () => {
  assert.equal(matchByLetter('A', 'A'), true);
  assert.equal(matchByLetter('A. 顺序组合', 'A'), true);
  assert.equal(matchByLetter('A、顺序组合', 'A'), true);
});

test('有标号但不匹配时返回 false，不能返回 null', () => {
  assert.equal(matchByLetter('A 顺序组合', 'B'), false);
});

console.log(`\n${passed} passed`);
