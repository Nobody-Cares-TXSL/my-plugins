// 启动入口：hooks.json 的 modules 每插件只允许一项，所有 mod 从这里挂上去。
// 加新 mod 时在下面加一行 import 和一次调用。

import { register as registerHtmlLink } from './html-link.js'
import { register as registerPrompts } from './prompts.js'

export function register(on, options) {
  registerPrompts(on, options)
  registerHtmlLink(on)
}
