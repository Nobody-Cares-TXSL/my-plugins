// net-link：会话记录里的裸 http(s) 链接改写成 markdown 链接，交给引擎绘制与点击。
// 只改绘制用的 props 副本，存储的消息不变。与 html-link 分工：html-link 认本地 .html 文件。

// URL 到空白、包裹字符、表格竖线或中日韩字符为止（中文正文常紧贴链接书写）；
// 结尾的 ASCII 标点由 trimUrl 去掉
const URL_RE = /https?:\/\/[^\s<>"'`|　-〿一-鿿＀-￯]+/gi
const FENCE = /^\s{0,3}(`{3,}|~{3,})/
// "*" 是 markdown 粗体：**https://x** 里 URL 后面跟的是 "**"
const TAIL = /[.,;:!?…。，、；：！？"'」』】*]+$/u

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

// markdown 链接目标里的括号会截断语法，编码后浏览器会还原
const hrefOf = (url) =>
  url.replace(/[()]/g, (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase())

// 把裸 URL 改写成 [url](url)，可见文字不变，表格单元格里也能点。
// 已有的 [x](url) 目标、尖括号自动链接、行内代码、代码围栏都不动。
const linkifyBare = (text) => {
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
      return line.replace(URL_RE, (match, offset, whole) => {
        const url = trimUrl(match)
        if (!/^https?:\/\/[^/?#\s]+/i.test(url)) return match
        // 已是 markdown 链接的目标或尖括号自动链接
        const before = whole.slice(Math.max(0, offset - 2), offset)
        if (before.endsWith('](') || before.endsWith('<')) return match
        // 行内代码：前面反引号数为奇数说明在代码里
        if (((whole.slice(0, offset).match(/`/g) || []).length % 2) === 1) return match
        return '[' + url + '](' + hrefOf(url) + ')' + match.slice(url.length)
      })
    })
    .join('\n')
}

export function register(on) {
  // 点击由引擎处理：改写后的链接是普通 https 链接，终端自己打开浏览器。
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    if (!e.props.text || !/https?:\/\//i.test(e.props.text)) return next(e)
    return next({ ...e, props: { ...e.props, text: linkifyBare(e.props.text) } })
  })

  on('ui.render', { component: 'UserMessage' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    if (!e.props.text || !/https?:\/\//i.test(e.props.text)) return next(e)
    return next({ ...e, props: { ...e.props, text: linkifyBare(e.props.text) } })
  })

  on('ui.render', { component: 'CommandOutput' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || !e.viewport?.isFullscreen) return next(e)
    if (!e.props.text || !/https?:\/\//i.test(e.props.text)) return next(e)
    return next({ ...e, props: { ...e.props, text: linkifyBare(e.props.text) } })
  })
}
