// html-link：会话记录里的 .html / .htm 路径变成可点链接，点击用系统浏览器打开。
// .md 的点击显示交给 mdview，本模块只认 html，且只在自己的行里追加，不替换正文。

import { HTML, baseName, hrefOf, linkify, refOf, resolveRef } from './links.js'

const MAX_LINKS = 20
const cwdOf = new Map() // requestId → 首次绘制时的 cwd：cd 之后旧消息里的相对路径不漂移

export function register(on) {
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    // 点击只在 fullscreen 终端里到达插件；其它情况保持引擎的绘制
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    const text = e.props.text
    if (!text || !HTML.test(text)) return next(e)

    const cwd = await $.session.cwd()
    if (!cwdOf.has(e.requestId)) cwdOf.set(e.requestId, cwd)
    const home = (await $.env.get('HOME')) ?? ''
    const base = cwdOf.get(e.requestId) || cwd

    // 只收集路径（按 abs 去重，同一文件的 #a 与 #b 算一个），不改写正文
    const abs = []
    linkify(text, (raw) => {
      const ref = resolveRef(raw, base, home)
      if (ref && !abs.includes(ref.abs) && abs.length < MAX_LINKS) abs.push(ref.abs)
      return null
    })
    if (abs.length === 0) return next(e)

    const hrefs = abs.map((p) => hrefOf({ abs: p, frag: '' }))
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
