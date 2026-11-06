import { expect, test } from 'claude-code/testing'

const BAND = {
  hasSurvey: false,
  isWorking: false,
  maxRows: 8,
  bodyColumns: 100,
  scroll: { offset: 0, bodyRows: 8 },
  view: {},
}
const answerWith = (text: string) => ({
  value: {
    isAnswered: true as const,
    text,
    usage: { input_tokens: 10, output_tokens: 5, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
  },
})
const rewrite = (text: string) => 'REWRITE\n' + text
const sessionModel = () => ({ value: 'claude-test' })

function draftStubs(on: any, initial: string) {
  let draft = initial
  let fills = 0
  on('prompt.read', () => ({ value: { text: draft, cursor: draft.length } }))
  on('prompt.fill', (_$: unknown, e: { text: string }) => {
    draft = e.text
    fills++
    return { isFilled: true, text: draft, cursor: draft.length }
  })
  return {
    get text() { return draft },
    get fills() { return fills },
    change(text: string) { draft = text },
  }
}
const mount = ($: any, on: any, surface: 'terminal' | 'desktop' = 'terminal') => {
  on('ui.render', ($: any, e: any) => $.ui.resolve(e).Text({ children: ['base'] }))
  return $.ui.mount({ plugin: 'master-plugin', surface, component: 'AbovePrompt', props: BAND })
}

test('三档优化按钮始终可见，未点击不调用模型', async ($, on) => {
  let calls = 0
  on('model.complete', () => { calls++; return answerWith('IMPROVE_SKIP') })
  const ui = await mount($, on)
  expect(await ui.find({ key: 'optimize-low' })).toBeDefined()
  expect(await ui.find({ key: 'optimize-medium' })).toBeDefined()
  expect(await ui.find({ key: 'optimize-high' })).toBeDefined()
  expect(calls).toBe(0)
  await ui.unmount()
})

test('任务重构只回填优化结果，不附加原文且不会发送', async ($, on) => {
  const original = '我感觉项目架构有问题，先看看并给我一些改进的建议，不要修改代码'
  const draft = draftStubs(on, original)
  let submits = 0
  on('prompt.submit', () => { submits++; return { text: '不应发送' } })
  on('model.complete', (_$: unknown, e: { system: string; maxTokens: number }) => {
    expect(e.system.includes('任务意图重构器')).toBe(true)
    expect(e.system.includes('绝不升级为改代码')).toBe(true)
    expect(e.system.includes('技术前提')).toBe(true)
    expect(e.maxTokens).toBe(850)
    expect((e as any).model).toBe('claude-test')
    expect((e as any).effort).toBe('low')
    expect((e as any).timeoutMs).toBe(8500)
    return answerWith(rewrite('请先阅读现有项目的架构与关键模块，找出有证据的设计问题、影响范围及替代方案；只分析和提出建议，不要修改代码。请区分已验证事实与待检验假设。'))
  })
  on('session.model', sessionModel)
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect(draft.text).toBe('请先阅读现有项目的架构与关键模块，找出有证据的设计问题、影响范围及替代方案；只分析和提出建议，不要修改代码。请区分已验证事实与待检验假设。')
  expect(draft.text.includes('原始描述')).toBe(false)
  expect(draft.text.includes(original)).toBe(false)
  expect(draft.fills).toBe(1)
  expect(submits).toBe(0)
  expect(await ui.find({ key: 'restore-draft' })).toBeDefined()
  await ui.unmount()
})


test('low、medium、high 使用当前会话模型并从最初草稿分别优化', async ($, on) => {
  const original = '我想重新梳理这个项目的架构，看看现在的设计是否合理'
  const draft = draftStubs(on, original)
  const outputs = [
    'low 结果：先梳理模块职责与依赖，指出有证据的架构问题。',
    'medium 结果：检查模块边界、数据流与变更影响，按证据提出改进建议。',
    'high 结果：系统评估模块职责、依赖方向、数据流及扩展风险，区分事实与假设并给出优先级建议。',
  ]
  const requests: any[] = []
  on('session.model', sessionModel)
  on('model.complete', (_$: unknown, e: any) => {
    requests.push(e)
    return answerWith(rewrite(outputs[requests.length - 1]))
  })
  const ui = await mount($, on)

  await ui.press({ key: 'optimize-low' })
  expect(draft.text).toBe(outputs[0])
  await ui.press({ key: 'optimize-medium' })
  expect(draft.text).toBe(outputs[1])
  await ui.press({ key: 'optimize-high' })
  expect(draft.text).toBe(outputs[2])

  expect(requests.map((r) => r.model)).toEqual(['claude-test', 'claude-test', 'claude-test'])
  expect(requests.map((r) => r.effort)).toEqual(['low', 'medium', 'high'])
  expect(requests.map((r) => r.timeoutMs)).toEqual([8500, 14000, 22000])
  expect(requests.every((r) => r.prompt === original)).toBe(true)
  expect(requests.every((r) => r.maxTokens === 850)).toBe(true)
  expect(draft.text.includes('原始描述')).toBe(false)

  await ui.press({ key: 'restore-draft' })
  expect(draft.text).toBe(original)
  await ui.unmount()
})

test('手动还原可以恢复优化前的原始草稿', async ($, on) => {
  const original = '帮我看看这个后端接口到底是什么原因导致出错'
  const draft = draftStubs(on, original)
  on('model.complete', () => answerWith(rewrite('先定位后端接口报错的实际触发条件和调用链，收集日志与可复现步骤，再分析可能根因；目前不要直接改动代码。')))
  on('session.model', sessionModel)
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  await ui.press({ key: 'restore-draft' })
  expect(draft.text).toBe(original)
  expect(draft.fills).toBe(2)
  await ui.unmount()
})

test('已有清晰表达不必重构，保持草稿', async ($, on) => {
  const original = '按 docs/api.md 第三节实现重试，超时设置为 30 秒'
  const draft = draftStubs(on, original)
  on('model.complete', () => answerWith('IMPROVE_SKIP'))
  on('session.model', sessionModel)
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect(draft.text).toBe(original)
  expect(draft.fills).toBe(0)
  await ui.unmount()
})

test('优化期间用户修改草稿，不会被过时结果覆盖', async ($, on) => {
  const original = '帮我分析这个设计方案，指出可能存在的问题'
  const draft = draftStubs(on, original)
  on('model.complete', () => {
    draft.change(original + '，先不要动任何代码')
    return answerWith(rewrite('调查当前设计方案中的约束与风险，先不要动任何代码，提供改善建议。'))
  })
  on('session.model', sessionModel)
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect(draft.text).toBe(original + '，先不要动任何代码')
  expect(draft.fills).toBe(0)
  await ui.unmount()
})

test('无效响应格式不能替换草稿', async ($, on) => {
  const original = '帮我重新检查一遍这个页面的布局问题'
  const draft = draftStubs(on, original)
  on('model.complete', () => answerWith('任务：直接重写整个页面并删除样式'))
  on('session.model', sessionModel)
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect(draft.text).toBe(original)
  expect(draft.fills).toBe(0)
  await ui.unmount()
})

test('丢失 @ 引用、路径或数字的改写会被拒绝', async ($, on) => {
  const original = '@src/server.ts 不要改旧接口，只调查 timeout=30 的影响'
  const draft = draftStubs(on, original)
  on('model.complete', () => answerWith(rewrite('请先调查当前接口超时问题，收集日志并分析根因，不修改实现。')))
  on('session.model', sessionModel)
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect(draft.text).toBe(original)
  expect(draft.fills).toBe(0)
  await ui.unmount()
})

test('正确保留 @ 引用和数值的改写可以回填', async ($, on) => {
  const original = '@src/server.ts 不要改旧接口，只调查 timeout=30 的影响'
  const draft = draftStubs(on, original)
  on('model.complete', () => answerWith(rewrite('请审查 @src/server.ts 中 timeout=30 的现有行为，先验证超时设置及其影响，不要修改旧接口；给出事实证据与后续建议。')))
  on('session.model', sessionModel)
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect(draft.text).toBe('请审查 @src/server.ts 中 timeout=30 的现有行为，先验证超时设置及其影响，不要修改旧接口；给出事实证据与后续建议。')
  await ui.unmount()
})

test('空草稿不调用模型', async ($, on) => {
  const draft = draftStubs(on, '')
  let calls = 0
  on('model.complete', () => { calls++; return answerWith('IMPROVE_SKIP') })
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect(calls).toBe(0)
  expect(draft.fills).toBe(0)
  await ui.unmount()
})

test('Desktop 也能显示三档优化按钮', async ($, on) => {
  const ui = await mount($, on, 'desktop')
  expect(await ui.find({ key: 'optimize-low' })).toBeDefined()
  expect(await ui.find({ key: 'optimize-medium' })).toBeDefined()
  expect(await ui.find({ key: 'optimize-high' })).toBeDefined()
  await ui.unmount()
})

test('直接 Enter 提交不触发优化模型', async ($, on) => {
  let calls = 0
  on('model.complete', () => { calls++; return answerWith('IMPROVE_SKIP') })
  on('prompt.submit', (_$: unknown, e: { text: string }) => ({ text: e.text }))
  const text = '帮我检查 Spring Boot 接口'
  const result = await $.prompt.submit({ text, origin: { kind: 'composer' as const }, wait: false })
  expect(result.text).toBe(text)
  expect(calls).toBe(0)
})

test('API 499 会明确提示客户端取消，输入不变', async ($, on) => {
  const original = '帮我完善这个架构方案，看看有哪些认知盲区'
  const draft = draftStubs(on, original)
  on('session.model', sessionModel)
  on('model.complete', () => ({
    value: { isAnswered: false, reason: 'api-error', status: 499, error: 'unknown',
      usage: { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } },
  }))
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect(draft.text).toBe(original)
  expect(draft.fills).toBe(0)
  expect((await ui.find({ text: /499/ }))?.text.includes('499')).toBe(true)
  await ui.unmount()
})

test('超时中断时明确提示，原文不变', async ($, on) => {
  const original = '我想让你帮我研究一下项目里的异常处理策略'
  const draft = draftStubs(on, original)
  on('session.model', sessionModel)
  on('model.complete', () => ({
    value: { isAnswered: false, reason: 'aborted',
      usage: { input_tokens: 0, output_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } },
  }))
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect(draft.text).toBe(original)
  expect(draft.fills).toBe(0)
  expect((await ui.find({ text: /8.5/ }))?.text.includes('8.5')).toBe(true)
  await ui.unmount()
})

test('已回填时显示清晰状态提示，仍然不发送', async ($, on) => {
  const original = '帮我分析项目的技术风险，看看有哪些改进方向'
  draftStubs(on, original)
  on('session.model', sessionModel)
  on('model.complete', () => answerWith(rewrite('先梳理现有模块和依赖，分析技术风险的证据与影响范围，再给出按优先级排序的建议；本次只分析不改代码。')))
  const ui = await mount($, on)
  await ui.press({ key: 'optimize-low' })
  expect((await ui.find({ text: /low优化完成/ }))?.text.includes('low优化完成')).toBe(true)
  await ui.unmount()
})
