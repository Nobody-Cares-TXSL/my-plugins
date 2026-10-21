// 纯函数：在文本中找出 .html 引用，并转换成 file:// 链接。无副作用，不碰 $。

export const HTML = /\.html?$/i

// 行内代码、markdown 链接/图片、URL，或裸的 .html 路径（含中文紧邻、:line 后缀）。
const TOKEN =
  /(`+)([^`\n]+?)\1|(!?)\[([^\]\n]*)\]\(<?([^)\s>]+)>?\)|\b(?:https?|file):\/\/[^\s<>)\]]+|(?<![\w/.~@+-])((?:~|\.{1,2})?\/?(?:[\p{L}\p{N}_.@+-]+\/)*[\p{L}\p{N}_.@+-]+\.html?(?::\d+(?::\d+)?)?)(?![\w/])/giu

export const FENCE = /^\s{0,3}(`{3,}|~{3,})/

export const baseName = (p) => p.slice(p.lastIndexOf('/') + 1)

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
export const resolveRef = (raw, base, home) => {
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
  if (p === '~' || p.startsWith('~/')) p = home + p.slice(1)
  else if (!p.startsWith('/')) p = base + '/' + p
  return { abs: normalize(p), frag }
}

export const hrefOf = (ref) =>
  'file://' +
  encodeURI(ref.abs).replace(/[#?()]/g, (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase()) +
  (ref.frag ? '#' + encodeURIComponent(ref.frag) : '')

export const refOf = (href) => {
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

// 裸路径被中文紧邻时的起点候选：先整体，再从每个「非 ASCII → ASCII」的转折处
const starts = (bare) => {
  const out = [0]
  for (let i = 1; i < bare.length; i++) if (bare.charCodeAt(i - 1) > 0x7f && bare.charCodeAt(i) <= 0x7f) out.push(i)
  return out
}

// 把每一处 link 回调认得（返回 href）的引用改写成 markdown 链接；代码围栏不动。
// 回调签名 (raw, kind) => href | null，kind 为 'code' | 'link' | 'bare'。
export const linkify = (text, link, mark = '') => {
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
