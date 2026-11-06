// html-link：会话记录里的 .html / .htm 路径变成可点链接，点击用系统浏览器打开。
// .md 的点击显示交给 mdview，本模块只认 html，且只在自己的行里追加，不替换正文。

const MAX_LINKS = 20
const MAX_CWD_ENTRIES = 512
const MAX_STAT_ENTRIES = 1024
const FILE_CACHE_TTL_MS = 30_000
const MISSING_CACHE_TTL_MS = 1_000

// requestId → 首次绘制时的 cwd；有界 LRU，避免长会话无限累积。
const cwdOf = new Map()
// abs path → { kind, checkedAt }；正/负结果均短期缓存，减少流式重绘 IO。
const statCache = new Map()

function readLru(map, key) {
  if (!map.has(key)) return undefined
  const value = map.get(key)
  map.delete(key)
  map.set(key, value)
  return value
}

function writeLru(map, key, value, limit) {
  map.delete(key)
  map.set(key, value)
  if (map.size > limit) map.delete(map.keys().next().value)
}

function clearCaches() {
  cwdOf.clear()
  statCache.clear()
}

async function isHtmlFile($, abs) {
  const now = Date.now()
  const cached = readLru(statCache, abs)
  if (cached) {
    const ttl = cached.kind === 'file' ? FILE_CACHE_TTL_MS : MISSING_CACHE_TTL_MS
    if (now - cached.checkedAt < ttl) return cached.kind === 'file'
  }

  const stat = await $.fs.stat(abs).catch(() => null)
  const kind = stat?.kind === 'file' ? 'file' : 'missing'
  writeLru(statCache, abs, { kind, checkedAt: Date.now() }, MAX_STAT_ENTRIES)
  return kind === 'file'
}

// ---- 以下为路径解析与文本链接化的纯函数：无副作用，不碰 $ ----

const HTML = /\.html?$/i
// 门禁用：只看「这段文本里可能提到 html 路径」，不锚定结尾
const MAYBE_HTML = /\.html?\b/i

// 行内代码、markdown 链接/图片、URL、或裸的 .html 路径（含中文紧邻、:line 后缀）。
// URL 单独成一个捕获组：裸写的 file:// 是绝对路径，比相对路径可靠得多，不能当普通 URL 丢掉。
const TOKEN =
  /(`+)([^`\n]+?)\1|(!?)\[([^\]\n]*)\]\(<?([^)\s>]+)>?\)|\b((?:https?|file):\/\/[^\s<>)\]]+)|(?<![\w/.~@+-])((?:~|\.{1,2})?\/?(?:[\p{L}\p{N}_.@+-]+\/)*[\p{L}\p{N}_.@+-]+\.html?(?::\d+(?::\d+)?)?)(?![\w/])/giu

const FENCE = /^\s{0,3}(`{3,}|~{3,})/

const baseName = (p) => p.slice(p.lastIndexOf('/') + 1)
const escapeMarkdownLabel = (value) => value.replace(/\\/g, '\\\\').replace(/\]/g, '\\]')

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

// 裸路径被中文紧邻时的起点候选。
// token 以 ASCII 开头（"23-张截图.html"）→ 整段就是路径，中文在文件名里，不切。
// token 以中文开头（"见index.html"）→ 先试中文之后的转折处，再兜底整段
// （"中文文件.html" 这种文件名本身以中文开头的情况）。
const starts = (bare) => {
  if (/^[\w/.-]/.test(bare)) return [0]
  const out = []
  for (let i = 1; i < bare.length; i++) {
    if (bare.charCodeAt(i - 1) > 0x7f && /[\w/.-]/.test(bare[i])) out.push(i)
  }
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
      return line.replace(TOKEN, (m, _ticks, code, bang, label, target, url, bare) => {
        if (code !== undefined) {
          const h = link(code, 'code')
          return h ? `[${m}${mark}](${h})` : m
        }
        if (target !== undefined && !bang) {
          const h = link(target, 'link')
          return h ? `[${label}${mark}](${h})` : m
        }
        if (url !== undefined) {
          const h = link(url, 'url')
          return h ? `[${url}${mark}](${h})` : m
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
  // /clear、/resume、/branch 等会话切换触发 session.end；及时释放旧会话缓存。
  on('session.end', async ($, e, next) => {
    clearCaches()
    return next(e)
  })

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    // 点击只在 fullscreen 终端里到达插件；其它情况保持引擎的绘制
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    const text = e.props.text
    if (!text || !MAYBE_HTML.test(text)) return next(e)

    let base
    if (e.requestId != null) {
      const cachedCwd = readLru(cwdOf, e.requestId)
      if (cachedCwd !== undefined) {
        base = cachedCwd
      } else {
        base = await $.session.cwd()
        writeLru(cwdOf, e.requestId, base, MAX_CWD_ENTRIES)
      }
    } else {
      base = await $.session.cwd()
    }
    const home = (await $.env.get('HOME')) ?? ''

    // 收集候选：回调返回 href 而非 null，linkify 才会在第一个成立的候选起点停下
    // （"见index.html" 若返回 null，会继续试整体的"见index.html"，多算一个不存在的文件）。
    // 按绝对路径去重：同一文件的不同锚点只保留一个，不同目录下的同名文件必须分别保留。
    const found = []
    const paths = new Set()
    linkify(text, (raw) => {
      const ref = resolveRef(raw, base, home)
      if (!ref) return null
      const h = hrefOf({ abs: ref.abs, frag: '' }) // 去掉锚点：同一文件的 #a 与 #b 算一个
      if (paths.has(ref.abs)) return h
      if (found.length >= MAX_LINKS) return null
      paths.add(ref.abs)
      found.push({ abs: ref.abs, href: h })
      return h
    })
    if (found.length === 0) return next(e)

    // 正向结果缓存 30 秒，负向结果缓存 1 秒；缓存有容量上限，点击时仍会重新 stat。
    const live = []
    for (const file of found) {
      if (await isHtmlFile($, file.abs)) live.push(file)
    }
    if (live.length === 0) return next(e)

    // 默认只显示文件名；同名文件改为显示相对 cwd 的路径（cwd 之外显示绝对路径）。
    const nameCounts = new Map()
    for (const file of live) {
      const name = baseName(file.abs)
      nameCounts.set(name, (nameCounts.get(name) ?? 0) + 1)
    }
    const labels = live.map((file) => {
      const name = baseName(file.abs)
      if (nameCounts.get(name) === 1) return name
      const prefix = base.endsWith('/') ? base : base + '/'
      return file.abs.startsWith(prefix) ? file.abs.slice(prefix.length) : file.abs
    })
    const hrefs = live.map((file) => file.href)

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
              text: '⎿  ' + labels.map((label, i) => `[${escapeMarkdownLabel(label)} ↗](${hrefs[i]})`).join(' · '),
              pressableLinks: hrefs,
              onLinkPress: (link) => void openHtml($, link.href),
            }),
          ],
        }),
      ],
    })
  })
}

// 交给默认网页浏览器打开；不经 shell 拼接，直接传参数数组。

// desktop 文件内容 → 可 exec 的 argv：取首条 Exec=，去掉 %U/%f 字段码与 env/变量赋值前缀。
// 不处理 Exec 里的引号（发行版桌面文件极少用），解析不出来就放弃这条路、回退 xdg-open。
function desktopExec(text) {
  const line = /^Exec=(.+)$/m.exec(text)?.[1]
  if (!line) return null
  const argv = line
    .trim()
    .split(/\s+/)
    .filter((t) => !/^%[a-zA-Z]$/.test(t) && !/^[A-Za-z_][A-Za-z0-9_]*=/.test(t))
  if (argv[0] === 'env') argv.shift()
  return argv.length > 0 ? argv : null
}

// 系统「默认网页浏览器」的 argv。查的是 http(s) 归属（default-web-browser），
// 不是 text/html 的文件关联——后者会被桌面的「打开方式→设为默认」改掉
// （2026-10-28 就曾被 ZCode 抢走，点击 .html 进了编辑器），前者没人会去动。
async function webBrowserArgv($) {
  const home = (await $.env.get('HOME')) ?? ''
  const run = await $.process.run(['xdg-settings', 'get', 'default-web-browser'], { timeoutMs: 3_000 }).catch(() => null)
  if (!run || run.exitCode !== 0) return null
  const desktop = String(run.stdout ?? '').trim()
  if (!/^[A-Za-z0-9._+@-]+\.desktop$/.test(desktop)) return null
  const dirs = [
    ...(home ? [`${home}/.local/share/applications`] : []),
    '/usr/share/applications',
    '/usr/local/share/applications',
    '/var/lib/flatpak/exports/share/applications',
  ]
  for (const dir of dirs) {
    const text = await $.fs.read(`${dir}/${desktop}`).catch(() => null)
    if (typeof text !== 'string') continue
    const argv = desktopExec(text)
    if (argv) return argv
  }
  return null
}

async function openHtml($, href) {
  const ref = refOf(href)
  if (!ref) return
  const st = await $.fs.stat(ref.abs).catch(() => null)
  if (st?.kind !== 'file') {
    $.ui.toast(`html-link: 文件不存在 ${ref.abs}`)
    return
  }
  const browser = (await $.env.get('OS')) === 'Windows_NT' ? null : await webBrowserArgv($)
  const tries =
    (await $.env.get('OS')) === 'Windows_NT'
      ? [['cmd', '/c', 'start', '', ref.abs]]
      : [
          // 首选浏览器直开（file:// URL，不经 mime 默认）；查不到浏览器才回退 xdg-open/open
          ...(browser ? [[...browser, hrefOf({ abs: ref.abs, frag: '' })]] : []),
          ['xdg-open', ref.abs],
          ['open', ref.abs],
        ]
  // 首选命中即返回；回退候选各 5 秒超时。Linux 上 /usr/bin/open 常是 xdg-open 的
  // 符号链接，最后两次尝试只是兜底瞬时故障，正常路径不会走到。
  for (const argv of tries) {
    const run = await $.process.run(argv, { timeoutMs: 5_000 }).catch(() => null)
    if (run && run.exitCode === 0) {
      $.ui.toast(`html-link: 已在浏览器打开 ${baseName(ref.abs)}`)
      return
    }
  }
  $.ui.toast(`html-link: 无法打开浏览器，文件在 ${ref.abs}`)
}
