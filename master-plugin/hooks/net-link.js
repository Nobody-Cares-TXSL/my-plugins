// net-link：会话记录里的 http(s) 链接变成可点行，单击用系统浏览器打开。
// 与 html-link 分工：html-link 认本地 .html 文件，本模块认网络 URL；两者都只追加不替换。

const MAX_LINKS = 20
const MAX_LABEL = 60
const MAX_SCAN = 100_000 // 工具输出可能是几十 MB，只看前 100k 字符

// URL 到空白、包裹字符或中日韩字符为止（中文正文常紧贴链接书写）；
// 结尾的 ASCII 标点由 trimUrl 去掉
const URL_RE = /https?:\/\/[^\s<>"'`　-〿一-鿿＀-￯]+/gi
const FENCE = /^\s{0,3}(`{3,}|~{3,})/
const TAIL = /[.,;:!?…。，、；：！？"'」』】]+$/u

// ---- 以下为文本解析的纯函数：无副作用，不碰 $ ----

// 去掉粘在 URL 末尾的标点。右括号只在不成对时去掉：
// wikipedia 的 "Foo_(bar)" 结尾的 ")" 属于 URL，正文的 "（见 https://x）" 不属于。
const trimUrl = (raw) => {
  let url = raw.replace(TAIL, '')
  while (url.endsWith(')')) {
    const open = (url.match(/\(/g) || []).length
    const close = (url.match(/\)/g) || []).length
    if (open >= close) break
    url = url.slice(0, -1).replace(TAIL, '')
  }
  return url
}

// 抽出文本里的链接：跳过代码围栏，按出现顺序去重，最多 MAX_LINKS 条
const collect = (text) => {
  const found = []
  const seen = new Set()
  let fence = null
  for (const line of text.slice(0, MAX_SCAN).split('\n')) {
    const f = FENCE.exec(line)?.[1]
    if (fence) {
      if (f && f[0] === fence[0] && f.length >= fence.length) fence = null
      continue
    }
    if (f) {
      fence = f
      continue
    }
    for (const match of line.matchAll(URL_RE)) {
      const url = trimUrl(match[0])
      // 至少要有个主机名："https://" 后面直接是路径或空白的不算
      if (!/^https?:\/\/[^/?#\s]+/i.test(url) || seen.has(url)) continue
      seen.add(url)
      found.push(url)
      if (found.length >= MAX_LINKS) return found
    }
  }
  return found
}

// markdown 链接目标里的括号会截断语法，编码后系统打开时浏览器会还原
const hrefOf = (url) =>
  url.replace(/[()]/g, (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase())

// 显示文本去掉协议，并转义会破坏 "[label]" 的方括号
const labelOf = (url) => {
  const text = url.replace(/^https?:\/\//i, '').replace(/[[\]]/g, '\\$&')
  return text.length > MAX_LABEL ? text.slice(0, MAX_LABEL - 1) + '…' : text
}

const hostOf = (url) => url.replace(/^https?:\/\//i, '').split(/[/?#]/)[0]

// 工具输出是任意结构：递归取出其中的字符串再扫描
const textOf = (value) => {
  if (typeof value === 'string') return value
  if (Array.isArray(value)) return value.map(textOf).join('\n')
  if (value && typeof value === 'object') return Object.values(value).map(textOf).join('\n')
  return ''
}

// ---- hook 注册 ----

export function register(on) {
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    return appendLinks($, e, next, e.props.text)
  })

  on('ui.render', { component: 'UserMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    return appendLinks($, e, next, e.props.text)
  })

  on('ui.render', { component: 'CommandOutput' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    return appendLinks($, e, next, e.props.text)
  })

  on('ui.render', { component: 'ToolResult' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    return appendLinks($, e, next, textOf(e.props.output))
  })
}

// 先拿下一层（引擎与其它 mod）的绘制，再在其下追加一行链接。
async function appendLinks($, e, next, text) {
  if (!text || !/https?:\/\//i.test(text)) return next(e)
  const urls = collect(text)
  if (urls.length === 0) return next(e)

  const rest = await next(e)
  const { Box, Markdown } = $.ui.resolve(e)
  const hrefs = urls.map(hrefOf)
  return Box({
    flexDirection: 'column',
    children: [
      rest,
      Box({
        paddingLeft: 2,
        children: [
          Markdown({
            key: 'net-open',
            dimColor: true,
            text: '⎿  ' + urls.map((url, i) => '[' + labelOf(url) + ' ↗](' + hrefs[i] + ')').join(' · '),
            pressableLinks: hrefs,
            onLinkPress: (link) => void openUrl($, link.href),
          }),
        ],
      }),
    ],
  })
}

// 交给系统默认浏览器打开；不经 shell 拼接，直接传参数数组。
async function openUrl($, href) {
  const url = href.replace(/%28/g, '(').replace(/%29/g, ')')
  const tries =
    (await $.env.get('OS')) === 'Windows_NT'
      ? [['cmd', '/c', 'start', '', url]]
      : [
          ['xdg-open', url],
          ['open', url],
        ]
  // 两个候选、每次 5s：最坏 10s 仍在 ui.press 链的可接受范围内。
  for (const argv of tries) {
    const run = await $.process.run(argv, { timeoutMs: 5_000 }).catch(() => null)
    if (run && run.exitCode === 0) {
      $.ui.toast('net-link: 已在浏览器打开 ' + hostOf(url))
      return
    }
  }
  $.ui.toast('net-link: 无法打开浏览器，链接在 ' + url)
}
