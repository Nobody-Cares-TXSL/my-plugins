// prompt-optimize：把口语化的提示词改写成任务导向描述，改写后的文本直接进入会话。
// 只处理人手动输入的文本；命令、隐藏提示词、非人手来源、过长过短的文本一律原样放行。

const MAX_CHARS = 300 // 超过视为别处复制的成品提示词，不再优化
const MIN_CHARS = 10 // 过短（确认词、单字）不优化
const MAX_OUTPUT_CHARS = 400 // 改写结果上限，防止把短提示词换成更长的文本
const TIMEOUT_MS = 8000

// 人手来源：终端输入，以及手机/网页客户端的 Remote Control
const HUMAN_ORIGINS = new Set(['composer', 'bridge'])

const SYSTEM = [
  '你是提示词任务化改写器。把用户的一句话请求改写为任务导向的简短描述，供执行者阅读。',
  '',
  '规则：',
  '- 只澄清用户已有的意图：目标、对象、约束、交付物、验收标准。',
  '- 绝不新增用户没提到的需求、技术选型或验收条件；信息不足处标注「待确认」。',
  '- 保留原文中的专有名词、路径、命令、代码标识符原样。',
  '- 原文里的 @文件 提及必须原样保留，包括 @ 符号。',
  '- 输出 2-4 行纯文本，不要解释、不要寒暄、不要 Markdown 标题。',
  '- 若原文已是清晰完整的任务描述，只输出 IMPROVE_SKIP。',
].join('\n')

// 原文中的 @ 提及：改写结果必须全部保留，否则视为丢失附件
const mentionsOf = (text) => [...text.matchAll(/@[^\s@]+/g)].map((m) => m[0])

const optimizePrompt = async ($, e, next) => {
  const text = (e.text || '').trim()
  // 命令的文本由 command.run 决定，隐藏提示词不该被改写，非人手来源不碰
  if (e.command || e.isMeta) return next(e)
  if (!HUMAN_ORIGINS.has(e.origin?.kind)) return next(e)
  if (text.length > MAX_CHARS || text.length < MIN_CHARS) return next(e)

  let improved = ''
  try {
    const reply = await $.model.complete(
      {
        model: await $.session.model(),
        system: SYSTEM,
        prompt: text,
        maxTokens: 400,
        effort: 'low',
        timeoutMs: TIMEOUT_MS,
      },
      { signal: next.signal },
    )
    if (reply.isAnswered) improved = reply.text.trim()
  } catch (error) {
    $.ui.log('prompt-optimize：改写失败，已放行原文：' + error.message)
    return next(e)
  }

  if (!improved || improved.includes('IMPROVE_SKIP')) return next(e)
  // 改写结果超长，或丢掉了原文的 @ 提及：保留原文
  if (improved.length > MAX_OUTPUT_CHARS) {
    $.ui.log('prompt-optimize：改写结果过长，已放行原文')
    return next(e)
  }
  if (!mentionsOf(text).every((mention) => improved.includes(mention))) {
    $.ui.log('prompt-optimize：改写丢失 @ 提及，已放行原文')
    return next(e)
  }
  return next({ ...e, text: improved })
}

// 失败时按原样放行，不吞掉用户的提示词
const passThrough = async ($, e, next) => next(e)

export function register(on) {
  on('prompt.submit', optimizePrompt).catch(passThrough)
}
