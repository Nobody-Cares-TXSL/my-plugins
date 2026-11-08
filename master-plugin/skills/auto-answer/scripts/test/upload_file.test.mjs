// upload_file.test.mjs — file input 选择顺序回归测试
// 核心用例：考试作答区在同源 iframe 里，主文档也可能有一个 file input。
// 必须优先选 iframe 里的那个；allDocs() 把主文档排在第一位，不能按顺序取第一个命中。
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { makeEl, makeDoc, buildScript } from './dom_stub.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const read = name => readFileSync(join(here, '..', 'js', name), 'utf8');

let passed = 0;
const test = (name, fn) => {
  try { fn(); passed++; console.log('  ok  ' + name); }
  catch (e) { console.error('  FAIL ' + name + '\n       ' + e.message); process.exitCode = 1; }
};
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

// 造一个 file input；记录是否收到 change 事件
function makeFileInput(tag = 'main') {
  const inp = makeEl({ tag: 'input', attrs: { type: 'file' } });
  inp.tag = tag;
  return inp;
}

function runUpload({ mainInput, iframeInput }) {
  const mainDoc = makeDoc(mainInput ? [mainInput] : []);
  const iframeDoc = makeDoc(iframeInput ? [iframeInput] : []);
  // 模拟 document.querySelectorAll('iframe')：一个同源 iframe
  const iframeEl = { contentDocument: iframeDoc };
  mainDoc.querySelectorAll = sel => {
    if (sel === 'iframe') return [iframeEl];
    const parts = sel.split(',');
    const out = [];
    const walk = n => {
      for (const c of n.children || []) {
        if (parts.some(p => c.tagName === p.trim().replace(/\[.*\]/, ''))) out.push(c);
        walk(c);
      }
    };
    walk(mainDoc);
    return out;
  };
  const win = {
    document: mainDoc,
    __aa_chunks: ['aGVsbG8='],      // base64("hello")
    __aa_file_name: 'answer.jpg',
    atob: s => Buffer.from(s, 'base64').toString('binary'),
  };
  const js = buildScript(read, 'upload_file.js');
  const FileStub = class { constructor(parts, name, opts) { this.name = name; this.size = parts[0].length; this.type = opts.type; } };
  const DataTransferStub = class {
    constructor() { this.files = []; this.items = { add: f => this.files.push(f) }; }
  };
  const out = new Function('window', 'document', 'File', 'DataTransfer', 'Event', 'Uint8Array', js)(
    win, mainDoc, FileStub, DataTransferStub, class { constructor(t) { this.type = t; } }, Uint8Array,
  );
  return { result: JSON.parse(out), mainInput, iframeInput };
}

test('主文档与 iframe 都有 file input 时，选 iframe 的', () => {
  const main = makeFileInput('main');
  const frame = makeFileInput('iframe');
  const { result, iframeInput, mainInput } = runUpload({ mainInput: main, iframeInput: frame });
  assert(result.ok, '应成功注入，实际: ' + JSON.stringify(result));
  assert(iframeInput.events.includes('change'), 'iframe 里的 input 应收到 change');
  assert(!mainInput.events.includes('change'), '主文档的 input 不应被触碰');
});

test('只有主文档有 file input 时，回退到主文档', () => {
  const main = makeFileInput('main');
  const { result, mainInput } = runUpload({ mainInput: main, iframeInput: null });
  assert(result.ok, '应成功注入，实际: ' + JSON.stringify(result));
  assert(mainInput.events.includes('change'), '主文档 input 应收到 change');
});

test('只有 iframe 有 file input 时，选 iframe', () => {
  const frame = makeFileInput('iframe');
  const { result, iframeInput } = runUpload({ mainInput: null, iframeInput: frame });
  assert(result.ok, '应成功注入');
  assert(iframeInput.events.includes('change'), 'iframe input 应收到 change');
});

test('两边都没有 file input 时返回 no file input', () => {
  const { result } = runUpload({ mainInput: null, iframeInput: null });
  assert(result.ok === false && result.error === 'no file input', '应报 no file input，实际: ' + JSON.stringify(result));
});

console.log('\n' + passed + ' passed');
