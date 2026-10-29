// upload_file.js — 把 window.__aa_chunks（base64 分块）组装成 File 并注入 file input
// 支持同源 iframe：优先选 iframe 内的 input，其次主文档
(() => {
  const AA = window.__aa;
  const chunks = window.__aa_chunks || [];
  if (!chunks.length) return JSON.stringify({ ok: false, error: 'no chunks' });

  const b64 = chunks.join('');
  const bin = atob(b64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);

  const name = window.__aa_file_name || 'answer.jpg';
  const type = /\.png$/i.test(name) ? 'image/png'
    : /\.pdf$/i.test(name) ? 'application/pdf'
      : /\.jpe?g$/i.test(name) ? 'image/jpeg'
        : 'application/octet-stream';
  const file = new File([arr], name, { type });

  // 优先 iframe（考试作答区），其次主文档
  let input = null;
  for (const c of AA.allDocs()) {
    const el = c.doc.querySelector('input[type=file]');
    if (el) { input = el; break; }
  }
  if (!input) return JSON.stringify({ ok: false, error: 'no file input' });

  const dt = new DataTransfer();
  dt.items.add(file);
  input.files = dt.files;
  input.dispatchEvent(new Event('change', { bubbles: true }));

  return JSON.stringify({ ok: true, name, size: file.size, files: input.files.length });
})()
