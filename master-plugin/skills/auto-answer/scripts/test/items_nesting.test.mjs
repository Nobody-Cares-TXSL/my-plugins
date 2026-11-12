// items_nesting.test.mjs — 题目项计数回归测试
// 核心用例：新考试系统（changjiang-exam.yuketang.cn）的 DOM 是
// .subject-item 包裹 .exercise-item，两者都带 h4 且指向同一道题。
// 若 items() 把两个选择器合并，会把每道题计两次（实测 30 题变 60）。
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import assert from 'node:assert/strict';
import { makeEl, makeDoc } from './dom_stub.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const read = name => readFileSync(join(here, '..', 'js', name), 'utf8');

let passed = 0;
const test = (name, fn) => {
  try { fn(); passed++; console.log('  ok  ' + name); }
  catch (e) { console.error('  FAIL ' + name + '\n       ' + e.message); process.exitCode = 1; }
};

// 只加载 _common.js（items/pickRoot 在这里）
const win = { document: null };
new Function('window', read('_common.js'))(win);
const AA = win.__aa;

// 造一道题：外层 .subject-item 包住内层 .exercise-item，两者都含 h4
function nestedQuestion() {
  const h4inner = makeEl({ tag: 'h4', text: '题目' });
  const ex = makeEl({ tag: 'div', classes: ['exercise-item'], children: [h4inner] });
  const h4outer = makeEl({ tag: 'h4', text: '题目' });
  return makeEl({ tag: 'div', classes: ['subject-item'], children: [h4outer, ex] });
}

// 旧版雨课堂：只有 .subject-item，无内层 .exercise-item
function flatQuestion() {
  return makeEl({
    tag: 'div', classes: ['subject-item'],
    children: [makeEl({ tag: 'h4', text: '题目' })],
  });
}

test('嵌套结构每题只计一次（3 题不变成 6 题）', () => {
  const doc = makeDoc([nestedQuestion(), nestedQuestion(), nestedQuestion()]);
  assert.equal(AA.items(doc).length, 3);
});

// 反向验证：确认这个用例真能抓到"合并两个选择器"的回归。
// 内层 .exercise-item 自带 h4（与线上实测一致），合并后每题会被命中两次。
test('合并两个选择器会让本题计数翻倍（证明上面的用例有效）', () => {
  const doc = makeDoc([nestedQuestion()]);
  const merged = Array.from
    ? doc.querySelectorAll('.subject-item, .exercise-item').filter(
        it => it.querySelector('h4') || it.querySelector('input[placeholder=输入答案]'))
    : [];
  assert.equal(merged.length, 2, '合并选择器本应重复计数，说明测试桩没能复现该场景');
  assert.equal(AA.items(doc).length, 1);
});

test('旧版扁平结构正常计数', () => {
  const doc = makeDoc([flatQuestion(), flatQuestion()]);
  assert.equal(AA.items(doc).length, 2);
});

test('无 h4 也无填空的 .subject-item 被过滤（导航面板）', () => {
  const nav = makeEl({ tag: 'div', classes: ['subject-item'], children: [makeEl({ tag: 'span', text: '1' })] });
  const doc = makeDoc([nav, flatQuestion()]);
  assert.equal(AA.items(doc).length, 1);
});

console.log(`\n${passed} passed`);
