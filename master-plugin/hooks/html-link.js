// html-link：会话记录里的 .html / .htm 路径变成可点链接，点击用系统浏览器打开。
// .md 的点击显示交给 mdview，本模块只认 html，且只在自己的行里追加，不替换正文。

const MAX_LINKS = 20
const cwdOf = new Map() // requestId → 首次绘制时的 cwd：cd 之后旧消息里的相对路径不漂移

// ---- 以下为路径解析与文本链接化的纯函数：无副作用，不碰 $ ----

const HTML = /\.html?$/i
// 门禁用：只看「这段文本里可能提到 html 路径」，不锚定结尾
const MAYBE_HTML = /\.html?\b/i

// 行内代码、markdown 链接/图片、URL，或裸的 .html 路径（含中文紧邻、:line 后缀）。
const TOKEN =
  /(`+)([^`\n]+?)\1|(!?)\[([^\]\n]*)\]\(<?([^)\s>]+)>?\)|\b(?:https?|file):\/\/[^\s<>)\]]+|(?<![\w/.~@+-])((?:~|\.{1,2})?\/?(?:[\p{L}\p{N}_.@+-]+\/)*[\p{L}\p{N}_.@+-]+\.html?(?::\d+(?::\d+)?)?)(?![\w/])/giu

const FENCE = /^\s{0,3}(`{3,}|~{3,})/

const baseName = (p) => p.slice(p.lastIndexOf('/') + 1)

// 折叠绝对路径里的 . 与 ..
const normalize = (p) => {
  const out = []
  for (const s of p.split('/')) {
    if (s === '' || s === '.') continue
    if (s === '..') out.pop()
    else out.push(s)
  }
  return '/' + out.join('/')
}

// 一处引用指向哪里：文件，以及文件内的锚点（'' 表示顶部）
const resolveRef = (raw, base, home) => {
  let p = raw.trim().replace(/^["'`]|["'`]$/g, '')
  if (/^file:\/\//i.test(p)) {
    try {
      p = decodeURIComponent(p.slice(7))
    } catch {
      return null
    }
  }
  let frag = ''
  const hash = p.indexOf('#')
  if (hash >= 0) {
    frag = p.slice(hash + 1)
    p = p.slice(0, hash)
  }
  const line = /:(\d+)(?:[:-]\d+)?$/.exec(p)
  if (line) {
    p = p.slice(0, line.index)
    frag ||= 'L' + line[1]
  }
  if (!p) return null
  // 非本地 html、带协议（http://…）、跨行，都不算
  if (!HTML.test(p) || /^[a-z][\w+.-]*:/i.test(p) || p.includes('\n')) return null
  // 文件名不能为空或只有扩展名（切分中文时可能剩 ".html"）
  const name = p.slice(p.lastIndexOf('/') + 1)
  if (name === '' || /^\.html?$/i.test(name)) return null
  if (p === '~' || p.startsWith('~/')) p = home + p.slice(1)
  else if (!p.startsWith('/')) p = base + '/' + p
  return { abs: normalize(p), frag }
}

const hrefOf = (ref) =>
  'file://' +
  encodeURI(ref.abs).replace(/[#?()]/g, (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase()) +
  (ref.frag ? '#' + encodeURIComponent(ref.frag) : '')

const refOf = (href) => {
  if (!/^file:\/\//i.test(href)) return null
  const hash = href.indexOf('#')
  try {
    return {
      abs: decodeURIComponent(href.slice(7, hash < 0 ? undefined : hash)),
      frag: hash < 0 ? '' : decodeURIComponent(href.slice(hash + 1)),
    }
  } catch {
    return null
  }
}

// 裸路径被中文紧邻时的起点候选：先试「非 ASCII → ASCII」的转折处（"见index.html" 里的"见"是正文），
// 都不成立再试整体（"中文文件.html" 这种文件名本身带中文的情况）。
const starts = (bare) => {
  const out = []
  for (let i = 1; i < bare.length; i++) if (bare.charCodeAt(i - 1) > 0x7f && bare.charCodeAt(i) <= 0x7f) out.push(i)
  out.push(0)
  return out
}

// 把每一处 link 回调认得（返回 href）的引用改写成 markdown 链接；代码围栏不动。
// 回调签名 (raw, kind) => href | null，kind 为 'code' | 'link' | 'bare'。
const linkify = (text, link, mark = '') => {
  let fence = null
  return text
    .split('\n')
    .map((line) => {
      const f = FENCE.exec(line)?.[1]
      if (fence) {
        if (f && f[0] === fence[0] && f.length >= fence.length) fence = null
        return line
      }
      if (f) {
        fence = f
        return line
      }
      return line.replace(TOKEN, (m, _ticks, code, bang, label, target, bare) => {
        if (code !== undefined) {
          const h = link(code, 'code')
          return h ? `[${m}${mark}](${h})` : m
        }
        if (target !== undefined && !bang) {
          const h = link(target, 'link')
          return h ? `[${label}${mark}](${h})` : m
        }
        if (bare !== undefined) {
          for (const i of starts(bare)) {
            const h = link(bare.slice(i), 'bare')
            if (h) return `${bare.slice(0, i)}[${bare.slice(i)}${mark}](${h})`
          }
        }
        return m
      })
    })
    .join('\n')
}

// ---- hook 注册 ----

export function register(on) {
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    // 点击只在 fullscreen 终端里到达插件；其它情况保持引擎的绘制
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    const text = e.props.text
    if (!text || !MAYBE_HTML.test(text)) return next(e)

    const cwd = await $.session.cwd()
    if (!cwdOf.has(e.requestId)) cwdOf.set(e.requestId, cwd)
    const home = (await $.env.get('HOME')) ?? ''
    const base = cwdOf.get(e.requestId) || cwd

    // 收集 href：回调返回 href 而非 null，linkify 才会在第一个成立的候选起点停下
    // （"见index.html" 若返回 null，会继续试整体的"见index.html"，多算一个不存在的文件）。
    // linkify 的返回值丢弃——正文由引擎与 mdview 绘制，这里只取路径。
    const hrefs = []
    linkify(text, (raw) => {
      const ref = resolveRef(raw, base, home)
      if (!ref) return null
      const h = hrefOf({ abs: ref.abs, frag: '' }) // 去掉锚点：同一文件的 #a 与 #b 算一个
      if (hrefs.includes(h)) return h
      if (hrefs.length >= MAX_LINKS) return null
      hrefs.push(h)
      return h
    })
    if (hrefs.length === 0) return next(e)
    const abs = hrefs.map((h) => refOf(h).abs)
    // 先拿下一层（引擎 + mdview）的结果，再在其下追加一行
    const rest = await next(e)
    const { Box, Markdown } = $.ui.resolve(e)
    return Box({
      flexDirection: 'column',
      children: [
        rest,
        Box({
          paddingLeft: 2,
          children: [
            Markdown({
              key: 'html-open',
              dimColor: true,
              text: '⎿  ' + abs.map((p, i) => `[${baseName(p)} ↗](${hrefs[i]})`).join(' · '),
              pressableLinks: hrefs,
              onLinkPress: (link) => void openHtml($, link.href),
            }),
          ],
        }),
      ],
    })
  })
}

// 交给系统默认浏览器打开；不经 shell 拼接，直接传参数数组。
async function openHtml($, href) {
  const ref = refOf(href)
  if (!ref) return
  const st = await $.fs.stat(ref.abs).catch(() => null)
  if (st?.kind !== 'file') {
    $.ui.toast(`html-link: 文件不存在 ${ref.abs}`)
    return
  }
  const tries =
    (await $.env.get('OS')) === 'Windows_NT'
      ? [['cmd', '/c', 'start', '', ref.abs]]
      : [
          ['xdg-open', ref.abs],
          ['open', ref.abs],
        ]
  // 只两个候选，超时压到 5s：最坏 10s 仍在 ui.press 链的可接受范围内。
  // Linux 上 /usr/bin/open 常是 xdg-open 的符号链接，第二次尝试只是兜底瞬时故障。
  for (const argv of tries) {
    const run = await $.process.run(argv, { timeoutMs: 5_000 }).catch(() => null)
    if (run && run.exitCode === 0) {
      $.ui.toast(`html-link: 已在浏览器打开 ${baseName(ref.abs)}`)
      return
    }
  }
  $.ui.toast(`html-link: 无法打开浏览器，文件在 ${ref.abs}`)
}
