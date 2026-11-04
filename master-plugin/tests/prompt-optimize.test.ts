import { expect, test } from 'claude-code/testing'

// 模型 stub：回答固定的改写文本
const answerWith = (text: string) => ({
  value: {
    isAnswered: true as const,
    text,
    usage: { input_tokens: 10, output_tokens: 5, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
  },
})

// 会话模型 stub：任何改写都要先读当前模型
const sessionModel = () => ({ value: 'claude-test' })
// 链尾 stub：返回进会话的文本本身
const passThrough = (_$: unknown, e: { text: string }) => ({ text: e.text })

// 终端里人手输入的提交
const fromComposer = (text: string) => ({ text, origin: { kind: 'composer' as const }, wait: false })

test('短提示词被改写为任务化描述', async ($, on) => {
  on('model.complete', () => answerWith('任务：修改登录页按钮颜色'))
  on('session.model', sessionModel)
  on('prompt.submit', passThrough)

  const result = await $.prompt.submit(fromComposer('那个登录页的按钮颜色改一下，太丑了'))
  expect(result.text).toBe('任务：修改登录页按钮颜色')
})

test('模型返回 IMPROVE_SKIP 时保留原文', async ($, on) => {
  on('model.complete', () => answerWith('IMPROVE_SKIP'))
  on('session.model', sessionModel)
  on('prompt.submit', passThrough)

  const text = '按 docs/api.md 第 3 节实现重试，超时 30 秒'
  const result = await $.prompt.submit(fromComposer(text))
  expect(result.text).toBe(text)
})

test('超长提示词不调用模型', async ($, on) => {
  let called = 0
  on('model.complete', () => {
    called += 1
    return answerWith('不应发生')
  })
  on('prompt.submit', passThrough)

  const text = '你是一个资深架构师。'.repeat(40) // 超过 300 字符
  const result = await $.prompt.submit(fromComposer(text))
  expect(result.text).toBe(text)
  expect(called).toBe(0)
})

test('过短提示词不调用模型', async ($, on) => {
  let called = 0
  on('model.complete', () => {
    called += 1
    return answerWith('不应发生')
  })
  on('prompt.submit', passThrough)

  const result = await $.prompt.submit(fromComposer('ok'))
  expect(result.text).toBe('ok')
  expect(called).toBe(0)
})

test('模型失败时保留原文', async ($, on) => {
  on('model.complete', () => ({ deny: '模型不可用' }))
  on('session.model', sessionModel)
  on('prompt.submit', passThrough)

  const text = '那个登录页的按钮颜色改一下，太丑了'
  const result = await $.prompt.submit(fromComposer(text))
  expect(result.text).toBe(text)
})

test('非人手来源的提示词不改写', async ($, on) => {
  let called = 0
  on('model.complete', () => {
    called += 1
    return answerWith('不应发生')
  })
  on('prompt.submit', passThrough)

  const text = '另一个会话发来的指令，请继续执行第三步'
  for (const origin of [{ kind: 'peer' as const }, { kind: 'scheduled-trigger' as const }, { kind: 'sdk' as const }]) {
    const result = await $.prompt.submit({ text, origin, wait: false })
    expect(result.text).toBe(text)
  }
  expect(called).toBe(0)
})

test('隐藏提示词与命令不改写', async ($, on) => {
  let called = 0
  on('model.complete', () => {
    called += 1
    return answerWith('不应发生')
  })
  on('prompt.submit', passThrough)

  const text = '这是一条不该被改写的隐藏提示词'
  const hidden = await $.prompt.submit({ text, origin: { kind: 'composer' as const }, wait: false, isMeta: true })
  expect(hidden.text).toBe(text)

  const command = await $.prompt.submit({
    text: 'prompts 关键词',
    origin: { kind: 'composer' as const },
    wait: false,
    command: { name: 'prompts', args: '关键词' },
  })
  expect(command.text).toBe('prompts 关键词')
  expect(called).toBe(0)
})

test('改写结果丢失 @ 提及时保留原文', async ($, on) => {
  on('model.complete', () => answerWith('检查 src/server.ts 的重试逻辑'))
  on('session.model', sessionModel)
  on('prompt.submit', passThrough)

  const text = '@src/server.ts 这个重试逻辑有问题吗，帮我看看'
  const result = await $.prompt.submit(fromComposer(text))
  expect(result.text).toBe(text)
})

test('改写结果过长时保留原文', async ($, on) => {
  on('model.complete', () => answerWith('任务化描述。'.repeat(100)))
  on('session.model', sessionModel)
  on('prompt.submit', passThrough)

  const text = '那个登录页的按钮颜色改一下，太丑了'
  const result = await $.prompt.submit(fromComposer(text))
  expect(result.text).toBe(text)
})
